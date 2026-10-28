// Admin Catalogue Screen: Lists, filters, and manages draft destinations and places.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/presentation/screens/admin_publication_screen.dart';
import 'package:travelgo_mobile/features/admin/presentation/widgets/admin_destination_form.dart';
import 'package:travelgo_mobile/features/admin/presentation/widgets/admin_place_form.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';

class AdminCatalogueScreen extends StatefulWidget {
  const AdminCatalogueScreen({super.key});

  @override
  State<AdminCatalogueScreen> createState() => _AdminCatalogueScreenState();
}

class _AdminCatalogueScreenState extends State<AdminCatalogueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminCatalogueProvider>();
      if (provider.snapshot == null && !provider.isLoading) {
        provider.load();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openDestinationForm(BuildContext context, {AdminDestinationDraft? initial}) {
    final provider = context.read<AdminCatalogueProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeCtx) => AdminDestinationForm(
          initial: initial,
          errorMessageProvider: () => provider.lastErrorMessage,
          onSubmit: (draft, reason) async {
            final ok = await provider.submitDestination(draft, reason);
            if (ok && routeCtx.mounted) {
              Navigator.of(routeCtx).pop();
            }
            return ok;
          },
        ),
      ),
    );
  }

  void _openPlaceForm(BuildContext context, {AdminPlaceDraft? initial}) {
    final provider = context.read<AdminCatalogueProvider>();
    final destinations = provider.snapshot?.destinations ?? const [];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeCtx) => AdminPlaceForm(
          initial: initial,
          destinations: destinations,
          errorMessageProvider: () => provider.lastErrorMessage,
          onSubmit: (draft, reason) async {
            final ok = await provider.submitPlace(draft, reason);
            if (ok && routeCtx.mounted) {
              Navigator.of(routeCtx).pop();
            }
            return ok;
          },
        ),
      ),
    );
  }

  Future<void> _showArchiveDestinationDialog(
    BuildContext context,
    AdminDestinationDraft destination,
    int activeChildCount,
  ) async {
    final provider = context.read<AdminCatalogueProvider>();
    final reasonController = TextEditingController(text: 'Ẩn điểm đến không hoạt động');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Ẩn điểm đến ${destination.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Điểm đến này có $activeChildCount địa điểm đang hoạt động.',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
              ),
              const SizedBox(height: 12),
              const Text('Hành động này sẽ tạm ẩn điểm đến khỏi khách hàng.'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('archive_reason_field'),
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do ẩn *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('archive_cancel_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ bỏ'),
            ),
            ElevatedButton(
              key: const Key('archive_confirm_button'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận ẩn'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && destination.id != null) {
      final ok = await provider.archiveDestination(destination.id!, reasonController.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Đã ẩn và xuất bản thành công.'
                : (provider.lastErrorMessage ?? 'Lỗi khi ẩn điểm đến.')),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showArchivePlaceDialog(
    BuildContext context,
    AdminPlaceDraft place,
  ) async {
    final provider = context.read<AdminCatalogueProvider>();
    final reasonController = TextEditingController(text: 'Ẩn địa điểm');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Ẩn địa điểm ${place.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Địa điểm sẽ bị tạm ẩn khỏi ứng dụng khách hàng.'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('archive_place_reason_field'),
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do ẩn *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('archive_place_cancel_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ bỏ'),
            ),
            ElevatedButton(
              key: const Key('archive_place_confirm_button'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận ẩn'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && place.id != null) {
      final ok = await provider.archivePlace(place.id!, reasonController.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Đã ẩn và xuất bản thành công.'
                : (provider.lastErrorMessage ?? 'Lỗi khi ẩn địa điểm.')),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AdminCatalogueProvider>();
    final snapshot = provider.snapshot;
    final isLoading = provider.isLoading;
    final error = provider.error;

    final allDestinations = snapshot?.destinations ?? const [];
    final allPlaces = snapshot?.places ?? const [];

    final filteredDestinations = allDestinations.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.name.toLowerCase().contains(q) ||
          d.slug.toLowerCase().contains(q) ||
          d.region.toLowerCase().contains(q);
    }).toList();

    final filteredPlaces = allPlaces.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.slug.toLowerCase().contains(q) ||
          p.destinationId.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên tập danh mục'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: isLoading ? null : () => provider.load(),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Xuất bản danh mục',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminPublicationScreen(
                    draftRevision: provider.currentRevision,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.slate500,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: 'Điểm đến (${allDestinations.length})'),
            Tab(text: 'Địa điểm (${allPlaces.length})'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Revision banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppTheme.primarySoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Bản nháp r${provider.currentRevision}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Xuất bản', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AdminPublicationScreen(
                                draftRevision: provider.currentRevision,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider.isSaving
                        ? 'Đang lưu và xuất bản danh mục...'
                        : 'Lưu nháp không cập nhật danh mục của khách hàng cho đến khi xuất bản.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.primaryDark),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                key: const Key('catalogue_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm điểm đến hoặc địa điểm...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),

            if (isLoading && snapshot == null)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && snapshot == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          error.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Destinations list tab
                    _buildDestinationsTab(context, filteredDestinations, allPlaces),
                    // Places list tab
                    _buildPlacesTab(context, filteredPlaces),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('catalogue_add_fab'),
        onPressed: () {
          if (_tabController.index == 0) {
            _openDestinationForm(context);
          } else {
            _openPlaceForm(context);
          }
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Thêm điểm đến' : 'Thêm địa điểm'),
      ),
    );
  }

  Widget _buildStatusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? Colors.green : Colors.grey),
      ),
      child: Text(
        active ? 'Hoạt động' : 'Đã ẩn',
        style: TextStyle(
          fontSize: 10,
          color: active ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildDestinationsTab(
    BuildContext context,
    List<AdminDestinationDraft> destinations,
    List<AdminPlaceDraft> allPlaces,
  ) {
    if (destinations.isEmpty) {
      return const Center(child: Text('Không tìm thấy điểm đến nào'));
    }

    final activeCounts = <String, int>{};
    for (final p in allPlaces) {
      if (p.active && p.destinationId.isNotEmpty) {
        activeCounts[p.destinationId] = (activeCounts[p.destinationId] ?? 0) + 1;
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: destinations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final d = destinations[i];
        final activeChildCount = activeCounts[d.id ?? ''] ?? 0;

        return ListTile(
          key: Key('destination_tile_${d.id ?? i}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  d.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(d.active),
            ],
          ),
          subtitle: Text(
            '${d.region} • /${d.slug} ($activeChildCount địa điểm)',
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            key: Key('archive_destination_btn_${d.id ?? i}'),
            icon: const Icon(Icons.archive_outlined, size: 20),
            tooltip: 'Ẩn điểm đến',
            onPressed: () => _showArchiveDestinationDialog(context, d, activeChildCount),
          ),
          onTap: () => _openDestinationForm(context, initial: d),
        );
      },
    );
  }

  Widget _buildPlacesTab(
    BuildContext context,
    List<AdminPlaceDraft> places,
  ) {
    if (places.isEmpty) {
      return const Center(child: Text('Không tìm thấy địa điểm nào'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: places.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final p = places[i];

        return ListTile(
          key: Key('place_tile_${p.id ?? i}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(p.active),
            ],
          ),
          subtitle: Text(
            '${p.destinationId} • /${p.slug}',
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            key: Key('archive_place_btn_${p.id ?? i}'),
            icon: const Icon(Icons.archive_outlined, size: 20),
            tooltip: 'Ẩn địa điểm',
            onPressed: () => _showArchivePlaceDialog(context, p),
          ),
          onTap: () => _openPlaceForm(context, initial: p),
        );
      },
    );
  }
}
