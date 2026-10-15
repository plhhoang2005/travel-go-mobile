import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';

Map<String, dynamic> catalogueData() => jsonDecode(
  File('docs/phase-2/catalogue/catalogue_readiness_v1.json').readAsStringSync(),
) as Map<String, dynamic>;
Map<String, dynamic> firstSample(Map<String, dynamic> data) =>
    (data['destinations'] as List).first['sample'] as Map<String, dynamic>;
Map<String, dynamic> conditionalReview() => {
  'status': 'reviewed_with_conditions',
  'reviewedAt': '2026-10-15',
  'sourceIds': ['hn'],
  'conditions': ['Synthetic test condition'],
  'reviewNotes': ['Synthetic fixture only; not real travel verification'],
};

void main() {
  final parser = CatalogueParser();
  test(
    '12 destinations, 72 immutable places, unknowns and all pending samples',
    () {
      final result = parser.parse(jsonEncode(catalogueData()));
      expect(result.destinations.length, 12);
      expect(result.destinations.expand((d) => d.places).length, 72);
      expect(result.sources.length, 17);
      expect(result.destinations.every((d) => !d.sample.canPreview), true);
      expect(result.destinations.first.places.first.priceVnd, isNull);
      expect(() => result.destinations.clear(), throwsUnsupportedError);
      expect(
        () => result.destinations.first.places.clear(),
        throwsUnsupportedError,
      );
      expect(() => result.sources.clear(), throwsUnsupportedError);
      expect(
        () => result.destinations.first.sample.days.first.placeIds.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('legacy missing review stays pending; conditional review keeps feasibility warning', () {
    final data = catalogueData();
    firstSample(data).remove('editorialReview');
    expect(
      parser.parse(jsonEncode(data)).destinations.first.sample.canPreview,
      false,
    );
    firstSample(data)['editorialReview'] = conditionalReview();
    final sample = parser.parse(jsonEncode(data)).destinations.first.sample;
    expect(sample.canPreview, true);
    expect(sample.status, 'not_feasibility_verified');
    expect(sample.warnings, isNotEmpty);
  });
  test('two days with one and three stops do not require all six places', () {
    final data = catalogueData();
    final places = (data['destinations'] as List).first['places'] as List;
    firstSample(data)['days'] = [
      {
        'day': 1,
        'placeIds': [places[0]['id']],
      },
      {
        'day': 2,
        'placeIds': [places[1]['id'], places[2]['id'], places[3]['id']],
      },
    ];
    expect(
      parser.parse(jsonEncode(data)).destinations.first.sample.days.length,
      2,
    );
  });
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'schema': (d) => d['schemaVersion'] = 2,
    'duplicate destination': (d) =>
        (d['destinations'] as List)[1]['id'] = 'ha-noi',
    'missing destination': (d) => (d['destinations'] as List).removeLast(),
    'duplicate source': (d) => (d['sources'] as List)[1]['id'] = 'hn',
    'source credentials': (d) =>
        (d['sources'] as List)[0]['url'] = 'https://u:p@vietnam.travel/x',
    'source host': (d) =>
        (d['sources'] as List)[0]['url'] = 'https://vietnam.travel.evil.test/x',
    'source HTTP': (d) =>
        (d['sources'] as List)[0]['url'] = 'http://vietnam.travel/x',
    'source port': (d) =>
        (d['sources'] as List)[0]['url'] = 'https://vietnam.travel:8443/x',
    'source date': (d) => (d['sources'] as List)[0]['checkedAt'] = '2026-02-30',
    'source missing': (d) =>
        ((d['destinations'] as List)[0]['places'] as List)[0]['sourceId'] =
            'fake',
    'price free': (d) =>
        ((d['destinations'] as List)[0]['places'] as List)[0]['priceVnd'] = 0,
    'coordinates fake': (d) =>
        ((d['destinations'] as List)[0]['places'] as List)[0]['coordinates'] = {
          'lat': 0,
        },
    'place duplicate': (d) =>
        ((d['destinations'] as List)[0]['places'] as List)[1]['id'] =
            'ha-noi/hoan-kiem',
    'routing verified': (d) =>
        (d['destinations'] as List)[0]['routingReady'] = true,
    'sample falsely verified': (d) => firstSample(d)['status'] = 'verified',
    'sample cross destination': (d) =>
        (firstSample(d)['days'] as List)[0]['placeIds'] = ['hue/citadel'],
    'sample duplicate stop': (d) =>
        (firstSample(d)['days'] as List)[0]['placeIds'] = [
          'ha-noi/hoan-kiem',
          'ha-noi/hoan-kiem',
        ],
    'sample wrong day': (d) => (firstSample(d)['days'] as List)[0]['day'] = 2,
    'review null': (d) => firstSample(d)['editorialReview'] = null,
    'review status': (d) =>
        (firstSample(d)['editorialReview'] as Map)['status'] = 'verified',
    'review pending dated': (d) =>
        (firstSample(d)['editorialReview'] as Map)['reviewedAt'] = '2026-10-15',
    'review conditional no source': (d) => firstSample(d)['editorialReview'] = {
      ...conditionalReview(),
      'sourceIds': [],
    },
    'review conditional fake source': (d) =>
        firstSample(d)['editorialReview'] = {
          ...conditionalReview(),
          'sourceIds': ['fake'],
        },
    'review conditional bad date': (d) => firstSample(d)['editorialReview'] = {
      ...conditionalReview(),
      'reviewedAt': '2026-02-30',
    },
    'review conditional blank condition': (d) =>
        firstSample(d)['editorialReview'] = {
          ...conditionalReview(),
          'conditions': [' '],
        },
    'review conditional no notes': (d) => firstSample(d)['editorialReview'] = {
      ...conditionalReview(),
      'reviewNotes': [],
    },
    'rights false': (d) => (d['rights'] as Map)['copiedImages'] = true,
  };
  for (final entry in invalid.entries) {
    test('reject ${entry.key}', () {
      final data = catalogueData();
      entry.value(data);
      expect(() => parser.parse(jsonEncode(data)), throwsFormatException);
    });
  }
}
