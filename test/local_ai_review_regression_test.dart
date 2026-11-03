import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_ai_management_screen.dart';
import 'package:travelgo_mobile/features/ai_chat/models/ai_chat_session.dart';
import 'package:travelgo_mobile/features/ai_chat/providers/ai_chat_provider.dart';
import 'package:travelgo_mobile/features/ai_chat/services/ai_chat_storage_service.dart';
import 'package:travelgo_mobile/features/ai_chat/services/local_ai_settings_store.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';

import 'local_ai_chat_provider_test.dart' show FakeLocalAi, FailingChatStorage;
import 'admin_ai_management_test.dart' show ProbeAi, tapAdminButton;

class DelayedSettingsStore extends LocalAiSettingsStore {
  final release = Completer<void>();
  @override
  Future<bool> writeJson(String json) async {
    await release.future;
    return super.writeJson(json);
  }
}

class DelayedAssistantStorage extends AiChatStorageService {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> saveMessages(String id, List<AiChatMessage> messages) async {
    if (messages.isNotEmpty && !messages.last.isUser) {
      started.complete();
      await release.future;
      throw StateError('disk full after switch');
    }
    await super.saveMessages(id, messages);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'unsaved assistant keeps warning and save-only retry after A B A',
    () async {
      final storage = FailingChatStorage();
      final service = FakeLocalAi();
      final provider = AiChatProvider(
        storageService: storage,
        aiService: service,
      );
      await provider.init();
      final first = provider.currentSession!.id;
      storage.failAssistant = true;
      await provider.sendMessage('Huế');
      expect(provider.lastFailure!.code, LocalAiFailureCode.storage);
      await provider.createNewSession();
      await provider.selectSession(first);
      expect(provider.messages, hasLength(2));
      expect(provider.lastFailure?.code, LocalAiFailureCode.storage);
      storage.failAssistant = false;
      await provider.retryFailedMessage();
      expect(service.calls, 1);
      expect(provider.lastFailure, isNull);
      expect(await storage.loadMessages(first), hasLength(2));
      provider.dispose();
    },
  );

  test(
    'save failure arriving after switch remains attached to original chat',
    () async {
      final storage = DelayedAssistantStorage();
      final provider = AiChatProvider(
        storageService: storage,
        aiService: FakeLocalAi(),
      );
      await provider.init();
      final first = provider.currentSession!.id;
      final sending = provider.sendMessage('Huế');
      await storage.started.future;
      final switching = provider.createNewSession();
      storage.release.complete();
      await Future.wait([sending, switching]);
      expect(provider.lastFailure, isNull);
      await provider.selectSession(first);
      expect(provider.lastFailure?.code, LocalAiFailureCode.storage);
      expect(provider.messages, hasLength(2));
      provider.dispose();
    },
  );

  testWidgets('saved settings reload root provider after admin screen closes', (
    tester,
  ) async {
    final store = DelayedSettingsStore();
    final service = FakeLocalAi();
    final provider = AiChatProvider(settingsStore: store, aiService: service);
    await provider.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: AdminAiManagementScreen(
            settingsStore: store,
            service: ProbeAi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ollama_host_field')),
      'http://localhost:11435',
    );
    await tapAdminButton(tester, 'Lưu cấu hình');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    store.release.complete();
    await tester.pumpAndSettle();
    await provider.sendMessage('Huế');
    expect(service.receivedSettings!.baseUrl, 'http://localhost:11435');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
