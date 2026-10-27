import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/auth/services/account_access_service.dart';

void main() {
  group('AccountAccess Model Tests', () {
    test('fromJson deserializes valid enabled account', () {
      final access = AccountAccess.fromJson({
        'subjectId': '11111111-1111-4111-8111-111111111111',
        'role': 'admin',
        'revision': 5,
        'state': 'enabled',
        'sessionValid': true,
      });

      expect(access.subjectId, '11111111-1111-4111-8111-111111111111');
      expect(access.role, 'admin');
      expect(access.isAdmin, isTrue);
      expect(access.revision, 5);
      expect(access.state, 'enabled');
      expect(access.sessionValid, isTrue);
      expect(access.isEnabled, isTrue);
      expect(access.isLocked, isFalse);
    });

    test('locked account flags isLocked true and isEnabled false', () {
      final access = AccountAccess.fromJson({
        'subjectId': '22222222-2222-4222-8222-222222222222',
        'role': 'customer',
        'revision': 2,
        'state': 'locked',
        'sessionValid': true,
      });

      expect(access.isLocked, isTrue);
      expect(access.isEnabled, isFalse);
      expect(access.isAdmin, isFalse);
    });
  });

  group('AccountAccessService Unit Tests', () {
    test('empty token throws AccountAccessDenied unauthorized immediately', () async {
      final service = AccountAccessService();
      expect(
        () => service.verify('   '),
        throwsA(isA<AccountAccessDenied>().having((e) => e.code, 'code', 'unauthorized')),
      );
    });

    test('injected verifier returning enabled session yields valid AccountAccess', () async {
      final service = AccountAccessService(
        injectedVerifier: (token) async => {
          'subjectId': '11111111-1111-4111-8111-111111111111',
          'role': 'customer',
          'revision': 3,
          'state': 'enabled',
          'sessionValid': true,
        },
      );

      final access = await service.verify('valid.jwt.token');
      expect(access.subjectId, '11111111-1111-4111-8111-111111111111');
      expect(access.role, 'customer');
      expect(access.isEnabled, isTrue);
    });

    test('injected verifier with locked account throws AccountAccessDenied account_locked', () async {
      final service = AccountAccessService(
        injectedVerifier: (token) async => {
          'subjectId': '11111111-1111-4111-8111-111111111111',
          'role': 'customer',
          'revision': 4,
          'state': 'locked',
          'sessionValid': true,
        },
      );

      expect(
        () => service.verify('valid.jwt.token'),
        throwsA(isA<AccountAccessDenied>().having((e) => e.code, 'code', 'account_locked')),
      );
    });

    test('injected verifier with invalid session throws AccountAccessDenied invalid_session', () async {
      final service = AccountAccessService(
        injectedVerifier: (token) async => {
          'subjectId': '11111111-1111-4111-8111-111111111111',
          'role': 'customer',
          'revision': 4,
          'state': 'enabled',
          'sessionValid': false,
        },
      );

      expect(
        () => service.verify('valid.jwt.token'),
        throwsA(isA<AccountAccessDenied>().having((e) => e.code, 'code', 'invalid_session')),
      );
    });
  });
}
