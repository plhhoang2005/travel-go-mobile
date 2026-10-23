import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';

void main() {
  Widget buildTestScreen(TripProvider provider) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: ChangeNotifierProvider<TripProvider>.value(
        value: provider,
        child: const HomePlannerScreen(),
      ),
    );
  }

  group('HomePlannerScreen - Adaptive UI Controls', () {
    testWidgets('renders Origin quick chips and updates origin', (tester) async {
      final provider = TripProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pumpAndSettle();

      // Find origin chip for Hà Nội
      final haNoiChip = find.text('Hà Nội');
      expect(haNoiChip, findsOneWidget);

      await tester.tap(haNoiChip);
      await tester.pumpAndSettle();

      expect(provider.currentRequest.origin, 'Hà Nội');
    });

    testWidgets('renders Companion Type choice chips and updates companionType', (tester) async {
      final provider = TripProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pumpAndSettle();

      final familyChip = find.text('Gia đình');
      expect(familyChip, findsOneWidget);

      await tester.ensureVisible(familyChip);
      await tester.tap(familyChip);
      await tester.pumpAndSettle();

      expect(provider.currentRequest.companionType, 'family');
    });

    testWidgets('allows adding custom interest chip', (tester) async {
      final provider = TripProvider();
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pumpAndSettle();

      final addInterestBtn = find.text('+ Thêm sở thích');
      expect(addInterestBtn, findsOneWidget);

      await tester.ensureVisible(addInterestBtn);
      await tester.tap(addInterestBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Thêm sở thích mới'), findsOneWidget);
      final inputField = find.byKey(const ValueKey('custom-interest-input'));
      expect(inputField, findsOneWidget);

      await tester.enterText(inputField, 'cà phê chill');
      await tester.tap(find.text('Thêm'));
      await tester.pumpAndSettle();

      expect(provider.currentRequest.preferences.contains('cà phê chill'), isTrue);
      expect(find.text('cà phê chill'), findsOneWidget);
    });

    testWidgets('enables submit button when destination is selected', (tester) async {
      final provider = TripProvider();
      addTearDown(provider.dispose);

      provider.prepareDestinationWorkspace(
        destinationId: 'nha-trang',
        destinationName: 'Nha Trang',
        expectedWorkspaceGeneration: provider.workspaceGeneration,
      );

      await tester.pumpWidget(buildTestScreen(provider));
      await tester.pumpAndSettle();

      // Button should be ENABLED and labeled with destination name
      final submitBtn = find.widgetWithText(ElevatedButton, 'Xem gợi ý cho Nha Trang');
      expect(submitBtn, findsOneWidget);

      final buttonWidget = tester.widget<ElevatedButton>(submitBtn);
      expect(buttonWidget.onPressed, isNotNull);
    });
  });
}
