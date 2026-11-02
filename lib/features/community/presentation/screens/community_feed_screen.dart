import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/community_trip.dart';
import '../../services/community_service.dart';
import '../widgets/community_trip_card.dart';
import 'shared_trip_detail_screen.dart';

/// Màn hình Bảng tin Cộng đồng (Community Feed Screen).
/// Hiển thị danh sách các chuyến đi được chia sẻ công khai bởi người dùng TravelGO.
/// Hỗ trợ tìm kiếm theo từ khóa/điểm đến, lọc theo Chip điểm đến,
/// kéo để làm mới (Pull-to-Refresh), và mở màn hình chi tiết.
class CommunityFeedScreen extends StatefulWidget {
  final CommunityService? service;

  const CommunityFeedScreen({super.key, this.service});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  late final CommunityService _service;
  final TextEditingController _searchController = TextEditingController();

  List<CommunityTrip> _allTrips = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedDestination = 'Tất cả';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    var result = _allTrips;

    // Lọc theo Chip điểm đến
    if (_selectedDestination != 'Tất cả') {
      result = result.where((trip) {
        return trip.destination.trim().toLowerCase() ==
            _selectedDestination.toLowerCase();
      }).toList();
    }

    // Lọc theo từ khóa tìm kiếm (tiêu đề hoặc điểm đến hoặc tác giả)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((trip) {
        final title = trip.title.toLowerCase();
        final dest = trip.destination.toLowerCase();
        final author = (trip.authorName ?? '').toLowerCase();
        return title.contains(query) ||
            dest.contains(query) ||
            author.contains(query);
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrips;
    final filterOptions = _destinationFilterOptions;

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cộng Đồng Xê Dịch',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Bảng tin & sao chép lịch trình thực tế',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
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
              // 1. Thanh tìm kiếm trực quan (Search Bar) chuẩn layout TravelGO
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm chuyến đi, điểm đến (Đà Nẵng, Hà Nội...)...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.slate400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.slate50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Thanh lọc điểm đến dạng Chip trượt ngang
              if (filterOptions.length > 1)
                Container(
                  height: 48,
                  color: Colors.white,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: filterOptions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
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

              // 3. Dòng chỉ số đếm số chuyến đi
              if (!_isLoading && _errorMessage == null && filtered.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hiển thị ${filtered.length} chuyến đi công khai',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate500,
                    ),
                  ),
                ),

              // 4. Thân chính: Danh sách / Đang tải / Trống / Báo lỗi
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Đang tải bảng tin cộng đồng…',
              style: TextStyle(color: AppTheme.slate500, fontSize: 13),
            ),
          ],
        ),
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
              Text(
                _searchQuery.isNotEmpty
                    ? 'Không tìm thấy chuyến đi phù hợp'
                    : 'Chưa có chuyến đi công khai nào',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Hãy thử tìm kiếm với tên thành phố hoặc từ khóa khác.'
                    : 'Hãy là người đầu tiên chia sẻ lịch trình du lịch của bạn lên cộng đồng để mọi người cùng khám phá!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.slate500),
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
