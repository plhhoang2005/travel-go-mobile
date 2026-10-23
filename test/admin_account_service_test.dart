import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

class MockAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler == null) {
      throw StateError('MockAdapter handler not set');
    }
    return handler!(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Map<String, dynamic> body, int status) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

void main() {
  group('AdminAccount Models Parsing & Validation', () {
    test('AdminAccess.fromJson parses valid admin and rejects invalid', () {
      final valid = AdminAccess.fromJson({
        'subjectId': 'user-123',
        'role': 'admin',
        'accountRevision': 3,
        'allowed': true,
      });
      expect(valid.subjectId, 'user-123');
      expect(valid.role, 'admin');
      expect(valid.accountRevision, 3);
      expect(valid.allowed, isTrue);

      expect(
        () => AdminAccess.fromJson({'subjectId': '', 'role': 'admin', 'accountRevision': 1, 'allowed': true}),
        throwsFormatException,
      );
      expect(
        () => AdminAccess.fromJson({'subjectId': 'u1', 'role': 'customer', 'accountRevision': 1, 'allowed': true}),
        throwsFormatException,
      );
      expect(
        () => AdminAccess.fromJson({'subjectId': 'u1', 'role': 'admin', 'accountRevision': 0, 'allowed': true}),
        throwsFormatException,
      );
      expect(
        () => AdminAccess.fromJson({'subjectId': 'u1', 'role': 'admin', 'accountRevision': 1, 'allowed': false}),
        throwsFormatException,
      );
    });

    test('UserSummary.fromJson strictly checks role, state, and handles null lastSignInAt', () {
      final summary = UserSummary.fromJson({
        'id': 'u1',
        'fullName': 'Nguyen Van A',
        'email': 'a@example.com',
        'role': 'customer',
        'state': 'enabled',
        'revision': 1,
        'createdAt': '2026-10-23T10:00:00.000Z',
        'lastSignInAt': null,
        'authSynced': true,
      });

      expect(summary.id, 'u1');
      expect(summary.role, 'customer');
      expect(summary.state, 'enabled');
      expect(summary.lastSignInAt, isNull);
      expect(summary.authSynced, isTrue);

      final withSignIn = UserSummary.fromJson({
        'id': 'u2',
        'fullName': 'Admin User',
        'email': 'admin@example.com',
        'role': 'admin',
        'state': 'locked',
        'revision': 4,
        'createdAt': '2026-10-20T10:00:00.000Z',
        'lastSignInAt': '2026-10-23T08:00:00.000Z',
        'authSynced': false,
      });
      expect(withSignIn.role, 'admin');
      expect(withSignIn.isLocked, isTrue);
      expect(withSignIn.lastSignInAt, isNotNull);
      expect(withSignIn.authSynced, isFalse);

      // Unknown role fails
      expect(
        () => UserSummary.fromJson({
          'id': 'u3',
          'fullName': 'Bad Role',
          'email': 'bad@example.com',
          'role': 'moderator',
          'state': 'enabled',
          'revision': 1,
          'createdAt': '2026-10-23T10:00:00.000Z',
          'authSynced': true,
        }),
        throwsFormatException,
      );

      // Unknown state fails
      expect(
        () => UserSummary.fromJson({
          'id': 'u4',
          'fullName': 'Bad State',
          'email': 'bad@example.com',
          'role': 'customer',
          'state': 'banned',
          'revision': 1,
          'createdAt': '2026-10-23T10:00:00.000Z',
          'authSynced': true,
        }),
        throwsFormatException,
      );
    });

    test('DashboardSnapshot.fromJson parses 7/30 days and valid counts', () {
      final snap = DashboardSnapshot.fromJson({
        'asOf': '2026-10-23T12:00:00.000Z',
        'days': 7,
        'totalUsers': 120,
        'lockedUsers': 2,
        'activeAdmins': 3,
        'registrations': [
          {'date': '2026-10-23', 'count': 5}
        ],
        'draft': {
          'revision': 4,
          'activeDestinations': 12,
          'hiddenDestinations': 1,
          'activePlaces': 72,
          'hiddenPlaces': 0,
        },
        'published': {
          'version': 'v1',
          'sourceRevision': 3,
          'activeDestinations': 12,
          'activePlaces': 72,
        },
      });

      expect(snap.days, 7);
      expect(snap.totalUsers, 120);
      expect(snap.draft.revision, 4);
      expect(snap.published?.version, 'v1');

      // Invalid days (not 7 or 30) throws
      expect(
        () => DashboardSnapshot.fromJson({
          'asOf': '2026-10-23T12:00:00.000Z',
          'days': 14,
          'totalUsers': 120,
          'lockedUsers': 2,
          'activeAdmins': 3,
          'registrations': [],
          'draft': {
            'revision': 1,
            'activeDestinations': 1,
            'hiddenDestinations': 0,
            'activePlaces': 1,
            'hiddenPlaces': 0,
          },
        }),
        throwsFormatException,
      );
    });

    test('DashboardSnapshot.fromJson parses published stats with integer or string version from SQL DTO (D2)', () {
      final snapWithIntVersion = DashboardSnapshot.fromJson({
        'asOf': '2026-10-23T12:00:00.000Z',
        'days': 7,
        'totalUsers': 5,
        'lockedUsers': 0,
        'activeAdmins': 1,
        'registrations': [],
        'draft': {
          'revision': 6,
          'activeDestinations': 12,
          'hiddenDestinations': 0,
          'activePlaces': 72,
          'hiddenPlaces': 0,
        },
        'published': {
          'version': 1,
          'sourceRevision': 5,
          'activeDestinations': 12,
          'activePlaces': 72,
        },
      });

      expect(snapWithIntVersion.published, isNotNull);
      expect(snapWithIntVersion.published!.version, '1');
      expect(snapWithIntVersion.published!.sourceRevision, 5);
      expect(snapWithIntVersion.published!.activeDestinations, 12);
      expect(snapWithIntVersion.published!.activePlaces, 72);
    });
  });

  group('AdminAccountService Transport and Security', () {
    late Directory tempDir;
    late LocalTripStore store;
    late LocalAccountLifecycleService lifecycle;
    late Dio dio;
    late MockAdapter adapter;
    late AdminAccountService service;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      tempDir = await Directory.systemTemp.createTemp('admin_svc_test_');
      final dbFile = File('${tempDir.path}/test_trips.db');
      store = LocalTripStore(
        databaseFactory: databaseFactoryFfi,
        databasePath: dbFile.path,
      );
      await store.open();

      final session = Session.fromJson({
        'access_token': 'valid.token.test',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': '11111111-1111-4111-8111-111111111111',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
          'aud': 'authenticated',
          'created_at': '2026-10-23T00:00:00.000Z',
        },
      })!..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

      lifecycle = LocalAccountLifecycleService(
        storeLoader: () async => store,
        sessionReader: () => session,
        registryPath: '${tempDir.path}/lifecycle.json',
        verifySubject: (tok) async => '11111111-1111-4111-8111-111111111111',
      );
      await lifecycle.establishAccount(freshAuthentication: true);

      adapter = MockAdapter();
      dio = Dio()..httpClientAdapter = adapter;

      service = AdminAccountService(
        dio: dio,
        projectOrigin: Uri.parse('https://example.supabase.co'),
        publicKey: 'anon-key-test',
        lifecycleLoader: () async => lifecycle,
      );
    });

    tearDown(() async {
      await lifecycle.close();
      await store.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('access() dispatches valid contract envelope and parses response', () async {
      adapter.handler = (opts) async {
        expect(opts.uri.toString(), 'https://example.supabase.co/functions/v1/admin-control');
        expect(opts.headers['Authorization'], 'Bearer valid.token.test');
        expect(opts.headers['apikey'], 'anon-key-test');
        expect(opts.data['contract'], 'travelgo.admin.v1');
        expect(opts.data['action'], 'access');

        return jsonResponse({
          'status': 'ok',
          'data': {
            'subjectId': '11111111-1111-4111-8111-111111111111',
            'role': 'admin',
            'accountRevision': 2,
            'allowed': true,
          },
        }, 200);
      };

      final access = await service.access();
      expect(access.subjectId, '11111111-1111-4111-8111-111111111111');
      expect(access.role, 'admin');
      expect(access.allowed, isTrue);
    });

    test('401 response throws AdminFailure unauthorized', () async {
      adapter.handler = (opts) async {
        return jsonResponse({
          'status': 'error',
          'code': 'unauthorized',
        }, 401);
      };

      expect(
        () => service.access(),
        throwsA(isA<AdminFailure>().having((f) => f.code, 'code', 'unauthorized')),
      );
    });

    test('403 account_locked throws AdminFailure account_locked', () async {
      adapter.handler = (opts) async {
        return jsonResponse({
          'status': 'error',
          'code': 'account_locked',
        }, 403);
      };

      expect(
        () => service.access(),
        throwsA(isA<AdminFailure>().having((f) => f.code, 'code', 'account_locked')),
      );
    });

    test('403 admin_required throws AdminFailure admin_required', () async {
      adapter.handler = (opts) async {
        return jsonResponse({
          'status': 'error',
          'code': 'admin_required',
        }, 403);
      };

      expect(
        () => service.access(),
        throwsA(isA<AdminFailure>().having((f) => f.code, 'code', 'admin_required')),
      );
    });

    test('503 or network timeout on mutate marks outcomeUncertain true', () async {
      adapter.handler = (opts) async {
        return jsonResponse({
          'status': 'error',
          'code': 'upstream_unavailable',
        }, 503);
      };

      expect(
        () => service.mutate(
          requestId: 'req-1',
          targetId: 'user-2',
          expectedRevision: 1,
          action: 'lock',
          reason: 'Test lock',
        ),
        throwsA(isA<AdminFailure>()
            .having((f) => f.code, 'code', 'upstream_unavailable')
            .having((f) => f.outcomeUncertain, 'outcomeUncertain', isTrue)),
      );
    });
  });
}
