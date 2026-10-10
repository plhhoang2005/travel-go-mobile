import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';

/// Base exception for all trip payload encoding, decoding and validation errors.
abstract class TripPayloadException implements Exception {
  final String message;
  const TripPayloadException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class CorruptPayloadException extends TripPayloadException {
  const CorruptPayloadException(super.message);
}

class EmptyPayloadContentException extends TripPayloadException {
  const EmptyPayloadContentException(super.message);
}

class InvalidSchemaVersionException extends TripPayloadException {
  const InvalidSchemaVersionException(super.message);
}

class UnsupportedSchemaVersionException extends TripPayloadException {
  const UnsupportedSchemaVersionException(super.message);
}

class InvalidDateFormatException extends TripPayloadException {
  const InvalidDateFormatException(super.message);
}

class InvalidDateRangeException extends TripPayloadException {
  const InvalidDateRangeException(super.message);
}

class InvalidMetadataException extends TripPayloadException {
  const InvalidMetadataException(super.message);
}

/// Metadata describing high-level itinerary parameters in Envelope V1.
class TripMetadataV1 {
  final String? title;
  final String? destinationId;
  final String? destinationName;
  final String? startDate;
  final String? endDate;
  final String? timezone;

  TripMetadataV1({
    this.title,
    this.destinationId,
    this.destinationName,
    this.startDate,
    this.endDate,
    this.timezone,
  }) {
    if (title != null) {
      if (title!.trim().isEmpty) {
        throw const InvalidMetadataException('title cannot be blank if provided');
      }
      TripPayloadCodec.validateUnicode(title!);
    }
    if (destinationId != null) {
      if (destinationId!.trim().isEmpty) {
        throw const InvalidMetadataException('destinationId cannot be blank if provided');
      }
      TripPayloadCodec.validateUnicode(destinationId!);
    }
    if (destinationName != null) {
      if (destinationName!.trim().isEmpty) {
        throw const InvalidMetadataException('destinationName cannot be blank if provided');
      }
      TripPayloadCodec.validateUnicode(destinationName!);
    }
    if (timezone != null) {
      if (timezone!.trim().isEmpty) {
        throw const InvalidMetadataException('timezone cannot be blank if provided');
      }
      TripPayloadCodec.validateUnicode(timezone!);
    }

    if (startDate != null) {
      TripPayloadCodec.validateCalendarDate(startDate!);
    }
    if (endDate != null) {
      TripPayloadCodec.validateCalendarDate(endDate!);
    }
    if (startDate != null && endDate != null) {
      final s = DateTime.utc(
        int.parse(startDate!.substring(0, 4)),
        int.parse(startDate!.substring(5, 7)),
        int.parse(startDate!.substring(8, 10)),
      );
      final e = DateTime.utc(
        int.parse(endDate!.substring(0, 4)),
        int.parse(endDate!.substring(5, 7)),
        int.parse(endDate!.substring(8, 10)),
      );
      if (e.isBefore(s)) {
        throw InvalidDateRangeException(
          'endDate ($endDate) cannot be before startDate ($startDate)',
        );
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'destinationId': destinationId,
      'destinationName': destinationName,
      'startDate': startDate,
      'endDate': endDate,
      'timezone': timezone,
    };
  }

  TripMetadataV1 copyWith({
    String? title,
    String? destinationId,
    String? destinationName,
    String? startDate,
    String? endDate,
    String? timezone,
  }) {
    return TripMetadataV1(
      title: title ?? this.title,
      destinationId: destinationId ?? this.destinationId,
      destinationName: destinationName ?? this.destinationName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timezone: timezone ?? this.timezone,
    );
  }
}

/// Frozen canonical trip payload envelope v1.
class CanonicalTripPayloadV1 {
  final int schemaVersion;
  final TripMetadataV1 metadata;
  final PlanTripRequest? request;
  final PlanTripResponse? plan;

  CanonicalTripPayloadV1({
    this.schemaVersion = 1,
    required this.metadata,
    PlanTripRequest? request,
    PlanTripResponse? plan,
  })  : request = request != null ? TripPayloadCodec.deepFreezeRequest(request) : null,
        plan = plan != null ? TripPayloadCodec.deepFreezePlan(plan) : null {
    if (schemaVersion != 1) {
      throw InvalidSchemaVersionException('schemaVersion must be 1, got $schemaVersion');
    }
    if (this.request == null && this.plan == null) {
      throw const EmptyPayloadContentException(
        'At least one of request or plan must be non-null in a valid payload',
      );
    }
    if (this.request != null) {
      TripPayloadCodec.validateRequest(this.request!);
    }
    if (this.plan != null) {
      TripPayloadCodec.validatePlan(this.plan!);
    }
  }
}

/// Original raw headers preserved from a legacy database row.
class LegacyTripRowContext {
  final String? id;
  final String? userId;
  final String? title;
  final String? destinationName;
  final num? numDays;
  final num? budgetTotal;
  final String? status;
  final String? startDate; // Original raw instant string
  final String? endDate;   // Original raw instant string
  final String? createdAt; // Original raw instant string

  const LegacyTripRowContext({
    this.id,
    this.userId,
    this.title,
    this.destinationName,
    this.numDays,
    this.budgetTotal,
    this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
  });
}

/// Result of decoding a legacy database row.
class LegacyRowAdapterResult {
  final CanonicalTripPayloadV1 payload;
  final LegacyTripRowContext legacyContext;

  const LegacyRowAdapterResult({
    required this.payload,
    required this.legacyContext,
  });
}

/// Codec for CanonicalTripPayloadV1 providing deterministic UTF-16 ordinal JSON
/// encoding, SHA-256 digest calculation, and strict schema validation.
class TripPayloadCodec {
  static const int currentSchemaVersion = 1;

  static const Set<String> _requiredEnvelopeKeys = {
    'schemaVersion',
    'metadata',
    'request',
    'plan',
  };

  static const Set<String> _requiredMetadataKeys = {
    'title',
    'destinationId',
    'destinationName',
    'startDate',
    'endDate',
    'timezone',
  };

  static const Set<String> _requiredRequestKeys = {
    'origin',
    'numDays',
    'numPeople',
    'budgetVnd',
    'preferences',
    'priority',
  };

  static const Set<String> _requiredPlanKeys = {
    'winnerId',
    'topDestinations',
    'transportOptions',
    'itineraryDays',
    'budgetBreakdown',
    'aiExplanation',
    'dataSources',
    'assumptions',
  };

  static const Set<String> _allAllowedPlanKeys = {
    'winnerId',
    'topDestinations',
    'transportOptions',
    'itineraryDays',
    'budgetBreakdown',
    'aiExplanation',
    'dataSources',
    'assumptions',
    'isFallback',
  };

  static const Set<String> _requiredDestinationKeys = {
    'id',
    'name',
    'totalScore',
    'normalizedScores',
    'scoreContributions',
    'estimatedCostVnd',
    'weatherSource',
    'avgTempMax',
    'avgPrecipitation',
    'latitude',
    'longitude',
    'region',
  };

  static const Set<String> _allAllowedTransportKeys = {
    'mode',
    'displayName',
    'priceTotalVnd',
    'durationHours',
    'comfortScore',
    'paretoOptimal',
    'isParetoOptimal',
    'tradeoffType',
    'recommendationReason',
  };

  static const Set<String> _requiredDayKeys = {
    'day',
    'title',
    'activities',
  };

  static const Set<String> _requiredActivityKeys = {
    'time',
    'title',
    'costVnd',
    'durationHours',
  };

  static const Set<String> _requiredBudgetKeys = {
    'transport',
    'accommodation',
    'food',
    'attractions',
    'remainingSafetyMargin',
  };

  /// Strict calendar validation: validates format YYYY-MM-DD, four-digit year (1..9999),
  /// and exact day component roundtrip (rejecting non-existent leap days or months).
  static void validateCalendarDate(String dateStr) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dateStr);
    if (match == null) {
      throw InvalidDateFormatException('Date must be in YYYY-MM-DD format: $dateStr');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1 || day > 31) {
      throw InvalidDateFormatException('Date values out of calendar range: $dateStr');
    }

    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw InvalidDateFormatException('Invalid calendar date: $dateStr');
    }
  }

  /// Encodes a [CanonicalTripPayloadV1] into deterministic canonical JSON string.
  /// Keys are sorted recursively by UTF-16 code-unit ordinal (String.compareTo).
  /// Original Unicode code points are preserved without NFC normalization.
  static String encode(CanonicalTripPayloadV1 payload) {
    final map = <String, dynamic>{
      'schemaVersion': payload.schemaVersion,
      'metadata': payload.metadata.toJson(),
      'request': payload.request?.toJson(),
      'plan': payload.plan?.toJson(),
    };
    return _canonicalize(map);
  }

  /// Computes SHA-256 hex digest over the UTF-8 bytes of the canonical JSON string.
  static String computeDigest(CanonicalTripPayloadV1 payload) {
    final canonicalString = encode(payload);
    final bytes = utf8.encode(canonicalString);
    return sha256.convert(bytes).toString();
  }

  /// Decodes raw JSON map into a [CanonicalTripPayloadV1].
  /// Enforces strict validation before calling DTO parsers.
  static CanonicalTripPayloadV1 decode(dynamic raw) {
    if (raw is! Map) {
      throw const CorruptPayloadException('Payload must be a Map');
    }
    final map = Map<String, dynamic>.from(raw);
    if (map.isEmpty) {
      throw const CorruptPayloadException('Payload cannot be empty');
    }

    if (!map.containsKey('schemaVersion')) {
      return decodeBareLegacyPlan(map);
    }

    final versionRaw = map['schemaVersion'];
    if (versionRaw == null || versionRaw is! int) {
      throw InvalidSchemaVersionException(
        'schemaVersion must be an integer, got ${versionRaw.runtimeType} ($versionRaw)',
      );
    }
    if (versionRaw <= 0) {
      throw InvalidSchemaVersionException('schemaVersion must be positive, got $versionRaw');
    }
    if (versionRaw > currentSchemaVersion) {
      throw UnsupportedSchemaVersionException(
        'Unsupported schemaVersion $versionRaw (expected <= $currentSchemaVersion)',
      );
    }

    // Check required and unknown content envelope keys
    for (final key in _requiredEnvelopeKeys) {
      if (!map.containsKey(key)) {
        throw CorruptPayloadException('Missing required content envelope key: $key');
      }
    }
    for (final key in map.keys) {
      if (!_requiredEnvelopeKeys.contains(key)) {
        throw CorruptPayloadException('Unknown content envelope key: $key');
      }
    }

    // Validate metadata
    final metadataRaw = map['metadata'];
    if (metadataRaw == null || metadataRaw is! Map) {
      throw const CorruptPayloadException('metadata must be a non-null Map');
    }
    final metaMap = Map<String, dynamic>.from(metadataRaw);
    for (final key in _requiredMetadataKeys) {
      if (!metaMap.containsKey(key)) {
        throw CorruptPayloadException('Missing required metadata key: $key');
      }
    }
    for (final key in metaMap.keys) {
      if (!_requiredMetadataKeys.contains(key)) {
        throw CorruptPayloadException('Unknown metadata key: $key');
      }
    }

    // Validate metadata value types
    for (final entry in metaMap.entries) {
      if (entry.value != null && entry.value is! String) {
        throw CorruptPayloadException(
          'metadata field "${entry.key}" must be a String or null, got ${entry.value.runtimeType}',
        );
      }
    }

    final metadata = TripMetadataV1(
      title: metaMap['title'] as String?,
      destinationId: metaMap['destinationId'] as String?,
      destinationName: metaMap['destinationName'] as String?,
      startDate: metaMap['startDate'] as String?,
      endDate: metaMap['endDate'] as String?,
      timezone: metaMap['timezone'] as String?,
    );

    // Validate request
    PlanTripRequest? request;
    if (map['request'] != null) {
      final reqRaw = map['request'];
      if (reqRaw is! Map) {
        throw const CorruptPayloadException('request must be a Map');
      }
      final reqMap = Map<String, dynamic>.from(reqRaw);
      _validateRequestMap(reqMap);
      request = deepFreezeRequest(PlanTripRequest.fromJson(reqMap));
    }

    // Validate plan
    PlanTripResponse? plan;
    if (map['plan'] != null) {
      final planRaw = map['plan'];
      if (planRaw is! Map) {
        throw const CorruptPayloadException('plan must be a Map');
      }
      final planMap = Map<String, dynamic>.from(planRaw);
      _validatePlanMap(planMap);
      plan = deepFreezePlan(PlanTripResponse.fromJson(planMap));
    }

    if (request == null && plan == null) {
      throw const EmptyPayloadContentException(
        'At least one of request or plan must be non-null in a valid payload',
      );
    }

    return CanonicalTripPayloadV1(
      schemaVersion: versionRaw,
      metadata: metadata,
      request: request,
      plan: plan,
    );
  }

  /// Decodes a bare legacy plan without envelope or schemaVersion.
  static CanonicalTripPayloadV1 decodeBareLegacyPlan(Map<String, dynamic> rawPlan) {
    if (rawPlan.isEmpty) {
      throw const CorruptPayloadException('Legacy plan cannot be empty');
    }
    if (!rawPlan.containsKey('winnerId') &&
        !rawPlan.containsKey('topDestinations') &&
        !rawPlan.containsKey('itineraryDays')) {
      throw const CorruptPayloadException('Unrecognized unversioned payload shape');
    }
    _validatePlanMap(rawPlan, isLegacy: true);
    final plan = deepFreezePlan(PlanTripResponse.fromJson(rawPlan));

    return CanonicalTripPayloadV1(
      schemaVersion: currentSchemaVersion,
      metadata: TripMetadataV1(
        title: null,
        destinationId: null,
        destinationName: null,
        startDate: null,
        endDate: null,
        timezone: null,
      ),
      request: null,
      plan: plan,
    );
  }

  /// Decodes a legacy database row into a [LegacyRowAdapterResult].
  /// Preserves original row context including timestamps and numeric totals without truncation.
  static LegacyRowAdapterResult decodeLegacyRow(Map<String, dynamic> row) {
    final rawPlan = row['ai_plan_data'] ?? row['trip_plan_data'];
    if (rawPlan == null || rawPlan is! Map || rawPlan.isEmpty) {
      throw const CorruptPayloadException('Missing or empty plan data in legacy row');
    }
    final planMap = Map<String, dynamic>.from(rawPlan);

    CanonicalTripPayloadV1 payload;
    if (planMap.containsKey('schemaVersion')) {
      payload = decode(planMap);
    } else {
      payload = decodeBareLegacyPlan(planMap);
      // Populate metadata if available from legacy row headers without fabricating dates
      final rowTitle = row['title'] as String?;
      final rowDest = row['destination_name'] as String?;
      if ((rowTitle != null && rowTitle.trim().isNotEmpty) ||
          (rowDest != null && rowDest.trim().isNotEmpty)) {
        payload = CanonicalTripPayloadV1(
          schemaVersion: currentSchemaVersion,
          metadata: TripMetadataV1(
            title: rowTitle?.trim().isNotEmpty == true ? rowTitle : null,
            destinationId: payload.plan?.winnerId,
            destinationName: rowDest?.trim().isNotEmpty == true ? rowDest : null,
            startDate: null,
            endDate: null,
            timezone: null,
          ),
          request: payload.request,
          plan: payload.plan,
        );
      }
    }

    final context = LegacyTripRowContext(
      id: row['id'] as String?,
      userId: row['user_id'] as String?,
      title: row['title'] as String?,
      destinationName: row['destination_name'] as String?,
      numDays: row['num_days'] as num?,
      budgetTotal: row['budget_total'] as num?,
      status: row['status'] as String?,
      startDate: row['start_date'] as String?,
      endDate: row['end_date'] as String?,
      createdAt: row['created_at'] as String?,
    );

    return LegacyRowAdapterResult(
      payload: payload,
      legacyContext: context,
    );
  }

  /// Validates [PlanTripRequest] at constructor/encoding boundaries.
  static void validateRequest(PlanTripRequest req) {
    if (req.origin.trim().isEmpty) {
      throw const CorruptPayloadException('Request origin cannot be blank');
    }
    validateUnicode(req.origin);
    if (req.numDays < 1) {
      throw const CorruptPayloadException('Request numDays must be at least 1');
    }
    if (req.numPeople < 1) {
      throw const CorruptPayloadException('Request numPeople must be at least 1');
    }
    if (req.budgetVnd < 0) {
      throw const CorruptPayloadException('Request budgetVnd cannot be negative');
    }
    for (final pref in req.preferences) {
      validateUnicode(pref);
    }
    validateUnicode(req.priority);
  }

  /// Validates [PlanTripResponse] at constructor/encoding boundaries.
  static void validatePlan(PlanTripResponse plan) {
    validateUnicode(plan.winnerId);
    validateUnicode(plan.aiExplanation);
    for (final entry in plan.dataSources.entries) {
      validateUnicode(entry.key);
      validateUnicode(entry.value);
    }
    for (final asm in plan.assumptions) {
      validateUnicode(asm);
    }

    if (plan.budgetBreakdown != null) {
      final b = plan.budgetBreakdown!;
      if (b.transport < 0 ||
          b.accommodation < 0 ||
          b.food < 0 ||
          b.attractions < 0 ||
          b.remainingSafetyMargin < 0) {
        throw const CorruptPayloadException('Budget breakdown amounts cannot be negative');
      }
    }

    for (final dest in plan.topDestinations) {
      validateUnicode(dest.id);
      validateUnicode(dest.name);
      validateUnicode(dest.weatherSource);
      validateUnicode(dest.region);
      if (!dest.totalScore.isFinite ||
          !dest.avgTempMax.isFinite ||
          !dest.avgPrecipitation.isFinite) {
        throw const CorruptPayloadException('Destination scores and weather values must be finite');
      }
      if (dest.latitude != null && !dest.latitude!.isFinite) {
        throw const CorruptPayloadException('Destination latitude must be finite');
      }
      if (dest.longitude != null && !dest.longitude!.isFinite) {
        throw const CorruptPayloadException('Destination longitude must be finite');
      }
      if (dest.estimatedCostVnd < 0) {
        throw const CorruptPayloadException('Destination estimatedCostVnd cannot be negative');
      }
      for (final entry in dest.normalizedScores.entries) {
        validateUnicode(entry.key);
        if (!entry.value.isFinite) {
          throw const CorruptPayloadException('normalizedScores value must be finite');
        }
      }
      for (final entry in dest.scoreContributions.entries) {
        validateUnicode(entry.key);
        if (!entry.value.isFinite) {
          throw const CorruptPayloadException('scoreContributions value must be finite');
        }
      }
    }

    for (final opt in plan.transportOptions) {
      validateUnicode(opt.mode);
      validateUnicode(opt.displayName);
      validateUnicode(opt.tradeoffType);
      validateUnicode(opt.recommendationReason);
      if (opt.priceTotalVnd < 0) {
        throw const CorruptPayloadException('Transport priceTotalVnd cannot be negative');
      }
      if (!opt.durationHours.isFinite || !opt.comfortScore.isFinite) {
        throw const CorruptPayloadException('Transport duration and comfort score must be finite');
      }
    }

    for (final day in plan.itineraryDays) {
      if (day.day < 1) {
        throw const CorruptPayloadException('Itinerary day number must be at least 1');
      }
      validateUnicode(day.title);
      for (final act in day.activities) {
        validateUnicode(act.time);
        validateUnicode(act.title);
        if (act.costVnd < 0) {
          throw const CorruptPayloadException('Activity costVnd cannot be negative');
        }
        if (!act.durationHours.isFinite) {
          throw const CorruptPayloadException('Activity durationHours must be finite');
        }
      }
    }
  }

  static void _validateRequestMap(Map<String, dynamic> m) {
    for (final k in _requiredRequestKeys) {
      if (!m.containsKey(k)) {
        throw CorruptPayloadException('Missing required request key: $k');
      }
    }
    for (final k in m.keys) {
      if (!_requiredRequestKeys.contains(k)) {
        throw CorruptPayloadException('Unknown request key: $k');
      }
    }

    if (m['origin'] is! String) {
      throw const CorruptPayloadException('Request origin must be a String');
    }
    final origin = m['origin'] as String;
    if (origin.trim().isEmpty) {
      throw const CorruptPayloadException('Request origin cannot be blank');
    }
    validateUnicode(origin);

    if (m['numDays'] is! int) {
      throw const CorruptPayloadException('Request numDays must be an integer');
    }
    if ((m['numDays'] as int) < 1) {
      throw const CorruptPayloadException('Request numDays must be at least 1');
    }

    if (m['numPeople'] is! int) {
      throw const CorruptPayloadException('Request numPeople must be an integer');
    }
    if ((m['numPeople'] as int) < 1) {
      throw const CorruptPayloadException('Request numPeople must be at least 1');
    }

    if (m['budgetVnd'] is! int) {
      throw const CorruptPayloadException('Request budgetVnd must be an integer');
    }
    if ((m['budgetVnd'] as int) < 0) {
      throw const CorruptPayloadException('Request budgetVnd cannot be negative');
    }

    if (m['preferences'] is! List) {
      throw const CorruptPayloadException('Request preferences must be a List');
    }
    for (final item in (m['preferences'] as List)) {
      if (item is! String) {
        throw const CorruptPayloadException('Each preference item must be a String');
      }
      validateUnicode(item);
    }

    if (m['priority'] is! String) {
      throw const CorruptPayloadException('Request priority must be a String');
    }
    validateUnicode(m['priority'] as String);
  }

  static void _validatePlanMap(Map<String, dynamic> m, {bool isLegacy = false}) {
    for (final k in _requiredPlanKeys) {
      if (isLegacy && k == 'budgetBreakdown') {
        continue;
      }
      if (!m.containsKey(k)) {
        throw CorruptPayloadException('Missing required plan key: $k');
      }
    }
    for (final k in m.keys) {
      if (!_allAllowedPlanKeys.contains(k)) {
        throw CorruptPayloadException('Unknown plan key: $k');
      }
    }

    if (m['winnerId'] is! String) {
      throw const CorruptPayloadException('Plan winnerId must be a String');
    }
    validateUnicode(m['winnerId'] as String);

    if (m['aiExplanation'] is! String) {
      throw const CorruptPayloadException('Plan aiExplanation must be a String');
    }
    validateUnicode(m['aiExplanation'] as String);

    if (m.containsKey('isFallback') && m['isFallback'] != null && m['isFallback'] is! bool) {
      throw const CorruptPayloadException('Plan isFallback must be a boolean');
    }

    if (m['dataSources'] is! Map) {
      throw const CorruptPayloadException('Plan dataSources must be a Map');
    }
    for (final entry in (m['dataSources'] as Map).entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const CorruptPayloadException('Plan dataSources keys and values must be Strings');
      }
      validateUnicode(entry.key as String);
      validateUnicode(entry.value as String);
    }

    if (m['assumptions'] is! List) {
      throw const CorruptPayloadException('Plan assumptions must be a List');
    }
    for (final item in (m['assumptions'] as List)) {
      if (item is! String) {
        throw const CorruptPayloadException('Plan assumption item must be a String');
      }
      validateUnicode(item);
    }

    if (m['budgetBreakdown'] != null) {
      if (m['budgetBreakdown'] is! Map) {
        throw const CorruptPayloadException('Plan budgetBreakdown must be a Map or null');
      }
      final bMap = m['budgetBreakdown'] as Map;
      for (final k in _requiredBudgetKeys) {
        if (!bMap.containsKey(k)) {
          throw CorruptPayloadException('Missing required budgetBreakdown key: $k');
        }
      }
      for (final k in bMap.keys) {
        if (!_requiredBudgetKeys.contains(k)) {
          throw CorruptPayloadException('Unknown budgetBreakdown key: $k');
        }
      }
      for (final k in _requiredBudgetKeys) {
        if (bMap[k] is! int) {
          throw CorruptPayloadException('budgetBreakdown $k must be an integer');
        }
      }
    }

    if (m['topDestinations'] is! List) {
      throw const CorruptPayloadException('Plan topDestinations must be a List');
    }
    for (final destItem in (m['topDestinations'] as List)) {
      if (destItem is! Map) {
        throw const CorruptPayloadException('topDestinations item must be a Map');
      }
      final dMap = destItem;
      for (final k in _requiredDestinationKeys) {
        if (!dMap.containsKey(k)) {
          throw CorruptPayloadException('Missing required destination key: $k');
        }
      }
      for (final k in dMap.keys) {
        if (!_requiredDestinationKeys.contains(k)) {
          throw CorruptPayloadException('Unknown destination key: $k');
        }
      }

      if (dMap['id'] is! String) throw const CorruptPayloadException('Destination id must be a String');
      validateUnicode(dMap['id'] as String);

      if (dMap['name'] is! String) throw const CorruptPayloadException('Destination name must be a String');
      validateUnicode(dMap['name'] as String);

      if (dMap['totalScore'] is! num || !(dMap['totalScore'] as num).isFinite) {
        throw const CorruptPayloadException('Destination totalScore must be a finite number');
      }

      if (dMap['estimatedCostVnd'] is! int) {
        throw const CorruptPayloadException('Destination estimatedCostVnd must be an integer');
      }

      if (dMap['weatherSource'] is! String) {
        throw const CorruptPayloadException('Destination weatherSource must be a String');
      }
      validateUnicode(dMap['weatherSource'] as String);

      if (dMap['avgTempMax'] is! num || !(dMap['avgTempMax'] as num).isFinite) {
        throw const CorruptPayloadException('Destination avgTempMax must be a finite number');
      }

      if (dMap['avgPrecipitation'] is! num || !(dMap['avgPrecipitation'] as num).isFinite) {
        throw const CorruptPayloadException('Destination avgPrecipitation must be a finite number');
      }

      if (dMap['region'] is! String) throw const CorruptPayloadException('Destination region must be a String');
      validateUnicode(dMap['region'] as String);

      if (dMap['latitude'] != null && (dMap['latitude'] is! num || !(dMap['latitude'] as num).isFinite)) {
        throw const CorruptPayloadException('Destination latitude must be a finite number or null');
      }

      if (dMap['longitude'] != null && (dMap['longitude'] is! num || !(dMap['longitude'] as num).isFinite)) {
        throw const CorruptPayloadException('Destination longitude must be a finite number or null');
      }

      if (dMap['normalizedScores'] is! Map) {
        throw const CorruptPayloadException('Destination normalizedScores must be a Map');
      }
      for (final entry in (dMap['normalizedScores'] as Map).entries) {
        if (entry.key is! String) throw const CorruptPayloadException('normalizedScores key must be String');
        validateUnicode(entry.key as String);
        if (entry.value is! num || !(entry.value as num).isFinite) {
          throw const CorruptPayloadException('normalizedScores value must be a finite number');
        }
      }

      if (dMap['scoreContributions'] is! Map) {
        throw const CorruptPayloadException('Destination scoreContributions must be a Map');
      }
      for (final entry in (dMap['scoreContributions'] as Map).entries) {
        if (entry.key is! String) throw const CorruptPayloadException('scoreContributions key must be String');
        validateUnicode(entry.key as String);
        if (entry.value is! num || !(entry.value as num).isFinite) {
          throw const CorruptPayloadException('scoreContributions value must be a finite number');
        }
      }
    }

    if (m['transportOptions'] is! List) {
      throw const CorruptPayloadException('Plan transportOptions must be a List');
    }
    for (final optItem in (m['transportOptions'] as List)) {
      if (optItem is! Map) {
        throw const CorruptPayloadException('transportOptions item must be a Map');
      }
      final tMap = optItem;
      for (final k in tMap.keys) {
        if (!_allAllowedTransportKeys.contains(k)) {
          throw CorruptPayloadException('Unknown transportOption key: $k');
        }
      }

      if (!tMap.containsKey('paretoOptimal') && !tMap.containsKey('isParetoOptimal')) {
        throw const CorruptPayloadException(
          'transportOption must contain at least paretoOptimal or isParetoOptimal',
        );
      }
      if (tMap.containsKey('paretoOptimal') && tMap['paretoOptimal'] is! bool) {
        throw const CorruptPayloadException('transportOption paretoOptimal must be a boolean');
      }
      if (tMap.containsKey('isParetoOptimal') && tMap['isParetoOptimal'] is! bool) {
        throw const CorruptPayloadException('transportOption isParetoOptimal must be a boolean');
      }

      const baseReq = [
        'mode',
        'displayName',
        'priceTotalVnd',
        'durationHours',
        'comfortScore',
        'tradeoffType',
        'recommendationReason'
      ];
      for (final k in baseReq) {
        if (!tMap.containsKey(k)) {
          throw CorruptPayloadException('Missing required transportOption key: $k');
        }
      }

      if (tMap['mode'] is! String) throw const CorruptPayloadException('Transport mode must be a String');
      validateUnicode(tMap['mode'] as String);

      if (tMap['displayName'] is! String) throw const CorruptPayloadException('Transport displayName must be a String');
      validateUnicode(tMap['displayName'] as String);

      if (tMap['priceTotalVnd'] is! int) {
        throw const CorruptPayloadException('Transport priceTotalVnd must be an integer');
      }

      if (tMap['durationHours'] is! num || !(tMap['durationHours'] as num).isFinite) {
        throw const CorruptPayloadException('Transport durationHours must be a finite number');
      }

      if (tMap['comfortScore'] is! num || !(tMap['comfortScore'] as num).isFinite) {
        throw const CorruptPayloadException('Transport comfortScore must be a finite number');
      }

      if (tMap['tradeoffType'] is! String) throw const CorruptPayloadException('Transport tradeoffType must be a String');
      validateUnicode(tMap['tradeoffType'] as String);

      if (tMap['recommendationReason'] is! String) {
        throw const CorruptPayloadException('Transport recommendationReason must be a String');
      }
      validateUnicode(tMap['recommendationReason'] as String);
    }

    if (m['itineraryDays'] is! List) {
      throw const CorruptPayloadException('Plan itineraryDays must be a List');
    }
    for (final dayItem in (m['itineraryDays'] as List)) {
      if (dayItem is! Map) {
        throw const CorruptPayloadException('itineraryDays item must be a Map');
      }
      final dayMap = dayItem;
      for (final k in _requiredDayKeys) {
        if (!dayMap.containsKey(k)) {
          throw CorruptPayloadException('Missing required itineraryDay key: $k');
        }
      }
      for (final k in dayMap.keys) {
        if (!_requiredDayKeys.contains(k)) {
          throw CorruptPayloadException('Unknown itineraryDay key: $k');
        }
      }

      if (dayMap['day'] is! int) throw const CorruptPayloadException('itineraryDay day must be an integer');
      if (dayMap['title'] is! String) throw const CorruptPayloadException('itineraryDay title must be a String');
      validateUnicode(dayMap['title'] as String);

      if (dayMap['activities'] is! List) throw const CorruptPayloadException('itineraryDay activities must be a List');
      for (final actItem in (dayMap['activities'] as List)) {
        if (actItem is! Map) throw const CorruptPayloadException('activity must be a Map');
        final actMap = actItem;
        for (final k in _requiredActivityKeys) {
          if (!actMap.containsKey(k)) throw CorruptPayloadException('Missing required activity key: $k');
        }
        for (final k in actMap.keys) {
          if (!_requiredActivityKeys.contains(k)) throw CorruptPayloadException('Unknown activity key: $k');
        }

        if (actMap['time'] is! String) throw const CorruptPayloadException('Activity time must be a String');
        validateUnicode(actMap['time'] as String);

        if (actMap['title'] is! String) throw const CorruptPayloadException('Activity title must be a String');
        validateUnicode(actMap['title'] as String);

        if (actMap['costVnd'] is! int) throw const CorruptPayloadException('Activity costVnd must be an integer');

        if (actMap['durationHours'] is! num || !(actMap['durationHours'] as num).isFinite) {
          throw const CorruptPayloadException('Activity durationHours must be a finite number');
        }
      }
    }
  }

  static PlanTripRequest deepFreezeRequest(PlanTripRequest req) {
    return PlanTripRequest(
      origin: req.origin,
      numDays: req.numDays,
      numPeople: req.numPeople,
      budgetVnd: req.budgetVnd,
      preferences: List<String>.unmodifiable(req.preferences),
      priority: req.priority,
    );
  }

  static PlanTripResponse deepFreezePlan(PlanTripResponse p) {
    final frozenDestinations = p.topDestinations.map((d) {
      return DestinationCard(
        id: d.id,
        name: d.name,
        totalScore: d.totalScore,
        normalizedScores: Map<String, double>.unmodifiable(d.normalizedScores),
        scoreContributions: Map<String, double>.unmodifiable(d.scoreContributions),
        estimatedCostVnd: d.estimatedCostVnd,
        weatherSource: d.weatherSource,
        avgTempMax: d.avgTempMax,
        avgPrecipitation: d.avgPrecipitation,
        latitude: d.latitude,
        longitude: d.longitude,
        region: d.region,
      );
    }).toList();

    final frozenItinerary = p.itineraryDays.map((day) {
      return ItineraryDay(
        day: day.day,
        title: day.title,
        activities: List<Activity>.unmodifiable(day.activities),
      );
    }).toList();

    return PlanTripResponse(
      winnerId: p.winnerId,
      topDestinations: List<DestinationCard>.unmodifiable(frozenDestinations),
      transportOptions: List<TransportOption>.unmodifiable(p.transportOptions),
      itineraryDays: List<ItineraryDay>.unmodifiable(frozenItinerary),
      budgetBreakdown: p.budgetBreakdown,
      aiExplanation: p.aiExplanation,
      dataSources: Map<String, String>.unmodifiable(p.dataSources),
      assumptions: List<String>.unmodifiable(p.assumptions),
    );
  }

  static void validateUnicode(String s) {
    if (s.contains('\u0000')) {
      throw const CorruptPayloadException('String contains null character (U+0000)');
    }
    final codeUnits = s.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      final cu = codeUnits[i];
      if (cu >= 0xD800 && cu <= 0xDBFF) {
        if (i + 1 >= codeUnits.length ||
            codeUnits[i + 1] < 0xDC00 ||
            codeUnits[i + 1] > 0xDFFF) {
          throw CorruptPayloadException('Unpaired high surrogate at index $i');
        }
        i++; // valid surrogate pair
      } else if (cu >= 0xDC00 && cu <= 0xDFFF) {
        throw CorruptPayloadException('Unpaired low surrogate at index $i');
      }
    }
  }

  static String _canonicalize(dynamic obj) {
    if (obj == null) return 'null';
    if (obj is bool) return obj ? 'true' : 'false';
    if (obj is int) return obj.toString();
    if (obj is double) {
      if (!obj.isFinite) {
        throw CorruptPayloadException('Non-finite double: $obj');
      }
      final normalized = (obj == 0.0 && obj.isNegative) ? 0.0 : obj;
      return jsonEncode(normalized);
    }
    if (obj is String) {
      validateUnicode(obj);
      return jsonEncode(obj);
    }
    if (obj is List) {
      final buffer = StringBuffer('[');
      for (var i = 0; i < obj.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write(_canonicalize(obj[i]));
      }
      buffer.write(']');
      return buffer.toString();
    }
    if (obj is Map) {
      final buffer = StringBuffer('{');
      final keys = obj.keys.map((k) {
        if (k is! String) {
          throw CorruptPayloadException('Map key is not a String: $k');
        }
        return k;
      }).toList();

      // String.compareTo in Dart performs UTF-16 code-unit ordinal ordering
      keys.sort((a, b) => a.compareTo(b));

      for (var i = 0; i < keys.length; i++) {
        if (i > 0) buffer.write(',');
        final k = keys[i];
        validateUnicode(k);
        buffer.write(jsonEncode(k));
        buffer.write(':');
        buffer.write(_canonicalize(obj[k]));
      }
      buffer.write('}');
      return buffer.toString();
    }
    throw CorruptPayloadException(
      'Unsupported data type in canonical JSON: ${obj.runtimeType}',
    );
  }
}
