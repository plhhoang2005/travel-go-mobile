import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/trip_comparison_matrix_widget.dart';

void main() {
  group('TripComparisonMatrixWidget Truthful Data Tests', () {
    testWidgets('renders supplied DTO alternatives without hardcoded Furama or Ba Na',
        (tester) async {
      final response = PlanTripResponse(
        winnerId: 'hue',
        topDestinations: [
          DestinationCard(
            id: 'hue',
            name: 'Huế',
            totalScore: 9.0,
            normalizedScores: const {},
            scoreContributions: const {},
            estimatedCostVnd: 5500000,
            weatherSource: 'test',
            avgTempMax: 27.0,
            avgPrecipitation: 0.2,
            region: 'Miền Trung',
          ),
          DestinationCard(
            id: 'da-nang',
            name: 'Đà Nẵng',
            totalScore: 8.5,
            normalizedScores: const {},
            scoreContributions: const {},
            estimatedCostVnd: 5800000,
            weatherSource: 'test',
            avgTempMax: 29.0,
            avgPrecipitation: 0.4,
            region: 'Miền Trung',
          ),
        ],
        transportOptions: [
          TransportOption(
            mode: 'train',
            displayName: 'Tàu hỏa SE1',
            priceTotalVnd: 1800000,
            durationHours: 13.0,
            comfortScore: 7,
            isParetoOptimal: true,
            tradeoffType: 'Cân bằng',
            recommendationReason: 'Ngắm cảnh đèo Hải Vân',
          ),
        ],
        itineraryDays: [],
        aiExplanation: 'Lộ trình Huế',
        dataSources: {},
        assumptions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripComparisonMatrixWidget(
                response: response,
                requestedBudgetVnd: 6000000,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Huế'), findsWidgets);
      expect(find.textContaining('Tàu hỏa SE1'), findsOneWidget);
      expect(find.textContaining('Ngắm cảnh đèo Hải Vân'), findsOneWidget);

      // Must NOT fabricate fake hardcoded Đà Nẵng hotels or cancellation policies
      expect(find.textContaining('Furama'), findsNothing);
      expect(find.textContaining('Bà Nà Hills'), findsNothing);
      expect(find.textContaining('Miễn phí hủy phòng trước 48h'), findsNothing);
    });

    testWidgets('renders truthful empty state when no alternatives exist',
        (tester) async {
      final response = PlanTripResponse(
        winnerId: 'empty',
        topDestinations: [],
        transportOptions: [],
        itineraryDays: [],
        aiExplanation: '',
        dataSources: {},
        assumptions: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripComparisonMatrixWidget(
                response: response,
                requestedBudgetVnd: 6000000,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Chưa có phương án so sánh'), findsOneWidget);
    });
  });
}
