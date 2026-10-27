import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';

void main() {
  group('TripApiService - Intelligent Dynamic Fallback', () {
    late TripApiService service;

    setUp(() {
      service = TripApiService();
    });

    test('Generates dynamic N-day itinerary matching exact requested numDays', () async {
      // 1 day
      final req1 = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 1,
        numPeople: 2,
        budgetVnd: 2000000,
        preferences: ['ẩm thực'],
        priority: 'balanced',
      );
      final res1 = await service.planTrip(req1);
      expect(res1.itineraryDays.length, 1);
      expect(res1.itineraryDays[0].day, 1);

      // 2 days
      final req2 = req1.copyWith(numDays: 2);
      final res2 = await service.planTrip(req2);
      expect(res2.itineraryDays.length, 2);
      expect(res2.itineraryDays[0].day, 1);
      expect(res2.itineraryDays[1].day, 2);

      // 5 days
      final req5 = req1.copyWith(numDays: 5);
      final res5 = await service.planTrip(req5);
      expect(res5.itineraryDays.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(res5.itineraryDays[i].day, i + 1);
        expect(res5.itineraryDays[i].activities, isNotEmpty);
      }
    });

    test('Routes directly to requested destination and uses destination-specific activities', () async {
      // Đà Lạt
      final reqDalat = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 2,
        budgetVnd: 5000000,
        preferences: ['núi', 'nghỉ dưỡng'],
        priority: 'balanced',
        destinationId: 'da-lat',
        destinationName: 'Đà Lạt',
      );
      final resDalat = await service.planTrip(reqDalat);
      expect(resDalat.winnerId, 'da-lat');
      expect(resDalat.topDestinations.first.id, 'da-lat');
      // Must NOT contain Đà Nẵng specific attractions like Bà Nà Hills
      final dalatTitles = resDalat.itineraryDays
          .expand((d) => d.activities)
          .map((a) => a.title)
          .join(' ');
      expect(dalatTitles.contains('Bà Nà'), isFalse);
      expect(dalatTitles.toLowerCase().contains('đà lạt') ||
             dalatTitles.toLowerCase().contains('hồ xuân hương') ||
             dalatTitles.toLowerCase().contains('langbiang') ||
             dalatTitles.toLowerCase().contains('chợ đêm'), isTrue);

      // Phú Quốc
      final reqPhuQuoc = PlanTripRequest(
        origin: 'Hà Nội',
        numDays: 4,
        numPeople: 2,
        budgetVnd: 10000000,
        preferences: ['biển'],
        priority: 'comfortable',
        destinationId: 'phu-quoc',
        destinationName: 'Phú Quốc',
      );
      final resPhuQuoc = await service.planTrip(reqPhuQuoc);
      expect(resPhuQuoc.winnerId, 'phu-quoc');
      final pqTitles = resPhuQuoc.itineraryDays
          .expand((d) => d.activities)
          .map((a) => a.title)
          .join(' ');
      expect(pqTitles.toLowerCase().contains('phú quốc') ||
             pqTitles.toLowerCase().contains('bãi sao') ||
             pqTitles.toLowerCase().contains('hòn thơm') ||
             pqTitles.toLowerCase().contains('biển'), isTrue);
    });

    test('Adapts budget breakdown according to companionType', () async {
      final reqFamily = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 4,
        budgetVnd: 16000000,
        preferences: ['nghỉ dưỡng', 'ẩm thực'],
        priority: 'balanced',
        companionType: 'family',
      );
      final resFamily = await service.planTrip(reqFamily);
      expect(resFamily.budgetBreakdown, isNotNull);

      final reqSolo = reqFamily.copyWith(
        numPeople: 1,
        budgetVnd: 4000000,
        companionType: 'solo',
      );
      final resSolo = await service.planTrip(reqSolo);
      expect(resSolo.budgetBreakdown, isNotNull);

      // Family reserves more percentage for accommodation & safety margin
      final familySafetyRatio = resFamily.budgetBreakdown!.remainingSafetyMargin / reqFamily.budgetVnd;
      final soloSafetyRatio = resSolo.budgetBreakdown!.remainingSafetyMargin / reqSolo.budgetVnd;
      expect(familySafetyRatio, greaterThanOrEqualTo(soloSafetyRatio));
    });

    test('Fallback transparency flag and data sources are preserved (Law 3)', () async {
      final req = PlanTripRequest.presetMinh();
      final res = await service.planTrip(req);
      expect(res.dataSources['status'], contains('FALLBACK'));
      expect(res.topDestinations, isNotEmpty);
      expect(res.transportOptions, isNotEmpty);
      expect(res.itineraryDays, isNotEmpty);
    });
  });
}
