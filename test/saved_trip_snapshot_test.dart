import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/saved_trip_snapshot_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/trip_snapshot_service.dart';

import 'local_account_lifecycle_test.dart' as lifecycle_fixtures;
import 'local_trip_store_test.dart' as store_fixtures;

const _tripId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

User _user(String owner) => User(
  id: owner,
  email: 'owner@example.test',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-13T00:00:00Z',
);

class _OfflineSnapshots extends TripSnapshotService {
  _OfflineSnapshots(LocalAccountLifecycleService lifecycle)
    : super(
        projectUrl: 'https://staging.example.test',
        publicKey: 'fixture-public',
        isCurrentProof: lifecycle.isCurrentProof,
      );

  @override
  Future<SnapshotFetchBatch> fetchSnapshots({
    required AccountSessionProof proof,
  }) async => throw DioException(
    requestOptions: RequestOptions(path: '/rest/v1/trips'),
    type: DioExceptionType.connectionTimeout,
  );
}

Future<void> _withOfflineWidget(
  WidgetTester tester, {
  required bool hasCache,
  bool includePlan = true,
  required Future<void> Function(SavedTripsProvider, AuthProvider) check,
}) async {
  await tester.runAsync(() async {
    await store_fixtures.runWithStore((ctx) async {
      final session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerA);
      final lifecycle = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
      );
      final snapshots = _OfflineSnapshots(lifecycle);
      final provider = SavedTripsProvider(requiresLifecycle: true);
      final auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer');
      try {
        await auth.initialization;
        auth.simulateSupabaseUser(_user(lifecycle_fixtures.ownerA));
        expect(
          await lifecycle.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        if (hasCache) {
          await ctx.store.replaceSnapshot(
            handle: lifecycle.handle!,
            tripId: _tripId,
            payload: store_fixtures.createValidPayload(
              includePlan: includePlan,
            ),
            remoteVersion: 3,
            fetchedAt: DateTime.utc(2026, 10, 12, 8, 30),
          );
        }
        provider.bindAccount(
          lifecycle: lifecycle,
          store: ctx.store,
          snapshots: snapshots,
          handle: lifecycle.handle!,
        );
        await provider.loadTrips(lifecycle_fixtures.ownerA);
        await check(provider, auth);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        auth.dispose();
        snapshots.close();
        await lifecycle.close();
      }
    });
  });
}

Widget _app(Widget child, SavedTripsProvider trips, AuthProvider auth) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SavedTripsProvider>.value(value: trips),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('offline card opens real checked itinerary and cannot delete', (
    tester,
  ) async {
    await _withOfflineWidget(
      tester,
      hasCache: true,
      check: (trips, auth) async {
        expect(trips.cacheState, AccountCacheState.offline);
        await tester.pumpWidget(_app(const MyTripsScreen(), trips, auth));
        await tester.pump();
        expect(find.text('BẢN TRÊN MÁY · NGOẠI TUYẾN'), findsOneWidget);
        final delete = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete_outline),
        );
        expect(delete.onPressed, isNull);
        await tester.tap(find.text('Xem lịch trình đã lưu'));
        await tester.pumpAndSettle();
        expect(find.text('Tắm biển'), findsNothing);
        expect(find.textContaining('Tắm biển'), findsOneWidget);
        expect(
          find.text('Ngoại tuyến · chưa kiểm tra lại với server'),
          findsOneWidget,
        );
        expect(find.text('Phiên bản server: 3'), findsOneWidget);
        expect(find.textContaining('12/10/2026'), findsOneWidget);
        expect(find.textContaining('Máy bay'), findsOneWidget);
      trips.unbindAccount();
      await tester.pump();
      expect(
        find.text('Không có bản lưu trên máy khả dụng cho tài khoản này.'),
        findsOneWidget,
      );
      expect(find.textContaining('Tắm biển'), findsNothing);
      },
    );
  });

  testWidgets(
    'input-only snapshot stays input-only and account switch hides it',
    (tester) async {
      await _withOfflineWidget(
        tester,
        hasCache: true,
        includePlan: false,
        check: (trips, auth) async {
          await tester.pumpWidget(
            _app(
              const SavedTripSnapshotScreen(
                tripId: _tripId,
                expectedOwnerId: lifecycle_fixtures.ownerA,
              ),
              trips,
              auth,
            ),
          );
          await tester.pump();
          expect(
            find.text('Chỉ có thông tin đầu vào, chưa có lịch trình.'),
            findsOneWidget,
          );
          expect(find.text('Lịch trình'), findsNothing);
          auth.simulateSupabaseUser(_user(lifecycle_fixtures.ownerB));
          await tester.pump();
          expect(
            find.text('Không có bản lưu trên máy khả dụng cho tài khoản này.'),
            findsOneWidget,
          );
          expect(
            find.text('Chỉ có thông tin đầu vào, chưa có lịch trình.'),
            findsNothing,
          );
        },
      );
    },
  );

  testWidgets('missing cache reports unavailable without a network retry', (
    tester,
  ) async {
    await _withOfflineWidget(
      tester,
      hasCache: false,
      check: (trips, auth) async {
        expect(trips.cacheState, AccountCacheState.unavailable);
        await tester.pumpWidget(
          _app(
            const SavedTripSnapshotScreen(
              tripId: _tripId,
              expectedOwnerId: lifecycle_fixtures.ownerA,
            ),
            trips,
            auth,
          ),
        );
        await tester.pump();
        expect(
          find.text('Không có bản lưu trên máy khả dụng cho tài khoản này.'),
          findsOneWidget,
        );
      },
    );
  });
}
