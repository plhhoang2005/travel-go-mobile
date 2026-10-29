import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/map/models/catalogue_map_marker.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/catalogue_discovery_map_screen.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/place_map_preview_card.dart';

void main() {
  group('PlaceMapPreviewCard Tests', () {
    testWidgets('renders marker title, rating, and details button', (tester) async {
      bool detailsPressed = false;
      final marker = CatalogueMapMarker(
        id: 'p1',
        title: 'Bà Nà Hills',
        subtitle: 'Đà Nẵng, Việt Nam',
        point: const LatLng(15.9988, 107.9961),
        type: MarkerType.place,
        averageRating: 4.8,
        reviewCount: 120,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlaceMapPreviewCard(
            marker: marker,
            onDetailsPressed: () {
              detailsPressed = true;
            },
          ),
        ),
      ));

      expect(find.text('Bà Nà Hills'), findsOneWidget);
      expect(find.textContaining('4.8'), findsOneWidget);
      expect(find.textContaining('120'), findsOneWidget);

      await tester.tap(find.text('Xem chi tiết'));
      expect(detailsPressed, isTrue);
    });
  });

  group('CatalogueDiscoveryMapScreen Tests', () {
    testWidgets('renders map screen and initial components with sovereignty markers', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CatalogueDiscoveryMapScreen(
          enableNetworkTiles: false,
        ),
      ));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Bản Đồ Khám Phá'), findsOneWidget);
      expect(find.text('Hoàng Sa (VN)'), findsOneWidget);
      expect(find.text('Trường Sa (VN)'), findsOneWidget);
    });

    testWidgets('renders destination markers from catalogue and enables drill-down', (tester) async {
      final mockCatalogue = CatalogueReference(
        checkedAt: '2026-10-29',
        sources: const [],
        destinations: [
          DestinationReference(
            id: 'da-lat',
            name: 'Đà Lạt',
            region: 'Tây Nguyên',
            sample: SampleReference.unavailable(),
            places: const [
              PlaceReference(
                id: 'p-xuan-huong',
                name: 'Hồ Xuân Hương',
                sourceId: 's1',
                latitude: 11.9404,
                longitude: 108.4583,
              ),
              PlaceReference(
                id: 'p-linh-phuoc',
                name: 'Chùa Linh Phước',
                sourceId: 's1',
                latitude: 11.9442,
                longitude: 108.4988,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: CatalogueDiscoveryMapScreen(
          initialCatalogue: mockCatalogue,
          enableNetworkTiles: false,
        ),
      ));

      expect(find.text('Đà Lạt'), findsOneWidget);

      // Tap on destination to drill down into its places
      await tester.tap(find.text('Đà Lạt'));
      await tester.pumpAndSettle();

      // Expect to see drill-down header and place preview card or reset button
      expect(find.textContaining('Đang xem: Đà Lạt'), findsOneWidget);
      expect(find.text('Toàn cảnh'), findsOneWidget);

      // Tap "Toàn cảnh" to reset to national view
      await tester.tap(find.text('Toàn cảnh'));
      await tester.pumpAndSettle();

      expect(find.text('Đà Lạt'), findsOneWidget);
    });
  });
}
