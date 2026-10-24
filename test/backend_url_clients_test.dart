import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/core/constants/api_constants.dart';
import 'package:travelgo_mobile/core/services/backend_api_config.dart';
import 'package:travelgo_mobile/features/map/services/map_api_service.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';

void main() {
  group('Task R1: API Clients Synchronization with BackendApiConfig', () {
    late SharedPreferences prefs;
    late BackendApiConfig config;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      config = await BackendApiConfig.load(prefs);
      ApiConstants.configure(config);
    });

    test('TripApiService captures dynamic baseUrl from ApiConstants and reader', () async {
      final initialService = TripApiService(
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );
      expect(initialService.baseUrlReader!(), BackendApiConfig.defaultBaseUrl());

      // Verify initial configuration reflects default
      expect(config.effectiveBaseUrl, BackendApiConfig.defaultBaseUrl());

      // Update configuration
      await config.setBaseUrl('http://192.168.1.88:9000');
      expect(config.effectiveBaseUrl, 'http://192.168.1.88:9000/api/v1');
      expect(config.revision, 1);

      // Verify that a request attempts to call the updated host
      // Using an adapter/mock interceptor or observing request options
      final dio = Dio();
      String? recordedUrl;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            recordedUrl = '${options.baseUrl}${options.path}';
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Connection refused intentionally for test',
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      final client = TripApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      final req = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 2,
        budgetVnd: 5000000,
        preferences: const ['nature'],
        priority: 'balanced',
        startDate: '2026-11-01',
        endDate: '2026-11-03',
      );

      await client.planTrip(req);
      expect(recordedUrl, 'http://192.168.1.88:9000/api/v1/plan-trip');
    });

    test('TripApiService throws BackendConfigChangedException when revision changes in-flight', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Simulate config changing while request is in-flight
            await config.setBaseUrl('http://192.168.1.99:9000');
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'success',
                  'destination': 'Da Nang',
                  'budget': 5000000,
                  'estimated_cost': 4500000,
                  'days': 3,
                  'itinerary': [],
                  'summary': 'Test',
                },
              ),
            );
          },
        ),
      );

      final client = TripApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      final req = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 2,
        budgetVnd: 5000000,
        preferences: const ['nature'],
        priority: 'balanced',
        startDate: '2026-11-01',
        endDate: '2026-11-03',
      );

      expect(
        () => client.planTrip(req),
        throwsA(isA<BackendConfigChangedException>()),
      );
    });

    test('MapApiService throws BackendConfigChangedException when revision changes in-flight', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Simulate config changing while map route request is in-flight
            await config.setBaseUrl('http://192.168.1.99:9000');
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'routes': [
                    {
                      'distance': 1000.0,
                      'duration': 600.0,
                      'geometry': 'mock_geometry',
                      'steps': [],
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final mapClient = MapApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      expect(
        () => mapClient.getRoute(
          origin: const LatLng(16.0544, 108.2022),
          destination: const LatLng(16.0744, 108.2222),
        ),
        throwsA(isA<BackendConfigChangedException>()),
      );
    });

    test('url_change_during_osrm_success_rejects_old_operation', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.uri.host.contains('project-osrm.org')) {
              // Simulate config changing while OSRM request is in-flight
              await config.setBaseUrl('http://192.168.1.99:9000');
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'code': 'Ok',
                    'routes': [
                      {
                        'distance': 1500.0,
                        'duration': 300.0,
                        'geometry': {
                          'coordinates': [
                            [107.5775, 16.4698],
                            [107.5440, 16.4530],
                          ],
                        },
                      }
                    ],
                  },
                ),
              );
            } else {
              // Backend 503 triggers fallback to OSRM
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 503,
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          },
        ),
      );

      final mapClient = MapApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      expect(
        () => mapClient.getRoute(
          origin: const LatLng(16.4698, 107.5775),
          destination: const LatLng(16.4530, 107.5440),
        ),
        throwsA(isA<BackendConfigChangedException>()),
      );
    });

    test('url_change_during_osrm_error_preserves_invalidation', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.uri.host.contains('project-osrm.org')) {
              await config.setBaseUrl('http://192.168.1.99:9000');
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                  error: 'OSRM timeout',
                ),
              );
            } else {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 503,
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          },
        ),
      );

      final mapClient = MapApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      expect(
        () => mapClient.getRoute(
          origin: const LatLng(16.4698, 107.5775),
          destination: const LatLng(16.4530, 107.5440),
        ),
        throwsA(isA<BackendConfigChangedException>()),
      );
    });

    test('same_revision_osrm_still_succeeds', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.uri.host.contains('project-osrm.org')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'code': 'Ok',
                    'routes': [
                      {
                        'distance': 1500.0,
                        'duration': 300.0,
                        'geometry': {
                          'coordinates': [
                            [107.5775, 16.4698],
                            [107.5440, 16.4530],
                          ],
                        },
                      }
                    ],
                  },
                ),
              );
            } else {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 503,
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          },
        ),
      );

      final mapClient = MapApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      final route = await mapClient.getRoute(
        origin: const LatLng(16.4698, 107.5775),
        destination: const LatLng(16.4530, 107.5440),
      );

      expect(route.points.length, 2);
      expect(route.summary, 'Tuyến đường OSRM');
    });

    test('new_operation_uses_new_host_without_retargeting_old_retry', () async {
      final recordedHosts = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            recordedHosts.add(options.uri.host);
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'fail',
              ),
            );
          },
        ),
      );

      final mapClient = MapApiService(
        dio: dio,
        baseUrlReader: () => config.effectiveBaseUrl,
        configRevisionReader: () => config.revision,
      );

      try {
        await mapClient.getRoute(
          origin: const LatLng(16.0, 108.0),
          destination: const LatLng(16.1, 108.1),
        );
      } catch (_) {}

      await config.setBaseUrl('http://192.168.1.99:9000');

      try {
        await mapClient.getRoute(
          origin: const LatLng(16.0, 108.0),
          destination: const LatLng(16.1, 108.1),
        );
      } catch (_) {}

      expect(recordedHosts, contains('192.168.1.99'));
    });
  });
}
