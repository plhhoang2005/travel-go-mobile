import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/presentation/travel_image.dart';
import 'package:travelgo_mobile/core/presentation/travel_media.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/trip_live_preview.dart';

import 'editable_local_store_test.dart' as records;

Future<void> pumpVisual(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('public photo requests identify TravelGO to the image host', (
    tester,
  ) async {
    await pumpVisual(
      tester,
      TravelImage(
        media: TravelMediaCatalog.forDestination('ha-noi'),
        semanticLabel: 'Hồ Hoàn Kiếm',
        height: 180,
      ),
    );
    final provider =
        tester.widget<Image>(find.byType(Image)).image as NetworkImage;
    expect(
      provider.headers?['User-Agent'],
      'TravelGO/1.0 (https://github.com/plhhoang2005/travel-go-mobile)',
    );
    expect(provider.headers?.keys, isNot(contains('Authorization')));
  });

  test('all twelve destination covers have explicit attribution and unknown IDs stay unknown', () {
    const ids = [
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
    ];
    for (final id in ids) {
      final media = TravelMediaCatalog.forDestination(id);
      expect(media, isNotNull, reason: id);
      expect(Uri.parse(media!.imageUrl).scheme, 'https');
      expect(Uri.parse(media.sourceUrl).host, 'commons.wikimedia.org');
      expect(media.author.trim(), isNotEmpty);
      expect(media.license.trim(), isNotEmpty);
      expect(Uri.parse(media.licenseUrl!).scheme, 'https');
    }
    expect(TravelMediaCatalog.forDestination('unknown'), isNull);
    expect(TravelMediaCatalog.forPlace('unknown'), isNull);
  });

  testWidgets(
    'missing photo remains labelled and never substitutes another destination',
    (tester) async {
      await pumpVisual(
        tester,
        const TravelImage(
          media: null,
          semanticLabel: 'Ảnh điểm chưa xác minh',
          height: 160,
        ),
      );
      expect(find.text('Chưa có ảnh phù hợp'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byTooltip('Nguồn ảnh'), findsNothing);
      expect(find.bySemanticsLabel('Ảnh điểm chưa xác minh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed network photo keeps attribution accessible at large text',
    (tester) async {
      final media = TravelMediaCatalog.forDestination('hue')!;
      await pumpVisual(
        tester,
        TravelImage(media: media, semanticLabel: 'Ngọ Môn, Huế', height: 180),
        scale: 2,
      );
      // flutter_test network image requests return an error rather than real photos.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh chưa tải được'), findsOneWidget);
      final target = tester.getSize(find.byTooltip('Nguồn ảnh'));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byTooltip('Nguồn ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh: ${media.author}'), findsOneWidget);
      expect(find.text(media.sourceUrl), findsOneWidget);
      expect(find.textContaining(media.license), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live preview reflects day people and exact budget without overflow',
    (tester) async {
      TripInput input(int people, int budget) => TripInput.fromJson({
        ...records.doc().input.toJson(),
        'destinationId': 'hue',
        'destinationName': 'Huế',
        'travelerCount': people,
        'totalBudgetVnd': budget,
      });
      await pumpVisual(
        tester,
        TripLivePreview(input: input(2, 4000000), dayCount: 3),
        scale: 2,
      );
      expect(find.text('3 ngày'), findsOneWidget);
      expect(find.text('2 người'), findsOneWidget);
      expect(find.textContaining('4.000.000'), findsOneWidget);
      expect(find.textContaining('2.000.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await pumpVisual(
        tester,
        TripLivePreview(input: input(3, 3000000), dayCount: 4),
        scale: 2,
      );
      expect(find.text('4 ngày'), findsOneWidget);
      expect(find.text('3 người'), findsOneWidget);
      expect(find.textContaining('3.000.000'), findsOneWidget);
      expect(find.textContaining('1.000.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact preview keeps exact total and handles zero people safely',
    (tester) async {
      final input = TripInput.fromJson({
        ...records.doc().input.toJson(),
        'travelerCount': 0,
        'totalBudgetVnd': 1234567,
      });
      await pumpVisual(
        tester,
        TripLivePreview(input: input, dayCount: 1, compact: true),
      );
      expect(find.byType(TravelImage), findsNothing);
      expect(find.textContaining('1.234.567'), findsOneWidget);
      expect(find.textContaining('/người'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
