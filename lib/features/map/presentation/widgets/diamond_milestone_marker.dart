import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/map_models.dart';

class DiamondMilestoneMarker extends StatelessWidget {
  final RouteWaypoint waypoint;
  final int sequenceNumber;
  final bool isSelected;
  final VoidCallback onTap;

  const DiamondMilestoneMarker({
    super.key,
    required this.waypoint,
    required this.sequenceNumber,
    required this.isSelected,
    required this.onTap,
  });

  IconData _resolveCategoryIcon() {
    final cat = (waypoint.category ?? '').toLowerCase();
    final type = waypoint.type.toLowerCase();
    final title = waypoint.title.toLowerCase();

    if (type == 'origin') return Icons.navigation_rounded;
    if (type == 'destination') return Icons.flag_rounded;

    if (cat.contains('xe buýt') || cat.contains('bus') || title.contains('xe buýt') || title.contains('trạm')) {
      return Icons.directions_bus_filled_rounded;
    }
    if (cat.contains('khách sạn') || cat.contains('hotel')) return Icons.hotel_rounded;
    if (cat.contains('thác') || cat.contains('suối') || cat.contains('nước')) return Icons.water_drop_rounded;
    if (cat.contains('cà phê') || cat.contains('cafe')) return Icons.local_cafe_rounded;
    if (cat.contains('ẩm thực') || cat.contains('ăn') || cat.contains('nhà hàng') || cat.contains('bến thành')) {
      return Icons.ramen_dining_rounded;
    }
    if (cat.contains('check-in') || cat.contains('sao') || cat.contains('khám phá')) return Icons.star_rounded;
    if (cat.contains('khởi hành') || cat.contains('xe')) return Icons.directions_car_rounded;

    return Icons.place_rounded;
  }

  Color _resolveMarkerColor() {
    final cat = (waypoint.category ?? '').toLowerCase();
    final type = waypoint.type.toLowerCase();
    final title = waypoint.title.toLowerCase();

    if (waypoint.isCompleted) return const Color(0xFF10B981); // Emerald Green
    if (type == 'origin') return const Color(0xFF0284C7); // Anime Sky Blue
    if (type == 'destination') return const Color(0xFFFF4757); // Vibrant Coral Red

    if (cat.contains('xe buýt') || cat.contains('bus') || title.contains('xe buýt') || title.contains('trạm')) {
      return const Color(0xFFFF9F1A); // Vibrant Anime Bus Orange/Yellow
    }
    if (cat.contains('khách sạn') || cat.contains('hotel')) {
      return const Color(0xFF546E7A); // Purple/Blue Stay
    }
    if (cat.contains('cà phê') || cat.contains('cafe')) {
      return const Color(0xFFD97706); // Amber Coffee
    }
    if (cat.contains('ẩm thực') || cat.contains('nhà hàng') || cat.contains('bến thành')) {
      return const Color(0xFFFF5252); // Red Food Badge
    }

    return const Color(0xFF0284C7); // Vibrant Primary
  }

  @override
  Widget build(BuildContext context) {
    final markerBg = _resolveMarkerColor();

    final seqStr = sequenceNumber == 0
        ? 'A'
        : (waypoint.type == 'destination'
            ? 'D'
            : sequenceNumber.toString().padLeft(2, '0'));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedScale(
          scale: isSelected ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -math.pi / 4,
                child: Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    color: markerBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(5),
                    ),
                    border: Border.all(color: Colors.white, width: 3.0),
                    boxShadow: [
                      BoxShadow(
                        color: markerBg.withValues(alpha: isSelected ? 0.6 : 0.4),
                        blurRadius: isSelected ? 12 : 7,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Top-Left Sequence Circle
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            width: 19,
                            height: 19,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: waypoint.isCompleted
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: Color(0xFF10B981),
                                    )
                                  : Text(
                                      seqStr,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: markerBg,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        // Bottom-Right Category Icon
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Icon(
                            _resolveCategoryIcon(),
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Tiny Anime Name Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: markerBg.withValues(alpha: 0.5), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  waypoint.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: markerBg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
