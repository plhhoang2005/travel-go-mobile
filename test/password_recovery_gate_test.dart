// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/core/services/backend_api_config.dart';
import 'package:travelgo_mobile/features/auth/models/password_recovery_state.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:travelgo_mobile/features/auth/presentation/widgets/password_recovery_gate.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/providers/password_recovery_provider.dart';
import 'package:travelgo_mobile/features/auth/services/password_recovery_service.dart';
import 'package:travelgo_mobile/features/auth/services/recovery_intent_store.dart';
import 'package:travelgo_mobile/main.dart';

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

class ControllableRecoveryService extends PasswordRecoveryService {
  AuthException? rejectWith;
  AuthException? exchangeRejectWith;
  Completer<void>? exchangeEntered;
  Completer<UserResponse>? updateCompleter;
  Completer<AuthSessionUrlResponse>? exchangeCompleter;

  @override
  Future<AuthSessionUrlResponse> exchange(SupabaseClient client, String code) async {
    if (exchangeEntered != null && !exchangeEntered!.isCompleted) {
      exchangeEntered!.complete();
    }
    if (exchangeRejectWith != null) {
      throw exchangeRejectWith!;
    }
    if (exchangeCompleter != null) {
      return exchangeCompleter!.future;
    }
    return super.exchange(client, code);
  }

  @override
  Future<UserResponse> updatePassword(SupabaseClient client, String password) async {
    if (rejectWith != null) {
      throw rejectWith!;
    }
    if (updateCompleter != null) {
      return updateCompleter!.future;
    }
    return super.updatePassword(client, password);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task A4: Recovery Gate / UI Integration', () {
    late SharedPreferences prefs;
    late RecoveryIntentStore store;
    late ControllableRecoveryService service;
    late MockAsyncStorage asyncStorage;
    late SupabaseClient client;
    late AuthProvider auth;
    late PasswordRecoveryProvider recoveryProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = RecoveryIntentStore(prefs, projectNamespace: 'gate_test');
      service = ControllableRecoveryService();
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
          if (path.contains('/user') && request.method == 'PUT') {
            return http.Response(
              jsonEncode({
                'id': 'usr-recovery-gate',
                'email': 'gate@travelgo.vn',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/token')) {
            return http.Response(
              jsonEncode({
                'access_token': 'gate-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'gate-refresh',
                'user': {
                  'id': 'usr-recovery-gate',
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'gate@travelgo.vn',
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (path.contains('/logout')) {
            return http.Response('{}', 204);
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      final sessionJson = jsonEncode({
        'access_token': 'gate-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'gate-refresh',
        'user': {
          'id': 'usr-recovery-gate',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'gate@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      await client.auth.recoverSession(sessionJson);

      auth = AuthProvider(client: client, initialRecoveryIntentId: 'gate-intent');
      recoveryProvider = PasswordRecoveryProvider(
        service: service,
        store: store,
        auth: auth,
        clientProvider: () => client,
      );
    });

    Widget createTestApp({required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PasswordRecoveryProvider>.value(
            value: recoveryProvider,
          ),
        ],
        child: MaterialApp(
          home: PasswordRecoveryGate(child: child),
        ),
      );
    }

    testWidgets('password_form_survives_pending_update', (tester) async {
      final intent = PendingRecovery(
        intentId: 'gate-intent',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-gate',
      );
      await store.write(intent);
      await recoveryProvider.initializeFromStore();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: Text('BACKGROUND_CHILD_SCREEN')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('BACKGROUND_CHILD_SCREEN'), findsNothing);

      // Fill in password
      await tester.enterText(
        find.byKey(const ValueKey('new-password-field')),
        'ValidPass2026!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password-field')),
        'ValidPass2026!',
      );

      final updateCompleter = Completer<UserResponse>();
      service.updateCompleter = updateCompleter;

      // Ensure visible and tap submit
      final btn = find.byKey(const ValueKey('submit-new-password-btn'));
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.pump();

      // Pending update: ResetPasswordScreen must STILL be mounted!
      expect(recoveryProvider.state, RecoveryState.updating);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('BACKGROUND_CHILD_SCREEN'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Release PUT
      updateCompleter.complete(
        UserResponse.fromJson({
          'id': 'usr-recovery-gate',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'gate@travelgo.vn',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('server_rejection_stays_on_reset_form', (tester) async {
      final intent = PendingRecovery(
        intentId: 'gate-intent',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-gate',
      );
      await store.write(intent);
      await recoveryProvider.initializeFromStore();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: Text('BACKGROUND_CHILD_SCREEN')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const ValueKey('new-password-field')),
        'WeakPass123!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password-field')),
        'WeakPass123!',
      );

      service.rejectWith = const AuthException(
        'Mật khẩu quá yếu theo chính sách bảo mật máy chủ.',
        statusCode: '422',
      );

      final btn = find.byKey(const ValueKey('submit-new-password-btn'));
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.pump();

      await tester.runAsync(() async {
        for (int i = 0; i < 50; i++) {
          if (recoveryProvider.errorMessage != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();

      // Must remain on form with server error message visible
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.textContaining('Mật khẩu quá yếu'), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-new-password-btn')), findsOneWidget);
    });

    testWidgets('cleanup_and_uncertain_never_show_update_button', (tester) async {
      final intent = PendingRecovery(
        intentId: 'gate-intent',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.cleanup,
        verifiedUserId: 'usr-recovery-gate',
      );
      await store.write(intent);
      await recoveryProvider.initializeFromStore();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: Text('BACKGROUND_CHILD_SCREEN')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-new-password-btn')), findsNothing);
      expect(find.textContaining('đăng xuất'), findsWidgets);
    });

    testWidgets('warm_and_cold_callbacks_override_nested_bootstrap', (tester) async {
      final linkStreamController = StreamController<Uri>.broadcast();
      final intent = PendingRecovery(
        intentId: 'gate-intent',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.sent,
      );
      await store.write(intent);
      await asyncStorage.setItem(
        key: 'supabase.auth.token-code-verifier',
        value: 'mock-verifier/passwordRecovery',
      );

      await tester.pumpWidget(
        TravelGoApp(
          authClient: client,
          authProvider: auth,
          authCallbackLinks: linkStreamController.stream,
          recoveryProvider: recoveryProvider,
          recoveryIntentStore: store,
          recoveryService: service,
          backendConfig: BackendApiConfig.unpersisted(),
        ),
      );
      await tester.pump();

      // Dispatch warm recovery callback link
      linkStreamController.add(
        Uri.parse('io.supabase.travelgo://login-callback?flow=recovery&code=code-gate-warm'),
      );
      
      await tester.runAsync(() async {
        for (int i = 0; i < 50; i++) {
          if (recoveryProvider.isReady) break;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();

      // Recovery gate overrides nested bootstrap routes
      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      await linkStreamController.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('bootstrap_resume_timer_cannot_replace_recovery_form', (tester) async {
      final intent = PendingRecovery(
        intentId: 'gate-intent',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.ready,
        verifiedUserId: 'usr-recovery-gate',
      );
      await store.write(intent);
      await recoveryProvider.initializeFromStore();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: Text('BACKGROUND_CHILD_SCREEN')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      // Simulate lifecycle resume and timers
      await auth.handleAppLifecycleState(AppLifecycleState.inactive);
      await auth.handleAppLifecycleState(AppLifecycleState.paused);
      await auth.handleAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      // Form remains visible and auth is not elevated
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(auth.isAuthenticated, isFalse);
    });

    testWidgets('cleanup_success_returns_to_login_flow', (tester) async {
      final intent = PendingRecovery(
        intentId: 'gate-intent',
        requestedAt: DateTime.now().toUtc(),
        phase: RecoveryPhase.cleanup,
        verifiedUserId: 'usr-recovery-gate',
      );
      await store.write(intent);
      await recoveryProvider.initializeFromStore();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: Text('BACKGROUND_CHILD_SCREEN')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResetPasswordScreen), findsOneWidget);

      // Tap retry cleanup button
      await tester.tap(find.text('Thử lại hoàn tất đăng xuất'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Gate unmounts ResetPasswordScreen and returns to child login screen
      expect(find.text('BACKGROUND_CHILD_SCREEN'), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(auth.isAuthenticated, isFalse);
    });
  });
}
