import 'package:flutter/material.dart';
import '../../models/map_models.dart';

class MilestoneMarkerWidget extends StatelessWidget {
  final RouteWaypoint waypoint;
  final int sequenceNumber;
  final bool isActive;
  final VoidCallback? onTap;

  const MilestoneMarkerWidget({
    super.key,
    required this.waypoint,
    required this.sequenceNumber,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isActive ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isActive ? 16 : 8),
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Color(0x55086C61),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: _buildBadgeContent(),
        ),
      ),
    );
  }

  Widget _buildBadgeContent() {
    switch (waypoint.type) {
      case 'origin':
        return _buildOriginBadge();
      case 'destination':
        return _buildDestinationBadge();
      case 'stop':
      default:
        return _buildStopCapsule();
    }
  }

  Widget _buildOriginBadge() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
      ),
      child: const Center(
        child: Icon(
          Icons.explore_outlined,
          color: Color(0xFFF59E0B),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildDestinationBadge() {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFE11D48), // Coral Rose
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.flag_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildStopCapsule() {
    final seqText = sequenceNumber.toString().padLeft(2, '0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF9), // Sand Canvas
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? const Color(0xFF086C61) : const Color(0xFFCBD5E1),
              width: isActive ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF086C61), // Emerald Teal
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    seqText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  waypoint.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.arrow_drop_down,
          color: Color(0xFF086C61),
          size: 16,
        ),
      ],
    );
  }
}
