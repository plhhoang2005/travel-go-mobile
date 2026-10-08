import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/navigation/presentation/screens/main_navigation_shell.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/core/constants/supabase_constants.dart';
import 'package:travelgo_mobile/features/favorites/providers/favorites_provider.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/home/providers/home_catalog_provider.dart';
import 'package:travelgo_mobile/main.dart';

class FakeTripsServiceForNav extends TripsService {
  final Map<String, List<SavedTrip>> fakeMap = {};
  Completer<List<SavedTrip>>? pendingCompleter;
  int fetchCount = 0;
  bool shouldThrow = false;

  @override
  Future<List<SavedTrip>> fetchTrips(String userId) async {
    fetchCount++;
    if (shouldThrow) {
      throw Exception('Server network error');
    }
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    return fakeMap[userId] ?? [];
  }
}

void main() {
  group('AuthProvider Unit Tests', () {
    test('Initial state is not authenticated', () {
      final auth = AuthProvider();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('continueAsGuest sets isGuest to true', () {
      final auth = AuthProvider();
      auth.continueAsGuest();
      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);
    });

    test('quickDemoLogin with customer sets Minh profile', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.customer);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.customer);
      expect(auth.currentUser?.fullName, 'Hoàng Minh');
      expect(auth.isGuest, isFalse);
    });

    test('quickDemoLogin with partner sets Furama profile', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.partner);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.partner);
      expect(auth.currentUser?.fullName, 'Resort Furama Đà Nẵng');
    });

    test('quickDemoLogin with admin sets Admin profile', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.admin);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.admin);
    });

    test('verifyOtp succeeds with 6-digit code', () async {
      final auth = AuthProvider();
      final result = await auth.verifyOtp('123456');
      expect(result, isTrue);
      expect(auth.isAuthenticated, isTrue);
    });

    test('verifyOtp fails with code shorter than 6 digits', () async {
      final auth = AuthProvider();
      final result = await auth.verifyOtp('123');
      expect(result, isFalse);
      expect(auth.errorMessage, isNotNull);
    });

    test('logout clears user and sets isGuest to true', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.customer);
      expect(auth.isAuthenticated, isTrue);

      auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.isGuest, isTrue);
    });

    test('login without Supabase connection reports error safely without mock fallback', () async {
      final auth = AuthProvider();
      final success = await auth.login('minh@travelgo.vn', '123456');
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('kết nối'));
    });

    test('register without Supabase connection reports error safely without mock fallback', () async {
      final auth = AuthProvider();
      final success = await auth.register(
        fullName: 'Nguyễn Văn Test',
        email: 'test@travelgo.vn',
        phone: '0912345678',
        password: 'password123',
      );
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('kết nối'));
    });

    test(
      'signInWithOAuth without Supabase connection reports error safely',
      () async {
        final auth = AuthProvider();
        final success = await auth.signInWithOAuth(OAuthProvider.facebook);
        expect(success, isFalse);
        expect(auth.errorMessage, contains('kết nối'));
      },
    );

    test('SupabaseConstants holds valid configuration', () {
      expect(SupabaseConstants.projectUrl, startsWith('https://'));
      expect(SupabaseConstants.projectUrl, contains('.supabase.co'));
      expect(SupabaseConstants.publishableKey, startsWith('sb_publishable_'));
    });
  });

  group('Navigation Shell Widget Tests', () {
    testWidgets(
      'MainNavigationShell renders 5 bottom destinations and switches tabs',
      (WidgetTester tester) async {
        final authProvider = AuthProvider()..continueAsGuest();
        final tripProvider = TripProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: tripProvider),
              ChangeNotifierProvider(create: (_) => FavoritesProvider()),
              ChangeNotifierProvider(create: (_) => SavedTripsProvider()),
              ChangeNotifierProvider(create: (_) => HomeCatalogProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check bottom navigation items
        final navBar = find.byType(NavigationBar);
        expect(
          find.descendant(of: navBar, matching: find.text('Trang chủ')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Khám phá')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Chuyến đi')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Yêu thích')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: navBar, matching: find.text('Cá nhân')),
          findsOneWidget,
        );

        // Verify initial tab is Home and displays guest greeting instead of hardcoded name
        expect(find.text('Điểm đến nổi bật'), findsOneWidget);
        expect(find.text('Xin chào, Quý khách'), findsOneWidget);
        expect(find.text('Vãng lai'), findsOneWidget);
        expect(find.text('Xin chào, Hoàng'), findsNothing);

        // Switch to Explore tab
        await tester.tap(
          find.descendant(of: navBar, matching: find.text('Khám phá')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Khám Phá Việt Nam'), findsOneWidget);

        // Switch to Trips tab
        await tester.tap(find.text('Chuyến đi'));
        await tester.pumpAndSettle();
        expect(find.text('Chuyến Đi Của Tôi'), findsOneWidget);

        // Switch to Favorites tab
        await tester.tap(find.text('Yêu thích'));
        await tester.pumpAndSettle();
        expect(find.text('Danh Sách Yêu Thích'), findsOneWidget);

        // Switch to Profile tab
        await tester.tap(find.text('Cá nhân'));
        await tester.pumpAndSettle();
        expect(find.text('Tài Khoản'), findsOneWidget);
        expect(find.text('Khách Vãng Lai'), findsOneWidget);
      },
    );

    testWidgets(
      'Lifecycle & ProxyProvider: account transition A -> B never exposes A data to B or Guest (FIX-01, REV-001)',
      (WidgetTester tester) async {
        final authProvider = AuthProvider();
        final tripProvider = TripProvider();
        final fakeTripsService = FakeTripsServiceForNav();
        final savedTripsProvider = SavedTripsProvider(
          service: fakeTripsService,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: tripProvider),
              ChangeNotifierProvider(create: (_) => FavoritesProvider()),
              ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
                create: (_) => savedTripsProvider,
                update: (_, auth, savedTrips) => updateSavedTripsFromAuth(
                  auth,
                  savedTrips ?? savedTripsProvider,
                ),
              ),
              ChangeNotifierProvider(create: (_) => HomeCatalogProvider()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Consumer2<AuthProvider, SavedTripsProvider>(
                  builder: (context, auth, saved, _) {
                    return Column(
                      children: [
                        Text('USER:${auth.currentUser?.id ?? "NONE"}'),
                        Text('TRIPS_COUNT:${saved.count}'),
                        Text(
                          'FIRST_OWNER:${saved.trips.isEmpty ? "NONE" : saved.trips.first.userId}',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('USER:NONE'), findsOneWidget);
        expect(find.text('TRIPS_COUNT:0'), findsOneWidget);

        // Login as User A
        fakeTripsService.fakeMap['user-a'] = [
          SavedTrip(
            id: 'trip-a',
            userId: 'user-a',
            title: 'Trip A',
            destinationName: 'HN',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        ];

        authProvider.simulateSupabaseUser(
          User(
            id: 'user-a',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
            email: 'a@travelgo.vn',
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('USER:user-a'), findsOneWidget);
        expect(find.text('TRIPS_COUNT:1'), findsOneWidget);
        expect(find.text('FIRST_OWNER:user-a'), findsOneWidget);

        // Switch to User B with pending fetch
        final bCompleter = Completer<List<SavedTrip>>();
        fakeTripsService.pendingCompleter = bCompleter;

        authProvider.simulateSupabaseUser(
          User(
            id: 'user-b',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
            email: 'b@travelgo.vn',
          ),
        );

        // Pump single frame
        await tester.pump();
        // Critical assertion: In frame 1 of User B, User A data must NOT be rendered!
        expect(find.text('USER:user-b'), findsOneWidget);
        expect(find.text('TRIPS_COUNT:0'), findsOneWidget);
        expect(find.text('FIRST_OWNER:NONE'), findsOneWidget);

        // Complete User B fetch
        bCompleter.complete([
          SavedTrip(
            id: 'trip-b',
            userId: 'user-b',
            title: 'Trip B',
            destinationName: 'DN',
            tripPlanData: {},
            createdAt: DateTime.now(),
          ),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('USER:user-b'), findsOneWidget);
        expect(find.text('TRIPS_COUNT:1'), findsOneWidget);
        expect(find.text('FIRST_OWNER:user-b'), findsOneWidget);

        // Switch to Guest
        authProvider.continueAsGuest();
        await tester.pumpAndSettle();
        expect(find.text('USER:NONE'), findsOneWidget);
        expect(find.text('TRIPS_COUNT:0'), findsOneWidget);
        expect(find.text('FIRST_OWNER:NONE'), findsOneWidget);
      },
    );

    testWidgets('rapid_auth_changes_never_render_old_owner (Task 1)', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider();
      final fakeTripsService = FakeTripsServiceForNav();
      final savedTripsProvider = SavedTripsProvider(service: fakeTripsService);
      final renderedFrames = <Map<String, String?>>[];

      fakeTripsService.fakeMap['user-a'] = [
        SavedTrip(
          id: 'a-1',
          userId: 'user-a',
          title: 'Trip A',
          destinationName: 'Da Nang',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];
      fakeTripsService.fakeMap['user-b'] = [
        SavedTrip(
          id: 'b-1',
          userId: 'user-b',
          title: 'Trip B',
          destinationName: 'Hue',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
              create: (_) => savedTripsProvider,
              update: (_, auth, saved) =>
                  updateSavedTripsFromAuth(auth, saved ?? savedTripsProvider),
            ),
          ],
          child: MaterialApp(
            home: Consumer2<AuthProvider, SavedTripsProvider>(
              builder: (context, auth, saved, _) {
                renderedFrames.add({
                  'auth': auth.currentUser?.id,
                  'owner': saved.trips.isEmpty
                      ? null
                      : saved.trips.first.userId,
                });
                return Text('COUNT:${saved.count}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Login A
      authProvider.simulateSupabaseUser(
        User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: 'auth',
          createdAt: '',
          email: 'a@travelgo.vn',
        ),
      );
      await tester.pumpAndSettle();

      // Rapid: switch to B with slow fetch, then immediately to Guest
      final bCompleter = Completer<List<SavedTrip>>();
      fakeTripsService.pendingCompleter = bCompleter;
      authProvider.simulateSupabaseUser(
        User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'auth',
          createdAt: '',
          email: 'b@travelgo.vn',
        ),
      );
      await tester.pump(); // frame B pending

      authProvider.continueAsGuest();
      await tester.pump(); // frame guest

      // Complete late B response
      bCompleter.complete(fakeTripsService.fakeMap['user-b']!);
      await tester.pumpAndSettle();

      // Check all rendered frames: never mix owners!
      for (final frame in renderedFrames) {
        final authUser = frame['auth'];
        final owner = frame['owner'];
        if (authUser == null) {
          expect(
            owner,
            isNull,
            reason: 'Guest frame must never render user trips',
          );
        } else if (authUser == 'user-b') {
          expect(
            owner,
            isNot('user-a'),
            reason: 'User B frame must never render User A trips',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('same_subject_update_fetches_once (Task 1)', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider();
      final fakeTripsService = FakeTripsServiceForNav();
      final savedTripsProvider = SavedTripsProvider(service: fakeTripsService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
              create: (_) => savedTripsProvider,
              update: (_, auth, saved) =>
                  updateSavedTripsFromAuth(auth, saved ?? savedTripsProvider),
            ),
          ],
          child: MaterialApp(
            home: Consumer<SavedTripsProvider>(
              builder: (context, saved, child) => Text('TRIPS:${saved.count}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Login user A
      authProvider.simulateSupabaseUser(
        User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: 'auth',
          createdAt: '',
          email: 'a@travelgo.vn',
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeTripsService.fetchCount, 1);

      // Same user update (rebuild / metadata change without ID change)
      authProvider.notifyListeners();
      await tester.pumpAndSettle();

      expect(
        fakeTripsService.fetchCount,
        1,
        reason: 'Same subject must not re-fetch trips',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('guest_planner_survives_auth_changes (Task 1)', (
      WidgetTester tester,
    ) async {
      final authProvider = AuthProvider();
      final tripProvider = TripProvider();
      final fakeTripsService = FakeTripsServiceForNav();
      final savedTripsProvider = SavedTripsProvider(service: fakeTripsService);

      // Guest creates plan in tripProvider
      tripProvider.applyPreset(2);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: tripProvider),
            ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
              create: (_) => savedTripsProvider,
              update: (_, auth, saved) =>
                  updateSavedTripsFromAuth(auth, saved ?? savedTripsProvider),
            ),
          ],
          child: const MaterialApp(home: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();

      // Login user-a
      authProvider.simulateSupabaseUser(
        User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: 'auth',
          createdAt: '',
          email: 'a@travelgo.vn',
        ),
      );
      await tester.pumpAndSettle();

      // Logout / back to guest
      authProvider.continueAsGuest();
      await tester.pumpAndSettle();

      // Planner state is preserved
      expect(tripProvider.currentRequest.numDays, 4);
      expect(tripProvider.currentRequest.budgetVnd, 8000000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('B_error_keeps_A_hidden (Task 1)', (WidgetTester tester) async {
      final authProvider = AuthProvider();
      final fakeTripsService = FakeTripsServiceForNav();
      final savedTripsProvider = SavedTripsProvider(service: fakeTripsService);

      fakeTripsService.fakeMap['user-a'] = [
        SavedTrip(
          id: 'a-1',
          userId: 'user-a',
          title: 'A Private Trip',
          destinationName: 'Sa Pa',
          tripPlanData: {},
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProxyProvider<AuthProvider, SavedTripsProvider>(
              create: (_) => savedTripsProvider,
              update: (_, auth, saved) =>
                  updateSavedTripsFromAuth(auth, saved ?? savedTripsProvider),
            ),
          ],
          child: MaterialApp(
            home: Consumer<SavedTripsProvider>(
              builder: (context, saved, _) => Column(
                children: [
                  Text('COUNT:${saved.count}'),
                  Text('ERROR:${saved.errorMessage ?? "NONE"}'),
                ],
              ),
            ),
          ),
        ),
      );

      // Login A
      authProvider.simulateSupabaseUser(
        User(
          id: 'user-a',
          appMetadata: {},
          userMetadata: {},
          aud: 'auth',
          createdAt: '',
          email: 'a@travelgo.vn',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('COUNT:1'), findsOneWidget);

      // Switch to B with network error
      fakeTripsService.shouldThrow = true;
      authProvider.simulateSupabaseUser(
        User(
          id: 'user-b',
          appMetadata: {},
          userMetadata: {},
          aud: 'auth',
          createdAt: '',
          email: 'b@travelgo.vn',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COUNT:0'), findsOneWidget);
      expect(
        find.textContaining('Lỗi tải danh sách chuyến đi'),
        findsOneWidget,
      );
      expect(savedTripsProvider.trips, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
