// Public catalogue snapshot and release manifest models for Discovery V2.

import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';

@immutable
class DiscoveryManifest {
  final String contract;
  final int schemaVersion;
  final int version;
  final String objectKey;
  final String sha256;
  final int byteLength;
  final DateTime publishedAt;

  const DiscoveryManifest({
    required this.contract,
    required this.schemaVersion,
    required this.version,
    required this.objectKey,
    required this.sha256,
    required this.byteLength,
    required this.publishedAt,
  });

  factory DiscoveryManifest.fromJson(Map<String, dynamic> json) {
    final contract = json['contract'] as String? ?? '';
    if (contract != 'travelgo.discovery.manifest.v2') {
      throw FormatException('Invalid manifest contract: $contract');
    }

    final schemaVersion = json['schemaVersion'] ?? json['schema_version'];
    if (schemaVersion != 2) {
      throw FormatException('Unsupported manifest schema version: $schemaVersion');
    }

    final version = json['version'] as int?;
    if (version == null || version < 1) {
      throw const FormatException('Manifest version must be an integer >= 1');
    }

    final objectKey = (json['objectKey'] ?? json['object_key']) as String? ?? '';
    if (!RegExp(r'^releases/v2/[1-9][0-9]*\.json$').hasMatch(objectKey)) {
      throw FormatException('Invalid manifest object key pattern: $objectKey');
    }

    final sha256 = json['sha256'] as String? ?? '';
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw FormatException('Invalid manifest sha256: $sha256');
    }

    final byteLength = (json['byteLength'] ?? json['byte_length']) as int?;
    if (byteLength == null || byteLength < 1 || byteLength > 2097152) {
      throw FormatException('Invalid manifest byte length: $byteLength');
    }

    final pubAtRaw = (json['publishedAt'] ?? json['published_at']) as String?;
    final publishedAt = DateTime.tryParse(pubAtRaw ?? '') ?? DateTime.now();

    return DiscoveryManifest(
      contract: contract,
      schemaVersion: schemaVersion as int,
      version: version,
      objectKey: objectKey,
      sha256: sha256,
      byteLength: byteLength,
      publishedAt: publishedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'contract': contract,
        'schemaVersion': schemaVersion,
        'version': version,
        'objectKey': objectKey,
        'sha256': sha256,
        'byteLength': byteLength,
        'publishedAt': publishedAt.toUtc().toIso8601String(),
      };
}

@immutable
class PublicCatalogueSnapshot {
  final int version;
  final String sha256;
  final String origin;
  final DiscoveryManifest manifest;
  final CatalogueReference catalogue;
  final VisitCatalogue visits;
  final DateTime fetchedAt;

  const PublicCatalogueSnapshot({
    required this.version,
    required this.sha256,
    required this.origin,
    required this.manifest,
    required this.catalogue,
    required this.visits,
    required this.fetchedAt,
  });
}
