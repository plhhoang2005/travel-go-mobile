// Unified immutable catalogue snapshot ensuring atomic consistency between
// public metadata (Layer A: Discovery) and operational visit facts (Layer B: Visit Grounding).

import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/trip_planner/models/ai_context_grounding.dart';

@immutable
class UnifiedCatalogueSnapshot {
  final int version;
  final String releaseSha256;
  final DateTime publishedAt;
  final DateTime fetchedAt;
  final String origin;
  final CatalogueReference catalogue;
  final VisitCatalogue visits;
  final Set<String> placeIds;

  const UnifiedCatalogueSnapshot._({
    required this.version,
    required this.releaseSha256,
    required this.publishedAt,
    required this.fetchedAt,
    required this.origin,
    required this.catalogue,
    required this.visits,
    required this.placeIds,
  });

  /// Factory creating an atomically verified unified snapshot from a PublicCatalogueSnapshot V2.
  factory UnifiedCatalogueSnapshot.fromPublicSnapshot(PublicCatalogueSnapshot snapshot) {
    if (snapshot.version != snapshot.visits.version) {
      throw FormatException(
        'Catalogue version mismatch: metadata version ${snapshot.version} != visit version ${snapshot.visits.version}',
      );
    }

    final allPlaceIds = <String>{};
    for (final dest in snapshot.catalogue.destinations) {
      for (final place in dest.places) {
        allPlaceIds.add(place.id);
      }
    }

    return UnifiedCatalogueSnapshot._(
      version: snapshot.version,
      releaseSha256: snapshot.sha256,
      publishedAt: snapshot.manifest.publishedAt,
      fetchedAt: snapshot.fetchedAt,
      origin: snapshot.origin,
      catalogue: snapshot.catalogue,
      visits: snapshot.visits,
      placeIds: Set.unmodifiable(allPlaceIds),
    );
  }

  /// Factory for standalone/testing or composite manual assembly with strict consistency checks.
  factory UnifiedCatalogueSnapshot.composite({
    required int version,
    required String releaseSha256,
    required DateTime publishedAt,
    required DateTime fetchedAt,
    required String origin,
    required CatalogueReference catalogue,
    required VisitCatalogue visits,
  }) {
    if (version != visits.version) {
      throw FormatException(
        'Composite version mismatch: catalogue version $version != visits version ${visits.version}',
      );
    }

    final allPlaceIds = <String>{};
    for (final dest in catalogue.destinations) {
      for (final place in dest.places) {
        allPlaceIds.add(place.id);
      }
    }

    return UnifiedCatalogueSnapshot._(
      version: version,
      releaseSha256: releaseSha256,
      publishedAt: publishedAt,
      fetchedAt: fetchedAt,
      origin: origin,
      catalogue: catalogue,
      visits: visits,
      placeIds: Set.unmodifiable(allPlaceIds),
    );
  }

  /// Tra cứu đồng thời cả metadata tham chiếu và facts tham quan cho một địa điểm.
  (PlaceReference?, PlaceVisitDetails?) lookupPlace(String placeId) {
    PlaceReference? reference;
    for (final dest in catalogue.destinations) {
      for (final place in dest.places) {
        if (place.id == placeId) {
          reference = place;
          break;
        }
      }
      if (reference != null) break;
    }

    final facts = visits.places[placeId];
    return (reference, facts);
  }

  /// Đánh giá nhanh trạng thái hoạt động thực tế của địa điểm theo rào chắn R1-R5.
  GroundedPlaceFacts evaluatePlace({
    required String placeId,
    DateTime? date,
    int? startMinute,
    int? endMinute,
  }) {
    final details = visits.places[placeId];
    return evaluatePlaceGrounding(
      placeId: placeId,
      details: details,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  /// Kiểm tra xem địa điểm có tồn tại trong bản phát hành đã xác thực hay không.
  bool containsPlace(String placeId) => placeIds.contains(placeId);

  /// Lấy danh sách địa điểm theo điểm đến cụ thể.
  List<PlaceReference> placesForDestination(String destinationId) {
    final dest = catalogue.destinations
        .where((d) => d.id == destinationId)
        .firstOrNull;
    return dest?.places ?? const [];
  }
}
