import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/trip_template_preview_sheet.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_template_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripTemplatePreviewSheet Tests', () {
    testWidgets('renders template title, budget, day highlights and action button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final inputProvider = PlannerInputProvider();
      final template = TripTemplateRepository().getCuratedTemplates().first;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: inputProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => TripTemplatePreviewSheet.show(ctx, template),
                  child: const Text('Open Preview'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      // Check title and destination
      expect(find.text(template.title), findsOneWidget);
      expect(find.textContaining('3 ngày'), findsWidgets);
      expect(find.text('Sử dụng lịch trình này'), findsOneWidget);

      // Verify day items are visible
      expect(find.textContaining('Ngày 1'), findsOneWidget);
    });
  });
}
