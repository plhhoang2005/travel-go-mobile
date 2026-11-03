import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/ai_chat/models/ai_chat_session.dart';
import 'package:travelgo_mobile/features/ai_chat/providers/ai_chat_provider.dart';
import 'package:travelgo_mobile/features/ai_chat/services/ai_chat_storage_service.dart';
import 'package:travelgo_mobile/features/ai_chat/services/local_ai_settings_store.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_settings.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

class FakeLocalAi extends LocalAiService {
  int calls = 0;
  LocalAiSettings? receivedSettings;
  Future<String> Function()? answer;
  FakeLocalAi() : super(dio: Dio());
  @override
  Future<String> requestReply(
    String prompt, {
    required LocalAiSettings settings,
    CancelToken? cancelToken,
  }) async {
    calls++;
    receivedSettings = settings;
    return answer == null ? 'Phản hồi thật từ fixture Ollama' : answer!();
  }
}

class FailingChatStorage extends AiChatStorageService {
  bool failUser = false;
  bool failAssistant = false;
  bool failSessions = false;
  @override
  Future<void> saveSessions(List<AiChatSession> sessions) async {
    if (failSessions) throw StateError('disk full');
    await super.saveSessions(sessions);
  }

  @override
  Future<void> saveMessages(String id, List<AiChatMessage> messages) async {
    if ((failUser && messages.isNotEmpty && messages.last.isUser) ||
        (failAssistant && messages.isNotEmpty && !messages.last.isUser)) {
      throw StateError('disk full');
    }
    await super.saveMessages(id, messages);
  }
}

class PausedChatStorage extends AiChatStorageService {
  final started = Completer<void>();
  final release = Completer<void>();
  bool pause = true;
  @override
  Future<void> saveMessages(String id, List<AiChatMessage> messages) async {
    if (pause && messages.isNotEmpty) {
      pause = false;
      started.complete();
      await release.future;
    }
    await super.saveMessages(id, messages);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'uses selected settings and real reply without static citations',
    () async {
      final store = LocalAiSettingsStore();
      await store.save(
        LocalAiSettings(baseUrl: 'http://localhost:11435', temperature: 0.3),
      );
      final service = FakeLocalAi();
      final provider = AiChatProvider(aiService: service, settingsStore: store);
      await provider.init();
      await provider.sendMessage('Đà Lạt');
      expect(provider.messages.last.content, 'Phản hồi thật từ fixture Ollama');
      expect(provider.messages.last.citations, isEmpty);
      expect(service.receivedSettings!.baseUrl, 'http://localhost:11435');
      expect(service.receivedSettings!.temperature, 0.3);
      expect(service.calls, 1);
      provider.dispose();
    },
  );

  test(
    'failure keeps question and retry never duplicates the user message',
    () async {
      final service = FakeLocalAi()
        ..answer = () async => throw const LocalAiFailure(
          LocalAiFailureCode.connection,
          'Không kết nối được Ollama',
        );
      final provider = AiChatProvider(aiService: service);
      await provider.init();
      await provider.sendMessage('Gợi ý Đà Lạt');
      expect(provider.messages, hasLength(1));
      expect(provider.lastFailure!.code, LocalAiFailureCode.connection);
      final userId = provider.messages.single.id;
      expect(provider.failedMessageId, userId);
      service.answer = () async => 'Đã kết nối lại';
      await provider.retryFailedMessage();
      expect(provider.messages, hasLength(2));
      expect(provider.messages.first.id, userId);
      expect(provider.lastFailure, isNull);
      expect(provider.isLoading, false);
      provider.dispose();
    },
  );

  for (final action in ['create', 'select', 'delete', 'cancel', 'dispose']) {
    test(
      '$action while waiting ignores late reply and preserves storage',
      () async {
        final service = FakeLocalAi();
        final provider = AiChatProvider(aiService: service);
        await provider.init();
        final oldId = provider.currentSession!.id;
        await provider.createNewSession(initialTitle: 'B');
        final newId = provider.currentSession!.id;
        await provider.selectSession(oldId);
        final gate = Completer<String>();
        final started = Completer<void>();
        service.answer = () {
          started.complete();
          return gate.future;
        };
        final sending = provider.sendMessage('Câu hỏi A');
        await started.future;
        await provider.sendMessage('Bấm gửi hai lần');
        expect(service.calls, 1);
        switch (action) {
          case 'create':
            await provider.createNewSession();
          case 'select':
            await provider.selectSession(newId);
          case 'delete':
            await provider.deleteSession(oldId);
          case 'cancel':
            provider.cancelPendingReply();
          case 'dispose':
            provider.dispose();
        }
        gate.complete('Câu trả lời cũ');
        await sending;
        if (action != 'dispose') {
          expect(provider.messages.where((m) => !m.isUser), isEmpty);
          expect(provider.isLoading, false);
          provider.dispose();
        }
        final stored = await AiChatStorageService().loadMessages(oldId);
        expect(stored.where((m) => !m.isUser), isEmpty);
        if (action == 'delete') expect(stored, isEmpty);
      },
    );
  }

  test(
    'user storage failure prevents inference and retry keeps single question',
    () async {
      final storage = FailingChatStorage();
      final service = FakeLocalAi();
      final provider = AiChatProvider(
        storageService: storage,
        aiService: service,
      );
      await provider.init();
      storage.failUser = true;
      await provider.sendMessage('Huế');
      expect(service.calls, 0);
      expect(provider.messages, hasLength(1));
      expect(provider.isLoading, false);
      expect(provider.lastFailure!.code, LocalAiFailureCode.storage);
      storage.failUser = false;
      await provider.retryFailedMessage();
      expect(service.calls, 1);
      expect(provider.messages.where((m) => m.isUser), hasLength(1));
      provider.dispose();
    },
  );

  test(
    'assistant save retry persists received reply without another inference',
    () async {
      final storage = FailingChatStorage();
      final service = FakeLocalAi();
      final provider = AiChatProvider(
        storageService: storage,
        aiService: service,
      );
      await provider.init();
      storage.failAssistant = true;
      await provider.sendMessage('Huế');
      expect(provider.messages, hasLength(2));
      expect(provider.lastFailure!.code, LocalAiFailureCode.storage);
      storage.failAssistant = false;
      await provider.retryFailedMessage();
      expect(provider.lastFailure, isNull);
      expect(service.calls, 1);
      expect(
        await storage.loadMessages(provider.currentSession!.id),
        hasLength(2),
      );
      provider.dispose();
    },
  );

  test(
    'settings changes apply to next request and initialization is idempotent',
    () async {
      final service = FakeLocalAi();
      final provider = AiChatProvider(aiService: service);
      await Future.wait([provider.init(), provider.init()]);
      expect(provider.sessions, hasLength(1));
      await LocalAiSettingsStore().save(LocalAiSettings(temperature: 0.1));
      await provider.reloadAiSettings();
      await provider.sendMessage('Huế');
      expect(service.receivedSettings!.temperature, 0.1);
      provider.dispose();
    },
  );

  test(
    'deleting during slow initial write cannot resurrect deleted chat',
    () async {
      final storage = PausedChatStorage();
      final service = FakeLocalAi();
      final provider = AiChatProvider(
        storageService: storage,
        aiService: service,
      );
      await provider.init();
      final deletedId = provider.currentSession!.id;
      final sending = provider.sendMessage('Câu hỏi giữ lại');
      await storage.started.future;
      final deleting = provider.deleteSession(deletedId);
      storage.release.complete();
      await Future.wait([sending, deleting]);
      expect(service.calls, 0);
      expect(await storage.loadMessages(deletedId), isEmpty);
      expect(
        (await storage.loadSessions()).where((s) => s.id == deletedId),
        isEmpty,
      );
      provider.dispose();
    },
  );

  test(
    'initial storage failure can be retried without another empty session',
    () async {
      final storage = FailingChatStorage()..failSessions = true;
      final provider = AiChatProvider(
        storageService: storage,
        aiService: FakeLocalAi(),
      );
      await provider.init();
      expect(provider.isReady, false);
      expect(provider.lastFailure!.code, LocalAiFailureCode.storage);
      storage.failSessions = false;
      await provider.retryFailedMessage();
      expect(provider.isReady, true);
      expect(provider.lastFailure, isNull);
      expect(provider.sessions, hasLength(1));
      await provider.sendMessage('Huế');
      expect(provider.messages, hasLength(2));
      provider.dispose();
    },
  );

  test(
    'quota exhaustion prevents inference for regular users and sets quotaExceeded failure',
    () async {
      final ai = FakeLocalAi();
      final provider = AiChatProvider(aiService: ai);
      await provider.init();
      provider.updateRole(isAdmin: false);

      // Consume all daily quota
      for (int i = 0; i < provider.settings.dailyQuota; i++) {
        await provider.quotaService.recordUsage(isAdmin: false);
      }
      await provider.refreshQuota();

      expect(provider.remainingQuota, 0);
      expect(provider.isQuotaExhausted, isTrue);

      await provider.sendMessage('Đà Nẵng');

      expect(ai.calls, 0); // No inference!
      expect(provider.lastFailure, isNotNull);
      expect(provider.lastFailure!.code, LocalAiFailureCode.quotaExceeded);
      expect(provider.messages, isEmpty); // Request rejected before message added

      provider.dispose();
    },
  );

  test(
    'admin bypasses quota exhaustion and inference succeeds',
    () async {
      final ai = FakeLocalAi();
      final provider = AiChatProvider(aiService: ai);
      await provider.init();
      provider.updateRole(isAdmin: true);

      // Simulate quota count already at max
      for (int i = 0; i < provider.settings.dailyQuota; i++) {
        await provider.quotaService.recordUsage(isAdmin: false);
      }
      await provider.refreshQuota();

      expect(provider.isAdmin, isTrue);
      expect(provider.isQuotaExhausted, isFalse);

      await provider.sendMessage('Hà Nội');

      expect(ai.calls, 1);
      expect(provider.lastFailure, isNull);
      expect(provider.messages, hasLength(2));

      provider.dispose();
    },
  );
}
