import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/explore/presentation/widgets/place_visit_details_widget.dart';
import 'package:travelgo_mobile/features/explore/services/place_visit_details_repository.dart';

import 'place_visit_details_model_test.dart'
    show visitCatalogueFixture, visitTestHash, visitTestNow;

Future<void> pumpVisitDetails(
  WidgetTester tester,
  Map<String, dynamic> data, {
  double scale = 1,
  double width = 360,
  String origin = 'cache',
  VoidCallback? onRefresh,
  String? errorCode,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = Size(width, width > 600 ? 450 : 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final catalogue = parseVisitCatalogue(
    jsonEncode(data),
    expectedPlaceIds: {'test/place'},
    expectedCatalogueSha256: visitTestHash,
    now: visitTestNow,
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PlaceVisitDetailsWidget(
            place: const PlaceReference(
              id: 'test/place',
              name: 'Synthetic place',
              sourceId: 'official',
            ),
            details: catalogue.places['test/place'],
            snapshot: VisitSnapshot(
              catalogue: catalogue,
              origin: origin,
              sha256: 'a' * 64,
              lastFetchedAt: visitTestNow,
            ),
            now: visitTestNow,
            onRefresh: onRefresh,
            errorCode: errorCode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expandVisit(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'reference source remains readable when visit data is unavailable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceVisitDetailsWidget(
                place: PlaceReference(
                  id: 'test/place',
                  name: 'Synthetic place',
                  sourceId: 'reference',
                ),
                referenceSource: SourceReference(
                  id: 'reference',
                  title: 'Name reference',
                  publisher: 'Reference publisher',
                  url: 'https://example.org/name-reference',
                  checkedAt: '2026-10-13',
                ),
                details: null,
                snapshot: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expandVisit(tester, 'visit-source-test/place');
      expect(
        find.textContaining('https://example.org/name-reference'),
        findsOneWidget,
      );
      expect(find.textContaining('Nguồn tên địa điểm'), findsOneWidget);
      expect(find.text('Chưa xác minh giá vé'), findsOneWidget);
    },
  );
  testWidgets(
    'price keeps unit, audience and conditions rather than a bare amount',
    (tester) async {
      await pumpVisitDetails(tester, visitCatalogueFixture());
      expect(
        find.byKey(const ValueKey('visit-price-test/place')),
        findsOneWidget,
      );
      expect(find.textContaining('100 ₫'), findsOneWidget);
      expect(find.textContaining('person/visit'), findsOneWidget);
      expect(find.textContaining('Adults'), findsOneWidget);
      await expandVisit(tester, 'visit-conditions-test/place');
      expect(find.textContaining('Synthetic fixture only'), findsOneWidget);
      expect(find.textContaining('Transport'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown never turns into free, eligible free retains audience', (
    tester,
  ) async {
    final data = visitCatalogueFixture();
    final price = data['places'][0]['price'];
    price['status'] = 'unverified';
    price['options'][0]['amountVnd'] = null;
    price['evidence']['reviewState'] = 'unverified';
    await pumpVisitDetails(tester, data);
    expect(find.text('Chưa xác minh giá vé'), findsOneWidget);
    expect(find.textContaining('Miễn phí'), findsNothing);
    price['status'] = 'free';
    price['options'][0]['amountVnd'] = 0;
    price['options'][0]['audience'] = 'Eligible children';
    price['evidence']['reviewState'] = 'reviewed';
    await pumpVisitDetails(tester, data);
    expect(find.textContaining('Miễn phí'), findsOneWidget);
    expect(find.textContaining('Eligible children'), findsOneWidget);
  });

  testWidgets('bundle and variable labels keep route scope and exclusions', (
    tester,
  ) async {
    final data = visitCatalogueFixture();
    data['packages'] = [
      {
        'id': 'route',
        'label': 'Synthetic route',
        'scope': 'Fee for the whole route',
        'included': ['Two sites'],
        'excluded': ['Boat'],
        'conditions': ['Do not count each site separately'],
        'sourceIds': ['official'],
      },
    ];
    data['places'][0]['price']['status'] = 'bundled';
    data['places'][0]['price']['options'][0]['packageId'] = 'route';
    await pumpVisitDetails(tester, data);
    expect(find.textContaining('Vé theo gói/tuyến'), findsOneWidget);
    await expandVisit(tester, 'visit-conditions-test/place');
    expect(find.textContaining('Fee for the whole route'), findsOneWidget);
    expect(find.textContaining('Boat'), findsOneWidget);
    data['places'][0]['price']['status'] = 'variable';
    data['places'][0]['price']['options'][0]['amountVnd'] = null;
    await pumpVisitDetails(tester, data);
    expect(find.text('Giá thay đổi theo điều kiện'), findsOneWidget);
  });

  testWidgets('season, weekdays, overnight and return cutoff remain explicit', (
    tester,
  ) async {
    final data = visitCatalogueFixture();
    final hours = data['places'][0]['hours'];
    hours['status'] = 'seasonal';
    final rule = hours['rules'][0];
    rule['seasonStart'] = '11-01';
    rule['seasonEnd'] = '04-15';
    rule['startMinutes'] = 1200;
    rule['endMinutes'] = 60;
    rule['endDayOffset'] = 1;
    rule['admissionCutoffMinutes'] = 1230;
    rule['lastReturnMinutes'] = 60;
    await pumpVisitDetails(tester, data);
    expect(find.textContaining('01/11–15/04'), findsOneWidget);
    expect(find.textContaining('ngày hôm sau'), findsOneWidget);
    expect(find.textContaining('Nhận khách cuối'), findsOneWidget);
    expect(find.textContaining('Chuyến về cuối'), findsOneWidget);
    expect(find.text('Đang mở'), findsNothing);
    hours['status'] = 'temporarily_closed';
    hours['rules'] = <Object>[];
    hours['notes'] = ['Synthetic closure'];
    await pumpVisitDetails(tester, data);
    expect(find.text('Tạm đóng cửa theo nguồn'), findsOneWidget);
    expect(find.textContaining('20:00'), findsNothing);
  });

  testWidgets(
    'each field has sources and checked date distinct from fetch date',
    (tester) async {
      final data = visitCatalogueFixture();
      data['places'][0]['price']['evidence']['checkedAt'] = '2026-09-01';
      await pumpVisitDetails(tester, data, origin: 'remote');
      expect(find.textContaining('phiên bản 1'), findsOneWidget);
      expect(find.textContaining('Lần tải dữ liệu'), findsOneWidget);
      await expandVisit(tester, 'visit-source-test/place');
      expect(find.text('Nguồn giá vé'), findsOneWidget);
      expect(find.text('Nguồn giờ tham quan'), findsOneWidget);
      expect(find.textContaining('01/09/2026'), findsOneWidget);
      expect(find.text('Thông tin cần kiểm tra lại'), findsOneWidget);
    },
  );

  testWidgets('360dp text2x and landscape keep URL/copy controls readable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final data = visitCatalogueFixture();
    final url = 'https://example.org/${'long-source-path-' * 18}';
    data['sources'][0]['url'] = url;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    try {
      for (final width in [360.0, 800.0]) {
        await pumpVisitDetails(tester, data, width: width, scale: 2);
        await expandVisit(tester, 'visit-source-test/place');
        final copy = find.byKey(
          const ValueKey('copy-source-test/place-price-official'),
        );
        await tester.ensureVisible(copy);
        expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Sao chép nguồn giá vé'), findsOneWidget);
        await tester.tap(copy);
        await tester.pumpAndSettle();
        expect(copied, url);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'update error retains information and manual retry is actionable',
    (tester) async {
      var refreshes = 0;
      await pumpVisitDetails(
        tester,
        visitCatalogueFixture(),
        errorCode: 'remote_unavailable',
        onRefresh: () => refreshes++,
      );
      expect(find.textContaining('giữ bản dữ liệu hiện có'), findsOneWidget);
      await tester.tap(find.text('Cập nhật thông tin'));
      expect(refreshes, 1);
      expect(find.textContaining('100 ₫'), findsOneWidget);
    },
  );
}
