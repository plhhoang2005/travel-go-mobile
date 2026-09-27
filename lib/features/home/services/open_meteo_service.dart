import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/destination_weather.dart';

class OpenMeteoService {
  final Dio _dio;

  static const Map<String, (double lat, double lng)> destinationCoordinates = {
    'da-nang': (16.0544, 108.2022),
    'da-lat': (11.9404, 108.4583),
    'phu-quoc': (10.2899, 103.9840),
    'nha-trang': (12.2388, 109.1967),
    'hoi-an': (15.8801, 108.3380),
    'ha-long': (20.9505, 107.0734),
    'sa-pa': (22.3364, 103.8438),
    'hue': (16.4637, 107.5909),
    'vung-tau': (10.3460, 107.0843),
    'quy-nhon': (13.7830, 109.2197),
    'phan-thiet': (10.9804, 108.2615),
    'can-tho': (10.0452, 105.7469),
    'ha-noi': (21.0285, 105.8542),
    'tphcm': (10.8231, 106.6297),
  };

  final Map<String, DestinationWeather> _cache = {};

  OpenMeteoService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.open-meteo.com/v1',
                connectTimeout: const Duration(milliseconds: 4000),
                receiveTimeout: const Duration(milliseconds: 4000),
                sendTimeout: const Duration(milliseconds: 4000),
              ),
            );

  DestinationWeather? getCachedWeather(String destinationId) {
    final cached = _cache[destinationId];
    if (cached != null && !cached.isExpired) {
      return cached;
    }
    return null;
  }

  Future<DestinationWeather?> fetchWeather(
    String destinationId, {
    bool forceRefresh = false,
    double defaultFallbackTemp = 26.0,
  }) async {
    final coords = destinationCoordinates[destinationId];
    if (coords == null) return null;

    if (!forceRefresh) {
      final cached = getCachedWeather(destinationId);
      if (cached != null) return cached;
    }

    try {
      final response = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': coords.$1,
          'longitude': coords.$2,
          'current': 'temperature_2m,relative_humidity_2m,weather_code',
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final weather = DestinationWeather.fromOpenMeteoJson(
          response.data as Map<String, dynamic>,
        );
        _cache[destinationId] = weather;
        return weather;
      }
    } on DioException catch (e) {
      if (kDebugMode && e.response?.statusCode != 400) {
        debugPrint('OpenMeteoService notice for $destinationId: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OpenMeteoService notice for $destinationId: $e');
      }
    }

    return _cache[destinationId] ?? DestinationWeather.fallback(defaultFallbackTemp);
  }

  Future<Map<String, DestinationWeather>> fetchBatchWeather(
    List<String> destinationIds, {
    bool forceRefresh = false,
  }) async {
    final Map<String, DestinationWeather> result = {};
    final futures = destinationIds.map((id) async {
      final weather = await fetchWeather(id, forceRefresh: forceRefresh);
      if (weather != null) {
        result[id] = weather;
      }
    });

    await Future.wait(futures);
    return result;
  }
}
