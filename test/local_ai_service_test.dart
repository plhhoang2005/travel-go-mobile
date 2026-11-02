import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

void main() {
  group('LocalAiService Tests', () {
    test('searchPlaceInfoHybrid prioritizes local catalogue place over web', () async {
      final service = LocalAiService(dio: Dio());
      final catalogue = [
        {
          'id': 'place-xuanhuong',
          'name': 'Hồ Xuân Hương',
          'description': 'Hồ nước trung tâm thơ mộng',
          'ticketPrice': 'Miễn phí',
          'openingHours': 'Cả ngày',
        },
        {
          'id': 'place-langbiang',
          'name': 'Đỉnh Langbiang',
          'description': 'Nóc nhà của Đà Lạt',
          'ticketPrice': '50.000 VNĐ',
          'openingHours': '07:00 - 17:00',
        },
      ];

      final result = await service.searchPlaceInfoHybrid(
        'Hồ Xuân Hương',
        localCataloguePlaces: catalogue,
      );

      expect(result.placeName, 'Hồ Xuân Hương');
      expect(result.isFromWeb, isFalse);
      expect(result.sourceUrl, isNull);
    });

    test('searchPlaceInfoHybrid falls back to web citations when place is absent locally', () async {
      final service = LocalAiService(dio: Dio());
      final catalogue = [
        {
          'id': 'place-xuanhuong',
          'name': 'Hồ Xuân Hương',
          'description': 'Hồ nước trung tâm',
        },
      ];

      final result = await service.searchPlaceInfoHybrid(
        'Đảo Điệp Sơn',
        localCataloguePlaces: catalogue,
      );

      expect(result.placeName, 'Đảo Điệp Sơn');
      expect(result.isFromWeb, isTrue);
      expect(result.sourceUrl, isNotNull);
    });

    test('getRecommendationsWithRatings filters and orders top rated places >= 4.5', () async {
      final service = LocalAiService(dio: Dio());
      final ratedPlaces = [
        {
          'id': 'p1',
          'name': 'Bà Nà Hills',
          'destination': 'Đà Nẵng',
          'description': 'Cầu Vàng nổi tiếng thế giới',
          'estimatedCostVnd': 950000,
          'averageRating': 4.8,
          'reviewCount': 120,
          'tags': ['Sống ảo', 'Nổi tiếng'],
        },
        {
          'id': 'p2',
          'name': 'Chợ Cồn',
          'destination': 'Đà Nẵng',
          'description': 'Thiên đường ẩm thực địa phương',
          'estimatedCostVnd': 150000,
          'averageRating': 4.6,
          'reviewCount': 85,
          'tags': ['Ẩm thực', 'Chợ'],
        },
        {
          'id': 'p3',
          'name': 'Quán Nước Vỉa Hè',
          'destination': 'Đà Nẵng',
          'description': 'Điểm mới mở',
          'estimatedCostVnd': 30000,
          'averageRating': 3.5,
          'reviewCount': 2,
          'tags': ['Bình dân'],
        },
      ];

      final recommendations = await service.getRecommendationsWithRatings(
        destination: 'Đà Nẵng',
        budgetVnd: 2000000,
        ratedPlaces: ratedPlaces,
      );

      expect(recommendations.length, 2);
      expect(recommendations.every((r) => r.isTopRated), isTrue);
      expect(recommendations.first.placeName, 'Bà Nà Hills');
      expect(recommendations.first.averageRating, 4.8);
      expect(recommendations.last.placeName, 'Chợ Cồn');
    });

    test('sendChatMessage returns friendly fallback message when offline', () async {
      final service = LocalAiService(
        dio: Dio(BaseOptions(connectTimeout: const Duration(milliseconds: 100))),
        ollamaBaseUrl: 'http://127.0.0.1:59999', // unreachable port
      );

      final reply = await service.sendChatMessage('Gợi ý cho tôi quán cà phê');
      expect(reply, contains('Ollama'));
    });
  });
}
