import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/services/route_optimizer_service.dart';

void main() {
  group('RouteOptimizerService Tests', () {
    late RouteOptimizerService optimizer;

    setUp(() {
      optimizer = const RouteOptimizerService();
    });

    test('calculateDistance returns approximate Haversine distance in km', () {
      // Ho Chi Minh City Center (10.7769, 106.7009) to Vung Tau (10.3460, 107.0843) ~ 65-70 km direct
      const p1 = LatLng(10.7769, 106.7009);
      const p2 = LatLng(10.3460, 107.0843);

      final dist = optimizer.calculateDistance(p1, p2);
      expect(dist, greaterThan(60.0));
      expect(dist, lessThan(80.0));
    });

    test('optimize returns hasImprovement=false when waypoints count < 2', () {
      const origin = LatLng(10.7769, 106.7009);
      const destination = LatLng(10.3460, 107.0843);
      final waypoints = [
        const RouteWaypoint(
          id: 'wp1',
          title: 'Điểm 1',
          position: LatLng(10.5, 106.8),
          type: 'stop',
        ),
      ];

      final result = optimizer.optimize(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      expect(result.hasImprovement, isFalse);
      expect(result.distanceSavedKm, closeTo(0.0, 0.001));
      expect(result.reorderedWaypoints.length, equals(1));
    });

    test('optimize correctly finds shorter route when waypoints are zig-zagged', () {
      // Straight line on latitude from x=1.0 to x=4.0
      // Origin: (10.0, 106.0)
      // WP A: (10.0, 106.3)
      // WP B: (10.0, 106.1)
      // WP C: (10.0, 106.2)
      // Destination: (10.0, 106.4)
      //
      // Order [A, B, C] zig-zags back and forth:
      // 106.0 -> 106.3 -> 106.1 -> 106.2 -> 106.4
      // Distance is ~ 0.3 + 0.2 + 0.1 + 0.2 = 0.8
      // Optimal [B, C, A]:
      // 106.0 -> 106.1 -> 106.2 -> 106.3 -> 106.4
      // Distance is ~ 0.4
      const origin = LatLng(10.0, 106.0);
      const destination = LatLng(10.0, 106.4);

      final waypoints = [
        const RouteWaypoint(
          id: 'A',
          title: 'Điểm A',
          position: LatLng(10.0, 106.3),
          type: 'stop',
        ),
        const RouteWaypoint(
          id: 'B',
          title: 'Điểm B',
          position: LatLng(10.0, 106.1),
          type: 'stop',
        ),
        const RouteWaypoint(
          id: 'C',
          title: 'Điểm C',
          position: LatLng(10.0, 106.2),
          type: 'stop',
        ),
      ];

      final result = optimizer.optimize(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      expect(result.hasImprovement, isTrue);
      expect(result.distanceSavedKm, greaterThan(0.0));
      expect(result.timeSavedMinutes, greaterThanOrEqualTo(1));
      expect(result.reorderedWaypoints.map((w) => w.id).toList(), equals(['B', 'C', 'A']));
    });

    test('optimize preserves dayNumber and isCompleted attributes on reordered waypoints', () {
      const origin = LatLng(10.0, 106.0);
      const destination = LatLng(10.0, 106.4);

      final waypoints = [
        const RouteWaypoint(
          id: 'A',
          title: 'Điểm A',
          position: LatLng(10.0, 106.3),
          type: 'stop',
          dayNumber: 2,
          isCompleted: true,
        ),
        const RouteWaypoint(
          id: 'B',
          title: 'Điểm B',
          position: LatLng(10.0, 106.1),
          type: 'stop',
          dayNumber: 1,
          isCompleted: false,
        ),
      ];

      final result = optimizer.optimize(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );

      final reorderedB = result.reorderedWaypoints.firstWhere((w) => w.id == 'B');
      expect(reorderedB.dayNumber, equals(1));
      expect(reorderedB.isCompleted, isFalse);

      final reorderedA = result.reorderedWaypoints.firstWhere((w) => w.id == 'A');
      expect(reorderedA.dayNumber, equals(2));
      expect(reorderedA.isCompleted, isTrue);
    });
  });
}
