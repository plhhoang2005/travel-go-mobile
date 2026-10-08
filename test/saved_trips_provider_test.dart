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
  });
}
