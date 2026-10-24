import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../explore/models/catalogue_reference.dart' as catalogue;
import '../../trips/models/editable_trip_codec.dart';
import '../../../core/constants/supabase_constants.dart';
import '../models/editable_trip_command.dart';
import '../models/editable_trip_document.dart';
import 'editable_trip_mutator.dart';
import 'editable_trip_validator.dart';

const aiItineraryContract = 'travelgo.itinerary.v1';
const aiItineraryModel = 'gemini-3.5-flash-lite';
void _check(bool value) {
  if (!value) {
    throw const FormatException('invalid_ai_contract');
  }
}

Map<String, Object?> _object(Object? value, Set<String> keys) {
  _check(value is Map);
  final map = Map<String, Object?>.from(value as Map);
  _check(
    map.keys.toSet().length == keys.length && map.keys.every(keys.contains),
  );
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

int _integer(Object? value, int min, int max) {
  _check(value is int && value >= min && value <= max);
  return value as int;
}

class AiGenerationContext {
  final String destinationId;
  final String? destinationName;
  final int numDays, numPeople, budgetVnd;
  final List<String> interests;
  AiGenerationContext._(
    this.destinationId,
    this.destinationName,
    this.numDays,
    this.numPeople,
    this.budgetVnd,
    List<String> interests,
  ) : interests = List.unmodifiable(interests);
  factory AiGenerationContext.fromDocument(
    EditableTripDocumentV2 document, {
    catalogue.DestinationReference? destination,
  }) {
    EditableTripCodec.validateDocument(document);
    final input = document.input;
    String? destName;
    if (destination != null) {
      _check(destination.id == input.destinationId);
      _check(RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$').hasMatch(destination.id));
      _text(destination.name.trim(), 200);
      _check(
        !RegExp(
          r'@|https?:|www\.|\+?\d[\d .()-]{7,}\d',
          caseSensitive: false,
        ).hasMatch(destination.name),
      );
      destName = destination.name.trim();
    } else {
      _check(
        input.destinationId != null &&
            (EditableTripCodec.destinations.contains(input.destinationId) ||
                RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$').hasMatch(input.destinationId!)),
      );
    }
    for (final interest in input.interests) {
      _text(interest, 80);
      _check(
        !RegExp(
          r'@|https?:|www\.|\+?\d[\d .()-]{7,}\d',
          caseSensitive: false,
        ).hasMatch(interest),
      );
    }
    _check(input.interests.toSet().length == input.interests.length);
    return AiGenerationContext._(
      input.destinationId!,
      destName,
      document.days.length,
      input.travelerCount,
      input.totalBudgetVnd,
      input.interests,
    );
  }
  Map<String, Object?> toJson() => {
    'destinationId': destinationId,
    if (destinationName != null && destinationName!.isNotEmpty)
      'destinationName': destinationName,
    'originRegion': 'unknown',
    'numDays': numDays,
    'numPeople': numPeople,
    'budgetVnd': budgetVnd,
    'interests': interests,
  };
}

class AiProposedActivity {
  final int day;
  final String title, category;
  final int? startMinute, endMinute, costVnd;
  const AiProposedActivity(
    this.day,
    this.title,
    this.startMinute,
    this.endMinute,
    this.costVnd,
    this.category,
  );
}

class AiItineraryProposal {
  final String summary;
  final List<AiProposedActivity> activities;
  final List<String> warnings;
  AiItineraryProposal._(
    this.summary,
    List<AiProposedActivity> activities,
    List<String> warnings,
  ) : activities = List.unmodifiable(activities),
      warnings = List.unmodifiable(warnings);
  factory AiItineraryProposal.fromJson(
    Map<String, Object?> value,
    AiGenerationContext context,
  ) {
    final row = _object(value, {
      'contract',
      'destinationId',
      'numDays',
      'summary',
      'activities',
      'warnings',
      'model',
      'verification',
    });
    _check(
      row['contract'] == aiItineraryContract &&
          row['destinationId'] == context.destinationId &&
          row['numDays'] == context.numDays &&
          row['model'] == aiItineraryModel &&
          row['verification'] == 'unverified',
    );
    final summary = _text(row['summary'], 800),
        raw = row['activities'],
        warn = row['warnings'];
    _check(
      raw is List &&
          raw.isNotEmpty &&
          raw.length <= 48 &&
          warn is List &&
          warn.length <= 12,
    );
    final activities = <AiProposedActivity>[];
    var total = 0;
    for (final value in raw as List) {
      final a = _object(value, {
        'day',
        'title',
        'startMinute',
        'endMinute',
        'costVnd',
        'category',
      });
      final day = _integer(a['day'], 1, context.numDays),
          title = _text(a['title'], 120);
      final start = a['startMinute'] == null
          ? null
          : _integer(a['startMinute'], 0, 1439);
      final end = a['endMinute'] == null
          ? null
          : _integer(a['endMinute'], 1, 1440);
      _check(
        (start == null) == (end == null) && (start == null || end! > start),
      );
      final cost = a['costVnd'] == null
          ? null
          : _integer(a['costVnd'], 0, EditableTripCodec.maxMoney);
      total += cost ?? 0;
      _check(total <= EditableTripCodec.maxMoney);
      _check(EditableTripCodec.categories.contains(a['category']));
      for (final previous in activities) {
        if (previous.day == day &&
            previous.startMinute != null &&
            start != null) {
          _check(start >= previous.endMinute! || previous.startMinute! >= end!);
        }
      }
      activities.add(
        AiProposedActivity(
          day,
          title,
          start,
          end,
          cost,
          a['category'] as String,
        ),
      );
    }
    return AiItineraryProposal._(
      summary,
      activities,
      (warn as List).map((w) => _text(w, 200)).toList(),
    );
  }
}

class AiPreparedProposal {
  final AiItineraryProposal proposal;
  final EditableTripDocumentV2 document;
  final List<EditableCommand> commands;
  final List<EditableValidationIssue> issues;
  AiPreparedProposal(
    this.proposal,
    this.document,
    List<EditableCommand> commands,
    List<EditableValidationIssue> issues,
  ) : commands = List.unmodifiable(commands),
      issues = List.unmodifiable(issues);
  bool get canApply => !issues.any((i) => i.isBlocking);
}

String _normalizeActivityTitle(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

AiPreparedProposal prepareAiProposal(
  EditableTripDocumentV2 before,
  AiItineraryProposal proposal,
  String Function() newId,
) {
  final existingKeys = <String>{};
  for (var i = 0; i < before.days.length; i++) {
    final day = before.days[i];
    final dayOrdinal = i + 1;
    for (final item in before.items.where((it) => it.dayId == day.id)) {
      existingKeys.add(
        '$dayOrdinal|${_normalizeActivityTitle(item.title)}|${item.startMinute}|${item.endMinute}',
      );
    }
  }

  final proposalKeys = <String>{};
  final duplicateTitles = <String>{};
  for (final a in proposal.activities) {
    final key =
        '${a.day}|${_normalizeActivityTitle(a.title)}|${a.startMinute}|${a.endMinute}';
    if (existingKeys.contains(key) || proposalKeys.contains(key)) {
      duplicateTitles.add(a.title.trim());
    }
    proposalKeys.add(key);
  }

  final commands = <EditableCommand>[];
  final positions = {
    for (final d in before.days)
      d.id: before.items.where((i) => i.dayId == d.id).length,
  };
  for (final a in proposal.activities) {
    final day = before.days[a.day - 1], itemId = newId();
    commands.add(
      AddItemCommand(
        TripItem(
          id: itemId,
          dayId: day.id,
          position: positions[day.id]!,
          title: a.title,
          placeId: null,
          startMinute: a.startMinute,
          endMinute: a.endMinute,
          notes: 'Gợi ý AI chưa xác minh. Kiểm tra địa điểm, giờ mở cửa, đường đi và thời tiết.',
          provenance: FieldProvenance(
            quality: 'unknown',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ),
    );
    positions[day.id] = positions[day.id]! + 1;
    commands.add(
      PutEstimateCommand(
        EstimatedExpense(
          id: newId(),
          itemId: itemId,
          category: a.category,
          unitAmountVnd: a.costVnd,
          basis: 'trip_total',
          customQuantity: null,
          active: true,
          description: 'Ước tính AI: ${a.title}',
          provenance: FieldProvenance(
            quality: a.costVnd == null ? 'unknown' : 'estimated',
            sourceRefs: [],
            observedAt: null,
          ),
        ),
      ),
    );
  }

  final candidate = EditableTripMutator.apply(before, commands);
  for (final day in before.days) {
    final dayItems =
        candidate.items.where((i) => i.dayId == day.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final known =
        dayItems
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
        dayItems
            .where((i) => i.startMinute == null || i.endMinute == null)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final ordered = [...known, ...unknown];
    final orderedIds = ordered.map((i) => i.id).toList();
    final currentIds = dayItems.map((i) => i.id).toList();
    var changed = false;
    if (orderedIds.length == currentIds.length) {
      for (var i = 0; i < orderedIds.length; i++) {
        if (orderedIds[i] != currentIds[i]) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      commands.add(ReorderDayCommand(day.id, orderedIds));
    }
  }

  final after = EditableTripMutator.apply(before, commands);
  final issues = <EditableValidationIssue>[];
  if (duplicateTitles.isNotEmpty) {
    issues.add(
      EditableValidationIssue(
        code: 'ai_duplicate_activity',
        path: 'proposal.activities',
        message:
            'Đề xuất có hoạt động trùng với lịch hiện có hoặc bị lặp trong chính đề xuất: ${duplicateTitles.join(', ')}.',
        severity: EditableIssueSeverity.error,
      ),
    );
  }
  issues.addAll(
    EditableTripValidator.validate(after, mode: ValidationMode.draft),
  );
  return AiPreparedProposal(
    proposal,
    after,
    commands,
    issues,
  );
}

class AiGenerationFailure implements Exception {
  final String code;
  const AiGenerationFailure(this.code);
  bool get retrySameRequest => !const {
    'failed',
    'expired',
    'result_expired',
    'invalid_context',
    'unauthorized',
    'identity_unavailable',
    'subject_denied',
    'deployment_blocked',
  }.contains(code);
  String get message => switch (code) {
    'deployment_blocked' || 'subject_denied' => 'Dịch vụ sinh lịch AI chưa được mở cho phiên này. Bạn vẫn có thể lập lịch thủ công.',
    'quota_exhausted' => 'Đã hết lượt AI hôm nay. Lượt mới được tính từ 00:00 giờ Việt Nam; planner thủ công vẫn dùng được.',
    'unauthorized' || 'identity_unavailable' =>
      'Chưa thể xác minh phiên dùng AI. Giữ nguyên bản nháp và thử lại sau.',
    'invalid_context' => 'Thông tin gửi AI chưa hợp lệ. Kiểm tra điểm đến và bỏ thông tin liên hệ khỏi sở thích.',
    'pending' || 'outcome_pending' => 'Chưa xác nhận được kết quả AI. Thử kiểm tra lại; nội dung chuyến đi chưa thay đổi.',
    'stale' =>
      'Chuyến đi hoặc phiên đã thay đổi. Hãy mở lại đề xuất từ bản hiện tại.',
    _ => 'Chưa thể tạo lịch AI hợp lệ. Bản nháp được giữ nguyên; bạn vẫn có thể tự chỉnh lịch.',
  };
  @override
  String toString() => 'AiGenerationFailure($code)';
}

/// Dedicated anonymous SDK identity. Never mutates the Account SDK or publishes a user.
class GuestAiIdentity {
  final SupabaseClient client;
  final LocalStorage storage;
  bool _loaded = false;
  bool _knownIdentity = false;
  String? _subject;
  Future<void> _tail = Future.value();
  GuestAiIdentity({required this.client, required this.storage});
  Future<String> access() {
    final result = Completer<String>();
    _tail = _tail.then((_) async {
      try {
        if (!_loaded) {
          await storage.initialize();
          if (await storage.hasAccessToken()) {
            _knownIdentity = true;
            final persisted = await storage.accessToken();
            if (persisted == null) {
              throw const AiGenerationFailure('identity_unavailable');
            }
            await client.auth.recoverSession(persisted);
          }
          _loaded = true;
        }
        var session = client.auth.currentSession;
        if (session == null) {
          if (_knownIdentity) {
            throw const AiGenerationFailure('identity_unavailable');
          }
          session = (await client.auth.signInAnonymously()).session;
        }
        if (session == null || session.user.isAnonymous != true) {
          throw const AiGenerationFailure('identity_unavailable');
        }
        if (_subject != null && _subject != session.user.id) {
          throw const AiGenerationFailure('identity_unavailable');
        }
        _knownIdentity = true;
        _subject = session.user.id;
        if ((session.expiresAt ?? 0) <=
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30) {
          final owner = session.user.id;
          session = (await client.auth.refreshSession()).session;
          if (session == null ||
              session.user.id != owner ||
              session.user.isAnonymous != true) {
            throw const AiGenerationFailure('identity_unavailable');
          }
        }
        await storage.persistSession(jsonEncode(session.toJson()));
        result.complete(session.accessToken);
      } on Object {
        result.completeError(const AiGenerationFailure('identity_unavailable'));
      }
    });
    return result.future;
  }

  static GuestAiIdentity? _shared;
  static GuestAiIdentity get shared => _shared ??= GuestAiIdentity(
    client: SupabaseClient(
      SupabaseConstants.projectUrl,
      SupabaseConstants.publishableKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
    storage: SharedPreferencesLocalStorage(
      persistSessionKey: 'travelgo.ai.anonymous.v1',
    ),
  );
}

class AiGatewayClient {
  final Dio dio;
  final Uri endpoint;
  final String publicKey;
  AiGatewayClient({Dio? dio, Uri? endpoint, String? publicKey})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 35),
            ),
          ),
      endpoint =
          endpoint ??
          Uri.parse(
            '${SupabaseConstants.projectUrl}/functions/v1/itinerary-proposal',
          ),
      publicKey = publicKey ?? SupabaseConstants.publishableKey;
  Future<AiItineraryProposal> generate(
    AiGenerationContext context,
    String requestId, {
    required Future<String> Function() credential,
    required bool Function() isCurrent,
  }) async {
    final result = await request(
      {
        'contract': aiItineraryContract,
        'intent': 'generate',
        'requestId': requestId,
        'consent': true,
        'context': context.toJson(),
      },
      credential: credential,
      isCurrent: isCurrent,
    );
    try {
      return AiItineraryProposal.fromJson(result, context);
    } on Object {
      throw const AiGenerationFailure('invalid_result');
    }
  }

  Future<Map<String, Object?>> request(
    Map<String, Object?> payload, {
    required Future<String> Function() credential,
    required bool Function() isCurrent,
  }) async {
    final requestId = payload['requestId'];
    try {
      if (!isCurrent()) {
        throw const AiGenerationFailure('stale');
      }
      final bearer = await credential();
      if (!isCurrent()) {
        throw const AiGenerationFailure('stale');
      }
      final response = await dio.postUri<ResponseBody>(
        endpoint,
        data: jsonEncode(payload),
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          headers: {
            'content-type': 'application/json',
            'apikey': publicKey,
            'Authorization': 'Bearer $bearer',
          },
        ),
      );
      final chunks = <int>[];
      await for (final chunk in response.data!.stream.timeout(
        const Duration(seconds: 35),
      )) {
        if (chunks.length + chunk.length > 32768) {
          throw const FormatException('ai_response_too_large');
        }
        chunks.addAll(chunk);
      }
      if (!isCurrent()) {
        throw const AiGenerationFailure('stale');
      }
      if (response.statusCode == 404) {
        throw const AiGenerationFailure('deployment_blocked');
      }
      final value = EditableTripCodec.parseStrict(
        utf8.decode(chunks),
        limit: 32768,
      );
      if (value is! Map) {
        throw const FormatException('invalid_ai_envelope');
      }
      final row = Map<String, Object?>.from(value);
      const safeCodes = {
        'deployment_blocked',
        'subject_denied',
        'unauthorized',
        'auth_unavailable',
        'invalid_context',
        'quota_unavailable',
        'quota_exhausted',
        'global_cap',
        'pending',
        'outcome_pending',
        'failed',
        'expired',
        'result_expired',
      };
      if (response.statusCode != 200 || row['status'] != 'succeeded') {
        throw AiGenerationFailure(
          safeCodes.contains(row['status'])
              ? row['status'] as String
              : 'unavailable',
        );
      }
      _object(row, {
        'status',
        'requestId',
        'acceptedDay',
        'remaining',
        'result',
      });
      _check(
        row['requestId'] == requestId &&
            row['remaining'] is int &&
            (row['remaining'] as int) >= 0,
      );
      _check(row['result'] is Map);
      return Map<String, Object?>.from(row['result'] as Map);
    } on AiGenerationFailure {
      rethrow;
    } on FormatException {
      throw const AiGenerationFailure('invalid_result');
    } on Object {
      throw const AiGenerationFailure('outcome_pending');
    }
  }
}

Future<Map<String, Object?>> requestAiForDraft({
  required AuthProvider auth,
  required Map<String, Object?> payload,
  required bool Function() workspaceCurrent,
  AiGatewayClient? gateway,
}) async {
  final epoch = auth.authEpoch,
      owner = auth.currentUser?.id,
      guest = auth.isGuest;
  bool current() =>
      workspaceCurrent() &&
      auth.authEpoch == epoch &&
      auth.currentUser?.id == owner &&
      auth.isGuest == guest &&
      !auth.isDemoSession;
  if (!current() || (!guest && owner == null)) {
    throw const AiGenerationFailure('unauthorized');
  }
  Future<String> credential() async {
    if (!current()) {
      throw const AiGenerationFailure('stale');
    }
    if (guest) {
      return GuestAiIdentity.shared.access();
    }
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null ||
        session.user.id != owner ||
        session.user.isAnonymous == true ||
        (session.expiresAt ?? 0) <=
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10) {
      throw const AiGenerationFailure('unauthorized');
    }
    return session.accessToken;
  }

  final own = gateway == null, client = gateway ?? AiGatewayClient();
  try {
    final result = await client.request(
      payload,
      credential: credential,
      isCurrent: current,
    );
    if (!current()) {
      throw const AiGenerationFailure('stale');
    }
    return result;
  } finally {
    if (own) {
      client.dio.close(force: true);
    }
  }
}

Future<AiPreparedProposal> generateAiForDraft({
  required AuthProvider auth,
  required EditableTripDocumentV2 document,
  required String requestId,
  required String Function() newId,
  required bool Function() workspaceCurrent,
  catalogue.DestinationReference? destination,
  AiGatewayClient? gateway,
}) async {
  final context = AiGenerationContext.fromDocument(
    document,
    destination: destination,
  );
  final raw = await requestAiForDraft(
    auth: auth,
    payload: {
      'contract': aiItineraryContract,
      'intent': 'generate',
      'requestId': requestId,
      'consent': true,
      'context': context.toJson(),
    },
    workspaceCurrent: workspaceCurrent,
    gateway: gateway,
  );
  try {
    return prepareAiProposal(
      document,
      AiItineraryProposal.fromJson(raw, context),
      newId,
    );
  } on Object {
    throw const AiGenerationFailure('invalid_result');
  }
}
