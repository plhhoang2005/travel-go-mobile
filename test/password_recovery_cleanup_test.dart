// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/password_recovery_state.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/providers/password_recovery_provider.dart';
import 'package:travelgo_mobile/features/auth/services/password_recovery_service.dart';
import 'package:travelgo_mobile/features/auth/services/recovery_intent_store.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'local_trip_store_test.dart' as local_fixtures;

String syntheticJwt(String id) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic';
}

String requestSubject(http.Request request) {
  final token = request.headers['authorization']!.split(' ').last;
  final claims = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
  ) as Map<String, dynamic>;
  return claims['sub'] as String;
}

class MemoryPkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }
  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

class FailingStore extends RecoveryIntentStore {
  bool failUpdatingWrite = false;
  bool failCleanupWrite = false;
  bool failRemove = false;

  FailingStore(super.prefs, {super.projectNamespace = 'test_cleanup'});

  @override
  Future<void> write(PendingRecovery value) async {
    if (failUpdatingWrite && value.phase == RecoveryPhase.updating) {
      throw StateError('Simulated write-ahead updating failure');
    }
    if (failCleanupWrite && value.phase == RecoveryPhase.cleanup) {
      throw StateError('Simulated write cleanup failure');
    }
    return super.write(value);
  }

  @override
  Future<void> clear([String? expectedIntentId]) async {
    if (failRemove) {
      throw StateError('Simulated prefs remove failure');
    }
    return super.clear(expectedIntentId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Task A3: Update Bền Vững & Cleanup-Only Retry', () {
    late SharedPreferences prefs;
    late FailingStore store;
    late PasswordRecoveryService service;
    late SupabaseClient client;
    late AuthProvider auth;
    late PasswordRecoveryProvider provider;
    int updateCalls = 0;
    bool failSignoutOnce = false;
    bool dropUpdateAck = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = FailingStore(prefs);
      service = PasswordRecoveryService();
      updateCalls = 0;
      failSignoutOnce = false;
      dropUpdateAck = false;

      client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.contains('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': syntheticJwt('usr-user-B'),
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
          if (path.contains('/user') && request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'id': requestSubject(request),
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'userB@travelgo.vn',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/user') && request.method == 'PUT') {
            updateCalls++;
            if (dropUpdateAck) {
              throw const SocketException('Connection lost before ACK');
            }
            return http.Response(
              jsonEncode({
                'id': 'usr-recovery-cleanup',
                'email': 'cleanup@travelgo.vn',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/logout')) {
            if (failSignoutOnce) {
              failSignoutOnce = false;
              return http.Response('{"error":"server_error"}', 500);
            }
            return http.Response('{}', 204);
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      final sessionJson = jsonEncode({
        'access_token': syntheticJwt('usr-recovery-cleanup'),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'recovery-cleanup-refresh',
        'user': {
          'id': 'usr-recovery-cleanup',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'cleanup@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);

      auth = AuthProvider(client: client);
      provider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: auth,
        clientProvider: () => client,
      );
    });

    tearDown(() async {
      provider.dispose();
      auth.dispose();
      await client.dispose();
    });

    test('failed_write_ahead_never_updates_password', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-1',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.failUpdatingWrite = true;

      final res = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      expect(res, isFalse);
      expect(updateCalls, 0);
      final stored = await store.read();
      expect(stored?.phase, RecoveryPhase.ready);
    });

    test('acknowledged_update_and_marker_failure_is_cleanup_only', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-2',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();

      store.failCleanupWrite = true;

      final res = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      expect(res, isFalse);
      expect(updateCalls, 1);
      expect(provider.isCleanupRequired, isTrue);

      // Attempting to submit new password again must NOT call updatePassword
      final secondSubmit = await provider.submitNewPassword('AnotherPass!', 'AnotherPass!');
      expect(secondSubmit, isFalse);
      expect(updateCalls, 1); // Remains 1!

      // Retrying cleanup succeeds without updating password again
      store.failCleanupWrite = false;
      await provider.retryCleanup();
      expect(updateCalls, 1);
      expect(provider.state, RecoveryState.completed);
    });

    test('acknowledged_update_and_signout_failure_retries_cleanup', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-3',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();

      failSignoutOnce = true;

      final res = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      expect(res, isFalse);
      expect(updateCalls, 1);
      expect(provider.isCleanupRequired, isTrue);

      // Retry cleanup succeeds on second signout attempt
      await provider.retryCleanup();
      expect(updateCalls, 1);
      expect(provider.state, RecoveryState.completed);
      expect(await store.read(), isNull);
    });

    test('false_remove_keeps_recovery_blocked', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-4',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();

      store.failRemove = true;

      final res = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      expect(res, isFalse);
      expect(updateCalls, 1);
      expect(provider.isCleanupRequired, isTrue);
      expect(auth.isRecovering, isTrue);

      // Retry cleanup with failing remove remains blocked
      await provider.retryCleanup();
      expect(provider.isCleanupRequired, isTrue);
      expect(updateCalls, 1);

      // Once remove succeeds, finish recovery
      store.failRemove = false;
      await provider.retryCleanup();
      expect(provider.state, RecoveryState.completed);
      expect(auth.isRecovering, isFalse);
    });

    test('restart_after_dispatch_never_reissues_update', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-5',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.updating,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);

      await provider.initializeFromStore();

      expect(provider.state, RecoveryState.uncertain);
      expect(updateCalls, 0);
    });

    test('lost_update_ack_is_uncertain_not_retryable_ready', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-6',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();

      dropUpdateAck = true;

      final res = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      expect(res, isFalse);
      expect(updateCalls, 1);
      expect(provider.state, RecoveryState.uncertain);
      final stored = await store.read();
      expect(stored?.phase, RecoveryPhase.updating);
    });

    test('wrong_or_expired_session_cannot_update', () async {
      final intent = PendingRecovery(
        intentId: 'intent-wa-7',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'different-owner-id',
      );
      await store.write(intent);
      await provider.initializeFromStore();

      final res = await provider.submitNewPassword('NewPass123!', 'NewPass123!');
      expect(res, isFalse);
      expect(updateCalls, 0);
    });

    test('expired_cleanup_marker_does_not_unlock_sdk_session', () async {
      final expiredIntent = PendingRecovery(
        intentId: 'intent-wa-8',
        requestedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 65)),
        phase: RecoveryPhase.cleanup,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(expiredIntent);

      final coldAuth = AuthProvider(
        client: client,
        initialRecoveryIntentId: expiredIntent.intentId,
      );
      final coldProvider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: coldAuth,
        clientProvider: () => client,
      );

      await coldProvider.initializeFromStore();

      expect(coldAuth.currentUser, isNull);
      expect(coldAuth.isAuthenticated, isFalse);
      expect(coldProvider.isCleanupRequired, isTrue);

      coldAuth.continueAsGuest();
      expect(coldAuth.isGuest, isTrue);
      expect(coldAuth.currentUser, isNull);
    });

    test('R5_failed_marker_cleanup_must_block_fresh_account_login', () async {
      final intent = PendingRecovery(
        intentId: 'intent-R5',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.failRemove = true;
      final loggedIn = await auth.login('userB@travelgo.vn', 'PasswordB123!');
      expect(loggedIn, isFalse, reason: 'new account cannot complete with stale recovery marker A');
      expect(auth.isAuthenticated, isFalse);
    });

    test('R9_failed_cancel_cleanup_must_keep_a_visible_cleanup_retry_state', () async {
      final intent = PendingRecovery(
        intentId: 'intent-R9',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.failRemove = true;
      await provider.cancel();

      expect(auth.isRecovering, isTrue, reason: 'failed cleanup must not claim recovery ended');
      expect(provider.isCleanupRequired, isTrue,
          reason: 'cleanup failure must not hide recovery UI behind idle');
      expect(provider.state, RecoveryState.cleanupRequired);
    });

    for (final failRemove in [false, true]) {
      test('${failRemove ? 'R10' : 'CONTROL'} real lifecycle login ${failRemove ? 'must block failed cleanup' : 'succeeds after cleanup'}', () async {
        await local_fixtures.runWithStore((ctx) async {
          const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
          const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
          late final LocalAccountLifecycleService lifecycle;
          late final SupabaseClient guardedClient;
          late final AuthProvider guardedAuth;
          late final PasswordRecoveryProvider guardedProvider;

          final pkce = MemoryPkce();
          guardedClient = SupabaseClient(
            'https://mock.supabase.co',
            'mock-anon-key',
            authOptions: AuthClientOptions(
              autoRefreshToken: false,
              pkceAsyncStorage: pkce,
            ),
            httpClient: MockClient((request) async {
              final path = request.url.path;
              if (path.contains('/token')) {
                return http.Response(
                  jsonEncode({
                    'access_token': syntheticJwt(ownerB),
                    'token_type': 'bearer',
                    'expires_in': 3600,
                    'refresh_token': 'user-refresh-B',
                    'user': {
                      'id': ownerB,
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
              if (path.contains('/user') && request.method == 'GET') {
                return http.Response(
                  jsonEncode({
                    'id': requestSubject(request),
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': 'userB@travelgo.vn',
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (path.contains('/logout')) return http.Response('{}', 204);
              return http.Response('{"error":"not_found"}', 404);
            }),
          );

          lifecycle = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            registryPath: '${ctx.tempDir.path}/synthetic-recovery-registry.json',
            sessionReader: () => guardedClient.auth.currentSession,
            verifySubject: (_) async => guardedClient.auth.currentUser?.id ?? (throw StateError('No SDK user')),
          );

          guardedAuth = AuthProvider(
            client: guardedClient,
            initialRecoveryIntentId: 'intent-R10',
            lifecycleLoader: () async => lifecycle,
          );

          guardedProvider = PasswordRecoveryProvider(
            service: service,
            store: store,
            auth: guardedAuth,
            clientProvider: () => guardedClient,
          );

          try {
            final sessionJson = jsonEncode({
              'access_token': syntheticJwt(ownerA),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'recovery-cleanup-refresh',
              'user': {
                'id': ownerA,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'cleanup@travelgo.vn',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
            });
            await guardedClient.auth.recoverSession(sessionJson);

            final intent = PendingRecovery(
              intentId: 'intent-R10',
              requestedAt: DateTime.now().toUtc(),
              phase: RecoveryPhase.ready,
              verifiedUserId: ownerA,
            );
            await store.write(intent);
            await guardedProvider.initializeFromStore();
            expect(guardedProvider.isReady, isTrue);

            store.failRemove = failRemove;
            final loggedIn = await guardedAuth.login('userB@travelgo.vn', 'PasswordB123!');
            if (failRemove) {
              expect(loggedIn, isFalse, reason: 'production lifecycle must not grant B with recovery A marker left behind');
              expect(lifecycle.handle, isNull);
            } else {
              expect(loggedIn, isTrue);
              expect(lifecycle.handle?.ownerId, ownerB);
              expect(await store.read(), isNull);
            }
          } finally {
            guardedProvider.dispose();
            guardedAuth.dispose();
            await guardedClient.dispose();
            await lifecycle.close();
          }
        });
      });
    }

    test('X4_failed_sdk_signout_during_login_cleanup_retains_usable_cleanup_retry_state', () async {
      final sessionJson = jsonEncode({
        'access_token': syntheticJwt('usr-recovery-cleanup'),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'recovery-cleanup-refresh',
        'user': {
          'id': 'usr-recovery-cleanup',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'cleanup@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);
      final intent = PendingRecovery(
        intentId: 'intent-X4',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      failSignoutOnce = true;
      final loggedIn = await auth.login('userB@travelgo.vn', 'PasswordB123!');
      expect(loggedIn, isFalse);
      expect(auth.isRecovering, isTrue);
      expect(provider.isCleanupRequired, isTrue, reason: 'marker clear succeeded but SDK signout failed: recovery gate must retain retry UI');
      expect(provider.currentIntent, isNotNull, reason: 'retry needs the cleanup owner even after marker removal');
    });

    test('X5_guest_cannot_bypass_failed_marker_cleanup_and_grant_B', () async {
      final sessionJson = jsonEncode({
        'access_token': syntheticJwt('usr-recovery-cleanup'),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'recovery-cleanup-refresh',
        'user': {
          'id': 'usr-recovery-cleanup',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'cleanup@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);
      final intent = PendingRecovery(
        intentId: 'intent-X5',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.failRemove = true;
      final uncaught = <Object>[];
      final completed = Completer<void>();
      bool? loginResult;

      await runZonedGuarded(() async {
        try {
          auth.continueAsGuest();
          for (var i = 0; i < 50 && !provider.isCleanupRequired; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          loginResult = await auth.login('userB@travelgo.vn', 'PasswordB123!');
        } finally {
          completed.complete();
        }
      }, (error, stack) => uncaught.add(error));

      await completed.future;
      expect((await store.read())?.intentId, 'intent-X5', reason: 'cleanup really failed and A marker remains');
      expect(loginResult, isFalse, reason: 'Guest selection cannot erase the cleanup gate for subsequent login B');
      expect(uncaught, isEmpty, reason: 'cleanup failure should be represented in state, not an unhandled async error');
    });

    test('CONTROL_guest_with_successful_cleanup_allows_subsequent_login_B', () async {
      final sessionJson = jsonEncode({
        'access_token': syntheticJwt('usr-recovery-cleanup'),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'recovery-cleanup-refresh',
        'user': {
          'id': 'usr-recovery-cleanup',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'cleanup@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);
      final intent = PendingRecovery(
        intentId: 'intent-control-guest',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-cleanup',
      );
      await store.write(intent);
      await provider.initializeFromStore();
      expect(provider.isReady, isTrue);

      store.failRemove = false;
      auth.continueAsGuest();
      expect(auth.isGuest, isTrue);

      for (var i = 0; i < 50 && auth.isRecovering; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final loggedIn = await auth.login('userB@travelgo.vn', 'PasswordB123!');
      expect(loggedIn, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(await store.read(), isNull);
    });

    for (final failRemove in [true, false]) {
      test('X5_R10_sqlite_lifecycle_guest_with_failRemove_$failRemove', () async {
        await local_fixtures.runWithStore((ctx) async {
          const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
          const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

          late SupabaseClient guardedClient;
          late LocalAccountLifecycleService lifecycle;
          late AuthProvider guardedAuth;
          late PasswordRecoveryProvider guardedProvider;

          guardedClient = SupabaseClient(
            'https://mock.supabase.co',
            'mock-anon-key',
            authOptions: AuthClientOptions(
              autoRefreshToken: false,
              pkceAsyncStorage: MemoryPkce(),
            ),
            httpClient: MockClient((request) async {
              final path = request.url.path;
              if (path.contains('/token')) {
                return http.Response(
                  jsonEncode({
                    'access_token': syntheticJwt(ownerB),
                    'token_type': 'bearer',
                    'expires_in': 3600,
                    'refresh_token': 'user-refresh-B',
                    'user': {
                      'id': ownerB,
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
              if (path.contains('/user') && request.method == 'GET') {
                return http.Response(
                  jsonEncode({
                    'id': requestSubject(request),
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': 'userB@travelgo.vn',
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }
              if (path.contains('/logout')) return http.Response('{}', 204);
              return http.Response('{"error":"not_found"}', 404);
            }),
          );

          lifecycle = LocalAccountLifecycleService(
            storeLoader: () async => ctx.store,
            registryPath: '${ctx.tempDir.path}/synthetic-recovery-registry-guest.json',
            sessionReader: () => guardedClient.auth.currentSession,
            verifySubject: (_) async => guardedClient.auth.currentUser?.id ?? (throw StateError('No SDK user')),
          );

          guardedAuth = AuthProvider(
            client: guardedClient,
            initialRecoveryIntentId: 'intent-R10-guest',
            lifecycleLoader: () async => lifecycle,
          );

          guardedProvider = PasswordRecoveryProvider(
            service: service,
            store: store,
            auth: guardedAuth,
            clientProvider: () => guardedClient,
          );

          try {
            final sessionJson = jsonEncode({
              'access_token': syntheticJwt(ownerA),
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'recovery-cleanup-refresh',
              'user': {
                'id': ownerA,
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'cleanup@travelgo.vn',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
            });
            await guardedClient.auth.recoverSession(sessionJson);

            final intent = PendingRecovery(
              intentId: 'intent-R10-guest',
              requestedAt: DateTime.now().toUtc(),
              phase: RecoveryPhase.ready,
              verifiedUserId: ownerA,
            );
            await store.write(intent);
            await guardedProvider.initializeFromStore();
            expect(guardedProvider.isReady, isTrue);

            store.failRemove = failRemove;
            guardedAuth.continueAsGuest();
            expect(guardedAuth.isGuest, isTrue);

            for (var i = 0; i < 50 && (!failRemove ? guardedAuth.isRecovering : !guardedProvider.isCleanupRequired); i++) {
              await Future<void>.delayed(Duration.zero);
            }

            final loggedIn = await guardedAuth.login('userB@travelgo.vn', 'PasswordB123!');
            if (failRemove) {
              expect(loggedIn, isFalse, reason: 'Guest choice followed by failed cleanup must still block account grant');
              expect(lifecycle.handle, isNull);
            } else {
              expect(loggedIn, isTrue);
              expect(lifecycle.handle?.ownerId, ownerB);
              expect(await store.read(), isNull);
            }
          } finally {
            guardedProvider.dispose();
            guardedAuth.dispose();
            await guardedClient.dispose();
            await lifecycle.close();
          }
        });
      });
    }
  });
}
