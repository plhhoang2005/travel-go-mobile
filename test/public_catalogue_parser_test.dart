// Tests for PublicCatalogueParser, cross-runtime digest parity, and strict V2 error handling.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

void main() {
  group('PublicCatalogueParser & Cross-Runtime Digest Tests (Task P4)', () {
    late Map<String, dynamic> vectorsJson;

    setUpAll(() {
      final file = File('test/fixtures/discovery_release_v2_vectors.json');
      vectorsJson = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('same_raw_fixture_has_same_cross_runtime_digest: parses vector and verifies SHA-256', () {
      final vectors = (vectorsJson['vectors'] as List).cast<Map<String, dynamic>>();
      final standard = vectors.firstWhere((v) => v['name'] == 'standard_active_catalogue');

      final bundle = {
        'contract': 'travelgo.discovery.release.v2',
        'schemaVersion': 2,
        'version': 1,
        'preparedAt': '2026-10-23T10:00:00.000Z',
        'catalogue': {
          'sources': [
            {
              'id': 'src-vn-01',
              'title': 'Cổng du lịch',
              'publisher': 'Tổng cục Du lịch',
              'url': 'https://vietnam.travel',
              'checkedAt': '2026-10-20T08:00:00Z',
            }
          ],
          'destinations': [
            {
              'id': 'da-nang',
              'name': 'Đà Nẵng',
              'slug': 'da-nang',
              'region': 'Miền Trung',
              'places': [
                {
                  'id': 'da-nang/ba-na-hills',
                  'destinationId': 'da-nang',
                  'name': 'Bà Nà Hills',
                  'slug': 'ba-na-hills',
                  'sourceRefs': ['src-vn-01'],
                }
              ],
            }
          ],
        },
        'visitDetails': {
          'sources': [
            {
              'id': 'src-vn-01',
              'title': 'Cổng du lịch',
              'publisher': 'Tổng cục Du lịch',
              'url': 'https://vietnam.travel',
              'checkedAt': '2026-10-20T08:00:00Z',
            }
          ],
          'packages': [],
          'places': [
            {
              'placeId': 'da-nang/ba-na-hills',
              'visitScopeLabel': 'Khu du lịch',
              'price': {
                'status': 'unverified',
                'options': [],
                'evidence': {
                  'reviewState': 'unverified',
                  'sourceIds': ['src-vn-01'],
                  'conditions': ['Chưa xác minh'],
                  'unresolvedIssues': ['Chưa có thông tin'],
                },
              },
              'hours': {
                'status': 'unverified',
                'rules': [],
                'notes': ['Chưa xác minh'],
                'evidence': {
                  'reviewState': 'unverified',
                  'sourceIds': ['src-vn-01'],
                  'conditions': ['Chưa xác minh'],
                  'unresolvedIssues': ['Chưa có thông tin'],
                },
              },
            }
          ],
        },
      };

      final payloadText = jsonEncode(bundle);
      final rawBytes = utf8.encode(payloadText);
      final computedSha = sha256.convert(rawBytes).toString();

      final manifest = DiscoveryManifest(
        contract: 'travelgo.discovery.manifest.v2',
        schemaVersion: 2,
        version: 1,
        objectKey: 'releases/v2/1.json',
        sha256: computedSha,
        byteLength: rawBytes.length,
        publishedAt: DateTime.utc(2026, 10, 23, 10, 0),
      );

      final snapshot = PublicCatalogueParser.parse(
        payloadText: payloadText,
        manifest: manifest,
        now: DateTime.utc(2026, 10, 23, 12, 0),
      );

      expect(snapshot.sha256, computedSha);
      expect(snapshot.catalogue.destinations.map((d) => d.id).toList(), standard['expectedDestinationIds']);
      expect(snapshot.catalogue.destinations.first.places.map((p) => p.id).toList(), standard['expectedPlaceIds']);
      expect(snapshot.visits.bindingKind, 'release_v2');
    });

    test('all-hidden catalogue parses cleanly with 0 destinations and 0 places', () {
      final bundle = {
        'contract': 'travelgo.discovery.release.v2',
        'schemaVersion': 2,
        'version': 2,
        'preparedAt': '2026-10-23T10:05:00.000Z',
        'catalogue': {
          'sources': [],
          'destinations': [],
        },
        'visitDetails': {
          'sources': [],
          'packages': [],
          'places': [],
        },
      };

      final payloadText = jsonEncode(bundle);
      final rawBytes = utf8.encode(payloadText);
      final computedSha = sha256.convert(rawBytes).toString();

      final manifest = DiscoveryManifest(
        contract: 'travelgo.discovery.manifest.v2',
        schemaVersion: 2,
        version: 2,
        objectKey: 'releases/v2/2.json',
        sha256: computedSha,
        byteLength: rawBytes.length,
        publishedAt: DateTime.utc(2026, 10, 23, 10, 5),
      );

      final snapshot = PublicCatalogueParser.parse(
        payloadText: payloadText,
        manifest: manifest,
        now: DateTime.utc(2026, 10, 23, 12, 0),
      );

      expect(snapshot.catalogue.destinations, isEmpty);
      expect(snapshot.visits.places, isEmpty);
    });

    test('sha256 integrity mismatch throws FormatException', () {
      const payloadText = '{"contract":"travelgo.discovery.release.v2","schemaVersion":2,"version":1}';
      final rawBytes = utf8.encode(payloadText);

      final manifest = DiscoveryManifest(
        contract: 'travelgo.discovery.manifest.v2',
        schemaVersion: 2,
        version: 1,
        objectKey: 'releases/v2/1.json',
        sha256: '0' * 64, // Bad SHA!
        byteLength: rawBytes.length,
        publishedAt: DateTime.utc(2026, 10, 23, 10, 0),
      );

      expect(
        () => PublicCatalogueParser.parse(
          payloadText: payloadText,
          manifest: manifest,
          now: DateTime.now(),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
