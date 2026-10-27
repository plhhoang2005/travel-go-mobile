import '../../trip_planner/models/editable_trip_document.dart';

enum EvidenceOrigin { catalogue, web, user }

enum ClaimKind { fact, inference, unknown }

class EvidenceRecord {
  final String id;
  final EvidenceOrigin origin;
  final Uri? url;
  final String? _wireUrl;
  final String? title;
  final String? publisher;
  final String factKey;
  final String factValue;
  final String? retrievedAt;
  final String? checkedAt;
  final String? publishedAt;
  final String? effectiveFrom;
  final String? effectiveTo;
  final bool reviewed;
  final String? evidenceRequestId;

  const EvidenceRecord({
    required this.id,
    required this.origin,
    this.url,
    this.title,
    this.publisher,
    required this.factKey,
    required this.factValue,
    this.retrievedAt,
    this.checkedAt,
    this.publishedAt,
    this.effectiveFrom,
    this.effectiveTo,
    required this.reviewed,
    this.evidenceRequestId,
  }) : _wireUrl = null;

  factory EvidenceRecord.fromJson(Map<String, Object?> json) =>
      EvidenceRecord._fromJson(json);

  // Uri normalizes host/escapes; retain the received spelling for wire digests.
  EvidenceRecord._fromJson(Map<String, Object?> json)
    : id = json['id'] as String,
      origin = EvidenceOrigin.values.byName(json['origin'] as String),
      url = json['url'] == null ? null : Uri.parse(json['url'] as String),
      _wireUrl = json['url'] as String?,
      title = json['title'] as String?,
      publisher = json['publisher'] as String?,
      factKey = json['factKey'] as String,
      factValue = json['factValue'] as String,
      retrievedAt = json['retrievedAt'] as String?,
      checkedAt = json['checkedAt'] as String?,
      publishedAt = json['publishedAt'] as String?,
      effectiveFrom = json['effectiveFrom'] as String?,
      effectiveTo = json['effectiveTo'] as String?,
      reviewed = json['reviewed'] as bool,
      evidenceRequestId = json['evidenceRequestId'] as String?;

  Map<String, Object?> toJson() => {
    'id': id,
    'origin': origin.name,
    'url': _wireUrl ?? url?.toString(),
    'title': title,
    'publisher': publisher,
    'factKey': factKey,
    'factValue': factValue,
    'retrievedAt': retrievedAt,
    'checkedAt': checkedAt,
    'publishedAt': publishedAt,
    'effectiveFrom': effectiveFrom,
    'effectiveTo': effectiveTo,
    'reviewed': reviewed,
    'evidenceRequestId': evidenceRequestId,
  };
}

class EvidenceClaim {
  final String id;
  final String text;
  final ClaimKind kind;
  final List<String> evidenceIds;

  EvidenceClaim({
    required this.id,
    required this.text,
    required this.kind,
    required List<String> evidenceIds,
  }) : evidenceIds = List.unmodifiable(evidenceIds);

  factory EvidenceClaim.fromJson(Map<String, Object?> json) => EvidenceClaim(
    id: json['id'] as String,
    text: json['text'] as String,
    kind: ClaimKind.values.byName(json['kind'] as String),
    evidenceIds: List<String>.from(json['evidenceIds'] as List),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'kind': kind.name,
    'evidenceIds': evidenceIds,
  };
}

class ExternalPlaceRecord {
  final String id;
  final String name;
  final String destinationName;
  final List<String> evidenceIds;

  ExternalPlaceRecord({
    required this.id,
    required this.name,
    required this.destinationName,
    required List<String> evidenceIds,
  }) : evidenceIds = List.unmodifiable(evidenceIds);

  factory ExternalPlaceRecord.fromJson(Map<String, Object?> json) =>
      ExternalPlaceRecord(
        id: json['id'] as String,
        name: json['name'] as String,
        destinationName: json['destinationName'] as String,
        evidenceIds: List<String>.from(json['evidenceIds'] as List),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'destinationName': destinationName,
    'evidenceIds': evidenceIds,
  };
}

class ExternalItemBinding {
  final String itemId;
  final String externalPlaceId;

  const ExternalItemBinding({
    required this.itemId,
    required this.externalPlaceId,
  });

  factory ExternalItemBinding.fromJson(Map<String, Object?> json) =>
      ExternalItemBinding(
        itemId: json['itemId'] as String,
        externalPlaceId: json['externalPlaceId'] as String,
      );

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'externalPlaceId': externalPlaceId,
  };
}

class TripEvidenceEnvelope {
  static const contractName = 'travelgo.trip.evidence.v1';
  final EditableTripDocumentV2 document;
  final List<EvidenceRecord> evidence;
  final List<EvidenceClaim> claims;
  final List<ExternalPlaceRecord> externalPlaces;
  final List<ExternalItemBinding> externalBindings;
  String get contract => contractName;

  TripEvidenceEnvelope({
    required this.document,
    List<EvidenceRecord> evidence = const [],
    List<EvidenceClaim> claims = const [],
    List<ExternalPlaceRecord> externalPlaces = const [],
    List<ExternalItemBinding> externalBindings = const [],
  }) : evidence = List.unmodifiable(evidence),
       claims = List.unmodifiable(claims),
       externalPlaces = List.unmodifiable(externalPlaces),
       externalBindings = List.unmodifiable(externalBindings);

  factory TripEvidenceEnvelope.fromJson(Map<String, Object?> json) =>
      TripEvidenceEnvelope(
        document: EditableTripDocumentV2.fromJson(
          editableObject(json['document']),
        ),
        evidence: (json['evidence'] as List)
            .map((v) => EvidenceRecord.fromJson(editableObject(v)))
            .toList(),
        claims: (json['claims'] as List)
            .map((v) => EvidenceClaim.fromJson(editableObject(v)))
            .toList(),
        externalPlaces: (json['externalPlaces'] as List)
            .map((v) => ExternalPlaceRecord.fromJson(editableObject(v)))
            .toList(),
        externalBindings: (json['externalBindings'] as List)
            .map((v) => ExternalItemBinding.fromJson(editableObject(v)))
            .toList(),
      );

  Map<String, Object?> toJson() => {
    'contract': contract,
    'document': document.toJson(),
    'evidence': evidence.map((v) => v.toJson()).toList(),
    'claims': claims.map((v) => v.toJson()).toList(),
    'externalPlaces': externalPlaces.map((v) => v.toJson()).toList(),
    'externalBindings': externalBindings.map((v) => v.toJson()).toList(),
  };
}
