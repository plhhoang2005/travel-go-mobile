import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_account_lifecycle_service.dart';

import 'editable_local_store_test.dart' as records;
import 'local_account_lifecycle_test.dart' as accounts;
import 'local_trip_store_test.dart' as stores;

class ReplyAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  ReplyAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonReply(Object? body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Future<void> withProof(
  Future<void> Function(AccountSessionProof, LocalAccountLifecycleService) body,
) async {
  await stores.runWithStore((ctx) async {
    final session = accounts.sessionFor(records.ownerA);
    final lifecycle = LocalAccountLifecycleService(
      storeLoader: () async => ctx.store,
      sessionReader: () => session,
      registryPath: '${ctx.tempDir.path}/account_cache_lifecycle_v1.json',
    );
    try {
      await lifecycle.establishAccount(freshAuthentication: true);
      await body(lifecycle.captureProof(), lifecycle);
    } finally {
      await lifecycle.close();
    }
  });
}

EditableTripService service(
  LocalAccountLifecycleService lifecycle,
  Future<ResponseBody> Function(RequestOptions) respond, {
  bool Function(AccountSessionProof)? current,
}) => EditableTripService(
  projectUrl: 'https://staging.example.test',
  publicKey: 'synthetic-public',
  isCurrentProof: current ?? lifecycle.isCurrentProof,
  adapter: ReplyAdapter(respond),
);

Map<String, Object?> ack({EditableHead? head}) => {
  'status': 'committed',
  'receipt': EditableRecordCodec.receiptJson(
    records.ack(records.attempt()).receipt!,
  ),
  'head': EditableRecordCodec.headJson(head ?? records.head()),
};

Map<String, Object?> summary({
  String kind = 'editable_v2',
  String id = records.tripId,
  String owner = records.ownerA,
  String createdAt = '2026-10-15T00:00:00.000Z',
}) => {
  'kind': kind,
  'tripId': id,
  'ownerId': owner,
  'title': 'Huế',
  'destinationName': 'Huế',
  'createdAt': createdAt,
  'version': kind == 'legacy_v1' ? null : 1,
};

Matcher failure(EditableRemoteFailure kind) =>
    throwsA(isA<EditableRemoteException>().having((e) => e.kind, 'kind', kind));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'update and delete bind trip, base version and the original request key',
    () async {
      await withProof((proof, lifecycle) async {
        for (final op in ['update', 'delete']) {
          final text = op == 'delete'
              ? EditableTripCodec.canonicalJson({
                  'op': op,
                  'tripId': records.tripId,
                  'expectedVersion': 1,
                })
              : EditableTripCodec.canonicalJson({
                  'payloadText': records.head().payloadText,
                  'contentDigest': records.head().contentDigest,
                  'commands': [],
                });
          final attempt = EditablePendingAttempt(
            requestId: records.requestId,
            ownerId: records.ownerA,
            operation: op,
            tripId: records.tripId,
            expectedVersion: 1,
            requestText: text,
            requestDigest: EditableTripCodec.digestText(text),
            contentDigest: op == 'delete' ? null : records.head().contentDigest,
          );
          final remote = service(lifecycle, (options) async {
            expect(options.uri.path, '/rest/v1/rpc/${op}_editable_trip_v2');
            expect(options.data, {
              'p_trip_id': records.tripId,
              'p_expected_version': 1,
              'p_request_id': records.requestId,
              if (op != 'delete') 'p_request_text': text,
              if (op != 'delete') 'p_request_digest': attempt.requestDigest,
            });
            return jsonReply({
              'status': op == 'delete' ? 'deleted' : 'committed',
              'receipt': {
                ...EditableRecordCodec.receiptJson(
                  records.ack(records.attempt()).receipt!,
                ),
                'operation': op,
                'resultVersion': 2,
                'requestDigest': attempt.requestDigest,
                'contentDigest': attempt.contentDigest,
              },
              'head': op == 'delete'
                  ? null
                  : EditableRecordCodec.headJson(records.head(version: 2)),
            });
          });
          try {
            final result = op == 'delete'
                ? await remote.delete(proof: proof, attempt: attempt)
                : await remote.update(proof: proof, attempt: attempt);
            expect(result.receipt!.resultVersion, 2);
            expect(
              result.status,
              op == 'delete'
                  ? EditableMutationStatus.deleted
                  : EditableMutationStatus.committed,
            );
          } finally {
            remote.close();
          }
        }
      });
    },
  );

  test(
    'lookup of a deleted imported trip retains its original create receipt',
    () async {
      await withProof((proof, lifecycle) async {
        final remote = service(
          lifecycle,
          (_) async => jsonReply({...ack(), 'status': 'deleted', 'head': null}),
        );
        try {
          final result = await remote.lookup(
            proof: proof,
            requestId: records.requestId,
          );
          expect(result.status, EditableMutationStatus.deleted);
          expect(result.receipt!.operation, 'create');
          expect(result.head, isNull);
        } finally {
          remote.close();
        }
      });
    },
  );

  test('create retries send frozen bytes and accept an older receipt with newer head', () async {
    await withProof((proof, lifecycle) async {
      final original = records.doc();
      final newer = original.copyWith(
        input: TripInput.fromJson({
          ...original.input.toJson(),
          'title': 'Version 3',
        }),
      );
      final calls = <Map<String, Object?>>[];
      final remote = service(lifecycle, (options) async {
        expect(options.uri.path, '/rest/v1/rpc/create_editable_trip_v2');
        expect(options.method, 'POST');
        expect(options.followRedirects, isFalse);
        expect(options.headers['Authorization'], 'Bearer ${proof.accessToken}');
        expect(options.headers['apikey'], 'synthetic-public');
        calls.add(Map<String, Object?>.from(options.data as Map));
        return jsonReply(ack(head: records.head(version: 3, document: newer)));
      });
      try {
        for (var i = 0; i < 2; i++) {
          final result = await remote.create(
            proof: proof,
            attempt: records.attempt(),
          );
          expect(result.receipt!.resultVersion, 1);
          expect(result.head!.version, 3);
          expect(
            result.head!.contentDigest,
            isNot(result.receipt!.contentDigest),
          );
        }
        expect(calls[0], calls[1]);
        expect(calls[0], {
          'p_request_id': records.requestId,
          'p_request_text': records.attempt().requestText,
          'p_request_digest': records.attempt().requestDigest,
        });
      } finally {
        remote.close();
      }
    });
  });

  test(
    'mixed list validates cursor and discriminator before any legacy decode',
    () async {
      await withProof((proof, lifecycle) async {
        const older = '00000000-0000-4000-8000-000000000049';
        final responses = <Object?>[
          {
            'items': [summary(), summary(kind: 'legacy_v1', id: older)],
            'nextCursor': {
              'createdAt': '2026-10-15T00:00:00.000Z',
              'id': older,
            },
          },
          {
            'items': [summary(kind: 'future')],
            'nextCursor': null,
          },
          {
            'items': [summary(owner: records.ownerB)],
            'nextCursor': null,
          },
          {
            'items': [summary(), summary()],
            'nextCursor': null,
          },
          {
            'items': [summary()],
            'nextCursor': {
              'createdAt': '2026-10-15T00:00:00.000Z',
              'id': older,
            },
          },
          {
            'items': [summary(id: 'bad-id')],
            'nextCursor': null,
          },
          {
            'items': [
              {...summary(), 'version': 0},
            ],
            'nextCursor': null,
          },
        ];
        final remote = service(
          lifecycle,
          (options) async => jsonReply(responses.removeAt(0)),
        );
        try {
          final page = await remote.list(proof: proof, limit: 2);
          expect(page.items.map((e) => e.kind), [
            OwnedTripKind.editableV2,
            OwnedTripKind.legacyV1,
          ]);
          expect(page.nextCursor!.id, older);
          for (var i = 0; i < 6; i++) {
            await expectLater(
              remote.list(proof: proof),
              failure(EditableRemoteFailure.protocol),
            );
          }
        } finally {
          remote.close();
        }
      });
    },
  );

  test(
    'read and lookup reject forged identities, content and receipt bindings',
    () async {
      await withProof((proof, lifecycle) async {
        final valid = ack();
        final head = valid['head'] as Map<String, Object?>;
        final receipt = valid['receipt'] as Map<String, Object?>;
        final bad = <Map<String, Object?>>[
          {
            ...valid,
            'head': {...head, 'ownerId': records.ownerB},
          },
          {
            ...valid,
            'head': {...head, 'tripId': records.requestId},
          },
          {
            ...valid,
            'head': {...head, 'contentDigest': '0' * 64},
          },
          {
            ...valid,
            'receipt': {...receipt, 'requestId': records.tripId},
          },
          {
            ...valid,
            'receipt': {...receipt, 'resultVersion': 2},
          },
          {
            ...valid,
            'receipt': {...receipt, 'contentDigest': '0' * 64},
          },
          {
            ...valid,
            'receipt': {...receipt, 'requestDigest': '0' * 64},
          },
        ];
        final remote = service(
          lifecycle,
          (_) async => jsonReply(bad.removeAt(0)),
        );
        try {
          for (var i = 0; i < 7; i++) {
            await expectLater(
              remote.create(proof: proof, attempt: records.attempt()),
              failure(EditableRemoteFailure.protocol),
            );
          }
        } finally {
          remote.close();
        }
        final unavailable = service(
          lifecycle,
          (o) async => jsonReply(
            o.uri.path.endsWith('get_editable_trip_v2')
                ? {'status': 'unavailable', 'head': null}
                : {'status': 'not_found', 'head': null, 'receipt': null},
          ),
        );
        try {
          expect(
            await unavailable.read(proof: proof, tripId: records.tripId),
            isNull,
          );
          expect(
            (await unavailable.lookup(
              proof: proof,
              requestId: records.requestId,
            )).status,
            EditableMutationStatus.notFound,
          );
          await expectLater(
            unavailable.create(proof: proof, attempt: records.attempt()),
            failure(EditableRemoteFailure.protocol),
          );
        } finally {
          unavailable.close();
        }
      });
    },
  );

  test(
    'delayed success or HTTP error cannot publish under a stale proof',
    () async {
      await withProof((proof, lifecycle) async {
        for (final status in [200, 403]) {
          var current = true;
          final started = Completer<void>();
          final response = Completer<ResponseBody>();
          final remote = service(lifecycle, (_) {
            started.complete();
            return response.future;
          }, current: (_) => current);
          try {
            final request = remote.lookup(
              proof: proof,
              requestId: records.requestId,
            );
            final rejected = expectLater(request, throwsA(isA<StateError>()));
            await started.future;
            current = false;
            response.complete(jsonReply(ack(), status));
            await rejected;
          } finally {
            remote.close();
          }
        }
      });
    },
  );

  test(
    'missing RPC differs from uncertain timeout and never exposes server text',
    () async {
      await withProof((proof, lifecycle) async {
        final missing = service(
          lifecycle,
          (_) async => jsonReply({
            'code': 'PGRST202',
            'message': 'secret server text',
          }, 404),
        );
        final timeout = service(
          lifecycle,
          (o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.receiveTimeout,
          ),
        );
        try {
          await expectLater(
            missing.create(proof: proof, attempt: records.attempt()),
            failure(EditableRemoteFailure.deploymentBlocked),
          );
          await expectLater(
            timeout.create(proof: proof, attempt: records.attempt()),
            failure(EditableRemoteFailure.uncertain),
          );
        } finally {
          missing.close();
          timeout.close();
        }
      });
    },
  );

  test(
    'strict transport rejects duplicate JSON keys and unsafe origins',
    () async {
      for (final url in [
        'http://example.test',
        'https://a@b.test',
        'https://b.test/x',
        'https://b.test:8443',
        'https://b.test/?x=1',
      ]) {
        expect(
          () => EditableTripService(
            projectUrl: url,
            publicKey: 'public',
            isCurrentProof: (_) => true,
          ),
          throwsArgumentError,
        );
      }
      await withProof((proof, lifecycle) async {
        final remote = service(
          lifecycle,
          (_) async => ResponseBody.fromString(
            '{"status":"not_found","status":"not_found","receipt":null,"head":null}',
            200,
          ),
        );
        try {
          await expectLater(
            remote.lookup(proof: proof, requestId: records.requestId),
            failure(EditableRemoteFailure.protocol),
          );
        } finally {
          remote.close();
        }
      });
    },
  );
}
