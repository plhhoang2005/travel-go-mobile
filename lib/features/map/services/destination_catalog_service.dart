import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Destination {
  final String id;
  final String name;
  final String region;
  final LatLng position;
  final IconData icon;

  const Destination({
    required this.id,
    required this.name,
    required this.region,
    required this.position,
    required this.icon,
  });
}

class DestinationCatalogService {
  static const List<Destination> _catalog = [
    Destination(
      id: 'hcm',
      name: 'TP. Hồ Chí Minh',
      region: 'Nam Bộ',
      position: LatLng(10.7769, 106.7009),
      icon: Icons.location_city,
    ),
    Destination(
      id: 'dalat',
      name: 'Đà Lạt',
      region: 'Tây Nguyên',
      position: LatLng(11.9404, 108.4583),
      icon: Icons.local_florist,
    ),
    Destination(
      id: 'nhatrang',
      name: 'Nha Trang',
      region: 'Duyên hải Nam Trung Bộ',
      position: LatLng(12.2395, 109.1960),
      icon: Icons.beach_access,
    ),
    Destination(
      id: 'phuquoc',
      name: 'Phú Quốc',
      region: 'Tây Nam Bộ',
      position: LatLng(10.2899, 103.9840),
      icon: Icons.wb_sunny_outlined,
    ),
    Destination(
      id: 'vungtau',
      name: 'Vũng Tàu',
      region: 'Đông Nam Bộ',
      position: LatLng(10.3460, 107.0842),
      icon: Icons.sailing,
    ),
    Destination(
      id: 'cantho',
      name: 'Cần Thơ',
      region: 'Đồng bằng sông Cửu Long',
      position: LatLng(10.0452, 105.7469),
      icon: Icons.directions_boat_filled,
    ),
    Destination(
      id: 'sapa',
      name: 'Sa Pa',
      region: 'Tây Bắc',
      position: LatLng(22.3364, 103.8438),
      icon: Icons.terrain,
    ),
  ];

  List<Destination> getAll() {
    return List<Destination>.unmodifiable(_catalog);
  }

  List<Destination> search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return getAll();
    }
    return _catalog.where((dest) {
      return dest.name.toLowerCase().contains(trimmed) ||
          dest.region.toLowerCase().contains(trimmed);
    }).toList();
  }
}
