import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/screens/editable_trip_detail_screen.dart';
import 'package:travelgo_mobile/features/trips/presentation/widgets/editable_draft_import_selection.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';

import 'editable_guest_import_ui_test.dart'
    show withDraftUi, pumpDraftUi, waitImport;
import 'editable_saved_trip_ui_test.dart' show user;
import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;
import 'local_account_lifecycle_test.dart' as accounts;
import 'manual_discovery_flow_test.dart' show resources;
import 'manual_budget_ui_test.dart' show tapText, finishSave;
import 'native/editable_trip_probe.dart' show probeDocument;

Future<void> waitForEditor(
  WidgetTester tester,
  ManualPlannerRuntime runtime,
) async {
  for (
    var i = 0;
    i < 150 && (await runtime.getResources()).planner.document == null;
    i++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await tester.pump();
  }
  expect((await runtime.getResources()).planner.document, isNotNull);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Guest edit persists after restart, explicit account import, offline view then B fencing',
    (tester) async {
      await withDraftUi(tester, (ctx, auth, trips, firstRuntime) async {
        var runtime = firstRuntime;
        try {
          await pumpDraftUi(
            tester,
            const MyTripsScreen(),
            auth,
            trips,
            runtime,
          );
          // In C1: guest draft banner is removed from MyTripsScreen
          expect(find.text('Mở bản nháp tự lập'), findsNothing);

          // Use EditableGuestDraftList standalone (retained until C2) to open draft
          final initialBundle = await runtime.getResources();
          await initialBundle.drafts.load();
          await pumpDraftUi(
            tester,
            const Scaffold(
              body: EditableGuestDraftList(fallback: SizedBox.shrink()),
            ),
            auth,
            trips,
            runtime,
          );
          await tapText(tester, 'Mở bản nháp tự lập');
          await waitForEditor(tester, runtime);
          var planner = (await runtime.getResources()).planner;
          final id = planner.draftId!;
          await tapText(tester, 'Thêm hoạt động', scroll: 'manual.timeline');
          await tester.showKeyboard(
            find.byKey(const ValueKey('activity.title')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('activity.title')),
            'Ghé bảo tàng sau khi tự chọn',
          );
          await tapText(tester, 'Áp dụng thay đổi');
          await tapText(tester, 'Xem lại trước khi lưu');
          await tapText(
            tester,
            'Lưu bản nháp trên máy',
            scroll: 'manual.preview',
          );
          await finishSave(planner);
          await tester.pumpAndSettle();
          final digest = EditableTripCodec.digest(planner.document!);
          expect(ctx.server.creates, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          await runtime.close();
          await ctx.disk.store.close();
          await ctx.disk.store.open();
          runtime = ManualPlannerRuntime(factory: () async => resources(ctx));
          await pumpDraftUi(
            tester,
            const MyTripsScreen(),
            auth,
            trips,
            runtime,
          );
          // In C1: guest draft banner is removed from MyTripsScreen
          expect(find.text('Mở bản nháp tự lập'), findsNothing);

          // Use EditableGuestDraftList standalone (retained until C2) to reopen draft
          final reopenedBundle = await runtime.getResources();
          await reopenedBundle.drafts.load();
          await pumpDraftUi(
            tester,
            const Scaffold(
              body: EditableGuestDraftList(fallback: SizedBox.shrink()),
            ),
            auth,
            trips,
            runtime,
          );
          await tester.tap(find.text('Mở bản nháp tự lập').first);
          await tester.pump();
          await waitForEditor(tester, runtime);
          planner = (await runtime.getResources()).planner;
          expect(planner.draftId, id);
          expect(EditableTripCodec.digest(planner.document!), digest);
          expect(
            planner.document!.items.single.title,
            'Ghé bảo tàng sau khi tự chọn',
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          await ctx.login();
          auth.simulateSupabaseUser(user(records.ownerA));
          await pumpDraftUi(
            tester,
            const EditableDraftImportSelection(expectedOwnerId: records.ownerA),
            auth,
            trips,
            runtime,
          );
          expect(ctx.server.creates, 0);
          await tester.tap(find.byKey(ValueKey('import.v2.$id')));
          await tester.pump();
          await tapText(tester, 'Xem lại 1 bản nháp tự lập');
          await tapText(tester, 'Xác nhận chuyển bản tự lập');
          await waitImport(tester, runtime);
          expect(ctx.server.creates, 1);
          expect(
            await ctx.disk.store.readEditableDraft(
              deviceScope: 'default',
              draftId: id,
            ),
            isNull,
          );
          ctx.server.offline = true;
          await pumpDraftUi(
            tester,
            const EditableTripDetailScreen(
              tripId: records.tripId,
              expectedOwnerId: records.ownerA,
            ),
            auth,
            trips,
            runtime,
          );
          expect(
            find.text('Ngoại tuyến · bản trên máy chỉ đọc'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Chỉnh sửa lịch trình'),
                )
                .onPressed,
            isNull,
          );
          auth.simulateSupabaseUser(user(records.ownerB));
          ctx.lifecycle.invalidateAccountContext();
          await tester.pump();
          expect(find.text(records.doc().input.title), findsNothing);
          expect(
            find.text('Phiên đã thay đổi. Quay lại danh sách chuyến đi.'),
            findsOneWidget,
          );
          expect(await ctx.lifecycle.revokeAccount(), isTrue);
          ctx.session = accounts.sessionFor(records.ownerB);
          await ctx.login();
          expect(
            await ctx.disk.store.listEditableSnapshots(
              handle: ctx.lifecycle.handle!,
            ),
            isEmpty,
          );
          expect(
            (await ctx.disk.store.listEditableDrafts(deviceScope: 'default'))
                .length,
            1,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await runtime.close();
        }
      }, guest: true);
    },
  );
  test(
    'sealed account cache survives real disk reopen and is purged before B',
    () async {
      await repository.run((ctx) async {
        await ctx.repository.saveGuest(
          scope: 'default',
          draftId: records.draftId,
          expectedRevision: null,
          document: records.doc(),
        );
        await ctx.login();
        await ctx.disk.store.putEditableSnapshot(
          handle: ctx.lifecycle.handle!,
          head: records.head(),
        );
        expect(await ctx.lifecycle.sealForPause(), isTrue);
        await ctx.close();
        await ctx.disk.store.close();
        await ctx.disk.store.open();
        ctx.bind();
        final restored = await ctx.lifecycle.resumeAccount();
        expect(restored?.ownerId, records.ownerA);
        final head = await ctx.disk.store.readEditableSnapshot(
          handle: restored!,
          tripId: records.tripId,
        );
        expect(
          head!.head.contentDigest,
          EditableTripCodec.digest(records.doc()),
        );
        expect(
          head.head.document.actualExpenses.single.amountVnd,
          records.doc().actualExpenses.single.amountVnd,
        );
        expect(await ctx.lifecycle.revokeAccount(), isTrue);
        ctx.session = accounts.sessionFor(records.ownerB);
        await ctx.login();
        expect(
          await ctx.disk.store.listEditableSnapshots(
            handle: ctx.lifecycle.handle!,
          ),
          isEmpty,
        );
        expect(
          await ctx.disk.store.listEditableAttempts(
            handle: ctx.lifecycle.handle!,
          ),
          isEmpty,
        );
        expect(
          await ctx.disk.store.readEditableDraft(
            deviceScope: 'default',
            draftId: records.draftId,
          ),
          isNotNull,
        );
      });
    },
  );
  test('native probe synthetic document is strict and contains a linked actual ledger', () {
    final doc = probeDocument();
    final text = EditableTripCodec.encode(doc);
    expect(EditableTripCodec.encode(EditableTripCodec.decode(text)), text);
    expect(doc.input.destinationId, 'hue');
    expect(doc.actualExpenses.single.amountVnd, 20000);
    expect(
      doc.actualExpenses.single.sourceItemSnapshot!.title,
      doc.items.single.title,
    );
  });
}
