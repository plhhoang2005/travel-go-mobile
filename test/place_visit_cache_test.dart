import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/explore/services/place_visit_cache.dart';

import 'place_visit_details_model_test.dart'
    show visitCatalogueFixture, visitTestHash;

CachedVisitRelease cachedFixture(int version, {String suffix = ''}) {
  final data = visitCatalogueFixture()..['version'] = version;
  final bytes = Uint8List.fromList(utf8.encode('${jsonEncode(data)}$suffix'));
  return CachedVisitRelease(
    version: version,
    payloadUtf8: bytes,
    sha256: sha256.convert(bytes).toString(),
    catalogueSha256: visitTestHash,
    publishedAt: DateTime.utc(2026, 10, 20),
    lastFetchedAt: DateTime.utc(2026, 10, 20, 10),
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late String path;
  late SqliteVisitReleaseCache cache;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('travelgo-public-visit-');
    path = '${directory.path}/travelgo_discovery_public_v1.db';
    cache = SqliteVisitReleaseCache(databasePath: () async => path);
  });
  tearDown(() async {
    await cache.close();
    await directory.delete(recursive: true);
  });

  test(
    'release survives close/reopen with exact original UTF8 bytes',
    () async {
      expect(await cache.read(), isNull);
      final value = cachedFixture(1, suffix: '\n');
      await cache.write(value);
      expect(() => value.payloadUtf8[0] = 0, throwsUnsupportedError);
      await cache.close();
      cache = SqliteVisitReleaseCache(databasePath: () async => path);
      final restored = (await cache.read())!;
      expect(restored.payloadUtf8, value.payloadUtf8);
      expect(restored.sha256, value.sha256);
      expect(restored.lastFetchedAt, value.lastFetchedAt);
    },
  );

  test(
    'transaction guards downgrade and same version with different hash',
    () async {
      await cache.write(cachedFixture(2));
      await expectLater(
        cache.write(cachedFixture(1)),
        throwsA(isA<VisitDataException>()),
      );
      await expectLater(
        cache.write(cachedFixture(2, suffix: '\n')),
        throwsA(isA<VisitDataException>()),
      );
      expect((await cache.read())!.sha256, cachedFixture(2).sha256);
      await cache.write(cachedFixture(3));
      expect((await cache.read())!.version, 3);
    },
  );

  test(
    'SQLite failure during replace retains previous release after reopen',
    () async {
      await cache.write(cachedFixture(1));
      final db = await openDatabase(path, singleInstance: false);
      await db.execute(
        "CREATE TRIGGER fixture_fail BEFORE UPDATE ON active_release BEGIN SELECT RAISE(ABORT, 'synthetic disk failure'); END",
      );
      await db.close();
      await expectLater(
        cache.write(cachedFixture(2)),
        throwsA(isA<DatabaseException>()),
      );
      await cache.close();
      cache = SqliteVisitReleaseCache(databasePath: () async => path);
      expect((await cache.read())!.version, 1);
    },
  );

  test(
    'corrupt cached bytes are rejected without touching adjacent private data',
    () async {
      final privateSentinel = File('${directory.path}/guest_private_sentinel');
      await privateSentinel.writeAsString('must remain unchanged');
      await cache.write(cachedFixture(1));
      await cache.close();
      final db = await openDatabase(path, singleInstance: false);
      await db.update('active_release', {
        'payload_utf8': Uint8List.fromList([123, 255]),
      });
      await db.close();
      cache = SqliteVisitReleaseCache(databasePath: () async => path);
      await expectLater(cache.read(), throwsA(isA<VisitDataException>()));
      expect(await privateSentinel.readAsString(), 'must remain unchanged');
    },
  );

  test(
    'metadata, checksum and unreviewed payload fail before persistence',
    () async {
      final original = cachedFixture(1);
      final invalid = CachedVisitRelease(
        version: 2,
        payloadUtf8: original.payloadUtf8,
        sha256: original.sha256,
        catalogueSha256: original.catalogueSha256,
        publishedAt: original.publishedAt,
        lastFetchedAt: original.lastFetchedAt,
      );
      await expectLater(
        cache.write(invalid),
        throwsA(isA<VisitDataException>()),
      );
      final partialData = visitCatalogueFixture();
      partialData['places'][0]['price']['evidence']['reviewState'] =
          'unverified';
      final partialBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(partialData)),
      );
      final partial = CachedVisitRelease(
        version: 1,
        payloadUtf8: partialBytes,
        sha256: sha256.convert(partialBytes).toString(),
        catalogueSha256: visitTestHash,
        publishedAt: original.publishedAt,
        lastFetchedAt: original.lastFetchedAt,
      );
      await expectLater(
        cache.write(partial),
        throwsA(isA<VisitDataException>()),
      );
      expect(await cache.read(), isNull);
    },
  );

  test('close waits for accepted IO and refuses later operations', () async {
    await cache.close();
    final gate = Completer<String>();
    cache = SqliteVisitReleaseCache(databasePath: () => gate.future);
    final write = cache.write(cachedFixture(1));
    var closed = false;
    final closing = cache.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, false);
    gate.complete(path);
    await write;
    await closing;
    await expectLater(cache.read(), throwsStateError);
    cache = SqliteVisitReleaseCache(databasePath: () async => path);
    expect((await cache.read())!.version, 1);
  });
}
