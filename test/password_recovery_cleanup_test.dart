// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
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
  Future<void> clear() async {
    if (failRemove) {
      throw StateError('Simulated prefs remove failure');
    }
    return super.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        'access_token': 'recovery-cleanup-token',
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
  });
}
