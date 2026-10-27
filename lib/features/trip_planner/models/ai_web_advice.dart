import '../../trips/models/editable_trip_codec.dart';
import '../../trips/models/trip_evidence_envelope.dart';
import 'editable_trip_command.dart';
import 'editable_trip_document.dart';

/// Context sent for web advice requests.
/// Strict Privacy: Never contains user private notes, emails, phone numbers, or actual expenses.
class AiWebAdviceContext {
  final String destinationName;
  final List<String> dates;
  final int numPeople;
  final int budgetVnd;
  final List<String> interests;
  final String scope;
  final String baseDigest;

  const AiWebAdviceContext({
    required this.destinationName,
    required this.dates,
    required this.numPeople,
    required this.budgetVnd,
    required this.interests,
    required this.scope,
    required this.baseDigest,
  });

  factory AiWebAdviceContext.fromDocument(
    EditableTripDocumentV2 doc, {
    int? selectedDay,
  }) {
    final start = doc.input.startDate != null ? DateTime.tryParse(doc.input.startDate!) : null;
    final end = doc.input.endDate != null ? DateTime.tryParse(doc.input.endDate!) : null;
    final dates = <String>[];
    if (start != null && end != null && !end.isBefore(start)) {
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        dates.add(d.toIso8601String().substring(0, 10));
      }
    } else if (doc.input.startDate != null) {
      dates.add(doc.input.startDate!);
    }
    if (dates.isEmpty) {
      dates.add(DateTime.now().toIso8601String().substring(0, 10));
    }

    final dest = doc.input.destinationName?.trim().isNotEmpty == true
        ? doc.input.destinationName!.trim()
        : (doc.input.destinationId ?? 'Việt Nam');

    final digest = EditableTripCodec.digest(doc);

    return AiWebAdviceContext(
      destinationName: dest,
      dates: selectedDay != null && selectedDay > 0 && selectedDay <= dates.length
          ? [dates[selectedDay - 1]]
          : dates,
      numPeople: doc.input.travelerCount > 0 ? doc.input.travelerCount : 2,
      budgetVnd: doc.input.totalBudgetVnd,
      interests: doc.input.interests.isNotEmpty ? doc.input.interests : const ['văn hóa', 'ẩm thực'],
      scope: selectedDay != null ? 'day' : 'whole_trip',
      baseDigest: digest,
    );
  }

  Map<String, Object?> toJson() => {
    'destinationName': destinationName,
    'dates': dates,
    'numPeople': numPeople,
    'budgetVnd': budgetVnd,
    'interests': interests,
    'scope': scope,
    'baseDigest': baseDigest,
  };
}

/// Sourced response received from the Google Search Grounding advisor.
class AiWebAdviceReply {
  final String requestId;
  final String summary;
  final List<EvidenceRecord> evidence;
  final List<EvidenceClaim> claims;
  final List<String> searchQueries;
  final String? searchEntryPoint;
  final List<String> warnings;
  final String baseDigest;

  const AiWebAdviceReply({
    required this.requestId,
    required this.summary,
    required this.evidence,
    required this.claims,
    required this.searchQueries,
    this.searchEntryPoint,
    required this.warnings,
    required this.baseDigest,
  });

  /// Advice never mutates the user's trip document directly (Law 1).
  List<EditableCommand> get commands => const [];
  bool get hasEvidence => evidence.isNotEmpty;

  factory AiWebAdviceReply.fromJson(Map<String, Object?> json) {
    final contract = json['contract'] as String?;
    if (contract != 'travelgo.web.advice.v1') {
      throw const FormatException('invalid_web_advice_contract');
    }

    final rawEvidence = json['evidence'];
    final evidenceList = <EvidenceRecord>[];
    if (rawEvidence is List) {
      for (final item in rawEvidence) {
        if (item is Map) {
          final uriStr = item['sourceUri'] as String? ?? item['url'] as String? ?? '';
          evidenceList.add(EvidenceRecord(
            id: item['id'] as String? ?? 'web:source',
            origin: EvidenceOrigin.web,
            url: Uri.tryParse(uriStr),
            title: item['sourceTitle'] as String? ?? item['title'] as String?,
            publisher: item['publisher'] as String? ?? 'web',
            factKey: 'advice',
            factValue: item['sourceTitle'] as String? ?? uriStr,
            retrievedAt: item['retrievedAt'] as String?,
            reviewed: item['reviewed'] == true,
            evidenceRequestId: json['requestId'] as String?,
          ));
        }
      }
    }

    final rawClaims = json['claims'];
    final claimsList = <EvidenceClaim>[];
    if (rawClaims is List) {
      for (final item in rawClaims) {
        if (item is Map) {
          final rawSources = item['sourceIds'] ?? item['evidenceIds'];
          final sourceIds = <String>[];
          if (rawSources is List) {
            for (final s in rawSources) {
              if (s is String) sourceIds.add(s);
            }
          }
          final kindStr = item['kind'] as String? ?? 'fact';
          final claimKind = ClaimKind.values.where((k) => k.name == kindStr).firstOrNull ?? ClaimKind.fact;
          claimsList.add(EvidenceClaim(
            id: item['id'] as String? ?? 'claim:web',
            text: item['context'] as String? ?? item['text'] as String? ?? '',
            kind: claimKind,
            evidenceIds: sourceIds,
          ));
        }
      }
    }

    final rawQueries = json['searchQueries'];
    final queries = <String>[];
    if (rawQueries is List) {
      for (final q in rawQueries) {
        if (q is String) queries.add(q);
      }
    }

    final rawWarnings = json['warnings'];
    final warnings = <String>[];
    if (rawWarnings is List) {
      for (final w in rawWarnings) {
        if (w is String) warnings.add(w);
      }
    }
    if (warnings.isEmpty) {
      warnings.add('Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện.');
    }

    return AiWebAdviceReply(
      requestId: json['requestId'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      evidence: evidenceList,
      claims: claimsList,
      searchQueries: queries,
      searchEntryPoint: json['searchEntryPoint'] as String?,
      warnings: warnings,
      baseDigest: json['baseDigest'] as String? ?? '',
    );
  }
}
