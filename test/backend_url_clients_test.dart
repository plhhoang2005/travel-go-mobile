import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelgo_mobile/core/constants/api_constants.dart';
import 'package:travelgo_mobile/core/services/backend_api_config.dart';
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
  });
}
