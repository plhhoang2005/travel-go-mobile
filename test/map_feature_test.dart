import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/services/location_service.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/map/services/map_preset_service.dart';
import 'package:travelgo_mobile/features/map/providers/map_provider.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/milestone_marker_widget.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/journey_carousel_widget.dart';

class FakeMapApiService extends MapApiService {
  bool shouldThrowBackendUnreachable = false;

  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
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

  group('MapProvider Multi-Stop & Offline Resilience Tests', () {
    test('MapProvider initializes with demo preset when waypoints are not provided', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final presetService = MapPresetService();
      final provider = MapProvider(
        apiService: fakeRouting,
        presetService: presetService,
        locationService: fakeLocation,
      );

      await provider.init();

      expect(provider.waypoints.length, 2); // 2 intermediate stops (Đồng Nai & Dambri)
      expect(provider.destinationName, contains('Lâm Viên'));
      expect(provider.allStops.length, 4);
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.isFallback, isFalse);
      expect(provider.currentRoute!.points.length, 4);
    });

    test('MapProvider generates local offline line when backend is down/unreachable', () async {
      final fakeRouting = FakeMapApiService()..shouldThrowBackendUnreachable = true;
      final fakeLocation = FakeLocationService();
      final presetService = MapPresetService();
      final provider = MapProvider(
        apiService: fakeRouting,
        presetService: presetService,
        locationService: fakeLocation,
      );

      await provider.init();

      // Must NOT crash, must generate local offline line with isFallback=true
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.isFallback, isTrue);
      expect(provider.currentRoute!.summary, contains('Đường thẳng cục bộ'));
      expect(provider.errorMessage, contains('Backend không kết nối'));
      expect(provider.currentRoute!.points.length, 4);
      expect(provider.currentRoute!.distanceKm, greaterThan(200));
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
  });
}
