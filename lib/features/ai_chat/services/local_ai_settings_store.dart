import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
      return LocalAiSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
