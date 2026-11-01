import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/map/models/catalogue_map_marker.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/catalogue_discovery_map_screen.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/place_map_preview_card.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart';

void main() {
  group('[Member 2] Catalogue Map Marker & Sovereignty Tests', () {
    test('Marker correctly assigns visual weight and colors based on rating', () {
      final topRatedPlace = CatalogueMapMarker(
        id: 'place-bana',
        title: 'Bà Nà Hills',
        point: const LatLng(15.9988, 107.9961),
        type: MarkerType.place,
        averageRating: 4.8,
        reviewCount: 320,
      );
      expect(topRatedPlace.isTopRated, isTrue);
      expect(topRatedPlace.markerColor, equals(Colors.amber));
      expect(topRatedPlace.iconData, equals(Icons.star));
      expect(topRatedPlace.markerSize, equals(38.0));

      final normalRatedPlace = CatalogueMapMarker(
        id: 'place-market',
        title: 'Chợ Đà Lạt',
        point: const LatLng(11.9425, 108.4365),
        type: MarkerType.place,
        averageRating: 4.1,
        reviewCount: 45,
      );
      expect(normalRatedPlace.isTopRated, isFalse);
      expect(normalRatedPlace.markerColor, equals(Colors.teal));
      expect(normalRatedPlace.markerSize, equals(32.0));

      final lowRatedPlace = CatalogueMapMarker(
        id: 'place-new',
        title: 'Điểm Check-in Mới',
        point: const LatLng(11.9280, 108.4200),
        type: MarkerType.place,
        averageRating: 3.2,
      );
      expect(lowRatedPlace.isTopRated, isFalse);
      expect(lowRatedPlace.markerColor, equals(Colors.grey));
      expect(lowRatedPlace.markerSize, equals(26.0));
    });

    test('VietnameseSovereigntyLayer provides exact Hoang Sa and Truong Sa coordinates', () {
      final markers = VietnameseSovereigntyLayer.markers;
      expect(markers.length, equals(2));

      final hoangSa = markers.firstWhere((m) => m.title.contains('Hoàng Sa'));
      expect(hoangSa.point.latitude, closeTo(16.5392, 0.01));
      expect(hoangSa.point.longitude, closeTo(111.6025, 0.01));

      final truongSa = markers.firstWhere((m) => m.title.contains('Trường Sa'));
      expect(truongSa.point.latitude, closeTo(10.7327, 0.01));
      expect(truongSa.point.longitude, closeTo(115.8272, 0.01));
    });
  });

  group('[Member 2] PlaceMapPreviewCard Widget Tests', () {
    testWidgets('PlaceMapPreviewCard displays place details, star count, and handles details tap', (tester) async {
      bool detailsTapped = false;
      bool closeTapped = false;

      final marker = CatalogueMapMarker(
        id: 'place-xuan-huong',
        title: 'Hồ Xuân Hương',
        subtitle: 'Đà Lạt, Lâm Đồng',
        point: const LatLng(11.9404, 108.4583),
        type: MarkerType.place,
        averageRating: 4.9,
        reviewCount: 150,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlaceMapPreviewCard(
            marker: marker,
            onDetailsPressed: () => detailsTapped = true,
            onClosePressed: () => closeTapped = true,
          ),
        ),
      ));

      expect(find.text('Hồ Xuân Hương'), findsOneWidget);
      expect(find.text('Đà Lạt, Lâm Đồng'), findsOneWidget);
      expect(find.textContaining('4.9'), findsOneWidget);
      expect(find.textContaining('150 đánh giá'), findsOneWidget);
      expect(find.text('⭐ Nổi Bật'), findsOneWidget);

      await tester.tap(find.text('Xem chi tiết'));
      expect(detailsTapped, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      expect(closeTapped, isTrue);
    });
  });

  group('[Member 2] CatalogueDiscoveryMapScreen Interactive Drill-down Tests', () {
    testWidgets('renders map with sovereignty badges and destinations', (tester) async {
      final catalogue = CatalogueReference(
        checkedAt: '2026-10-30',
        sources: const [],
        destinations: [
          DestinationReference(
            id: 'da-lat',
            name: 'Đà Lạt',
            region: 'Tây Nguyên',
            sample: SampleReference.unavailable(),
            places: const [
              PlaceReference(
                id: 'place-xuan-huong',
                name: 'Hồ Xuân Hương',
                sourceId: 's1',
                latitude: 11.9404,
                longitude: 108.4583,
              ),
              PlaceReference(
                id: 'place-linh-phuoc',
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
          initialCatalogue: catalogue,
          enableNetworkTiles: false,
        ),
      ));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Bản Đồ Khám Phá'), findsOneWidget);
      expect(find.text('Hoàng Sa (VN)'), findsOneWidget);
      expect(find.text('Trường Sa (VN)'), findsOneWidget);
      expect(find.text('Đà Lạt'), findsOneWidget);

      // Drill down: Tap on destination
      await tester.tap(find.text('Đà Lạt'));
      await tester.pumpAndSettle();

      // Should display drill down header and return to national view button
      expect(find.textContaining('Đang xem: Đà Lạt'), findsOneWidget);
      expect(find.text('Toàn cảnh'), findsOneWidget);

      // Reset to national view
      await tester.tap(find.text('Toàn cảnh'));
      await tester.pumpAndSettle();

      expect(find.text('Đà Lạt'), findsOneWidget);
    });

    testWidgets('reflects dynamic admin changes (hiding/removing a place)', (tester) async {
      final catalogueWithPlace = CatalogueReference(
        checkedAt: '2026-10-30',
        sources: const [],
        destinations: [
          DestinationReference(
            id: 'da-lat',
            name: 'Đà Lạt',
            region: 'Tây Nguyên',
            sample: SampleReference.unavailable(),
            places: const [
              PlaceReference(
                id: 'place-cho-da-lat',
                name: 'Chợ Đà Lạt',
                sourceId: 's1',
                latitude: 11.9425,
                longitude: 108.4365,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: CatalogueDiscoveryMapScreen(
          initialCatalogue: catalogueWithPlace,
          enableNetworkTiles: false,
        ),
      ));

      // Tap Đà Lạt to enter drill-down
      await tester.tap(find.text('Đà Lạt'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đang xem: Đà Lạt (1 địa điểm)'), findsOneWidget);

      // Now simulate Admin hiding the place
      final catalogueWithoutPlace = CatalogueReference(
        checkedAt: '2026-10-30',
        sources: const [],
        destinations: [
          DestinationReference(
            id: 'da-lat',
            name: 'Đà Lạt',
            region: 'Tây Nguyên',
            sample: SampleReference.unavailable(),
            places: const [],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: CatalogueDiscoveryMapScreen(
          initialCatalogue: catalogueWithoutPlace,
          enableNetworkTiles: false,
        ),
      ));

      expect(find.byType(FlutterMap), findsOneWidget);
    });
  });
}

