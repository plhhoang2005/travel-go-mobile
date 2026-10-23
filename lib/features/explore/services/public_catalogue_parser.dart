// Strict parser for Discovery Release V2 public bundles and cross-runtime snapshot integrity.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';

class PublicCatalogueParser {
  static PublicCatalogueSnapshot parse({
    required String payloadText,
    required DiscoveryManifest manifest,
    required DateTime now,
    String origin = 'remote',
  }) {
    // 1. Raw byte length and whole-bundle SHA-256 integrity check
    final rawBytes = utf8.encode(payloadText);
    if (rawBytes.length != manifest.byteLength) {
      throw FormatException(
        'Release byte length mismatch: expected ${manifest.byteLength}, actual ${rawBytes.length}',
      );
    }

    final computedSha = sha256.convert(rawBytes).toString();
    if (computedSha != manifest.sha256) {
      throw FormatException(
        'Release SHA-256 integrity mismatch: expected ${manifest.sha256}, computed $computedSha',
      );
    }

    // 2. Decode and validate bundle envelope
    final Object? decoded = jsonDecode(payloadText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Release bundle must be a JSON object');
    }

    final contract = decoded['contract'] as String? ?? '';
    if (contract != 'travelgo.discovery.release.v2') {
      throw FormatException('Invalid release contract: $contract');
    }

    final schemaVersion = decoded['schemaVersion'] as int? ?? 0;
    if (schemaVersion != 2) {
      throw FormatException('Unsupported release schemaVersion: $schemaVersion');
    }

    final version = decoded['version'] as int? ?? 0;
    if (version != manifest.version) {
      throw FormatException('Release version mismatch: expected ${manifest.version}, bundle had $version');
    }

    final preparedAt = decoded['preparedAt'] as String? ?? '';

    // 3. Parse catalogue section
    final catalogueMap = decoded['catalogue'] as Map<String, dynamic>? ?? const {};
    final rawSources = catalogueMap['sources'] as List? ?? const [];
    final sources = <SourceReference>[];

    for (final s in rawSources) {
      if (s is Map<String, dynamic>) {
        sources.add(SourceReference(
          id: s['id'] as String? ?? '',
          title: s['title'] as String? ?? '',
          publisher: s['publisher'] as String? ?? '',
          url: s['url'] as String? ?? '',
          checkedAt: s['checkedAt'] as String? ?? preparedAt,
        ));
      }
    }

    final rawDestinations = catalogueMap['destinations'] as List? ?? const [];
    final destinations = <DestinationReference>[];
    final allPlaceIds = <String>{};

    for (final d in rawDestinations) {
      if (d is Map<String, dynamic>) {
        final destId = d['id'] as String? ?? '';
        final destName = d['name'] as String? ?? '';
        final destRegion = d['region'] as String? ?? '';
        final destDesc = d['description'] as String?;
        final destImageUrl = d['imageUrl'] as String?;
        final destImageRights = d['imageRights'] as Map<String, dynamic>?;
        final rawSourceRefs = d['sourceRefs'] as List? ?? const [];
        final sourceRefs = rawSourceRefs.map((e) => e.toString()).toList();

        final rawPlaces = d['places'] as List? ?? const [];
        final places = <PlaceReference>[];

        for (final p in rawPlaces) {
          if (p is Map<String, dynamic>) {
            final placeId = p['id'] as String? ?? '';
            final placeName = p['name'] as String? ?? '';
            allPlaceIds.add(placeId);

            places.add(PlaceReference(
              id: placeId,
              name: placeName,
              sourceId: (p['sourceRefs'] as List?)?.firstOrNull?.toString() ?? '',
              destinationId: destId,
              slug: p['slug'] as String?,
              description: p['description'] as String?,
              imageUrl: p['imageUrl'] as String?,
              imageRights: p['imageRights'] as Map<String, dynamic>?,
              latitude: (p['latitude'] as num?)?.toDouble(),
              longitude: (p['longitude'] as num?)?.toDouble(),
              sourceRefs: (p['sourceRefs'] as List?)?.map((e) => e.toString()).toList() ?? const [],
            ));
          }
        }

        destinations.add(DestinationReference(
          id: destId,
          name: destName,
          region: destRegion,
          places: places,
          sample: SampleReference.unavailable(id: destId),
          description: destDesc,
          imageUrl: destImageUrl,
          imageRights: destImageRights,
          sourceRefs: sourceRefs,
        ));
      }
    }

    final catalogue = CatalogueReference(
      checkedAt: preparedAt,
      sources: sources,
      destinations: destinations,
    );

    // 4. Parse visitDetails section via P4a bridge
    final visitDetailsMap = decoded['visitDetails'] as Map<String, dynamic>? ?? const {};
    final visits = VisitCatalogue.fromPublicProjection(
      version: version,
      publishedAt: manifest.publishedAt,
      releaseSha256: manifest.sha256,
      data: visitDetailsMap,
      expectedPlaceIds: allPlaceIds,
      now: now,
    );

    return PublicCatalogueSnapshot(
      version: version,
      sha256: computedSha,
      origin: origin,
      manifest: manifest,
      catalogue: catalogue,
      visits: visits,
      fetchedAt: now,
    );
  }
}
