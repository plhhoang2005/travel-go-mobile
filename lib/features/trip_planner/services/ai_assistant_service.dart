import 'dart:convert';

import '../../auth/providers/auth_provider.dart';
import '../../explore/models/catalogue_reference.dart' as catalogue;
import '../../explore/models/place_visit_details.dart';
import '../../trips/models/editable_trip_codec.dart';
import '../models/ai_context_grounding.dart';
import '../models/editable_trip_command.dart';
import '../models/editable_trip_document.dart';
import 'ai_generation_service.dart';
import 'budget_calculator.dart';
import 'editable_trip_mutator.dart';
import 'editable_trip_validator.dart';

const aiAssistantContract = 'travelgo.assistant.v1';
void _check(bool value) {
  if (!value) {
    throw const FormatException('invalid_assistant_contract');
  }
}

Map<String, Object?> _object(Object? value, Set<String> keys) {
  _check(value is Map);
  final map = Map<String, Object?>.from(value as Map);
  _check(map.length == keys.length && map.keys.every(keys.contains));
  return map;
}

String _text(Object? value, int max) {
  _check(
    value is String &&
        value.isNotEmpty &&
        value == value.trim() &&
        value.runes.length <= max &&
        !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value),
  );
  return value as String;
}

String _human(Object? value, int max, {bool multiline = false}) {
  final text = _text(
    multiline && value is String
        ? value.replaceAll(RegExp(r'[\r\n\t]'), ' ')
        : value,
    max,
  );
  _check(
    !RegExp(
      r'@|https?:|www\.|(?:\+\d|0)(?:[ .()-]*\d){8,14}',
      caseSensitive: false,
    ).hasMatch(text),
  );
  return value as String;
}

int _integer(Object? value, int min, int max) {
  _check(value is int && value >= min && value <= max);
  return value as int;
}

int? _time(Object? value, int max) =>
    value == null ? null : _integer(value, 0, max);
Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((k, v) => MapEntry(k as String, _freeze(v))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  return value;
}

class AiAssistantContext {
  final Map<String, Object?> _body;
  final String baseDigest;
  final GroundingResolution? grounding;
  final String? destinationName;
  final Set<String> closedPlaceIds;

  AiAssistantContext._(
    Map<String, Object?> body,
    this.baseDigest, {
    this.grounding,
    this.destinationName,
    Set<String>? closedPlaceIds,
  })  : closedPlaceIds = Set.unmodifiable(
          closedPlaceIds ??
              (grounding?.facts.entries
                      .where(
                        (e) => e.value.availability == AvailabilityState.closed,
                      )
                      .map((e) => e.key)
                      .toSet() ??
                  const <String>{}),
        ),
        _body = _freeze(body) as Map<String, Object?>;

  int get selectedDay => _body['selectedDay'] as int;
  String get destinationId => _body['destinationId'] as String;
  List<Map<String, Object?>> get activities =>
      (_body['activities'] as List).cast<Map<String, Object?>>();
  List<Map<String, Object?>> get places =>
      (_body['places'] as List).cast<Map<String, Object?>>();
  Map<String, Object?> toJson() => _body;

  factory AiAssistantContext.fromDocument(
    EditableTripDocumentV2 doc, {
    catalogue.DestinationReference? destination,
    required int selectedDay,
    List<catalogue.PlaceReference> places = const [],
    List<Map<String, Object?>> openingWindows = const [],
    List<Map<String, Object?>> routes = const [],
    Map<String, PlaceVisitDetails> visitDetails = const {},
    Map<String, VisitPackage> packages = const {},
    Set<String>? closedPlaceIds,
  }) {
    final base = AiGenerationContext.fromDocument(
      doc,
      destination: destination,
    ).toJson();
    _integer(selectedDay, 1, doc.days.length);
    _check(places.length <= 12);
    final references = places
        .map(
          (p) => {
            'id': p.id,
            'name': _human(p.name.trim(), 200),
            'sourceId': p.sourceId,
          },
        )
        .toList();
    final ids = references.map((p) => p['id']).toSet();
    _check(ids.length == references.length);
    final day = doc.days[selectedDay - 1];
    final activities = doc.items
        .where((i) => i.dayId == day.id)
        .map(
          (i) => {
            'id': i.id,
            'title': _human(i.title.trim(), 200),
            'placeId': ids.contains(i.placeId) ? i.placeId : null,
            'startMinute': i.startMinute,
            'endMinute': i.endMinute,
          },
        )
        .toList();
    _check(activities.length <= 48);

    GroundingResolution? grounding;
    var effectiveWindows = openingWindows;
    if (visitDetails.isNotEmpty) {
      final selectedDate =
          day.date != null ? DateTime.tryParse(day.date!) : null;
      grounding = resolveGrounding(
        placeIds: places.map((p) => p.id).toList(),
        visitDetails: visitDetails,
        packages: packages,
        date: selectedDate,
      );
      if (effectiveWindows.isEmpty) {
        effectiveWindows = grounding.openingWindows.take(48).toList();
      }
    }

    final body = <String, Object?>{
      ...base,
      'selectedDay': selectedDay,
      'date': day.date,
      'priority': doc.input.priority,
      'activities': activities,
      'places': references,
      'constraints': {'openingWindows': effectiveWindows, 'routes': routes},
      'weather': 'unknown',
    };
    _validateFacts(body);
    return AiAssistantContext._(
      body,
      EditableTripCodec.digest(doc),
      grounding: grounding,
      destinationName: destination?.name,
      closedPlaceIds: closedPlaceIds,
    );
  }
}

void _validateFacts(Map<String, Object?> body) {
  final places = (body['places'] as List).cast<Map>();
  final ids = places.map((p) => p['id']).toSet();
  final facts = _object(body['constraints'], {'openingWindows', 'routes'});
  _check(
    facts['openingWindows'] is List &&
        facts['routes'] is List &&
        (facts['openingWindows'] as List).length <= 48 &&
        (facts['routes'] as List).length <= 48,
  );
  for (final value in facts['openingWindows'] as List) {
    final w = _object(value, {
      'placeId',
      'startMinute',
      'endMinute',
      'sourceRef',
    });
    _check(ids.contains(w['placeId']));
    final start = _integer(w['startMinute'], 0, 1439),
        end = _integer(w['endMinute'], 1, 1440);
    _check(end > start);
    _text(w['sourceRef'], 128);
  }
  for (final value in facts['routes'] as List) {
    final r = _object(value, {
      'fromPlaceId',
      'toPlaceId',
      'minMinutes',
      'sourceRef',
    });
    _check(ids.contains(r['fromPlaceId']) && ids.contains(r['toPlaceId']));
    _integer(r['minMinutes'], 0, 1440);
    _text(r['sourceRef'], 128);
  }
}

Map<String, Object?> assistantRequest(
  AiAssistantContext context,
  String intent,
  String prompt,
  List<Map<String, Object?>> history,
  String requestId,
) {
  _check(const {'advice', 'recommendations', 'modify'}.contains(intent));
  _human(prompt, 600, multiline: true);
  _check(history.length <= 4 && history.length.isEven);
  for (var i = 0; i < history.length; i++) {
    final h = _object(history[i], {'role', 'text'});
    _check(h['role'] == (i.isEven ? 'user' : 'model'));
    _human(h['text'], 1200, multiline: true);
  }
  final body = <String, Object?>{
    'contract': aiAssistantContract,
    'intent': intent,
    'requestId': requestId,
    'consent': true,
    'context': context.toJson(),
    'prompt': prompt,
    'history': history,
  };
  _check(utf8.encode(jsonEncode(body)).length <= 32768);
  return _freeze(body) as Map<String, Object?>;
}

class AiRecommendation {
  final String title, reason;
  final String? placeId;
  const AiRecommendation(this.title, this.reason, this.placeId);
}

class AiAssistantOperation {
  final String kind;
  final Map<String, Object?> values;
  AiAssistantOperation(this.kind, Map<String, Object?> values)
    : values = Map.unmodifiable(values);
}

class AiAssistantResult {
  final String intent, summary;
  final List<AiRecommendation> recommendations;
  final List<AiAssistantOperation> operations;
  final List<String> warnings;
  AiAssistantResult._(
    this.intent,
    this.summary,
    List<AiRecommendation> recommendations,
    List<AiAssistantOperation> operations,
    List<String> warnings,
  ) : recommendations = List.unmodifiable(recommendations),
      operations = List.unmodifiable(operations),
      warnings = List.unmodifiable(warnings);

  factory AiAssistantResult.outOfDomainPivot(
    AiAssistantContext context,
    String prompt,
  ) {
    final summary = formatSmartPivotSummary(
      prompt: prompt,
      destinationName: context.destinationName,
      selectedDay: context.selectedDay,
    );
    return AiAssistantResult._(
      'advice',
      summary,
      const [],
      const [],
      const [
        'Câu hỏi nằm ngoài phạm vi lập kế hoạch du lịch của TravelGO (Hướng B kết hợp C: Smart Pivot).',
      ],
    );
  }

  factory AiAssistantResult.fromJson(
    Map<String, Object?> raw,
    AiAssistantContext context,
    String intent,
  ) {
    final v = _object(raw, {
          'contract',
          'intent',
          'destinationId',
          'numDays',
          'selectedDay',
          'summary',
          'recommendations',
          'operations',
          'warnings',
          'model',
          'verification',
        }),
        c = context.toJson();
    _check(
      v['contract'] == aiAssistantContract &&
          v['intent'] == intent &&
          v['destinationId'] == context.destinationId &&
          v['numDays'] == c['numDays'] &&
          v['selectedDay'] == context.selectedDay &&
          v['model'] == aiItineraryModel &&
          v['verification'] == 'unverified',
    );
    final summary = _human(v['summary'], 1200, multiline: true);
    _check(
      v['recommendations'] is List &&
          (v['recommendations'] as List).length <= 6 &&
          v['operations'] is List &&
          (v['operations'] as List).length <= 12 &&
          v['warnings'] is List &&
          (v['warnings'] as List).length <= 12,
    );
    final placeIds = context.places.map((p) => p['id']).toSet();
    final recommendations = (v['recommendations'] as List).map((value) {
      final r = _object(value, {'title', 'reason', 'placeId'});
      final pid = r['placeId'] as String?;
      _check(pid == null || placeIds.contains(pid));
      _check(pid == null || !context.closedPlaceIds.contains(pid));
      return AiRecommendation(
        _human(r['title'], 200),
        _human(r['reason'], 400, multiline: true),
        pid,
      );
    }).toList();
    if (intent == 'recommendations') {
      _check(recommendations.isNotEmpty);
    }
    final operations = <AiAssistantOperation>[], targets = <String>{};
    var newCost = 0;
    for (final value in v['operations'] as List) {
      _check(value is Map);
      final kind = (value as Map)['kind'];
      _check(const {'add', 'edit', 'remove'}.contains(kind));
      final op = _object(
        value,
        kind == 'remove'
            ? {'kind', 'itemId'}
            : kind == 'edit'
            ? {'kind', 'itemId', 'title', 'placeId', 'startMinute', 'endMinute'}
            : {
                'kind',
                'title',
                'placeId',
                'startMinute',
                'endMinute',
                'costVnd',
                'category',
              },
      );
      if (kind != 'add') {
        final id = op['itemId'];
        _check(
          id is String &&
              context.activities.any((a) => a['id'] == id) &&
              targets.add(id),
        );
      }
      if (kind != 'remove') {
        _human(op['title'], 200);
        final pid = op['placeId'] as String?;
        _check(pid == null || placeIds.contains(pid));
        _check(pid == null || !context.closedPlaceIds.contains(pid));
        final start = _time(op['startMinute'], 1439),
            end = _time(op['endMinute'], 1440);
        _check(
          (start == null) == (end == null) && (start == null || end! > start),
        );
        if (kind == 'add') {
          if (op['costVnd'] != null) {
            newCost += _integer(op['costVnd'], 0, EditableTripCodec.maxMoney);
            _check(newCost <= EditableTripCodec.maxMoney);
          }
          _check(EditableTripCodec.categories.contains(op['category']));
        }
      }
      operations.add(AiAssistantOperation(kind as String, op));
    }
    _check(intent == 'modify' ? operations.isNotEmpty : operations.isEmpty);
    if (intent == 'modify') {
      _validateCandidate(context, operations);
    }
    final combinedWarnings = <String>[
      if (context.grounding != null) ...context.grounding!.warnings,
      ...(v['warnings'] as List)
          .map((w) => _human(w, 200, multiline: true)),
    ];
    return AiAssistantResult._(
      intent,
      summary,
      recommendations,
      operations,
      combinedWarnings,
    );
  }
}

void _validateCandidate(
  AiAssistantContext context,
  List<AiAssistantOperation> operations,
) {
  final items = context.activities
      .map((a) => Map<String, Object?>.from(a))
      .toList();
  for (final operation in operations) {
    final o = operation.values;
    if (operation.kind == 'remove') {
      items.removeWhere((a) => a['id'] == o['itemId']);
    } else if (operation.kind == 'edit') {
      items.firstWhere((a) => a['id'] == o['itemId']).addAll({
        'title': o['title'],
        'placeId': o['placeId'],
        'startMinute': o['startMinute'],
        'endMinute': o['endMinute'],
      });
    } else {
      items.add({
        'title': o['title'],
        'placeId': o['placeId'],
        'startMinute': o['startMinute'],
        'endMinute': o['endMinute'],
      });
    }
  }
  final facts = context.toJson()['constraints'] as Map;
  for (final a in items) {
    final pid = a['placeId'] as String?;
    if (pid != null) {
      _check(!context.closedPlaceIds.contains(pid));
    }
    if (a['startMinute'] == null || a['endMinute'] == null) {
      continue;
    }
    final start = a['startMinute'] as int, end = a['endMinute'] as int;
    _check(end > start);
    final windows = (facts['openingWindows'] as List)
        .cast<Map>()
        .where((w) => w['placeId'] == a['placeId'])
        .toList();
    if (windows.isNotEmpty) {
      _check(
        windows.any(
          (w) =>
              start >= (w['startMinute'] as int) &&
              end <= (w['endMinute'] as int),
        ),
      );
    }
  }
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      var a = items[i], b = items[j];
      if (a['startMinute'] == null ||
          a['endMinute'] == null ||
          b['startMinute'] == null ||
          b['endMinute'] == null) {
        continue;
      }
      if ((a['startMinute'] as int) > (b['startMinute'] as int)) {
        final old = a;
        a = b;
        b = old;
      }
      _check((a['endMinute'] as int) <= (b['startMinute'] as int));
      final route = (facts['routes'] as List)
          .cast<Map>()
          .where(
            (r) =>
                r['fromPlaceId'] == a['placeId'] &&
                r['toPlaceId'] == b['placeId'],
          )
          .firstOrNull;
      if (route != null) {
        _check(
          (b['startMinute'] as int) - (a['endMinute'] as int) >=
              (route['minMinutes'] as int),
        );
      }
    }
  }
}

class AiModificationPreview {
  final EditableTripDocumentV2 before, document;
  final List<EditableCommand> commands;
  final List<String> differences;
  final List<EditableValidationIssue> issues;
  final BudgetTotals beforeBudget, afterBudget;
  final List<String> estimateReviewItemIds;
  AiModificationPreview(
    this.before,
    this.document,
    List<EditableCommand> commands,
    List<String> differences,
    List<EditableValidationIssue> issues, {
    List<String> estimateReviewItemIds = const [],
  }) : commands = List.unmodifiable(commands),
      differences = List.unmodifiable(differences),
      issues = List.unmodifiable(issues),
      estimateReviewItemIds = List.unmodifiable(estimateReviewItemIds),
      beforeBudget = BudgetCalculator.calculate(before),
      afterBudget = BudgetCalculator.calculate(document);
  bool get canApply => !issues.any((i) => i.isBlocking);
  bool get requiresEstimateReview => estimateReviewItemIds.isNotEmpty;
}

String _clock(int? value) => value == null
    ? 'chưa rõ'
    : '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
String _description(String title, int? start, int? end, String? place) =>
    '$title · ${_clock(start)}–${_clock(end)} · ${place ?? 'địa điểm chưa rõ'}';
String _normalizeTitle(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
String _ledger(EditableTripDocumentV2 doc) => EditableTripCodec.canonicalJson(
  doc.actualExpenses
      .map(
        (e) => {
          'id': e.id,
          'amountVnd': e.amountVnd,
          'category': e.category,
          'paidOn': e.paidOn,
          'description': e.description,
          'provenance': e.provenance.toJson(),
        },
      )
      .toList(),
);
AiModificationPreview prepareAiModification(
  EditableTripDocumentV2 before,
  AiAssistantResult result,
  AiAssistantContext context,
  String Function() newId,
) {
  if (EditableTripCodec.digest(before) != context.baseDigest) {
    throw const AiGenerationFailure('stale');
  }
  _check(result.intent == 'modify' && result.operations.isNotEmpty);
  final day = before.days[context.selectedDay - 1],
      commands = <EditableCommand>[],
      differences = <String>[],
      estimateReviewItemIds = <String>[];
  var count = before.items.where((i) => i.dayId == day.id).length;
  for (final operation in result.operations) {
    final o = operation.values;
    if (operation.kind == 'remove') {
      final old = before.items.firstWhere((i) => i.id == o['itemId']);
      commands.add(RemoveItemCommand(old.id));
      count--;
      differences.add(
        'Xóa hoạt động: ${_description(old.title, old.startMinute, old.endMinute, old.placeId)}. Khoản đã chi được giữ cùng ảnh chụp nguồn.',
      );
    } else if (operation.kind == 'edit') {
      final old = before.items.firstWhere((i) => i.id == o['itemId']);
      final titleChanged =
          _normalizeTitle(old.title) != _normalizeTitle(o['title'] as String);
      final placeChanged = old.placeId != o['placeId'];
      final hasActiveEstimate =
          before.estimates.any((e) => e.itemId == old.id && e.active);
      if ((titleChanged || placeChanged) && hasActiveEstimate) {
        if (!estimateReviewItemIds.contains(old.id)) {
          estimateReviewItemIds.add(old.id);
        }
      }
      commands.add(
        EditItemCommand(
          itemId: old.id,
          title: o['title'] as String,
          notes: old.notes,
          placeId: o['placeId'] as String?,
          startMinute: o['startMinute'] as int?,
          endMinute: o['endMinute'] as int?,
          provenance: FieldProvenance(
            quality: 'unknown',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      );
      differences.add(
        'Trước: ${_description(old.title, old.startMinute, old.endMinute, old.placeId)}\nSau: ${_description(o['title'] as String, o['startMinute'] as int?, o['endMinute'] as int?, o['placeId'] as String?)}. Giữ ghi chú và khoản dự toán cũ; cần xem lại dự toán.',
      );
    } else {
      final itemId = newId();
      commands.add(
        AddItemCommand(
          TripItem(
            id: itemId,
            dayId: day.id,
            position: count++,
            title: o['title'] as String,
            placeId: o['placeId'] as String?,
            startMinute: o['startMinute'] as int?,
            endMinute: o['endMinute'] as int?,
            notes: 'Đề xuất AI chưa xác minh.',
            provenance: FieldProvenance(
              quality: 'unknown',
              sourceRefs: [],
              observedAt: null,
            ),
          ),
        ),
      );
      commands.add(
        PutEstimateCommand(
          EstimatedExpense(
            id: newId(),
            itemId: itemId,
            category: o['category'] as String,
            unitAmountVnd: o['costVnd'] as int?,
            basis: 'trip_total',
            customQuantity: null,
            active: true,
            description: 'Ước tính AI: ${o['title']}',
            provenance: FieldProvenance(
              quality: o['costVnd'] == null ? 'unknown' : 'estimated',
              sourceRefs: [],
              observedAt: null,
            ),
          ),
        ),
      );
      differences.add(
        'Thêm: ${_description(o['title'] as String, o['startMinute'] as int?, o['endMinute'] as int?, o['placeId'] as String?)} · ${o['costVnd'] == null ? 'chi phí chưa rõ' : 'ước tính ${o['costVnd']} VND'}',
      );
    }
  }

  final candidate = EditableTripMutator.apply(before, commands);
  final candidateDayItems =
      candidate.items.where((i) => i.dayId == day.id).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  final known =
      candidateDayItems
          .where((i) => i.startMinute != null && i.endMinute != null)
          .toList()
        ..sort((a, b) {
          final startCmp = a.startMinute!.compareTo(b.startMinute!);
          if (startCmp != 0) return startCmp;
          final endCmp = a.endMinute!.compareTo(b.endMinute!);
          if (endCmp != 0) return endCmp;
          return a.position.compareTo(b.position);
        });
  final unknown =
      candidateDayItems
          .where((i) => i.startMinute == null || i.endMinute == null)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
  final ordered = [...known, ...unknown];
  final orderedIds = ordered.map((i) => i.id).toList();
  final currentIds = candidateDayItems.map((i) => i.id).toList();

  var changedOrder = false;
  if (orderedIds.length == currentIds.length) {
    for (var i = 0; i < orderedIds.length; i++) {
      if (orderedIds[i] != currentIds[i]) {
        changedOrder = true;
        break;
      }
    }
  }
  if (changedOrder) {
    commands.add(ReorderDayCommand(day.id, orderedIds));
    differences.add(
      'Sắp xếp lại thứ tự các hoạt động trong ngày theo giờ bắt đầu.',
    );
  }

  if (context.grounding != null) {
    for (final w in context.grounding!.warnings) {
      differences.add('Lưu ý dữ liệu: $w');
    }
  }

  final after = EditableTripMutator.apply(before, commands);
  _check(_ledger(before) == _ledger(after));
  return AiModificationPreview(
    before,
    after,
    commands,
    differences,
    EditableTripValidator.validate(after, mode: ValidationMode.draft),
    estimateReviewItemIds: estimateReviewItemIds,
  );
}

class AiAssistantReply {
  final AiAssistantResult result;
  final AiModificationPreview? modification;
  const AiAssistantReply(this.result, [this.modification]);
}

typedef AiAssistantGenerator = Future<AiAssistantReply> Function(
  String intent,
  String prompt,
  List<Map<String, Object?>> history,
  String requestId,
);
Future<AiAssistantReply> askAiForDraft({
  required AuthProvider auth,
  required EditableTripDocumentV2 document,
  required AiAssistantContext context,
  required String intent,
  required String prompt,
  required List<Map<String, Object?>> history,
  required String requestId,
  required String Function() newId,
  required bool Function() workspaceCurrent,
  AiGatewayClient? gateway,
}) async {
  // Guardrail: Hướng B kết hợp C (Smart Pivot cho câu hỏi ngoài phạm vi nghiệp vụ)
  if (isOutOfDomainQuery(prompt)) {
    final pivot = AiAssistantResult.outOfDomainPivot(context, prompt);
    return AiAssistantReply(pivot);
  }

  final payload = assistantRequest(context, intent, prompt, history, requestId);
  final raw = await requestAiForDraft(
    auth: auth,
    payload: payload,
    workspaceCurrent: workspaceCurrent,
    gateway: gateway,
  );
  try {
    final result = AiAssistantResult.fromJson(raw, context, intent);
    return AiAssistantReply(
      result,
      intent == 'modify'
          ? prepareAiModification(document, result, context, newId)
          : null,
    );
  } on AiGenerationFailure {
    rethrow;
  } on Object {
    throw const AiGenerationFailure('invalid_result');
  }
}
