import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/favorites/models/favorite_item_model.dart';
import 'package:travelgo_mobile/features/trips/models/saved_trip_model.dart';
import 'package:travelgo_mobile/features/home/models/destination_model.dart';
import 'package:travelgo_mobile/features/home/models/service_model.dart';
import 'package:travelgo_mobile/features/home/models/voucher_model.dart';
import 'package:travelgo_mobile/features/home/models/destination_weather.dart';
import 'package:travelgo_mobile/features/home/services/open_meteo_service.dart';

void main() {
  test('PlanTripRequest serialization test', () {
    final req = PlanTripRequest.presetMinh();
    expect(req.numDays, 3);
    expect(req.budgetVnd, 4000000);
    expect(req.priority, 'balanced');

    final json = req.toJson();
    expect(json['origin'], 'TP. Hồ Chí Minh');
    expect(json['budgetVnd'], 4000000);
  });

  test('PlanTripResponse deserialization test', () {
    final mockJson = {
      'winnerId': 'da-lat',
      'topDestinations': [
        {
          'id': 'da-lat',
          'name': 'Đà Lạt',
          'totalScore': 8.75,
          'normalizedScores': {'cost': 0.88},
          'scoreContributions': {'cost': 0.32},
          'estimatedCostVnd': 3500000,
          'weatherSource': 'Open-Meteo',
          'avgTempMax': 22.0,
          'avgPrecipitation': 0.0,
          'region': 'Tây Nguyên'
        }
      ],
      'transportOptions': [
        {
          'mode': 'bus',
          'displayName': 'Xe khách',
          'priceTotalVnd': 600000,
          'durationHours': 6.0,
          'comfortScore': 8,
          'isParetoOptimal': true,
          'tradeoffType': 'Tiết kiệm nhất',
          'recommendationReason': 'Tối ưu chi phí'
        }
      ],
      'itineraryDays': [
        {
          'day': 1,
          'title': 'Khám phá Đà Lạt',
          'activities': [
            {'time': '08:00', 'title': 'Hồ Xuân Hương', 'costVnd': 0, 'durationHours': 2.0}
          ]
        }
      ],
      'budgetBreakdown': {
        'transport': 1200000,
        'accommodation': 1200000,
        'food': 1000000,
        'attractions': 400000,
        'remainingSafetyMargin': 200000
      },
      'aiExplanation': 'Đà Lạt là điểm đến tối ưu nhất.',
      'dataSources': {'weather': 'Open-Meteo Live'},
      'assumptions': ['Thời tiết ổn định']
    };

    final res = PlanTripResponse.fromJson(mockJson);
    expect(res.winnerId, 'da-lat');
    expect(res.topDestinations.length, 1);
    expect(res.topDestinations.first.name, 'Đà Lạt');
    expect(res.transportOptions.first.isParetoOptimal, true);
    expect(res.budgetBreakdown?.totalAllocated, 3800000);
    expect(res.isFallback, false);
  });

  test('FavoriteItem JSON serialization test', () {
    final item = FavoriteItem(
      id: 'fav-1',
      userId: 'usr-1',
      itemId: 'furama-resort',
      itemType: 'hotel',
      title: 'Furama Resort Đà Nẵng',
      location: 'Đà Nẵng',
      price: 2500000,
      rating: 4.8,
      createdAt: DateTime(2026, 9, 26),
    );

    final json = item.toJson();
    expect(json['user_id'], 'usr-1');
    expect(json['item_id'], 'furama-resort');
    expect(json['item_type'], 'hotel');
    expect(json['price'], 2500000);

    final parsed = FavoriteItem.fromJson({
      'id': 'fav-1',
      ...json,
      'created_at': '2026-09-26T12:00:00Z',
    });
    expect(parsed.title, 'Furama Resort Đà Nẵng');
    expect(parsed.rating, 4.8);
  });

  test('SavedTrip JSON serialization test', () {
    final trip = SavedTrip(
      id: 'trip-1',
      userId: 'usr-minh',
      title: 'Chuyến đi Đà Lạt 3N2Đ',
      destinationName: 'Đà Lạt',
      numDays: 3,
      budgetTotal: 3500000,
      tripPlanData: {'winnerId': 'da-lat'},
      createdAt: DateTime(2026, 9, 26),
    );

    final json = trip.toJson();
    expect(json['destination_name'], 'Đà Lạt');
    expect(json['num_days'], 3);
    expect(json['budget_total'], 3500000);

    final parsed = SavedTrip.fromJson({
      'id': 'trip-1',
      ...json,
      'created_at': '2026-09-26T12:00:00Z',
    });
    expect(parsed.title, 'Chuyến đi Đà Lạt 3N2Đ');
    expect(parsed.tripPlanData['winnerId'], 'da-lat');
  });

  test('DestinationModel serialization and fallback test', () {
    final dest = DestinationModel(
      id: 'da-nang',
      name: 'Đà Nẵng',
      region: 'Trung',
      description: 'Thành phố biển xinh đẹp',
      imageUrl: 'https://images.unsplash.com/sample.jpg',
      weatherCachedTemp: 28.5,
      isPopular: true,
    );

    final json = dest.toJson();
    expect(json['id'], 'da-nang');
    expect(json['name'], 'Đà Nẵng');
    expect(json['region'], 'Trung');
    expect(json['weather_cached_temp'], 28.5);

    final parsed = DestinationModel.fromJson(json);
    expect(parsed.id, 'da-nang');
    expect(parsed.name, 'Đà Nẵng');
    expect(parsed.region, 'Trung');

    final fallbacks = DestinationModel.presetFallbackList();
    expect(fallbacks.length, greaterThanOrEqualTo(6));
  });

  test('ServiceModel serialization and fallback test', () {
    final hotel = ServiceModel(
      id: 'furama-resort',
      destinationId: 'da-nang',
      serviceType: 'hotel',
      title: 'Furama Resort',
      basePrice: 2200000,
      rating: 4.8,
      reviewCount: 128,
      images: ['https://example.com/img1.jpg'],
      amenities: ['Hồ bơi vô cực', 'Giáp biển'],
      isFeatured: true,
    );

    final json = hotel.toJson();
    expect(json['id'], 'furama-resort');
    expect(json['base_price'], 2200000);
    expect(json['rating'], 4.8);

    final parsed = ServiceModel.fromJson(json);
    expect(parsed.primaryImage, 'https://example.com/img1.jpg');
    expect(parsed.amenities.length, 2);

    final hotelFallbacks = ServiceModel.presetHotelsFallback();
    expect(hotelFallbacks.isNotEmpty, isTrue);

    final tourFallbacks = ServiceModel.presetToursFallback();
    expect(tourFallbacks.isNotEmpty, isTrue);
  });

  test('VoucherModel serialization and discount display test', () {
    final voucherCash = VoucherModel(
      id: 'HELLO25',
      title: 'Ưu đãi chào bạn mới',
      discountAmount: 200000,
      minOrderValue: 1000000,
      expiryDate: DateTime(2026, 12, 31),
    );
    expect(voucherCash.discountDisplay, '200.000₫');

    final voucherPercent = VoucherModel(
      id: 'SUMMER2026',
      title: 'Ưu đãi hè',
      discountPercent: 10,
      expiryDate: DateTime(2026, 8, 31),
    );
    expect(voucherPercent.discountDisplay, '10%');

    final json = voucherCash.toJson();
    expect(json['id'], 'HELLO25');
    expect(json['discount_amount'], 200000);

    final parsed = VoucherModel.fromJson(json);
    expect(parsed.id, 'HELLO25');
    expect(parsed.discountAmount, 200000);

    final fallbacks = VoucherModel.presetFallbackList();
    expect(fallbacks.length, greaterThanOrEqualTo(2));
  });

  test('DestinationWeather WMO parsing and serialization test', () {
    final mockOpenMeteoJson = {
      'current': {
        'temperature_2m': 19.5,
        'relative_humidity_2m': 80,
        'weather_code': 2,
      }
    };

    final weather = DestinationWeather.fromOpenMeteoJson(mockOpenMeteoJson);
    expect(weather.temperature, 19.5);
    expect(weather.relativeHumidity, 80);
    expect(weather.weatherCode, 2);
    expect(weather.weatherDescription, 'Mây rải rác, mát mẻ');
    expect(weather.isExpired, isFalse);

    final rainWeather = DestinationWeather(
      temperature: 25.0,
      weatherCode: 61,
      fetchedAt: DateTime.now(),
    );
    expect(rainWeather.weatherDescription, 'Có mưa rào');

    final stormWeather = DestinationWeather(
      temperature: 27.0,
      weatherCode: 95,
      fetchedAt: DateTime.now(),
    );
    expect(stormWeather.weatherDescription, 'Có dông sét');

    final json = weather.toJson();
    expect(json['temperature'], 19.5);
    expect(json['weather_code'], 2);

    final fromJson = DestinationWeather.fromJson(json);
    expect(fromJson.temperature, 19.5);
  });

  test('OpenMeteoService coordinates coverage test', () {
    final coords = OpenMeteoService.destinationCoordinates;
    expect(coords.length, 14);
    expect(coords.containsKey('da-lat'), isTrue);
    expect(coords.containsKey('da-nang'), isTrue);
    expect(coords.containsKey('ha-noi'), isTrue);
    expect(coords.containsKey('tphcm'), isTrue);
    expect(coords.containsKey('phu-quoc'), isTrue);

    // Verify coordinates ranges for Vietnam (Lat: ~8.5 to ~23.5, Lng: ~102.0 to ~109.5)
    for (final entry in coords.entries) {
      final lat = entry.value.$1;
      final lng = entry.value.$2;
      expect(lat, inInclusiveRange(8.0, 24.0), reason: '${entry.key} latitude invalid');
      expect(lng, inInclusiveRange(102.0, 110.0), reason: '${entry.key} longitude invalid');
    }
  });

  testWidgets('TravelGO Mobile App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelGoApp());
    expect(find.text('TravelGO Mobile'), findsOneWidget);
    // Drain pending timers to cleanly finish widget test
    await tester.pumpAndSettle();
  });
}
