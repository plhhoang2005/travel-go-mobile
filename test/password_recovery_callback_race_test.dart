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

class BlockingStore extends RecoveryIntentStore {
  Completer<void>? readBlocker;
  BlockingStore(super.prefs, {super.projectNamespace = 'test_race'});

  @override
  Future<PendingRecovery?> read() async {
    if (readBlocker != null) {
      await readBlocker!.future;
    }
    return super.read();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task A2: Callback Idempotency & Bootstrap Ordering', () {
    late SharedPreferences prefs;
    late BlockingStore store;
    late PasswordRecoveryService service;
    late MockAsyncStorage asyncStorage;
    late SupabaseClient client;
    late AuthProvider auth;
    late PasswordRecoveryProvider provider;
    int exchangeCalls = 0;

    Completer<void>? exchangeEntered;
    Completer<void>? exchangeRelease;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = BlockingStore(prefs);
      service = PasswordRecoveryService();
      asyncStorage = MockAsyncStorage();
      exchangeCalls = 0;
      exchangeEntered = null;
      exchangeRelease = null;

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
            if (query['grant_type'] == 'pkce' ||
                body.contains('code=') ||
                body.contains('auth_code')) {
              exchangeCalls++;
              if (exchangeEntered != null && !exchangeEntered!.isCompleted) {
                exchangeEntered!.complete();
              }
              if (exchangeRelease != null) {
                await exchangeRelease!.future;
              }
              return http.Response(
                jsonEncode({
                  'access_token': 'recovery-token-race',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'refresh_token': 'recovery-refresh-race',
                  'user': {
                    'id': 'usr-recovery-race',
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': 'recovery_race@travelgo.vn',
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

    test('initial_and_stream_callback_exchange_once', () async {
      final intent = PendingRecovery(
        intentId: 'intent-race-1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      exchangeEntered = Completer<void>();
      exchangeRelease = Completer<void>();

      final uri = Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=code-race-1',
      );

      final f1 = provider.handleCallback(uri);
      final f2 = provider.handleCallback(uri);

      await exchangeEntered!.future;
      exchangeRelease!.complete();

      final r1 = await f1;
      final r2 = await f2;

      expect(exchangeCalls, 1);
      expect(r1, isTrue);
      expect(r2, isTrue);
      expect(provider.isReady, isTrue);
      expect(provider.state, RecoveryState.ready);
    });

    test('duplicate_after_ready_preserves_ready', () async {
      final intent = PendingRecovery(
        intentId: 'intent-race-2',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final uri = Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=code-race-2',
      );

      final firstSuccess = await provider.handleCallback(uri);
      expect(firstSuccess, isTrue);
      expect(exchangeCalls, 1);
      expect(provider.isReady, isTrue);

      // Replay same callback after ready
      final duplicateSuccess = await provider.handleCallback(uri);
      expect(duplicateSuccess, isTrue);
      expect(exchangeCalls, 1);
      expect(provider.isReady, isTrue);
      expect(provider.errorMessage, isNull);
      final stored = await store.read();
      expect(stored?.phase, RecoveryPhase.ready);
    });

    test('callback_waits_for_slow_bootstrap', () async {
      final intent = PendingRecovery(
        intentId: 'intent-race-3',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      store.readBlocker = Completer<void>();
      final initFuture = provider.initializeFromStore();

      final uri = Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=code-race-3',
      );
      final callbackFuture = provider.handleCallback(uri);

      // Release store read so bootstrap finishes
      store.readBlocker!.complete();
      await initFuture;
      final handled = await callbackFuture;

      expect(handled, isTrue);
      expect(exchangeCalls, 1);
      expect(provider.isReady, isTrue);
      expect(provider.state, RecoveryState.ready);
    });

    test('different_or_replayed_code_never_reexchanges_ready_intent', () async {
      final intent = PendingRecovery(
        intentId: 'intent-race-4',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final uri = Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=code-race-4',
      );
      expect(await provider.handleCallback(uri), isTrue);
      expect(exchangeCalls, 1);
      expect(provider.isReady, isTrue);

      // Different code sent while ready
      final differentUri = Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=different-code-99',
      );
      final handledDiff = await provider.handleCallback(differentUri);
      expect(handledDiff, isFalse);
      expect(exchangeCalls, 1); // No new exchange
      expect(provider.isReady, isTrue); // Preserves ready
      expect(provider.state, RecoveryState.ready);
    });

    test('invalid_recovery_uri_has_no_sdk_effect', () async {
      final intent = PendingRecovery(
        intentId: 'intent-race-5',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final invalidUris = [
        Uri.parse('https://travelgo.vn/login-callback?flow=recovery&code=c1'),
        Uri.parse('io.supabase.travelgo://other-host?flow=recovery&code=c1'),
        Uri.parse('io.supabase.travelgo://login-callback/somepath?flow=recovery&code=c1'),
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=c1#fragment'),
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&flow=recovery2&code=c1'),
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=c1&code=c2'),
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=c1&access_token=token123'),
      ];

      for (final badUri in invalidUris) {
        final res = await provider.handleCallback(badUri);
        expect(res, isFalse, reason: 'URI $badUri should be rejected');
      }
      expect(exchangeCalls, 0);
    });
  });
}
