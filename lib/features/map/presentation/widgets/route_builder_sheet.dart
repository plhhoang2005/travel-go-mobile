import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../../services/destination_catalog_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<MapProvider>(
      builder: (context, provider, _) {
        final searchResults = _catalogService.search(_destinationQuery);

        return DraggableScrollableSheet(
          initialChildSize: 0.74,
          minChildSize: 0.48,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header: Clean Neutral Style
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.route_rounded, color: Color(0xFF475569), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Route Builder',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Tạo lộ trình du lịch thông minh',
                                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Vertical Journey Flow (Natural Colors: Teal Start, Coral End)
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        // NODE 1: Origin Node (Teal Circle)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF0284C7), width: 5),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 48,
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          provider.originName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Vị trí xuất phát',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '8.4 km',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // NODE 2: Destination Node (Coral Red Pin)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF6B6B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.place_rounded, color: Colors.white, size: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: provider.destination == null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _destinationSearchController,
                                          decoration: InputDecoration(
                                            hintText: 'Chọn điểm đến...',
                                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                          ),
                                          onChanged: (val) => setState(() => _destinationQuery = val),
                                        ),
                                        if (_destinationQuery.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: searchResults.length,
                                              separatorBuilder: (_, _) => const Divider(height: 1),
                                              itemBuilder: (context, idx) {
                                                final dest = searchResults[idx];
                                                return ListTile(
                                                  leading: Icon(dest.icon, color: const Color(0xFF2196F3)),
                                                  title: Text(dest.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  subtitle: Text(dest.region, style: const TextStyle(fontSize: 11)),
                                                  onTap: () {
                                                    provider.setDestination(dest.position, dest.name);
                                                    _destinationSearchController.clear();
                                                    setState(() => _destinationQuery = '');
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFF6B6B), width: 1.2),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                provider.destinationName ?? 'Điểm đến',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Điểm kết thúc hành trình',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF2F2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  '25 phút',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 18),
                                                onPressed: () => provider.enterLocateOnlyMode(),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Action Button: Add Waypoint Row
                        Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddWaypointSheet(context, provider),
                            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF475569)),
                            label: const Text(
                              '+ Thêm điểm dừng',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Solid Blue CTA Button ('TẠO LỘ TRÌNH')
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (provider.destination == null || provider.isLoading)
                              ? null
                              : () async {
                                  await provider.buildRoute();
                                  if (context.mounted && provider.currentRoute != null) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.near_me_rounded, color: Colors.white, size: 18),
                          label: Text(
                            provider.isLoading ? 'ĐANG TÍNH TOÁN...' : 'TẠO LỘ TRÌNH',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3), // Solid Blue Primary Action
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
}

class _WaypointPickerModal extends StatefulWidget {
  final DestinationCatalogService catalogService;
  final LatLng? currentDestination;
  final ValueChanged<Destination> onSelected;

  const _WaypointPickerModal({
    required this.catalogService,
    required this.currentDestination,
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
      color: Colors.white,
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
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn Trạm Dừng Chân',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final item = results[idx];
                  final isSameAsDest = widget.currentDestination != null &&
                      widget.currentDestination!.latitude == item.position.latitude &&
                      widget.currentDestination!.longitude == item.position.longitude;

                  return ListTile(
                    enabled: !isSameAsDest,
                    leading: Icon(item.icon, color: isSameAsDest ? colorScheme.outline : const Color(0xFF2196F3)),
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
                    trailing: isSameAsDest ? null : const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF2196F3)),
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
