import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../widgets/diamond_milestone_marker.dart';
import '../widgets/location_detail_sheet.dart';
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

class _TripMapScreenState extends State<TripMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  bool _is3DMode = false;
  int _currentTileStyle = 0; // 0: CartoDB Voyager (Natural Illustrated), 1: OSM HOT

  // Animation for journey arrow moving along route
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

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
    _animController.dispose();
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
            padding: const EdgeInsets.fromLTRB(40, 180, 40, 140),
          ),
        );
      }
    } catch (_) {
      // Safe fallback
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

  LatLng? _getAnimatedRoutePoint(List<LatLng> points, double progress) {
    if (points.length < 2) return null;
    final totalSegs = points.length - 1;
    final targetIndex = (progress * totalSegs).floor().clamp(0, totalSegs - 1);
    final segProgress = (progress * totalSegs) - targetIndex;

    final p1 = points[targetIndex];
    final p2 = points[targetIndex + 1];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * segProgress;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * segProgress;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapProvider>();
    final hasRoute = provider.hasRoute;
    final allStops = provider.currentDayStops;
    final activeIndex = provider.selectedWaypointIndex;
    final topPadding = MediaQuery.of(context).padding.top;

    // Natural Illustrated Map Tile Basemaps (CartoDB Voyager & OSM HOT)
    final tileUrls = [
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. NATURAL COLORFUL ILLUSTRATED MAP CANVAS (No heavy blue color filter)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: provider.origin,
                initialZoom: hasRoute ? 13.5 : 15.0,
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
                // Clean Natural Vector Map Tile Layer
                TileLayer(
                  urlTemplate: tileUrls[_currentTileStyle],
                  userAgentPackageName: 'com.travelgo.travelgo_mobile',
                  tileProvider: NetworkTileProvider(),
                ),

                // 2. CLEAR BLUE ROUTE POLYLINE (#2196F3) WITH WHITE BORDER HIGHLIGHT
                if (hasRoute && provider.currentRoute != null) ...[
                  PolylineLayer(
                    polylines: [
                      // White Outer Border Line for Crisp Contrast
                      Polyline(
                        points: provider.currentRoute!.points,
                        strokeWidth: 10.0,
                        color: Colors.white.withValues(alpha: 0.9),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      // Main Vibrant Blue Travel Route Line (Strongest Blue on Map)
                      Polyline(
                        points: provider.currentRoute!.points,
                        strokeWidth: 6.0,
                        color: const Color(0xFF2196F3),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ],
                  ),

                  // Animated Journey Marker along Route
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      final pos = _getAnimatedRoutePoint(
                        provider.currentRoute!.points,
                        _animController.value,
                      );
                      if (pos == null) return const SizedBox.shrink();

                      return MarkerLayer(
                        markers: [
                          Marker(
                            point: pos,
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x29000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.navigation_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                // 3. CUSTOM DIVERSE ILLUSTRATED MARKERS (Diverse Natural Colors)
                MarkerLayer(
                  markers: _buildNaturalIllustratedMarkers(provider, allStops, activeIndex),
                ),
              ],
            ),
          ),

          // 4. FLOATING SEARCH BAR (Clean White with Slate Gray Text & Blue Search Icon)
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () => _openRouteBuilderSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            // Neutral Avatar Circle
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.explore_outlined, color: Color(0xFF475569), size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Search Label Text (Dark Slate Gray)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.destinationName ?? 'Khám phá điểm đến...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: provider.hasRoute ? FontWeight.bold : FontWeight.w500,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (provider.hasRoute)
                                    Text(
                                      '${allStops.length} điểm dừng · ${provider.currentRoute?.formattedDistance ?? ''}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                ],
                              ),
                            ),

                            // Primary Blue Search Action Icon
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2196F3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 5. UNIFIED FLOATING MAP CONTROLS (Clean White Segment Control)
          Positioned(
            right: 16,
            top: topPadding + 78,
            child: Container(
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3D Toggle
                  IconButton(
                    icon: Text(
                      '3D',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _is3DMode ? const Color(0xFF2196F3) : const Color(0xFF64748B),
                      ),
                    ),
                    tooltip: 'Chế độ 3D',
                    onPressed: () {
                      setState(() => _is3DMode = !_is3DMode);
                    },
                  ),
                  const Divider(height: 1, indent: 6, endIndent: 6, color: Color(0xFFE2E8F0)),

                  // My Location GPS (Teal/Blue)
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF0284C7)),
                    tooltip: 'Vị trí của tôi',
                    onPressed: () {
                      _mapController.move(provider.origin, 16.0);
                    },
                  ),
                  const Divider(height: 1, indent: 6, endIndent: 6, color: Color(0xFFE2E8F0)),

                  // Layer Style Toggle
                  IconButton(
                    icon: const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Đổi bản đồ',
                    onPressed: () {
                      setState(() {
                        _currentTileStyle = (_currentTileStyle + 1) % tileUrls.length;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // 6. ROUTE BUILDER BOTTOM SHEET SUMMARY ("TẠO LỘ TRÌNH")
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x17000000),
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.map_outlined, color: Color(0xFF475569), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tạo Lộ Trình',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Lập kế hoạch chuyến đi dễ dàng và nhanh chóng',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Primary Solid Blue Action CTA ("TẠO LỘ TRÌNH")
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _openRouteBuilderSheet(context),
                          icon: const Icon(Icons.explore_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'TẠO LỘ TRÌNH',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3), // Solid Blue Brand Color
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Diverse Illustrated Markers (Teal Start, Coral Destination, Gold Attractions)
  List<Marker> _buildNaturalIllustratedMarkers(
    MapProvider provider,
    List<RouteWaypoint> stops,
    int selectedIdx,
  ) {
    final markers = <Marker>[];

    // 1. Current Location Marker (Teal/Cyan Compass Pin)
    markers.add(
      Marker(
        point: provider.origin,
        width: 110,
        height: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulsingRingMarker(
              color: Color(0xFF0284C7),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Vị trí của bạn',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 2. Destination Marker (Warm Coral/Red Pin)
    if (provider.destination != null) {
      markers.add(
        Marker(
          point: provider.destination!,
          width: 46,
          height: 54,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B), // Soft Coral Red
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x29FF6B6B),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.place_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Milestone Waypoints
    for (int i = 0; i < stops.length; i++) {
      final wp = stops[i];
      final isSelected = (i == selectedIdx);
      markers.add(
        Marker(
          point: wp.position,
          width: 50,
          height: 50,
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
}
