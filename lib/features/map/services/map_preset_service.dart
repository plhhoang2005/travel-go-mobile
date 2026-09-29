import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';

class MapPresetService {
  List<GroupMemberLocation> getDemoGroupMembers({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    return [
      GroupMemberLocation(
        memberId: 'demo-an',
        displayName: 'An Nguyễn',
        avatarInitials: 'AN',
        position: const LatLng(10.7740, 106.6591),
        updatedAt: now.subtract(const Duration(minutes: 1)),
        status: GroupMemberStatus.online,
        isDemo: true,
      ),
      GroupMemberLocation(
        memberId: 'demo-lan',
        displayName: 'Lan Trần',
        avatarInitials: 'LT',
        position: const LatLng(10.7709, 106.6557),
        updatedAt: now.subtract(const Duration(minutes: 3)),
        status: GroupMemberStatus.online,
        isDemo: true,
      ),
      GroupMemberLocation(
        memberId: 'demo-khoa',
        displayName: 'Khoa Lê',
        avatarInitials: 'KL',
        position: const LatLng(10.7762, 106.6620),
        updatedAt: now.subtract(const Duration(minutes: 8)),
        status: GroupMemberStatus.idle,
        isDemo: true,
      ),
      GroupMemberLocation(
        memberId: 'demo-mai',
        displayName: 'Mai Phạm',
        avatarInitials: 'MP',
        position: const LatLng(10.7688, 106.6608),
        updatedAt: now.subtract(const Duration(minutes: 18)),
        status: GroupMemberStatus.offline,
        isDemo: true,
      ),
    ];
  }

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
