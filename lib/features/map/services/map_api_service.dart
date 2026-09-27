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
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Exponential backoff retry interceptor
    dio.interceptors.add(InterceptorsWrapper(
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
    ));

    return dio;
  }

  Future<RouteData> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<RouteWaypoint> waypoints = const [],
  }) async {
    final allWaypoints = [
      {'lat': origin.latitude, 'lng': origin.longitude},
      ...waypoints.map((w) => {'lat': w.position.latitude, 'lng': w.position.longitude}),
      {'lat': destination.latitude, 'lng': destination.longitude}
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
        throw RoutingException(
          'Không thể kết nối đến máy chủ Backend (${e.message})',
          backendUnreachable: true,
        );
      }

      if (e.response?.statusCode == 503) {
        throw RoutingException(
          'Dịch vụ bản đồ tạm thời không khả dụng (HTTP 503)',
          backendUnreachable: true,
        );
      }

      throw RoutingException(
        'Lỗi mạng kết nối: ${e.message}',
        backendUnreachable: false,
      );
    } catch (e) {
      if (e is RoutingException) rethrow;
      throw RoutingException(
        'Đã xảy ra lỗi không xác định: $e',
        backendUnreachable: false,
      );
    }
  }
}
