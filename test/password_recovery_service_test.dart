// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/password_recovery_state.dart';
import 'package:travelgo_mobile/features/auth/services/password_recovery_service.dart';
import 'package:travelgo_mobile/features/auth/services/recovery_intent_store.dart';

class MockAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};
  @override
  Future<String?> getItem({required String key}) async => _storage[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _storage[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _storage.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Task R3: RecoveryIntentStore', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('writes and reads pending recovery intent with TTL check', () async {
      var fakeNow = DateTime.utc(2026, 10, 24, 10, 0, 0);
      final store = RecoveryIntentStore(
        prefs,
        projectNamespace: 'test_project',
        clock: () => fakeNow,
      );

      expect(await store.read(), isNull);

      final intent = PendingRecovery(
        intentId: 'intent-uuid-1',
        requestedAt: fakeNow,
        phase: RecoveryPhase.sent,
      );

      await store.write(intent);

      final read1 = await store.read();
      expect(read1, isNotNull);
      expect(read1!.intentId, 'intent-uuid-1');
      expect(read1.phase, RecoveryPhase.sent);

      // Advance clock by 59 minutes (within TTL)
      fakeNow = fakeNow.add(const Duration(minutes: 59));
      final read2 = await store.read();
      expect(read2, isNotNull);

      // Advance clock past 60 minutes (expired)
      fakeNow = fakeNow.add(const Duration(minutes: 2));
      final readExpired = await store.read();
      expect(readExpired, isNull);
      // Key should be cleared
      expect(prefs.containsKey(store.storageKey), isFalse);
    });

    test('clears corrupt marker gracefully and returns null', () async {
      final store = RecoveryIntentStore(prefs, projectNamespace: 'test_project');
      await prefs.setString(store.storageKey, 'INVALID_JSON_CORRUPTED');

      expect(await store.read(), isNull);
      expect(prefs.containsKey(store.storageKey), isFalse);
    });
  });

  group('Task R3: PasswordRecoveryService', () {
    test('requestEmail validates format and calls resetPasswordForEmail', () async {
      final service = PasswordRecoveryService();
      String? sentPath;
      Map<String, dynamic>? sentBody;

      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MockAsyncStorage(),
        ),
        httpClient: MockClient((request) async {
          sentPath = request.url.path;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );

      expect(() => service.requestEmail(client, 'invalid-email'), throwsFormatException);

      await service.requestEmail(client, 'qa@example.com');
      expect(sentPath, contains('/recover'));
      expect(sentBody?['email'], 'qa@example.com');
    });

    test('exchange validates code and returns response with session', () async {
      final service = PasswordRecoveryService();
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MockAsyncStorage(),
        ),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.contains('/recover')) {
            return http.Response('{}', 200);
          }
          if (path.contains('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'mock-session-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'mock-refresh',
                'user': {
                  'id': 'u-recovered-123',
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'qa@example.com',
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/user')) {
            return http.Response(
              jsonEncode({
                'id': 'u-recovered-123',
                'email': 'qa@example.com',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );

      expect(() => service.exchange(client, ''), throwsFormatException);

      // Generate code verifier via requestEmail
      await service.requestEmail(client, 'qa@example.com');

      final res = await service.exchange(client, 'code123');
      expect(res.session, isNotNull);
      expect(res.session.user.id, 'u-recovered-123');

      // Now updateUser has an active session
      final updateRes = await service.updatePassword(client, 'Secret12345');
      expect(updateRes.user, isNotNull);
    });

    test('updatePassword validates minimum 8 chars', () async {
      final service = PasswordRecoveryService();
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MockAsyncStorage(),
        ),
      );

      expect(() => service.updatePassword(client, 'short'), throwsFormatException);
    });
  });
}
