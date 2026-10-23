import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_cache.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

Map<String, dynamic> buildValidBundle({int version = 1}) => {
      'contract': 'travelgo.discovery.release.v2',
      'schemaVersion': 2,
      'version': version,
      'preparedAt': '2026-10-20T10:00:00.000Z',
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

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late String fixtureText;
  late DiscoveryManifest validManifest;
  late PublicCatalogueSnapshot validSnapshot;
  PublicCatalogueCache? cache;

  setUpAll(() {
    final bundle = buildValidBundle(version: 1);
    fixtureText = jsonEncode(bundle);
    final rawBytes = utf8.encode(fixtureText);
    final computedSha = sha256.convert(rawBytes).toString();

    validManifest = DiscoveryManifest(
      contract: 'travelgo.discovery.manifest.v2',
      schemaVersion: 2,
      version: 1,
      objectKey: 'releases/v2/1.json',
      sha256: computedSha,
      byteLength: rawBytes.length,
      publishedAt: DateTime.parse('2026-10-20T10:00:00Z'),
    );

    validSnapshot = PublicCatalogueParser.parse(
      payloadText: fixtureText,
      manifest: validManifest,
      now: DateTime.parse('2026-10-20T12:00:00Z'),
      origin: 'test',
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pub_cat_cache_test_');
    dbPath = '${tempDir.path}/test_cache.db';
  });

  tearDown(() async {
    await cache?.close();
    cache = null;
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('write and read roundtrip preserves manifest and snapshot', () async {
    cache = PublicCatalogueCache(
      databasePath: () async => dbPath,
      databaseFactory: databaseFactory,
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    await cache!.write(validSnapshot);
    final readBack = await cache!.read();

    expect(readBack, isNotNull);
    expect(readBack!.version, 1);
    expect(readBack.sha256, validManifest.sha256);
    expect(readBack.origin, 'cache');
    expect(readBack.catalogue.destinations.length, 1);
  });

  test('cache_write_failure_keeps_ram_and_disk_version: failed transaction keeps prior row', () async {
    cache = PublicCatalogueCache(
      databasePath: () async => dbPath,
      databaseFactory: databaseFactory,
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    // Initial successful write (v1)
    await cache!.write(validSnapshot);

    // Attempt invalid write: snapshot with no payloadText
    final invalidSnapshot = PublicCatalogueSnapshot(
      version: 2,
      sha256: 'a' * 64,
      origin: 'test',
      manifest: DiscoveryManifest(
        contract: 'travelgo.discovery.manifest.v2',
        schemaVersion: 2,
        version: 2,
        objectKey: 'releases/v2/2.json',
        sha256: 'a' * 64,
        byteLength: 10,
        publishedAt: DateTime.parse('2026-10-20T17:00:00Z'),
      ),
      catalogue: validSnapshot.catalogue,
      visits: validSnapshot.visits,
      fetchedAt: DateTime.now(),
      payloadText: null, // missing payload text causes FormatException
    );

    expect(
      () => cache!.write(invalidSnapshot),
      throwsA(isA<FormatException>()),
    );

    // Disk remains at version 1
    final diskSnapshot = await cache!.read();
    expect(diskSnapshot, isNotNull);
    expect(diskSnapshot!.version, 1);
    expect(diskSnapshot.sha256, validManifest.sha256);
  });

  test('version downgrade is rejected with FormatException and retains disk version', () async {
    cache = PublicCatalogueCache(
      databasePath: () async => dbPath,
      databaseFactory: databaseFactory,
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    // Build valid version 2 snapshot
    final v2Bundle = buildValidBundle(version: 2);
    final v2Text = jsonEncode(v2Bundle);
    final v2Bytes = utf8.encode(v2Text);
    final v2Sha = sha256.convert(v2Bytes).toString();

    final v2Manifest = DiscoveryManifest(
      contract: 'travelgo.discovery.manifest.v2',
      schemaVersion: 2,
      version: 2,
      objectKey: 'releases/v2/2.json',
      sha256: v2Sha,
      byteLength: v2Bytes.length,
      publishedAt: DateTime.parse('2026-10-20T11:00:00Z'),
    );

    final v2Snapshot = PublicCatalogueParser.parse(
      payloadText: v2Text,
      manifest: v2Manifest,
      now: DateTime.parse('2026-10-20T12:00:00Z'),
      origin: 'test',
    );

    await cache!.write(v2Snapshot);

    // Attempt to write version 1
    expect(
      () => cache!.write(validSnapshot),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('version_downgrade'))),
    );

    // Verify disk still has version 2
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final rows = await db.query('public_discovery_release_v2', where: 'id = ?', whereArgs: [1]);
    expect(rows.first['version'], 2);
    await db.close();
  });

  test('version conflict (same version different hash) is rejected', () async {
    cache = PublicCatalogueCache(
      databasePath: () async => dbPath,
      databaseFactory: databaseFactory,
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    await cache!.write(validSnapshot);

    // Same version 1 but different hash
    final conflictingSnapshot = PublicCatalogueSnapshot(
      version: 1,
      sha256: 'f' * 64,
      origin: 'test',
      manifest: DiscoveryManifest(
        contract: 'travelgo.discovery.manifest.v2',
        schemaVersion: 2,
        version: 1,
        objectKey: 'releases/v2/1.json',
        sha256: 'f' * 64,
        byteLength: validManifest.byteLength,
        publishedAt: validManifest.publishedAt,
      ),
      catalogue: validSnapshot.catalogue,
      visits: validSnapshot.visits,
      fetchedAt: DateTime.now(),
      payloadText: fixtureText,
    );

    expect(
      () => cache!.write(conflictingSnapshot),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('version_conflict'))),
    );
  });

  test('corrupted row is revalidated on read and raises FormatException', () async {
    cache = PublicCatalogueCache(
      databasePath: () async => dbPath,
      databaseFactory: databaseFactory,
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    await cache!.write(validSnapshot);

    // Tamper with disk payload
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.update(
      'public_discovery_release_v2',
      {'payload_text': '{"contract": "damaged"}'},
      where: 'id = ?',
      whereArgs: [1],
    );
    await db.close();

    expect(
      () => cache!.read(),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('cache_corrupted'))),
    );
  });
}
