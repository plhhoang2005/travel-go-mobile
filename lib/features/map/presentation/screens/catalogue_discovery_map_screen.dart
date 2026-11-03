import '../../../../core/widgets/global_profile_avatar_action.dart';
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
import '../../../trip_planner/presentation/screens/home_planner_screen.dart';
import '../../../trip_planner/presentation/widgets/planner_workspace_actions.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/catalogue_map_marker.dart';
import '../widgets/place_map_preview_card.dart';
import '../widgets/vietnamese_sovereignty_layer.dart';

class CatalogueDiscoveryMapScreen extends StatefulWidget {
  final CatalogueReference? initialCatalogue;
  final PublicCatalogueSnapshot? initialSnapshot;
  final bool enableNetworkTiles;
  final bool showBackButton;

  const CatalogueDiscoveryMapScreen({
    super.key,
    this.initialCatalogue,
    this.initialSnapshot,
    this.enableNetworkTiles = true,
    this.showBackButton = true,
  });

  static LatLng resolveDestinationCoords(
    DestinationReference destination, {
    PublicCatalogueSnapshot? snapshot,
  }) =>
      _CatalogueDiscoveryMapScreenState.resolveDestinationCoords(
        destination,
        snapshot: snapshot,
      );

  @override
  State<CatalogueDiscoveryMapScreen> createState() =>
      _CatalogueDiscoveryMapScreenState();
}

class _CatalogueDiscoveryMapScreenState
    extends State<CatalogueDiscoveryMapScreen> {
  late final MapController _mapController;
  DestinationReference? _selectedDestination;
  CatalogueMapMarker? _selectedMarker;
  final Set<String> _hiddenPlaceIds = {};

  void _togglePlaceHide(CatalogueMapMarker marker) {
    final willHide = !_hiddenPlaceIds.contains(marker.id);
    setState(() {
      if (willHide) {
        _hiddenPlaceIds.add(marker.id);
      } else {
        _hiddenPlaceIds.remove(marker.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willHide
              ? 'Admin đã ẩn "${marker.title}" khỏi bản đồ!'
              : 'Admin đã khôi phục "${marker.title}" trên bản đồ!',
        ),
        backgroundColor:
            willHide ? Colors.red.shade700 : Colors.teal.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const LatLng _vietnamCenter = LatLng(16.047079, 108.206230);
  static const double _initialZoom = 6.0;

  static const Map<String, LatLng> _knownDestinationCoords = {
    'ha-noi': LatLng(21.0285, 105.8542),
    'ha-long': LatLng(20.9505, 107.0734),
    'quang-ninh': LatLng(20.9505, 107.0734),
    'sapa': LatLng(22.3364, 103.8438),
    'sa-pa': LatLng(22.3364, 103.8438),
    'ninh-binh': LatLng(20.2506, 105.9745),
    'hue': LatLng(16.4637, 107.5909),
    'da-nang': LatLng(16.0544, 108.2022),
    'hoi-an': LatLng(15.8801, 108.3380),
    'nha-trang': LatLng(12.2388, 109.1967),
    'da-lat': LatLng(11.9404, 108.4583),
    'ho-chi-minh': LatLng(10.8231, 106.6297),
    'tp-ho-chi-minh': LatLng(10.8231, 106.6297),
    'can-tho': LatLng(10.0452, 105.7469),
    'phu-quoc': LatLng(10.2899, 103.9840),
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

  CatalogueReference? _resolveCatalogue({bool listen = false}) {
    if (widget.initialCatalogue != null) return widget.initialCatalogue;
    try {
      final publicProv = listen
          ? context.watch<PublicCatalogueProvider?>()
          : context.read<PublicCatalogueProvider?>();
      if (publicProv?.snapshot?.catalogue != null) {
        return publicProv!.snapshot!.catalogue;
      }
    } catch (_) {}

    try {
      final discProv = listen
          ? context.watch<DiscoveryProvider?>()
          : context.read<DiscoveryProvider?>();
      if (discProv?.catalogue != null) return discProv!.catalogue;
    } catch (_) {}

    if (widget.initialSnapshot?.catalogue != null) {
      return widget.initialSnapshot!.catalogue;
    }

    return null;
  }

  PublicCatalogueSnapshot? _resolveSnapshot({bool listen = false}) {
    if (widget.initialSnapshot != null) return widget.initialSnapshot;
    try {
      final publicProv = listen
          ? context.watch<PublicCatalogueProvider?>()
          : context.read<PublicCatalogueProvider?>();
      return publicProv?.snapshot;
    } catch (_) {
      return null;
    }
  }

  static LatLng resolveDestinationCoords(
    DestinationReference destination, {
    PublicCatalogueSnapshot? snapshot,
  }) {
    final key = destination.id.toLowerCase().replaceAll('_', '-');
    if (_knownDestinationCoords.containsKey(key)) {
      return _knownDestinationCoords[key]!;
    }
    final nameLower = destination.name.toLowerCase();
    if (nameLower.contains('cần thơ')) return const LatLng(10.0452, 105.7469);
    if (nameLower.contains('hà nội')) return const LatLng(21.0285, 105.8542);
    if (nameLower.contains('hạ long') || nameLower.contains('quảng ninh')) {
      return const LatLng(20.9505, 107.0734);
    }
    if (nameLower.contains('sa pa') || nameLower.contains('sapa')) {
      return const LatLng(22.3364, 103.8438);
    }
    if (nameLower.contains('ninh bình')) return const LatLng(20.2506, 105.9745);
    if (nameLower.contains('huế')) return const LatLng(16.4637, 107.5909);
    if (nameLower.contains('đà nẵng')) return const LatLng(16.0544, 108.2022);
    if (nameLower.contains('hội an')) return const LatLng(15.8801, 108.3380);
    if (nameLower.contains('nha trang')) return const LatLng(12.2388, 109.1967);
    if (nameLower.contains('đà lạt')) return const LatLng(11.9404, 108.4583);
    if (nameLower.contains('hồ chí minh') || nameLower.contains('sài gòn')) {
      return const LatLng(10.8231, 106.6297);
    }
    if (nameLower.contains('phú quốc')) return const LatLng(10.2899, 103.9840);

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

  LatLng _resolveDestinationCoords(DestinationReference destination) {
    return resolveDestinationCoords(
      destination,
      snapshot: _resolveSnapshot(listen: false),
    );
  }

  LatLng _resolvePlaceCoords(
    PlaceReference place,
    DestinationReference destination,
    int index,
  ) {
    if (place.latitude != null && place.longitude != null) {
      return LatLng(place.latitude!, place.longitude!);
    }
    final snapshot = _resolveSnapshot(listen: false);
    final manual = ManualPlaceLocations.find(place.id, snapshot: snapshot) ??
        ManualPlaceLocations.find('${destination.id}/${place.id}', snapshot: snapshot) ??
        ManualPlaceLocations.forPlace(place.id);
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
    final catalogue = _resolveCatalogue(listen: false);

    if (marker.type == MarkerType.destination) {
      final dest = catalogue?.destinations
          .where((d) => d.id == marker.id || d.name == marker.title)
          .firstOrNull;
      if (dest != null && catalogue != null) {
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
      DestinationReference? dest = _selectedDestination;
      if (dest == null && catalogue != null) {
        dest = catalogue.destinations
            .where((d) =>
                d.id == marker.destinationId ||
                d.places.any((p) => p.id == marker.id || p.name == marker.title))
            .firstOrNull;
      }

      final place = dest?.places
          .where((p) => p.id == marker.id || p.name == marker.title)
          .firstOrNull;

      if (dest != null && place != null) {
        _showPlaceDetailModal(dest, place, marker);
      } else if (dest != null && catalogue != null) {
        final targetDest = dest;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(
              catalogue: catalogue,
              destination: targetDest,
            ),
          ),
        );
      }
    }
  }

  void _showPlaceDetailModal(
    DestinationReference dest,
    PlaceReference place,
    CatalogueMapMarker marker,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalogue = _resolveCatalogue(listen: false);
    SourceReference? source;
    try {
      source = catalogue?.source(place.sourceId);
    } catch (_) {}

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: marker.markerColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          marker.iconData,
                          color: marker.markerColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dest.name} · ${dest.region}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            marker.averageRating > 0
                                ? marker.averageRating.toStringAsFixed(1)
                                : 'Mới',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${marker.reviewCount} lượt đánh giá)',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (marker.isTopRated)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '⭐ Điểm Đến Nổi Bật',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Vị trí địa lý',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.explore_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tọa độ: ${marker.point.latitude.toStringAsFixed(4)}, ${marker.point.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thông tin tham quan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Giờ mở cửa & giá vé: Theo nguồn tham khảo',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (source != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Nguồn: ${source.title} (${source.publisher})',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            'Kiểm tra ngày: ${source.checkedAt}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final accepted = await replacePlannerWorkspace(
                          context,
                          destinationId: dest.id,
                          destinationName: dest.name,
                        );
                        if (!accepted || !mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HomePlannerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Chuẩn bị chuyến đi tới đây'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        if (catalogue != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DestinationDetailScreen(
                                catalogue: catalogue,
                                destination: dest,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.location_city),
                      label: Text('Xem toàn cảnh ${dest.name}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Marker> _buildMapMarkers(
    CatalogueReference? catalogue, {
    bool isAdmin = false,
  }) {
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
        final isHidden = _hiddenPlaceIds.contains(place.id);
        if (!isAdmin && isHidden) {
          // Người dùng bình thường không nhìn thấy địa điểm đã bị ẩn
          continue;
        }
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
              child: _buildPlaceMarkerWidget(markerData, isHidden: isHidden),
            ),
          ),
        );
      }
    }

    return markers;
  }

  Widget _buildPlaceMarkerWidget(
    CatalogueMapMarker marker, {
    bool isHidden = false,
  }) {
    final isSelected = _selectedMarker?.id == marker.id;

    if (isHidden) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueGrey.shade700,
          border: Border.all(
            color: isSelected ? Colors.red.shade400 : Colors.red.shade200,
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
            Icons.visibility_off,
            color: Colors.white70,
            size: marker.markerSize * 0.45,
          ),
        ),
      );
    }

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
    final catalogue = _resolveCatalogue(listen: true);
    final auth = context.watch<AuthProvider?>();
    final isAdmin = auth?.currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
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
          const GlobalProfileAvatarAction(),
        ],
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
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
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.travelgo.travelgo_mobile',
                    keepBuffer: 3,
                    panBuffer: 1,
                    maxNativeZoom: 18,
                    maxZoom: 19,
                    tileDisplay: const TileDisplay.fadeIn(),
                    tileUpdateTransformer: TileUpdateTransformers.throttle(
                      const Duration(milliseconds: 120),
                    ),
                    errorTileCallback: (tile, error, stackTrace) {
                      // Gracefully ignore network tile download failures when offline
                    },
                  ),
                MarkerLayer(
                  markers: _buildMapMarkers(catalogue, isAdmin: isAdmin),
                ),
              ],
            ),
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
                isAdmin: isAdmin,
                isPlaceHidden: _hiddenPlaceIds.contains(_selectedMarker!.id),
                onAdminToggleHide: () => _togglePlaceHide(_selectedMarker!),
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
