import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'admin_catalogue_service_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late LocalTripStore store;
  late LocalAccountLifecycleService lifecycle;
  late fixture.MockDioAdapter adapter;
  late AdminPublicationService service;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('c7-publication-service-');
    store = LocalTripStore(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${dir.path}/db',
    );
    await store.open();
    final session = Session.fromJson({
      'access_token': 'fixture.token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': '22222222-2222-4222-8222-222222222222',
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'created_at': '2026-10-23T00:00:00Z',
      },
    })!..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    lifecycle = LocalAccountLifecycleService(
      storeLoader: () async => store,
      sessionReader: () => session,
      registryPath: '${dir.path}/registry.json',
      verifySubject: (_) async => '22222222-2222-4222-8222-222222222222',
    );
    await lifecycle.establishAccount(freshAuthentication: true);
    adapter = fixture.MockDioAdapter();
    service = AdminPublicationService(
      dio: Dio()..httpClientAdapter = adapter,
      projectOrigin: Uri.parse('https://example.test'),
      publicKey: 'fixture',
      lifecycleLoader: () async => lifecycle,
    );
  });
  tearDown(() async {
    await lifecycle.close();
    await store.close();
    await dir.delete(recursive: true);
  });
  test(
    'operation sends only requested identity with separate auth transport',
    () async {
      adapter.handler = (opts) async {
        expect(opts.data['request'], {'operationId': 'op-a'});
        expect(opts.headers['Authorization'], 'Bearer fixture.token');
        return fixture.jsonResp({
          'operation': {
            'id': 'op-a',
            'state': 'completed',
            'version': 2,
            'sourceRevision': 3,
          },
        }, 200);
      };
      final result = await service.operation('op-a');
      expect(result.isCompleted, isTrue);
      expect(result.sourceRevision, 3);
    },
  );
  for (final status in [200, 500]) {
    test('operation rejects stale lifecycle proof on HTTP $status', () async {
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      adapter.handler = (_) {
        started.complete();
        return response.future;
      };
      final result = service.operation('op-a');
      final assertion = expectLater(
        result,
        throwsA(
          isA<AdminFailure>().having((f) => f.code, 'code', 'stale_session'),
        ),
      );
      await started.future;
      lifecycle.invalidateAccountContext();
      response.complete(
        fixture.jsonResp({
          'operation': {'id': 'op-a', 'state': 'completed', 'version': 2},
        }, status),
      );
      await assertion;
    });
  }
}
