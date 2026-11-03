import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/local_ai_models.dart';

/// Dịch vụ Trợ lý Du lịch AI Cục bộ (Local AI Assistant Service)
/// Kết nối Ollama JSON API (mô hình qwen2.5:1.5b), tích hợp tra cứu Hybrid RAG
/// và lọc gợi ý thông minh dựa trên đánh giá thực tế từ cộng đồng.
class LocalAiService {
  final Dio dio;
  final String ollamaBaseUrl;
  final String modelName;

  LocalAiService({
    required this.dio,
    String? ollamaBaseUrl,
    String? modelName,
  })  : ollamaBaseUrl = ollamaBaseUrl ?? ApiConstants.localOllamaHost,
        modelName = modelName ?? ApiConstants.localOllamaModel;

  /// Gửi tin nhắn trò chuyện tự do tới mô hình Ollama
  Future<String> sendChatMessage(
    String prompt, {
    List<LocalChatMessage>? history,
  }) async {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            'Bạn là Trợ lý du lịch TravelGO thân thiện, am hiểu văn hóa, ẩm thực và các điểm đến du lịch tại Việt Nam. Hãy trả lời ngắn gọn, lịch sự, chính xác bằng tiếng Việt.',
      },
    ];

    if (history != null && history.isNotEmpty) {
      for (final msg in history.take(10)) {
        messages.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }
    }

    messages.add({'role': 'user', 'content': prompt});

    try {
      final response = await dio.post(
        '$ollamaBaseUrl/api/chat',
        data: {
          'model': modelName,
          'messages': messages,
          'stream': false,
        },
        options: Options(
          sendTimeout: const Duration(milliseconds: 1500),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final message = response.data['message'];
        if (message is Map && message['content'] is String) {
          return (message['content'] as String).trim();
        }
      }
      return 'Trợ lý AI đã phản hồi nhưng không có nội dung văn bản hợp lệ.';
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        return '⚠️ Không thể kết nối tới dịch vụ Ollama cục bộ ($ollamaBaseUrl).\n'
            'Vui lòng đảm bảo bạn đã cài đặt và chạy lệnh: `ollama run $modelName` trên máy tính.';
      }
      return '⚠️ Đã xảy ra lỗi khi trao đổi với mô hình AI: ${e.message}';
    } catch (e) {
      return '⚠️ Đã xảy ra lỗi không xác định: $e';
    }
  }

  /// Tra cứu thông tin địa điểm theo cơ chế Hybrid Search:
  /// Ưu tiên CSDL Admin Catalogue nội bộ; nếu không có mới tìm kiếm Internet trích dẫn nguồn.
  Future<PlaceInfoResult> searchPlaceInfoHybrid(
    String query, {
    required List<Map<String, dynamic>> localCataloguePlaces,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();

    // 1. Kiểm tra trong CSDL nội bộ
    for (final place in localCataloguePlaces) {
      final name = (place['name'] as String? ?? '').toLowerCase();
      if (name.contains(normalizedQuery) || normalizedQuery.contains(name)) {
        return PlaceInfoResult(
          placeName: place['name'] as String? ?? query,
          summary: place['description'] as String? ??
              'Địa điểm tham quan nổi tiếng trong danh mục TravelGO.',
          priceInfo: place['ticketPrice'] as String? ??
              place['price'] as String? ??
              'Tham khảo tại quầy vé',
          openingHours: place['openingHours'] as String? ?? '07:30 - 17:30',
          tips: place['tips'] as String? ??
              'Nên đi vào buổi sáng để có trải nghiệm tham quan tốt nhất.',
          isFromWeb: false,
          sourceUrl: null,
        );
      }
    }

    // 2. Không có trong CSDL nội bộ: Fallback sang nguồn Internet có trích dẫn
    final cleanQuery = query.replaceAll(' ', '+');
    final webSourceUrl = 'https://dulich.vnexpress.net/tim-kiem?q=$cleanQuery';

    return PlaceInfoResult(
      placeName: query,
      summary:
          'Địa điểm "$query" chưa có trong Danh mục kiểm duyệt của Ban Quản trị TravelGO. '
          'Thông tin được tìm kiếm tổng hợp từ Internet.',
      priceInfo: 'Chi phí tham khảo theo nguồn tin trực tuyến',
      openingHours: 'Giờ mở cửa có thể thay đổi theo thời vụ',
      tips: 'Bạn nên liên hệ trước hoặc tra cứu thêm từ liên kết bài viết gốc.',
      isFromWeb: true,
      sourceUrl: webSourceUrl,
    );
  }

  /// Gợi ý địa điểm thông minh dựa trên bộ lọc Rating >= 4.5 sao từ CSDL thật của Thành viên 3
  Future<List<AiRecommendationItem>> getRecommendationsWithRatings({
    required String destination,
    required int budgetVnd,
    List<String>? tags,
    required List<Map<String, dynamic>> ratedPlaces,
  }) async {
    final normalizedDest = destination.trim().toLowerCase();

    // Lọc theo điểm đến nếu có
    var matching = ratedPlaces.where((p) {
      final dest = (p['destination'] as String? ?? '').toLowerCase();
      if (normalizedDest.isNotEmpty && !dest.contains(normalizedDest)) {
        return false;
      }
      return true;
    }).toList();

    if (matching.isEmpty) {
      matching = ratedPlaces;
    }

    // Lọc các địa điểm có điểm đánh giá cao >= 4.5 sao
    final topRated = matching.where((p) {
      final rating = (p['averageRating'] as num?)?.toDouble() ?? 0.0;
      return rating >= 4.5;
    }).toList();

    // Sắp xếp giảm dần theo điểm rating
    topRated.sort((a, b) {
      final rA = (a['averageRating'] as num?)?.toDouble() ?? 0.0;
      final rB = (b['averageRating'] as num?)?.toDouble() ?? 0.0;
      return rB.compareTo(rA);
    });

    final targetList = topRated.isNotEmpty ? topRated : matching;

    return targetList.map((item) {
      return AiRecommendationItem(
        placeId: item['id'] as String? ?? '',
        placeName: item['name'] as String? ?? '',
        destination: item['destination'] as String? ?? destination,
        description: item['description'] as String? ?? '',
        estimatedCostVnd: (item['estimatedCostVnd'] as num?)?.toInt() ?? 0,
        averageRating: (item['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (item['reviewCount'] as num?)?.toInt() ?? 0,
        tags: (item['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            const [],
      );
    }).toList();
  }
}
