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
  final Map<RecoveryPhase, Completer<void>> gates = {};
  final Map<RecoveryPhase, int> entered = {};

  BlockingStore(super.prefs, {super.projectNamespace = 'test_race'});

  @override
  Future<PendingRecovery?> read() async {
    if (readBlocker != null) {
      await readBlocker!.future;
    }
    return super.read();
  }

  @override
  Future<void> write(PendingRecovery next) async {
    entered.update(next.phase, (n) => n + 1, ifAbsent: () => 1);
    final gate = gates[next.phase];
    if (gate != null) await gate.future;
    await super.write(next);
  }
}

Future<void> spinUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  if (!condition()) throw StateError('Condition not met within spin limit');
}

String syntheticJwt(String id) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic';
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
          if (path.contains('/recover')) {
            return http.Response('{}', 200);
          }
          if (path.endsWith('/user') && request.method == 'GET') {
            final token = request.headers['authorization']!.split(' ').last;
            final claims = jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token.split('.')[1])),
              ),
            ) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': claims['sub'],
                'email': 'fixture@example.invalid',
              }),
              200,
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

    test('F01_F02_stale_mutation_A_never_overwrites_or_clears_intent_B', () async {
      final sessionJson = jsonEncode({
        'access_token': syntheticJwt('usr-recovery-A'),
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
      });
      await client.auth.recoverSession(sessionJson);

      final intentA = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      );
      await store.write(intentA);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      final intentB = PendingRecovery(
        intentId: 'intent-B',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await auth.beginRecovery('intent-B');
      await store.write(intentB);

      await provider.retryCleanup();

      final current = await store.read();
      expect(current?.intentId, 'intent-B', reason: 'Stale A cleanup must not clear marker B');
      expect(auth.isCurrentRecoveryIntent('intent-B'), isTrue);
    });

    test('X1_pending_ready_write_A_cannot_overwrite_newly_requested_B_marker', () async {
      final intentA = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intentA);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final gate = store.gates[RecoveryPhase.ready] = Completer<void>();
      final callbackA = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-A'),
      );

      await spinUntil(() => (store.entered[RecoveryPhase.ready] ?? 0) == 1);
      final cancel = provider.cancel();
      final next = provider.requestEmail('account-B@travelgo.vn');
      await Future<void>.delayed(Duration.zero);
      expect(store.entered[RecoveryPhase.requesting] ?? 0, 0,
          reason: 'successor commit must wait for old write and cleanup');
      gate.complete();
      await Future.wait([callbackA, cancel, next]);
      final intentB = provider.currentIntent!;
      expect(intentB.intentId, isNot('intent-A'));
      expect((await store.read())?.intentId, intentB.intentId);
      expect(auth.isCurrentRecoveryIntent(intentB.intentId), isTrue);
    });

    test('R2_repair_write_from_A_cannot_revive_B_after_B_was_cancelled', () async {
      final intentA = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intentA);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final aReady = store.gates[RecoveryPhase.ready] = Completer<void>();
      final callbackA = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-A'),
      );
      await spinUntil(() => (store.entered[RecoveryPhase.ready] ?? 0) == 1);
      final cancelA = provider.cancel();
      final requestB = provider.requestEmail('account-B@travelgo.vn');
      final cancelB = provider.cancel();
      aReady.complete();
      await Future.wait([callbackA, cancelA, requestB, cancelB]);
      expect(await store.read(), isNull,
          reason: 'cancel B drains queued writes; no repair can revive it');
      expect(auth.isRecovering, isFalse);
      expect(provider.currentIntent, isNull);
    });

    test('R3_pending_B_repair_cannot_erase_newer_C_after_cancel_B', () async {
      final intentA = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intentA);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final aReady = store.gates[RecoveryPhase.ready] = Completer<void>();
      final callbackA = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-A'),
      );
      await spinUntil(() => (store.entered[RecoveryPhase.ready] ?? 0) == 1);
      final cancelA = provider.cancel();
      final requestB = provider.requestEmail('account-B@travelgo.vn');
      final cancelB = provider.cancel();
      final requestC = provider.requestEmail('account-C@travelgo.vn');
      aReady.complete();
      await Future.wait([callbackA, cancelA, requestB, cancelB, requestC]);
      final cId = provider.currentIntent!.intentId;
      expect((await store.read())?.intentId, cId,
          reason: 'queued stale mutations cannot erase successor C');
      expect(auth.isCurrentRecoveryIntent(cId), isTrue);
    });

    test('slot_callback_A_finally_does_not_reset_in_flight_slot_of_B', () async {
      final intentA = PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intentA);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      exchangeEntered = Completer<void>();
      exchangeRelease = Completer<void>();

      final callbackFutureA = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-A'),
      );

      await exchangeEntered!.future;
      final cancelA = provider.cancel();

      final intentB = PendingRecovery(
        intentId: 'intent-B',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intentB);
      await auth.beginRecovery('intent-B');

      // Release callback A while intent B is active
      exchangeRelease!.complete();
      await Future.wait([callbackFutureA, cancelA]);

      expect(auth.isCurrentRecoveryIntent('intent-B'), isTrue);
    });
  });
}
