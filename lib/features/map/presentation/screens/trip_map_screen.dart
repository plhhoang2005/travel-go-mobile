import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../widgets/diamond_milestone_marker.dart';
import '../widgets/floating_view_switch.dart';
import '../widgets/journey_story_timeline.dart';
import '../widgets/journey_trip_card.dart';
import '../widgets/location_detail_sheet.dart';
import '../widgets/pulsing_ring_marker.dart';
import '../widgets/route_builder_sheet.dart';

class TripMapScreen extends StatefulWidget {
  final LatLng? initialDestination;
  final String? initialDestinationName;
  final List<RouteWaypoint>? initialWaypoints;
  final MapMode initialMode;
  final bool enableNetworkTiles;

  const TripMapScreen({
    super.key,
    this.initialDestination,
    this.initialDestinationName,
    this.initialWaypoints,
    this.initialMode = MapMode.routing,
    this.enableNetworkTiles = true,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  // View Mode: Map or Story Timeline
  JourneyViewMode _viewMode = JourneyViewMode.map;

  // Tile degraded / fallback flag (Law 3: Zero Silent Fallbacks)
  bool _isTileDegraded = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapProvider>();
      provider
          .init(
        targetDestination: widget.initialDestination,
        targetName: widget.initialDestinationName,
        waypoints: widget.initialWaypoints,
      )
          .then((_) {
        if (mounted && _isMapReady) {
          if (provider.hasRoute) {
            _fitCameraToBounds(provider);
          } else {
            _mapController.move(provider.origin, 15.0);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitCameraToBounds(MapProvider provider) {
    if (!mounted || !_isMapReady) return;
    try {
      final route = provider.currentRoute;
      if (route != null && route.points.toSet().length >= 2) {
        final bounds = LatLngBounds.fromPoints(route.points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(40, 180, 40, 120),
          ),
        );
      }
    } catch (_) {
      // MapController might not be attached to viewport yet
    }
  }

  void _onDiamondMarkerTapped(RouteWaypoint wp, int index, MapProvider provider) {
    provider.selectWaypoint(wp);
    _mapController.move(wp.position, 14.0);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LocationDetailSheet(
        waypoint: wp,
        sequenceNumber: index,
        provider: provider,
      ),
    );
  }

  void _openRouteBuilderSheet(BuildContext context) {
    final provider = context.read<MapProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<MapProvider>.value(
        value: provider,
        child: const RouteBuilderSheet(),
      ),
    ).then((_) {
      if (mounted && _isMapReady && provider.hasRoute) {
        _fitCameraToBounds(provider);
      }
    });
  }

  void _showMoreOptionsMenu(BuildContext context, MapProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (provider.hasRoute) ...[
              ListTile(
                leading: const Icon(Icons.fit_screen_rounded, color: Color(0xFF086C61)),
                title: const Text('Toàn cảnh lộ trình', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  _fitCameraToBounds(provider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF086C61)),
                title: const Text('Chỉnh sửa lộ trình', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  _openRouteBuilderSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
                title: const Text('Xóa lộ trình hiện tại', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE11D48))),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã xóa lộ trình hiện tại'),
                      action: SnackBarAction(
                        label: 'HOÀN TÁC',
                        onPressed: () => provider.loadDemoRoute(),
                      ),
                    ),
                  );
                  provider.clearRoute();
                  _mapController.move(provider.origin, 15.0);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF086C61)),
                title: const Text('Tạo lộ trình mới', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  _openRouteBuilderSheet(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasRoute = provider.hasRoute;
    final allStops = provider.currentDayStops;
    final activeIndex = provider.selectedWaypointIndex;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Canvas with permanently visible attribution
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: provider.origin,
              initialZoom: hasRoute ? 13.0 : 15.0,
              minZoom: 4.0,
              maxZoom: 18.0,
              onMapReady: () {
                _isMapReady = true;
                final p = context.read<MapProvider>();
                if (!p.isLoading) {
                  if (p.hasRoute) {
                    _fitCameraToBounds(p);
                  } else {
                    _mapController.move(p.origin, 15.0);
                  }
                }
              },
            ),
            children: [
              if (widget.enableNetworkTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.travelgo.travelgo_mobile',
                  tileProvider: NetworkTileProvider(),
                  errorTileCallback: (tile, error, stackTrace) {
                    if (!_isTileDegraded && mounted) {
                      setState(() {
                        _isTileDegraded = true;
                      });
                    }
                  },
                ),

              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
                alignment: Alignment.bottomLeft,
              ),

              // Ribbon Polyline Layer (Only in STATE B)
              if (hasRoute && provider.currentRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: provider.currentRoute!.points,
                      strokeWidth: provider.currentRoute!.isFallback ? 4.0 : 5.0,
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                      color: provider.currentRoute!.isFallback
                          ? const Color(0xFFF59E0B) // Amber Sun
                          : const Color(0xFF086C61), // Emerald Teal
                    ),
                  ],
                ),

              // Markers Layer: 1 marker in STATE A, Diamond Milestones in STATE B
              MarkerLayer(
                markers: hasRoute
                    ? _buildDiamondMilestoneMarkers(provider, allStops, activeIndex)
                    : _buildLocateOnlyMarkers(provider),
              ),
            ],
          ),

          // 2. Floating Top Bar (Always visible)
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFloatingToolButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Quay lại',
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                _buildFloatingToolButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'Tùy chọn',
                  onTap: () => _showMoreOptionsMenu(context, provider),
                ),
              ],
            ),
          ),

          // 3. STATE A: Top Search Bar & Journey Preview Card
          if (!hasRoute && !provider.isLoading) ...[
            Positioned(
              top: topPadding + 62,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _openRouteBuilderSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF086C61)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bạn muốn đi đâu?',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF086C61).withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alt_route_rounded, color: Color(0xFF086C61), size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: topPadding + 128,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isTileDegraded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildNotificationBanner(
                        icon: Icons.wifi_off_rounded,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        text: 'Bản đồ ngoại tuyến [Đang dùng tile dự phòng]',
                      ),
                    ),
                  _buildJourneyPreviewCard(context, provider),
                ],
              ),
            ),
          ],

          // 4. STATE B: Top Journey Trip Card
          if (hasRoute && !provider.isLoading)
            Positioned(
              top: topPadding + 62,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  JourneyTripCard(provider: provider),
                  if (provider.isMockGps)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildNotificationBanner(
                        icon: Icons.info_outline,
                        color: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF0F9FF),
                        text: 'Tọa độ mặc định: Cổng ĐH Bách Khoa TP.HCM',
                      ),
                    ),
                  if (provider.currentRoute?.isFallback == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildNotificationBanner(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        text: 'Dữ liệu lộ trình ngoại tuyến [OSRM Offline]',
                      ),
                    ),
                  if (_isTileDegraded)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildNotificationBanner(
                        icon: Icons.wifi_off_rounded,
                        color: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        text: 'Bản đồ ngoại tuyến [Đang dùng tile dự phòng]',
                      ),
                    ),
                ],
              ),
            ),

          // 5. Floating Controls (Right side: Fit Camera, Zoom In, My Location)
          Positioned(
            right: 14,
            top: topPadding + (hasRoute ? 240 : 190),
            child: Column(
              children: [
                if (hasRoute) ...[
                  _buildFloatingToolButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: 'Toàn cảnh hành trình',
                    onTap: () => _fitCameraToBounds(provider),
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingToolButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Phóng to',
                    onTap: () {
                      final cam = _mapController.camera;
                      _mapController.move(cam.center, (cam.zoom + 1.0).clamp(4.0, 18.0));
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                _buildFloatingToolButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Cập nhật vị trí',
                  onTap: () async {
                    await provider.refreshCurrentLocation();
                    if (mounted && _isMapReady) {
                      _mapController.move(provider.origin, 15.0);
                    }
                  },
                ),
              ],
            ),
          ),

          // 6. Loading Overlay
          if (provider.isLoading)
            Positioned(
              top: topPadding + 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Đang tính toán tuyến đường OSRM...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. STATE B: Story Mode Timeline (Over Map Canvas)
          if (hasRoute && _viewMode == JourneyViewMode.story)
            Positioned(
              top: topPadding + 225,
              left: 16,
              right: 16,
              bottom: 84,
              child: JourneyStoryTimeline(
                provider: provider,
                onStopSelected: (stop) {
                  setState(() => _viewMode = JourneyViewMode.map);
                  final idx = allStops.indexWhere((s) => s.id == stop.id || s.position == stop.position);
                  _onDiamondMarkerTapped(stop, idx >= 0 ? idx : 0, provider);
                },
              ),
            ),

          // 8. STATE B: Bottom Floating View Switch
          if (hasRoute && !provider.isLoading) ...[
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingViewSwitch(
                  currentMode: _viewMode,
                  onModeChanged: (mode) => setState(() => _viewMode = mode),
                ),
              ),
            ),
            // Edit Route FAB on right
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'fab_edit_journey',
                tooltip: 'Chỉnh sửa lộ trình',
                backgroundColor: const Color(0xFF086C61),
                foregroundColor: Colors.white,
                onPressed: () => _openRouteBuilderSheet(context),
                child: const Icon(Icons.edit_outlined, size: 20),
              ),
            ),
          ],

          // 9. STATE A Primary FAB
          if (!hasRoute && !provider.isLoading)
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_create_route',
                onPressed: () => _openRouteBuilderSheet(context),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Tạo Lộ Trình', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF086C61),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJourneyPreviewCard(BuildContext context, MapProvider provider) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(242),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18102037),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bolt_rounded, size: 16, color: primaryColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CHUYẾN ĐI CỦA MINH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Đà Lạt · 3 ngày 2 đêm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102037),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: const Text(
                    'Khám phá hành trình',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    await provider.loadDemoRoute();
                    if (mounted) {
                      _fitCameraToBounds(provider);
                    }
                  },
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => _openRouteBuilderSheet(context),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF5E718B),
                  ),
                  child: const Text(
                    'hoặc tự tạo lộ trình mới ↓',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildLocateOnlyMarkers(MapProvider provider) {
    return [
      Marker(
        point: provider.origin,
        width: 120,
        height: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF086C61),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Center(
                child: Icon(Icons.my_location_rounded, size: 13, color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Text(
                provider.isMockGps ? 'Vị trí mặc định' : 'Vị trí hiện tại',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF086C61),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Marker> _buildDiamondMilestoneMarkers(
    MapProvider provider,
    List<RouteWaypoint> allStops,
    int activeIndex,
  ) {
    final markers = <Marker>[];

    for (int i = 0; i < allStops.length; i++) {
      final wp = allStops[i];
      final isSelected = (provider.selectedWaypoint != null &&
              (provider.selectedWaypoint!.id == wp.id || provider.selectedWaypoint!.position == wp.position)) ||
          (provider.selectedWaypoint == null && i == 0);

      // If active/selected, add pulsing ring underneath
      if (isSelected) {
        markers.add(
          Marker(
            point: wp.position,
            width: 76,
            height: 76,
            child: const PulsingRingMarker(
              size: 76,
              color: Color(0xFF086C61),
            ),
          ),
        );
      }

      // Add Diamond Milestone Marker (-45deg rotated pin)
      markers.add(
        Marker(
          point: wp.position,
          width: 60,
          height: 60,
          child: DiamondMilestoneMarker(
            waypoint: wp,
            sequenceNumber: i,
            isSelected: isSelected,
            onTap: () => _onDiamondMarkerTapped(wp, i, provider),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildFloatingToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAF9).withAlpha(225),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, size: 20, color: const Color(0xFF086C61)),
            tooltip: tooltip,
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBanner({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
