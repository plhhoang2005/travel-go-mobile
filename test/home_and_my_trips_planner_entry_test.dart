import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/home/presentation/screens/main_home_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home & My Trips Planner Integration Tests', () {
    testWidgets('MainHomeScreen displays quick planner CTA and templates section', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthProvider();
      final discovery = DiscoveryProvider();
      final plannerInput = PlannerInputProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: discovery),
            ChangeNotifierProvider.value(value: plannerInput),
          ],
          child: const MaterialApp(home: MainHomeScreen()),
        ),
      );

      await tester.pump();

      // Quick Wizard Button
      expect(find.text('Tạo chuyến đi nhanh'), findsOneWidget);

      // Curated Templates Section
      expect(find.text('Lịch trình gợi ý sẵn'), findsOneWidget);
      expect(find.textContaining('Đà Lạt'), findsWidgets);
    });

    testWidgets('MyTripsScreen empty state displays quick wizard and template actions', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthProvider();
      final savedTrips = SavedTripsProvider();
      final plannerInput = PlannerInputProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: savedTrips),
            ChangeNotifierProvider.value(value: plannerInput),
          ],
          child: const MaterialApp(home: MyTripsScreen()),
        ),
      );

      await tester.pump();

      // Fast wizard CTA in empty state
      expect(find.text('Tạo chuyến đi nhanh (GoAI)'), findsOneWidget);

      // Templates CTA in empty state
      expect(find.text('Khám phá lịch trình mẫu'), findsOneWidget);
    });
  });
}
