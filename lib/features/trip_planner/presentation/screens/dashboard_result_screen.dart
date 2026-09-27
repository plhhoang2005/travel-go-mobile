import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/trip_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/pareto_chart_widget.dart';
import '../widgets/budget_donut_chart.dart';
import '../widgets/itinerary_timeline_widget.dart';
import '../widgets/trip_comparison_matrix_widget.dart';
import 'package:latlong2/latlong.dart';
import '../../../map/presentation/screens/trip_map_screen.dart';

class DashboardResultScreen extends StatefulWidget {
  const DashboardResultScreen({super.key});

  @override
  State<DashboardResultScreen> createState() => _DashboardResultScreenState();
}

class _DashboardResultScreenState extends State<DashboardResultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final res = provider.currentResponse;

    if (res == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kết Quả Lập Kế Hoạch')),
        body: const Center(child: Text('Chưa có dữ liệu kế hoạch chuyến đi.')),
      );
    }

    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);
    final winner = res.topDestinations.isNotEmpty ? res.topDestinations.first : null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo Tối Ưu Hóa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Xem Bản Đồ & Radar Nhóm',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripMapScreen(
                    initialDestination: (winner != null && winner.latitude != null && winner.longitude != null)
                        ? LatLng(winner.latitude!, winner.longitude!)
                        : null,
                    initialDestinationName: winner?.name,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: AppTheme.slate700,
          indicatorColor: primaryColor,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Đánh Đổi Pareto', icon: Icon(Icons.auto_graph, size: 20)),
            Tab(text: 'Ngân Sách', icon: Icon(Icons.pie_chart, size: 20)),
            Tab(text: 'Lịch Trình', icon: Icon(Icons.calendar_month, size: 20)),
            Tab(text: 'So Sánh Phương Án', icon: Icon(Icons.compare_arrows, size: 20)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Law 3: Zero Silent Fallback Banner
            if (res.isFallback)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ĐANG DÙNG DỮ LIỆU NGOẠI TUYẾN [FALLBACK]\n${res.dataSources['reason'] ?? 'Backend Spring Boot chưa sẵn sàng'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Winner Destination Hero Card (MCDA Result)
            if (winner != null)
              Card(
                color: primaryColor,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'ĐIỂM ĐẾN TỐI ƯU NHẤT (MCDA)',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${winner.totalScore.toStringAsFixed(2)} / 10',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        winner.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vùng: ${winner.region} · Dự kiến: ${currencyFmt.format(winner.estimatedCostVnd)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny_outlined, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Nhiệt độ: ${winner.avgTempMax}°C · Mưa: ${winner.avgPrecipitation}mm',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TripMapScreen(
                                  initialDestination: (winner.latitude != null && winner.longitude != null)
                                      ? LatLng(winner.latitude!, winner.longitude!)
                                      : null,
                                  initialDestinationName: winner.name,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text(
                            'Xem Lộ Trình Bản Đồ & Radar Nhóm',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // Law 4: AI Explanation Card
            if (res.aiExplanation.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome, color: primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thuyết Minh Quyết Định (AI Explainer)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              res.aiExplanation,
                              style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.slate700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            // Tab View Body
            SizedBox(
              height: 490,
              child: TabBarView(
                controller: _tabController,
                children: [
                  ParetoChartWidget(transportOptions: res.transportOptions),
                  if (res.budgetBreakdown != null)
                    BudgetDonutChartWidget(budget: res.budgetBreakdown!)
                  else
                    const Center(child: Text('Không có dữ liệu phân bổ')),
                  SingleChildScrollView(
                    child: ItineraryTimelineWidget(itineraryDays: res.itineraryDays),
                  ),
                  SingleChildScrollView(
                    child: TripComparisonMatrixWidget(
                      baseBudgetVnd: res.budgetBreakdown?.totalAllocated ?? 4000000,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
