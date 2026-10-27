// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

import 'local_trip_store_test.dart' as local_fixtures;
import 'password_recovery_authority_test.dart' show syntheticJwt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final outcome in [
    'valid',
    'wrong',
    'expired',
    'offline',
    'no-session',
  ]) {
    test('lifecycle signup OTP $outcome obeys server authority', () async {
      await local_fixtures.runWithStore((ctx) async {
        const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        final user = {
          'id': owner,
          'aud': 'authenticated',
          'email': 'fixture@example.invalid',
          'created_at': '2026-10-25T00:00:00Z',
        };
        var verifies = 0;
        var serverChecks = 0;
        final client = SupabaseClient(
          'https://synthetic.invalid',
          'synthetic-public',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/verify')) {
              verifies++;
              final payload = jsonDecode(request.body) as Map;
              expect(payload['type'], 'signup');
              expect(payload['email'], 'fixture@example.invalid');
              if (outcome == 'offline') {
                throw http.ClientException('synthetic offline');
              }
              if (outcome == 'wrong' || outcome == 'expired') {
                return http.Response('{"msg":"invalid or expired OTP"}', 403);
              }
              return http.Response(
                jsonEncode({
                  if (outcome != 'no-session') ...{
                    'access_token': syntheticJwt(owner),
                    'refresh_token': 'synthetic-refresh',
                    'token_type': 'bearer',
                    'expires_in': 3600,
                  },
                  'user': user,
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/user')) {
              serverChecks++;
              return http.Response(jsonEncode(user), 200);
            }
            return http.Response('{}', 204);
          }),
        );
        final lifecycle = LocalAccountLifecycleService(
          storeLoader: () async => ctx.store,
          sessionReader: () => client.auth.currentSession,
          registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
          verifySubject: (token) async =>
              (await client.auth.getUser(token)).user!.id,
        );
        final auth = AuthProvider(
          client: client,
          lifecycleLoader: () async => lifecycle,
          trustedRoleFetcher: (_) async => 'customer',
        );
        try {
          await auth.initialization;
          expect(
            await auth.verifyOtp('123456', email: 'fixture@example.invalid'),
            outcome == 'valid',
          );
          expect(verifies, 1);
          expect(auth.isAuthenticated, outcome == 'valid');
          expect(
            lifecycle.handle?.ownerId,
            outcome == 'valid' ? owner : isNull,
          );
          if (outcome == 'valid') {
            expect(serverChecks, greaterThanOrEqualTo(1));
            expect(auth.currentUser?.role, UserRole.customer);
          } else {
            expect(auth.currentUser, isNull);
          }
        } finally {
          auth.dispose();
          await lifecycle.close();
          await client.dispose();
        }
      });
    });
  }
  group('Task R2: OTP Server Authority Verification', () {
    test('rejects non-6-digit tokens without dispatching network or mutating state', () async {
      int requestCount = 0;
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requestCount++;
          return http.Response('{"error": "unexpected"}', 500);
        }),
      );

      final auth = AuthProvider(client: client);

      for (final invalidCode in ['abcdef', '12345', '1234567', '', '  ', '12 456']) {
        final result = await auth.verifyOtp(invalidCode, email: 'test@travelgo.vn');
        expect(result, isFalse);
        expect(auth.isAuthenticated, isFalse);
        expect(auth.currentUser, isNull);
        expect(auth.errorMessage, contains('6 chữ số'));
      }

      expect(requestCount, 0, reason: 'SDK must not be invoked for invalid formats');
    });

    test('rejects missing or invalid email format', () async {
      int requestCount = 0;
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requestCount++;
          return http.Response('{"error": "unexpected"}', 500);
        }),
      );

      final auth = AuthProvider(client: client);

      expect(await auth.verifyOtp('123456', email: null), isFalse);
      expect(await auth.verifyOtp('123456', email: ''), isFalse);
      expect(await auth.verifyOtp('123456', email: 'no-at-sign'), isFalse);
      expect(requestCount, 0);
      expect(auth.currentUser, isNull);
    });

    test('rejects arbitrary code when client is unavailable without creating synthetic user', () async {
      final auth = AuthProvider(); // client is null
      final result = await auth.verifyOtp('123456', email: 'real@travelgo.vn');
      expect(result, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.errorMessage, isNotNull);
    });

    test('rejects when server returns invalid or expired OTP error', () async {
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/auth/v1/verify')) {
            return http.Response(
              jsonEncode({
                'code': 400,
                'msg': 'Token has expired or is invalid',
                'error_code': 'otp_expired',
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      final auth = AuthProvider(client: client);
      final result = await auth.verifyOtp('654321', email: 'user@travelgo.vn');

      expect(result, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.errorMessage, isNotNull);
    });

    test('rejects when server returns user without session', () async {
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/auth/v1/verify')) {
            // Return user without access_token / session
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'u-no-session-123',
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'user@travelgo.vn',
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      final auth = AuthProvider(client: client);
      final result = await auth.verifyOtp('123456', email: 'user@travelgo.vn');

      expect(result, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('accepts valid OTP with active session, establishes account and calls trusted role fetcher', () async {
      String? fetchedUserId;
      final client = SupabaseClient(
        'https://mock.supabase.co',
        'mock-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/auth/v1/verify')) {
            return http.Response(
              jsonEncode({
                'access_token': 'mock-access-token-123',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'mock-refresh-token-123',
                'user': {
                  'id': 'u-real-999',
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'real@travelgo.vn',
                  'phone': '0988776655',
                  'user_metadata': {
                    'full_name': 'Thành Viên Thật',
                    'role': 'customer',
                  },
                  'app_metadata': {'provider': 'email'},
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"error":"not_found"}', 404);
        }),
      );

      final auth = AuthProvider(
        client: client,
        trustedRoleFetcher: (uid) async {
          fetchedUserId = uid;
          return 'customer';
        },
      );

      final result = await auth.verifyOtp('123456', email: 'real@travelgo.vn');

      expect(result, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.id, 'u-real-999');
      expect(auth.currentUser!.email, 'real@travelgo.vn');
      expect(auth.currentUser!.role, UserRole.customer);
      expect(fetchedUserId, 'u-real-999');
    });
  });
}
