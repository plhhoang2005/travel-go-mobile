import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';

class MapPresetService {
  List<RouteWaypoint> getDefaultDemoRoute() {
    return const [
      RouteWaypoint(
        id: 'wp-origin',
        title: 'Cổng ĐH Bách Khoa TP.HCM',
        position: LatLng(10.7725, 106.6578),
        type: 'origin',
      ),
      RouteWaypoint(
        id: 'wp-stop1',
        title: 'Trạm Dừng Chân Đồng Nai',
        position: LatLng(10.9574, 106.8427),
        type: 'stop',
      ),
      RouteWaypoint(
        id: 'wp-stop2',
        title: 'Thác Dambri (Bảo Lộc)',
        position: LatLng(11.6441, 107.7423),
        type: 'stop',
      ),
      RouteWaypoint(
        id: 'wp-dest',
        title: 'Quảng Trường Lâm Viên (Đà Lạt)',
        position: LatLng(11.9363, 108.4452),
        type: 'destination',
      ),
    ];
  }
}
