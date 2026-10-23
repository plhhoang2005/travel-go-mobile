import 'package:latlong2/latlong.dart';
import '../../explore/models/public_catalogue_snapshot.dart';

/// Presentation-only reference positions; never serialized into a trip.
class ManualPlaceLocation {
  final String placeId, sourceUrl, checkedAt, note;
  final LatLng position;
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
      position: LatLng(21.028888888889, 105.8525),
      sourceUrl: 'https://www.wikidata.org/w/index.php?title=Q1151254&oldid=2519101846',
      checkedAt: '2026-10-17',
      note: 'Vị trí tham khảo của hồ; chưa xác minh lối tiếp cận.',
    ),
    'hue/citadel': ManualPlaceLocation(
      placeId: 'hue/citadel',
      position: LatLng(16.469444444444, 107.57777777778),
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
          if (place.id == id && place.latitude != null && place.longitude != null) {
            final sourceUrl = place.sourceRefs.isNotEmpty
                ? (snapshot.catalogue.source(place.sourceRefs.first).url)
                : '';
            final checkedAt = snapshot.manifest.publishedAt.toIso8601String().substring(0, 10);
            return ManualPlaceLocation(
              placeId: place.id,
              position: LatLng(place.latitude!, place.longitude!),
              sourceUrl: sourceUrl,
              checkedAt: checkedAt,
              note: 'Tọa độ tham khảo từ danh mục phát hành; chưa xác minh lối tiếp cận.',
            );
          }
        }
      }
    }

    return _locations[id];
  }
}
