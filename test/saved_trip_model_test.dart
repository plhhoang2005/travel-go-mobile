import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';

void main() {
  group('SavedTrip Model Tests (R03, DB-001)', () {
    test('fromJson reads primary ai_plan_data from database trips table', () {
      final json = {
        'id': 'trip-uuid-1',
        'user_id': 'user-uuid-1',
        'title': 'Khám phá Đà Nẵng',
        'destination_name': 'Đà Nẵng',
        'num_days': 4,
        'budget_total': 6500000.0,
        'status': 'planning',
        'ai_plan_data': {
          'days': [
            {'day': 1, 'activity': 'Bà Nà Hills'}
          ]
        },
        'created_at': '2026-10-08T10:00:00.000Z',
      };

      final model = SavedTrip.fromJson(json);

      expect(model.id, 'trip-uuid-1');
      expect(model.userId, 'user-uuid-1');
      expect(model.title, 'Khám phá Đà Nẵng');
      expect(model.destinationName, 'Đà Nẵng');
      expect(model.numDays, 4);
      expect(model.budgetTotal, 6500000.0);
      expect(model.status, 'planning');
      expect(model.tripPlanData['days'], isNotEmpty);
    });

    test('fromJson falls back to legacy trip_plan_data for old cached fixtures', () {
      final legacyJson = {
        'id': 'legacy-trip-2',
        'user_id': 'user-uuid-2',
        'title': 'Du lịch Phú Quốc',
        'destination_name': 'Phú Quốc',
        'trip_plan_data': {
          'itinerary': ['Bãi Sao', 'Hòn Thơm']
        },
      };

      final model = SavedTrip.fromJson(legacyJson);

      expect(model.id, 'legacy-trip-2');
      expect(model.destinationName, 'Phú Quốc');
      expect(model.tripPlanData['itinerary'], contains('Bãi Sao'));
    });

    test('toJson outputs ai_plan_data matching Supabase PostgreSQL schema', () {
      final trip = SavedTrip(
        id: 'trip-123',
        userId: 'user-456',
        title: 'Chuyến đi Hà Nội',
        destinationName: 'Hà Nội',
        numDays: 3,
        budgetTotal: 4000000,
        tripPlanData: {'focus': 'Ẩm thực phố cổ'},
        createdAt: DateTime.now(),
      );

      final jsonForInsert = trip.toJson(includeId: false);
      expect(jsonForInsert.containsKey('id'), isFalse);
      expect(jsonForInsert['ai_plan_data'], equals({'focus': 'Ẩm thực phố cổ'}));
      expect(jsonForInsert['destination_name'], 'Hà Nội');
      expect(jsonForInsert['status'], 'planning');

      final jsonWithId = trip.toJson(includeId: true);
      expect(jsonWithId['id'], 'trip-123');
    });

    test('Lossless serialization roundtrip', () {
      final original = SavedTrip(
        id: 'roundtrip-id',
        userId: 'user-rt',
        title: 'Hành trình Sa Pa',
        destinationName: 'Sa Pa',
        numDays: 2,
        budgetTotal: 3000000,
        startDate: DateTime.parse('2026-11-01T08:00:00.000Z'),
        endDate: DateTime.parse('2026-11-03T18:00:00.000Z'),
        status: 'planning',
        tripPlanData: {
          'locations': ['Fansipan', 'Bản Cát Cát']
        },
        createdAt: DateTime.parse('2026-10-08T12:00:00.000Z'),
      );

      final serialized = original.toJson(includeId: true);
      final deserialized = SavedTrip.fromJson(serialized);

      expect(deserialized.id, original.id);
      expect(deserialized.userId, original.userId);
      expect(deserialized.title, original.title);
      expect(deserialized.destinationName, original.destinationName);
      expect(deserialized.numDays, original.numDays);
      expect(deserialized.budgetTotal, original.budgetTotal);
      expect(deserialized.startDate, original.startDate);
      expect(deserialized.endDate, original.endDate);
      expect(deserialized.tripPlanData, original.tripPlanData);
    });

    test('Malformed or missing plan data defaults gracefully to empty map', () {
      final jsonNullPlan = {
        'id': 'empty-plan-1',
        'title': 'Empty plan trip',
      };

      final model = SavedTrip.fromJson(jsonNullPlan);
      expect(model.tripPlanData, isEmpty);
      expect(model.numDays, 3);
      expect(model.budgetTotal, 0.0);
    });
  });
}
