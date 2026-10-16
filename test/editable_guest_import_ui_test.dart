import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/widgets/editable_draft_import_selection.dart';

import 'editable_trip_repository_test.dart' as repository;
import 'editable_local_store_test.dart' as records;
import 'manual_discovery_flow_test.dart' show resources;
import 'editable_saved_trip_ui_test.dart' show UiTrips, user;
import 'manual_budget_ui_test.dart' show tapText;

Future<void> withDraftUi(
  WidgetTester tester,
  Future<void> Function(
    repository.Context,
    AuthProvider,
    UiTrips,
    ManualPlannerRuntime,
  )
  body, {
  bool guest = false,
  bool incomplete = false,
}) async {
  await tester.runAsync(
    () => repository.run((ctx) async {
      var doc = records.doc();
      if (incomplete) {
        doc = doc.copyWith(
          input: TripInput.fromJson({
            ...doc.input.toJson(),
            'startDate': null,
            'endDate': null,
          }),
          days: [
            TripDay.fromJson({...doc.days.single.toJson(), 'date': null}),
          ],
        );
      }
      for (final id in [records.draftId, records.requestId]) {
        await ctx.repository.saveGuest(
          scope: 'default',
          draftId: id,
          expectedRevision: null,
          document: doc,
        );
      }
      if (guest) {
        ctx.lifecycle.invalidateAccountContext();
      } else {
        await ctx.login();
      }
      final auth = AuthProvider(trustedRoleFetcher: (_) async => 'customer');
      await auth.initialization;
      if (guest) {
        auth.continueAsGuest();
      } else {
        auth.simulateSupabaseUser(user(records.ownerA));
      }
      final trips = UiTrips();
      final runtime = ManualPlannerRuntime(factory: () async => resources(ctx));
      try {
        await body(ctx, auth, trips, runtime);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await runtime.close();
        trips.dispose();
        auth.dispose();
      }
    }),
  );
}

Future<void> pumpDraftUi(
  WidgetTester tester,
  Widget home,
  AuthProvider auth,
  UiTrips trips,
  ManualPlannerRuntime runtime,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider<SavedTripsProvider>.value(value: trips),
        Provider.value(value: runtime),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ),
  );
  await tester.pump();
  await Future<void>.delayed(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

Future<void> waitImport(
  WidgetTester tester,
  ManualPlannerRuntime runtime,
) async {
  final drafts = (await runtime.getResources()).drafts;
  for (var i = 0; i < 200 && drafts.isImporting; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(drafts.isImporting, isFalse);
  await tester.pumpAndSettle();
}

// Simulate another Guest workspace writing a newer revision to this synthetic
// disk. The account-facing API must continue to reject Guest writes.
Future<void> advanceGuestDisk(repository.Context ctx, String id) async {
  final previous = await ctx.disk.store.readEditableDraft(
    deviceScope: 'default',
    draftId: id,
  );
  expect(previous!.revision, 1);
  final doc = records.doc().copyWith(
    input: TripInput.fromJson({
      ...records.doc().input.toJson(),
      'title': 'Bản mới trên máy',
    }),
  );
  final text = EditableTripCodec.encode(doc);
  await ctx.disk.store.rawDb.insert('guest_editable_drafts', {
    'device_scope': 'default',
    'draft_id': id,
    'revision': 2,
    'payload_text': text,
    'content_digest': EditableTripCodec.digestText(text),
    'saved_at': DateTime.now().toUtc().toIso8601String(),
  });
}

const selector = EditableDraftImportSelection(expectedOwnerId: records.ownerA);
void main() {
  testWidgets(
    'no auto import; choose one of two, preview cancel, then explicit import',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, runtime) async {
        await pumpDraftUi(tester, selector, auth, trips, runtime);
        expect(ctx.server.creates, 0);
        expect(find.byType(CheckboxListTile), findsNWidgets(2));
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Xem lại 0 bản nháp tự lập'),
        );
        expect(button.onPressed, isNull);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        final draft = (await runtime.getResources()).drafts.selected.single;
        await tapText(tester, 'Xem lại 1 bản nháp tự lập');
        expect(find.textContaining('phiên bản 1'), findsWidgets);
        await tapText(tester, 'Hủy');
        expect(ctx.server.creates, 0);
        await tapText(tester, 'Xem lại 1 bản nháp tự lập');
        await tapText(tester, 'Xác nhận chuyển bản tự lập');
        await waitImport(tester, runtime);
        expect(ctx.server.creates, 1);
        expect(trips.loads, 1);
        expect(
          await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: draft.draftId,
          ),
          isNull,
        );
        expect(
          (await ctx.disk.store.listEditableDrafts(deviceScope: 'default'))
              .length,
          1,
        );
      });
    },
  );
  testWidgets('incomplete dates explain completion and never submit', (
    tester,
  ) async {
    await withDraftUi(tester, (ctx, auth, trips, runtime) async {
      await pumpDraftUi(tester, selector, auth, trips, runtime);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tapText(tester, 'Xem lại 1 bản nháp tự lập');
      expect(find.textContaining('Hoàn thiện'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận chuyển bản tự lập'),
            )
            .onPressed,
        isNull,
      );
      expect(ctx.server.creates, 0);
    }, incomplete: true);
  });
  testWidgets(
    'account changes during consent hides selected private data and prevents request',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, runtime) async {
        await pumpDraftUi(tester, selector, auth, trips, runtime);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        await tapText(tester, 'Xem lại 1 bản nháp tự lập');
        auth.simulateSupabaseUser(user(records.ownerB));
        ctx.lifecycle.invalidateAccountContext();
        await tester.pump();
        expect(find.textContaining('Tài khoản đã thay đổi'), findsWidgets);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận chuyển bản tự lập'),
              )
              .onPressed,
          isNull,
        );
        expect(ctx.server.creates, 0);
      });
    },
  );
  testWidgets(
    'new disk revision while consent is open rejects stale selection',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, runtime) async {
        await pumpDraftUi(tester, selector, auth, trips, runtime);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        final source = (await runtime.getResources()).drafts.selected.single;
        await tapText(tester, 'Xem lại 1 bản nháp tự lập');
        await advanceGuestDisk(ctx, source.draftId);
        await tapText(tester, 'Xác nhận chuyển bản tự lập');
        await waitImport(tester, runtime);
        expect(ctx.server.creates, 0);
        expect(find.textContaining('đã thay đổi'), findsWidgets);
        expect(
          (await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: source.draftId,
          ))!.revision,
          2,
        );
      });
    },
  );
  testWidgets(
    'acknowledging revision one does not remove a newer Guest revision',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, runtime) async {
        ctx.server.entered = Completer<void>();
        ctx.server.release = Completer<void>();
        await pumpDraftUi(tester, selector, auth, trips, runtime);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        final source = (await runtime.getResources()).drafts.selected.single;
        await tapText(tester, 'Xem lại 1 bản nháp tự lập');
        await tester.tap(find.text('Xác nhận chuyển bản tự lập'));
        await tester.pump();
        await ctx.server.entered!.future;
        await advanceGuestDisk(ctx, source.draftId);
        ctx.server.release!.complete();
        await waitImport(tester, runtime);
        expect(ctx.server.creates, 1);
        expect(
          (await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: source.draftId,
          ))!.revision,
          2,
        );
      });
    },
  );
  testWidgets(
    'lost local ack retries original request even after Guest revision advances',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, runtime) async {
        await pumpDraftUi(tester, selector, auth, trips, runtime);
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        final source = (await runtime.getResources()).drafts.selected.single;
        ctx.disk.store.onEditableStepForTesting = (step) async {
          if (step == 'ack_snapshot_written') {
            throw StateError('synthetic lost ack');
          }
        };
        await tapText(tester, 'Xem lại 1 bản nháp tự lập');
        await tapText(tester, 'Xác nhận chuyển bản tự lập');
        await waitImport(tester, runtime);
        expect(ctx.server.creates, 1);
        expect((await runtime.getResources()).drafts.uncertain, isTrue);
        expect(
          await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: source.draftId,
          ),
          isNotNull,
        );
        ctx.disk.store.onEditableStepForTesting = null;
        await advanceGuestDisk(ctx, source.draftId);
        await tapText(tester, 'Kiểm tra lại lần chuyển');
        await tapText(tester, 'Xác nhận kiểm tra lại');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(ctx.server.creates, 1);
        expect((await runtime.getResources()).drafts.uncertain, isFalse);
        expect(
          (await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: source.draftId,
          ))!.revision,
          2,
        );
      });
    },
  );
  testWidgets(
    'Guest list opens exact V2 draft without account write or V1 decoding',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, runtime) async {
        await pumpDraftUi(tester, const MyTripsScreen(), auth, trips, runtime);
        expect(find.text('Bản nháp tự lập trên máy'), findsOneWidget);
        final source = (await runtime.getResources()).drafts.drafts.last;
        await tapText(tester, 'Mở bản nháp tự lập');
        for (
          var i = 0;
          i < 100 && find.byType(ManualPlannerScreen).evaluate().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byType(ManualPlannerScreen), findsOneWidget);
        final planner = (await runtime.getResources()).planner;
        expect(planner.draftId, source.draftId);
        expect(
          EditableTripCodec.digest(planner.document!),
          source.contentDigest,
        );
        expect(ctx.server.creates, 0);
      }, guest: true);
    },
  );
}
