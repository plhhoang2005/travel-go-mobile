part of 'local_trip_store.dart';

/// Shares the existing connection, serialized queue and three-layer account guard.
extension EditableLocalOperations on LocalTripStore {
  Future<T> _editableGuest<T>(
    Future<T> Function(DatabaseExecutor txn) action, {
    bool write = false,
  }) {
    final generation = _storeGeneration;
    void check() {
      _getDb();
      if (generation != _storeGeneration) {
        throw const StaleSessionEpochException(
          'Guest operation changed context.',
        );
      }
      if (write && (_activeOwnerId != null || _isDemo)) {
        throw const UnauthorizedAccountAccessException(
          'Account workspace cannot write Guest drafts.',
        );
      }
    }

    return _enqueue(() async {
      check();
      final result = await _getDb().transaction<T>((txn) async {
        check();
        final result = await action(txn);
        check();
        return result;
      });
      check();
      return result;
    });
  }

  EditableDraftRecord _editableDraft(Map<String, Object?> row) {
    try {
      final raw = row['payload_text'];
      if (raw is! String) {
        EditableRecordCodec.bad();
      }
      final hash = EditableRecordCodec.digest(row['content_digest']);
      if (EditableTripCodec.digestText(raw) != hash) {
        EditableRecordCodec.bad();
      }
      return EditableDraftRecord(
        deviceScope: EditableRecordCodec.text(row['device_scope']),
        draftId: EditableRecordCodec.text(row['draft_id']),
        revision: EditableRecordCodec.positive(row['revision']),
        document: EditableTripCodec.decode(raw),
        payloadText: raw,
        contentDigest: hash,
        savedAt: EditableRecordCodec.utc(row['saved_at']),
      );
    } on LocalTripStoreException {
      rethrow;
    } on Object {
      throw const CorruptDatabaseException('Invalid editable draft.');
    }
  }

  Future<EditableDraftRecord> saveEditableDraft({
    required String deviceScope,
    required String draftId,
    required int? expectedRevision,
    required EditableTripDocumentV2 document,
  }) {
    EditableRecordCodec.text(deviceScope);
    EditableRecordCodec.text(draftId);
    if (expectedRevision != null) {
      EditableRecordCodec.positive(expectedRevision);
    }
    final text = EditableTripCodec.encode(document);
    final digest = EditableTripCodec.digestText(text);
    final issues = EditableTripValidator.validate(document);
    if (issues.any(
      (i) => i.isBlocking && !{'overlap', 'time_order'}.contains(i.code),
    )) {
      throw const CorruptDatabaseException('Invalid editable draft content.');
    }
    return _editableGuest((txn) async {
      final rows = await txn.query(
        'guest_editable_drafts',
        where: 'device_scope = ? AND draft_id = ?',
        whereArgs: [deviceScope, draftId],
        orderBy: 'revision DESC',
        limit: 1,
      );
      final previous = rows.isEmpty ? null : _editableDraft(rows.single);
      if (previous?.revision != expectedRevision) {
        throw const EditableDraftConflictException('Guest revision changed.');
      }
      final revision = (previous?.revision ?? 0) + 1;
      EditableRecordCodec.positive(revision);
      final saved = _clock().toUtc();
      await txn.insert('guest_editable_drafts', {
        'device_scope': deviceScope,
        'draft_id': draftId,
        'revision': revision,
        'payload_text': text,
        'content_digest': digest,
        'saved_at': saved.toIso8601String(),
      });
      await onEditableStepForTesting?.call('draft_written');
      return EditableDraftRecord(
        deviceScope: deviceScope,
        draftId: draftId,
        revision: revision,
        document: document,
        payloadText: text,
        contentDigest: digest,
        savedAt: saved,
      );
    }, write: true);
  }

  Future<EditableDraftRecord?> readEditableDraft({
    required String deviceScope,
    required String draftId,
  }) {
    EditableRecordCodec.text(deviceScope);
    EditableRecordCodec.text(draftId);
    return _editableGuest((txn) async {
      final rows = await txn.query(
        'guest_editable_drafts',
        where: 'device_scope = ? AND draft_id = ?',
        whereArgs: [deviceScope, draftId],
        orderBy: 'revision DESC',
        limit: 1,
      );
      return rows.isEmpty ? null : _editableDraft(rows.single);
    });
  }

  Future<List<EditableDraftRecord>> listEditableDrafts({
    required String deviceScope,
  }) {
    EditableRecordCodec.text(deviceScope);
    return _editableGuest((txn) async {
      final rows = await txn.rawQuery(
        '''SELECT d.* FROM guest_editable_drafts d JOIN
        (SELECT draft_id,MAX(revision) latest FROM guest_editable_drafts WHERE device_scope=? GROUP BY draft_id) r
        ON d.draft_id=r.draft_id AND d.revision=r.latest WHERE d.device_scope=? ORDER BY d.saved_at DESC,d.draft_id''',
        [deviceScope, deviceScope],
      );
      return List.unmodifiable(rows.map(_editableDraft));
    });
  }

  Future<void> deleteEditableDraft({
    required String deviceScope,
    required String draftId,
    required int expectedRevision,
  }) {
    EditableRecordCodec.text(deviceScope);
    EditableRecordCodec.text(draftId);
    EditableRecordCodec.positive(expectedRevision);
    return _editableGuest((txn) async {
      final rows = await txn.query(
        'guest_editable_drafts',
        where: 'device_scope=? AND draft_id=?',
        whereArgs: [deviceScope, draftId],
        orderBy: 'revision DESC',
        limit: 1,
      );
      if (rows.isEmpty ||
          _editableDraft(rows.single).revision != expectedRevision) {
        throw const EditableDraftConflictException(
          'Guest revision changed before deletion.',
        );
      }
      await txn.delete(
        'guest_editable_drafts',
        where: 'device_scope=? AND draft_id=?',
        whereArgs: [deviceScope, draftId],
      );
    }, write: true);
  }

  EditableSnapshotRecord _editableSnapshot(Map<String, Object?> row) {
    try {
      return EditableSnapshotRecord(
        EditableRecordCodec.head({
          'ownerId': row['owner_id'],
          'tripId': row['trip_id'],
          'version': row['version'],
          'payloadText': row['payload_text'],
          'contentDigest': row['content_digest'],
          'fetchedAt': row['fetched_at'],
        }),
      );
    } on LocalTripStoreException {
      rethrow;
    } on Object {
      throw const CorruptDatabaseException('Invalid editable snapshot.');
    }
  }

  Future<EditableSnapshotRecord> _putEditableSnapshot(
    DatabaseExecutor txn,
    String owner,
    EditableHead incoming,
  ) async {
    final checked = EditableRecordCodec.head(
      EditableRecordCodec.headJson(incoming),
    );
    if (checked.ownerId != owner ||
        EditableTripCodec.encode(checked.document) !=
            EditableTripCodec.encode(incoming.document)) {
      throw const ReceiptBindingMismatchException(
        'Snapshot content or owner mismatch.',
      );
    }
    final rows = await txn.query(
      'editable_trip_snapshots',
      where: 'owner_id=? AND trip_id=?',
      whereArgs: [owner, checked.tripId],
    );
    if (rows.isNotEmpty) {
      final old = _editableSnapshot(rows.single).head;
      if (checked.version < old.version) {
        throw const SnapshotStaleVersionException(
          'Cannot downgrade editable snapshot.',
        );
      }
      if (checked.version == old.version) {
        if (checked.contentDigest != old.contentDigest ||
            checked.payloadText != old.payloadText) {
          throw const SnapshotConflictException(
            'Same editable version has different content.',
          );
        }
        if (!checked.fetchedAt.isAfter(old.fetchedAt)) {
          return EditableSnapshotRecord(old);
        }
      }
    }
    final row = {
      'owner_id': owner,
      'trip_id': checked.tripId,
      'version': checked.version,
      'payload_text': checked.payloadText,
      'content_digest': checked.contentDigest,
      'fetched_at': checked.fetchedAt.toIso8601String(),
    };
    if (rows.isEmpty) {
      await txn.insert('editable_trip_snapshots', row);
    } else {
      await txn.update(
        'editable_trip_snapshots',
        row,
        where: 'owner_id=? AND trip_id=?',
        whereArgs: [owner, checked.tripId],
      );
    }
    await onEditableStepForTesting?.call('snapshot_written');
    return EditableSnapshotRecord(checked);
  }

  Future<EditableSnapshotRecord> putEditableSnapshot({
    required SessionHandle handle,
    required EditableHead head,
  }) => _executeGuardedAccountOperation(
    handle,
    (txn) => _putEditableSnapshot(txn, handle.ownerId, head),
  );
  Future<EditableSnapshotRecord?> readEditableSnapshot({
    required SessionHandle handle,
    required String tripId,
  }) {
    EditableRecordCodec.id(tripId);
    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'editable_trip_snapshots',
        where: 'owner_id=? AND trip_id=?',
        whereArgs: [handle.ownerId, tripId],
      );
      return rows.isEmpty ? null : _editableSnapshot(rows.single);
    });
  }

  Future<List<EditableSnapshotRecord>> listEditableSnapshots({
    required SessionHandle handle,
  }) => _executeGuardedAccountOperation(handle, (txn) async {
    final rows = await txn.query(
      'editable_trip_snapshots',
      where: 'owner_id=?',
      whereArgs: [handle.ownerId],
      orderBy: 'fetched_at DESC,trip_id',
    );
    return List.unmodifiable(rows.map(_editableSnapshot));
  });
  Future<void> deleteEditableSnapshot({
    required SessionHandle handle,
    required String tripId,
  }) {
    EditableRecordCodec.id(tripId);
    return _executeGuardedAccountOperation(handle, (txn) async {
      await txn.delete(
        'editable_trip_snapshots',
        where: 'owner_id=? AND trip_id=?',
        whereArgs: [handle.ownerId, tripId],
      );
    });
  }

  EditableAttemptRecord _editableAttempt(Map<String, Object?> row) {
    try {
      final raw = row['attempt_json'];
      if (raw is! String) {
        EditableRecordCodec.bad();
      }
      final attempt = EditableRecordCodec.attempt(
        EditableRecordCodec.object(
          EditableTripCodec.parseStrict(raw, limit: 8 * 1024 * 1024),
        ),
      );
      if (attempt.ownerId != row['owner_id'] ||
          attempt.requestId != row['request_id']) {
        EditableRecordCodec.bad();
      }
      final state = row['state'];
      if (state is! String ||
          !{'staged', 'uncertain', 'committed'}.contains(state)) {
        EditableRecordCodec.bad();
      }
      final rawReceipt = row['receipt_json'];
      if ((state == 'committed') != (rawReceipt != null)) {
        EditableRecordCodec.bad();
      }
      final receipt = rawReceipt == null
          ? null
          : EditableRecordCodec.receipt(
              EditableRecordCodec.object(
                EditableTripCodec.parseStrict(rawReceipt as String),
              ),
            );
      if (receipt != null) {
        _bindEditableReceipt(attempt, receipt);
      }
      return EditableAttemptRecord(
        attempt: attempt,
        state: state,
        receipt: receipt,
      );
    } on LocalTripStoreException {
      rethrow;
    } on Object {
      throw const CorruptDatabaseException('Invalid editable attempt.');
    }
  }

  void _bindEditableReceipt(
    EditablePendingAttempt attempt,
    EditableReceipt receipt,
  ) {
    if (receipt.requestId != attempt.requestId ||
        receipt.ownerId != attempt.ownerId ||
        receipt.operation != attempt.operation ||
        receipt.requestDigest != attempt.requestDigest ||
        receipt.contentDigest != attempt.contentDigest ||
        attempt.tripId != null && receipt.tripId != attempt.tripId ||
        receipt.resultVersion !=
            (attempt.operation == 'create'
                ? 1
                : attempt.expectedVersion! + 1) ||
        EditableTripCodec.canonicalJson(receipt.sourceBinding?.toJson()) !=
            EditableTripCodec.canonicalJson(attempt.sourceBinding?.toJson())) {
      throw const ReceiptBindingMismatchException(
        'Editable receipt does not match frozen attempt.',
      );
    }
  }

  Future<EditableAttemptRecord> stageEditableAttempt({
    required SessionHandle handle,
    required EditablePendingAttempt attempt,
  }) {
    EditableRecordCodec.validateAttempt(attempt);
    if (attempt.ownerId != handle.ownerId) {
      throw const UnauthorizedAccountAccessException('Attempt owner mismatch.');
    }
    final serialized = EditableTripCodec.canonicalJson(
      EditableRecordCodec.attemptJson(attempt),
    );
    return _executeGuardedAccountOperation(handle, (txn) async {
      final rows = await txn.query(
        'editable_mutation_outbox',
        where: 'owner_id=? AND request_id=?',
        whereArgs: [handle.ownerId, attempt.requestId],
      );
      if (rows.isNotEmpty) {
        final existing = _editableAttempt(rows.single);
        if (EditableTripCodec.canonicalJson(
              EditableRecordCodec.attemptJson(existing.attempt),
            ) !=
            serialized) {
          throw const ImportAttemptConflictException(
            'Request already binds different editable content.',
          );
        }
        return existing;
      }
      final source = attempt.sourceBinding;
      if (source?.kind == 'guest_import') {
        final draftRows = await txn.query(
          'guest_editable_drafts',
          where: 'device_scope=? AND draft_id=? AND revision=?',
          whereArgs: [
            source!.deviceScope,
            source.draftId,
            source.sourceRevision,
          ],
        );
        if (draftRows.length != 1 ||
            _editableDraft(draftRows.single).contentDigest !=
                attempt.contentDigest) {
          throw const ImportAttemptConflictException(
            'Selected Guest revision differs from frozen import.',
          );
        }
        final journals = await txn.query(
          'editable_import_journal',
          where: 'owner_id=? AND device_scope=? AND draft_id=? AND source_revision=?',
          whereArgs: [
            handle.ownerId,
            source.deviceScope,
            source.draftId,
            source.sourceRevision,
          ],
        );
        if (journals.isNotEmpty) {
          throw const ImportAttemptConflictException(
            'Guest source already has an editable attempt.',
          );
        }
        await txn.insert('editable_import_journal', {
          'owner_id': handle.ownerId,
          'device_scope': source.deviceScope,
          'draft_id': source.draftId,
          'source_revision': source.sourceRevision,
          'request_id': attempt.requestId,
          'source_digest': attempt.contentDigest,
          'state': 'staged',
          'receipt_json': null,
        });
      }
      await txn.insert('editable_mutation_outbox', {
        'owner_id': handle.ownerId,
        'request_id': attempt.requestId,
        'attempt_json': serialized,
        'state': 'staged',
        'receipt_json': null,
      });
      await onEditableStepForTesting?.call('attempt_staged');
      return EditableAttemptRecord(attempt: attempt, state: 'staged');
    });
  }

  Future<List<EditableAttemptRecord>> listEditableAttempts({
    required SessionHandle handle,
  }) => _executeGuardedAccountOperation(handle, (txn) async {
    final rows = await txn.query(
      'editable_mutation_outbox',
      where: 'owner_id=? AND state<>?',
      whereArgs: [handle.ownerId, 'committed'],
      orderBy: 'request_id',
    );
    return List.unmodifiable(rows.map(_editableAttempt));
  });
  Future<void> commitEditableAck({
    required SessionHandle handle,
    required EditableMutationReply reply,
  }) => _executeGuardedAccountOperation(handle, (txn) async {
    final receipt = reply.receipt;
    if (receipt == null || reply.status == EditableMutationStatus.notFound) {
      throw const ReceiptBindingMismatchException(
        'No committed editable receipt.',
      );
    }
    final checked = EditableRecordCodec.receipt(
      EditableRecordCodec.receiptJson(receipt),
    );
    if (checked.ownerId != handle.ownerId) {
      throw const ReceiptBindingMismatchException(
        'Editable acknowledgement changed owner.',
      );
    }
    final rows = await txn.query(
      'editable_mutation_outbox',
      where: 'owner_id=? AND request_id=?',
      whereArgs: [handle.ownerId, checked.requestId],
    );
    if (rows.length != 1) {
      throw const ImportJournalNotFoundException(
        'Editable frozen attempt unavailable.',
      );
    }
    final pending = _editableAttempt(rows.single);
    _bindEditableReceipt(pending.attempt, checked);
    final receiptText = EditableTripCodec.canonicalJson(
      EditableRecordCodec.receiptJson(checked),
    );
    if (pending.receipt != null &&
        EditableTripCodec.canonicalJson(
              EditableRecordCodec.receiptJson(pending.receipt!),
            ) !=
            receiptText) {
      throw const ReceiptBindingMismatchException(
        'Committed editable receipt changed.',
      );
    }
    final head = reply.head;
    if (reply.status == EditableMutationStatus.deleted) {
      if (head != null) {
        throw const ReceiptBindingMismatchException(
          'Deleted reply includes editable content.',
        );
      }
      await txn.delete(
        'editable_trip_snapshots',
        where: 'owner_id=? AND trip_id=?',
        whereArgs: [handle.ownerId, checked.tripId],
      );
    } else {
      if (head == null ||
          head.ownerId != checked.ownerId ||
          head.tripId != checked.tripId ||
          head.version < checked.resultVersion ||
          head.version == checked.resultVersion &&
              head.contentDigest != checked.contentDigest ||
          checked.operation == 'delete') {
        throw const ReceiptBindingMismatchException(
          'Editable head and receipt disagree.',
        );
      }
      EditableRecordCodec.head(EditableRecordCodec.headJson(head));
      final cached = await txn.query(
        'editable_trip_snapshots',
        where: 'owner_id=? AND trip_id=?',
        whereArgs: [handle.ownerId, head.tripId],
      );
      if (cached.isEmpty ||
          _editableSnapshot(cached.single).head.version <= head.version) {
        await _putEditableSnapshot(txn, handle.ownerId, head);
      }
    }
    await onEditableStepForTesting?.call('ack_snapshot_written');
    final source = pending.attempt.sourceBinding;
    if (source?.kind == 'guest_import') {
      final journals = await txn.query(
        'editable_import_journal',
        where: 'owner_id=? AND request_id=?',
        whereArgs: [handle.ownerId, checked.requestId],
      );
      if (journals.length != 1 ||
          journals.single['source_digest'] != checked.contentDigest ||
          journals.single['device_scope'] != source!.deviceScope ||
          journals.single['draft_id'] != source.draftId ||
          journals.single['source_revision'] != source.sourceRevision) {
        throw const ReceiptBindingMismatchException(
          'Editable source journal mismatch.',
        );
      }
      await txn.update(
        'editable_import_journal',
        {'state': 'committed', 'receipt_json': receiptText},
        where: 'owner_id=? AND request_id=?',
        whereArgs: [handle.ownerId, checked.requestId],
      );
      await txn.delete(
        'guest_editable_drafts',
        where: 'device_scope=? AND draft_id=? AND revision<=?',
        whereArgs: [source.deviceScope, source.draftId, source.sourceRevision],
      );
    }
    await onEditableStepForTesting?.call('ack_source_removed');
    await txn.update(
      'editable_mutation_outbox',
      {'state': 'committed', 'receipt_json': receiptText},
      where: 'owner_id=? AND request_id=?',
      whereArgs: [handle.ownerId, checked.requestId],
    );
  });
}
