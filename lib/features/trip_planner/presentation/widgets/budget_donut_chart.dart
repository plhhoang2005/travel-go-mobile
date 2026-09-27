import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/trip_response.dart';

class BudgetDonutChartWidget extends StatelessWidget {
  final BudgetBreakdown budget;

  const BudgetDonutChartWidget({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);
    final total = budget.totalAllocated + budget.remainingSafetyMargin;

    if (total <= 0) return const SizedBox.shrink();

    final sections = [
      _buildSection(budget.transport.toDouble(), const Color(0xFF0284C7)),
      _buildSection(budget.accommodation.toDouble(), const Color(0xFF8B5CF6)),
      _buildSection(budget.food.toDouble(), const Color(0xFFF59E0B)),
      _buildSection(budget.attractions.toDouble(), const Color(0xFF10B981)),
      _buildSection(budget.remainingSafetyMargin.toDouble(), const Color(0xFF64748B)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.pie_chart, color: Color(0xFF0284C7), size: 20),
                SizedBox(width: 8),
                Text(
                  'Phân Bổ Ngân Sách Dự Kiến',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegendItem('Di chuyển', budget.transport, const Color(0xFF0284C7), total, currencyFmt),
            _buildLegendItem('Khách sạn', budget.accommodation, const Color(0xFF8B5CF6), total, currencyFmt),
            _buildLegendItem('Ăn uống', budget.food, const Color(0xFFF59E0B), total, currencyFmt),
            _buildLegendItem('Vé tham quan', budget.attractions, const Color(0xFF10B981), total, currencyFmt),
            _buildLegendItem('Dự phòng an toàn', budget.remainingSafetyMargin, const Color(0xFF64748B), total, currencyFmt),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _buildSection(double value, Color color) {
    return PieChartSectionData(
      color: color,
      value: value,
      title: '',
      radius: 35,
    );
  }

  Widget _buildLegendItem(String label, int value, Color color, int total, NumberFormat fmt) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$pct%  ', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(fmt.format(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
