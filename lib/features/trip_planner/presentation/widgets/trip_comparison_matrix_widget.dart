import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip_response.dart';

class TripComparisonMatrixWidget extends StatelessWidget {
  final PlanTripResponse response;
  final int? requestedBudgetVnd;
  final int baseBudgetVnd;

  const TripComparisonMatrixWidget({
    super.key,
    required this.response,
    this.requestedBudgetVnd,
    this.baseBudgetVnd = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);

    final destinations = response.topDestinations;
    final transports = response.transportOptions;

    if (destinations.isEmpty && transports.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.compare_arrows, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Chưa có phương án so sánh',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'So Sánh Phương Án Thực Tế',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requestedBudgetVnd != null
                          ? 'Ngân sách yêu cầu: ${currencyFmt.format(requestedBudgetVnd)}'
                          : 'Chưa có ngân sách đầu vào',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 1. Destinations comparison
        if (destinations.isNotEmpty) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.place_outlined, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Điểm Đến Đề Xuất (Theo Xếp Hạng)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...destinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dest = entry.value;
                    final isWinner = dest.id == response.winnerId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isWinner ? const Color(0xFFF0F9FF) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isWinner ? const Color(0xFF0284C7) : Colors.grey.shade200,
                          width: isWinner ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isWinner ? const Color(0xFF0284C7) : Colors.grey.shade600,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isWinner ? 'Hạng #${index + 1} · Lựa chọn tối ưu' : 'Hạng #${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dest.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                '${dest.totalScore.toStringAsFixed(1)} điểm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isWinner ? const Color(0xFF0284C7) : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Khu vực: ${dest.region}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Chi phí ước tính: ${currencyFmt.format(dest.estimatedCostVnd)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (dest.avgTempMax > 0 || dest.weatherSource.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Thời tiết: ${dest.avgTempMax.toStringAsFixed(0)}°C · Mưa: ${(dest.avgPrecipitation * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],

        // 2. Transport options comparison
        if (transports.isNotEmpty) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.directions_bus_outlined, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Phương Tiện Di Chuyển',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '* Chi phí hiển thị là tổng chi phí di chuyển cho cả nhóm.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  ...transports.map((opt) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: opt.isParetoOptimal ? const Color(0xFFECFDF5) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: opt.isParetoOptimal ? const Color(0xFF10B981) : Colors.grey.shade200,
                          width: opt.isParetoOptimal ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (opt.isParetoOptimal) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Pareto',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  opt.displayName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                currencyFmt.format(opt.priceTotalVnd),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Thời gian: ${opt.durationHours.toStringAsFixed(1)} giờ · Tiện nghi: ${opt.comfortScore}/10',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (opt.tradeoffType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    opt.tradeoffType,
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          ),
                          if (opt.recommendationReason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              opt.recommendationReason,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
