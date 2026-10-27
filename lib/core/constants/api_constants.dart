import '../services/backend_api_config.dart';

class ApiConstants {
  static BackendApiConfig? _config;

  // Allow overriding baseUrl at runtime (e.g. for testing on physical devices via LAN IP)
  static String? overrideBaseUrl;

  static void configure(BackendApiConfig config) {
    _config = config;
  }

  static String get baseUrl {
    if (overrideBaseUrl != null && overrideBaseUrl!.trim().isNotEmpty) {
      return overrideBaseUrl!.trim();
    }
    if (_config != null) {
      return _config!.effectiveBaseUrl;
    }
    return BackendApiConfig.defaultBaseUrl();
  }

  static int get configRevision => _config?.revision ?? 0;

  static const String planTrip = '/plan-trip';
  static const String simulateSensitivity = '/simulate-sensitivity';
  static const String destinations = '/destinations';
  static const String mapsRoutes = '/maps/routes';
  static const String health = '/health';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
