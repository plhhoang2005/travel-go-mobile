import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:sqflite/sqflite.dart';

import '../models/place_visit_details.dart';

/// Public travel facts only. This cache has no account or itinerary dependency.
abstract interface class VisitReleaseCache {
  Future<CachedVisitRelease?> read();
  Future<void> write(CachedVisitRelease value);
  Future<void> close();
}

class CachedVisitRelease {
  final int version;
  final Uint8List payloadUtf8;
  final String sha256, catalogueSha256;
  final DateTime publishedAt, lastFetchedAt;
  CachedVisitRelease({
    required this.version,
    required Uint8List payloadUtf8,
    required this.sha256,
    required this.catalogueSha256,
    required this.publishedAt,
    required this.lastFetchedAt,
  }) : payloadUtf8 = Uint8List.fromList(payloadUtf8).asUnmodifiableView();
}

class SqliteVisitReleaseCache implements VisitReleaseCache {
  final Future<String> Function() databasePath;
  Future<Database>? _opening;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  bool _closed = false;

  SqliteVisitReleaseCache({required this.databasePath});

  Future<Database> _open() async => openDatabase(
    await databasePath(),
    singleInstance: false,
    version: 1,
    onCreate: (db, _) => db.execute('''
      CREATE TABLE active_release (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        version INTEGER NOT NULL,
        payload_utf8 BLOB NOT NULL,
        sha256 TEXT NOT NULL,
        catalogue_sha256 TEXT NOT NULL,
        published_at TEXT NOT NULL,
        last_fetched_at TEXT NOT NULL
      )
    '''),
  );

  Future<T> _run<T>(Future<T> Function(Database db) action) {
    if (_closed) {
      return Future<T>.error(StateError('Public visit cache is closed'));
    }
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final db = await (_opening ??= _open());
        result.complete(await action(db));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  @override
  Future<CachedVisitRelease?> read() => _run((db) async {
    final rows = await db.query(
      'active_release',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) {
      return null;
    }
    try {
      final row = rows.single;
      final value = CachedVisitRelease(
        version: row['version'] as int,
        payloadUtf8: row['payload_utf8'] as Uint8List,
        sha256: row['sha256'] as String,
        catalogueSha256: row['catalogue_sha256'] as String,
        publishedAt: DateTime.parse(row['published_at'] as String),
        lastFetchedAt: DateTime.parse(row['last_fetched_at'] as String),
      );
      _validate(value);
      return value;
    } catch (_) {
      throw const VisitDataException('cache_corrupt');
    }
  });

  @override
  Future<void> write(CachedVisitRelease value) => _run((db) async {
    _validate(value);
    await db.transaction((txn) async {
      final rows = await txn.query(
        'active_release',
        columns: ['version', 'sha256'],
        where: 'id = ?',
        whereArgs: [1],
      );
      if (rows.isNotEmpty) {
        final old = rows.single;
        final version = old['version'] as int;
        if (value.version < version) {
          throw const VisitDataException('version_downgrade');
        }
        if (value.version == version && value.sha256 != old['sha256']) {
          throw const VisitDataException('version_conflict');
        }
      }
      final row = <String, Object?>{
        'id': 1,
        'version': value.version,
        'payload_utf8': value.payloadUtf8,
        'sha256': value.sha256,
        'catalogue_sha256': value.catalogueSha256,
        'published_at': value.publishedAt.toUtc().toIso8601String(),
        'last_fetched_at': value.lastFetchedAt.toUtc().toIso8601String(),
      };
      if (rows.isEmpty) {
        await txn.insert('active_release', row);
      } else {
        await txn.update(
          'active_release',
          row,
          where: 'id = ?',
          whereArgs: [1],
        );
      }
    });
  });

  // Checks internal schema/integrity. Repository additionally pins the exact
  // supported base catalogue and place IDs; a stored row cannot select those.
  void _validate(CachedVisitRelease value) {
    try {
      if (value.payloadUtf8.isEmpty ||
          value.payloadUtf8.length > maxVisitReleaseBytes ||
          crypto.sha256.convert(value.payloadUtf8).toString() != value.sha256) {
        throw const VisitDataException('cache_integrity');
      }
      final text = utf8.decode(value.payloadUtf8);
      final raw = jsonDecode(text) as Map<String, dynamic>;
      final ids = (raw['places'] as List)
          .map((p) => (p as Map<String, dynamic>)['placeId'] as String)
          .toSet();
      final catalogue = parseVisitCatalogue(
        text,
        expectedPlaceIds: ids,
        expectedCatalogueSha256: value.catalogueSha256,
        now: DateTime.now(),
        requireComplete: true,
      );
      if (catalogue.version != value.version ||
          !catalogue.publishedAt.isAtSameMomentAs(value.publishedAt)) {
        throw const VisitDataException('cache_metadata');
      }
    } on VisitDataException {
      rethrow;
    } catch (_) {
      throw const VisitDataException('cache_corrupt');
    }
  }

  @override
  Future<void> close() {
    _closed = true;
    return _closing ??= () async {
      await _tail;
      final opening = _opening;
      if (opening != null) {
        await (await opening).close();
      }
    }();
  }
}
