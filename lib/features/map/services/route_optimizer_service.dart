import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';

class OptimizationResult {
  final List<RouteWaypoint> reorderedWaypoints;
  final double originalDistanceKm;
  final double optimizedDistanceKm;
  final double distanceSavedKm;
  final int timeSavedMinutes;
  final bool hasImprovement;

  const OptimizationResult({
    required this.reorderedWaypoints,
    required this.originalDistanceKm,
    required this.optimizedDistanceKm,
    required this.distanceSavedKm,
    required this.timeSavedMinutes,
    required this.hasImprovement,
  });
}

class RouteOptimizerService {
  const RouteOptimizerService();

  static const double _earthRadiusKm = 6371.0;

  /// Calculates the Haversine direct distance between two coordinates in kilometers.
  double calculateDistance(LatLng p1, LatLng p2) {
    final dLat = _degToRad(p2.latitude - p1.latitude);
    final dLon = _degToRad(p2.longitude - p1.longitude);

    final lat1 = _degToRad(p1.latitude);
    final lat2 = _degToRad(p2.latitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Calculates total sequence distance from origin -> waypoints -> destination
  double calculateTotalDistance({
    required LatLng origin,
    LatLng? destination,
    required List<RouteWaypoint> waypoints,
  }) {
    if (waypoints.isEmpty) {
      if (destination != null) {
        return calculateDistance(origin, destination);
      }
      return 0.0;
    }

    double total = 0.0;
    LatLng current = origin;

    for (final wp in waypoints) {
      total += calculateDistance(current, wp.position);
      current = wp.position;
    }

    if (destination != null) {
      total += calculateDistance(current, destination);
    }

    return total;
  }

  /// Optimizes waypoint order using Nearest Neighbor + 2-Opt TSP algorithm.
  OptimizationResult optimize({
    required LatLng origin,
    LatLng? destination,
    required List<RouteWaypoint> waypoints,
  }) {
    if (waypoints.length < 2) {
      final origDist = calculateTotalDistance(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );
      return OptimizationResult(
        reorderedWaypoints: List.unmodifiable(waypoints),
        originalDistanceKm: origDist,
        optimizedDistanceKm: origDist,
        distanceSavedKm: 0.0,
        timeSavedMinutes: 0,
        hasImprovement: false,
      );
    }

    final origDist = calculateTotalDistance(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );

    List<RouteWaypoint> bestOrder;

    if (waypoints.length <= 7) {
      // Small number of waypoints: exhaustive search guarantees global optimal
      bestOrder = _findBestPermutation(origin, destination, waypoints);
    } else {
      // Larger number: Nearest Neighbor seed followed by 2-Opt iterations
      bestOrder = _runNearestNeighborWith2Opt(origin, destination, waypoints);
    }

    final optDist = calculateTotalDistance(
      origin: origin,
      destination: destination,
      waypoints: bestOrder,
    );

    final savedKm = origDist - optDist;
    final hasImprovement = savedKm > 0.05; // At least 50m saved
    final timeSavedMinutes = hasImprovement
        ? math.max(1, (savedKm / 35.0 * 60).round()) // Assumes ~35 km/h urban speed
        : 0;

    return OptimizationResult(
      reorderedWaypoints: bestOrder,
      originalDistanceKm: origDist,
      optimizedDistanceKm: optDist,
      distanceSavedKm: hasImprovement ? savedKm : 0.0,
      timeSavedMinutes: timeSavedMinutes,
      hasImprovement: hasImprovement,
    );
  }

  List<RouteWaypoint> _findBestPermutation(
    LatLng origin,
    LatLng? destination,
    List<RouteWaypoint> waypoints,
  ) {
    List<RouteWaypoint>? best;
    double bestDist = double.infinity;

    void permute(List<RouteWaypoint> current, List<RouteWaypoint> remaining) {
      if (remaining.isEmpty) {
        final dist = calculateTotalDistance(
          origin: origin,
          destination: destination,
          waypoints: current,
        );
        if (dist < bestDist) {
          bestDist = dist;
          best = List<RouteWaypoint>.from(current);
        }
        return;
      }

      for (int i = 0; i < remaining.length; i++) {
        final next = remaining[i];
        final nextRemaining = List<RouteWaypoint>.from(remaining)..removeAt(i);
        permute([...current, next], nextRemaining);
      }
    }

    permute([], waypoints);
    return best ?? waypoints;
  }

  List<RouteWaypoint> _runNearestNeighborWith2Opt(
    LatLng origin,
    LatLng? destination,
    List<RouteWaypoint> waypoints,
  ) {
    // 1. Greedy Nearest Neighbor
    final unvisited = List<RouteWaypoint>.from(waypoints);
    final ordered = <RouteWaypoint>[];
    LatLng currentPos = origin;

    while (unvisited.isNotEmpty) {
      int nearestIdx = 0;
      double minDist = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final d = calculateDistance(currentPos, unvisited[i].position);
        if (d < minDist) {
          minDist = d;
          nearestIdx = i;
        }
      }

      final nearest = unvisited.removeAt(nearestIdx);
      ordered.add(nearest);
      currentPos = nearest.position;
    }

    // 2. 2-Opt heuristic refinement
    bool improved = true;
    int iterations = 0;
    while (improved && iterations < 50) {
      improved = false;
      iterations++;

      for (int i = 0; i < ordered.length - 1; i++) {
        for (int k = i + 1; k < ordered.length; k++) {
          final candidate = _twoOptSwap(ordered, i, k);
          final currentDist = calculateTotalDistance(
            origin: origin,
            destination: destination,
            waypoints: ordered,
          );
          final newDist = calculateTotalDistance(
            origin: origin,
            destination: destination,
            waypoints: candidate,
          );

          if (newDist < currentDist - 0.001) {
            ordered.clear();
            ordered.addAll(candidate);
            improved = true;
            break;
          }
        }
        if (improved) break;
      }
    }

    return ordered;
  }

  List<RouteWaypoint> _twoOptSwap(List<RouteWaypoint> route, int i, int k) {
    final newRoute = <RouteWaypoint>[];
    for (int c = 0; c < i; c++) {
      newRoute.add(route[c]);
    }
    for (int c = k; c >= i; c--) {
      newRoute.add(route[c]);
    }
    for (int c = k + 1; c < route.length; c++) {
      newRoute.add(route[c]);
    }
    return newRoute;
  }
}
