import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite_lib;
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

/// Local SQLite persistence store for guest drafts, authenticated trip snapshots,
/// and import journal records, enforcing strict integrity and fail-closed safety.
class LocalTripStore {
  static const int databaseSchemaVersion = 1;
  static const String defaultDatabaseName = 'travel_go_local.db';

  final DatabaseFactory _databaseFactory;
  final String _databasePath;
  final DateTime Function() _clock;

  Database? _db;
  bool _isOpened = false;

  // Process-local fail-closed owners; only successful purge completion clears one.
  final Set<String> _blockedOwners = <String>{};

  // Store-owned monotonic generation
  int _storeGeneration = 0;
  String? _activeOwnerId;
  int? _activeCoordinatorEpoch;
  bool _isDemo = false;

  // Non-poisoning neutral sequential Future queue (C02)
  Future<void> _lastQueueTask = Future<void>.value();

  // Deterministic fault injection hooks for testing within 3-file allowlist
  @visibleForTesting
  Future<void> Function(String step)? onPurgeStepForTesting;

  @visibleForTesting
  Future<void> Function(String step)? onAckStepForTesting;

  @visibleForTesting
  Future<void> Function(String step)? onSaveDraftStepForTesting;

  @visibleForTesting
  Future<void> Function(String step)? onAccountOpStepForTesting;

  @visibleForTesting
  Future<void> Function(String step)? onActivationStepForTesting;

  LocalTripStore({
    DatabaseFactory? databaseFactory,
    required this._databasePath,
    DateTime Function()? clock,
  }) : _databaseFactory = databaseFactory ?? sqflite_lib.databaseFactory,
       _clock = clock ?? (() => DateTime.now().toUtc());

  @visibleForTesting
  Database get rawDb => _getDb();

  Database _getDb() {
    final db = _db;
    if (db == null || !_isOpened) {
      throw const StoreUnavailableException('Store database is not open.');
    }
    return db;
  }

  /// Neutral queue without action != open bypass (C02)
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lastQueueTask = _lastQueueTask.then(
      (_) async {
        try {
          final result = await action();
          completer.complete(result);
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
      onError: (_) async {
        try {
          final result = await action();
          completer.complete(result);
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
    );
    return completer.future;
  }

  /// Recovers committed cleanup markers on startup before readiness is published (C01, C02, C04)
  Future<void> _recoverCommittedMarkersOnStartup(Database db) async {
    final markers = await db.query(
      'local_cleanup_state',
      where: 'is_blocked = 1 OR purge_pending = 1',
    );

    for (final marker in markers) {
      final namespace = marker['namespace'] as String? ?? '';
      if (!namespace.startsWith('account:') || namespace.length <= 8) {
        throw const CorruptDatabaseException(
          'Malformed cleanup state namespace.',
        );
      }
      final ownerId = namespace.substring(8);
      if (ownerId.trim().isEmpty) {
        throw const CorruptDatabaseException(
          'Malformed cleanup state namespace owner.',
        );
      }

      final now = _clock();

      // Step 3 (Txn 2): Serialized purge
      await db.transaction((txn) async {
        await txn.delete(
          'account_trip_snapshots',
          where: 'owner_id = ?',
          whereArgs: [ownerId],
        );
        await txn.delete(
          'local_import_journal',
          where: 'target_owner = ? AND state = ?',
          whereArgs: [ownerId, 'committed'],
        );
        await txn.update(
          'local_import_journal',
          {
            'state': 'quarantined',
            'receipt_payload': null,
            'updated_at': now.toIso8601String(),
          },
          where: 'target_owner = ? AND state IN (?, ?)',
          whereArgs: [ownerId, 'staged', 'pending_ack'],
        );
      });

      // Step 4 (Txn 3): Complete cleanup
      await db.transaction((txn) async {
        await txn.delete(
          'local_cleanup_state',
          where: 'namespace = ?',
          whereArgs: [namespace],
        );
      });

      _blockedOwners.remove(ownerId);
    }
  }

  /// Open lifecycle: recovers any committed account cleanup markers (C01, C02)
  Future<void> open() {
    return _enqueue(() async {
      if (_isOpened) return;
      if (_db != null) {
        throw const StoreUnavailableException(
          'Retry close of failed connection before reopening.',
        );
      }
      _db = await _databaseFactory.openDatabase(
        _databasePath,
        options: OpenDatabaseOptions(
          version: databaseSchemaVersion,
          onConfigure: (db) async =>
              await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async => await _createSchema(db),
          onUpgrade: (db, oldVersion, newVersion) async =>
              throw const UnsupportedDatabaseVersionException(
                'Unsupported upgrade.',
              ),
          onDowngrade: (db, oldVersion, newVersion) async =>
              throw const UnsupportedDatabaseVersionException(
                'Unsupported downgrade.',
              ),
        ),
      );
      try {
        await _recoverCommittedMarkersOnStartup(_db!);
        _isOpened = true;
      } catch (e, st) {
        _isOpened = false;
        unbindSession();
        try {
          await _db?.close();
          _db = null;
        } catch (_) {}
        Error.throwWithStackTrace(e, st);
      }
    });
  }

  Future<void> close() {
    unbindSession();
    return _enqueue(() async {
      if (_db == null) return;
      try {
        await _db?.close();
        _db = null;
      } finally {
        _isOpened = false;
      }
    });
  }

  /// Asynchronous guarded session activation under queue with cancellation protection (C02)
  Future<SessionHandle> activateSession({
    required String ownerId,
    required int coordinatorEpoch,
    bool isDemo = false,
  }) {
    if (!_isOpened) {
      return Future.error(
        const StoreUnavailableException('Store is not opened.'),
      );
    }
    if (ownerId.trim().isEmpty) {
      return Future.error(ArgumentError('ownerId cannot be blank'));
    }
    if (isDemo) {
      return Future.error(
        const UnauthorizedAccountAccessException(
          'Demo sessions cannot bind account store.',
        ),
      );
    }

    final requestedGeneration = ++_storeGeneration;
    _activeOwnerId = null;
    _activeCoordinatorEpoch = null;
    _isDemo = false;

    return _enqueue(() async {
      if (!_isOpened) {
        throw const StoreUnavailableException('Store is not opened.');
      }

      if (_storeGeneration != requestedGeneration) {
        throw const StaleSessionEpochException(
          'Activation canceled by intervening unbind.',
        );
      }

      final db = _getDb();
      if (_blockedOwners.contains(ownerId)) {
        throw const AccountNamespaceBlockedException(
          'Account cleanup must complete before activation.',
        );
      }

      await onActivationStepForTesting?.call('before_marker_read');
      final blocked = await db.query(
        'local_cleanup_state',
        where: 'namespace = ? AND (is_blocked = 1 OR purge_pending = 1)',
        whereArgs: ['account:$ownerId'],
      );
      await onActivationStepForTesting?.call('after_marker_read');
      if (blocked.isNotEmpty) {
        throw AccountNamespaceBlockedException(
          'Account namespace is blocked pending cleanup: $ownerId',
        );
      }

      if (!_isOpened || _storeGeneration != requestedGeneration) {
        throw const StaleSessionEpochException(
          'Activation canceled while checking cleanup.',
        );
      }
      _activeOwnerId = ownerId;
      _activeCoordinatorEpoch = coordinatorEpoch;
      _isDemo = isDemo;

      return SessionHandle(
        ownerId: ownerId,
        coordinatorEpoch: coordinatorEpoch,
        storeGeneration: requestedGeneration,
        isDemoSession: isDemo,
      );
    });
  }

  /// Synchronous invalidation advances generation immediately and clears RAM (C02)
  void unbindSession() {
    _storeGeneration++;
    _activeOwnerId = null;
    _activeCoordinatorEpoch = null;
    _isDemo = false;
  }

  /// Cleanup metadata is available only to an unbound lifecycle coordinator.
  /// Capture generation before queueing and check again after every SQL await.
  Future<T> _executeNeutralCleanupRead<T>(
    Future<T> Function(Database db, void Function() check) read,
  ) {
    final generation = _storeGeneration;
    void check() {
      _getDb();
      if (_activeOwnerId != null || generation != _storeGeneration) {
        throw const StaleSessionEpochException(
          'Cleanup inspection requires an unchanged, unbound store.',
        );
      }
    }

    return _enqueue(() async {
      check();
      final result = await read(_getDb(), check);
      check();
      return result;
    });
  }

  Future<List<String>> listAccountOwnersForCleanup() {
    return _executeNeutralCleanupRead((db, check) async {
      final owners = <String>{..._blockedOwners};
      String checkedOwner(Object? value) {
        if (value is! String || value.isEmpty || value.trim() != value) {
          throw const CorruptDatabaseException('Invalid cleanup owner.');
        }
        return value;
      }

      for (final source in const [
        ('account_trip_snapshots', 'owner_id'),
        ('local_import_journal', 'target_owner'),
      ]) {
        final rows = await db.query(
          source.$1,
          columns: [source.$2],
          distinct: true,
        );
        check();
        for (final row in rows) {
          owners.add(checkedOwner(row[source.$2]));
        }
      }
      final markers = await db.query('local_cleanup_state');
      check();
      for (final row in markers) {
        final namespace = row['namespace'];
        if (namespace is! String || !namespace.startsWith('account:')) {
          throw const CorruptDatabaseException('Invalid cleanup namespace.');
        }
        for (final key in const ['is_blocked', 'purge_pending']) {
          if (row[key] is! int || (row[key] != 0 && row[key] != 1)) {
            throw const CorruptDatabaseException('Invalid cleanup flag.');
          }
        }
        owners.add(checkedOwner(namespace.substring(8)));
      }
      return List.unmodifiable(owners.toList()..sort());
    });
  }

  Future<bool> checkAccountCleanupComplete({required String ownerId}) {
    if (ownerId.isEmpty || ownerId.trim() != ownerId) {
      throw ArgumentError('Invalid cleanup owner.');
    }
    return _executeNeutralCleanupRead((db, check) async {
      final rows = await db.query(
        'local_cleanup_state',
        where: 'namespace = ?',
        whereArgs: ['account:$ownerId'],
      );
      check();
      // Any remaining marker is conservative, including an unfinished unlock.
      return !_blockedOwners.contains(ownerId) && rows.isEmpty;
    });
  }

  void _assertSessionHandle(SessionHandle handle) {
    if (!_isOpened || _db == null) {
      throw const StoreUnavailableException('Account store is not ready.');
    }
    handle.validate();
    if (_blockedOwners.contains(handle.ownerId)) {
      throw const AccountNamespaceBlockedException(
        'Account cleanup is incomplete.',
      );
    }
    if (handle.storeGeneration != _storeGeneration ||
        handle.ownerId != _activeOwnerId ||
        handle.coordinatorEpoch != _activeCoordinatorEpoch ||
        _isDemo) {
      throw const StaleSessionEpochException(
        'Session handle is stale or unaligned with current active store generation.',
      );
    }
  }

  Future<void> _assertNamespaceNotBlocked(
    DatabaseExecutor executor,
    String ownerId,
  ) async {
    final blocked = await executor.query(
      'local_cleanup_state',
      where: 'namespace = ? AND (is_blocked = 1 OR purge_pending = 1)',
      whereArgs: ['account:$ownerId'],
    );
    if (blocked.isNotEmpty) {
      throw AccountNamespaceBlockedException(
        'Account namespace is blocked pending cleanup: $ownerId',
      );
    }
  }

  /// 3-Layer Fencing Execution Template (C03)
  Future<T> _executeGuardedAccountOperation<T>(
    SessionHandle handle,
    Future<T> Function(DatabaseExecutor txn) action,
  ) {
    return _enqueue(() async {
      await onAccountOpStepForTesting?.call('queue_entry');
      // 1. Layer 1 Guard (Queue Entry)
      _assertSessionHandle(handle);

      final db = _getDb();
      final result = await db.transaction<T>((txn) async {
        // 2. Layer 2 Guard (Inside Transaction Boundary)
        _assertSessionHandle(handle);
        await _assertNamespaceNotBlocked(txn, handle.ownerId);
        await onAccountOpStepForTesting?.call('after_marker');
        _assertSessionHandle(handle);

        final value = await action(txn);
        await onAccountOpStepForTesting?.call('before_commit');
        _assertSessionHandle(handle);
        return value;
      });

      if (onAccountOpStepForTesting != null) {
        await onAccountOpStepForTesting!('before_layer3');
      }

      // 3. Layer 3 Guard (Pre-Publication Boundary)
      try {
        _assertSessionHandle(handle);
      } on LocalTripStoreException {
        // The transaction has already committed. Do not expose its account
        // cache again until the coordinator completes the cleanup protocol.
        _blockedOwners.add(handle.ownerId);
        rethrow;
      }

      return result;
    });
  }

  // ==========================================
  // Checked Mappers and Payload Validation (C07)
  // ==========================================

  DateTime _parseStrictUtc(String? raw, String fieldName) {
    if (raw == null) {
      throw CorruptDatabaseException('$fieldName must not be null.');
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.endsWith('Z')) {
      throw CorruptDatabaseException(
        '$fieldName must be a strict ISO-8601 UTC string ending with Z.',
      );
    }
    try {
      final parsed = DateTime.parse(trimmed);
      if (!parsed.isUtc) {
        throw CorruptDatabaseException(
          '$fieldName parsed timestamp is not UTC.',
        );
      }
      return parsed;
    } catch (e) {
      if (e is CorruptDatabaseException) rethrow;
      throw CorruptDatabaseException('Malformed timestamp in $fieldName: $e');
    }
  }

  LocalImportReceipt? _parseReceiptPayload(
    Object? rawReceipt,
    Map<String, dynamic> journal,
  ) {
    try {
      for (final key in [
        'device_scope',
        'target_owner',
        'draft_id',
        'request_key',
        'content_digest',
        'state',
        'created_at',
        'updated_at',
      ]) {
        final value = journal[key];
        if (value is! String || value.trim().isEmpty) {
          throw CorruptDatabaseException('Invalid journal field $key.');
        }
      }
      final revision = journal['source_revision'];
      if (revision is! int ||
          revision < 1 ||
          !RegExp(r'^[0-9a-f]{64}$')
              .hasMatch(journal['content_digest'] as String) ||
          ![
            'staged',
            'pending_ack',
            'committed',
            'quarantined',
          ].contains(journal['state'])) {
        throw const CorruptDatabaseException('Invalid journal identity/state.');
      }
      _parseStrictUtc(journal['created_at'] as String, 'journal.created_at');
      _parseStrictUtc(journal['updated_at'] as String, 'journal.updated_at');
      if (journal['state'] != 'committed') {
        if (rawReceipt != null) {
          throw const CorruptDatabaseException(
            'Active journal contains a receipt.',
          );
        }
        return null;
      }
      if (rawReceipt is! String || rawReceipt.trim().isEmpty) {
        throw const CorruptDatabaseException(
          'Committed journal is missing its receipt.',
        );
      }
      final decoded = jsonDecode(rawReceipt);
      if (decoded is! Map<String, dynamic>) {
        throw const CorruptDatabaseException(
          'Receipt JSON root must be a Map.',
        );
      }
      final receipt = LocalImportReceipt.fromMap(decoded);
      if (receipt.deviceScope != journal['device_scope'] ||
          receipt.targetOwner != journal['target_owner'] ||
          receipt.draftId != journal['draft_id'] ||
          receipt.sourceRevision != revision ||
          receipt.requestKey != journal['request_key'] ||
          receipt.contentDigest != journal['content_digest']) {
        throw const CorruptDatabaseException(
          'Stored receipt contradicts its journal identity.',
        );
      }
      return receipt;
    } catch (e) {
      if (e is LocalTripStoreException) rethrow;
      throw CorruptDatabaseException('Malformed stored receipt payload: $e');
    }
  }

  static String computeProjectedTitle(CanonicalTripPayloadV1 payload) {
    return payload.metadata.title ??
        (payload.plan != null && payload.plan!.topDestinations.isNotEmpty
            ? 'Chuyến đi ${payload.plan!.topDestinations.first.name}'
            : (payload.request != null &&
                      payload.request!.preferences.isNotEmpty
                  ? 'Chuyến đi ${payload.request!.preferences.first}'
                  : 'Chuyến đi'));
  }

  static String computeProjectedDestination(
    CanonicalTripPayloadV1 payload, {
    String defaultFallback = 'Điểm đến',
  }) {
    return payload.metadata.destinationName ??
        (payload.plan != null && payload.plan!.topDestinations.isNotEmpty
            ? payload.plan!.topDestinations.first.name
            : defaultFallback);
  }

  CanonicalTripPayloadV1 _validateAndDecodePayload(
    String payloadJson,
    String storedDigest,
  ) {
    // 1. Verify SHA-256 over raw UTF-8 bytes matches stored digest
    final actualDigest = sha256.convert(utf8.encode(payloadJson)).toString();
    if (actualDigest != storedDigest) {
      throw const CorruptDatabaseException(
        'Payload bytes SHA-256 mismatch with stored digest.',
      );
    }

    // 2. Parse JSON and map syntax errors to CorruptDatabaseException
    dynamic decoded;
    try {
      decoded = jsonDecode(payloadJson);
    } catch (e) {
      throw CorruptDatabaseException('Invalid JSON syntax: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CorruptDatabaseException('Payload JSON root must be a Map.');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const CorruptDatabaseException('Payload schemaVersion must be 1.');
    }

    // 3. Decode via B1 codec, mapping B1 validation errors to CorruptDatabaseException
    CanonicalTripPayloadV1 payload;
    try {
      payload = TripPayloadCodec.decode(decoded);
    } catch (e) {
      throw CorruptDatabaseException('B1 codec validation failed: $e');
    }

    // 4. Verify canonical re-encode byte consistency
    try {
      final reEncoded = TripPayloadCodec.encode(payload);
      if (reEncoded != payloadJson) {
        throw const CorruptDatabaseException(
          'Stored payload bytes are not canonical JSON.',
        );
      }
    } catch (e) {
      throw CorruptDatabaseException('Re-encode validation failed: $e');
    }

    return payload;
  }

  AccountTripSnapshotRecord _mapAccountSnapshotRow(Map<String, dynamic> row) {
    try {
      return _mapAccountSnapshotRowUnchecked(row);
    } on LocalTripStoreException {
      rethrow;
    } catch (e) {
      throw CorruptDatabaseException('Invalid account row type/date: $e');
    }
  }

  AccountTripSnapshotRecord _mapAccountSnapshotRowUnchecked(
    Map<String, dynamic> row,
  ) {
    final rowSchemaVersion = row['schema_version'];
    if (rowSchemaVersion is! int || rowSchemaVersion != 1) {
      throw const CorruptDatabaseException('Row schema_version must be 1.');
    }

    final ownerId = row['owner_id'] as String? ?? '';
    final tripId = row['trip_id'] as String? ?? '';
    final title = row['title'] as String? ?? '';
    final destinationName = row['destination_name'] as String? ?? '';
    final rawFetchedAt = row['fetched_at'] as String? ?? '';
    final rawUpdatedAt = row['updated_at'] as String? ?? '';

    if (ownerId.trim().isEmpty ||
        tripId.trim().isEmpty ||
        title.trim().isEmpty) {
      throw const CorruptDatabaseException(
        'Account row contains blank required string fields.',
      );
    }

    final remoteVersion = row['remote_version'];
    if (remoteVersion != null && (remoteVersion is! int || remoteVersion < 1)) {
      throw const CorruptDatabaseException(
        'Account row remote_version must be null or integer >= 1.',
      );
    }

    final payloadJson = row['payload_json'] as String? ?? '';
    final storedDigest = row['digest'] as String? ?? '';
    final payload = _validateAndDecodePayload(payloadJson, storedDigest);

    // Shared projection policy check against explicit payload metadata (F2 / C05 / C07)
    final expectedTitle = computeProjectedTitle(payload);
    final expectedDestination = computeProjectedDestination(
      payload,
      defaultFallback: 'Điểm đến',
    );
    if (title != expectedTitle) {
      throw CorruptDatabaseException(
        'Snapshot title projection "$title" contradicts payload expectation "$expectedTitle".',
      );
    }
    if (destinationName != expectedDestination) {
      throw CorruptDatabaseException(
        'Snapshot destination projection "$destinationName" contradicts payload expectation "$expectedDestination".',
      );
    }
    if (row['start_date'] != payload.metadata.startDate) {
      throw const CorruptDatabaseException(
        'Snapshot start_date contradicts payload metadata.',
      );
    }
    if (row['end_date'] != payload.metadata.endDate) {
      throw const CorruptDatabaseException(
        'Snapshot end_date contradicts payload metadata.',
      );
    }

    final fetchedAt = _parseStrictUtc(
      rawFetchedAt,
      'account_trip_snapshots.fetched_at',
    );
    final updatedAt = _parseStrictUtc(
      rawUpdatedAt,
      'account_trip_snapshots.updated_at',
    );

    return AccountTripSnapshotRecord(
      ownerId: ownerId,
      tripId: tripId,
      remoteVersion: remoteVersion as int?,
      schemaVersion: 1,
      fetchedAt: fetchedAt,
      payloadJson: payloadJson,
      digest: storedDigest,
      title: title,
      destinationName: destinationName,
      startDate: row['start_date'] as String?,
      endDate: row['end_date'] as String?,
      updatedAt: updatedAt,
      cachedPayload: payload,
    );
  }

  GuestDraftRevisionRecord _mapGuestDraftRevisionRow(Map<String, dynamic> row) {
    try {
      return _mapGuestDraftRevisionRowUnchecked(row);
    } on LocalTripStoreException {
      rethrow;
    } catch (e) {
      throw CorruptDatabaseException('Invalid Guest row type/date: $e');
    }
  }

  GuestDraftRevisionRecord _mapGuestDraftRevisionRowUnchecked(
    Map<String, dynamic> row,
  ) {
    final rowSchemaVersion = row['schema_version'];
    if (rowSchemaVersion is! int || rowSchemaVersion != 1) {
      throw const CorruptDatabaseException('Row schema_version must be 1.');
    }

    final deviceScope = row['device_scope'] as String? ?? '';
    final draftId = row['draft_id'] as String? ?? '';
    final rawRevision = row['revision'];
    final rawCreatedAt = row['created_at'] as String? ?? '';
    final state = row['state'] as String? ?? '';

    if (deviceScope.trim().isEmpty || draftId.trim().isEmpty) {
      throw const CorruptDatabaseException(
        'Guest row contains blank scoped ID.',
      );
    }
    if (rawRevision is! int || rawRevision < 1) {
      throw const CorruptDatabaseException(
        'Guest revision must be integer >= 1.',
      );
    }
    if (!['draft', 'quarantined', 'imported', 'superseded'].contains(state)) {
      throw const CorruptDatabaseException('Guest row state is invalid.');
    }

    final payloadJson = row['payload_json'] as String? ?? '';
    final storedDigest = row['digest'] as String? ?? '';
    final payload = _validateAndDecodePayload(payloadJson, storedDigest);

    final createdAt = _parseStrictUtc(
      rawCreatedAt,
      'guest_draft_revisions.created_at',
    );

    return GuestDraftRevisionRecord(
      deviceScope: deviceScope,
      draftId: draftId,
      revision: rawRevision,
      payloadJson: payloadJson,
      schemaVersion: 1,
      digest: storedDigest,
      createdAt: createdAt,
      state: state,
      cachedPayload: payload,
    );
  }

  // ==========================================
  // Guest Draft Operations (C08)
  // ==========================================

  Future<GuestDraftRevisionRecord> saveDraftRevision({
    required String draftId,
    required CanonicalTripPayloadV1 payload,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _enqueue(() async {
      final db = _getDb();
      return await db.transaction<GuestDraftRevisionRecord>((txn) async {
        final existingHeaderRows = await txn.query(
          'guest_drafts',
          where: 'device_scope = ? AND draft_id = ?',
          whereArgs: [deviceScope, draftId],
          limit: 1,
        );

        int allocatedRevision = 1;
        int highestAllocated = 1;
        if (existingHeaderRows.isNotEmpty) {
          final header = existingHeaderRows.first;
          final currentHighest = header['highest_allocated_revision'];
          final currentRev = header['current_revision'];
          if (currentHighest is! int || currentHighest < 1) {
            throw const CorruptDatabaseException(
              'Guest header highest_allocated_revision must be int >= 1.',
            );
          }
          if (currentRev != null &&
              (currentRev is! int ||
                  currentRev < 1 ||
                  currentRev > currentHighest)) {
            throw const CorruptDatabaseException(
              'Guest header current_revision invalid against highest_allocated.',
            );
          }

          // Validate high-water mark against present revisions in DB (F2 / plan §6.3:745):
          final maxRevQuery = await txn.rawQuery(
            'SELECT MAX(revision) as max_rev FROM guest_draft_revisions WHERE device_scope = ? AND draft_id = ?',
            [deviceScope, draftId],
          );
          final maxPresentRev = maxRevQuery.first['max_rev'] as int?;
          if (maxPresentRev != null && maxPresentRev > currentHighest) {
            throw const CorruptDatabaseException(
              'Guest header high-water mark is smaller than present revision.',
            );
          }

          allocatedRevision = currentHighest + 1;
          highestAllocated = allocatedRevision;
        }

        final digest = TripPayloadCodec.computeDigest(payload);
        final payloadJson = TripPayloadCodec.encode(payload);
        final now = _clock();

        // 1. Insert revision row first
        await txn.insert('guest_draft_revisions', {
          'device_scope': deviceScope,
          'draft_id': draftId,
          'revision': allocatedRevision,
          'payload_json': payloadJson,
          'schema_version': 1,
          'digest': digest,
          'created_at': now.toIso8601String(),
          'state': 'draft',
        });

        if (onSaveDraftStepForTesting != null) {
          await onSaveDraftStepForTesting!('after_revision_insert');
        }

        // 2. Upsert header pointer and projections
        final title = computeProjectedTitle(payload);
        final destinationName =
            payload.metadata.destinationName ??
            (payload.plan != null && payload.plan!.topDestinations.isNotEmpty
                ? payload.plan!.topDestinations.first.name
                : null);

        if (existingHeaderRows.isEmpty) {
          await txn.insert('guest_drafts', {
            'device_scope': deviceScope,
            'draft_id': draftId,
            'current_revision': allocatedRevision,
            'highest_allocated_revision': highestAllocated,
            'title': title,
            'destination_name': destinationName,
            'updated_at': now.toIso8601String(),
          });
        } else {
          await txn.update(
            'guest_drafts',
            {
              'current_revision': allocatedRevision,
              'highest_allocated_revision': highestAllocated,
              'title': title,
              'destination_name': destinationName,
              'updated_at': now.toIso8601String(),
            },
            where: 'device_scope = ? AND draft_id = ?',
            whereArgs: [deviceScope, draftId],
          );
        }

        return GuestDraftRevisionRecord(
          deviceScope: deviceScope,
          draftId: draftId,
          revision: allocatedRevision,
          payloadJson: payloadJson,
          schemaVersion: 1,
          digest: digest,
          createdAt: now,
          state: 'draft',
          cachedPayload: payload,
        );
      });
    });
  }

  Future<GuestDraftRevisionRecord?> getLatestDraft({
    required String draftId,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _enqueue(() async {
      final db = _getDb();
      final headerRows = await db.query(
        'guest_drafts',
        where: 'device_scope = ? AND draft_id = ?',
        whereArgs: [deviceScope, draftId],
        limit: 1,
      );
      if (headerRows.isEmpty) return null;

      final header = headerRows.first;
      final currentRevision = header['current_revision'];
      final highestAllocated = header['highest_allocated_revision'];
      if (highestAllocated is! int || highestAllocated < 1) {
        throw const CorruptDatabaseException(
          'Guest header highest_allocated_revision must be int >= 1.',
        );
      }
      if (currentRevision != null &&
          (currentRevision is! int ||
              currentRevision < 1 ||
              currentRevision > highestAllocated)) {
        throw const CorruptDatabaseException(
          'Guest header current_revision invalid against highest_allocated.',
        );
      }
      if (currentRevision == null) return null;

      final revRows = await db.query(
        'guest_draft_revisions',
        where: 'device_scope = ? AND draft_id = ? AND revision = ?',
        whereArgs: [deviceScope, draftId, currentRevision],
        limit: 1,
      );
      if (revRows.isEmpty) {
        throw const CorruptDatabaseException(
          'Active revision row missing for guest draft.',
        );
      }

      return _mapGuestDraftRevisionRow(revRows.first);
    });
  }

  Future<GuestDraftRevisionRecord?> getDraftRevision({
    required String draftId,
    required int revision,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (revision < 1) throw ArgumentError('revision must be >= 1');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _enqueue(() async {
      final db = _getDb();
      final revRows = await db.query(
        'guest_draft_revisions',
        where: 'device_scope = ? AND draft_id = ? AND revision = ?',
        whereArgs: [deviceScope, draftId, revision],
        limit: 1,
      );
      if (revRows.isEmpty) return null;
      return _mapGuestDraftRevisionRow(revRows.first);
    });
  }

  Future<List<GuestDraftSummaryRecord>> listGuestDrafts({
    String deviceScope = 'default',
  }) {
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _enqueue(() async {
      final db = _getDb();
      final rows = await db.query(
        'guest_drafts',
        where: 'device_scope = ? AND current_revision IS NOT NULL',
        whereArgs: [deviceScope],
        orderBy: 'updated_at DESC',
      );

      final result = <GuestDraftSummaryRecord>[];
      for (final row in rows) {
        final currentRev = row['current_revision'];
        final highestAllocated = row['highest_allocated_revision'];
        if (highestAllocated is! int || highestAllocated < 1) {
          throw const CorruptDatabaseException(
            'Guest header highest_allocated_revision must be int >= 1.',
          );
        }
        if (currentRev is! int ||
            currentRev < 1 ||
            currentRev > highestAllocated) {
          throw const CorruptDatabaseException(
            'Malformed guest draft pointer invariants.',
          );
        }

        final rawUpdatedAt = row['updated_at'] as String? ?? '';
        final updatedAt = _parseStrictUtc(
          rawUpdatedAt,
          'guest_drafts.updated_at',
        );

        result.add(
          GuestDraftSummaryRecord(
            deviceScope: row['device_scope'] as String,
            draftId: row['draft_id'] as String,
            currentRevision: currentRev,
            highestAllocatedRevision: highestAllocated,
            title: row['title'] as String?,
            destinationName: row['destination_name'] as String?,
            updatedAt: updatedAt,
          ),
        );
      }
      return result;
    });
  }

  Future<void> deleteDraft({
    required String draftId,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _enqueue(() async {
      final db = _getDb();
      await db.transaction((txn) async {
        // Check active reservations in import journal (C08)
        final pinnedRows = await txn.query(
          'local_import_journal',
          where: 'device_scope = ? AND draft_id = ? AND state IN (?, ?, ?)',
          whereArgs: [
            deviceScope,
            draftId,
            'staged',
            'pending_ack',
            'quarantined',
          ],
          limit: 1,
        );
        if (pinnedRows.isNotEmpty) {
          throw const DraftRevisionPinnedException(
            'Draft revision is currently pinned in active journal.',
          );
        }

        final headerRows = await txn.query(
          'guest_drafts',
          where: 'device_scope = ? AND draft_id = ?',
          whereArgs: [deviceScope, draftId],
          limit: 1,
        );
        if (headerRows.isEmpty) return;

        final now = _clock();

        // 1. Unlink current_revision pointer FIRST to satisfy ON DELETE RESTRICT (C08)
        await txn.update(
          'guest_drafts',
          {
            'current_revision': null,
            'title': null,
            'destination_name': null,
            'updated_at': now.toIso8601String(),
          },
          where: 'device_scope = ? AND draft_id = ?',
          whereArgs: [deviceScope, draftId],
        );

        // 2. Delete all revisions for this draft
        await txn.delete(
          'guest_draft_revisions',
          where: 'device_scope = ? AND draft_id = ?',
          whereArgs: [deviceScope, draftId],
        );

        // Tombstone header remains with highest_allocated_revision intact! (C08)
      });
    });
  }

  // ==========================================
  // Local Import Journal Operations (C05, C06, C08)
  // ==========================================

  Future<LocalImportJournalRecord> prepareImportJournal({
    required SessionHandle handle,
    required String draftId,
    required int sourceRevision,
    required String requestKey,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (sourceRevision < 1) throw ArgumentError('sourceRevision must be >= 1');
    if (requestKey.trim().isEmpty) {
      throw ArgumentError('requestKey cannot be blank');
    }
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _executeGuardedAccountOperation(handle, (txn) async {
      // 1. Check if requestKey is already used for any other draft/revision under same owner
      final existingKeyRows = await txn.query(
        'local_import_journal',
        where: 'target_owner = ? AND request_key = ?',
        whereArgs: [handle.ownerId, requestKey],
        limit: 1,
      );
      if (existingKeyRows.isNotEmpty) {
        final existing = existingKeyRows.first;
        if (existing['device_scope'] != deviceScope ||
            existing['draft_id'] != draftId ||
            existing['source_revision'] != sourceRevision) {
          throw const DuplicateRequestKeyException(
            'requestKey is already used for another draft or revision.',
          );
        }
      }

      // 2. Check if a journal row already exists for this exact source
      final existingSourceRows = await txn.query(
        'local_import_journal',
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [deviceScope, handle.ownerId, draftId, sourceRevision],
        limit: 1,
      );

      if (existingSourceRows.isNotEmpty) {
        final existing = existingSourceRows.first;
        if (existing['request_key'] != requestKey) {
          throw const ImportAttemptConflictException(
            'Source revision already prepared with a different requestKey.',
          );
        }

        final state = existing['state'] as String;
        if (state == 'committed') {
          // F1: For committed state, the source revision in guest_draft_revisions has already been consumed.
          // Return the existing committed identity and durable receipt without demanding the source.
          final rawReceipt = existing['receipt_payload'];
          final receipt = _parseReceiptPayload(rawReceipt, existing);
          if (receipt == null) {
            throw const CorruptDatabaseException(
              'Committed journal entry missing receipt payload.',
            );
          }

          return LocalImportJournalRecord(
            deviceScope: existing['device_scope'] as String,
            targetOwner: existing['target_owner'] as String,
            draftId: existing['draft_id'] as String,
            sourceRevision: existing['source_revision'] as int,
            requestKey: existing['request_key'] as String,
            contentDigest: existing['content_digest'] as String,
            state: state,
            receiptPayload: rawReceipt as String?,
            createdAt: _parseStrictUtc(
              existing['created_at'] as String,
              'journal.created_at',
            ),
            updatedAt: _parseStrictUtc(
              existing['updated_at'] as String,
              'journal.updated_at',
            ),
            cachedReceipt: receipt,
          );
        }

        // Active attempts (staged, pending_ack, quarantined):
        // Check source revision in guest_draft_revisions
        final sourceRows = await txn.query(
          'guest_draft_revisions',
          where: 'device_scope = ? AND draft_id = ? AND revision = ?',
          whereArgs: [deviceScope, draftId, sourceRevision],
          limit: 1,
        );
        if (sourceRows.isEmpty) {
          throw const ImportAttemptConflictException(
            'Source revision missing during retry.',
          );
        }
        final sourceRec = _mapGuestDraftRevisionRow(sourceRows.first);
        if (sourceRec.digest != existing['content_digest']) {
          throw const ImportAttemptConflictException(
            'Source digest conflicts with journal.',
          );
        }

        final rawReceipt = existing['receipt_payload'];
        final receipt = _parseReceiptPayload(rawReceipt, existing);

        return LocalImportJournalRecord(
          deviceScope: existing['device_scope'] as String,
          targetOwner: existing['target_owner'] as String,
          draftId: existing['draft_id'] as String,
          sourceRevision: existing['source_revision'] as int,
          requestKey: existing['request_key'] as String,
          contentDigest: existing['content_digest'] as String,
          state: state,
          receiptPayload: rawReceipt as String?,
          createdAt: _parseStrictUtc(
            existing['created_at'] as String,
            'journal.created_at',
          ),
          updatedAt: _parseStrictUtc(
            existing['updated_at'] as String,
            'journal.updated_at',
          ),
          cachedReceipt: receipt,
        );
      }

      // 3. Check cross-owner reservation (C08)
      final reservedRows = await txn.query(
        'local_import_journal',
        where: 'device_scope = ? AND draft_id = ? AND source_revision = ? AND state IN (?, ?, ?)',
        whereArgs: [
          deviceScope,
          draftId,
          sourceRevision,
          'staged',
          'pending_ack',
          'quarantined',
        ],
        limit: 1,
      );
      if (reservedRows.isNotEmpty) {
        throw const DraftImportPendingException(
          'Source revision is reserved by another active import.',
        );
      }

      // 4. Verify source draft revision exists and is in permitted draft state
      final sourceRows = await txn.query(
        'guest_draft_revisions',
        where: 'device_scope = ? AND draft_id = ? AND revision = ?',
        whereArgs: [deviceScope, draftId, sourceRevision],
        limit: 1,
      );
      if (sourceRows.isEmpty) {
        throw const ImportJournalNotFoundException(
          'Source draft revision not found.',
        );
      }
      final sourceRec = _mapGuestDraftRevisionRow(sourceRows.first);
      if (sourceRec.state != 'draft') {
        throw const DraftImportPendingException(
          'Source revision is not in draft state.',
        );
      }

      final now = _clock();

      // Plain INSERT with abort-on-conflict, never REPLACE! (C08)
      await txn.insert('local_import_journal', {
        'device_scope': deviceScope,
        'target_owner': handle.ownerId,
        'draft_id': draftId,
        'source_revision': sourceRevision,
        'request_key': requestKey,
        'content_digest': sourceRec.digest,
        'state': 'staged',
        'receipt_payload': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return LocalImportJournalRecord(
        deviceScope: deviceScope,
        targetOwner: handle.ownerId,
        draftId: draftId,
        sourceRevision: sourceRevision,
        requestKey: requestKey,
        contentDigest: sourceRec.digest,
        state: 'staged',
        receiptPayload: null,
        createdAt: now,
        updatedAt: now,
        cachedReceipt: null,
      );
    });
  }

  Future<void> markJournalPendingAck({
    required SessionHandle handle,
    required String draftId,
    required int sourceRevision,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (sourceRevision < 1) throw ArgumentError('sourceRevision must be >= 1');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'local_import_journal',
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [deviceScope, handle.ownerId, draftId, sourceRevision],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const ImportJournalNotFoundException('Journal entry not found.');
      }

      final state = rows.first['state'] as String;
      if (state == 'pending_ack') return; // Idempotent no-op

      if (state == 'staged') {
        final now = _clock();
        await txn.update(
          'local_import_journal',
          {'state': 'pending_ack', 'updated_at': now.toIso8601String()},
          where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
          whereArgs: [deviceScope, handle.ownerId, draftId, sourceRevision],
        );
        return;
      }

      throw ImportAttemptConflictException(
        'Cannot transition state from $state to pending_ack.',
      );
    });
  }

  Future<ImportCommitResult> commitImportAck({
    required SessionHandle handle,
    required LocalImportReceipt receipt,
    required CanonicalTripPayloadV1 payload,
  }) {
    return _executeGuardedAccountOperation(handle, (txn) async {
      final journalRows = await txn.query(
        'local_import_journal',
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [
          receipt.deviceScope,
          handle.ownerId,
          receipt.draftId,
          receipt.sourceRevision,
        ],
        limit: 1,
      );
      if (journalRows.isEmpty) {
        throw const ImportJournalNotFoundException('Journal entry not found.');
      }

      final journal = journalRows.first;
      final persistedReceipt = _parseReceiptPayload(
        journal['receipt_payload'],
        journal,
      );
      final state = journal['state'] as String;

      // 2. Common validation BEFORE both branches (C06)
      final computedDigest = TripPayloadCodec.computeDigest(payload);
      if (computedDigest != journal['content_digest'] ||
          computedDigest != receipt.contentDigest) {
        throw const ReceiptBindingMismatchException(
          'Content digest mismatch across payload, journal, and receipt.',
        );
      }
      if (receipt.targetOwner != handle.ownerId ||
          receipt.deviceScope != journal['device_scope'] ||
          receipt.draftId != journal['draft_id'] ||
          receipt.sourceRevision != journal['source_revision'] ||
          receipt.requestKey != journal['request_key']) {
        throw const ReceiptBindingMismatchException(
          'Receipt bindings do not match journal identity.',
        );
      }

      // 3. Branch A: Committed Idempotence (C05, C06, C07)
      if (state == 'committed') {
        final storedReceipt = persistedReceipt;
        if (storedReceipt == null) {
          throw const CorruptDatabaseException(
            'Committed journal entry missing receipt payload.',
          );
        }
        // Full 10-field equality helper comparison (C05)
        if (!LocalImportReceipt.areReceiptsEqual(storedReceipt, receipt)) {
          throw const ReceiptBindingMismatchException(
            'Conflicting receipt bindings for already committed import.',
          );
        }
        final currentSnapshotRows = await txn.query(
          'account_trip_snapshots',
          where: 'owner_id = ? AND trip_id = ?',
          whereArgs: [handle.ownerId, receipt.tripId],
          limit: 1,
        );
        if (currentSnapshotRows.isEmpty) {
          throw const CorruptDatabaseException(
            'Committed import snapshot missing from account store.',
          );
        }
        final currentSnapshot = _mapAccountSnapshotRow(
          currentSnapshotRows.first,
        );
        return ImportCommitResult(
          receipt: storedReceipt,
          snapshot: currentSnapshot,
        );
      }

      if (state == 'quarantined') {
        throw const ImportAttemptQuarantinedException(
          'Cannot commit quarantined attempt without explicit online reconciliation.',
        );
      }

      // 4. Branch B: First Ack Transfer (C06, C08)
      final sourceRows = await txn.query(
        'guest_draft_revisions',
        where: 'device_scope = ? AND draft_id = ? AND revision = ?',
        whereArgs: [
          receipt.deviceScope,
          receipt.draftId,
          receipt.sourceRevision,
        ],
        limit: 1,
      );
      if (sourceRows.isEmpty) {
        throw const CorruptDatabaseException(
          'Source revision missing during ack commit.',
        );
      }
      final sourceRecord = _mapGuestDraftRevisionRow(sourceRows.first);
      if (sourceRecord.digest != journal['content_digest'] ||
          sourceRecord.digest != computedDigest) {
        throw const CorruptDatabaseException(
          '4-way digest verification failed for source revision.',
        );
      }

      final now = _clock();

      // a. Record receipt in journal
      await txn.update(
        'local_import_journal',
        {
          'state': 'committed',
          'receipt_payload': jsonEncode(receipt.toWhitelistedMap()),
          'updated_at': now.toIso8601String(),
        },
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [
          receipt.deviceScope,
          handle.ownerId,
          receipt.draftId,
          receipt.sourceRevision,
        ],
      );

      if (onAckStepForTesting != null) {
        await onAckStepForTesting!('after_journal_update');
      }

      // b. Upsert snapshot via shared CAS writer
      final snapshot = await _upsertSnapshotTxn(
        txn,
        ownerId: handle.ownerId,
        tripId: receipt.tripId,
        payload: payload,
        remoteVersion: receipt.remoteVersion,
        fetchedAt: receipt.committedAt,
        updatedAt: now,
      );

      if (onAckStepForTesting != null) {
        await onAckStepForTesting!('after_snapshot_upsert');
      }

      // c. Pointer-Safe Consumption (C08)
      final headerRows = await txn.query(
        'guest_drafts',
        where: 'device_scope = ? AND draft_id = ?',
        whereArgs: [receipt.deviceScope, receipt.draftId],
        limit: 1,
      );
      if (headerRows.isNotEmpty) {
        final currentRev = headerRows.first['current_revision'] as int?;
        if (currentRev == receipt.sourceRevision) {
          await txn.update(
            'guest_drafts',
            {
              'current_revision': null,
              'title': null,
              'destination_name': null,
              'updated_at': now.toIso8601String(),
            },
            where: 'device_scope = ? AND draft_id = ?',
            whereArgs: [receipt.deviceScope, receipt.draftId],
          );
        }
      }

      if (onAckStepForTesting != null) {
        await onAckStepForTesting!('after_pointer_null');
      }

      final deletedCount = await txn.delete(
        'guest_draft_revisions',
        where: 'device_scope = ? AND draft_id = ? AND revision = ?',
        whereArgs: [
          receipt.deviceScope,
          receipt.draftId,
          receipt.sourceRevision,
        ],
      );
      if (deletedCount != 1) {
        throw const CorruptDatabaseException(
          'Failed to consume exact source revision row.',
        );
      }

      if (onAckStepForTesting != null) {
        await onAckStepForTesting!('after_source_delete');
      }

      return ImportCommitResult(receipt: receipt, snapshot: snapshot);
    });
  }

  Future<LocalImportJournalRecord> reconcileQuarantinedAttempt({
    required SessionHandle handle,
    required String draftId,
    required int sourceRevision,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (sourceRevision < 1) throw ArgumentError('sourceRevision must be >= 1');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'local_import_journal',
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [deviceScope, handle.ownerId, draftId, sourceRevision],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const ImportJournalNotFoundException('Journal entry not found.');
      }

      final row = rows.first;
      _parseReceiptPayload(row['receipt_payload'], row);
      final state = row['state'] as String;
      if (state != 'quarantined') {
        final rawReceipt = row['receipt_payload'];
        final receipt = _parseReceiptPayload(rawReceipt, row);
        return LocalImportJournalRecord(
          deviceScope: row['device_scope'] as String,
          targetOwner: row['target_owner'] as String,
          draftId: row['draft_id'] as String,
          sourceRevision: row['source_revision'] as int,
          requestKey: row['request_key'] as String,
          contentDigest: row['content_digest'] as String,
          state: state,
          receiptPayload: rawReceipt as String?,
          createdAt: _parseStrictUtc(
            row['created_at'] as String,
            'journal.created_at',
          ),
          updatedAt: _parseStrictUtc(
            row['updated_at'] as String,
            'journal.updated_at',
          ),
          cachedReceipt: receipt,
        );
      }

      final now = _clock();
      await txn.update(
        'local_import_journal',
        {'state': 'pending_ack', 'updated_at': now.toIso8601String()},
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [deviceScope, handle.ownerId, draftId, sourceRevision],
      );

      return LocalImportJournalRecord(
        deviceScope: row['device_scope'] as String,
        targetOwner: row['target_owner'] as String,
        draftId: row['draft_id'] as String,
        sourceRevision: row['source_revision'] as int,
        requestKey: row['request_key'] as String,
        contentDigest: row['content_digest'] as String,
        state: 'pending_ack',
        receiptPayload: null,
        createdAt: _parseStrictUtc(
          row['created_at'] as String,
          'journal.created_at',
        ),
        updatedAt: now,
        cachedReceipt: null,
      );
    });
  }

  Future<LocalImportJournalRecord?> getJournalEntry({
    required SessionHandle handle,
    required String draftId,
    required int sourceRevision,
    String deviceScope = 'default',
  }) {
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (sourceRevision < 1) throw ArgumentError('sourceRevision must be >= 1');
    if (deviceScope.trim().isEmpty) {
      throw ArgumentError('deviceScope cannot be blank');
    }

    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'local_import_journal',
        where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
        whereArgs: [deviceScope, handle.ownerId, draftId, sourceRevision],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final rawReceipt = row['receipt_payload'];
      final receipt = _parseReceiptPayload(rawReceipt, row);

      return LocalImportJournalRecord(
        deviceScope: row['device_scope'] as String,
        targetOwner: row['target_owner'] as String,
        draftId: row['draft_id'] as String,
        sourceRevision: row['source_revision'] as int,
        requestKey: row['request_key'] as String,
        contentDigest: row['content_digest'] as String,
        state: row['state'] as String,
        receiptPayload: rawReceipt as String?,
        createdAt: _parseStrictUtc(
          row['created_at'] as String,
          'journal.created_at',
        ),
        updatedAt: _parseStrictUtc(
          row['updated_at'] as String,
          'journal.updated_at',
        ),
        cachedReceipt: receipt,
      );
    });
  }

  /// Owner-guarded inventory includes attempts for older, no-longer-current revisions.
  Future<List<LocalImportJournalRecord>> listImportJournals({
    required SessionHandle handle,
  }) {
    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'local_import_journal',
        where: 'target_owner = ?',
        whereArgs: [handle.ownerId],
        orderBy: 'updated_at DESC, device_scope ASC, draft_id ASC, source_revision ASC',
      );
      final result = <LocalImportJournalRecord>[];
      for (final row in rows) {
        final state = row['state'];
        if (!{
          'staged',
          'pending_ack',
          'quarantined',
          'committed',
        }.contains(state)) {
          throw const CorruptDatabaseException('Invalid journal state.');
        }
        final receipt = _parseReceiptPayload(row['receipt_payload'], row);
        if (state == 'committed') {
          if (receipt == null) {
            throw const CorruptDatabaseException(
              'Committed journal missing receipt.',
            );
          }
        } else {
          final sources = await txn.query(
            'guest_draft_revisions',
            where: 'device_scope = ? AND draft_id = ? AND revision = ?',
            whereArgs: [
              row['device_scope'],
              row['draft_id'],
              row['source_revision'],
            ],
            limit: 1,
          );
          if (sources.isEmpty ||
              _mapGuestDraftRevisionRow(sources.single).digest !=
                  row['content_digest']) {
            throw const CorruptDatabaseException(
              'Active journal source is missing or inconsistent.',
            );
          }
        }
        result.add(
          LocalImportJournalRecord(
            deviceScope: row['device_scope'] as String,
            targetOwner: row['target_owner'] as String,
            draftId: row['draft_id'] as String,
            sourceRevision: row['source_revision'] as int,
            requestKey: row['request_key'] as String,
            contentDigest: row['content_digest'] as String,
            state: state as String,
            receiptPayload: row['receipt_payload'] as String?,
            createdAt: _parseStrictUtc(
              row['created_at'] as String,
              'journal.created_at',
            ),
            updatedAt: _parseStrictUtc(
              row['updated_at'] as String,
              'journal.updated_at',
            ),
            cachedReceipt: receipt,
          ),
        );
      }
      return List.unmodifiable(result);
    });
  }

  Future<List<LocalImportJournalRecord>> listQuarantinedJournals({
    required SessionHandle handle,
  }) {
    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'local_import_journal',
        where: 'target_owner = ? AND state = ?',
        whereArgs: [handle.ownerId, 'quarantined'],
        orderBy: 'updated_at DESC',
      );

      final result = <LocalImportJournalRecord>[];
      for (final row in rows) {
        final rawReceipt = row['receipt_payload'];
        final receipt = _parseReceiptPayload(rawReceipt, row);
        result.add(
          LocalImportJournalRecord(
            deviceScope: row['device_scope'] as String,
            targetOwner: row['target_owner'] as String,
            draftId: row['draft_id'] as String,
            sourceRevision: row['source_revision'] as int,
            requestKey: row['request_key'] as String,
            contentDigest: row['content_digest'] as String,
            state: 'quarantined',
            receiptPayload: rawReceipt as String?,
            createdAt: _parseStrictUtc(
              row['created_at'] as String,
              'journal.created_at',
            ),
            updatedAt: _parseStrictUtc(
              row['updated_at'] as String,
              'journal.updated_at',
            ),
            cachedReceipt: receipt,
          ),
        );
      }
      return result;
    });
  }

  // ==========================================
  // Snapshot Operations & Shared CAS Writer (C07, C09)
  // ==========================================

  Future<AccountTripSnapshotRecord> _upsertSnapshotTxn(
    DatabaseExecutor txn, {
    required String ownerId,
    required String tripId,
    required CanonicalTripPayloadV1 payload,
    required int? remoteVersion,
    required DateTime fetchedAt,
    required DateTime updatedAt,
  }) async {
    final newDigest = TripPayloadCodec.computeDigest(payload);
    final canonicalJson = TripPayloadCodec.encode(payload);

    final existingRows = await txn.query(
      'account_trip_snapshots',
      where: 'owner_id = ? AND trip_id = ?',
      whereArgs: [ownerId, tripId],
      limit: 1,
    );

    if (existingRows.isNotEmpty) {
      final existingRecord = _mapAccountSnapshotRow(existingRows.first);
      final existingVersion = existingRecord.remoteVersion;
      final existingDigest = existingRecord.digest;
      final existingFetchedAt = existingRecord.fetchedAt;

      if (remoteVersion != null && existingVersion != null) {
        if (remoteVersion < existingVersion) {
          throw SnapshotStaleVersionException(
            'Incoming remoteVersion ($remoteVersion) < existing ($existingVersion)',
          );
        }
        if (remoteVersion == existingVersion) {
          if (newDigest == existingDigest) {
            final touchFetchedAt = fetchedAt.isAfter(existingFetchedAt)
                ? fetchedAt
                : existingFetchedAt;
            await txn.update(
              'account_trip_snapshots',
              {
                'fetched_at': touchFetchedAt.toIso8601String(),
                'updated_at': updatedAt.toIso8601String(),
              },
              where: 'owner_id = ? AND trip_id = ?',
              whereArgs: [ownerId, tripId],
            );
            return AccountTripSnapshotRecord(
              ownerId: ownerId,
              tripId: tripId,
              remoteVersion: existingVersion,
              schemaVersion: 1,
              fetchedAt: touchFetchedAt,
              payloadJson: existingRecord.payloadJson,
              digest: existingDigest,
              title: existingRecord.title,
              destinationName: existingRecord.destinationName,
              startDate: existingRecord.startDate,
              endDate: existingRecord.endDate,
              updatedAt: updatedAt,
              cachedPayload: existingRecord.cachedPayload,
            );
          } else {
            throw SnapshotConflictException(
              'Conflicting content for identical remoteVersion ($remoteVersion)',
            );
          }
        }
      } else if (remoteVersion != null && existingVersion == null) {
        // Upgrade from legacy null version: proceed
      } else if (remoteVersion == null && existingVersion != null) {
        throw const SnapshotStaleVersionException(
          'Cannot overwrite versioned snapshot with unversioned legacy',
        );
      } else {
        // Both null legacy: compare fetchedAt
        if (newDigest == existingDigest) {
          final touchFetchedAt = fetchedAt.isAfter(existingFetchedAt)
              ? fetchedAt
              : existingFetchedAt;
          await txn.update(
            'account_trip_snapshots',
            {
              'fetched_at': touchFetchedAt.toIso8601String(),
              'updated_at': updatedAt.toIso8601String(),
            },
            where: 'owner_id = ? AND trip_id = ?',
            whereArgs: [ownerId, tripId],
          );
          return AccountTripSnapshotRecord(
            ownerId: ownerId,
            tripId: tripId,
            remoteVersion: null,
            schemaVersion: 1,
            fetchedAt: touchFetchedAt,
            payloadJson: existingRecord.payloadJson,
            digest: existingDigest,
            title: existingRecord.title,
            destinationName: existingRecord.destinationName,
            startDate: existingRecord.startDate,
            endDate: existingRecord.endDate,
            updatedAt: updatedAt,
            cachedPayload: existingRecord.cachedPayload,
          );
        }
        if (!fetchedAt.isAfter(existingFetchedAt)) {
          throw const SnapshotStaleVersionException(
            'Incoming unversioned snapshot fetchedAt is older or conflicting.',
          );
        }
      }
    }

    // Projections: deterministic display placeholders, non-mutating (C09)
    final title = computeProjectedTitle(payload);
    final destinationName = computeProjectedDestination(
      payload,
      defaultFallback: 'Điểm đến',
    );

    await txn.insert('account_trip_snapshots', {
      'owner_id': ownerId,
      'trip_id': tripId,
      'remote_version': remoteVersion,
      'schema_version': 1,
      'fetched_at': fetchedAt.toIso8601String(),
      'payload_json': canonicalJson,
      'digest': newDigest,
      'title': title,
      'destination_name': destinationName,
      'start_date': payload.metadata.startDate,
      'end_date': payload.metadata.endDate,
      'updated_at': updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return AccountTripSnapshotRecord(
      ownerId: ownerId,
      tripId: tripId,
      remoteVersion: remoteVersion,
      schemaVersion: 1,
      fetchedAt: fetchedAt,
      payloadJson: canonicalJson,
      digest: newDigest,
      title: title,
      destinationName: destinationName,
      startDate: payload.metadata.startDate,
      endDate: payload.metadata.endDate,
      updatedAt: updatedAt,
      cachedPayload: payload,
    );
  }

  Future<AccountTripSnapshotRecord> replaceSnapshot({
    required SessionHandle handle,
    required String tripId,
    required CanonicalTripPayloadV1 payload,
    int? remoteVersion,
    required DateTime fetchedAt,
  }) {
    if (tripId.trim().isEmpty) throw ArgumentError('tripId cannot be blank');
    if (!fetchedAt.isUtc) throw ArgumentError('fetchedAt must be in UTC');

    return _executeGuardedAccountOperation(handle, (txn) async {
      return await _upsertSnapshotTxn(
        txn,
        ownerId: handle.ownerId,
        tripId: tripId,
        payload: payload,
        remoteVersion: remoteVersion,
        fetchedAt: fetchedAt,
        updatedAt: _clock(),
      );
    });
  }

  Future<AccountTripSnapshotRecord?> getSnapshot({
    required SessionHandle handle,
    required String tripId,
  }) {
    if (tripId.trim().isEmpty) throw ArgumentError('tripId cannot be blank');

    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'account_trip_snapshots',
        where: 'owner_id = ? AND trip_id = ?',
        whereArgs: [handle.ownerId, tripId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapAccountSnapshotRow(rows.first);
    });
  }

  Future<List<AccountTripSnapshotRecord>> listSnapshots({
    required SessionHandle handle,
  }) {
    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'account_trip_snapshots',
        where: 'owner_id = ?',
        whereArgs: [handle.ownerId],
        orderBy: 'fetched_at DESC',
      );
      return rows.map((r) => _mapAccountSnapshotRow(r)).toList();
    });
  }

  Future<bool> deleteSnapshot({
    required SessionHandle handle,
    required String tripId,
  }) {
    if (tripId.trim().isEmpty) throw ArgumentError('tripId cannot be blank');

    return _executeGuardedAccountOperation(handle, (txn) async {
      final count = await txn.delete(
        'account_trip_snapshots',
        where: 'owner_id = ? AND trip_id = ?',
        whereArgs: [handle.ownerId, tripId],
      );
      return count > 0;
    });
  }

  // ==========================================
  // Durable Purge Protocol (C04)
  // ==========================================

  Future<void> purgeAccountData({
    required String targetOwnerId,
    required String reason,
  }) {
    if (targetOwnerId.trim().isEmpty) {
      throw ArgumentError('targetOwnerId cannot be blank');
    }
    if (reason.trim().isEmpty) throw ArgumentError('reason cannot be blank');

    // Step 1: Synchronously unbind in RAM and lock process cache (fail-closed)
    unbindSession();
    _blockedOwners.add(targetOwnerId);

    return _enqueue(() async {
      final db = _getDb();
      final now = _clock();

      // Step 2 (Txn 1): Persist durable marker in separate transaction
      try {
        if (onPurgeStepForTesting != null) {
          await onPurgeStepForTesting!('before_marker_txn');
        }
        await db.transaction((txn) async {
          await txn.insert('local_cleanup_state', {
            'namespace': 'account:$targetOwnerId',
            'is_blocked': 1,
            'purge_pending': 1,
            'reason': reason,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
        if (onPurgeStepForTesting != null) {
          await onPurgeStepForTesting!('after_marker_txn');
        }
      } catch (e) {
        // Lock cache in process (already in _blockedOwners) and throw typed exception
        throw CleanupMarkerPersistenceException(
          'Failed to persist durable cleanup marker: $e',
        );
      }

      // Step 3 (Txn 2): Serialized purge transaction
      if (onPurgeStepForTesting != null) {
        await onPurgeStepForTesting!('before_purge_txn');
      }
      await db.transaction((txn) async {
        await txn.delete(
          'account_trip_snapshots',
          where: 'owner_id = ?',
          whereArgs: [targetOwnerId],
        );
        await onPurgeStepForTesting?.call('inside_purge_txn');
        await txn.delete(
          'local_import_journal',
          where: 'target_owner = ? AND state = ?',
          whereArgs: [targetOwnerId, 'committed'],
        );
        await txn.update(
          'local_import_journal',
          {
            'state': 'quarantined',
            'receipt_payload': null,
            'updated_at': now.toIso8601String(),
          },
          where: 'target_owner = ? AND state IN (?, ?)',
          whereArgs: [targetOwnerId, 'staged', 'pending_ack'],
        );
      });
      if (onPurgeStepForTesting != null) {
        await onPurgeStepForTesting!('after_purge_txn');
      }

      // Step 4 (Txn 3): Complete cleanup (delete marker)
      if (onPurgeStepForTesting != null) {
        await onPurgeStepForTesting!('before_delete_marker_txn');
      }
      await db.transaction((txn) async {
        await txn.delete(
          'local_cleanup_state',
          where: 'namespace = ?',
          whereArgs: ['account:$targetOwnerId'],
        );
        await onPurgeStepForTesting?.call('inside_completion_txn');
      });
      if (onPurgeStepForTesting != null) {
        await onPurgeStepForTesting!('after_delete_marker_txn');
      }

      // Step 5: Namespace unlocked for future verified sessions
      _blockedOwners.remove(targetOwnerId);
    });
  }

  // ==========================================
  // DDL Schema Creation
  // ==========================================

  static Future<void> _createSchema(Database db) async {
    // 1. guest_draft_revisions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guest_draft_revisions (
        device_scope TEXT NOT NULL DEFAULT 'default' CHECK (trim(device_scope) != ''),
        draft_id TEXT NOT NULL CHECK (trim(draft_id) != ''),
        revision INTEGER NOT NULL CHECK (typeof(revision) = 'integer' AND revision >= 1),
        payload_json TEXT NOT NULL CHECK (trim(payload_json) != ''),
        schema_version INTEGER NOT NULL CHECK (typeof(schema_version) = 'integer' AND schema_version = 1),
        digest TEXT NOT NULL CHECK (length(digest) = 64 AND digest NOT GLOB '*[^0-9a-f]*'),
        created_at TEXT NOT NULL CHECK (trim(created_at) != ''),
        state TEXT NOT NULL CHECK (state IN ('draft', 'quarantined', 'imported', 'superseded')),
        PRIMARY KEY (device_scope, draft_id, revision)
      );
    ''');

    // 2. guest_drafts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guest_drafts (
        device_scope TEXT NOT NULL CHECK (trim(device_scope) != ''),
        draft_id TEXT NOT NULL CHECK (trim(draft_id) != ''),
        current_revision INTEGER NULL CHECK (
          current_revision IS NULL OR
          (typeof(current_revision) = 'integer' AND current_revision >= 1 AND current_revision <= highest_allocated_revision)
        ),
        highest_allocated_revision INTEGER NOT NULL CHECK (
          typeof(highest_allocated_revision) = 'integer' AND highest_allocated_revision >= 1
        ),
        title TEXT NULL,
        destination_name TEXT NULL,
        updated_at TEXT NOT NULL CHECK (trim(updated_at) != ''),
        PRIMARY KEY (device_scope, draft_id),
        FOREIGN KEY (device_scope, draft_id, current_revision)
          REFERENCES guest_draft_revisions (device_scope, draft_id, revision)
          ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_guest_drafts_updated
      ON guest_drafts (device_scope, updated_at DESC);
    ''');

    // 3. account_trip_snapshots
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_trip_snapshots (
        owner_id TEXT NOT NULL CHECK (trim(owner_id) != ''),
        trip_id TEXT NOT NULL CHECK (trim(trip_id) != ''),
        remote_version INTEGER NULL CHECK (
          remote_version IS NULL OR
          (typeof(remote_version) = 'integer' AND remote_version >= 1)
        ),
        schema_version INTEGER NOT NULL CHECK (typeof(schema_version) = 'integer' AND schema_version = 1),
        fetched_at TEXT NOT NULL CHECK (trim(fetched_at) != ''),
        payload_json TEXT NOT NULL CHECK (trim(payload_json) != ''),
        digest TEXT NOT NULL CHECK (length(digest) = 64 AND digest NOT GLOB '*[^0-9a-f]*'),
        title TEXT NOT NULL CHECK (trim(title) != ''),
        destination_name TEXT NOT NULL CHECK (trim(destination_name) != ''),
        start_date TEXT NULL,
        end_date TEXT NULL,
        updated_at TEXT NOT NULL CHECK (trim(updated_at) != ''),
        PRIMARY KEY (owner_id, trip_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_snapshots_owner_fetched
      ON account_trip_snapshots (owner_id, fetched_at DESC);
    ''');

    // 4. local_import_journal
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_import_journal (
        device_scope TEXT NOT NULL DEFAULT 'default' CHECK (trim(device_scope) != ''),
        target_owner TEXT NOT NULL CHECK (trim(target_owner) != ''),
        draft_id TEXT NOT NULL CHECK (trim(draft_id) != ''),
        source_revision INTEGER NOT NULL CHECK (typeof(source_revision) = 'integer' AND source_revision >= 1),
        request_key TEXT NOT NULL CHECK (trim(request_key) != ''),
        content_digest TEXT NOT NULL CHECK (length(content_digest) = 64 AND content_digest NOT GLOB '*[^0-9a-f]*'),
        state TEXT NOT NULL CHECK (state IN ('staged', 'pending_ack', 'committed', 'quarantined')),
        receipt_payload TEXT NULL,
        created_at TEXT NOT NULL CHECK (trim(created_at) != ''),
        updated_at TEXT NOT NULL CHECK (trim(updated_at) != ''),
        PRIMARY KEY (device_scope, target_owner, draft_id, source_revision),
        UNIQUE (target_owner, request_key),
        CHECK (
          (state = 'committed' AND receipt_payload IS NOT NULL AND trim(receipt_payload) != '') OR
          (state != 'committed' AND receipt_payload IS NULL)
        )
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_active_source_reservation
      ON local_import_journal (device_scope, draft_id, source_revision)
      WHERE state IN ('staged', 'pending_ack', 'quarantined');
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_owner_state
      ON local_import_journal (target_owner, state);
    ''');

    // 5. local_cleanup_state
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_cleanup_state (
        namespace TEXT NOT NULL PRIMARY KEY CHECK (trim(namespace) != ''),
        is_blocked INTEGER NOT NULL DEFAULT 1 CHECK (is_blocked IN (0, 1)),
        purge_pending INTEGER NOT NULL DEFAULT 1 CHECK (purge_pending IN (0, 1)),
        reason TEXT NOT NULL CHECK (trim(reason) != ''),
        created_at TEXT NOT NULL CHECK (trim(created_at) != ''),
        updated_at TEXT NOT NULL CHECK (trim(updated_at) != ''),
        CHECK (purge_pending = 0 OR is_blocked = 1)
      );
    ''');
  }
}
