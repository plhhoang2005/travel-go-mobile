import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/services/location_service.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/map/providers/map_provider.dart';

class FakeMapApiService extends MapApiService {
  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    return RouteData(
      points: [origin, destination],
      distanceKm: 300.0,
      durationMinutes: 360,
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

  group('Location Service Unit Tests', () {
    final locationService = LocationService();

    test('calculateDistanceMeters computes reasonable Haversine distances', () {
      const p1 = LatLng(10.7725, 106.6578);
      const p2 = LatLng(10.7735, 106.6578);
      final dist = locationService.calculateDistanceMeters(p1, p2);
      expect(dist, greaterThan(100));
      expect(dist, lessThan(125));
    });
  });

  group('MapProvider Unit Tests', () {
    test('MapProvider initializes and fetches route cleanly with FakeMapApiService', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(apiService: fakeRouting, locationService: fakeLocation);
      await provider.init();

      expect(provider.currentMode, MapMode.routing);
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.distanceKm, 300.0);
      expect(provider.currentRoute!.isFallback, isFalse);
      expect(provider.origin, LocationService.defaultUniversityOrigin);
    });

    test('MapProvider loadRoute updates waypoints and destination', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(apiService: fakeRouting, locationService: fakeLocation);

      await provider.loadRoute(
        customDestination: const LatLng(10.0333, 105.7833),
        customDestName: 'Cần Thơ',
        customWaypoints: [
          const RouteWaypoint(
            id: 'wp1',
            title: 'Trạm Tiền Giang',
            position: LatLng(10.3600, 106.3600),
            type: 'activity',
          ),
        ],
      );

      expect(provider.destinationName, 'Cần Thơ');
      expect(provider.waypoints.length, 1);
      expect(provider.waypoints.first.title, 'Trạm Tiền Giang');
      expect(provider.currentRoute, isNotNull);
    });
  });
}
