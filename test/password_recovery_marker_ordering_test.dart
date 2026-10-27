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

import 'password_recovery_authority_test.dart'
    show PausableRecoveryIntentStore, MockAsyncStorage, syntheticJwt, spinUntil;

const _owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

Map<String, dynamic> _user() => {
  'id': _owner,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'recovery@example.invalid',
  'created_at': '2026-10-25T00:00:00Z',
};

Map<String, dynamic> _session() => {
  'access_token': syntheticJwt(_owner),
  'refresh_token': 'synthetic-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': _user(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PausableRecoveryIntentStore store;
  late SupabaseClient client;
  late AuthProvider auth;
  late PasswordRecoveryProvider recovery;
  late MockAsyncStorage pkce;
  var failLogout = false;
  var passwordUpdates = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PausableRecoveryIntentStore(
      await SharedPreferences.getInstance(),
      projectNamespace: 'ordering',
    );
    pkce = MockAsyncStorage();
    failLogout = false;
    passwordUpdates = 0;
    client = SupabaseClient(
      'https://synthetic.invalid',
      'synthetic-public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: pkce,
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/token')) {
          return http.Response(
            jsonEncode(_session()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/recover')) return http.Response('{}', 200);
        if (path.endsWith('/logout')) {
          return failLogout
              ? http.Response('{"error":"server_error"}', 500)
              : http.Response('{}', 204);
        }
        if (path.endsWith('/user')) {
          if (request.method == 'PUT') passwordUpdates++;
          return http.Response(
            jsonEncode(_user()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    auth = AuthProvider(client: client, initialRecoveryIntentId: 'intent-A');
    recovery = PasswordRecoveryProvider(
      service: PasswordRecoveryService(),
      store: store,
      auth: auth,
      clientProvider: () => client,
    );
  });

  tearDown(() async {
    store.releaseAll();
    await Future<void>.delayed(Duration.zero);
    recovery.dispose();
    auth.dispose();
    await client.dispose();
  });

  Future<void> seed(RecoveryPhase phase) async {
    await client.auth.recoverSession(jsonEncode(_session()));
    await store.write(
      PendingRecovery(
        intentId: 'intent-A',
        requestedAt: DateTime.now().toUtc(),
        phase: phase,
        verifiedUserId: phase == RecoveryPhase.ready ? _owner : null,
      ),
    );
    await pkce.setItem(
      key: 'supabase.auth.token-code-verifier',
      value: 'synthetic-verifier/passwordRecovery',
    );
    await recovery.initializeFromStore();
  }

  test('pending marker write drains before cancel and successor commit', () async {
    await seed(RecoveryPhase.sent);
    final readyGate = store.gates[RecoveryPhase.ready] = Completer<void>();
    final callback = recovery.handleCallback(
      Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=synthetic-A',
      ),
    );
    await spinUntil(() => (store.entered[RecoveryPhase.ready] ?? 0) == 1);
    var cancelled = false;
    final cancel = recovery.cancel().then((_) {
      cancelled = true;
    });
    final next = recovery.requestEmail('successor@example.invalid');
    await Future<void>.delayed(Duration.zero);
    final clearedBeforeDrain = store.clearCalls;
    final successorBeforeDrain = store.entered[RecoveryPhase.requesting] ?? 0;
    final cancelBeforeDrain = cancelled;
    readyGate.complete();
    await Future.wait([callback, cancel, next]);
    expect(
      clearedBeforeDrain,
      0,
      reason: 'clear must not overtake pending write',
    );
    expect(
      successorBeforeDrain,
      0,
      reason: 'successor cannot commit ahead of old write',
    );
    expect(
      cancelBeforeDrain,
      false,
      reason: 'cancel completion must include marker cleanup',
    );
    expect(store.readCalls, greaterThan(0));
    final marker = await store.read();
    expect(marker?.intentId, recovery.currentIntent?.intentId);
    expect(marker?.intentId, isNot('intent-A'));
    expect(marker?.phase, RecoveryPhase.sent);
    expect(
      client.auth.currentSession == null,
      true,
      reason: 'an email request is not a verified successor SDK session',
    );
    expect(passwordUpdates, 0);
  });

  test(
    'cancel retains retry owner after marker removed and logout fails',
    () async {
      await seed(RecoveryPhase.ready);
      failLogout = true;
      await recovery.cancel();
      expect(await store.read(), isNull);
      expect(recovery.isCleanupRequired, true);
      failLogout = false;
      await recovery.retryCleanup();
      expect(auth.isRecovering, false);
      expect(recovery.isCleanupRequired, false);
      expect(recovery.currentIntent, isNull);
      expect(passwordUpdates, 0);
    },
  );

  test(
    'failed marker clear keeps owner and successful retry releases it',
    () async {
      await seed(RecoveryPhase.ready);
      store.failClear = true;
      await recovery.cancel();
      expect((await store.read())?.intentId, 'intent-A');
      expect(recovery.isCleanupRequired, true);
      store.failClear = false;
      await recovery.retryCleanup();
      expect(await store.read(), isNull);
      expect(auth.isRecovering, false);
      expect(recovery.isCleanupRequired, false);
    },
  );

  test('control successful cancellation leaves no marker or retry', () async {
    await seed(RecoveryPhase.ready);
    await recovery.cancel();
    expect(await store.read(), isNull);
    expect(auth.isRecovering, false);
    expect(recovery.isCleanupRequired, false);
  });

  test(
    'old callback cannot reacquire authority while cancel is draining',
    () async {
      await seed(RecoveryPhase.ready);
      store.firstClearGate = Completer<void>();
      final cancel = recovery.cancel();
      await spinUntil(() => store.clearCalls == 1);
      final accepted = await recovery.handleCallback(
        Uri.parse(
          'io.supabase.travelgo://login-callback?flow=recovery&code=old-during-cancel',
        ),
      );
      store.firstClearGate!.complete();
      await cancel;
      expect(accepted, false);
      expect(recovery.isReady, false);
      expect(auth.isRecovering, false);
    },
  );

  test('cancel drains SDK session established before pending ready marker', () async {
    await seed(RecoveryPhase.sent);
    final readyGate = store.gates[RecoveryPhase.ready] = Completer<void>();
    final callback = recovery.handleCallback(
      Uri.parse(
        'io.supabase.travelgo://login-callback?flow=recovery&code=verified-before-marker',
      ),
    );
    await spinUntil(() => (store.entered[RecoveryPhase.ready] ?? 0) == 1);
    expect(client.auth.currentSession, isNotNull);
    final cancel = recovery.cancel();
    readyGate.complete();
    await Future.wait([callback, cancel]);
    expect(await store.read(), isNull);
    expect(
      client.auth.currentSession == null,
      true,
      reason:
          'SDK ownership starts at exchange success, before marker persistence',
    );
    expect(auth.isRecovering, false);
  });
}
