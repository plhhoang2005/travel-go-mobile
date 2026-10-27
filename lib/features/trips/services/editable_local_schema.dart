import 'package:sqflite/sqflite.dart';

import '../models/local_trip_records.dart';

class EditableLocalSchema {
  static const accountTables = <String>[
    'editable_trip_snapshots',
    'editable_import_journal',
    'editable_mutation_outbox',
  ];
  static const tables = <String>['guest_editable_drafts', ...accountTables];
  static Future<void> create(
    DatabaseExecutor db, {
    Future<void> Function(String)? onStep,
  }) async {
    await db.execute('''CREATE TABLE guest_editable_drafts (
      device_scope TEXT NOT NULL CHECK(trim(device_scope)!=''), draft_id TEXT NOT NULL CHECK(trim(draft_id)!=''),
      revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>=1 AND revision<=9007199254740991),
      payload_text TEXT NOT NULL, content_digest TEXT NOT NULL CHECK(length(content_digest)=64), saved_at TEXT NOT NULL,
      PRIMARY KEY(device_scope,draft_id,revision))''');
    await onStep?.call('schema_guest_created');
    await db.execute('''CREATE TABLE editable_trip_snapshots (
      owner_id TEXT NOT NULL,trip_id TEXT NOT NULL,version INTEGER NOT NULL CHECK(typeof(version)='integer' AND version>=1),
      payload_text TEXT NOT NULL,content_digest TEXT NOT NULL CHECK(length(content_digest)=64),fetched_at TEXT NOT NULL,
      PRIMARY KEY(owner_id,trip_id))''');
    await db.execute(
      '''CREATE TABLE editable_import_journal (
      owner_id TEXT NOT NULL,device_scope TEXT NOT NULL,draft_id TEXT NOT NULL,source_revision INTEGER NOT NULL CHECK(source_revision>=1),
      request_id TEXT NOT NULL,source_digest TEXT NOT NULL,state TEXT NOT NULL CHECK(state IN ('staged','committed')),
      receipt_json TEXT,PRIMARY KEY(owner_id,device_scope,draft_id,source_revision),UNIQUE(owner_id,request_id))''',
    );
    await db.execute(
      '''CREATE TABLE editable_mutation_outbox (
      owner_id TEXT NOT NULL,request_id TEXT NOT NULL,attempt_json TEXT NOT NULL,
      state TEXT NOT NULL CHECK(state IN ('staged','uncertain','committed')),receipt_json TEXT,
      PRIMARY KEY(owner_id,request_id),CHECK((state='committed')=(receipt_json IS NOT NULL)))''',
    );
    await db.execute(
      'CREATE INDEX idx_editable_guest_latest ON guest_editable_drafts(device_scope,draft_id,revision DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_editable_outbox_state ON editable_mutation_outbox(owner_id,state)',
    );
    await onStep?.call('schema_complete');
  }

  static Future<void> verify(DatabaseExecutor db) async {
    const columns = {
      'guest_editable_drafts':
          'device_scope draft_id revision payload_text content_digest saved_at',
      'editable_trip_snapshots':
          'owner_id trip_id version payload_text content_digest fetched_at',
      'editable_import_journal': 'owner_id device_scope draft_id source_revision request_id source_digest state receipt_json',
      'editable_mutation_outbox':
          'owner_id request_id attempt_json state receipt_json',
    };
    for (final table in tables) {
      final rows = await db.rawQuery(
        'SELECT name FROM sqlite_master WHERE type=? AND name=?',
        ['table', table],
      );
      if (rows.length != 1) {
        throw const UnsupportedDatabaseVersionException(
          'Incomplete editable schema; refusing reset.',
        );
      }
      final info = await db.rawQuery('PRAGMA table_info($table)');
      if (info.map((row) => row['name']).join(' ') != columns[table]) {
        throw const UnsupportedDatabaseVersionException(
          'Editable table shape is unsupported; refusing reset.',
        );
      }
    }
  }

  static Future<void> purge(DatabaseExecutor db, String ownerId) async {
    for (final table in accountTables) {
      await db.delete(table, where: 'owner_id = ?', whereArgs: [ownerId]);
    }
  }
}
