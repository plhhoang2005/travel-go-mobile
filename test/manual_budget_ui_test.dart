import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/manual_budget_panel.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/manual_expense_form.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/manual_save_preview.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/editable_trip_mutator.dart';
import 'package:travelgo_mobile/features/trip_planner/services/budget_calculator.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/editable_remote_records.dart';
import 'package:travelgo_mobile/features/trips/models/editable_local_records.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;
import 'manual_planner_screen_test.dart' as editor;

Future<void> tapText(WidgetTester tester, String text, {String? scroll}) async {
  await tester.pumpAndSettle();
  final target = find.text(text);
  if (scroll != null && target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(ValueKey(scroll)),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target.last);
  await tester.pumpAndSettle();
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

Future<void> pumpForm(
  WidgetTester tester,
  ManualExpenseKind kind,
  ValueChanged<EditableCommand?> result, {
  String? expenseId,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('Mở form'),
            onPressed: () async {
              result(
                await Navigator.of(context).push<EditableCommand>(
                  MaterialPageRoute(
                    builder: (_) => ManualExpenseForm(
                      document: records.doc(),
                      kind: kind,
                      newId: editor.nextId,
                      expenseId: expenseId,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tapText(tester, 'Mở form');
}

Future<void> pumpBudgetEditor(
  WidgetTester tester,
  ManualPlannerProvider planner,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ManualPlannerScreen(
        planner: planner,
        destinations: editor.destinations(),
        newId: editor.nextId,
        enableBudget: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> finishSave(ManualPlannerProvider planner) async {
  for (var n = 0; n < 300 && planner.isSaving; n++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(planner.isSaving, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'budget chart keeps estimates, actuals and unknown prices separate at large text',
    (tester) async {
      final base = records.doc();
      final document = base.copyWith(
        input: TripInput.fromJson({
          ...base.input.toJson(),
          'totalBudgetVnd': 1,
        }),
      );
      final totals = BudgetCalculator.calculate(document);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManualBudgetSummary(totals: totals, budget: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.map((g) => g.barRods.single.toY), [
        1.0,
        300000.0,
        250000.0,
      ]);
      expect(find.text('Chưa gồm 1 khoản chưa biết giá'), findsOneWidget);
      expect(
        find.text('Vượt ngân sách theo dự kiến: 299.999 đ'),
        findsOneWidget,
      );
      expect(
        find.text('Vượt ngân sách theo đã chi: 249.999 đ'),
        findsOneWidget,
      );
      expect(chart.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paid-date calendar preserves exact VND and does not guess a payment date',
    (tester) async {
      EditableCommand? result;
      await pumpForm(tester, ManualExpenseKind.actual, (v) => result = v);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('expense.paidOn')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const ValueKey('expense.amount')),
        '5123456',
      );
      await tapText(tester, 'Chọn ngày đã chi trên lịch');
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 10, 17));
      await tester.pumpAndSettle();
      await tapText(tester, 'Áp dụng thay đổi');
      expect((result as PutActualCommand).actual.amountVnd, 5123456);
      expect((result as PutActualCommand).actual.paidOn, '2026-10-17');
    },
  );
  testWidgets(
    'Guest confirms one frozen itinerary and actual snapshot to disk',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            newId: editor.nextId,
          );
          try {
            planner.openNew(records.doc());
            planner.dispatch(
              DayNotesCommand(planner.document!.days.single.id, 'Together'),
            );
            final actual = planner.document!.actualExpenses.single;
            planner.dispatch(
              PutActualCommand(
                ActualExpense.fromJson({
                  ...actual.toJson(),
                  'amountVnd': 123456,
                }),
              ),
            );
            final expected = EditableTripCodec.encode(planner.document!);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.lightTheme,
                home: ManualSavePreview(
                  planner: planner,
                  preview: planner.previewSave(),
                  onResolveIssue: (_) {},
                ),
              ),
            );
            await tapText(
              tester,
              'Lưu bản nháp trên máy',
              scroll: 'manual.preview',
            );
            for (var n = 0; n < 100 && planner.isSaving; n++) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            final saved = await ctx.disk.store.readEditableDraft(
              deviceScope: 'default',
              draftId: planner.draftId!,
            );
            expect(saved, isNotNull);
            expect(EditableTripCodec.encode(saved!.document), expected);
            expect(planner.dirty, isFalse);
            expect(ctx.server.creates, 0);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            planner.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'overlap reason binds only that fingerprint and requires another preview',
    (tester) async {
      final doc = records.doc(), dayId = records.doc().days.single.id;
      final provenance = FieldProvenance(
        quality: 'user_provided',
        sourceRefs: [],
        observedAt: null,
      );
      final planner = editor.guest(
        document: doc.copyWith(
          items: [
            for (var i = 0; i < 2; i++)
              TripItem(
                id: editor.nextId(),
                dayId: dayId,
                position: i,
                title: 'Overlap $i',
                placeId: null,
                startMinute: 540 + i * 15,
                endMinute: 600 + i * 15,
                notes: '',
                provenance: provenance,
              ),
          ],
        ),
      );
      addTearDown(planner.dispose);
      final preview = planner.previewSave();
      final fingerprint = preview.issues
          .singleWhere((i) => i.code == 'overlap')
          .fingerprint;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ManualSavePreview(
            planner: planner,
            preview: preview,
            onResolveIssue: (_) {},
          ),
        ),
      );
      await tapText(tester, 'Ghi lý do chấp nhận', scroll: 'manual.preview');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('preview.reason')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('manual.preview')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('preview.reason')),
        'Hai người tham gia riêng',
      );
      await tapText(tester, 'Áp dụng lý do và xem lại sau');
      expect(planner.document!.exceptions.single.fingerprint, fingerprint);
      expect(
        planner.document!.exceptions.single.reason,
        'Hai người tham gia riêng',
      );
      expect(await planner.confirmSave(preview), isFalse);
      expect(
        planner
            .previewSave()
            .issues
            .singleWhere((i) => i.code == 'overlap')
            .acknowledged,
        isTrue,
      );
    },
  );

  testWidgets('cached account budget exposes no expense write actions', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.run((ctx) async {
        await ctx.login();
        final planner = ManualPlannerProvider(
          repositoryLoader: () async => ctx.repository,
          lifecycle: ctx.lifecycle,
          newId: editor.nextId,
        );
        var edits = 0;
        try {
          planner.openSaved(
            EditableTripView(
              EditableTripViewState.cachedReadOnly,
              records.head(),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ManualBudgetPanel(
                  planner: planner,
                  onEditExpense: (_, _) => edits++,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Thêm khoản dự kiến'), findsNothing);
          expect(find.text('Sửa dự kiến'), findsNothing);
          await tester.drag(
            find.byKey(const ValueKey('manual.budget')),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(find.text('Thêm khoản đã chi'), findsNothing);
          expect(find.text('Sửa khoản đã chi'), findsNothing);
          expect(edits, 0);
          expect(ctx.server.updates, 0);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          planner.dispose();
        }
      }),
    );
  });
  testWidgets(
    'budget shows independent estimates and actual balances including negatives',
    (tester) async {
      final planner = editor.guest();
      addTearDown(planner.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: planner,
              builder: (_, _) =>
                  ManualBudgetPanel(planner: planner, onEditExpense: (_, _) {}),
            ),
          ),
        ),
      );
      expect(find.text('Dự kiến đã biết: 300.000 đ'), findsOneWidget);
      expect(find.text('Còn theo dự kiến: 200.000 đ'), findsOneWidget);
      expect(find.text('Chưa gồm 1 khoản chưa biết giá'), findsOneWidget);
      expect(find.text('Đã chi: 250.000 đ'), findsOneWidget);
      expect(find.text('Còn theo đã chi: 250.000 đ'), findsOneWidget);
      planner.dispatch(
        SetTripInputCommand(
          TripInput.fromJson({
            ...planner.document!.input.toJson(),
            'totalBudgetVnd': 1,
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Còn theo dự kiến: -299.999 đ'), findsOneWidget);
      expect(find.text('Còn theo đã chi: -249.999 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('estimate empty money stays unknown and zero is explicit', (
    tester,
  ) async {
    EditableCommand? result;
    await pumpForm(tester, ManualExpenseKind.estimate, (v) => result = v);
    await tapText(tester, 'Áp dụng thay đổi');
    expect((result as PutEstimateCommand).estimate.unitAmountVnd, isNull);
    expect(
      (result as PutEstimateCommand).estimate.provenance.quality,
      'unknown',
    );
    await tapText(tester, 'Mở form');
    await tester.enterText(find.byKey(const ValueKey('expense.amount')), '0');
    await tapText(tester, 'Áp dụng thay đổi');
    expect((result as PutEstimateCommand).estimate.unitAmountVnd, 0);
    expect(
      (result as PutEstimateCommand).estimate.provenance.quality,
      'user_provided',
    );
  });

  testWidgets(
    'actual requires integer money and real paid date without multiplier',
    (tester) async {
      EditableCommand? result;
      await pumpForm(tester, ManualExpenseKind.actual, (v) => result = v);
      expect(find.text('Cơ sở tính'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('expense.amount')),
        '1.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('expense.paidOn')),
        '2026-02-30',
      );
      await tapText(tester, 'Áp dụng thay đổi');
      expect(result, isNull);
      expect(
        find.text('Nhập số tiền VND nguyên trong giới hạn hỗ trợ.'),
        findsOneWidget,
      );
      expect(find.text('Nhập ngày có thật theo YYYY-MM-DD.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('expense.amount')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('expense.paidOn')),
        '2026-10-14',
      );
      await tapText(tester, 'Áp dụng thay đổi');
      final actual = (result as PutActualCommand).actual;
      expect(actual.amountVnd, 123456);
      expect(actual.paidOn, '2026-10-14');
      expect(actual.provenance.quality, 'user_provided');
    },
  );

  testWidgets(
    'actual deletion needs its own confirmation and cancel keeps bytes',
    (tester) async {
      EditableCommand? result;
      await pumpForm(
        tester,
        ManualExpenseKind.actual,
        (v) => result = v,
        expenseId: records.doc().actualExpenses.single.id,
      );
      await tapText(tester, 'Xóa khoản đã chi');
      await tapText(tester, 'Giữ khoản đã chi');
      expect(result, isNull);
      await tapText(tester, 'Xóa khoản đã chi');
      await tapText(tester, 'Xác nhận xóa khoản chi');
      expect(
        (result as DeleteActualCommand).expenseId,
        records.doc().actualExpenses.single.id,
      );
    },
  );

  testWidgets(
    'save preview shows implicit unlink separately and cancellation never writes',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            newId: editor.nextId,
          );
          try {
            final linked = editor.documentWithLinkedActivity();
            final record = await ctx.repository.saveGuest(
              scope: 'default',
              draftId: records.draftId,
              expectedRevision: null,
              document: linked,
            );
            planner.openDraft(record);
            planner.dispatch(RemoveItemCommand(linked.items.single.id));
            final preview = planner.previewSave();
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.lightTheme,
                home: ManualSavePreview(
                  planner: planner,
                  preview: preview,
                  onResolveIssue: (_) {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tapText(tester, 'Các khoản đã chi', scroll: 'manual.preview');
            expect(
              find.textContaining('Giữ khoản đã chi; bỏ liên kết hoạt động'),
              findsOneWidget,
            );
            expect(planner.document!.actualExpenses.single.amountVnd, 250000);
            expect(ctx.server.creates, 0);
            planner.cancelPreview();
            expect(await planner.confirmSave(preview), isFalse);
            expect(planner.draftRevision, 1);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            planner.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'stale frozen preview disables confirm without replacing its content',
    (tester) async {
      final planner = editor.guest();
      addTearDown(planner.dispose);
      final preview = planner.previewSave();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ManualSavePreview(
            planner: planner,
            preview: preview,
            onResolveIssue: (_) {},
          ),
        ),
      );
      planner.dispatch(
        DayNotesCommand(planner.document!.days.single.id, 'Later edit'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Nội dung đã thay đổi. Quay lại và xem lại trước khi lưu.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Lưu bản nháp trên máy'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('manual.preview')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu bản nháp trên máy'),
      );
      expect(button.onPressed, isNull);
      expect(await planner.confirmSave(preview), isFalse);
      expect(EditableTripCodec.digest(preview.document), preview.digest);
    },
  );

  testWidgets(
    'account missing dates blocks preview and session change removes private content',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          await ctx.login();
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            lifecycle: ctx.lifecycle,
            newId: editor.nextId,
          );
          try {
            final doc = records.doc();
            planner.openNew(
              doc.copyWith(
                input: TripInput.fromJson({
                  ...doc.input.toJson(),
                  'title': 'PRIVATE BUDGET',
                  'startDate': null,
                  'endDate': null,
                }),
                days: [
                  TripDay.fromJson({...doc.days.single.toJson(), 'date': null}),
                ],
              ),
            );
            final preview = planner.previewSave();
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.lightTheme,
                home: ManualSavePreview(
                  planner: planner,
                  preview: preview,
                  onResolveIssue: (_) {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(preview.canConfirm, isFalse);
            await tester.scrollUntilVisible(
              find.text('Lưu vào tài khoản'),
              300,
              scrollable: find
                  .descendant(
                    of: find.byKey(const ValueKey('manual.preview')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Lưu vào tài khoản'),
                  )
                  .onPressed,
              isNull,
            );
            ctx.lifecycle.invalidateAccountContext();
            await tester.pumpAndSettle();
            expect(find.textContaining('PRIVATE BUDGET'), findsNothing);
            expect(ctx.server.creates, 0);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            planner.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'default editor budget route applies actual in RAM and preview groups it',
    (tester) async {
      final planner = editor.guest();
      addTearDown(planner.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ManualPlannerScreen(
            planner: planner,
            destinations: editor.destinations(),
            newId: editor.nextId,
            enableBudget: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Ngân sách');
      await tapText(tester, 'Thêm khoản đã chi', scroll: 'manual.budget');
      await tester.enterText(
        find.byKey(const ValueKey('expense.amount')),
        '10000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('expense.paidOn')),
        '2026-10-15',
      );
      await tapText(tester, 'Áp dụng thay đổi');
      expect(planner.document!.actualExpenses.length, 2);
      expect(planner.totals!.actualTotal, 260000);
      await tapText(tester, 'Xem lại trước khi lưu');
      expect(find.text('Xem lại chuyến đi'), findsOneWidget);
      await tapText(tester, 'Các khoản đã chi', scroll: 'manual.preview');
      expect(find.textContaining('10.000 đ'), findsWidgets);
      await tapText(tester, 'Quay lại chỉnh sửa');
      expect(planner.document!.actualExpenses.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every estimate basis uses explicit integer quantity', (
    tester,
  ) async {
    for (final basis in manualExpenseBases.entries) {
      EditableCommand? result;
      await pumpForm(tester, ManualExpenseKind.estimate, (v) => result = v);
      await tester.enterText(
        find.byKey(const ValueKey('expense.amount')),
        '100',
      );
      if (basis.key != 'trip_total') {
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tapText(tester, basis.value);
      }
      if (basis.key == 'custom_quantity') {
        await tester.enterText(
          find.byKey(const ValueKey('expense.quantity')),
          '0',
        );
        await tapText(tester, 'Áp dụng thay đổi');
        expect(result, isNull);
        expect(
          find.text('Nhập số lượng nguyên dương trong giới hạn hỗ trợ.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('expense.quantity')),
          '2',
        );
      }
      await tapText(tester, 'Áp dụng thay đổi');
      final e = (result as PutEstimateCommand).estimate;
      expect(e.basis, basis.key);
      expect(e.customQuantity, basis.key == 'custom_quantity' ? 2 : null);
      final candidate = EditableTripMutator.apply(records.doc(), [result!]);
      final factor = {
        'trip_total': 1,
        'per_person': 3,
        'per_day': 1,
        'per_person_day': 3,
        'custom_quantity': 2,
      }[basis.key]!;
      expect(
        BudgetCalculator.calculate(candidate).knownEstimate,
        300000 + 100 * factor,
      );
    }
  });

  testWidgets('warning on another day opens the exact activity form', (
    tester,
  ) async {
    final linked = editor.documentWithLinkedActivity();
    final target = linked.items.single;
    final planner = editor.guest(
      document: linked.copyWith(
        items: [
          TripItem.fromJson({...target.toJson(), 'endMinute': null}),
        ],
      ),
    );
    addTearDown(planner.dispose);
    await pumpBudgetEditor(tester, planner);
    await tapText(tester, 'Xem lại trước khi lưu');
    await tapText(tester, 'Đi sửa nội dung', scroll: 'manual.preview');
    expect(find.byKey(const ValueKey('activity.title')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('activity.title')))
          .controller!
          .text,
      target.title,
    );
    await tester.enterText(find.byKey(const ValueKey('activity.end')), '10:30');
    await tapText(tester, 'Áp dụng thay đổi');
    expect(planner.document!.items.single.id, target.id);
    expect(planner.document!.items.single.dayId, target.dayId);
    expect(planner.document!.items.single.endMinute, 630);
    expect(find.textContaining('Ngày 3'), findsWidgets);
  });

  testWidgets(
    'account save keeps later UI edits dirty while one snapshot is in flight',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          await ctx.login();
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            lifecycle: ctx.lifecycle,
            newId: editor.nextId,
          );
          try {
            planner.openSaved(
              EditableTripView(EditableTripViewState.online, records.head()),
            );
            planner.dispatch(
              DayNotesCommand(
                planner.document!.days.single.id,
                'Submitted note',
              ),
            );
            await pumpBudgetEditor(tester, planner);
            ctx.server.entered = Completer<void>();
            ctx.server.release = Completer<void>();
            await tapText(tester, 'Xem lại trước khi lưu');
            await tapText(
              tester,
              'Lưu vào tài khoản',
              scroll: 'manual.preview',
            );
            await ctx.server.entered!.future.timeout(
              const Duration(seconds: 3),
            );
            expect(planner.isSaving, isTrue);
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Lưu vào tài khoản'),
                  )
                  .onPressed,
              isNull,
            );
            await tapText(tester, 'Quay lại chỉnh sửa');
            await tapText(
              tester,
              'Sửa ghi chú ngày',
              scroll: 'manual.timeline',
            );
            await tester.enterText(
              find.byKey(const ValueKey('day.notes')),
              'Later UI edit',
            );
            await tapText(tester, 'Áp dụng thay đổi');
            ctx.server.release!.complete();
            await finishSave(planner);
            await tester.pumpAndSettle();
            expect(planner.document!.days.single.notes, 'Later UI edit');
            expect(planner.dirty, isTrue);
            expect(planner.baseHead!.version, 2);
            expect(
              ctx.server.latest!.document.days.single.notes,
              'Submitted note',
            );
            expect(ctx.server.updates, 1);
            expect(
              await ctx.disk.store.rawDb.query('guest_editable_drafts'),
              isEmpty,
            );
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            if (!(ctx.server.release?.isCompleted ?? true)) {
              ctx.server.release!.complete();
            }
            planner.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'uncertain retry reuses receipt and newer head stays a conflict in UI',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          await ctx.login();
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            lifecycle: ctx.lifecycle,
            newId: editor.nextId,
          );
          try {
            planner.openSaved(
              EditableTripView(EditableTripViewState.online, records.head()),
            );
            planner.dispatch(
              DayNotesCommand(planner.document!.days.single.id, 'Mine'),
            );
            await pumpBudgetEditor(tester, planner);
            ctx.server.offline = true;
            await tapText(tester, 'Xem lại trước khi lưu');
            await tapText(
              tester,
              'Lưu vào tài khoản',
              scroll: 'manual.preview',
            );
            await finishSave(planner);
            await tester.pumpAndSettle();
            expect(planner.state, ManualPlannerState.uncertain);
            await tapText(tester, 'Quay lại chỉnh sửa');
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Xem lại trước khi lưu'),
                  )
                  .onPressed,
              isNull,
            );
            ctx.server.offline = false;
            ctx.disk.store.onEditableStepForTesting = (step) async {
              if (step == 'ack_snapshot_written') {
                throw StateError('lost local acknowledgement');
              }
            };
            await tapText(
              tester,
              'Thử lại lần lưu trước',
              scroll: 'manual.timeline',
            );
            await finishSave(planner);
            await tester.pumpAndSettle();
            expect(planner.state, ManualPlannerState.uncertain);
            final key = ctx.server.replies.keys.single;
            final newer = records.head(
              version: 3,
              document: records.doc().copyWith(
                input: TripInput.fromJson({
                  ...records.doc().input.toJson(),
                  'title': 'Newer remote',
                }),
              ),
            );
            ctx.server.replies[key]!['head'] = EditableRecordCodec.headJson(
              newer,
            );
            ctx.disk.store.onEditableStepForTesting = null;
            await tapText(
              tester,
              'Thử lại lần lưu trước',
              scroll: 'manual.timeline',
            );
            await finishSave(planner);
            await tester.pumpAndSettle();
            expect(planner.state, ManualPlannerState.conflict);
            expect(planner.baseHead!.version, 1);
            expect(planner.document!.days.single.notes, 'Mine');
            expect(planner.dirty, isTrue);
            expect(ctx.server.replies.keys.single, key);
            expect(ctx.server.updates, 1);
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Xem lại trước khi lưu'),
                  )
                  .onPressed,
              isNull,
            );
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            planner.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'held retry callback cannot submit another workspace pending save',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          await ctx.login();
          var loads = 0;
          final planner = ManualPlannerProvider(
            repositoryLoader: () async {
              loads++;
              return ctx.repository;
            },
            lifecycle: ctx.lifecycle,
            newId: editor.nextId,
          );
          try {
            planner.openNew(records.doc());
            ctx.server.offline = true;
            expect(await planner.confirmSave(planner.previewSave()), isFalse);
            await pumpBudgetEditor(tester, planner);
            final oldRetry = tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Thử lại lần lưu trước'),
                )
                .onPressed!;
            planner.openNew(records.doc());
            expect(await planner.confirmSave(planner.previewSave()), isFalse);
            final before = loads;
            oldRetry();
            await tester.pumpAndSettle();
            expect(loads, before);
            expect(ctx.server.creates, 0);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            planner.dispose();
          }
        }),
      );
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 800),
    const Size(640, 360),
  ]) {
    testWidgets(
      'expense and frozen preview are reachable with keyboard at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final scale = size.width == 360 ? 2.0 : 1.5;
        EditableCommand? result;
        await pumpForm(
          tester,
          ManualExpenseKind.actual,
          (v) => result = v,
          textScale: scale,
        );
        final inset = size.height > 500 ? 320.0 : 144.0;
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('expense.amount')),
          '123',
        );
        await tester.enterText(
          find.byKey(const ValueKey('expense.paidOn')),
          '2026-10-15',
        );
        await tapText(tester, 'Áp dụng thay đổi');
        expect((result as PutActualCommand).actual.amountVnd, 123);
        final planner = editor.guest(
          document: EditableTripMutator.apply(records.doc(), [result!]),
        );
        addTearDown(planner.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: ManualSavePreview(
              planner: planner,
              preview: planner.previewSave(),
              onResolveIssue: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Lưu bản nháp trên máy'),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('manual.preview')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('Lưu bản nháp trên máy'));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Lưu bản nháp trên máy',
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(
          tester.getRect(button).bottom,
          lessThanOrEqualTo(size.height - inset),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
