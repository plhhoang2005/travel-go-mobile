import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/services/place_visit_cache.dart';
import 'package:travelgo_mobile/features/explore/services/place_visit_details_repository.dart';

import 'place_visit_cache_test.dart' show cachedFixture;
import 'place_visit_details_model_test.dart'
    show visitCatalogueFixture, visitTestHash, visitTestNow;

class MemoryVisitCache implements VisitReleaseCache {
  CachedVisitRelease? value;
  bool failRead = false, failWrite = false, closed = false;
  int writes = 0;
  Completer<void>? writeGate;
  @override
  Future<CachedVisitRelease?> read() async {
    if (failRead) throw StateError('synthetic corrupt cache');
    return value;
  }

  @override
  Future<void> write(CachedVisitRelease next) async {
    if (failWrite) throw StateError('synthetic disk failure');
    await writeGate?.future;
    value = next;
    writes++;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

class PublicVisitAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  late Future<ResponseBody> Function(RequestOptions) reply;
  bool closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

Map<String, dynamic> manifestFixture(CachedVisitRelease release) => {
  'schemaVersion': 1,
  'version': release.version,
  'objectPath': 'releases/${release.version}.json',
  'sha256': release.sha256,
  'byteLength': release.payloadUtf8.length,
  'publishedAt': '2026-10-20T00:00:00Z',
  'catalogueSha256': visitTestHash,
};
ResponseBody visitJson(Object value, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  late Dio dio;
  late PublicVisitAdapter adapter;
  late MemoryVisitCache cache;
  late VisitDetailsRepository repository;
  late String seed;
  late bool seedFailure;
  setUp(() {
    dio = Dio(
      BaseOptions(
        headers: {
          'Authorization': 'synthetic-do-not-send',
          'apikey': 'private',
        },
      ),
    );
    adapter = PublicVisitAdapter();
    dio.httpClientAdapter = adapter;
    cache = MemoryVisitCache();
    seed = jsonEncode(visitCatalogueFixture());
    seedFailure = false;
    repository = VisitDetailsRepository(
      dio: dio,
      cache: cache,
      seedLoader: () async {
        if (seedFailure) throw StateError('seed missing');
        return seed;
      },
      projectOrigin: Uri.parse('https://bkocylxbuyvdgxccpixx.supabase.co'),
      expectedPlaceIds: {'test/place'},
      expectedCatalogueSha256: visitTestHash,
      now: () => visitTestNow,
      remoteEnabled: true,
    );
    adapter.reply = (_) async => visitJson(manifestFixture(cachedFixture(2)));
  });
  tearDown(() async {
    await repository.close();
    dio.close(force: true);
  });

  test('a slow request times out and retains current snapshot', () async {
    await repository.close();
    cache = MemoryVisitCache();
    repository = VisitDetailsRepository(
      dio: dio,
      cache: cache,
      seedLoader: () async => seed,
      projectOrigin: Uri.parse('https://bkocylxbuyvdgxccpixx.supabase.co'),
      expectedPlaceIds: {'test/place'},
      expectedCatalogueSha256: visitTestHash,
      now: () => visitTestNow,
      remoteEnabled: true,
      requestTimeout: const Duration(milliseconds: 30),
    );
    adapter.reply = (_) => Completer<ResponseBody>().future;
    final local = await repository.loadLocal();
    final result = await repository.refresh(local);
    expect(result.errorCode, 'timeout');
    expect(result.snapshot.catalogue.version, 1);
    expect(cache.writes, 0);
  });

  test('a newer seed wins over an older valid cached release', () async {
    final newer = visitCatalogueFixture()..['version'] = 3;
    seed = jsonEncode(newer);
    cache.value = cachedFixture(2);
    expect((await repository.loadLocal()).catalogue.version, 3);
    expect((await repository.loadLocal()).origin, 'bundled');
  });

  test(
    'corrupt supported-ID binding falls back to seed despite valid checksum',
    () async {
      final data = visitCatalogueFixture()..['version'] = 2;
      data['places'][0]['placeId'] = 'unsupported/place';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
      cache.value = CachedVisitRelease(
        version: 2,
        payloadUtf8: bytes,
        sha256: sha256.convert(bytes).toString(),
        catalogueSha256: visitTestHash,
        publishedAt: DateTime.utc(2026, 10, 20),
        lastFetchedAt: visitTestNow,
      );
      final result = await repository.loadLocal();
      expect(result.catalogue.version, 1);
      expect(result.warningCode, 'cache_unavailable');
    },
  );

  test(
    'oversized release stream is rejected while reading, before cache write',
    () async {
      final local = await repository.loadLocal();
      final release = cachedFixture(2);
      adapter.reply = (request) async =>
          request.uri.path.endsWith('latest.json')
          ? visitJson(manifestFixture(release))
          : ResponseBody(
              Stream.fromIterable([
                Uint8List(1024 * 1024),
                Uint8List(1024 * 1024),
                Uint8List(1),
              ]),
              200,
            );
      final result = await repository.refresh(local);
      expect(result.errorCode, 'response_size');
      expect(cache.writes, 0);
    },
  );

  test('redirect metadata on status 200 is refused', () async {
    adapter.reply = (_) async =>
        ResponseBody.fromString('{}', 200, isRedirect: true);
    final result = await repository.refresh(await repository.loadLocal());
    expect(result.errorCode, 'http_status');
  });

  test(
    'download now does not renew a source checked more than 30 days ago',
    () async {
      final data = visitCatalogueFixture()..['version'] = 2;
      data['places'][0]['price']['evidence']['checkedAt'] = '2026-09-01';
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
      final release = CachedVisitRelease(
        version: 2,
        payloadUtf8: bytes,
        sha256: sha256.convert(bytes).toString(),
        catalogueSha256: visitTestHash,
        publishedAt: DateTime.utc(2026, 10, 20),
        lastFetchedAt: visitTestNow,
      );
      adapter.reply = (request) async =>
          request.uri.path.endsWith('latest.json')
          ? visitJson(manifestFixture(release))
          : ResponseBody.fromBytes(bytes, 200);
      final result = await repository.refresh(await repository.loadLocal());
      final evidence =
          result.snapshot.catalogue.places['test/place']!.price.evidence;
      expect(evidence.checkedAt, DateTime.utc(2026, 9, 1));
      expect(evidence.needsReview(visitTestNow), true);
      expect(result.snapshot.lastFetchedAt, visitTestNow);
    },
  );

  test('remote is off outside staging and shared Dio is not closed', () async {
    await repository.close();
    expect(adapter.closed, false);
    cache = MemoryVisitCache();
    repository = VisitDetailsRepository(
      dio: dio,
      cache: cache,
      seedLoader: () async => seed,
      projectOrigin: Uri.parse('https://production.supabase.co'),
      expectedPlaceIds: {'test/place'},
      expectedCatalogueSha256: visitTestHash,
      now: () => visitTestNow,
      remoteEnabled: false,
    );
    final result = await repository.refresh(await repository.loadLocal());
    expect(result.updated, false);
    expect(adapter.requests, isEmpty);
    expect(
      () => VisitDetailsRepository(
        dio: dio,
        cache: cache,
        seedLoader: () async => seed,
        projectOrigin: Uri.parse('https://production.supabase.co'),
        expectedPlaceIds: {'test/place'},
        expectedCatalogueSha256: visitTestHash,
        now: () => visitTestNow,
        remoteEnabled: true,
      ),
      throwsArgumentError,
    );
  });

  test(
    'startup selects highest valid complete cache and preserves source date',
    () async {
      cache.value = cachedFixture(2);
      final local = await repository.loadLocal();
      expect(local.catalogue.version, 2);
      expect(local.origin, 'cache');
      expect(
        local.catalogue.places['test/place']!.price.evidence.checkedAt,
        DateTime.utc(2026, 10, 20),
      );
      expect(local.lastFetchedAt, cache.value!.lastFetchedAt);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'corrupt cache falls back with warning, valid cache survives missing seed',
    () async {
      cache.failRead = true;
      expect((await repository.loadLocal()).warningCode, 'cache_unavailable');
      await repository.close();
      cache = MemoryVisitCache()..value = cachedFixture(2);
      seedFailure = true;
      repository = VisitDetailsRepository(
        dio: dio,
        cache: cache,
        seedLoader: () async => throw StateError('missing'),
        projectOrigin: Uri.parse('https://bkocylxbuyvdgxccpixx.supabase.co'),
        expectedPlaceIds: {'test/place'},
        expectedCatalogueSha256: visitTestHash,
        now: () => visitTestNow,
        remoteEnabled: true,
      );
      expect((await repository.loadLocal()).catalogue.version, 2);
    },
  );

  test('new release becomes visible only after cache commit, sends public GET only', () async {
    final release = cachedFixture(2, suffix: '\n');
    adapter.reply = (request) async => request.uri.path.endsWith('latest.json')
        ? visitJson(manifestFixture(release))
        : ResponseBody.fromBytes(release.payloadUtf8, 200);
    final local = await repository.loadLocal();
    cache.writeGate = Completer<void>();
    var finished = false;
    final pending = repository.refresh(local).then((value) {
      finished = true;
      return value;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(finished, false);
    cache.writeGate!.complete();
    final result = await pending;
    expect(result.updated, true);
    expect(result.snapshot.origin, 'remote');
    expect(result.snapshot.catalogue.version, 2);
    expect(result.snapshot.lastFetchedAt, visitTestNow);
    expect(cache.value!.payloadUtf8, release.payloadUtf8);
    expect(adapter.requests, hasLength(2));
    for (final request in adapter.requests) {
      expect(request.method, 'GET');
      expect(request.uri.origin, 'https://bkocylxbuyvdgxccpixx.supabase.co');
      expect(request.uri.query, isEmpty);
      expect(request.data, isNull);
      expect(request.followRedirects, false);
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(anyElement(isIn(['authorization', 'apikey', 'cookie']))),
      );
    }
  });

  test('same version and hash skips payload fetch, does not renew source/fetched dates', () async {
    cache.value = cachedFixture(2);
    final local = await repository.loadLocal();
    final result = await repository.refresh(local);
    expect(result.updated, false);
    expect(result.errorCode, isNull);
    expect(result.snapshot.lastFetchedAt, local.lastFetchedAt);
    expect(cache.writes, 0);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'downgrade and same version changed bytes keep last good release',
    () async {
      cache.value = cachedFixture(2);
      final local = await repository.loadLocal();
      for (final release in [
        cachedFixture(1),
        cachedFixture(2, suffix: '\n'),
      ]) {
        adapter.reply = (_) async => visitJson(manifestFixture(release));
        final result = await repository.refresh(local);
        expect(result.errorCode, isNotNull);
        expect(result.snapshot.catalogue.version, 2);
        expect(cache.writes, 0);
      }
    },
  );

  for (final failure in [
    '404',
    'html',
    'path',
    'host',
    'redirect',
    'large',
    'utf8',
    'checksum',
    'length',
    'ids',
    'partial',
    'metadata',
    'disk',
  ]) {
    test('$failure cannot replace last good snapshot', () async {
      final local = await repository.loadLocal();
      final release = cachedFixture(2);
      final manifest = manifestFixture(release);
      switch (failure) {
        case 'path':
          manifest['objectPath'] = 'releases/../2.json';
        case 'host':
          manifest['objectPath'] = 'https://external.invalid/2.json';
        case 'length':
          manifest['byteLength'] = release.payloadUtf8.length + 1;
        case 'disk':
          cache.failWrite = true;
      }
      adapter.reply = (request) async {
        if (request.uri.path.endsWith('latest.json')) {
          return switch (failure) {
            '404' => visitJson({}, status: 404),
            'html' => ResponseBody.fromString(
              '<html>private do not echo</html>',
              200,
            ),
            'redirect' => ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://external.invalid'],
              },
            ),
            'large' => ResponseBody.fromString('x' * 32769, 200),
            'utf8' => ResponseBody.fromBytes([255], 200),
            _ => visitJson(manifest),
          };
        }
        var bytes = release.payloadUtf8;
        if (['ids', 'partial', 'metadata'].contains(failure)) {
          final data = visitCatalogueFixture()..['version'] = 2;
          switch (failure) {
            case 'ids':
              data['places'][0]['placeId'] = 'unknown/place';
            case 'partial':
              data['places'][0]['hours']['evidence']['reviewState'] =
                  'unverified';
            case 'metadata':
              data['publishedAt'] = '2026-10-19T00:00:00Z';
          }
          bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
        }
        if (failure == 'checksum') bytes = Uint8List.fromList([...bytes, 32]);
        return ResponseBody.fromBytes(bytes, 200);
      };
      if (['ids', 'partial', 'metadata'].contains(failure)) {
        // Match bytes/hash so the field/schema assertion, not checksum, rejects it.
        final data = visitCatalogueFixture()..['version'] = 2;
        switch (failure) {
          case 'ids':
            data['places'][0]['placeId'] = 'unknown/place';
          case 'partial':
            data['places'][0]['hours']['evidence']['reviewState'] =
                'unverified';
          case 'metadata':
            data['publishedAt'] = '2026-10-19T00:00:00Z';
        }
        final bytes = utf8.encode(jsonEncode(data));
        manifest['sha256'] = sha256.convert(bytes).toString();
        manifest['byteLength'] = bytes.length;
      }
      final result = await repository.refresh(local);
      expect(result.updated, false);
      expect(result.errorCode, isNotNull);
      expect(identical(result.snapshot.catalogue, local.catalogue), true);
      expect(cache.writes, 0);
    });
  }

  test(
    'concurrent refresh is single flight and stale caller cannot downgrade V2',
    () async {
      final local = await repository.loadLocal();
      final gate = Completer<void>();
      final release = cachedFixture(2);
      adapter.reply = (request) async {
        await gate.future;
        return request.uri.path.endsWith('latest.json')
            ? visitJson(manifestFixture(release))
            : ResponseBody.fromBytes(release.payloadUtf8, 200);
      };
      final a = repository.refresh(local);
      final b = repository.refresh(local);
      gate.complete();
      expect((await a).snapshot.catalogue.version, 2);
      expect((await b).snapshot.catalogue.version, 2);
      expect(adapter.requests, hasLength(2));
      adapter.reply = (_) async => visitJson(manifestFixture(cachedFixture(1)));
      expect((await repository.refresh(local)).snapshot.catalogue.version, 2);
    },
  );
}
