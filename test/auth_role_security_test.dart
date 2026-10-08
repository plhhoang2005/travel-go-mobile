import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

void main() {
  group('Auth Role Security & Epoch Tests (R02, DB-006)', () {
    User createFakeUser({
      required String id,
      required String email,
      Map<String, dynamic>? metadata,
    }) {
      return User(
        id: id,
        appMetadata: {},
        userMetadata: metadata ?? {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
    }

    test('Spoofed client userMetadata role=admin is ignored and defaults to customer', () async {
      final auth = AuthProvider();

      final fakeUser = createFakeUser(
        id: 'attacker-123',
        email: 'attacker@travelgo.vn',
        metadata: {
          'full_name': 'Attacker Eve',
          'role': 'admin', // Malicious client-supplied role
        },
      );

      auth.simulateSupabaseUser(fakeUser);

      expect(auth.isAuthenticated, isTrue);
      // Critical assertion: userMetadata.role cannot grant admin privileges!
      expect(auth.currentUser?.role, UserRole.customer);
      expect(auth.currentUser?.fullName, 'Attacker Eve');
      expect(auth.isDemoSession, isFalse);
    });

    test('Trusted role fetcher upgrades role to verified admin after server acknowledgement', () async {
      final completer = Completer<String?>();

      final auth = AuthProvider(
        trustedRoleFetcher: (userId) => completer.future,
      );

      final fakeUser = createFakeUser(
        id: 'real-admin-1',
        email: 'admin@travelgo.vn',
        metadata: {'full_name': 'Legit Admin'},
      );

      auth.simulateSupabaseUser(fakeUser);
      // Immediately customer
      expect(auth.currentUser?.role, UserRole.customer);

      // Complete server fetch with verified admin role
      completer.complete('admin');
      await Future<void>.delayed(Duration.zero);

      expect(auth.currentUser?.role, UserRole.admin);
    });

    test('Trusted role fetch failure retains customer role safely without breaking session', () async {
      final auth = AuthProvider(
        trustedRoleFetcher: (userId) async {
          throw Exception('Network timeout querying profiles table');
        },
      );

      final fakeUser = createFakeUser(
        id: 'customer-1',
        email: 'user@travelgo.vn',
        metadata: {'full_name': 'Normal User'},
      );

      auth.simulateSupabaseUser(fakeUser);
      await Future<void>.delayed(Duration.zero);

      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.customer);
      expect(auth.errorMessage, isNull);
    });

    test('Late role fetch response from User A is ignored after logout (epoch guard)', () async {
      final userACompleter = Completer<String?>();

      final auth = AuthProvider(
        trustedRoleFetcher: (userId) {
          if (userId == 'user-a') {
            return userACompleter.future;
          }
          return Future.value('customer');
        },
      );

      final userA = createFakeUser(
        id: 'user-a',
        email: 'usera@travelgo.vn',
      );

      auth.simulateSupabaseUser(userA);
      expect(auth.currentUser?.id, 'user-a');

      // User logs out before User A's response arrives
      auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);

      // Late response arrives from User A
      userACompleter.complete('admin');
      await Future<void>.delayed(Duration.zero);

      // Epoch has changed: late response must be dropped!
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('Late role fetch response from User A is ignored after switch to User B', () async {
      final userACompleter = Completer<String?>();

      final auth = AuthProvider(
        trustedRoleFetcher: (userId) {
          if (userId == 'user-a') {
            return userACompleter.future;
          }
          return Future.value('partner');
        },
      );

      final userA = createFakeUser(id: 'user-a', email: 'a@travelgo.vn');
      final userB = createFakeUser(id: 'user-b', email: 'b@travelgo.vn');

      auth.simulateSupabaseUser(userA);
      final epochA = auth.authEpoch;

      // Switch to User B
      auth.simulateSupabaseUser(userB);
      expect(auth.authEpoch, greaterThan(epochA));
      expect(auth.currentUser?.id, 'user-b');

      // Late response for User A arrives
      userACompleter.complete('admin');
      await Future<void>.delayed(Duration.zero);

      // Current user should remain User B with verified partner role, NOT User A's admin role!
      expect(auth.currentUser?.id, 'user-b');
      expect(auth.currentUser?.role, UserRole.partner);
    });

    test('Demo session has explicit provenance and does not masquerade as live Supabase session', () async {
      final auth = AuthProvider();

      await auth.quickDemoLogin(UserRole.admin);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.role, UserRole.admin);
      expect(auth.isDemoSession, isTrue);

      auth.logout();
      expect(auth.isDemoSession, isFalse);
    });
  });
}
