import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/trip_provider.dart';
import 'dashboard_result_screen.dart';

class HomePlannerScreen extends StatefulWidget {
  const HomePlannerScreen({super.key});

  @override
  State<HomePlannerScreen> createState() => _HomePlannerScreenState();
}

class _HomePlannerScreenState extends State<HomePlannerScreen> {
  final List<String> availablePreferences = [
    'biển',
    'ẩm thực',
    'nghỉ dưỡng',
    'núi',
    'văn hóa',
    'khám phá',
  ];

  final Map<String, String> priorityLabels = {
    'balanced': 'Cân bằng',
    'cheapest': 'Rẻ nhất',
    'fastest': 'Nhanh nhất',
    'comfortable': 'Thoải mái',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final req = provider.currentRequest;
    final currencyFmt = NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.explore, color: primaryColor),
            const SizedBox(width: 8),
            const Text('TravelGO Mobile'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: provider.isBackendOnline
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: provider.isBackendOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Text(
                  provider.isBackendOnline ? 'API Sẵn Sàng' : 'Chế Độ Dự Phòng',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: provider.isBackendOnline ? const Color(0xFF047857) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro Header
            const Text(
              'Lập Kế Hoạch Chuyến Đi Thông Minh',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Được tính toán bởi mô hình MCDA & Tối ưu hóa Pareto (Spring Boot Backend)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Quick Presets
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gợi ý kịch bản mẫu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.person, size: 16, color: Color(0xFF0284C7)),
                          label: const Text('Persona Minh (4 triệu - 3N2Đ)'),
                          onPressed: () => provider.applyPreset(1),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.beach_access, size: 16, color: Color(0xFF10B981)),
                          label: const Text('Phú Quốc (8 triệu - 4 ngày)'),
                          onPressed: () => provider.applyPreset(2),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.directions_bus, size: 16, color: Color(0xFFF59E0B)),
                          label: const Text('Vũng Tàu (1.5 triệu - 2 ngày)'),
                          onPressed: () => provider.applyPreset(3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sliders Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ngân sách tối đa:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          currencyFmt.format(req.budgetVnd),
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 16),
                        ),
                      ],
                    ),
                    Slider(
                      value: req.budgetVnd.toDouble(),
                      min: 1000000,
                      max: 15000000,
                      divisions: 28,
                      onChanged: (val) {
                        provider.updateRequest(req.copyWith(budgetVnd: val.toInt()));
                      },
                    ),

                    const SizedBox(height: 12),

                    // Num Days Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số ngày đi:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${req.numDays} ngày',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                        ),
                      ],
                    ),
                    Slider(
                      value: req.numDays.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      onChanged: (val) {
                        provider.updateRequest(req.copyWith(numDays: val.toInt()));
                      },
                    ),

                    const SizedBox(height: 12),

                    // Num People Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số lượng người:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${req.numPeople} người',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                        ),
                      ],
                    ),
                    Slider(
                      value: req.numPeople.toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      onChanged: (val) {
                        provider.updateRequest(req.copyWith(numPeople: val.toInt()));
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Preferences
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sở thích du lịch:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availablePreferences.map((pref) {
                        final isSelected = req.preferences.contains(pref);
                        return FilterChip(
                          label: Text(pref),
                          selected: isSelected,
                          onSelected: (selected) {
                            final currentList = List<String>.from(req.preferences);
                            if (selected) {
                              currentList.add(pref);
                            } else {
                              currentList.remove(pref);
                            }
                            provider.updateRequest(req.copyWith(preferences: currentList));
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Priority
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mục tiêu ưu tiên:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: priorityLabels.entries.map((entry) {
                        final isSelected = req.priority == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              provider.updateRequest(req.copyWith(priority: entry.key));
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        await provider.submitPlan();
                        if (!mounted) return;
                        if (provider.currentResponse != null) {
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => const DashboardResultScreen(),
                            ),
                          );
                        }
                      },
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt),
                label: Text(
                  provider.isLoading ? 'Đang phân tích tối ưu...' : 'Tối Ưu Hóa & Lập Kế Hoạch',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
