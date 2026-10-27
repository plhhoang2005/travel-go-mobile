// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/password_recovery_state.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/providers/password_recovery_provider.dart';
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

  group('Task R3: End-to-End Password Recovery Flow', () {
    late SharedPreferences prefs;
    late RecoveryIntentStore store;
    late PasswordRecoveryService service;
    late SupabaseClient client;
    late AuthProvider auth;
    late PasswordRecoveryProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = RecoveryIntentStore(prefs, projectNamespace: 'test_recovery');
      service = PasswordRecoveryService();

      client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
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
                'access_token': 'recovery-access-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'recovery-refresh-token',
                'user': {
                  'id': 'usr-recovery-99',
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'recovery@travelgo.vn',
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
                'id': 'usr-recovery-99',
                'email': 'recovery@travelgo.vn',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/logout')) {
            return http.Response('{}', 204);
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      auth = AuthProvider(client: client);
      provider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: auth,
        clientProvider: () => client,
      );
    });

    test('complete recovery flow: request email -> handle callback -> update password -> cleanup', () async {
      expect(provider.state, RecoveryState.idle);

      // 1. Request recovery email
      await provider.requestEmail('recovery@travelgo.vn');
      expect(provider.state, RecoveryState.emailRequested);
      expect(provider.successMessage, isNotNull);
      expect(auth.isRecovering, isTrue);

      final savedIntent = await store.read();
      expect(savedIntent, isNotNull);
      expect(savedIntent!.phase, RecoveryPhase.sent);

      // 2. Handle callback deep link
      final callbackUri = Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=mock_pkce_auth_code_123',
      );
      final handled = await provider.handleCallback(callbackUri);
      expect(handled, isTrue);
      expect(provider.state, RecoveryState.ready);
      expect(provider.isReady, isTrue);

      final readyIntent = await store.read();
      expect(readyIntent!.phase, RecoveryPhase.ready);
      expect(readyIntent.verifiedUserId, 'usr-recovery-99');

      // 3. Validation on new password
      expect(await provider.submitNewPassword('short', 'short'), isFalse);
      expect(provider.errorMessage, contains('8 ký tự'));

      expect(await provider.submitNewPassword('Password123', 'Mismatch999'), isFalse);
      expect(provider.errorMessage, contains('không khớp'));

      // 4. Submit valid new password
      final updated = await provider.submitNewPassword('NewSecret2026!', 'NewSecret2026!');
      expect(updated, isTrue);
      expect(provider.state, RecoveryState.completed);
      expect(provider.successMessage, contains('thành công'));

      // Marker cleared and auth recovery finished
      expect(await store.read(), isNull);
      expect(auth.isRecovering, isFalse);
    });

    test('cancel aborts recovery and clears store marker', () async {
      await provider.requestEmail('recovery@travelgo.vn');
      expect(provider.state, RecoveryState.emailRequested);
      expect(await store.read(), isNotNull);

      await provider.cancel();
      expect(provider.state, RecoveryState.idle);
      expect(await store.read(), isNull);
      expect(auth.isRecovering, isFalse);
    });
  });
}
