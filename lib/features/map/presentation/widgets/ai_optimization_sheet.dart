import 'package:flutter/material.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';

class AiOptimizationSheet extends StatelessWidget {
  final MapProvider provider;

  const AiOptimizationSheet({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    final waypoints = provider.waypoints;
    final canOptimize = waypoints.length >= 2;

    // Simulated Greedy reordering for demonstration
    final List<RouteWaypoint> optimizedWaypoints = canOptimize
        ? List<RouteWaypoint>.from(waypoints.reversed)
        : List<RouteWaypoint>.from(waypoints);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRAVEL-GO AI OPTIMIZER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Có thể tối ưu lộ trình',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102037),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            'Mô hình Greedy TSP phát hiện tuyến đường ngắn hơn nếu hoán đổi thứ tự ghé thăm giữa các trạm dừng.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5E718B),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 14),

          // Saving Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1FBF7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCFE9DF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tiết kiệm 3.8 km',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF157E5B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ít đi vòng lại hơn',
                        style: TextStyle(fontSize: 11, color: Color(0xFF5E718B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFCFE9DF),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '~12 phút',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF157E5B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Thời gian di chuyển',
                        style: TextStyle(fontSize: 11, color: Color(0xFF5E718B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Route Sequence Preview
          const Text(
            'THỨ TỰ ĐỀ XUẤT:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF91A0B4),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: List.generate(optimizedWaypoints.length, (index) {
                final wp = optimizedWaypoints[index];
                final seqStr = (index + 1).toString().padLeft(2, '0');
                final isLast = index == optimizedWaypoints.length - 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            seqStr,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          wp.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF102037),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: Color(0xFF91A0B4),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Giữ hiện tại', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF20A574),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Chấp nhận', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await provider.applyAiReorder(optimizedWaypoints);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Đã cập nhật hành trình tối ưu AI'),
                          backgroundColor: Color(0xFF20A574),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
