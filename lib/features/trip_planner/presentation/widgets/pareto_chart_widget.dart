import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/trip_response.dart';

class ParetoChartWidget extends StatelessWidget {
  final List<TransportOption> transportOptions;

  const ParetoChartWidget({
    super.key,
    required this.transportOptions,
  });

  @override
  Widget build(BuildContext context) {
    if (transportOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final currencyFmt = NumberFormat.compact(locale: 'vi');

    // Scatter spot points: x = durationHours, y = priceTotalVnd / 1000
    final spots = transportOptions.asMap().entries.map((entry) {
      final opt = entry.value;
      return ScatterSpot(
        opt.durationHours,
        opt.priceTotalVnd / 1000.0,
        show: true,
        dotPainter: FlDotCirclePainter(
          radius: opt.isParetoOptimal ? 9 : 6,
          color: opt.isParetoOptimal ? const Color(0xFF10B981) : Colors.grey,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_graph, color: Color(0xFF0284C7), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đánh Đổi Pareto (Thời Gian vs Chi Phí)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Các phương tiện màu xanh lá cây nằm trên đường biên Pareto tối ưu.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: ScatterChart(
                ScatterChartData(
                  scatterSpots: spots,
                  minX: 0,
                  maxX: 12,
                  minY: 0,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Thời gian (Giờ)', style: TextStyle(fontSize: 11)),
                      sideTitles: const SideTitles(showTitles: true, reservedSize: 22),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Chi phí (k VNĐ)', style: TextStyle(fontSize: 11)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (val, meta) => Text(
                          currencyFmt.format(val * 1000),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: true),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: transportOptions.map((opt) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4.0),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: opt.isParetoOptimal ? const Color(0xFF10B981) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${opt.displayName} (${opt.durationHours}h - ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(opt.priceTotalVnd)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: opt.isParetoOptimal ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
