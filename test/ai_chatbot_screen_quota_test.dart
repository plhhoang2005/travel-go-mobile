import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/ai_chat/presentation/screens/ai_chatbot_screen.dart';
import 'package:travelgo_mobile/features/ai_chat/providers/ai_chat_provider.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

import 'local_ai_chat_provider_test.dart' show FakeLocalAi;

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserEntity? mockUser;
  MockAuthProvider({this.mockUser});

  @override
  UserEntity? get currentUser => mockUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AiChatbotScreen displays quota badge for user and updates when exhausted', (
    tester,
  ) async {
    final ai = FakeLocalAi();
    final provider = AiChatProvider(aiService: ai);
    await provider.init();

    final auth = MockAuthProvider(mockUser: UserEntity.demoMinh());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AiChatProvider>.value(value: provider),
        ],
        child: const MaterialApp(home: AiChatbotScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify quota badge exists and shows initial quota
    final badgeFinder = find.byKey(const Key('ai_chat_quota_badge'));
    expect(badgeFinder, findsOneWidget);
    expect(find.textContaining('Còn 10/10 lượt'), findsOneWidget);

    // Simulate consuming quota to 0
    for (int i = 0; i < 10; i++) {
      await provider.quotaService.recordUsage(isAdmin: false);
    }
    await provider.refreshQuota();
    await tester.pumpAndSettle();

    // Verify quota badge shows exhausted state
    expect(find.textContaining('Còn 0/10 lượt'), findsOneWidget);
    expect(find.textContaining('Đã hết 10 lượt hỏi hôm nay...'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('AiChatbotScreen displays unlimited badge for admin', (
    tester,
  ) async {
    final ai = FakeLocalAi();
    final provider = AiChatProvider(aiService: ai);
    await provider.init();

    final auth = MockAuthProvider(mockUser: UserEntity.demoAdmin());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AiChatProvider>.value(value: provider),
        ],
        child: const MaterialApp(home: AiChatbotScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify badge shows admin unlimited
    expect(find.text('Admin · Không giới hạn'), findsOneWidget);

    provider.dispose();
  });
}
