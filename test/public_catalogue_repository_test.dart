import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_cache.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';

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

class FakeHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  late Future<ResponseBody> Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late PublicCatalogueCache cache;
  late Dio dio;
  late FakeHttpClientAdapter adapter;
  late String fixtureText;
  late DiscoveryManifest validManifest;
  late PublicCatalogueSnapshot seedSnapshot;

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

    seedSnapshot = PublicCatalogueParser.parse(
      payloadText: fixtureText,
      manifest: validManifest,
      now: DateTime.parse('2026-10-20T12:00:00Z'),
      origin: 'seed',
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pub_cat_repo_test_');
    dbPath = '${tempDir.path}/repo_test.db';
    cache = PublicCatalogueCache(
      databasePath: () async => dbPath,
      databaseFactory: databaseFactory,
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );
    dio = Dio();
    adapter = FakeHttpClientAdapter();
    dio.httpClientAdapter = adapter;
  });

  tearDown(() async {
    await cache.close();
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('load() returns seed when cache is empty', () async {
    var seedCalls = 0;
    final repo = PublicCatalogueRepository(
      seedLoader: () async {
        seedCalls++;
        return seedSnapshot;
      },
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    final snapshot = await repo.load();
    expect(snapshot.version, 1);
    expect(snapshot.origin, 'seed');
    expect(seedCalls, 1);

    // Second call uses in-memory snapshot
    final second = await repo.load();
    expect(identical(second, snapshot), isTrue);
    expect(seedCalls, 1);
  });

  test('load() prefers cache over seed', () async {
    // Write to cache first
    await cache.write(seedSnapshot);

    var seedCalls = 0;
    final repo = PublicCatalogueRepository(
      seedLoader: () async {
        seedCalls++;
        return seedSnapshot;
      },
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    final snapshot = await repo.load();
    expect(snapshot.version, 1);
    expect(snapshot.origin, 'cache');
    expect(seedCalls, 0);
  });

  test('single-flight refresh deduplication and 5-minute cooldown', () async {
    final manifestJson = jsonEncode([
      {
        'contract': 'travelgo.discovery.manifest.v2',
        'schema_version': 2,
        'version': 1,
        'object_key': 'releases/v2/1.json',
        'sha256': validManifest.sha256,
        'byte_length': validManifest.byteLength,
        'published_at': '2026-10-20T10:00:00Z',
      }
    ]);

    adapter.onFetch = (options) async {
      final uri = options.uri.toString();
      if (uri.contains('discovery_release_manifest')) {
        // Assert: NO Authorization header in public requests
        expect(options.headers['Authorization'], isNull);
        return ResponseBody.fromString(
          manifestJson,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (uri.contains('releases/v2/1.json')) {
        expect(options.headers['Authorization'], isNull);
        return ResponseBody.fromString(
          fixtureText,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('Not Found', 404);
    };

    var now = DateTime.parse('2026-10-20T12:00:00Z');
    final repo = PublicCatalogueRepository(
      seedLoader: () async => seedSnapshot,
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => now,
    );

    // Initial load
    await repo.load();

    // Trigger two concurrent refresh calls -> single-flight
    final f1 = repo.refresh();
    final f2 = repo.refresh();
    final results = await Future.wait([f1, f2]);
    expect(results[0].updated, isFalse);
    expect(results[1].updated, isFalse);

    // Verify adapter only received 1 manifest call
    final manifestRequests = adapter.requests.where((r) => r.uri.toString().contains('manifest')).toList();
    expect(manifestRequests.length, 1);

    // Third call within 5 minutes -> skips network due to cooldown
    now = now.add(const Duration(minutes: 3));
    final r3 = await repo.refresh(force: false);
    expect(r3.updated, isFalse);
    expect(adapter.requests.where((r) => r.uri.toString().contains('manifest')).length, 1);

    // Fourth call with force: true -> bypasses cooldown
    final r4 = await repo.refresh(force: true);
    expect(r4.updated, isFalse);
    expect(adapter.requests.where((r) => r.uri.toString().contains('manifest')).length, 2);
  });

  test('refresh() downloads higher version, validates object and updates cache and RAM', () async {
    final v2Bundle = buildValidBundle(version: 2);
    final v2Text = jsonEncode(v2Bundle);
    final v2Bytes = utf8.encode(v2Text);
    final v2Sha = sha256.convert(v2Bytes).toString();

    final manifestJson = jsonEncode([
      {
        'contract': 'travelgo.discovery.manifest.v2',
        'schema_version': 2,
        'version': 2,
        'object_key': 'releases/v2/2.json',
        'sha256': v2Sha,
        'byte_length': v2Bytes.length,
        'published_at': '2026-10-20T11:00:00Z',
      }
    ]);

    adapter.onFetch = (options) async {
      final uri = options.uri.toString();
      if (uri.contains('discovery_release_manifest')) {
        expect(options.headers['Authorization'], isNull);
        return ResponseBody.fromString(
          manifestJson,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (uri.contains('releases/v2/2.json')) {
        expect(options.headers['Authorization'], isNull);
        return ResponseBody.fromString(
          v2Text,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('Not Found', 404);
    };

    final repo = PublicCatalogueRepository(
      seedLoader: () async => seedSnapshot,
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    await repo.load();
    expect(repo.currentSnapshot!.version, 1);

    final refreshResult = await repo.refresh(force: true);
    expect(refreshResult.updated, isTrue);
    expect(refreshResult.snapshot.version, 2);
    expect(refreshResult.snapshot.sha256, v2Sha);
    expect(repo.currentSnapshot!.version, 2);

    // Verify disk has version 2
    final diskSnapshot = await cache.read();
    expect(diskSnapshot, isNotNull);
    expect(diskSnapshot!.version, 2);
  });

  test('refresh() bootstraps remote version 1 publication when current is local seed version 1', () async {
    final v1RemoteBundle = buildValidBundle(version: 1);
    (v1RemoteBundle['catalogue']['destinations'] as List).add({
      'id': 'hue',
      'name': 'Huế',
      'slug': 'hue',
      'region': 'Miền Trung',
      'places': [],
    });
    final v1Text = jsonEncode(v1RemoteBundle);
    final v1Bytes = utf8.encode(v1Text);
    final v1RemoteSha = sha256.convert(v1Bytes).toString();

    final manifestJson = jsonEncode([
      {
        'contract': 'travelgo.discovery.manifest.v2',
        'schema_version': 2,
        'version': 1,
        'object_key': 'releases/v2/1.json',
        'sha256': v1RemoteSha,
        'byte_length': v1Bytes.length,
        'published_at': '2026-10-23T12:00:00Z',
      }
    ]);

    adapter.onFetch = (options) async {
      final uri = options.uri.toString();
      if (uri.contains('discovery_release_manifest')) {
        return ResponseBody.fromString(
          manifestJson,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      if (uri.contains('releases/v2/1.json')) {
        return ResponseBody.fromString(
          v1Text,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString('Not Found', 404);
    };

    final repo = PublicCatalogueRepository(
      seedLoader: () async => seedSnapshot,
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => DateTime.parse('2026-10-23T12:00:00Z'),
    );

    await repo.load();
    expect(repo.currentSnapshot!.version, 1);
    expect(repo.currentSnapshot!.origin, 'seed');

    final refreshResult = await repo.refresh(force: true);
    expect(refreshResult.updated, isTrue);
    expect(refreshResult.snapshot.version, 1);
    expect(refreshResult.snapshot.sha256, v1RemoteSha);
    expect(refreshResult.snapshot.origin, 'storage');
    expect(repo.currentSnapshot!.sha256, v1RemoteSha);
  });

  test('network failure or invalid manifest preserves RAM and disk snapshot', () async {
    await cache.write(seedSnapshot);

    final repo = PublicCatalogueRepository(
      seedLoader: () async => seedSnapshot,
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    await repo.load();

    // Injected error: manifest endpoint returns 500
    adapter.onFetch = (options) async => ResponseBody.fromString('Server Error', 500);

    final result = await repo.refresh(force: true);
    expect(result.updated, isFalse);
    expect(result.errorCode, isNotNull);

    // In-memory snapshot still valid v1
    expect(repo.currentSnapshot!.version, 1);
    expect(repo.currentSnapshot!.sha256, validManifest.sha256);

    // Disk still valid v1
    final diskSnapshot = await cache.read();
    expect(diskSnapshot!.version, 1);
  });

  test('PublicCatalogueProvider loads and refreshes correctly', () async {
    final manifestJson = jsonEncode([
      {
        'contract': 'travelgo.discovery.manifest.v2',
        'schema_version': 2,
        'version': 1,
        'object_key': 'releases/v2/1.json',
        'sha256': validManifest.sha256,
        'byte_length': validManifest.byteLength,
        'published_at': '2026-10-20T10:00:00Z',
      }
    ]);

    adapter.onFetch = (options) async {
      return ResponseBody.fromString(
        manifestJson,
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    };

    final repo = PublicCatalogueRepository(
      seedLoader: () async => seedSnapshot,
      cache: cache,
      client: dio,
      projectOrigin: 'https://bkocylxbuyvdgxccpixx.supabase.co',
      clock: () => DateTime.parse('2026-10-20T12:00:00Z'),
    );

    final provider = PublicCatalogueProvider(repository: repo);
    expect(provider.snapshot, isNull);
    expect(provider.isLoading, isFalse);

    await provider.load();
    expect(provider.snapshot, isNotNull);
    expect(provider.snapshot!.version, 1);
    expect(provider.isLoading, isFalse);

    await provider.onResume();
    expect(provider.snapshot, isNotNull);
    expect(provider.isLoading, isFalse);

    provider.dispose();
  });
}
