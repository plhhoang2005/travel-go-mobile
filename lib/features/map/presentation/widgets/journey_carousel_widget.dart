import 'package:flutter/material.dart';
import '../../models/map_models.dart';

class JourneyCarouselWidget extends StatelessWidget {
  final List<RouteWaypoint> waypoints;
  final int activeIndex;
  final ValueChanged<int> onCardChanged;
  final PageController pageController;

  const JourneyCarouselWidget({
    super.key,
    required this.waypoints,
    required this.activeIndex,
    required this.onCardChanged,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    if (waypoints.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: PageView.builder(
        controller: pageController,
        itemCount: waypoints.length,
        onPageChanged: onCardChanged,
        itemBuilder: (context, index) {
          final wp = waypoints[index];
          final isActive = index == activeIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF9), // Sand Canvas
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? const Color(0xFF086C61) : const Color(0xFFE2E8F0),
                width: isActive ? 2.0 : 1.0,
              ),
              boxShadow: isActive
                  ? const [
                      BoxShadow(
                        color: Color(0x1F086C61),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Opacity(
              opacity: isActive ? 1.0 : 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _badgeColor(wp.type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _badgeLabel(wp.type, index + 1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wp.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12, thickness: 0.5, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            wp.time != null && wp.time!.isNotEmpty ? wp.time! : 'Thời gian: —',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.navigation_outlined, size: 13, color: Color(0xFF086C61)),
                          const SizedBox(width: 4),
                          Text(
                            'Chặng ${index + 1}/${waypoints.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF086C61),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _badgeColor(String type) {
    switch (type) {
      case 'origin':
        return const Color(0xFFF59E0B);
      case 'destination':
        return const Color(0xFFE11D48);
      case 'stop':
      default:
        return const Color(0xFF086C61);
    }
  }

  String _badgeLabel(String type, int seq) {
    switch (type) {
      case 'origin':
        return 'XUẤT PHÁT';
      case 'destination':
        return 'ĐÍCH ĐẾN';
      case 'stop':
      default:
        return 'MỐC ${seq.toString().padLeft(2, '0')}';
    }
  }
}
