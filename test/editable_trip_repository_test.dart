import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_service_test.dart' as transport;
import 'local_account_lifecycle_test.dart' as accounts;
import 'local_trip_store_test.dart' as stores;

class Server {
  int creates = 0, updates = 0, deletes = 0;
  final replies = <String, Map<String, Object?>>{};
  bool offline = false, missing = false;
  EditableHead? latest;
  Completer<void>? entered;
  Completer<void>? release;
  Future<ResponseBody> respond(RequestOptions options) async {
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (missing) return transport.jsonReply({'code': 'PGRST202'}, 404);
    final args = Map<String, Object?>.from(options.data as Map);
    final rpc = options.uri.path.split('/').last;
    if (rpc == 'get_editable_mutation_v2') {
      return transport.jsonReply(
        replies[args['p_request_id']] ??
            {'status': 'not_found', 'head': null, 'receipt': null},
      );
    }
    if (rpc == 'get_editable_trip_v2') {
      return transport.jsonReply({
        'status': latest == null ? 'unavailable' : 'ready',
        'head': latest == null ? null : EditableRecordCodec.headJson(latest!),
      });
    }
    if (rpc == 'list_owned_trips_v2') {
      return transport.jsonReply({'items': [], 'nextCursor': null});
    }
    final op = rpc.split('_').first;
    if (op == 'create') creates++;
    if (op == 'update') updates++;
    if (op == 'delete') deletes++;
    final requestId = args['p_request_id'] as String;
    final raw = op == 'delete'
        ? EditableTripCodec.canonicalJson({
            'op': op,
            'tripId': args['p_trip_id'],
            'expectedVersion': args['p_expected_version'],
          })
        : args['p_request_text'] as String;
    final request = EditableRecordCodec.object(
      EditableTripCodec.parseStrict(raw),
    );
    final version = (args['p_expected_version'] as int? ?? 0) + 1;
    latest = op == 'delete'
        ? null
        : records.head(
            version: version,
            document: EditableTripCodec.decode(
              request['payloadText'] as String,
            ),
          );
    final receipt = EditableReceipt(
      requestId: requestId,
      ownerId: records.ownerA,
      tripId: records.tripId,
      operation: op,
      requestDigest: EditableTripCodec.digestText(raw),
      contentDigest: op == 'delete' ? null : request['contentDigest'] as String,
      resultVersion: version,
      committedAt: DateTime.utc(2026, 10, 15),
      sourceBinding: EditableRecordCodec.source(request['sourceBinding']),
    );
    final reply = <String, Object?>{
      'status': op == 'delete' ? 'deleted' : 'committed',
      'receipt': EditableRecordCodec.receiptJson(receipt),
      'head': latest == null ? null : EditableRecordCodec.headJson(latest!),
    };
    replies[requestId] = reply;
    entered?.complete();
    await release?.future;
    return transport.jsonReply(reply);
  }
}

class Context {
  final stores.TestStoreContext disk;
  Session session = accounts.sessionFor(records.ownerA);
  late LocalAccountLifecycleService lifecycle;
  late EditableTripService remote;
  late EditableTripRepository repository;
  final Server server = Server();
  Context(this.disk) {
    bind();
  }
  void bind() {
    lifecycle = LocalAccountLifecycleService(
      storeLoader: () async => disk.store,
      sessionReader: () => session,
      registryPath: '${disk.tempDir.path}/account_cache_lifecycle_v1.json',
    );
    remote = transport.service(lifecycle, server.respond);
    repository = EditableTripRepository(
      store: disk.store,
      lifecycle: lifecycle,
      service: remote,
      newId: () => records.requestId,
    );
  }

  Future<void> login() async {
    expect(
      await lifecycle.establishAccount(freshAuthentication: true),
      isNotNull,
    );
  }

  Future<void> close() async {
    remote.close();
    await lifecycle.close();
  }
}

Future<void> run(Future<void> Function(Context) body) =>
    stores.runWithStore((disk) async {
      final ctx = Context(disk);
      try {
        await body(ctx);
      } finally {
        await ctx.close();
      }
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('explicit retry uses the confirmed key rather than a changed editor candidate', () async {
    await run((ctx) async {
      await ctx.login();
      ctx.server.offline = true;
      await expectLater(
        ctx.repository.saveAccount(
          document: records.doc(),
          commands: [],
          requestId: records.draftId,
        ),
        transport.failure(EditableRemoteFailure.uncertain),
      );
      ctx.server.offline = false;
      final reply = await ctx.repository.retryPending(records.draftId);
      expect(reply.receipt!.requestId, records.draftId);
      expect(ctx.server.creates, 1);
      expect(
        await ctx.disk.store.listEditableAttempts(
          handle: ctx.lifecycle.handle!,
        ),
        isEmpty,
      );
      await expectLater(
        ctx.repository.retryPending(records.requestId),
        throwsA(isA<ImportJournalNotFoundException>()),
      );
      expect(ctx.server.creates, 1);
    });
  });
  test(
    'remote commit plus local ack failure recovers after sealed disk restart',
    () async {
      await run((ctx) async {
        final draft = await ctx.repository.saveGuest(
          scope: 'default',
          draftId: records.draftId,
          expectedRevision: null,
          document: records.doc(),
        );
        await ctx.login();
        ctx.disk.store.onEditableStepForTesting = (step) async {
          if (step == 'ack_source_removed') {
            throw StateError('ack transaction fault');
          }
        };
        await expectLater(
          ctx.repository.importGuest(draft),
          throwsA(isA<StateError>()),
        );
        expect(ctx.server.creates, 1);
        expect(
          await ctx.disk.store.listEditableAttempts(
            handle: ctx.lifecycle.handle!,
          ),
          hasLength(1),
        );
        expect(
          await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: records.draftId,
          ),
          isNotNull,
        );
        ctx.disk.store.onEditableStepForTesting = null;
        expect(await ctx.lifecycle.sealForPause(), isTrue);
        await ctx.close();
        await records.reopen(ctx.disk);
        ctx.bind();
        expect(await ctx.lifecycle.resumeAccount(), isNotNull);
        await ctx.repository.recoverPending();
        expect(ctx.server.creates, 1);
        expect(
          await ctx.disk.store.listEditableAttempts(
            handle: ctx.lifecycle.handle!,
          ),
          isEmpty,
        );
        expect(
          await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: records.draftId,
          ),
          isNull,
        );
        expect(
          (await ctx.repository.readTrip(records.tripId)).head!.version,
          1,
        );
        final outbox = await ctx.disk.store.rawDb.query(
          'editable_mutation_outbox',
        );
        expect(jsonEncode(outbox), isNot(contains(ctx.session.accessToken)));
      });
    },
  );

  test('import frozen revision one retains revision two and lookup may return head three', () async {
    await run((ctx) async {
      final first = await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.draftId,
        expectedRevision: null,
        document: records.doc(),
      );
      await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.draftId,
        expectedRevision: 1,
        document: records.doc(),
      );
      await ctx.login();
      ctx.server.offline = true;
      await expectLater(
        ctx.repository.importGuest(first),
        transport.failure(EditableRemoteFailure.uncertain),
      );
      ctx.server.offline = false;
      ctx.disk.store.onEditableStepForTesting = (step) async {
        if (step == 'ack_snapshot_written') throw StateError('ack fault');
      };
      await expectLater(
        ctx.repository.recoverPending(),
        throwsA(isA<StateError>()),
      );
      final id = ctx.server.replies.keys.single;
      final doc = records.doc();
      final newer = records.head(
        version: 3,
        document: doc.copyWith(
          input: TripInput.fromJson({
            ...doc.input.toJson(),
            'title': 'Newer head',
          }),
        ),
      );
      ctx.server.replies[id]!['head'] = EditableRecordCodec.headJson(newer);
      ctx.disk.store.onEditableStepForTesting = null;
      await ctx.repository.recoverPending();
      expect(ctx.server.creates, 1);
      expect(
        (await ctx.disk.store.readEditableDraft(
          deviceScope: 'default',
          draftId: records.draftId,
        ))!.revision,
        2,
      );
      expect(
        (await ctx.disk.store.readEditableSnapshot(
          handle: ctx.lifecycle.handle!,
          tripId: records.tripId,
        ))!.head.version,
        3,
      );
    });
  });

  test('cache is read only on network failure; deployment and digest conflicts stay visible', () async {
    await run((ctx) async {
      await ctx.login();
      ctx.server.latest = records.head();
      expect(
        (await ctx.repository.readTrip(records.tripId)).state,
        EditableTripViewState.online,
      );
      ctx.server.offline = true;
      expect(
        (await ctx.repository.readTrip(records.tripId)).state,
        EditableTripViewState.cachedReadOnly,
      );
      expect(
        (await ctx.repository.readTrip(records.draftId)).state,
        EditableTripViewState.unavailable,
      );
      await expectLater(
        ctx.repository.readTrip(records.tripId, allowCached: false),
        transport.failure(EditableRemoteFailure.uncertain),
      );
      ctx.server.offline = false;
      ctx.server.missing = true;
      await expectLater(
        ctx.repository.readTrip(records.tripId),
        transport.failure(EditableRemoteFailure.deploymentBlocked),
      );
      ctx.server.missing = false;
      final doc = records.doc();
      ctx.server.latest = records.head(
        document: doc.copyWith(
          input: TripInput.fromJson({
            ...doc.input.toJson(),
            'title': 'same version forged content',
          }),
        ),
      );
      await expectLater(
        ctx.repository.readTrip(records.tripId),
        throwsA(isA<SnapshotConflictException>()),
      );
      ctx.server.latest = null;
      expect(
        (await ctx.repository.readTrip(records.tripId)).state,
        EditableTripViewState.unavailable,
      );
      expect(
        await ctx.disk.store.readEditableSnapshot(
          handle: ctx.lifecycle.handle!,
          tripId: records.tripId,
        ),
        isNull,
      );
    });
  });

  test('logout before ack fences publication, clears account data and retains Guest source', () async {
    await run((ctx) async {
      final draft = await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.draftId,
        expectedRevision: null,
        document: records.doc(),
      );
      await ctx.login();
      ctx.server.entered = Completer<void>();
      ctx.server.release = Completer<void>();
      final operation = ctx.repository.importGuest(draft);
      final rejection = expectLater(operation, throwsA(isA<StateError>()));
      await ctx.server.entered!.future;
      ctx.lifecycle.invalidateAccountContext();
      ctx.server.release!.complete();
      await rejection;
      expect(await ctx.lifecycle.revokeAccount(), isTrue);
      ctx.session = accounts.sessionFor(records.ownerB);
      await ctx.login();
      expect(
        await ctx.disk.store.listEditableSnapshots(
          handle: ctx.lifecycle.handle!,
        ),
        isEmpty,
      );
      expect(
        await ctx.disk.store.listEditableAttempts(
          handle: ctx.lifecycle.handle!,
        ),
        isEmpty,
      );
      expect(
        await ctx.disk.store.readEditableDraft(
          deviceScope: 'default',
          draftId: records.draftId,
        ),
        isNotNull,
      );
    });
  });

  test('login never invents a retry; explicitly selected import reuses identity after purge', () async {
    await run((ctx) async {
      final draft = await ctx.repository.saveGuest(
        scope: 'default',
        draftId: records.draftId,
        expectedRevision: null,
        document: records.doc(),
      );
      await ctx.login();
      ctx.disk.store.onEditableStepForTesting = (step) async {
        if (step == 'ack_snapshot_written') throw StateError('lost local ack');
      };
      await expectLater(
        ctx.repository.importGuest(draft),
        throwsA(isA<StateError>()),
      );
      ctx.disk.store.onEditableStepForTesting = null;
      await ctx.lifecycle.revokeAccount();
      await ctx.login();
      await ctx.repository.listOwned();
      await ctx.repository.recoverPending();
      expect(ctx.server.creates, 1);
      expect(
        await ctx.disk.store.readEditableDraft(
          deviceScope: 'default',
          draftId: records.draftId,
        ),
        isNotNull,
      );
      await ctx.repository.importGuest(draft);
      expect(ctx.server.creates, 1);
      expect(
        await ctx.disk.store.readEditableDraft(
          deviceScope: 'default',
          draftId: records.draftId,
        ),
        isNull,
      );
    });
  });

  test('save verifies command replay, then update/delete use one confirmed frozen attempt', () async {
    await run((ctx) async {
      await ctx.login();
      final base = records.head();
      final changed = base.document.copyWith(
        input: TripInput.fromJson({
          ...base.document.input.toJson(),
          'title': 'Edited',
        }),
      );
      await expectLater(
        ctx.repository.saveAccount(document: changed, commands: [], base: base),
        throwsA(isA<EditableMutationException>()),
      );
      expect(
        await ctx.disk.store.listEditableAttempts(
          handle: ctx.lifecycle.handle!,
        ),
        isEmpty,
      );
      final result = await ctx.repository.saveAccount(
        document: changed,
        commands: [SetTripInputCommand(changed.input)],
        base: base,
      );
      expect(result.head!.document.input.title, 'Edited');
      expect(result.head!.version, 2);
      // A distinct confirmed operation has a distinct key, not the previous update key.
      final deleting = EditableTripRepository(
        store: ctx.disk.store,
        lifecycle: ctx.lifecycle,
        service: ctx.remote,
        newId: () => records.draftId,
      );
      expect(
        (await deleting.deleteTrip(result.head!)).status,
        EditableMutationStatus.deleted,
      );
      expect(ctx.server.updates, 1);
      expect(ctx.server.deletes, 1);
      expect(
        await ctx.disk.store.readEditableSnapshot(
          handle: ctx.lifecycle.handle!,
          tripId: records.tripId,
        ),
        isNull,
      );
    });
  });
}
