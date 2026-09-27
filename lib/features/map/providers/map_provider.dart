import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../services/map_api_service.dart';
import '../services/location_service.dart';

class MapProvider extends ChangeNotifier {
  final MapApiService _apiService;
  final LocationService _locationService;

  MapProvider({
    MapApiService? apiService,
    LocationService? locationService,
  })  : _apiService = apiService ?? MapApiService(),
        _locationService = locationService ?? LocationService();

  MapMode _currentMode = MapMode.routing;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMockGps = false;

  LatLng _origin = LocationService.defaultUniversityOrigin;
  String _originName = LocationService.defaultOriginName;

  // Default demo destination: Đà Lạt
  LatLng _destination = const LatLng(11.9404, 108.4583);
  String _destinationName = 'Đà Lạt (Lâm Đồng)';

  List<RouteWaypoint> _waypoints = [];
  RouteData? _currentRoute;

  List<GroupMember> _groupMembers = [];
  GroupMember? _selectedMember;
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
  List<GroupMember> get groupMembers => _groupMembers;
  GroupMember? get selectedMember => _selectedMember;
  RouteWaypoint? get selectedWaypoint => _selectedWaypoint;

  GroupMember? get leader => _groupMembers.cast<GroupMember?>().firstWhere(
        (m) => m?.isLeader == true,
        orElse: () => null,
      );

  void setMode(MapMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }

  void selectMember(GroupMember? member) {
    _selectedMember = member;
    notifyListeners();
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

      // 2. Set destination and waypoints if supplied
      if (targetDestination != null) {
        _destination = targetDestination;
      }
      if (targetName != null && targetName.isNotEmpty) {
        _destinationName = targetName;
      }
      if (waypoints != null) {
        _waypoints = waypoints;
      }

      // 3. Initialize group members around user/origin
      _groupMembers = _locationService.generateInitialGroupMembers(_origin);

      // 4. Fetch initial trip route
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
    _currentRoute = await _apiService.getRoute(
      origin: _origin,
      destination: _destination,
      waypoints: _waypoints,
    );
  }

  /// Triggered when tapping "Chỉ đường quay lại nhóm" for a lost/separated member
  Future<void> routeBackToLeader(GroupMember member) async {
    final leaderMember = leader;
    if (leaderMember == null) return;

    _currentMode = MapMode.routing;
    _origin = member.position;
    _originName = 'Vị trí của ${member.name}';
    _destination = leaderMember.position;
    _destinationName = 'Vị trí Trưởng nhóm (${leaderMember.name})';
    _waypoints = [];
    _selectedMember = member;

    await loadRoute();
  }

  void refreshRadarDistances() {
    final leaderMember = leader;
    if (leaderMember == null) return;

    final updated = _groupMembers.map((m) {
      if (m.isLeader) return m;
      final distance = _locationService.calculateDistanceMeters(
        m.position,
        leaderMember.position,
      );
      return m.copyWith(
        distanceToLeaderMeters: distance,
        lastUpdated: DateTime.now(),
      );
    }).toList();

    _groupMembers = updated;
    notifyListeners();
  }
}
