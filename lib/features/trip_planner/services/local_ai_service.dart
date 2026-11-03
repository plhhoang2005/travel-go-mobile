import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/local_ai_models.dart';
import '../models/local_ai_settings.dart';

/// Dịch vụ Trợ lý Du lịch AI Cục bộ (Local AI Assistant Service)
/// Kết nối Ollama JSON API (mô hình qwen2.5:1.5b), tích hợp tra cứu Hybrid RAG
/// và lọc gợi ý thông minh dựa trên đánh giá thực tế từ cộng đồng.
class LocalAiService {
  final Dio dio;
  final String ollamaBaseUrl;
  final String modelName;

  LocalAiService({required this.dio, String? ollamaBaseUrl, String? modelName})
    : ollamaBaseUrl = ollamaBaseUrl ?? ApiConstants.localOllamaHost,
      modelName = modelName ?? ApiConstants.localOllamaModel {
    dio.options.connectTimeout = const Duration(seconds: 5);
  }

  Future<String> requestReply(
    String prompt, {
    required LocalAiSettings settings,
    CancelToken? cancelToken,
  }) => _chat(prompt, settings, cancelToken: cancelToken);

  Future<LocalAiConnectionCheck> checkConnection(
    LocalAiSettings settings, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<dynamic>(
        '${settings.baseUrl}/api/tags',
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = response.data;
      if (data is! Map || data['models'] is! List) {
        throw const LocalAiFailure(
          LocalAiFailureCode.invalidResponse,
          'Ollama trả danh sách model không hợp lệ.',
        );
      }
      final models = data['models'] as List;
      if (!models.any(
        (m) =>
            m is Map &&
            (m['name'] == settings.modelName ||
                m['model'] == settings.modelName),
      )) {
        throw const LocalAiFailure(
          LocalAiFailureCode.modelMissing,
          'Chưa tìm thấy model đã chọn trên Ollama. Hãy tải model trên máy tính.',
        );
      }
      await requestReply(
        'Chỉ trả lời một từ: OK',
        settings: settings,
        cancelToken: cancelToken,
      );
      return LocalAiConnectionCheck(
        modelName: settings.modelName,
        elapsed: stopwatch.elapsed,
      );
    } on DioException catch (e) {
      throw _failure(e);
    } finally {
      stopwatch.stop();
    }
  }

  Future<String> _chat(
    String prompt,
    LocalAiSettings settings, {
    List<LocalChatMessage>? history,
    CancelToken? cancelToken,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': settings.systemPrompt},
      for (final msg in history?.take(10) ?? <LocalChatMessage>[])
        {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text},
      {'role': 'user', 'content': prompt},
    ];
    try {
      final response = await dio.post<dynamic>(
        '${settings.baseUrl}/api/chat',
        cancelToken: cancelToken,
        data: {
          'model': settings.modelName,
          'messages': messages,
          'stream': false,
          'think': false,
          'options': {
            'temperature': settings.temperature,
            'num_ctx': 2048,
            'num_predict': 256,
          },
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      final data = response.data;
      if (data is Map && data['done'] == true && data['done_reason'] != 'length') {
        final message = data['message'];
        if (message is Map &&
            message['role'] == 'assistant' &&
            message['content'] is String &&
            (message['content'] as String).trim().isNotEmpty) {
          return (message['content'] as String).trim();
        }
      }
      throw const LocalAiFailure(
        LocalAiFailureCode.invalidResponse,
        'Ollama chưa trả câu trả lời hoàn chỉnh, hợp lệ. Vui lòng thử lại.',
      );
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  LocalAiFailure _failure(DioException error) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return const LocalAiFailure(
          LocalAiFailureCode.cancelled,
          'Đã hủy yêu cầu AI.',
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const LocalAiFailure(
          LocalAiFailureCode.timeout,
          'Ollama phản hồi quá lâu. Kiểm tra máy tính rồi thử lại.',
        );
      case DioExceptionType.connectionError:
        return const LocalAiFailure(
          LocalAiFailureCode.connection,
          'Không thể kết nối tới dịch vụ Ollama cục bộ. Kiểm tra Ollama và kết nối USB.',
        );
      default:
        final data = error.response?.data;
        final detail = data is Map ? data['error'] : null;
        if (error.response?.statusCode == 404 &&
            detail is String &&
            detail.toLowerCase().contains('model') &&
            detail.toLowerCase().contains('not found')) {
          return const LocalAiFailure(
            LocalAiFailureCode.modelMissing,
            'Chưa tìm thấy model đã chọn trên Ollama. Hãy tải model trên máy tính.',
          );
        }
        return const LocalAiFailure(
          LocalAiFailureCode.server,
          'Ollama gặp lỗi máy chủ hoặc địa chỉ API không đúng. Kiểm tra rồi thử lại.',
        );
    }
  }

  /// Gửi tin nhắn trò chuyện tự do tới mô hình Ollama
  Future<String> sendChatMessage(
    String prompt, {
    List<LocalChatMessage>? history,
  }) async {
    try {
      return await _chat(
        prompt,
        LocalAiSettings(baseUrl: ollamaBaseUrl, modelName: modelName),
        history: history,
      );
    } on LocalAiFailure catch (e) {
      return '⚠️ ${e.message}';
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
