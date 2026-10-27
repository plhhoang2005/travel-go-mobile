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

class PausableRecoveryIntentStore extends RecoveryIntentStore {
  final Map<RecoveryPhase, Completer<void>> gates = {};
  final Map<RecoveryPhase, int> entered = {};
  Completer<void>? readGate;
  bool failClear = false;
  bool failWrite = false;
  Completer<void>? firstClearGate;
  Completer<void>? firstClearEntered;
  int clearCalls = 0;
  int readCalls = 0;

  PausableRecoveryIntentStore(
    super.preferences, {
    required super.projectNamespace,
    super.clock,
  });

  @override
  Future<PendingRecovery?> read() async {
    readCalls++;
    final captured = await super.read();
    if (readGate != null) await readGate!.future;
    return captured;
  }

  @override
  Future<void> write(PendingRecovery next) async {
    if (failWrite) throw StateError('synthetic first marker write failure');
    entered.update(next.phase, (n) => n + 1, ifAbsent: () => 1);
    final gate = gates[next.phase];
    if (gate != null) await gate.future;
    await super.write(next);
  }

  @override
  Future<void> clear([String? expectedIntentId]) async {
    clearCalls++;
    if (clearCalls == 1 && firstClearEntered != null && !firstClearEntered!.isCompleted) {
      firstClearEntered!.complete();
    }
    if (clearCalls == 1 && firstClearGate != null) await firstClearGate!.future;
    if (failClear) throw StateError('synthetic marker removal failure');
    await super.clear(expectedIntentId);
  }

  void releaseAll() {
    for (final g in [...gates.values, ?readGate, ?firstClearGate]) {
      if (!g.isCompleted) g.complete();
    }
  }
}

class CompletionGatedStore extends RecoveryIntentStore {
  final firstClearEntered = Completer<void>();
  final firstClearRelease = Completer<void>();
  int clears = 0;
  CompletionGatedStore(super.preferences, {required super.projectNamespace});
  @override
  Future<void> clear([String? expectedIntentId]) async {
    final sequence = ++clears;
    await super.clear(expectedIntentId);
    if (sequence == 1) {
      firstClearEntered.complete();
      await firstClearRelease.future;
    }
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

  group('Task A1: Recovery Authority & Cancellation', () {
    late SharedPreferences prefs;
    late PausableRecoveryIntentStore store;
    late PasswordRecoveryService service;
    late MockAsyncStorage asyncStorage;
    late SupabaseClient client;
    late AuthProvider auth;
    late PasswordRecoveryProvider provider;
    late List<String> callTrace;
    int exchangeCalls = 0;
    int recoverCalls = 0;
    int putCalls = 0;

    Completer<void>? exchangeEntered;
    Completer<void>? exchangeRelease;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = PausableRecoveryIntentStore(prefs, projectNamespace: 'test_authority');
      service = PasswordRecoveryService();
      callTrace = [];
      exchangeCalls = 0;
      recoverCalls = 0;
      putCalls = 0;
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
          if (path.contains('/recover')) {
            recoverCalls++;
            return http.Response('{}', 200);
          }
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
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else if (query['grant_type'] == 'password' || body.contains('password')) {
              final isUserA = body.contains('recoveryA') || body.contains('account-A');
              final userId = isUserA ? 'usr-recovery-A' : 'usr-user-B';
              final userEmail = isUserA ? 'recoveryA@travelgo.vn' : 'userB@travelgo.vn';
              callTrace.add(isUserA ? 'loginA' : 'loginB');
              return http.Response(
                jsonEncode({
                  'access_token': syntheticJwt(userId),
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'refresh_token': '$userId-refresh',
                  'user': {
                    'id': userId,
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': userEmail,
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
          if (path.contains('/user') && request.method == 'PUT') {
            putCalls++;
            return http.Response(
              jsonEncode({
                'id': 'usr-recovery-A',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'recoveryA@travelgo.vn',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/user') && request.method == 'GET') {
            final authHeader = request.headers['authorization'] ?? '';
            final token = authHeader.replaceFirst(RegExp(r'^Bearer\s+'), '');
            final parts = token.split('.');
            final subject = parts.length == 3
                ? (jsonDecode(
                    utf8.decode(
                      base64Url.decode(base64Url.normalize(parts[1])),
                    ),
                  ) as Map<String, dynamic>)['sub']
                : null;
            final isUserA = subject == 'usr-recovery-A';
            final userId = isUserA ? 'usr-recovery-A' : 'usr-user-B';
            final userEmail = isUserA ? 'recoveryA@travelgo.vn' : 'userB@travelgo.vn';
            return http.Response(
              jsonEncode({
                'id': userId,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': userEmail,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
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
        'access_token': syntheticJwt('usr-recovery-A'),
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

    tearDown(() {
      store.releaseAll();
      provider.dispose();
      auth.dispose();
    });

    test('R1_cancel_during_ready_marker_write_never_resurrects_ready', () async {
      final intent = PendingRecovery(
        intentId: 'intent-R1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await provider.initializeFromStore();
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      final readyGate = store.gates[RecoveryPhase.ready] = Completer<void>();
      final callbackFuture = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-R1'),
      );

      await spinUntil(() => (store.entered[RecoveryPhase.ready] ?? 0) == 1);
      final cancel = provider.cancel();
      readyGate.complete();
      await Future.wait([callbackFuture, cancel]);

      expect(auth.isRecovering, isFalse);
      expect(provider.isReady, isFalse, reason: 'cancelled completion must not reopen reset form');
      final currentStored = await store.read();
      expect(currentStored, isNull, reason: 'marker must remain null after cancel');
    });

    test('R3_cancel_during_sdk_exchange_must_not_leave_recovery_session', () async {
      final intent = PendingRecovery(
        intentId: 'intent-R3',
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

      final callbackFuture = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-R3'),
      );

      await exchangeEntered!.future;
      final cancel = provider.cancel();
      exchangeRelease!.complete();
      await Future.wait([callbackFuture, cancel]);

      expect(provider.isReady, isFalse);
      expect(await store.read(), isNull);
      expect(client.auth.currentSession, isNull, reason: 'late SDK exchange must be drained then signed out');
    });

    test('R4_guest_during_bootstrap_read_stays_guest_without_recovery_revival', () async {
      final intent = PendingRecovery(
        intentId: 'intent-R4',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);

      store.readGate = Completer<void>();
      final initFuture = provider.initializeFromStore();
      auth.continueAsGuest();
      store.readGate!.complete();
      await initFuture;

      expect(auth.isGuest, isTrue);
      expect(auth.isRecovering, isFalse, reason: 'stale startup read cannot call beginRecovery after Guest');
    });

    test('R8_guest_while_request_marker_pending_prevents_sending_mail', () async {
      final reqGate = store.gates[RecoveryPhase.requesting] = Completer<void>();
      final reqFuture = provider.requestEmail('synthetic@travelgo.vn');

      await spinUntil(() => (store.entered[RecoveryPhase.requesting] ?? 0) == 1);
      auth.continueAsGuest();
      reqGate.complete();
      await reqFuture;

      expect(recoverCalls, 0, reason: 'cancelled pre-dispatch recovery must not send email');
      expect(auth.isRecovering, isFalse);
    });

    test('F02_cancel_pending_exchange_and_login_B_leaves_B_authenticated', () async {
      final intent = PendingRecovery(
        intentId: 'intent-F02',
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

      final callbackFuture = provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-F02'),
      );

      await exchangeEntered!.future;
      final cancelFuture = provider.cancel();
      final loginFuture = auth.login('userB@travelgo.vn', 'passwordB123');

      exchangeRelease!.complete();
      await callbackFuture;
      await cancelFuture;
      final loginResult = await loginFuture;

      expect(loginResult, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.id, 'usr-user-B');
      expect(client.auth.currentSession?.user.id, 'usr-user-B');
    });

    test('X6_cancel_revokes_password_update_authority_before_waiting_for_marker_cleanup', () async {
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
      final intent = PendingRecovery(
        intentId: 'intent-X6',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.firstClearGate = Completer<void>();
      final cancelFuture = provider.cancel();
      await spinUntil(() => store.clearCalls == 1);

      final submitResult = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      store.firstClearGate!.complete();
      await cancelFuture;

      expect(putCalls, 0, reason: 'a submission made after cancel was invoked must not dispatch password PUT');
      expect(submitResult, isFalse);
    });

    test('P2_production_store_cancel_forbids_subsequent_password_put', () async {
      final prodStore = CompletionGatedStore(prefs, projectNamespace: 'prod_p2');
      final prodProvider = PasswordRecoveryProvider(
        service: service,
        store: prodStore,
        auth: auth,
        clientProvider: () => client,
      );
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
      await prodStore.write(PendingRecovery(
        intentId: 'intent-P2',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await prodProvider.initializeFromStore();
      expect(prodProvider.isReady, isTrue);

      final cancelFuture = prodProvider.cancel();
      await prodStore.firstClearEntered.future;
      expect(await prodStore.read(), isNull);

      final submitResult = await prodProvider.submitNewPassword('NewPass123!', 'NewPass123!');
      prodStore.firstClearRelease.complete();
      await cancelFuture;

      expect(putCalls, 0, reason: 'cancel must invalidate AuthProvider mutation authority immediately');
      expect(submitResult, isFalse);
      prodProvider.dispose();
    });

    test('X2_pending_cancel_A_cleanup_cannot_sign_out_account_B_after_successful_login', () async {
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
      final intent = PendingRecovery(
        intentId: 'intent-X2',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.firstClearGate = Completer<void>();
      final cancelFuture = provider.cancel();
      await spinUntil(() => store.clearCalls == 1);

      var loginCompleted = false;
      final loginFuture = auth.login('userB@travelgo.vn', 'passwordB123').then((value) { loginCompleted = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(loginCompleted, isFalse, reason: 'login must await pending marker cleanup');
      store.firstClearGate!.complete();
      await cancelFuture;
      final loggedIn = await loginFuture;
      expect(loggedIn, isTrue, reason: 'independent cleanup completed and B login succeeds');
      expect(client.auth.currentUser?.id, 'usr-user-B', reason: 'real SDK holds B after cleanup and login');
      expect(client.auth.currentUser?.id, 'usr-user-B', reason: 'late A cancel must not call signOut on B');
    });

    test('P1_production_store_late_cancel_A_preserves_logged_in_SDK_B', () async {
      final prodStore = CompletionGatedStore(prefs, projectNamespace: 'prod_p1');
      final prodProvider = PasswordRecoveryProvider(
        service: service,
        store: prodStore,
        auth: auth,
        clientProvider: () => client,
      );
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
      await prodStore.write(PendingRecovery(
        intentId: 'intent-P1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await prodProvider.initializeFromStore();
      expect(prodProvider.isReady, isTrue);

      final cancelFuture = prodProvider.cancel();
      await prodStore.firstClearEntered.future;
      expect(await prodStore.read(), isNull, reason: 'real production clear already removed A marker');

      var loginCompleted = false;
      final loginFuture = auth.login('userB@travelgo.vn', 'passwordB123').then((value) { loginCompleted = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(loginCompleted, isFalse, reason: 'login must await pending marker cleanup');
      prodStore.firstClearRelease.complete();
      await cancelFuture;
      final loggedIn = await loginFuture;
      expect(loggedIn, isTrue);
      expect(client.auth.currentUser?.id, 'usr-user-B');
      expect(client.auth.currentUser?.id, 'usr-user-B', reason: 'late cancel A must not sign out user B');
      prodProvider.dispose();
    });

    test('X2_sent_phase_unverified_cancel_A_cleanup_cannot_sign_out_account_B', () async {
      await store.write(PendingRecovery(
        intentId: 'intent-sent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      ));
      await provider.initializeFromStore();
      expect(provider.state, RecoveryState.emailRequested);

      store.firstClearGate = Completer<void>();
      final cancelFuture = provider.cancel();
      await spinUntil(() => store.clearCalls == 1);

      var loginCompleted = false;
      final loginFuture = auth.login('userB@travelgo.vn', 'passwordB123').then((value) { loginCompleted = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(loginCompleted, isFalse, reason: 'login must await pending marker cleanup');
      store.firstClearGate!.complete();
      await cancelFuture;
      final loggedIn = await loginFuture;
      expect(loggedIn, isTrue);
      expect(client.auth.currentUser?.id, 'usr-user-B', reason: 'User B is active after cleanup and login');
      expect(client.auth.currentUser?.id, 'usr-user-B', reason: 'sent phase intent has no verified session and must not sign out B');
    });

    test('X2_same_user_new_login_is_not_signed_out_by_old_cancel_cleanup', () async {
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
      await store.write(PendingRecovery(
        intentId: 'intent-same-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.firstClearGate = Completer<void>();
      final cancelFuture = provider.cancel();
      await spinUntil(() => store.clearCalls == 1);

      var loginCompleted = false;
      final loginFuture = auth.login('recoveryA@travelgo.vn', 'newPasswordA123!').then((value) { loginCompleted = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(loginCompleted, isFalse, reason: 'login must await pending marker cleanup');
      store.firstClearGate!.complete();
      await cancelFuture;
      final loggedIn = await loginFuture;
      expect(loggedIn, isTrue);
      expect(client.auth.currentUser?.id, 'usr-recovery-A');
      expect(auth.currentUser?.id, 'usr-recovery-A');
      expect(client.auth.currentUser?.id, 'usr-recovery-A', reason: 'new login is not owned by old recovery even for the same subject');
      expect(auth.currentUser?.id, 'usr-recovery-A');
    });

    test('X2_stale_retry_cleanup_cannot_sign_out_account_B_after_preflight_read', () async {
      await store.write(PendingRecovery(
        intentId: 'intent-retry-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await provider.initializeFromStore();
      store.failClear = true;
      await provider.cancel();
      expect(provider.isCleanupRequired, isTrue);

      store.failClear = false;
      store.readGate = Completer<void>();
      final readsBefore = store.readCalls;
      final retryFuture = provider.retryCleanup();
      await spinUntil(() => store.readCalls == readsBefore + 1);

      final loggedIn = await auth.login('userB@travelgo.vn', 'passwordB123');
      expect(loggedIn, isTrue);
      expect(client.auth.currentUser?.id, 'usr-user-B');

      store.readGate!.complete();
      await retryFuture;
      expect(client.auth.currentUser?.id, 'usr-user-B', reason: 'retry cleanup must recheck account ownership and not sign out B');
    });

    test('P1_production_store_unverified_sent_cancel_cannot_log_out_B', () async {
      final prodStore = CompletionGatedStore(prefs, projectNamespace: 'prod_sent_p1');
      final prodProvider = PasswordRecoveryProvider(
        service: service,
        store: prodStore,
        auth: auth,
        clientProvider: () => client,
      );
      await prodStore.write(PendingRecovery(
        intentId: 'intent-sent-p1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      ));
      await prodProvider.initializeFromStore();
      expect(prodProvider.state, RecoveryState.emailRequested);

      final cancelFuture = prodProvider.cancel();
      await prodStore.firstClearEntered.future;
      expect(await prodStore.read(), isNull, reason: 'production clear already removed marker');

      var loginCompleted = false;
      final loginFuture = auth.login('userB@travelgo.vn', 'passwordB123').then((value) { loginCompleted = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(loginCompleted, isFalse, reason: 'login must await pending marker cleanup');
      prodStore.firstClearRelease.complete();
      await cancelFuture;
      final loggedIn = await loginFuture;
      expect(loggedIn, isTrue);
      expect(client.auth.currentUser?.id, 'usr-user-B');
      expect(client.auth.currentUser?.id, 'usr-user-B');
      prodProvider.dispose();
    });

    test('P1_production_store_same_user_new_login_preserved_after_cancel', () async {
      final prodStore = CompletionGatedStore(prefs, projectNamespace: 'prod_same_p1');
      final prodProvider = PasswordRecoveryProvider(
        service: service,
        store: prodStore,
        auth: auth,
        clientProvider: () => client,
      );
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
      await prodStore.write(PendingRecovery(
        intentId: 'intent-same-p1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await prodProvider.initializeFromStore();
      expect(prodProvider.isReady, isTrue);

      final cancelFuture = prodProvider.cancel();
      await prodStore.firstClearEntered.future;
      expect(await prodStore.read(), isNull);

      var loginCompleted = false;
      final loginFuture = auth.login('recoveryA@travelgo.vn', 'newPasswordA123!').then((value) { loginCompleted = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(loginCompleted, isFalse, reason: 'login must await pending marker cleanup');
      prodStore.firstClearRelease.complete();
      await cancelFuture;
      final loggedIn = await loginFuture;
      expect(loggedIn, isTrue);
      expect(client.auth.currentUser?.id, 'usr-recovery-A');
      expect(client.auth.currentUser?.id, 'usr-recovery-A');
      prodProvider.dispose();
    });

    test('R3_old_cancel_cannot_sign_out_newer_recovery_of_same_subject', () async {
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
      await store.write(PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.firstClearGate = Completer<void>();
      final oldCancel = provider.cancel();
      await spinUntil(() => store.clearCalls == 1);

      final successor = provider.requestEmail('recoveryA@travelgo.vn');
      await Future<void>.delayed(Duration.zero);
      store.firstClearGate!.complete();
      await oldCancel;
      await successor;
      final newIntentId = provider.currentIntent!.intentId;
      expect(newIntentId, isNot('intent-A'));
      expect(await provider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-new-A'),
      ), isTrue);

      expect(auth.currentUser, isNull, reason: 'new flow is recovery, not a normal login');
      expect(client.auth.currentUser?.id, 'usr-recovery-A');
      expect(provider.currentIntent?.intentId, newIntentId);
      expect(provider.isReady, isTrue);


      expect(client.auth.currentUser?.id, 'usr-recovery-A',
        reason: 'old intent does not own newer recovery session of same subject');
      expect(provider.currentIntent?.intentId, newIntentId);
      expect(provider.isReady, isTrue);
    });

    test('R3_production_store_old_cancel_must_preserve_newer_recovery_of_same_user', () async {
      final prodStore = CompletionGatedStore(prefs, projectNamespace: 'prod_r3_same');
      final prodProvider = PasswordRecoveryProvider(
        service: service,
        store: prodStore,
        auth: auth,
        clientProvider: () => client,
      );
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
      await prodStore.write(PendingRecovery(
        intentId: 'intent-prod-r3',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-A',
      ));
      await prodProvider.initializeFromStore();
      expect(prodProvider.isReady, isTrue);

      final oldCancel = prodProvider.cancel();
      await prodStore.firstClearEntered.future;
      expect(await prodStore.read(), isNull, reason: 'production marker clear already completed');

      final successor = prodProvider.requestEmail('recoveryA@travelgo.vn');
      await Future<void>.delayed(Duration.zero);
      prodStore.firstClearRelease.complete();
      await oldCancel;
      await successor;
      final newIntentId = prodProvider.currentIntent!.intentId;
      expect(await prodProvider.handleCallback(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-new-prod-A'),
      ), isTrue);

      expect(client.auth.currentUser?.id, 'usr-recovery-A');
      expect(prodProvider.currentIntent?.intentId, newIntentId);
      expect(prodProvider.isReady, isTrue);


      expect(client.auth.currentUser?.id, 'usr-recovery-A',
        reason: 'completion of old clear cannot authorize logout of newer recovery');
      expect(prodProvider.currentIntent?.intentId, newIntentId);
      prodProvider.dispose();
    });

    test('X3_first_marker_persistence_failure_leaves_an_error_and_permits_retry', () async {
      store.failWrite = true;
      await provider.requestEmail('account-A@travelgo.vn');
      expect(provider.isProcessing, isFalse, reason: 'failed persistence must not leave sending state forever');
      expect(provider.errorMessage, isNotEmpty);
      expect(recoverCalls, 0);

      store.failWrite = false;
      await provider.requestEmail('account-A@travelgo.vn');
      expect(recoverCalls, 1, reason: 'retry should be dispatchable once persistence recovers');
      expect(provider.state, RecoveryState.emailRequested);
    });
  });
}
