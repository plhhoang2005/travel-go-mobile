import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../trip_planner/models/editable_trip_document.dart';
import 'trip_payload_codec.dart';

class EditableCodecException implements Exception {
  final String code;
  final String path;
  const EditableCodecException(this.code, [this.path = r'$']);
  @override
  String toString() => 'EditableCodecException($code, $path)';
}

/// Separate contract: never relax the frozen V1 reader to accept editable data.
class EditableTripCodec {
  static const maxMoney = 9007199254740991;
  static const maxCount = 2147483647;
  static const maxBytes = 1024 * 1024;
  static const destinations = <String>{
    'ha-noi',
    'ha-long',
    'sa-pa',
    'ninh-binh',
    'hue',
    'da-nang',
    'hoi-an',
    'nha-trang',
    'da-lat',
    'ho-chi-minh',
    'phu-quoc',
    'can-tho',
  };
  static bool isValidDestinationId(String id) =>
      _destinationIdRegex.hasMatch(id);
  static const categories = <String>{
    'transport',
    'accommodation',
    'food',
    'attractions',
    'shopping',
    'other',
  };
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _hex = RegExp(r'^[0-9a-f]{64}$');

  static Object? parseStrict(String text, {int limit = maxBytes}) {
    if (text.length > limit || utf8.encode(text).length > limit) {
      throw const EditableCodecException('invalid_input', 'size');
    }
    try {
      return _StrictEditableJson(text).parse();
    } on EditableCodecException {
      rethrow;
    } on Object {
      throw const EditableCodecException('invalid_input');
    }
  }

  static EditableTripDocumentV2 decode(String text) {
    try {
      final raw = _object(parseStrict(text));
      if (raw['schemaVersion'] != 2) {
        throw const EditableCodecException('unsupported_schema');
      }
      _validate(raw);
      return EditableTripDocumentV2.fromJson(raw);
    } on EditableCodecException {
      rethrow;
    } on Object {
      throw const EditableCodecException('invalid_input');
    }
  }

  static void validateDocument(EditableTripDocumentV2 document) {
    try {
      _validate(document.toJson());
    } on EditableCodecException {
      rethrow;
    } on Object {
      throw const EditableCodecException('invalid_input');
    }
  }

  static String encode(EditableTripDocumentV2 document) {
    validateDocument(document);
    final text = canonicalJson(document.toJson());
    if (utf8.encode(text).length > maxBytes) {
      throw const EditableCodecException('invalid_input', 'size');
    }
    return text;
  }

  static String digest(EditableTripDocumentV2 document) =>
      digestText(encode(document));
  static String digestText(String text) =>
      sha256.convert(utf8.encode(text)).toString();
  static String canonicalJson(Object? value) => jsonEncode(_sorted(value));
  static Object? _sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _sorted(value[key])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  static Map<String, Object?> _object(Object? v) {
    if (v is! Map<String, Object?>) {
      throw const EditableCodecException('invalid_input', 'object');
    }
    return v;
  }

  static void _keys(Map<String, Object?> m, String names) {
    final keys = names.split(' ');
    if (m.length != keys.length || m.keys.any((k) => !keys.contains(k))) {
      throw const EditableCodecException('invalid_input', 'keys');
    }
  }

  static void _text(
    Object? v,
    int max, {
    bool blank = false,
    bool nullable = false,
  }) {
    if (nullable && v == null) return;
    if (v is! String || v.runes.length > max || (!blank && v.trim().isEmpty)) {
      throw const EditableCodecException('invalid_input', 'text');
    }
    TripPayloadCodec.validateUnicode(v);
  }

  static void _integer(Object? v, int min, int max, {bool nullable = false}) {
    if (nullable && v == null) return;
    if (v is! int || v < min || v > max) {
      throw const EditableCodecException('invalid_input', 'integer');
    }
  }

  static void _enum(Object? v, Set<String> values, {bool nullable = false}) {
    if (nullable && v == null) return;
    if (v is! String || !values.contains(v)) {
      throw const EditableCodecException('invalid_input', 'enum');
    }
  }

  static void _id(Object? v, {bool nullable = false}) {
    if (nullable && v == null) return;
    if (v is! String || !_uuid.hasMatch(v)) {
      throw const EditableCodecException('invalid_input', 'id');
    }
  }

  static void _digest(Object? v, {bool nullable = false}) {
    if (nullable && v == null) return;
    if (v is! String || !_hex.hasMatch(v)) {
      throw const EditableCodecException('invalid_input', 'digest');
    }
  }

  static void _date(Object? v, {bool nullable = false}) {
    if (nullable && v == null) return;
    if (v is! String) {
      throw const EditableCodecException('invalid_input', 'date');
    }
    TripPayloadCodec.validateCalendarDate(v);
  }

  static List<Object?> _list(Object? value, int max) {
    if (value is! List<Object?> || value.length > max) {
      throw const EditableCodecException('invalid_input', 'list');
    }
    return value;
  }

  static void _provenance(Object? value) {
    final p = _object(value);
    _keys(p, 'quality sourceRefs observedAt');
    _enum(p['quality'], {'user_provided', 'estimated', 'unknown'});
    for (final ref in _list(p['sourceRefs'], 1000)) {
      _text(ref, 128);
    }
    final refs = p['sourceRefs'] as List;
    if (refs.toSet().length != refs.length) {
      throw const EditableCodecException('invalid_input', 'sourceRefs');
    }
    final time = p['observedAt'];
    if (time != null) {
      if (time is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
              .hasMatch(time)) {
        throw const EditableCodecException('invalid_input', 'observedAt');
      }
      _date(time.substring(0, 10));
      final parsed = DateTime.tryParse(time);
      if (parsed == null ||
          parsed.toIso8601String().substring(0, 19) != time.substring(0, 19)) {
        throw const EditableCodecException('invalid_input', 'observedAt');
      }
    }
  }

  static final _destinationIdRegex = RegExp(r'^[a-z0-9][a-z0-9/-]{0,119}$');

  static void _destinationId(Object? value, {bool nullable = false}) {
    if (value == null) {
      if (nullable) return;
      throw const EditableCodecException('invalid_input', r'$.input.destinationId');
    }
    if (value is! String || !_destinationIdRegex.hasMatch(value)) {
      throw const EditableCodecException('invalid_input', r'$.input.destinationId');
    }
  }

  static void _validate(Map<String, Object?> m) {
    _keys(
      m,
      'schemaVersion input days items estimates actualExpenses exceptions source',
    );
    if (m['schemaVersion'] != 2) {
      throw const EditableCodecException('unsupported_schema');
    }
    final input = _object(m['input']);
    _keys(
      input,
      'title destinationId destinationName startDate endDate timezone origin travelerCount totalBudgetVnd interests priority',
    );
    _text(input['title'], 200, blank: true);
    _text(input['origin'], 200, blank: true);
    final destId = input['destinationId'];
    if (destId != null) {
      _destinationId(destId);
      final destName = input['destinationName'];
      if (destName == null || destName is! String || destName.trim().isEmpty || destName.length > 180) {
        throw const EditableCodecException('invalid_input', r'$.input.destinationName');
      }
    } else {
      _text(input['destinationName'], 180, nullable: true);
    }
    _date(input['startDate'], nullable: true);
    _date(input['endDate'], nullable: true);
    _enum(input['timezone'], {'Asia/Ho_Chi_Minh'});
    _integer(input['travelerCount'], 1, maxCount);
    _integer(input['totalBudgetVnd'], 0, maxMoney);
    _enum(input['priority'], {
      'cheapest',
      'fastest',
      'balanced',
      'comfortable',
    });
    for (final interest in _list(input['interests'], 20)) {
      _text(interest, 80);
    }
    final days = _list(m['days'], 366);
    if (days.isEmpty) {
      throw const EditableCodecException('invalid_input', 'days');
    }
    final dayIds = <String>{};
    for (var index = 0; index < days.length; index++) {
      final day = _object(days[index]);
      _keys(day, 'id ordinal date notes');
      _id(day['id']);
      _integer(day['ordinal'], index + 1, index + 1);
      _date(day['date'], nullable: true);
      _text(day['notes'], 2000, blank: true);
      if (!dayIds.add(day['id'] as String)) {
        throw const EditableCodecException('invalid_input', 'duplicate day');
      }
    }
    final itemIds = <String>{};
    final positions = <String, List<int>>{};
    for (final value in _list(m['items'], 1000)) {
      final item = _object(value);
      _keys(
        item,
        'id dayId position title placeId startMinute endMinute notes provenance',
      );
      _id(item['id']);
      _id(item['dayId']);
      _integer(item['position'], 0, 999);
      _text(item['title'], 200);
      _text(item['placeId'], 128, nullable: true);
      _integer(item['startMinute'], 0, 1439, nullable: true);
      _integer(item['endMinute'], 0, 1439, nullable: true);
      _text(item['notes'], 2000, blank: true);
      _provenance(item['provenance']);
      if (!dayIds.contains(item['dayId']) ||
          !itemIds.add(item['id'] as String)) {
        throw const EditableCodecException('invalid_input', 'item link');
      }
      positions
          .putIfAbsent(item['dayId'] as String, () => [])
          .add(item['position'] as int);
    }
    for (final list in positions.values) {
      list.sort();
      for (var index = 0; index < list.length; index++) {
        if (list[index] != index) {
          throw const EditableCodecException('invalid_input', 'position');
        }
      }
    }
    final derivedItems = <String>{};
    for (final kind in ['estimates', 'actualExpenses']) {
      final ids = <String>{};
      for (final value in _list(m[kind], 1000)) {
        final e = _object(value);
        final estimate = kind == 'estimates';
        _keys(
          e,
          estimate
              ? 'id itemId category unitAmountVnd basis customQuantity active description provenance'
              : 'id itemId amountVnd category paidOn description sourceItemSnapshot provenance',
        );
        _id(e['id']);
        _id(e['itemId'], nullable: true);
        _enum(e['category'], categories);
        _text(e['description'], 2000, blank: true);
        _provenance(e['provenance']);
        if (!ids.add(e['id'] as String) ||
            (e['itemId'] != null && !itemIds.contains(e['itemId']))) {
          throw const EditableCodecException('invalid_input', 'expense link');
        }
        if (estimate) {
          _integer(e['unitAmountVnd'], 0, maxMoney, nullable: true);
          _enum(e['basis'], {
            'trip_total',
            'per_person',
            'per_day',
            'per_person_day',
            'custom_quantity',
          });
          if (e['active'] is! bool) {
            throw const EditableCodecException('invalid_input', 'active');
          }
          if (e['basis'] == 'custom_quantity') {
            _integer(e['customQuantity'], 1, maxCount);
          } else if (e['customQuantity'] != null) {
            throw const EditableCodecException(
              'invalid_input',
              'customQuantity',
            );
          }
          if (e['unitAmountVnd'] == null &&
              _object(e['provenance'])['quality'] != 'unknown') {
            throw const EditableCodecException('invalid_input', 'unknown');
          }
          if (e['active'] == true &&
              e['itemId'] != null &&
              !derivedItems.add(e['itemId'] as String)) {
            throw const EditableCodecException(
              'invalid_input',
              'derived estimate',
            );
          }
        } else {
          _integer(e['amountVnd'], 0, maxMoney);
          _date(e['paidOn']);
          if (_object(e['provenance'])['quality'] != 'user_provided') {
            throw const EditableCodecException(
              'invalid_input',
              'actual provenance',
            );
          }
          if (e['sourceItemSnapshot'] != null) {
            final snap = _object(e['sourceItemSnapshot']);
            _keys(snap, 'title dayId date');
            _text(snap['title'], 200);
            _id(snap['dayId']);
            _date(snap['date'], nullable: true);
          }
        }
      }
    }
    for (final value in _list(m['exceptions'], 1000)) {
      final e = _object(value);
      _keys(e, 'issueCode itemIds reason fingerprint');
      _enum(e['issueCode'], {'overlap', 'known_closed', 'time_order'});
      _text(e['reason'], 2000);
      _digest(e['fingerprint']);
      for (final id in _list(e['itemIds'], 1000)) {
        _id(id);
        if (!itemIds.contains(id)) {
          throw const EditableCodecException('invalid_input', 'exception link');
        }
      }
    }
    final source = _object(m['source']);
    _keys(source, 'kind sourceId sourceDigest');
    _enum(source['kind'], {'new', 'manual_v1_copy', 'catalogue_reference'});
    _text(source['sourceId'], 128, nullable: true);
    _digest(source['sourceDigest'], nullable: true);
  }
}

/// Token reader rejects lexical integer tricks and duplicate keys before a Map
/// can erase them. No generic double numbers exist in the editable contract.
class _StrictEditableJson {
  final String text;
  int index = 0;
  _StrictEditableJson(this.text);
  Never fail() => throw const EditableCodecException('invalid_input', 'json');
  void space() {
    while (index < text.length &&
        const [9, 10, 13, 32].contains(text.codeUnitAt(index))) {
      index++;
    }
  }

  Object? parse() {
    final result = value(0);
    space();
    if (index != text.length) fail();
    return result;
  }

  Object? value(int depth) {
    if (depth > 32) fail();
    space();
    if (index >= text.length) fail();
    final c = text[index];
    if (c == '"') return string();
    if (c == '{') {
      index++;
      space();
      final map = <String, Object?>{};
      if (take('}')) return map;
      do {
        space();
        if (index >= text.length || text[index] != '"') fail();
        final key = string();
        if (map.containsKey(key)) fail();
        space();
        if (!take(':')) fail();
        map[key] = value(depth + 1);
        space();
        if (take('}')) return map;
      } while (take(','));
      fail();
    }
    if (c == '[') {
      index++;
      space();
      final list = <Object?>[];
      if (take(']')) return list;
      do {
        list.add(value(depth + 1));
        space();
        if (take(']')) return list;
      } while (take(','));
      fail();
    }
    for (final literal in ['null', 'true', 'false']) {
      if (text.startsWith(literal, index)) {
        index += literal.length;
        return literal == 'null' ? null : literal == 'true';
      }
    }
    final match = RegExp(r'-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?')
        .matchAsPrefix(text, index);
    if (match == null || match.group(2) != null || match.group(3) != null) {
      fail();
    }
    index = match.end;
    final number = int.tryParse(match.group(0)!);
    if (number == null ||
        number < -EditableTripCodec.maxMoney ||
        number > EditableTripCodec.maxMoney) {
      fail();
    }
    return number;
  }

  bool take(String s) {
    if (index < text.length && text[index] == s) {
      index++;
      return true;
    }
    return false;
  }

  String string() {
    final start = index++;
    var escaped = false;
    while (index < text.length) {
      final code = text.codeUnitAt(index++);
      if (!escaped && code == 34) {
        final v = jsonDecode(text.substring(start, index)) as String;
        TripPayloadCodec.validateUnicode(v);
        return v;
      }
      if (!escaped && code == 92) {
        escaped = true;
      } else {
        escaped = false;
      }
    }
    fail();
  }
}
