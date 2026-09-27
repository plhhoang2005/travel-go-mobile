import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../services/destination_catalog_service.dart';
import '../services/location_service.dart';
import '../services/map_api_service.dart';
import '../services/map_preset_service.dart';

class MapProvider extends ChangeNotifier {
  final MapApiService _apiService;
  final MapPresetService _presetService;
  final LocationService _locationService;
  final DestinationCatalogService _catalogService;

  MapProvider({
    MapApiService? apiService,
    MapPresetService? presetService,
    LocationService? locationService,
    DestinationCatalogService? catalogService,
  })  : _apiService = apiService ?? MapApiService(),
        _presetService = presetService ?? MapPresetService(),
        _locationService = locationService ?? LocationService(),
        _catalogService = catalogService ?? DestinationCatalogService();

  final MapMode _currentMode = MapMode.routing;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMockGps = false;
  bool _isDemoMode = false;

  LatLng _origin = LocationService.defaultUniversityOrigin;
  String _originName = LocationService.defaultOriginName;

  LatLng? _destination;
  String? _destinationName;

  List<RouteWaypoint> _waypoints = [];
  RouteData? _currentRoute;
  RouteWaypoint? _selectedWaypoint;

  // Getters
  MapMode get currentMode => _currentMode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isMockGps => _isMockGps;
  bool get isDemoMode => _isDemoMode;
  LatLng get origin => _origin;
  String get originName => _originName;
  LatLng? get destination => _destination;
  String? get destinationName => _destinationName;
  List<RouteWaypoint> get waypoints => _waypoints;
  RouteData? get currentRoute => _currentRoute;
  RouteWaypoint? get selectedWaypoint => _selectedWaypoint;

  bool get hasRoute => _currentRoute != null || _waypoints.isNotEmpty;
  List<Destination> get availableDestinations => _catalogService.getAll();

  List<RouteWaypoint> get allStops {
    final stops = <RouteWaypoint>[
      RouteWaypoint(
        id: 'origin',
        title: _originName,
        position: _origin,
        type: 'origin',
      ),
      ..._waypoints,
    ];
    if (_destination != null) {
      stops.add(
        RouteWaypoint(
          id: 'destination',
          title: _destinationName ?? 'Điểm đến',
          position: _destination!,
          type: 'destination',
        ),
      );
    }
    return stops;
  }

  int get selectedWaypointIndex {
    if (_selectedWaypoint == null) return 0;
    final stops = allStops;
    final index = stops.indexWhere(
      (w) => w.id == _selectedWaypoint!.id || w.position == _selectedWaypoint!.position,
    );
    return index >= 0 ? index : 0;
  }

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

      // 2. Set waypoints if passed explicitly
      if (waypoints != null && waypoints.isNotEmpty) {
        _waypoints = List<RouteWaypoint>.from(waypoints);
      } else {
        _waypoints = [];
      }

      // 3. Override destination if explicitly passed
      if (targetDestination != null) {
        _destination = targetDestination;
        _destinationName = targetName ?? 'Điểm đến';
      }

      // 4. Lazy evaluation: Only fetch route if destination is provided!
      if (_destination != null) {
        await _fetchRoute();
      }
    } catch (e) {
      _errorMessage = 'Không thể khởi tạo bản đồ: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void enterLocateOnlyMode() {
    _destination = null;
    _destinationName = null;
    _waypoints = [];
    _currentRoute = null;
    _selectedWaypoint = null;
    _isDemoMode = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearRoute() => enterLocateOnlyMode();

  void setDestination(LatLng position, String name) {
    _destination = position;
    _destinationName = name;
    notifyListeners();
  }

  void addWaypoint(RouteWaypoint wp) {
    _waypoints = [..._waypoints, wp];
    notifyListeners();
  }

  void removeWaypoint(int index) {
    if (index >= 0 && index < _waypoints.length) {
      _waypoints = List<RouteWaypoint>.from(_waypoints)..removeAt(index);
      notifyListeners();
    }
  }

  Future<void> loadDemoRoute() async {
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
      _isDemoMode = true;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      try {
        await _fetchRoute();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> buildRoute() async {
    if (_destination == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _fetchRoute();
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
    if (_destination == null) return;
    try {
      _currentRoute = await _apiService.getRoute(
        origin: _origin,
        destination: _destination!,
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

  RouteData? _generateLocalOfflineLine() {
    if (_destination == null) return null;
    final points = <LatLng>[
      _origin,
      ..._waypoints.map((w) => w.position),
      _destination!,
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
