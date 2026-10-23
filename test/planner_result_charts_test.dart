import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/budget_donut_chart.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/itinerary_timeline_widget.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/pareto_chart_widget.dart';

void main() {
  group('ParetoChartWidget Adaptive Axis & Safety Tests', () {
    testWidgets('pareto_includes_twenty_hour_option', (tester) async {
      final options = [
        TransportOption(
          mode: 'bus',
          displayName: 'Xe khách',
          priceTotalVnd: 800000,
          durationHours: 20.0,
          comfortScore: 4,
          isParetoOptimal: true,
          tradeoffType: 'Tiết kiệm nhất',
          recommendationReason: 'Giá rẻ',
        ),
        TransportOption(
          mode: 'plane',
          displayName: 'Máy bay',
          priceTotalVnd: 2500000,
          durationHours: 1.5,
          comfortScore: 9,
          isParetoOptimal: true,
          tradeoffType: 'Nhanh nhất',
          recommendationReason: 'Thời gian ngắn',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParetoChartWidget(transportOptions: options),
          ),
        ),
      );

      final chart = tester.widget<ScatterChart>(find.byType(ScatterChart));
      expect(chart.data.maxX, greaterThanOrEqualTo(20.0));
    });

    testWidgets('all zeros or single point has non-zero positive axis',
        (tester) async {
      final options = [
        TransportOption(
          mode: 'walk',
          displayName: 'Đi bộ',
          priceTotalVnd: 0,
          durationHours: 0.0,
          comfortScore: 1,
          isParetoOptimal: true,
          tradeoffType: 'Miễn phí',
          recommendationReason: 'Không mất tiền',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParetoChartWidget(transportOptions: options),
          ),
        ),
      );

      final chart = tester.widget<ScatterChart>(find.byType(ScatterChart));
      expect(chart.data.maxX, greaterThan(0));
      expect(chart.data.maxY, greaterThan(0));
    });

    testWidgets('invalid or negative options are excluded with a notice',
        (tester) async {
      final options = [
        TransportOption(
          mode: 'plane',
          displayName: 'Máy bay',
          priceTotalVnd: 2000000,
          durationHours: 2.0,
          comfortScore: 8,
          isParetoOptimal: true,
          tradeoffType: 'Nhanh',
          recommendationReason: 'Tốt',
        ),
        TransportOption(
          mode: 'invalid',
          displayName: 'Không hợp lệ',
          priceTotalVnd: -100,
          durationHours: double.nan,
          comfortScore: 0,
          isParetoOptimal: false,
          tradeoffType: '',
          recommendationReason: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParetoChartWidget(transportOptions: options),
          ),
        ),
      );

      expect(find.textContaining('không thể vẽ'), findsOneWidget);
    });
  });

  group('BudgetDonutChartWidget Safety & Deficit Tests', () {
    testWidgets('budget chart must not pass negative values to PieChartSectionData',
        (tester) async {
      final breakdown = BudgetBreakdown(
        transport: 600000,
        accommodation: 500000,
        food: 200000,
        attractions: 100000,
        remainingSafetyMargin: -400000, // Deficit!
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetDonutChartWidget(budget: breakdown),
          ),
        ),
      );

      final chart = tester.widget<PieChart>(find.byType(PieChart));
      expect(chart.data.sections.every((s) => s.value >= 0), isTrue);
      // Deficit warning should be displayed
      expect(find.textContaining('Vượt hạn mức'), findsOneWidget);
    });

    testWidgets('negative expense item shows data error', (tester) async {
      final breakdown = BudgetBreakdown(
        transport: -200000, // Negative expense!
        accommodation: 500000,
        food: 200000,
        attractions: 100000,
        remainingSafetyMargin: 200000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetDonutChartWidget(budget: breakdown),
          ),
        ),
      );

      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('không hợp lệ'), findsOneWidget);
    });

    testWidgets('all zero breakdown shows empty state', (tester) async {
      final breakdown = BudgetBreakdown(
        transport: 0,
        accommodation: 0,
        food: 0,
        attractions: 0,
        remainingSafetyMargin: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetDonutChartWidget(budget: breakdown),
          ),
        ),
      );

      expect(find.byType(PieChart), findsNothing);
      expect(find.textContaining('Chưa có phân bổ'), findsOneWidget);
    });
  });

  group('ItineraryTimelineWidget Date Display Tests', () {
    testWidgets('timeline shows exact calendar dates from startDate',
        (tester) async {
      final days = [
        ItineraryDay(
          day: 1,
          title: 'Ngày 1',
          activities: [
            Activity(
              time: '08:00',
              title: 'Check-in',
              costVnd: 0,
              durationHours: 1.0,
            ),
          ],
        ),
        ItineraryDay(
          day: 2,
          title: 'Ngày 2',
          activities: [
            Activity(
              time: '09:00',
              title: 'Tham quan',
              costVnd: 100000,
              durationHours: 2.0,
            ),
          ],
        ),
        ItineraryDay(
          day: 3,
          title: 'Ngày 3',
          activities: [
            Activity(
              time: '14:00',
              title: 'Rời đi',
              costVnd: 0,
              durationHours: 1.0,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryTimelineWidget(
              itineraryDays: days,
              startDate: '2026-11-01',
            ),
          ),
        ),
      );

      expect(find.textContaining('2026-11-01'), findsOneWidget);
      expect(find.textContaining('2026-11-02'), findsOneWidget);
      expect(find.textContaining('2026-11-03'), findsOneWidget);
    });

    testWidgets('timeline shows explicit missing date label when startDate is null',
        (tester) async {
      final days = [
        ItineraryDay(
          day: 1,
          title: 'Ngày 1',
          activities: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryTimelineWidget(
              itineraryDays: days,
              startDate: null,
            ),
          ),
        ),
      );

      expect(find.textContaining('Chưa chọn ngày'), findsOneWidget);
    });
  });
}
