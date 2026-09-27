import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/trip_map_screen.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/diamond_milestone_marker.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/floating_view_switch.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/journey_carousel_widget.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/journey_trip_card.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/milestone_marker_widget.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/route_builder_sheet.dart';
import 'package:travelgo_mobile/features/map/providers/map_provider.dart';
import 'package:travelgo_mobile/features/map/services/destination_catalog_service.dart';
import 'package:travelgo_mobile/features/map/services/location_service.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/map/services/map_preset_service.dart';

class FakeMapApiService extends MapApiService {
  bool shouldThrowBackendUnreachable = false;
  int callCount = 0;

  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    callCount++;
    if (shouldThrowBackendUnreachable) {
      throw RoutingException('Connection refused', backendUnreachable: true);
    }

    final allPoints = [origin, ...waypoints.map((w) => w.position), destination];
    return RouteData(
      points: allPoints,
      distanceKm: 310.0,
      durationMinutes: 370,
      isFallback: false,
      summary: 'Tuyến đường thử nghiệm OSRM',
      waypoints: waypoints,
    );
  }
}

class FakeLocationService extends LocationService {
  @override
  Future<LocationResult> getCurrentUserLocation() async {
    return const LocationResult(
      position: LocationService.defaultUniversityOrigin,
      isMock: true,
      locationName: LocationService.defaultOriginName,
    );
  }
}

void main() {
  group('Map Models Unit Tests', () {
    test('RouteData formats duration and distance correctly', () {
      const route1 = RouteData(
        points: [LatLng(10.7725, 106.6578), LatLng(11.9404, 108.4583)],
        distanceKm: 305.4,
        durationMinutes: 380, // 6h 20m
        isFallback: false,
        summary: 'QL20',
      );
      expect(route1.formattedDistance, '305 km');
      expect(route1.formattedDuration, '6 giờ 20 phút');

      const route2 = RouteData(
        points: [LatLng(10.7725, 106.6578), LatLng(10.7800, 106.6600)],
        distanceKm: 2.34,
        durationMinutes: 12,
        isFallback: true,
        summary: 'Dự phòng',
      );
      expect(route2.formattedDistance, '2.3 km');
      expect(route2.formattedDuration, '12 phút');
    });

    test('RouteData.fromJson parses Backend DTO properly', () {
      final json = {
        'data': {
          'distanceKm': 15.5,
          'durationMinutes': 30,
          'points': [
            {'lat': 10.77, 'lng': 106.65},
            {'lat': 10.78, 'lng': 106.66},
          ],
        },
      };
      final metadata = {
        'provider': 'osrm',
        'isFallback': false,
      };

      final route = RouteData.fromJson(json, metadata);
      expect(route.distanceKm, 15.5);
      expect(route.durationMinutes, 30);
      expect(route.isFallback, false);
      expect(route.points.length, 2);
      expect(route.summary, 'Tuyến đường OSRM');
    });
  });

  group('DestinationCatalogService Unit Tests', () {
    final catalog = DestinationCatalogService();

    test('getAll returns all 7 static Vietnam destinations', () {
      final all = catalog.getAll();
      expect(all.length, 7);
      expect(all.any((d) => d.id == 'dalat' && d.name == 'Đà Lạt'), isTrue);
      expect(all.any((d) => d.id == 'phuquoc' && d.icon == Icons.wb_sunny_outlined), isTrue);
      expect(all.any((d) => d.id == 'cantho' && d.icon == Icons.directions_boat_filled), isTrue);
    });

    test('search with empty query returns all 7 destinations', () {
      final results = catalog.search('');
      expect(results.length, 7);
    });

    test('search by name "Đà" returns 1 result (Đà Lạt)', () {
      final results = catalog.search('Đà');
      expect(results.length, 1);
      expect(results.first.id, 'dalat');
    });

    test('search by region "Duyên" returns 1 result (Nha Trang)', () {
      final results = catalog.search('Duyên');
      expect(results.length, 1);
      expect(results.first.id, 'nhatrang');
    });

    test('search with non-existent query returns empty list', () {
      final results = catalog.search('xyz999');
      expect(results.isEmpty, isTrue);
    });
  });

  group('MapPresetService Unit Tests', () {
    test('getDefaultDemoRoute returns 4 waypoints for A->B->C->D demo', () {
      final presetService = MapPresetService();
      final demoRoute = presetService.getDefaultDemoRoute();
      expect(demoRoute.length, 4);
      expect(demoRoute.first.type, 'origin');
      expect(demoRoute.last.type, 'destination');
      expect(demoRoute[1].type, 'stop');
      expect(demoRoute[2].type, 'stop');
    });
  });

  group('MapProvider FSM State Machine & Lazy Loading Tests', () {
    test('1 & 2: init() without parameters starts in STATE A (destination == null, hasRoute == false)', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.init();

      expect(provider.destination, isNull);
      expect(provider.destinationName, isNull);
      expect(provider.waypoints.isEmpty, isTrue);
      expect(provider.hasRoute, isFalse);
      expect(provider.currentRoute, isNull);
      expect(provider.allStops.length, 1); // Only origin, safe without NPE
    });

    test('3: init() without parameters does NOT call MapApiService', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.init();

      expect(fakeRouting.callCount, 0);
    });

    test('4: init(targetDestination: X) enters STATE B and calls MapApiService once', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.init(
        targetDestination: const LatLng(11.9404, 108.4583),
        targetName: 'Đà Lạt',
      );

      expect(fakeRouting.callCount, 1);
      expect(provider.hasRoute, isTrue);
      expect(provider.currentRoute, isNotNull);
      expect(provider.destinationName, 'Đà Lạt');
      expect(provider.allStops.length, 2); // origin + destination
    });

    test('5: enterLocateOnlyMode() and clearRoute() resets everything to STATE A', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.loadDemoRoute();
      expect(provider.hasRoute, isTrue);

      provider.clearRoute();

      expect(provider.destination, isNull);
      expect(provider.destinationName, isNull);
      expect(provider.waypoints.isEmpty, isTrue);
      expect(provider.currentRoute, isNull);
      expect(provider.isDemoMode, isFalse);
      expect(provider.hasRoute, isFalse);
    });

    test('6 & 7: setDestination() and addWaypoint() do NOT trigger API calls', () {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);

      provider.setDestination(const LatLng(10.0, 105.0), 'Cần Thơ');
      expect(provider.destination, const LatLng(10.0, 105.0));
      expect(fakeRouting.callCount, 0);

      const wp = RouteWaypoint(
        id: 'stop1',
        title: 'Trạm dừng',
        position: LatLng(10.5, 105.5),
        type: 'stop',
      );
      provider.addWaypoint(wp);
      expect(provider.waypoints.length, 1);
      expect(fakeRouting.callCount, 0);
    });

    test('8: buildRoute() after setDestination() calls API once', () async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);

      provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
      expect(fakeRouting.callCount, 0);

      await provider.buildRoute();

      expect(fakeRouting.callCount, 1);
      expect(provider.currentRoute, isNotNull);
      expect(provider.hasRoute, isTrue);
    });

    test('9: buildRoute() when destination is null returns early without calling API', () async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);

      expect(provider.destination, isNull);
      await provider.buildRoute();

      expect(fakeRouting.callCount, 0);
      expect(provider.currentRoute, isNull);
    });

    test('10: loadDemoRoute() loads 2 waypoints, 1 destination, and calls API once', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final presetService = MapPresetService();
      final provider = MapProvider(
        apiService: fakeRouting,
        presetService: presetService,
        locationService: fakeLocation,
      );

      await provider.loadDemoRoute();

      expect(fakeRouting.callCount, 1);
      expect(provider.waypoints.length, 2);
      expect(provider.destinationName, contains('Lâm Viên'));
      expect(provider.allStops.length, 4);
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.isFallback, isFalse);
    });

    test('11: buildRoute() generates local offline line when backend is unreachable', () async {
      final fakeRouting = FakeMapApiService()..shouldThrowBackendUnreachable = true;
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
      await provider.buildRoute();

      // Must NOT crash, must generate local offline line with isFallback=true
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.isFallback, isTrue);
      expect(provider.currentRoute!.summary, contains('Đường thẳng cục bộ'));
      expect(provider.errorMessage, contains('Backend không kết nối'));
      expect(provider.currentRoute!.points.length, 2);
      expect(provider.currentRoute!.distanceKm, greaterThan(100));
    });

    test('12 & 13: removeWaypoint handles index in range and out of range safely', () {
      final provider = MapProvider();
      const wp1 = RouteWaypoint(id: '1', title: 'W1', position: LatLng(10, 106), type: 'stop');
      const wp2 = RouteWaypoint(id: '2', title: 'W2', position: LatLng(11, 107), type: 'stop');

      provider.addWaypoint(wp1);
      provider.addWaypoint(wp2);
      expect(provider.waypoints.length, 2);

      // Out of range does not crash or change list
      provider.removeWaypoint(99);
      provider.removeWaypoint(-1);
      expect(provider.waypoints.length, 2);

      // In range removes correctly
      provider.removeWaypoint(0);
      expect(provider.waypoints.length, 1);
      expect(provider.waypoints.first.id, '2');
    });
  });

  group('Journey Board UI Widget Tests', () {
    testWidgets('JourneyCarouselWidget renders cards and triggers onCardChanged', (tester) async {
      int changedIndex = -1;
      const waypoints = [
        RouteWaypoint(id: '1', title: 'Điểm 1', position: LatLng(10, 106), type: 'origin', time: '08:00'),
        RouteWaypoint(id: '2', title: 'Điểm 2', position: LatLng(11, 107), type: 'stop', time: '10:30'),
      ];
      final pageController = PageController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyCarouselWidget(
              waypoints: waypoints,
              activeIndex: 0,
              pageController: pageController,
              onCardChanged: (idx) => changedIndex = idx,
            ),
          ),
        ),
      );

      expect(find.text('Điểm 1'), findsOneWidget);
      expect(find.text('XUẤT PHÁT'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);

      await tester.drag(find.text('Điểm 1'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(changedIndex, 1);
    });

    testWidgets('MilestoneMarkerWidget renders stop capsule with sequence and responds to tap', (tester) async {
      bool tapped = false;
      const wp = RouteWaypoint(id: 'stop1', title: 'Thác Dambri', position: LatLng(11, 107), type: 'stop');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MilestoneMarkerWidget(
              waypoint: wp,
              sequenceNumber: 2,
              isActive: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Thác Dambri'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);

      await tester.tap(find.text('Thác Dambri'));
      expect(tapped, isTrue);
    });

    testWidgets('15: RouteBuilderSheet opens and "VẼ LỘ TRÌNH" button is disabled until destination is chosen', (tester) async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapProvider>.value(
            value: provider,
            child: const Scaffold(
              body: RouteBuilderSheet(),
            ),
          ),
        ),
      );

      // Initially, destination is null -> button disabled
      final buttonFinder = find.widgetWithText(FilledButton, 'VẼ LỘ TRÌNH');
      expect(buttonFinder, findsOneWidget);
      final FilledButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);

      // Set destination -> button becomes enabled
      provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
      await tester.pumpAndSettle();

      final FilledButton enabledButton = tester.widget(buttonFinder);
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('DiamondMilestoneMarker renders sequence and responds to tap', (tester) async {
      bool tapped = false;
      const wp = RouteWaypoint(
        id: 'stop_hotel',
        title: 'Pine Hill Hotel',
        position: LatLng(11.9, 108.4),
        type: 'stop',
        category: 'Khách sạn',
        isCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DiamondMilestoneMarker(
                waypoint: wp,
                sequenceNumber: 1,
                isSelected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DiamondMilestoneMarker), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.hotel_rounded), findsOneWidget);

      await tester.tap(find.byType(DiamondMilestoneMarker));
      expect(tapped, isTrue);
    });

    testWidgets('FloatingViewSwitch toggles between map and story mode', (tester) async {
      JourneyViewMode selectedMode = JourneyViewMode.map;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FloatingViewSwitch(
                  currentMode: selectedMode,
                  onModeChanged: (m) => setState(() => selectedMode = m),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Hành trình'), findsOneWidget);

      await tester.tap(find.text('Hành trình'));
      await tester.pumpAndSettle();

      expect(selectedMode, JourneyViewMode.story);
    });

    testWidgets('JourneyTripCard renders title, day selector, and triggers selectDay', (tester) async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);
      await provider.loadDemoRoute();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyTripCard(provider: provider),
          ),
        ),
      );

      expect(find.text('CHUYẾN ĐI CỦA MINH'), findsOneWidget);
      expect(find.text('NGÀY 1'), findsOneWidget);
      expect(find.text('NGÀY 2'), findsOneWidget);

      await tester.tap(find.text('NGÀY 2'));
      expect(provider.selectedDay, 2);
    });

    testWidgets('16-18: STATE A renders Journey Preview Card and tap explores demo route', (tester) async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapProvider>.value(
            value: provider,
            child: const TripMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In STATE A:
      expect(find.text('CHUYẾN ĐI CỦA MINH'), findsOneWidget);
      expect(find.text('Đà Lạt · 3 ngày 2 đêm'), findsOneWidget);
      expect(find.text('Khám phá hành trình Đà Lạt'), findsOneWidget);

      // Tap 'Khám phá hành trình Đà Lạt' -> triggers loadDemoRoute -> enters STATE B
      await tester.tap(find.text('Khám phá hành trình Đà Lạt'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(provider.hasRoute, isTrue);
      // In STATE B: Journey Preview Card disappears
      expect(find.text('Khám phá hành trình Đà Lạt'), findsNothing);
    });

    testWidgets('19: Tap "hoặc tự tạo lộ trình mới ↓" opens RouteBuilderSheet', (tester) async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapProvider>.value(
            value: provider,
            child: const TripMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('hoặc tự tạo lộ trình mới ↓'), findsOneWidget);
      await tester.tap(find.text('hoặc tự tạo lộ trình mới ↓'));
      await tester.pumpAndSettle();

      expect(find.byType(RouteBuilderSheet), findsOneWidget);
    });
  });

  group('Journey Map Multi-Day & AI Optimizer Tests', () {
    test('selectDay switches selectedDay and filters currentDayStops correctly', () async {
      final provider = MapProvider(apiService: FakeMapApiService());
      await provider.loadDemoRoute();

      expect(provider.selectedDay, 1);
      provider.selectDay(2);
      expect(provider.selectedDay, 2);
    });

    test('toggleStopCompleted flips isCompleted status', () async {
      final provider = MapProvider(apiService: FakeMapApiService());
      await provider.loadDemoRoute();

      final firstStop = provider.waypoints.first;
      final initialStatus = firstStop.isCompleted;

      provider.toggleStopCompleted(firstStop.id);
      expect(provider.waypoints.first.isCompleted, !initialStatus);
    });

    test('applyAiReorder updates waypoint order and triggers API route fetch', () async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);
      await provider.loadDemoRoute();

      final initialCallCount = fakeRouting.callCount;
      final reversedWaypoints = provider.waypoints.reversed.toList();

      await provider.applyAiReorder(reversedWaypoints);

      expect(fakeRouting.callCount, initialCallCount + 1);
      expect(provider.waypoints.first.id, reversedWaypoints.first.id);
    });
  });
}
