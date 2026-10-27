import '../models/public_catalogue_snapshot.dart';

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}

/// Presentation-only reference positions; never serialized into a trip.
class ManualPlaceLocation {
  final String placeId, sourceUrl, checkedAt, note;
  final GeoPoint position;
  const ManualPlaceLocation({
    required this.placeId,
    required this.position,
    required this.sourceUrl,
    required this.checkedAt,
    required this.note,
  });
}

class ManualPlaceLocations {
  ManualPlaceLocations._();
  // Wikidata P625 read 2026-10-17. These are area reference positions, not
  // verified entrances or arrival/routing points. Other IDs remain unknown.
  static const _locations = {
    'ha-noi/hoan-kiem': ManualPlaceLocation(
      placeId: 'ha-noi/hoan-kiem',
      position: GeoPoint(21.028888888889, 105.8525),
      sourceUrl: 'https://www.wikidata.org/w/index.php?title=Q1151254&oldid=2519101846',
      checkedAt: '2026-10-17',
      note: 'Vị trí tham khảo của hồ; chưa xác minh lối tiếp cận.',
    ),
    'hue/citadel': ManualPlaceLocation(
      placeId: 'hue/citadel',
      position: GeoPoint(16.469444444444, 107.57777777778),
      sourceUrl: 'https://www.wikidata.org/w/index.php?title=Q10769129&oldid=2521036693',
      checkedAt: '2026-10-17',
      note: 'Vị trí tham khảo khu Hoàng thành bên trong Kinh thành; chưa xác minh cổng vào.',
    ),
  };

  static ManualPlaceLocation? forPlace(String? id) => find(id);

  static ManualPlaceLocation? find(String? id, {PublicCatalogueSnapshot? snapshot}) {
    if (id == null) return null;

    if (snapshot != null) {
      for (final destination in snapshot.catalogue.destinations) {
        for (final place in destination.places) {
          if (place.id == id) {
            final lat = place.latitude;
            final lng = place.longitude;
            if (lat != null &&
                lng != null &&
                lat.isFinite &&
                lng.isFinite &&
                lat >= -90.0 &&
                lat <= 90.0 &&
                lng >= -180.0 &&
                lng <= 180.0) {
              String sourceUrl = '';
              if (place.sourceRefs.isNotEmpty) {
                try {
                  sourceUrl = snapshot.catalogue.source(place.sourceRefs.first).url;
                } catch (_) {}
              }
              final checkedAt = snapshot.manifest.publishedAt.toIso8601String().substring(0, 10);
              return ManualPlaceLocation(
                placeId: place.id,
                position: GeoPoint(lat, lng),
                sourceUrl: sourceUrl,
                checkedAt: checkedAt,
                note: 'Tọa độ tham khảo từ danh mục phát hành; chưa xác minh lối tiếp cận.',
              );
            }
            // Found in snapshot, but coords missing or invalid: do NOT fallback to static reference
            return null;
          }
        }
      }
    }

    return _locations[id];
  }
}

