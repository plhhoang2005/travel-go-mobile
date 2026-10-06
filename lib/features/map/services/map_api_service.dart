import 'dart:async';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_models.dart';
import '../../../core/constants/api_constants.dart';

class RoutingException implements Exception {
  final String message;
  final bool backendUnreachable;
  final bool isFallback;

  RoutingException(
    this.message, {
    this.backendUnreachable = false,
    this.isFallback = false,
  });

  @override
  String toString() => message;
}

class MapApiService {
  final Dio _dio;

  MapApiService({Dio? dio}) : _dio = dio ?? _createDefaultDio();

  static Dio _createDefaultDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    // Exponential backoff retry interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.requestOptions.extra['retries'] != null &&
              e.requestOptions.extra['retries'] as int > 0) {
            int retries = e.requestOptions.extra['retries'] as int;
            int delayMs = 500 * (3 - retries); // 500ms, 1000ms

            await Future.delayed(Duration(milliseconds: delayMs));
            e.requestOptions.extra['retries'] = retries - 1;

            try {
              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (e2) {
              return handler.reject(e2 as DioException);
            }
          }
          return handler.next(e);
        },
      ),
    );

    return dio;
  }

  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    final allWaypoints = [
      {'lat': origin.latitude, 'lng': origin.longitude},
      ...waypoints.map(
        (w) => {'lat': w.position.latitude, 'lng': w.position.longitude},
      ),
      {'lat': destination.latitude, 'lng': destination.longitude},
    ];

    try {
      final response = await _dio.post(
        ApiConstants.mapsRoutes,
        data: {'waypoints': allWaypoints},
        options: Options(extra: {'retries': 2}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          return RouteData.fromJson(
            data,
            data['metadata'] as Map<String, dynamic>? ?? {},
          );
        } else {
          final metadata = data['metadata'] as Map<String, dynamic>?;
          final isFallback = metadata?['isFallback'] as bool? ?? false;
          throw RoutingException(
            'Lỗi máy chủ đường dẫn: Không có dữ liệu',
            backendUnreachable: false,
            isFallback: isFallback,
          );
        }
      } else {
        throw RoutingException(
          'Máy chủ phản hồi HTTP ${response.statusCode}',
          backendUnreachable: response.statusCode == 503,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return _fetchDirectOsrmRoute(origin, destination, waypoints);
      }

      if (e.response?.statusCode == 503) {
        return _fetchDirectOsrmRoute(origin, destination, waypoints);
      }

      throw RoutingException(
        'Lỗi mạng kết nối: ${e.message}',
        backendUnreachable: false,
      );
    } catch (e) {
      if (e is RoutingException) {
        if (e.backendUnreachable) {
          return _fetchDirectOsrmRoute(origin, destination, waypoints);
        }
        rethrow;
      }
      throw RoutingException(
        'Đã xảy ra lỗi không xác định: $e',
        backendUnreachable: false,
      );
    }
  }

  Future<RouteData> _fetchDirectOsrmRoute(
    LatLng origin,
    LatLng destination,
    List<RouteWaypoint> waypoints,
  ) async {
    final coordinates = [
      origin,
      ...waypoints.map((w) => w.position),
      destination,
    ].map((point) => '${point.longitude},${point.latitude}').join(';');
    final cancelToken = CancelToken();
    const timeout = Duration(seconds: 5);
    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            'https://router.project-osrm.org/route/v1/driving/$coordinates',
            queryParameters: {'overview': 'full', 'geometries': 'geojson'},
            cancelToken: cancelToken,
            options: Options(
              sendTimeout: timeout,
              receiveTimeout: timeout,
              extra: {'retries': 0},
            ),
          )
          .timeout(
            timeout,
            onTimeout: () {
              cancelToken.cancel('OSRM vượt quá thời gian chờ 5 giây.');
              throw TimeoutException('OSRM vượt quá thời gian chờ 5 giây.');
            },
          );
      final data = response.data;
      if (data == null || data['code'] != 'Ok') {
        throw RoutingException(
          'OSRM không tìm được tuyến đường: ${data?['code'] ?? 'phản hồi rỗng'}',
        );
      }
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        throw RoutingException('OSRM không trả về tuyến đường.');
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final rawPoints = geometry['coordinates'] as List<dynamic>;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      if (rawPoints.length < 2 ||
          !distance.isFinite ||
          distance < 0 ||
          !duration.isFinite ||
          duration < 0) {
        throw RoutingException('Dữ liệu tuyến đường OSRM không hợp lệ.');
      }
      // Limit rendering work while retaining the first and last road coordinates.
      final count = rawPoints.length > 500 ? 500 : rawPoints.length;
      final points = List<LatLng>.generate(count, (index) {
        final sourceIndex = (index * (rawPoints.length - 1) / (count - 1))
            .round();
        final coordinate = rawPoints[sourceIndex] as List<dynamic>;
        final longitude = (coordinate[0] as num).toDouble();
        final latitude = (coordinate[1] as num).toDouble();
        if (!latitude.isFinite ||
            !longitude.isFinite ||
            latitude.abs() > 90 ||
            longitude.abs() > 180) {
          throw RoutingException('Tọa độ OSRM không hợp lệ.');
        }
        return LatLng(latitude, longitude);
      });
      return RouteData(
        points: points,
        distanceKm: distance / 1000,
        durationMinutes: (duration / 60).round(),
        isFallback: false,
        summary: 'Tuyến đường OSRM',
        waypoints: waypoints,
      );
    } on TimeoutException catch (error) {
      throw RoutingException(
        'Backend và OSRM không khả dụng: $error',
        backendUnreachable: true,
      );
    } on DioException catch (error) {
      final unreachable =
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          (error.response?.statusCode ?? 0) >= 500;
      throw RoutingException(
        'Không thể định tuyến qua OSRM: ${error.message}',
        backendUnreachable: unreachable,
      );
    } on RoutingException {
      rethrow;
    } catch (error) {
      throw RoutingException('Dữ liệu OSRM không hợp lệ: $error');
    }
  }
}
