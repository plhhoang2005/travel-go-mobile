import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Allow overriding baseUrl at runtime (e.g. for testing on physical devices via LAN IP)
  static String? overrideBaseUrl;

  // Configured for local dev: 10.0.2.2 for Android Emulator, localhost for iOS/Web/Desktop
  static String get baseUrl {
    if (overrideBaseUrl != null && overrideBaseUrl!.trim().isNotEmpty) {
      return overrideBaseUrl!.trim();
    }
    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  static const String planTrip = '/plan-trip';
  static const String simulateSensitivity = '/simulate-sensitivity';
  static const String destinations = '/destinations';
  static const String mapsRoutes = '/maps/routes';
  static const String health = '/health';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
