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

    // Negative expense validation
    if (budget.transport < 0 ||
        budget.accommodation < 0 ||
        budget.food < 0 ||
        budget.attractions < 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dữ liệu chi phí phân bổ không hợp lệ (có khoản mục âm).',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // All-zero empty state
    if (budget.transport == 0 &&
        budget.accommodation == 0 &&
        budget.food == 0 &&
        budget.attractions == 0 &&
        budget.remainingSafetyMargin == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Chưa có phân bổ ngân sách dự kiến.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    final totalAllocated = budget.totalAllocated;
    final total = totalAllocated + (budget.remainingSafetyMargin > 0 ? budget.remainingSafetyMargin : 0);

    final sections = <PieChartSectionData>[];
    if (budget.transport > 0) {
      sections.add(_buildSection(budget.transport.toDouble(), const Color(0xFF0284C7)));
    }
    if (budget.accommodation > 0) {
      sections.add(_buildSection(budget.accommodation.toDouble(), const Color(0xFF8B5CF6)));
    }
    if (budget.food > 0) {
      sections.add(_buildSection(budget.food.toDouble(), const Color(0xFFF59E0B)));
    }
    if (budget.attractions > 0) {
      sections.add(_buildSection(budget.attractions.toDouble(), const Color(0xFF10B981)));
    }
    if (budget.remainingSafetyMargin > 0) {
      sections.add(_buildSection(budget.remainingSafetyMargin.toDouble(), const Color(0xFF64748B)));
    }

    final hasDeficit = budget.remainingSafetyMargin < 0;

    return SingleChildScrollView(
      child: Card(
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
              if (hasDeficit) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vượt hạn mức ngân sách: ${currencyFmt.format(budget.remainingSafetyMargin.abs())}',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (sections.isNotEmpty)
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
              if (budget.remainingSafetyMargin >= 0)
                _buildLegendItem('Dự phòng an toàn', budget.remainingSafetyMargin, const Color(0xFF64748B), total, currencyFmt)
              else
                _buildDeficitItem('Thâm hụt dự phòng', budget.remainingSafetyMargin, Colors.red, currencyFmt),
            ],
          ),
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

  Widget _buildDeficitItem(String label, int value, Color color, NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '-${fmt.format(value.abs())}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900),
          ),
        ],
      ),
    );
  }
}
