import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';

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
  late final MapController _mapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

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

  void _fitCameraToBounds(MapProvider provider) {
    if (!mounted || !_isMapReady) return;
    try {
      final route = provider.currentRoute;
      if (route != null && route.points.length >= 2) {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapProvider>();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lộ Trình Du Lịch',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_free_rounded),
            tooltip: 'Căn chỉnh khung hình',
            onPressed: () => _fitCameraToBounds(provider),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Canvas (Powered by CartoDB OSM CDN)
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
                urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travelgo.travelgo_mobile',
                tileProvider: NetworkTileProvider(),
              ),

              // Routing Mode Polyline
              if (provider.currentRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: provider.currentRoute!.points,
                      strokeWidth: 4.5,
                      color: provider.currentRoute!.isFallback
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF086C61),
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: _buildRoutingMarkers(provider),
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

          // 3. Loading Overlay
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

          // 4. Floating Routing Summary Card
          if (provider.currentRoute != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildRouteSummaryCard(context, provider),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildRoutingMarkers(MapProvider provider) {
    final markers = <Marker>[];

    // Origin Marker (Cổng Trường / Điểm xuất phát)
    markers.add(
      Marker(
        point: provider.origin,
        width: 140,
        height: 60,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF086C61),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Text(
                'Điểm Xuất Phát',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.location_pin, color: Color(0xFF086C61), size: 30),
          ],
        ),
      ),
    );

    // Destination Marker
    markers.add(
      Marker(
        point: provider.destination,
        width: 160,
        height: 60,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                provider.destinationName,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.location_pin, color: Color(0xFFE11D48), size: 30),
          ],
        ),
      ),
    );

    // Intermediate Waypoint Markers
    for (final wp in provider.waypoints) {
      markers.add(
        Marker(
          point: wp.position,
          width: 120,
          height: 50,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  wp.title,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.place, color: Color(0xFF475569), size: 22),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildRouteSummaryCard(BuildContext context, MapProvider provider) {
    final route = provider.currentRoute!;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, color: Color(0xFF086C61), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route.summary,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF086C61).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'OSRM Driving',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF086C61)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatColumn('Quãng đường', route.formattedDistance, Icons.straighten),
                Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                _buildStatColumn('Thời gian ước tính', route.formattedDuration, Icons.schedule),
                Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                _buildStatColumn('Điểm dừng', '${route.waypoints.length} trạm', Icons.flag_outlined),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.trip_origin, size: 14, color: Color(0xFF086C61)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    provider.originName,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Icon(Icons.location_on, size: 14, color: Color(0xFFE11D48)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    provider.destinationName,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
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
