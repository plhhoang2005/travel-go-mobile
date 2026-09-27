import 'package:latlong2/latlong.dart';

enum MapMode {
  routing,
}

enum GroupMemberStatus {
  online,
  idle,
  offline,
}

class GroupMemberLocation {
  final String memberId;
  final String displayName;
  final String avatarInitials;
  final LatLng position;
  final DateTime updatedAt;
  final GroupMemberStatus status;
  final bool isDemo;

  const GroupMemberLocation({
    required this.memberId,
    required this.displayName,
    required this.avatarInitials,
    required this.position,
    required this.updatedAt,
    required this.status,
    required this.isDemo,
  });

  GroupMemberLocation copyWith({
    LatLng? position,
    DateTime? updatedAt,
    GroupMemberStatus? status,
  }) {
    return GroupMemberLocation(
      memberId: memberId,
      displayName: displayName,
      avatarInitials: avatarInitials,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isDemo: isDemo,
    );
  }
}

class RouteWaypoint {
  final String id;
  final String title;
  final LatLng position;
  final String type; // 'origin', 'destination', 'stop', 'activity'
  final String? time;
  final int dayNumber;
  final String? category;
  final String? imageUrl;
  final String? openingHours;
  final double? rating;
  final bool isCompleted;

  const RouteWaypoint({
    required this.id,
    required this.title,
    required this.position,
    required this.type,
    this.time,
    this.dayNumber = 1,
    this.category,
    this.imageUrl,
    this.openingHours,
    this.rating,
    this.isCompleted = false,
  });

  RouteWaypoint copyWith({
    String? id,
    String? title,
    LatLng? position,
    String? type,
    String? time,
    int? dayNumber,
    String? category,
    String? imageUrl,
    String? openingHours,
    double? rating,
    bool? isCompleted,
  }) {
    return RouteWaypoint(
      id: id ?? this.id,
      title: title ?? this.title,
      position: position ?? this.position,
      type: type ?? this.type,
      time: time ?? this.time,
      dayNumber: dayNumber ?? this.dayNumber,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      openingHours: openingHours ?? this.openingHours,
      rating: rating ?? this.rating,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
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
