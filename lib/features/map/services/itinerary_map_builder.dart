import 'package:latlong2/latlong.dart';
import '../../explore/models/catalogue_reference.dart';
import '../../explore/models/public_catalogue_snapshot.dart';
import '../../trip_planner/models/planner_result_snapshot.dart';
import '../models/itinerary_map_context.dart';

class ItineraryMapBuilder {
  static ItineraryMapContext build({
    required PlannerResultSnapshot result,
    required PublicCatalogueSnapshot snapshot,
    Map<String, String> userPlaceBindings = const {},
  }) {
    final destId = result.winner?.id ?? result.request.destinationId ?? '';
    final destName = result.winner?.name ?? result.request.destinationName ?? '';

    // Destination-scoped search
    DestinationReference? matchedDestination;
    for (final dest in snapshot.catalogue.destinations) {
      if (dest.id == destId) {
        matchedDestination = dest;
        break;
      }
    }

    final placesInDestination = matchedDestination?.places ?? const <PlaceReference>[];

    LatLng? destinationCenter;
    for (final p in placesInDestination) {
      if (_isValidCoordinate(p.latitude, p.longitude)) {
        destinationCenter = LatLng(p.latitude!, p.longitude!);
        break;
      }
    }

    final activities = <ItineraryMapActivity>[];

    for (final day in result.plan.itineraryDays) {
      for (var pos = 0; pos < day.activities.length; pos++) {
        final act = day.activities[pos];
        final key = 'day:${day.day}/activity:$pos';

        if (userPlaceBindings.containsKey(key)) {
          final boundId = userPlaceBindings[key]!;
          PlaceReference? boundPlace;
          for (final p in placesInDestination) {
            if (p.id == boundId) {
              boundPlace = p;
              break;
            }
          }

          if (boundPlace != null && _isValidCoordinate(boundPlace.latitude, boundPlace.longitude)) {
            activities.add(
              ItineraryMapActivity(
                key: key,
                dayNumber: day.day,
                position: pos,
                title: act.title,
                time: act.time,
                placeId: boundPlace.id,
                positionOnMap: LatLng(boundPlace.latitude!, boundPlace.longitude!),
                resolution: 'user',
              ),
            );
          } else {
            // Bound ID invalid, hidden, or lacks coordinates: rejected
            activities.add(
              ItineraryMapActivity(
                key: key,
                dayNumber: day.day,
                position: pos,
                title: act.title,
                time: act.time,
                placeId: null,
                positionOnMap: null,
                resolution: 'unresolved',
              ),
            );
          }
        } else {
          // Exact, trimmed, case-folded matching ONLY within the destination
          final target = act.title.trim().toLowerCase();
          final matches = placesInDestination
              .where((p) => p.name.trim().toLowerCase() == target)
              .toList();

          if (matches.length == 1) {
            final matched = matches.first;
            if (_isValidCoordinate(matched.latitude, matched.longitude)) {
              activities.add(
                ItineraryMapActivity(
                  key: key,
                  dayNumber: day.day,
                  position: pos,
                  title: act.title,
                  time: act.time,
                  placeId: matched.id,
                  positionOnMap: LatLng(matched.latitude!, matched.longitude!),
                  resolution: 'catalogueName',
                ),
              );
            } else {
              activities.add(
                ItineraryMapActivity(
                  key: key,
                  dayNumber: day.day,
                  position: pos,
                  title: act.title,
                  time: act.time,
                  placeId: null,
                  positionOnMap: null,
                  resolution: 'unresolved',
                ),
              );
            }
          } else {
            activities.add(
              ItineraryMapActivity(
                key: key,
                dayNumber: day.day,
                position: pos,
                title: act.title,
                time: act.time,
                placeId: null,
                positionOnMap: null,
                resolution: 'unresolved',
              ),
            );
          }
        }
      }
    }

    return ItineraryMapContext(
      result: result,
      snapshot: snapshot,
      destinationId: destId,
      destinationName: destName,
      destinationCenter: destinationCenter,
      activities: activities,
    );
  }

  static bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lng >= -180.0 &&
        lng <= 180.0;
  }
}
