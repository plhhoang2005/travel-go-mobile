import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/catalogue_map_marker.dart';

class VietnameseSovereigntyLayer {
  const VietnameseSovereigntyLayer._();

  static const List<CatalogueMapMarker> markers = [
    CatalogueMapMarker(
      id: 'sovereignty-hoang-sa',
      title: 'Quần đảo Hoàng Sa (Đà Nẵng)',
      subtitle: 'Chủ quyền Việt Nam',
      point: LatLng(16.5392, 111.6025),
      type: MarkerType.sovereignty,
    ),
    CatalogueMapMarker(
      id: 'sovereignty-truong-sa',
      title: 'Quần đảo Trường Sa (Khánh Hòa)',
      subtitle: 'Chủ quyền Việt Nam',
      point: LatLng(10.7327, 115.8272),
      type: MarkerType.sovereignty,
    ),
  ];

  static Widget buildSovereigntyBadge(CatalogueMapMarker marker) {
    final label = marker.title.contains('Hoàng Sa') ? 'Hoàng Sa (VN)' : 'Trường Sa (VN)';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.yellow, size: 12),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.location_on, color: Colors.red, size: 24),
        ],
      ),
    );
  }
}
