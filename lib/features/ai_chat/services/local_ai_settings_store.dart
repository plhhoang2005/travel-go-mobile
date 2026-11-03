import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_constants.dart';
import '../../trip_planner/models/local_ai_settings.dart';

/// Persists one complete local configuration without touching legacy keys.
class LocalAiSettingsStore {
  static const preferencesKey = 'travelgo_local_ai_settings_v1';
  final SharedPreferences? prefs;
  String? _loadWarning;
  String? get loadWarning => _loadWarning;

  LocalAiSettingsStore({this.prefs});

  Future<SharedPreferences> _preferences() async =>
      prefs ?? await SharedPreferences.getInstance();

  Future<LocalAiSettings> load() async {
    _loadWarning = null;
    final preferences = await _preferences();
    try {
      final raw = preferences.getString(preferencesKey);
      if (raw == null) return LocalAiSettings();
      final loaded =
          LocalAiSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      var baseUrl = loaded.baseUrl;
      var prompt = loaded.systemPrompt;

      if (baseUrl == 'http://127.0.0.1:11434' &&
          ApiConstants.localOllamaHost != 'http://127.0.0.1:11434') {
        baseUrl = ApiConstants.localOllamaHost;
      }

      const legacyPrompt =
          'Bạn là Trợ lý du lịch TravelGO. Trả lời ngắn gọn bằng tiếng Việt. '
          'Khi thiếu dữ liệu về giá, giờ mở cửa hoặc địa điểm, hãy nói rõ giới hạn. '
          'Không tự nhận đã tìm Internet hoặc thay đổi lịch trình.';
      if (prompt == legacyPrompt) {
        prompt = LocalAiSettings.defaultPrompt;
      }

      return LocalAiSettings(
        baseUrl: baseUrl,
        modelName: loaded.modelName,
        systemPrompt: prompt,
        temperature: loaded.temperature,
        dailyQuota: loaded.dailyQuota,
        isChatbotEnabled: loaded.isChatbotEnabled,
      );
    } catch (_) {
      _loadWarning = 'Cấu hình AI đã lưu không hợp lệ. Đang dùng cấu hình mặc định; vui lòng kiểm tra lại.';
      return LocalAiSettings();
    }
  }

  Future<bool> writeJson(String json) async =>
      (await _preferences()).setString(preferencesKey, json);

  Future<void> save(LocalAiSettings settings) async {
    if (!await writeJson(jsonEncode(settings.toJson()))) {
      throw StateError('Không lưu được cấu hình AI trên thiết bị.');
    }
  }
}
