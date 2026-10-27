import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/services/trip_list_classifier.dart';

void main() {
  group('TripListClassifier Unit Tests', () {
    // 2026-11-02T17:00:00Z in UTC -> +7 hours = 2026-11-03T00:00:00 in Vietnam!
    final nowUtc = DateTime.parse('2026-11-02T17:00:00Z');

    OwnedTripSummary makeSummary({
      String tripId = 'trip-1',
      String? startDate,
      String? endDate,
      String? rawStatus = 'planning',
      bool statusKnown = true,
    }) {
      return OwnedTripSummary(
        kind: OwnedTripKind.editableV2,
        tripId: tripId,
        ownerId: 'owner-1',
        title: 'Chuyến đi thử nghiệm',
        destinationName: 'Huế',
        createdAt: DateTime.parse('2026-10-24T00:00:00Z'),
        version: 1,
        startDate: startDate,
        endDate: endDate,
        rawStatus: rawStatus,
        statusKnown: statusKnown,
      );
    }

    test('classifies past trip correctly when endDate < Vietnam today', () {
      final trip = makeSummary(
        startDate: '2026-10-30',
        endDate: '2026-11-02',
      );
      final bucket = TripListClassifier.classify(trip, nowUtc: nowUtc);
      expect(bucket, TripListBucket.past);
    });

    test('classifies ongoing trip correctly when endDate == Vietnam today', () {
      final trip = makeSummary(
        startDate: '2026-11-01',
        endDate: '2026-11-03',
      );
      final bucket = TripListClassifier.classify(trip, nowUtc: nowUtc);
      expect(bucket, TripListBucket.upcomingOrOngoing);
    });

    test('classifies upcoming trip correctly when startDate > Vietnam today', () {
      final trip = makeSummary(
        startDate: '2026-11-05',
        endDate: '2026-11-08',
      );
      final bucket = TripListClassifier.classify(trip, nowUtc: nowUtc);
      expect(bucket, TripListBucket.upcomingOrOngoing);
    });

    test('accepts planning, booked, and completed status', () {
      for (final status in ['planning', 'booked']) {
        final trip = makeSummary(
          startDate: '2026-11-05',
          endDate: '2026-11-08',
          rawStatus: status,
        );
        expect(TripListClassifier.classify(trip, nowUtc: nowUtc), TripListBucket.upcomingOrOngoing);
      }

      final pastCompleted = makeSummary(
        startDate: '2026-10-20',
        endDate: '2026-10-25',
        rawStatus: 'completed',
      );
      expect(TripListClassifier.classify(pastCompleted, nowUtc: nowUtc), TripListBucket.past);
    });

    test('flags completed status on future/ongoing trip as insufficient due to contradiction', () {
      final futureCompleted = makeSummary(
        startDate: '2026-11-05',
        endDate: '2026-11-08',
        rawStatus: 'completed',
      );
      expect(TripListClassifier.classify(futureCompleted, nowUtc: nowUtc), TripListBucket.insufficient);

      final todayCompleted = makeSummary(
        startDate: '2026-11-01',
        endDate: '2026-11-03',
        rawStatus: 'completed',
      );
      expect(TripListClassifier.classify(todayCompleted, nowUtc: nowUtc), TripListBucket.insufficient);
    });

    test('classifies unknown rawStatus as insufficient', () {
      final trip = makeSummary(
        startDate: '2026-11-05',
        endDate: '2026-11-08',
        rawStatus: 'cancelled_by_user',
      );
      expect(TripListClassifier.classify(trip, nowUtc: nowUtc), TripListBucket.insufficient);
    });

    test('classifies missing dates as insufficient', () {
      final noStart = makeSummary(startDate: null, endDate: '2026-11-08');
      expect(TripListClassifier.classify(noStart, nowUtc: nowUtc), TripListBucket.insufficient);

      final noEnd = makeSummary(startDate: '2026-11-05', endDate: null);
      expect(TripListClassifier.classify(noEnd, nowUtc: nowUtc), TripListBucket.insufficient);

      final noDates = makeSummary(startDate: null, endDate: null);
      expect(TripListClassifier.classify(noDates, nowUtc: nowUtc), TripListBucket.insufficient);
    });

    test('classifies invalid date range (end before start or invalid format) as insufficient', () {
      final inverted = makeSummary(startDate: '2026-11-08', endDate: '2026-11-05');
      expect(TripListClassifier.classify(inverted, nowUtc: nowUtc), TripListBucket.insufficient);

      final malformed = makeSummary(startDate: 'not-a-date', endDate: '2026-11-05');
      expect(TripListClassifier.classify(malformed, nowUtc: nowUtc), TripListBucket.insufficient);
    });

    test('classifies unverified / statusKnown=false as insufficient', () {
      final cachedLegacy = makeSummary(
        startDate: '2026-11-05',
        endDate: '2026-11-08',
        statusKnown: false,
      );
      expect(TripListClassifier.classify(cachedLegacy, nowUtc: nowUtc), TripListBucket.insufficient);
    });
  });
}
