// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/password_recovery_state.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:travelgo_mobile/features/auth/presentation/widgets/password_recovery_gate.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/providers/password_recovery_provider.dart';
import 'package:travelgo_mobile/features/auth/services/password_recovery_service.dart';
import 'package:travelgo_mobile/features/auth/services/recovery_intent_store.dart';

import 'password_recovery_authority_test.dart'
    show MockAsyncStorage, spinUntil, syntheticJwt;
import 'password_recovery_gate_test.dart' show pumpRecoveryUntil;

const _owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _password = 'SyntheticPassword123!';

// Exercise production RecoveryIntentStore.write, including setString=false.
class _FailurePreferences extends InMemorySharedPreferencesStore {
  bool rejectReady = false;
  bool throwOnReady = false;
  bool rejectUpdating = false;
  int updatingWrites = 0;
  int readyRestoreAttempts = 0;
  Completer<void>? readyGate;

  _FailurePreferences(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (value is String && key.contains('supabase_recovery_intent')) {
      final marker = jsonDecode(value) as Map<String, dynamic>;
      if (marker['phase'] == 'updating') {
        updatingWrites++;
        if (rejectUpdating) return false;
      }
      if (marker['phase'] == 'ready' && rejectReady) {
        readyRestoreAttempts++;
        await readyGate?.future;
        if (throwOnReady) throw StateError('synthetic local write failure');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform previousPlatform;
  late _FailurePreferences platform;
  late SharedPreferences prefs;
  late RecoveryIntentStore store;
  late SupabaseClient client;
  late AuthProvider auth;
  late PasswordRecoveryProvider recovery;
  late DateTime now;
  late bool offline;
  late int gets;
  late int puts;

  Map<String, dynamic> user() => {
    'id': _owner,
    'aud': 'authenticated',
    'email': 'fixture@example.invalid',
    'created_at': '2026-10-25T00:00:00Z',
  };

  PasswordRecoveryProvider provider() => PasswordRecoveryProvider(
    service: PasswordRecoveryService(),
    store: store,
    auth: auth,
    clientProvider: () => client,
    clock: () => now,
  );

  setUp(() async {
    now = DateTime.now().toUtc();
    offline = false;
    gets = puts = 0;
    SharedPreferences.setMockInitialValues({});
    previousPlatform = SharedPreferencesStorePlatform.instance;
    platform = _FailurePreferences(await previousPlatform.getAll());
    SharedPreferencesStorePlatform.instance = platform;
    prefs = await SharedPreferences.getInstance();
    store = RecoveryIntentStore(
      prefs,
      projectNamespace: 'c4-retry',
      clock: () => now,
    );
    client = SupabaseClient(
      'https://synthetic.invalid',
      'synthetic-public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MockAsyncStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/user')) {
          if (request.method == 'GET') {
            gets++;
            if (offline) throw http.ClientException('synthetic offline');
          } else if (request.method == 'PUT') {
            puts++;
          }
          return http.Response(jsonEncode(user()), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 204);
        }
        if (request.url.path.endsWith('/recover')) {
          return http.Response('{}', 200);
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
        'user': user(),
      }),
    );
    auth = AuthProvider(
      client: client,
      initialRecoveryIntentId: 'retry-intent',
    );
    recovery = provider();
    await store.write(
      PendingRecovery(
        intentId: 'retry-intent',
        requestedAt: now,
        phase: RecoveryPhase.ready,
        verifiedUserId: _owner,
      ),
    );
    await recovery.initializeFromStore();
    expect(recovery.isReady, isTrue);
  });

  tearDown(() async {
    final gate = platform.readyGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    recovery.dispose();
    auth.dispose();
    await client.dispose();
    SharedPreferencesStorePlatform.instance = previousPlatform;
  });

  Future<bool> submit() => recovery.submitNewPassword(_password, _password);

  Future<void> failRestore() async {
    offline = platform.rejectReady = true;
    expect(await submit(), isFalse);
    expect(puts, 0);
    expect(platform.readyRestoreAttempts, 1);
  }

  Future<RecoveryPhase> durablePhase() async {
    final values = await platform.getAll();
    final raw =
        values.entries
                .singleWhere((entry) => entry.key.endsWith(store.storageKey))
                .value
            as String;
    final phase = (jsonDecode(raw) as Map<String, dynamic>)['phase'];
    return RecoveryPhase.values.singleWhere((value) => value.name == phase);
  }

  for (final throws in [false, true]) {
    test(
      'GET outage plus ready restore ${throws ? 'throws' : 'returns false'} permits safe retry',
      () async {
        platform.throwOnReady = throws;
        await failRestore();
        expect(recovery.state, RecoveryState.ready);
        expect(recovery.currentIntent?.phase, RecoveryPhase.ready);
        expect(
          await durablePhase(),
          RecoveryPhase.updating,
          reason:
              'Disk marker stays conservative until a successful later write',
        );
        offline = platform.rejectReady = false;
        expect(await submit(), isTrue);
        expect(
          gets,
          3,
          reason: 'Cold verify, failed preflight, fresh retry verify',
        );
        expect(platform.updatingWrites, 2);
        expect(puts, 1);
      },
    );
  }

  test(
    'retry while write-ahead still fails never dispatches GET or PUT',
    () async {
      await failRestore();
      offline = false;
      platform.rejectUpdating = true;
      final getsBefore = gets;
      expect(await submit(), isFalse);
      expect(gets, getsBefore);
      expect(puts, 0);
      expect(recovery.isReady, isTrue);
      platform.rejectUpdating = platform.rejectReady = false;
      expect(await submit(), isTrue);
      expect(puts, 1);
    },
  );

  test(
    'retry after TTL expiry does not turn into a password request',
    () async {
      await failRestore();
      offline = platform.rejectReady = false;
      now = now.add(const Duration(minutes: PendingRecovery.ttlMinutes));
      expect(await submit(), isFalse);
      expect(puts, 0);
      expect(recovery.isReady, isFalse);
      expect(client.auth.currentSession, isNull);
    },
  );

  test(
    'cancel while failing restore is pending cannot resurrect ready',
    () async {
      offline = platform.rejectReady = true;
      platform.readyGate = Completer<void>();
      final operation = submit();
      await spinUntil(() => platform.readyRestoreAttempts == 1);
      final cancelled = recovery.cancel();
      platform.readyGate!.complete();
      expect(await operation, isFalse);
      await cancelled;
      expect(recovery.isReady, isFalse);
      expect(recovery.currentIntent, isNull);
      expect(client.auth.currentSession, isNull);
      expect(puts, 0);
    },
  );

  test('late failed restore cannot replace successor intent', () async {
    offline = platform.rejectReady = true;
    platform.readyGate = Completer<void>();
    final operation = submit();
    await spinUntil(() => platform.readyRestoreAttempts == 1);
    final successor = recovery.requestEmail('successor@example.invalid');
    final successorId = recovery.currentIntent!.intentId;
    platform.readyGate!.complete();
    expect(await operation, isFalse);
    await successor;
    expect(recovery.currentIntent?.intentId, successorId);
    expect(recovery.currentIntent?.phase, RecoveryPhase.sent);
    expect((await store.read())?.intentId, successorId);
    expect(recovery.isReady, isFalse);
    expect(puts, 0);
  });

  test(
    'cold reload of persisted updating stays uncertain and never auto-retries',
    () async {
      await failRestore();
      expect(await durablePhase(), RecoveryPhase.updating);
      await prefs.reload();
      recovery.dispose();
      recovery = provider();
      await recovery.initializeFromStore();
      expect(recovery.state, RecoveryState.uncertain);
      offline = platform.rejectReady = false;
      expect(await submit(), isFalse);
      expect(puts, 0);
    },
  );

  testWidgets(
    'combined GET and storage errors preserve form input and allow retry',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<PasswordRecoveryProvider>.value(
          value: recovery,
          child: const MaterialApp(
            home: PasswordRecoveryGate(child: Text('BACKGROUND')),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('new-password-field'));
      await tester.enterText(field, _password);
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password-field')),
        _password,
      );
      final button = find.byKey(const ValueKey('submit-new-password-btn'));
      offline = platform.rejectReady = true;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await pumpRecoveryUntil(
        tester,
        () => !recovery.isProcessing && recovery.errorMessage != null,
      );
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, _password);
      expect(recovery.currentIntent?.phase, RecoveryPhase.ready);
      expect(puts, 0);
      offline = platform.rejectReady = false;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await pumpRecoveryUntil(
        tester,
        () =>
            recovery.state == RecoveryState.completed ||
            recovery.state == RecoveryState.error,
      );
      expect(recovery.state, RecoveryState.completed);
      expect(puts, 1);
      expect(find.text('BACKGROUND'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
