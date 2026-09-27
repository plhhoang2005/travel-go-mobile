import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final LatLng position;
  final bool isMock;
  final String locationName;

  const LocationResult({
    required this.position,
    required this.isMock,
    required this.locationName,
  });
}

class LocationService {
  // Default University Origin (Cổng ĐH Bách Khoa TP.HCM - Cơ sở Lý Thường Kiệt)
  static const LatLng defaultUniversityOrigin = LatLng(10.7725, 106.6578);
  static const String defaultOriginName = 'Cổng ĐH Bách Khoa TP.HCM (268 Lý Thường Kiệt)';

  // Khu Đô thị ĐHQG TP.HCM (Dĩ An, Bình Dương)
  static const LatLng vnuUniversityOrigin = LatLng(10.8805, 106.8054);
  static const String vnuOriginName = 'Khu Đô thị ĐHQG TP.HCM (Dĩ An)';

  Future<LocationResult> getCurrentUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        return const LocationResult(
          position: defaultUniversityOrigin,
          isMock: true,
          locationName: defaultOriginName,
        );
      }

      var permission = await Geolocator.checkPermission().timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => LocationPermission.denied,
      );

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 2),
          onTimeout: () => LocationPermission.denied,
        );
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            position: defaultUniversityOrigin,
            isMock: true,
            locationName: defaultOriginName,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          position: defaultUniversityOrigin,
          isMock: true,
          locationName: defaultOriginName,
        );
      }

      // 1. Try to get last known position first (instant, 0ms, non-blocking)
      final lastKnown = await Geolocator.getLastKnownPosition().timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => null,
      );
      if (lastKnown != null) {
        return LocationResult(
          position: LatLng(lastKnown.latitude, lastKnown.longitude),
          isMock: false,
          locationName: 'Vị trí GPS của bạn',
        );
      }

      // 2. Fetch current position with 2s strict timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 2),
        ),
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw Exception('Location timeout'),
      );

      return LocationResult(
        position: LatLng(position.latitude, position.longitude),
        isMock: false,
        locationName: 'Vị trí GPS thực tế của bạn',
      );
    } catch (_) {
      return const LocationResult(
        position: defaultUniversityOrigin,
        isMock: true,
        locationName: defaultOriginName,
      );
    }
  }

  double calculateDistanceMeters(LatLng p1, LatLng p2) {
    return Geolocator.distanceBetween(
      p1.latitude,
      p1.longitude,
      p2.latitude,
      p2.longitude,
    );
  }
}
