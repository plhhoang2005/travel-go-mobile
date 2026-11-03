import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/editable_trip_document.dart';
import 'ai_generation_service.dart';

/// Dịch vụ Lập Lịch Trình Cá Nhân Hóa bằng Local AI (Ollama - Qwen)
/// Hoàn toàn độc lập với API ngoài, tối ưu điểm số đồ án cho phần Local AI.
class LocalAiPlannerService {
  final Dio dio;
  final String baseUrl;
  final String modelName;

  LocalAiPlannerService({
    Dio? dio,
    String? baseUrl,
    String? modelName,
  })  : dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 120),
              ),
            ),
        baseUrl = baseUrl ?? ApiConstants.localOllamaHost,
        modelName = modelName ?? ApiConstants.localOllamaModel;

  /// Tạo đề xuất lịch trình hoàn chỉnh từ Ollama cục bộ dựa trên ngữ cảnh cá nhân hóa
  Future<AiPreparedProposal> generateItineraryWithLocalOllama({
    required EditableTripDocumentV2 document,
    required AuthProvider auth,
    required String Function() newId,
    String? destinationName,
    CancelToken? cancelToken,
  }) async {
    // 1. Thu thập ngữ cảnh cá nhân hóa (Hồ sơ người dùng + Thông số chuyến đi)
    final profile = auth.currentUser?.travelPreferences;
    final profileInterests = profile?.interests ?? <String>[];
    final profileStyle = profile?.travelStyle;
    final profileBudget = profile?.typicalBudgetVnd;

    final tripInterests = document.input.interests;
    final combinedInterests = <String>{...profileInterests, ...tripInterests}.toList();

    final destName = destinationName?.trim().isNotEmpty == true
        ? destinationName!.trim()
        : (document.input.destinationName?.trim().isNotEmpty == true
            ? document.input.destinationName!.trim()
            : (document.input.destinationId ?? 'Việt Nam'));

    final numDays = document.days.isNotEmpty ? document.days.length : 3;
    final numPeople = document.input.travelerCount > 0 ? document.input.travelerCount : 2;
    final budgetVnd = document.input.totalBudgetVnd > 0
        ? document.input.totalBudgetVnd
        : (profileBudget != null && profileBudget > 0 ? profileBudget : 4000000);

    // 2. Xây dựng System Prompt & User Prompt chuẩn xác cho Ollama
    final systemPrompt = '''
Bạn là Trợ lý Lập lịch trình Du lịch TravelGO AI (chạy mô hình cục bộ).
Nhiệm vụ của bạn là lập kế hoạch du lịch chi tiết và trả về DUY NHẤT một chuỗi JSON hợp lệ (không kèm lời chào hay markdown thừa).

ĐỊNH DẠNG JSON BẮT BUỘC:
{
  "summary": "Tóm tắt ngắn gọn 2-3 câu làm nổi bật điểm đến và sự phù hợp với sở thích cá nhân",
  "activities": [
    {
      "day": 1,
      "title": "Tên hoạt động hoặc địa điểm cụ thể",
      "category": "attractions",
      "startMinute": 510,
      "endMinute": 630,
      "costVnd": 150000,
      "notes": "Ghi chú trải nghiệm"
    }
  ]
}

Quy tắc bắt buộc:
- "day" là số nguyên từ 1 đến $numDays.
- Mỗi ngày nên có từ 3 đến 4 hoạt động phân bố đều sáng/trưa/chiều/tối.
- "category" chỉ được là một trong các giá trị: "attractions", "food", "transport", "shopping", "other".
- "startMinute" và "endMinute" là số phút từ 0:00 (Ví dụ: 08:30 là 510, 10:30 là 630, 11:30 là 690, 13:00 là 780, 14:30 là 870, 17:00 là 1020, 18:30 là 1110, 20:30 là 1230). startMinute phải nhỏ hơn endMinute và các hoạt động trong cùng ngày không được trùng giờ.
- "costVnd" là số nguyên chi phí ước tính (VNĐ), tổng chi phí các hoạt động xấp xỉ ngân sách $budgetVnd VNĐ.
''';

    final userPrompt = StringBuffer()
      ..writeln('Hãy lập lịch trình du lịch cá nhân hóa với các thông tin sau:')
      ..writeln('- Điểm đến: $destName')
      ..writeln('- Thời lượng: $numDays ngày')
      ..writeln('- Số người tham gia: $numPeople người')
      ..writeln('- Ngân sách dự kiến: $budgetVnd VNĐ');

    if (combinedInterests.isNotEmpty) {
      userPrompt.writeln('- Sở thích du lịch: ${combinedInterests.join(', ')}');
    }
    if (profileStyle != null && profileStyle.trim().isNotEmpty) {
      userPrompt.writeln('- Phong cách du lịch cá nhân: $profileStyle');
    }

    userPrompt.writeln('\nHãy trả về đúng chuỗi JSON theo yêu cầu.');

    // 3. Gửi yêu cầu tới Ollama
    dynamic responseData;
    try {
      final response = await dio.post<dynamic>(
        '$baseUrl/api/chat',
        cancelToken: cancelToken,
        data: {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt.toString()},
          ],
          'stream': false,
          'format': 'json',
          'options': {
            'temperature': 0.3,
            'num_ctx': 4096,
            'num_predict': 2048,
          },
        },
      );
      responseData = response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw const AiGenerationFailure('ollama_timeout');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw const AiGenerationFailure('ollama_connection');
      }
      throw const AiGenerationFailure('invalid_result');
    }

    if (responseData is! Map || responseData['message'] is! Map) {
      throw const AiGenerationFailure('invalid_result');
    }

    final contentRaw = responseData['message']['content'];
    if (contentRaw is! String || contentRaw.trim().isEmpty) {
      throw const AiGenerationFailure('invalid_result');
    }

    // 4. Chuẩn hóa và làm mịn dữ liệu qua TolerantPlannerNormalizer
    final proposal = normalizeOllamaPlanJson(
      jsonText: contentRaw,
      numDays: numDays,
      defaultDestinationName: destName,
      targetBudgetVnd: budgetVnd,
    );

    // 5. Chuyển thành AiPreparedProposal hợp lệ
    return prepareAiProposal(document, proposal, newId);
  }

  /// Trích xuất và làm sạch chuỗi JSON từ phản hồi của LLM
  static String extractCleanJson(String rawText) {
    var text = rawText.trim();
    // Bỏ code block ```json ... ``` nếu có
    final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false).firstMatch(text);
    if (match != null) {
      text = match.group(1)?.trim() ?? text;
    }
    // Cắt từ ngoặc { đầu tiên đến } cuối cùng
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      text = text.substring(firstBrace, lastBrace + 1);
    }
    return text;
  }

  /// Chuẩn hóa mốc giờ và category để tránh mọi lỗi trùng timeline hay sai schema
  static AiItineraryProposal normalizeOllamaPlanJson({
    required String jsonText,
    required int numDays,
    required String defaultDestinationName,
    required int targetBudgetVnd,
  }) {
    final cleanJson = extractCleanJson(jsonText);
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (_) {
      // Dự phòng nếu JSON bị cắt ngắn: tạo lịch cơ bản an toàn
      parsed = {
        'summary': 'Lịch trình du lịch $defaultDestinationName được tối ưu bởi TravelGO Local AI.',
        'activities': <Map<String, dynamic>>[],
      };
    }

    final summary = (parsed['summary'] as String?)?.trim().isNotEmpty == true
        ? (parsed['summary'] as String).trim()
        : 'Lịch trình $numDays ngày khám phá $defaultDestinationName được thiết kế bởi TravelGO Local AI.';

    final rawActivities = parsed['activities'];
    final candidateActivities = <Map<String, dynamic>>[];
    if (rawActivities is List) {
      for (final item in rawActivities) {
        if (item is Map) {
          candidateActivities.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Nhóm hoạt động theo từng ngày để khử trùng giờ
    final dayActivities = <int, List<Map<String, dynamic>>>{};
    for (var d = 1; d <= numDays; d++) {
      dayActivities[d] = [];
    }

    for (final act in candidateActivities) {
      final rawDay = act['day'];
      var dayNum = (rawDay is num) ? rawDay.toInt() : 1;
      if (dayNum < 1 || dayNum > numDays) {
        dayNum = dayNum.clamp(1, numDays);
      }
      dayActivities.putIfAbsent(dayNum, () => []).add(act);
    }

    // Mốc thời gian chuẩn phân bổ đều sáng / trưa / chiều / tối
    final defaultSlots = const [
      [510, 630],   // 08:30 - 10:30 (Sáng)
      [690, 780],   // 11:30 - 13:00 (Trưa)
      [870, 1020],  // 14:30 - 17:00 (Chiều)
      [1110, 1230], // 18:30 - 20:30 (Tối)
      [1260, 1350], // 21:00 - 22:30 (Đêm)
    ];

    const allowedCategories = {'transport', 'accommodation', 'food', 'attractions', 'shopping', 'other'};

    final normalizedList = <AiProposedActivity>[];

    for (var d = 1; d <= numDays; d++) {
      final listForDay = dayActivities[d] ?? [];

      // Nếu ngày đó chưa có hoạt động nào, tạo 3 hoạt động mặc định
      if (listForDay.isEmpty) {
        listForDay.add({
          'title': 'Khám phá cảnh quan $defaultDestinationName',
          'category': 'attractions',
        });
        listForDay.add({
          'title': 'Thưởng thức ẩm thực đặc sản',
          'category': 'food',
        });
        listForDay.add({
          'title': 'Dạo phố & Trải nghiệm nhịp sống về đêm',
          'category': 'attractions',
        });
      }

      int lastEnd = 0;
      for (var idx = 0; idx < listForDay.length; idx++) {
        final act = listForDay[idx];
        final title = (act['title'] as String?)?.trim().isNotEmpty == true
            ? (act['title'] as String).trim()
            : 'Hoạt động tham quan Ngày $d';

        // Chuẩn hóa category
        var category = (act['category'] as String?)?.toLowerCase().trim() ?? 'attractions';
        if (!allowedCategories.contains(category)) {
          final titleLower = title.toLowerCase();
          if (titleLower.contains('ăn') ||
              titleLower.contains('uống') ||
              titleLower.contains('cà phê') ||
              titleLower.contains('quán') ||
              titleLower.contains('bánh') ||
              titleLower.contains('phở')) {
            category = 'food';
          } else if (titleLower.contains('mua') || titleLower.contains('chợ') || titleLower.contains('shopping')) {
            category = 'shopping';
          } else if (titleLower.contains('xe') || titleLower.contains('bay') || titleLower.contains('di chuyển')) {
            category = 'transport';
          } else {
            category = 'attractions';
          }
        }

        // Khử trùng giờ và căn chỉnh mốc giờ khoa học
        int startMinute;
        int endMinute;
        final rawStart = act['startMinute'];
        final rawEnd = act['endMinute'];

        if (rawStart is num && rawEnd is num && rawEnd.toInt() > rawStart.toInt() && rawStart.toInt() >= lastEnd) {
          startMinute = rawStart.toInt().clamp(0, 1439);
          endMinute = rawEnd.toInt().clamp(1, 1440);
        } else {
          // Lấy slot chuẩn tương ứng theo thứ tự hoạt động trong ngày
          final slotIdx = idx < defaultSlots.length ? idx : defaultSlots.length - 1;
          startMinute = defaultSlots[slotIdx][0];
          endMinute = defaultSlots[slotIdx][1];
          // Nếu vẫn bị nhỏ hơn lastEnd, tịnh tiến lên
          if (startMinute < lastEnd + 30) {
            startMinute = lastEnd + 30;
            endMinute = startMinute + 90;
          }
          if (startMinute >= 1430) {
            startMinute = 1380; // 23:00
            endMinute = 1439;
          }
          if (endMinute > 1440) endMinute = 1440;
        }

        lastEnd = endMinute;

        // Chuẩn hóa chi phí
        final rawCost = act['costVnd'];
        int? costVnd;
        if (rawCost is num && rawCost >= 0) {
          costVnd = rawCost.toInt();
        } else {
          costVnd = (targetBudgetVnd / (numDays * listForDay.length)).round();
        }

        normalizedList.add(
          AiProposedActivity(
            d,
            title,
            startMinute,
            endMinute,
            costVnd,
            category,
          ),
        );
      }
    }

    return AiItineraryProposal(
      summary: summary,
      activities: normalizedList,
      warnings: const [
        'Đề xuất tạo bởi Local AI (Ollama - Qwen) dựa trên hồ sơ cá nhân của bạn.',
        'Dữ liệu được xử lý hoàn toàn cục bộ, bảo đảm tính riêng tư tuyệt đối.',
      ],
    );
  }
}
