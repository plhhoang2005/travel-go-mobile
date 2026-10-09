// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/dashboard_result_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';

void main() {
  group('Auth Role Security & Epoch Tests (R02, DB-006)', () {
    User createFakeUser({
      required String id,
      required String email,
      Map<String, dynamic>? metadata,
    }) {
      return User(
        id: id,
        appMetadata: {},
        userMetadata: metadata ?? {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
    }

    test('Spoofed client userMetadata role=admin is ignored and defaults to customer', () async {
      final auth = AuthProvider();

      final fakeUser = createFakeUser(
        id: 'attacker-123',
        email: 'attacker@travelgo.vn',
        metadata: {
          'full_name': 'Attacker Eve',
          'role': 'admin', // Malicious client-supplied role
        },
      );

      auth.simulateSupabaseUser(fakeUser);

      expect(auth.isAuthenticated, isTrue);
      // Critical assertion: userMetadata.role cannot grant admin privileges!
      expect(auth.currentUser?.role, UserRole.customer);
      expect(auth.currentUser?.fullName, 'Attacker Eve');
      expect(auth.isDemoSession, isFalse);
    });

    test('Trusted role fetcher upgrades role to verified admin after server acknowledgement', () async {
      final completer = Completer<String?>();

      final auth = AuthProvider(
        trustedRoleFetcher: (userId) => completer.future,
      );

      final fakeUser = createFakeUser(
        id: 'real-admin-1',
        email: 'admin@travelgo.vn',
        metadata: {'full_name': 'Legit Admin'},
      );

      auth.simulateSupabaseUser(fakeUser);
      // Immediately customer
      expect(auth.currentUser?.role, UserRole.customer);

      // Complete server fetch with verified admin role
      completer.complete('admin');
      await Future<void>.delayed(Duration.zero);

      expect(auth.currentUser?.role, UserRole.admin);
    });

    test('Trusted role fetch failure retains customer role safely without breaking session', () async {
      final auth = AuthProvider(
        trustedRoleFetcher: (userId) async {
          throw Exception('Network timeout querying profiles table');
        },
      );

      final fakeUser = createFakeUser(
        id: 'customer-1',
        email: 'user@travelgo.vn',
        metadata: {'full_name': 'Normal User'},
      );

      auth.simulateSupabaseUser(fakeUser);
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.customer);
      expect(auth.errorMessage, isNull);
    });

    test('Late role fetch response from User A is ignored after logout (epoch guard)', () async {
      final userACompleter = Completer<String?>();

      final auth = AuthProvider(
        trustedRoleFetcher: (userId) {
          if (userId == 'user-a') {
            return userACompleter.future;
          }
          return Future.value('customer');
        },
      );

      final userA = createFakeUser(
        id: 'user-a',
        email: 'usera@travelgo.vn',
      );

      auth.simulateSupabaseUser(userA);
      expect(auth.currentUser?.id, 'user-a');

      // User logs out before User A's response arrives
      auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);

      // Late response arrives from User A
      userACompleter.complete('admin');
      await Future<void>.delayed(Duration.zero);

      // Epoch has changed: late response must be dropped!
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('Late role fetch response from User A is ignored after switch to User B', () async {
      final userACompleter = Completer<String?>();

      final auth = AuthProvider(
        trustedRoleFetcher: (userId) {
          if (userId == 'user-a') {
            return userACompleter.future;
          }
          return Future.value('partner');
        },
      );

      final userA = createFakeUser(id: 'user-a', email: 'a@travelgo.vn');
      final userB = createFakeUser(id: 'user-b', email: 'b@travelgo.vn');

      auth.simulateSupabaseUser(userA);
      final epochA = auth.authEpoch;

      // Switch to User B
      auth.simulateSupabaseUser(userB);
      expect(auth.authEpoch, greaterThan(epochA));
      expect(auth.currentUser?.id, 'user-b');

      // Late response for User A arrives
      userACompleter.complete('admin');
      await Future<void>.delayed(Duration.zero);

      // Current user should remain User B with verified partner role, NOT User A's admin role!
      expect(auth.currentUser?.id, 'user-b');
      expect(auth.currentUser?.role, UserRole.partner);
    });

    test('Demo session has explicit provenance and does not masquerade as live Supabase session', () async {
      final auth = AuthProvider();

      await auth.quickDemoLogin(UserRole.admin);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.admin);
      expect(auth.isDemoSession, isTrue);

      auth.logout();
      expect(auth.isDemoSession, isFalse);
    });

    test('updateProfile fails when unauthenticated', () async {
      final auth = AuthProvider();
      expect(auth.isAuthenticated, isFalse);

      final success = await auth.updateProfile(fullName: 'Hacker');
      expect(success, isFalse);
      expect(auth.errorMessage, contains('chưa đăng nhập'));
    });

    test('updateProfile in demo session safely updates permitted fields without altering role or email', () async {
      final auth = AuthProvider();
      await auth.quickDemoLogin(UserRole.customer);

      final originalRole = auth.currentUser!.role;
      final originalEmail = auth.currentUser!.email;

      final success = await auth.updateProfile(
        fullName: 'Minh Cập Nhật',
        phone: '0987654321',
        address: 'Quận 3, TP. Hồ Chí Minh',
      );

      expect(success, isTrue);
      expect(auth.currentUser?.fullName, 'Minh Cập Nhật');
      expect(auth.currentUser?.phone, '0987654321');
      expect(auth.currentUser?.address, 'Quận 3, TP. Hồ Chí Minh');
      // Role and email MUST be preserved
      expect(auth.currentUser?.role, originalRole);
      expect(auth.currentUser?.email, originalEmail);
    });

    test('UI-01: zero-row profile update must not report success or replace local name', () async {
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) async => http.Response(
                req.method == 'PATCH' ? '' : '[]',
                req.method == 'PATCH' ? 204 : 200,
                request: req,
                headers: {'content-type': 'application/json'},
              )),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com', metadata: {'full_name': 'Original'}));
      final result = await auth.updateProfile(fullName: 'Unsaved');
      expect(result, isFalse, reason: 'No server row acknowledged the update');
      expect(auth.currentUser!.fullName, 'Original');
    });

    test('UI-01: updateProfile payload strictly contains allowlisted fields and excludes role/email/id', () async {
      http.Request? capturedPatch;
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) async {
            if (req.method == 'PATCH') {
              capturedPatch = req;
              return http.Response(
                jsonEncode({
                  'id': 'a',
                  'full_name': 'Nguyen Van A',
                  'phone': '0901234567',
                  'avatar_url': 'https://example.com/avatar.png',
                  'address': 'TP.HCM',
                  'role': 'customer',
                }),
                200,
                request: req,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode([
                {
                  'id': 'a',
                  'full_name': 'Nguyen Van A',
                  'phone': '0901234567',
                  'avatar_url': 'https://example.com/avatar.png',
                  'address': 'TP.HCM',
                  'role': 'customer',
                }
              ]),
              200,
              request: req,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com', metadata: {'full_name': 'Original'}));
      final success = await auth.updateProfile(
        fullName: 'Nguyen Van A',
        phone: '0901234567',
        avatarUrl: 'https://example.com/avatar.png',
        address: 'TP.HCM',
      );
      expect(success, isTrue);
      expect(capturedPatch, isNotNull);
      final body = jsonDecode(capturedPatch!.body) as Map<String, dynamic>;
      expect(body.containsKey('full_name'), isTrue);
      expect(body.containsKey('phone'), isTrue);
      expect(body.containsKey('avatar_url'), isTrue);
      expect(body.containsKey('address'), isTrue);
      // STRICT ALLOWLIST: Absolutely forbidden fields!
      expect(body.containsKey('role'), isFalse);
      expect(body.containsKey('email'), isFalse);
      expect(body.containsKey('id'), isFalse);
    });

    test('UI-02: late profile error from A must not modify B state', () async {
      final pending = Completer<http.Response>();
      final reached = Completer<void>();
      http.Request? sent;
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) {
            sent = req;
            if (!reached.isCompleted) reached.complete();
            return pending.future;
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com'));
      final result = auth.updateProfile(fullName: 'A update');
      await reached.future;
      auth.simulateSupabaseUser(createFakeUser(id: 'b', email: 'b@example.com'));
      pending.complete(http.Response(
        '{"message":"A-only request failure","code":"42501"}',
        403,
        request: sent,
        headers: {'content-type': 'application/json'},
      ));
      expect(await result, isFalse);
      expect(auth.currentUser!.id, 'b');
      expect(auth.errorMessage, isNull, reason: 'A response must not set B error state');
      expect(auth.isLoading, isFalse);
    });

    test('UI-02: late profile error from A must not modify Guest state after logout', () async {
      final pending = Completer<http.Response>();
      final reached = Completer<void>();
      http.Request? sent;
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) {
            sent = req;
            if (!reached.isCompleted) reached.complete();
            return pending.future;
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com'));
      final result = auth.updateProfile(fullName: 'A update');
      await reached.future;
      auth.logout();
      pending.complete(http.Response(
        '{"message":"A network error","code":"PGRST"}',
        500,
        request: sent,
        headers: {'content-type': 'application/json'},
      ));
      expect(await result, isFalse);
      expect(auth.isGuest, isTrue);
      expect(auth.currentUser, isNull);
      expect(auth.errorMessage, isNull, reason: 'A error must not leak into Guest state');
      expect(auth.isLoading, isFalse);
    });

    test('UI-02: late profile success from A must not modify B state or B profile', () async {
      final pending = Completer<http.Response>();
      final reached = Completer<void>();
      http.Request? sent;
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) {
            sent = req;
            if (!reached.isCompleted) reached.complete();
            return pending.future;
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com', metadata: {'full_name': 'Original A'}));
      final result = auth.updateProfile(fullName: 'Late A');
      await reached.future;
      auth.simulateSupabaseUser(createFakeUser(id: 'b', email: 'b@example.com', metadata: {'full_name': 'User B'}));
      pending.complete(http.Response('', 204, request: sent, headers: {'content-type': 'application/json'}));
      expect(await result, isFalse);
      expect(auth.currentUser!.id, 'b');
      expect(auth.currentUser!.fullName, 'User B');
    });

    test('UI-02: network error sets errorMessage for current session and fails safely', () async {
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) async {
            throw http.ClientException('Network connection dropped');
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com'));
      final result = await auth.updateProfile(fullName: 'Will Fail');
      expect(result, isFalse);
      expect(auth.errorMessage, contains('Lỗi không xác định khi cập nhật hồ sơ'));
      expect(auth.isLoading, isFalse);
    });

    test('UI-01: PATCH zero rows with existing readable profile fails acknowledgement without separate GET', () async {
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) async {
            // If an independent GET were called, it would return this existing record.
            // But the mutation itself (PATCH) returns empty / 204.
            return http.Response(
              req.method == 'PATCH'
                  ? ''
                  : jsonEncode([{'id': 'a', 'full_name': 'Original', 'phone': '', 'address': '', 'role': 'customer'}]),
              req.method == 'PATCH' ? 204 : 200,
              request: req,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com'));
      final result = await auth.updateProfile(fullName: 'Requested new name');
      expect(result, isFalse, reason: 'GET of an unchanged existing row is not mutation acknowledgement');
      expect(auth.errorMessage, contains('Không thể xác thực bản ghi hồ sơ đã cập nhật'));
      expect(auth.isLoading, isFalse);
    });

    testWidgets('UI-03: production CustomerProfileScreen dialog can cancel after focus without disposed controller exception', (tester) async {
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) async => http.Response('[]', 200, request: req, headers: {'content-type': 'application/json'})),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com', metadata: {'full_name': 'Original'}));

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: CustomerProfileScreen()),
        ),
      );
      await tester.tap(find.text('Thông tin cá nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Thông Tin Cá Nhân'), findsOneWidget);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Thông Tin Cá Nhân'), findsNothing);
      expect(find.byType(CustomerProfileScreen), findsOneWidget);
    });

    testWidgets('UI-03: production CustomerProfileScreen dialog blocks system Back while saving, safe on delayed response', (tester) async {
      final updateCompleter = Completer<http.Response>();
      http.Request? capturedReq;
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((req) {
            capturedReq = req;
            return updateCompleter.future;
          }),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'a', email: 'a@example.com'));

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: CustomerProfileScreen()),
        ),
      );
      await tester.tap(find.text('Thông tin cá nhân'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu'));
      await tester.pump();

      // System back while saving
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();

      // Protected by PopScope
      expect(find.text('Thông Tin Cá Nhân'), findsOneWidget);

      // Delayed response succeeds
      updateCompleter.complete(http.Response(
        jsonEncode({'id': 'a', 'full_name': 'Updated A', 'phone': '', 'address': '', 'role': 'customer'}),
        200,
        request: capturedReq,
        headers: {'content-type': 'application/json'},
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Thông Tin Cá Nhân'), findsNothing);
      expect(find.byType(CustomerProfileScreen), findsOneWidget);
    });

    testWidgets('UI-03: production DashboardResultScreen save dialog can cancel after focus without exception', (tester) async {
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'user-a', email: 'a@example.com'));
      final tripProvider = TripProvider(apiService: _FakeTripApiService());
      await tripProvider.submitPlan();
      final tripsProvider = SavedTripsProvider(service: _FakeTripsService());
      await tripsProvider.loadTrips('user-a');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: tripsProvider),
          ],
          child: const MaterialApp(home: DashboardResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open save trip dialog
      await tester.tap(find.text('Lưu Chuyến Đi Này Lên Cloud'));
      await tester.pumpAndSettle();
      expect(find.text('Lưu Chuyến Đi Lên Cloud'), findsOneWidget);

      // Focus textfield and cancel
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Lưu Chuyến Đi Lên Cloud'), findsNothing);
      expect(find.byType(DashboardResultScreen), findsOneWidget);
    });

    testWidgets('UI-03: production DashboardResultScreen save dialog blocks Back while saving, safe on delayed completion', (tester) async {
      final auth = AuthProvider(
        client: SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        trustedRoleFetcher: (_) async => 'customer',
      );
      auth.simulateSupabaseUser(createFakeUser(id: 'user-a', email: 'a@example.com'));
      final saveCompleter = Completer<SavedTrip>();
      final tripProvider = TripProvider(apiService: _FakeTripApiService());
      await tripProvider.submitPlan();
      final tripsProvider = SavedTripsProvider(service: _FakeTripsService(completer: saveCompleter));
      await tripsProvider.loadTrips('user-a');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: tripsProvider),
          ],
          child: const MaterialApp(home: DashboardResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu Chuyến Đi Này Lên Cloud'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu'));
      await tester.pump();

      // System back while saving
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();

      // Blocked by PopScope
      expect(find.text('Lưu Chuyến Đi Lên Cloud'), findsOneWidget);

      saveCompleter.complete(SavedTrip(
        id: 'new-id',
        userId: 'user-a',
        title: 'Trip A',
        destinationName: 'Đà Nẵng',
        tripPlanData: const {},
        createdAt: DateTime.now(),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Lưu Chuyến Đi Lên Cloud'), findsNothing);
      expect(find.byType(DashboardResultScreen), findsOneWidget);
    });
  });
}

class _FakeTripsService extends TripsService {
  final Completer<SavedTrip>? completer;
  _FakeTripsService({this.completer});

  @override
  Future<SavedTrip> saveTrip(SavedTrip trip) async {
    if (completer != null) return completer!.future;
    return SavedTrip(
      id: 'mock-trip-id-1',
      userId: trip.userId,
      title: trip.title,
      destinationName: trip.destinationName,
      numDays: trip.numDays,
      budgetTotal: trip.budgetTotal,
      tripPlanData: trip.tripPlanData,
      createdAt: DateTime.now(),
    );
  }
}

class _FakeTripApiService extends TripApiService {
  @override
  Future<PlanTripResponse> planTrip(PlanTripRequest req) async {
    return PlanTripResponse(
      winnerId: 'da-nang',
      topDestinations: [
        DestinationCard(
          id: 'da-nang',
          name: 'Đà Nẵng',
          totalScore: 9.0,
          normalizedScores: const {},
          scoreContributions: const {},
          estimatedCostVnd: 4000000,
          weatherSource: 'Test',
          avgTempMax: 28,
          avgPrecipitation: 0,
          latitude: 16.0,
          longitude: 108.0,
          region: 'Trung Bộ',
        ),
      ],
      transportOptions: const [],
      itineraryDays: const [],
      budgetBreakdown: BudgetBreakdown(transport: 1, accommodation: 1, food: 1, attractions: 1, remainingSafetyMargin: 1),
      aiExplanation: 'Test explanation',
      dataSources: const {},
      assumptions: const [],
    );
  }
}
