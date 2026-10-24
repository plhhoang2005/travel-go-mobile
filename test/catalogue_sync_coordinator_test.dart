import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/models/unified_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_sync_coordinator.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';
import 'package:travelgo_mobile/features/trip_planner/models/ai_context_grounding.dart';

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
    return cannedSnapshot ?? createDummySnapshot(1);
  }

  @override
  Future<PublicRefreshResult> refresh({bool force = false}) async {
    refreshCalls++;
    forceHistory.add(force);
    if (throwOnRefresh) {
      throw Exception('Network unreachable (503)');
    }
    final snap = cannedSnapshot ?? createDummySnapshot(2);
    return PublicRefreshResult(
      snapshot: snap,
      updated: true,
    );
  }

  static PublicCatalogueSnapshot createDummySnapshot(
    int version, {
    String placeId = 'hue/citadel',
    String placeName = 'Đại Nội Huế',
    String destId = 'hue',
  }) {
    final bundle = {
      'contract': 'travelgo.discovery.release.v2',
      'schemaVersion': 2,
      'version': version,
      'preparedAt': '2026-10-23T10:00:00.000Z',
      'catalogue': {
        'sources': [
          {
            'id': 'src-hue',
            'title': 'Bảo tồn Cố đô Huế',
            'publisher': 'Huế Heritage',
            'url': 'https://hueworldheritage.org.vn',
            'checkedAt': '2026-10-20',
          }
        ],
        'destinations': [
          {
            'id': destId,
            'name': 'Huế',
            'region': 'Miền Trung',
            'description': 'Cố đô cổ kính',
            'places': [
              {
                'id': placeId,
                'name': placeName,
                'slug': 'dai-noi',
                'description': 'Kinh thành Huế',
                'sourceRefs': ['src-hue'],
                'latitude': 16.469,
                'longitude': 107.578,
              }
            ],
          }
        ],
      },
      'visitDetails': {
        'sources': [
          {
            'id': 'src-hue',
            'title': 'Bảo tồn Cố đô Huế',
            'publisher': 'Huế Heritage',
            'url': 'https://hueworldheritage.org.vn',
            'checkedAt': '2026-10-20',
          }
        ],
        'packages': [],
        'places': [
          {
            'placeId': placeId,
            'visitScopeLabel': 'Đại Nội Huế có vé',
            'price': {
              'status': 'priced',
              'options': [
                {
                  'id': 'standard-adult',
                  'label': 'Vé người lớn',
                  'audience': 'Người lớn',
                  'amountVnd': 200000,
                  'currency': 'VND',
                  'unit': 'người/lượt',
                  'included': ['Đại Nội'],
                  'excluded': [],
                  'conditions': [],
                }
              ],
              'evidence': {
                'reviewState': 'reviewed',
                'sourceIds': ['src-hue'],
                'checkedAt': '2026-10-20',
                'conditions': [],
                'unresolvedIssues': [],
              },
            },
            'hours': {
              'status': 'scheduled',
              'rules': [
                {
                  'label': 'Giờ tiêu chuẩn',
                  'weekdays': [1, 2, 3, 4, 5, 6, 7],
                  'startMinutes': 420, // 07:00
                  'endMinutes': 1080, // 18:00
                  'admissionCutoffMinutes': 1020, // 17:00
                  'endDayOffset': 0,
                }
              ],
              'notes': [],
              'evidence': {
                'reviewState': 'reviewed',
                'sourceIds': ['src-hue'],
                'checkedAt': '2026-10-20',
                'conditions': [],
                'unresolvedIssues': [],
              },
            },
            'notes': [],
          }
        ],
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Packet P1: UnifiedCatalogueSnapshot Invariants', () {
    test('atomically constructs from PublicCatalogueSnapshot with matching metadata and visits', () {
      final pubSnapshot = FakePublicCatalogueRepository.createDummySnapshot(1);
      final unified = UnifiedCatalogueSnapshot.fromPublicSnapshot(pubSnapshot);

      expect(unified.version, 1);
      expect(unified.releaseSha256, pubSnapshot.sha256);
      expect(unified.placeIds.contains('hue/citadel'), isTrue);
      expect(unified.containsPlace('hue/citadel'), isTrue);
      expect(unified.containsPlace('unknown/place'), isFalse);

      final places = unified.placesForDestination('hue');
      expect(places.length, 1);
      expect(places.first.name, 'Đại Nội Huế');
    });

    test('lookupPlace returns both reference and visit details atomically', () {
      final pubSnapshot = FakePublicCatalogueRepository.createDummySnapshot(1);
      final unified = UnifiedCatalogueSnapshot.fromPublicSnapshot(pubSnapshot);

      final (ref, facts) = unified.lookupPlace('hue/citadel');
      expect(ref, isNotNull);
      expect(ref!.name, 'Đại Nội Huế');
      expect(facts, isNotNull);
      expect(facts!.visitScopeLabel, 'Đại Nội Huế có vé');
      expect(facts.price.status, 'priced');

      final (nonExistentRef, nonExistentFacts) = unified.lookupPlace('missing/place');
      expect(nonExistentRef, isNull);
      expect(nonExistentFacts, isNull);
    });

    test('evaluatePlace executes deterministic R1-R5 grounding checks', () {
      final pubSnapshot = FakePublicCatalogueRepository.createDummySnapshot(1);
      final unified = UnifiedCatalogueSnapshot.fromPublicSnapshot(pubSnapshot);

      // Đi trong giờ mở cửa (08:00 - 10:00 -> 480 - 600)
      final valid = unified.evaluatePlace(
        placeId: 'hue/citadel',
        date: DateTime.utc(2026, 12, 15),
        startMinute: 480,
        endMinute: 600,
      );
      expect(valid.availability, AvailabilityState.open);
      expect(valid.amountVnd, 200000);

      // Đi sau giờ đóng cửa (18:30 - 19:30 -> 1110 - 1170)
      final invalid = unified.evaluatePlace(
        placeId: 'hue/citadel',
        date: DateTime.utc(2026, 12, 15),
        startMinute: 1110,
        endMinute: 1170,
      );
      expect(invalid.availability, AvailabilityState.closed);
    });
  });

  group('Packet P1: CatalogueSyncCoordinator Atomic Coordination', () {
    late FakePublicCatalogueRepository repo;
    late CatalogueSyncCoordinator coordinator;
    late DateTime simulatedTime;

    setUp(() {
      simulatedTime = DateTime.utc(2026, 10, 24, 8, 0);
      repo = FakePublicCatalogueRepository();
      coordinator = CatalogueSyncCoordinator(
        repository: repo,
        clock: () => simulatedTime,
        minRefreshInterval: const Duration(minutes: 15),
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('loadLocal loads snapshot from repository and notifies listeners', () async {
      var notified = false;
      coordinator.addListener(() => notified = true);

      expect(coordinator.hasSnapshot, isFalse);
      final snapshot = await coordinator.loadLocal();

      expect(snapshot.version, 1);
      expect(coordinator.hasSnapshot, isTrue);
      expect(coordinator.snapshot?.version, 1);
      expect(repo.loadCalls, 1);

      // Subsequent loadLocal call reuses existing snapshot without calling repo
      final cached = await coordinator.loadLocal();
      expect(cached.version, 1);
      expect(repo.loadCalls, 1);

      await Future<void>.delayed(Duration.zero);
      expect(notified, isTrue);
    });

    test('sync updates snapshot and sets updated status', () async {
      await coordinator.loadLocal();
      expect(coordinator.snapshot?.version, 1);

      final result = await coordinator.sync(force: true);

      expect(result.updated, isTrue);
      expect(result.status, UnifiedSyncStatus.updated);
      expect(result.snapshot.version, 2);
      expect(coordinator.snapshot?.version, 2);
      expect(coordinator.lastSuccessfulSyncAt, simulatedTime);
      expect(repo.refreshCalls, 1);
    });

    test('sync deduplicates concurrent requests (Single-Flight)', () async {
      await coordinator.loadLocal();

      // Gọi đồng thời 3 lệnh sync(force: true)
      final f1 = coordinator.sync(force: true);
      final f2 = coordinator.sync(force: true);
      final f3 = coordinator.sync(force: true);

      final results = await Future.wait([f1, f2, f3]);

      // Tất cả đều nhận cùng snapshot version 2
      expect(results[0].snapshot.version, 2);
      expect(results[1].snapshot.version, 2);
      expect(results[2].snapshot.version, 2);

      // Nhưng repository.refresh chỉ bị gọi ĐÚNG 1 LẦN
      expect(repo.refreshCalls, 1);
    });

    test('preserves Last-Known-Good snapshot when network refresh fails', () async {
      await coordinator.loadLocal();
      expect(coordinator.snapshot?.version, 1);

      // Mô phỏng mất mạng khi refresh
      repo.throwOnRefresh = true;
      final result = await coordinator.sync(force: true);

      expect(result.updated, isFalse);
      expect(result.status, UnifiedSyncStatus.error);
      expect(result.errorCode, contains('Network unreachable'));

      // Snapshot version 1 vẫn được bảo toàn nguyên vẹn (Last-Known-Good)
      expect(coordinator.snapshot?.version, 1);
      expect(coordinator.lastErrorCode, contains('Network unreachable'));
    });

    test('throttles periodic refresh when within minRefreshInterval', () async {
      await coordinator.loadLocal();
      await coordinator.sync(force: true);
      expect(repo.refreshCalls, 1);

      // Tiến thêm 5 phút (nhỏ hơn minRefreshInterval 15 phút)
      simulatedTime = simulatedTime.add(const Duration(minutes: 5));

      final throttledResult = await coordinator.sync(force: false);
      expect(throttledResult.updated, isFalse);
      expect(throttledResult.status, UnifiedSyncStatus.upToDate);
      // Không gọi thêm refresh
      expect(repo.refreshCalls, 1);

      // Nhưng nếu gọi force: true -> bắt buộc refresh
      final forcedResult = await coordinator.sync(force: true);
      expect(forcedResult.status, UnifiedSyncStatus.updated);
      expect(repo.refreshCalls, 2);
    });
  });
}

