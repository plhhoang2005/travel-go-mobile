import 'dart:math' as math;
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

    final validOptions = transportOptions.where((opt) {
      return opt.durationHours.isFinite &&
          opt.durationHours >= 0 &&
          opt.priceTotalVnd.isFinite &&
          opt.priceTotalVnd >= 0;
    }).toList();

    final excludedCount = transportOptions.length - validOptions.length;

    double maxDuration = 0.0;
    double maxPriceK = 0.0;
    for (final opt in validOptions) {
      if (opt.durationHours > maxDuration) maxDuration = opt.durationHours;
      final priceK = opt.priceTotalVnd / 1000.0;
      if (priceK > maxPriceK) maxPriceK = priceK;
    }

    final maxX = math.max(1.0, maxDuration * 1.1);
    final maxY = math.max(1.0, maxPriceK * 1.1);

    final spots = validOptions.asMap().entries.map((entry) {
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

    return SingleChildScrollView(
      child: Card(
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
              if (excludedCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Có $excludedCount phương tiện không thể vẽ do dữ liệu không hợp lệ.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: ScatterChart(
                  ScatterChartData(
                    scatterSpots: spots,
                    minX: 0,
                    maxX: maxX,
                    minY: 0,
                    maxY: maxY,
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
                      children: [
                        Icon(
                          opt.isParetoOptimal ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: opt.isParetoOptimal ? const Color(0xFF10B981) : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${opt.displayName} (${opt.tradeoffType.isNotEmpty ? opt.tradeoffType : opt.mode})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${opt.durationHours.isFinite ? opt.durationHours.toStringAsFixed(1) : "-"}h · ${opt.priceTotalVnd >= 0 ? currencyFmt.format(opt.priceTotalVnd) : "-"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
