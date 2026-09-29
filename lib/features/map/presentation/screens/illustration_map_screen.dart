import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/map_state_provider.dart';
import '../widgets/mascot_marker_widget.dart';

class IllustrationMapScreen extends StatelessWidget {
  const IllustrationMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mascotType = context.select((MapStateProvider p) => p.activeMascot);
    
    return Scaffold(
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(21.0285, 105.8542), // Hanoi Coordinates
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            errorTileCallback: (tile, error, stackTrace) {
              debugPrint("Lỗi tải bản đồ (Offline Mode Triggered)");
            },
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(21.0285, 105.8542),
                width: 60,
                height: 60,
                child: MascotMarkerWidget(type: mascotType),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
