import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/catalogue_map_marker.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart';

void main() {
  group('CatalogueMapMarker Tests', () {
    test('CatalogueMapMarker calculates visual weight based on rating', () {
      final highRated = CatalogueMapMarker(
        id: 'p1',
        title: 'Bà Nà Hills',
        point: const LatLng(15.9988, 107.9961),
        type: MarkerType.place,
        averageRating: 4.8,
        reviewCount: 50,
      );
      expect(highRated.isTopRated, isTrue);
      expect(highRated.markerColor, equals(Colors.amber));
      expect(highRated.markerSize, greaterThan(35.0));

      final lowRated = CatalogueMapMarker(
        id: 'p2',
        title: 'Điểm mới',
        point: const LatLng(16.0, 108.0),
        type: MarkerType.place,
        averageRating: 3.0,
        reviewCount: 2,
      );
      expect(lowRated.isTopRated, isFalse);
      expect(lowRated.markerSize, lessThan(highRated.markerSize));
    });

    test('CatalogueMapMarker handles destination type correctly', () {
      final destMarker = CatalogueMapMarker(
        id: 'da-lat',
        title: 'Đà Lạt',
        point: const LatLng(11.9404, 108.4583),
        type: MarkerType.destination,
      );
      expect(destMarker.type, equals(MarkerType.destination));
      expect(destMarker.markerSize, greaterThanOrEqualTo(40.0));
    });
  });

  group('VietnameseSovereigntyLayer Tests', () {
    test('provides fixed sovereignty coordinates for Hoang Sa and Truong Sa', () {
      final markers = VietnameseSovereigntyLayer.markers;
      expect(markers.length, equals(2));
      
      final hoangSa = markers.firstWhere((m) => m.title.contains('Hoàng Sa'));
      expect(hoangSa.point.latitude, closeTo(16.5, 0.5));
      expect(hoangSa.point.longitude, closeTo(111.6, 0.5));

      final truongSa = markers.firstWhere((m) => m.title.contains('Trường Sa'));
      expect(truongSa.point.latitude, closeTo(10.7, 1.5));
      expect(truongSa.point.longitude, closeTo(115.8, 1.5));
    });
  });
}
