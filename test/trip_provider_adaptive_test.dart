import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';

class _FakeAdaptiveApiService extends TripApiService {
  PlanTripRequest? capturedRequest;

  @override
  Future<PlanTripResponse> planTrip(PlanTripRequest request) async {
    capturedRequest = request;
    return PlanTripResponse(
      winnerId: request.destinationId ?? 'da-nang',
      topDestinations: [
        DestinationCard(
          id: request.destinationId ?? 'da-nang',
          name: request.destinationName ?? 'Đà Nẵng',
          totalScore: 9.0,
          normalizedScores: const {},
          scoreContributions: const {},
          estimatedCostVnd: request.budgetVnd,
          weatherSource: 'test',
          avgTempMax: 28.0,
          avgPrecipitation: 0.5,
          region: 'test',
        ),
      ],
      transportOptions: [],
      itineraryDays: [],
      budgetBreakdown: null,
      aiExplanation: 'Adaptive test plan',
      dataSources: {'status': 'LIVE'},
      assumptions: [],
    );
  }
}

void main() {
  group('TripProvider - Adaptive Destination Planning', () {
    late _FakeAdaptiveApiService apiService;
    late TripProvider provider;

    setUp(() {
      apiService = _FakeAdaptiveApiService();
      provider = TripProvider(apiService: apiService);
    });

    tearDown(() {
      provider.dispose();
    });

    test('submitPlan succeeds and forwards selected destination to API', () async {
      provider.prepareDestinationWorkspace(
        destinationId: 'nha-trang',
        destinationName: 'Nha Trang',
        expectedWorkspaceGeneration: provider.workspaceGeneration,
      );

      expect(provider.hasSelectedDestination, isTrue);

      final accepted = await provider.submitPlan();
      expect(accepted, isTrue);
      expect(provider.currentResponse, isNotNull);
      expect(provider.currentResponse!.winnerId, 'nha-trang');
      expect(apiService.capturedRequest, isNotNull);
      expect(apiService.capturedRequest!.destinationId, 'nha-trang');
      expect(apiService.capturedRequest!.destinationName, 'Nha Trang');
    });

    test('updateRequest preserves adaptive parameters', () {
      final req = PlanTripRequest(
        origin: 'Hà Nội',
        numDays: 5,
        numPeople: 3,
        budgetVnd: 15000000,
        preferences: ['núi', 'ẩm thực', 'check-in'],
        priority: 'comfortable',
        startDate: '2026-11-20',
        endDate: '2026-11-24',
        companionType: 'family',
      );

      provider.updateRequest(req);
      expect(provider.currentRequest.origin, 'Hà Nội');
      expect(provider.currentRequest.numDays, 5);
      expect(provider.currentRequest.numPeople, 3);
      expect(provider.currentRequest.startDate, '2026-11-20');
      expect(provider.currentRequest.endDate, '2026-11-24');
      expect(provider.currentRequest.companionType, 'family');
    });
  });
}
