import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Vai trò địa lý của tọa độ hiển thị trên bản đồ.
enum CoordinateRole {
  /// Tọa độ mốc đại diện cho cụm/khu vực quần đảo
  archipelagoLandmark,

  /// Tọa độ thực thể đảo cụ thể
  islandEntity,

  /// Tọa độ mốc đại diện vùng biển
  maritimeZone,
}

enum SovereigntyType { archipelago, island, sea }

class SovereigntyItem {
  final String id;
  final String name;
  final String administrativeUnit;
  final LatLng position;
  final SovereigntyType type;
  final CoordinateRole coordinateRole;
  final String coordinateDescription;
  final double minZoomRequired;
  final String description;
  final bool isRoutable;

  const SovereigntyItem({
    required this.id,
    required this.name,
    required this.administrativeUnit,
    required this.position,
    required this.type,
    required this.coordinateRole,
    required this.coordinateDescription,
    this.minZoomRequired = 0.0,
    required this.description,
    this.isRoutable = false,
  });
}

/// Lớp phủ khẳng định chủ quyền lãnh thổ & biển đảo Việt Nam trên FlutterMap.
///
/// Vai trò kỹ thuật:
/// - Hiển thị tên gọi hành chính và chủ quyền hợp pháp của Việt Nam tại Quần đảo Hoàng Sa (TP. Đà Nẵng),
///   Quần đảo Trường Sa (Tỉnh Khánh Hòa) và vùng biển Biển Đông.
/// - Áp dụng cơ chế lọc theo ngưỡng zoom (Zoom Threshold Filtering) để giảm thiểu mật độ nhãn ở góc nhìn rộng.
/// - Lưu ý: Đây là lớp phủ hiển thị các mốc chủ quyền (Sovereignty Marker Overlay), không phải bộ lọc
///   thay thế toàn bộ điểm ảnh trên raster tiles nền của bên thứ ba.
class VietnameseSovereigntyLayer extends StatelessWidget {
  final void Function(SovereigntyItem item)? onIslandTapped;
  final void Function(SovereigntyItem item)? onItemTapped;

  const VietnameseSovereigntyLayer({
    super.key,
    this.onIslandTapped,
    this.onItemTapped,
  });

  /// Nguồn dữ liệu mốc chủ quyền duy nhất (Single Source of Truth)
  static const List<SovereigntyItem> sovereigntyPoints = [
    // Quần đảo Hoàng Sa
    SovereigntyItem(
      id: 'hoangsa',
      name: 'Quần đảo Hoàng Sa',
      administrativeUnit: 'TP. Đà Nẵng · Việt Nam',
      position: LatLng(16.5367, 112.3486),
      type: SovereigntyType.archipelago,
      coordinateRole: CoordinateRole.archipelagoLandmark,
      coordinateDescription: 'Tọa độ mốc đại diện khu vực Quần đảo Hoàng Sa',
      minZoomRequired: 0.0,
      description: 'Quần đảo Hoàng Sa thuộc chủ quyền không thể tranh cãi của Việt Nam, được quản lý theo địa giới hành chính của TP. Đà Nẵng.',
    ),
    // Quần đảo Trường Sa
    SovereigntyItem(
      id: 'truongsa',
      name: 'Quần đảo Trường Sa',
      administrativeUnit: 'Tỉnh Khánh Hòa · Việt Nam',
      position: LatLng(9.5000, 113.8000),
      type: SovereigntyType.archipelago,
      coordinateRole: CoordinateRole.archipelagoLandmark,
      coordinateDescription: 'Tọa độ mốc đại diện khu vực Quần đảo Trường Sa',
      minZoomRequired: 0.0,
      description: 'Quần đảo Trường Sa thuộc chủ quyền không thể tách rời của Việt Nam, được quản lý theo địa giới hành chính của Tỉnh Khánh Hòa.',
    ),
    // Đảo Trường Sa Lớn
    SovereigntyItem(
      id: 'truongsa_lon',
      name: 'Đảo Trường Sa',
      administrativeUnit: 'Khánh Hòa · Việt Nam',
      position: LatLng(8.6444, 111.9194),
      type: SovereigntyType.island,
      coordinateRole: CoordinateRole.islandEntity,
      coordinateDescription: 'Tọa độ Đảo Trường Sa (Trường Sa Lớn)',
      minZoomRequired: 7.0,
      description: 'Đảo Trường Sa (Trường Sa Lớn) thuộc Tỉnh Khánh Hòa, Việt Nam.',
    ),
    // Biển Đông (Việt Nam)
    SovereigntyItem(
      id: 'bien_dong',
      name: 'Biển Đông',
      administrativeUnit: 'Vùng biển Việt Nam',
      position: LatLng(12.8000, 111.8000),
      type: SovereigntyType.sea,
      coordinateRole: CoordinateRole.maritimeZone,
      coordinateDescription: 'Tọa độ mốc đại diện vùng biển Biển Đông Việt Nam',
      minZoomRequired: 5.0,
      description: 'Vùng biển thuộc chủ quyền, quyền chủ quyền và quyền tài phán của Việt Nam được xác lập phù hợp với luật pháp quốc tế và Công ước Liên Hợp Quốc về Luật Biển (UNCLOS 1982).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.maybeOf(context);
    final currentZoom = camera?.zoom ?? 6.0;

    // Lọc danh sách điểm theo ngưỡng zoom để giảm thiểu mật độ nhãn
    final visiblePoints = sovereigntyPoints.where((item) {
      return currentZoom >= item.minZoomRequired;
    }).toList(growable: false);

    final isCompact = currentZoom < 5.0;

    return MarkerLayer(
      markers: visiblePoints.map((item) {
        final double markerWidth = isCompact
            ? 160.0
            : (item.type == SovereigntyType.sea ? 192.0 : 224.0);
        final double markerHeight = isCompact ? 40.0 : (item.type == SovereigntyType.sea ? 52.0 : 64.0);

        return Marker(
          point: item.position,
          width: markerWidth,
          height: markerHeight,
          alignment: Alignment.center,
          child: _SovereigntyBadge(
            item: item,
            isCompact: isCompact,
            onTap: () {
              _showSovereigntySnackBar(context, item);
              onItemTapped?.call(item);
              onIslandTapped?.call(item);
            },
          ),
        );
      }).toList(growable: false),
    );
  }

  void _showSovereigntySnackBar(BuildContext context, SovereigntyItem item) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 4),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('🇻🇳', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.description}\n(${item.coordinateDescription})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFCBD5E1),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SovereigntyBadge extends StatelessWidget {
  final SovereigntyItem item;
  final bool isCompact;
  final VoidCallback onTap;

  const _SovereigntyBadge({
    required this.item,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSea = item.type == SovereigntyType.sea;

    final borderColor = isSea ? colorScheme.outline : colorScheme.outlineVariant;
    final primaryTeal = colorScheme.primary;

    if (isCompact) {
      // Chế độ gọn gàng ở mức zoom rộng
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withAlpha(25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFDA251D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Icon(Icons.star_rounded, color: Color(0xFFFFEB3B), size: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Chế độ thẻ đầy đủ thông tin (zoom >= 5.0)
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isSea) ...[
              // Biểu tượng Quốc kỳ Việt Nam
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFDA251D),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26DA251D),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFEB3B),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              // Biểu tượng Biển Đông
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primaryTeal.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(
                    Icons.waves_rounded,
                    color: primaryTeal,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.2,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.administrativeUnit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSea
                          ? primaryTeal
                          : const Color(0xFFB91C1C),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
