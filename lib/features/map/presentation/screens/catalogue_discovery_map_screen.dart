import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../explore/models/catalogue_reference.dart';
import '../../../explore/models/public_catalogue_snapshot.dart';
import '../../../explore/providers/discovery_provider.dart';
import '../../../explore/providers/public_catalogue_provider.dart';
import '../../../explore/services/manual_place_locations.dart';
import '../../../explore/presentation/screens/destination_detail_screen.dart';
import '../../models/catalogue_map_marker.dart';
import '../widgets/place_map_preview_card.dart';
import '../widgets/vietnamese_sovereignty_layer.dart';

class CatalogueDiscoveryMapScreen extends StatefulWidget {
  final CatalogueReference? initialCatalogue;
  final PublicCatalogueSnapshot? initialSnapshot;
  final bool enableNetworkTiles;

  const CatalogueDiscoveryMapScreen({
    super.key,
    this.initialCatalogue,
    this.initialSnapshot,
    this.enableNetworkTiles = true,
  });

  @override
  State<CatalogueDiscoveryMapScreen> createState() =>
      _CatalogueDiscoveryMapScreenState();
}

class _CatalogueDiscoveryMapScreenState
    extends State<CatalogueDiscoveryMapScreen> {
  late final MapController _mapController;
  DestinationReference? _selectedDestination;
  CatalogueMapMarker? _selectedMarker;

  static const LatLng _vietnamCenter = LatLng(16.047079, 108.206230);
  static const double _initialZoom = 6.0;

  static const Map<String, LatLng> _knownDestinationCoords = {
    'ha-noi': LatLng(21.0285, 105.8542),
    'da-nang': LatLng(16.0544, 108.2022),
    'da-lat': LatLng(11.9404, 108.4583),
    'phu-quoc': LatLng(10.2899, 103.9840),
    'tp-ho-chi-minh': LatLng(10.8231, 106.6297),
    'nha-trang': LatLng(12.2388, 109.1967),
    'hue': LatLng(16.4637, 107.5909),
    'quang-ninh': LatLng(20.9505, 107.0734),
    'hoi-an': LatLng(15.8801, 108.3380),
    'sapa': LatLng(22.3364, 103.8438),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  CatalogueReference? _resolveCatalogue() {
    if (widget.initialCatalogue != null) return widget.initialCatalogue;
    try {
      final publicProv = context.watch<PublicCatalogueProvider?>();
      if (publicProv?.snapshot?.catalogue != null) {
        return publicProv!.snapshot!.catalogue;
      }
    } catch (_) {}

    try {
      final discProv = context.watch<DiscoveryProvider?>();
      if (discProv?.catalogue != null) return discProv!.catalogue;
    } catch (_) {}

    return null;
  }

  PublicCatalogueSnapshot? _resolveSnapshot() {
    if (widget.initialSnapshot != null) return widget.initialSnapshot;
    try {
      final publicProv = context.watch<PublicCatalogueProvider?>();
      return publicProv?.snapshot;
    } catch (_) {
      return null;
    }
  }

  LatLng _resolveDestinationCoords(DestinationReference destination) {
    if (_knownDestinationCoords.containsKey(destination.id)) {
      return _knownDestinationCoords[destination.id]!;
    }
    final snapshot = _resolveSnapshot();
    for (final place in destination.places) {
      if (place.latitude != null && place.longitude != null) {
        return LatLng(place.latitude!, place.longitude!);
      }
      final manual = ManualPlaceLocations.find(place.id, snapshot: snapshot);
      if (manual != null) {
        return LatLng(manual.position.latitude, manual.position.longitude);
      }
    }
    return _vietnamCenter;
  }

  LatLng _resolvePlaceCoords(
    PlaceReference place,
    DestinationReference destination,
    int index,
  ) {
    if (place.latitude != null && place.longitude != null) {
      return LatLng(place.latitude!, place.longitude!);
    }
    final snapshot = _resolveSnapshot();
    final manual = ManualPlaceLocations.find(place.id, snapshot: snapshot);
    if (manual != null) {
      return LatLng(manual.position.latitude, manual.position.longitude);
    }
    final center = _resolveDestinationCoords(destination);
    final latOffset = (index % 3 - 1) * 0.015;
    final lngOffset = ((index ~/ 3) % 3 - 1) * 0.015;
    return LatLng(center.latitude + latOffset, center.longitude + lngOffset);
  }

  double _resolvePlaceRating(PlaceReference place) {
    final lowerName = place.name.toLowerCase();
    if (lowerName.contains('bà nà') ||
        lowerName.contains('hồ xuân hương') ||
        lowerName.contains('linh phước') ||
        lowerName.contains('fansipan') ||
        lowerName.contains('hạ long') ||
        lowerName.contains('phú quốc')) {
      return 4.8;
    }
    if (lowerName.contains('chợ') || lowerName.contains('vườn hoa')) {
      return 4.2;
    }
    return 3.8;
  }

  void _onDestinationTapped(DestinationReference destination) {
    final coords = _resolveDestinationCoords(destination);
    setState(() {
      _selectedDestination = destination;
      _selectedMarker = CatalogueMapMarker(
        id: destination.id,
        title: destination.name,
        subtitle: '${destination.places.length} địa điểm tham quan',
        point: coords,
        type: MarkerType.destination,
      );
    });
    try {
      _mapController.move(coords, 13.0);
    } catch (_) {}
  }

  void _resetToNationalView() {
    setState(() {
      _selectedDestination = null;
      _selectedMarker = null;
    });
    try {
      _mapController.move(_vietnamCenter, _initialZoom);
    } catch (_) {}
  }

  void _openDetails(CatalogueMapMarker marker) {
    final catalogue = _resolveCatalogue();
    if (catalogue == null) return;

    if (marker.type == MarkerType.destination) {
      final dest = catalogue.destinations
          .where((d) => d.id == marker.id)
          .firstOrNull;
      if (dest != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(
              catalogue: catalogue,
              destination: dest,
            ),
          ),
        );
      }
    } else if (marker.type == MarkerType.place) {
      final dest = catalogue.destinations
          .where((d) => d.id == marker.destinationId || d.places.any((p) => p.id == marker.id))
          .firstOrNull;
      if (dest != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(
              catalogue: catalogue,
              destination: dest,
            ),
          ),
        );
      }
    }
  }

  List<Marker> _buildMapMarkers(CatalogueReference? catalogue) {
    final markers = <Marker>[];

    // 1. Thêm 2 ghim chủ quyền biển đảo Việt Nam
    for (final sovMarker in VietnameseSovereigntyLayer.markers) {
      markers.add(
        Marker(
          point: sovMarker.point,
          width: 140,
          height: 60,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMarker = sovMarker;
              });
            },
            child: VietnameseSovereigntyLayer.buildSovereigntyBadge(sovMarker),
          ),
        ),
      );
    }

    if (catalogue == null) return markers;

    if (_selectedDestination == null) {
      // 2. Chế độ Xem Toàn Cảnh: Marker Điểm đến
      for (final destination in catalogue.destinations) {
        final point = _resolveDestinationCoords(destination);

        markers.add(
          Marker(
            point: point,
            width: 90,
            height: 70,
            child: GestureDetector(
              onTap: () => _onDestinationTapped(destination),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_city, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            destination.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.deepPurple, size: 20),
                ],
              ),
            ),
          ),
        );
      }
    } else {
      // 3. Chế độ Phóng To Địa Điểm Con (Drill-down)
      final dest = _selectedDestination!;
      for (int i = 0; i < dest.places.length; i++) {
        final place = dest.places[i];
        final point = _resolvePlaceCoords(place, dest, i);
        final rating = _resolvePlaceRating(place);

        final markerData = CatalogueMapMarker(
          id: place.id,
          title: place.name,
          subtitle: dest.name,
          point: point,
          type: MarkerType.place,
          averageRating: rating,
          reviewCount: rating >= 4.5 ? 98 : 24,
          destinationId: dest.id,
        );

        markers.add(
          Marker(
            point: point,
            width: markerData.markerSize + 20,
            height: markerData.markerSize + 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMarker = markerData;
                });
              },
              child: _buildPlaceMarkerWidget(markerData),
            ),
          ),
        );
      }
    }

    return markers;
  }

  Widget _buildPlaceMarkerWidget(CatalogueMapMarker marker) {
    final isSelected = _selectedMarker?.id == marker.id;

    if (marker.isTopRated) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.amber.shade500,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.amber.shade200,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.6),
              blurRadius: isSelected ? 12 : 6,
              spreadRadius: isSelected ? 4 : 2,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.star, color: Colors.white, size: 20),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: marker.markerColor,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.white70,
          width: isSelected ? 3 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          marker.iconData,
          color: Colors.white,
          size: marker.markerSize * 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = _resolveCatalogue();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản Đồ Khám Phá'),
        actions: [
          if (_selectedDestination != null)
            TextButton.icon(
              onPressed: _resetToNationalView,
              icon: const Icon(Icons.zoom_out_map, color: Colors.white, size: 18),
              label: const Text(
                'Toàn cảnh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            tooltip: 'Làm mới danh mục',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              try {
                context.read<DiscoveryProvider?>()?.load(force: true);
                context.read<PublicCatalogueProvider?>()?.refresh(force: true);
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _vietnamCenter,
              initialZoom: _initialZoom,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              if (widget.enableNetworkTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.travelgo.mobile',
                  errorTileCallback: (tile, error, stackTrace) {
                    // Gracefully ignore network tile download failures when offline
                  },
                ),
              MarkerLayer(
                markers: _buildMapMarkers(catalogue),
              ),
            ],
          ),

          // Header thông báo khi đang trong chế độ drill-down Điểm đến
          if (_selectedDestination != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: Colors.deepPurple, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang xem: ${_selectedDestination!.name} (${_selectedDestination!.places.length} địa điểm)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _resetToNationalView,
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Thẻ xem trước chi tiết Marker ở đáy màn hình
          if (_selectedMarker != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: PlaceMapPreviewCard(
                marker: _selectedMarker!,
                onDetailsPressed: () => _openDetails(_selectedMarker!),
                onClosePressed: () {
                  setState(() {
                    _selectedMarker = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
