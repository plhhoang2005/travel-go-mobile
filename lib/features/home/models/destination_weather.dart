import 'package:flutter/material.dart';

class DestinationWeather {
  final double temperature;
  final int weatherCode;
  final int relativeHumidity;
  final DateTime fetchedAt;

  const DestinationWeather({
    required this.temperature,
    required this.weatherCode,
    this.relativeHumidity = 70,
    required this.fetchedAt,
  });

  bool get isExpired {
    return DateTime.now().difference(fetchedAt).inMinutes >= 60;
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0:
        return 'Trời quang, nắng ráo';
      case 1:
        return 'Nắng đẹp, ít mây';
      case 2:
        return 'Mây rải rác, mát mẻ';
      case 3:
        return 'Trời nhiều mây';
      case 45:
      case 48:
        return 'Có sương mù';
      case 51:
      case 53:
      case 55:
        return 'Mưa phùn nhẹ';
      case 61:
      case 63:
      case 65:
        return 'Có mưa rào';
      case 71:
      case 73:
      case 75:
        return 'Tuyết nhẹ / lạnh sâu';
      case 80:
      case 81:
      case 82:
        return 'Mưa rào từng đợt';
      case 95:
      case 96:
      case 99:
        return 'Có dông sét';
      default:
        return 'Khí hậu ổn định';
    }
  }

  IconData get weatherIcon {
    switch (weatherCode) {
      case 0:
      case 1:
        return Icons.wb_sunny_rounded;
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.blur_on_rounded;
      case 51:
      case 53:
      case 55:
        return Icons.grain_rounded;
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  Color get weatherColor {
    switch (weatherCode) {
      case 0:
      case 1:
        return Colors.amber.shade700;
      case 2:
      case 3:
        return Colors.blueGrey;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return const Color(0xFF0284C7);
      case 95:
      case 96:
      case 99:
        return Colors.deepPurple;
      default:
        return Colors.amber.shade700;
    }
  }

  factory DestinationWeather.fromOpenMeteoJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    return DestinationWeather(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 26.0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      relativeHumidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 70,
      fetchedAt: DateTime.now(),
    );
  }

  factory DestinationWeather.fallback(double defaultTemp) {
    return DestinationWeather(
      temperature: defaultTemp,
      weatherCode: 0,
      relativeHumidity: 70,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'weather_code': weatherCode,
      'relative_humidity': relativeHumidity,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }

  factory DestinationWeather.fromJson(Map<String, dynamic> json) {
    return DestinationWeather(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 26.0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      relativeHumidity: (json['relative_humidity'] as num?)?.toInt() ?? 70,
      fetchedAt: json['fetched_at'] != null
          ? DateTime.tryParse(json['fetched_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
