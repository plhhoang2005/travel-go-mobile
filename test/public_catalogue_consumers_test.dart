import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/place_visit_details_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

Map<String, dynamic> buildBundle({
  int version = 1,
  List<Map<String, dynamic>> destinations = const [],
  List<Map<String, dynamic>> visitPlaces = const [],
}) => {
      'contract': 'travelgo.discovery.release.v2',
      'schemaVersion': 2,
      'version': version,
      'preparedAt': '2026-10-20T10:00:00.000Z',
      'catalogue': {
        'sources': [
          {
            'id': 'src-01',
            'title': 'Cổng du lịch',
            'publisher': 'Tổng cục Du lịch',
            'url': 'https://vietnam.travel',
            'checkedAt': '2026-10-20T08:00:00Z',
          }
        ],
        'destinations': destinations,
      },
      'visitDetails': {
        'sources': [
          {
            'id': 'src-01',
            'title': 'Cổng du lịch',
            'publisher': 'Tổng cục Du lịch',
            'url': 'https://vietnam.travel',
            'checkedAt': '2026-10-20T08:00:00Z',
          }
        ],
        'packages': [],
        'places': visitPlaces,
      },
    };

PublicCatalogueSnapshot createSnapshot({
  int version = 1,
  List<Map<String, dynamic>> destinations = const [],
  List<Map<String, dynamic>> visitPlaces = const [],
}) {
  final bundle = buildBundle(
    version: version,
    destinations: destinations,
    visitPlaces: visitPlaces,
  );
  final payloadText = jsonEncode(bundle);
  final rawBytes = utf8.encode(payloadText);
  final sha = sha256.convert(rawBytes).toString();

  final manifest = DiscoveryManifest(
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version: version,
    objectKey: 'releases/v2/$version.json',
    sha256: sha,
    byteLength: rawBytes.length,
    publishedAt: DateTime.parse('2026-10-20T10:00:00Z'),
  );

  return PublicCatalogueParser.parse(
    payloadText: payloadText,
    manifest: manifest,
    now: DateTime.parse('2026-10-20T12:00:00Z'),
    origin: 'storage',
  );
}

void main() {
  test('catalogue_and_visits_change_as_one_snapshot: version equality preserved on notification', () async {
    final discovery = DiscoveryProvider();
    final visitDetails = PlaceVisitDetailsProvider(
      now: DateTime.now,
      repositoryFactory: (_) => throw UnimplementedError('Should not be called for V2'),
    );

    final v1Snapshot = createSnapshot(
      version: 1,
      destinations: [
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
              'sourceRefs': ['src-01'],
            }
          ],
        }
      ],
      visitPlaces: [
        {
          'placeId': 'da-nang/ba-na-hills',
          'visitScopeLabel': 'Khu du lịch',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-01'],
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
              'sourceIds': ['src-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
        }
      ],
    );

    discovery.bindPublicSnapshot(v1Snapshot);
    visitDetails.bindPublicSnapshot(v1Snapshot);

    expect(discovery.version, 1);
    expect(visitDetails.version, 1);
    expect(discovery.version, visitDetails.version);
    expect(discovery.catalogue!.destinations.length, 1);
    expect(discovery.visibleDestinations.length, 1);
    expect(visitDetails.snapshot!.catalogue.places.length, 1);

    // Switch to version 2 with additional place
    final v2Snapshot = createSnapshot(
      version: 2,
      destinations: [
        {
          'id': 'da-nang',
          'name': 'Đà Nẵng Mới',
          'slug': 'da-nang',
          'region': 'Miền Trung',
          'places': [
            {
              'id': 'da-nang/ba-na-hills',
              'destinationId': 'da-nang',
              'name': 'Bà Nà Hills',
              'slug': 'ba-na-hills',
              'sourceRefs': ['src-01'],
            },
            {
              'id': 'da-nang/cau-vang',
              'destinationId': 'da-nang',
              'name': 'Cầu Vàng',
              'slug': 'cau-vang',
              'sourceRefs': ['src-01'],
            }
          ],
        }
      ],
      visitPlaces: [
        {
          'placeId': 'da-nang/ba-na-hills',
          'visitScopeLabel': 'Khu du lịch',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-01'],
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
              'sourceIds': ['src-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
        },
        {
          'placeId': 'da-nang/cau-vang',
          'visitScopeLabel': 'Cầu cảnh quan',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-01'],
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
              'sourceIds': ['src-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
        }
      ],
    );

    discovery.bindPublicSnapshot(v2Snapshot);
    visitDetails.bindPublicSnapshot(v2Snapshot);

    expect(discovery.version, 2);
    expect(visitDetails.version, 2);
    expect(discovery.version, visitDetails.version);
    expect(discovery.catalogue!.destinations.first.name, 'Đà Nẵng Mới');
    expect(discovery.catalogue!.destinations.first.places.length, 2);
    expect(visitDetails.errorCode, isNull);
  });

  test('all-hidden yields empty visible destinations state without fallback', () async {
    final discovery = DiscoveryProvider();
    final emptySnapshot = createSnapshot(
      version: 1,
      destinations: [],
      visitPlaces: [],
    );

    discovery.bindPublicSnapshot(emptySnapshot);

    expect(discovery.state, DiscoveryLoadState.ready);
    expect(discovery.catalogue!.destinations, isEmpty);
    expect(discovery.visibleDestinations, isEmpty);
  });

  test('search and region filters are preserved across snapshot updates', () async {
    final discovery = DiscoveryProvider();

    final v1Snapshot = createSnapshot(
      version: 1,
      destinations: [
        {
          'id': 'da-nang',
          'name': 'Đà Nẵng',
          'slug': 'da-nang',
          'region': 'Miền Trung',
          'places': [],
        },
        {
          'id': 'ha-noi',
          'name': 'Hà Nội',
          'slug': 'ha-noi',
          'region': 'Miền Bắc',
          'places': [],
        }
      ],
      visitPlaces: [],
    );

    discovery.bindPublicSnapshot(v1Snapshot);
    discovery.setQuery('đà nẵng');
    discovery.setRegion('Miền Trung');

    expect(discovery.query, 'đà nẵng');
    expect(discovery.region, 'Miền Trung');
    expect(discovery.visibleDestinations.length, 1);
    expect(discovery.visibleDestinations.first.id, 'da-nang');

    // Update to version 2
    final v2Snapshot = createSnapshot(
      version: 2,
      destinations: [
        {
          'id': 'da-nang',
          'name': 'Đà Nẵng Biển',
          'slug': 'da-nang',
          'region': 'Miền Trung',
          'places': [],
        },
        {
          'id': 'ha-noi',
          'name': 'Hà Nội Thủ Đô',
          'slug': 'ha-noi',
          'region': 'Miền Bắc',
          'places': [],
        }
      ],
      visitPlaces: [],
    );

    discovery.bindPublicSnapshot(v2Snapshot);

    // Filter and region remain preserved
    expect(discovery.query, 'đà nẵng');
    expect(discovery.region, 'Miền Trung');
    expect(discovery.visibleDestinations.length, 1);
    expect(discovery.visibleDestinations.first.name, 'Đà Nẵng Biển');
  });

  test('CatalogueRepository supports injectable snapshotLoader', () async {
    final snapshot = createSnapshot(
      version: 1,
      destinations: [
        {
          'id': 'mock-dest',
          'name': 'Mock Destination',
          'slug': 'mock-dest',
          'region': 'Miền Nam',
          'places': [],
        }
      ],
      visitPlaces: [],
    );

    final repo = CatalogueRepository(
      snapshotLoader: () async => snapshot.catalogue,
    );

    final catalogue = await repo.load();
    expect(catalogue.destinations.length, 1);
    expect(catalogue.destinations.first.id, 'mock-dest');
  });

  test('PlaceVisitDetailsProvider ignores independent refresh when bound to V2', () async {
    final visitDetails = PlaceVisitDetailsProvider(
      now: DateTime.now,
      repositoryFactory: (_) => throw UnimplementedError(),
    );

    final v1Snapshot = createSnapshot(
      version: 1,
      destinations: [],
      visitPlaces: [],
    );

    visitDetails.bindPublicSnapshot(v1Snapshot);
    expect(visitDetails.isBoundToV2, isTrue);

    // refresh should complete without error and without calling repositoryFactory
    await visitDetails.refresh(force: true);
    expect(visitDetails.version, 1);
  });

  test('seed_v1_to_remote_v1_different_hash_rebinds_catalogue_and_facts', () async {
    final discovery = DiscoveryProvider();
    final visitDetails = PlaceVisitDetailsProvider(
      now: DateTime.now,
      repositoryFactory: (_) => throw UnimplementedError(),
    );

    final seedSnapshot = createSnapshot(
      version: 1,
      destinations: [
        {
          'id': 'dest-seed',
          'name': 'Seed Destination',
          'slug': 'dest-seed',
          'region': 'Miền Trung',
          'places': [
            {
              'id': 'dest-seed/place-seed',
              'destinationId': 'dest-seed',
              'name': 'Seed Place',
              'slug': 'place-seed',
              'sourceRefs': ['src-01'],
            }
          ],
        }
      ],
      visitPlaces: [
        {
          'placeId': 'dest-seed/place-seed',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'checkedAt': '2026-10-20',
              'sourceIds': ['src-01'],
              'reviewState': 'unverified',
              'conditions': <String>[],
              'unresolvedIssues': <String>[],
            }
          },
          'hours': {
            'status': 'unverified',
            'rules': [],
            'notes': <String>[],
            'evidence': {
              'checkedAt': '2026-10-20',
              'sourceIds': ['src-01'],
              'reviewState': 'unverified',
              'conditions': <String>[],
              'unresolvedIssues': <String>[],
            }
          },
        }
      ],
    );

    discovery.bindPublicSnapshot(seedSnapshot);
    visitDetails.bindPublicSnapshot(seedSnapshot);

    expect(discovery.catalogue?.destinations.first.id, 'dest-seed');
    expect(visitDetails.snapshot?.catalogue.places['dest-seed/place-seed']?.placeId, 'dest-seed/place-seed');

    final remoteSnapshot = createSnapshot(
      version: 1, // Same version 1, but different content and hash
      destinations: [
        {
          'id': 'dest-remote',
          'name': 'Remote Destination',
          'slug': 'dest-remote',
          'region': 'Miền Bắc',
          'places': [
            {
              'id': 'dest-remote/place-remote',
              'destinationId': 'dest-remote',
              'name': 'Remote Place',
              'slug': 'place-remote',
              'sourceRefs': ['src-01'],
            }
          ],
        }
      ],
      visitPlaces: [
        {
          'placeId': 'dest-remote/place-remote',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'checkedAt': '2026-10-20',
              'sourceIds': ['src-01'],
              'reviewState': 'unverified',
              'conditions': <String>[],
              'unresolvedIssues': <String>[],
            }
          },
          'hours': {
            'status': 'unverified',
            'rules': [],
            'notes': <String>[],
            'evidence': {
              'checkedAt': '2026-10-20',
              'sourceIds': ['src-01'],
              'reviewState': 'unverified',
              'conditions': <String>[],
              'unresolvedIssues': <String>[],
            }
          },
        }
      ],
    );

    // Hashes must be different
    expect(seedSnapshot.manifest.sha256 != remoteSnapshot.manifest.sha256, isTrue);

    discovery.bindPublicSnapshot(remoteSnapshot);
    visitDetails.bindPublicSnapshot(remoteSnapshot);

    // Invariant: Both rebind to new catalogue and facts because sha256 changed
    expect(discovery.catalogue?.destinations.first.id, 'dest-remote');
    expect(visitDetails.snapshot?.catalogue.places['dest-remote/place-remote']?.placeId, 'dest-remote/place-remote');
  });
}
