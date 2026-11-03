import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';

import 'catalogue_parser_test.dart'
    show catalogueData, firstSample, conditionalReview;
import 'discovery_screen_test.dart' show pumpDiscovery, discoveryVisitsFixture;
import 'guest_draft_planner_test.dart' show DraftApi;

void main() {
  testWidgets(
    'direct detail loads visit fields and keeps source and pending sample policy',
    (tester) async {
      final catalogue = CatalogueParser().parse(jsonEncode(catalogueData()));
      final discovery = DiscoveryProvider();
      final trip = TripProvider(apiService: DraftApi());
      final visits = discoveryVisitsFixture();
      addTearDown(discovery.dispose);
      addTearDown(trip.dispose);
      addTearDown(visits.dispose);
      await pumpDiscovery(
        tester,
        discovery,
        trip,
        visits: visits,
        width: 360,
        scale: 2,
        screen: DestinationDetailScreen(
          catalogue: catalogue,
          destination: catalogue.destinations.first,
          visitProvider: visits,
        ),
      );
      expect(find.text('Ví dụ đang được rà soát'), findsOneWidget);
      expect(find.text('Ngày 1'), findsNothing);
      expect(
        find.textContaining(
          'Giá, giờ mở cửa, thời lượng và vị trí chính xác: Chưa xác minh',
        ),
        findsNothing,
      );

      // Switch to Attractions tab to view places & details
      await tester.tap(find.textContaining('Điểm tham quan'));
      await tester.pumpAndSettle();

      // Tap on Van Mieu to expand its details & reviews
      final toggleVanMieu = find.byKey(
        const ValueKey('toggle-place-ha-noi/van-mieu'),
      );
      await tester.ensureVisible(toggleVanMieu);
      await tester.tap(toggleVanMieu);
      await tester.pumpAndSettle();

      expect(find.textContaining('70.000 ₫'), findsWidgets);
      final source = find.byKey(const ValueKey('visit-source-ha-noi/van-mieu'));
      await tester.ensureVisible(source);
      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(find.text('Nguồn giá vé'), findsOneWidget);
      expect(
        find.textContaining(
          'vanmieu.gov.vn/vi/introduction/visitor-information',
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed visit loader leaves detail and preparation action available',
    (tester) async {
      final catalogue = CatalogueParser().parse(jsonEncode(catalogueData()));
      final discovery = DiscoveryProvider();
      final trip = TripProvider(apiService: DraftApi());
      final visits = discoveryVisitsFixture(fail: true);
      addTearDown(discovery.dispose);
      addTearDown(trip.dispose);
      addTearDown(visits.dispose);
      await pumpDiscovery(
        tester,
        discovery,
        trip,
        visits: visits,
        screen: DestinationDetailScreen(
          catalogue: catalogue,
          destination: catalogue.destinations.first,
          visitProvider: visits,
        ),
      );
      expect(
        find.textContaining('Chưa tải được thông tin tham quan'),
        findsOneWidget,
      );

      // Switch to Attractions tab where place cards display pricing
      await tester.tap(find.textContaining('Điểm tham quan'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa xác minh giá vé'), findsNWidgets(6));
      final prepare = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Chuẩn bị chuyến đi'),
      );
      expect(prepare.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 390.0]) {
    testWidgets(
      'pending hides days/semantics, sources wrap at $width scale 1.5',
      (tester) async {
        final catalogue = CatalogueParser().parse(jsonEncode(catalogueData()));
        final discovery = DiscoveryProvider(),
            trip = TripProvider(apiService: DraftApi());
        addTearDown(discovery.dispose);
        addTearDown(trip.dispose);
        await pumpDiscovery(
          tester,
          discovery,
          trip,
          width: width,
          scale: 1.5,
          screen: DestinationDetailScreen(
            catalogue: catalogue,
            destination: catalogue.destinations.first,
          ),
        );
        expect(find.text('Ví dụ đang được rà soát'), findsOneWidget);
        expect(find.text('Ngày 1'), findsNothing);
        expect(find.textContaining('Chưa xác minh'), findsWidgets);

        // Switch to Attractions tab and expand first place to see source url
        await tester.tap(find.textContaining('Điểm tham quan'));
        await tester.pumpAndSettle();
        final firstToggle = find.byKey(
          ValueKey(
            'toggle-place-${catalogue.destinations.first.places.first.id}',
          ),
        );
        await tester.ensureVisible(firstToggle);
        await tester.tap(firstToggle);
        await tester.pumpAndSettle();

        expect(find.textContaining('vietnam.travel'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'conditional synthetic sample previews with warnings and conditions',
    (tester) async {
      final data = catalogueData();
      firstSample(data)['editorialReview'] = conditionalReview();
      final catalogue = CatalogueParser().parse(jsonEncode(data));
      final d = DiscoveryProvider(),
          trip = TripProvider(apiService: DraftApi());
      addTearDown(d.dispose);
      addTearDown(trip.dispose);
      await pumpDiscovery(
        tester,
        d,
        trip,
        screen: DestinationDetailScreen(
          catalogue: catalogue,
          destination: catalogue.destinations.first,
        ),
      );
      await tester.tap(find.text('Xem ví dụ tham khảo'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa xác minh tính khả thi'), findsOneWidget);
      expect(find.text('Synthetic test condition'), findsOneWidget);
      expect(find.text('Ngày 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanding place with missing or empty sourceId does not crash (no Bad state: No element)',
    (tester) async {
      final catalogue = CatalogueParser().parse(jsonEncode(catalogueData()));
      final destinationWithUnknownSource = DestinationReference(
        id: 'test-dest',
        name: 'Điểm đến thử nghiệm',
        region: 'Miền Trung',
        places: [
          const PlaceReference(
            id: 'place-no-source',
            name: 'Địa điểm không có nguồn',
            sourceId: 'non-existent-source-id',
          ),
        ],
        sample: SampleReference.unavailable(id: 'test-dest'),
      );

      final discovery = DiscoveryProvider();
      final trip = TripProvider(apiService: DraftApi());
      addTearDown(discovery.dispose);
      addTearDown(trip.dispose);

      await pumpDiscovery(
        tester,
        discovery,
        trip,
        screen: DestinationDetailScreen(
          catalogue: catalogue,
          destination: destinationWithUnknownSource,
        ),
      );

      // Switch to Attractions tab
      await tester.tap(find.textContaining('Điểm tham quan'));
      await tester.pumpAndSettle();

      // Tap to expand the place accordion card
      final toggleButton = find.byKey(
        const ValueKey('toggle-place-place-no-source'),
      );
      expect(toggleButton, findsOneWidget);
      await tester.ensureVisible(toggleButton);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Must render details and reviews section without throwing Bad state: No element
      expect(find.text('Địa điểm không có nguồn'), findsWidgets);
      expect(find.textContaining('Thông tin tổng hợp TravelGO'), findsOneWidget);
      expect(find.byKey(const ValueKey('place-reviews-place-no-source')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
