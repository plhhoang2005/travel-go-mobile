import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_envelope.dart';

final _vectors = (jsonDecode(
  File('test/fixtures/trip_evidence_vectors.json').readAsStringSync(),
) as List).cast<Map<String, dynamic>>();
Map<String, dynamic> _vector(String id) =>
    _vectors.singleWhere((v) => v['id'] == id);
String _text(String id) => _vector(id)['rawText'] as String;
Map<String, dynamic> _raw() =>
    jsonDecode(_text('new_envelope')) as Map<String, dynamic>;
Map<String, dynamic> _record(Map<String, dynamic> raw, String key) =>
    (raw[key] as List).first as Map<String, dynamic>;
Map<String, dynamic> _document(Map<String, dynamic> raw) =>
    raw['document'] as Map<String, dynamic>;
void _reject(Map<String, dynamic> raw, {String code = 'invalid_input'}) {
  expect(
    () => TripEvidenceCodec.decode(jsonEncode(raw)),
    throwsA(isA<EditableCodecException>().having((e) => e.code, 'code', code)),
  );
}

String _sized(Map<String, dynamic> raw, int bytes) {
  _record(raw, 'evidence')['factValue'] = '';
  final overhead = utf8.encode(jsonEncode(raw)).length;
  _record(raw, 'evidence')['factValue'] = 'a' * (bytes - overhead);
  final result = jsonEncode(raw);
  expect(utf8.encode(result).length, bytes);
  return result;
}

void main() {
  test('reads_legacy_v2_without_rewriting', () {
    for (final id in ['old_v2', 'legacy_unresolved']) {
      final legacy = TripEvidenceCodec.decode(_text(id));
      expect(legacy.evidence, isEmpty);
      expect(legacy.claims, isEmpty);
      expect(legacy.externalPlaces, isEmpty);
      expect(legacy.externalBindings, isEmpty);
      expect(EditableTripCodec.encode(legacy.document), _text(id));
      expect(legacy.document.actualExpenses.single.amountVnd, 250000);
      expect(legacy.document.estimates.last.unitAmountVnd, isNull);
      expect(legacy.document.input.travelerCount, 3);
      expect(legacy.document.input.destinationName, 'Huế');
      expect(legacy.document.days.single.date, isNull);
    }
    final old = TripEvidenceCodec.decode(_text('legacy_unresolved'));
    expect(old.document.items.single.provenance.sourceRefs, [
      'historical-unresolved',
    ]);
    expect(old.document.items.single.provenance.quality, 'estimated');
    expect(old.document.items.single.notes, 'Giữ ghi chú');
    expect(
      () => TripEvidenceCodec.encode(old),
      throwsA(isA<EditableCodecException>()),
    );
    expect(
      () => TripEvidenceCodec.digest(old),
      throwsA(isA<EditableCodecException>()),
    );
    final wrapped = TripEvidenceCodec.encode(
      TripEvidenceCodec.decode(_text('old_v2')),
    );
    expect(TripEvidenceCodec.decode(wrapped).evidence, isEmpty);
    expect(
      () => EditableTripCodec.decode(wrapped),
      throwsA(isA<EditableCodecException>()),
    );
  });

  test('roundtrip_keeps_claim_sources', () {
    final before = TripEvidenceCodec.decode(_text('new_envelope'));
    final encoded = TripEvidenceCodec.encode(before);
    expect(encoded, _vector('new_envelope')['canonicalText']);
    expect(
      TripEvidenceCodec.digest(before),
      _vector('new_envelope')['expectedDigest'],
    );
    final restored = TripEvidenceCodec.decode(encoded);
    expect(restored.contract, 'travelgo.trip.evidence.v1');
    expect(
      restored.evidence.single.url.toString(),
      'https://example.org/place-a',
    );
    expect(restored.claims.single.evidenceIds, ['source-a']);
    expect(restored.externalPlaces.single.evidenceIds, ['source-a']);
    expect(
      restored.externalBindings.single.itemId,
      restored.document.items.single.id,
    );
    expect(restored.document.items.single.provenance.sourceRefs, ['source-a']);
    expect(restored.document.estimates.first.provenance.sourceRefs, [
      'source-a',
    ]);
    expect(restored.document.actualExpenses.single.provenance.sourceRefs, [
      'source-a',
    ]);
    expect(
      () => EditableTripCodec.decode(encoded),
      throwsA(isA<EditableCodecException>()),
    );
  });

  test('model_collections_are_immutable', () {
    final decoded = TripEvidenceCodec.decode(_text('new_envelope'));
    final records = [...decoded.evidence];
    final ids = ['source-a'];
    final claim = EvidenceClaim(
      id: 'claim-a',
      text: 'Thử',
      kind: ClaimKind.fact,
      evidenceIds: ids,
    );
    final place = ExternalPlaceRecord(
      id: 'external-a',
      name: 'Thử',
      destinationName: 'Huế',
      evidenceIds: ids,
    );
    final claims = [claim];
    final places = [place];
    final bindings = [...decoded.externalBindings];
    final model = TripEvidenceEnvelope(
      document: decoded.document,
      evidence: records,
      claims: claims,
      externalPlaces: places,
      externalBindings: bindings,
    );
    final encoded = TripEvidenceCodec.encode(model);
    final digest = TripEvidenceCodec.digest(model);
    records.clear();
    ids.clear();
    claims.clear();
    places.clear();
    bindings.clear();
    for (final list in [
      model.evidence,
      model.claims,
      model.externalPlaces,
      model.externalBindings,
      claim.evidenceIds,
      place.evidenceIds,
      model.document.items.single.provenance.sourceRefs,
      model.document.days,
    ]) {
      expect(() => list.clear(), throwsUnsupportedError);
    }
    final json = model.toJson();
    (json['evidence'] as List).clear();
    final claimJson = claim.toJson();
    expect(
      () => (claimJson['evidenceIds'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(TripEvidenceCodec.encode(model), encoded);
    expect(TripEvidenceCodec.digest(model), digest);
    expect(
      TripEvidenceEnvelope.fromJson(decoded.toJson()).toJson(),
      decoded.toJson(),
    );
  });

  for (final id in ['dangling_source', 'duplicate_id', 'bad_url']) {
    test('contract vector $id', () {
      expect(
        () => TripEvidenceCodec.decode(_text(id)),
        throwsA(
          isA<EditableCodecException>().having(
            (e) => e.code,
            'code',
            _vector(id)['expectedError'],
          ),
        ),
      );
    });
  }

  group('rejects_dangling_evidence', () {
    for (final collection in ['items', 'estimates', 'actualExpenses']) {
      test('$collection provenance', () {
        final raw = _raw();
        (_record(_document(raw), collection)['provenance']
            as Map)['sourceRefs'] = [
          'missing',
        ];
        _reject(raw);
      });
    }
    for (final collection in ['claims', 'externalPlaces']) {
      test('$collection refs', () {
        final raw = _raw();
        _record(raw, collection)['evidenceIds'] = ['missing'];
        _reject(raw);
      });
    }
    test('fact requires evidence but inference and unknown may have none', () {
      final raw = _raw();
      _record(raw, 'claims')['evidenceIds'] = <String>[];
      _reject(raw);
      for (final kind in ['inference', 'unknown']) {
        _record(raw, 'claims')['kind'] = kind;
        expect(
          TripEvidenceCodec.decode(jsonEncode(raw)).claims.single.kind.name,
          kind,
        );
      }
      _record(raw, 'externalPlaces')['evidenceIds'] = <String>[];
      _reject(raw);
    });
  });

  group('duplicate and external references', () {
    for (final key in [
      'evidence',
      'claims',
      'externalPlaces',
      'externalBindings',
    ]) {
      test('duplicate $key', () {
        final raw = _raw();
        (raw[key] as List).add(_record(raw, key));
        _reject(raw);
      });
    }
    for (final key in ['claims', 'externalPlaces']) {
      test('duplicate refs $key', () {
        final raw = _raw();
        _record(raw, key)['evidenceIds'] = ['source-a', 'source-a'];
        _reject(raw);
      });
    }
    for (final key in ['itemId', 'externalPlaceId']) {
      test('missing binding $key', () {
        final raw = _raw();
        _record(raw, 'externalBindings')[key] = 'missing';
        _reject(raw);
      });
    }
    test('catalogue and external binding conflict', () {
      final raw = _raw();
      _record(_document(raw), 'items')['placeId'] = 'catalogue-a';
      _reject(raw);
    });
    test('several items may share an external place', () {
      final raw = _raw();
      final item = Map<String, dynamic>.from(_record(_document(raw), 'items'));
      item['id'] = '00000000-0000-4000-8000-000000000011';
      item['position'] = 1;
      (_document(raw)['items'] as List).add(item);
      (raw['externalBindings'] as List).add({
        'itemId': item['id'],
        'externalPlaceId': 'external-a',
      });
      expect(
        TripEvidenceCodec.decode(jsonEncode(raw)).externalBindings,
        hasLength(2),
      );
    });
  });

  group('url trust and times', () {
    for (final url in [
      'http://example.org/a',
      '/relative',
      'https:///no-host',
      'https://user:pass@example.org/a',
      'https://example.org/a b',
      'https://example.org/\n',
      'https://[bad',
    ]) {
      test('bad URL ${jsonEncode(url)}', () {
        final raw = _raw();
        _record(raw, 'evidence')['url'] = url;
        _reject(raw);
      });
    }
    for (final origin in ['web', 'user']) {
      test('$origin cannot be reviewed', () {
        final raw = _raw();
        final r = _record(raw, 'evidence');
        r['origin'] = origin;
        r['reviewed'] = true;
        if (origin == 'user') r['url'] = null;
        _reject(raw);
      });
    }
    test('user cannot claim a URL; user and web unknown times stay null', () {
      final raw = _raw();
      final r = _record(raw, 'evidence');
      r['origin'] = 'user';
      _reject(raw);
      r['url'] = null;
      r['retrievedAt'] = null;
      var record = TripEvidenceCodec.decode(jsonEncode(raw)).evidence.single;
      expect(record.url, isNull);
      expect(record.retrievedAt, isNull);
      expect(record.checkedAt, isNull);
      expect(record.publishedAt, isNull);
      r['origin'] = 'web';
      r['url'] = 'https://example.org/a';
      record = TripEvidenceCodec.decode(jsonEncode(raw)).evidence.single;
      expect(record.reviewed, isFalse);
      expect(record.checkedAt, isNull);
    });
    for (final key in ['retrievedAt', 'checkedAt', 'publishedAt']) {
      for (final time in [
        '2026-02-30T01:00:00Z',
        '2026-10-27T24:00:00Z',
        '2026-10-27T01:00:00+00:00',
        '2026-10-27',
        '2026-10-27T01:00:00.1234567Z',
      ]) {
        test('invalid $key $time', () {
          final raw = _raw();
          _record(raw, 'evidence')[key] = time;
          _reject(raw);
        });
      }
    }
    test('valid fractional UTC timestamps are preserved', () {
      final raw = _raw();
      _record(raw, 'evidence')['checkedAt'] = '2026-10-27T01:00:00.123456Z';
      expect(
        TripEvidenceCodec.decode(jsonEncode(raw)).evidence.single.checkedAt,
        '2026-10-27T01:00:00.123456Z',
      );
    });
    test('URL wire spelling is preserved rather than normalized by Uri', () {
      final raw = _raw();
      const url = 'https://EXAMPLE.org/%7eplace?x=%41';
      _record(raw, 'evidence')['url'] = url;
      final decoded = TripEvidenceCodec.decode(jsonEncode(raw));
      expect(decoded.evidence.single.url, Uri.parse(url));
      final encoded =
          jsonDecode(TripEvidenceCodec.encode(decoded)) as Map<String, dynamic>;
      expect(_record(encoded, 'evidence')['url'], url);
    });
    test('UTC timestamps use the same calendar range as V2', () {
      final raw = _raw();
      _record(raw, 'evidence')['retrievedAt'] = '0000-01-01T00:00:00Z';
      _reject(raw);
    });
    test('effective dates validate format calendar and ordering', () {
      for (final pair in [
        ['2026-11-02', '2026-11-01'],
        ['2026-11-01', '2026-11-02T01:00:00Z'],
        ['2026-02-30', null],
        ['2026-11-01T01:00:00Z', '2026-11-01T00:00:00Z'],
      ]) {
        final raw = _raw();
        final r = _record(raw, 'evidence');
        r['effectiveFrom'] = pair[0];
        r['effectiveTo'] = pair[1];
        _reject(raw);
      }
      for (final pair in [
        ['2026-11-01', '2026-11-02'],
        ['2026-11-01T00:00:00Z', '2026-11-01T01:00:00Z'],
      ]) {
        final raw = _raw();
        final r = _record(raw, 'evidence');
        r['effectiveFrom'] = pair[0];
        r['effectiveTo'] = pair[1];
        expect(
          TripEvidenceCodec.decode(jsonEncode(raw))
              .evidence
              .single
              .effectiveFrom,
          pair[0],
        );
      }
    });
    test('receipt UUID is optional but cannot be malformed', () {
      final raw = _raw();
      final r = _record(raw, 'evidence');
      r['evidenceRequestId'] = 'model-invented';
      _reject(raw);
      r['evidenceRequestId'] = '00000000-0000-4000-8000-000000000001';
      expect(
        TripEvidenceCodec.decode(jsonEncode(raw))
            .evidence
            .single
            .evidenceRequestId,
        r['evidenceRequestId'],
      );
    });
  });

  group('strict schema', () {
    test('unknown contract and V1 do not fall back', () {
      final raw = _raw();
      raw['contract'] = 'travelgo.trip.evidence.v9';
      _reject(raw, code: 'unsupported_schema');
      expect(
        () => TripEvidenceCodec.decode('{"schemaVersion":1}'),
        throwsA(isA<EditableCodecException>()),
      );
    });
    for (final key in [
      'evidence',
      'claims',
      'externalPlaces',
      'externalBindings',
    ]) {
      test('unknown and missing keys $key', () {
        final raw = _raw();
        _record(raw, key)['extra'] = true;
        _reject(raw);
        final missing = _raw();
        _record(missing, key).remove(_record(missing, key).keys.first);
        _reject(missing);
      });
    }
    test('outer keys and wrong primitive types', () {
      final variants = <void Function(Map<String, dynamic>)>[
        (r) => r['extra'] = true,
        (r) => r.remove('claims'),
        (r) => r['evidence'] = {},
        (r) => _record(r, 'evidence')['reviewed'] = 'false',
        (r) => _record(r, 'evidence')['origin'] = 'official',
        (r) => _record(r, 'claims')['kind'] = 'verified',
        (r) => _record(r, 'claims')['evidenceIds'] = [42],
        (r) => _document(r)['extra'] = 1,
      ];
      for (final change in variants) {
        final raw = _raw();
        change(raw);
        _reject(raw);
      }
    });
    test('duplicate JSON keys Unicode and nested integer lexical tricks', () {
      final text = _text('new_envelope');
      for (final bad in [
        text.replaceFirst(
          '"reviewed":false',
          '"reviewed":false,"reviewed":true',
        ),
        text.replaceFirst('"factKey":"admission"', r'"factKey":"\ud800"'),
        text.replaceFirst('"travelerCount":3', '"travelerCount":3e0'),
        text.replaceFirst('"travelerCount":3', '"travelerCount":3.0'),
      ]) {
        expect(
          () => TripEvidenceCodec.decode(bad),
          throwsA(isA<EditableCodecException>()),
        );
      }
    });
    test('id bounds blank text and optional title publisher', () {
      for (final key in ['title', 'publisher', 'factKey', 'id']) {
        final raw = _raw();
        _record(raw, 'evidence')[key] = ' ';
        _reject(raw);
      }
      final raw = _raw();
      final r = _record(raw, 'evidence');
      r['id'] = 'a' * 129;
      _reject(raw);
      r['id'] = 'a' * 128;
      r['title'] = null;
      r['publisher'] = null;
      r['factValue'] = '';
      raw['claims'] = [];
      raw['externalPlaces'] = [];
      raw['externalBindings'] = [];
      for (final key in ['items', 'estimates', 'actualExpenses']) {
        for (final item in _document(raw)[key] as List) {
          (item['provenance'] as Map)['sourceRefs'] = [];
        }
      }
      expect(
        TripEvidenceCodec.decode(jsonEncode(raw)).evidence.single.id.length,
        128,
      );
    });
    test('encode validates manually constructed models', () {
      final good = TripEvidenceCodec.decode(_text('new_envelope'));
      final bad = TripEvidenceEnvelope(
        document: good.document,
        claims: good.claims,
      );
      expect(
        () => TripEvidenceCodec.encode(bad),
        throwsA(isA<EditableCodecException>()),
      );
    });
  });

  test('whole envelope UTF8 limit includes all evidence', () {
    final exactText = _sized(_raw(), TripEvidenceCodec.maxBytes);
    final exact = TripEvidenceCodec.decode(exactText);
    expect(
      utf8.encode(TripEvidenceCodec.encode(exact)).length,
      TripEvidenceCodec.maxBytes,
    );
    final descriptor = _vector('too_big');
    final tooBig = _sized(
      jsonDecode(_text(descriptor['baseVectorId'] as String))
          as Map<String, dynamic>,
      descriptor['oversizeUtf8Bytes'] as int,
    );
    expect(
      () => TripEvidenceCodec.decode(tooBig),
      throwsA(
        isA<EditableCodecException>().having((e) => e.path, 'path', 'size'),
      ),
    );
    final oversizedModel = TripEvidenceEnvelope.fromJson(
      jsonDecode(tooBig) as Map<String, Object?>,
    );
    expect(
      () => TripEvidenceCodec.encode(oversizedModel),
      throwsA(
        isA<EditableCodecException>().having((e) => e.path, 'path', 'size'),
      ),
    );
    final multi = _raw();
    _record(multi, 'evidence')['factValue'] =
        'ế' * (TripEvidenceCodec.maxBytes ~/ 2);
    final multiText = jsonEncode(multi);
    expect(multiText.length, lessThan(TripEvidenceCodec.maxBytes));
    expect(
      utf8.encode(multiText).length,
      greaterThan(TripEvidenceCodec.maxBytes),
    );
    expect(
      () => TripEvidenceCodec.decode(multiText),
      throwsA(isA<EditableCodecException>()),
    );
    expect(
      utf8.encode(EditableTripCodec.encode(exact.document)).length,
      lessThan(TripEvidenceCodec.maxBytes),
    );
  });

  test('digest_covers_evidence_change', () {
    final original = TripEvidenceCodec.decode(_text('new_envelope'));
    final digest = TripEvidenceCodec.digest(original);
    final changes = <void Function(Map<String, dynamic>)>[
      (r) => _record(r, 'evidence')['factValue'] = 'Đổi dữ kiện',
      (r) => _record(r, 'evidence')['url'] = 'https://example.org/b',
      (r) => _record(r, 'evidence')['reviewed'] = true,
      (r) => _record(r, 'evidence')['checkedAt'] = '2026-10-27T02:00:00Z',
      (r) => _record(r, 'claims')['text'] = 'Đổi nhận định',
      (r) => _record(r, 'externalPlaces')['name'] = 'Đổi tên',
    ];
    for (final change in changes) {
      final raw = _raw();
      change(raw);
      final changed = TripEvidenceCodec.decode(jsonEncode(raw));
      expect(
        EditableTripCodec.digest(changed.document),
        EditableTripCodec.digest(original.document),
      );
      expect(TripEvidenceCodec.digest(changed), isNot(digest));
    }
    final raw = _raw();
    final reversed = Map<String, dynamic>.fromEntries(
      raw.entries.toList().reversed,
    );
    expect(
      TripEvidenceCodec.encode(TripEvidenceCodec.decode(jsonEncode(reversed))),
      TripEvidenceCodec.encode(original),
    );
    expect(
      digest,
      sha256
          .convert(utf8.encode(TripEvidenceCodec.encode(original)))
          .toString(),
    );
  });
}
