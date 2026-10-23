import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/password_recovery_state.dart';

class RecoveryIntentStore {
  final SharedPreferences? _prefs;
  final String _storageKey;
  final DateTime Function() _clock;

  RecoveryIntentStore(
    SharedPreferences? preferences, {
    required String projectNamespace,
    DateTime Function()? clock,
  })  : _prefs = preferences,
        _storageKey = 'supabase_recovery_intent.v1.$projectNamespace',
        _clock = clock ?? (() => DateTime.now().toUtc());

  String get storageKey => _storageKey;

  Future<PendingRecovery?> read() async {
    final prefs = _prefs;
    if (prefs == null) return null;

    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final item = PendingRecovery.fromJson(decoded);
      if (item.isExpired(_clock())) {
        await clear();
        return null;
      }
      return item;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> write(PendingRecovery value) async {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('SharedPreferences storage is unavailable.');
    }
    final encoded = jsonEncode(value.toJson());
    final success = await prefs.setString(_storageKey, encoded);
    if (!success) {
      throw StateError('Failed to persist recovery intent to storage.');
    }
  }

  Future<void> clear() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_storageKey);
    }
  }
}
