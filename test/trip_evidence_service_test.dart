import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';

import 'editable_trip_service_test.dart' as transport;
import 'trip_evidence_repository_test.dart' as evidence;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('capability is owner epoch bound and evidence list uses v3', () async {
    await transport.withProof((proof, lifecycle) async {
      final paths = <String>[];
      final remote = transport.service(lifecycle, (options) async {
        paths.add(options.uri.path);
        if (options.uri.path.endsWith('get_trip_capabilities_v1')) {
          return transport.jsonReply({'evidenceV1': true, 'ownedListV3': true});
        }
        expect(options.uri.path.endsWith('list_owned_trips_v3'), isTrue);
        return transport.jsonReply({
          'items': [transport.summary(kind: 'evidence_v1')],
          'nextCursor': null,
        });
      });
      try {
        expect(await remote.supportsEvidence(proof: proof), isTrue);
        final page = await remote.list(proof: proof);
        expect(page.items.single.kind, OwnedTripKind.evidenceV1);
        expect(
          paths.where((p) => p.endsWith('get_trip_capabilities_v1')),
          hasLength(1),
        );
      } finally {
        remote.close();
      }
    });
  });
  test('missing capability is unsupported but network and malformed capability are errors', () async {
    await transport.withProof((proof, lifecycle) async {
      for (final kind in ['missing', 'network', 'bad']) {
        final remote = transport.service(
          lifecycle,
          (o) async => kind == 'missing'
              ? transport.jsonReply({'code': 'PGRST202'}, 404)
              : kind == 'network'
              ? transport.jsonReply({}, 503)
              : transport.jsonReply({
                  'evidenceV1': 'true',
                  'ownedListV3': true,
                }),
        );
        try {
          if (kind == 'missing') {
            expect(await remote.supportsEvidence(proof: proof), isFalse);
          } else {
            await expectLater(
              remote.supportsEvidence(proof: proof),
              transport.failure(
                kind == 'network'
                    ? EditableRemoteFailure.uncertain
                    : EditableRemoteFailure.protocol,
              ),
            );
          }
        } finally {
          remote.close();
        }
      }
    });
  });
  test(
    'evidence read preserves registry and rejects wrong owner or trip',
    () async {
      await transport.withProof((proof, lifecycle) async {
        for (final bad in [false, true]) {
          final raw = evidence.evidenceHeadJson();
          if (bad) raw['ownerId'] = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
          final remote = transport.service(lifecycle, (options) async {
            expect(options.uri.path.endsWith('get_evidence_trip_v1'), isTrue);
            expect(jsonEncode(options.data), contains('p_trip_id'));
            return transport.jsonReply({'status': 'ready', 'head': raw});
          });
          try {
            final future = remote.readEvidence(
              proof: proof,
              tripId: raw['tripId'] as String,
            );
            if (bad) {
              await expectLater(
                future,
                transport.failure(EditableRemoteFailure.protocol),
              );
            } else {
              expect(
                (await future)!.evidenceEnvelope!.evidence.single.id,
                'source-a',
              );
            }
          } finally {
            remote.close();
          }
        }
      });
    },
  );
  test(
    'missing table is a deployment error rather than an unsupported capability',
    () async {
      await transport.withProof((proof, lifecycle) async {
        final remote = transport.service(
          lifecycle,
          (o) async => transport.jsonReply({'code': '42P01'}, 400),
        );
        try {
          await expectLater(
            remote.supportsEvidence(proof: proof),
            transport.failure(EditableRemoteFailure.deploymentBlocked),
          );
        } finally {
          remote.close();
        }
      });
    },
  );
}
