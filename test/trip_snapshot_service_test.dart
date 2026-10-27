import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/trip_snapshot_service.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';

import 'local_account_lifecycle_test.dart' as lifecycle_fixtures;
import 'local_trip_store_test.dart' as store_fixtures;

const owner = lifecycle_fixtures.ownerA;
const trip = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

class _OneTripService extends TripsService {
  final SavedTrip trip;
  _OneTripService(this.trip);
  @override
  Future<List<SavedTrip>> fetchTrips(String userId) async => [trip];
}

class _ReplyAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  _ReplyAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

Map<String, dynamic> _receipt(String digest) => {
  'deviceScope': 'device-1',
  'targetOwner': owner,
  'draftId': 'draft-1',
  'sourceRevision': 1,
  'requestKey': 'request-1',
  'contentDigest': digest,
  'receiptId': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'tripId': trip,
  'remoteVersion': 1,
  'committedAt': '2026-10-13T00:00:00.000Z',
};

Future<void> _withProof(
  Future<void> Function(AccountSessionProof, LocalAccountLifecycleService) body,
) async {
  await store_fixtures.runWithStore((ctx) async {
    final session = lifecycle_fixtures.sessionFor(owner);
    final lifecycle = LocalAccountLifecycleService(
      storeLoader: () async => ctx.store,
      sessionReader: () => session,
      registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
    );
    try {
      expect(
        await lifecycle.establishAccount(freshAuthentication: true),
        isNotNull,
      );
      await body(lifecycle.captureProof(), lifecycle);
    } finally {
      await lifecycle.close();
    }
  });
}

TripSnapshotService _service(
  LocalAccountLifecycleService lifecycle,
  Future<ResponseBody> Function(RequestOptions) reply,
) => TripSnapshotService(
  projectUrl: 'https://staging.example.test',
  publicKey: 'synthetic-public',
  isCurrentProof: lifecycle.isCurrentProof,
  adapter: _ReplyAdapter(reply),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'exact legacy fetch does not enumerate or decode unrelated V2 rows',
    () async {
      await _withProof((proof, lifecycle) async {
        final payload = store_fixtures.createValidPayload();
        final ids = <String>[];
        final service = _service(lifecycle, (options) async {
          if (options.method == 'POST') {
            return _json({
              'status': 'unavailable',
              'receipt': null,
              'payloadText': null,
            });
          }
          final id = options.uri.queryParameters['id'];
          ids.add(id!);
          expect(id, 'eq.$trip');
          return _json([
            {
              'id': trip,
              'user_id': owner,
              'canonical_payload_text': null,
              'ai_plan_data': jsonDecode(TripPayloadCodec.encode(payload)),
            },
          ]);
        });
        try {
          final batch = await service.fetchLegacySnapshots(
            proof: proof,
            tripIds: [trip],
          );
          expect(batch.snapshots.single.tripId, trip);
          expect(ids, ['eq.$trip']);
          expect(batch.complete, isFalse);
          await expectLater(
            service.fetchLegacySnapshots(proof: proof, tripIds: [trip, trip]),
            throwsA(isA<SnapshotRejectedException>()),
          );
        } finally {
          service.close();
        }
      });
    },
  );

  test(
    'legacy row preserves missing headers and has no invented version',
    () async {
      await _withProof((proof, lifecycle) async {
        final payload = store_fixtures.createValidPayload();
        final snapshotService = _service(lifecycle, (options) async {
          expect(options.method, 'GET');
          expect(options.uri.path, '/rest/v1/trips');
          expect(options.uri.queryParameters['user_id'], 'eq.$owner');
          expect(
            options.headers['Authorization'],
            'Bearer ${proof.accessToken}',
          );
          return _json([
            {
              'id': trip,
              'user_id': owner,
              'title': 'Đà Nẵng',
              'destination_name': 'Đà Nẵng',
              'ai_plan_data': jsonDecode(TripPayloadCodec.encode(payload)),
              'canonical_payload_text': null,
              'num_days': null,
              'budget_total': null,
              'created_at': null,
            },
          ]);
        });
        try {
          final batch = await snapshotService.fetchSnapshots(proof: proof);
          expect(batch.complete, isFalse);
          expect(batch.snapshots, hasLength(1));
          expect(batch.snapshots.single.remoteVersion, isNull);
          expect(batch.snapshots.single.headers.numDays, isNull);
          expect(batch.snapshots.single.headers.budgetTotal, isNull);
          expect(batch.snapshots.single.headers.createdAt, isNull);
          expect(batch.snapshots.single.payload.plan, isNotNull);
        } finally {
          snapshotService.close();
        }
      });
    },
  );

  test(
    'B3 receipt binds owner/trip/version to exact canonical bytes',
    () async {
      await _withProof((proof, lifecycle) async {
        final payload = store_fixtures.createValidPayload(includePlan: false);
        final text = TripPayloadCodec.encode(payload);
        final digest = TripPayloadCodec.computeDigest(payload);
        final snapshotService = _service(lifecycle, (options) async {
          expect(options.method, 'POST');
          expect(options.uri.path, '/rest/v1/rpc/get_import_trip_snapshot_v1');
          expect(
            options.headers['Authorization'],
            'Bearer ${proof.accessToken}',
          );
          return _json({
            'status': 'committed',
            'receipt': _receipt(digest),
            'payloadText': text,
          });
        });
        try {
          final result = await snapshotService.readImportedSnapshot(
            proof: proof,
            tripId: trip,
          );
          expect(result.status, SnapshotLookupStatus.ready);
          expect(result.snapshot?.remoteVersion, 1);
          expect(result.snapshot?.payload.request, isNotNull);
          expect(result.snapshot?.payload.plan, isNull);
        } finally {
          snapshotService.close();
        }
      });
    },
  );

  test('list verifies imported row through receipt RPC', () async {
    await _withProof((proof, lifecycle) async {
      final payload = store_fixtures.createValidPayload(includePlan: false);
      final text = TripPayloadCodec.encode(payload);
      final digest = TripPayloadCodec.computeDigest(payload);
      var calls = 0;
      final snapshotService = _service(lifecycle, (options) async {
        calls++;
        if (options.method == 'GET') {
          return _json([
            {
              'id': trip,
              'user_id': owner,
              'title': 'Đà Nẵng',
              'destination_name': 'Đà Nẵng',
              'num_days': 3,
              'budget_total': 5000000,
              'created_at': '2026-10-13T00:00:00Z',
              'canonical_payload_text': text,
            },
          ]);
        }
        expect(options.uri.path, '/rest/v1/rpc/get_import_trip_snapshot_v1');
        return _json({
          'status': 'committed',
          'receipt': _receipt(digest),
          'payloadText': text,
        });
      });
      try {
        final batch = await snapshotService.fetchSnapshots(proof: proof);
        expect(calls, 2);
        expect(batch.snapshots.single.remoteVersion, 1);
        expect(batch.snapshots.single.headers.numDays, 3);
        expect(batch.snapshots.single.payload.plan, isNull);
      } finally {
        snapshotService.close();
      }
    });
  });

  test('owned lookup uses legacy row after unavailable receipt', () async {
    await _withProof((proof, lifecycle) async {
      final payload = store_fixtures.createValidPayload();
      var calls = 0;
      final snapshotService = _service(lifecycle, (options) async {
        calls++;
        if (options.method == 'POST') {
          return _json({
            'status': 'unavailable',
            'receipt': null,
            'payloadText': null,
          });
        }
        expect(options.uri.queryParameters['id'], 'eq.$trip');
        return _json([
          {
            'id': trip,
            'user_id': owner,
            'ai_plan_data': jsonDecode(TripPayloadCodec.encode(payload)),
          },
        ]);
      });
      try {
        final result = await snapshotService.readOwnedSnapshot(
          proof: proof,
          tripId: trip,
        );
        expect(calls, 2);
        expect(result.status, SnapshotLookupStatus.ready);
        expect(result.snapshot?.remoteVersion, isNull);
      } finally {
        snapshotService.close();
      }
    });
  });

  test(
    'bad digest and missing RPC fail without a fabricated snapshot',
    () async {
      await _withProof((proof, lifecycle) async {
        final payload = store_fixtures.createValidPayload();
        final text = TripPayloadCodec.encode(payload);
        final bad = _service(
          lifecycle,
          (_) async => _json({
            'status': 'committed',
            'receipt': _receipt(List.filled(64, '0').join()),
            'payloadText': text,
          }),
        );
        final missing = _service(
          lifecycle,
          (_) async => _json({'code': 'PGRST202'}, 404),
        );
        try {
          expect(
            (await bad.readImportedSnapshot(proof: proof, tripId: trip)).status,
            SnapshotLookupStatus.rejected,
          );
          expect(
            (await missing.readImportedSnapshot(
              proof: proof,
              tripId: trip,
            )).status,
            SnapshotLookupStatus.deploymentBlocked,
          );
        } finally {
          bad.close();
          missing.close();
        }
      });
    },
  );

  test(
    'owner invalidation during transport discards late list response',
    () async {
      await _withProof((proof, lifecycle) async {
        final snapshotService = _service(lifecycle, (_) async {
          lifecycle.invalidateAccountContext();
          return _json([]);
        });
        try {
          await expectLater(
            snapshotService.fetchSnapshots(proof: proof),
            throwsStateError,
          );
        } finally {
          snapshotService.close();
        }
      });
    },
  );

  testWidgets('saved card labels absent day, budget, and time honestly', (
    tester,
  ) async {
    final auth = AuthProvider()
      ..simulateSupabaseUser(
        User(
          id: owner,
          email: 'person@example.test',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-10-13T00:00:00Z',
        ),
      );
    final saved = SavedTripsProvider(
      service: _OneTripService(
        const SavedTrip(
          id: trip,
          userId: owner,
          title: 'Chuyến đi cũ',
          destinationName: 'Đà Nẵng',
          tripPlanData: {},
        ),
      ),
    );
    try {
      await saved.loadTrips(owner);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: saved),
          ],
          child: const MaterialApp(home: MyTripsScreen()),
        ),
      );
      expect(find.text('Chưa có số ngày'), findsOneWidget);
      expect(find.text('Chưa có ngân sách'), findsOneWidget);
      expect(find.text('Chưa có thời điểm lưu'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      saved.dispose();
      auth.dispose();
    }
  });
}
