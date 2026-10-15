import 'package:uuid/uuid.dart';

import '../../trip_planner/models/editable_trip_command.dart';
import '../../trip_planner/models/editable_trip_document.dart';
import '../../trip_planner/services/editable_trip_mutator.dart';
import '../models/editable_local_records.dart';
import '../models/editable_remote_records.dart';
import '../models/editable_trip_codec.dart';
import '../models/local_trip_records.dart';
import 'editable_trip_service.dart';
import 'local_account_lifecycle_service.dart';
import 'local_trip_store.dart';

class _EditableAccountContext {
  final AccountSessionProof proof;
  final SessionHandle handle;
  final LocalAccountLifecycleService lifecycle;
  final DateTime Function() clock;
  const _EditableAccountContext(
    this.proof,
    this.handle,
    this.lifecycle,
    this.clock,
  );

  void check() {
    if (!lifecycle.isCurrentProof(proof) ||
        proof.expiresAt <= clock().millisecondsSinceEpoch ~/ 1000 + 10 ||
        lifecycle.handle?.storeGeneration != handle.storeGeneration) {
      throw StateError('Editable account operation changed context.');
    }
  }

  Future<T> wait<T>(Future<T> operation) async {
    try {
      final result = await operation;
      check();
      return result;
    } catch (_) {
      check();
      rethrow;
    }
  }
}

/// Coordinates frozen requests and atomic local acknowledgements. No UI or auth
/// token is persisted; account I/O shares the app's existing store and lifecycle.
class EditableTripRepository {
  final LocalTripStore store;
  final LocalAccountLifecycleService lifecycle;
  final EditableTripService service;
  final String Function() _newId;
  final DateTime Function() _clock;
  Future<void> _tail = Future.value();

  EditableTripRepository({
    required this.store,
    required this.lifecycle,
    required this.service,
    String Function()? newId,
    DateTime Function()? clock,
  }) : _newId = newId ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  Future<T> _account<T>(Future<T> Function(_EditableAccountContext) body) {
    final proof = lifecycle.captureProof();
    final handle = lifecycle.handle;
    if (handle == null) throw StateError('Account store is unavailable.');
    final context = _EditableAccountContext(proof, handle, lifecycle, _clock);
    final finish = lifecycle.beginAccountOperation(proof);
    // Serialize remote/cache decisions too: an older read cannot purge a cache
    // written by a concurrent acknowledgement through this shared repository.
    final result = _tail.then((_) async {
      context.check();
      final value = await body(context);
      context.check();
      return value;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result.whenComplete(finish);
  }

  Future<EditableDraftRecord> saveGuest({
    required String scope,
    required String draftId,
    required int? expectedRevision,
    required EditableTripDocumentV2 document,
  }) => store.saveEditableDraft(
    deviceScope: scope,
    draftId: draftId,
    expectedRevision: expectedRevision,
    document: document,
  );

  EditablePendingAttempt _freeze({
    required String owner,
    required String requestId,
    required EditableTripDocumentV2 document,
    required List<EditableCommand> commands,
    EditableHead? base,
    SourceBinding? source,
  }) {
    final text = EditableTripCodec.encode(document);
    final digest = EditableTripCodec.digestText(text);
    EditableRecordCodec.accountDocument(text, digest);
    if (base != null) {
      EditableRecordCodec.head(EditableRecordCodec.headJson(base));
      if (base.ownerId != owner || source != null) {
        throw const EditableMutationException('account_base_mismatch');
      }
      final replay = EditableTripMutator.apply(base.document, commands);
      if (EditableTripCodec.encode(replay) != text) {
        throw const EditableMutationException('command_candidate_mismatch');
      }
    }
    final requestText = EditableTripCodec.canonicalJson({
      'payloadText': text,
      'contentDigest': digest,
      if (base == null) 'sourceBinding': source?.toJson(),
      if (base != null) 'commands': commands.map((c) => c.toJson()).toList(),
    });
    final attempt = EditablePendingAttempt(
      requestId: requestId,
      ownerId: owner,
      operation: base == null ? 'create' : 'update',
      requestText: requestText,
      requestDigest: EditableTripCodec.digestText(requestText),
      contentDigest: digest,
      tripId: base?.tripId,
      expectedVersion: base?.version,
      sourceBinding: source,
    );
    EditableRecordCodec.validateAttempt(attempt);
    return attempt;
  }

  Future<EditableMutationReply> saveAccount({
    required EditableTripDocumentV2 document,
    required List<EditableCommand> commands,
    EditableHead? base,
    SourceBinding? source,
    String? requestId,
  }) {
    final frozenCommands = List<EditableCommand>.unmodifiable(commands);
    return _account((context) async {
      final attempt = _freeze(
        owner: context.proof.ownerId,
        requestId: requestId ?? _newId(),
        document: document,
        commands: frozenCommands,
        base: base,
        source: source,
      );
      return await _submit(context, attempt);
    });
  }

  Future<EditableMutationReply> importGuest(
    EditableDraftRecord revision,
  ) => _account((context) async {
    if (EditableTripCodec.encode(revision.document) != revision.payloadText ||
        EditableTripCodec.digestText(revision.payloadText) !=
            revision.contentDigest) {
      throw const EditableDraftConflictException(
        'Selected Guest revision changed.',
      );
    }
    // Stable only for explicit re-selection of this same source and owner.
    // Logout may purge the local outbox while the server retained its receipt.
    final requestId = const Uuid().v5(
      '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
      EditableTripCodec.canonicalJson([
        'travelgo/editable-guest/v2',
        context.proof.ownerId,
        revision.deviceScope,
        revision.draftId,
        revision.revision,
      ]),
    );
    final attempt = _freeze(
      owner: context.proof.ownerId,
      requestId: requestId,
      document: revision.document,
      commands: [],
      source: SourceBinding.guest(
        deviceScope: revision.deviceScope,
        draftId: revision.draftId,
        sourceRevision: revision.revision,
      ),
    );
    return await _submit(context, attempt);
  });

  Future<EditableMutationReply> _submit(
    _EditableAccountContext context,
    EditablePendingAttempt attempt,
  ) async {
    context.check();
    final staged = await context.wait(
      store.stageEditableAttempt(handle: context.handle, attempt: attempt),
    );
    // An absent receipt is not evidence of rollback. Resend only the exact same
    // request key and bytes; the server decides its idempotent result atomically.
    var reply = await context.wait(
      service.lookup(proof: context.proof, requestId: attempt.requestId),
    );
    if (reply.status == EditableMutationStatus.notFound) {
      if (staged.state == 'committed') {
        throw const EditableRemoteException(
          EditableRemoteFailure.protocol,
          'committed_receipt_unavailable',
        );
      }
      reply = await context.wait(switch (attempt.operation) {
        'create' => service.create(proof: context.proof, attempt: attempt),
        'update' => service.update(proof: context.proof, attempt: attempt),
        'delete' => service.delete(proof: context.proof, attempt: attempt),
        _ => throw const EditableMutationException('invalid_operation'),
      });
    }
    await context.wait(
      store.commitEditableAck(handle: context.handle, reply: reply),
    );
    return reply;
  }

  Future<void> recoverPending() => _account((context) async {
    final pending = await context.wait(
      store.listEditableAttempts(handle: context.handle),
    );
    for (final record in pending) {
      await context.wait(_submit(context, record.attempt));
    }
  });

  /// Retry is bound to a confirmed outbox row, never to the current editor text.
  Future<EditableMutationReply> retryPending(String requestId) =>
      _account((context) async {
        EditableRecordCodec.id(requestId);
        final pending = await context.wait(
          store.listEditableAttempts(handle: context.handle),
        );
        final selected = pending.where((r) => r.attempt.requestId == requestId);
        if (selected.length != 1) {
          throw const ImportJournalNotFoundException(
            'Confirmed save is unavailable.',
          );
        }
        return await _submit(context, selected.single.attempt);
      });

  Future<EditableTripView> readTrip(
    String tripId, {
    bool allowCached = true,
  }) => _account((context) async {
    EditableHead? head;
    try {
      head = await context.wait(
        service.read(proof: context.proof, tripId: tripId),
      );
    } on EditableRemoteException catch (error) {
      if (!allowCached || error.kind != EditableRemoteFailure.uncertain) {
        rethrow;
      }
      final cached = await context.wait(
        store.readEditableSnapshot(handle: context.handle, tripId: tripId),
      );
      return cached == null
          ? const EditableTripView(EditableTripViewState.unavailable)
          : EditableTripView(EditableTripViewState.cachedReadOnly, cached.head);
    }
    if (head == null) {
      await context.wait(
        store.deleteEditableSnapshot(handle: context.handle, tripId: tripId),
      );
      return const EditableTripView(EditableTripViewState.unavailable);
    }
    final stored = await context.wait(
      store.putEditableSnapshot(handle: context.handle, head: head),
    );
    return EditableTripView(EditableTripViewState.online, stored.head);
  });

  Future<OwnedTripPage> listOwned({OwnedTripCursor? cursor}) =>
      _account((context) async {
        return await context.wait(
          service.list(proof: context.proof, cursor: cursor),
        );
      });

  Future<EditableMutationReply> deleteTrip(EditableHead base) =>
      _account((context) async {
        EditableRecordCodec.head(EditableRecordCodec.headJson(base));
        if (base.ownerId != context.proof.ownerId) {
          throw const EditableMutationException('account_base_mismatch');
        }
        final text = EditableTripCodec.canonicalJson({
          'op': 'delete',
          'tripId': base.tripId,
          'expectedVersion': base.version,
        });
        final attempt = EditablePendingAttempt(
          requestId: _newId(),
          ownerId: base.ownerId,
          operation: 'delete',
          tripId: base.tripId,
          expectedVersion: base.version,
          requestText: text,
          requestDigest: EditableTripCodec.digestText(text),
        );
        return await _submit(context, attempt);
      });
}
