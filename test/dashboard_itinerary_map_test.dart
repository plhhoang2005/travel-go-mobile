import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';
import 'package:travelgo_mobile/features/map/models/itinerary_map_context.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/trip_map_screen.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/itinerary_map_panel.dart';
import 'package:travelgo_mobile/features/map/providers/map_provider.dart';
import 'package:travelgo_mobile/features/map/services/itinerary_map_builder.dart';
import 'package:travelgo_mobile/features/map/services/location_service.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/trip_planner/models/planner_result_snapshot.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/dashboard_result_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

class ControllableMapApiService extends MapApiService {
  Completer<RouteData>? pendingCompleter;
  bool shouldThrowRoutingException = false;
  int getRouteCalls = 0;
  LatLng? lastOrigin;
  LatLng? lastDestination;
  List<RouteWaypoint>? lastWaypoints;

  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    getRouteCalls++;
    lastOrigin = origin;
    lastDestination = destination;
    lastWaypoints = waypoints;

    if (shouldThrowRoutingException) {
      throw RoutingException('OSRM down');
    }

    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }

    final allPoints = [origin, ...waypoints.map((w) => w.position), destination];
    return RouteData(
      points: allPoints,
      distanceKm: 50.0,
      durationMinutes: 60,
      isFallback: false,
      summary: 'Route test',
      waypoints: waypoints,
    );
  }
}

class FakeTestLocationService extends LocationService {
  @override
  Future<LocationResult> getCurrentUserLocation() async {
    return const LocationResult(
      position: LatLng(16.0544, 108.2022),
      isMock: true,
      locationName: 'Đà Nẵng',
    );
  }

  @override
  Stream<LocationResult> watchUserLocation() => const Stream.empty();
}

class FakePublicCatalogueProvider extends ChangeNotifier
    implements PublicCatalogueProvider {
  final PublicCatalogueSnapshot _testSnapshot;
  FakePublicCatalogueProvider(this._testSnapshot);

  @override
  PublicCatalogueSnapshot? get snapshot => _testSnapshot;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  DateTime? get lastRefreshedAt => DateTime.now();

  @override
  PublicCatalogueRepository get repository => throw UnimplementedError();

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> onResume() => refresh(force: true);

  @override
  void updateSnapshot(PublicCatalogueSnapshot next) {}
}

class FakeTripApiService extends TripApiService {
  final PlanTripResponse plan;
  FakeTripApiService(this.plan);

  @override
  Future<PlanTripResponse> planTrip(PlanTripRequest request) async {
    return plan;
  }
}

PublicCatalogueSnapshot createTestSnapshot() {
  return PublicCatalogueSnapshot(
    version: 1,
    sha256: 'b' * 64,
    origin: 'test',
    manifest: DiscoveryManifest(
      contract: 'travelgo.discovery.manifest.v2',
      schemaVersion: 2,
      version: 1,
      objectKey: 'releases/v1/1.json',
      sha256: 'b' * 64,
      byteLength: 500,
      publishedAt: DateTime.parse('2026-10-24T00:00:00Z'),
    ),
    catalogue: CatalogueReference(
      checkedAt: '2026-10-24',
      sources: const [
        SourceReference(
          id: 'src-1',
          title: 'Source 1',
          url: 'https://test.example',
          publisher: 'Test Publisher',
          checkedAt: '2026-10-24',
        ),
      ],
      destinations: [
        DestinationReference(
          id: 'hue',
          name: 'Huế',
          region: 'Miền Trung',
          places: const [
            PlaceReference(
              id: 'hue/dai-noi',
              destinationId: 'hue',
              name: 'Đại Nội Huế',
              sourceId: 'src-1',
              latitude: 16.469,
              longitude: 107.577,
            ),
            PlaceReference(
              id: 'hue/thien-mu',
              destinationId: 'hue',
              name: 'Chùa Thiên Mụ',
              sourceId: 'src-1',
              latitude: 16.453,
              longitude: 107.545,
            ),
            PlaceReference(
              id: 'hue/dong-ba',
              destinationId: 'hue',
              name: 'Chợ Đông Ba',
              sourceId: 'src-1',
              latitude: 16.471,
              longitude: 107.588,
            ),
          ],
          sample: SampleReference(
            id: 'sample-hue',
            editorialReview: EditorialReview(
              status: 'unverified',
              reviewedAt: '2026-10-24',
              sourceIds: const [],
              conditions: const [],
              reviewNotes: const [],
            ),
            days: const [],
            warnings: const [],
          ),
        ),
      ],
    ),
    visits: VisitCatalogue.fromPublicProjection(
      version: 1,
      publishedAt: DateTime.parse('2026-10-24T00:00:00Z'),
      releaseSha256: 'b' * 64,
      data: const {
        'sources': [],
        'packages': [],
        'places': [],
      },
      expectedPlaceIds: {},
      now: DateTime.parse('2026-10-24T01:00:00Z'),
    ),
    fetchedAt: DateTime.now(),
  );
}

PlanTripResponse createTestPlan() {
  return PlanTripResponse(
    winnerId: 'hue',
    topDestinations: [
      DestinationCard(
        id: 'hue',
        name: 'Huế',
        totalScore: 9.2,
        normalizedScores: const {},
        scoreContributions: const {},
        estimatedCostVnd: 4500000,
        weatherSource: 'test',
        avgTempMax: 28.0,
        avgPrecipitation: 0.1,
        region: 'Miền Trung',
      ),
    ],
    transportOptions: const [],
    itineraryDays: [
      ItineraryDay(
        day: 1,
        title: 'Ngày 1: Khám phá',
        activities: [
          Activity(time: '08:00', title: 'Đại Nội Huế', costVnd: 150000, durationHours: 3.0),
          Activity(time: '14:00', title: 'Chùa Thiên Mụ', costVnd: 0, durationHours: 2.0),
        ],
      ),
      ItineraryDay(
        day: 2,
        title: 'Ngày 2: Chợ & Dạo phố',
        activities: [
          Activity(time: '09:00', title: 'Chợ Đông Ba', costVnd: 200000, durationHours: 2.0),
          Activity(time: '12:00', title: 'Cà phê bên hồ', costVnd: 50000, durationHours: 1.0), // Unlocated!
          Activity(time: '15:00', title: 'Chùa Thiên Mụ', costVnd: 0, durationHours: 1.5),
        ],
      ),
    ],
    aiExplanation: 'Lịch trình thử nghiệm',
    dataSources: const {},
    assumptions: const [],
  );
}

PlannerResultSnapshot createTestResult() {
  final plan = createTestPlan();

  return PlannerResultSnapshot(
    request: PlanTripRequest(
      origin: 'TP. Hồ Chí Minh',
      numDays: 2,
      numPeople: 2,
      budgetVnd: 5000000,
      preferences: const ['culture'],
      priority: 'balanced',
      destinationId: 'hue',
      destinationName: 'Huế',
      startDate: '2026-11-01',
      endDate: '2026-11-02',
    ),
    metadata: TripMetadataV1(
      destinationId: 'hue',
      destinationName: 'Huế',
      startDate: '2026-11-01',
      endDate: '2026-11-02',
    ),
    plan: plan,
    workspaceGeneration: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P5: Dashboard to Map Itinerary Flow & Panel Tests', () {
    testWidgets('DashboardResultScreen passes ItineraryMapContext to TripMapScreen via appbar action', (tester) async {
      final plan = createTestPlan();
      final tripProvider = TripProvider(apiService: FakeTripApiService(plan));
      tripProvider.setPlannerContext(
        isGuest: false,
        isDemo: false,
        ownerId: 'user-1',
        authEpoch: 1,
      );
      tripProvider.prepareDestinationWorkspace(
        destinationId: 'hue',
        destinationName: 'Huế',
        expectedWorkspaceGeneration: tripProvider.workspaceGeneration,
      );
      tripProvider.updateRequest(
        PlanTripRequest(
          origin: 'TP. Hồ Chí Minh',
          numDays: 2,
          numPeople: 2,
          budgetVnd: 5000000,
          preferences: const ['culture'],
          priority: 'balanced',
          destinationId: 'hue',
          destinationName: 'Huế',
          startDate: '2026-11-01',
          endDate: '2026-11-02',
        ),
      );
      await tripProvider.submitPlan();

      final snapshot = createTestSnapshot();
      final catalogueProvider = FakePublicCatalogueProvider(snapshot);

      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<PublicCatalogueProvider>.value(value: catalogueProvider),
            ChangeNotifierProvider<MapProvider>.value(value: mapProvider),
          ],
          child: const MaterialApp(
            home: DashboardResultScreen(enableMapNetworkTiles: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the appbar map button
      final appbarMapButton = find.byTooltip('Xem Bản Đồ & Radar Nhóm');
      expect(appbarMapButton, findsOneWidget);

      await tester.tap(appbarMapButton);
      await tester.pumpAndSettle();

      // Should now be on TripMapScreen with ItineraryMapPanel present
      expect(find.byType(TripMapScreen), findsOneWidget);
      expect(find.byType(ItineraryMapPanel), findsOneWidget);
      expect(find.textContaining('Lộ trình Huế'), findsOneWidget);
      expect(find.text('Ngày 1'), findsOneWidget);
      expect(find.text('Ngày 2'), findsOneWidget);
    });

    testWidgets('ItineraryMapPanel day switching updates stops and shows gap warning when incomplete', (tester) async {
      final resultSnapshot = createTestResult();
      final snapshot = createTestSnapshot();
      final itineraryContext = ItineraryMapBuilder.build(
        result: resultSnapshot,
        snapshot: snapshot,
      );

      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MapProvider>.value(value: mapProvider),
          ],
          child: MaterialApp(
            home: TripMapScreen(
              itinerary: itineraryContext,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Day 1 has 2/2 located stops -> no gap warning
      expect(find.text('Đại Nội Huế'), findsOneWidget);
      expect(find.text('Chùa Thiên Mụ'), findsOneWidget);
      expect(find.text('Tuyến qua các điểm có vị trí, chưa đầy đủ'), findsNothing);

      // Tap Day 2
      await tester.tap(find.text('Ngày 2'));
      await tester.pumpAndSettle();

      // Day 2 has 2 located (Chợ Đông Ba, Chùa Thiên Mụ) and 1 unlocated (Cà phê bên hồ)
      expect(find.text('Chợ Đông Ba'), findsOneWidget);
      expect(find.text('Cà phê bên hồ'), findsOneWidget);
      expect(find.text('Chưa xác định vị trí'), findsOneWidget);
      expect(find.text('Tuyến qua các điểm có vị trí, chưa đầy đủ'), findsOneWidget);
    });
  });

  group('P6: Map Context Token Fencing & Late Route Rejection', () {
    test('MapProvider begins context and increments routeContextGeneration', () {
      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      final token1 = mapProvider.beginRouteContext();
      expect(token1, greaterThan(0));

      final token2 = mapProvider.beginRouteContext();
      expect(token2, token1 + 1);
    });

    test('Stale route response from context A does not overwrite context B', () async {
      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      // Context A starts with pending completer
      final completerA = Completer<RouteData>();
      fakeRouting.pendingCompleter = completerA;

      final tokenA = mapProvider.beginRouteContext();
      // Trigger route A
      final futureA = mapProvider.init(
        targetDestination: const LatLng(10.7769, 106.7009), // HCM
        targetName: 'TP. Hồ Chí Minh',
        contextGeneration: tokenA,
      );

      // Now Context B starts before A finishes
      fakeRouting.pendingCompleter = null; // B completes immediately
      final tokenB = mapProvider.beginRouteContext();
      await mapProvider.init(
        targetDestination: const LatLng(16.0544, 108.2022), // Da Nang
        targetName: 'Đà Nẵng',
        contextGeneration: tokenB,
      );

      expect(mapProvider.destinationName, 'Đà Nẵng');
      expect(mapProvider.destination?.latitude, closeTo(16.0544, 0.001));
      expect(mapProvider.hasRoute, isTrue);
      final daNangDistance = mapProvider.currentRoute?.distanceKm;

      // Now late route A completes
      completerA.complete(
        const RouteData(
          points: [LatLng(10.0, 106.0), LatLng(10.7769, 106.7009)],
          distanceKm: 999.0,
          durationMinutes: 999,
          isFallback: false,
          summary: 'Late route A',
        ),
      );
      await futureA;

      // MapProvider must NOT be updated with stale A route!
      expect(mapProvider.destinationName, 'Đà Nẵng');
      expect(mapProvider.currentRoute?.distanceKm, daNangDistance);
      expect(mapProvider.currentRoute?.summary, isNot('Late route A'));
    });

    test('Failed route B does not retain route A polyline', () async {
      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      // Init route A successfully
      final tokenA = mapProvider.beginRouteContext();
      await mapProvider.init(
        targetDestination: const LatLng(16.0544, 108.2022),
        targetName: 'Đà Nẵng',
        contextGeneration: tokenA,
      );
      expect(mapProvider.hasRoute, isTrue);

      // Route B throws an error
      fakeRouting.shouldThrowRoutingException = true;

      final tokenB = mapProvider.beginRouteContext();
      await mapProvider.init(
        targetDestination: const LatLng(21.0285, 105.8542),
        targetName: 'Hà Nội',
        contextGeneration: tokenB,
      );

      // Route A's polyline must NOT be retained!
      expect(mapProvider.currentRoute, isNull);
      expect(mapProvider.currentRoute?.points ?? [], isEmpty);
      expect(mapProvider.hasRoute, isFalse);
    });

    test('endRouteContext only clears if generation matches active context', () {
      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      final tokenA = mapProvider.beginRouteContext();
      final tokenB = mapProvider.beginRouteContext();

      // Screen A disposes and calls endRouteContext(tokenA)
      mapProvider.endRouteContext(tokenA);
      // Context B should NOT be ended
      expect(mapProvider.isContextActive(tokenB), isTrue);

      // Screen B disposes
      mapProvider.endRouteContext(tokenB);
      expect(mapProvider.isContextActive(tokenB), isFalse);
    });
  });
}
