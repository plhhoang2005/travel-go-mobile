import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_models.dart';
import '../services/destination_catalog_service.dart';
import '../services/group_location_service.dart';
import '../services/location_service.dart';
import '../services/map_api_service.dart';
import '../services/map_preset_service.dart';
import '../services/route_optimizer_service.dart';

enum GroupRadarConnectionState { idle, connecting, realtime, demoFallback }

class MapProvider extends ChangeNotifier {
  final MapApiService _apiService;
  final MapPresetService _presetService;
  final LocationService _locationService;
  final DestinationCatalogService _catalogService;
  final GroupLocationGateway _groupLocationService;
  final RouteOptimizerService _routeOptimizerService;

  MapProvider({
    MapApiService? apiService,
    MapPresetService? presetService,
    LocationService? locationService,
    DestinationCatalogService? catalogService,
    GroupLocationGateway? groupLocationService,
    RouteOptimizerService? routeOptimizerService,
  }) : _apiService = apiService ?? MapApiService(),
       _presetService = presetService ?? MapPresetService(),
       _locationService = locationService ?? LocationService(),
       _catalogService = catalogService ?? DestinationCatalogService(),
       _groupLocationService = groupLocationService ?? GroupLocationService(),
       _routeOptimizerService =
           routeOptimizerService ?? const RouteOptimizerService();

  final MapMode _currentMode = MapMode.routing;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMockGps = false;
  bool _isDemoMode = false;

  LatLng _origin = LocationService.defaultUniversityOrigin;
  String _originName = LocationService.defaultOriginName;
  LatLng _currentLocationOrigin = LocationService.defaultUniversityOrigin;
  String _currentLocationName = LocationService.defaultOriginName;
  bool _currentLocationIsMock = true;
  bool _isUsingCurrentLocation = true;

  LatLng? _destination;
  String? _destinationName;

  List<RouteWaypoint> _waypoints = [];
  RouteData? _currentRoute;
  RouteWaypoint? _selectedWaypoint;
  bool _isGroupRadarEnabled = false;
  List<GroupMemberLocation> _groupMembers = [];
  GroupMemberLocation? _selectedGroupMember;
  GroupRadarConnectionState _groupRadarConnectionState =
      GroupRadarConnectionState.idle;
  String? _groupRadarMessage;
  String? _activeGroupId;
  StreamSubscription<List<GroupMemberLocation>>? _groupMembersSubscription;
  StreamSubscription<LocationResult>? _locationSubscription;

  int _radarGeneration = 0;
  bool _appPaused = false;
  bool _disposed = false;

  // Getters
  MapMode get currentMode => _currentMode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isMockGps => _isMockGps;
  bool get isDemoMode => _isDemoMode;
  LatLng get origin => _origin;
  String get originName => _originName;
  bool get isUsingCurrentLocation => _isUsingCurrentLocation;
  LatLng? get destination => _destination;
  String? get destinationName => _destinationName;
  List<RouteWaypoint> get waypoints => _waypoints;
  RouteData? get currentRoute => _currentRoute;
  RouteWaypoint? get selectedWaypoint => _selectedWaypoint;
  bool get isGroupRadarEnabled => _isGroupRadarEnabled;
  List<GroupMemberLocation> get groupMembers =>
      List<GroupMemberLocation>.unmodifiable(_groupMembers);
  GroupMemberLocation? get selectedGroupMember => _selectedGroupMember;
  GroupRadarConnectionState get groupRadarConnectionState =>
      _groupRadarConnectionState;
  String? get groupRadarMessage => _groupRadarMessage;
  String? get activeGroupId => _activeGroupId;
  bool get isDemoGroupRadar =>
      _groupMembers.isNotEmpty &&
      _groupMembers.every((member) => member.isDemo);

  bool get hasRoute => _currentRoute != null || _waypoints.isNotEmpty;
  bool get canBuildRoute => _destination != null && _destination != _origin;
  List<Destination> get availableDestinations => _catalogService.getAll();

  int _selectedDay = 1;
  int get selectedDay => _selectedDay;

  int get totalDays {
    if (_isDemoMode) return 3;
    if (allStops.isEmpty) return 1;
    final maxDay = allStops
        .map((w) => w.dayNumber)
        .fold<int>(1, (prev, elem) => elem > prev ? elem : prev);
    return maxDay.clamp(1, 7);
  }

  List<RouteWaypoint> get currentDayStops {
    final stops = allStops;
    final dayFiltered = stops
        .where((w) => w.dayNumber == _selectedDay)
        .toList();
    return dayFiltered.isNotEmpty ? dayFiltered : stops;
  }

  void selectDay(int day) {
    if (_selectedDay != day) {
      _selectedDay = day;
      _selectedWaypoint = null;
      notifyListeners();
    }
  }

  void toggleStopCompleted(String id) {
    _waypoints = _waypoints.map((wp) {
      if (wp.id == id) {
        return wp.copyWith(isCompleted: !wp.isCompleted);
      }
      return wp;
    }).toList();
    notifyListeners();
  }

  Future<void> applyAiReorder(List<RouteWaypoint> reorderedStops) async {
    _waypoints = reorderedStops.where((w) => w.type == 'stop').toList();
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

  OptimizationResult getOptimizationPreview() {
    return _routeOptimizerService.optimize(
      origin: _origin,
      destination: _destination,
      waypoints: _waypoints,
    );
  }

  Future<void> reorderWaypoints(
    int oldIndex,
    int newIndex, {
    bool autoFetch = false,
  }) async {
    if (oldIndex < 0 || oldIndex >= _waypoints.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= _waypoints.length) newIndex = _waypoints.length - 1;
    if (oldIndex == newIndex) return;

    final items = List<RouteWaypoint>.from(_waypoints);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    _waypoints = items;

    if (autoFetch && canBuildRoute) {
      _isLoading = true;
      notifyListeners();
      try {
        await _fetchRoute();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _invalidateCurrentRoute();
      notifyListeners();
    }
  }

  void updateWaypointDay(int index, int dayNumber) {
    if (index >= 0 && index < _waypoints.length) {
      final items = List<RouteWaypoint>.from(_waypoints);
      items[index] = items[index].copyWith(dayNumber: dayNumber);
      _waypoints = items;
      notifyListeners();
    }
  }

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
      (w) =>
          w.id == _selectedWaypoint!.id ||
          w.position == _selectedWaypoint!.position,
    );
    return index >= 0 ? index : 0;
  }

  void selectWaypoint(RouteWaypoint? waypoint) {
    _selectedWaypoint = waypoint;
    notifyListeners();
  }

  void setGroupRadarEnabled(bool enabled) {
    if (_isGroupRadarEnabled == enabled) return;
    _isGroupRadarEnabled = enabled;
    if (enabled && _groupMembers.isEmpty) {
      _groupMembers = _presetService.getDemoGroupMembers();
      _groupRadarConnectionState = GroupRadarConnectionState.demoFallback;
      _groupRadarMessage = 'Đang hiển thị dữ liệu thành viên demo.';
    }
    if (!enabled) {
      _selectedGroupMember = null;
      unawaited(disconnectGroupRadar());
    }
    notifyListeners();
  }

  void toggleGroupRadar() => setGroupRadarEnabled(!_isGroupRadarEnabled);

  void selectGroupMember(String? memberId) {
    GroupMemberLocation? selected;
    if (_isGroupRadarEnabled && memberId != null) {
      for (final member in _groupMembers) {
        if (member.memberId == memberId) {
          selected = member;
          break;
        }
      }
    }
    if (_selectedGroupMember?.memberId == selected?.memberId) return;
    _selectedGroupMember = selected;
    notifyListeners();
  }

  double distanceToGroupMemberMeters(GroupMemberLocation member) {
    return _locationService.calculateDistanceMeters(_origin, member.position);
  }

  Future<void> connectGroupRadar({
    required String userId,
    required String displayName,
    required String avatarInitials,
    String roomCode = 'TRAVELGO-DEMO',
  }) async {
    if (_groupRadarConnectionState == GroupRadarConnectionState.connecting ||
        _groupRadarConnectionState == GroupRadarConnectionState.realtime) {
      return;
    }
    final generation = ++_radarGeneration;
    unawaited(_cancelRadarSubscriptions());
    _isGroupRadarEnabled = false;
    _groupMembers = [];
    _selectedGroupMember = null;
    _groupRadarConnectionState = GroupRadarConnectionState.connecting;
    _groupRadarMessage = null;
    notifyListeners();

    try {
      if (userId.trim().isEmpty) {
        throw StateError('Thiếu định danh phiên Radar.');
      }
      final groupId = await _groupLocationService
          .joinGroup(
            roomCode: roomCode,
            displayName: displayName,
            avatarInitials: avatarInitials,
          )
          .timeout(const Duration(seconds: 6));
      if (_disposed || generation != _radarGeneration) return;
      _activeGroupId = groupId;
      _isGroupRadarEnabled = true;
      _groupMembersSubscription = _groupLocationService
          .watchMembers(groupId)
          .listen(
            (members) {
              if (!_disposed && generation == _radarGeneration) {
                _replaceRealtimeMembers(members);
              }
            },
            onError: (Object error) {
              if (!_disposed && generation == _radarGeneration) {
                _failRadar(error);
              }
            },
          );
      _groupRadarConnectionState = GroupRadarConnectionState.realtime;
      if (!_appPaused) _startRadarLocation();
      notifyListeners();
    } catch (error) {
      if (!_disposed && generation == _radarGeneration) {
        _failRadar(error, roomCode);
      }
      rethrow;
    }
  }

  void _failRadar(Object error, [String? pendingRoom]) {
    unawaited(disconnectGroupRadar());
    _groupRadarMessage = 'Không thể kết nối Radar: $error';
    notifyListeners();
  }

  void _markOfflineInBackground(String groupId) {
    unawaited(
      Future<void>.sync(() => _groupLocationService.markOffline(groupId))
          .timeout(const Duration(seconds: 2))
          .catchError((Object error) {
            debugPrint('Radar teardown: $error');
          }),
    );
  }

  Future<void> disconnectGroupRadar() async {
    ++_radarGeneration;
    final groupId = _activeGroupId;
    final wasConnecting =
        _groupRadarConnectionState == GroupRadarConnectionState.connecting;
    _isGroupRadarEnabled = false;
    _groupMembers = [];
    _selectedGroupMember = null;
    _groupRadarConnectionState = GroupRadarConnectionState.idle;
    _groupRadarMessage = null;
    _activeGroupId = null;
    unawaited(_cancelRadarSubscriptions());
    if (groupId != null || wasConnecting) {
      _markOfflineInBackground(groupId ?? '');
    }
    notifyListeners();
  }

  void onAppPaused() {
    _appPaused = true;
    _radarPingTimer?.cancel();
    _radarPingTimer = null;
    final subscription = _locationSubscription;
    _locationSubscription = null;
    unawaited(subscription?.cancel());
  }

  void onAppResumed() {
    if (!_appPaused || _disposed) return;
    _appPaused = false;
    if (_activeGroupId != null) _startRadarLocation();
  }

  void _startRadarLocation() {
    final generation = _radarGeneration;
    _locationSubscription = _locationService.watchUserLocation().listen(
      (result) {
        if (!_disposed && !_appPaused && generation == _radarGeneration) {
          _publishRealtimeLocation(result);
        }
      },
      onError: (Object error) {
        if (_disposed || generation != _radarGeneration) return;
        _groupRadarMessage = 'Không thể đọc GPS realtime: $error';
        notifyListeners();
      },
    );
  }

  void _replaceRealtimeMembers(List<GroupMemberLocation> members) {
    final uniqueMembers = <String, GroupMemberLocation>{};
    for (final member in members) {
      if (member.memberId.isNotEmpty) {
        uniqueMembers[member.memberId] = member;
      }
    }
    _groupMembers = uniqueMembers.values.toList(growable: false);
    final selectedId = _selectedGroupMember?.memberId;
    _selectedGroupMember = selectedId == null
        ? null
        : uniqueMembers[selectedId];
    notifyListeners();
  }

  Timer? _radarPingTimer;

  void _publishRealtimeLocation(LocationResult result) {
    final groupId = _activeGroupId;
    if (groupId == null || _appPaused || _disposed) return;

    _radarPingTimer?.cancel();

    final generation = _radarGeneration;
    void sendPing() {
      if (_disposed || _appPaused || generation != _radarGeneration) return;
      unawaited(
        _groupLocationService
            .publishLocation(groupId: groupId, position: result.position)
            .catchError((Object error) {
              if (!_disposed && generation == _radarGeneration) {
                _failRadar(error);
              }
            }),
      );
    }

    sendPing();
    _radarPingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => sendPing(),
    );
  }

  Future<void> _cancelRadarSubscriptions() async {
    _radarPingTimer?.cancel();
    _radarPingTimer = null;
    final members = _groupMembersSubscription;
    final location = _locationSubscription;
    _groupMembersSubscription = null;
    _locationSubscription = null;
    await Future.wait([
      if (members != null) members.cancel(),
      if (location != null) location.cancel(),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_radarGeneration;
    final groupId = _activeGroupId;
    _radarPingTimer?.cancel();
    unawaited(_groupMembersSubscription?.cancel());
    unawaited(_locationSubscription?.cancel());
    if (groupId != null ||
        _groupRadarConnectionState == GroupRadarConnectionState.connecting) {
      _markOfflineInBackground(groupId ?? '');
    }
    super.dispose();
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
      _currentLocationOrigin = locationResult.position;
      _currentLocationName = locationResult.locationName;
      _currentLocationIsMock = locationResult.isMock;
      _isUsingCurrentLocation = true;

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
    _selectedDay = 1;
    _errorMessage = null;
    notifyListeners();
  }

  void clearRoute() => enterLocateOnlyMode();

  void setOrigin(LatLng position, String name) {
    _origin = position;
    _originName = name;
    _isUsingCurrentLocation = false;
    _isMockGps = false;
    _invalidateCurrentRoute();
    notifyListeners();
  }

  void useCurrentLocationAsOrigin() {
    _origin = _currentLocationOrigin;
    _originName = _currentLocationName;
    _isUsingCurrentLocation = true;
    _isMockGps = _currentLocationIsMock;
    _invalidateCurrentRoute();
    notifyListeners();
  }

  void setDestination(LatLng position, String name) {
    _destination = position;
    _destinationName = name;
    _invalidateCurrentRoute();
    notifyListeners();
  }

  void _invalidateCurrentRoute() {
    _currentRoute = null;
    _selectedWaypoint = null;
    _isDemoMode = false;
    _errorMessage = null;
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
      _isUsingCurrentLocation = false;
      _isMockGps = false;
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
    if (!canBuildRoute) return;
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

  Future<void> refreshCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final locationResult = await _locationService.getCurrentUserLocation();
      _origin = locationResult.position;
      _originName = locationResult.locationName;
      _isMockGps = locationResult.isMock;

      if (_destination != null) {
        await _fetchRoute();
      }
    } catch (e) {
      _errorMessage = 'Không thể cập nhật vị trí: $e';
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
        _errorMessage =
            'Backend và OSRM không kết nối - đang hiển thị đường thẳng cục bộ';
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
      totalDistKm += distanceCalc.as(
        LengthUnit.Kilometer,
        points[i],
        points[i + 1],
      );
    }

    final durationMins = (totalDistKm / 40.0 * 60).round().clamp(15, 1440);

    return RouteData(
      points: points,
      distanceKm: totalDistKm,
      durationMinutes: durationMins,
      isFallback: true,
      summary: 'Đường thẳng cục bộ [OSRM Offline]',
      waypoints: _waypoints,
    );
  }
}
