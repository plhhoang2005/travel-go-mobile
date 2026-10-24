import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';

// Synthetic contract fixtures. These amounts and times are not travel facts.
const visitTestHash =
    'c14cecc97149a3acf64f439d44662333bbb8756bd580e18f368ac053bdd1542a';
final visitTestNow = DateTime.utc(2026, 10, 20, 12);

Map<String, dynamic> visitEvidenceFixture() => {
  'sourceIds': ['official'],
  'checkedAt': '2026-10-20',
  'reviewState': 'reviewed',
  'conditions': <String>[],
  'unresolvedIssues': <String>[],
};

Map<String, dynamic> visitOptionFixture() => {
  'id': 'adult',
  'label': 'Synthetic admission',
  'audience': 'Adults',
  'amountVnd': 100,
  'currency': 'VND',
  'unit': 'person/visit',
  'included': ['Admission'],
  'excluded': ['Transport'],
  'conditions': ['Synthetic fixture only'],
};

Map<String, dynamic> visitRuleFixture() => {
  'label': 'Synthetic daily schedule',
  'weekdays': [1, 2, 3, 4, 5, 6, 7],
  'startMinutes': 480,
  'endMinutes': 1020,
  'endDayOffset': 0,
};

Map<String, dynamic> visitCatalogueFixture() => {
  'schemaVersion': 1,
  'version': 1,
  'publishedAt': '2026-10-20T00:00:00Z',
  'catalogueSha256': visitTestHash,
  'timezone': 'Asia/Ho_Chi_Minh',
  'sources': [
    {
      'id': 'official',
      'title': 'Synthetic official information',
      'publisher': 'Fixture operator',
      'url': 'https://example.org/visit',
    },
  ],
  'packages': <Map<String, dynamic>>[],
  'places': [
    {
      'placeId': 'test/place',
      'visitScopeLabel': 'Synthetic paid site',
      'price': {
        'status': 'priced',
        'options': [visitOptionFixture()],
        'evidence': visitEvidenceFixture(),
      },
      'hours': {
        'status': 'scheduled',
        'rules': [visitRuleFixture()],
        'notes': <String>[],
        'evidence': visitEvidenceFixture(),
      },
      'notes': <String>[],
    },
  ],
};

Map<String, dynamic> fixturePlace(Map<String, dynamic> data) =>
    (data['places'] as List).first as Map<String, dynamic>;

VisitCatalogue parseFixture(
  Map<String, dynamic> data, {
  bool complete = false,
}) => parseVisitCatalogue(
  jsonEncode(data),
  expectedPlaceIds: {'test/place'},
  expectedCatalogueSha256: visitTestHash.toUpperCase(),
  now: visitTestNow,
  requireComplete: complete,
);

void main() {
  Matcher invalid([String? code]) => throwsA(
    isA<VisitDataException>().having(
      (e) => e.code,
      'safe code',
      code == null ? isNotEmpty : equals(code),
    ),
  );

  test(
    'source age uses Vietnam date and does not count download freshness',
    () {
      final data = visitCatalogueFixture();
      fixturePlace(data)['price']['evidence']['checkedAt'] = '2026-09-20';
      final evidence = parseFixture(data).places['test/place']!.price.evidence;
      expect(evidence.needsReview(DateTime.utc(2026, 10, 20, 16, 59)), false);
      expect(evidence.needsReview(DateTime.utc(2026, 10, 20, 17)), true);
    },
  );

  test('untrusted source and malformed envelope never leak their bodies', () {
    for (final url in [
      'http://example.org',
      'https://secret@example.org',
      'javascript:alert(1)',
    ]) {
      final data = visitCatalogueFixture();
      data['sources'][0]['url'] = url;
      expect(() => parseFixture(data), invalid('source_url'));
    }
    for (final mutation in [
      'schema',
      'version',
      'zone',
      'publication',
      'date',
      'refs',
    ]) {
      final data = visitCatalogueFixture();
      switch (mutation) {
        case 'schema':
          data['schemaVersion'] = 2;
        case 'version':
          data['version'] = 1.5;
        case 'zone':
          data['timezone'] = 'UTC';
        case 'publication':
          data['publishedAt'] = '2026-10-20T24:00:00Z';
        case 'date':
          data['sources'][0]['effectiveFrom'] = '2026-02-30';
        case 'refs':
          fixturePlace(data)['price']['evidence']['sourceIds'] = [
            'official',
            'official',
          ];
      }
      expect(() => parseFixture(data), invalid(), reason: mutation);
    }
    expect(() => parseVisitManifest('\uFEFF{}'), invalid('size_or_encoding'));
    expect(
      () => parseVisitManifest(' ' * (maxVisitManifestBytes + 1)),
      invalid('size_or_encoding'),
    );
    try {
      parseVisitManifest('{"private":"do not echo"');
      fail('Malformed manifest accepted');
    } on VisitDataException catch (error) {
      expect(error.toString(), 'VisitDataException(json)');
    }
  });

  test(
    'reviewed catalogue preserves separate evidence and immutable values',
    () {
      final catalogue = parseFixture(visitCatalogueFixture(), complete: true);
      final place = catalogue.places['test/place']!;
      expect(catalogue.isComplete, true);
      expect(place.price.options.single.amountVnd, 100);
      expect(place.hours.rules.single.startMinutes, 480);
      expect(place.price.evidence.checkedAt, DateTime.utc(2026, 10, 20));
      expect(() => catalogue.places.clear(), throwsUnsupportedError);
      expect(() => catalogue.sources.clear(), throwsUnsupportedError);
      expect(() => place.price.options.clear(), throwsUnsupportedError);
      expect(
        () => place.hours.rules.single.weekdays.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => place.price.evidence.sourceIds.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'null is not free and partial seed cannot become a complete release',
    () {
      final data = visitCatalogueFixture();
      final price = fixturePlace(data)['price'] as Map<String, dynamic>;
      price['status'] = 'unverified';
      (price['options'] as List).first['amountVnd'] = null;
      price['evidence'] = {
        'reviewState': 'unverified',
        'sourceIds': <String>[],
        'checkedAt': null,
        'conditions': <String>[],
        'unresolvedIssues': ['Not researched'],
      };
      expect(
        parseFixture(data).places['test/place']!.price.options.single.amountVnd,
        isNull,
      );
      expect(parseFixture(data).isComplete, false);
      expect(() => parseFixture(data, complete: true), invalid('incomplete'));
      price['status'] = 'free';
      expect(() => parseFixture(data), invalid());
    },
  );

  for (final field in ['price', 'hours']) {
    test(
      'reviewed $field requires its own sources, date and resolved issues',
      () {
        for (final mutation in ['sources', 'date', 'issues', 'status']) {
          final data = visitCatalogueFixture();
          final value = fixturePlace(data)[field] as Map<String, dynamic>;
          final evidence = value['evidence'] as Map<String, dynamic>;
          switch (mutation) {
            case 'sources':
              evidence['sourceIds'] = <String>[];
            case 'date':
              evidence['checkedAt'] = null;
            case 'issues':
              evidence['unresolvedIssues'] = ['Conflict'];
            case 'status':
              value['status'] = 'unverified';
          }
          expect(() => parseFixture(data), invalid(), reason: mutation);
        }
      },
    );
  }

  test('free admission retains audience and eligibility conditions', () {
    final data = visitCatalogueFixture();
    final price = fixturePlace(data)['price'] as Map<String, dynamic>;
    price['status'] = 'free';
    final option = (price['options'] as List).first;
    option['amountVnd'] = 0;
    option['audience'] = 'Eligible children';
    option['conditions'] = ['Proof of eligibility required'];
    final parsed = parseFixture(data).places['test/place']!.price;
    expect(parsed.options.single.audience, 'Eligible children');
    expect(
      parsed.options.single.conditions,
      contains('Proof of eligibility required'),
    );
    option['amountVnd'] = null;
    expect(() => parseFixture(data), invalid());
  });

  test(
    'exact place IDs, catalogue hash and unique references are enforced',
    () {
      for (final mutation in [
        'missing',
        'unknown',
        'duplicate',
        'hash',
        'source',
        'package',
      ]) {
        final data = visitCatalogueFixture();
        switch (mutation) {
          case 'missing':
            data['places'] = <Object>[];
          case 'unknown':
            fixturePlace(data)['placeId'] = 'unknown/place';
          case 'duplicate':
            (data['places'] as List).add(fixturePlace(data));
          case 'hash':
            data['catalogueSha256'] = '0' * 64;
          case 'source':
            fixturePlace(data)['hours']['evidence']['sourceIds'] = ['absent'];
          case 'package':
            fixturePlace(data)['price']['options'][0]['packageId'] = 'absent';
        }
        expect(() => parseFixture(data), invalid(), reason: mutation);
      }
    },
  );

  test('money, dates and time inputs reject normalization or overflow', () {
    for (final amount in [-1, 1.5, 9007199254740992, '100']) {
      final data = visitCatalogueFixture();
      fixturePlace(data)['price']['options'][0]['amountVnd'] = amount;
      expect(() => parseFixture(data), invalid(), reason: '$amount');
    }
    for (final date in ['2026-02-30', '2026-10-21', '20/10/2026']) {
      final data = visitCatalogueFixture();
      fixturePlace(data)['hours']['evidence']['checkedAt'] = date;
      expect(() => parseFixture(data), invalid(), reason: date);
    }
    for (final minute in [-1, 1440, 480.5, '08:00']) {
      final data = visitCatalogueFixture();
      fixturePlace(data)['hours']['rules'][0]['startMinutes'] = minute;
      expect(() => parseFixture(data), invalid());
    }
  });

  test(
    'season wraps year with inclusive boundaries and no inferred overnight',
    () {
      final data = visitCatalogueFixture();
      final rule = fixturePlace(data)['hours']['rules'][0];
      fixturePlace(data)['hours']['status'] = 'seasonal';
      rule['seasonStart'] = '11-01';
      rule['seasonEnd'] = '04-15';
      final parsed = parseFixture(data)
          .places['test/place']!
          .hours
          .rules
          .single;
      expect(parsed.appliesOn(DateTime(2026, 11, 1)), true);
      expect(parsed.appliesOn(DateTime(2027, 4, 15)), true);
      expect(parsed.appliesOn(DateTime(2027, 4, 16)), false);
      expect(parsed.appliesOn(DateTime(2026, 10, 31)), false);
      rule['startMinutes'] = 1200;
      rule['endMinutes'] = 60;
      expect(() => parseFixture(data), invalid());
      rule['endDayOffset'] = 1;
      expect(
        parseFixture(data)
            .places['test/place']!
            .hours
            .rules
            .single
            .endDayOffset,
        1,
      );
      rule['seasonEnd'] = '02-30';
      expect(() => parseFixture(data), invalid());
    },
  );

  test('package scope, route, cutoffs and event hours remain distinct', () {
    final data = visitCatalogueFixture();
    data['packages'] = [
      {
        'id': 'shared-route',
        'label': 'Synthetic route',
        'scope': 'Route admission, not a fee for each site',
        'included': ['Two sites'],
        'excluded': ['Boat'],
        'conditions': ['Per route'],
        'sourceIds': ['official'],
      },
    ];
    final place = fixturePlace(data);
    place['price']['status'] = 'bundled';
    place['price']['options'][0]['packageId'] = 'shared-route';
    place['price']['options'][0]['routeId'] = 'route-2';
    place['hours']['rules'][0]['admissionCutoffMinutes'] = 960;
    place['hours']['rules'][0]['lastReturnMinutes'] = 1050;
    final parsed = parseFixture(data);
    expect(parsed.packages['shared-route']!.excluded, ['Boat']);
    expect(
      parsed.places['test/place']!.price.options.single.packageId,
      'shared-route',
    );
    expect(
      parsed.places['test/place']!.hours.rules.single.lastReturnMinutes,
      1050,
    );
    place['hours']['status'] = 'event_based';
    place['hours']['rules'] = <Object>[];
    place['hours']['notes'] = ['By separately announced performances'];
    expect(parseFixture(data).places['test/place']!.hours.rules, isEmpty);
    place['hours']['status'] = 'temporarily_closed';
    expect(
      parseFixture(data).places['test/place']!.hours.status,
      'temporarily_closed',
    );
  });

  test(
    'manifest rejects traversal, unsupported versions and unbounded bodies',
    () {
      final manifest = <String, dynamic>{
        'schemaVersion': 1,
        'version': 2,
        'objectPath': 'releases/2.json',
        'sha256': 'a' * 64,
        'byteLength': 100,
        'publishedAt': '2026-10-20T00:00:00Z',
        'catalogueSha256': visitTestHash,
      };
      expect(parseVisitManifest(jsonEncode(manifest)).version, 2);
      for (final path in [
        '../2.json',
        'releases/../2.json',
        'https://example.org/2',
        'releases/1.json',
      ]) {
        manifest['objectPath'] = path;
        expect(() => parseVisitManifest(jsonEncode(manifest)), invalid());
      }
      manifest['objectPath'] = 'releases/2.json';
      manifest['byteLength'] = 2097153;
      expect(() => parseVisitManifest(jsonEncode(manifest)), invalid());
      manifest['byteLength'] = 100;
      manifest['version'] = 9007199254740992;
      expect(() => parseVisitManifest(jsonEncode(manifest)), invalid());
      expect(
        () => parseVisitManifest('{"private":"do not echo"'),
        invalid('json'),
      );
    },
  );
}
