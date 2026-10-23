// Dedicated atomic SQLite cache for Discovery Release V2.

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';

class PublicCatalogueCache {
  final Future<String> Function() _databasePath;
  final DatabaseFactory _databaseFactory;
  final DateTime Function() _clock;

  Future<Database>? _opening;
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  PublicCatalogueCache({
    Future<String> Function()? databasePath,
    DatabaseFactory? databaseFactory,
    DateTime Function()? clock,
  })  : _databasePath = databasePath ?? (() async => 'public_discovery_v2.db'),
        _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin,
        _clock = clock ?? (() => DateTime.now().toUtc());

  Future<Database> _open() async {
    final path = await _databasePath();
    return _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS public_discovery_release_v2 (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              version INTEGER NOT NULL,
              object_key TEXT NOT NULL,
              sha256 TEXT NOT NULL,
              byte_length INTEGER NOT NULL,
              schema_version INTEGER NOT NULL,
              published_at TEXT NOT NULL,
              payload_text TEXT NOT NULL,
              last_fetched_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<T> _run<T>(Future<T> Function(Database db) action) {
    if (_closed) {
      return Future<T>.error(StateError('Public catalogue cache is closed'));
    }
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final db = await (_opening ??= _open());
        final result = await action(db);
        completer.complete(result);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<PublicCatalogueSnapshot?> read() => _run((db) async {
        final rows = await db.query(
          'public_discovery_release_v2',
          where: 'id = ?',
          whereArgs: [1],
        );
        if (rows.isEmpty) {
          return null;
        }

        final row = rows.first;
        final version = row['version'] as int;
        final objectKey = row['object_key'] as String;
        final sha256 = row['sha256'] as String;
        final byteLength = row['byte_length'] as int;
        final schemaVersion = row['schema_version'] as int;
        final publishedAt = DateTime.parse(row['published_at'] as String);
        final payloadText = row['payload_text'] as String;

        final manifest = DiscoveryManifest(
          contract: 'travelgo.discovery.manifest.v2',
          schemaVersion: schemaVersion,
          version: version,
          objectKey: objectKey,
          sha256: sha256,
          byteLength: byteLength,
          publishedAt: publishedAt,
        );

        try {
          final now = _clock();
          final effectiveNow = publishedAt.isAfter(now) ? publishedAt : now;
          return PublicCatalogueParser.parse(
            payloadText: payloadText,
            manifest: manifest,
            now: effectiveNow,
            origin: 'cache',
          );
        } catch (_) {
          throw const FormatException('cache_corrupted');
        }
      });

  Future<void> write(PublicCatalogueSnapshot snapshot) => _run((db) async {
        final payloadText = snapshot.payloadText;
        if (payloadText == null || payloadText.isEmpty) {
          throw const FormatException('Cannot cache snapshot without payloadText');
        }

        await db.transaction((txn) async {
          final existingRows = await txn.query(
            'public_discovery_release_v2',
            where: 'id = ?',
            whereArgs: [1],
          );

          if (existingRows.isNotEmpty) {
            final existing = existingRows.first;
            final existingVersion = existing['version'] as int;
            final existingSha256 = existing['sha256'] as String;

            if (snapshot.version < existingVersion) {
              throw const FormatException('version_downgrade');
            }
            if (snapshot.version == existingVersion && snapshot.sha256 != existingSha256) {
              throw const FormatException('version_conflict');
            }
          }

          final record = <String, Object?>{
            'id': 1,
            'version': snapshot.version,
            'object_key': snapshot.manifest.objectKey,
            'sha256': snapshot.sha256,
            'byte_length': snapshot.manifest.byteLength,
            'schema_version': snapshot.manifest.schemaVersion,
            'published_at': snapshot.manifest.publishedAt.toUtc().toIso8601String(),
            'payload_text': payloadText,
            'last_fetched_at': _clock().toUtc().toIso8601String(),
          };

          if (existingRows.isEmpty) {
            await txn.insert('public_discovery_release_v2', record);
          } else {
            await txn.update(
              'public_discovery_release_v2',
              record,
              where: 'id = ?',
              whereArgs: [1],
            );
          }
        });
      });

  Future<void> close() async {
    _closed = true;
    await _tail;
    final opening = _opening;
    if (opening != null) {
      final db = await opening;
      await db.close();
    }
  }
}
