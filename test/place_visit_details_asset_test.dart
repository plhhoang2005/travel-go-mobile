import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const assetPath = 'assets/catalogue/place_visit_details_v1.json';
  final rawBytes = File('assets/catalogue/catalogue_readiness_v1.json')
      .readAsBytesSync();
  final baseBytes = rawBytes.contains(13)
      ? rawBytes
      : utf8.encode(utf8.decode(rawBytes).replaceAll('\r\n', '\n').replaceAll('\n', '\r\n'));
  final base = jsonDecode(utf8.decode(baseBytes)) as Map<String, dynamic>;
  final destinations = base['destinations'] as List;
  final ids = destinations
      .expand((d) => d['places'] as List)
      .map((p) => p['id'] as String)
      .toSet();

  VisitCatalogue parseSeed() => parseVisitCatalogue(
    File(assetPath).readAsStringSync(),
    expectedPlaceIds: ids,
    expectedCatalogueSha256: sha256.convert(baseBytes).toString(),
    now: DateTime.now(),
  );

  test('seed has exact 72 stable IDs in existing 12 destinations', () {
    expect(destinations, hasLength(12));
    expect(ids, hasLength(72));
    expect(parseSeed().places.keys.toSet(), ids);
  });

  test('seed is registered and can be loaded through Flutter assets', () async {
    final value = await rootBundle.loadString(assetPath);
    expect(value, File(assetPath).readAsStringSync());
  });

  test(
    'Ha Long keeps route fees shared and site/port seasonal clocks separate',
    () {
      final seed = parseSeed();
      final places = seed.places.values.where(
        (place) => place.placeId.startsWith('ha-long/'),
      );
      expect(places, hasLength(6));
      expect(places.every((place) => place.isComplete), true);
      final sungSot = seed.places['ha-long/sung-sot']!;
      final meCung = seed.places['ha-long/me-cung']!;
      expect(
        sungSot.price.options.first.packageId,
        meCung.price.options.first.packageId,
      );
      expect(sungSot.price.options.first.amountVnd, 250000);
      final winter = sungSot.hours.rules.singleWhere(
        (rule) => rule.appliesOn(DateTime(2026, 11, 1)),
      );
      expect(winter.startMinutes, 450);
      expect(winter.endMinutes, 1020);
      expect(seed.places['ha-long/bay']!.hours.rules.first.startMinutes, 300);
      expect(seed.places['ha-long/ga-choi']!.hours.status, 'event_based');
      final tuanChau = seed.places['ha-long/tuan-chau']!;
      expect(
        tuanChau.price.options.any((option) => option.amountVnd == 150000),
        true,
      );
      expect(
        tuanChau.price.options.any((option) => option.amountVnd == 300000),
        true,
      );
      expect(tuanChau.hours.notes.join(' '), contains('10:00'));
      expect(seed.isComplete, false);
    },
  );

  test('reviewed facts retain direct evidence and unknowns are never zero', () {
    final seed = parseSeed();
    final temple = seed.places['ha-noi/van-mieu']!;
    expect(temple.price.options.first.amountVnd, 70000);
    expect(temple.price.evidence.isReviewed, true);
    expect(temple.hours.evidence.isReviewed, true);
    expect(
      seed.sources[temple.price.evidence.sourceIds.single]!.url,
      'https://www.vanmieu.gov.vn/vi/introduction/visitor-information',
    );
    for (final place in seed.places.values) {
      if (place.price.status == 'unverified') {
        expect(
          place.price.options.every((option) => option.amountVnd == null),
          true,
        );
      }
    }
  });

  test(
    'Hue paid sites distinguish child rates and last ticket sale from closing',
    () {
      final seed = parseSeed();
      for (final id in [
        'hue/citadel',
        'hue/tu-duc',
        'hue/minh-mang',
        'hue/khai-dinh',
      ]) {
        final place = seed.places[id]!;
        expect(place.isComplete, true);
        expect(
          place.price.options.first.amountVnd,
          id == 'hue/citadel' ? 200000 : 150000,
        );
        expect(
          place.price.options[1].amountVnd,
          id == 'hue/citadel' ? 40000 : 30000,
        );
        final winter = place.hours.rules.singleWhere(
          (rule) => rule.appliesOn(DateTime(2026, 10, 20)),
        );
        expect(winter.endMinutes, 1080);
        expect(winter.admissionCutoffMinutes, 1020);
        expect(
          place.hours.rules
              .singleWhere((rule) => rule.appliesOn(DateTime(2026, 10, 15)))
              .endMinutes,
          1110,
        );
      }
      expect(seed.places['hue/citadel']!.visitScopeLabel, contains('Đại Nội'));
    },
  );

  test('Hoi An shares ticket packages without borrowing pedestrian hours', () {
    final seed = parseSeed();
    final town = seed.places['hoi-an/ancient-town']!;
    final bridge = seed.places['hoi-an/japanese-bridge']!;
    final house = seed.places['hoi-an/tan-ky']!;
    final museum = seed.places['hoi-an/history-museum']!;
    for (final place in [town, bridge, house]) {
      expect(place.price.evidence.isReviewed, true);
      expect(place.price.options.map((o) => o.amountVnd), [80000, 120000]);
      expect(place.price.options.first.packageId, 'hoian-heritage-80');
      expect(place.price.options[1].packageId, 'hoian-heritage-120');
      expect(place.price.options.first.audience, contains('Chọn gói'));
    }
    expect(
      seed.packages['hoian-heritage-80']!.conditions.join(' '),
      contains('03 ngày'),
    );
    expect(town.hours.status, 'unverified');
    expect(bridge.hours.status, 'unverified');
    expect(town.hours.rules, isEmpty);
    expect(bridge.hours.rules, isEmpty);
    expect(museum.isComplete, true);
    expect(museum.price.options.single.amountVnd, 120000);
    expect(museum.hours.rules.single.startMinutes, 420);
    expect(museum.hours.rules.single.endMinutes, 1020);
    expect(house.isComplete, true);
    expect(house.hours.rules.map((r) => r.startMinutes), [480, 810]);
    expect(house.hours.rules.map((r) => r.endMinutes), [690, 1065]);
    expect(house.hours.evidence.conditions.join(' '), contains('Traveloka'));
    for (final id in ['hoi-an/an-bang', 'hoi-an/cua-dai']) {
      expect(seed.places[id]!.price.status, 'unverified');
      expect(seed.places[id]!.hours.status, 'unverified');
    }
  });

  test('Da Nang separates site admission, student rates and optional lift', () {
    final seed = parseSeed();
    final marble = seed.places['da-nang/marble']!;
    expect(marble.isComplete, true);
    final prices = {
      for (final option in marble.price.options) option.id: option,
    };
    expect(prices['thuy-son-adult']!.amountVnd, 40000);
    expect(prices['thuy-son-student']!.amountVnd, 10000);
    expect(prices['am-phu-adult']!.amountVnd, 20000);
    expect(prices['am-phu-student']!.amountVnd, 7000);
    expect(prices['lift-one-way']!.amountVnd, 15000);
    expect(prices['lift-return']!.amountVnd, 30000);
    expect(prices['thuy-son-under-six']!.amountVnd, 0);
    expect(prices['thuy-son-under-six']!.audience, contains('dưới 6'));
    expect(prices['thuy-son-adult']!.excluded.join(' '), contains('thang máy'));
    expect(marble.hours.rules.single.startMinutes, 420);
    expect(marble.hours.rules.single.endMinutes, 1020);
    expect(marble.price.evidence.sourceIds, contains('danang-fees-2026'));
  });

  test(
    'Da Nang preserves route seasons, referenced hours and unresolved gaps',
    () {
      final seed = parseSeed();
      final peninsula = seed.places['da-nang/son-tra']!;
      expect(peninsula.isComplete, true);
      expect(peninsula.visitScopeLabel, contains('ba tuyến'));
      expect(peninsula.price.status, 'free');
      expect(
        peninsula.price.options.single.excluded.join(' '),
        contains('Đồng Đình'),
      );
      for (final date in [
        DateTime(2026, 10, 1),
        DateTime(2027, 2, 28),
        DateTime(2028, 2, 29),
      ]) {
        final rule = peninsula.hours.rules.singleWhere(
          (r) => r.appliesOn(date),
        );
        expect(rule.startMinutes, 450);
        expect(rule.endMinutes, 1050);
        expect(rule.lastReturnMinutes, isNull);
      }
      expect(
        peninsula.hours.rules
            .singleWhere((r) => r.appliesOn(DateTime(2026, 3, 1)))
            .endMinutes,
        1110,
      );
      final market = seed.places['da-nang/han-market']!;
      expect(market.hours.evidence.isReviewed, true);
      expect(market.hours.rules.single.startMinutes, 360);
      expect(market.hours.rules.single.endMinutes, 1140);
      expect(market.hours.notes.join(' '), contains('tham khảo'));
      expect(market.price.status, 'unverified');
      final pagoda = seed.places['da-nang/lady-buddha']!;
      expect(pagoda.price.status, 'free');
      expect(pagoda.hours.status, 'unverified');
      expect(pagoda.hours.rules, isEmpty);
      final pass = seed.places['da-nang/hai-van']!;
      expect(pass.price.options.single.amountVnd, 0);
      expect(
        pass.price.options.single.excluded.join(' '),
        contains('Hải Vân Quan'),
      );
      expect(pass.hours.status, 'unverified');
      expect(seed.places['da-nang/my-khe']!.isComplete, false);
    },
  );

  test('partial development seed is not an approved remote release', () {
    final seed = parseSeed();
    expect(seed.isComplete, false);
    expect(
      () => parseVisitCatalogue(
        File(assetPath).readAsStringSync(),
        expectedPlaceIds: ids,
        expectedCatalogueSha256: sha256.convert(baseBytes).toString(),
        now: DateTime.now(),
        requireComplete: true,
      ),
      throwsA(
        isA<VisitDataException>().having((e) => e.code, 'code', 'incomplete'),
      ),
    );
  });
}
