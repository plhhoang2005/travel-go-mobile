import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../theme/travelgo_map_tokens.dart';
import '../widgets/floating_view_switch.dart';
import '../widgets/journey_story_timeline.dart';
import '../widgets/journey_trip_card.dart';
import '../widgets/location_detail_sheet.dart';
import '../widgets/group_radar_sheet.dart';
import '../widgets/route_builder_sheet.dart';
import '../widgets/travelgo_character_badge.dart';
import '../widgets/travelgo_markers.dart';
import '../../services/destination_catalog_service.dart';

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

class _TripMapScreenState extends State<TripMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  // View Mode: Map or Story Timeline
  JourneyViewMode _viewMode = JourneyViewMode.map;

  // Layer toggle: standard OSM vs Topo/Clean
  bool _isAlternateTileLayer = false;
  final DestinationCatalogService _catalogService = DestinationCatalogService();

  AnimationController? _routeRevealController;
  Animation<double>? _routeRevealAnimation;
  RouteData? _previousRoute;
  Timer? _routeRevealTimer;

  @override
  void initState() {
    super.initState();
    _routeRevealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _routeRevealAnimation = CurvedAnimation(parent: _routeRevealController!, curve: Curves.easeInOut);

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

  final Set<AnimationController> _runningMapAnimations = {};

  @override
  void dispose() {
    _routeRevealTimer?.cancel();
    for (final controller in _runningMapAnimations) {
      controller.stop();
      controller.dispose();
    }
    _runningMapAnimations.clear();
    _routeRevealController?.dispose();
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

  void _animatedMapMove(LatLng destLocation, double destZoom, {int durationMs = 250}) {
    if (!mounted || !_isMapReady) return;
    try {
      final camera = _mapController.camera;
      final latTween = LatLngTween(begin: camera.center, end: destLocation);
      final zoomTween = Tween<double>(begin: camera.zoom, end: destZoom);

      final controller = AnimationController(
        duration: Duration(milliseconds: durationMs),
        vsync: this,
      );
      _runningMapAnimations.add(controller);

      final animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

      controller.addListener(() {
        if (!mounted) return;
        _mapController.move(
          latTween.evaluate(animation),
          zoomTween.evaluate(animation),
        );
      });

      animation.addStatusListener((status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          _runningMapAnimations.remove(controller);
          controller.dispose();
        }
      });

      controller.forward();
    } catch (_) {
      _mapController.move(destLocation, destZoom);
    }
  }

  bool _isRouteRevealing = false;

  void _startRouteRevealSequence(MapProvider provider) async {
    if (!mounted || !_isMapReady) return;
    
    setState(() => _isRouteRevealing = true);
    _routeRevealController?.reset();

    // 1. Camera Glide to fit route
    try {
      final bounds = LatLngBounds.fromPoints(provider.currentRoute!.points);
      final center = LatLng(
        (bounds.southWest.latitude + bounds.northEast.latitude) / 2,
        (bounds.southWest.longitude + bounds.northEast.longitude) / 2,
      );
      final distance = provider.currentRoute!.distanceKm;
      double zoom = 13.0;
      if (distance > 300) zoom = 6.5;
      else if (distance > 150) zoom = 7.5;
      else if (distance > 50) zoom = 9.0;
      else if (distance > 20) zoom = 11.0;
      
      _animatedMapMove(center, zoom, durationMs: 700);
    } catch (_) {
      _fitCameraToBounds(provider);
    }

    // Wait for camera to settle
    _routeRevealTimer?.cancel();
    _routeRevealTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      // 2. Route Reveal (River Flow)
      _routeRevealController?.forward();

      // Wait for route to complete revealing
      _routeRevealTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        // 3. Destination and Metadata Reveal is handled implicitly by the UI 
        // updating via the _isRouteRevealing flag flip.
        setState(() => _isRouteRevealing = false);
      });
    });
  }

  void _onDiamondMarkerTapped(RouteWaypoint wp, int index, MapProvider provider) {
    HapticFeedback.lightImpact();
    provider.selectWaypoint(wp);
    _animatedMapMove(wp.position, 14.5);
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
          color: const Color(0xFFE8F2F6),
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
    
    if (provider.currentRoute != _previousRoute) {
      _previousRoute = provider.currentRoute;
      if (provider.currentRoute != null) {
        _startRouteRevealSequence(provider);
      }
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasRoute = provider.hasRoute;
    final allStops = provider.currentDayStops;
    final activeIndex = provider.selectedWaypointIndex;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Canvas (tile.openstreetmap.de with TravelGO Styling)
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
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF7FA2B3),
                    BlendMode.color,
                  ),
                  child: TileLayer(
                  urlTemplate: _isAlternateTileLayer
                      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  fallbackUrl: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.travelgo.travelgo_mobile',
                  tileProvider: NetworkTileProvider(),
                ),
              ),

              // Ribbon Polyline Layer (Only in STATE B) with Route Reveal Animation
              if (hasRoute && provider.currentRoute != null)
                AnimatedBuilder(
                  animation: _routeRevealAnimation!,
                  builder: (context, child) {
                    final points = provider.currentRoute!.points;
                    final revealCount = (points.length * _routeRevealAnimation!.value).ceil().clamp(0, points.length);
                    if (revealCount < 2) return const SizedBox.shrink();
                    
                    final fallback = provider.currentRoute!.isFallback;
                    
                    return PolylineLayer(
                      polylines: [
                        // Layer 1: Shadow / Depth (Deep Teal)
                        Polyline(
                          points: points.sublist(0, revealCount),
                          strokeWidth: fallback ? 10.0 : 12.0,
                          color: fallback 
                              ? const Color(0xFF92400E).withAlpha(100) 
                              : const Color(0xFF042F2A).withAlpha(100),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                        // Layer 2: Main Route (Emerald Coastal Teal)
                        Polyline(
                          points: points.sublist(0, revealCount),
                          strokeWidth: fallback ? 6.0 : 8.0,
                          color: fallback
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF086C61),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                        // Layer 3: Inner Highlight (Lighter Teal/Ice Blue)
                        Polyline(
                          points: points.sublist(0, revealCount),
                          strokeWidth: fallback ? 2.0 : 3.0,
                          color: fallback
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF5EEAD4).withAlpha(200),
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        ),
                      ],
                    );
                  },
                ),

              // Markers Layer: 1 marker in STATE A, Diamond Milestones in STATE B
              MarkerLayer(
                markers: [
                  ..._buildLandmarkMarkers(provider),
                  if (hasRoute)
                    ..._buildDiamondMilestoneMarkers(provider, allStops, activeIndex)
                  else
                    ..._buildLocateOnlyMarkers(provider),
                  if (provider.isGroupRadarEnabled)
                    ..._buildGroupMemberMarkers(provider),
                ],
              ),
            ],
          ),

          // 1.5 OpenStreetMap Attribution Badge (Clean & Transparent)
          Positioned(
            bottom: hasRoute ? 82 : 16,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(210),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, size: 11, color: Color(0xFF5F6F7F)),
                  SizedBox(width: 4),
                  Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF5F6F7F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Notification Banner for Radar
          if (provider.isGroupRadarEnabled)
            Positioned(
              top: topPadding + 70,
              left: 16,
              right: 16,
              child: _buildNotificationBanner(
                icon: Icons.radar_rounded,
                color: const Color(0xFF086C61),
                bgColor: const Color(0xFFE8F2F6),
                text: 'Radar nhóm demo [ thành viên]',
              ),
            ),

          // Notification Banner for Radar
          if (provider.isGroupRadarEnabled)
            Positioned(
              top: topPadding + 70,
              left: 16,
              right: 16,
              child: _buildNotificationBanner(
                icon: Icons.radar_rounded,
                color: const Color(0xFF086C61),
                bgColor: const Color(0xFFE8F2F6),
                text: 'Radar nhóm demo [${provider.groupMembers.length} thành viên]',
              ),
            ),

          // 2. Floating Top Bar (Always visible)
          Positioned(
            top: topPadding + 12,
            left: 16,
            child: _buildFloatingToolButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Quay lại',
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),

          // 3. Living Character Companion (Bé Cú TravelGO)
          Positioned(
            top: topPadding + 70,
            left: 16,
            child: TravelGoCharacterBadge(
              state: provider.isLoading || _isRouteRevealing
                  ? TravelGoCharacterState.buildingRoute
                  : (provider.currentRoute?.isFallback == true
                      ? TravelGoCharacterState.fallback
                      : (hasRoute
                          ? TravelGoCharacterState.routeComplete
                          : TravelGoCharacterState.idle)),
              customMessage: (provider.isLoading || _isRouteRevealing)
                  ? 'Để mình bay đi mở đường nhé!'
                  : (hasRoute
                      ? 'Có đường rồi! Lên đường thôi! (${provider.currentRoute?.formattedDistance ?? ''})'
                      : null),
              onTap: () {
                if (!hasRoute && !provider.isLoading && !_isRouteRevealing) {
                  _openRouteBuilderSheet(context);
                }
              },
            ),
          ),

          // 4. Floating Controls (Right edge)
          Positioned(
            right: 14,
            top: topPadding + 12,
            child: Column(
              children: [
                _buildFloatingToolButton(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'Tùy chọn',
                  onTap: () => _showMoreOptionsMenu(context, provider),
                ),
                const SizedBox(height: 12),
                _buildFloatingToolButton(
                  icon: Icons.radar_rounded,
                  tooltip: provider.isGroupRadarEnabled ? 'Radar nhóm (Đang bật)' : 'Radar nhóm',
                  isActive: provider.isGroupRadarEnabled,
                  onTap: () => _openGroupRadarSheet(context, provider),
                ),
                const SizedBox(height: 12),
                if (hasRoute) ...[
                  _buildFloatingToolButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: 'Toàn cảnh hành trình',
                    onTap: () => _fitCameraToBounds(provider),
                  ),
                  const SizedBox(height: 12),
                  _buildFloatingToolButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Phóng to',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final cam = _mapController.camera;
                      _animatedMapMove(cam.center, (cam.zoom + 1.0).clamp(4.0, 18.0));
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFloatingToolButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Vị trí của bạn',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _animatedMapMove(provider.origin, 15.0);
                  },
                ),
                const SizedBox(height: 12),
                _buildFloatingToolButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Chế độ bản đồ',
                  onTap: () {
                    HapticFeedback.selectionClick();
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
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2F6),
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
                        'Cú Mây đang tính toán lộ trình...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF086C61)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Bottom Panels (Search or Route Summary)
          if (!provider.isLoading && !_isRouteRevealing)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: hasRoute 
                  ? _buildCompactRouteSummary(context, provider).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0)
                  : _buildDiscoverySearchPanel(context).animate().fadeIn(duration: 200.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySearchPanel(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openRouteBuilderSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2F6),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF086C61)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Khám phá Việt Nam...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF086C61).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Color(0xFF086C61), size: 20),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8F2F6),
              foregroundColor: const Color(0xFF086C61),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
            icon: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF086C61)),
            label: const Text('TẠO LỘ TRÌNH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF086C61))),
            onPressed: () => _openRouteBuilderSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRouteSummary(BuildContext context, MapProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2F6),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF086C61).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route_rounded, color: Color(0xFF086C61)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.destinationName ?? 'Hành trình TravelGO',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF102037),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${provider.currentRoute?.formattedDistance ?? ''} · ${provider.currentRoute?.formattedDuration ?? ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5E718B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF086C61)),
            onPressed: () => _openRouteBuilderSheet(context),
            tooltip: 'Chỉnh sửa lộ trình',
          ),
        ],
      ),
    );
  }

  List<Marker> _buildLocateOnlyMarkers(MapProvider provider) {
    return [
      Marker(
        point: provider.origin,
        width: 32,
        height: 32,
        child: const CurrentLocationMarker(isSelected: true),
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
          
      final isDestination = wp.type.toLowerCase() == 'destination';

      if (isDestination) {
        markers.add(
          Marker(
            point: wp.position,
            width: 60,
            height: 60,
            child: TravelGoDestinationMarker(
              isSelected: isSelected,
              onTap: () => _onDiamondMarkerTapped(wp, i, provider),
            ),
          ),
        );
      } else {
        markers.add(
          Marker(
            point: wp.position,
            width: 60,
            height: 60,
            child: TravelGoWaypointMarker(
              waypoint: wp,
              sequenceNumber: i,
              isSelected: isSelected,
              onTap: () => _onDiamondMarkerTapped(wp, i, provider),
            ),
          ),
        );
      }
    }

    return markers;
  }

  List<Marker> _buildLandmarkMarkers(MapProvider provider) {
    // Show landmarks only when zoom is moderate/high to avoid clutter
    double currentZoom = 13.0;
    try {
      currentZoom = _mapController.camera.zoom;
      if (currentZoom < 10.0) return [];
    } catch (_) {}

    final catalog = _catalogService.getAll();
    return catalog.map((dest) {
      final isSelected = provider.selectedWaypoint != null &&
          (provider.selectedWaypoint!.position.latitude == dest.position.latitude &&
           provider.selectedWaypoint!.position.longitude == dest.position.longitude);

      if (isSelected) {
        // Hero Landmark for Location Detail
        return Marker(
          point: dest.position,
          width: 280,
          height: 280,
          alignment: Alignment.bottomCenter, // Anchor to the base
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Illustration placeholder
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F6), // Ice blue background for illustration
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8F2F6), width: 6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Center(
                  child: Icon(dest.icon, size: 80, color: const Color(0xFF086C61)),
                ),
              ),
              // Anchor pin
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF086C61),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8), // Lift it slightly off the exact point
            ],
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        );
      }

      // Small discovery landmark
      return Marker(
        point: dest.position,
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            final wp = RouteWaypoint(
              id: dest.id,
              title: dest.name,
              position: dest.position,
              type: 'destination',
            );
            provider.selectWaypoint(wp);
            _animatedMapMove(dest.position, 14.5);
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => LocationDetailSheet(
                waypoint: wp,
                sequenceNumber: 0,
                provider: provider,
              ),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white70,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Icon(dest.icon, color: const Color(0xFF086C61), size: 24),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFloatingToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF086C61) : const Color(0xFFE8F2F6).withAlpha(240),
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
            icon: Icon(icon, size: 20, color: isActive ? Colors.white : const Color(0xFF086C61)),
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
        borderRadius: BorderRadius.circular(TravelGoMapTokens.radiusSmall),
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
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.1, end: 0);
  }
  List<Marker> _buildGroupMemberMarkers(MapProvider provider) {
    return provider.groupMembers.map((member) {
      final isSelected =
          provider.selectedGroupMember?.memberId == member.memberId;
      return Marker(
        point: member.position,
        width: 84,
        height: 70,
        child: GestureDetector(
          onTap: () {
            provider.selectGroupMember(member.memberId);
            final distMeters =
                provider.distanceToGroupMemberMeters(member).round();
            final distStr = distMeters >= 1000
                ? '${(distMeters / 1000).toStringAsFixed(1)} km'
                : '$distMeters m';
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF4338CA),
                      child: Text(
                        member.avatarInitials,
                        style: const TextStyle(
                          fontSize: 10,
                          color: const Color(0xFFE8F2F6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${member.displayName} · Cách bạn $distStr'),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isSelected ? 38 : 34,
                    height: isSelected ? 38 : 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected ? const Color(0xFFF59E0B) : Colors.white,
                        width: isSelected ? 3.0 : 2.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        member.avatarInitials,
                        style: const TextStyle(
                          color: const Color(0xFFE8F2F6),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: member.status == GroupMemberStatus.online
                            ? const Color(0xFF10B981)
                            : (member.status == GroupMemberStatus.idle
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF94A3B8)),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE8F2F6), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F6),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _openGroupRadarSheet(BuildContext context, MapProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupRadarSheet(provider: provider),
    );
  }
}

/// LatLngTween for smooth 60 FPS camera motion across geographic coordinates.
class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    final b = begin ?? const LatLng(0, 0);
    final e = end ?? const LatLng(0, 0);
    return LatLng(
      b.latitude + (e.latitude - b.latitude) * t,
      b.longitude + (e.longitude - b.longitude) * t,
    );
  }
}
