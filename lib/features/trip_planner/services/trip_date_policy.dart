import 'package:flutter/foundation.dart';

@immutable
class TripDateRange {
  final String startDate;
  final String endDate;
  final int numDays;

  const TripDateRange({
    required this.startDate,
    required this.endDate,
    required this.numDays,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripDateRange &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          numDays == other.numDays;

  @override
  int get hashCode => Object.hash(startDate, endDate, numDays);

  @override
  String toString() =>
      'TripDateRange(startDate: $startDate, endDate: $endDate, numDays: $numDays)';
}

class TripDatePolicy {
  static final RegExp _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Validates [startDate] and [endDate] calendar dates.
  /// Returns null if both are null.
  /// Throws [FormatException] if only one is null, invalid syntax, non-existent calendar date,
  /// endDate before startDate, days outside [1, maxDays], or [expectedDays] does not match.
  static TripDateRange? validate(
    String? startDate,
    String? endDate, {
    int? expectedDays,
    int maxDays = 366,
  }) {
    if (startDate == null && endDate == null) {
      return null;
    }
    if (startDate == null || endDate == null) {
      throw const FormatException(
        'Cả ngày đi và ngày về phải được cung cấp cùng lúc',
      );
    }

    final startDt = parseCalendarDate(startDate);
    final endDt = parseCalendarDate(endDate);

    if (endDt.isBefore(startDt)) {
      throw FormatException(
        'Ngày về ($endDate) không thể trước ngày đi ($startDate)',
      );
    }

    final days = endDt.difference(startDt).inDays + 1;
    if (days < 1) {
      throw const FormatException('Số ngày phải lớn hơn hoặc bằng 1');
    }
    if (days > maxDays) {
      throw FormatException(
        'Khoảng thời gian ($days ngày) vượt quá giới hạn cho phép ($maxDays ngày)',
      );
    }
    if (expectedDays != null && expectedDays != days) {
      throw FormatException(
        'Số ngày được chỉ định ($expectedDays) không khớp với khoảng ngày ($days)',
      );
    }

    return TripDateRange(
      startDate: startDate,
      endDate: endDate,
      numDays: days,
    );
  }

  /// Parses and strictly verifies exact calendar date existence (e.g. rejects 2026-02-30).
  static DateTime parseCalendarDate(String dateStr) {
    if (!_dateRegex.hasMatch(dateStr)) {
      throw FormatException(
        'Định dạng ngày không hợp lệ: $dateStr (yêu cầu YYYY-MM-DD)',
      );
    }
    final parts = dateStr.split('-').map(int.parse).toList();
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];

    final dt = DateTime.utc(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) {
      throw FormatException('Ngày không tồn tại trên lịch: $dateStr');
    }
    return dt;
  }

  /// Formats UTC date to YYYY-MM-DD
  static String formatCalendarDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Calculates endDate given startDate and numDays (inclusive).
  static String calculateEndDate(String startDate, int numDays) {
    if (numDays < 1) {
      throw ArgumentError.value(numDays, 'numDays', 'Số ngày phải >= 1');
    }
    final startDt = parseCalendarDate(startDate);
    final endDt = startDt.add(Duration(days: numDays - 1));
    return formatCalendarDate(endDt);
  }

  /// Calculates startDate given endDate and numDays (inclusive).
  static String calculateStartDate(String endDate, int numDays) {
    if (numDays < 1) {
      throw ArgumentError.value(numDays, 'numDays', 'Số ngày phải >= 1');
    }
    final endDt = parseCalendarDate(endDate);
    final startDt = endDt.subtract(Duration(days: numDays - 1));
    return formatCalendarDate(startDt);
  }
}
