import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/local_ai_assistant_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

void main() {
  group('LocalAiAssistantScreen Tests', () {
    testWidgets('renders 3 tab bar items and switches views smoothly', (tester) async {
      final service = LocalAiService(dio: Dio());

      await tester.pumpWidget(
        MaterialApp(
          home: LocalAiAssistantScreen(service: service),
        ),
      );

      expect(find.text('Trợ Lý AI TravelGO'), findsOneWidget);
      expect(find.text('Trò Chuyện 💬'), findsOneWidget);
      expect(find.text('Tra Cứu 🔍'), findsOneWidget);
      expect(find.text('Gợi Ý 💡'), findsOneWidget);

      // Verify default tab is Chat
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Hỏi AI về bất kỳ chuyến đi nào...'), findsOneWidget);

      // Switch to Tra Cứu tab
      await tester.tap(find.text('Tra Cứu 🔍'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập tên địa danh cần tra cứu...'), findsOneWidget);

      // Switch to Gợi Ý tab
      await tester.tap(find.text('Gợi Ý 💡'));
      await tester.pumpAndSettle();
      expect(find.text('Điểm đến yêu thích:'), findsOneWidget);
      expect(find.text('Gợi ý địa điểm ≥ 4.5⭐'), findsOneWidget);
    });
  });
}
