import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

class MockDioAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (handler == null) throw StateError('MockDioAdapter handler not set');
    return handler!(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResp(dynamic body, int status) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('AdminCatalogueService RPC and Wire Tests', () {
    late Directory tempDir;
    late LocalTripStore store;
    late LocalAccountLifecycleService lifecycle;
    late Dio dio;
    late MockDioAdapter adapter;
    late AdminCatalogueService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cat_svc_test_');
      final dbFile = File('${tempDir.path}/test_trips.db');
      store = LocalTripStore(
        databaseFactory: databaseFactoryFfi,
        databasePath: dbFile.path,
      );
      await store.open();

      final session = Session.fromJson({
        'access_token': 'cat.token.test',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': '22222222-2222-4222-8222-222222222222',
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
        verifySubject: (tok) async => '22222222-2222-4222-8222-222222222222',
      );
      await lifecycle.establishAccount(freshAuthentication: true);

      adapter = MockDioAdapter();
      dio = Dio()..httpClientAdapter = adapter;

      service = AdminCatalogueService(
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

    test('read() calls admin_discovery RPC and parses snapshot', () async {
      adapter.handler = (opts) async {
        expect(opts.uri.toString(), 'https://example.supabase.co/rest/v1/rpc/admin_discovery');
        expect(opts.headers['Authorization'], 'Bearer cat.token.test');
        expect(opts.headers['apikey'], 'anon-key-test');

        return jsonResp({
          'revision': 2,
          'payload': {
            'inventory': {
              'destinations': [
                {
                  'id': 'da-nang',
                  'name': 'Đà Nẵng',
                  'slug': 'da-nang',
                  'region': 'Miền Trung',
                  'description': 'Thành phố biển',
                  'isActive': true,
                }
              ],
              'places': [],
            },
            'places': [],
            'sources': [],
          },
          'history': [
            {
              'revision': 2,
              'reason': 'Initial baseline',
              'changedAt': '2026-10-23T10:00:00Z',
              'payloadHash': 'hash123',
            }
          ],
        }, 200);
      };

      final snapshot = await service.read();
      expect(snapshot.revision, 2);
      expect(snapshot.destinations.length, 1);
      expect(snapshot.destinations.first.name, 'Đà Nẵng');
      expect(snapshot.history.length, 1);
    });

    test('command() calls admin_discovery_command RPC with typed parameters', () async {
      adapter.handler = (opts) async {
        expect(opts.uri.toString(), 'https://example.supabase.co/rest/v1/rpc/admin_discovery_command');
        expect(opts.data['p_request_id'], 'req-uuid-1');
        expect(opts.data['p_expected_revision'], 2);
        expect(opts.data['p_command']['command'], 'createDestination');
        expect(opts.data['p_reason'], 'Add destination');

        return jsonResp({
          'revision': 3,
          'payload': {
            'inventory': {
              'destinations': [
                {
                  'id': 'phu-yen',
                  'name': 'Phú Yên',
                  'slug': 'phu-yen',
                  'region': 'Nam Trung Bộ',
                  'description': 'Xứ hoa vàng',
                  'isActive': true,
                }
              ],
              'places': [],
            },
            'places': [],
          },
          'history': [],
          'entityId': 'phu-yen',
        }, 200);
      };

      final updated = await service.command(
        requestId: 'req-uuid-1',
        expectedRevision: 2,
        command: {
          'command': 'createDestination',
          'name': 'Phú Yên',
          'slug': 'phu-yen',
          'region': 'Nam Trung Bộ',
          'description': 'Xứ hoa vàng',
        },
        reason: 'Add destination',
      );

      expect(updated.revision, 3);
      expect(updated.entityId, 'phu-yen');
      expect(updated.destinations.first.id, 'phu-yen');
    });

    test('503 or network failure on command marks outcomeUncertain true', () async {
      adapter.handler = (opts) async {
        return jsonResp({'code': 'upstream_unavailable', 'message': 'Gateway timeout'}, 503);
      };

      expect(
        () => service.command(
          requestId: 'req-2',
          expectedRevision: 1,
          command: {'command': 'archivePlace', 'placeId': 'p-1'},
          reason: 'Archive',
        ),
        throwsA(isA<AdminFailure>()
            .having((f) => f.code, 'code', 'upstream_unavailable')
            .having((f) => f.outcomeUncertain, 'outcomeUncertain', isTrue)),
      );
    });
  });
}
