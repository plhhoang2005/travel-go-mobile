import 'dart:convert';

const maxVisitReleaseBytes = 2 * 1024 * 1024;
const maxVisitManifestBytes = 32 * 1024;
const _maxSafeInteger = 9007199254740991;

/// A bounded error code, suitable for UI. Never contains a remote body or URL.
class VisitDataException implements Exception {
  final String code;
  const VisitDataException(this.code);
  @override
  String toString() => 'VisitDataException($code)';
}

class VisitSource {
  final String id, title, publisher, url;
  final DateTime? publishedAt, effectiveFrom, effectiveTo;
  const VisitSource._(
    this.id,
    this.title,
    this.publisher,
    this.url,
    this.publishedAt,
    this.effectiveFrom,
    this.effectiveTo,
  );
}

class VisitPackage {
  final String id, label, scope;
  final List<String> included, excluded, conditions, sourceIds;
  VisitPackage._(
    this.id,
    this.label,
    this.scope,
    List<String> included,
    List<String> excluded,
    List<String> conditions,
    List<String> sourceIds,
  ) : included = List.unmodifiable(included),
      excluded = List.unmodifiable(excluded),
      conditions = List.unmodifiable(conditions),
      sourceIds = List.unmodifiable(sourceIds);
}

class VisitEvidence {
  final List<String> sourceIds, conditions, unresolvedIssues;
  final DateTime? checkedAt;
  final String reviewState;
  VisitEvidence._(
    List<String> sourceIds,
    this.checkedAt,
    this.reviewState,
    List<String> conditions,
    List<String> unresolvedIssues,
  ) : sourceIds = List.unmodifiable(sourceIds),
      conditions = List.unmodifiable(conditions),
      unresolvedIssues = List.unmodifiable(unresolvedIssues);
  bool get isReviewed => reviewState == 'reviewed';

  /// Source verification age, independent of the time the app downloaded it.
  bool needsReview(DateTime now) =>
      checkedAt != null && _vietnamDate(now).difference(checkedAt!).inDays > 30;
}

class VisitPriceOption {
  final String id, label, audience, currency, unit;
  final int? amountVnd;
  final String? packageId, routeId;
  final List<String> included, excluded, conditions;
  VisitPriceOption._(
    this.id,
    this.label,
    this.audience,
    this.amountVnd,
    this.currency,
    this.unit,
    this.packageId,
    this.routeId,
    List<String> included,
    List<String> excluded,
    List<String> conditions,
  ) : included = List.unmodifiable(included),
      excluded = List.unmodifiable(excluded),
      conditions = List.unmodifiable(conditions);
}

class VisitPrice {
  final String status;
  final List<VisitPriceOption> options;
  final VisitEvidence evidence;
  VisitPrice._(this.status, List<VisitPriceOption> options, this.evidence)
    : options = List.unmodifiable(options);
}

class VisitScheduleRule {
  final String label;
  final List<int> weekdays;
  final String? seasonStart, seasonEnd;
  final DateTime? effectiveFrom, effectiveTo;
  final int startMinutes, endMinutes, endDayOffset;
  final int? admissionCutoffMinutes, lastReturnMinutes;
  VisitScheduleRule._(
    this.label,
    List<int> weekdays,
    this.seasonStart,
    this.seasonEnd,
    this.effectiveFrom,
    this.effectiveTo,
    this.startMinutes,
    this.endMinutes,
    this.endDayOffset,
    this.admissionCutoffMinutes,
    this.lastReturnMinutes,
  ) : weekdays = List.unmodifiable(weekdays);

  /// Matches a supplied Vietnam calendar date, not a claim of live opening.
  bool appliesOn(DateTime localDate) {
    final date = DateTime.utc(localDate.year, localDate.month, localDate.day);
    if (!weekdays.contains(date.weekday) ||
        (effectiveFrom != null && date.isBefore(effectiveFrom!)) ||
        (effectiveTo != null && date.isAfter(effectiveTo!))) {
      return false;
    }
    if (seasonStart == null) return true;
    final day =
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final start = seasonStart!;
    final end = seasonEnd!;
    return start.compareTo(end) <= 0
        ? day.compareTo(start) >= 0 && day.compareTo(end) <= 0
        : day.compareTo(start) >= 0 || day.compareTo(end) <= 0;
  }
}

class VisitHours {
  final String status;
  final List<VisitScheduleRule> rules;
  final List<String> notes;
  final VisitEvidence evidence;
  VisitHours._(
    this.status,
    List<VisitScheduleRule> rules,
    List<String> notes,
    this.evidence,
  ) : rules = List.unmodifiable(rules),
      notes = List.unmodifiable(notes);
}

class PlaceVisitDetails {
  final String placeId, visitScopeLabel;
  final VisitPrice price;
  final VisitHours hours;
  final List<String> notes;
  PlaceVisitDetails._(
    this.placeId,
    this.visitScopeLabel,
    this.price,
    this.hours,
    List<String> notes,
  ) : notes = List.unmodifiable(notes);
  bool get isComplete => price.evidence.isReviewed && hours.evidence.isReviewed;
}

class VisitCatalogue {
  final int version;
  final DateTime publishedAt;
  final String catalogueSha256;
  final Map<String, VisitSource> sources;
  final Map<String, VisitPackage> packages;
  final Map<String, PlaceVisitDetails> places;
  final String bindingKind;

  VisitCatalogue._(
    this.version,
    this.publishedAt,
    this.catalogueSha256,
    Map<String, VisitSource> sources,
    Map<String, VisitPackage> packages,
    Map<String, PlaceVisitDetails> places, {
    this.bindingKind = 'catalogue_v1',
  }) : sources = Map.unmodifiable(sources),
      packages = Map.unmodifiable(packages),
      places = Map.unmodifiable(places);
  bool get isComplete => places.values.every((place) => place.isComplete);

  factory VisitCatalogue.fromPublicProjection({
    required int version,
    required DateTime publishedAt,
    required String releaseSha256,
    required Map<String, Object?> data,
    required Set<String> expectedPlaceIds,
    required DateTime now,
  }) {
    if (publishedAt.isAfter(now.toUtc().add(const Duration(minutes: 5)))) {
      _fail('future_publication');
    }

    final rawSources = data['sources'];
    final sources = <String, VisitSource>{};
    for (final source in _objects(rawSources)) {
      final id = _text(source['id']);
      if (sources.containsKey(id)) _fail('duplicate_source');
      final url = _text(source['url']);
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        _fail('source_url');
      }
      final from = _optionalDate(source['effectiveFrom']);
      final to = _optionalDate(source['effectiveTo']);
      _dateRange(from, to);
      sources[id] = VisitSource._(
        id,
        _text(source['title']),
        _text(source['publisher']),
        url,
        _optionalDateOrTimestamp(source['publishedAt'] ?? source['checkedAt']),
        from,
        to,
      );
    }

    final rawPackages = data['packages'];
    final packages = <String, VisitPackage>{};
    for (final package in _objects(rawPackages)) {
      final id = _text(package['id']);
      if (packages.containsKey(id)) _fail('duplicate_package');
      final refs = _references(package['sourceIds'], sources.keys.toSet());
      if (refs.isEmpty) _fail('package_evidence');
      packages[id] = VisitPackage._(
        id,
        _text(package['label']),
        _text(package['scope']),
        _strings(package['included']),
        _strings(package['excluded']),
        _strings(package['conditions']),
        refs,
      );
    }

    final rawPlaces = data['places'];
    final places = <String, PlaceVisitDetails>{};
    for (final place in _objects(rawPlaces)) {
      final id = _text(place['placeId'] ?? place['id']);
      if (!expectedPlaceIds.contains(id) || places.containsKey(id)) {
        _fail('place_set');
      }

      final priceMap = place['price'] != null
          ? _map(place['price'])
          : {
              'status': 'unverified',
              'options': [],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': [],
                'conditions': ['Chưa xác minh'],
                'unresolvedIssues': ['Chưa có thông tin giá vé'],
              },
            };

      final hoursMap = place['hours'] != null
          ? _map(place['hours'])
          : {
              'status': 'unverified',
              'rules': [],
              'notes': ['Chưa xác minh giờ mở cửa'],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': [],
                'conditions': ['Chưa xác minh'],
                'unresolvedIssues': ['Chưa có thông tin giờ'],
              },
            };

      places[id] = PlaceVisitDetails._(
        id,
        _text(place['visitScopeLabel'] ?? 'Chưa xác minh'),
        _price(
          priceMap,
          sources.keys.toSet(),
          packages.keys.toSet(),
          now,
        ),
        _hours(hoursMap, sources.keys.toSet(), now),
        _strings(place['notes'] ?? const []),
      );
    }

    for (final expectedId in expectedPlaceIds) {
      if (!places.containsKey(expectedId)) {
        places[expectedId] = PlaceVisitDetails._(
          expectedId,
          'Chưa xác minh',
          _price(
            {
              'status': 'unverified',
              'options': [],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': [],
                'conditions': ['Chưa xác minh'],
                'unresolvedIssues': ['Chưa có thông tin giá vé'],
              },
            },
            sources.keys.toSet(),
            packages.keys.toSet(),
            now,
          ),
          _hours(
            {
              'status': 'unverified',
              'rules': [],
              'notes': ['Chưa xác minh giờ mở cửa'],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': [],
                'conditions': ['Chưa xác minh'],
                'unresolvedIssues': ['Chưa có thông tin giờ'],
              },
            },
            sources.keys.toSet(),
            now,
          ),
          const [],
        );
      }
    }

    if (places.length != expectedPlaceIds.length) {
      _fail('place_set');
    }

    return VisitCatalogue._(
      version,
      publishedAt,
      _hash(releaseSha256),
      sources,
      packages,
      places,
      bindingKind: 'release_v2',
    );
  }
}

class VisitManifest {
  final int version, byteLength;
  final String objectPath, sha256, catalogueSha256;
  final DateTime publishedAt;
  const VisitManifest._(
    this.version,
    this.objectPath,
    this.sha256,
    this.byteLength,
    this.publishedAt,
    this.catalogueSha256,
  );
}

VisitManifest parseVisitManifest(String json) {
  final data = _decode(json, maxVisitManifestBytes);
  _schema(data);
  final version = _integer(data['version'], 1, _maxSafeInteger);
  final path = _text(data['objectPath']);
  if (path != 'releases/$version.json') _fail('object_path');
  return VisitManifest._(
    version,
    path,
    _hash(data['sha256']),
    _integer(data['byteLength'], 1, maxVisitReleaseBytes),
    _timestamp(data['publishedAt']),
    _hash(data['catalogueSha256']),
  );
}

VisitCatalogue parseVisitCatalogue(
  String json, {
  required Set<String> expectedPlaceIds,
  required String expectedCatalogueSha256,
  required DateTime now,
  bool requireComplete = false,
}) {
  final data = _decode(json, maxVisitReleaseBytes);
  _schema(data);
  if (data['timezone'] != 'Asia/Ho_Chi_Minh') _fail('timezone');
  final version = _integer(data['version'], 1, _maxSafeInteger);
  final hash = _hash(data['catalogueSha256']);
  if (hash != _hash(expectedCatalogueSha256)) _fail('catalogue_hash');
  final published = _timestamp(data['publishedAt']);
  if (published.isAfter(now.toUtc().add(const Duration(minutes: 5)))) {
    _fail('future_publication');
  }
  final sources = <String, VisitSource>{};
  for (final source in _objects(data['sources'])) {
    final id = _text(source['id']);
    if (sources.containsKey(id)) _fail('duplicate_source');
    final url = _text(source['url']);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _fail('source_url');
    }
    final from = _optionalDate(source['effectiveFrom']);
    final to = _optionalDate(source['effectiveTo']);
    _dateRange(from, to);
    sources[id] = VisitSource._(
      id,
      _text(source['title']),
      _text(source['publisher']),
      url,
      _optionalDate(source['publishedAt']),
      from,
      to,
    );
  }
  final packages = <String, VisitPackage>{};
  for (final package in _objects(data['packages'])) {
    final id = _text(package['id']);
    if (packages.containsKey(id)) _fail('duplicate_package');
    final refs = _references(package['sourceIds'], sources.keys.toSet());
    if (refs.isEmpty) _fail('package_evidence');
    packages[id] = VisitPackage._(
      id,
      _text(package['label']),
      _text(package['scope']),
      _strings(package['included']),
      _strings(package['excluded']),
      _strings(package['conditions']),
      refs,
    );
  }
  final places = <String, PlaceVisitDetails>{};
  for (final place in _objects(data['places'])) {
    final id = _text(place['placeId']);
    if (!expectedPlaceIds.contains(id) || places.containsKey(id)) {
      _fail('place_set');
    }
    places[id] = PlaceVisitDetails._(
      id,
      _text(place['visitScopeLabel']),
      _price(
        _map(place['price']),
        sources.keys.toSet(),
        packages.keys.toSet(),
        now,
      ),
      _hours(_map(place['hours']), sources.keys.toSet(), now),
      _strings(place['notes']),
    );
  }
  if (expectedPlaceIds.isEmpty || places.length != expectedPlaceIds.length) {
    _fail('place_set');
  }
  final result = VisitCatalogue._(
    version,
    published,
    hash,
    sources,
    packages,
    places,
  );
  if (requireComplete && !result.isComplete) _fail('incomplete');
  return result;
}

VisitPrice _price(
  Map<String, dynamic> data,
  Set<String> sources,
  Set<String> packages,
  DateTime now,
) {
  final status = _choice(data['status'], {
    'priced',
    'free',
    'bundled',
    'variable',
    'unverified',
  });
  final evidence = _evidence(_map(data['evidence']), sources, now, status);
  final options = <VisitPriceOption>[];
  final ids = <String>{};
  for (final option in _objects(data['options'])) {
    final id = _text(option['id']);
    if (!ids.add(id)) _fail('duplicate_option');
    final amount = option['amountVnd'] == null
        ? null
        : _integer(option['amountVnd'], 0, _maxSafeInteger);
    if (option['currency'] != 'VND') _fail('currency');
    if ((status == 'free' && amount != 0) ||
        (status == 'priced' && amount == null) ||
        (status == 'unverified' && amount != null)) {
      _fail('price_amount');
    }
    final packageId = _optionalText(option['packageId']);
    if (packageId != null && !packages.contains(packageId)) {
      _fail('package_reference');
    }
    if (status == 'bundled' && packageId == null) _fail('package_reference');
    options.add(
      VisitPriceOption._(
        id,
        _text(option['label']),
        _text(option['audience']),
        amount,
        'VND',
        _text(option['unit']),
        packageId,
        _optionalText(option['routeId']),
        _strings(option['included']),
        _strings(option['excluded']),
        _strings(option['conditions']),
      ),
    );
  }
  if ({'priced', 'free', 'bundled'}.contains(status) && options.isEmpty) {
    _fail('price_options');
  }
  if (status == 'priced' &&
      !options.any((option) => (option.amountVnd ?? 0) > 0)) {
    _fail('price_amount');
  }
  if (status == 'variable' &&
      evidence.conditions.isEmpty &&
      !options.any((option) => option.conditions.isNotEmpty)) {
    _fail('variable_conditions');
  }
  return VisitPrice._(status, options, evidence);
}

VisitHours _hours(
  Map<String, dynamic> data,
  Set<String> sources,
  DateTime now,
) {
  final status = _choice(data['status'], {
    'scheduled',
    'seasonal',
    'event_based',
    'no_fixed_hours',
    'temporarily_closed',
    'unverified',
  });
  final evidence = _evidence(_map(data['evidence']), sources, now, status);
  final notes = _strings(data['notes']);
  final rules = _objects(data['rules']).map(_rule).toList();
  if ({'scheduled', 'seasonal'}.contains(status) && rules.isEmpty) {
    _fail('hours_rules');
  }
  if ({'no_fixed_hours', 'temporarily_closed', 'unverified'}.contains(status) &&
      rules.isNotEmpty) {
    _fail('hours_rules');
  }
  if ({
        'no_fixed_hours',
        'temporarily_closed',
        'event_based',
      }.contains(status) &&
      notes.isEmpty &&
      evidence.conditions.isEmpty) {
    _fail('hours_conditions');
  }
  if (status == 'seasonal' && rules.any((rule) => rule.seasonStart == null)) {
    _fail('season');
  }
  return VisitHours._(status, rules, notes, evidence);
}

VisitScheduleRule _rule(Map<String, dynamic> data) {
  final weekdays = _list(data['weekdays'])
      .map((d) => _integer(d, 1, 7))
      .toList();
  if (weekdays.isEmpty || weekdays.toSet().length != weekdays.length) {
    _fail('weekdays');
  }
  final start = _integer(data['startMinutes'], 0, 1439);
  final end = _integer(data['endMinutes'], 0, 1439);
  final offset = _integer(data['endDayOffset'], 0, 1);
  final duration = end + offset * 1440 - start;
  if (duration <= 0 || duration > 1440) _fail('hours_range');
  final seasonStart = _season(data['seasonStart']);
  final seasonEnd = _season(data['seasonEnd']);
  if ((seasonStart == null) != (seasonEnd == null)) _fail('season');
  final from = _optionalDate(data['effectiveFrom']);
  final to = _optionalDate(data['effectiveTo']);
  _dateRange(from, to);
  return VisitScheduleRule._(
    _text(data['label']),
    weekdays,
    seasonStart,
    seasonEnd,
    from,
    to,
    start,
    end,
    offset,
    _optionalMinute(data['admissionCutoffMinutes']),
    _optionalMinute(data['lastReturnMinutes']),
  );
}

VisitEvidence _evidence(
  Map<String, dynamic> data,
  Set<String> sources,
  DateTime now,
  String status,
) {
  final state = _choice(data['reviewState'], {'unverified', 'reviewed'});
  final refs = _references(data['sourceIds'], sources);
  final checked = _optionalDate(data['checkedAt']);
  final conditions = _strings(data['conditions']);
  final issues = _strings(data['unresolvedIssues']);
  if (checked != null && checked.isAfter(_vietnamDate(now))) {
    _fail('checked_at');
  }
  if (state == 'reviewed' &&
      (refs.isEmpty ||
          checked == null ||
          issues.isNotEmpty ||
          status == 'unverified')) {
    _fail('evidence');
  }
  return VisitEvidence._(refs, checked, state, conditions, issues);
}

Never _fail(String code) => throw VisitDataException(code);

Map<String, dynamic> _decode(String json, int maxBytes) {
  if (json.startsWith('\uFEFF') || utf8.encode(json).length > maxBytes) {
    _fail('size_or_encoding');
  }
  try {
    return _map(jsonDecode(json));
  } on FormatException {
    _fail('json');
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : _fail('object');
List<Object?> _list(Object? value) => value is List ? value : _fail('list');
List<Map<String, dynamic>> _objects(Object? value) =>
    _list(value).map(_map).toList();
String _text(Object? value) =>
    value is String && value.trim().isNotEmpty && value.length <= 4096
    ? value
    : _fail('text');
String? _optionalText(Object? value) => value == null ? null : _text(value);
List<String> _strings(Object? value) => _list(value).map(_text).toList();
List<String> _references(Object? value, Set<String> known) {
  final refs = _strings(value);
  if (refs.toSet().length != refs.length ||
      refs.any((id) => !known.contains(id))) {
    _fail('source_reference');
  }
  return refs;
}

int _integer(Object? value, int min, int max) =>
    value is int && value >= min && value <= max ? value : _fail('integer');
int? _optionalMinute(Object? value) =>
    value == null ? null : _integer(value, 0, 1439);
String _choice(Object? value, Set<String> choices) =>
    value is String && choices.contains(value) ? value : _fail('status');
String _hash(Object? value) =>
    value is String && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)
    ? value.toLowerCase()
    : _fail('hash');
void _schema(Map<String, dynamic> data) {
  if (data['schemaVersion'] is! int || data['schemaVersion'] != 1) {
    _fail('schema');
  }
}

DateTime _date(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    _fail('date');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    _fail('date');
  }
  return parsed;
}

DateTime? _optionalDate(Object? value) => value == null ? null : _date(value);
DateTime? _optionalDateOrTimestamp(Object? value) {
  if (value == null) return null;
  if (value is String) {
    if (value.contains('T')) {
      return _date(value.substring(0, 10));
    }
    return _date(value);
  }
  _fail('date');
}
DateTime _timestamp(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
          .hasMatch(value)) {
    _fail('timestamp');
  }
  _date(value.substring(0, 10));
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.hour != int.parse(value.substring(11, 13)) ||
      parsed.minute != int.parse(value.substring(14, 16)) ||
      parsed.second != int.parse(value.substring(17, 19))) {
    _fail('timestamp');
  }
  return parsed;
}

DateTime _vietnamDate(DateTime now) {
  final local = now.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(local.year, local.month, local.day);
}

void _dateRange(DateTime? from, DateTime? to) {
  if (from != null && to != null && from.isAfter(to)) _fail('date_range');
}

String? _season(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^\d{2}-\d{2}$').hasMatch(value)) {
    _fail('season');
  }
  _date('2000-$value');
  return value;
}
