import '../../trips/models/trip_evidence_codec.dart';
import '../../trips/models/trip_evidence_envelope.dart';
import '../models/editable_trip_command.dart';
import '../models/editable_trip_document.dart';
import '../services/ai_generation_service.dart';
import '../services/editable_trip_validator.dart';

/// Combines an AI proposal with its verified catalogue evidence envelope.
class AiGroundedProposal {
  final AiItineraryProposal proposal;
  final List<EvidenceRecord> evidence;
  final List<EvidenceClaim> claims;
  final String baseDigest;
  final String catalogueVersion;
  final String catalogueDigest;
  final List<EditableCommand> commands;
  final bool canApply;
  final List<EditableValidationIssue> issues;
  final TripEvidenceEnvelope envelope;

  const AiGroundedProposal({
    required this.proposal,
    required this.evidence,
    required this.claims,
    required this.baseDigest,
    required this.catalogueVersion,
    required this.catalogueDigest,
    required this.commands,
    required this.canApply,
    required this.issues,
    required this.envelope,
  });

  factory AiGroundedProposal.fromReceipt({
    required EditableTripDocumentV2 before,
    required Map<String, Object?> receipt,
    required AiGenerationContext context,
    required String Function() newId,
  }) {
    final contract = receipt['contract'] as String?;
    if (contract != 'travelgo.itinerary.evidence.v1') {
      throw const FormatException('invalid_evidence_contract');
    }
    final rawProposal = receipt['proposal'];
    if (rawProposal is! Map) {
      throw const FormatException('missing_proposal_in_receipt');
    }
    final proposal = AiItineraryProposal.fromJson(
      Map<String, Object?>.from(rawProposal),
      context,
    );
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

    // Prepare commands and validate application on empty document
    final prepared = prepareAiProposal(before, proposal, newId);
    
    final envelope = TripEvidenceEnvelope(
      document: prepared.document,
      evidence: evidence,
      claims: claims,
      externalPlaces: const [],
      externalBindings: const [],
    );
    TripEvidenceCodec.encode(envelope);

    return AiGroundedProposal(
      proposal: proposal,
      evidence: List.unmodifiable(evidence),
      claims: List.unmodifiable(claims),
      baseDigest: bDigest,
      catalogueVersion: catVersion,
      catalogueDigest: catDigest,
      commands: prepared.commands,
      canApply: prepared.canApply,
      issues: prepared.issues,
      envelope: envelope,
    );
  }

  factory AiGroundedProposal.fromWebReceipt({
    required EditableTripDocumentV2 before,
    required Map<String, Object?> receipt,
    required String Function() newId,
  }) {
    final contract = receipt['contract'] as String?;
    if (contract != 'travelgo.web.proposal.v1') {
      throw const FormatException('invalid_web_proposal_contract');
    }
    final rawProposal = receipt['proposal'];
    if (rawProposal is! Map) {
      throw const FormatException('missing_proposal_in_receipt');
    }
    final rawProposalMap = Map<String, Object?>.from(rawProposal);
    final rawActivities = rawProposalMap['activities'] as List? ?? const [];
    final activities = <AiProposedActivity>[];
    for (final rawA in rawActivities) {
      if (rawA is Map) {
        final aMap = Map<String, Object?>.from(rawA);
        activities.add(
          AiProposedActivity(
            aMap['day'] as int? ?? 1,
            aMap['title'] as String? ?? 'Hoạt động',
            aMap['startMinute'] as int?,
            aMap['endMinute'] as int?,
            aMap['costVnd'] as int?,
            aMap['category'] as String? ?? 'attractions',
            externalPlaceName: aMap['externalPlaceName'] as String?,
          ),
        );
      }
    }
    final proposal = AiItineraryProposal(
      summary: rawProposalMap['summary'] as String? ?? 'Đề xuất từ Internet',
      activities: activities,
      warnings: (rawProposalMap['warnings'] as List? ?? const [])
          .map((w) => w.toString())
          .toList(),
    );
    final bDigest = receipt['baseDigest'] as String? ?? '';

    final rawEvidence = receipt['evidence'] as List? ?? const [];
    final evidence = rawEvidence
        .map((e) => EvidenceRecord.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();

    final rawClaims = receipt['claims'] as List? ?? const [];
    final claims = rawClaims
        .map((c) => EvidenceClaim.fromJson(Map<String, Object?>.from(c as Map)))
        .toList();

    final rawExternalPlaces = receipt['externalPlaces'] as List? ?? const [];
    final externalPlaces = rawExternalPlaces
        .map((p) => ExternalPlaceRecord.fromJson(Map<String, Object?>.from(p as Map)))
        .toList();

    final prepared = prepareExternalAiProposal(
      before: before,
      proposal: proposal,
      externalPlaces: externalPlaces,
      evidence: evidence,
      newId: newId,
    );

    final envelope = TripEvidenceEnvelope(
      document: prepared.document,
      evidence: evidence,
      claims: claims,
      externalPlaces: prepared.externalPlaces,
      externalBindings: prepared.externalBindings,
    );
    TripEvidenceCodec.encode(envelope);

    return AiGroundedProposal(
      proposal: proposal,
      evidence: List.unmodifiable(evidence),
      claims: List.unmodifiable(claims),
      baseDigest: bDigest,
      catalogueVersion: '',
      catalogueDigest: '',
      commands: prepared.commands,
      canApply: prepared.canApply,
      issues: prepared.issues,
      envelope: envelope,
    );
  }
}

