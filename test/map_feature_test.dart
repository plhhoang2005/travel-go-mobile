import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/map/models/map_models.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/trip_map_screen.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/ai_optimization_sheet.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/diamond_milestone_marker.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/floating_view_switch.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/journey_carousel_widget.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/journey_story_timeline.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/journey_trip_card.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/location_detail_sheet.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/group_radar_sheet.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/milestone_marker_widget.dart';
import 'package:travelgo_mobile/features/map/presentation/widgets/route_builder_sheet.dart';
import 'package:travelgo_mobile/features/map/providers/map_provider.dart';
import 'package:travelgo_mobile/features/map/services/destination_catalog_service.dart';
import 'package:travelgo_mobile/features/map/services/group_location_service.dart';
import 'package:travelgo_mobile/features/map/services/location_service.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/map/services/map_preset_service.dart';

class FakeMapApiService extends MapApiService {
  bool shouldThrowBackendUnreachable = false;
  int callCount = 0;
  LatLng? lastOrigin;
  LatLng? lastDestination;

  @override
  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    callCount++;
    lastOrigin = origin;
    lastDestination = destination;
    if (shouldThrowBackendUnreachable) {
      throw RoutingException('Connection refused', backendUnreachable: true);
    }

    final allPoints = [
      origin,
      ...waypoints.map((w) => w.position),
      destination,
    ];
    return RouteData(
      points: allPoints,
      distanceKm: 310.0,
      durationMinutes: 370,
      isFallback: false,
      summary: 'Tuyến đường thử nghiệm OSRM',
      waypoints: waypoints,
    );
  }
}

class FakeLocationService extends LocationService {
  final StreamController<LocationResult> locationController =
      StreamController<LocationResult>.broadcast();
  LocationResult result;
  int callCount = 0;

  FakeLocationService({
    this.result = const LocationResult(
      position: LocationService.defaultUniversityOrigin,
      isMock: true,
      locationName: LocationService.defaultOriginName,
    ),
  });

  @override
  Future<LocationResult> getCurrentUserLocation() async {
    callCount++;
    return result;
  }

  @override
  Stream<LocationResult> watchUserLocation() => locationController.stream;

  Future<void> close() => locationController.close();
}

class FakeGroupLocationService implements GroupLocationGateway {
  final StreamController<List<GroupMemberLocation>> membersController =
      StreamController<List<GroupMemberLocation>>.broadcast();
  bool shouldFailJoin = false;
  Completer<String>? pendingJoin;
  Completer<void>? pendingOffline;
  int joinCalls = 0;
  int markOfflineCalls = 0;
  final List<LatLng> publishedPositions = [];

  @override
  Future<String> joinGroup({
    required String roomCode,
    required String displayName,
    required String avatarInitials,
  }) async {
    joinCalls++;
    if (shouldFailJoin) throw StateError('network unavailable');
    return pendingJoin == null ? 'group-01' : await pendingJoin!.future;
  }

  @override
  Stream<List<GroupMemberLocation>> watchMembers(String groupId) {
    return membersController.stream;
  }

  @override
  Future<void> publishLocation({
    required String groupId,
    required LatLng position,
  }) async {
    publishedPositions.add(position);
  }

  @override
  Future<void> markOffline(String groupId) async {
    markOfflineCalls++;
    await pendingOffline?.future;
  }

  Future<void> close() => membersController.close();
}

class RadarTestChannel extends RealtimeChannel {
  final callbacks = <String, void Function(Map<String, dynamic>)>{};
  final sent = <Map<String, dynamic>>[];
  RadarTestChannel(super.name, super.socket);
  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic>) callback,
  }) {
    callbacks[event] = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) {
    callback?.call(RealtimeSubscribeStatus.subscribed, null);
    return this;
  }

  @override
  Future<ChannelResponse> sendBroadcastMessage({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    sent.add(payload);
    return ChannelResponse.ok;
  }
}

class RadarTestClient extends SupabaseClient {
  final created = <RadarTestChannel>[];
  Completer<String>? removal;
  RadarTestClient()
    : super(
        'https://radar.test',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final result = RadarTestChannel(name, realtime);
    created.add(result);
    return result;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async =>
      removal == null ? 'ok' : await removal!.future;
}

void main() {
  group('Multi-tier OSRM routing', () {
    const origin = LatLng(10.8, 106.7);
    const destination = LatLng(10.75, 106.65);
    const stop = RouteWaypoint(
      id: 'stop',
      title: 'Stop',
      position: LatLng(10.78, 106.68),
      type: 'stop',
    );
    Map<String, dynamic> osrmResponse({List<List<double>>? coordinates}) => {
      'code': 'Ok',
      'routes': [
        {
          'distance': 12500,
          'duration': 930,
          'geometry': {
            'type': 'LineString',
            'coordinates':
                coordinates ??
                [
                  [106.7, 10.8],
                  [106.69, 10.79],
                  [106.65, 10.75],
                ],
          },
        },
      ],
    };
    Dio fakeDio({
      DioExceptionType? failure = DioExceptionType.connectionError,
      int? backendStatus,
      Object? publicResponse,
      bool publicOffline = false,
      List<RequestOptions>? requests,
    }) {
      final dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests?.add(options);
            if (options.method == 'POST') {
              if (backendStatus != null) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: options,
                      statusCode: backendStatus,
                    ),
                  ),
                );
              } else if (failure != null) {
                handler.reject(
                  DioException(requestOptions: options, type: failure),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'success': true,
                      'metadata': {'provider': 'osrm', 'isFallback': false},
                      'data': {
                        'points': [
                          {'lat': 10.8, 'lng': 106.7},
                          {'lat': 10.75, 'lng': 106.65},
                        ],
                        'distanceKm': 9.0,
                        'durationMinutes': 12,
                      },
                    },
                  ),
                );
              }
            } else if (publicOffline) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: publicResponse ?? osrmResponse(),
                ),
              );
            }
          },
        ),
      );
      addTearDown(() => dio.close(force: true));
      return dio;
    }

    for (final failure in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test(
        '$failure uses public OSRM with ordered longitude-first stops',
        () async {
          final requests = <RequestOptions>[];
          final service = MapApiService(
            dio: fakeDio(failure: failure, requests: requests),
          );
          final route = await service.getRoute(
            origin: origin,
            destination: destination,
            waypoints: [stop],
          );
          expect(requests.map((r) => r.method), ['POST', 'GET']);
          final publicRequest = requests.last;
          expect(publicRequest.uri.host, 'router.project-osrm.org');
          expect(publicRequest.uri.scheme, 'https');
          expect(
            publicRequest.uri.path,
            '/route/v1/driving/106.7,10.8;106.68,10.78;106.65,10.75',
          );
          expect(publicRequest.uri.queryParameters, {
            'overview': 'full',
            'geometries': 'geojson',
          });
          expect(route.points, [
            origin,
            const LatLng(10.79, 106.69),
            destination,
          ]);
          expect(route.distanceKm, 12.5);
          expect(route.durationMinutes, 16);
          expect(route.isFallback, isFalse);
          expect(route.summary, 'Tuyến đường OSRM');
          expect(route.waypoints, [stop]);
        },
      );
    }
    test(
      'public OSRM timeout cancels the request after five seconds',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'http://backend.test/api/v1'));
        RequestOptions? publicRequest;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'POST') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
              } else {
                publicRequest =
                    options; // Simulate a server that never responds.
              }
            },
          ),
        );
        final route = MapApiService(dio: dio)
            .getRoute(origin: origin, destination: destination);
        final assertion = expectLater(
          route,
          throwsA(
            isA<RoutingException>().having(
              (e) => e.backendUnreachable,
              'unreachable',
              true,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(publicRequest, isNotNull);
        await assertion;
        expect(publicRequest!.cancelToken!.isCancelled, isTrue);
        dio.close(force: true);
      },
    );
    test('malformed OSRM geometry remains a data error', () async {
      await expectLater(
        MapApiService(
          dio: fakeDio(
            publicResponse: {
              'code': 'Ok',
              'routes': [
                {
                  'distance': 100,
                  'duration': 60,
                  'geometry': {'coordinates': []},
                },
              ],
            },
          ),
        ).getRoute(origin: origin, destination: destination),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.backendUnreachable,
            'unreachable',
            false,
          ),
        ),
      );
    });
    test('successful backend never requests public OSRM', () async {
      final requests = <RequestOptions>[];
      final route = await MapApiService(
        dio: fakeDio(failure: null, requests: requests),
      ).getRoute(origin: origin, destination: destination);
      expect(requests, hasLength(1));
      expect(route.distanceKm, 9);
    });
    test('backend 503 tries public OSRM', () async {
      final route = await MapApiService(dio: fakeDio(backendStatus: 503))
          .getRoute(origin: origin, destination: destination);
      expect(route.isFallback, isFalse);
    });
    test('backend 400 remains an error without public retry', () async {
      final requests = <RequestOptions>[];
      await expectLater(
        MapApiService(dio: fakeDio(backendStatus: 400, requests: requests))
            .getRoute(origin: origin, destination: destination),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.backendUnreachable,
            'unreachable',
            false,
          ),
        ),
      );
      expect(requests, hasLength(1));
    });
    test(
      'both gateways offline enable provider beeline, recovery clears error',
      () async {
        final dio = fakeDio(publicOffline: true);
        final provider = MapProvider(
          apiService: MapApiService(dio: dio),
          locationService: FakeLocationService(),
        );
        addTearDown(provider.dispose);
        provider.setOrigin(origin, 'Origin');
        provider.setDestination(destination, 'Destination');
        await provider.buildRoute();
        expect(provider.currentRoute!.isFallback, isTrue);
        expect(provider.errorMessage, isNotNull);
        dio.interceptors.clear();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'POST') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: osrmResponse(),
                  ),
                );
              }
            },
          ),
        );
        await provider.buildRoute();
        expect(provider.currentRoute!.isFallback, isFalse);
        expect(provider.currentRoute!.points, hasLength(3));
        expect(provider.errorMessage, isNull);
      },
    );
    test('NoRoute is reported without claiming offline', () async {
      await expectLater(
        MapApiService(dio: fakeDio(publicResponse: {'code': 'NoRoute'}))
            .getRoute(origin: origin, destination: destination),
        throwsA(
          isA<RoutingException>().having(
            (e) => e.backendUnreachable,
            'unreachable',
            false,
          ),
        ),
      );
    });
    test(
      'long geometry is bounded to 500 points retaining endpoints',
      () async {
        final coordinates = List.generate(
          1001,
          (i) => [106.0 + i / 10000, 10.0 + i / 10000],
        );
        final route = await MapApiService(
          dio: fakeDio(publicResponse: osrmResponse(coordinates: coordinates)),
        ).getRoute(origin: origin, destination: destination);
        expect(route.points, hasLength(500));
        expect(route.points.first, const LatLng(10, 106));
        expect(route.points.last, const LatLng(10.1, 106.1));
      },
    );
  });

  group('Map Models Unit Tests', () {
    test(
      'GroupMemberLocation copyWith preserves identity and demo disclosure',
      () {
        final updatedAt = DateTime.utc(2026, 9, 27, 12);
        final member = GroupMemberLocation(
          memberId: 'demo-an',
          displayName: 'An Nguyễn',
          avatarInitials: 'AN',
          position: const LatLng(10.7740, 106.6591),
          updatedAt: updatedAt,
          status: GroupMemberStatus.online,
          isDemo: true,
        );

        final moved = member.copyWith(
          position: const LatLng(10.7750, 106.6600),
          status: GroupMemberStatus.idle,
        );

        expect(moved.memberId, member.memberId);
        expect(moved.displayName, member.displayName);
        expect(moved.position, isNot(member.position));
        expect(moved.status, GroupMemberStatus.idle);
        expect(moved.isDemo, isTrue);
      },
    );

    test('RouteData formats duration and distance correctly', () {
      const route1 = RouteData(
        points: [LatLng(10.7725, 106.6578), LatLng(11.9404, 108.4583)],
        distanceKm: 305.4,
        durationMinutes: 380, // 6h 20m
        isFallback: false,
        summary: 'QL20',
      );
      expect(route1.formattedDistance, '305 km');
      expect(route1.formattedDuration, '6 giờ 20 phút');

      const route2 = RouteData(
        points: [LatLng(10.7725, 106.6578), LatLng(10.7800, 106.6600)],
        distanceKm: 2.34,
        durationMinutes: 12,
        isFallback: true,
        summary: 'Dự phòng',
      );
      expect(route2.formattedDistance, '2.3 km');
      expect(route2.formattedDuration, '12 phút');
    });

    test('RouteData.fromJson parses Backend DTO properly', () {
      final json = {
        'data': {
          'distanceKm': 15.5,
          'durationMinutes': 30,
          'points': [
            {'lat': 10.77, 'lng': 106.65},
            {'lat': 10.78, 'lng': 106.66},
          ],
        },
      };
      final metadata = {'provider': 'osrm', 'isFallback': false};

      final route = RouteData.fromJson(json, metadata);
      expect(route.distanceKm, 15.5);
      expect(route.durationMinutes, 30);
      expect(route.isFallback, false);
      expect(route.points.length, 2);
      expect(route.summary, 'Tuyến đường OSRM');
    });
  });

  group('DestinationCatalogService Unit Tests', () {
    final catalog = DestinationCatalogService();

    test('getAll returns all 7 static Vietnam destinations', () {
      final all = catalog.getAll();
      expect(all.length, 7);
      expect(all.any((d) => d.id == 'dalat' && d.name == 'Đà Lạt'), isTrue);
      expect(
        all.any((d) => d.id == 'phuquoc' && d.icon == Icons.wb_sunny_outlined),
        isTrue,
      );
      expect(
        all.any(
          (d) => d.id == 'cantho' && d.icon == Icons.directions_boat_filled,
        ),
        isTrue,
      );
    });

    test('search with empty query returns all 7 destinations', () {
      final results = catalog.search('');
      expect(results.length, 7);
    });

    test('search by name "Đà" returns 1 result (Đà Lạt)', () {
      final results = catalog.search('Đà');
      expect(results.length, 1);
      expect(results.first.id, 'dalat');
    });

    test('search by region "Duyên" returns 1 result (Nha Trang)', () {
      final results = catalog.search('Duyên');
      expect(results.length, 1);
      expect(results.first.id, 'nhatrang');
    });

    test('search with non-existent query returns empty list', () {
      final results = catalog.search('xyz999');
      expect(results.isEmpty, isTrue);
    });
  });

  group('MapPresetService Unit Tests', () {
    test('getDefaultDemoRoute returns 4 waypoints for A->B->C->D demo', () {
      final presetService = MapPresetService();
      final demoRoute = presetService.getDefaultDemoRoute();
      expect(demoRoute.length, 4);
      expect(demoRoute.first.type, 'origin');
      expect(demoRoute.last.type, 'destination');
      expect(demoRoute[1].type, 'stop');
      expect(demoRoute[2].type, 'stop');
    });

    test(
      'getDemoGroupMembers returns deterministic disclosed demo members',
      () {
        final presetService = MapPresetService();
        final referenceTime = DateTime.utc(2026, 9, 27, 12);
        final members = presetService.getDemoGroupMembers(
          referenceTime: referenceTime,
        );

        expect(members.length, 4);
        expect(
          members.map((member) => member.memberId).toSet().length,
          members.length,
        );
        expect(members.every((member) => member.isDemo), isTrue);
        expect(
          members.every((member) => !member.updatedAt.isAfter(referenceTime)),
          isTrue,
        );
        expect(
          members.any((member) => member.status == GroupMemberStatus.offline),
          isTrue,
        );
      },
    );
  });

  group('MapProvider FSM State Machine & Lazy Loading Tests', () {
    test('1 & 2: init() without parameters starts in STATE A (destination == null, hasRoute == false)', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.init();

      expect(provider.destination, isNull);
      expect(provider.destinationName, isNull);
      expect(provider.waypoints.isEmpty, isTrue);
      expect(provider.hasRoute, isFalse);
      expect(provider.currentRoute, isNull);
      expect(provider.allStops.length, 1); // Only origin, safe without NPE
    });

    test('3: init() without parameters does NOT call MapApiService', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.init();

      expect(fakeRouting.callCount, 0);
    });

    test('refreshCurrentLocation updates GPS state without requesting a route in STATE A', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );
      await provider.init();
      expect(provider.isMockGps, isTrue);

      fakeLocation.result = const LocationResult(
        position: LatLng(10.7800, 106.6600),
        isMock: false,
        locationName: 'Vị trí GPS hiện tại của bạn',
      );
      await provider.refreshCurrentLocation();

      expect(provider.origin, const LatLng(10.7800, 106.6600));
      expect(provider.originName, 'Vị trí GPS hiện tại của bạn');
      expect(provider.isMockGps, isFalse);
      expect(fakeLocation.callCount, 2);
      expect(fakeRouting.callCount, 0);
    });

    test('group radar loads demo members lazily and selects members by id', () {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      expect(provider.isGroupRadarEnabled, isFalse);
      expect(provider.groupMembers, isEmpty);

      provider.setGroupRadarEnabled(true);

      expect(provider.isGroupRadarEnabled, isTrue);
      expect(provider.groupMembers.length, 4);
      expect(provider.isDemoGroupRadar, isTrue);
      expect(fakeRouting.callCount, 0);

      final firstMember = provider.groupMembers.first;
      provider.selectGroupMember(firstMember.memberId);
      expect(provider.selectedGroupMember?.memberId, firstMember.memberId);
      expect(provider.distanceToGroupMemberMeters(firstMember), greaterThan(0));

      provider.setGroupRadarEnabled(false);
      expect(provider.isGroupRadarEnabled, isFalse);
      expect(provider.selectedGroupMember, isNull);
      expect(provider.groupMembers, isEmpty);
    });

    test('4: init(targetDestination: X) enters STATE B and calls MapApiService once', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await provider.init(
        targetDestination: const LatLng(11.9404, 108.4583),
        targetName: 'Đà Lạt',
      );

      expect(fakeRouting.callCount, 1);
      expect(provider.hasRoute, isTrue);
      expect(provider.currentRoute, isNotNull);
      expect(provider.destinationName, 'Đà Lạt');
      expect(provider.allStops.length, 2); // origin + destination
    });

    test(
      '5: enterLocateOnlyMode() and clearRoute() resets everything to STATE A',
      () async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );

        await provider.loadDemoRoute();
        expect(provider.hasRoute, isTrue);

        provider.clearRoute();

        expect(provider.destination, isNull);
        expect(provider.destinationName, isNull);
        expect(provider.waypoints.isEmpty, isTrue);
        expect(provider.currentRoute, isNull);
        expect(provider.isDemoMode, isFalse);
        expect(provider.hasRoute, isFalse);
      },
    );

    test(
      '6 & 7: setDestination() and addWaypoint() do NOT trigger API calls',
      () {
        final fakeRouting = FakeMapApiService();
        final provider = MapProvider(apiService: fakeRouting);

        provider.setDestination(const LatLng(10.0, 105.0), 'Cần Thơ');
        expect(provider.destination, const LatLng(10.0, 105.0));
        expect(fakeRouting.callCount, 0);

        const wp = RouteWaypoint(
          id: 'stop1',
          title: 'Trạm dừng',
          position: LatLng(10.5, 105.5),
          type: 'stop',
        );
        provider.addWaypoint(wp);
        expect(provider.waypoints.length, 1);
        expect(fakeRouting.callCount, 0);
      },
    );

    test(
      'changing origin is lazy and buildRoute sends selected A and B to API',
      () async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );
        await provider.init();

        const customOrigin = LatLng(10.0452, 105.7469);
        const destination = LatLng(11.9404, 108.4583);
        provider.setOrigin(customOrigin, 'Cần Thơ');
        provider.setDestination(destination, 'Đà Lạt');

        expect(provider.isUsingCurrentLocation, isFalse);
        expect(fakeRouting.callCount, 0);

        await provider.buildRoute();

        expect(fakeRouting.callCount, 1);
        expect(fakeRouting.lastOrigin, customOrigin);
        expect(fakeRouting.lastDestination, destination);

        provider.useCurrentLocationAsOrigin();
        expect(provider.isUsingCurrentLocation, isTrue);
        expect(provider.origin, LocationService.defaultUniversityOrigin);
        expect(provider.isMockGps, isTrue);
        expect(provider.currentRoute, isNull);
      },
    );

    test('8: buildRoute() after setDestination() calls API once', () async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);

      provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
      expect(fakeRouting.callCount, 0);

      await provider.buildRoute();

      expect(fakeRouting.callCount, 1);
      expect(provider.currentRoute, isNotNull);
      expect(provider.hasRoute, isTrue);
    });

    test('9: buildRoute() when destination is null returns early without calling API', () async {
      final fakeRouting = FakeMapApiService();
      final provider = MapProvider(apiService: fakeRouting);

      expect(provider.destination, isNull);
      await provider.buildRoute();

      expect(fakeRouting.callCount, 0);
      expect(provider.currentRoute, isNull);
    });

    test('10: loadDemoRoute() loads 2 waypoints, 1 destination, and calls API once', () async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final presetService = MapPresetService();
      final provider = MapProvider(
        apiService: fakeRouting,
        presetService: presetService,
        locationService: fakeLocation,
      );

      await provider.loadDemoRoute();

      expect(fakeRouting.callCount, 1);
      expect(provider.waypoints.length, 2);
      expect(provider.destinationName, contains('Lâm Viên'));
      expect(provider.allStops.length, 4);
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.isFallback, isFalse);
    });

    test('11: buildRoute() generates local offline line when backend is unreachable', () async {
      final fakeRouting = FakeMapApiService()
        ..shouldThrowBackendUnreachable = true;
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
      await provider.buildRoute();

      // Must NOT crash, must generate local offline line with isFallback=true
      expect(provider.currentRoute, isNotNull);
      expect(provider.currentRoute!.isFallback, isTrue);
      expect(provider.currentRoute!.summary, contains('Đường thẳng cục bộ'));
      expect(provider.errorMessage, contains('Backend và OSRM không kết nối'));
      expect(provider.currentRoute!.points.length, 2);
      expect(provider.currentRoute!.distanceKm, greaterThan(100));
    });

    test(
      '12 & 13: removeWaypoint handles index in range and out of range safely',
      () {
        final provider = MapProvider();
        const wp1 = RouteWaypoint(
          id: '1',
          title: 'W1',
          position: LatLng(10, 106),
          type: 'stop',
        );
        const wp2 = RouteWaypoint(
          id: '2',
          title: 'W2',
          position: LatLng(11, 107),
          type: 'stop',
        );

        provider.addWaypoint(wp1);
        provider.addWaypoint(wp2);
        expect(provider.waypoints.length, 2);

        // Out of range does not crash or change list
        provider.removeWaypoint(99);
        provider.removeWaypoint(-1);
        expect(provider.waypoints.length, 2);

        // In range removes correctly
        provider.removeWaypoint(0);
        expect(provider.waypoints.length, 1);
        expect(provider.waypoints.first.id, '2');
      },
    );
  });

  group('Radar service lifecycle', () {
    test('TTL idles and evicts members without departure', () async {
      var clock = DateTime(2026, 10, 6);
      final client = RadarTestClient();
      final service = GroupLocationService(client: client, now: () => clock);
      await service.joinGroup(
        roomCode: 'ROOM',
        displayName: 'A',
        avatarInitials: 'A',
      );
      var members = <GroupMemberLocation>[];
      final sub = service.watchMembers('ROOM').listen((v) => members = v);
      final ping = <String, dynamic>{
        'user_id': 'B',
        'latitude': 10,
        'longitude': 106,
      };
      client.created.single.callbacks['location_ping']!(ping);
      client.created.single.callbacks['location_ping']!(ping);
      await pumpEventQueue();
      expect(members, hasLength(1));
      clock = clock.add(const Duration(seconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 5100));
      expect(members.single.status, GroupMemberStatus.idle);
      clock = clock.add(const Duration(seconds: 15));
      await Future<void>.delayed(const Duration(milliseconds: 5100));
      expect(members, isEmpty);
      await service.dispose();
      await sub.cancel();
      await client.dispose();
    });
    test('rejoin serializes removal and preserves identity', () async {
      final client = RadarTestClient();
      final service = GroupLocationService(client: client);
      await service.joinGroup(
        roomCode: 'ROOM',
        displayName: 'A',
        avatarInitials: 'A',
      );
      await service.publishLocation(
        groupId: 'ROOM',
        position: const LatLng(10, 106),
      );
      final old = client.created.single;
      final identity = old.sent.single['user_id'];
      client.removal = Completer<String>();
      final leaving = service.markOffline('ROOM');
      final joining = service.joinGroup(
        roomCode: 'ROOM',
        displayName: 'A',
        avatarInitials: 'A',
      );
      await pumpEventQueue();
      expect(client.created, hasLength(1));
      client.removal!.complete('ok');
      await leaving;
      await joining;
      await service.publishLocation(
        groupId: 'ROOM',
        position: const LatLng(11, 107),
      );
      expect(client.created.last.sent.single['user_id'], identity);
      var members = <GroupMemberLocation>[];
      final sub = service.watchMembers('ROOM').listen((v) => members = v);
      old.callbacks['location_ping']!({'user_id': 'ghost'});
      await pumpEventQueue();
      expect(members, isEmpty);
      await service.dispose();
      await sub.cancel();
      await client.dispose();
    });
  });

  group('MapProvider Group Radar Realtime Tests', () {
    testWidgets('leave closes modal while network departure is pending', (
      tester,
    ) async {
      final gateway = FakeGroupLocationService()
        ..pendingOffline = Completer<void>();
      final gps = FakeLocationService();
      final provider = MapProvider(
        groupLocationService: gateway,
        locationService: gps,
      );
      await provider.connectGroupRadar(
        userId: 'guest',
        displayName: 'A',
        avatarInitials: 'A',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => GroupRadarSheet(provider: provider),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rời phòng / Tắt Radar'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupRadarSheet), findsNothing);
      expect(provider.groupMembers, isEmpty);
      expect(provider.isGroupRadarEnabled, isFalse);
      gateway.pendingOffline!.complete();
      provider.dispose();
      await gps.close();
      await gateway.close();
    });

    test(
      'disconnect clears members and notifies before a stalled offline write',
      () async {
        final gateway = FakeGroupLocationService()
          ..pendingOffline = Completer<void>();
        final gps = FakeLocationService();
        final provider = MapProvider(
          groupLocationService: gateway,
          locationService: gps,
        );
        await provider.connectGroupRadar(
          userId: 'guest',
          displayName: 'A',
          avatarInitials: 'A',
        );
        gateway.membersController.add([
          GroupMemberLocation(
            memberId: 'b',
            displayName: 'B',
            avatarInitials: 'B',
            position: const LatLng(10, 106),
            updatedAt: DateTime.now(),
            status: GroupMemberStatus.online,
            isDemo: false,
          ),
        ]);
        await pumpEventQueue();
        expect(provider.groupMembers, hasLength(1));
        var notifications = 0;
        provider.addListener(() => notifications++);
        final departure = provider.disconnectGroupRadar();
        expect(provider.groupMembers, isEmpty);
        expect(provider.activeGroupId, isNull);
        expect(provider.isGroupRadarEnabled, isFalse);
        expect(notifications, 1);
        await departure.timeout(const Duration(milliseconds: 100));
        gateway.pendingOffline!.complete();
        provider.dispose();
        await gps.close();
        await gateway.close();
      },
    );

    testWidgets(
      'stalled join times out at six seconds and ignores late completion',
      (tester) async {
        final gateway = FakeGroupLocationService()
          ..pendingJoin = Completer<String>();
        final provider = MapProvider(
          groupLocationService: gateway,
          locationService: FakeLocationService(),
        );
        final attempt = provider.connectGroupRadar(
          userId: 'guest',
          displayName: 'A',
          avatarInitials: 'A',
        );
        final assertion = expectLater(
          attempt,
          throwsA(isA<TimeoutException>()),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await assertion;
        expect(
          provider.groupRadarConnectionState,
          GroupRadarConnectionState.idle,
        );
        expect(provider.groupMembers, isEmpty);
        gateway.pendingJoin!.complete('old-room');
        await tester.pump();
        expect(provider.activeGroupId, isNull);
        provider.dispose();
        await gateway.close();
      },
    );

    testWidgets('pause stops heartbeat and resume restores GPS publication', (
      tester,
    ) async {
      final gateway = FakeGroupLocationService();
      final gps = FakeLocationService();
      final provider = MapProvider(
        groupLocationService: gateway,
        locationService: gps,
      );
      await provider.connectGroupRadar(
        userId: 'guest',
        displayName: 'A',
        avatarInitials: 'A',
      );
      gps.locationController.add(gps.result);
      await tester.pump();
      expect(gateway.publishedPositions, hasLength(1));
      provider.onAppPaused();
      await tester.pump(const Duration(seconds: 9));
      expect(gateway.publishedPositions, hasLength(1));
      provider.onAppResumed();
      await tester.pump();
      gps.locationController.add(gps.result);
      await tester.pump();
      expect(gateway.publishedPositions, hasLength(2));
      await provider.disconnectGroupRadar();
      await tester.pump(const Duration(seconds: 3));
      expect(gateway.publishedPositions, hasLength(2));
      provider.dispose();
      await gps.close();
      await gateway.close();
    });

    test(
      'connects, deduplicates members, publishes real GPS, and disconnects',
      () async {
        final groupService = FakeGroupLocationService();
        final locationService = FakeLocationService();
        final provider = MapProvider(
          groupLocationService: groupService,
          locationService: locationService,
        );

        await provider.connectGroupRadar(
          userId: 'user-01',
          displayName: 'Hoàng Minh',
          avatarInitials: 'HM',
        );
        expect(
          provider.groupRadarConnectionState,
          GroupRadarConnectionState.realtime,
        );
        expect(groupService.joinCalls, 1);

        final member = GroupMemberLocation(
          memberId: 'user-02',
          displayName: 'Lan Trần',
          avatarInitials: 'LT',
          position: const LatLng(10.773, 106.658),
          updatedAt: DateTime(2026, 9, 27),
          status: GroupMemberStatus.online,
          isDemo: false,
        );
        groupService.membersController.add([member, member]);
        await pumpEventQueue();
        expect(provider.groupMembers, hasLength(1));
        expect(provider.isDemoGroupRadar, isFalse);

        locationService.locationController.add(
          const LocationResult(
            position: LatLng(10.774, 106.659),
            isMock: false,
            locationName: 'GPS',
          ),
        );
        await pumpEventQueue();
        expect(groupService.publishedPositions, [
          const LatLng(10.774, 106.659),
        ]);

        await provider.disconnectGroupRadar();
        expect(
          provider.groupRadarConnectionState,
          GroupRadarConnectionState.idle,
        );
        expect(provider.isGroupRadarEnabled, isFalse);
        expect(groupService.markOfflineCalls, 1);
        await locationService.close();
        await groupService.close();
        provider.dispose();
      },
    );

    test('publishes mock GPS as realtime data for emulator support', () async {
      final groupService = FakeGroupLocationService();
      final locationService = FakeLocationService();
      final provider = MapProvider(
        groupLocationService: groupService,
        locationService: locationService,
      );
      await provider.connectGroupRadar(
        userId: 'user-01',
        displayName: 'Hoàng Minh',
        avatarInitials: 'HM',
      );

      locationService.locationController.add(
        const LocationResult(
          position: LocationService.defaultUniversityOrigin,
          isMock: true,
          locationName: LocationService.defaultOriginName,
        ),
      );
      await pumpEventQueue();
      expect(groupService.publishedPositions, [
        LocationService.defaultUniversityOrigin,
      ]);

      await provider.disconnectGroupRadar();
      await locationService.close();
      await groupService.close();
      provider.dispose();
    });

    test('Supabase failure reports error without enabling demo', () async {
      final groupService = FakeGroupLocationService()..shouldFailJoin = true;
      final provider = MapProvider(groupLocationService: groupService);

      await expectLater(
        provider.connectGroupRadar(
          userId: 'user-01',
          displayName: 'Hoàng Minh',
          avatarInitials: 'HM',
        ),
        throwsStateError,
      );
      expect(
        provider.groupRadarConnectionState,
        GroupRadarConnectionState.idle,
      );
      expect(provider.groupRadarMessage, contains('network unavailable'));
      expect(provider.groupMembers, isEmpty);
      expect(provider.isGroupRadarEnabled, isFalse);
      await groupService.close();
      provider.dispose();
    });
  });

  group('Journey Board UI Widget Tests', () {
    testWidgets(
      'JourneyCarouselWidget renders cards and triggers onCardChanged',
      (tester) async {
        int changedIndex = -1;
        const waypoints = [
          RouteWaypoint(
            id: '1',
            title: 'Điểm 1',
            position: LatLng(10, 106),
            type: 'origin',
            time: '08:00',
          ),
          RouteWaypoint(
            id: '2',
            title: 'Điểm 2',
            position: LatLng(11, 107),
            type: 'stop',
            time: '10:30',
          ),
        ];
        final pageController = PageController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JourneyCarouselWidget(
                waypoints: waypoints,
                activeIndex: 0,
                pageController: pageController,
                onCardChanged: (idx) => changedIndex = idx,
              ),
            ),
          ),
        );

        expect(find.text('Điểm 1'), findsOneWidget);
        expect(find.text('XUẤT PHÁT'), findsOneWidget);
        expect(find.text('08:00'), findsOneWidget);

        await tester.drag(find.text('Điểm 1'), const Offset(-400, 0));
        await tester.pumpAndSettle();

        expect(changedIndex, 1);
      },
    );

    testWidgets(
      'MilestoneMarkerWidget renders stop capsule with sequence and responds to tap',
      (tester) async {
        bool tapped = false;
        const wp = RouteWaypoint(
          id: 'stop1',
          title: 'Thác Dambri',
          position: LatLng(11, 107),
          type: 'stop',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MilestoneMarkerWidget(
                waypoint: wp,
                sequenceNumber: 2,
                isActive: true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Thác Dambri'), findsOneWidget);
        expect(find.text('02'), findsOneWidget);

        await tester.tap(find.text('Thác Dambri'));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      '15: RouteBuilderSheet opens and "VẼ LỘ TRÌNH" button is disabled until destination is chosen',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final provider = MapProvider(apiService: fakeRouting);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<MapProvider>.value(
              value: provider,
              child: const Scaffold(body: RouteBuilderSheet()),
            ),
          ),
        );

        // Initially, destination is null -> button disabled
        final buttonFinder = find.widgetWithText(FilledButton, 'VẼ LỘ TRÌNH');
        expect(buttonFinder, findsOneWidget);
        final FilledButton button = tester.widget(buttonFinder);
        expect(button.onPressed, isNull);

        // Set destination -> button becomes enabled
        provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
        await tester.pumpAndSettle();

        final FilledButton enabledButton = tester.widget(buttonFinder);
        expect(enabledButton.onPressed, isNotNull);

        await tester.tap(find.byTooltip('Đổi điểm xuất phát'));
        await tester.pumpAndSettle();

        expect(find.text('Chọn Điểm Xuất Phát'), findsOneWidget);
        expect(find.text('Dùng vị trí hiện tại'), findsOneWidget);
        await tester.tap(find.text('TP. Hồ Chí Minh').last);
        await tester.pumpAndSettle();

        expect(provider.originName, 'TP. Hồ Chí Minh');
        expect(provider.isUsingCurrentLocation, isFalse);
        expect(fakeRouting.callCount, 0);
      },
    );

    testWidgets('DiamondMilestoneMarker renders sequence and responds to tap', (
      tester,
    ) async {
      bool tapped = false;
      const wp = RouteWaypoint(
        id: 'stop_hotel',
        title: 'Pine Hill Hotel',
        position: LatLng(11.9, 108.4),
        type: 'stop',
        category: 'Khách sạn',
        isCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DiamondMilestoneMarker(
                waypoint: wp,
                sequenceNumber: 1,
                isSelected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DiamondMilestoneMarker), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.hotel_rounded), findsOneWidget);

      await tester.tap(find.byType(DiamondMilestoneMarker));
      expect(tapped, isTrue);
    });

    testWidgets('FloatingViewSwitch toggles between map and story mode', (
      tester,
    ) async {
      JourneyViewMode selectedMode = JourneyViewMode.map;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FloatingViewSwitch(
                  currentMode: selectedMode,
                  onModeChanged: (m) => setState(() => selectedMode = m),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Hành trình'), findsOneWidget);

      await tester.tap(find.text('Hành trình'));
      await tester.pumpAndSettle();

      expect(selectedMode, JourneyViewMode.story);
    });

    testWidgets(
      'JourneyTripCard renders title, day selector, and triggers selectDay',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final provider = MapProvider(apiService: fakeRouting);
        await provider.loadDemoRoute();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: JourneyTripCard(provider: provider)),
          ),
        );

        expect(find.text('CHUYẾN ĐI CỦA MINH'), findsOneWidget);
        expect(find.text('OSRM'), findsOneWidget);
        expect(find.textContaining('→'), findsOneWidget);
        expect(find.text('NGÀY 1'), findsOneWidget);
        expect(find.text('NGÀY 2'), findsOneWidget);

        await tester.tap(find.text('NGÀY 2'));
        expect(provider.selectedDay, 2);
      },
    );

    testWidgets('JourneyTripCard labels offline route as FALLBACK', (
      tester,
    ) async {
      final fakeRouting = FakeMapApiService()
        ..shouldThrowBackendUnreachable = true;
      final provider = MapProvider(apiService: fakeRouting);
      provider.setDestination(const LatLng(11.9404, 108.4583), 'Đà Lạt');
      await provider.buildRoute();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JourneyTripCard(provider: provider)),
        ),
      );

      expect(find.text('FALLBACK'), findsOneWidget);
      expect(find.textContaining('→'), findsOneWidget);
    });

    testWidgets(
      '16-18: STATE A renders Journey Preview Card and tap explores demo route',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<MapProvider>.value(
              value: provider,
              child: const TripMapScreen(enableNetworkTiles: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TileLayer), findsNothing);
        expect(find.byType(SimpleAttributionWidget), findsOneWidget);
        expect(find.text('OpenStreetMap contributors'), findsOneWidget);
        expect(find.byTooltip('Chế độ bản đồ'), findsNothing);

        // In STATE A:
        expect(find.text('CHUYẾN ĐI CỦA MINH'), findsOneWidget);
        expect(find.text('Đà Lạt · 3 ngày 2 đêm'), findsOneWidget);
        expect(find.text('Khám phá hành trình'), findsOneWidget);
        expect(find.text('Vị trí mặc định'), findsOneWidget);
        expect(find.text('Vị trí hiện tại'), findsNothing);

        // Tap 'Khám phá hành trình' -> triggers loadDemoRoute -> enters STATE B
        await tester.tap(find.text('Khám phá hành trình'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(provider.hasRoute, isTrue);
        // In STATE B: Journey Preview Card disappears
        expect(find.text('Khám phá hành trình'), findsNothing);
      },
    );

    testWidgets(
      '19: Tap "hoặc tự tạo lộ trình mới ↓" opens RouteBuilderSheet',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<MapProvider>.value(
              value: provider,
              child: const TripMapScreen(enableNetworkTiles: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('hoặc tự tạo lộ trình mới ↓'), findsOneWidget);
        await tester.tap(find.text('hoặc tự tạo lộ trình mới ↓'));
        await tester.pumpAndSettle();

        expect(find.byType(RouteBuilderSheet), findsOneWidget);
      },
    );

    testWidgets('N1: STATE A (chưa có route): KHÔNG thấy JourneyTripCard', (
      tester,
    ) async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapProvider>.value(
            value: provider,
            child: const TripMapScreen(enableNetworkTiles: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(JourneyTripCard), findsNothing);
      expect(find.byType(FloatingViewSwitch), findsNothing);
    });

    testWidgets('N2: STATE B: thấy JourneyTripCard + FloatingViewSwitch', (
      tester,
    ) async {
      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapProvider>.value(
            value: provider,
            child: const TripMapScreen(enableNetworkTiles: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await provider.loadDemoRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(JourneyTripCard), findsOneWidget);
      expect(find.byType(FloatingViewSwitch), findsOneWidget);
    });

    testWidgets(
      'N3: Bấm FloatingViewSwitch item "Hành trình" -> JourneyStoryTimeline hiện',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<MapProvider>.value(
              value: provider,
              child: const TripMapScreen(enableNetworkTiles: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await provider.loadDemoRoute();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Hành trình'), findsOneWidget);
        await tester.tap(find.text('Hành trình'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(JourneyStoryTimeline), findsOneWidget);
      },
    );

    testWidgets('N4: Bấm marker -> LocationDetailSheet mở với đúng title', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRouting = FakeMapApiService();
      final fakeLocation = FakeLocationService();
      final provider = MapProvider(
        apiService: fakeRouting,
        locationService: fakeLocation,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MapProvider>.value(
            value: provider,
            child: const TripMapScreen(enableNetworkTiles: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await provider.loadDemoRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final diamondFinder = find.byType(DiamondMilestoneMarker);
      expect(diamondFinder, findsWidgets);

      await tester.tap(diamondFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LocationDetailSheet), findsOneWidget);
      final firstTitle = provider.currentDayStops.first.title;
      expect(find.text(firstTitle), findsWidgets);
    });

    testWidgets(
      'N5: TileLayer has OSM Global urlTemplate and OSM HOT fallbackUrl configured',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<MapProvider>.value(
              value: provider,
              child: const TripMapScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileLayerFinder = find.byType(TileLayer);
        expect(tileLayerFinder, findsOneWidget);
        final tileLayer = tester.widget<TileLayer>(tileLayerFinder);
        expect(tileLayer.urlTemplate, contains('tile.openstreetmap.org'));
        expect(tileLayer.fallbackUrl, contains('tile.openstreetmap.fr/hot'));
        expect(tileLayer.subdomains, contains('a'));
      },
    );
  });

  group('Journey Map Multi-Day & AI Optimizer Tests', () {
    test(
      'selectDay switches selectedDay and filters currentDayStops correctly',
      () async {
        final provider = MapProvider(apiService: FakeMapApiService());
        await provider.loadDemoRoute();

        expect(provider.selectedDay, 1);
        provider.selectDay(2);
        expect(provider.selectedDay, 2);
      },
    );

    test('toggleStopCompleted flips isCompleted status', () async {
      final provider = MapProvider(apiService: FakeMapApiService());
      await provider.loadDemoRoute();

      final firstStop = provider.waypoints.first;
      final initialStatus = firstStop.isCompleted;

      provider.toggleStopCompleted(firstStop.id);
      expect(provider.waypoints.first.isCompleted, !initialStatus);
    });

    test(
      'applyAiReorder updates waypoint order and triggers API route fetch',
      () async {
        final fakeRouting = FakeMapApiService();
        final provider = MapProvider(apiService: fakeRouting);
        await provider.loadDemoRoute();

        final initialCallCount = fakeRouting.callCount;
        final reversedWaypoints = provider.waypoints.reversed.toList();

        await provider.applyAiReorder(reversedWaypoints);

        expect(fakeRouting.callCount, initialCallCount + 1);
        expect(provider.waypoints.first.id, reversedWaypoints.first.id);
      },
    );

    test('reorderWaypoints updates waypoint order correctly', () async {
      final provider = MapProvider(apiService: FakeMapApiService());
      await provider.loadDemoRoute();

      final firstId = provider.waypoints[0].id;
      final secondId = provider.waypoints[1].id;

      await provider.reorderWaypoints(0, 1);
      expect(provider.waypoints[0].id, secondId);
      expect(provider.waypoints[1].id, firstId);
    });

    test(
      'updateWaypointDay updates dayNumber for specified waypoint',
      () async {
        final provider = MapProvider(apiService: FakeMapApiService());
        await provider.loadDemoRoute();

        provider.updateWaypointDay(0, 3);
        expect(provider.waypoints.first.dayNumber, 3);
      },
    );

    test('getOptimizationPreview returns deterministic TSP result', () async {
      final provider = MapProvider(apiService: FakeMapApiService());
      await provider.loadDemoRoute();

      final preview = provider.getOptimizationPreview();
      expect(preview.originalDistanceKm, greaterThan(0));
      expect(preview.reorderedWaypoints.length, provider.waypoints.length);
    });

    testWidgets(
      'RouteBuilderSheet renders ReorderableListView and opens AiOptimizationSheet on button tap',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final provider = MapProvider(apiService: FakeMapApiService());
        await provider.loadDemoRoute();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<MapProvider>.value(
                value: provider,
                child: const RouteBuilderSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ReorderableListView), findsOneWidget);
        expect(find.text('Tối ưu AI'), findsOneWidget);
        expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

        await tester.tap(find.text('Tối ưu AI'));
        await tester.pumpAndSettle();

        expect(find.byType(AiOptimizationSheet), findsOneWidget);
      },
    );

    testWidgets(
      'JourneyStoryTimeline renders Day chips and allows switching day',
      (tester) async {
        final provider = MapProvider(apiService: FakeMapApiService());
        await provider.loadDemoRoute();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JourneyStoryTimeline(
                provider: provider,
                onStopSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ngày 1'), findsOneWidget);
        expect(find.text('Ngày 2'), findsOneWidget);

        await tester.tap(find.text('Ngày 2'));
        await tester.pumpAndSettle();

        expect(provider.selectedDay, 2);
      },
    );

    testWidgets(
      'Group Location Radar: floating button opens GroupRadarSheet and toggles demo members',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<MapProvider>.value(
              value: provider,
              child: const TripMapScreen(enableNetworkTiles: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find floating radar button
        final radarBtn = find.byTooltip('Radar nhóm');
        expect(radarBtn, findsOneWidget);

        await tester.tap(radarBtn);
        await tester.pumpAndSettle();

        // GroupRadarSheet should be open
        expect(find.byType(GroupRadarSheet), findsOneWidget);
        expect(find.text('Radar Nhóm Du Lịch'), findsOneWidget);
        expect(find.text('KẾT NỐI PHÒNG RADAR'), findsOneWidget);

        // Tap demo button
        final demoBtn = find.text(
          'Hoặc xem thử dữ liệu mẫu (4 thành viên demo)',
        );
        expect(demoBtn, findsOneWidget);
        await tester.tap(demoBtn);
        await tester.pumpAndSettle();

        // Radar should be enabled and sheet closed
        expect(provider.isGroupRadarEnabled, isTrue);
        expect(provider.groupMembers.length, 4);

        // Map should show banner and member markers
        expect(
          find.textContaining('Radar nhóm demo [4 thành viên]'),
          findsOneWidget,
        );
        expect(find.text('An Nguyễn'), findsOneWidget);
        expect(find.text('Lan Trần'), findsOneWidget);
      },
    );

    testWidgets(
      'Group Location Radar: GroupRadarSheet displays members list and allows disconnecting',
      (tester) async {
        final fakeRouting = FakeMapApiService();
        final fakeLocation = FakeLocationService();
        final provider = MapProvider(
          apiService: fakeRouting,
          locationService: fakeLocation,
        );
        provider.setGroupRadarEnabled(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GroupRadarSheet(provider: provider)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('THÀNH VIÊN TRONG PHÒNG (4)'),
          findsOneWidget,
        );
        expect(find.text('An Nguyễn'), findsOneWidget);
        expect(find.text('Lan Trần'), findsOneWidget);
        expect(find.text('Khoa Lê'), findsOneWidget);
        expect(find.text('Mai Phạm'), findsOneWidget);
        expect(find.text('Rời phòng / Tắt Radar'), findsOneWidget);

        await tester.tap(find.text('Rời phòng / Tắt Radar'));
        await tester.pumpAndSettle();

        expect(provider.isGroupRadarEnabled, isFalse);
      },
    );
  });
}
