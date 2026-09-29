import 'dart:ui';
import 'package:flutter/material.dart';
import '../../providers/map_provider.dart';

class JourneyTripCard extends StatelessWidget {
  final MapProvider provider;

  const JourneyTripCard({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final destName = provider.destinationName ?? 'Khám Phá';
    final totalDays = provider.totalDays;
    final currentDay = provider.selectedDay;
    final dayStops = provider.currentDayStops;
    final route = provider.currentRoute;

    final distanceStr = route != null ? route.formattedDistance : 'Chưa tính';
    final durationStr = route != null ? route.formattedDuration : 'Chưa tính';
    final routeSource = route == null ? 'CHƯA TÍNH' : (route.isFallback ? 'FALLBACK' : 'OSRM');
    final sourceColor = route?.isFallback == true ? const Color(0xFFD97706) : primaryColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(235),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(160)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18102037),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eyebrow & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHUYẾN ĐI CỦA MINH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF102037),
                            ),
                            children: [
                              TextSpan(text: destName),
                              TextSpan(
                                text: ' · $totalDays ngày',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF5E718B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${provider.originName} → $destName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5E718B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sourceColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route_rounded, size: 14, color: sourceColor),
                        const SizedBox(width: 4),
                        Text(
                          routeSource,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: sourceColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Day Selector Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: List.generate(totalDays, (index) {
                    final dayNum = index + 1;
                    final isActive = currentDay == dayNum;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => provider.selectDay(dayNum),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isActive ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withAlpha(60),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'NGÀY $dayNum',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isActive ? Colors.white : const Color(0xFF5E718B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 10),

              // Journey Summary Row
              Row(
                children: [
                  Text(
                    '${dayStops.length} điểm dừng',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF20344F),
                    ),
                  ),
                  _buildDot(),
                  Text(
                    distanceStr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF20344F),
                    ),
                  ),
                  _buildDot(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car_rounded, size: 14, color: Color(0xFF5E718B)),
                      const SizedBox(width: 3),
                      Text(
                        durationStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF20344F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: Color(0xFF91A0B4),
        shape: BoxShape.circle,
      ),
    );
  }
}
