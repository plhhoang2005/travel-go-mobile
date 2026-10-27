import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_envelope.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';

import 'editable_local_store_test.dart' as records;
import 'local_trip_store_test.dart' as stores;
import 'editable_trip_repository_test.dart' as repository;
import 'editable_trip_service_test.dart' as transport;

class EvidenceServer extends repository.Server {
  final calls = <String>[];
  String? rejectCreate;
  String? rejectUpdate;
  bool supported = true, loseAck = false;
  @override
  Future<ResponseBody> respond(RequestOptions options) async {
    final rpc = options.uri.path.split('/').last;
    calls.add(rpc);
    if (rpc == 'create_evidence_trip_v1' && rejectCreate != null) {
      return transport.jsonReply({
        'code': 'P0001',
        'message': rejectCreate,
      }, 400);
    }
    if (rpc == 'update_evidence_trip_v1' && rejectUpdate != null) {
      return transport.jsonReply({
        'code': 'P0001',
        'message': rejectUpdate,
      }, 400);
    }
    if (rpc == 'get_trip_capabilities_v1') {
      return supported
          ? transport.jsonReply({'evidenceV1': true, 'ownedListV3': true})
          : transport.jsonReply({'code': 'PGRST202'}, 404);
    }
    final args = Map<String, Object?>.from(options.data as Map);
    if (rpc == 'get_evidence_mutation_v1') {
      return transport.jsonReply(
        replies[args['p_request_id']] ??
            {'status': 'not_found', 'head': null, 'receipt': null},
      );
    }
    if (rpc == 'get_evidence_trip_v1') {
      return transport.jsonReply({
        'status': latest == null ? 'unavailable' : 'ready',
        'head': latest == null ? null : EditableRecordCodec.headJson(latest!),
      });
    }
    if (rpc == 'list_owned_trips_v3') {
      return transport.jsonReply({
        'items': latest == null
            ? []
            : [
                {
                  ...transport.summary(kind: 'evidence_v1'),
                  'version': latest!.version,
                },
              ],
        'nextCursor': null,
      });
    }
    if (!rpc.endsWith('_evidence_trip_v1')) {
      throw StateError('Unexpected downgrade RPC: $rpc');
    }
    final op = rpc.split('_').first;
    final requestId = args['p_request_id'] as String;
    final request = op == 'delete'
        ? EditableTripCodec.canonicalJson({
            'op': 'delete',
            'tripId': args['p_trip_id'],
            'expectedVersion': args['p_expected_version'],
          })
        : args['p_request_text'] as String;
    final body = jsonDecode(request) as Map;
    final version = (args['p_expected_version'] as int? ?? 0) + 1;
    if (op == 'create') creates++;
    if (op == 'update') updates++;
    if (op == 'delete') deletes++;
    latest = op == 'delete'
        ? null
        : EditableRecordCodec.head({
            ...evidenceHeadJson(version: version),
            'payloadText': body['payloadText'],
            'contentDigest': body['contentDigest'],
          });
    final receipt = EditableReceipt(
      requestId: requestId,
      ownerId: records.ownerA,
      tripId: records.tripId,
      operation: op,
      requestDigest: EditableTripCodec.digestText(request),
      contentDigest: op == 'delete' ? null : body['contentDigest'] as String,
      resultVersion: version,
      committedAt: DateTime.utc(2026, 10, 27),
      sourceBinding: null,
    );
    final reply = <String, Object?>{
      'status': op == 'delete' ? 'deleted' : 'committed',
      'head': latest == null ? null : EditableRecordCodec.headJson(latest!),
      'receipt': EditableRecordCodec.receiptJson(receipt),
    };
    replies[requestId] = reply;
    if (loseAck) {
      loseAck = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return transport.jsonReply(reply);
  }
}

Future<void> withEvidenceRepository(
  Future<void> Function(repository.Context, EvidenceServer) body,
) => repository.run((ctx) async {
  await ctx.login();
  final server = EvidenceServer();
  ctx.remote.close();
  ctx.remote = transport.service(ctx.lifecycle, server.respond);
  var sequence = 60;
  ctx.repository = EditableTripRepository(
    store: ctx.disk.store,
    lifecycle: ctx.lifecycle,
    service: ctx.remote,
    newId: () =>
        '00000000-0000-4000-8000-${(sequence++).toString().padLeft(12, '0')}',
  );
  await body(ctx, server);
});

TripEvidenceEnvelope evidenceFixture() => TripEvidenceCodec.decode(
  (jsonDecode(
        File('test/fixtures/trip_evidence_persistence_vectors.json')
            .readAsStringSync(),
      ) as Map)['canonicalText']
      as String,
);
Map<String, Object?> evidenceHeadJson({
  int version = 1,
  String owner = records.ownerA,
}) {
  final text = TripEvidenceCodec.encode(evidenceFixture());
  return {
    'tripId': records.tripId,
    'ownerId': owner,
    'version': version,
    'payloadText': text,
    'contentDigest': EditableTripCodec.digestText(text),
    'fetchedAt': '2026-10-27T00:00:00.000Z',
  };
}

EditablePendingAttempt evidenceAttempt() {
  final payload = TripEvidenceCodec.encode(evidenceFixture());
  final request = EditableTripCodec.canonicalJson({
    'payloadText': payload,
    'contentDigest': EditableTripCodec.digestText(payload),
    'sourceBinding': null,
  });
  return EditablePendingAttempt(
    payloadKind: 'evidence_v1',
    requestId: records.requestId,
    ownerId: records.ownerA,
    operation: 'create',
    requestText: request,
    requestDigest: EditableTripCodec.digestText(request),
    contentDigest: EditableTripCodec.digestText(payload),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('rejected evidence cleanup is exact staged owner/bytes CAS and preserves committed receipt', () async {
    await withEvidenceRepository((ctx, server) async {
      final attempt = evidenceAttempt();
      final handle = ctx.lifecycle.handle!;
      await ctx.disk.store.stageEditableAttempt(
        handle: handle,
        attempt: attempt,
      );
      final changed = EditableRecordCodec.attempt({
        ...EditableRecordCodec.attemptJson(attempt),
        'requestText': '${attempt.requestText} ',
        'requestDigest': EditableTripCodec.digestText(
          '${attempt.requestText} ',
        ),
      });
      await expectLater(
        ctx.disk.store.discardRejectedEvidenceAttempt(
          handle: handle,
          attempt: changed,
        ),
        throwsA(isA<LocalTripStoreException>()),
      );
      final wrongOwner = EditableRecordCodec.attempt({
        ...EditableRecordCodec.attemptJson(attempt),
        'ownerId': records.ownerB,
      });
      await expectLater(
        Future.sync(
          () => ctx.disk.store.discardRejectedEvidenceAttempt(
            handle: handle,
            attempt: wrongOwner,
          ),
        ),
        throwsA(isA<LocalTripStoreException>()),
      );
      expect(
        (await ctx.disk.store.listEditableAttempts(handle: handle))
            .single
            .attempt
            .requestText,
        attempt.requestText,
      );
      await ctx.disk.store.discardRejectedEvidenceAttempt(
        handle: handle,
        attempt: attempt,
      );
      expect(
        await ctx.disk.store.listEditableAttempts(handle: handle),
        isEmpty,
      );
      final reply = await ctx.repository.saveEvidenceAccount(
        envelope: evidenceFixture(),
        commands: [],
        requestId: records.requestId,
      );
      await expectLater(
        ctx.disk.store.discardRejectedEvidenceAttempt(
          handle: handle,
          attempt: attempt,
        ),
        throwsA(isA<LocalTripStoreException>()),
      );
      expect(
        (await ctx.disk.store.readEditableSnapshot(
          handle: handle,
          tripId: records.tripId,
        ))!.head.contentDigest,
        reply.head!.contentDigest,
      );
    });
  });
  test(
    'evidence head roundtrip preserves complete payload rather than V2 alone',
    () {
      final raw = evidenceHeadJson();
      final head = EditableRecordCodec.head(raw);
      expect(EditableRecordCodec.headJson(head), raw);
      expect(head.document.input.destinationName, 'Phú Yên');
    },
  );
  test(
    'evidence cache survives reopen with owner isolation and tamper rejection',
    () async {
      await stores.runWithStore((ctx) async {
        var handle = await ctx.store.activateSession(
          ownerId: records.ownerA,
          coordinatorEpoch: 1,
        );
        final head = EditableRecordCodec.head(evidenceHeadJson());
        await ctx.store.putEditableSnapshot(handle: handle, head: head);
        await records.reopen(ctx);
        handle = await ctx.store.activateSession(
          ownerId: records.ownerA,
          coordinatorEpoch: 2,
        );
        expect(
          (await ctx.store.readEditableSnapshot(
            handle: handle,
            tripId: records.tripId,
          ))!.head.payloadText,
          head.payloadText,
        );
        final other = await ctx.store.activateSession(
          ownerId: records.ownerB,
          coordinatorEpoch: 3,
        );
        expect(
          await ctx.store.readEditableSnapshot(
            handle: other,
            tripId: records.tripId,
          ),
          isNull,
        );
        await expectLater(
          ctx.store.putEditableSnapshot(handle: other, head: head),
          throwsA(isA<LocalTripStoreException>()),
        );
      });
    },
  );
  test(
    'evidence create read source-only update and delete use typed endpoints',
    () async {
      await withEvidenceRepository((ctx, server) async {
        final first = await ctx.repository.saveEvidenceAccount(
          envelope: evidenceFixture(),
          commands: [],
          requestId: records.requestId,
        );
        expect(
          first.head!.evidenceEnvelope!.evidence.single.origin,
          EvidenceOrigin.user,
        );
        final page = await ctx.repository.listOwned();
        expect(page.items.single.kind, OwnedTripKind.evidenceV1);
        final view = await ctx.repository.readTrip(
          records.tripId,
          kind: OwnedTripKind.evidenceV1,
        );
        final raw = jsonDecode(view.head!.payloadText) as Map<String, Object?>;
        ((raw['claims'] as List).first as Map)['text'] = 'Changed explanation';
        final changed = TripEvidenceEnvelope.fromJson(raw);
        final second = await ctx.repository.saveEvidenceAccount(
          envelope: changed,
          commands: [],
          base: first.head,
          requestId: records.draftId,
        );
        expect(second.head!.version, 2);
        expect(second.head!.contentDigest, isNot(first.head!.contentDigest));
        expect(
          EditableTripCodec.encode(second.head!.document),
          EditableTripCodec.encode(first.head!.document),
        );
        await ctx.repository.deleteTrip(second.head!);
        expect(server.deletes, 1);
        expect(server.latest, isNull);
        expect(
          server.calls.where((p) => p.endsWith('_editable_trip_v2')),
          isEmpty,
        );
      });
    },
  );
  test(
    'lost ACK retry uses frozen envelope even after candidate changes',
    () async {
      await withEvidenceRepository((ctx, server) async {
        server.loseAck = true;
        await expectLater(
          ctx.repository.saveEvidenceAccount(
            envelope: evidenceFixture(),
            commands: [],
            requestId: records.requestId,
          ),
          transport.failure(EditableRemoteFailure.uncertain),
        );
        final pending = await ctx.disk.store.listEditableAttempts(
          handle: ctx.lifecycle.handle!,
        );
        expect(pending.single.attempt.payloadKind, 'evidence_v1');
        final frozen = pending.single.attempt.requestText;
        final reply = await ctx.repository.retryPending(records.requestId);
        expect(reply.head!.payloadText, evidenceHeadJson()['payloadText']);
        expect(server.creates, 1);
        expect(
          (jsonDecode(frozen) as Map)['payloadText'],
          reply.head!.payloadText,
        );
      });
    },
  );
  test('unsupported evidence never invokes V2 write', () async {
    await withEvidenceRepository((ctx, server) async {
      server.supported = false;
      await expectLater(
        ctx.repository.saveEvidenceAccount(
          envelope: evidenceFixture(),
          commands: [],
        ),
        transport.failure(EditableRemoteFailure.deploymentBlocked),
      );
      expect(server.creates, 0);
      expect(server.calls, ['get_trip_capabilities_v1']);
    });
  });
}
