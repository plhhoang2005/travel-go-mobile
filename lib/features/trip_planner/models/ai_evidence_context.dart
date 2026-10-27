import 'dart:convert';

import '../../explore/models/public_catalogue_snapshot.dart';
import '../../trips/models/editable_trip_codec.dart';
import '../../trips/models/trip_evidence_codec.dart';
import '../../trips/models/trip_evidence_envelope.dart';
import '../services/budget_calculator.dart';
import 'editable_trip_document.dart';

void _require(bool valid) {
  if (!valid) throw const FormatException('invalid_ai_evidence_context');
}

String _human(String value, int limit) {
  _require(
    value.isNotEmpty &&
        value == value.trim() &&
        value.runes.length <= limit &&
        !RegExp(
          r'[\x00-\x1f\x7f]|@|https?:|www\.|(?:\+\d|0)(?:[ .()-]*\d){8,14}',
          caseSensitive: false,
        ).hasMatch(value),
  );
  return value;
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _freeze(item))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

/// Minimum user context; catalogue facts and source authority are resolved by the server.
class AiEvidenceContext {
  final Map<String, Object?> _body;
  final BudgetTotals budget;
  AiEvidenceContext._(Map<String, Object?> body, this.budget)
    : _body = _freeze(body) as Map<String, Object?>;

  String get destinationId => _body['destinationId'] as String;
  String get catalogueVersion => _body['catalogueVersion'] as String;
  String get catalogueDigest => _body['catalogueDigest'] as String;
  String get baseDigest => _body['baseDigest'] as String;
  String get scope => _body['scope'] as String;
  int get numPeople => _body['numPeople'] as int;
  int get budgetVnd => _body['budgetVnd'] as int;

  factory AiEvidenceContext.fromDocument(
    EditableTripDocumentV2 document, {
    required PublicCatalogueSnapshot snapshot,
    String scope = 'trip',
    int? selectedDay,
    TripEvidenceEnvelope? evidenceEnvelope,
  }) {
    EditableTripCodec.validateDocument(document);
    _require(scope == 'trip' || scope == 'day');
    _require(
      scope == 'day'
          ? selectedDay != null &&
                selectedDay >= 1 &&
                selectedDay <= document.days.length
          : selectedDay == null,
    );
    final destinationId = document.input.destinationId;
    _require(
      destinationId != null &&
          snapshot.origin != 'seed' &&
          snapshot.version > 0 &&
          snapshot.version == snapshot.manifest.version &&
          snapshot.sha256 == snapshot.manifest.sha256 &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(snapshot.sha256) &&
          snapshot.catalogue.destinations.any((d) => d.id == destinationId),
    );
    final days = scope == 'day'
        ? [document.days[selectedDay! - 1]]
        : document.days;
    final dayIds = days.map((d) => d.id).toSet();
    final activities = document.items
        .where((a) => dayIds.contains(a.dayId))
        .map(
          (a) => {
            'id': a.id,
            'day': document.days.indexWhere((d) => d.id == a.dayId) + 1,
            'title': _human(a.title, 200),
            'placeId': a.placeId,
            'startMinute': a.startMinute,
            'endMinute': a.endMinute,
          },
        )
        .toList();
    _require(activities.length <= 48 && document.input.interests.length <= 20);
    final interests = document.input.interests
        .map((s) => _human(s, 80))
        .toList();
    final totals = BudgetCalculator.calculate(document);
    var baseDigest = EditableTripCodec.digest(document);
    if (evidenceEnvelope != null) {
      _require(
        EditableTripCodec.digest(evidenceEnvelope.document) == baseDigest,
      );
      baseDigest = TripEvidenceCodec.digest(evidenceEnvelope);
    }
    return AiEvidenceContext._({
      'destinationId': destinationId,
      'catalogueVersion': snapshot.version.toString(),
      'catalogueDigest': snapshot.sha256,
      'dates': days.where((d) => d.date != null).map((d) => d.date!).toList(),
      'dayDates': days
          .map((d) => {'day': document.days.indexOf(d) + 1, 'date': d.date})
          .toList(),
      'numDays': document.days.length,
      'numPeople': document.input.travelerCount,
      'budgetVnd': document.input.totalBudgetVnd,
      'interests': interests,
      'budget': {
        'knownEstimate': totals.knownEstimate,
        'unknownEstimateCount': totals.unknownEstimateCount,
        'actualTotal': totals.actualTotal,
        'estimateRemaining': totals.estimateRemaining,
        'actualRemaining': totals.actualRemaining,
      },
      'baseDigest': baseDigest,
      'scope': scope,
      'selectedDay': selectedDay,
      'priority': document.input.priority,
      'activities': activities,
    }, totals);
  }

  Map<String, Object?> toJson() => _body;

  /// Opt-in wire only. Existing UI continues using v1 until A4/A5 integration.
  Map<String, Object?> request({
    required String intent,
    required String requestId,
    String? prompt,
    List<Map<String, Object?>> history = const [],
  }) {
    _require(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(requestId),
    );
    final assistant = intent != 'generate';
    _require(
      !assistant ||
          const {'advice', 'recommendations', 'modify'}.contains(intent),
    );
    _require(intent != 'modify' || scope == 'day');
    final body = <String, Object?>{
      'contract': assistant
          ? 'travelgo.assistant.evidence.v1'
          : 'travelgo.itinerary.evidence.v1',
      'intent': intent,
      'requestId': requestId,
      'consent': true,
      'context': _body,
    };
    if (assistant) {
      _require(prompt != null && history.length <= 4 && history.length.isEven);
      _human(prompt!.replaceAll(RegExp(r'[\r\n\t]'), ' '), 600);
      for (var i = 0; i < history.length; i++) {
        final row = history[i];
        _require(
          row.length == 2 &&
              row['role'] == (i.isEven ? 'user' : 'model') &&
              row['text'] is String,
        );
        _human(
          (row['text'] as String).replaceAll(RegExp(r'[\r\n\t]'), ' '),
          1200,
        );
      }
      body.addAll({'prompt': prompt, 'history': history});
    } else {
      _require(prompt == null && history.isEmpty);
    }
    _require(utf8.encode(jsonEncode(body)).length <= 32768);
    return _freeze(body) as Map<String, Object?>;
  }
}
