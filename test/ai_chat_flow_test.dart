import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/ai_chat/models/ai_chat_session.dart';
import 'package:travelgo_mobile/features/ai_chat/providers/ai_chat_provider.dart';
import 'package:travelgo_mobile/features/ai_chat/services/ai_chat_storage_service.dart';
import 'package:travelgo_mobile/features/ai_chat/presentation/screens/ai_chatbot_screen.dart';
import 'package:travelgo_mobile/features/ai_chat/presentation/widgets/ai_prompt_chips.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/core/widgets/global_profile_avatar_action.dart';

import 'local_ai_chat_provider_test.dart' show FakeLocalAi;

import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Chat Models & Storage Tests', () {
    test('AiChatMessage serialization preserves all fields and citations', () {
      final now = DateTime.now();
      final msg = AiChatMessage(
        id: 'msg_1',
        sessionId: 'session_1',
        content: 'Xin chào AI',
        sender: ChatSender.user,
        timestamp: now,
        citations: ['vietnam.travel'],
      );

      final json = msg.toJson();
      final decoded = AiChatMessage.fromJson(json);

      expect(decoded.id, 'msg_1');
      expect(decoded.sessionId, 'session_1');
      expect(decoded.content, 'Xin chào AI');
      expect(decoded.isUser, isTrue);
      expect(decoded.citations, contains('vietnam.travel'));
    });

    test(
      'AiChatStorageService creates, renames, and deletes sessions',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = AiChatStorageService();

        final s1 = AiChatSession(
          id: 's1',
          title: 'Chuyến đi Sa Pa',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final s2 = AiChatSession(
          id: 's2',
          title: 'Ẩm thực Đà Lạt',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await storage.saveSessions([s1, s2]);
        var loaded = await storage.loadSessions();
        expect(loaded.length, 2);

        // Rename
        await storage.renameSession('s1', 'Sa Pa Mùa Thu');
        loaded = await storage.loadSessions();
        expect(loaded.firstWhere((s) => s.id == 's1').title, 'Sa Pa Mùa Thu');

        // Delete
        await storage.deleteSession('s2');
        loaded = await storage.loadSessions();
        expect(loaded.length, 1);
        expect(loaded.first.id, 's1');
      },
    );
  });

  group('AiChatProvider Local Reply Tests', () {
    test('sendMessage uses Ollama reply and auto-titles session', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AiChatStorageService();
      final provider = AiChatProvider(
        storageService: storage,
        aiService: FakeLocalAi(),
      );
      await provider.init();

      expect(provider.sessions.length, 1);
      expect(provider.messages, isEmpty);

      // Send message asking about Da Lat
      await provider.sendMessage('Cho tôi gợi ý du lịch Đà Lạt 3 ngày');

      expect(provider.messages.length, 2);
      expect(provider.messages.first.isUser, isTrue);
      expect(provider.messages.last.isUser, isFalse);
      expect(provider.messages.last.content, 'Phản hồi thật từ fixture Ollama');
      expect(provider.currentSession!.title, contains('Đà Lạt'));
    });

    test('local replies never claim web citations without retrieval', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AiChatProvider(
        storageService: AiChatStorageService(),
        aiService: FakeLocalAi(),
      );
      await provider.init();

      await provider.sendMessage('Thời tiết Sa Pa tháng 11');
      expect(provider.messages.last.citations, isEmpty);
    });
  });

  group('AiChatbotScreen UI & Widgets Tests', () {
    testWidgets('failure retry retains question and displays real response', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final service = FakeLocalAi()
        ..answer = () async => throw const LocalAiFailure(
          LocalAiFailureCode.timeout,
          'Ollama phản hồi quá lâu.',
        );
      final provider = AiChatProvider(aiService: service);
      await provider.init();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AiChatbotScreen()),
        ),
      );
      await provider.sendMessage('Giữ câu hỏi này');
      await tester.pumpAndSettle();
      expect(find.text('Ollama phản hồi quá lâu.'), findsOneWidget);
      expect(
        find.widgetWithText(SelectableText, 'Giữ câu hỏi này'),
        findsOneWidget,
      );
      service.answer = () async => 'Phản hồi sau khi thử lại';
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Phản hồi sau khi thử lại'), findsOneWidget);
      expect(provider.messages.where((m) => m.isUser), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });

    testWidgets(
      'pending request can be cancelled at 320dp and text scale two',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gate = Completer<String>();
        final started = Completer<void>();
        final service = FakeLocalAi()
          ..answer = () {
            started.complete();
            return gate.future;
          };
        final provider = AiChatProvider(aiService: service);
        await provider.init();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const AiChatbotScreen(),
            ),
          ),
        );
        final sending = provider.sendMessage('Hỏi về du lịch Huế');
        await started.future;
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Hủy yêu cầu'));
        await tester.pump();
        gate.complete('Không được hiện');
        await sending;
        await tester.pumpAndSettle();
        expect(find.text('Không được hiện'), findsNothing);
        expect(
          find.widgetWithText(SelectableText, 'Hỏi về du lịch Huế'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      },
    );

    testWidgets(
      'legacy citation labels remain stored without claiming evidence',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final storage = AiChatStorageService();
        final now = DateTime(2026);
        await storage.saveSessions([
          AiChatSession(
            id: 'legacy',
            title: 'Cũ',
            createdAt: now,
            updatedAt: now,
          ),
        ]);
        await storage.saveMessages('legacy', [
          AiChatMessage(
            id: 'm1',
            sessionId: 'legacy',
            content: 'Nội dung cũ',
            sender: ChatSender.ai,
            timestamp: now,
            citations: ['Google Search Grounding'],
          ),
        ]);
        final provider = AiChatProvider(
          aiService: FakeLocalAi(),
          storageService: storage,
        );
        await provider.init();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const MaterialApp(home: AiChatbotScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Google Search Grounding'), findsNothing);
        expect((await storage.loadMessages('legacy')).single.citations, [
          'Google Search Grounding',
        ]);
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      },
    );

    testWidgets(
      'renders empty state hero and allows tapping starter prompt chips',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final provider = AiChatProvider(
          storageService: AiChatStorageService(),
          aiService: FakeLocalAi(),
        );
        await provider.init();

        await tester.pumpWidget(
          ChangeNotifierProvider<AiChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: AiChatbotScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trợ Lý Du Lịch TravelGO'), findsOneWidget);
        expect(find.text('Lịch trình Đà Lạt 3 ngày'), findsOneWidget);

        // Tap on starter prompt chip
        await tester.tap(find.text('Lịch trình Đà Lạt 3 ngày'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Should have sent the message and received response
        expect(provider.messages.length, 2);
        expect(find.byType(AiPromptChips), findsWidgets);
      },
    );

    testWidgets(
      'AiChatbotScreen renders back button and history button in AppBar',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final provider = AiChatProvider(aiService: FakeLocalAi());
        await provider.init();

        await tester.pumpWidget(
          ChangeNotifierProvider<AiChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: AiChatbotScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('ai_chat_back_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ai_chat_history_button')),
          findsOneWidget,
        );
        expect(find.textContaining('Ollama'), findsOneWidget);
        expect(find.textContaining('Gemini'), findsNothing);
        expect(find.byTooltip('Tìm kiếm web: Đang TẮT'), findsNothing);
      },
    );

    test(
      'chat never substitutes hardcoded general knowledge for model replies',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = FakeLocalAi();
        final provider = AiChatProvider(aiService: service);
        await provider.init();

        await provider.sendMessage('ronaldo sinh năm bao nhiêu');
        expect(provider.messages.length, 2);
        final ronaldoReply = provider.messages.last.content;
        expect(ronaldoReply, 'Phản hồi thật từ fixture Ollama');

        await provider.sendMessage('gợi ý quán cafe view đẹp');
        expect(provider.messages.length, 4);
        final cafeReply = provider.messages.last.content;
        expect(cafeReply, 'Phản hồi thật từ fixture Ollama');
        expect(service.calls, 2);
      },
    );

    testWidgets('GlobalProfileAvatarAction renders login for Guest', (
      tester,
    ) async {
      final auth = AuthProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: Row(children: [GlobalProfileAvatarAction()]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });
}
