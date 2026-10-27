import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserEntity? _user;
  bool _isDemo = false;

  void setAuthenticatedUser(String id, String email) {
    _user = UserEntity(
      id: id,
      email: email,
      fullName: 'Test User',
      phone: '0901234567',
      role: UserRole.customer,
    );
    _isDemo = false;
    notifyListeners();
  }

  void setDemoMinh() {
    _user = UserEntity.demoMinh();
    _isDemo = true;
    notifyListeners();
  }

  void setGuest() {
    _user = null;
    _isDemo = false;
    notifyListeners();
  }

  @override
  UserEntity? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  bool get isDemoSession => _isDemo;

  @override
  bool get isGuest => _user == null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSavedTripsProvider extends ChangeNotifier implements SavedTripsProvider {
  String? _userId;
  List<OwnedTripSummary> _visible = [];
  List<SavedTrip> _legacyTrips = [];
  bool _hasMore = false;
  int loadMoreCalls = 0;

  void setTrips(
    String userId,
    List<OwnedTripSummary> trips, {
    List<SavedTrip> legacyTrips = const [],
    bool hasMore = false,
  }) {
    _userId = userId;
    _visible = trips;
    _legacyTrips = legacyTrips;
    _hasMore = hasMore;
    notifyListeners();
  }

  @override
  String? get currentUserId => _userId;

  @override
  List<OwnedTripSummary> get visibleTrips => _visible;

  @override
  List<SavedTrip> get trips => _legacyTrips;

  @override
  List<AccountTripSnapshotRecord> get accountSnapshots => const [];

  @override
  bool get hasMoreTrips => _hasMore;

  @override
  bool get isLoading => false;

  @override
  String? get cacheErrorMessage => null;

  @override
  bool get requiresLifecycle => false;

  @override
  AccountCacheState get cacheState => AccountCacheState.online;

  @override
  Future<void> loadMoreTrips() async {
    loadMoreCalls++;
  }

  @override
  Future<void> loadTrips(String? userId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task Q1: MyTripsScreen Truthful States & Bucket Tests', () {
    testWidgets('Demo persona Minh never displays fake #TG-2026-001 or Furama or ĐÃ XÁC NHẬN card', (tester) async {
      final auth = FakeAuthProvider()..setDemoMinh();
      final trips = FakeSavedTripsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: trips),
          ],
          child: const MaterialApp(home: MyTripsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('TG-2026-001'), findsNothing);
      expect(find.textContaining('ĐÃ XÁC NHẬN'), findsNothing);
      expect(find.textContaining('Furama'), findsNothing);
      expect(find.textContaining('Persona Minh'), findsNothing);
    });

    testWidgets('Renders 3 truthful tabs and buckets trips by Vietnam dates', (tester) async {
      final auth = FakeAuthProvider()..setAuthenticatedUser('user-1', 'user1@example.com');
      final trips = FakeSavedTripsProvider();

      final upcomingTrip = OwnedTripSummary(
        kind: OwnedTripKind.editableV2,
        tripId: 'trip-upcoming',
        ownerId: 'user-1',
        title: 'Chuyến đi Hà Nội sắp tới',
        destinationName: 'Hà Nội',
        createdAt: DateTime.now(),
        version: 1,
        startDate: '2028-11-01',
        endDate: '2028-11-03',
        rawStatus: 'planning',
        statusKnown: true,
      );

      final pastTrip = OwnedTripSummary(
        kind: OwnedTripKind.editableV2,
        tripId: 'trip-past',
        ownerId: 'user-1',
        title: 'Chuyến đi Đà Nẵng năm ngoái',
        destinationName: 'Đà Nẵng',
        createdAt: DateTime.now(),
        version: 1,
        startDate: '2024-05-01',
        endDate: '2024-05-03',
        rawStatus: 'planning',
        statusKnown: true,
      );

      final unverifiedTrip = OwnedTripSummary(
        kind: OwnedTripKind.legacyV1,
        tripId: 'trip-unverified',
        ownerId: 'user-1',
        title: 'Chuyến đi chưa rõ ngày',
        destinationName: 'Huế',
        createdAt: DateTime.now(),
        version: null,
        startDate: null,
        endDate: null,
        rawStatus: null,
        statusKnown: false,
      );

      final unverifiedSavedTrip = SavedTrip(
        id: 'trip-unverified',
        userId: 'user-1',
        title: 'Chuyến đi chưa rõ ngày',
        destinationName: 'Huế',
        tripPlanData: const {},
      );

      trips.setTrips(
        'user-1',
        [upcomingTrip, pastTrip, unverifiedTrip],
        legacyTrips: [unverifiedSavedTrip],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: trips),
          ],
          child: const MaterialApp(home: MyTripsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Check tab bar labels with counts
      expect(find.text('Sắp/đang đi (1)'), findsOneWidget);
      expect(find.text('Đã qua ngày (1)'), findsOneWidget);
      expect(find.text('Chưa đủ thông tin (1)'), findsOneWidget);

      // On Tab 1 (Sắp/đang đi): only upcoming trip is shown
      expect(find.text('Chuyến đi Hà Nội sắp tới'), findsOneWidget);
      expect(find.text('Chuyến đi Đà Nẵng năm ngoái'), findsNothing);
      expect(find.text('Chuyến đi chưa rõ ngày'), findsNothing);

      // Switch to Tab 2 (Đã qua ngày)
      await tester.tap(find.text('Đã qua ngày (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Chuyến đi Hà Nội sắp tới'), findsNothing);
      expect(find.text('Chuyến đi Đà Nẵng năm ngoái'), findsOneWidget);
      expect(find.text('Chuyến đi chưa rõ ngày'), findsNothing);

      // Switch to Tab 3 (Chưa đủ thông tin)
      await tester.tap(find.text('Chưa đủ thông tin (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Chuyến đi Hà Nội sắp tới'), findsNothing);
      expect(find.text('Chuyến đi Đà Nẵng năm ngoái'), findsNothing);
      expect(find.text('Chuyến đi chưa rõ ngày'), findsOneWidget);
    });

    testWidgets('Empty tab displays "Xem thêm chuyến đi" button when hasMoreTrips is true', (tester) async {
      final auth = FakeAuthProvider()..setAuthenticatedUser('user-1', 'user1@example.com');
      final trips = FakeSavedTripsProvider();

      // Only 1 upcoming trip on page 1, zero past trips, but hasMoreTrips is true!
      final upcomingTrip = OwnedTripSummary(
        kind: OwnedTripKind.editableV2,
        tripId: 'trip-upcoming',
        ownerId: 'user-1',
        title: 'Chuyến đi sắp tới',
        destinationName: 'Hà Nội',
        createdAt: DateTime.now(),
        version: 1,
        startDate: '2028-11-01',
        endDate: '2028-11-03',
        rawStatus: 'planning',
        statusKnown: true,
      );

      trips.setTrips('user-1', [upcomingTrip], hasMore: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SavedTripsProvider>.value(value: trips),
          ],
          child: const MaterialApp(home: MyTripsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Tab 2 (Đã qua ngày) which has 0 trips
      await tester.tap(find.text('Đã qua ngày (0)'));
      await tester.pumpAndSettle();

      // Should display empty title AND "Xem thêm chuyến đi"
      expect(find.text('Chưa có chuyến đi đã qua ngày'), findsOneWidget);
      expect(find.text('Đã tải 1 chuyến · còn chuyến chưa tải'), findsOneWidget);
      expect(find.text('Xem thêm chuyến đi'), findsOneWidget);

      await tester.tap(find.text('Xem thêm chuyến đi'));
      await tester.pump();
      expect(trips.loadMoreCalls, 1);
    });
  });
}
