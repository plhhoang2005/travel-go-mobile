import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/services/backend_api_config.dart';
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

class RecordedRouteCall {
  final LatLng origin;
  final LatLng destination;
  final List<RouteWaypoint> waypoints;
  final Completer<RouteData> completer = Completer<RouteData>();

  RecordedRouteCall({
    required this.origin,
    required this.destination,
    required this.waypoints,
  });
}

class ConfigChangedThrowingMapApiService extends MapApiService {
  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    throw BackendConfigChangedException();
  }
}

class ControllableMapApiService extends MapApiService {
  Completer<RouteData>? pendingCompleter;
  bool shouldThrowRoutingException = false;
  int getRouteCalls = 0;
  LatLng? lastOrigin;
  LatLng? lastDestination;
  List<RouteWaypoint>? lastWaypoints;
  bool manualMode = false;
  final List<RecordedRouteCall> recordedCalls = [];

  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    getRouteCalls++;
    lastOrigin = origin;
    lastDestination = destination;
    lastWaypoints = List<RouteWaypoint>.unmodifiable(waypoints);

    if (shouldThrowRoutingException) {
      throw RoutingException('OSRM down');
    }

    if (manualMode) {
      final call = RecordedRouteCall(
        origin: origin,
        destination: destination,
        waypoints: List<RouteWaypoint>.unmodifiable(waypoints),
      );
      recordedCalls.add(call);
      return call.completer.future;
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
  int getUserLocationCalls = 0;
  bool shouldThrow = false;
  LatLng mockPosition = const LatLng(10.7769, 106.7009);

  @override
  Future<LocationResult> getCurrentUserLocation() async {
    getUserLocationCalls++;
    if (shouldThrow) {
      throw StateError('Location permission denied in test');
    }
    return LocationResult(
      position: mockPosition,
      isMock: true,
      locationName: 'TP. Hồ Chí Minh (GPS)',
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

  group('Task B1: Itinerary Route Có Origin Thực (CR3)', () {
    ItineraryMapContext createThreeStopItinerary() {
      final res = createTestResult();
      final snap = createTestSnapshot();
      return ItineraryMapContext(
        result: res,
        snapshot: snap,
        destinationId: 'hue',
        destinationName: 'Huế',
        activities: const [
          ItineraryMapActivity(
            key: 'act-1',
            dayNumber: 1,
            position: 0,
            time: '08:00',
            title: 'Điểm A',
            placeId: 'hue/a',
            positionOnMap: LatLng(16.4698, 107.5775),
            resolution: 'catalogueName',
          ),
          ItineraryMapActivity(
            key: 'act-2',
            dayNumber: 1,
            position: 1,
            time: '11:00',
            title: 'Điểm B',
            placeId: 'hue/b',
            positionOnMap: LatLng(16.4530, 107.5440),
            resolution: 'catalogueName',
          ),
          ItineraryMapActivity(
            key: 'act-3',
            dayNumber: 1,
            position: 2,
            time: '14:00',
            title: 'Điểm C',
            placeId: 'hue/c',
            positionOnMap: LatLng(16.4645, 107.5904),
            resolution: 'catalogueName',
          ),
        ],
      );
    }

    ItineraryMapContext createSingleStopItinerary() {
      final res = createTestResult();
      final snap = createTestSnapshot();
      return ItineraryMapContext(
        result: res,
        snapshot: snap,
        destinationId: 'hue',
        destinationName: 'Huế',
        activities: const [
          ItineraryMapActivity(
            key: 'act-single',
            dayNumber: 1,
            position: 0,
            time: '08:00',
            title: 'Điểm duy nhất',
            placeId: 'hue/single',
            positionOnMap: LatLng(16.4698, 107.5775),
            resolution: 'catalogueName',
          ),
        ],
      );
    }

    testWidgets('itinerary_route_uses_first_located_stop_not_gps', (tester) async {
      final itinerary = createThreeStopItinerary();
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const expectedA = LatLng(16.4698, 107.5775);
      const expectedB = LatLng(16.4530, 107.5440);
      const expectedC = LatLng(16.4645, 107.5904);

      expect(fakeRouting.lastOrigin, expectedA);
      expect(fakeRouting.lastDestination, expectedC);
      expect(fakeRouting.lastWaypoints?.map((w) => w.position).toList(), [expectedB]);
      expect(fakeLocation.getUserLocationCalls, 0);
    });

    testWidgets('itinerary_route_does_not_require_location_permission', (tester) async {
      final itinerary = createThreeStopItinerary();
      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      fakeLocation.shouldThrow = true;
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(mapProvider.hasRoute, isTrue);
      expect(mapProvider.errorMessage, isNull);
      expect(fakeLocation.getUserLocationCalls, 0);
    });

    testWidgets('one_or_zero_located_stops_never_route', (tester) async {
      final singleItinerary = createSingleStopItinerary();
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
              itinerary: singleItinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeRouting.getRouteCalls, 0);
      expect(mapProvider.hasRoute, isFalse);
      expect(fakeLocation.getUserLocationCalls, 0);
    });

    testWidgets('both_dashboard_map_actions_use_same_itinerary_coordinates', (tester) async {
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

      // 1. Trigger via Appbar Action Button
      final appbarMapBtn = find.byTooltip('Xem Bản Đồ & Radar Nhóm');
      expect(appbarMapBtn, findsOneWidget);
      await tester.tap(appbarMapBtn);
      await tester.pumpAndSettle();

      final origin1 = fakeRouting.lastOrigin;
      final dest1 = fakeRouting.lastDestination;
      expect(origin1, isNotNull);
      expect(dest1, isNotNull);

      // Return to Dashboard via back button
      final backBtn = find.byTooltip('Quay lại');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // 2. Trigger via Content Button in Dashboard
      final contentMapBtn = find.text('Xem Lộ Trình Bản Đồ & Radar Nhóm');
      await tester.ensureVisible(contentMapBtn);
      await tester.pumpAndSettle();
      expect(contentMapBtn, findsOneWidget);
      await tester.tap(contentMapBtn);
      await tester.pumpAndSettle();

      final origin2 = fakeRouting.lastOrigin;
      final dest2 = fakeRouting.lastDestination;

      // Both actions MUST produce identical coordinates from the resolved itinerary!
      expect(origin2, origin1);
      expect(dest2, dest1);
    });
  });

  group('Task B2: Context Mới Cho Đổi Ngày / Binding & Camera (CR4)', () {
    ItineraryMapContext createMultiDayItinerary() {
      final res = createTestResult();
      final snap = createTestSnapshot();
      return ItineraryMapContext(
        result: res,
        snapshot: snap,
        destinationId: 'hue',
        destinationName: 'Huế',
        activities: const [
          ItineraryMapActivity(
            key: 'act-1-1',
            dayNumber: 1,
            position: 0,
            time: '08:00',
            title: 'Điểm 1A',
            placeId: 'hue/1a',
            positionOnMap: LatLng(16.4698, 107.5775),
            resolution: 'catalogueName',
          ),
          ItineraryMapActivity(
            key: 'act-1-2',
            dayNumber: 1,
            position: 1,
            time: '14:00',
            title: 'Điểm 1B',
            placeId: 'hue/1b',
            positionOnMap: LatLng(16.4530, 107.5440),
            resolution: 'catalogueName',
          ),
          ItineraryMapActivity(
            key: 'act-2-1',
            dayNumber: 2,
            position: 0,
            time: '09:00',
            title: 'Điểm 2A',
            placeId: 'hue/2a',
            positionOnMap: LatLng(16.4710, 107.5880),
            resolution: 'catalogueName',
          ),
          ItineraryMapActivity(
            key: 'act-2-2',
            dayNumber: 2,
            position: 1,
            time: '15:00',
            title: 'Điểm 2B',
            placeId: 'hue/2b',
            positionOnMap: LatLng(16.4645, 107.5904),
            resolution: 'catalogueName',
          ),
          ItineraryMapActivity(
            key: 'act-3-1',
            dayNumber: 3,
            position: 0,
            time: '08:00',
            title: 'Điểm 3A',
            placeId: 'hue/3a',
            positionOnMap: LatLng(16.4600, 107.5800),
            resolution: 'catalogueName',
          ),
        ],
      );
    }

    testWidgets('day_one_late_success_cannot_replace_day_two', (tester) async {
      final itinerary = createMultiDayItinerary();
      final fakeRouting = ControllableMapApiService()..manualMode = true;
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(fakeRouting.recordedCalls.length, 1);

      // Tap Day 2
      await tester.tap(find.text('Ngày 2'));
      await tester.pump();
      expect(fakeRouting.recordedCalls.length, 2);

      // Complete Day 2 first
      final call2 = fakeRouting.recordedCalls[1];
      call2.completer.complete(
        RouteData(
          points: [call2.origin, call2.destination],
          distanceKm: 10.0,
          durationMinutes: 15,
          isFallback: false,
          summary: 'Day 2 Route',
          waypoints: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(mapProvider.hasRoute, isTrue);
      expect(mapProvider.origin, const LatLng(16.4710, 107.5880)); // Điểm 2A
      expect(mapProvider.destination, const LatLng(16.4645, 107.5904)); // Điểm 2B

      // Now complete Day 1 late
      final call1 = fakeRouting.recordedCalls[0];
      call1.completer.complete(
        RouteData(
          points: [call1.origin, call1.destination],
          distanceKm: 20.0,
          durationMinutes: 30,
          isFallback: false,
          summary: 'Day 1 Route',
          waypoints: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Day 2 geometry and endpoints MUST remain! Day 1 late success cannot replace Day 2!
      expect(mapProvider.hasRoute, isTrue);
      expect(mapProvider.origin, const LatLng(16.4710, 107.5880));
      expect(mapProvider.destination, const LatLng(16.4645, 107.5904));
    });

    testWidgets('old_success_after_new_day_failure_never_restores_old_route', (tester) async {
      final itinerary = createMultiDayItinerary();
      final fakeRouting = ControllableMapApiService()..manualMode = true;
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(fakeRouting.recordedCalls.length, 1);

      // Tap Day 2
      await tester.tap(find.text('Ngày 2'));
      await tester.pump();
      expect(fakeRouting.recordedCalls.length, 2);

      // Fail Day 2 with non-fallback error
      fakeRouting.recordedCalls[1].completer.completeError(
        RoutingException('OSRM server unreachable', backendUnreachable: false),
      );
      await tester.pumpAndSettle();

      expect(mapProvider.hasRoute, isFalse);

      // Now Day 1 completes late
      final call1 = fakeRouting.recordedCalls[0];
      call1.completer.complete(
        RouteData(
          points: [call1.origin, call1.destination],
          distanceKm: 20.0,
          durationMinutes: 30,
          isFallback: false,
          summary: 'Day 1 Route',
          waypoints: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Route MUST stay false! Old success must never restore old route
      expect(mapProvider.hasRoute, isFalse);
    });

    testWidgets('day_with_one_stop_stays_routeless_after_old_response', (tester) async {
      final itinerary = createMultiDayItinerary();
      final fakeRouting = ControllableMapApiService()..manualMode = true;
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(fakeRouting.recordedCalls.length, 1);

      // Tap Day 3 (has only 1 located stop)
      await tester.tap(find.text('Ngày 3'));
      await tester.pumpAndSettle();

      // No new route call for 1 stop
      expect(fakeRouting.recordedCalls.length, 1);
      expect(mapProvider.hasRoute, isFalse);
      expect(mapProvider.isLoading, isFalse);

      // Complete Day 1 late
      final call1 = fakeRouting.recordedCalls[0];
      call1.completer.complete(
        RouteData(
          points: [call1.origin, call1.destination],
          distanceKm: 20.0,
          durationMinutes: 30,
          isFallback: false,
          summary: 'Day 1 Route',
          waypoints: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Must remain routeless
      expect(mapProvider.hasRoute, isFalse);
      expect(mapProvider.isLoading, isFalse);
    });

    testWidgets('rapid_day_a_b_a_and_binding_change_uses_latest_token', (tester) async {
      final itinerary = createMultiDayItinerary();
      final fakeRouting = ControllableMapApiService()..manualMode = true;
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pump();
      final token1 = mapProvider.routeContextGeneration;

      // Switch to Day 2
      await tester.tap(find.text('Ngày 2'));
      await tester.pump();
      final token2 = mapProvider.routeContextGeneration;
      expect(token2, greaterThan(token1));

      // Switch back to Day 1
      await tester.tap(find.text('Ngày 1'));
      await tester.pump();
      final token3 = mapProvider.routeContextGeneration;
      expect(token3, greaterThan(token2));

      expect(fakeRouting.recordedCalls.length, 3);

      // Complete call 3 (latest Day 1)
      final call3 = fakeRouting.recordedCalls[2];
      call3.completer.complete(
        RouteData(
          points: [call3.origin, call3.destination],
          distanceKm: 25.0,
          durationMinutes: 35,
          isFallback: false,
          summary: 'Latest Day 1 Route',
          waypoints: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(mapProvider.hasRoute, isTrue);
      expect(mapProvider.currentRoute!.summary, 'Latest Day 1 Route');

      // Complete call 2 (Day 2) late
      final call2 = fakeRouting.recordedCalls[1];
      call2.completer.complete(
        RouteData(
          points: [call2.origin, call2.destination],
          distanceKm: 10.0,
          durationMinutes: 15,
          isFallback: false,
          summary: 'Stale Day 2 Route',
          waypoints: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Latest Day 1 route still active
      expect(mapProvider.currentRoute!.summary, 'Latest Day 1 Route');
    });

    testWidgets('stale_location_finally_and_camera_do_not_apply', (tester) async {
      final fakeRouting = ControllableMapApiService();
      final fakeLocation = FakeTestLocationService();
      final mapProvider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      // Begin context A
      final tokenA = mapProvider.beginRouteContext();
      // Begin context B while A is in progress
      final tokenB = mapProvider.beginRouteContext();
      expect(mapProvider.isContextActive(tokenA), isFalse);
      expect(mapProvider.isContextActive(tokenB), isTrue);

      // Init itinerary route on old token should immediately exit or return without affecting B
      await mapProvider.initItineraryRoute(
        stops: [
          const RouteWaypoint(id: '1', title: 'A', position: LatLng(10, 10), type: 'stop'),
          const RouteWaypoint(id: '2', title: 'B', position: LatLng(11, 11), type: 'stop'),
        ],
        contextGeneration: tokenA,
      );

      expect(mapProvider.hasRoute, isFalse);
      expect(mapProvider.isLoading, isFalse);
    });

    testWidgets('dispose_releases_owned_context_without_clearing_new_owner', (tester) async {
      final itinerary = createMultiDayItinerary();
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
              itinerary: itinerary,
              enableNetworkTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final screenToken = mapProvider.routeContextGeneration;

      // Another owner begins new context
      final newToken = mapProvider.beginRouteContext();
      expect(newToken, greaterThan(screenToken));

      // Dispose Screen
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // newToken MUST NOT be cleared by old screen disposing screenToken!
      expect(mapProvider.isContextActive(newToken), isTrue);
    });
  });

  group('Task B3: Revision Bao Cả OSRM và Caller (CR7)', () {
    test('config_change_does_not_create_local_line_in_provider', () async {
      final exceptionThrowingService = ConfigChangedThrowingMapApiService();
      final mapProvider = MapProvider(
        apiService: exceptionThrowingService,
        locationService: FakeTestLocationService(),
      );

      final token = mapProvider.beginRouteContext();
      await mapProvider.initItineraryRoute(
        stops: [
          const RouteWaypoint(id: '1', title: 'A', position: LatLng(16.0, 108.0), type: 'stop'),
          const RouteWaypoint(id: '2', title: 'B', position: LatLng(16.1, 108.1), type: 'stop'),
        ],
        contextGeneration: token,
      );

      expect(mapProvider.hasRoute, isFalse);
      expect(mapProvider.currentRoute, isNull);
      expect(mapProvider.errorMessage, contains('Cấu hình'));
    });
  });
}
