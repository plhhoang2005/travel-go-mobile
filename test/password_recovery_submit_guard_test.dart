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
    show PausableRecoveryIntentStore, spinUntil, syntheticJwt;

const _owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _password = 'SyntheticPassword123!';

Map<String, dynamic> _user([String id = _owner]) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'fixture@example.invalid',
  'created_at': '2026-10-25T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late DateTime requestedAt;
  late PausableRecoveryIntentStore store;
  late SupabaseClient client;
  late AuthProvider auth;
  late PasswordRecoveryProvider recovery;
  late List<String> passwords;
  late int gets;
  late int getStatus;
  late String getOwner;
  late bool offline;
  late bool malformed;
  Completer<void>? getGate;
  Completer<void>? putGate;
  Completer<void>? logoutGate;

  setUp(() async {
    now = requestedAt = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({});
    store = PausableRecoveryIntentStore(
      await SharedPreferences.getInstance(),
      projectNamespace: 'c4-submit',
      clock: () => now,
    );
    passwords = [];
    gets = 0;
    getStatus = 200;
    getOwner = _owner;
    offline = malformed = false;
    getGate = putGate = logoutGate = null;
    client = SupabaseClient(
      'https://synthetic.invalid',
      'synthetic-public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/user')) {
          if (request.method == 'GET') {
            gets++;
            await getGate?.future;
            if (offline) throw http.ClientException('synthetic offline');
            return http.Response(
              jsonEncode(
                getStatus != 200
                    ? {'msg': 'synthetic denied'}
                    : malformed
                    ? <String, dynamic>{}
                    : _user(getOwner),
              ),
              getStatus,
            );
          }
          passwords.add(
            (jsonDecode(request.body) as Map)['password'] as String,
          );
          await putGate?.future;
          return http.Response(jsonEncode(_user()), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          await logoutGate?.future;
          return http.Response('{}', 204);
        }
        if (request.url.path.endsWith('/token')) {
          const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
          return http.Response(
            jsonEncode({
              'access_token': syntheticJwt(other),
              'refresh_token': 'synthetic-refresh-B',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': _user(other),
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': syntheticJwt(_owner),
        'refresh_token': 'synthetic-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': _user(),
      }),
    );
    auth = AuthProvider(client: client, initialRecoveryIntentId: 'c4-intent');
    recovery = PasswordRecoveryProvider(
      service: PasswordRecoveryService(),
      store: store,
      auth: auth,
      clientProvider: () => client,
      clock: () => now,
    );
    await store.write(
      PendingRecovery(
        intentId: 'c4-intent',
        requestedAt: requestedAt,
        phase: RecoveryPhase.ready,
        verifiedUserId: _owner,
      ),
    );
  });

  tearDown(() async {
    store.releaseAll();
    for (final gate in [getGate, putGate, logoutGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    recovery.dispose();
    auth.dispose();
    await client.dispose();
  });

  Future<bool> submit([String password = _password]) =>
      recovery.submitNewPassword(password, password);

  Future<void> ready() async {
    await recovery.initializeFromStore();
    expect(recovery.isReady, isTrue);
    gets = 0;
  }

  for (final second in [_password, 'DifferentSynthetic456!']) {
    test('double submit before write-ahead sends one PUT ($second)', () async {
      await ready();
      final gate = store.gates[RecoveryPhase.updating] = Completer<void>();
      final first = submit();
      await spinUntil(() => (store.entered[RecoveryPhase.updating] ?? 0) > 0);
      final duplicate = submit(second);
      gate.complete();
      final results = await Future.wait([first, duplicate]);
      expect(passwords, [_password]);
      expect(results, [true, false]);
    });
  }

  test('single valid submit revalidates server then sends one PUT', () async {
    await ready();
    expect(await submit(), isTrue);
    expect(gets, 1);
    expect(passwords, [_password]);
    expect(client.auth.currentSession, isNull);
    expect(await store.read(), isNull);
  });

  test(
    'marker failure sends zero PUT and releases slot for safe retry',
    () async {
      await ready();
      store.failWrite = true;
      expect(await submit(), isFalse);
      expect(passwords, isEmpty);
      store.failWrite = false;
      expect(await submit(), isTrue);
      expect(passwords, [_password]);
    },
  );

  for (final offset in [-1, 0, 1]) {
    test('intent TTL boundary offset ${offset}ms', () async {
      await ready();
      now = requestedAt.add(
        Duration(milliseconds: PendingRecovery.ttlMinutes * 60 * 1000 + offset),
      );
      expect(await submit(), offset < 0);
      expect(passwords, offset < 0 ? [_password] : isEmpty);
    });
  }

  test('intent expires while write-ahead is pending: zero PUT', () async {
    await ready();
    final gate = store.gates[RecoveryPhase.updating] = Completer<void>();
    final operation = submit();
    await spinUntil(() => (store.entered[RecoveryPhase.updating] ?? 0) > 0);
    now = requestedAt.add(const Duration(minutes: PendingRecovery.ttlMinutes));
    gate.complete();
    expect(await operation, isFalse);
    expect(passwords, isEmpty);
    expect(recovery.state, isNot(RecoveryState.uncertain));
  });

  test('intent expires while credential queue is pending: zero PUT', () async {
    await ready();
    final gate = Completer<void>();
    var entered = false;
    final blocker = auth.runRecoveryMutation('c4-intent', (_) async {
      entered = true;
      await gate.future;
    });
    await spinUntil(() => entered);
    final operation = submit();
    await spinUntil(() => (store.entered[RecoveryPhase.updating] ?? 0) > 0);
    now = requestedAt.add(const Duration(minutes: PendingRecovery.ttlMinutes));
    gate.complete();
    await blocker;
    expect(await operation, isFalse);
    expect(passwords, isEmpty);
  });

  for (final outcome in ['expired', 'cancel', 'guest']) {
    test('$outcome while server preflight is pending: zero PUT', () async {
      await ready();
      getGate = Completer<void>();
      final operation = submit();
      // Baseline has no GET: wait for either observable dispatch boundary.
      await spinUntil(() => gets > 0 || passwords.isNotEmpty);
      Future<void>? transition;
      if (outcome == 'expired') {
        now = requestedAt.add(
          const Duration(minutes: PendingRecovery.ttlMinutes),
        );
      } else if (outcome == 'cancel') {
        transition = recovery.cancel();
      } else {
        auth.continueAsGuest();
      }
      getGate!.complete();
      await operation;
      await transition;
      expect(gets, 1);
      expect(passwords, isEmpty);
      expect(recovery.isReady, isFalse);
    });
  }

  for (final boundary in ['GET', 'PUT', 'cleanup']) {
    test('duplicate during pending $boundary sends one PUT', () async {
      await ready();
      if (boundary == 'GET') getGate = Completer<void>();
      if (boundary == 'PUT') putGate = Completer<void>();
      if (boundary == 'cleanup') logoutGate = Completer<void>();
      final first = submit();
      await spinUntil(
        () => boundary == 'GET'
            ? gets > 0 || passwords.isNotEmpty
            : boundary == 'PUT'
            ? passwords.isNotEmpty
            : recovery.isCleanupRequired,
      );
      final duplicate = submit('DifferentSynthetic456!');
      getGate?.complete();
      putGate?.complete();
      logoutGate?.complete();
      expect(await duplicate, isFalse);
      expect(await first, isTrue);
      expect(passwords, [_password]);
    });
  }

  for (final outcome in [
    'denied',
    'wrong-owner',
    'malformed',
    'offline',
    'server-error',
  ]) {
    test('cold $outcome cannot open reset form', () async {
      getStatus = outcome == 'denied'
          ? 401
          : outcome == 'server-error'
          ? 500
          : 200;
      getOwner = outcome == 'wrong-owner' ? 'wrong-owner' : _owner;
      malformed = outcome == 'malformed';
      offline = outcome == 'offline';
      await recovery.initializeFromStore();
      expect(gets, 1);
      expect(recovery.isReady, isFalse);
      expect(auth.currentUser, isNull);
      expect(passwords, isEmpty);
    });
  }

  test(
    'cold success verifies online without establishing normal account',
    () async {
      await recovery.initializeFromStore();
      expect(gets, 1);
      expect(recovery.isReady, isTrue);
      expect(auth.currentUser, isNull);
    },
  );

  test('cold offline retry revalidates and never sends password', () async {
    offline = true;
    await recovery.initializeFromStore();
    expect(recovery.isReady, isFalse);
    offline = false;
    await recovery.retryVerification();
    expect(gets, 2);
    expect(recovery.isReady, isTrue);
    expect(passwords, isEmpty);
  });

  test('cold retry after TTL revokes stale recovery session', () async {
    offline = true;
    await recovery.initializeFromStore();
    now = requestedAt.add(const Duration(minutes: PendingRecovery.ttlMinutes));
    await recovery.retryVerification();
    expect(recovery.isReady, isFalse);
    expect(passwords, isEmpty);
    expect(auth.isRecovering, isFalse);
    expect(client.auth.currentSession, isNull);
  });

  test(
    'expired ready marker survives bootstrap read only for owned cleanup',
    () async {
      now = requestedAt.add(
        const Duration(minutes: PendingRecovery.ttlMinutes),
      );
      // main() reads the marker before constructing AuthProvider. Do not erase
      // the owner and let an old recovery SDK session become a normal account.
      expect((await store.read())?.intentId, 'c4-intent');
      await recovery.initializeFromStore();
      expect(recovery.isReady, isFalse);
      expect(auth.isRecovering, isFalse);
      expect(auth.currentUser, isNull);
      expect(client.auth.currentSession, isNull);
      expect(await store.read(), isNull);
      expect(gets, 0);
      expect(passwords, isEmpty);
    },
  );

  test('cold TTL expiry during GET never opens reset form', () async {
    getGate = Completer<void>();
    final operation = recovery.initializeFromStore();
    await spinUntil(() => gets == 1);
    now = requestedAt.add(const Duration(minutes: PendingRecovery.ttlMinutes));
    getGate!.complete();
    await operation;
    expect(recovery.isReady, isFalse);
    expect(client.auth.currentSession, isNull);
    expect(passwords, isEmpty);
  });

  test(
    'double submit while reading marker dispatches at most one PUT',
    () async {
      store.readGate = Completer<void>();
      final first = submit();
      await spinUntil(() => store.readCalls > 0);
      final duplicate = submit('OtherSynthetic456!');
      store.readGate!.complete();
      expect(await duplicate, isFalse);
      expect(await first, isTrue);
      expect(passwords, [_password]);
    },
  );

  test('expiry while initial marker read is pending sends zero PUT', () async {
    store.readGate = Completer<void>();
    final operation = submit();
    await spinUntil(() => store.readCalls > 0);
    now = requestedAt.add(const Duration(minutes: PendingRecovery.ttlMinutes));
    store.readGate!.complete();
    expect(await operation, isFalse);
    expect(passwords, isEmpty);
  });

  test('cancel while submit reads marker cannot revive ready', () async {
    store.readGate = Completer<void>();
    final operation = submit();
    await spinUntil(() => store.readCalls > 0);
    final cancelled = recovery.cancel();
    store.readGate!.complete();
    await cancelled;
    expect(await operation, isFalse);
    expect(recovery.isReady, isFalse);
    expect(passwords, isEmpty);
  });

  test('cold GET response after cancel cannot reopen reset form', () async {
    getGate = Completer<void>();
    final operation = recovery.initializeFromStore();
    await spinUntil(() => gets > 0 || recovery.isReady);
    final cancelled = recovery.cancel();
    getGate!.complete();
    await Future.wait([operation, cancelled]);
    expect(recovery.isReady, isFalse);
    expect(auth.isRecovering, isFalse);
    expect(client.auth.currentSession, isNull);
  });

  test('warm denied preflight sends no PUT', () async {
    await ready();
    getStatus = 401;
    expect(await submit(), isFalse);
    expect(gets, 1);
    expect(passwords, isEmpty);
    expect(recovery.isReady, isFalse);
  });

  test(
    'login B during preflight cannot receive stale PUT or lose its session',
    () async {
      await ready();
      getGate = Completer<void>();
      final update = submit();
      await spinUntil(() => gets == 1);
      final login = auth.login('other@example.invalid', 'SyntheticLogin123!');
      getGate!.complete();
      expect(await update, isFalse);
      expect(await login, isTrue);
      expect(passwords, isEmpty);
      expect(auth.currentUser?.id, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
      expect(client.auth.currentSession?.user.id, auth.currentUser?.id);
    },
  );

  test(
    'expiry after PUT dispatch does not invent a failed server outcome',
    () async {
      await ready();
      putGate = Completer<void>();
      final operation = submit();
      await spinUntil(() => passwords.isNotEmpty);
      now = requestedAt.add(
        const Duration(minutes: PendingRecovery.ttlMinutes),
      );
      putGate!.complete();
      expect(await operation, isTrue);
      expect(passwords, [_password]);
      expect(recovery.state, RecoveryState.completed);
    },
  );

  test(
    'warm offline preflight is safely retryable and not uncertain',
    () async {
      await ready();
      offline = true;
      expect(await submit(), isFalse);
      expect(passwords, isEmpty);
      expect(recovery.isReady, isTrue);
      expect(recovery.state, isNot(RecoveryState.uncertain));
      expect((await store.read())?.phase, RecoveryPhase.ready);
      offline = false;
      expect(await submit(), isTrue);
      expect(passwords, [_password]);
    },
  );
}
