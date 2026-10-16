import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/trip_snapshot_service.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';

import 'editable_local_store_test.dart' as editable;

import 'local_account_lifecycle_test.dart' as lifecycle_fixtures;
import 'local_trip_store_test.dart' as store_fixtures;

const _ownedTripId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{"message":"unauthorized"}', 401);

  @override
  void close({bool force = false}) {}
}

class _SnapshotFixture extends TripSnapshotService {
  Future<SnapshotFetchBatch> Function(AccountSessionProof)? fetch;
  Future<SnapshotLookup> Function(AccountSessionProof, String)? read;

  _SnapshotFixture(LocalAccountLifecycleService lifecycle)
    : super(
        projectUrl: 'https://staging.example.test',
        publicKey: 'fixture-public',
        isCurrentProof: lifecycle.isCurrentProof,
      );

  @override
  Future<SnapshotFetchBatch> fetchSnapshots({
    required AccountSessionProof proof,
  }) => fetch!(proof);

  @override
  Future<SnapshotLookup> readOwnedSnapshot({
    required AccountSessionProof proof,
    required String tripId,
  }) => read!(proof, tripId);
}

RemoteTripSnapshot _remote(String owner) => RemoteTripSnapshot(
  ownerId: owner,
  tripId: _ownedTripId,
  payload: store_fixtures.createValidPayload(),
  remoteVersion: null,
  fetchedAt: DateTime.now().toUtc(),
  headers: LegacyTripRowContext(
    id: _ownedTripId,
    userId: owner,
    title: 'Đà Nẵng',
    destinationName: 'Đà Nẵng',
  ),
);

class FakeTripsService extends TripsService {
  List<SavedTrip> fakeTrips = [];
  bool shouldFailFetch = false;
  bool shouldFailSave = false;
  bool shouldFailDelete = false;
  int fetchCalls = 0;
  int saveCalls = 0;
  int deleteCalls = 0;
  Completer<List<SavedTrip>>? fetchCompleter;
  Completer<SavedTrip>? saveCompleter;
  Completer<bool>? deleteCompleter;

  @override
  Future<List<SavedTrip>> fetchTrips(String userId) async {
    fetchCalls++;
    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }
    if (shouldFailFetch) {
      throw Exception('Network connection error fetching trips');
    }
    return fakeTrips.where((t) => t.userId == userId).toList();
  }

  @override
  Future<SavedTrip> saveTrip(SavedTrip trip) async {
    saveCalls++;
    if (saveCompleter != null) {
      return saveCompleter!.future;
    }
    if (shouldFailSave) {
      throw Exception('Server rejected insert with 401 unauthorized');
    }
    final saved = SavedTrip(
      id: 'server-gen-id-${DateTime.now().millisecondsSinceEpoch}',
      userId: trip.userId,
      title: trip.title,
      destinationName: trip.destinationName,
      numDays: trip.numDays,
      budgetTotal: trip.budgetTotal,
      startDate: trip.startDate,
      endDate: trip.endDate,
      status: trip.status,
      tripPlanData: trip.tripPlanData,
      createdAt: DateTime.now(),
    );
    fakeTrips.insert(0, saved);
    return saved;
  }

  @override
  Future<bool> deleteTrip({
    required String tripId,
    required String userId,
  }) async {
    deleteCalls++;
    if (deleteCompleter != null) {
      return deleteCompleter!.future;
    }
    if (shouldFailDelete) {
      throw Exception('Delete failed on server');
    }
    fakeTrips.removeWhere((t) => t.id == tripId && t.userId == userId);
    return true;
  }
}

class _MixedRepository extends EditableTripRepository {
  Future<OwnedTripPage> Function(OwnedTripCursor?)? onList;
  Future<EditableTripView> Function(String, bool)? onRead;
  _MixedRepository(LocalTripStore store, LocalAccountLifecycleService lifecycle)
    : super(
        store: store,
        lifecycle: lifecycle,
        service: EditableTripService(
          projectUrl: 'https://staging.example.test',
          publicKey: 'synthetic',
          isCurrentProof: lifecycle.isCurrentProof,
        ),
      );
  @override
  Future<OwnedTripPage> listOwned({OwnedTripCursor? cursor}) => onList!(cursor);
  @override
  Future<EditableTripView> readTrip(String tripId, {bool allowCached = true}) =>
      onRead!(tripId, allowCached);
}

OwnedTripSummary _summary(String id, OwnedTripKind kind) => OwnedTripSummary(
  kind: kind,
  tripId: id,
  ownerId: lifecycle_fixtures.ownerA,
  title: kind == OwnedTripKind.editableV2 ? 'V2 manual' : 'V1 legacy',
  destinationName: 'Huế',
  createdAt: DateTime.utc(2026, 10, 15),
  version: kind == OwnedTripKind.editableV2 ? 1 : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  Future<void> withStrictProvider(
    Future<void> Function(
      SavedTripsProvider provider,
      _SnapshotFixture snapshots,
      LocalAccountLifecycleService lifecycle,
      store_fixtures.TestStoreContext context,
    )
    body,
  ) async {
    await store_fixtures.runWithStore((context) async {
      final session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerA);
      final lifecycle = LocalAccountLifecycleService(
        storeLoader: () async => context.store,
        sessionReader: () => session,
        registryPath: '${context.tempDir.path}/account_cache_lifecycle_v1.json',
      );
      final snapshots = _SnapshotFixture(lifecycle);
      final provider = SavedTripsProvider(requiresLifecycle: true);
      try {
        expect(
          await lifecycle.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        provider.bindAccount(
          lifecycle: lifecycle,
          store: context.store,
          snapshots: snapshots,
          handle: lifecycle.handle!,
        );
        await body(provider, snapshots, lifecycle, context);
      } finally {
        provider.dispose();
        snapshots.close();
        await lifecycle.close();
      }
    });
  }

  test(
    'mixed discriminator list only sends legacy IDs to V1 snapshot decoder',
    () async {
      await withStrictProvider((provider, snapshots, lifecycle, context) async {
        final repo = _MixedRepository(context.store, lifecycle);
        final legacy = _summary(_ownedTripId, OwnedTripKind.legacyV1);
        final v2 = _summary(editable.tripId, OwnedTripKind.editableV2);
        var broadFetches = 0;
        final legacyIds = <String>[];
        snapshots.fetch = (_) async {
          broadFetches++;
          throw StateError('broad decoder forbidden');
        };
        snapshots.read = (proof, id) async {
          legacyIds.add(id);
          expect(id, _ownedTripId);
          return SnapshotLookup(
            SnapshotLookupStatus.ready,
            _remote(proof.ownerId),
          );
        };
        repo.onList = (_) async => OwnedTripPage(items: [legacy, v2]);
        repo.onRead = (id, allow) async {
          expect(id, editable.tripId);
          expect(allow, isFalse);
          return EditableTripView(
            EditableTripViewState.online,
            editable.head(),
          );
        };
        try {
          provider.bindEditableRepository(repo);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.visibleTrips.map((t) => t.kind).toSet(), {
            OwnedTripKind.legacyV1,
            OwnedTripKind.editableV2,
          });
          expect(provider.trips.single.id, _ownedTripId);
          expect(provider.accountSnapshots.single.tripId, _ownedTripId);
          expect(legacyIds, [_ownedTripId]);
          expect(broadFetches, 0);
          expect(provider.cacheState, AccountCacheState.online);
          expect(await provider.deleteTrip(editable.tripId), isFalse);
        } finally {
          repo.service.close();
        }
      });
    },
  );
  test(
    'mixed pages recheck absent caches and load more without duplicates',
    () async {
      await withStrictProvider((provider, snapshots, lifecycle, context) async {
        final repo = _MixedRepository(context.store, lifecycle);
        final remote = _remote(lifecycle_fixtures.ownerA);
        await context.store.replaceSnapshot(
          handle: lifecycle.handle!,
          tripId: remote.tripId,
          payload: remote.payload,
          remoteVersion: null,
          fetchedAt: remote.fetchedAt,
        );
        await context.store.putEditableSnapshot(
          handle: lifecycle.handle!,
          head: editable.head(),
        );
        snapshots.read = (_, _) async =>
            SnapshotLookup(SnapshotLookupStatus.ready, remote);
        final cursor = OwnedTripCursor(
          DateTime.utc(2026, 10, 15),
          editable.tripId,
        );
        var pages = 0;
        final reads = <String>[];
        repo.onList = (after) async {
          pages++;
          return after == null
              ? OwnedTripPage(items: [], nextCursor: cursor)
              : OwnedTripPage(
                  items: [
                    _summary(remote.tripId, OwnedTripKind.legacyV1),
                    _summary(editable.tripId, OwnedTripKind.editableV2),
                  ],
                );
        };
        repo.onRead = (id, allow) async {
          reads.add(id);
          expect(allow, isFalse);
          return EditableTripView(
            EditableTripViewState.online,
            editable.head(),
          );
        };
        try {
          provider.bindEditableRepository(repo);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.visibleTrips.length, 2);
          expect(provider.hasMoreTrips, isTrue);
          expect(reads, [editable.tripId]);
          await provider.loadMoreTrips();
          expect(provider.visibleTrips.length, 2);
          expect(provider.hasMoreTrips, isFalse);
          expect(pages, 2);
          expect(
            await context.store.readEditableSnapshot(
              handle: lifecycle.handle!,
              tripId: editable.tripId,
            ),
            isNotNull,
          );
        } finally {
          repo.service.close();
        }
      });
    },
  );
  test(
    'late mixed page after unbind cannot publish private summaries',
    () async {
      await withStrictProvider((provider, snapshots, lifecycle, context) async {
        final repo = _MixedRepository(context.store, lifecycle),
            pending = Completer<OwnedTripPage>();
        repo.onList = (_) => pending.future;
        try {
          provider.bindEditableRepository(repo);
          final loading = provider.loadTrips(lifecycle_fixtures.ownerA);
          provider.unbindAccount();
          pending.complete(
            OwnedTripPage(
              items: [_summary(editable.tripId, OwnedTripKind.editableV2)],
            ),
          );
          await loading;
          expect(provider.visibleTrips, isEmpty);
          expect(provider.trips, isEmpty);
        } finally {
          repo.service.close();
        }
      });
    },
  );
  test(
    'translated unauthorized mixed list invalidates account access',
    () async {
      await withStrictProvider((provider, snapshots, lifecycle, context) async {
        final repo = _MixedRepository(context.store, lifecycle);
        final proof = lifecycle.captureProof();
        repo.onList = (_) async => throw const EditableRemoteException(
          EditableRemoteFailure.rejected,
          'unauthorized',
        );
        try {
          provider.bindEditableRepository(repo);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(lifecycle.isCurrentProof(proof), isFalse);
          expect(provider.currentUserId, isNull);
          expect(provider.cacheState, AccountCacheState.blocked);
          expect(provider.visibleTrips, isEmpty);
          expect(provider.isLoading, isFalse);
        } finally {
          repo.service.close();
        }
      });
    },
  );

  test('missing V2 list RPC is deployment error without legacy fallback or cache purge', () async {
    await withStrictProvider((provider, snapshots, lifecycle, context) async {
      final repo = _MixedRepository(context.store, lifecycle);
      var fallback = 0;
      snapshots.fetch = (_) async {
        fallback++;
        return SnapshotFetchBatch([], DateTime.now());
      };
      await context.store.putEditableSnapshot(
        handle: lifecycle.handle!,
        head: editable.head(),
      );
      repo.onList = (_) async => throw const EditableRemoteException(
        EditableRemoteFailure.deploymentBlocked,
        'editable_schema_unavailable',
      );
      try {
        provider.bindEditableRepository(repo);
        await provider.loadTrips(lifecycle_fixtures.ownerA);
        expect(provider.cacheState, AccountCacheState.error);
        expect(provider.cacheErrorMessage, contains('chưa sẵn sàng'));
        expect(provider.visibleTrips, isEmpty);
        expect(fallback, 0);
        expect(
          await context.store.readEditableSnapshot(
            handle: lifecycle.handle!,
            tripId: editable.tripId,
          ),
          isNotNull,
        );
      } finally {
        repo.service.close();
      }
    });
  });
  test(
    'uncertain mixed list exposes separately cached V1 and V2 in offline state',
    () async {
      await withStrictProvider((provider, snapshots, lifecycle, context) async {
        final repo = _MixedRepository(context.store, lifecycle),
            remote = _remote(lifecycle_fixtures.ownerA);
        await context.store.replaceSnapshot(
          handle: lifecycle.handle!,
          tripId: remote.tripId,
          payload: remote.payload,
          remoteVersion: null,
          fetchedAt: remote.fetchedAt,
        );
        await context.store.putEditableSnapshot(
          handle: lifecycle.handle!,
          head: editable.head(),
        );
        repo.onList = (_) async => throw const EditableRemoteException(
          EditableRemoteFailure.uncertain,
          'outcome_unknown',
        );
        try {
          provider.bindEditableRepository(repo);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.cacheState, AccountCacheState.offline);
          expect(provider.visibleTrips.length, 2);
          expect(provider.trips.length, 1);
          expect(provider.hasMoreTrips, isFalse);
        } finally {
          repo.service.close();
        }
      });
    },
  );

  test(
    'imported V1 remains a legacy snapshot with its remote version',
    () async {
      await withStrictProvider((provider, snapshots, lifecycle, context) async {
        final repo = _MixedRepository(context.store, lifecycle);
        final base = _remote(lifecycle_fixtures.ownerA);
        snapshots.read = (_, _) async => SnapshotLookup(
          SnapshotLookupStatus.ready,
          RemoteTripSnapshot(
            ownerId: base.ownerId,
            tripId: base.tripId,
            payload: base.payload,
            remoteVersion: 1,
            fetchedAt: base.fetchedAt,
            headers: base.headers,
          ),
        );
        repo.onList = (_) async => OwnedTripPage(
          items: [_summary(base.tripId, OwnedTripKind.legacyV1)],
        );
        try {
          provider.bindEditableRepository(repo);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.visibleTrips.single.kind, OwnedTripKind.legacyV1);
          expect(provider.visibleTrips.single.version, isNull);
          expect(provider.accountSnapshots.single.remoteVersion, 1);
          expect(provider.trips.single.id, base.tripId);
        } finally {
          repo.service.close();
        }
      });
    },
  );

  group('B6.4 lifecycle-bound SQLite cache', () {
    test(
      'stale load request for another owner cannot clear active binding',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          await provider.loadTrips(lifecycle_fixtures.ownerB);
          expect(provider.currentUserId, lifecycle_fixtures.ownerA);
          expect(provider.cacheState, AccountCacheState.loading);
        });
      },
    );

    test(
      'late online response after unbind cannot republish account data',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          final pending = Completer<SnapshotFetchBatch>();
          snapshots.fetch = (_) => pending.future;
          final work = provider.loadTrips(lifecycle_fixtures.ownerA);
          provider.unbindAccount();
          final remote = _remote(lifecycle_fixtures.ownerA);
          pending.complete(SnapshotFetchBatch([remote], remote.fetchedAt));
          await work;
          expect(provider.trips, isEmpty);
          expect(provider.accountSnapshots, isEmpty);
          expect(provider.currentUserId, isNull);
        });
      },
    );

    test(
      'online validated snapshot reaches only owned SQLite namespace',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          final remote = _remote(lifecycle_fixtures.ownerA);
          snapshots.fetch = (_) async =>
              SnapshotFetchBatch([remote], remote.fetchedAt);
          snapshots.read = (_, _) async =>
              const SnapshotLookup(SnapshotLookupStatus.unavailable);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.cacheState, AccountCacheState.online);
          expect(provider.trips.single.id, _ownedTripId);
          expect(
            provider.accountSnapshots.single.ownerId,
            lifecycle_fixtures.ownerA,
          );
          expect(
            await context.store.getSnapshot(
              handle: lifecycle.handle!,
              tripId: _ownedTripId,
            ),
            isNotNull,
          );
        });
      },
    );

    test(
      'connectivity loss reads checked owner cache, then unbind hides it',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          final remote = _remote(lifecycle_fixtures.ownerA);
          await context.store.replaceSnapshot(
            handle: lifecycle.handle!,
            tripId: _ownedTripId,
            payload: remote.payload,
            fetchedAt: remote.fetchedAt,
          );
          snapshots.fetch = (_) async => throw DioException(
            requestOptions: RequestOptions(path: '/rest/v1/trips'),
            type: DioExceptionType.connectionTimeout,
          );
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.cacheState, AccountCacheState.offline);
          expect(provider.trips.single.userId, lifecycle_fixtures.ownerA);
          provider.unbindAccount();
          expect(provider.trips, isEmpty);
          expect(provider.accountSnapshots, isEmpty);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.trips, isEmpty);
        });
      },
    );

    test(
      '401 denies cached account data instead of offline fallback',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          final remote = _remote(lifecycle_fixtures.ownerA);
          await context.store.replaceSnapshot(
            handle: lifecycle.handle!,
            tripId: _ownedTripId,
            payload: remote.payload,
            fetchedAt: remote.fetchedAt,
          );
          final request = RequestOptions(path: '/rest/v1/trips');
          snapshots.fetch = (_) async => throw DioException(
            requestOptions: request,
            response: Response(requestOptions: request, statusCode: 401),
            type: DioExceptionType.badResponse,
          );
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.cacheState, AccountCacheState.blocked);
          expect(provider.trips, isEmpty);
          expect(lifecycle.handle, isNull);
        });
      },
    );

    test(
      'imported RPC 401 remains an auth error for provider denial',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          final adapter = TripSnapshotService(
            projectUrl: 'https://staging.example.test',
            publicKey: 'fixture-public',
            isCurrentProof: lifecycle.isCurrentProof,
            adapter: _UnauthorizedAdapter(),
          );
          try {
            await expectLater(
              adapter.readImportedSnapshot(
                proof: lifecycle.captureProof(),
                tripId: _ownedTripId,
              ),
              throwsA(
                isA<DioException>().having(
                  (error) => error.response?.statusCode,
                  'status',
                  401,
                ),
              ),
            );
          } finally {
            adapter.close();
          }
        });
      },
    );

    test(
      'partial list cannot evict an absent trip without owner recheck',
      () async {
        await withStrictProvider((
          provider,
          snapshots,
          lifecycle,
          context,
        ) async {
          final remote = _remote(lifecycle_fixtures.ownerA);
          await context.store.replaceSnapshot(
            handle: lifecycle.handle!,
            tripId: _ownedTripId,
            payload: remote.payload,
            fetchedAt: remote.fetchedAt,
          );
          snapshots.fetch = (_) async =>
              SnapshotFetchBatch([], DateTime.now().toUtc());
          snapshots.read = (_, _) async =>
              const SnapshotLookup(SnapshotLookupStatus.rejected);
          await provider.loadTrips(lifecycle_fixtures.ownerA);
          expect(provider.cacheState, AccountCacheState.error);
          expect(
            await context.store.getSnapshot(
              handle: lifecycle.handle!,
              tripId: _ownedTripId,
            ),
            isNotNull,
          );
        });
      },
    );
  });

  group('SavedTripsProvider & Server Ack Tests (R03, DB-001, INT-002)', () {
    late FakeTripsService fakeService;
    late SavedTripsProvider provider;

    setUp(() {
      fakeService = FakeTripsService();
      provider = SavedTripsProvider(service: fakeService);
    });

    test(
      'saveTrip succeeds only after valid server ID acknowledgement',
      () async {
        await provider.loadTrips('user-alice');
        expect(provider.trips, isEmpty);

        final success = await provider.saveTrip(
          title: 'Hè Đà Nẵng',
          destinationName: 'Đà Nẵng',
          numDays: 3,
          budgetTotal: 5000000,
          tripPlanData: {'focus': 'Biển'},
        );

        expect(success, isTrue);
        expect(provider.count, 1);
        expect(provider.trips.first.id, startsWith('server-gen-id-'));
        expect(provider.trips.first.title, 'Hè Đà Nẵng');
        expect(provider.errorMessage, isNull);
      },
    );

    test('saveTrip failure does NOT fake success or insert unconfirmed RAM dummy (Law 3)', () async {
      await provider.loadTrips('user-alice');
      fakeService.shouldFailSave = true;

      final success = await provider.saveTrip(
        title: 'Failed Trip',
        destinationName: 'Huế',
        numDays: 2,
        budgetTotal: 3000000,
        tripPlanData: {},
      );

      // Critical assertion: NO fake success, NO silent RAM insertion!
      expect(success, isFalse);
      expect(provider.count, 0);
      expect(provider.trips, isEmpty);
      expect(provider.errorMessage, contains('Không thể lưu chuyến đi'));
    });

    test('loadTrips failure sets errorMessage and does not wipe state as legitimate empty', () async {
      fakeService.fakeTrips = [
        SavedTrip(
          id: 'existing-1',
          userId: 'user-alice',
          title: 'Existing Trip',
          destinationName: 'Đà Lạt',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];

      // First successful load
      await provider.loadTrips('user-alice');
      expect(provider.count, 1);

      // Next load fails on network error
      fakeService.shouldFailFetch = true;
      await provider.loadTrips('user-alice');

      expect(provider.errorMessage, contains('Lỗi tải danh sách chuyến đi'));
      // Does not treat fetch failure as legitimate empty result
      expect(provider.count, 1);
    });

    test('deleteTrip failure restores trip in current session', () async {
      fakeService.fakeTrips = [
        SavedTrip(
          id: 'del-1',
          userId: 'user-alice',
          title: 'Trip to delete',
          destinationName: 'Hội An',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];

      await provider.loadTrips('user-alice');
      expect(provider.count, 1);

      fakeService.shouldFailDelete = true;
      final result = await provider.deleteTrip('del-1');

      expect(result, isFalse);
      // Item was restored due to server delete failure
      expect(provider.count, 1);
      expect(provider.errorMessage, isNotNull);
    });

    test('clearLocal purges RAM, resets current user, and increments session epoch', () {
      provider.clearLocal();
      expect(provider.trips, isEmpty);
      expect(provider.currentUserId, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.sessionEpoch, greaterThan(0));
    });

    test('Late fetch response from User A after clearLocal/logout is dropped (epoch guard)', () async {
      final completer = Completer<List<SavedTrip>>();
      fakeService.fetchCompleter = completer;

      // Start slow load for User A
      provider.loadTrips('user-a');
      expect(provider.isLoading, isTrue);

      // User logs out before fetch completes
      provider.clearLocal();
      expect(provider.trips, isEmpty);
      expect(provider.currentUserId, isNull);

      // User A's slow response returns
      completer.complete([
        SavedTrip(
          id: 'late-trip-a',
          userId: 'user-a',
          title: 'Late Trip',
          destinationName: 'Ninh Bình',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // Critical assertion: Late response MUST NOT pollute logged-out state!
      expect(provider.trips, isEmpty);
      expect(provider.currentUserId, isNull);
    });

    test('Slow User A fetch followed by User B login ensures User B data wins (R04)', () async {
      final userACompleter = Completer<List<SavedTrip>>();
      fakeService.fetchCompleter = userACompleter;

      // Start slow load for User A
      provider.loadTrips('user-a');

      // Switch to User B with immediate response
      fakeService.fetchCompleter = null;
      fakeService.fakeTrips = [
        SavedTrip(
          id: 'b-1',
          userId: 'user-b',
          title: 'Trip for B',
          destinationName: 'Cần Thơ',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];
      await provider.loadTrips('user-b');

      expect(provider.currentUserId, 'user-b');
      expect(provider.count, 1);
      expect(provider.trips.first.title, 'Trip for B');

      // Late response from User A arrives
      userACompleter.complete([
        SavedTrip(
          id: 'a-1',
          userId: 'user-a',
          title: 'Trip for A',
          destinationName: 'Hà Nội',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      // User B must still win! No pollution from User A!
      expect(provider.currentUserId, 'user-b');
      expect(provider.count, 1);
      expect(provider.trips.first.title, 'Trip for B');
    });

    test(
      'In-flight save for User A is ignored if session switches to User B',
      () async {
        await provider.loadTrips('user-a');

        final saveCompleter = Completer<SavedTrip>();
        fakeService.saveCompleter = saveCompleter;

        // User A initiates save
        final saveFuture = provider.saveTrip(
          title: 'Trip by A',
          destinationName: 'Sa Pa',
          numDays: 3,
          budgetTotal: 4000000,
          tripPlanData: {},
        );

        // Account switches to User B before save returns
        provider.clearLocal();
        await provider.loadTrips('user-b');

        // Server acknowledges User A save late
        saveCompleter.complete(
          SavedTrip(
            id: 'server-id-a',
            userId: 'user-a',
            title: 'Trip by A',
            destinationName: 'Sa Pa',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        );

        final saveResult = await saveFuture;
        expect(saveResult, isFalse);
        expect(provider.currentUserId, 'user-b');
        // No User A trips in User B session!
        expect(provider.trips.any((t) => t.userId == 'user-a'), isFalse);
      },
    );

    test('syncWithAuth purges RAM on guest or demo session and loads for real user', () {
      fakeService.fakeTrips = [
        SavedTrip(
          id: 'trip-real-1',
          userId: 'real-user-1',
          title: 'Real Trip',
          destinationName: 'Nha Trang',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];

      // 1. Authenticated real user loads trips
      provider.syncWithAuth(
        isAuthenticated: true,
        isDemoSession: false,
        userId: 'real-user-1',
      );
      expect(provider.currentUserId, 'real-user-1');

      // 2. Switch to guest -> RAM cleared
      provider.syncWithAuth(
        isAuthenticated: false,
        isDemoSession: false,
        userId: null,
      );
      expect(provider.currentUserId, isNull);
      expect(provider.trips, isEmpty);

      // 3. Demo login -> RAM cleared, no live queries
      provider.syncWithAuth(
        isAuthenticated: true,
        isDemoSession: true,
        userId: 'demo-minh',
      );
      expect(provider.currentUserId, isNull);
      expect(provider.trips, isEmpty);
    });

    test(
      'account_switch_clears_loaded_A_before_B_completes (FIX-01, REV-001)',
      () async {
        // Setup: User A has loaded trips
        fakeService.fakeTrips = [
          SavedTrip(
            id: 'trip-a-1',
            userId: 'user-a',
            title: 'Private A Trip',
            destinationName: 'Hà Nội',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        ];
        await provider.loadTrips('user-a');
        expect(provider.count, 1);
        expect(provider.trips.first.userId, 'user-a');

        // Switch to User B with pending completer, WITHOUT explicit clearLocal in test setup
        final bCompleter = Completer<List<SavedTrip>>();
        fakeService.fetchCompleter = bCompleter;

        final loadBFuture = provider.loadTrips('user-b');

        // Assert immediately before B completes: User A data MUST be gone!
        expect(provider.currentUserId, 'user-b');
        expect(provider.isLoading, isTrue);
        expect(provider.trips, isEmpty);
        expect(provider.trips.where((t) => t.userId == 'user-a'), isEmpty);

        // Now complete B
        bCompleter.complete([
          SavedTrip(
            id: 'trip-b-1',
            userId: 'user-b',
            title: 'Trip for B',
            destinationName: 'Đà Nẵng',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        ]);
        await loadBFuture;

        expect(provider.isLoading, isFalse);
        expect(provider.count, 1);
        expect(provider.trips.first.userId, 'user-b');
      },
    );

    test('B_fetch_error_never_restores_A (FIX-01, REV-001)', () async {
      // Setup: User A has loaded trips
      fakeService.fakeTrips = [
        SavedTrip(
          id: 'trip-a-1',
          userId: 'user-a',
          title: 'Private A Trip',
          destinationName: 'Hà Nội',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];
      await provider.loadTrips('user-a');
      expect(provider.count, 1);

      // Switch to User B where fetch fails, WITHOUT calling clearLocal in test setup
      fakeService.shouldFailFetch = true;
      fakeService.fetchCompleter = null;

      await provider.loadTrips('user-b');

      // Assert after error B: trips must remain empty, User A trips must NOT be restored!
      expect(provider.currentUserId, 'user-b');
      expect(provider.trips, isEmpty);
      expect(provider.errorMessage, contains('Lỗi tải danh sách chuyến đi'));
    });

    test('clearLocal_cancels_pending_fetch (REV-006)', () async {
      final fake = FakeTripsService();
      final p = SavedTripsProvider(service: fake);
      p.updateAuthContext(
        isAuthenticated: true,
        isDemoSession: false,
        userId: 'user-a',
      );
      p.clearLocal();
      p.fetchIfPending();

      expect(p.currentUserId, isNull);
      expect(fake.fetchCalls, 0);
      expect(p.isLoading, isFalse);
      p.dispose();
    });

    test('dispose_ignores_inflight_fetch (REV-007)', () async {
      final completer = Completer<List<SavedTrip>>();
      final fake = FakeTripsService()..fetchCompleter = completer;
      final p = SavedTripsProvider(service: fake);
      final work = p.loadTrips('user-a');
      p.dispose();
      completer.complete([]);
      await expectLater(work, completes);
    });

    test('dispose_ignores_inflight_save_and_delete (REV-007)', () async {
      final saveComp = Completer<SavedTrip>();
      final delComp = Completer<bool>();
      final fake = FakeTripsService()
        ..saveCompleter = saveComp
        ..deleteCompleter = delComp
        ..fakeTrips = [
          SavedTrip(
            id: 'trip-1',
            userId: 'user-a',
            title: 'Seeded Trip',
            destinationName: 'Da Nang',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        ];
      final p = SavedTripsProvider(service: fake);
      await p.loadTrips('user-a');
      expect(p.trips.single.id, 'trip-1');

      final saveWork = p.saveTrip(
        title: 'Trip',
        destinationName: 'Da Nang',
        numDays: 2,
        budgetTotal: 1000,
        tripPlanData: {},
      );
      final delWork = p.deleteTrip('trip-1');
      expect(
        fake.deleteCalls,
        1,
        reason: 'Must enter the real asynchronous DELETE path',
      );

      p.dispose();

      saveComp.complete(
        SavedTrip(
          id: 'id-1',
          userId: 'user-a',
          title: 'Trip',
          destinationName: 'Da Nang',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      );
      delComp.complete(true);

      final saveResult = await saveWork;
      final delResult = await delWork;

      expect(saveResult, isFalse);
      expect(delResult, isFalse);
    });

    test('late successful DELETE after account switch returns false and preserves new session', () async {
      final delComp = Completer<bool>();
      final fake = FakeTripsService()
        ..deleteCompleter = delComp
        ..fakeTrips = [
          SavedTrip(
            id: 'trip-a-1',
            userId: 'user-a',
            title: 'Trip A',
            destinationName: 'Hà Nội',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        ];
      final p = SavedTripsProvider(service: fake);
      await p.loadTrips('user-a');
      expect(p.trips.single.id, 'trip-a-1');

      final deleteFuture = p.deleteTrip('trip-a-1');
      expect(
        fake.deleteCalls,
        1,
        reason: 'Must enter the real asynchronous DELETE path',
      );

      // User switches to User B while delete is in-flight
      fake.fakeTrips = [];
      await p.loadTrips('user-b');
      expect(p.currentUserId, 'user-b');
      expect(p.trips, isEmpty);

      // Server acknowledges User A delete with success
      delComp.complete(true);
      final result = await deleteFuture;

      expect(
        result,
        isFalse,
        reason: 'Acknowledgement belongs to an invalidated session',
      );
      expect(p.currentUserId, 'user-b');
      expect(p.trips, isEmpty);
      p.dispose();
    });
  });
}
