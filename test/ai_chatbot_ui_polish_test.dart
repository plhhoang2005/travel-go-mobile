import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/ai_chat/models/ai_chat_session.dart';
import 'package:travelgo_mobile/features/ai_chat/presentation/screens/ai_chatbot_screen.dart';
import 'package:travelgo_mobile/features/ai_chat/presentation/widgets/ai_markdown_text.dart';
import 'package:travelgo_mobile/features/ai_chat/providers/ai_chat_provider.dart';
import 'package:travelgo_mobile/features/ai_chat/services/ai_chat_storage_service.dart';

import 'local_ai_chat_provider_test.dart' show FakeLocalAi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiChatbotScreen UI Polish Tests', () {
    testWidgets('renders markdown, timestamp, and action buttons in AI bubble', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final fakeAi = FakeLocalAi()
        ..answer = () async => '1. **Phở Hà Nội**\n2. **Bún thang**\n\n\n';
      final provider = AiChatProvider(
        storageService: AiChatStorageService(),
        aiService: fakeAi,
      );
      await provider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AiChatbotScreen()),
        ),
      );

      // Send a user question
      await provider.sendMessage('Món ăn Hà Nội');
      await tester.pumpAndSettle();

      // Verify AiMarkdownText is used
      expect(find.byType(AiMarkdownText), findsNWidgets(2)); // user + ai

      // Raw asterisks are not shown in rendered text
      expect(find.textContaining('**'), findsNothing);

      // Timestamp is displayed
      final nowHour = DateTime.now().hour.toString().padLeft(2, '0');
      expect(find.textContaining(nowHour), findsWidgets);

      // Regenerate button exists
      final refreshFinder = find.byIcon(Icons.refresh_rounded);
      expect(refreshFinder, findsOneWidget);

      // Copy button exists
      final copyFinder = find.byIcon(Icons.copy_rounded);
      expect(copyFinder, findsOneWidget);
    });

    testWidgets('copy button gives visual feedback on tap', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fakeAi = FakeLocalAi()..answer = () async => 'Câu trả lời mẫu';
      final provider = AiChatProvider(
        storageService: AiChatStorageService(),
        aiService: fakeAi,
      );
      await provider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AiChatbotScreen()),
        ),
      );

      await provider.sendMessage('Test copy button');
      await tester.pumpAndSettle();

      final copyFinder = find.byIcon(Icons.copy_rounded);
      expect(copyFinder, findsOneWidget);

      // Tap copy
      await tester.tap(copyFinder);
      await tester.pump();

      // Checkmark icon should appear immediately
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Advance timer past feedback duration (1500ms) and settle transitions
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('tapping regenerate triggers new response', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fakeAi = FakeLocalAi()..answer = () async => 'Câu trả lời ban đầu';
      final provider = AiChatProvider(
        storageService: AiChatStorageService(),
        aiService: fakeAi,
      );
      await provider.init();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: AiChatbotScreen()),
        ),
      );

      await provider.sendMessage('Hỏi lần đầu');
      await tester.pumpAndSettle();

      expect(find.text('Câu trả lời ban đầu'), findsOneWidget);

      // Change AI answer
      fakeAi.answer = () async => 'Câu trả lời sau khi tạo lại';

      // Tap regenerate button
      final refreshFinder = find.byIcon(Icons.refresh_rounded);
      await tester.tap(refreshFinder);
      await tester.pumpAndSettle();

      expect(find.text('Câu trả lời sau khi tạo lại'), findsOneWidget);
    });
  });
}
