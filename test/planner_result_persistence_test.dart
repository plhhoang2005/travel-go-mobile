import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/dashboard_result_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';

PlanTripRequest testInput() => PlanTripRequest(
      origin: 'Hà Nội',
      numDays: 3,
      numPeople: 4,
      budgetVnd: 6000000,
      preferences: ['văn hóa', 'ẩm thực'],
      priority: 'balanced',
      startDate: '2026-11-01',
      endDate: '2026-11-03',
      companionType: 'family',
      destinationId: 'hue',
      destinationName: 'Huế',
    );

PlanTripResponse testResponse() => PlanTripResponse(
      winnerId: 'hue',
      topDestinations: [
        DestinationCard(
          id: 'hue',
          name: 'Huế',
          totalScore: 9.2,
          normalizedScores: const {},
          scoreContributions: const {},
          estimatedCostVnd: 5000000,
          weatherSource: 'test',
          avgTempMax: 26.0,
          avgPrecipitation: 0.1,
          region: 'Miền Trung',
        ),
      ],
      transportOptions: [
        TransportOption(
          mode: 'plane',
          displayName: 'Máy bay',
          priceTotalVnd: 4000000,
          durationHours: 1.5,
          comfortScore: 9,
          isParetoOptimal: true,
          tradeoffType: 'Nhanh nhất',
          recommendationReason: 'Tiết kiệm thời gian',
        ),
      ],
      itineraryDays: [
        ItineraryDay(
          day: 1,
          title: 'Ngày 1: Đại Nội',
          activities: [
            Activity(
              time: '08:00',
              title: 'Khám phá Đại Nội',
              costVnd: 200000,
              durationHours: 3.0,
            ),
          ],
        ),
      ],
      budgetBreakdown: BudgetBreakdown(
        transport: 2000000,
        accommodation: 1500000,
        food: 1000000,
        attractions: 500000,
        remainingSafetyMargin: 1000000,
      ),
      aiExplanation: 'Lộ trình tối ưu cho gia đình',
      dataSources: {'itinerary': 'Decision Engine'},
      assumptions: ['Thời tiết khô ráo'],
    );

class FakeTestApi extends TripApiService {
  @override
  Future<PlanTripResponse> planTrip(PlanTripRequest request) async {
    return testResponse();
  }
}

class FakeTestAuth extends AuthProvider {
  String _id = 'user-owner-1';
  @override
  bool get isGuest => false;
  @override
  bool get isAuthenticated => true;
  @override
  UserEntity? get currentUser => UserEntity(
        id: _id,
        fullName: 'Test Owner',
        email: 'owner@example.invalid',
        phone: '',
        role: UserRole.customer,
      );

  void switchUser(String newId) {
    _id = newId;
    notifyListeners();
  }
}

class FakeTestSavedTrips extends SavedTripsProvider {
  String? capturedTitle;
  String? capturedDestinationName;
  int? capturedNumDays;
  double? capturedBudgetTotal;
  DateTime? capturedStartDate;
  DateTime? capturedEndDate;
  Map<String, dynamic>? capturedTripPlanData;
  int saveCallCount = 0;

  @override
  Future<bool> saveTrip({
    required String title,
    required String destinationName,
    required int numDays,
    required double budgetTotal,
    DateTime? startDate,
    DateTime? endDate,
    required Map<String, dynamic> tripPlanData,
  }) async {
    saveCallCount++;
    capturedTitle = title;
    capturedDestinationName = destinationName;
    capturedNumDays = numDays;
    capturedBudgetTotal = budgetTotal;
    capturedStartDate = startDate;
    capturedEndDate = endDate;
    capturedTripPlanData = tripPlanData;
    return true;
  }
}

void main() {
  group('Task P2 - Result Snapshot and Roundtrip Save', () {
    testWidgets('saved_result_roundtrips_original_input', (tester) async {
      final tripProvider = TripProvider(apiService: FakeTestApi());
      tripProvider.setPlannerContext(
        isGuest: false,
        isDemo: false,
        ownerId: 'user-owner-1',
        authEpoch: 1,
      );
      tripProvider.prepareDestinationWorkspace(
        destinationId: 'hue',
        destinationName: 'Huế',
        expectedWorkspaceGeneration: tripProvider.workspaceGeneration,
      );
      tripProvider.updateRequest(testInput());
      await tripProvider.submitPlan();

      final authProvider = FakeTestAuth();
      final savedTripsProvider = FakeTestSavedTrips();

      addTearDown(() {
        tripProvider.dispose();
        authProvider.dispose();
        savedTripsProvider.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SavedTripsProvider>.value(
              value: savedTripsProvider,
            ),
          ],
          child: const MaterialApp(home: DashboardResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open save dialog
      await tester.tap(find.byTooltip('Lưu Chuyến Đi'));
      await tester.pumpAndSettle();

      // Confirm save
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(savedTripsProvider.saveCallCount, 1);
      expect(savedTripsProvider.capturedTitle, contains('Huế'));
      expect(savedTripsProvider.capturedDestinationName, 'Huế');
      expect(savedTripsProvider.capturedNumDays, 3);
      // Original budgetVnd is 6000000, NOT totalAllocated (5000000) or default (4000000)
      expect(savedTripsProvider.capturedBudgetTotal, 6000000.0);
      expect(savedTripsProvider.capturedStartDate, DateTime(2026, 11, 1));
      expect(savedTripsProvider.capturedEndDate, DateTime(2026, 11, 3));

      // Check decoded payload
      final planData = savedTripsProvider.capturedTripPlanData!;
      final decoded = TripPayloadCodec.decode(planData);
      expect(decoded.request, isNotNull);
      expect(decoded.request!.origin, 'Hà Nội');
      expect(decoded.request!.numPeople, 4);
      expect(decoded.request!.budgetVnd, 6000000);
      expect(decoded.request!.companionType, 'family');
      expect(decoded.request!.startDate, '2026-11-01');
      expect(decoded.request!.endDate, '2026-11-03');
      expect(decoded.metadata.startDate, '2026-11-01');
      expect(decoded.metadata.endDate, '2026-11-03');
      expect(decoded.metadata.destinationId, 'hue');
      expect(decoded.metadata.destinationName, 'Huế');
      expect(decoded.plan, isNotNull);
      expect(decoded.plan!.winnerId, 'hue');
    });

    testWidgets('save dialog does not send if workspace changed before confirm',
        (tester) async {
      final tripProvider = TripProvider(apiService: FakeTestApi());
      tripProvider.setPlannerContext(
        isGuest: false,
        isDemo: false,
        ownerId: 'user-owner-1',
        authEpoch: 1,
      );
      tripProvider.updateRequest(testInput());
      await tripProvider.submitPlan();

      final authProvider = FakeTestAuth();
      final savedTripsProvider = FakeTestSavedTrips();

      addTearDown(() {
        tripProvider.dispose();
        authProvider.dispose();
        savedTripsProvider.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SavedTripsProvider>.value(
              value: savedTripsProvider,
            ),
          ],
          child: const MaterialApp(home: DashboardResultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open save dialog
      await tester.tap(find.byTooltip('Lưu Chuyến Đi'));
      await tester.pumpAndSettle();

      // Invalidate workspace by preparing a new one
      tripProvider.useSuggestedDestination(
        expectedWorkspaceGeneration: tripProvider.workspaceGeneration,
        replaceDirty: true,
      );
      await tester.pump();

      // Try to confirm save
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      // Must NOT have called saveTrip because generation / workspace changed
      expect(savedTripsProvider.saveCallCount, 0);
    });

    test('sql_fixture_export_and_bridge_validation', () {
      const exportFixtures = bool.fromEnvironment('PLANNER_EXPORT_SQL_FIXTURES');
      const consumeFixtures = bool.fromEnvironment('PLANNER_SQL_FIXTURES');
      const fixtureDir = String.fromEnvironment('PLANNER_SQL_FIXTURE_DIR');

      if (exportFixtures) {
        expect(fixtureDir, isNotEmpty, reason: 'PLANNER_SQL_FIXTURE_DIR must be specified');
        final payload = CanonicalTripPayloadV1(
          metadata: TripMetadataV1(
            title: 'Huế cùng gia đình',
            destinationId: 'hue',
            destinationName: 'Huế',
            startDate: '2026-11-01',
            endDate: '2026-11-03',
            timezone: 'Asia/Ho_Chi_Minh',
          ),
          request: testInput(),
          plan: testResponse(),
        );
        final canonicalString = TripPayloadCodec.encode(payload);
        final digest = TripPayloadCodec.computeDigest(payload);

        File('$fixtureDir/payload.json').writeAsStringSync(canonicalString);
        File('$fixtureDir/digest.txt').writeAsStringSync(digest);
      }

      if (consumeFixtures) {
        expect(fixtureDir, isNotEmpty, reason: 'PLANNER_SQL_FIXTURE_DIR must be specified');
        final resultFile = File('$fixtureDir/result.json');
        expect(resultFile.existsSync(), isTrue, reason: 'result.json must be written by SQL runner');
        final json = jsonDecode(resultFile.readAsStringSync()) as Map<String, dynamic>;
        expect(json['status'], 'ok');
        expect(json['validated'], isTrue);
      }
    });
  });
}
