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

    if (type == 'origin') return Icons.my_location_rounded;
    if (type == 'destination') return Icons.flag_rounded;

    if (cat.contains('khách sạn') || cat.contains('hotel')) return Icons.hotel_rounded;
    if (cat.contains('thác') || cat.contains('suối') || cat.contains('nước')) return Icons.water_drop_rounded;
    if (cat.contains('cà phê') || cat.contains('cafe')) return Icons.local_cafe_rounded;
    if (cat.contains('ẩm thực') || cat.contains('ăn') || cat.contains('nhà hàng')) return Icons.restaurant_rounded;
    if (cat.contains('check-in') || cat.contains('sao')) return Icons.star_rounded;
    if (cat.contains('khởi hành') || cat.contains('xe')) return Icons.directions_car_rounded;

    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Color logic from TravelGO Journey Map design
    final Color markerBg;
    if (waypoint.isCompleted) {
      markerBg = const Color(0xFF20A574); // Emerald Green Success
    } else if (isSelected) {
      markerBg = const Color(0xFF102037); // Deep Ink
    } else if (waypoint.type == 'origin') {
      markerBg = const Color(0xFF10B981);
    } else if (waypoint.type == 'destination') {
      markerBg = const Color(0xFFE11D48);
    } else {
      markerBg = colorScheme.primary; // Emerald Teal #086C61
    }

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
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Transform.rotate(
            angle: -math.pi / 4,
            child: Container(
              width: 42,
              height: 48,
              decoration: BoxDecoration(
                color: markerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(5),
                ),
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: markerBg.withAlpha(isSelected ? 110 : 70),
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
                    // Top-Left Sequence Pill / Checkmark
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
                                  color: Color(0xFF20A574),
                                )
                              : Text(
                                  seqStr,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
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
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
