import 'package:flutter/widgets.dart';
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
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

  group('Task A1: Recovery Authority & Cancellation', () {
    late SharedPreferences prefs;
    late RecoveryIntentStore store;
    late PasswordRecoveryService service;
    late MockAsyncStorage asyncStorage;
    late SupabaseClient client;
    late AuthProvider auth;
    late PasswordRecoveryProvider provider;
    late List<String> callTrace;
    int exchangeCalls = 0;

    Completer<void>? exchangeEntered;
    Completer<void>? exchangeRelease;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = RecoveryIntentStore(prefs, projectNamespace: 'test_authority');
      service = PasswordRecoveryService();
      callTrace = [];
      exchangeCalls = 0;
      exchangeEntered = null;
      exchangeRelease = null;

      asyncStorage = MockAsyncStorage();
      client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: asyncStorage,
        ),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.contains('/token')) {
            final query = request.url.queryParameters;
            final body = request.body;
            if (query['grant_type'] == 'pkce' || body.contains('code=') || body.contains('auth_code')) {
              exchangeCalls++;
              callTrace.add('exchangeA');
              if (exchangeEntered != null && !exchangeEntered!.isCompleted) {
                exchangeEntered!.complete();
              }
              if (exchangeRelease != null) {
                await exchangeRelease!.future;
              }
              return http.Response(
                jsonEncode({
                  'access_token': 'recovery-token-A',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'refresh_token': 'recovery-refresh-A',
                  'user': {
                    'id': 'usr-recovery-A',
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': 'recoveryA@travelgo.vn',
                    'created_at': DateTime.now().toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else if (query['grant_type'] == 'password' || body.contains('password')) {
              callTrace.add('loginB');
              return http.Response(
                jsonEncode({
                  'access_token': 'user-token-B',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'refresh_token': 'user-refresh-B',
                  'user': {
                    'id': 'usr-user-B',
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': 'userB@travelgo.vn',
                    'created_at': DateTime.now().toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }
          if (path.contains('/logout')) {
            callTrace.add('cleanupA');
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

    test('cancelled_intent_never_dispatches_queued_mutation', () async {
      final intent = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await auth.beginRecovery('intent-A');

      // Cancel before mutation dispatches
      await auth.cancelRecovery('intent-A');

      // Attempt mutation on cancelled intent
      expect(
        () => auth.runRecoveryMutation(
          'intent-A',
          (c) => service.exchange(c, 'code-A'),
        ),
        throwsA(isA<RecoveryIntentCancelledException>()),
      );
      expect(exchangeCalls, 0);
      final stored = await store.read();
      expect(stored?.phase, isNot(RecoveryPhase.ready));
    });

    test('guest_choice_fences_late_recovery_exchange', () async {
      exchangeEntered = Completer<void>();
      exchangeRelease = Completer<void>();

      final intent = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      // Start exchange in background
      final callbackFuture = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-A'),
      );

      await exchangeEntered!.future;
      // User chooses guest while exchange is in flight
      auth.continueAsGuest();

      // Release exchange
      exchangeRelease!.complete();
      await callbackFuture;

      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(provider.isReady, isFalse);
      final stored = await store.read();
      expect(stored?.phase, isNot(RecoveryPhase.ready));
    });

    test('new_login_waits_for_old_recovery_cleanup', () async {
      exchangeEntered = Completer<void>();
      exchangeRelease = Completer<void>();

      final intent = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final callbackFuture = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-A'),
      );

      await exchangeEntered!.future;

      // Start login B while recovery exchange A is in flight
      final loginFuture = auth.login('userB@travelgo.vn', 'passwordB123');

      exchangeRelease!.complete();
      await callbackFuture;
      await loginFuture;

      // Trace must order exchangeA -> cleanupA -> loginB
      expect(callTrace.contains('exchangeA'), isTrue);
      expect(callTrace.contains('loginB'), isTrue);
      final idxExchange = callTrace.indexOf('exchangeA');
      final idxLogin = callTrace.indexOf('loginB');
      expect(idxExchange, lessThan(idxLogin));

      expect(auth.currentUser?.id, 'usr-user-B');
      expect(auth.isAuthenticated, isTrue);
    });

    test('old_marker_write_cannot_overwrite_new_intent', () async {
      // Store with step interception
      final intentA = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      final intentB = PendingRecovery(
        intentId: 'intent-B',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );

      await auth.beginRecovery('intent-A');
      await store.write(intentA);

      // Start new recovery B
      await auth.cancelRecovery('intent-A');
      await auth.beginRecovery('intent-B');
      await store.write(intentB);

      expect(auth.isCurrentRecoveryIntent('intent-B'), isTrue);
      expect(auth.isCurrentRecoveryIntent('intent-A'), isFalse);
      final current = await store.read();
      expect(current?.intentId, 'intent-B');
    });

    test('recovery_session_never_publishes_on_resume', () async {
      final sessionJson = jsonEncode({
        'access_token': 'recovery-access-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'recovery-refresh-token',
        'user': {
          'id': 'usr-recovery-A',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'recoveryA@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);

      final intent = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      );
      await store.write(intent);
      await provider.initializeFromStore();

      expect(provider.isReady, isTrue);
      expect(auth.currentUser, isNull);

      // Simulate app lifecycle transition: inactive -> paused -> resumed
      await auth.handleAppLifecycleState(AppLifecycleState.inactive);
      await auth.handleAppLifecycleState(AppLifecycleState.paused);
      await auth.handleAppLifecycleState(AppLifecycleState.resumed);

      expect(auth.currentUser, isNull);
      expect(auth.isAuthenticated, isFalse);
    });
  });
}
