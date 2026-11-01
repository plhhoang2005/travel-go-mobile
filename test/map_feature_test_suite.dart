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

    test('Can Tho destination resolves to Mekong Delta coordinates (latitude ~10.04)', () {
      final canTho = DestinationReference(
        id: 'can-tho',
        name: 'Cần Thơ',
        region: 'Đồng bằng sông Cửu Long',
        sample: SampleReference.unavailable(),
        places: const [],
      );
      final coords = CatalogueDiscoveryMapScreen.resolveDestinationCoords(canTho);
      expect(coords.latitude, closeTo(10.0452, 0.05));
      expect(coords.longitude, closeTo(105.7469, 0.05));
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

    testWidgets('PlaceMapPreviewCard displays Admin section when isAdmin is true', (tester) async {
      bool togglePressed = false;
      final marker = CatalogueMapMarker(
        id: 'place-ponagar',
        title: 'Tháp Bà Po Nagar',
        subtitle: 'Nha Trang',
        point: const LatLng(12.2654, 109.1958),
        type: MarkerType.place,
        averageRating: 4.5,
      );

      // Render as Admin, currently visible
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlaceMapPreviewCard(
            marker: marker,
            isAdmin: true,
            isPlaceHidden: false,
            onAdminToggleHide: () => togglePressed = true,
          ),
        ),
      ));

      expect(find.text('Quản trị địa điểm'), findsOneWidget);
      expect(find.text('Đang hiển thị công khai'), findsOneWidget);
      expect(find.text('Ẩn địa điểm'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-toggle-place-visibility-btn')));
      expect(togglePressed, isTrue);

      // Now render when place is hidden
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlaceMapPreviewCard(
            marker: marker,
            isAdmin: true,
            isPlaceHidden: true,
            onAdminToggleHide: () {},
          ),
        ),
      ));

      expect(find.text('Đang ẩn với khách'), findsOneWidget);
      expect(find.text('Khách không nhìn thấy trên bản đồ'), findsOneWidget);
      expect(find.text('Hiện lại'), findsOneWidget);
    });

    testWidgets('PlaceMapPreviewCard hides Admin section when isAdmin is false', (tester) async {
      final marker = CatalogueMapMarker(
        id: 'place-ponagar',
        title: 'Tháp Bà Po Nagar',
        subtitle: 'Nha Trang',
        point: const LatLng(12.2654, 109.1958),
        type: MarkerType.place,
        averageRating: 4.5,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlaceMapPreviewCard(
            marker: marker,
            isAdmin: false,
          ),
        ),
      ));

      expect(find.text('Quản trị địa điểm'), findsNothing);
      expect(find.text('Ẩn địa điểm'), findsNothing);
      expect(find.byKey(const ValueKey('admin-toggle-place-visibility-btn')), findsNothing);
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

    testWidgets('tapping Xem chi tiết on place opens place detail modal sheet', (tester) async {
      final catalogue = CatalogueReference(
        checkedAt: '2026-10-30',
        sources: const [
          SourceReference(
            id: 's1',
            title: 'UBND TP Đà Lạt',
            publisher: 'UBND TP',
            url: 'https://dalat.vn',
            checkedAt: '2026-10-30',
          ),
        ],
        destinations: [
          DestinationReference(
            id: 'da-lat',
            name: 'Đà Lạt',
            region: 'Tây Nguyên',
            sample: SampleReference.unavailable(),
            places: const [
              PlaceReference(
                id: 'place-ga-da-lat',
                name: 'Ga Đà Lạt',
                sourceId: 's1',
                latitude: 11.9425,
                longitude: 108.4445,
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

      // Enter Đà Lạt drill down
      await tester.tap(find.text('Đà Lạt'));
      await tester.pumpAndSettle();

      // Tap on Ga Đà Lạt marker pin to open preview card
      await tester.tap(find.byIcon(Icons.place).first);
      await tester.pumpAndSettle();

      // Preview card is shown with Ga Đà Lạt
      expect(find.text('Ga Đà Lạt'), findsOneWidget);
      expect(find.text('Xem chi tiết'), findsOneWidget);

      // Tap Xem chi tiết
      await tester.tap(find.text('Xem chi tiết'));
      await tester.pumpAndSettle();

      // Place detail bottom sheet should appear with information
      expect(find.text('Vị trí địa lý'), findsOneWidget);
      expect(find.text('Thông tin tham quan'), findsOneWidget);
      expect(find.text('Chuẩn bị chuyến đi tới đây'), findsOneWidget);
      expect(find.text('Xem toàn cảnh Đà Lạt'), findsOneWidget);
    });
  });
}

