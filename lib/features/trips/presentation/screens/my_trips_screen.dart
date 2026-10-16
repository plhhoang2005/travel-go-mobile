import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';
import '../../models/saved_trip_model.dart';
import '../../models/editable_remote_records.dart';
import 'editable_trip_detail_screen.dart';
import '../../providers/guest_drafts_provider.dart';
import '../../providers/saved_trips_provider.dart';
import '../widgets/guest_draft_import_sheet.dart';
import 'saved_trip_snapshot_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tripsProvider = context.watch<SavedTripsProvider>();
    final isCustomer =
        auth.isDemoSession &&
        (auth.currentUser?.email.contains('minh') ?? false);

    final owned =
        auth.isAuthenticated &&
        !auth.isDemoSession &&
        auth.currentUser?.id == tripsProvider.currentUserId;
    final visible = owned ? tripsProvider.visibleTrips : <OwnedTripSummary>[];
    final upcomingCount = visible.isNotEmpty
        ? visible.length
        : (isCustomer ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Chuyến Đi Của Tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (auth.isAuthenticated && !auth.isDemoSession)
            IconButton(
              tooltip: 'Chuyển bản nháp Guest',
              onPressed: () => _openGuestImport(context, auth.currentUser!.id),
              icon: const Icon(Icons.move_to_inbox_outlined),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: AppTheme.slate500,
          indicatorColor: const Color(0xFF0F172A),
          tabs: [
            Tab(text: 'Sắp đi ($upcomingCount)'),
            const Tab(text: 'Đã đi (0)'),
            const Tab(text: 'Đã hủy (0)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Upcoming Tab
          visible.isNotEmpty || (owned && tripsProvider.hasMoreTrips)
              ? _buildSavedTripsList(context, visible)
              : owned &&
                    (tripsProvider.isLoading ||
                        tripsProvider.cacheErrorMessage != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tripsProvider.isLoading
                              ? 'Đang tải chuyến đi…'
                              : tripsProvider.cacheErrorMessage!,
                        ),
                        TextButton(
                          onPressed: tripsProvider.isLoading
                              ? null
                              : () => tripsProvider.loadTrips(
                                  auth.currentUser?.id,
                                ),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : (isCustomer
                    ? _buildUpcomingDemoCard(context)
                    : _buildEmptyState(context, 'Chưa có chuyến đi sắp tới')),
          // Completed Tab
          _buildEmptyState(context, 'Chưa có chuyến đi đã hoàn thành'),
          // Cancelled Tab
          _buildEmptyState(context, 'Chưa có chuyến đi bị hủy'),
        ],
      ),
    );
  }

  Future<void> _openGuestImport(BuildContext context, String ownerId) async {
    GuestDraftsProvider? drafts;
    try {
      drafts = context.read<GuestDraftsProvider?>();
    } on ProviderNotFoundException catch (_) {
      drafts = null;
    }
    if (drafts == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bản nháp trên máy chưa sẵn sàng.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          GuestDraftImportSheet(drafts: drafts!, expectedOwnerId: ownerId),
    );
  }

  Widget _buildSavedTripsList(
    BuildContext context,
    List<OwnedTripSummary> trips,
  ) {
    final provider = context.watch<SavedTripsProvider>();
    final canDelete =
        !provider.requiresLifecycle ||
        provider.cacheState == AccountCacheState.online;
    final statusLabel = switch (provider.cacheState) {
      AccountCacheState.offline => 'BẢN TRÊN MÁY · NGOẠI TUYẾN',
      AccountCacheState.online => 'ĐÃ LƯU TRÊN CLOUD',
      _ when !provider.requiresLifecycle => 'ĐÃ LƯU TRÊN CLOUD',
      _ => 'CHƯA KIỂM TRA ĐƯỢC SERVER',
    };
    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == trips.length) {
          return Column(
            children: [
              Text(
                'Đã tải ${trips.length} chuyến${provider.hasMoreTrips ? ' · còn chuyến chưa tải' : ''}',
              ),
              if (provider.cacheErrorMessage != null)
                Text(provider.cacheErrorMessage!),
              if (provider.hasMoreTrips)
                TextButton(
                  onPressed: provider.isLoading ? null : provider.loadMoreTrips,
                  child: Text(
                    provider.isLoading ? 'Đang tải…' : 'Xem thêm chuyến đi',
                  ),
                ),
            ],
          );
        }
        final summary = trips[index];
        if (summary.kind == OwnedTripKind.editableV2) {
          return _EditableTripRow(summary: summary, status: statusLabel);
        }
        final matches = provider.trips.where(
          (t) => t.id == summary.tripId && t.userId == summary.ownerId,
        );
        if (matches.isEmpty) return const SizedBox.shrink();
        final trip = matches.first;
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          trip.numDays == null
                              ? 'Chưa có số ngày'
                              : '${trip.numDays} Ngày',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Color(0xFFEF4444),
                          ),
                          tooltip: 'Xóa chuyến đi',
                          onPressed: canDelete
                              ? () => _confirmDeleteTrip(context, trip)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  trip.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Điểm đến: ${trip.destinationName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trip.createdAt == null
                      ? 'Chưa có thời điểm lưu'
                      : 'Đã lưu: ${DateFormat('dd/MM/yyyy HH:mm').format(trip.createdAt!.toLocal())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate600,
                  ),
                ),
                const Divider(height: 24, color: AppTheme.slate100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng dự toán:',
                      style: TextStyle(fontSize: 13, color: AppTheme.slate600),
                    ),
                    Text(
                      trip.budgetTotal == null
                          ? 'Chưa có ngân sách'
                          : currencyFmt.format(trip.budgetTotal),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SavedTripSnapshotScreen(
                          tripId: trip.id,
                          expectedOwnerId: trip.userId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Xem lịch trình đã lưu'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingDemoCard(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ĐÃ XÁC NHẬN',
                        style: TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Text(
                      'Mã đơn: #TG-2026-001',
                      style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chuyến đi Đà Nẵng 3N2Đ (Persona Minh)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Khởi hành: 20/10/2026 - 23/10/2026 · 2 Người lớn',
                  style: TextStyle(fontSize: 12, color: AppTheme.slate600),
                ),
                const Divider(height: 24, color: AppTheme.slate100),
                Row(
                  children: const [
                    Icon(
                      Icons.flight_takeoff,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Vé máy bay khứ hồi VietJet Air',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.hotel, size: 16, color: Color(0xFF0D9488)),
                    SizedBox(width: 6),
                    Text(
                      'Furama Resort Đà Nẵng (2 đêm)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Tổng thanh toán:',
                      style: TextStyle(fontSize: 13, color: AppTheme.slate600),
                    ),
                    Text(
                      '4.200.000đ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String title) {
    final auth = context.watch<AuthProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.luggage_outlined,
                size: 40,
                color: AppTheme.slate400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Để AI gợi ý hành trình tối ưu chi phí & thời gian cho chuyến đi sắp tới của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.slate500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (auth.isGuest || auth.currentUser == null) ...[
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Đăng nhập để xem chuyến đi'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF086C61),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HomePlannerScreen()),
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Lập kế hoạch với AI ngay'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0F172A)),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTrip(BuildContext context, SavedTrip trip) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Xóa Chuyến Đi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa chuyến đi "${trip.title}" không? Thao tác này sẽ xóa dữ liệu trên máy chủ.',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.slate700,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final tripsProvider = context.read<SavedTripsProvider>();
              final auth = context.read<AuthProvider>();
              final success = await tripsProvider.deleteTrip(trip.id);
              if (context.mounted) {
                if (success) {
                  // Reload to verify server state
                  await tripsProvider.loadTrips(auth.currentUser?.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa chuyến đi thành công'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tripsProvider.errorMessage ?? 'Xóa chuyến đi thất bại',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _EditableTripRow extends StatelessWidget {
  final OwnedTripSummary summary;
  final String status;
  const _EditableTripRow({required this.summary, required this.status});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Text(summary.title, style: Theme.of(context).textTheme.titleMedium),
        Text('Điểm đến: ${summary.destinationName}'),
        const Text('Lịch trình tự lập · có dự kiến và sổ chi riêng'),
        if (summary.createdAt.millisecondsSinceEpoch != 0)
          Text(
            'Đã lưu: ${DateFormat('dd/MM/yyyy HH:mm').format(summary.createdAt.toLocal())}',
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => EditableTripDetailScreen(
                tripId: summary.tripId,
                expectedOwnerId: summary.ownerId,
              ),
            ),
          ),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Xem lịch trình tự lập'),
        ),
      ],
    ),
  );
}
