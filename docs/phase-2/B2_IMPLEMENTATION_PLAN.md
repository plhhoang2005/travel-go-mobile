# B2 Implementation Plan — Local Store, Records, and Tests (Revision R5.1 / Direction A Delta)

**Date**: 2026-10-10  
**Target Phase**: Phase 2B / Batch B — Packet B2  
**Base Commit**: `0cbebee70b1d2203349beaad8e040c19eaf21671` (`main` after PR #19 merge)  
**Status**: CONVERGED FOR CODEX REVIEW — NO CODE WRITTEN, NO DATABASE APPLIED  
**Authority**: Owner explicitly confirmed **Direction A** in `docs/phase-2/B2_CONVERGENCE_PROPOSAL.md`. Aligns strictly with checklist C01–C10.

**Editing checkpoint**: Codex applied the requested documentation-only repair to the existing R5 plan (input SHA-256 `32A41FEE53CE4E060912DDF5508FF87E532BB4D66A5DD4D4D040AE808ED24AA2`). Prior DDL, receipt parser/equality, payload validation and CAS sketches are preserved. C01–C10 are design self-checks, not independent review PASS; implementation authorization remains with Owner.

---

## 1. Overview & Architecture Boundaries (C01)

### 1.1. Exact 3-File Allowlist
Packet B2 provides the local SQLite persistence layer for TravelGO Mobile. It is strictly constrained to 3 files (allowlist budget <= 5):
1. `lib/features/trips/models/local_trip_records.dart` (NEW) — Immutable typed local records, session handle/context, validated receipt semantics with 10-field equality helper, and domain exceptions.
2. `lib/features/trips/services/local_trip_store.dart` (NEW) — Database lifecycle, strict DDL with FK/CHECK constraints, store-owned monotonic generation fencing, neutral Future queue, pointer-safe atomic transactions, shared snapshot CAS writer, and 5-step purge engine.
3. `test/local_trip_store_test.dart` (NEW) — Real SQLite FFI behavioral verification test suite covering all 15 invariant groups with test-owned temp directory harness and independent error reporting.

### 1.2. Architecture Boundaries & Direction A Responsibility Division (C01)
- **B2 Local Store Responsibility**:
  - `open()` recovers any committed account cleanup markers (`is_blocked = 1` or `purge_pending = 1` in `local_cleanup_state`). It does NOT auto-activate account and does NOT infer authenticated owner from SQLite data.
  - Store clearly distinguishes DB readiness (`_isOpened`) from account authorization.
  - Guest APIs do NOT require account activation.
  - `activateSession` receives binding from trusted auth coordinator (B6). Store does not store secrets.
  - Its owner/epoch arguments represent that trusted integration binding; they are not an authentication proof by themselves. Only B6 may populate them in product wiring, after establishing non-demo current auth subject. Tests may supply controlled auth inputs. No UI entry point or SQLite row may mint an authorized session.
  - Activation captures request generation synchronously when requested. `unbindSession` synchronously advances generation, cancels any pending activation, and clears RAM active state.
  - Queue re-checks captured generation before/after awaited work and before publish.
  - If activation/queue fails, RAM does not stay active. If commit already happened during cancellation, do not publish and cleanup is executed before reactivation.
  - Queue is a neutral serializer (no `action != open` bypass). Account wrapper returns transaction results directly, guarding when queue runs, inside transaction, and before publish.
  - `purgeAccountData` always invalidates in RAM before awaiting queue. 3 separate transactions within 1 queued action: Marker commit -> Purge snapshots/committed receipts + quarantine metadata -> Completion commit (delete marker). All errors return typed results. Remote trips and untransferred Guest drafts are NOT deleted.
  - If marker commit fails: B2 locks account cache in current process and throws `CleanupMarkerPersistenceException`. Contract requires coordinator (B6) not to report logout/cleanup success and handle startup authorization; B2 does not promise a marker is durable when the write itself failed.
  - **No `session:active` registry in B2**: B2 relies strictly on account cleanup markers (`account:$ownerId`).
- **B6 Obligations (Deferred to B6 / Pre-Feature Activation)**:
  - B6 proves current subject from trusted auth state, including offline restart of still-valid session, expiry, logout, and account switch; does not use snapshot rows as authority.
  - Persists/recovers logout/cleanup decision in auth/lifecycle where appropriate. If unable to prove valid session or distinguish cleanup failure, denies account cache and completes safe purge/revalidation.
  - AC-016 and marker-failure restart are integration acceptance of B6/B9. B2 does NOT claim AC-016 or E2E recovery PASS.
  - B6 must not remove an unfinished purge marker just because login succeeds. If durable auth/lifecycle state cannot distinguish failed logout from still-valid offline session, account access stays denied until safe cleanup/revalidation; B6 must supply integration evidence before enabling account-cache wiring. Guest drafts remain a separate local namespace, subject to database availability.
- **Permanent Constraints**:
  - No dependencies added (`sqflite: 2.4.4+1`, `sqflite_common_ffi: 2.4.3`, `crypto: 3.0.7`, `uuid: 4.6.0`, `path: 1.9.1`).
  - No UI/Provider/Service wiring in B2.
  - No Supabase database apply, no backend edits.
  - Owner Decisions 1A–5A preserved.

---

## 2. Concrete SQLite DDL & Integrity Constraints (C08)

Executed inside `onConfigure` and `onCreate` callbacks of `openDatabase`:

```sql
-- onConfigure: Foreign Keys MUST be enforced on every connection
PRAGMA foreign_keys = ON;

-- 1. guest_draft_revisions
-- Stores immutable append-only snapshots of drafts. Never updated, never replaced.
-- Hex check enforces exact 64 lowercase hex characters: length=64 AND NOT GLOB '*[^0-9a-f]*'.
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

-- 2. guest_drafts
-- Tracks current active revision pointer and monotonically increasing highest allocated revision.
-- FOREIGN KEY enforces scoped pointer referential integrity with ON DELETE RESTRICT.
-- highest_allocated_revision ensures revision numbers are NEVER reused even after deleting or consuming drafts.
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

CREATE INDEX IF NOT EXISTS idx_guest_drafts_updated
ON guest_drafts (device_scope, updated_at DESC);

-- 3. account_trip_snapshots
-- Read-only local cache of trips owned by authenticated users.
-- Replaced only atomically after complete validation and authoritative version CAS.
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

CREATE INDEX IF NOT EXISTS idx_snapshots_owner_fetched
ON account_trip_snapshots (owner_id, fetched_at DESC);

-- 4. local_import_journal
-- Tracks import lifecycle from local guest draft to remote account trip.
-- Composite PK includes device_scope, target_owner, draft_id, and source_revision.
-- request_key is uniquely bound per target_owner.
-- CHECK constraints enforce that receipt_payload is present ONLY when state = 'committed'.
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

-- Cross-owner reservation index: prevents Owner B from claiming an active source revision of Owner A
CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_active_source_reservation
ON local_import_journal (device_scope, draft_id, source_revision)
WHERE state IN ('staged', 'pending_ack', 'quarantined');

CREATE INDEX IF NOT EXISTS idx_journal_owner_state
ON local_import_journal (target_owner, state);

-- 5. local_cleanup_state
-- Durable fail-closed marker for namespace purges.
-- purge_pending = 1 strictly implies is_blocked = 1.
CREATE TABLE IF NOT EXISTS local_cleanup_state (
  namespace TEXT NOT NULL PRIMARY KEY CHECK (trim(namespace) != ''),
  is_blocked INTEGER NOT NULL DEFAULT 1 CHECK (is_blocked IN (0, 1)),
  purge_pending INTEGER NOT NULL DEFAULT 1 CHECK (purge_pending IN (0, 1)),
  reason TEXT NOT NULL CHECK (trim(reason) != ''),
  created_at TEXT NOT NULL CHECK (trim(created_at) != ''),
  updated_at TEXT NOT NULL CHECK (trim(updated_at) != ''),
  CHECK (purge_pending = 0 OR is_blocked = 1)
);
```

---

## 3. Typed Records, Strict Receipt Deserialization & Exceptions (`local_trip_records.dart`) (C05)

### 3.1. Store-Owned Monotonic Session Handle
```dart
class SessionHandle {
  final String ownerId;
  final int coordinatorEpoch;
  final int storeGeneration;
  final bool isDemoSession;

  const SessionHandle({
    required this.ownerId,
    required this.coordinatorEpoch,
    required this.storeGeneration,
    required this.isDemoSession,
  });

  void validate() {
    if (ownerId.trim().isEmpty) {
      throw const UnauthorizedAccountAccessException('ownerId cannot be blank.');
    }
    if (isDemoSession) {
      throw const UnauthorizedAccountAccessException('Demo sessions cannot access persistent account store.');
    }
    if (storeGeneration < 1) {
      throw const UnauthorizedAccountAccessException('Invalid store generation.');
    }
  }
}
```

### 3.2. Strict Local Import Receipt Deserializer & 10-Field Equality Helper (C05)
```dart
class LocalImportReceipt {
  static const Set<String> permittedKeys = {
    'deviceScope',
    'targetOwner',
    'draftId',
    'sourceRevision',
    'requestKey',
    'contentDigest',
    'receiptId',
    'tripId',
    'remoteVersion',
    'committedAt',
  };

  final String deviceScope;
  final String targetOwner;
  final String draftId;
  final int sourceRevision;
  final String requestKey;
  final String contentDigest;
  final String receiptId;
  final String tripId;
  final int remoteVersion;
  final DateTime committedAt;

  LocalImportReceipt({
    required this.deviceScope,
    required this.targetOwner,
    required this.draftId,
    required this.sourceRevision,
    required this.requestKey,
    required this.contentDigest,
    required this.receiptId,
    required this.tripId,
    required this.remoteVersion,
    required this.committedAt,
  }) {
    if (deviceScope.trim().isEmpty) throw ArgumentError('deviceScope cannot be blank');
    if (targetOwner.trim().isEmpty) throw ArgumentError('targetOwner cannot be blank');
    if (draftId.trim().isEmpty) throw ArgumentError('draftId cannot be blank');
    if (sourceRevision < 1) throw ArgumentError('sourceRevision must be >= 1');
    if (requestKey.trim().isEmpty) throw ArgumentError('requestKey cannot be blank');
    if (contentDigest.length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentDigest)) {
      throw ArgumentError('contentDigest must be 64 lowercase hex characters');
    }
    if (receiptId.trim().isEmpty) throw ArgumentError('receiptId cannot be blank');
    if (tripId.trim().isEmpty) throw ArgumentError('tripId cannot be blank');
    if (remoteVersion < 1) throw ArgumentError('remoteVersion must be >= 1');
    if (!committedAt.isUtc) throw ArgumentError('committedAt must be in UTC');
  }

  Map<String, dynamic> toWhitelistedMap() => {
    'deviceScope': deviceScope,
    'targetOwner': targetOwner,
    'draftId': draftId,
    'sourceRevision': sourceRevision,
    'requestKey': requestKey,
    'contentDigest': contentDigest,
    'receiptId': receiptId,
    'tripId': tripId,
    'remoteVersion': remoteVersion,
    'committedAt': committedAt.toIso8601String(),
  };

  factory LocalImportReceipt.fromMap(Map<String, dynamic> map) {
    // 1. Strict key check: disallow extra or missing keys
    final keys = map.keys.toSet();
    if (keys.length != permittedKeys.length || !keys.containsAll(permittedKeys)) {
      throw const CorruptDatabaseException('Receipt JSON contains invalid or extra keys.');
    }

    // 2. Strict integer type check: NO .toInt() rounding/truncation
    final rawSourceRev = map['sourceRevision'];
    if (rawSourceRev is! int) {
      throw const CorruptDatabaseException('Receipt sourceRevision must be strict integer, got fractional or non-int.');
    }

    final rawRemoteVer = map['remoteVersion'];
    if (rawRemoteVer is! int) {
      throw const CorruptDatabaseException('Receipt remoteVersion must be strict integer, got fractional or non-int.');
    }

    // 3. Strict UTC string validation (must end with Z, no arbitrary offsets)
    final rawCommittedAt = map['committedAt'];
    if (rawCommittedAt is! String || !rawCommittedAt.endsWith('Z')) {
      throw const CorruptDatabaseException('Receipt committedAt must be strict ISO-8601 UTC string ending with Z.');
    }

    DateTime committedAt;
    try {
      committedAt = DateTime.parse(rawCommittedAt);
      if (!committedAt.isUtc) throw const FormatException();
    } catch (_) {
      throw const CorruptDatabaseException('Malformed receipt committedAt timestamp.');
    }

    try {
      return LocalImportReceipt(
        deviceScope: map['deviceScope'] as String,
        targetOwner: map['targetOwner'] as String,
        draftId: map['draftId'] as String,
        sourceRevision: rawSourceRev,
        requestKey: map['requestKey'] as String,
        contentDigest: map['contentDigest'] as String,
        receiptId: map['receiptId'] as String,
        tripId: map['tripId'] as String,
        remoteVersion: rawRemoteVer,
        committedAt: committedAt,
      );
    } catch (e) {
      throw CorruptDatabaseException('Malformed receipt structure: $e');
    }
  }

  // Single equality helper comparing all 10 fields (C05)
  static bool areReceiptsEqual(LocalImportReceipt a, LocalImportReceipt b) {
    return a.deviceScope == b.deviceScope &&
        a.targetOwner == b.targetOwner &&
        a.draftId == b.draftId &&
        a.sourceRevision == b.sourceRevision &&
        a.requestKey == b.requestKey &&
        a.contentDigest == b.contentDigest &&
        a.receiptId == b.receiptId &&
        a.tripId == b.tripId &&
        a.remoteVersion == b.remoteVersion &&
        a.committedAt == b.committedAt;
  }
}

class ImportCommitResult {
  final LocalImportReceipt receipt;
  final AccountTripSnapshotRecord snapshot;

  const ImportCommitResult({
    required this.receipt,
    required this.snapshot,
  });
}
```

### 3.3. Typed Domain Exceptions
- `LocalTripStoreException`: Base class.
- `UnsupportedDatabaseVersionException`: When local database file schema version > 1.
- `CorruptDatabaseException`: When SQLite database header, table, or stored bytes fail verification.
- `AccountNamespaceBlockedException`: When attempting account operations while `local_cleanup_state.is_blocked = 1`.
- `UnauthorizedAccountAccessException`: When accessing account data without valid auth context.
- `StaleSessionEpochException`: When operation handle store generation does not match active store generation.
- `DraftImportPendingException`: When attempting to stage/import a source revision already reserved by an active/quarantined journal entry.
- `ImportAttemptConflictException`: When a journal entry for the same source is re-prepared with conflicting requestKey or digest.
- `DuplicateRequestKeyException`: When a requestKey is reused for a different draft/revision under the same owner.
- `ImportJournalNotFoundException`: When attempting to commit an ack without pre-existing staged journal.
- `ReceiptBindingMismatchException`: When committing an ack whose bindings mismatch journal or stored receipt.
- `ImportAttemptQuarantinedException`: When attempting to commit a quarantined journal entry without explicit online reconciliation.
- `SnapshotStaleVersionException`: When incoming remoteVersion is lower than existing remoteVersion.
- `SnapshotConflictException`: When incoming snapshot has same remoteVersion but different content digest.
- `CleanupMarkerPersistenceException`: When persisting fail-closed marker to disk fails.
- `DraftRevisionPinnedException`: When attempting to delete a guest draft whose revision is currently pinned in active journal.
- `StoreUnavailableException`: When store is uninitialized or in persistent fail-closed recovery state.

---

## 4. Neutral Queue & Lifecycle Sequence (C02, C03)

### 4.1. Store Class Architecture & Monotonic Generation Fencing
```dart
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

  LocalTripStore({
    DatabaseFactory? databaseFactory,
    required String databasePath,
    DateTime Function()? clock,
  }) : _databaseFactory = databaseFactory ?? databaseFactorySqflite,
       _databasePath = databasePath,
       _clock = clock ?? (() => DateTime.now().toUtc());

  // Neutral queue without action != open bypass (C02)
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lastQueueTask = _lastQueueTask.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }, onError: (_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // Open lifecycle: recovers any committed account cleanup markers (C01, C02)
  Future<void> open() {
    return _enqueue(() async {
      if (_isOpened) return;
      if (_db != null) {
        throw const StoreUnavailableException('Retry close of failed connection before reopening.');
      }
      _db = await _databaseFactory.openDatabase(
        _databasePath,
        options: OpenDatabaseOptions(
          version: databaseSchemaVersion,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async => await _createSchema(db),
          onUpgrade: (db, oldVersion, newVersion) async => throw const UnsupportedDatabaseVersionException('Unsupported upgrade.'),
          onDowngrade: (db, oldVersion, newVersion) async => throw const UnsupportedDatabaseVersionException('Unsupported downgrade.'),
        ),
      );
      try {
        // Internal helper uses this connection directly, never nested _enqueue.
        // Keep readiness false until all committed markers are recovered.
        await _recoverCommittedMarkersOnStartup();
        _isOpened = true;
      } catch (e, st) {
        _isOpened = false;
        unbindSession();
        try {
          await _db?.close();
          _db = null;
        } catch (_) {
          // Preserve primary recovery error; report secondary close error as
          // diagnostics in implementation and retain connection for close retry.
        }
        Error.throwWithStackTrace(e, st);
      }
    });
  }

  Future<void> close() {
    // Cancel active/pending handles immediately, before waiting for disk work.
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

  // Asynchronous guarded session activation under queue with cancellation protection (C02)
  Future<SessionHandle> activateSession({
    required String ownerId,
    required int coordinatorEpoch,
    bool isDemo = false,
  }) {
    if (!_isOpened) throw const StoreUnavailableException('Store is not opened.');
    if (ownerId.trim().isEmpty) throw ArgumentError('ownerId cannot be blank');
    if (isDemo) throw const UnauthorizedAccountAccessException('Demo sessions cannot bind account store.');

    // Reserve a UNIQUE generation synchronously; supersedes older pending
    // activations and clears old RAM before this request waits in the queue.
    final requestedGeneration = ++_storeGeneration;
    _activeOwnerId = null;
    _activeCoordinatorEpoch = null;
    _isDemo = false;

    return _enqueue(() async {
      if (!_isOpened) throw const StoreUnavailableException('Store is not opened.');
      
      // If unbindSession was called while waiting in queue, generation was advanced -> cancel!
      if (_storeGeneration != requestedGeneration) {
        throw const StaleSessionEpochException('Activation canceled by intervening unbind.');
      }

      final db = _getDb();
      if (_blockedOwners.contains(ownerId)) {
        throw AccountNamespaceBlockedException('Account cleanup must complete before activation.');
      }
      // Check for blocked cleanup markers
      final blocked = await db.query(
        'local_cleanup_state',
        where: 'namespace = ? AND (is_blocked = 1 OR purge_pending = 1)',
        whereArgs: ['account:$ownerId'],
      );
      if (blocked.isNotEmpty) {
        throw AccountNamespaceBlockedException('Account namespace is blocked pending cleanup: $ownerId');
      }

      // The await above can race synchronous unbind/close/new activation.
      // Check again BEFORE assigning RAM. No await between here and publication.
      if (!_isOpened || _storeGeneration != requestedGeneration) {
        throw const StaleSessionEpochException('Activation canceled while checking cleanup.');
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

  // Synchronous invalidation advances generation immediately and clears RAM (C02)
  void unbindSession() {
    _storeGeneration++;
    _activeOwnerId = null;
    _activeCoordinatorEpoch = null;
    _isDemo = false;
  }

  void _assertSessionHandle(SessionHandle handle) {
    if (!_isOpened || _db == null) {
      throw const StoreUnavailableException('Account store is not ready.');
    }
    handle.validate();
    if (_blockedOwners.contains(handle.ownerId)) {
      throw const AccountNamespaceBlockedException('Account cleanup is incomplete.');
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
}
```

---

## 5. All-Read Validation & Checked Mappers (C07)

The public checked mappers below wrap syntax/codec and SQL-row type/date errors in local typed results. Implementation also validates nonblank scoped IDs, positive integer revision/known version, permitted state and strict UTC timestamp syntax before returning records. Row/envelope schema must agree. No private unchecked mapper may be called from a public read, list, ack or CAS branch; it is only the body of its checked wrapper. Account payload must have a complete plan; Guest payload may be request-only. Projection fields must follow the shared projection policy and must not contradict explicit metadata.

```dart
CanonicalTripPayloadV1 _validateAndDecodePayload(String payloadJson, String storedDigest) {
  // 1. Verify SHA-256 over raw UTF-8 bytes matches stored digest
  final actualDigest = sha256.convert(utf8.encode(payloadJson)).toString();
  if (actualDigest != storedDigest) {
    throw const CorruptDatabaseException('Payload bytes SHA-256 mismatch with stored digest.');
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
      throw const CorruptDatabaseException('Stored payload bytes are not canonical JSON.');
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

AccountTripSnapshotRecord _mapAccountSnapshotRowUnchecked(Map<String, dynamic> row) {
  final rowSchemaVersion = row['schema_version'] as int;
  if (rowSchemaVersion != 1) {
    throw const CorruptDatabaseException('Row schema_version must be 1.');
  }
  final payloadJson = row['payload_json'] as String;
  final storedDigest = row['digest'] as String;
  final payload = _validateAndDecodePayload(payloadJson, storedDigest);

  // Complete plan required on account snapshots (C07)
  if (payload.plan == null) {
    throw const CorruptDatabaseException('Account snapshot must contain complete usable plan.');
  }

  return AccountTripSnapshotRecord(
    ownerId: row['owner_id'] as String,
    tripId: row['trip_id'] as String,
    remoteVersion: row['remote_version'] as int?,
    schemaVersion: 1,
    fetchedAt: DateTime.parse(row['fetched_at'] as String).toUtc(),
    payloadJson: payloadJson,
    digest: storedDigest,
    title: row['title'] as String,
    destination_name: row['destination_name'] as String,
    startDate: row['start_date'] as String?,
    endDate: row['end_date'] as String?,
    updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
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

GuestDraftRevisionRecord _mapGuestDraftRevisionRowUnchecked(Map<String, dynamic> row) {
  final rowSchemaVersion = row['schema_version'] as int;
  if (rowSchemaVersion != 1) {
    throw const CorruptDatabaseException('Row schema_version must be 1.');
  }
  final payloadJson = row['payload_json'] as String;
  final storedDigest = row['digest'] as String;
  final payload = _validateAndDecodePayload(payloadJson, storedDigest);

  return GuestDraftRevisionRecord(
    deviceScope: row['device_scope'] as String,
    draftId: row['draft_id'] as String,
    revision: row['revision'] as int,
    payloadJson: payloadJson,
    schemaVersion: 1,
    digest: storedDigest,
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    state: row['state'] as String,
    cachedPayload: payload,
  );
}
```

---

## 6. Public API Contract Table & Common Execution Template (C02, C03)

### 6.1. Public API Contract Table
| Category | Method Signature | Fencing & Guards | Return Type | Failure Modes |
| :--- | :--- | :--- | :--- | :--- |
| **Lifecycle** | `open()` | Queued, single execution | `Future<void>` | `UnsupportedDatabaseVersionException`, `CorruptDatabaseException` |
| **Lifecycle** | `close()` | Queued, flushes queue | `Future<void>` | Safe error propagation |
| **Lifecycle** | `activateSession(ownerId, epoch, isDemo)` | Queued, checks markers, monotonic | `Future<SessionHandle>` | `AccountNamespaceBlockedException`, `UnauthorizedAccountAccessException` |
| **Lifecycle** | `unbindSession()` | Synchronous in RAM | `void` | None (immediate generation bump) |
| **Lifecycle** | `purgeAccountData(targetOwnerId, reason)` | Queued, 3-step transactions | `Future<void>` | `CleanupMarkerPersistenceException` |
| **Guest** | `saveDraftRevision(draftId, payload, scope)` | Queued, monotonic counter | `Future<GuestDraftRevisionRecord>` | Rollback on failure |
| **Guest** | `getLatestDraft(draftId, scope)` | Queued, checked mapper | `Future<GuestDraftRevisionRecord?>` | `CorruptDatabaseException` |
| **Guest** | `getDraftRevision(draftId, revision, scope)` | Queued, checked mapper | `Future<GuestDraftRevisionRecord?>` | `CorruptDatabaseException` |
| **Guest** | `listGuestDrafts(scope)` | Queued, filter active pointer | `Future<List<GuestDraftSummaryRecord>>` | Empty list if none |
| **Guest** | `deleteDraft(draftId, scope)` | Queued, pointer-safe tombstone | `Future<void>` | `DraftRevisionPinnedException` |
| **Journal** | `prepareImportJournal(handle, draftId, rev, key, scope)` | 3-layer fencing, source check | `Future<LocalImportJournalRecord>` | `ImportAttemptConflictException`, `DuplicateRequestKeyException`, `DraftImportPendingException` |
| **Journal** | `markJournalPendingAck(handle, draftId, rev, scope)` | 3-layer fencing | `Future<void>` | `ImportJournalNotFoundException` |
| **Journal** | `commitImportAck(handle, receipt, payload)` | 3-layer fencing, pointer-safe ack | `Future<ImportCommitResult>` | `ReceiptBindingMismatchException`, `ImportAttemptQuarantinedException` |
| **Journal** | `getJournalEntry(handle, draftId, rev, scope)` | 3-layer fencing | `Future<LocalImportJournalRecord?>` | `StaleSessionEpochException` |
| **Journal** | `listQuarantinedJournals(handle)` | 3-layer fencing, owner-scoped | `Future<List<LocalImportJournalRecord>>` | Empty list if none |
| **Journal** | `reconcileQuarantinedAttempt(handle, draftId, rev, scope)` | 3-layer fencing, owner check | `Future<LocalImportJournalRecord>` | `ImportJournalNotFoundException` |
| **Snapshot**| `replaceSnapshot(handle, tripId, payload, ver, fetchedAt)` | 3-layer fencing, CAS writer | `Future<AccountTripSnapshotRecord>` | `SnapshotStaleVersionException`, `SnapshotConflictException` |
| **Snapshot**| `getSnapshot(handle, tripId)` | 3-layer fencing, checked mapper | `Future<AccountTripSnapshotRecord?>` | `CorruptDatabaseException`, `StaleSessionEpochException` |
| **Snapshot**| `listSnapshots(handle)` | 3-layer fencing, checked mapper | `Future<List<AccountTripSnapshotRecord>>` | `CorruptDatabaseException`, `StaleSessionEpochException` |
| **Snapshot**| `deleteSnapshot(handle, tripId)` | 3-layer fencing | `Future<bool>` | `StaleSessionEpochException` |

### 6.2. Common Execution Template (C03)
```dart
Future<T> _executeGuardedAccountOperation<T>(
  SessionHandle handle,
  Future<T> Function(DatabaseExecutor txn) action,
) {
  return _enqueue(() async {
    // 1. Layer 1 Guard (Queue Entry)
    _assertSessionHandle(handle);

    final db = _getDb();
    final result = await db.transaction<T>((txn) async {
      // 2. Layer 2 Guard (Inside Transaction Boundary)
      _assertSessionHandle(handle);
      await _assertNamespaceNotBlocked(txn, handle.ownerId);
      _assertSessionHandle(handle); // invalidation may happen during marker read

      // 3. Verified Operation Execution
      final value = await action(txn);
      _assertSessionHandle(handle); // roll back stale mutation where possible
      return value;
    });

    // 4. Layer 3 Guard (Pre-Publication Boundary)
    _assertSessionHandle(handle);

    return result;
  });
}
```

---

### 6.3. Preserved Atomic Operations and Private Mutation Rules (C08)

All sequences below use one queued action and one transaction executor; errors roll back every statement. Immutable revision payload/schema/digest/created_at never have an UPDATE or REPLACE API. Historical source rows remain readable except consumed/deleted rows; revisions already pinned by an active journal cannot be deleted by Guest operations.

- **saveDraftRevision:** read scoped header/high-water -> allocate next integer revision -> encode frozen B1 payload/digest -> INSERT revision first -> INSERT/UPDATE matching header pointer/high-water/projections -> return checked record. A tombstone keeps its high-water; never lower it or reuse revision numbers. Validate high-water against present revisions; an invalid pointer/counter is corruption, not a new empty draft.
- **deleteDraft:** query scoped active reservations (staged/pending_ack/quarantined); if pinned, typed rejection -> clear pointer and title/destination projections -> delete scoped revisions -> retain header/high-water tombstone. Remote trips are untouched.
- **prepareImportJournal:** use guarded account wrapper; resolve scoped existing source/key identities. Exact existing binding returns unchanged row/state, conflicting source key/digest rejects, reused owner key for ANY different scope/draft/revision rejects. New source must exist with permitted unconsumed state, checked canonical payload and matching digest. Check cross-owner reservation; plain INSERT with abort-on-conflict, never journal REPLACE. Constraint race maps to typed conflict/pending without revealing another owner's identity. Missing source after committed transfer cannot create a new attempt. Quarantined/committed prepare result never authorizes resending.
- **markJournalPendingAck:** only staged -> pending_ack; same pending row is no-op. Committed/quarantined cannot regress. Preserve owner/scope/source/key/digest; missing identity gives typed error.
- **reconcileQuarantinedAttempt:** B4 trusted online coordinator must first confirm the same owner/source/key/digest and server outcome. B2 supplies the owner-fenced local primitive, never does network validation. Only matching quarantined -> pending_ack is allowed to resume that exact attempt; conflicting identity rejects. B cannot read/resume A. Receipt ack then uses unchanged original identity.
- **Reads/listing:** payload reads use checked mappers; Guest summary list filters non-null current pointers and validates header integrity. Snapshot/journal reads are owner-scoped; stored receipt parsing/binding errors are typed corruption. No read repairs or deletes corrupt/future-version rows silently.

---

## 7. Concrete Snapshot CAS Writer & Import Ack (C05, C06, C07, C08, C09)

### 7.1. Shared Snapshot CAS Writer (`_upsertSnapshotTxn`) (C07, C09)

**Ordering contract:** `fetchedAt` is UTC captured when the trusted coordinator starts the fetch, never response arrival time; a delayed older fetch therefore carries an older capture. Equal capture with different content rejects; equal/older capture with identical content only touches by max timestamp. Capture ordering is local cache freshness for legacy rows, not a server version claim. Coordinator serializes legacy captures or supplies consistent strictly ordered capture values; clock ambiguity must not be used as proof of freshness. Versioned rows always use authoritative remote version first. No Decision Engine calculations are repeated. Generated title/destination projections are display placeholders only; they do not assert selection or mutate payload.
```dart
Future<AccountTripSnapshotRecord> _upsertSnapshotTxn(
  DatabaseExecutor txn, {
  required String ownerId,
  required String tripId,
  required CanonicalTripPayloadV1 payload,
  required int? remoteVersion,
  required DateTime fetchedAt,
  required DateTime updatedAt,
}) async {
  if (payload.plan == null) {
    throw ArgumentError('Account snapshot requires complete usable plan.');
  }

  final newDigest = TripPayloadCodec.computeDigest(payload);
  final canonicalJson = TripPayloadCodec.encode(payload);

  final existingRows = await txn.query(
    'account_trip_snapshots',
    where: 'owner_id = ? AND trip_id = ?',
    whereArgs: [ownerId, tripId],
    limit: 1,
  );

  if (existingRows.isNotEmpty) {
    // Validate existing row through checked mapper first! (C07)
    final existingRecord = _mapAccountSnapshotRow(existingRows.first);
    final existingVersion = existingRecord.remoteVersion;
    final existingDigest = existingRecord.digest;
    final existingFetchedAt = existingRecord.fetchedAt;

    if (remoteVersion != null && existingVersion != null) {
      if (remoteVersion < existingVersion) {
        throw SnapshotStaleVersionException('Incoming remoteVersion ($remoteVersion) < existing ($existingVersion)');
      }
      if (remoteVersion == existingVersion) {
        if (newDigest == existingDigest) {
          // Idempotent safe touch: only update fetched_at if newer (C09)
          final touchFetchedAt = fetchedAt.isAfter(existingFetchedAt) ? fetchedAt : existingFetchedAt;
          await txn.update(
            'account_trip_snapshots',
            {'fetched_at': touchFetchedAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()},
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
            destination_name: existingRecord.destinationName,
            startDate: existingRecord.startDate,
            endDate: existingRecord.endDate,
            updatedAt: updatedAt,
            cachedPayload: existingRecord.payload,
          );
        } else {
          throw SnapshotConflictException('Conflicting content for identical remoteVersion ($remoteVersion)');
        }
      }
      // remoteVersion > existingVersion: proceed to overwrite
    } else if (remoteVersion != null && existingVersion == null) {
      // Versioned upgrade over legacy unversioned: proceed to overwrite
    } else if (remoteVersion == null && existingVersion != null) {
      throw SnapshotStaleVersionException('Cannot overwrite versioned snapshot with unversioned legacy');
    } else {
      // Both null legacy: compare fetchedAt (C09)
      if (newDigest == existingDigest) {
        final touchFetchedAt = fetchedAt.isAfter(existingFetchedAt) ? fetchedAt : existingFetchedAt;
        await txn.update(
          'account_trip_snapshots',
          {'fetched_at': touchFetchedAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String()},
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
          destination_name: existingRecord.destinationName,
          startDate: existingRecord.startDate,
          endDate: existingRecord.endDate,
          updatedAt: updatedAt,
          cachedPayload: existingRecord.payload,
        );
      }
      if (!fetchedAt.isAfter(existingFetchedAt)) {
        throw SnapshotStaleVersionException('Incoming unversioned snapshot fetchedAt is older or conflicting.');
      }
      // fetchedAt is strictly newer: proceed to overwrite
    }
  }

  // Projections: deterministic display placeholders, non-mutating (C09)
  final title = payload.metadata.title ??
      (payload.plan!.topDestinations.isNotEmpty ? 'Chuyến đi ${payload.plan!.topDestinations.first.name}' : 'Chuyến đi');
  final destinationName = payload.metadata.destinationName ??
      (payload.plan!.topDestinations.isNotEmpty ? payload.plan!.topDestinations.first.name : 'Điểm đến');

  await txn.insert(
    'account_trip_snapshots',
    {
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
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  return AccountTripSnapshotRecord(
    ownerId: ownerId,
    tripId: tripId,
    remoteVersion: remoteVersion,
    schemaVersion: 1,
    fetchedAt: fetchedAt,
    payloadJson: canonicalJson,
    digest: newDigest,
    title: title,
    destination_name: destinationName,
    startDate: payload.metadata.startDate,
    endDate: payload.metadata.endDate,
    updatedAt: updatedAt,
    cachedPayload: payload,
  );
}
```

### 7.2. Commit Import Ack Implementation (C05, C06, C07, C08)
```dart
Future<ImportCommitResult> commitImportAck({
  required SessionHandle handle,
  required LocalImportReceipt receipt,
  required CanonicalTripPayloadV1 payload,
}) {
  return _executeGuardedAccountOperation(handle, (txn) async {
    // 1. Query journal row
    final journalRows = await txn.query(
      'local_import_journal',
      where: 'device_scope = ? AND target_owner = ? AND draft_id = ? AND source_revision = ?',
      whereArgs: [receipt.deviceScope, handle.ownerId, receipt.draftId, receipt.sourceRevision],
      limit: 1,
    );
    if (journalRows.isEmpty) throw ImportJournalNotFoundException('Journal entry not found.');

    final journal = journalRows.first;
    final state = journal['state'] as String;

    // 2. Common validation BEFORE both branches (C06)
    if (payload.plan == null) throw ArgumentError('Import requires complete usable plan.');

    final computedDigest = TripPayloadCodec.computeDigest(payload);
    if (computedDigest != journal['content_digest'] || computedDigest != receipt.contentDigest) {
      throw const ReceiptBindingMismatchException('Content digest mismatch across payload, journal, and receipt.');
    }
    if (receipt.targetOwner != handle.ownerId ||
        receipt.deviceScope != journal['device_scope'] ||
        receipt.draftId != journal['draft_id'] ||
        receipt.sourceRevision != journal['source_revision'] ||
        receipt.requestKey != journal['request_key']) {
      throw const ReceiptBindingMismatchException('Receipt bindings do not match journal identity.');
    }

    // 3. Branch A: Committed Idempotence (C05, C06, C07)
    if (state == 'committed') {
      final storedReceipt = LocalImportReceipt.fromMap(
        jsonDecode(journal['receipt_payload'] as String) as Map<String, dynamic>,
      );
      // Full 10-field equality helper comparison (C05)
      if (!LocalImportReceipt.areReceiptsEqual(storedReceipt, receipt)) {
        throw const ReceiptBindingMismatchException('Conflicting receipt bindings for already committed import.');
      }
      final currentSnapshotRows = await txn.query(
        'account_trip_snapshots',
        where: 'owner_id = ? AND trip_id = ?',
        whereArgs: [handle.ownerId, receipt.tripId],
        limit: 1,
      );
      if (currentSnapshotRows.isEmpty) {
        throw const CorruptDatabaseException('Committed import snapshot missing from account store.');
      }
      // Route through checked mapper
      final currentSnapshot = _mapAccountSnapshotRow(currentSnapshotRows.first);
      return ImportCommitResult(receipt: storedReceipt, snapshot: currentSnapshot);
    }

    if (state == 'quarantined') {
      throw const ImportAttemptQuarantinedException('Cannot commit quarantined attempt without explicit online reconciliation.');
    }

    // 4. Branch B: First Ack Transfer (C06, C08)
    // 4-way digest verification: source == journal == receipt == payload (C06)
    final sourceRows = await txn.query(
      'guest_draft_revisions',
      where: 'device_scope = ? AND draft_id = ? AND revision = ?',
      whereArgs: [receipt.deviceScope, receipt.draftId, receipt.sourceRevision],
      limit: 1,
    );
    if (sourceRows.isEmpty) {
      throw const CorruptDatabaseException('Source revision missing during ack commit.');
    }
    final sourceRecord = _mapGuestDraftRevisionRow(sourceRows.first);
    if (sourceRecord.digest != journal['content_digest'] || sourceRecord.digest != computedDigest) {
      throw const CorruptDatabaseException('4-way digest verification failed for source revision.');
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
      whereArgs: [receipt.deviceScope, handle.ownerId, receipt.draftId, receipt.sourceRevision],
    );

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
          {'current_revision': null, 'title': null, 'destination_name': null, 'updated_at': now.toIso8601String()},
          where: 'device_scope = ? AND draft_id = ?',
          whereArgs: [receipt.deviceScope, receipt.draftId],
        );
      }
    }

    final deletedCount = await txn.delete(
      'guest_draft_revisions',
      where: 'device_scope = ? AND draft_id = ? AND revision = ?',
      whereArgs: [receipt.deviceScope, receipt.draftId, receipt.sourceRevision],
    );
    if (deletedCount != 1) {
      throw const CorruptDatabaseException('Failed to consume exact source revision row.');
    }

    return ImportCommitResult(receipt: receipt, snapshot: snapshot);
  });
}
```

---

## 8. Durable Purge Protocol (3 Transactions within 1 Queued Action) (C04)

`purgeAccountData` validates targetOwnerId/reason before side effects, then synchronously unbinds and adds targetOwnerId to `_blockedOwners` BEFORE waiting on the queue. It uses a cleanup-specific internal path, not an expired account handle. Activation and all account entry points reject a process-blocked owner. Remove that RAM block only after all deletion and marker-completion commits succeed; no automatic removal on close/open or login. Guest operations may continue if DB is readable; a DB-wide failure cannot promise Guest disk access.

When `purgeAccountData({required String targetOwnerId, required String reason})` is called:

```
[Logout / Expiry Event]
         |
         v
Step 1: Synchronously unbind active session in RAM
        unbindSession(); // _storeGeneration++, _activeOwnerId = null
         |
         v
Execute in single queue action _enqueue:
         |
Step 2 (Txn 1): Persist durable marker in SEPARATE transaction
        INSERT OR REPLACE INTO local_cleanup_state
        (namespace, is_blocked, purge_pending, reason, created_at, updated_at)
        VALUES ('account:' || targetOwnerId, 1, 1, reason, now, now);
         |
         +--> [If Txn 1 throws] --> Throw CleanupMarkerPersistenceException;
         |                           Cache locked in process; Fail-Closed.
         v
Step 3 (Txn 2): Serialized purge transaction
        - DELETE FROM account_trip_snapshots WHERE owner_id = ?;
        - DELETE FROM local_import_journal WHERE target_owner = ? AND state = 'committed';
        - UPDATE local_import_journal SET state = 'quarantined', receipt_payload = NULL, updated_at = ?
          WHERE target_owner = ? AND state IN ('staged', 'pending_ack');
        - Untransferred guest_drafts and guest_draft_revisions remain untouched.
         |
         +--> [If Txn 2 crashes/fails] --> Marker (is_blocked=1, purge_pending=1)
         |                                  SURVIVES on disk!
         |                                  Subsequent bind/read for targetOwnerId
         |                                  throws AccountNamespaceBlockedException!
         v
Step 4 (Txn 3): Complete cleanup
        DELETE FROM local_cleanup_state WHERE namespace = 'account:' || targetOwnerId;
         |
Step 5: Namespace is unlocked for future verified sessions.
```

**Completion/startup rules:** Txn 3 failure leaves the committed marker and RAM block intact; retry repeats idempotent purge and completion. Never unlock on an attempted marker deletion. Startup recovery enumerates ALL blocked/pending `account:<owner>` markers, validates namespace, runs Txn 2 then Txn 3 directly on the connection before `_isOpened=true`, and clears only successfully recovered owner blocks. Unknown/malformed cleanup state keeps account readiness unavailable; preserve file/Guest rows, return typed error. No nested queue and no outer-db calls from a transaction. Marker write failure leaves only a process-local guarantee and explicit B6 startup obligation, not a false durable marker claim. No auth/global session registry is introduced.

---

## 9. Complete 15-Group Test Matrix & Test-Owned Temp Harness (`test/local_trip_store_test.dart`) (C10)

### 9.1. Test-Owned Harness Contract — NOT RUN (C10)
- Each test calls `Directory.systemTemp.createTemp('b2_test_')` and retains that exact returned directory. Resolve canonical temp root and unique owned directory; require a strict child path under the intended temp root and a non-root target. Before recursive deletion, resolve again and require exact equality with the stored owned target using normalized Windows path comparison. Use runtime rejection, not only assert/substring; never substitute an app DB path. Close/delete operate within the same native filesystem API.
- Test body wrapped in `try/catch` to capture primary error and stack trace.
- `tearDown` independently closes `store` and recursively deletes `tempDir`.
- If primary error exists, secondary cleanup errors are printed as diagnostic logs and primary error/stack is rethrown.
- If only cleanup fails, the test fails.
- Register cleanup after acquiring owned temp state, so setup/test failure still triggers cleanup. Attempt delete even when close fails; keep the primary stack and report each secondary failure independently. Fault/barrier hooks are deterministic, inside the 3-file allowlist, and execute production SQLite FFI transactions rather than mock persistence or sleep-based races.

### 9.2. Explicit Test Matrix
| Group | Exact Test Case | Invariant & Behavior Verified |
| :--- | :--- | :--- |
| **G1** | `open_reopen_preserves_five_tables_and_pragmas` | 5 tables exist, PRAGMA foreign_keys=1 verified on reopen, indices created. |
| **G1** | `fk_constraint_enforced_on_invalid_pointer` | Inserting `guest_drafts` with non-existent `current_revision` fails with SqliteException. |
| **G1** | `check_constraints_reject_blank_id_fractional_revision_bad_digest` | DDL CHECK rejects blank string, fractional revision (1.5), and hex digest with valid prefix but non-hex suffix (`aa`+62 `z` chars) on all 3 tables. |
| **G2** | `draft_survives_reopen_without_drift` | Full planner input/result, Pareto `false`, fallback survive reopen byte-identical without DE calls. |
| **G2** | `input_only_draft_supported` | Request-only draft (`plan = null`) stored and retrieved cleanly. |
| **G3** | `revisions_append_monotonically_and_preserve_history` | Revisions append-only; historical queries retrieve exact frozen states. |
| **G3** | `consumed_revision_number_never_reused` | Consuming rev 1 leaves highest_allocated_revision=1; next save is rev 2. |
| **G3** | `delete_draft_preserves_tombstone_counter_and_pointer_order` | `deleteDraft` clears pointer first, deletes revisions, keeps tombstone header; saving same draftId allocates next counter (never 1 again). |
| **G3** | `concurrent_saves_serialize_monotonically` | Concurrent saves serialize to distinct revisions via monotonic counter. |
| **G4** | `draft_save_failure_rolls_back_both_revision_and_pointer` | Injected fault before pointer update rolls back revision; zero orphaned records. |
| **G5** | `same_source_retry_keeps_key_digest_state` | Calling `prepareImportJournal` with identical key/digest returns existing row. |
| **G5** | `scope_mismatch_cannot_return_another_journal` | Journal query with different device_scope does not match or return another scope's row. |
| **G5** | `conflicting_retry_or_reused_key_rejected` | Different key/digest throws `ImportAttemptConflictException`; reused key throws `DuplicateRequestKeyException`. |
| **G5** | `cross_owner_reservation_blocks_all_active_states` | Partial unique index blocks Owner B from staging/pending/quarantined source of Owner A; maps to `DraftImportPendingException`. |
| **G5** | `pinned_source_deletion_blocked` | Attempting to delete draft while pinned in active journal throws `DraftRevisionPinnedException`. |
| **G6** | `strict_fractional_receipt_numbers_rejected` | `sourceRevision: 1.9` in receipt payload throws `CorruptDatabaseException`, no `.toInt()` truncation. |
| **G6** | `commit_ack_pointer_safe_order_consumes_source_and_nulls_pointer` | Pointer cleared BEFORE deleting revision; satisfies RESTRICT FK; source deleted from Guest. |
| **G6** | `commit_ack_with_newer_revision_leaves_newer_guest_revision` | If `current_revision > sourceRevision`, newer revision stays intact in Guest. |
| **G6** | `transferred_source_not_guest_readable_or_importable` | Consumed revision cannot be read by Guest or re-staged by any owner. |
| **G6** | `rollback_after_each_step_restores_clean_state` | Injected fault after receipt/snapshot/pointer-null/source-delete restores clean pre-ack state after reopen. |
| **G6** | `repeated_identical_ack_is_idempotent_and_returns_current_snapshot` | Repeated ack with identical receipt bindings returns stored receipt + current snapshot. |
| **G7** | `each_binding_independently_mismatched_rejects_ack` | Mismatch of owner/scope/draftId/revision/key/digest/trip/receipt/version/time throws `ReceiptBindingMismatchException`. |
| **G7** | `conflicting_repeat_of_committed_receipt_rejected` | Different receipt for already committed row throws `ReceiptBindingMismatchException`. |
| **G7** | `tampered_source_with_different_digest_rejected_on_first_ack` | Replaced source row with different digest rejected during ack commit. |
| **G8** | `tampered_payload_json_detected_on_same_digest_cas_no_op` | `payload_json` bị sửa nhưng digest giữ nguyên bị `_mapAccountSnapshotRow` phát hiện và ném `CorruptDatabaseException`. |
| **G8** | `snapshot_higher_version_replaces_and_lower_rejects` | Higher version replaces; lower version with later `fetchedAt` throws `SnapshotStaleVersionException`. |
| **G8** | `same_version_different_content_rejected` | Equal `remoteVersion` with different digest throws `SnapshotConflictException`. |
| **G8** | `legacy_null_version_policy_upgrades_cleanly_and_rejects_downgrade` | Versioned replaces legacy null; legacy null cannot overwrite versioned. |
| **G8** | `both_null_legacy_same_digest_touches_fetched_at_only_if_newer` | Both-null legacy same digest never decreases `fetchedAt`; older time with different digest throws. |
| **G8** | `corrupt_or_partial_payload_preserves_good_snapshot` | Incomplete (plan=null) or corrupt payload rejected before SQL; previous good snapshot preserved. |
| **G9** | `multi_owner_snapshots_strictly_isolated` | User A and B with identical trip IDs have zero cross-visibility. Demo/guest access rejected. |
| **G9** | `store_generation_aba_and_stale_handle_rejected` | Monotonic store generation prevents ABA handle reuse; stale epoch/handle throws `StaleSessionEpochException`. |
| **G9** | `late_returning_account_read_rejected_at_publication_layer` | Read completing after `unbindSession` fails Layer 3 check and drops result. |
| **G10**| `logout_purges_snapshots_and_committed_receipts_quarantines_pending` | User A logout purges snapshots and committed receipts; pending journal marked `quarantined` with `receipt_payload = NULL`. |
| **G10**| `owner_b_cannot_view_or_resume_owner_a_quarantine` | User B queries journal -> empty. User B cannot stage same source (`DraftImportPendingException`). |
| **G11**| `queued_and_in_flight_writes_cannot_resurrect_data_after_purge` | In-flight write finishing after logout cannot publish or resurrect data. |
| **G11**| `failed_queue_operation_does_not_poison_subsequent_cleanup` | Failed write in queue does not prevent subsequent purge from completing. |
| **G12**| `simulated_purge_crash_leaves_namespace_blocked` | Crash ở Bước 3 để lại cờ khóa; mọi truy cập bị chặn cứng (`AccountNamespaceBlockedException`). |
| **G12**| `startup_recovery_resumes_purge_and_unlocks` | `LocalTripStore.open()` tiếp tục dọn dẹp và mở khóa namespace. |
| **G13**| `marker_write_failure_disables_cache_fail_closed` | Bước 2 thất bại: ném `CleanupMarkerPersistenceException`, khóa cache trong RAM, fail-closed. |
| **G14**| `unsupported_future_schema_rejects_without_data_loss` | DB version 2 ném `UnsupportedDatabaseVersionException`, không xóa file. |
| **G14**| `corrupt_payload_byte_hash_or_canonical_drift_detected` | Payload sai lệch hash hoặc lệch định dạng canonical bị `_validateAndDecodePayload` phát hiện. |
| **G15**| `test_temp_directory_cleaned_up_safely` | Đóng kết nối và xóa thư mục tạm trong `tearDown` độc lập, bảo tồn lỗi chính. |

### 9.3. Required Negative Controls and Race Cases (C02–C10)

These are explicit cases within the 15 groups above, not additional packet scope:

- **G1/G3/G4:** CHECK negatives on every relevant table; consume -> delete -> save -> actual close/reopen preserves high-water; faults after revision INSERT and header update; counter/pointer corruption rejected; no frozen-content update API.
- **G5:** exact retries preserve state/key/digest; same owner key reused in another scope cannot erase prior journal; active reservation negatives for all 3 states; committed/quarantined records cannot implicitly send/regress; permitted same-owner reconcile keeps identity; B denied.
- **G6/G7:** strict negatives for BOTH integer fields, missing/extra/wrong-type receipt keys and non-Z/invalid timestamps. Mutate each of 10 incoming and each of 10 STORED receipt bindings independently; all mismatches reject with no writes. First ack checks four-way digest equality, including an internally-valid changed source; committed retry validates durable receipt identity without a deleted source. Repeat after a newer current snapshot must return current content, not overwrite it. Request-only/missing/corrupt source and faults after every ack statement roll back and reopen unchanged.
- **G8/G14:** same-version/no-op and repeated ack reject tampered existing payload bytes with unchanged digest. Valid-hash noncanonical JSON, row/envelope mismatch, wrong SQL type/date, bare legacy envelope and request-only account row reject. Out-of-order fetch arrival uses older capture timestamp; same/different digest with older/equal/newer time; same-content touch never decreases timestamp; higher/lower/null version policy and malformed replacement preserve valid snapshot.
- **G9/G11:** activation queued before unbind, unbind during marker query, close while activation waits, two competing activations, failed DB query and recovery-open failure. Only latest uncanceled request may bind; no old owner publishes. Check account read/write/ack at queue, transaction and publication boundaries with barriers; stale work rolls back when possible, committed stale work is purged before reactivation. Failed queue action does not poison purge; no nested-queue deadlock.
- **G10/G12/G13:** fault before/after marker commit, during deletion, after deletion/before completion, and DURING completion. Actual file reopen recovers committed markers; blocked/nonpending and malformed marker cases fail closed. Step 2 write failure blocks same-process reactivation even after close/reopen of same store; successful purge clears it. Rows show no transferred payload/receipt survives; quarantine retains only permitted metadata and frozen Guest source. Cross-process auth ambiguity/AC-016 proof is deferred B6/B9, not claimed by this unit suite.
- **G15:** setup/body/close/delete failures independently; cleanup-only failure fails test; primary error/stack preserved; changed/unowned/root/temp-escape target rejected before deletion; no app-path fallback.

---

## 10. Verification Commands & Expected Evidence SOP (C10)

Following Owner approval, implementation will be executed and verified with:

```powershell
# 1. Static analysis
flutter analyze --no-pub
# Expected: No issues found! (exit code 0)

# 2. Targeted B2 SQLite FFI test suite
flutter test --no-pub --reporter expanded test/local_trip_store_test.dart
# Expected: All test cases PASS (exit code 0)

# 3. Codec regression check
flutter test --no-pub --reporter expanded test/trip_payload_codec_test.dart
# Expected: 35/35 tests PASS (exit code 0)

# 4. Full test suite regression
flutter test --no-pub --reporter expanded
# Expected: All tests PASS (exit code 0)

# 5. Git status and diff verification
git status -s
git diff --check
# Expected: Only the 3 approved files modified/added; untracked Owner files untouched.
```
