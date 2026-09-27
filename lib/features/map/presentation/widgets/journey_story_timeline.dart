import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';

class JourneyStoryTimeline extends StatelessWidget {
  final MapProvider provider;
  final ValueChanged<RouteWaypoint> onStopSelected;

  const JourneyStoryTimeline({
    super.key,
    required this.provider,
    required this.onStopSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final currentDay = provider.selectedDay;
    final stops = provider.currentDayStops;
    final route = provider.currentRoute;
    final distanceStr = route != null ? route.formattedDistance : 'Chưa tính';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(245),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6EDF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18102037),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Story Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOURNEY STORY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ngày $currentDay của bạn',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF102037),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      distanceStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE6EDF5)),
              const SizedBox(height: 12),

              // Timeline List
              Expanded(
                child: ListView.builder(
                  itemCount: stops.length,
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final isLast = index == stops.length - 1;
                    final isCompleted = stop.isCompleted;

                    return InkWell(
                      onTap: () => onStopSelected(stop),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Time
                            SizedBox(
                              width: 48,
                              child: Text(
                                stop.time ?? '--:--',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5E718B),
                                ),
                              ),
                            ),

                            // 2. Timeline Track
                            SizedBox(
                              width: 32,
                              child: Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? const Color(0xFF20A574)
                                          : primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x20000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: isCompleted
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 13,
                                              color: Colors.white,
                                            )
                                          : Text(
                                              (index + 1).toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 36,
                                      color: const Color(0xFFDCECF8),
                                    ),
                                ],
                              ),
                            ),

                            // 3. Content
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF102037),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    stop.category ?? (stop.type == 'origin' ? 'Điểm xuất phát' : 'Điểm đến'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF91A0B4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 4. Trailing Arrow
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF91A0B4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
