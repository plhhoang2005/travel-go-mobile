import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';

void main() {
  group('Local AI Models Tests', () {
    test('LocalChatMessage initializes with text, isUser, and timestamp', () {
      final now = DateTime.now();
      final msg = LocalChatMessage(
        text: 'Xin chào TravelGO',
        isUser: true,
        timestamp: now,
      );
      expect(msg.text, 'Xin chào TravelGO');
      expect(msg.isUser, isTrue);
      expect(msg.timestamp, now);
    });

    test('PlaceInfoResult supports local and web search sources with citations', () {
      final localInfo = PlaceInfoResult(
        placeName: 'Hồ Xuân Hương',
        summary: 'Hồ trung tâm thành phố Đà Lạt thơ mộng',
        priceInfo: 'Miễn phí',
        openingHours: 'Cả ngày',
        tips: 'Nên đi dạo vào sáng sớm hoặc hoàng hôn',
        isFromWeb: false,
      );
      expect(localInfo.isFromWeb, isFalse);
      expect(localInfo.sourceUrl, isNull);

      final webInfo = PlaceInfoResult(
        placeName: 'Đảo Điệp Sơn',
        summary: 'Con đường đi bộ giữa biển độc đáo',
        priceInfo: 'Vé cano khoảng 100.000 VNĐ',
        openingHours: '06:00 - 18:00',
        tips: 'Canh thủy triều rút để đi bộ',
        sourceUrl: 'https://vnexpress.net/diep-son',
        isFromWeb: true,
      );
      expect(webInfo.isFromWeb, isTrue);
      expect(webInfo.sourceUrl, 'https://vnexpress.net/diep-son');
    });

    test('AiRecommendationItem supports place details and real ratings', () {
      final rec = AiRecommendationItem(
        placeId: 'place-bana',
        placeName: 'Bà Nà Hills',
        destination: 'Đà Nẵng',
        description: 'Khu du lịch trên đỉnh núi Chúa với Cầu Vàng',
        estimatedCostVnd: 950000,
        averageRating: 4.8,
        reviewCount: 320,
        tags: const ['Nổi tiếng', 'Sống ảo', 'Gia đình'],
      );
      expect(rec.isTopRated, isTrue);
      expect(rec.averageRating, 4.8);
      expect(rec.reviewCount, 320);
    });
  });
}
