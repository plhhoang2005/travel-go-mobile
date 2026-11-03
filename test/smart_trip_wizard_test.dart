import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/smart_trip_wizard_sheet.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartTripWizardSheet Tests', () {
    testWidgets('renders Step 1 destinations initially and navigates between steps', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final inputProvider = PlannerInputProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: inputProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => SmartTripWizardSheet.show(ctx),
                  child: const Text('Open Wizard'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Step 1: Destination Selection
      expect(find.text('Bạn muốn đi đâu?'), findsOneWidget);
      expect(find.text('Đà Lạt'), findsWidgets);
      expect(find.text('Hà Nội'), findsWidgets);

      // Tap on Da Lat
      await tester.tap(find.text('Đà Lạt').first);
      await tester.pumpAndSettle();

      // Should advance to Step 2: Duration & Companions
      expect(find.text('Thời gian & Đồng hành'), findsOneWidget);
      expect(find.textContaining('3 ngày'), findsWidgets);
      expect(find.text('Cặp đôi 👩‍❤️‍👨'), findsOneWidget);

      // Tap Next to Step 3
      final nextFinder = find.widgetWithText(FilledButton, 'Tiếp theo');
      await tester.ensureVisible(nextFinder);
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();

      // Step 3: Choose planning mode
      expect(find.text('Cách bạn muốn lên lịch?'), findsOneWidget);
      expect(find.text('Khởi tạo cùng GoAI 🪄'), findsOneWidget);
      expect(find.text('Tự lên lịch trình ✏️'), findsOneWidget);
    });
  });
}
