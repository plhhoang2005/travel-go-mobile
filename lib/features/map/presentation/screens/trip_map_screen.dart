import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../widgets/milestone_marker_widget.dart';
import '../widgets/journey_carousel_widget.dart';
import '../widgets/pulsing_ring_marker.dart';
import '../widgets/route_builder_sheet.dart';

class TripMapScreen extends StatefulWidget {
  final LatLng? initialDestination;
  final String? initialDestinationName;
  final List<RouteWaypoint>? initialWaypoints;
  final MapMode initialMode;

  const TripMapScreen({
    super.key,
    this.initialDestination,
    this.initialDestinationName,
    this.initialWaypoints,
    this.initialMode = MapMode.routing,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final MapController _mapController = MapController();
  final PageController _carouselController = PageController(viewportFraction: 0.82);
  bool _isMapReady = false;

  int _lastCameraIndex = -1;
  Timer? _debounceTimer;

  // Layer toggle: standard OSM vs Topo/Clean
  bool _isAlternateTileLayer = false;

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
    _debounceTimer?.cancel();
    _carouselController.dispose();
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
            padding: const EdgeInsets.fromLTRB(40, 100, 40, 220),
          ),
        );
      }
    } catch (_) {
      // MapController might not be attached to viewport yet
    }
  }

  void _onCardChanged(int index, MapProvider provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted || !_isMapReady) return;
      if (index == _lastCameraIndex) return;

      final allStops = provider.allStops;
      if (index >= 0 && index < allStops.length) {
        final wp = allStops[index];
        _lastCameraIndex = index;
        provider.selectWaypoint(wp);
        _mapController.move(wp.position, 13.5);
      }
    });
  }

  void _onMarkerTapped(RouteWaypoint wp, MapProvider provider) {
    final allStops = provider.allStops;
    final index = allStops.indexWhere((item) => item.id == wp.id || item.position == wp.position);
    if (index >= 0) {
      provider.selectWaypoint(wp);
      if (_carouselController.hasClients) {
        _carouselController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      _mapController.move(wp.position, 13.5);
    }
  }

  void _openRouteBuilderSheet(BuildContext context) {
    final provider = context.read<MapProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RouteBuilderSheet(),
    ).then((_) {
      if (mounted && _isMapReady && provider.hasRoute) {
        _fitCameraToBounds(provider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasRoute = provider.hasRoute;
    final allStops = provider.allStops;
    final activeIndex = provider.selectedWaypointIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lộ Trình Du Lịch',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (hasRoute)
            IconButton(
              icon: const Icon(Icons.crop_free_rounded),
              tooltip: 'Căn chỉnh toàn cảnh',
              onPressed: () => _fitCameraToBounds(provider),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Canvas (Free OSM DE with Ribbon Styling)
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
              TileLayer(
                urlTemplate: _isAlternateTileLayer
                    ? 'https://tile.openstreetmap.de/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travelgo.travelgo_mobile',
                tileProvider: NetworkTileProvider(),
              ),

              // Ribbon Polyline Layer (Only in STATE B)
              if (hasRoute && provider.currentRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: provider.currentRoute!.points,
                      strokeWidth: provider.currentRoute!.isFallback ? 4.0 : 5.5,
                      borderStrokeWidth: provider.currentRoute!.isFallback ? 1.5 : 2.0,
                      borderColor: provider.currentRoute!.isFallback
                          ? const Color(0xFFFFFDF7)
                          : const Color(0xFFFFFFFF),
                      color: provider.currentRoute!.isFallback
                          ? const Color(0xFFF59E0B) // Amber Sun
                          : const Color(0xFF086C61), // Emerald Teal
                    ),
                  ],
                ),

              // Markers Layer: 1 marker in STATE A, Milestones in STATE B
              MarkerLayer(
                markers: hasRoute
                    ? _buildMilestoneMarkers(provider, allStops, activeIndex)
                    : _buildLocateOnlyMarkers(provider),
              ),
            ],
          ),

          // 2. STATE A: Top Search Bar
          if (!hasRoute)
            Positioned(
              top: 12,
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

          // 3. STATE B: Law 3 Transparency Banner & Clear Route Button
          if (hasRoute) ...[
            Positioned(
              top: 12,
              left: 16,
              right: 70,
              child: Column(
                children: [
                  if (provider.isMockGps)
                    _buildNotificationBanner(
                      icon: Icons.info_outline,
                      color: const Color(0xFF0284C7),
                      bgColor: const Color(0xFFF0F9FF),
                      text: 'Tọa độ mặc định: Cổng ĐH Bách Khoa TP.HCM',
                    ),
                  if (provider.currentRoute?.isFallback == true)
                    _buildNotificationBanner(
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFFFBEB),
                      text: 'Dữ liệu lộ trình ngoại tuyến [OSRM Offline]',
                    ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(220),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFE11D48)),
                      tooltip: 'Xóa lộ trình',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Xóa lộ trình hiện tại?'),
                            action: SnackBarAction(
                              label: 'XÓA',
                              textColor: const Color(0xFFF43F5E),
                              onPressed: () {
                                provider.clearRoute();
                                _mapController.move(provider.origin, 15.0);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],

          // 4. Floating Tools (Right side)
          Positioned(
            right: 14,
            top: hasRoute ? 72 : 80,
            child: Column(
              children: [
                _buildFloatingToolButton(
                  icon: Icons.explore_outlined,
                  tooltip: 'Về điểm xuất phát',
                  onTap: () => _mapController.move(provider.origin, 15.0),
                ),
                if (hasRoute) ...[
                  const SizedBox(height: 8),
                  _buildFloatingToolButton(
                    icon: Icons.fit_screen_outlined,
                    tooltip: 'Toàn cảnh hành trình',
                    onTap: () => _fitCameraToBounds(provider),
                  ),
                ],
                const SizedBox(height: 8),
                _buildFloatingToolButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Chế độ bản đồ',
                  onTap: () {
                    setState(() {
                      _isAlternateTileLayer = !_isAlternateTileLayer;
                    });
                  },
                ),
              ],
            ),
          ),

          // 5. Loading Overlay
          if (provider.isLoading)
            Positioned(
              top: 70,
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

          // 6. STATE B: Journey Carousel
          if (hasRoute && allStops.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: JourneyCarouselWidget(
                waypoints: allStops,
                activeIndex: activeIndex,
                pageController: _carouselController,
                onCardChanged: (idx) => _onCardChanged(idx, provider),
              ),
            ),

          // 7. FABs
          if (!hasRoute) ...[
            // Secondary FAB: Bolt (Demo)
            Positioned(
              bottom: 88,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'fab_demo_route',
                tooltip: 'Demo Đa Chặng (A→B→C→D)',
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                onPressed: () async {
                  await provider.loadDemoRoute();
                  if (mounted) {
                    _fitCameraToBounds(provider);
                  }
                },
                child: const Icon(Icons.bolt_rounded, size: 22),
              ),
            ),
            // Primary FAB: Tạo Lộ Trình
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
          ] else ...[
            // STATE B FAB: Chỉnh Sửa
            Positioned(
              bottom: 128,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_edit_route',
                onPressed: () => _openRouteBuilderSheet(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh Sửa', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF086C61),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Marker> _buildLocateOnlyMarkers(MapProvider provider) {
    return [
      Marker(
        point: provider.origin,
        width: 120,
        height: 56,
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
              child: const Text(
                'Vị trí của bạn',
                style: TextStyle(
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

  List<Marker> _buildMilestoneMarkers(
    MapProvider provider,
    List<RouteWaypoint> allStops,
    int activeIndex,
  ) {
    final markers = <Marker>[];

    for (int i = 0; i < allStops.length; i++) {
      final wp = allStops[i];
      final isActive = i == activeIndex;

      // If active, add pulsing ring underneath
      if (isActive) {
        markers.add(
          Marker(
            point: wp.position,
            width: 72,
            height: 72,
            child: const PulsingRingMarker(
              size: 72,
              color: Color(0xFF086C61),
            ),
          ),
        );
      }

      // Add Milestone Marker badge
      markers.add(
        Marker(
          point: wp.position,
          width: wp.type == 'stop' ? 100 : 50,
          height: wp.type == 'stop' ? 52 : 50,
          child: MilestoneMarkerWidget(
            waypoint: wp,
            sequenceNumber: i,
            isActive: isActive,
            onTap: () => _onMarkerTapped(wp, provider),
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
