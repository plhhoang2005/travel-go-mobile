import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/community_trip.dart';
import '../../services/community_service.dart';
import '../widgets/community_trip_card.dart';
import 'shared_trip_detail_screen.dart';

/// Màn hình Bảng tin Cộng đồng (Community Feed Screen).
/// Hiển thị danh sách các chuyến đi được chia sẻ công khai bởi người dùng TravelGO.
/// Hỗ trợ kéo để làm mới (Pull-to-Refresh), lọc theo điểm đến, và mở màn hình chi tiết.
class CommunityFeedScreen extends StatefulWidget {
  final CommunityService? service;

  const CommunityFeedScreen({super.key, this.service});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  late final CommunityService _service;

  List<CommunityTrip> _allTrips = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedDestination = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final trips = await _service.fetchPublicTrips();
      if (mounted) {
        setState(() {
          _allTrips = trips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Không thể tải bảng tin cộng đồng. Vui lòng kiểm tra kết nối mạng.';
          _isLoading = false;
        });
      }
    }
  }

  List<String> get _destinationFilterOptions {
    final destinations = <String>{'Tất cả'};
    for (final trip in _allTrips) {
      final dest = trip.destination.trim();
      if (dest.isNotEmpty) {
        destinations.add(dest);
      }
    }
    return destinations.toList();
  }

  List<CommunityTrip> get _filteredTrips {
    if (_selectedDestination == 'Tất cả') {
      return _allTrips;
    }
    return _allTrips.where((trip) {
      return trip.destination.trim().toLowerCase() ==
          _selectedDestination.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrips;
    final filterOptions = _destinationFilterOptions;

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: const Text(
          'Cộng Đồng Xê Dịch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadTrips,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTrips,
          child: Column(
            children: [
              // Thanh lọc điểm đến dạng Chip trượt ngang
              if (filterOptions.length > 1)
                Container(
                  height: 52,
                  color: Colors.white,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filterOptions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final option = filterOptions[index];
                      final isSelected = _selectedDestination == option;
                      return ChoiceChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedDestination = option);
                        },
                        selectedColor: AppTheme.primarySoft,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.slate700,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    },
                  ),
                ),

              // Thân chính: Danh sách / Đang tải / Trống / Báo lỗi
              Expanded(
                child: _buildBody(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<CommunityTrip> trips) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppTheme.slate400,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.slate700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTrips,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (trips.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có chuyến đi công khai nào',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy là người đầu tiên chia sẻ lịch trình du lịch của bạn lên cộng đồng để mọi người cùng khám phá!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.slate500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return CommunityTripCard(
          trip: trip,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SharedTripDetailScreen(
                  trip: trip,
                  service: _service,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
