import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../../services/destination_catalog_service.dart';
import 'ai_optimization_sheet.dart';

class RouteBuilderSheet extends StatefulWidget {
  const RouteBuilderSheet({super.key});

  @override
  State<RouteBuilderSheet> createState() => _RouteBuilderSheetState();
}

class _RouteBuilderSheetState extends State<RouteBuilderSheet> {
  final TextEditingController _destinationSearchController = TextEditingController();
  final DestinationCatalogService _catalogService = DestinationCatalogService();
  String _destinationQuery = '';

  @override
  void dispose() {
    _destinationSearchController.dispose();
    super.dispose();
  }

  void _showAddWaypointSheet(BuildContext parentContext, MapProvider provider) {
    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _WaypointPickerModal(
          catalogService: _catalogService,
          currentDestination: provider.destination,
          onSelected: (Destination item) {
            final wp = RouteWaypoint(
              id: 'wp_${DateTime.now().millisecondsSinceEpoch}',
              title: item.name,
              position: item.position,
              type: 'stop',
            );
            provider.addWaypoint(wp);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  void _showOriginPickerSheet(BuildContext parentContext, MapProvider provider) {
    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _WaypointPickerModal(
          title: 'Chọn Điểm Xuất Phát',
          catalogService: _catalogService,
          currentDestination: provider.destination,
          onUseCurrentLocation: () {
            provider.useCurrentLocationAsOrigin();
            Navigator.of(ctx).pop();
          },
          onSelected: (Destination item) {
            provider.setOrigin(item.position, item.name);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<MapProvider>(
      builder: (context, provider, _) {
        final searchResults = _catalogService.search(_destinationQuery);

        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withAlpha(128),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kế Hoạch Lộ Trình',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable Body
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        // SECTION 1: Origin
                        _buildSectionHeader('XUẤT PHÁT', const Color(0xFF10B981), Icons.my_location),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.trip_origin_rounded, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.originName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.isUsingCurrentLocation
                                          ? (provider.isMockGps
                                              ? 'Tọa độ mặc định · GPS chưa khả dụng'
                                              : 'Vị trí GPS hiện tại')
                                          : 'Điểm xuất phát tùy chọn',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.outline,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
                                color: const Color(0xFF10B981),
                                tooltip: 'Đổi điểm xuất phát',
                                onPressed: () => _showOriginPickerSheet(context, provider),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // SECTION 2: Destination
                        _buildSectionHeader('ĐIỂM ĐẾN', const Color(0xFFE11D48), Icons.location_on),
                        const SizedBox(height: 8),
                        if (provider.destination == null) ...[
                          TextField(
                            controller: _destinationSearchController,
                            decoration: InputDecoration(
                              hintText: 'Bạn muốn đi đâu?',
                              hintStyle: TextStyle(color: colorScheme.outline),
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _destinationQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _destinationSearchController.clear();
                                        setState(() => _destinationQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                              ),
                            ),
                            onChanged: (val) => setState(() => _destinationQuery = val),
                          ),
                          const SizedBox(height: 8),
                          // Search Results List
                          Material(
                            color: colorScheme.surfaceContainerHighest.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: searchResults.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
                                itemBuilder: (context, idx) {
                                  final dest = searchResults[idx];
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(dest.icon, color: colorScheme.primary, size: 20),
                                    title: Text(dest.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(dest.region, style: TextStyle(color: colorScheme.outline, fontSize: 11)),
                                    onTap: () {
                                      provider.setDestination(dest.position, dest.name);
                                      _destinationSearchController.clear();
                                      setState(() => _destinationQuery = '');
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48).withAlpha(16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE11D48).withAlpha(60)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.place_rounded, color: Color(0xFFE11D48), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.destinationName ?? 'Điểm đến',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Điểm kết thúc hành trình',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.outline,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  tooltip: 'Bỏ chọn',
                                  onPressed: () {
                                    provider.enterLocateOnlyMode();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // SECTION 3: Waypoints
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader(
                              'TRẠM DỪNG (${provider.waypoints.length})',
                              const Color(0xFFF59E0B),
                              Icons.alt_route_rounded,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (provider.waypoints.length >= 2) ...[
                                  TextButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => AiOptimizationSheet(provider: provider),
                                      );
                                    },
                                    icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF20A574)),
                                    label: const Text(
                                      'Tối ưu AI',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF20A574),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.only(right: 6),
                                    ),
                                  ),
                                ],
                                TextButton.icon(
                                  onPressed: () => _showAddWaypointSheet(context, provider),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                  label: const Text('Thêm trạm'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (provider.waypoints.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Chưa có điểm dừng chân giữa chặng',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                            ),
                          )
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: provider.waypoints.length,
                            onReorderItem: (oldIndex, newIndex) {
                              provider.reorderWaypoints(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final wp = provider.waypoints[index];
                              final seqStr = (index + 1).toString().padLeft(2, '0');
                              return Container(
                                key: ValueKey(wp.id.isNotEmpty ? wp.id : 'wp_$index'),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withAlpha(60),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          size: 20,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        seqStr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        wp.title,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<int>(
                                      initialValue: wp.dayNumber,
                                      tooltip: 'Chọn ngày',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 100),
                                      onSelected: (int selectedDay) {
                                        provider.updateWaypointDay(index, selectedDay);
                                      },
                                      itemBuilder: (context) => [
                                        for (int d = 1; d <= 5; d++)
                                          PopupMenuItem<int>(
                                            value: d,
                                            height: 36,
                                            child: Text('Ngày $d', style: const TextStyle(fontSize: 13)),
                                          ),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withAlpha(20),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'N${wp.dayNumber}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down_rounded,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                      color: colorScheme.error,
                                      tooltip: 'Xóa điểm dừng',
                                      onPressed: () => provider.removeWaypoint(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // SECTION 4: Action Button
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.route_rounded),
                          label: Text(
                            provider.isLoading ? 'ĐANG TÍNH TOÁN...' : 'VẼ LỘ TRÌNH',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          onPressed: (!provider.canBuildRoute || provider.isLoading)
                              ? null
                              : () async {
                                  await provider.buildRoute();
                                  if (context.mounted && provider.currentRoute != null) {
                                    Navigator.of(context).pop();
                                  }
                                },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WaypointPickerModal extends StatefulWidget {
  final String title;
  final DestinationCatalogService catalogService;
  final LatLng? currentDestination;
  final VoidCallback? onUseCurrentLocation;
  final ValueChanged<Destination> onSelected;

  const _WaypointPickerModal({
    this.title = 'Chọn Trạm Dừng Chân',
    required this.catalogService,
    required this.currentDestination,
    this.onUseCurrentLocation,
    required this.onSelected,
  });

  @override
  State<_WaypointPickerModal> createState() => _WaypointPickerModalState();
}

class _WaypointPickerModalState extends State<_WaypointPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final results = widget.catalogService.search(_query);

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 440,
        child: Column(
          children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm địa điểm, tỉnh thành...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: results.length + (widget.onUseCurrentLocation == null ? 0 : 1),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                if (widget.onUseCurrentLocation != null && idx == 0) {
                  return ListTile(
                    leading: const Icon(Icons.my_location_rounded),
                    title: const Text(
                      'Dùng vị trí hiện tại',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('GPS hoặc tọa độ mặc định an toàn'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onUseCurrentLocation,
                  );
                }

                final resultIndex = idx - (widget.onUseCurrentLocation == null ? 0 : 1);
                final item = results[resultIndex];
                final isSameAsDest = widget.currentDestination != null &&
                    widget.currentDestination!.latitude == item.position.latitude &&
                    widget.currentDestination!.longitude == item.position.longitude;

                return ListTile(
                  enabled: !isSameAsDest,
                  leading: Icon(item.icon, color: isSameAsDest ? colorScheme.outline : colorScheme.primary),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSameAsDest ? colorScheme.outline : null,
                    ),
                  ),
                  subtitle: Text(
                    isSameAsDest ? '${item.region} (Đang là điểm đến)' : item.region,
                    style: TextStyle(fontSize: 11, color: isSameAsDest ? colorScheme.outline : null),
                  ),
                  trailing: isSameAsDest ? null : const Icon(Icons.add_rounded, size: 20),
                  onTap: isSameAsDest ? null : () => widget.onSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
