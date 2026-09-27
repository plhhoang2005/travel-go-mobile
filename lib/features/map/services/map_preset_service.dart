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
        dayNumber: 1,
        time: '07:30',
        category: 'Khởi hành',
        openingHours: '24/7',
        isCompleted: true,
      ),
      RouteWaypoint(
        id: 'wp-stop1',
        title: 'Trạm Dừng Chân Đồng Nai',
        position: LatLng(10.9574, 106.8427),
        type: 'stop',
        dayNumber: 1,
        time: '09:00',
        category: 'Nghỉ ngơi',
        openingHours: '06:00–22:00',
        rating: 4.5,
        isCompleted: true,
      ),
      RouteWaypoint(
        id: 'wp-stop2',
        title: 'Thác Dambri (Bảo Lộc)',
        position: LatLng(11.6441, 107.7423),
        type: 'stop',
        dayNumber: 1,
        time: '12:30',
        category: 'Điểm tham quan',
        openingHours: '07:00–17:00',
        rating: 4.8,
        imageUrl: 'https://images.unsplash.com/photo-1546484475-7f7bd55792da?w=600',
        isCompleted: false,
      ),
      RouteWaypoint(
        id: 'wp-dest',
        title: 'Quảng Trường Lâm Viên (Đà Lạt)',
        position: LatLng(11.9363, 108.4452),
        type: 'destination',
        dayNumber: 1,
        time: '16:00',
        category: 'Check-in',
        openingHours: 'Mở cả ngày',
        rating: 4.9,
        imageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600',
        isCompleted: false,
      ),
    ];
  }
}
