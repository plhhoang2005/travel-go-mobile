import '../../../../core/constants/api_constants.dart';

/// Configuration for Ollama on this device, independent of cloud AI settings.
class LocalAiSettings {
  static const defaultPrompt =
      'Bạn là Trợ lý du lịch TravelGO. Luôn trả lời cô đọng, súc tích dưới 100 từ bằng tiếng Việt. '
      'Với các câu hỏi dài, kể chuyện hoặc lịch trình, hãy tóm tắt các ý chính trong 2-3 câu ngắn gọn '
      'sao cho câu trả lời luôn trọn vẹn trong giới hạn độ dài, tuyệt đối không viết dở dang. '
      'Khi thiếu dữ liệu về giá, giờ mở cửa hoặc địa điểm, hãy nói rõ giới hạn. '
      'Không tự nhận đã tìm Internet hoặc thay đổi lịch trình.';

  final String baseUrl;
  final String modelName;
  final String systemPrompt;
  final double temperature;
  final int dailyQuota;
  final bool isChatbotEnabled;

  LocalAiSettings({
    String baseUrl = ApiConstants.localOllamaHost,
    String modelName = ApiConstants.localOllamaModel,
    String systemPrompt = defaultPrompt,
    this.temperature = 0.7,
    this.dailyQuota = 10,
    this.isChatbotEnabled = true,
  }) : baseUrl = _normalizeUrl(baseUrl),
       modelName = modelName.trim(),
       systemPrompt = systemPrompt.trim() {
    if (this.modelName.isEmpty ||
        this.systemPrompt.isEmpty ||
        !temperature.isFinite ||
        temperature < 0 ||
        temperature > 1 ||
        dailyQuota <= 0 ||
        dailyQuota > 1000) {
      throw const FormatException(
        'Model, chỉ dẫn, độ sáng tạo hoặc hạn mức lượt hỏi không hợp lệ.',
      );
    }
  }

  static String _normalizeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Nhập địa chỉ Ollama dạng http://127.0.0.1:11434.',
      );
    }
    return uri.replace(path: '').toString();
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'modelName': modelName,
    'systemPrompt': systemPrompt,
    'temperature': temperature,
    'dailyQuota': dailyQuota,
    'isChatbotEnabled': isChatbotEnabled,
  };

  factory LocalAiSettings.fromJson(Map<String, dynamic> json) =>
      LocalAiSettings(
        baseUrl: json['baseUrl'] as String,
        modelName: json['modelName'] as String,
        systemPrompt: json['systemPrompt'] as String,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        dailyQuota: (json['dailyQuota'] as num?)?.toInt() ?? 10,
        isChatbotEnabled: json['isChatbotEnabled'] as bool? ?? true,
      );
}
