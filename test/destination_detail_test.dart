import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';

import 'catalogue_parser_test.dart'
    show catalogueData, firstSample, conditionalReview;
import 'discovery_screen_test.dart' show pumpDiscovery;
import 'guest_draft_planner_test.dart' show DraftApi;

void main() {
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
}
