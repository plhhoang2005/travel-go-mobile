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
      provider.init(
        targetDestination: widget.initialDestination,
        targetName: widget.initialDestinationName,
        waypoints: widget.initialWaypoints,
      ).then((_) {
        if (mounted && _isMapReady) {
          _fitCameraToBounds(provider);
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
      _carouselController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _mapController.move(wp.position, 13.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final allStops = provider.allStops;
    final activeIndex = provider.selectedWaypointIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lộ Trình Du Lịch',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
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
              initialZoom: 13.0,
              minZoom: 4.0,
              maxZoom: 18.0,
              onMapReady: () {
                _isMapReady = true;
                final p = context.read<MapProvider>();
                if (!p.isLoading) {
                  _fitCameraToBounds(p);
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

              // Ribbon Polyline Layer (Double stroke: white border + emerald/amber core)
              if (provider.currentRoute != null)
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

              // Markers Layer with Pulsing Ring on Active Waypoint
              MarkerLayer(
                markers: _buildMilestoneMarkers(provider, allStops, activeIndex),
              ),
            ],
          ),

          // 2. Law 3 Transparency Banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (provider.isMockGps)
                  _buildNotificationBanner(
                    icon: Icons.info_outline,
                    color: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    text: 'Đang dùng tọa độ xuất phát mặc định: Cổng ĐH Bách Khoa TP.HCM',
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

          // 3. Floating Tools (Top-Right, 3 buttons)
          Positioned(
            right: 12,
            top: 120,
            child: Column(
              children: [
                _buildFloatingToolButton(
                  icon: Icons.explore_outlined,
                  tooltip: 'Về điểm xuất phát',
                  onTap: () => _mapController.move(provider.origin, 13.5),
                ),
                const SizedBox(height: 8),
                _buildFloatingToolButton(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Toàn cảnh hành trình',
                  onTap: () => _fitCameraToBounds(provider),
                ),
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

          // 4. Loading Overlay
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
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

          // 5. Journey Carousel (Horizontal Waypoint Cards at bottom)
          if (allStops.isNotEmpty)
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
        ],
      ),
    );
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
            color: const Color(0xFFFAFAF9).withValues(alpha: 0.88),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
