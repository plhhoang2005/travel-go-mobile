import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../explore/models/public_catalogue_snapshot.dart';
import '../../trip_planner/models/planner_result_snapshot.dart';

@immutable
class ItineraryMapActivity {
  final String key;
  final int dayNumber;
  final int position;
  final String title;
  final String time;
  final String? placeId;
  final LatLng? positionOnMap;
  final String resolution; // 'catalogueName', 'user', 'unresolved'

  const ItineraryMapActivity({
    required this.key,
    required this.dayNumber,
    required this.position,
    required this.title,
    required this.time,
    this.placeId,
    this.positionOnMap,
    required this.resolution,
  });

  bool get isLocated => positionOnMap != null;

  ItineraryMapActivity copyWith({
    String? placeId,
    LatLng? positionOnMap,
    String? resolution,
  }) {
    return ItineraryMapActivity(
      key: key,
      dayNumber: dayNumber,
      position: position,
      title: title,
      time: time,
      placeId: placeId ?? this.placeId,
      positionOnMap: positionOnMap ?? this.positionOnMap,
      resolution: resolution ?? this.resolution,
    );
  }
}

@immutable
class ItineraryMapContext {
  final PlannerResultSnapshot result;
  final PublicCatalogueSnapshot snapshot;
  final String destinationId;
  final String destinationName;
  final LatLng? destinationCenter;
  final List<ItineraryMapActivity> activities;

  const ItineraryMapContext({
    required this.result,
    required this.snapshot,
    required this.destinationId,
    required this.destinationName,
    this.destinationCenter,
    required this.activities,
  });

  int get snapshotVersion => snapshot.version;
  String get snapshotSha256 => snapshot.sha256;

  List<ItineraryMapActivity> activitiesForDay(int dayNumber) {
    return activities.where((a) => a.dayNumber == dayNumber).toList();
  }

  List<int> get dayNumbers {
    final days = activities.map((a) => a.dayNumber).toSet().toList()..sort();
    return days;
  }
}
