// Integration tests for TravelGO Catalogue Save -> Auto-Publish -> Customer Visibility pipeline.
// Verifies dynamic SQL payload -> Node bundle projection -> Dart PublicCatalogueParser & Providers.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/providers/admin_catalogue_provider.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/auth/models/user_model.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/place_visit_details_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';

const bool kRunCatalogueFlowSql = bool.fromEnvironment('RUN_CATALOGUE_FLOW_SQL', defaultValue: false);
const String kCatalogueFlowFixture = String.fromEnvironment('TRAVELGO_CATALOGUE_FLOW_FIXTURE');

PublicCatalogueSnapshot createSnapshot({
  int version = 1,
  List<Map<String, dynamic>> destinations = const [],
  List<Map<String, dynamic>> visitPlaces = const [],
}) {
  final bundle = {
    'contract': 'travelgo.discovery.release.v2',
    'schemaVersion': 2,
    'version': version,
    'preparedAt': '2026-10-23T10:00:00.000Z',
    'catalogue': {
      'sources': [],
      'destinations': destinations,
    },
    'visitDetails': {
      'sources': [],
      'packages': [],
      'places': visitPlaces,
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
    publishedAt: DateTime.parse('2026-10-23T10:00:00Z'),
  );

  return PublicCatalogueParser.parse(
    payloadText: payloadText,
    manifest: manifest,
    now: DateTime.parse('2026-10-23T12:00:00Z'),
    origin: 'storage',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> loadFixtureData() {
    String resolvedPath = kCatalogueFlowFixture;
    if (resolvedPath.isEmpty) {
      resolvedPath = '.dart_tool/travelgo-visibility/flow_fixtures.json';
    }

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      if (kRunCatalogueFlowSql) {
        fail('RUN_CATALOGUE_FLOW_SQL is true but fixture not found at: $resolvedPath');
      }
      return const {};
    }

    final text = file.readAsStringSync().replaceFirst('\uFEFF', '');
    return jsonDecode(text) as Map<String, dynamic>;
  }

  group('Admin Catalogue Save -> Publish -> Customer Visibility Flow (D3 & D4)', () {
    final fixtures = loadFixtureData();
    final hasFixtures = fixtures.isNotEmpty && fixtures['cases'] != null;

    test('integration: customer app reads admin-created destination and place', () {
      if (!hasFixtures) {
        if (kRunCatalogueFlowSql) fail('Fixture missing under RUN_CATALOGUE_FLOW_SQL');
        return; // Skip when run without fixture in isolated local test
      }

      final cases = fixtures['cases'] as Map<String, dynamic>;
      final baseline = cases['baseline'] as Map<String, dynamic>;
      final created = cases['created'] as Map<String, dynamic>;

      final manifest = DiscoveryManifest.fromJson(created['manifest'] as Map<String, dynamic>);
      final bundleText = created['bundlePayloadText'] as String;

      final snapshot = PublicCatalogueParser.parse(
        payloadText: bundleText,
        manifest: manifest,
        now: DateTime.now().toUtc(),
        origin: 'storage',
      );

      final baselineDestCount = baseline['activeDestinationsCount'] as int;
      final baselinePlaceCount = baseline['activePlacesCount'] as int;

      // Invariant: Dynamic counts increased (not fixed to 72/12!)
      expect(snapshot.catalogue.destinations.length, baselineDestCount + 1);
      final allPlaces = snapshot.catalogue.destinations.expand((d) => d.places).toList();
      expect(allPlaces.length, baselinePlaceCount + 1);

      // Verify created destination and place IDs exist
      final destId = created['destinationId'] as String;
      final placeId = created['placeId'] as String;
      expect(snapshot.catalogue.destinations.any((d) => d.id == destId), isTrue);
      expect(allPlaces.any((p) => p.id == placeId), isTrue);

      // Verify visit details facts exist for new place
      expect(snapshot.visits.places.containsKey(placeId), isTrue);
      final visit = snapshot.visits.places[placeId]!;
      expect(visit.placeId, placeId);
      expect(visit.price.status, 'unverified');
      expect(visit.hours.status, 'unverified');
    });

    test('integration: customer app sees updated destination and place content', () {
      if (!hasFixtures) {
        if (kRunCatalogueFlowSql) fail('Fixture missing under RUN_CATALOGUE_FLOW_SQL');
        return;
      }

      final cases = fixtures['cases'] as Map<String, dynamic>;
      final updated = cases['updated'] as Map<String, dynamic>;

      final manifest = DiscoveryManifest.fromJson(updated['manifest'] as Map<String, dynamic>);
      final bundleText = updated['bundlePayloadText'] as String;

      final snapshot = PublicCatalogueParser.parse(
        payloadText: bundleText,
        manifest: manifest,
        now: DateTime.now().toUtc(),
        origin: 'storage',
      );

      final destId = updated['destinationId'] as String;
      final placeId = updated['placeId'] as String;

      final dest = snapshot.catalogue.destinations.firstWhere((d) => d.id == destId);
      expect(dest.name, 'Điểm đến Demo Đã Cập Nhật');
      expect(dest.imageUrl, 'https://example.invalid/demo-dest.jpg');

      final place = dest.places.firstWhere((p) => p.id == placeId);
      expect(place.name, 'Địa điểm Demo Đã Sửa Tên');
      expect(place.imageUrl, 'https://example.invalid/demo-place.jpg');
    });

    test('integration: archived records hidden from customer but visible in admin', () {
      if (!hasFixtures) {
        if (kRunCatalogueFlowSql) fail('Fixture missing under RUN_CATALOGUE_FLOW_SQL');
        return;
      }

      final cases = fixtures['cases'] as Map<String, dynamic>;
      final baseline = cases['baseline'] as Map<String, dynamic>;
      final archived = cases['archived'] as Map<String, dynamic>;

      final manifest = DiscoveryManifest.fromJson(archived['manifest'] as Map<String, dynamic>);
      final bundleText = archived['bundlePayloadText'] as String;

      final customerSnapshot = PublicCatalogueParser.parse(
        payloadText: bundleText,
        manifest: manifest,
        now: DateTime.now().toUtc(),
        origin: 'storage',
      );

      final destId = archived['destinationId'] as String;
      final placeId = archived['placeId'] as String;

      // Invariant: customer app DOES NOT see archived destination or place
      expect(customerSnapshot.catalogue.destinations.any((d) => d.id == destId), isFalse);
      final activePlaces = customerSnapshot.catalogue.destinations.expand((d) => d.places).toList();
      expect(activePlaces.any((p) => p.id == placeId), isFalse);

      // Customer count returns back to baseline
      expect(customerSnapshot.catalogue.destinations.length, baseline['activeDestinationsCount']);

      // Invariant: Admin payload STILL retains archived records with isActive == false
      final adminPayload = archived['adminPayload'] as Map<String, dynamic>;
      final adminInventory = adminPayload['inventory'] as Map<String, dynamic>;
      final adminDests = adminInventory['destinations'] as List;
      final adminPlaces = adminInventory['places'] as List;

      final archivedDestInAdmin = adminDests.firstWhere((d) => (d as Map)['id'] == destId) as Map;
      expect(archivedDestInAdmin['isActive'], isFalse);

      final archivedPlaceInAdmin = adminPlaces.firstWhere((p) => (p as Map)['id'] == placeId) as Map;
      expect(archivedPlaceInAdmin['isActive'], isFalse);
    });

    test('pipeline: Admin save auto-publishes and updates customer PublicCatalogueProvider & DiscoveryProvider', () async {
      // Setup customer side
      late PublicCatalogueSnapshot currentSnapshot;
      currentSnapshot = createSnapshot(version: 1, destinations: []);

      final fakeRepo = _MockPublicRepo(() => currentSnapshot);
      final publicProvider = PublicCatalogueProvider(repository: fakeRepo);
      final discoveryProvider = DiscoveryProvider(
        publicSnapshotLoader: (force) async {
          await publicProvider.refresh(force: force);
          return publicProvider.snapshot!;
        },
      );
      final visitProvider = PlaceVisitDetailsProvider(
        now: DateTime.now,
        repositoryFactory: (_) => throw UnimplementedError(),
      );

      await publicProvider.load();
      discoveryProvider.bindPublicSnapshot(publicProvider.snapshot!);
      visitProvider.bindPublicSnapshot(publicProvider.snapshot!);

      expect(discoveryProvider.catalogue?.destinations.length, 0);

      // Setup admin side
      final fakeAdminService = _MockAdminCatalogueService();
      final fakePubService = _MockAdminPublicationService();
      final authProvider = AuthProvider();
      await authProvider.quickDemoLogin(UserRole.admin);

      final adminProvider = AdminCatalogueProvider(
        service: fakeAdminService,
        publicationService: fakePubService,
        authProvider: authProvider,
        onPublished: (op) async {
          // New release snapshot with added destination
          currentSnapshot = createSnapshot(
            version: op.version ?? 2,
            destinations: [
              {
                'id': 'dest-pipeline',
                'name': 'Điểm Đến Tự Xuất Bản',
                'slug': 'dest-pipeline',
                'region': 'Miền Trung',
                'places': [],
              }
            ],
          );

          await publicProvider.refresh(force: true);
          discoveryProvider.bindPublicSnapshot(publicProvider.snapshot!);
          visitProvider.bindPublicSnapshot(publicProvider.snapshot!);
        },
      );

      // Admin clicks Save on a new destination
      const newDraft = AdminDestinationDraft(
        name: 'Điểm Đến Tự Xuất Bản',
        slug: 'dest-pipeline',
        region: 'Miền Trung',
        description: 'Mô tả pipeline',
      );

      final ok = await adminProvider.submitDestination(newDraft, 'Create destination');
      expect(ok, isTrue);
      expect(adminProvider.savePhase, AdminCatalogueSavePhase.published);

      // Invariant: Customer discovery provider now sees the new destination without separate publish screen!
      expect(discoveryProvider.catalogue?.destinations.length, 1);
      expect(discoveryProvider.catalogue?.destinations.first.id, 'dest-pipeline');
      expect(discoveryProvider.catalogue?.destinations.first.name, 'Điểm Đến Tự Xuất Bản');
      expect(visitProvider.version, 2);
    });
  });
}

class _MockPublicRepo implements PublicCatalogueRepository {
  final PublicCatalogueSnapshot Function() snapshotProvider;
  _MockPublicRepo(this.snapshotProvider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PublicCatalogueSnapshot> load() async => snapshotProvider();

  @override
  Future<PublicRefreshResult> refresh({bool force = false}) async {
    return PublicRefreshResult(snapshot: snapshotProvider(), updated: true);
  }
}

class _MockAdminCatalogueService implements AdminCatalogueService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AdminCatalogueSnapshot> command({
    required String requestId,
    required int expectedRevision,
    required Map<String, Object?> command,
    required String reason,
  }) async {
    return AdminCatalogueSnapshot(
      revision: expectedRevision + 1,
      payload: const {},
      history: const [],
      destinations: const [],
      places: const [],
    );
  }
}

class _MockAdminPublicationService implements AdminPublicationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PublicationPreview> preview({
    required String requestId,
    required int draftRevision,
  }) async {
    return PublicationPreview(
      previewId: 'prev-flow',
      sourceRevision: draftRevision,
      expectedActiveVersion: 1,
      previewDigest: 'digest-flow',
      summary: const PublicationSummary(added: 1, changed: 0, hidden: 0),
      warnings: const [],
      blockers: const [],
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<PublicationOperation> publish({
    required String requestId,
    required PublicationPreview preview,
    required int expectedDraftRevision,
    required int expectedActiveVersion,
  }) async {
    return PublicationOperation(
      id: 'op-flow',
      state: 'completed',
      version: expectedActiveVersion + 1,
      sourceRevision: expectedDraftRevision,
    );
  }
}
