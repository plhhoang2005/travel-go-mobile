import 'package:flutter/material.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import 'ai_optimization_sheet.dart';

class LocationDetailSheet extends StatelessWidget {
  final RouteWaypoint waypoint;
  final int sequenceNumber;
  final MapProvider provider;

  const LocationDetailSheet({
    super.key,
    required this.waypoint,
    required this.sequenceNumber,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final seqStr = sequenceNumber == 0
        ? 'A'
        : (waypoint.type == 'destination'
            ? 'D'
            : sequenceNumber.toString().padLeft(2, '0'));
    final currentDay = provider.selectedDay;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Location Hero Cover
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: primaryColor.withAlpha(20),
              image: waypoint.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(waypoint.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0x99102037), Colors.transparent],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'NGÀY $currentDay · ĐIỂM $seqStr',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black.withAlpha(100),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            waypoint.category ?? (waypoint.type == 'origin' ? 'Điểm xuất phát' : 'Điểm đến'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            waypoint.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF102037),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (waypoint.rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(
                              waypoint.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Metrics Grid (3 columns)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFE6EDF5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildMetricItem(
                        icon: Icons.directions_car_rounded,
                        value: '3.5 km',
                        label: 'từ trạm trước',
                        color: primaryColor,
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        icon: Icons.schedule_rounded,
                        value: waypoint.time ?? '~15 phút',
                        label: 'thời gian đến',
                        color: primaryColor,
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        icon: Icons.wb_sunny_outlined,
                        value: waypoint.openingHours ?? '07:00–17:00',
                        label: 'đang mở cửa',
                        color: primaryColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sheet Actions
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        onPressed: () {
                          provider.toggleStopCompleted(waypoint.id);
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          waypoint.isCompleted ? 'Chưa ghé' : 'Đã ghé thăm',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF20344F)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Gợi ý tối ưu AI',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => AiOptimizationSheet(provider: provider),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102037),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF91A0B4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE6EDF5),
    );
  }
}
