import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;

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
