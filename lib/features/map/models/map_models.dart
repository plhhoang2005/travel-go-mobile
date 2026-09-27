import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum MapMode {
  routing,
  radar,
}

enum MemberSafetyStatus {
  safe,
  warning,
  danger;

  String get label {
    switch (this) {
      case MemberSafetyStatus.safe:
        return 'Khoảng cách an toàn';
      case MemberSafetyStatus.warning:
        return 'Cảnh báo tách đoàn';
      case MemberSafetyStatus.danger:
        return 'Cảnh báo đi lạc';
    }
  }

  Color get color {
    switch (this) {
      case MemberSafetyStatus.safe:
        return const Color(0xFF10B981); // Emerald green
      case MemberSafetyStatus.warning:
        return const Color(0xFFF59E0B); // Amber yellow
      case MemberSafetyStatus.danger:
        return const Color(0xFFEF4444); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case MemberSafetyStatus.safe:
        return const Color(0xFFECFDF5);
      case MemberSafetyStatus.warning:
        return const Color(0xFFFFFBEB);
      case MemberSafetyStatus.danger:
        return const Color(0xFFFEF2F2);
    }
  }

  IconData get icon {
    switch (this) {
      case MemberSafetyStatus.safe:
        return Icons.verified_user_outlined;
      case MemberSafetyStatus.warning:
        return Icons.warning_amber_rounded;
      case MemberSafetyStatus.danger:
        return Icons.error_outline_rounded;
    }
  }
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

class GroupMember {
  final String id;
  final String name;
  final String avatarText;
  final Color avatarColor;
  final LatLng position;
  final bool isLeader;
  final double distanceToLeaderMeters;
  final DateTime lastUpdated;

  const GroupMember({
    required this.id,
    required this.name,
    required this.avatarText,
    required this.avatarColor,
    required this.position,
    this.isLeader = false,
    this.distanceToLeaderMeters = 0.0,
    required this.lastUpdated,
  });

  MemberSafetyStatus get status {
    if (isLeader) return MemberSafetyStatus.safe;
    if (distanceToLeaderMeters < 200) {
      return MemberSafetyStatus.safe;
    } else if (distanceToLeaderMeters <= 1000) {
      return MemberSafetyStatus.warning;
    } else {
      return MemberSafetyStatus.danger;
    }
  }

  String get formattedDistance {
    if (isLeader) return 'Trưởng nhóm (Vị trí gốc)';
    if (distanceToLeaderMeters >= 1000) {
      final km = distanceToLeaderMeters / 1000;
      return '${km.toStringAsFixed(2)} km';
    }
    return '${distanceToLeaderMeters.toStringAsFixed(0)} m';
  }

  GroupMember copyWith({
    LatLng? position,
    double? distanceToLeaderMeters,
    DateTime? lastUpdated,
  }) {
    return GroupMember(
      id: id,
      name: name,
      avatarText: avatarText,
      avatarColor: avatarColor,
      position: position ?? this.position,
      isLeader: isLeader,
      distanceToLeaderMeters: distanceToLeaderMeters ?? this.distanceToLeaderMeters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
