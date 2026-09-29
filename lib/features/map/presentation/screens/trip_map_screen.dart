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
  int _currentTileStyle = 0; // 0: CartoDB Voyager Anime Cel-Shaded, 1: OSM HOT

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

    final tileUrls = [
      'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: Stack(
        children: [
          // 1. ANIME / CARTOON MAP CANVAS (Cel-Shaded Land, Soft Anime Emerald Green & Vibrant Oceans)
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.96, 0.02, 0.04, 0, 4,   // R: Soft warm cel-shaded land
                0.01, 1.06, 0.02, 0, 8,   // G: Enhance vibrant anime green parks
                0.02, 0.04, 1.18, 0, 16,  // B: Bright clean anime blue oceans & rivers
                0,    0,    0,    1, 0,
              ]),
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
                  // Vector Anime Basemap Layer
                  TileLayer(
                    urlTemplate: tileUrls[_currentTileStyle],
                    userAgentPackageName: 'com.travelgo.travelgo_mobile',
                    tileProvider: NetworkTileProvider(),
                  ),

                  // 2. ANIME ADVENTURE ROUTE POLYLINE (Cel-Shaded Outline & Glow)
                  if (hasRoute && provider.currentRoute != null) ...[
                    PolylineLayer(
                      polylines: [
                        // Outer Soft Glow Aura
                        Polyline(
                          points: provider.currentRoute!.points,
                          strokeWidth: 16.0,
                          color: const Color(0x3B0284C7),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                        // Crisp White Outer Outline (Anime Cel-Shaded Border)
                        Polyline(
                          points: provider.currentRoute!.points,
                          strokeWidth: 10.0,
                          color: Colors.white,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                        // Primary Vibrant Anime Blue Trail
                        Polyline(
                          points: provider.currentRoute!.points,
                          strokeWidth: 6.0,
                          color: const Color(0xFF0284C7),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    ),

                    // Animated Traveling Arrow Icon along Route
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
                              width: 28,
                              height: 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x3B0284C7),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.navigation_rounded,
                                    size: 14,
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

                  // 3. ANIME / GAME STYLE CUSTOM MARKERS
                  MarkerLayer(
                    markers: _buildAnimeStyleMarkers(provider, allStops, activeIndex),
                  ),
                ],
              ),
            ),
          ),

          // 4. FLOATING ANIME SEARCH BAR (Top Cel-Shaded Pill)
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0284C7),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(27),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(27),
                      onTap: () => _openRouteBuilderSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            // Compass Avatar Badge (Anime Blue Circle)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE0F2FE),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.explore_rounded, color: Color(0xFF0284C7), size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Search Placeholder Text
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        provider.destinationName ?? 'Khám phá điểm đến...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: provider.hasRoute ? FontWeight.bold : FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF0284C7)),
                                    ],
                                  ),
                                  if (provider.hasRoute)
                                    Text(
                                      '${allStops.length} điểm dừng · ${provider.currentRoute?.formattedDistance ?? ''}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),

                            // Primary Anime Blue Search Button
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0284C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
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

          // 5. UNIFIED ANIME FLOATING CONTROLS (Right Stacked Pill)
          Positioned(
            right: 16,
            top: topPadding + 80,
            child: Container(
              width: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0284C7),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3D Toggle Button
                  IconButton(
                    icon: Text(
                      '3D',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _is3DMode ? const Color(0xFF0284C7) : const Color(0xFF0369A1),
                      ),
                    ),
                    tooltip: 'Chế độ 3D Anime',
                    onPressed: () {
                      setState(() => _is3DMode = !_is3DMode);
                    },
                  ),
                  const Divider(height: 1, indent: 6, endIndent: 6, color: Color(0xFFBAE6FD)),

                  // My Location GPS Button
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 20, color: Color(0xFF0284C7)),
                    tooltip: 'Vị trí của tôi',
                    onPressed: () {
                      _mapController.move(provider.origin, 16.0);
                    },
                  ),
                  const Divider(height: 1, indent: 6, endIndent: 6, color: Color(0xFFBAE6FD)),

                  // Layer Style Button
                  IconButton(
                    icon: const Icon(Icons.layers_rounded, size: 20, color: Color(0xFF0284C7)),
                    tooltip: 'Đổi kiểu bản đồ',
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

          // 6. ROUTE BUILDER ANIME BOTTOM PANEL ("TẠO LỘ TRÌNH")
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
                    border: Border(top: BorderSide(color: Color(0xFFE0F2FE), width: 1.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 18,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      Container(
                        width: 40,
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
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.explore_rounded, color: Color(0xFF0284C7), size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tạo Lộ Trình Phiêu Lưu',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Lập kế hoạch chuyến đi phong cách Anime',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Primary Solid Anime Blue Action CTA Button ("TẠO LỘ TRÌNH")
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _openRouteBuilderSheet(context),
                          icon: const Icon(Icons.near_me_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'TẠO LỘ TRÌNH',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7), // Solid Primary Anime Blue
                            elevation: 2,
                            shadowColor: const Color(0x3B0284C7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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

  // Anime / Game Style Custom Illustrated Markers
  List<Marker> _buildAnimeStyleMarkers(
    MapProvider provider,
    List<RouteWaypoint> stops,
    int selectedIdx,
  ) {
    final markers = <Marker>[];

    // 1. Current Location Marker (Anime Compass Badge + Pulsing Ring)
    markers.add(
      Marker(
        point: provider.origin,
        width: 110,
        height: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PulsingRingMarker(
              color: Color(0xFF0284C7),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0284C7),
                    blurRadius: 6,
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

    // 2. Destination Marker (Anime Adventure Coral Treasure Pin)
    if (provider.destination != null) {
      markers.add(
        Marker(
          point: provider.destination!,
          width: 48,
          height: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B), // Anime Coral Red
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3BFF6B6B),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.backpack_rounded,
                    color: Colors.white,
                    size: 22,
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
          width: 70,
          height: 75,
          child: DiamondMilestoneMarker(
            waypoint: wp,
            sequenceNumber: i,
            isSelected: isSelected,
            onTap: () => _onDiamondMarkerTapped(wp, i, provider),
          ),
        ),
      );
    }

    // 4. Vibrant Anime Bus Stop & Landmark Markers
    final busStopPosition = LatLng(
      provider.origin.latitude + 0.003,
      provider.origin.longitude + 0.002,
    );
    markers.add(
      Marker(
        point: busStopPosition,
        width: 76,
        height: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F1A), // Vibrant Anime Yellow Bus
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40FF9F1A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus_filled_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF9F1A), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Trạm Xe Buýt',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return markers;
  }
}
