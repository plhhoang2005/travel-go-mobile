import 'package:latlong2/latlong.dart';

enum MapMode {
  routing,
}

class RouteWaypoint {
  final String id;
  final String title;
  final LatLng position;
  final String type; // 'origin', 'destination', 'activity'
  final String? time;

  const RouteWaypoint({
    required this.id,
    required this.title,
    required this.position,
    required this.type,
    this.time,
  });
}

class RouteData {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final bool isFallback;
  final String summary;
  final List<RouteWaypoint> waypoints;

  const RouteData({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.isFallback,
    required this.summary,
    this.waypoints = const [],
  });

  factory RouteData.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    final data = json['data'] as Map<String, dynamic>;
    final points = (data['points'] as List).map((p) => LatLng(p['lat'], p['lng'])).toList();
    return RouteData(
      points: points,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      durationMinutes: data['durationMinutes'] as int,
      isFallback: metadata['isFallback'] as bool? ?? false,
      summary: metadata['provider'] == 'osrm' ? 'Tuyến đường OSRM' : 'Lộ trình ngoại tuyến dự phòng',
    );
  }

  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours giờ $mins phút';
    } else if (hours > 0) {
      return '$hours giờ';
    } else {
      return '$mins phút';
    }
  }

  String get formattedDistance {
    if (distanceKm >= 10) {
      return '${distanceKm.toStringAsFixed(0)} km';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }
}
