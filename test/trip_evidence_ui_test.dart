import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/evidence_details_sheet.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_evidence_envelope.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'trip_evidence_repository_test.dart' as evidence;

void main() {
  for (final code in [
    'evidence_expired',
    'evidence_untrusted',
    'evidence_immutable',
    'evidence_stale_citation',
  ]) {
    for (final update in [false, true]) {
      test(
        'definitive $code ${update ? 'update' : 'create'} preserves editor and allows a new preview',
        () async {
          await evidence.withEvidenceRepository((ctx, server) async {
            final planner = ManualPlannerProvider(
              repositoryLoader: () async => ctx.repository,
              lifecycle: ctx.lifecycle,
            );
            try {
              final envelope = evidence.evidenceFixture();
              if (update) {
                final saved = await ctx.repository.saveEvidenceAccount(
                  envelope: envelope,
                  commands: [],
                );
                planner.openSaved(
                  EditableTripView(EditableTripViewState.online, saved.head),
                );
                server.rejectUpdate = code;
              } else {
                planner.openNew(envelope.document);
                planner.replaceEvidence(envelope);
                server.rejectCreate = code;
              }
              final before = planner.contentDigest;
              expect(await planner.confirmSave(planner.previewSave()), isFalse);
              expect(planner.contentDigest, before);
              expect(planner.hasPendingSave, isFalse);
              expect(planner.state, ManualPlannerState.error);
              expect(planner.errorMessage, contains('căn cứ'));
              expect(() => planner.previewSave(), returnsNormally);
              expect(
                await ctx.disk.store.listEditableAttempts(
                  handle: ctx.lifecycle.handle!,
                ),
                isEmpty,
              );
            } finally {
              planner.dispose();
            }
          });
        },
      );
    }
  }
  test('rejection cleanup IO failure retains pending bytes until a successful explicit retry', () async {
    await evidence.withEvidenceRepository((ctx, server) async {
      server.rejectCreate = 'evidence_expired';
      ctx.disk.store.onEditableStepForTesting = (step) async {
        if (step == 'rejected_attempt_removed') {
          throw StateError('synthetic cleanup IO failure');
        }
      };
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
      );
      try {
        final envelope = evidence.evidenceFixture();
        planner.openNew(envelope.document);
        planner.replaceEvidence(envelope);
        expect(await planner.confirmSave(planner.previewSave()), isFalse);
        expect(planner.hasPendingSave, isTrue);
        expect(planner.state, ManualPlannerState.uncertain);
        final pending = (await ctx.disk.store.listEditableAttempts(
          handle: ctx.lifecycle.handle!,
        )).single.attempt;
        ctx.disk.store.onEditableStepForTesting = null;
        expect(await planner.retrySave(), isFalse);
        expect(planner.hasPendingSave, isFalse);
        expect(planner.contentDigest, TripEvidenceCodec.digest(envelope));
        expect(
          await ctx.disk.store.listEditableAttempts(
            handle: ctx.lifecycle.handle!,
          ),
          isEmpty,
        );
        expect(pending.requestText, contains('travelgo.trip.evidence.v1'));
      } finally {
        planner.dispose();
      }
    });
  });
  test('timeout keeps frozen pending and later evidence edits remain dirty after retry', () async {
    await evidence.withEvidenceRepository((ctx, server) async {
      server.loseAck = true;
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
      );
      try {
        final envelope = evidence.evidenceFixture();
        planner.openNew(envelope.document);
        planner.replaceEvidence(envelope);
        expect(await planner.confirmSave(planner.previewSave()), isFalse);
        expect(planner.hasPendingSave, isTrue);
        final raw = envelope.toJson();
        ((raw['claims'] as List).first as Map)['text'] = 'Later user edit';
        planner.replaceEvidence(TripEvidenceEnvelope.fromJson(raw));
        final edited = planner.contentDigest;
        expect(await planner.retrySave(), isTrue);
        expect(server.creates, 1);
        expect(planner.contentDigest, edited);
        expect(planner.dirty, isTrue);
        expect(planner.hasPendingSave, isFalse);
      } finally {
        planner.dispose();
      }
    });
  });
  test('expired evidence is a definitive rejection and does not strand a pending save', () async {
    await evidence.withEvidenceRepository((ctx, server) async {
      server.rejectCreate = 'evidence_expired';
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
      );
      try {
        final envelope = evidence.evidenceFixture();
        planner.openNew(envelope.document);
        planner.replaceEvidence(envelope);
        final before = planner.contentDigest;
        expect(await planner.confirmSave(planner.previewSave()), isFalse);
        expect(planner.contentDigest, before);
        expect(server.latest, isNull);
        expect(planner.hasPendingSave, isFalse);
        expect(() => planner.previewSave(), returnsNormally);
      } finally {
        planner.dispose();
      }
    });
  });
  testWidgets(
    'source sheet unknown time large text and URL launch only after tap',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final env = evidence.evidenceFixture();
      final record = EvidenceRecord.fromJson({
        ...env.evidence.single.toJson(),
        'origin': 'web',
        'url': 'https://example.org/${'a' * 200}',
      });
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: EvidenceDetailsSheet(
                  records: [record],
                  claim: env.claims.single,
                  openSource: (url) async {
                    calls++;
                    return false;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(calls, 0);
      expect(
        find.text('Thông tin từ Internet, chưa được Admin kiểm duyệt'),
        findsOneWidget,
      );
      expect(find.textContaining('Ngày kiểm tra: Chưa rõ'), findsOneWidget);
      expect(find.textContaining('hôm nay'), findsNothing);
      final button = find.widgetWithText(OutlinedButton, 'Mở nguồn');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text('Không mở được nguồn. Bạn có thể sao chép liên kết.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('authority change hides source and disables stale link action', (
    tester,
  ) async {
    final env = evidence.evidenceFixture();
    final authority = ValueNotifier(true);
    addTearDown(authority.dispose);
    final record = EvidenceRecord.fromJson({
      ...env.evidence.single.toJson(),
      'origin': 'web',
      'url': 'https://example.org/a',
    });
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceDetailsSheet(
            records: [record],
            claim: env.claims.single,
            authority: authority,
            isCurrent: () => authority.value,
            openSource: (u) async {
              calls++;
              return true;
            },
          ),
        ),
      ),
    );
    authority.value = false;
    await tester.pump();
    expect(find.text(record.factValue), findsNothing);
    expect(find.text('Mở nguồn'), findsNothing);
    expect(calls, 0);
  });
  test(
    'planner preview cancel and source-only change use full digest',
    () async {
      await evidence.withEvidenceRepository((ctx, server) async {
        final planner = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
        );
        try {
          final head = EditableRecordCodec.head(evidence.evidenceHeadJson());
          planner.openSaved(
            EditableTripView(EditableTripViewState.online, head),
          );
          expect(planner.dirty, isFalse);
          final before = planner.contentDigest;
          final preview = planner.previewSave();
          planner.cancelPreview();
          expect(planner.contentDigest, before);
          final raw = jsonDecode(head.payloadText) as Map<String, Object?>;
          ((raw['claims'] as List).first as Map)['text'] = 'New context';
          planner.replaceEvidence(TripEvidenceEnvelope.fromJson(raw));
          expect(planner.dirty, isTrue);
          expect(await planner.confirmSave(preview), isFalse);
          expect(server.updates, 0);
        } finally {
          planner.dispose();
        }
      });
    },
  );
  test(
    'manual semantic edits detach citations and saved evidence roundtrips',
    () async {
      await evidence.withEvidenceRepository((ctx, server) async {
        final saved = await ctx.repository.saveEvidenceAccount(
          envelope: evidence.evidenceFixture(),
          commands: [],
        );
        final planner = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
          newId: () => '00000000-0000-4000-8000-000000000091',
        );
        try {
          planner.openSaved(
            EditableTripView(EditableTripViewState.online, saved.head),
          );
          final actual = planner.document!.actualExpenses.single.amountVnd;
          final item = planner.document!.items.single;
          planner.dispatchAll([
            EditItemCommand.fromItem(
              TripItem.fromJson({
                ...item.toJson(),
                'title': 'User changed activity',
              }),
            ),
          ]);
          expect(planner.document!.items.single.provenance.sourceRefs, isEmpty);
          expect(planner.document!.actualExpenses.single.amountVnd, actual);
          expect(
            TripEvidenceCodec.encode(planner.evidenceEnvelope!),
            isNotEmpty,
          );
          expect(await planner.confirmSave(planner.previewSave()), isTrue);
          final restored = await ctx.repository.readTrip(
            saved.head!.tripId,
            kind: OwnedTripKind.evidenceV1,
          );
          expect(
            restored
                .evidenceEnvelope!
                .document
                .items
                .single
                .provenance
                .sourceRefs,
            isEmpty,
          );
        } finally {
          planner.dispose();
        }
      });
    },
  );
  test(
    'rejected citation edit leaves document and pending commands unchanged',
    () async {
      await evidence.withEvidenceRepository((ctx, server) async {
        final planner = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
        );
        try {
          planner.openSaved(
            EditableTripView(
              EditableTripViewState.online,
              EditableRecordCodec.head(evidence.evidenceHeadJson()),
            ),
          );
          final before = planner.contentDigest;
          final item = planner.document!.items.single;
          final bad = TripItem.fromJson({
            ...item.toJson(),
            'notes': 'Edited notes',
            'provenance': {
              ...item.provenance.toJson(),
              'sourceRefs': ['missing'],
            },
          });
          expect(
            () => planner.dispatchAll([EditItemCommand.fromItem(bad)]),
            throwsException,
          );
          expect(planner.contentDigest, before);
          expect(planner.previewSave().commands, isEmpty);
        } finally {
          planner.dispose();
        }
      });
    },
  );
}
