import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';

class FakePublicCatalogueRepository implements PublicCatalogueRepository {
  PublicCatalogueSnapshot? cannedSnapshot;
  bool throwOnRefresh = false;
  int loadCalls = 0;
  int refreshCalls = 0;
  final List<bool> forceHistory = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PublicCatalogueSnapshot> load() async {
    loadCalls++;
    return cannedSnapshot ?? _createDummySnapshot(1);
  }

  @override
  Future<PublicRefreshResult> refresh({bool force = false}) async {
    refreshCalls++;
    forceHistory.add(force);
    if (throwOnRefresh) {
      throw Exception('Network unreachable');
    }
    final snap = cannedSnapshot ?? _createDummySnapshot(2);
    return PublicRefreshResult(
      snapshot: snap,
      updated: true,
    );
  }

  static PublicCatalogueSnapshot _createDummySnapshot(int version) {
    final bundle = {
      'contract': 'travelgo.discovery.release.v2',
      'schemaVersion': 2,
      'version': version,
      'preparedAt': '2026-10-23T10:00:00.000Z',
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
    final sha = sha256.convert(rawBytes).toString();

    final manifest = DiscoveryManifest(
      contract: 'travelgo.discovery.manifest.v2',
      schemaVersion: 2,
      version: version,
      objectKey: 'releases/v2/$version.json',
      sha256: sha,
      byteLength: rawBytes.length,
      publishedAt: DateTime.utc(2026, 10, 23, 10),
    );

    return PublicCatalogueParser.parse(
      payloadText: payloadText,
      manifest: manifest,
      now: DateTime.utc(2026, 10, 23, 12),
      origin: 'test',
    );
  }
}

void main() {
  late FakePublicCatalogueRepository repository;
  late PublicCatalogueProvider provider;

  setUp(() {
    repository = FakePublicCatalogueRepository();
    provider = PublicCatalogueProvider(repository: repository);
  });

  tearDown(() {
    provider.dispose();
  });

  group('PublicCatalogueProvider Unit & Lifecycle Tests', () {
    test('initialize loads cache/seed first and immediately forces refresh', () async {
      await provider.initialize();

      expect(repository.loadCalls, 1);
      expect(repository.refreshCalls, 1);
      expect(repository.forceHistory, [true]);
      expect(provider.snapshot, isNotNull);
      expect(provider.snapshot!.version, 2);
      expect(provider.lastRefreshedAt, isNotNull);
      expect(provider.error, isNull);
    });

    test('onResume triggers force refresh to bypass 5-minute cooldown for demo', () async {
      await provider.load();
      expect(repository.refreshCalls, 0);

      await provider.onResume();
      expect(repository.refreshCalls, 1);
      expect(repository.forceHistory.last, isTrue);
    });

    test('refresh retains last-known-good snapshot on network error', () async {
      // First load initial good snapshot
      await provider.load();
      final initialSnapshot = provider.snapshot;
      expect(initialSnapshot, isNotNull);

      // Now configure refresh to fail
      repository.throwOnRefresh = true;
      await provider.refresh(force: true);

      // Snapshot MUST be retained, never wiped out
      expect(provider.snapshot, same(initialSnapshot));
      expect(provider.error, contains('Network unreachable'));
      expect(provider.isLoading, isFalse);
    });
  });
}
