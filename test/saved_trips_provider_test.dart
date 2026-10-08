import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/trips_service.dart';

class FakeTripsService extends TripsService {
  List<SavedTrip> fakeTrips = [];
  bool shouldFailFetch = false;
  bool shouldFailSave = false;
  bool shouldFailDelete = false;
  Completer<List<SavedTrip>>? fetchCompleter;
  Completer<SavedTrip>? saveCompleter;

  @override
  Future<List<SavedTrip>> fetchTrips(String userId) async {
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
  Future<bool> deleteTrip({required String tripId, required String userId}) async {
    if (shouldFailDelete) {
      throw Exception('Delete failed on server');
    }
    fakeTrips.removeWhere((t) => t.id == tripId && t.userId == userId);
    return true;
  }
}

void main() {
  group('SavedTripsProvider & Server Ack Tests (R03, DB-001, INT-002)', () {
    late FakeTripsService fakeService;
    late SavedTripsProvider provider;

    setUp(() {
      fakeService = FakeTripsService();
      provider = SavedTripsProvider(service: fakeService);
    });

    test('saveTrip succeeds only after valid server ID acknowledgement', () async {
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
    });

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

    test('In-flight save for User A is ignored if session switches to User B', () async {
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
    });

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
  });
}
