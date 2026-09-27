import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_models.dart';
import '../../providers/map_provider.dart';
import '../widgets/member_radar_sheet.dart';

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
      provider.setMode(widget.initialMode);
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
      if (provider.currentMode == MapMode.routing) {
        final route = provider.currentRoute;
        if (route != null && route.points.length >= 2) {
          final bounds = LatLngBounds.fromPoints(route.points);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(40, 100, 40, 220),
            ),
          );
          return;
        }
      }

      // Radar mode: Fit all group members
      final members = provider.groupMembers;
      if (members.isNotEmpty) {
        final points = members.map((m) => m.position).toList();
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(50, 100, 50, 300),
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
    final mode = provider.currentMode;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bản Đồ OpenStreetMap',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_free_rounded),
            tooltip: 'Căn chỉnh khung hình',
            onPressed: () => _fitCameraToBounds(provider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      title: 'Lộ Trình Du Lịch',
                      icon: Icons.directions_outlined,
                      isSelected: mode == MapMode.routing,
                      onTap: () {
                        provider.setMode(MapMode.routing);
                        _fitCameraToBounds(provider);
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      title: 'Radar Nhóm',
                      icon: Icons.radar_outlined,
                      isSelected: mode == MapMode.radar,
                      onTap: () {
                        provider.setMode(MapMode.radar);
                        _fitCameraToBounds(provider);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Canvas
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travelgo.travelgo_mobile',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'TravelGO-Mobile/1.0 (contact: support@travelgo.vn)',
                  },
                ),
              ),

              // Routing Mode Polyline
              if (mode == MapMode.routing && provider.currentRoute != null)
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

              // Radar Mode Lines (Dashed connection lines from members to leader)
              if (mode == MapMode.radar && provider.leader != null)
                PolylineLayer(
                  polylines: provider.groupMembers.where((m) => !m.isLeader).map((m) {
                    return Polyline(
                      points: [m.position, provider.leader!.position],
                      strokeWidth: 2.2,
                      color: m.status.color.withValues(alpha: 0.8),
                    );
                  }).toList(),
                ),

              // Markers Layer
              MarkerLayer(
                markers: mode == MapMode.routing
                    ? _buildRoutingMarkers(provider)
                    : _buildRadarMarkers(provider),
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
                if (mode == MapMode.routing && provider.currentRoute?.isFallback == true)
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

          // 4. Floating Routing Summary Card (in routing mode)
          if (mode == MapMode.routing && provider.currentRoute != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildRouteSummaryCard(context, provider),
            ),

          // 5. Member Radar Bottom Sheet (in radar mode)
          if (mode == MapMode.radar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MemberRadarSheet(
                provider: provider,
                onMemberSelected: () {
                  final selected = provider.selectedMember;
                  if (selected != null) {
                    _mapController.move(selected.position, 16.0);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF086C61) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF086C61) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
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

  List<Marker> _buildRadarMarkers(MapProvider provider) {
    return provider.groupMembers.map((member) {
      final isSelected = provider.selectedMember?.id == member.id;
      final status = member.status;

      return Marker(
        point: member.position,
        width: 80,
        height: 70,
        child: GestureDetector(
          onTap: () {
            provider.selectMember(member);
            _mapController.move(member.position, 16.0);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : status.backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: status.color, width: 1.2),
                ),
                child: Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : status.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              CircleAvatar(
                radius: member.isLeader ? 18 : 15,
                backgroundColor: member.avatarColor,
                child: Text(
                  member.avatarText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
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
