import '../../trips/models/trip_evidence_codec.dart';
import '../../trips/models/trip_evidence_envelope.dart';
import '../models/editable_trip_command.dart';
import '../models/editable_trip_document.dart';
import '../services/ai_assistant_service.dart';
import '../../explore/models/catalogue_reference.dart' as catalogue;

/// Combines an AI assistant reply with its verified catalogue evidence envelope.
class AiGroundedAssistantReply {
  final AiAssistantResult result;
  final AiModificationPreview? modification;
  final List<EvidenceRecord> evidence;
  final List<EvidenceClaim> claims;
  final String baseDigest;
  final String catalogueVersion;
  final String catalogueDigest;
  final TripEvidenceEnvelope? envelope;

  const AiGroundedAssistantReply({
    required this.result,
    this.modification,
    required this.evidence,
    required this.claims,
    required this.baseDigest,
    required this.catalogueVersion,
    required this.catalogueDigest,
    this.envelope,
  });

  List<EditableCommand> get commands => modification?.commands ?? const [];
  bool get canApply => modification == null || modification!.canApply;

  factory AiGroundedAssistantReply.fromReceipt({
    required EditableTripDocumentV2 before,
    required Map<String, Object?> receipt,
    required String intent,
    required int selectedDay,
    required String Function() newId,
    TripEvidenceEnvelope? beforeEnvelope,
    AiAssistantContext? assistantContext,
  }) {
    final contract = receipt['contract'] as String?;
    if (contract != 'travelgo.assistant.evidence.v1') {
      throw const FormatException('invalid_evidence_contract');
    }
    final rawProposal = receipt['proposal'];
    if (rawProposal is! Map) {
      throw const FormatException('missing_proposal_in_receipt');
    }
    final proposalMap = Map<String, Object?>.from(rawProposal);
    AiAssistantContext context = assistantContext ??
        AiAssistantContext.fromDocument(before, selectedDay: selectedDay);

    final knownPlaceIds = context.places.map((p) => p['id']).toSet();
    final neededPlaceIds = <String>{};
    for (final op in (proposalMap['operations'] as List? ?? const [])) {
      if (op is Map && op['placeId'] is String) {
        neededPlaceIds.add(op['placeId'] as String);
      }
    }
    for (final rec in (proposalMap['recommendations'] as List? ?? const [])) {
      if (rec is Map && rec['placeId'] is String) {
        neededPlaceIds.add(rec['placeId'] as String);
      }
    }
    final missingPlaceIds = neededPlaceIds.difference(knownPlaceIds);
    if (missingPlaceIds.isNotEmpty) {
      final extraPlaces = <catalogue.PlaceReference>[];
      for (final pid in missingPlaceIds) {
        final nameRecord = (receipt['evidence'] as List? ?? const [])
            .whereType<Map>()
            .firstWhere(
              (e) => e['factKey'] == '',
              orElse: () => const <String, Object?>{},
            );
        final name = (nameRecord['factValue'] as String?) ??
            before.items.where((i) => i.placeId == pid).firstOrNull?.title ??
            pid.split('/').last;
        extraPlaces.add(
          catalogue.PlaceReference(
            id: pid,
            name: name,
            sourceId: (nameRecord['id'] as String?) ?? 'rec-1',
          ),
        );
      }
      final allPlaces = [
        ...context.places.map(
          (p) => catalogue.PlaceReference(
            id: p['id'] as String,
            name: p['name'] as String,
            sourceId: p['sourceId'] as String,
          ),
        ),
        ...extraPlaces,
      ].take(12).toList();
      context = AiAssistantContext.fromDocument(
        before,
        selectedDay: selectedDay,
        places: allPlaces,
      );
    }

    final result = AiAssistantResult.fromJson(proposalMap, context, intent);
    final catVersion = receipt['catalogueVersion'] as String;
    final catDigest = receipt['catalogueDigest'] as String;
    final bDigest = receipt['baseDigest'] as String;

    final rawEvidence = receipt['evidence'] as List? ?? const [];
    final evidence = rawEvidence
        .map((e) => EvidenceRecord.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();

    final rawClaims = receipt['claims'] as List? ?? const [];
    final claims = rawClaims
        .map((c) => EvidenceClaim.fromJson(Map<String, Object?>.from(c as Map)))
        .toList();

    // Deduplicate and merge evidence records
    final evidenceMap = <String, EvidenceRecord>{};
    for (final e in (beforeEnvelope?.evidence ?? const <EvidenceRecord>[])) {
      evidenceMap[e.id] = e;
    }
    for (final e in evidence) {
      evidenceMap[e.id] = e;
    }

    final claimMap = <String, EvidenceClaim>{};
    for (final c in (beforeEnvelope?.claims ?? const <EvidenceClaim>[])) {
      claimMap[c.id] = c;
    }
    for (final c in claims) {
      claimMap[c.id] = c;
    }

    AiModificationPreview? modification;
    TripEvidenceEnvelope? envelope;

    if (intent == 'modify') {
      if (result.operations.isEmpty) {
        throw const FormatException('modify_requires_operations');
      }
      modification = prepareAiModification(before, result, context, newId);
      envelope = TripEvidenceEnvelope(
        document: modification.after,
        evidence: evidenceMap.values.toList(),
        claims: claimMap.values.toList(),
        externalPlaces: beforeEnvelope?.externalPlaces ?? const [],
        externalBindings: beforeEnvelope?.externalBindings ?? const [],
      );
      TripEvidenceCodec.encode(envelope);
    } else {
      if (result.operations.isNotEmpty) {
        throw const FormatException('advice_must_have_empty_operations');
      }
      envelope = TripEvidenceEnvelope(
        document: before,
        evidence: evidenceMap.values.toList(),
        claims: claimMap.values.toList(),
        externalPlaces: beforeEnvelope?.externalPlaces ?? const [],
        externalBindings: beforeEnvelope?.externalBindings ?? const [],
      );
      TripEvidenceCodec.encode(envelope);
    }

    return AiGroundedAssistantReply(
      result: result,
      modification: modification,
      evidence: List.unmodifiable(evidence),
      claims: List.unmodifiable(claims),
      baseDigest: bDigest,
      catalogueVersion: catVersion,
      catalogueDigest: catDigest,
      envelope: envelope,
    );
  }
}
