import 'dart:convert';

import 'editable_trip_codec.dart';
import 'trip_evidence_envelope.dart';
import 'trip_payload_codec.dart';

class TripEvidenceCodec {
  static const maxBytes = EditableTripCodec.maxBytes;
  static TripEvidenceEnvelope decode(String text) {
    return _checked(() {
      final raw = _object(EditableTripCodec.parseStrict(text), r'$');
      if (!raw.containsKey('contract')) {
        // Legacy refs remain opaque; only the new writer requires a registry.
        return TripEvidenceEnvelope(document: EditableTripCodec.decode(text));
      }
      _validate(raw);
      return TripEvidenceEnvelope.fromJson(raw);
    });
  }

  static String encode(TripEvidenceEnvelope envelope) => _checked(() {
    final raw = envelope.toJson();
    final text = EditableTripCodec.canonicalJson(raw);
    if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
      throw const EditableCodecException('invalid_input', 'size');
    }
    _validate(raw);
    return text;
  });

  static String digest(TripEvidenceEnvelope envelope) =>
      EditableTripCodec.digestText(encode(envelope));

  static T _checked<T>(T Function() action) {
    try {
      return action();
    } on EditableCodecException {
      rethrow;
    } on Object {
      throw const EditableCodecException('invalid_input');
    }
  }

  static Never _invalid(String path) =>
      throw EditableCodecException('invalid_input', path);

  static Map<String, Object?> _object(Object? value, String path) {
    if (value is! Map<String, Object?>) _invalid(path);
    return value;
  }

  static List<Object?> _list(Object? value, String path) {
    if (value is! List<Object?>) _invalid(path);
    return value;
  }

  static void _keys(Map<String, Object?> map, String names, String path) {
    final allowed = names.split(' ');
    if (map.length != allowed.length ||
        map.keys.any((k) => !allowed.contains(k))) {
      _invalid('$path.keys');
    }
  }

  static String _text(Object? value, String path, {bool blank = false}) {
    if (value is! String || (!blank && value.trim().isEmpty)) _invalid(path);
    try {
      TripPayloadCodec.validateUnicode(value);
    } on Object {
      _invalid(path);
    }
    return value;
  }

  static String _id(Object? value, String path) {
    final id = _text(value, path);
    if (id.runes.length > 128) _invalid(path);
    return id;
  }

  static void _uniqueId(
    Map<String, Object?> row,
    Set<String> ids,
    String path,
  ) {
    if (!ids.add(_id(row['id'], '$path.id'))) _invalid('$path.id');
  }

  static void _refs(
    Object? value,
    Set<String> ids,
    String path, {
    bool required = false,
  }) {
    final refs = _list(value, path);
    if (required && refs.isEmpty) _invalid(path);
    final seen = <String>{};
    for (final ref in refs) {
      final id = _id(ref, path);
      if (!ids.contains(id) || !seen.add(id)) _invalid(path);
    }
  }

  static final _timestamp = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
  );
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static void _time(Object? value, String path, {bool effective = false}) {
    if (value == null) return;
    final text = _text(value, path);
    if (effective && _date.hasMatch(text)) {
      try {
        TripPayloadCodec.validateCalendarDate(text);
      } on Object {
        _invalid(path);
      }
      return;
    }
    if (!_timestamp.hasMatch(text)) _invalid(path);
    try {
      TripPayloadCodec.validateCalendarDate(text.substring(0, 10));
    } on Object {
      _invalid(path);
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        parsed.toIso8601String().substring(0, 19) != text.substring(0, 19)) {
      _invalid(path);
    }
  }

  static void _record(Map<String, Object?> row, String path) {
    _keys(
      row,
      'id origin url title publisher factKey factValue retrievedAt checkedAt publishedAt effectiveFrom effectiveTo reviewed evidenceRequestId',
      path,
    );
    if (!EvidenceOrigin.values.any((v) => v.name == row['origin'])) {
      _invalid('$path.origin');
    }
    if (row['reviewed'] is! bool ||
        (row['origin'] != 'catalogue' && row['reviewed'] != false)) {
      _invalid('$path.reviewed');
    }
    if (row['origin'] == 'user') {
      if (row['url'] != null) _invalid('$path.url');
    } else {
      final value = _text(row['url'], '$path.url');
      if (RegExp(r'[\s\x00-\x20\x7f]').hasMatch(value)) _invalid('$path.url');
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !uri.isAbsolute ||
          uri.scheme != 'https' ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.authority.contains('@')) {
        _invalid('$path.url');
      }
    }
    for (final key in ['title', 'publisher']) {
      if (row[key] != null) _text(row[key], '$path.$key');
    }
    _text(row['factKey'], '$path.factKey');
    _text(row['factValue'], '$path.factValue', blank: true);
    for (final key in ['retrievedAt', 'checkedAt', 'publishedAt']) {
      _time(row[key], '$path.$key');
    }
    for (final key in ['effectiveFrom', 'effectiveTo']) {
      _time(row[key], '$path.$key', effective: true);
    }
    final from = row['effectiveFrom'] as String?;
    final to = row['effectiveTo'] as String?;
    if (from != null && to != null) {
      if (_date.hasMatch(from) != _date.hasMatch(to) ||
          DateTime.parse(from).isAfter(DateTime.parse(to))) {
        _invalid('$path.effectiveTo');
      }
    }
    if (row['evidenceRequestId'] != null &&
        !_uuid.hasMatch(
          _text(row['evidenceRequestId'], '$path.evidenceRequestId'),
        )) {
      _invalid('$path.evidenceRequestId');
    }
  }

  static void _validate(Map<String, Object?> raw) {
    if (raw['contract'] != TripEvidenceEnvelope.contractName) {
      throw const EditableCodecException('unsupported_schema');
    }
    _keys(
      raw,
      'contract document evidence claims externalPlaces externalBindings',
      r'$',
    );
    // Do not widen V2 schema or change its legacy provenance semantics.
    final document = EditableTripCodec.decode(
      EditableTripCodec.canonicalJson(raw['document']),
    );
    final evidenceIds = <String>{};
    var index = 0;
    for (final value in _list(raw['evidence'], r'$.evidence')) {
      final path = '\$.evidence[${index++}]';
      final row = _object(value, path);
      _record(row, path);
      _uniqueId(row, evidenceIds, path);
    }
    final claimIds = <String>{};
    index = 0;
    for (final value in _list(raw['claims'], r'$.claims')) {
      final path = '\$.claims[${index++}]';
      final row = _object(value, path);
      _keys(row, 'id text kind evidenceIds', path);
      _uniqueId(row, claimIds, path);
      _text(row['text'], '$path.text');
      if (!ClaimKind.values.any((v) => v.name == row['kind'])) {
        _invalid('$path.kind');
      }
      _refs(
        row['evidenceIds'],
        evidenceIds,
        '$path.evidenceIds',
        required: row['kind'] == 'fact',
      );
    }
    final externalIds = <String>{};
    index = 0;
    for (final value in _list(raw['externalPlaces'], r'$.externalPlaces')) {
      final path = '\$.externalPlaces[${index++}]';
      final row = _object(value, path);
      _keys(row, 'id name destinationName evidenceIds', path);
      _uniqueId(row, externalIds, path);
      _text(row['name'], '$path.name');
      _text(row['destinationName'], '$path.destinationName');
      _refs(
        row['evidenceIds'],
        evidenceIds,
        '$path.evidenceIds',
        required: true,
      );
    }
    final items = {for (final item in document.items) item.id: item};
    final boundItems = <String>{};
    index = 0;
    for (final value in _list(raw['externalBindings'], r'$.externalBindings')) {
      final path = '\$.externalBindings[${index++}]';
      final row = _object(value, path);
      _keys(row, 'itemId externalPlaceId', path);
      final itemId = _id(row['itemId'], '$path.itemId');
      final externalId = _id(row['externalPlaceId'], '$path.externalPlaceId');
      if (!items.containsKey(itemId) ||
          !externalIds.contains(externalId) ||
          !boundItems.add(itemId) ||
          items[itemId]?.placeId != null) {
        _invalid(path);
      }
    }
    for (final entry in [
      ('items', document.items.map((v) => v.provenance)),
      ('estimates', document.estimates.map((v) => v.provenance)),
      ('actualExpenses', document.actualExpenses.map((v) => v.provenance)),
    ]) {
      index = 0;
      for (final provenance in entry.$2) {
        _refs(
          provenance.sourceRefs,
          evidenceIds,
          '\$.document.${entry.$1}[${index++}].provenance.sourceRefs',
        );
      }
    }
  }
}
