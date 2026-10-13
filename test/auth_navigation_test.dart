// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

import 'local_trip_store_test.dart' as local_fixtures;
import 'local_account_lifecycle_test.dart' as lifecycle_fixtures;

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
  _b62LifecycleTests();
  _b62AuthTests();
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

class _PkceMemory extends GotrueAsyncStorage {
  final Map<String, String> data = {};
  @override
  Future<String?> getItem({required String key}) async => data[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    data.remove(key);
  }
}

class _ManualTimer implements Timer {
  final void Function() callback;
  bool active = true;
  _ManualTimer(this.callback);
  void fire() {
    if (active) {
      active = false;
      callback();
    }
  }

  @override
  void cancel() {
    active = false;
  }

  @override
  bool get isActive => active;
  @override
  int get tick => active ? 0 : 1;
}

class _SdkFixture {
  late final SupabaseClient client;
  String owner = lifecycle_fixtures.ownerA;
  final calls = <String>[];
  final storage = _PkceMemory();
  Completer<void>? logoutEntered,
      logoutRelease,
      exchangeEntered,
      exchangeRelease;
  Completer<void>? passwordEntered, passwordRelease;
  bool failLogout = false;
  bool userOnly = false;
  bool confirmOnly = false;
  bool rejectOldCode = false;
  int tokenSerial = 0;
  _SdkFixture() {
    client = SupabaseClient(
      'https://fixture.invalid',
      'fixture-public-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.pkce,
        pkceAsyncStorage: storage,
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/logout')) {
          calls.add('logout');
          if (logoutEntered?.isCompleted == false) logoutEntered!.complete();
          await logoutRelease?.future;
          return http.Response(
            failLogout ? '{"message":"Controlled SDK failure"}' : '{}',
            failLogout ? 500 : 200,
          );
        }
        if (path.endsWith('/token') ||
            path.endsWith('/signup') ||
            path.endsWith('/verify')) {
          final grant = request.url.queryParameters['grant_type'] ?? 'signup';
          calls.add(grant);
          if (grant == 'password') {
            if (passwordEntered?.isCompleted == false) {
              passwordEntered!.complete();
            }
            await passwordRelease?.future;
          }
          if (grant == 'pkce') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (rejectOldCode && body['auth_code'] == 'old-code') {
              return http.Response('{"message":"Invalid PKCE code"}', 400);
            }
            if (exchangeEntered?.isCompleted == false) {
              exchangeEntered!.complete();
            }
            await exchangeRelease?.future;
          }
          tokenSerial++;
          return http.Response(
            jsonEncode(
              userOnly || confirmOnly ? userData(owner) : sessionData(owner),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/user')) {
          calls.add('verify-subject');
          final token = request.headers['Authorization']!.split(' ').last;
          final payload = jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1])),
            ),
          ) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(userData(payload['sub'] as String)),
            200,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
  Map<String, dynamic> userData(String id) => {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-10-13T00:00:00Z',
    'email': 'fixture@example.invalid',
    'app_metadata': {},
    'user_metadata': {'full_name': 'Fixture', 'role': 'admin'},
  };
  Map<String, dynamic> sessionData(String id) {
    String encode(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    final expiry =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600 + tokenSerial;
    final token =
        '${encode({'alg': 'none'})}.${encode({'sub': id, 'exp': expiry, 'serial': tokenSerial})}.fixture';
    return {
      'access_token': token,
      'refresh_token': 'fixture-refresh',
      'expires_in': 3600,
      'token_type': 'bearer',
      'user': userData(id),
    };
  }

  Future<bool> launch(OAuthProvider provider) async {
    await client.auth.getOAuthSignInUrl(
      provider: provider,
      redirectTo: 'io.supabase.travelgo://login-callback',
    );
    calls.add('browser-launched');
    return true;
  }
}

Future<void> _withAuthFixture(
  Future<void> Function(
    local_fixtures.TestStoreContext,
    _SdkFixture,
    LocalAccountLifecycleService,
    AuthProvider,
  )
  body, {
  bool sealed = true,
  Future<void> Function(local_fixtures.TestStoreContext)? configure,
  Timer Function(Duration, void Function())? authTimer,
  Timer Function(Duration, void Function())? serviceTimer,
}) async {
  await local_fixtures.runWithStore((ctx) async {
    final sdk = _SdkFixture();
    LocalAccountLifecycleService? service;
    AuthProvider? auth;
    try {
      await sdk.client.auth.setInitialSession(
        jsonEncode(sdk.sessionData(sdk.owner)),
      );
      service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => sdk.client.auth.currentSession,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
        timerFactory: serviceTimer,
        verifySubject: (token) async =>
            (await sdk.client.auth.getUser(token)).user!.id,
      );
      final handle = (await service.establishAccount(
        freshAuthentication: true,
      ))!;
      await ctx.store.replaceSnapshot(
        handle: handle,
        tripId: 'A-snapshot',
        payload: local_fixtures.createValidPayload(),
        fetchedAt: DateTime.now().toUtc(),
      );
      await ctx.store.saveDraftRevision(
        draftId: 'Guest',
        payload: local_fixtures.createValidPayload(),
      );
      if (sealed) expect(await service.sealForPause(), isTrue);
      await configure?.call(ctx);
      sdk.calls.clear();
      final readyService = service;
      auth = AuthProvider(
        client: sdk.client,
        lifecycleLoader: () async => readyService,
        trustedRoleFetcher: (_) async => 'customer',
        timerFactory: authTimer,
        oauthLauncher: sdk.launch,
      );
      await auth.initialization;
      await body(ctx, sdk, service, auth);
    } finally {
      if (sdk.logoutRelease?.isCompleted == false) {
        sdk.logoutRelease!.complete();
      }
      if (sdk.exchangeRelease?.isCompleted == false) {
        sdk.exchangeRelease!.complete();
      }
      if (sdk.passwordRelease?.isCompleted == false) {
        sdk.passwordRelease!.complete();
      }
      try {
        await auth?.close();
      } finally {
        try {
          await service?.close();
        } finally {
          await sdk.client.dispose();
        }
      }
    }
  });
}

void _b62AuthTests() {
  test(
    'A04 repeated lifecycle delivery cannot purge a restored live account',
    () async {
      await _withAuthFixture((ctx, sdk, service, auth) async {
        await auth.handleAppLifecycleState(AppLifecycleState.resumed);
        expect(auth.isAuthenticated, isTrue);
        await auth.handleAppLifecycleState(AppLifecycleState.inactive);
        await auth.handleAppLifecycleState(AppLifecycleState.paused);
        await auth.handleAppLifecycleState(AppLifecycleState.paused);
        await auth.handleAppLifecycleState(AppLifecycleState.resumed);
        await auth.handleAppLifecycleState(AppLifecycleState.resumed);
        expect(auth.isAuthenticated, isTrue);
        expect(
          (await ctx.store.listSnapshots(handle: service.handle!))
              .single
              .tripId,
          'A-snapshot',
        );
      });
    },
  );
  test('A04 old PKCE code cannot authorize a later OAuth intent', () async {
    await _withAuthFixture((ctx, sdk, service, auth) async {
      sdk.rejectOldCode = true;
      final first = auth.signInWithOAuth(OAuthProvider.google);
      while (!sdk.calls.contains('browser-launched')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        await auth.handleAuthCallback(
          Uri.parse('io.supabase.travelgo://login-callback?code=old-code'),
        ),
        isFalse,
      );
      expect(await first, isFalse);
      expect(auth.currentUser, isNull);
      sdk.calls.clear();
      sdk.owner = lifecycle_fixtures.ownerB;
      final second = auth.signInWithOAuth(OAuthProvider.google);
      while (!sdk.calls.contains('browser-launched')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        await auth.handleAuthCallback(
          Uri.parse('io.supabase.travelgo://login-callback?code=current-code'),
        ),
        isTrue,
      );
      expect(await second, isTrue);
      expect(auth.currentUser!.id, lifecycle_fixtures.ownerB);
    });
  });
  test(
    'A05 dispose fences loader completion and waits it before close returns',
    () async {
      await local_fixtures.runWithStore((ctx) async {
        final sdk = _SdkFixture();
        final loader = Completer<LocalAccountLifecycleService>();
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => sdk.client.auth.currentSession,
          registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
        );
        final auth = AuthProvider(
          client: sdk.client,
          lifecycleLoader: () => loader.future,
        );
        try {
          var closed = false;
          final close = auth.close().then((_) {
            closed = true;
          });
          await Future<void>.delayed(Duration.zero);
          expect(closed, isFalse);
          loader.complete(service);
          await close;
          expect(auth.currentUser, isNull);
          expect(service.handle, isNull);
        } finally {
          if (!loader.isCompleted) loader.complete(service);
          await auth.close();
          await service.close();
          await sdk.client.dispose();
        }
      });
    },
  );
  for (final unsafe in ['missing', 'malformed', 'signedOut']) {
    test(
      'A01 unsafe $unsafe registry cannot publish restored account',
      () async {
        await _withAuthFixture(
          (ctx, sdk, service, auth) async {
            expect(auth.currentUser, isNull);
            expect(service.handle, isNull);
            expect(await ctx.store.listGuestDrafts(), hasLength(1));
          },
          configure: (ctx) async {
            final file = File(
              '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
            );
            if (unsafe == 'missing') {
              await file.delete();
            } else if (unsafe == 'malformed') {
              await file.writeAsString('{');
            } else {
              final data =
                  jsonDecode(await file.readAsString()) as Map<String, dynamic>;
              data['state'] = 'signedOut';
              await file.writeAsString(jsonEncode(data));
            }
          },
        );
      },
    );
  }
  testWidgets(
    'A05 Profile awaits logout, retains retry after user hidden, and guards unmount',
    (tester) async {
      await tester.runAsync(() async {
        await _withAuthFixture((ctx, sdk, service, auth) async {
          sdk.logoutEntered = Completer();
          sdk.logoutRelease = Completer();
          sdk.failLogout = true;
          await tester.pumpWidget(
            ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: const MaterialApp(home: CustomerProfileScreen()),
            ),
          );
          await tester.ensureVisible(find.text('Đăng xuất'));
          await tester.tap(find.text('Đăng xuất'));
          await sdk.logoutEntered!.future;
          final pending = auth.logout();
          await tester.pump();
          expect(find.text('Đã đăng xuất khỏi thiết bị này.'), findsNothing);
          expect(find.text('Đang đăng xuất…'), findsOneWidget);
          sdk.logoutRelease!.complete();
          expect(await pending, isFalse);
          await tester.pump();
          expect(find.text('Thử hoàn tất đăng xuất'), findsOneWidget);
          expect(find.text('Đã đăng xuất khỏi thiết bị này.'), findsNothing);
          sdk.failLogout = false;
          await tester.tap(find.text('Thử hoàn tất đăng xuất'));
          final retry = auth.logout();
          await tester.pumpWidget(const SizedBox.shrink());
          expect(await retry, isTrue);
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      });
    },
  );
  testWidgets(
    'A05 production root startup waits gate and logout clears provider RAM before frame',
    (tester) async {
      await tester.runAsync(() async {
        await local_fixtures.runWithStore((ctx) async {
          final sdk = _SdkFixture();
          await sdk.client.auth.setInitialSession(
            jsonEncode(sdk.sessionData(sdk.owner)),
          );
          final path = '${ctx.tempDir.path}/account_cache_lifecycle_v1.json';
          final pre = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            sessionReader: () => sdk.client.auth.currentSession,
            registryPath: path,
          );
          expect(
            await pre.establishAccount(freshAuthentication: true),
            isNotNull,
          );
          expect(await pre.sealForPause(), isTrue);
          await pre.close();
          var opens = 0;
          final runtime = LocalTripStoreRuntime(
            factory: () async {
              opens++;
              return ctx.store;
            },
            registryPathLoader: () async => path,
          );
          try {
            await tester.pumpWidget(
              TravelGoApp(
                localStoreRuntime: runtime,
                authClient: sdk.client,
                authCallbackLinks: const Stream<Uri>.empty(),
                initialAuthLinkLoader: () async => null,
              ),
            );
            final context = tester.element(find.byType(MaterialApp));
            final auth = Provider.of<AuthProvider>(context, listen: false);
            await auth.initialization;
            await tester.pump();
            expect(auth.currentUser?.id, sdk.owner);
            expect(opens, 1);
            final saved = Provider.of<SavedTripsProvider>(
              context,
              listen: false,
            );
            final trip = Provider.of<TripProvider>(context, listen: false);
            expect(saved.currentUserId, sdk.owner);
            final logout = auth.logout();
            expect(saved.currentUserId, isNull);
            expect(saved.trips, isEmpty);
            expect(trip.canPersistGuestDraft, isTrue);
            expect(await logout, isTrue);
            await tester.pumpWidget(const SizedBox.shrink());
            await auth.close();
            await runtime.close();
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            await sdk.client.dispose();
          }
        });
      });
    },
  );
  testWidgets(
    'A05 Guest can bypass blocked production bootstrap; late restoration stays hidden',
    (tester) async {
      await tester.runAsync(() async {
        await local_fixtures.runWithStore((ctx) async {
          final sdk = _SdkFixture();
          final pathReady = Completer<String>();
          final runtime = LocalTripStoreRuntime(
            factory: () async => ctx.store,
            registryPathLoader: () => pathReady.future,
          );
          try {
            await tester.pumpWidget(
              TravelGoApp(
                localStoreRuntime: runtime,
                authClient: sdk.client,
                authCallbackLinks: const Stream<Uri>.empty(),
                initialAuthLinkLoader: () async => null,
              ),
            );
            final context = tester.element(find.byType(MaterialApp));
            final auth = Provider.of<AuthProvider>(context, listen: false);
            await tester.pump(const Duration(seconds: 2));
            expect(find.text('Đang kiểm tra phiên đăng nhập'), findsOneWidget);
            await Future<void>.delayed(const Duration(milliseconds: 1700));
            await tester.pump();
            expect(find.text('Đang kiểm tra phiên đăng nhập'), findsOneWidget);
            await tester.tap(find.text('Tiếp tục với Guest'));
            await tester.pump();
            expect(auth.isGuest, isTrue);
            pathReady.complete(
              '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
            );
            await auth.initialization;
            await tester.pump();
            expect(auth.currentUser, isNull);
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.byType(MainNavigationShell), findsOneWidget);
            await tester.pumpWidget(const SizedBox.shrink());
            await auth.close();
            await runtime.close();
            expect(tester.takeException(), isNull);
          } finally {
            if (!pathReady.isCompleted) {
              pathReady.complete(
                '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            await sdk.client.dispose();
          }
        });
      });
    },
  );
  test('A01 matching sealed startup publishes only after local gate, no verifier call', () async {
    await _withAuthFixture((ctx, sdk, service, auth) async {
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser!.role, UserRole.customer);
      expect(sdk.calls, isEmpty);
      expect(
        (await ctx.store.listSnapshots(handle: service.handle!)).single.tripId,
        'A-snapshot',
      );
      expect(
        jsonDecode(
          await File('${ctx.tempDir.path}/account_cache_lifecycle_v1.json')
              .readAsString(),
        )['state'],
        'active',
      );
    });
  });
  test(
    'A01 active startup and unsolicited token event cannot mint fresh auth',
    () async {
      await _withAuthFixture((ctx, sdk, service, auth) async {
        expect(auth.isAuthenticated, isFalse);
        expect(await ctx.store.rawDb.query('account_trip_snapshots'), isEmpty);
        expect(await ctx.store.listGuestDrafts(), hasLength(1));
        await sdk.client.auth.setInitialSession(
          jsonEncode(sdk.sessionData(sdk.owner)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(auth.isAuthenticated, isFalse);
        expect(await auth.verifyOtp('123456'), isFalse);
      }, sealed: false);
    },
  );
  test(
    'A02 captured SDK logout must settle before success or B credentials',
    () async {
      await _withAuthFixture((ctx, sdk, service, auth) async {
        sdk.logoutEntered = Completer();
        sdk.logoutRelease = Completer();
        var clears = 0;
        auth.registerAccountInvalidator(() {
          clears++;
        });
        final logout = auth.logout();
        expect(identical(auth.logout(), logout), isTrue);
        expect(auth.currentUser, isNull);
        expect(clears, greaterThan(0));
        await sdk.logoutEntered!.future;
        expect(sdk.client.auth.currentSession, isNull);
        expect(auth.isLoggingOut, isTrue);
        sdk.owner = lifecycle_fixtures.ownerB;
        final loginB = auth.login(
          'fixture@example.invalid',
          'fixture-password',
        );
        await Future<void>.delayed(Duration.zero);
        expect(sdk.calls.where((c) => c == 'password'), isEmpty);
        sdk.logoutRelease!.complete();
        expect(await logout, isTrue);
        expect(await loginB, isTrue);
        expect(auth.currentUser!.id, lifecycle_fixtures.ownerB);
      });
    },
  );
  for (final fault in ['marker', 'sdk', 'preflight']) {
    test(
      'A02 $fault failure is truthful and Guest-visible retry can finish',
      () async {
        await _withAuthFixture(
          (ctx, sdk, service, auth) async {
            if (fault == 'sdk') sdk.failLogout = true;
            if (fault == 'marker') {
              ctx.store.onPurgeStepForTesting = (step) async {
                if (step == 'before_marker_txn') {
                  throw StateError('Controlled marker fault');
                }
              };
            }
            expect(await auth.logout(), isFalse);
            expect(auth.isGuest, isTrue);
            expect(auth.logoutNeedsRetry, isTrue);
            expect(auth.logoutErrorMessage, isNotNull);
            expect(
              await auth.login('fixture@example.invalid', 'fixture-password'),
              isFalse,
            );
            expect(await ctx.store.listGuestDrafts(), hasLength(1));
            if (fault == 'preflight') {
              expect(sdk.calls.where((c) => c == 'logout'), isEmpty);
              return;
            }
            sdk.failLogout = false;
            ctx.store.onPurgeStepForTesting = null;
            expect(await auth.logout(), isTrue);
            expect(auth.logoutNeedsRetry, isFalse);
          },
          configure: fault == 'preflight'
              ? (ctx) async {
                  // A directory at the registry path makes intent write fail on real IO.
                  final file = File(
                    '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
                  );
                  await file.delete();
                  await Directory(file.path).create();
                }
              : null,
        );
      },
    );
  }
  test(
    'A03 app-controlled refresh rotates proof while preserving snapshot',
    () async {
      await _withAuthFixture((ctx, sdk, service, auth) async {
        final proof = service.captureProof();
        expect(await auth.refreshSessionIfNeeded(), isTrue);
        expect(service.isCurrentProof(proof), isFalse);
        expect(auth.currentUser!.id, sdk.owner);
        expect(
          (await ctx.store.listSnapshots(handle: service.handle!))
              .single
              .tripId,
          'A-snapshot',
        );
      });
    },
  );
  test(
    'A03 expiry deadline without SDK event clears auth synchronously',
    () async {
      final deadlines = <_ManualTimer>[];
      await _withAuthFixture(
        (ctx, sdk, service, auth) async {
          expect(auth.isAuthenticated, isTrue);
          deadlines.last.fire();
          expect(auth.currentUser, isNull);
          expect(service.handle, isNull);
        },
        serviceTimer: (_, callback) {
          final timer = _ManualTimer(callback);
          deadlines.add(timer);
          return timer;
        },
      );
    },
  );
  test('A01 real SDK user-only response is not login; signup confirmation is separate', () async {
    await _withAuthFixture((ctx, sdk, service, auth) async {
      sdk.userOnly = true;
      expect(
        await auth.login('fixture@example.invalid', 'fixture-password'),
        isFalse,
      );
      expect(auth.isAuthenticated, isFalse);
      sdk.userOnly = false;
      sdk.confirmOnly = true;
      expect(
        await auth.register(
          fullName: 'Fixture',
          phone: '',
          email: 'fixture@example.invalid',
          password: 'fixture-password',
        ),
        isTrue,
      );
      expect(auth.isEmailConfirmationPending, isTrue);
      expect(auth.isAuthenticated, isFalse);
    });
  });
  test('A04 OAuth browser launch is not success, callback exchange owns credential queue', () async {
    await _withAuthFixture((ctx, sdk, service, auth) async {
      final oauth = auth.signInWithOAuth(OAuthProvider.google);
      // The browser launch records after the SDK creates its real PKCE verifier.
      while (!sdk.calls.contains('browser-launched')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(auth.isAuthenticated, isFalse);
      expect(
        auth.acceptsAuthCallback(
          Uri.parse(
            'io.supabase.travelgo://login-callback?access_token=fixture',
          ),
        ),
        isFalse,
      );
      final callback = Uri.parse(
        'io.supabase.travelgo://login-callback?code=current-code',
      );
      await auth.handleAppLifecycleState(AppLifecycleState.inactive);
      await auth.handleAppLifecycleState(AppLifecycleState.paused);
      sdk.exchangeEntered = Completer();
      sdk.exchangeRelease = Completer();
      final handled = auth.handleAuthCallback(callback);
      await sdk.exchangeEntered!.future;
      expect(auth.acceptsAuthCallback(callback), isFalse);
      sdk.exchangeRelease!.complete();
      await auth.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(await oauth, isTrue);
      expect(await handled, isTrue);
      expect(sdk.calls.where((c) => c == 'pkce'), hasLength(1));
    });
  });
  for (final cancellation in ['guest', 'timeout', 'logout']) {
    test(
      'A04 $cancellation during running OAuth exchange waits actual SDK completion',
      () async {
        final timers = <_ManualTimer>[];
        await _withAuthFixture(
          (ctx, sdk, service, auth) async {
            final oauth = auth.signInWithOAuth(OAuthProvider.google);
            while (!sdk.calls.contains('browser-launched')) {
              await Future<void>.delayed(Duration.zero);
            }
            sdk.exchangeEntered = Completer();
            sdk.exchangeRelease = Completer();
            final uri = Uri.parse(
              'io.supabase.travelgo://login-callback?code=current-code',
            );
            final handled = auth.handleAuthCallback(uri);
            await sdk.exchangeEntered!.future;
            Future<bool>? logout;
            if (cancellation == 'guest') auth.continueAsGuest();
            if (cancellation == 'timeout') timers.last.fire();
            if (cancellation == 'logout') logout = auth.logout();
            expect(await oauth, isFalse);
            expect(await handled, isFalse);
            expect(auth.currentUser, isNull);
            expect(auth.acceptsAuthCallback(uri), isFalse);
            sdk.owner = lifecycle_fixtures.ownerB;
            final b = auth.login('fixture@example.invalid', 'fixture-password');
            await Future<void>.delayed(Duration.zero);
            expect(sdk.calls.where((c) => c == 'password'), isEmpty);
            sdk.exchangeRelease!.complete();
            if (logout != null) expect(await logout, isTrue);
            expect(await b, isTrue);
            expect(auth.currentUser!.id, lifecycle_fixtures.ownerB);
          },
          authTimer: (_, callback) {
            final timer = _ManualTimer(callback);
            timers.add(timer);
            return timer;
          },
        );
      },
    );
  }
  test(
    'A04 inactive-only resume keeps authority, cold callbacks are denied',
    () async {
      await _withAuthFixture((ctx, sdk, service, auth) async {
        await auth.handleAppLifecycleState(AppLifecycleState.inactive);
        expect(auth.currentUser, isNull);
        await auth.handleAppLifecycleState(AppLifecycleState.resumed);
        expect(auth.isAuthenticated, isTrue);
        expect(
          (await ctx.store.listSnapshots(handle: service.handle!)),
          hasLength(1),
        );
        expect(
          await auth.handleAuthCallback(
            Uri.parse('io.supabase.travelgo://login-callback?code=cold'),
          ),
          isFalse,
        );
      });
    },
  );
  test('A03 failed refresh restores only exact old credentials; revocation consumes permit', () async {
    await local_fixtures.runWithStore((ctx) async {
      var session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerA);
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
      );
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        await service.prepareSessionRefresh();
        expect(
          await service.completeSessionRefresh(sdkSucceeded: false),
          isNotNull,
        );
        await service.prepareSessionRefresh();
        session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerB);
        expect(
          await service.completeSessionRefresh(sdkSucceeded: true),
          isNull,
        );
        expect(service.handle, isNull);
        session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerA);
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        await service.prepareSessionRefresh();
        await service.revokeAccount();
        expect(
          await service.completeSessionRefresh(sdkSucceeded: true),
          isNull,
        );
      } finally {
        await service.close();
      }
    });
  });
  test(
    'A05 Guest choice cancels slow startup; closing waits actual loader',
    () async {
      await local_fixtures.runWithStore((ctx) async {
        final sdk = _SdkFixture();
        final loader = Completer<LocalAccountLifecycleService>();
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => sdk.client.auth.currentSession,
          registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
        );
        final auth = AuthProvider(
          client: sdk.client,
          lifecycleLoader: () => loader.future,
        );
        try {
          auth.continueAsGuest();
          expect(auth.isGuest, isTrue);
          loader.complete(service);
          await auth.initialization;
          expect(auth.currentUser, isNull);
          await auth.close();
          await sdk.client.auth.setInitialSession(
            jsonEncode(sdk.sessionData(sdk.owner)),
          );
          expect(auth.currentUser, isNull);
        } finally {
          if (!loader.isCompleted) loader.complete(service);
          await auth.close();
          await service.close();
          await sdk.client.dispose();
        }
      });
    },
  );
}

void _b62LifecycleTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'B6.2 same-owner refresh preserves snapshot and consumes private permit',
    () async {
      await local_fixtures.runWithStore((ctx) async {
        var session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerA);
        final service = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => session,
          registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
        );
        try {
          final handle = (await service.establishAccount(
            freshAuthentication: true,
          ))!;
          await ctx.store.replaceSnapshot(
            handle: handle,
            tripId: 'keep',
            payload: local_fixtures.createValidPayload(),
            fetchedAt: DateTime.now().toUtc(),
          );
          final old = service.captureProof();
          await service.prepareSessionRefresh();
          session = session.copyWith(accessToken: 'refreshed-fixture');
          session.expiresAt = old.expiresAt + 3600;
          final refreshed = await service.completeSessionRefresh(
            sdkSucceeded: true,
          );
          expect(refreshed, isNotNull);
          expect(service.isCurrentProof(old), isFalse);
          expect(
            (await ctx.store.listSnapshots(handle: refreshed!)).single.tripId,
            'keep',
          );
          expect(
            await service.completeSessionRefresh(sdkSucceeded: true),
            isNull,
          );
        } finally {
          await service.close();
        }
      });
    },
  );
  test('B6.2 inactive -> paused -> resumed retains safe snapshot without verifier network', () async {
    await local_fixtures.runWithStore((ctx) async {
      final session = lifecycle_fixtures.sessionFor(lifecycle_fixtures.ownerA);
      var verifications = 0;
      final service = LocalAccountLifecycleService(
        storeLoader: () async => ctx.store,
        sessionReader: () => session,
        registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
        verifySubject: (_) async {
          verifications++;
          return session.user.id;
        },
      );
      try {
        expect(
          await service.establishAccount(freshAuthentication: true),
          isNotNull,
        );
        await service.suspendForegroundContext();
        expect(service.handle, isNull);
        expect(await service.sealForPause(), isTrue);
        expect(await service.resumeForegroundContext(), isNotNull);
        expect(verifications, 1);
      } finally {
        await service.close();
      }
    });
  });
}
