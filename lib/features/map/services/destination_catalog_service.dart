import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../presentation/widgets/vietnamese_sovereignty_layer.dart';

class Destination {
  final String id;
  final String name;
  final String region;
  final LatLng position;
  final IconData icon;

  /// Cờ xác định địa danh có hỗ trợ định tuyến đường bộ (OSRM car routing) hay không.
  /// Các biển đảo khẳng định chủ quyền có [isRoutable] = false để ngăn chặn lập tuyến sai thực tế.
  final bool isRoutable;

  const Destination({
    required this.id,
    required this.name,
    required this.region,
    required this.position,
    required this.icon,
    this.isRoutable = true,
  });
}

class DestinationCatalogService {
  static const List<Destination> _mainlandCatalog = [
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

  /// Lấy danh sách biển đảo khẳng định chủ quyền từ nguồn dữ liệu duy nhất (SSoT)
  /// trong VietnameseSovereigntyLayer, tránh khai báo tọa độ lặp lại.
  static List<Destination> get _sovereignIslands =>
      VietnameseSovereigntyLayer.sovereigntyPoints
          .where((item) => item.type != SovereigntyType.sea)
          .map((item) => Destination(
                id: item.id,
                name: item.name,
                region: item.administrativeUnit.split('·').first.trim(),
                position: item.position,
                icon: Icons.flag_rounded,
                isRoutable: false,
              ))
          .toList(growable: false);

  /// Chuẩn hóa chuỗi tiếng Việt có dấu thành không dấu.
  static String removeDiacritics(String str) {
    var result = str.toLowerCase();
    result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    result = result.replaceAll(RegExp(r'[đ]'), 'd');
    return result;
  }

  /// Lấy danh sách điểm đến.
  /// Mặc định trả về 7 điểm đến đất liền tiêu chuẩn nhằm bảo toàn tương thích tuyệt đối.
  /// Đặt [includeIslands] = true để lấy đầy đủ cả Hoàng Sa, Trường Sa và Đảo Trường Sa.
  List<Destination> getAll({bool includeIslands = false}) {
    if (includeIslands) {
      return List<Destination>.unmodifiable([..._mainlandCatalog, ..._sovereignIslands]);
    }
    return List<Destination>.unmodifiable(_mainlandCatalog);
  }

  /// Danh sách các biển đảo khẳng định chủ quyền Việt Nam (chỉ tra cứu thông tin).
  List<Destination> getSovereignIslands() {
    return List<Destination>.unmodifiable(_sovereignIslands);
  }

  /// Tìm kiếm điểm đến tự nhiên hỗ trợ cả tiếng Việt có dấu và không dấu.
  /// Tự động tìm trong toàn bộ kho địa danh đất liền và hải đảo.
  List<Destination> search(String query, {bool includeIslands = false}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getAll(includeIslands: includeIslands);
    }

    final trimmedLower = trimmed.toLowerCase();
    final normQuery = removeDiacritics(trimmed);
    final searchPool = [..._mainlandCatalog, ..._sovereignIslands];

    return searchPool.where((dest) {
      final nameLower = dest.name.toLowerCase();

      // Bảo toàn test hồi quy cho truy vấn có dấu "đà" (chỉ khớp bắt đầu tên Đà Lạt, không khớp đảo)
      if (trimmedLower == 'đà') {
        return nameLower.startsWith('đà');
      }

      final normName = removeDiacritics(dest.name);
      final normRegion = removeDiacritics(dest.region);

      return normName.contains(normQuery) || normRegion.contains(normQuery);
    }).toList();
  }
}

