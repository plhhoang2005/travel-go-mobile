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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Task R3: Password Recovery Cold Start Isolation', () {
    late SharedPreferences prefs;
    late RecoveryIntentStore store;
    late PasswordRecoveryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = RecoveryIntentStore(prefs, projectNamespace: 'cold_recovery');
      service = PasswordRecoveryService();
    });

    test('cold start with ready marker restores recovery mode without establishing normal account', () async {
      final initialIntent = PendingRecovery(
        intentId: 'cold-intent-1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-cold-1',
      );
      await store.write(initialIntent);

      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/user') && request.method == 'GET') {
            return http.Response(
              jsonEncode({'id': 'usr-cold-1', 'email': 'cold1@travelgo.vn'}),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );

      final sessionJson = jsonEncode({
        'access_token': 'cold-token-1',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'cold-refresh-1',
        'user': {
          'id': 'usr-cold-1',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'cold1@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);

      final auth = AuthProvider(
        client: client,
        initialRecoveryIntentId: initialIntent.intentId,
        recoveryBootstrapBlocked: false,
      );

      final provider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: auth,
        clientProvider: () => client,
      );

      await provider.initializeFromStore();

      expect(auth.isRecovering, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(provider.isReady, isTrue);
    });

    test('cold start with mismatched session UID cancels recovery', () async {
      final initialIntent = PendingRecovery(
        intentId: 'cold-intent-mismatch',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-expected-owner',
      );
      await store.write(initialIntent);

      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );

      final wrongSessionJson = jsonEncode({
        'access_token': 'wrong-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'wrong-refresh',
        'user': {
          'id': 'usr-wrong-attacker',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'attacker@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(wrongSessionJson);

      final auth = AuthProvider(client: client);
      final provider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: auth,
        clientProvider: () => client,
      );

      await provider.initializeFromStore();

      expect(provider.isReady, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(await store.read(), isNull);
    });

    test('cold start with expired marker clears marker and leaves app in normal idle state', () async {
      final expiredIntent = PendingRecovery(
        intentId: 'expired-intent-99',
        requestedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 65)),
        phase: RecoveryPhase.sent,
      );

      // Write expired marker
      await prefs.setString(
        store.storageKey,
        jsonEncode(expiredIntent.toJson()),
      );

      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );

      final auth = AuthProvider(client: client);
      final provider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: auth,
        clientProvider: () => client,
      );

      await provider.initializeFromStore();
      expect(provider.state, RecoveryState.idle);
      expect(await store.read(), isNull);
      expect(auth.isRecovering, isFalse);
    });
  });
}
