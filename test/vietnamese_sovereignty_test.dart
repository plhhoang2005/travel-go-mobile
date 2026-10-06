import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart';
import 'package:travelgo_mobile/features/map/services/destination_catalog_service.dart';

void main() {
  group('Vietnamese Sovereignty & Island Catalog Tests', () {
    late DestinationCatalogService catalogService;

    setUp(() {
      catalogService = DestinationCatalogService();
    });

    test('Single Source of Truth: Catalog derives sovereign islands directly from layer', () {
      final islandDestinations = catalogService.getSovereignIslands();
      final sovereigntyPoints = VietnameseSovereigntyLayer.sovereigntyPoints;

      // Only land entities (archipelagos and islands) are added to catalog; sea is excluded
      expect(islandDestinations.length, equals(3));

      // Hoàng Sa
      final destHoangSa = islandDestinations.firstWhere((d) => d.id == 'hoangsa');
      final pointHoangSa = sovereigntyPoints.firstWhere((p) => p.id == 'hoangsa');
      expect(destHoangSa.position, equals(pointHoangSa.position));
      expect(destHoangSa.position.latitude, closeTo(16.5367, 0.001));
      expect(pointHoangSa.coordinateRole, equals(CoordinateRole.archipelagoLandmark));
      expect(destHoangSa.isRoutable, isFalse);

      // Quần đảo Trường Sa
      final destTruongSa = islandDestinations.firstWhere((d) => d.id == 'truongsa');
      final pointTruongSa = sovereigntyPoints.firstWhere((p) => p.id == 'truongsa');
      expect(destTruongSa.position, equals(pointTruongSa.position));
      expect(destTruongSa.position.latitude, closeTo(9.5000, 0.001));
      expect(pointTruongSa.coordinateRole, equals(CoordinateRole.archipelagoLandmark));
      expect(destTruongSa.isRoutable, isFalse);

      // Đảo Trường Sa (Trường Sa Lớn)
      final destTruongSaLon = islandDestinations.firstWhere((d) => d.id == 'truongsa_lon');
      final pointTruongSaLon = sovereigntyPoints.firstWhere((p) => p.id == 'truongsa_lon');
      expect(destTruongSaLon.position, equals(pointTruongSaLon.position));
      expect(destTruongSaLon.position.latitude, closeTo(8.6444, 0.001));
      expect(pointTruongSaLon.coordinateRole, equals(CoordinateRole.islandEntity));
      expect(destTruongSaLon.isRoutable, isFalse);

      // Biển Đông (chỉ tồn tại trên layer bản đồ)
      final pointBienDong = sovereigntyPoints.firstWhere((p) => p.id == 'bien_dong');
      expect(pointBienDong.coordinateRole, equals(CoordinateRole.maritimeZone));
    });

    test('Routability guard: Mainland is routable, Sovereign Islands are non-routable lookup only', () {
      final all = catalogService.getAll(includeIslands: true);

      // Mainland destinations must be routable
      final dalat = all.firstWhere((d) => d.id == 'dalat');
      expect(dalat.isRoutable, isTrue);

      // Island destinations must not be routable
      final hoangsa = all.firstWhere((d) => d.id == 'hoangsa');
      expect(hoangsa.isRoutable, isFalse);

      final truongsa = all.firstWhere((d) => d.id == 'truongsa');
      expect(truongsa.isRoutable, isFalse);
    });

    test('Flexible search: supports partial queries (sa, khanh), unaccented queries, and baseline legacy tests', () {
      // Partial queries
      final searchSa = catalogService.search('sa');
      expect(searchSa.any((d) => d.id == 'sapa'), isTrue);
      expect(searchSa.any((d) => d.id == 'hoangsa'), isTrue);
      expect(searchSa.any((d) => d.id == 'truongsa'), isTrue);

      final searchKhanh = catalogService.search('khanh');
      expect(searchKhanh.any((d) => d.id == 'truongsa'), isTrue);

      // Unaccented searches
      final unaccentedHoangSa = catalogService.search('hoang sa');
      expect(unaccentedHoangSa.any((d) => d.id == 'hoangsa'), isTrue);

      final unaccentedTruongSa = catalogService.search('truong sa');
      expect(unaccentedTruongSa.any((d) => d.id == 'truongsa'), isTrue);
      expect(unaccentedTruongSa.any((d) => d.id == 'truongsa_lon'), isTrue);

      // Baseline legacy compatibility preserved
      final searchDa = catalogService.search('Đà');
      expect(searchDa.length, equals(1));
      expect(searchDa.first.id, equals('dalat'));

      final searchDuyen = catalogService.search('Duyên');
      expect(searchDuyen.length, equals(1));
      expect(searchDuyen.first.id, equals('nhatrang'));
    });

    test('VietnameseSovereigntyLayer descriptions use 2025 administrative naming and UNCLOS 1982', () {
      final points = VietnameseSovereigntyLayer.sovereigntyPoints;

      final hoangSa = points.firstWhere((p) => p.id == 'hoangsa');
      expect(hoangSa.description, contains('TP. Đà Nẵng'));
      expect(hoangSa.description, isNot(contains('Huyện Hoàng Sa')));

      final truongSa = points.firstWhere((p) => p.id == 'truongsa');
      expect(truongSa.description, contains('Tỉnh Khánh Hòa'));
      expect(truongSa.description, isNot(contains('Huyện Trường Sa')));

      final bienDong = points.firstWhere((p) => p.id == 'bien_dong');
      expect(bienDong.description, contains('UNCLOS 1982'));
      expect(bienDong.description, contains('phù hợp với luật pháp quốc tế'));
    });

    testWidgets('VietnameseSovereigntyLayer adjusts visible markers based on zoom level (Anti-clutter)', (tester) async {
      // Test at low zoom (< 5.0): Only compact Hoang Sa and Truong Sa are shown
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              key: ValueKey('map_low_zoom'),
              options: MapOptions(
                initialCenter: LatLng(14.0, 112.0),
                initialZoom: 4.0,
              ),
              children: [
                VietnameseSovereigntyLayer(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Quần đảo Hoàng Sa'), findsOneWidget);
      expect(find.text('Quần đảo Trường Sa'), findsOneWidget);
      // Truong Sa Lon and Bien Dong should not be displayed at zoom 4.0 to prevent overlapping
      expect(find.text('Đảo Trường Sa'), findsNothing);
      expect(find.text('Biển Đông'), findsNothing);

      // Test at zoom 8.0 centered directly on Dao Truong Sa: island marker is visible
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              key: ValueKey('map_high_zoom'),
              options: MapOptions(
                initialCenter: LatLng(8.6444, 111.9194),
                initialZoom: 8.0,
              ),
              children: [
                VietnameseSovereigntyLayer(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Đảo Trường Sa'), findsOneWidget);
    });
  });
}
