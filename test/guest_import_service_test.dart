import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/guest_import_service.dart';

import 'local_trip_store_test.dart' as fixtures;

const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

Session fakeSession(String owner) => Session.fromJson({
  'access_token': 'fake-$owner',
  'refresh_token': 'fake-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  'user': {
    'id': owner,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-10-13T00:00:00Z',
  },
})!..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

ImportSource sourceOf(GuestDraftRevisionRecord row) => ImportSource(
  deviceScope: row.deviceScope,
  draftId: row.draftId,
  revision: row.revision,
  digest: row.digest,
);

class FakeImportTransport implements GuestImportTransport {
  final calls = <Map<String, dynamic>>[];
  final owners = <String>[];
  final tokens = <String>[];
  final remote = <String, Map<String, dynamic>>{};
  bool loseReply = false;
  bool deleted = false;
  Completer<void>? entered;
  Completer<void>? release;
  Future<void> Function()? beforeReply;
  Map<String, dynamic> Function(Map<String, dynamic>)? mutate;

  @override
  Future<dynamic> importDraft({
    required GuestImportCredentials credentials,
    required Map<String, dynamic> parameters,
  }) async {
    calls.add(Map.of(parameters));
    owners.add(credentials.ownerId);
    tokens.add(credentials.accessToken);
    entered?.complete();
    await release?.future;
    final key = '${credentials.ownerId}/${parameters['p_request_key']}';
    final result = remote.putIfAbsent(
      key,
      () => {
        'status': 'committed',
        'payloadText': parameters['p_payload_text'],
        'receipt': {
          'deviceScope': parameters['p_device_scope'],
          'targetOwner': credentials.ownerId,
          'draftId': parameters['p_draft_id'],
          'sourceRevision': parameters['p_source_revision'],
          'requestKey': parameters['p_request_key'],
          'contentDigest': parameters['p_content_digest'],
          'receiptId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'tripId': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          'remoteVersion': 1,
          'committedAt': '2026-10-13T10:00:00.123Z',
        },
      },
    );
    await beforeReply?.call();
    if (loseReply) throw TimeoutException('Simulated lost reply');
    final copy = jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
    if (deleted) {
      copy['status'] = 'deleted';
      copy['payloadText'] = null;
    }
    return mutate?.call(copy) ?? copy;
  }
}

class CallbackAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  CallbackAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

class ServiceHarness {
  final fixtures.TestStoreContext ctx;
  Session? session = fakeSession(ownerA);
  final FakeImportTransport transport = FakeImportTransport();
  late GuestImportService service;
  late SessionHandle handle;

  ServiceHarness(this.ctx);

  Future<void> bind([String owner = ownerA]) async {
    session = fakeSession(owner);
    handle = await ctx.store.activateSession(
      ownerId: owner,
      coordinatorEpoch: 1,
    );
    service = GuestImportService(
      store: ctx.store,
      auth: GuestImportAuthContext(() => session),
      transport: transport,
      requestKeyFactory: () => 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    );
    service.bindSession(handle);
  }

  Future<ImportSource> save([String id = 'draft']) async => sourceOf(
    await ctx.store.saveDraftRevision(
      draftId: id,
      payload: fixtures.createValidPayload(includePlan: false, title: 'Huế 😀'),
    ),
  );

  Future<GuestImportOutcome> import(ImportSource source) async =>
      (await service.importConfirmed(service.confirmSelection([source])))
          .single;
}

void main() {
  sqfliteFfiInit();
  test('G01 blocked cleanup namespace rejects journal inventory', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      await ctx.store.rawDb.insert('local_cleanup_state', {
        'namespace': 'account:$ownerA',
        'is_blocked': 1,
        'purge_pending': 1,
        'reason': 'test',
        'created_at': '2026-10-13T00:00:00Z',
        'updated_at': '2026-10-13T00:00:00Z',
      });
      await expectLater(
        ctx.store.listImportJournals(handle: h.handle),
        throwsA(isA<AccountNamespaceBlockedException>()),
      );
    });
  });
  for (final corruption in ['receipt', 'timestamp']) {
    test('G01 checked inventory rejects corrupted $corruption', () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        await h.import(source);
        expect(
          (await ctx.store.listImportJournals(handle: h.handle))
              .single
              .cachedReceipt,
          isNotNull,
        );
        await ctx.store.rawDb.update(
          'local_import_journal',
          corruption == 'receipt'
              ? {'receipt_payload': '{"unexpected":true}'}
              : {'updated_at': 'invalid'},
        );
        await expectLater(
          ctx.store.listImportJournals(handle: h.handle),
          throwsA(isA<CorruptDatabaseException>()),
        );
      });
    });
  }
  test(
    'G07 exactly 1 MiB UTF-8 payload is accepted without truncation',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final raw = jsonDecode(
          TripPayloadCodec.encode(
            fixtures.createValidPayload(includePlan: false, title: 'x'),
          ),
        ) as Map<String, dynamic>;
        final before = TripPayloadCodec.encode(TripPayloadCodec.decode(raw));
        (raw['metadata'] as Map)['title'] =
            'x' * (1048576 - utf8.encode(before).length + 1);
        final source = sourceOf(
          await ctx.store.saveDraftRevision(
            draftId: 'draft',
            payload: TripPayloadCodec.decode(raw),
          ),
        );
        expect((await h.import(source)).status, GuestImportStatus.committed);
        expect(
          utf8
              .encode(h.transport.calls.single['p_payload_text'] as String)
              .length,
          1048576,
        );
      });
    },
  );
  test('G07 metadata dates, fallback and explicit Pareto false survive exact bytes', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final raw = jsonDecode(
        TripPayloadCodec.encode(fixtures.createValidPayload()),
      ) as Map<String, dynamic>;
      (raw['metadata'] as Map).addAll(<String, dynamic>{
        'startDate': '2026-12-01',
        'endDate': '2026-12-03',
      });
      ((raw['plan'] as Map)['dataSources'] as Map)['mode'] = 'offline fallback';
      (((raw['plan'] as Map)['transportOptions'] as List).first
              as Map)['paretoOptimal'] =
          false;
      final record = await ctx.store.saveDraftRevision(
        draftId: 'draft',
        payload: TripPayloadCodec.decode(raw),
      );
      final result = await h.import(sourceOf(record));
      expect(result.status, GuestImportStatus.committed);
      expect(result.result!.snapshot.payloadJson, record.payloadJson);
      expect(result.result!.snapshot.cachedPayload.plan!.isFallback, true);
      expect(
        result
            .result!
            .snapshot
            .cachedPayload
            .plan!
            .transportOptions
            .first
            .isParetoOptimal,
        false,
      );
      expect(result.result!.snapshot.startDate, '2026-12-01');
    });
  });
  test(
    'G07 identity and request-key limits reject overflow before dispatch',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save('界' * 128);
        h.service = GuestImportService(
          store: ctx.store,
          auth: GuestImportAuthContext(() => h.session),
          transport: h.transport,
          requestKeyFactory: () => 'k' * 256,
        );
        h.service.bindSession(h.handle);
        expect((await h.import(source)).status, GuestImportStatus.committed);
        final overflow = await h.save('x' * 129);
        expect(() => h.service.confirmSelection([overflow]), throwsA(anything));
        final another = await h.save('another');
        h.service = GuestImportService(
          store: ctx.store,
          auth: GuestImportAuthContext(() => h.session),
          transport: h.transport,
          requestKeyFactory: () => 'k' * 257,
        );
        h.service.bindSession(h.handle);
        expect((await h.import(another)).status, GuestImportStatus.rejected);
        expect(h.transport.calls.length, 1);
      });
    },
  );
  test('G05 partial batch failure records individual outcomes and preserves failed source', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final a = await h.save('one');
      final b = await h.save('two');
      var key = 0;
      h.service = GuestImportService(
        store: ctx.store,
        auth: GuestImportAuthContext(() => h.session),
        transport: h.transport,
        requestKeyFactory: () => 'batch-${key++}',
      );
      h.service.bindSession(h.handle);
      h.transport.beforeReply = () async {
        if (h.transport.calls.length == 2) throw TimeoutException('drop');
      };
      final result = await h.service.importConfirmed(
        h.service.confirmSelection([a, b]),
      );
      expect(result.map((r) => r.status), [
        GuestImportStatus.committed,
        GuestImportStatus.pendingRetry,
      ]);
      expect(
        await ctx.store.getDraftRevision(draftId: 'one', revision: 1),
        isNull,
      );
      expect(
        await ctx.store.getDraftRevision(draftId: 'two', revision: 1),
        isNotNull,
      );
    });
  });
  test('G09 real Dio path pins bearer A and discards reply after auth switches to B', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final source = await h.save();
      final transport = DioGuestImportTransport(
        projectUrl: 'https://staging.example.test',
        publicKey: 'fake-public',
        adapter: CallbackAdapter((options) async {
          expect(options.headers['Authorization'], 'Bearer fake-$ownerA');
          h.session = fakeSession(ownerB);
          final reply = await h.transport.importDraft(
            credentials: GuestImportCredentials(
              ownerId: ownerA,
              accessToken: 'fake-$ownerA',
              expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            ),
            parameters: Map<String, dynamic>.from(options.data as Map),
          );
          return ResponseBody.fromString(
            jsonEncode(reply),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }),
      );
      addTearDown(transport.close);
      h.service = GuestImportService(
        store: ctx.store,
        auth: GuestImportAuthContext(() => h.session),
        transport: transport,
      );
      h.service.bindSession(h.handle);
      expect(
        (await h.import(source)).status,
        GuestImportStatus.sessionInvalidated,
      );
      expect(
        await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
        isNotNull,
      );
    });
  });
  test('G09 partial batch hides prior account results when second reply invalidates session', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final a = await h.save('one');
      final b = await h.save('two');
      var key = 0;
      h.service = GuestImportService(
        store: ctx.store,
        auth: GuestImportAuthContext(() => h.session),
        transport: h.transport,
        requestKeyFactory: () => 'key-${key++}',
      );
      h.service.bindSession(h.handle);
      h.transport.beforeReply = () async {
        if (h.transport.calls.length == 2) {
          h.session = fakeSession(ownerB);
        }
      };
      final results = await h.service.importConfirmed(
        h.service.confirmSelection([a, b]),
      );
      expect(results.every((r) => r.result == null), isTrue);
      expect(results.last.status, GuestImportStatus.sessionInvalidated);
    });
  });
  for (final change in ['size', 'array', 'object', 'days', 'people', 'money']) {
    test(
      'G07 preflight rejects $change above B3 bound without dispatch',
      () async {
        await fixtures.runWithStore((ctx) async {
          final h = ServiceHarness(ctx);
          await h.bind();
          final raw = jsonDecode(
            TripPayloadCodec.encode(fixtures.createValidPayload()),
          ) as Map<String, dynamic>;
          switch (change) {
            case 'size':
              (raw['metadata'] as Map)['title'] = '界' * 350000;
            case 'array':
              (raw['request'] as Map)['preferences'] = List.filled(1001, 'x');
            case 'object':
              (raw['plan'] as Map)['dataSources'] = {
                for (var i = 0; i < 257; i++) '$i': 'x',
              };
            case 'days':
              (raw['request'] as Map)['numDays'] = 2147483648;
            case 'people':
              (raw['request'] as Map)['numPeople'] = 2147483648;
            case 'money':
              (raw['request'] as Map)['budgetVnd'] = 9007199254740992;
          }
          final source = sourceOf(
            await ctx.store.saveDraftRevision(
              draftId: 'draft',
              payload: TripPayloadCodec.decode(raw),
            ),
          );
          expect((await h.import(source)).status, GuestImportStatus.rejected);
          expect(h.transport.calls, isEmpty);
          expect(
            await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
            isNotNull,
          );
        });
      },
    );
  }
  test(
    'G02/G07 plan-only and exact boundary values keep canonical bytes',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final full = fixtures.createValidPayload();
        final payload = CanonicalTripPayloadV1(
          metadata: full.metadata,
          request: null,
          plan: full.plan,
        );
        final source = sourceOf(
          await ctx.store.saveDraftRevision(draftId: 'draft', payload: payload),
        );
        expect((await h.import(source)).status, GuestImportStatus.committed);
        expect(
          jsonDecode(
            h.transport.calls.single['p_payload_text'] as String,
          )['request'],
          isNull,
        );
      });
    },
  );
  test('G07 B3 request numeric and array maxima are accepted', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final raw = jsonDecode(
        TripPayloadCodec.encode(
          fixtures.createValidPayload(includePlan: false),
        ),
      ) as Map<String, dynamic>;
      (raw['request'] as Map).addAll(<String, dynamic>{
        'numDays': 2147483647,
        'numPeople': 2147483647,
        'budgetVnd': 9007199254740991,
        'preferences': List.filled(1000, 'x'),
      });
      final source = sourceOf(
        await ctx.store.saveDraftRevision(
          draftId: 'draft',
          payload: TripPayloadCodec.decode(raw),
        ),
      );
      expect((await h.import(source)).status, GuestImportStatus.committed);
    });
  });
  test(
    'G01 inventory guards stale/demo/blocked and checked corrupted source',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        await ctx.store.prepareImportJournal(
          handle: h.handle,
          draftId: source.draftId,
          sourceRevision: source.revision,
          requestKey: 'key',
        );
        await ctx.store.rawDb.update('guest_draft_revisions', {
          'digest': '0' * 64,
        });
        await expectLater(
          ctx.store.listImportJournals(handle: h.handle),
          throwsA(isA<CorruptDatabaseException>()),
        );
        ctx.store.unbindSession();
        await expectLater(
          ctx.store.listImportJournals(handle: h.handle),
          throwsA(isA<StaleSessionEpochException>()),
        );
        final demo = SessionHandle(
          ownerId: ownerA,
          coordinatorEpoch: 1,
          storeGeneration: 1,
          isDemoSession: true,
        );
        await expectLater(
          ctx.store.listImportJournals(handle: demo),
          throwsA(isA<UnauthorizedAccountAccessException>()),
        );
      });
    },
  );
  test('G03 preparation failure does not dispatch; invalid digest cannot pin draft', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final source = await h.save();
      final wrong = ImportSource(
        deviceScope: source.deviceScope,
        draftId: source.draftId,
        revision: 1,
        digest: '0' * 64,
      );
      expect((await h.import(wrong)).status, GuestImportStatus.rejected);
      expect(h.transport.calls, isEmpty);
      expect(await ctx.store.listImportJournals(handle: h.handle), isEmpty);
      ctx.store.onAccountOpStepForTesting = (step) async {
        if (step == 'before_commit') throw StateError('prepare fault');
      };
      expect((await h.import(source)).status, GuestImportStatus.rejected);
      expect(h.transport.calls, isEmpty);
    });
  });
  test('G09 account switch before dispatch sends nothing', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final source = await h.save();
      final confirmation = h.service.confirmSelection([source]);
      h.session = fakeSession(ownerB);
      expect(
        (await h.service.importConfirmed(confirmation)).single.status,
        GuestImportStatus.sessionInvalidated,
      );
      expect(h.transport.calls, isEmpty);
    });
  });
  test('G09 account invalidation inside ack rolls back and permits same-owner retry', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final source = await h.save();
      ctx.store.onAckStepForTesting = (step) async {
        if (step == 'after_snapshot_upsert') ctx.store.unbindSession();
      };
      expect(
        (await h.import(source)).status,
        GuestImportStatus.sessionInvalidated,
      );
      expect(
        await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
        isNotNull,
      );
      ctx.store.onAckStepForTesting = null;
      await h.bind();
      expect(
        (await h.service.retry(source)).status,
        GuestImportStatus.committed,
      );
    });
  });
  for (final httpStatus in [401, 409, 404, 500]) {
    test(
      'HTTP $httpStatus sanitized outcome retains draft and never falls back',
      () async {
        await fixtures.runWithStore((ctx) async {
          final h = ServiceHarness(ctx);
          await h.bind();
          final source = await h.save();
          final transport = DioGuestImportTransport(
            projectUrl: 'https://staging.example.test',
            publicKey: 'fake-public',
            adapter: CallbackAdapter((options) async {
              expect(options.headers['Authorization'], 'Bearer fake-$ownerA');
              expect(options.followRedirects, false);
              expect(options.uri.path, '/rest/v1/rpc/import_guest_draft_v1');
              return ResponseBody.fromString(
                jsonEncode({
                  'message': 'private token/payload must not escape',
                }),
                httpStatus,
                headers: {
                  Headers.contentTypeHeader: ['application/json'],
                },
              );
            }),
          );
          addTearDown(transport.close);
          h.service = GuestImportService(
            store: ctx.store,
            auth: GuestImportAuthContext(() => h.session),
            transport: transport,
          );
          h.service.bindSession(h.handle);
          final result = await h.import(source);
          expect(
            result.status,
            httpStatus == 404
                ? GuestImportStatus.deploymentBlocked
                : httpStatus == 500
                ? GuestImportStatus.pendingRetry
                : GuestImportStatus.rejected,
          );
          expect(result.reason, isNot(contains('private')));
          expect(
            await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
            isNotNull,
          );
        });
      },
    );
  }
  test(
    'G01 inventory discovers old pending revision after edit and reopen',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final first = await h.save();
        await ctx.store.prepareImportJournal(
          handle: h.handle,
          draftId: first.draftId,
          sourceRevision: first.revision,
          requestKey: 'key',
        );
        await h.save();
        await ctx.store.close();
        await ctx.store.open();
        await h.bind();
        expect(
          (await ctx.store.listImportJournals(handle: h.handle))
              .single
              .sourceRevision,
          1,
        );
        await h.bind(ownerB);
        expect(await ctx.store.listImportJournals(handle: h.handle), isEmpty);
      });
    },
  );

  test(
    'G02/G03 exact input-only source persisted pending before dispatch',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        final original = await ctx.store.getDraftRevision(
          draftId: 'draft',
          revision: 1,
        );
        h.transport.beforeReply = () async {
          expect(
            (await ctx.store.getJournalEntry(
              handle: h.handle,
              draftId: 'draft',
              sourceRevision: 1,
            ))!.state,
            'pending_ack',
          );
        };
        expect((await h.import(source)).status, GuestImportStatus.committed);
        expect(
          h.transport.calls.single['p_payload_text'],
          original!.payloadJson,
        );
        expect(
          await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
          isNull,
        );
        expect(
          (await ctx.store.getSnapshot(
            handle: h.handle,
            tripId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          ))!.cachedPayload.plan,
          isNull,
        );
      });
    },
  );

  test(
    'G04 lost response retry survives reopen with identical six arguments',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        h.transport.loseReply = true;
        expect((await h.import(source)).status, GuestImportStatus.pendingRetry);
        expect(
          await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
          isNotNull,
        );
        h.service.dispose();
        await ctx.store.close();
        await ctx.store.open();
        await h.bind();
        h.transport.loseReply = false;
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.committed,
        );
        expect(h.transport.calls[1], h.transport.calls[0]);
        expect(h.transport.remote.length, 1);
      });
    },
  );

  test('G05 double tap single-flight sends once', () async {
    await fixtures.runWithStore((ctx) async {
      final h = ServiceHarness(ctx);
      await h.bind();
      final source = await h.save();
      h.transport.entered = Completer();
      h.transport.release = Completer();
      final confirmation = h.service.confirmSelection([source]);
      final first = h.service.importConfirmed(confirmation);
      await h.transport.entered!.future;
      final second = h.service.importConfirmed(confirmation);
      h.transport.release!.complete();
      expect((await first).single.status, GuestImportStatus.committed);
      expect((await second).single.status, GuestImportStatus.committed);
      expect(h.transport.calls.length, 1);
    });
  });

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'envelope extra': (r) => r['extra'] = true,
    'envelope missing': (r) => r.remove('receipt'),
    'unavailable': (r) => r['status'] = 'unavailable',
    'receipt extra': (r) => (r['receipt'] as Map)['extra'] = true,
    'owner': (r) => (r['receipt'] as Map)['targetOwner'] = ownerB,
    'scope': (r) => (r['receipt'] as Map)['deviceScope'] = 'other',
    'draft': (r) => (r['receipt'] as Map)['draftId'] = 'other',
    'revision': (r) => (r['receipt'] as Map)['sourceRevision'] = 2,
    'fractional revision': (r) => (r['receipt'] as Map)['sourceRevision'] = 1.0,
    'key': (r) => (r['receipt'] as Map)['requestKey'] = 'other',
    'digest': (r) => (r['receipt'] as Map)['contentDigest'] = '0' * 64,
    'version': (r) => (r['receipt'] as Map)['remoteVersion'] = 2,
    'trip uuid': (r) => (r['receipt'] as Map)['tripId'] = 'bad',
    'receipt uuid': (r) => (r['receipt'] as Map)['receiptId'] = 'bad',
    'timestamp': (r) =>
        (r['receipt'] as Map)['committedAt'] = '2026-10-13T10:00:00+00:00',
    'null text': (r) => r['payloadText'] = null,
    'format changed': (r) => r['payloadText'] = ' ${r['payloadText']}',
    'deleted with text': (r) => r['status'] = 'deleted',
  };
  for (final mutation in mutations.entries) {
    test('G06/G07 reject ${mutation.key} without consuming source', () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        h.transport.mutate = (r) {
          mutation.value(r);
          return r;
        };
        expect((await h.import(source)).status, GuestImportStatus.rejected);
        expect(
          await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
          isNotNull,
        );
        expect(await ctx.store.listSnapshots(handle: h.handle), isEmpty);
      });
    });
  }
  for (final step in [
    'after_journal_update',
    'after_snapshot_upsert',
    'after_pointer_null',
    'after_source_delete',
  ]) {
    test('G08 local ack rollback $step then same-key retry', () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        ctx.store.onAckStepForTesting = (current) async {
          if (current == step) throw StateError('fault');
        };
        expect((await h.import(source)).status, GuestImportStatus.pendingRetry);
        expect(
          await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
          isNotNull,
        );
        expect(await ctx.store.listSnapshots(handle: h.handle), isEmpty);
        ctx.store.onAckStepForTesting = null;
        await ctx.store.close();
        await ctx.store.open();
        await h.bind();
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.committed,
        );
        expect(h.transport.remote.length, 1);
      });
    });
  }
  test(
    'G09 account changes in network wait do not publish or consume',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        h.transport.beforeReply = () async {
          h.session = fakeSession(ownerB);
          ctx.store.unbindSession();
        };
        expect(
          (await h.import(source)).status,
          GuestImportStatus.sessionInvalidated,
        );
        expect(h.transport.owners.single, ownerA);
        expect(
          await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
          isNotNull,
        );
        await h.bind(ownerB);
        expect(await ctx.store.listSnapshots(handle: h.handle), isEmpty);
      });
    },
  );
  test(
    'G10 quarantine A cannot resume by B; explicit A retry succeeds',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        h.transport.loseReply = true;
        await h.import(source);
        await ctx.store.purgeAccountData(
          targetOwnerId: ownerA,
          reason: 'logout',
        );
        await h.bind(ownerB);
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.rejected,
        );
        expect(h.transport.calls.length, 1);
        await h.bind();
        h.transport.loseReply = false;
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.committed,
        );
      });
    },
  );
  test(
    'G11 verified deleted keeps source and pending identity across reopen',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        h.transport.deleted = true;
        expect(
          (await h.import(source)).status,
          GuestImportStatus.deletedNeedsAttention,
        );
        await ctx.store.close();
        await ctx.store.open();
        await h.bind();
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.deletedNeedsAttention,
        );
        expect(
          await ctx.store.getDraftRevision(draftId: 'draft', revision: 1),
          isNotNull,
        );
        expect(await ctx.store.listSnapshots(handle: h.handle), isEmpty);
        expect(h.transport.calls[0], h.transport.calls[1]);
      });
    },
  );
  test(
    'G12 committed retry uses checked stored snapshot without network',
    () async {
      await fixtures.runWithStore((ctx) async {
        final h = ServiceHarness(ctx);
        await h.bind();
        final source = await h.save();
        await h.import(source);
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.alreadyCommitted,
        );
        expect(h.transport.calls.length, 1);
        await ctx.store.rawDb.update('account_trip_snapshots', {
          'digest': '0' * 64,
        });
        expect(
          (await h.service.retry(source)).status,
          GuestImportStatus.rejected,
        );
      });
    },
  );
}
