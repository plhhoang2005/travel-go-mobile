import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks local daily query counts for the AI Chatbot per device.
class LocalAiQuotaService {
  static const dateKey = 'travelgo_local_ai_quota_date_v1';
  static const countKey = 'travelgo_local_ai_quota_count_v1';
  static const unlimitedQuota = 999999;

  final SharedPreferences? prefs;

  LocalAiQuotaService({this.prefs});

  Future<SharedPreferences> _preferences() async =>
      prefs ?? await SharedPreferences.getInstance();

  String _todayString() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Returns the number of queries made by the user today.
  Future<int> getUsedCountToday() async {
    final preferences = await _preferences();
    final savedDate = preferences.getString(dateKey);
    final today = _todayString();
    if (savedDate != today) {
      return 0;
    }
    return preferences.getInt(countKey) ?? 0;
  }

  /// Returns the remaining quota for today.
  /// Admin accounts always receive [unlimitedQuota].
  Future<int> getRemainingQuota({
    required int dailyQuota,
    required bool isAdmin,
  }) async {
    if (isAdmin) {
      return unlimitedQuota;
    }
    final used = await getUsedCountToday();
    return max(0, dailyQuota - used);
  }

  /// Checks if the user is allowed to send a query today.
  Future<bool> canSend({
    required int dailyQuota,
    required bool isAdmin,
  }) async {
    if (isAdmin) return true;
    final used = await getUsedCountToday();
    return used < dailyQuota;
  }

  /// Increments today's usage count and returns the updated count.
  /// Admin usage is not tracked or counted towards limits.
  Future<int> recordUsage({required bool isAdmin}) async {
    if (isAdmin) {
      return await getUsedCountToday();
    }
    final preferences = await _preferences();
    final today = _todayString();
    final savedDate = preferences.getString(dateKey);

    int newCount;
    if (savedDate != today) {
      newCount = 1;
      await preferences.setString(dateKey, today);
      await preferences.setInt(countKey, newCount);
    } else {
      final current = preferences.getInt(countKey) ?? 0;
      newCount = current + 1;
      await preferences.setInt(countKey, newCount);
    }
    return newCount;
  }

  /// Resets today's quota to 0.
  Future<void> resetTodayQuota() async {
    final preferences = await _preferences();
    final today = _todayString();
    await preferences.setString(dateKey, today);
    await preferences.setInt(countKey, 0);
  }
}
