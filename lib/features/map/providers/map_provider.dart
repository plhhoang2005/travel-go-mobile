import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../services/map_api_service.dart';
import '../services/map_preset_service.dart';
import '../services/location_service.dart';

class MapProvider extends ChangeNotifier {
  final MapApiService _apiService;
  final MapPresetService _presetService;
  final LocationService _locationService;

  MapProvider({
    MapApiService? apiService,
    MapPresetService? presetService,
    LocationService? locationService,
  })  : _apiService = apiService ?? MapApiService(),
        _presetService = presetService ?? MapPresetService(),
        _locationService = locationService ?? LocationService();

  final MapMode _currentMode = MapMode.routing;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMockGps = false;

  LatLng _origin = LocationService.defaultUniversityOrigin;
  String _originName = LocationService.defaultOriginName;

  LatLng _destination = const LatLng(11.9363, 108.4452);
  String _destinationName = 'Quảng Trường Lâm Viên (Đà Lạt)';

  List<RouteWaypoint> _waypoints = [];
  RouteData? _currentRoute;
  RouteWaypoint? _selectedWaypoint;

  // Getters
  MapMode get currentMode => _currentMode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isMockGps => _isMockGps;
  LatLng get origin => _origin;
  String get originName => _originName;
  LatLng get destination => _destination;
  String get destinationName => _destinationName;
  List<RouteWaypoint> get waypoints => _waypoints;
  RouteData? get currentRoute => _currentRoute;
  RouteWaypoint? get selectedWaypoint => _selectedWaypoint;

  void selectWaypoint(RouteWaypoint? waypoint) {
    _selectedWaypoint = waypoint;
    notifyListeners();
  }

  Future<void> init({
    LatLng? targetDestination,
    String? targetName,
    List<RouteWaypoint>? waypoints,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Resolve current user/origin location
      final locationResult = await _locationService.getCurrentUserLocation();
      _origin = locationResult.position;
      _originName = locationResult.locationName;
      _isMockGps = locationResult.isMock;

      // 2. Set waypoints or load demo preset if none provided
      if (waypoints != null && waypoints.isNotEmpty) {
        _waypoints = waypoints;
      } else {
        final demoRoute = _presetService.getDefaultDemoRoute();
        if (demoRoute.isNotEmpty) {
          _origin = demoRoute.first.position;
          _originName = demoRoute.first.title;
          _destination = demoRoute.last.position;
          _destinationName = demoRoute.last.title;
          if (demoRoute.length > 2) {
            _waypoints = demoRoute.sublist(1, demoRoute.length - 1);
          } else {
            _waypoints = [];
          }
        }
      }

      // 3. Override destination if explicitly passed
      if (targetDestination != null) {
        _destination = targetDestination;
      }
      if (targetName != null && targetName.isNotEmpty) {
        _destinationName = targetName;
      }

      // 4. Fetch initial route
      await _fetchRoute();
    } catch (e) {
      _errorMessage = 'Không thể khởi tạo bản đồ: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoute({
    LatLng? customOrigin,
    LatLng? customDestination,
    String? customOriginName,
    String? customDestName,
    List<RouteWaypoint>? customWaypoints,
  }) async {
    if (customOrigin != null) _origin = customOrigin;
    if (customDestination != null) _destination = customDestination;
    if (customOriginName != null) _originName = customOriginName;
    if (customDestName != null) _destinationName = customDestName;
    if (customWaypoints != null) _waypoints = customWaypoints;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchRoute();
    } catch (e) {
      _errorMessage = 'Lỗi tải lộ trình: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchRoute() async {
    try {
      _currentRoute = await _apiService.getRoute(
        origin: _origin,
        destination: _destination,
        waypoints: _waypoints,
      );
      _errorMessage = null;
    } on RoutingException catch (e) {
      if (e.backendUnreachable) {
        _currentRoute = _generateLocalOfflineLine();
        _errorMessage = 'Backend không kết nối - đang hiển thị đường thẳng cục bộ';
      } else {
        _errorMessage = e.message;
        _currentRoute = null;
      }
    } catch (e) {
      _errorMessage = 'Lỗi không xác định: $e';
      _currentRoute = _generateLocalOfflineLine();
    }
  }

  RouteData _generateLocalOfflineLine() {
    final points = <LatLng>[
      _origin,
      ..._waypoints.map((w) => w.position),
      _destination,
    ];

    double totalDistKm = 0.0;
    const distanceCalc = Distance();
    for (int i = 0; i < points.length - 1; i++) {
      totalDistKm += distanceCalc.as(LengthUnit.Kilometer, points[i], points[i + 1]);
    }

    final durationMins = (totalDistKm / 40.0 * 60).round().clamp(15, 1440);

    return RouteData(
      points: points,
      distanceKm: totalDistKm,
      durationMinutes: durationMins,
      isFallback: true,
      summary: 'Đường thẳng cục bộ [BE Down]',
      waypoints: _waypoints,
    );
  }
}
