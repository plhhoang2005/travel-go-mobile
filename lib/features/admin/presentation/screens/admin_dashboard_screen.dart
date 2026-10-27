// Admin Dashboard Screen: Displays key platform statistics and registration trends.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_account_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminAccountProvider>();
      if (provider.dashboardSnapshot == null && !provider.isLoadingDashboard) {
        provider.loadDashboard(_selectedDays);
      }
    });
  }

  void _switchDays(int days) {
    if (_selectedDays == days) return;
    setState(() => _selectedDays = days);
    context.read<AdminAccountProvider>().loadDashboard(days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AdminAccountProvider>();
    final snapshot = provider.dashboardSnapshot;
    final isLoading = provider.isLoadingDashboard;
    final error = provider.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan hệ thống'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: isLoading ? null : () => provider.loadDashboard(_selectedDays),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadDashboard(_selectedDays),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Days Filter Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Khung thời gian',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7 ngày')),
                        ButtonSegment(value: 30, label: Text('30 ngày')),
                      ],
                      selected: {_selectedDays},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) _switchDays(set.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (error != null) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Không thể tải dữ liệu thống kê (${error.code})',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => provider.loadDashboard(_selectedDays),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (isLoading && snapshot == null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ] else if (snapshot != null) ...[
                  // Primary Metrics Grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'Tổng tài khoản',
                        value: NumberFormat.decimalPattern('vi').format(snapshot.totalUsers),
                        icon: Icons.people_alt_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      _StatCard(
                        title: 'Tài khoản bị khóa',
                        value: NumberFormat.decimalPattern('vi').format(snapshot.lockedUsers),
                        icon: Icons.lock_outline,
                        color: Colors.red.shade700,
                      ),
                      _StatCard(
                        title: 'Admin hoạt động',
                        value: NumberFormat.decimalPattern('vi').format(snapshot.activeAdmins),
                        icon: Icons.admin_panel_settings_outlined,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Catalogue Status Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trạng thái danh mục du lịch',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _CatalogueRow(
                            label: 'Bản nháp (Revision ${snapshot.draft.revision})',
                            detail: '${snapshot.draft.activeDestinations} điểm đến (${snapshot.draft.hiddenDestinations} ẩn), '
                                '${snapshot.draft.activePlaces} địa điểm (${snapshot.draft.hiddenPlaces} ẩn)',
                          ),
                          const Divider(height: 24),
                          _CatalogueRow(
                            label: 'Đã xuất bản (V2)',
                            detail: snapshot.published != null
                                ? 'Phiên bản ${snapshot.published!.version} (Source rev ${snapshot.published!.sourceRevision}) • '
                                    '${snapshot.published!.activeDestinations} điểm đến, ${snapshot.published!.activePlaces} địa điểm'
                                : 'Chưa có bản xuất bản chính thức',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Registration Chart
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đăng ký mới ($_selectedDays ngày)',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cập nhật lúc: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(snapshot.asOf.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 24),
                          if (snapshot.registrations.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('Không có số liệu đăng ký trong khoảng thời gian này'),
                              ),
                            )
                          else ...[
                            SizedBox(
                              height: 180,
                              child: _RegistrationLineChart(
                                points: snapshot.registrations,
                                lineColor: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Accessible breakdown table
                            ExpansionTile(
                              title: const Text('Bảng chi tiết số liệu đăng ký'),
                              children: snapshot.registrations.map((p) {
                                return ListTile(
                                  dense: true,
                                  title: Text(p.date),
                                  trailing: Text(
                                    '${p.count} người',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogueRow extends StatelessWidget {
  final String label;
  final String detail;

  const _CatalogueRow({
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade800),
        ),
      ],
    );
  }
}

class _RegistrationLineChart extends StatelessWidget {
  final List<RegistrationDayPoint> points;
  final Color lineColor;

  const _RegistrationLineChart({
    required this.points,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    double maxY = 5.0;

    for (var i = 0; i < points.length; i++) {
      final cnt = points[i].count.toDouble();
      if (cnt > maxY) maxY = cnt;
      spots.add(FlSpot(i.toDouble(), cnt));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble().clamp(1.0, 100.0),
        minY: 0,
        maxY: maxY + 2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                if (points.length > 7 && idx % (points.length ~/ 4) != 0 && idx != points.length - 1) {
                  return const SizedBox.shrink();
                }
                final parts = points[idx].date.split('-');
                final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : points[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == value.roundToDouble()) {
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
