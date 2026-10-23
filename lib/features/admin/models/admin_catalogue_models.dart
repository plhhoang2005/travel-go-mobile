// Catalogue models and immutable DTOs for TravelGO administration.
// Implements A5 server-authored discovery commands and snapshot projections.

import 'package:flutter/foundation.dart';

@immutable
class AdminReferenceSource {
  final String? id;
  final String title;
  final String publisher;
  final String url;
  final String checkedAt;

  const AdminReferenceSource({
    this.id,
    required this.title,
    required this.publisher,
    required this.url,
    required this.checkedAt,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'publisher': publisher,
        'url': url,
        'checkedAt': checkedAt,
      };

  factory AdminReferenceSource.fromJson(Map<String, dynamic> json) {
    return AdminReferenceSource(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      url: json['url'] as String? ?? '',
      checkedAt: json['checkedAt'] as String? ?? '',
    );
  }
}

@immutable
class AdminImageRights {
  final String sourceUrl;
  final String permission;
  final String credit;
  final String? licenseUrl;

  const AdminImageRights({
    required this.sourceUrl,
    required this.permission,
    required this.credit,
    this.licenseUrl,
  });

  Map<String, dynamic> toJson() => {
        'sourceUrl': sourceUrl,
        'permission': permission,
        'credit': credit,
        if (licenseUrl != null) 'licenseUrl': licenseUrl,
      };

  factory AdminImageRights.fromJson(Map<String, dynamic> json) {
    return AdminImageRights(
      sourceUrl: json['sourceUrl'] as String? ?? '',
      permission: json['permission'] as String? ?? '',
      credit: json['credit'] as String? ?? '',
      licenseUrl: json['licenseUrl'] as String?,
    );
  }
}

@immutable
class AdminDestinationDraft {
  final String? id;
  final String name;
  final String slug;
  final String region;
  final String description;
  final String? imageUrl;
  final List<String> sourceRefs;
  final List<AdminReferenceSource> sourceEdits;
  final AdminImageRights? imageRights;
  final bool active;

  const AdminDestinationDraft({
    this.id,
    required this.name,
    required this.slug,
    required this.region,
    required this.description,
    this.imageUrl,
    this.sourceRefs = const [],
    this.sourceEdits = const [],
    this.imageRights,
    this.active = true,
  });

  Map<String, dynamic> toCreateCommand() => {
        'command': 'createDestination',
        'name': name.trim(),
        'slug': slug.trim(),
        'region': region.trim(),
        'description': description.trim(),
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl!.trim(),
        if (sourceEdits.isNotEmpty)
          'sourceEdits': sourceEdits.map((s) => s.toJson()).toList(),
      };

  Map<String, dynamic> toUpdateCommand() => {
        'command': 'updateDestination',
        'destinationId': id,
        'name': name.trim(),
        'region': region.trim(),
        'description': description.trim(),
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl!.trim(),
        if (sourceEdits.isNotEmpty)
          'sourceEdits': sourceEdits.map((s) => s.toJson()).toList(),
      };

  factory AdminDestinationDraft.fromJson(Map<String, dynamic> json) {
    final sourceRefsRaw = json['sourceRefs'] as List?;
    final sourceRefs = sourceRefsRaw?.map((e) => e.toString()).toList() ?? const [];

    return AdminDestinationDraft(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      region: json['region'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      sourceRefs: sourceRefs,
      active: json['isActive'] as bool? ?? true,
    );
  }
}

@immutable
class AdminPlaceDraft {
  final String? id;
  final String destinationId;
  final String name;
  final String slug;
  final String description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final List<String> sourceRefs;
  final List<AdminReferenceSource> sourceEdits;
  final AdminImageRights? imageRights;
  final bool active;

  const AdminPlaceDraft({
    this.id,
    required this.destinationId,
    required this.name,
    required this.slug,
    required this.description,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.sourceRefs = const [],
    this.sourceEdits = const [],
    this.imageRights,
    this.active = true,
  });

  Map<String, dynamic> toCreateCommand() => {
        'command': 'createPlace',
        'destinationId': destinationId,
        'name': name.trim(),
        'slug': slug.trim(),
        'description': description.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl!.trim(),
        if (sourceEdits.isNotEmpty)
          'sourceEdits': sourceEdits.map((s) => s.toJson()).toList(),
      };

  Map<String, dynamic> toUpdateCommand() => {
        'command': 'updatePlace',
        'placeId': id,
        'name': name.trim(),
        'description': description.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'imageUrl': imageUrl!.trim(),
        if (sourceEdits.isNotEmpty)
          'sourceEdits': sourceEdits.map((s) => s.toJson()).toList(),
      };

  factory AdminPlaceDraft.fromJson(Map<String, dynamic> json) {
    final sourceRefsRaw = json['sourceRefs'] as List?;
    final sourceRefs = sourceRefsRaw?.map((e) => e.toString()).toList() ?? const [];

    return AdminPlaceDraft(
      id: json['id'] as String?,
      destinationId: json['destinationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      sourceRefs: sourceRefs,
      active: json['isActive'] as bool? ?? true,
    );
  }
}

@immutable
class AdminDraftVersion {
  final int revision;
  final int? baseRevision;
  final String? actorId;
  final String reason;
  final DateTime changedAt;
  final String payloadHash;

  const AdminDraftVersion({
    required this.revision,
    this.baseRevision,
    this.actorId,
    required this.reason,
    required this.changedAt,
    required this.payloadHash,
  });

  factory AdminDraftVersion.fromJson(Map<String, dynamic> json) {
    return AdminDraftVersion(
      revision: json['revision'] as int? ?? 1,
      baseRevision: json['baseRevision'] as int?,
      actorId: json['actorId'] as String?,
      reason: json['reason'] as String? ?? '',
      changedAt: DateTime.tryParse(json['changedAt'] as String? ?? '') ?? DateTime.now(),
      payloadHash: json['payloadHash'] as String? ?? '',
    );
  }
}

@immutable
class AdminCatalogueSnapshot {
  final int revision;
  final Map<String, dynamic> payload;
  final List<AdminDraftVersion> history;
  final List<AdminDestinationDraft> destinations;
  final List<AdminPlaceDraft> places;
  final String? entityId;

  const AdminCatalogueSnapshot({
    required this.revision,
    required this.payload,
    required this.history,
    required this.destinations,
    required this.places,
    this.entityId,
  });

  factory AdminCatalogueSnapshot.fromJson(Map<String, dynamic> json) {
    final rev = json['revision'] as int? ?? 1;
    final payload = (json['payload'] as Map<String, dynamic>?) ?? const {};
    final historyRaw = json['history'] as List? ?? const [];
    final history = historyRaw
        .map((h) => AdminDraftVersion.fromJson(h as Map<String, dynamic>))
        .toList(growable: false);

    final inventory = (payload['inventory'] as Map<String, dynamic>?) ?? const {};
    final destRaw = (inventory['destinations'] as List? ?? const []);
    final destinations = destRaw
        .map((d) => AdminDestinationDraft.fromJson(d as Map<String, dynamic>))
        .toList(growable: false);

    final placesRaw = (inventory['places'] as List? ?? const []);
    final places = placesRaw
        .map((p) => AdminPlaceDraft.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);

    return AdminCatalogueSnapshot(
      revision: rev,
      payload: payload,
      history: history,
      destinations: destinations,
      places: places,
      entityId: json['entityId'] as String?,
    );
  }
}
