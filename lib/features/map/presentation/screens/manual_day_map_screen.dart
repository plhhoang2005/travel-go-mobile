import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../explore/models/public_catalogue_snapshot.dart';

import '../../../trip_planner/models/editable_trip_document.dart';
import '../../../trip_planner/presentation/widgets/manual_itinerary_timeline.dart';
import '../../services/manual_place_locations.dart';
import '../widgets/vietnamese_sovereignty_layer.dart';

class ManualDayMapScreen extends StatefulWidget {
  final EditableTripDocumentV2 document;
  final String dayId;
  final bool enableNetworkTiles;
  final PublicCatalogueSnapshot? snapshot;
  const ManualDayMapScreen({
    super.key,
    required this.document,
    required this.dayId,
    this.enableNetworkTiles = true,
    this.snapshot,
  });
  @override
  State<ManualDayMapScreen> createState() => _ManualDayMapScreenState();
}

class _ManualDayMapScreenState extends State<ManualDayMapScreen> {
  final _controller = MapController();
  bool _tileFailure = false, _failureScheduled = false;
  String? _selected;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _failed() {
    if (_tileFailure || _failureScheduled || !mounted) return;
    _failureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tileFailure = true);
    });
  }

  void _select(_DayStop stop) {
    final location = stop.location;
    if (location == null) return;
    _controller.move(location.position, 15);
    setState(() => _selected = stop.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.document.days
        .where((d) => d.id == widget.dayId)
        .firstOrNull;
    final items =
        widget.document.items.where((i) => i.dayId == day?.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    final stops = [
      for (final (index, item) in items.indexed)
        _DayStop(item, index + 1, snapshot: widget.snapshot),
    ];
    final located = stops.where((s) => s.location != null).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          day == null ? 'Bản đồ lịch trình' : 'Bản đồ ngày ${day.ordinal}',
        ),
      ),
      body: SafeArea(
        child: day == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ngày này không còn trong lịch trình.'),
                ),
              )
            : CustomScrollView(
                key: const ValueKey('manual.dayMap.scroll'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: _DayMapOverview(
                        day: day,
                        count: stops.length,
                        locatedCount: located.length,
                        tileFailure: _tileFailure,
                        enableNetworkTiles: widget.enableNetworkTiles,
                        canvas: located.isEmpty
                            ? null
                            : _DayMapCanvas(
                                stops: located,
                                controller: _controller,
                                selected: _selected,
                                onSelect: _select,
                                enableNetworkTiles: widget.enableNetworkTiles,
                                onTileFailure: _failed,
                              ),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: stops.length,
                    itemBuilder: (context, index) => _DayStopTile(
                      stop: stops[index],
                      selected: _selected == stops[index].item.id,
                      onSelect: () => _select(stops[index]),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }
}

class _DayMapOverview extends StatelessWidget {
  final TripDay day;
  final int count, locatedCount;
  final bool tileFailure, enableNetworkTiles;
  final Widget? canvas;
  const _DayMapOverview({
    required this.day,
    required this.count,
    required this.locatedCount,
    required this.tileFailure,
    required this.enableNetworkTiles,
    required this.canvas,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(manualDayLabel(day), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('$locatedCount/$count hoạt động có vị trí tham khảo'),
      const SizedBox(height: 8),
      const Text(
        'Số trên bản đồ theo thứ tự lịch trình. Chưa có tuyến đường, thời gian di chuyển hoặc xác nhận lối vào.',
      ),
      if (tileFailure || !enableNetworkTiles) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            tileFailure
                ? 'Không tải được nền bản đồ. Danh sách và vị trí tham khảo vẫn còn bên dưới.'
                : 'Nền bản đồ đang tắt. Bạn vẫn xem được danh sách và vị trí tham khảo.',
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (canvas == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Ngày này chưa có tọa độ đã đối chiếu.'),
        )
      else
        SizedBox(height: 280, child: canvas!),
      const SizedBox(height: 16),
      Text(
        'Các hoạt động trong ngày',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (count == 0) const Text('Ngày này chưa có hoạt động.'),
    ],
  );
}

class _StopMarker extends StatelessWidget {
  final _DayStop stop;
  final bool selected;
  final VoidCallback onTap;
  const _StopMarker({
    required this.stop,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Vị trí ${stop.ordinal}: ${stop.item.title}',
    button: true,
    excludeSemantics: true,
    onTap: onTap,
    child: Tooltip(
      message: stop.item.title,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: selected
              ? Theme.of(context).colorScheme.tertiary
              : null,
        ),
        onPressed: onTap,
        child: Text('${stop.ordinal}'),
      ),
    ),
  );
}

class _DayStop {
  final TripItem item;
  final int ordinal;
  final ManualPlaceLocation? location;
  _DayStop(this.item, this.ordinal, {PublicCatalogueSnapshot? snapshot})
    : location = ManualPlaceLocations.find(item.placeId, snapshot: snapshot);
}

class _DayMapCanvas extends StatelessWidget {
  final List<_DayStop> stops;
  final MapController controller;
  final String? selected;
  final ValueChanged<_DayStop> onSelect;
  final bool enableNetworkTiles;
  final VoidCallback onTileFailure;
  const _DayMapCanvas({
    required this.stops,
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.enableNetworkTiles,
    required this.onTileFailure,
  });
  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: controller,
    options: MapOptions(
      initialCenter: stops.first.location!.position,
      initialZoom: 14,
      minZoom: 4,
      maxZoom: 18,
      onMapReady: () {
        final points = stops.map((s) => s.location!.position).toSet().toList();
        if (points.length > 1) {
          controller.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(48),
              maxZoom: 15,
            ),
          );
        }
      },
    ),
    children: [
      if (enableNetworkTiles)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.travelgo.travelgo_mobile',
          errorTileCallback: (_, error, trace) => onTileFailure(),
        ),
      const VietnameseSovereigntyLayer(),
      MarkerLayer(
        markers: [
          for (final stop in stops)
            Marker(
              point: stop.location!.position,
              width:
                  (24 +
                          MediaQuery.textScalerOf(context).scale(16) *
                              '${stop.ordinal}'.length)
                      .clamp(48, double.infinity)
                      .toDouble(),
              height: (24 + MediaQuery.textScalerOf(context).scale(20))
                  .clamp(48, double.infinity)
                  .toDouble(),
              child: _StopMarker(
                stop: stop,
                selected: selected == stop.item.id,
                onTap: () => onSelect(stop),
              ),
            ),
        ],
      ),
      Align(
        alignment: Alignment.bottomLeft,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              '© OpenStreetMap contributors\nopenstreetmap.org/copyright · flutter_map',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
    ],
  );
}

class _DayStopTile extends StatelessWidget {
  final _DayStop stop;
  final bool selected;
  final VoidCallback onSelect;
  const _DayStopTile({
    required this.stop,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final location = stop.location;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: selected,
            leading: Text(
              '${stop.ordinal}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            title: Text(stop.item.title),
            subtitle: Text(
              '${manualTimeLabel(stop.item)}\n${location == null ? (stop.item.placeId == null ? 'Chưa liên kết địa điểm; chưa có tọa độ.' : 'Địa điểm này chưa có tọa độ đã đối chiếu.') : location.note}',
            ),
            onTap: location == null ? null : onSelect,
          ),
          if (location != null)
            ExpansionTile(
              title: const Text('Nguồn vị trí'),
              children: [
                Text(
                  '${location.position.latitude.toStringAsFixed(6)}, ${location.position.longitude.toStringAsFixed(6)} · Đối chiếu ${location.checkedAt}',
                ),
                SelectableText(location.sourceUrl),
              ],
            ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
