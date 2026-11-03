import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/core/constants/api_constants.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_settings.dart';
import 'package:travelgo_mobile/features/ai_chat/services/local_ai_settings_store.dart';

class FailedSettingsStore extends LocalAiSettingsStore {
  @override
  Future<bool> writeJson(String json) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults match Qwen3 physical phone USB demo', () async {
    final settings = await LocalAiSettingsStore().load();
    expect(settings.baseUrl, ApiConstants.localOllamaHost);
    expect(settings.modelName, 'qwen3:4b-instruct-2507-q4_K_M');
    expect(settings.temperature, 0.7);
    expect(settings.dailyQuota, 10);
  });

  test(
    'settings roundtrip preserves custom host model prompt temperature',
    () async {
      final store = LocalAiSettingsStore();
      final settings = LocalAiSettings(
        baseUrl: 'http://10.0.2.2:11434/',
        modelName: 'qwen3:4b-instruct-2507-q4_K_M',
        systemPrompt: 'Trả lời bằng tiếng Việt.',
        temperature: 0.2,
        dailyQuota: 25,
      );
      await store.save(settings);
      final loaded = await store.load();
      expect(loaded.baseUrl, 'http://10.0.2.2:11434');
      expect(loaded.modelName, settings.modelName);
      expect(loaded.systemPrompt, settings.systemPrompt);
      expect(loaded.temperature, 0.2);
      expect(loaded.dailyQuota, 25);
      expect(store.loadWarning, isNull);
    },
  );

  for (final url in [
    'file:///tmp/model',
    'localhost:11434',
    'http://',
    'http://user:password@localhost:11434',
    'http://localhost:11434?key=secret',
    'http://localhost:11434#fragment',
    'http://localhost:11434/api/chat',
  ]) {
    test('rejects invalid base URL $url', () {
      expect(() => LocalAiSettings(baseUrl: url), throwsFormatException);
    });
  }

  test('rejects empty model prompt and invalid temperature', () {
    expect(() => LocalAiSettings(modelName: ' '), throwsFormatException);
    expect(() => LocalAiSettings(systemPrompt: ' '), throwsFormatException);
    for (final value in [-0.1, 1.1, double.nan, double.infinity]) {
      expect(() => LocalAiSettings(temperature: value), throwsFormatException);
    }
    for (final quota in [0, -1, 1001]) {
      expect(() => LocalAiSettings(dailyQuota: quota), throwsFormatException);
    }
  });

  test(
    'corrupt settings warn and recover without modifying legacy keys',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalAiSettingsStore.preferencesKey: '{broken',
        'admin_ai_selected_model': 'gemini-1.5-flash',
        'travelgo_ai_chat_sessions_v1': '[]',
      });
      final store = LocalAiSettingsStore();
      expect((await store.load()).modelName, 'qwen3:4b-instruct-2507-q4_K_M');
      expect(store.loadWarning, isNotNull);
      await store.save(LocalAiSettings());
      await store.load();
      expect(store.loadWarning, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('admin_ai_selected_model'), 'gemini-1.5-flash');
      expect(prefs.getString('travelgo_ai_chat_sessions_v1'), '[]');
    },
  );

  test('migrates legacy 127.0.0.1:11434 to ApiConstants.localOllamaHost', () async {
    SharedPreferences.setMockInitialValues({
      LocalAiSettingsStore.preferencesKey:
          '{"baseUrl":"http://127.0.0.1:11434","modelName":"qwen3:4b-instruct-2507-q4_K_M","systemPrompt":"Prompt","temperature":0.7}',
    });
    final store = LocalAiSettingsStore();
    final loaded = await store.load();
    expect(loaded.baseUrl, ApiConstants.localOllamaHost);
    expect(loaded.systemPrompt, 'Prompt');
  });

  test('upgrades legacy default prompt to concise default prompt', () async {
    const legacyPrompt =
        'Bạn là Trợ lý du lịch TravelGO. Trả lời ngắn gọn bằng tiếng Việt. '
        'Khi thiếu dữ liệu về giá, giờ mở cửa hoặc địa điểm, hãy nói rõ giới hạn. '
        'Không tự nhận đã tìm Internet hoặc thay đổi lịch trình.';
    SharedPreferences.setMockInitialValues({
      LocalAiSettingsStore.preferencesKey:
          '{"baseUrl":"https://example.com","modelName":"qwen3:4b-instruct-2507-q4_K_M","systemPrompt":"$legacyPrompt","temperature":0.7}',
    });
    final store = LocalAiSettingsStore();
    final loaded = await store.load();
    expect(loaded.systemPrompt, LocalAiSettings.defaultPrompt);
  });

  test(
    'failed preferences write throws instead of reporting success',
    () async {
      final store = FailedSettingsStore();
      await expectLater(store.save(LocalAiSettings()), throwsStateError);
      expect((await store.load()).modelName, 'qwen3:4b-instruct-2507-q4_K_M');
    },
  );
}
