import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/models/local_trip_records.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_repository.dart';
import 'package:travelgo_mobile/features/trips/services/editable_trip_service.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;

class _RejectedSaveRepository extends EditableTripRepository {
  final String failureCode;
  final EditableRemoteFailure? failureKind;
  _RejectedSaveRepository(
    EditableTripRepository original,
    this.failureCode, {
    this.failureKind,
  }) : super(
         store: original.store,
         lifecycle: original.lifecycle,
         service: original.service,
       );

  @override
  Future<EditableMutationReply> saveAccount({
    required EditableTripDocumentV2 document,
    required List<EditableCommand> commands,
    EditableHead? base,
    SourceBinding? source,
    String? requestId,
  }) async => throw EditableRemoteException(
    failureKind ??
        (failureCode == 'version_conflict'
            ? EditableRemoteFailure.rejected
            : EditableRemoteFailure.uncertain),
    failureCode,
  );
}

class _UpdateFailureAdapter implements HttpClientAdapter {
  final repository.Server server;
  final bool uncertain;
  _UpdateFailureAdapter(this.server, {required this.uncertain});
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.uri.path.endsWith('/update_editable_trip_v2')) {
      if (uncertain) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return ResponseBody.fromString(
        '{"code":"P0001","message":"version_conflict"}',
        409,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return server.respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'pause and an expired proof hide unsubmitted account editor data',
    () async {
      await repository.run((ctx) async {
        await ctx.login();
        final provider = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
        );
        try {
          // Finish consumer binding before requesting a seal. B6.1 correctly
          // denies a seal while another lifecycle control is still running.
          await ctx.login();
          provider.openNew(records.doc());
          expect(await ctx.lifecycle.sealForPause(), isTrue);
          expect(provider.document, isNull);
          expect(await ctx.lifecycle.resumeAccount(), isNotNull);
          expect(provider.document, isNull);
          provider.openNew(records.doc());
          ctx.session.expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          expect(provider.document, isNull);
          expect(provider.state, ManualPlannerState.unavailable);
          expect(ctx.server.creates, 0);
        } finally {
          provider.dispose();
        }
      });
    },
  );

  test('cancelled or stale preview cannot save; Guest save retains later dirty edits', () async {
    await repository.run((ctx) async {
      final provider = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: () => records.draftId,
      );
      try {
        provider.openNew(records.doc());
        final cancelled = provider.previewSave();
        provider.cancelPreview();
        expect(await provider.confirmSave(cancelled), isFalse);
        expect(ctx.server.creates, 0);
        final stale = provider.previewSave();
        provider.dispatch(
          DayNotesCommand(provider.document!.days.single.id, 'New note'),
        );
        expect(await provider.confirmSave(stale), isFalse);
        final confirmed = provider.previewSave();
        final entered = Completer<void>();
        final release = Completer<void>();
        ctx.disk.store.onEditableStepForTesting = (step) async {
          if (step == 'draft_written') {
            entered.complete();
            await release.future;
          }
        };
        final saving = provider.confirmSave(confirmed);
        await entered.future;
        provider.dispatch(
          DayNotesCommand(
            provider.document!.days.single.id,
            'Typed during save',
          ),
        );
        release.complete();
        expect(await saving, isTrue);
        expect(provider.dirty, isTrue);
        expect(provider.document!.days.single.notes, 'Typed during save');
        expect(provider.draftRevision, 1);
        ctx.disk.store.onEditableStepForTesting = null;
        expect(await provider.confirmSave(provider.previewSave()), isTrue);
        expect(provider.dirty, isFalse);
        expect(provider.draftRevision, 2);
        expect(ctx.server.creates, 0);
      } finally {
        provider.dispose();
      }
    });
  });

  test('account edits stay in RAM and a save advances base without dropping later commands', () async {
    await repository.run((ctx) async {
      await ctx.login();
      final provider = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: () => records.requestId,
      );
      try {
        provider.openSaved(
          EditableTripView(EditableTripViewState.online, records.head()),
        );
        provider.dispatch(
          DayNotesCommand(records.doc().days.single.id, 'Submitted'),
        );
        ctx.server.entered = Completer<void>();
        ctx.server.release = Completer<void>();
        final saving = provider.confirmSave(provider.previewSave());
        await ctx.server.entered!.future;
        provider.dispatch(
          DayNotesCommand(records.doc().days.single.id, 'Later'),
        );
        ctx.server.release!.complete();
        expect(await saving, isTrue);
        expect(provider.baseHead!.version, 2);
        expect(provider.document!.days.single.notes, 'Later');
        expect(provider.dirty, isTrue);
        expect(
          await ctx.disk.store.rawDb.query('guest_editable_drafts'),
          isEmpty,
        );
      } finally {
        provider.dispose();
      }
    });
  });

  test(
    'account dates block confirm while unknown estimates and overbudget do not',
    () async {
      await repository.run((ctx) async {
        await ctx.login();
        final provider = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
          newId: () => records.requestId,
        );
        try {
          final base = records.doc();
          final incomplete = base.copyWith(
            input: TripInput.fromJson({
              ...base.input.toJson(),
              'startDate': null,
              'endDate': null,
            }),
            days: [
              TripDay.fromJson({...base.days.single.toJson(), 'date': null}),
            ],
          );
          provider.openNew(incomplete);
          final invalid = provider.previewSave();
          expect(invalid.canConfirm, isFalse);
          expect(await provider.confirmSave(invalid), isFalse);
          provider.openNew(
            base.copyWith(
              input: TripInput.fromJson({
                ...base.input.toJson(),
                'totalBudgetVnd': 1,
              }),
            ),
          );
          final warning = provider.previewSave();
          expect(warning.canConfirm, isTrue);
          expect(warning.totals.unknownEstimateCount, 1);
          expect(warning.totals.actualRemaining, lessThan(0));
          expect(await provider.confirmSave(warning), isTrue);
        } finally {
          provider.dispose();
        }
      });
    },
  );

  for (final failure in [
    'version_conflict',
    'outcome_unknown',
    'uncertain_version_conflict',
  ]) {
    test(
      'P32 rejected conflict releases pending but uncertain retains it: $failure',
      () async {
        await repository.run((ctx) async {
          await ctx.login();
          final rejected = _RejectedSaveRepository(
            ctx.repository,
            failure == 'uncertain_version_conflict'
                ? 'version_conflict'
                : failure,
            failureKind: failure == 'uncertain_version_conflict'
                ? EditableRemoteFailure.uncertain
                : null,
          );
          final provider = ManualPlannerProvider(
            repositoryLoader: () async => rejected,
            lifecycle: ctx.lifecycle,
            newId: () => records.requestId,
          );
          try {
            provider.openSaved(
              EditableTripView(EditableTripViewState.online, records.head()),
            );
            provider.dispatch(
              DayNotesCommand(
                records.doc().days.single.id,
                'Keep my stale edits',
              ),
            );
            expect(await provider.confirmSave(provider.previewSave()), isFalse);
            final uncertain = failure != 'version_conflict';
            expect(
              provider.state,
              uncertain
                  ? ManualPlannerState.uncertain
                  : ManualPlannerState.conflict,
            );
            expect(provider.document!.days.single.notes, 'Keep my stale edits');
            expect(provider.baseHead!.version, 1);
            expect(provider.dirty, isTrue);
            expect(
              provider.hasPendingSave,
              uncertain,
              reason: 'Known rejected conflict must allow explicit editor replacement; unknown outcome must remain fenced.',
            );
          } finally {
            provider.dispose();
          }
        });
      },
    );
  }

  for (final uncertain in [false, true]) {
    test(
      'P32 persisted update conflict cleanup preserves unrelated receipt and uncertain=$uncertain',
      () async {
        await repository.run((ctx) async {
          await ctx.login();
          const committedRequest = '00000000-0000-4000-8000-000000009998';
          await ctx.repository.saveAccount(
            document: records.doc(),
            commands: [],
            requestId: committedRequest,
          );
          final service = EditableTripService(
            projectUrl: 'https://example.supabase.co',
            publicKey: 'public-test',
            isCurrentProof: ctx.lifecycle.isCurrentProof,
            adapter: _UpdateFailureAdapter(ctx.server, uncertain: uncertain),
          );
          final realRepository = EditableTripRepository(
            store: ctx.disk.store,
            lifecycle: ctx.lifecycle,
            service: service,
          );
          final provider = ManualPlannerProvider(
            repositoryLoader: () async => realRepository,
            lifecycle: ctx.lifecycle,
            newId: () => records.requestId,
          );
          try {
            provider.openSaved(
              EditableTripView(EditableTripViewState.online, records.head()),
            );
            provider.dispatch(
              DayNotesCommand(
                records.doc().days.single.id,
                'Retain my conflicting document',
              ),
            );
            expect(await provider.confirmSave(provider.previewSave()), isFalse);
            final pending = await ctx.disk.store.rawDb.query(
              'editable_mutation_outbox',
              where: 'request_id=?',
              whereArgs: [records.requestId],
            );
            expect(
              pending.length,
              uncertain ? 1 : 0,
              reason: 'Only a definitive rejected update may leave the unresolved outbox.',
            );
            if (uncertain) expect(pending.single['state'], 'staged');
            final committed = await ctx.disk.store.rawDb.query(
              'editable_mutation_outbox',
              where: 'request_id=?',
              whereArgs: [committedRequest],
            );
            expect(committed.single['state'], 'committed');
            expect(provider.hasPendingSave, uncertain);
            expect(
              provider.document!.days.single.notes,
              'Retain my conflicting document',
            );
            expect(provider.dirty, isTrue);
          } finally {
            provider.dispose();
            service.close();
          }
        });
      },
    );
  }

  test('P32 rejected update cleanup refuses changed frozen bytes and committed receipts', () async {
    await repository.run((ctx) async {
      await ctx.login();
      final provider = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: () => records.requestId,
      );
      try {
        provider.openSaved(
          EditableTripView(EditableTripViewState.online, records.head()),
        );
        provider.dispatch(
          DayNotesCommand(records.doc().days.single.id, 'Frozen update'),
        );
        ctx.server.offline = true;
        expect(await provider.confirmSave(provider.previewSave()), isFalse);
        final handle = ctx.lifecycle.handle!;
        final staged = (await ctx.disk.store.listEditableAttempts(
          handle: handle,
        )).single.attempt;
        final changed = EditableRecordCodec.attempt({
          ...EditableRecordCodec.attemptJson(staged),
          'expectedVersion': 2,
        });
        await expectLater(
          ctx.disk.store.discardRejectedEditableUpdate(
            handle: handle,
            attempt: changed,
          ),
          throwsA(isA<ImportAttemptConflictException>()),
        );
        expect(
          (await ctx.disk.store.listEditableAttempts(handle: handle))
              .single
              .attempt
              .expectedVersion,
          1,
        );
        ctx.server.offline = false;
        final committed = await ctx.repository.retryPending(records.requestId);
        expect(committed.status, EditableMutationStatus.committed);
        await expectLater(
          ctx.disk.store.discardRejectedEditableUpdate(
            handle: handle,
            attempt: staged,
          ),
          throwsA(isA<ImportAttemptConflictException>()),
        );
        final row = await ctx.disk.store.rawDb.query(
          'editable_mutation_outbox',
          where: 'request_id=?',
          whereArgs: [records.requestId],
        );
        expect(row.single['state'], 'committed');
      } finally {
        provider.dispose();
      }
    });
  });

  test('old receipt with newer head is conflict and does not silently replace editor base', () async {
    await repository.run((ctx) async {
      await ctx.login();
      final provider = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: () => records.requestId,
      );
      try {
        provider.openSaved(
          EditableTripView(EditableTripViewState.online, records.head()),
        );
        provider.dispatch(
          DayNotesCommand(records.doc().days.single.id, 'Mine'),
        );
        ctx.server.offline = true;
        expect(await provider.confirmSave(provider.previewSave()), isFalse);
        expect(provider.state, ManualPlannerState.uncertain);
        ctx.server.offline = false;
        ctx.disk.store.onEditableStepForTesting = (step) async {
          if (step == 'ack_snapshot_written') {
            throw StateError('lost local ack');
          }
        };
        expect(await provider.retrySave(), isFalse);
        final reply = ctx.server.replies[records.requestId]!;
        final doc = records.doc();
        final newer = records.head(
          version: 3,
          document: doc.copyWith(
            input: TripInput.fromJson({
              ...doc.input.toJson(),
              'title': 'Someone else',
            }),
          ),
        );
        reply['head'] = {
          'tripId': newer.tripId,
          'ownerId': newer.ownerId,
          'version': 3,
          'payloadText': newer.payloadText,
          'contentDigest': newer.contentDigest,
          'fetchedAt': newer.fetchedAt.toIso8601String(),
        };
        ctx.disk.store.onEditableStepForTesting = null;
        expect(await provider.retrySave(), isFalse);
        expect(provider.state, ManualPlannerState.conflict);
        expect(provider.baseHead!.version, 1);
        expect(provider.document!.days.single.notes, 'Mine');
        expect(provider.dirty, isTrue);
        expect(ctx.server.updates, 1);
      } finally {
        provider.dispose();
      }
    });
  });

  test('lifecycle invalidation and dispose fence delayed account saves and notifications', () async {
    await repository.run((ctx) async {
      await ctx.login();
      final provider = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        newId: () => records.requestId,
      );
      provider.openNew(records.doc());
      ctx.server.entered = Completer<void>();
      ctx.server.release = Completer<void>();
      final saving = provider.confirmSave(provider.previewSave());
      await ctx.server.entered!.future;
      ctx.lifecycle.invalidateAccountContext();
      expect(provider.document, isNull);
      var notifications = 0;
      provider.addListener(() => notifications++);
      provider.dispose();
      ctx.server.release!.complete();
      expect(await saving, isFalse);
      expect(notifications, 0);
    });
  });

  test('cached account view is read only and a preview cancelled by edits never writes', () async {
    await repository.run((ctx) async {
      await ctx.login();
      final provider = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
      );
      try {
        provider.openSaved(
          EditableTripView(
            EditableTripViewState.cachedReadOnly,
            records.head(),
          ),
        );
        expect(provider.isEditable, isFalse);
        expect(
          () => provider.dispatch(
            DayNotesCommand(records.doc().days.single.id, 'x'),
          ),
          throwsStateError,
        );
        expect(() => provider.previewSave(), throwsStateError);
        expect(ctx.server.updates, 0);
      } finally {
        provider.dispose();
      }
    });
  });
}
