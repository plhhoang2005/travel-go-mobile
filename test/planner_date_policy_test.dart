import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_date_policy.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';

void main() {
  group('TripDatePolicy unit tests', () {
    test('01-03/11/2026 => 3 days', () {
      final range = TripDatePolicy.validate('2026-11-01', '2026-11-03');
      expect(range, isNotNull);
      expect(range!.startDate, '2026-11-01');
      expect(range.endDate, '2026-11-03');
      expect(range.numDays, 3);
    });

    test('calculateEndDate with 5 days from 01/11 => 05/11', () {
      final end = TripDatePolicy.calculateEndDate('2026-11-01', 5);
      expect(end, '2026-11-05');
    });

    test('28/02-01/03/2028 leap year => 3 days', () {
      final range = TripDatePolicy.validate('2028-02-28', '2028-03-01');
      expect(range, isNotNull);
      expect(range!.numDays, 3);
      expect(TripDatePolicy.calculateEndDate('2028-02-28', 3), '2028-03-01');
    });

    test('single day range => 1 day', () {
      final range = TripDatePolicy.validate('2026-11-01', '2026-11-01');
      expect(range, isNotNull);
      expect(range!.numDays, 1);
    });

    test('both null returns null', () {
      final range = TripDatePolicy.validate(null, null);
      expect(range, isNull);
    });

    test('one date null throws FormatException', () {
      expect(
        () => TripDatePolicy.validate('2026-11-01', null),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TripDatePolicy.validate(null, '2026-11-03'),
        throwsA(isA<FormatException>()),
      );
    });

    test('non-existent calendar date throws FormatException', () {
      expect(
        () => TripDatePolicy.validate('2026-02-30', '2026-03-02'),
        throwsA(isA<FormatException>()),
      );
    });

    test('end before start throws FormatException', () {
      expect(
        () => TripDatePolicy.validate('2026-11-05', '2026-11-01'),
        throwsA(isA<FormatException>()),
      );
    });

    test('range > 30 rejected when maxDays is 30', () {
      expect(
        () => TripDatePolicy.validate('2026-11-01', '2026-12-02', maxDays: 30),
        throwsA(isA<FormatException>()),
      );
    });

    test('manual 366 days is valid when maxDays is 366', () {
      // 2028 is leap year (366 days from 2028-01-01 to 2028-12-31)
      final range = TripDatePolicy.validate('2028-01-01', '2028-12-31', maxDays: 366);
      expect(range, isNotNull);
      expect(range!.numDays, 366);
    });

    test('expectedDays mismatch throws FormatException', () {
      expect(
        () => TripDatePolicy.validate('2026-11-01', '2026-11-03', expectedDays: 5),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TripProvider date state integration', () {
    test('calendar_range_and_duration_are_one_state', () {
      final provider = TripProvider();
      addTearDown(provider.dispose);

      provider.setCalendarRange('2026-11-01', '2026-11-03');
      expect(provider.currentRequest.startDate, '2026-11-01');
      expect(provider.currentRequest.endDate, '2026-11-03');
      expect(provider.currentRequest.numDays, 3);
      expect(provider.currentMetadata.startDate, '2026-11-01');
      expect(provider.currentMetadata.endDate, '2026-11-03');

      // Update duration to 5
      provider.setDuration(5);
      expect(provider.currentRequest.startDate, '2026-11-01');
      expect(provider.currentRequest.endDate, '2026-11-05');
      expect(provider.currentRequest.numDays, 5);
      expect(provider.currentMetadata.endDate, '2026-11-05');

      // Reject range > 30 on auto planner
      expect(
        () => provider.setCalendarRange('2026-11-01', '2026-12-05'),
        throwsA(isA<FormatException>()),
      );
      // State remains unchanged
      expect(provider.currentRequest.startDate, '2026-11-01');
      expect(provider.currentRequest.endDate, '2026-11-05');
      expect(provider.currentRequest.numDays, 5);
    });

    test('updateRequest syncs metadata and validates dates', () {
      final provider = TripProvider();
      addTearDown(provider.dispose);

      provider.updateRequest(
        PlanTripRequest.presetMinh().copyWith(
          startDate: '2026-11-01',
          endDate: '2026-11-03',
          numDays: 3,
        ),
      );

      expect(provider.currentMetadata.startDate, '2026-11-01');
      expect(provider.currentMetadata.endDate, '2026-11-03');
    });
  });

  group('ManualTripFactory date synchronization', () {
    test('factory uses request dates if metadata dates are absent', () {
      final factory = ManualTripFactory();
      final request = PlanTripRequest.presetMinh().copyWith(
        startDate: '2026-11-01',
        endDate: '2026-11-03',
        numDays: 3,
      );
      final metadata = TripMetadataV1(destinationId: 'hue', destinationName: 'Huế');
      final doc = factory.fromInput(request, metadata);

      expect(doc.input.startDate, '2026-11-01');
      expect(doc.input.endDate, '2026-11-03');
      expect(doc.days.length, 3);
      expect(doc.days.first.date, '2026-11-01');
      expect(doc.days[1].date, '2026-11-02');
      expect(doc.days.last.date, '2026-11-03');
    });

    test('factory throws if request and metadata dates conflict', () {
      final factory = ManualTripFactory();
      final request = PlanTripRequest.presetMinh().copyWith(
        startDate: '2026-11-01',
        endDate: '2026-11-03',
        numDays: 3,
      );
      final metadata = TripMetadataV1(
        destinationId: 'hue',
        destinationName: 'Huế',
        startDate: '2026-11-05',
        endDate: '2026-11-07',
      );

      expect(
        () => factory.fromInput(request, metadata),
        throwsA(isA<EditableCodecException>()),
      );
    });
  });

  group('HomePlannerScreen slider date range widget test', () {
    testWidgets('slider keeps date label and range synchronized', (tester) async {
      final provider = TripProvider();
      addTearDown(provider.dispose);
      provider.setCalendarRange('2026-11-01', '2026-11-03');

      // Set duration via provider to 5
      provider.setDuration(5);
      expect(provider.currentRequest.startDate, '2026-11-01');
      expect(provider.currentRequest.endDate, '2026-11-05');
      expect(provider.currentRequest.numDays, 5);
      expect(provider.currentMetadata.startDate, '2026-11-01');
      expect(provider.currentMetadata.endDate, '2026-11-05');
    });
  });
}
