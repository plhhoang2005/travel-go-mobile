import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';
import '../../models/editable_remote_records.dart';
import '../../models/saved_trip_model.dart';
import '../../providers/guest_drafts_provider.dart';
import '../../providers/saved_trips_provider.dart';
import '../../services/trip_list_classifier.dart';
import '../widgets/editable_draft_import_selection.dart';
import '../widgets/guest_draft_import_sheet.dart';
import 'editable_trip_detail_screen.dart';
import 'saved_trip_snapshot_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  DateTime _nowUtc = DateTime.now().toUtc();
  bool _userSelectedTab = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _userSelectedTab = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _nowUtc = DateTime.now().toUtc();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tripsProvider = context.watch<SavedTripsProvider>();

    final isGuest = !auth.isAuthenticated &&
        !auth.isDemoSession &&
        auth.currentUser == null;
    final owned = auth.isAuthenticated &&
        !auth.isDemoSession &&
        auth.currentUser?.id == tripsProvider.currentUserId;
    final visible = owned ? tripsProvider.visibleTrips : <OwnedTripSummary>[];

    final upcomingTrips = <OwnedTripSummary>[];
    final pastTrips = <OwnedTripSummary>[];
    final insufficientTrips = <OwnedTripSummary>[];

    for (final trip in visible) {
      final bucket = TripListClassifier.classify(trip, nowUtc: _nowUtc);
      switch (bucket) {
        case TripListBucket.upcomingOrOngoing:
          upcomingTrips.add(trip);
          break;
        case TripListBucket.past:
          pastTrips.add(trip);
          break;
        case TripListBucket.insufficient:
          insufficientTrips.add(trip);
          break;
      }
    }

    final hasMore = owned && tripsProvider.hasMoreTrips;
    final totalLoaded = visible.length;
    final ownerId = owned ? auth.currentUser?.id : null;

    final defaultIndex = upcomingTrips.isNotEmpty
        ? 0
        : (pastTrips.isNotEmpty
            ? 1
            : (insufficientTrips.isNotEmpty ? 2 : 0));
    if (!_userSelectedTab && _tabController.index != defaultIndex) {
      _tabController.index = defaultIndex;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Chuyến Đi Của Tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
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
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Theme.of(context).colorScheme.primary,
          isScrollable: MediaQuery.textScalerOf(context).scale(16) > 24,
          tabs: [
            Tab(text: 'Sắp/đang đi (${upcomingTrips.length})'),
            Tab(text: 'Đã qua ngày (${pastTrips.length})'),
            Tab(text: 'Chưa đủ thông tin (${insufficientTrips.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Sắp/đang đi
          _withAccountRefresh(
            isGuest
                ? EditableGuestDraftList(
                    fallback: _buildEmptyState(
                      context,
                      'Chưa có chuyến đi sắp tới',
                    ),
                  )
                : _buildTabContent(
                    context,
                    trips: upcomingTrips,
                    totalLoaded: totalLoaded,
                    emptyTitle: 'Chưa có chuyến đi sắp tới',
                    hasMore: hasMore,
                    provider: tripsProvider,
                    owned: owned,
                  ),
            ownerId: ownerId,
            provider: tripsProvider,
          ),
          // Tab 2: Đã qua ngày
          _withAccountRefresh(
            isGuest
                ? _buildEmptyState(context, 'Chưa có chuyến đi đã qua ngày')
                : _buildTabContent(
                    context,
                    trips: pastTrips,
                    totalLoaded: totalLoaded,
                    emptyTitle: 'Chưa có chuyến đi đã qua ngày',
                    hasMore: hasMore,
                    provider: tripsProvider,
                    owned: owned,
                  ),
            ownerId: ownerId,
            provider: tripsProvider,
          ),
          // Tab 3: Chưa đủ thông tin
          _withAccountRefresh(
            isGuest
                ? _buildEmptyState(context, 'Không có chuyến đi thiếu thông tin')
                : _buildTabContent(
                    context,
                    trips: insufficientTrips,
                    totalLoaded: totalLoaded,
                    emptyTitle: 'Không có chuyến đi thiếu thông tin',
                    hasMore: hasMore,
                    provider: tripsProvider,
                    owned: owned,
                  ),
            ownerId: ownerId,
            provider: tripsProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context, {
    required List<OwnedTripSummary> trips,
    required int totalLoaded,
    required String emptyTitle,
    required bool hasMore,
    required SavedTripsProvider provider,
    required bool owned,
  }) {
    if (owned && provider.isLoading && totalLoaded == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (owned && provider.cacheErrorMessage != null && totalLoaded == 0) {
      final auth = context.read<AuthProvider>();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.cacheErrorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: provider.isLoading
                    ? null
                    : () => provider.loadTrips(auth.currentUser?.id),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (trips.isEmpty) {
      if (hasMore) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.luggage_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('Đã tải $totalLoaded chuyến · còn chuyến chưa tải'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: provider.isLoading ? null : provider.loadMoreTrips,
                child: Text(provider.isLoading ? 'Đang tải…' : 'Xem thêm chuyến đi'),
              ),
            ),
          ],
        );
      }
      return _buildEmptyState(context, emptyTitle);
    }

    return _buildSavedTripsList(context, trips, totalLoaded: totalLoaded);
  }

  Widget _withAccountRefresh(
    Widget child, {
    required String? ownerId,
    required SavedTripsProvider provider,
  }) {
    if (ownerId == null) return child;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _nowUtc = DateTime.now().toUtc();
        });
        await provider.loadTrips(ownerId);
      },
      child: child,
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
    List<OwnedTripSummary> trips, {
    required int totalLoaded,
  }) {
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: trips.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == trips.length) {
          return Column(
            children: [
              Text(
                'Đã tải $totalLoaded chuyến${provider.hasMoreTrips ? ' · còn chuyến chưa tải' : ''}',
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

  Widget _buildEmptyState(BuildContext context, String title) {
    final auth = context.watch<AuthProvider>();
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.luggage_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn điểm đến và tạo lịch trình riêng, thêm hoạt động rồi theo dõi ngân sách.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (auth.isGuest || auth.currentUser == null) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập để lưu chuyến đi'),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HomePlannerScreen()),
              ),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Lập chuyến đi'),
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
          onPressed: () async {
            final trips = context.read<SavedTripsProvider>();
            final epoch = trips.sessionEpoch;
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => EditableTripDetailScreen(
                  tripId: summary.tripId,
                  expectedOwnerId: summary.ownerId,
                ),
              ),
            );
            if (!context.mounted ||
                trips.sessionEpoch != epoch ||
                trips.currentUserId != summary.ownerId) {
              return;
            }
            await trips.loadTrips(summary.ownerId);
          },
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Xem lịch trình tự lập'),
        ),
      ],
    ),
  );
}
