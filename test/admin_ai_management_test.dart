import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_ai_management_screen.dart';
import 'package:travelgo_mobile/features/ai_chat/providers/ai_chat_provider.dart';
import 'package:travelgo_mobile/features/ai_chat/services/local_ai_settings_store.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_settings.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

import 'local_ai_chat_provider_test.dart' show FakeLocalAi;
import 'local_ai_settings_test.dart' show FailedSettingsStore;

class ProbeAi extends LocalAiService {
  Future<LocalAiConnectionCheck> Function()? result;
  LocalAiSettings? received;
  ProbeAi() : super(dio: Dio());
  @override
  Future<LocalAiConnectionCheck> checkConnection(
    LocalAiSettings settings, {
    CancelToken? cancelToken,
  }) async {
    received = settings;
    return result == null
        ? LocalAiConnectionCheck(
            modelName: settings.modelName,
            elapsed: const Duration(milliseconds: 73),
          )
        : result!();
  }
}

Future<void> tapAdminButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  final fallback = find.widgetWithText(OutlinedButton, label);
  final finder = button.evaluate().isNotEmpty ? button : fallback;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saving local configuration controls next chatbot request', (
    tester,
  ) async {
    final store = LocalAiSettingsStore();
    final chatService = FakeLocalAi();
    final provider = AiChatProvider(
      aiService: chatService,
      settingsStore: store,
    );
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
    expect(
      find.textContaining('Cấu hình AI trên thiết bị này'),
      findsOneWidget,
    );
    expect(find.textContaining('Gemini'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('ollama_host_field')),
      'http://localhost:11435',
    );
    await tester.enterText(
      find.byKey(const Key('ollama_prompt_field')),
      'Chỉ trả lời du lịch.',
    );
    await tapAdminButton(tester, 'Lưu cấu hình');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Đã lưu cấu hình trên thiết bị'),
      findsOneWidget,
    );
    await provider.sendMessage('Huế');
    expect(chatService.receivedSettings!.baseUrl, 'http://localhost:11435');
    expect(chatService.receivedSettings!.systemPrompt, 'Chỉ trả lời du lịch.');
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  for (final code in [
    LocalAiFailureCode.modelMissing,
    LocalAiFailureCode.timeout,
    LocalAiFailureCode.server,
  ]) {
    testWidgets('connection check reports $code without fake success', (
      tester,
    ) async {
      final service = ProbeAi()
        ..result = () async =>
            throw LocalAiFailure(code, 'Không kết nối được model');
      await tester.pumpWidget(
        MaterialApp(home: AdminAiManagementScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tapAdminButton(tester, 'Kiểm tra kết nối');
      await tester.pumpAndSettle();
      expect(find.text('Không kết nối được model'), findsOneWidget);
      expect(find.textContaining('Kết nối Ollama thành công'), findsNothing);
      expect(
        (await LocalAiSettingsStore().load()).baseUrl,
        'http://127.0.0.1:11434',
      );
    });
  }

  testWidgets('failed save retains form and never says saved', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminAiManagementScreen(
          settingsStore: FailedSettingsStore(),
          service: ProbeAi(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ollama_prompt_field')),
      'Giữ nội dung này',
    );
    await tapAdminButton(tester, 'Lưu cấu hình');
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã lưu cấu hình'), findsNothing);
    expect(find.text('Giữ nội dung này'), findsOneWidget);
    expect(find.textContaining('Không lưu được'), findsOneWidget);
  });

  for (final action in ['edit', 'dispose']) {
    testWidgets('$action during probe ignores stale connection status', (
      tester,
    ) async {
      final gate = Completer<LocalAiConnectionCheck>();
      final service = ProbeAi()..result = () => gate.future;
      await tester.pumpWidget(
        MaterialApp(home: AdminAiManagementScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tapAdminButton(tester, 'Kiểm tra kết nối');
      if (action == 'edit') {
        await tester.enterText(
          find.byKey(const Key('ollama_model_field')),
          'different:small',
        );
      } else {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      }
      gate.complete(
        const LocalAiConnectionCheck(
          modelName: 'qwen3:4b-instruct-2507-q4_K_M',
          elapsed: Duration(milliseconds: 73),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Kết nối Ollama thành công'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('configuration form fits 320dp with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AdminAiManagementScreen(service: ProbeAi()),
      ),
    );
    await tester.pumpAndSettle();
    await tapAdminButton(tester, 'Kiểm tra kết nối');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('73 ms'), findsOneWidget);
  });
}
