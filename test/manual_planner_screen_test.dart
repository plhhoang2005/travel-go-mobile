import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart'
    as catalogue;
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/manual_itinerary_timeline.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;

int _id = 1000;
String nextId() =>
    '00000000-0000-4000-8000-${(_id++).toString().padLeft(12, '0')}';
List<catalogue.DestinationReference> destinations() => CatalogueParser()
    .parse(File(CatalogueRepository.assetPath).readAsStringSync())
    .destinations;

EditableTripDocumentV2 documentWithLinkedActivity() {
  final base = records.doc();
  const day2 = '00000000-0000-4000-8000-000000000101';
  const day3 = '00000000-0000-4000-8000-000000000102';
  const itemId = '00000000-0000-4000-8000-000000000110';
  return base.copyWith(
    input: TripInput.fromJson({
      ...base.input.toJson(),
      'endDate': '2026-10-17',
    }),
    days: [
      base.days.single,
      TripDay(id: day2, ordinal: 2, date: '2026-10-16', notes: ''),
      TripDay(id: day3, ordinal: 3, date: '2026-10-17', notes: ''),
    ],
    items: [
      TripItem(
        id: itemId,
        dayId: day3,
        position: 0,
        title: 'Hoạt động C',
        placeId: null,
        startMinute: 540,
        endMinute: 600,
        notes: '',
        provenance: FieldProvenance(
          quality: 'user_provided',
          sourceRefs: [],
          observedAt: null,
        ),
      ),
    ],
    estimates: [
      EstimatedExpense.fromJson({
        ...base.estimates.first.toJson(),
        'itemId': itemId,
      }),
      ...base.estimates.skip(1),
    ],
    actualExpenses: [
      ActualExpense.fromJson({
        ...base.actualExpenses.single.toJson(),
        'itemId': itemId,
        'sourceItemSnapshot': {
          'title': 'Hoạt động C',
          'dayId': day3,
          'date': '2026-10-17',
        },
      }),
    ],
  );
}

ManualPlannerProvider guest({EditableTripDocumentV2? document}) {
  final planner = ManualPlannerProvider(
    repositoryLoader: () async => throw StateError('Unexpected persistence'),
    newId: nextId,
  );
  planner.openNew(document ?? records.doc());
  return planner;
}

Future<void> pumpEditor(
  WidgetTester tester, {
  required ManualPlannerProvider planner,
  required List<catalogue.DestinationReference> destinations,
  double width = 360,
  double height = 800,
  double textScale = 1.5,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ManualPlannerScreen(
        planner: planner,
        destinations: destinations,
        newId: nextId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  // Settle focus/caret scrolling before positioning the action for a tap.
  await tester.pumpAndSettle();
  final matches = find.text(text);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('manual.timeline')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(matches.last);
  await tester.pumpAndSettle();
  await tester.tap(matches.last);
  await tester.pumpAndSettle();
}

Future<void> add(WidgetTester tester, String title) async {
  await press(tester, 'Thêm hoạt động');
  await tester.enterText(find.byKey(const ValueKey('activity.title')), title);
  await press(tester, 'Áp dụng thay đổi');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'empty day adds, edits and reorders with labelled buttons without engine calls',
    (tester) async {
      final planner = guest();
      addTearDown(planner.dispose);
      await pumpEditor(tester, planner: planner, destinations: destinations());
      expect(find.text('Ngày này chưa có hoạt động'), findsOneWidget);
      expect(find.text('Ngân sách'), findsNothing);
      await add(tester, 'Bảo tàng');
      await add(tester, 'Ăn trưa');
      expect(planner.document!.items.map((i) => i.title), [
        'Bảo tàng',
        'Ăn trưa',
      ]);
      final semantics = tester.ensureSemantics();
      try {
        final down = find.byTooltip('Xuống: Bảo tàng');
        await tester.scrollUntilVisible(
          down,
          -400,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('manual.timeline')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.bySemanticsLabel('Xuống: Bảo tàng'), findsOneWidget);
        await tester.tap(down);
        await tester.pumpAndSettle();
        expect(planner.document!.items.map((i) => i.title), [
          'Ăn trưa',
          'Bảo tàng',
        ]);
        await tester.ensureVisible(find.byTooltip('Sửa: Bảo tàng'));
        await tester.tap(find.byTooltip('Sửa: Bảo tàng'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('activity.title')),
          'Bảo tàng mới',
        );
        await press(tester, 'Áp dụng thay đổi');
        expect(planner.document!.items.last.title, 'Bảo tàng mới');
        expect(find.text('Chưa có giờ'), findsWidgets);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'invalid times and Unicode title stay in form; cancel never mutates',
    (tester) async {
      final planner = guest();
      addTearDown(planner.dispose);
      await pumpEditor(tester, planner: planner, destinations: destinations());
      final before = EditableTripCodec.encode(planner.document!);
      await press(tester, 'Thêm hoạt động');
      await press(tester, 'Áp dụng thay đổi');
      expect(find.text('Nhập tên hoạt động.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('activity.title')),
        'Đi dạo',
      );
      await tester.enterText(
        find.byKey(const ValueKey('activity.start')),
        '10:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('activity.end')),
        '09:00',
      );
      await press(tester, 'Áp dụng thay đổi');
      expect(find.text('Giờ kết thúc phải sau giờ bắt đầu.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('activity.title')),
        'a\u0301' * 101,
      );
      await press(tester, 'Áp dụng thay đổi');
      expect(find.text('Tối đa 200 ký tự Unicode.'), findsOneWidget);
      await press(tester, 'Hủy');
      await press(tester, 'Bỏ thay đổi');
      expect(EditableTripCodec.encode(planner.document!), before);
    },
  );

  for (final action in ['delete', 'move']) {
    testWidgets(
      'resize $action explicitly resolves affected activity and preserves actual',
      (tester) async {
        final original = documentWithLinkedActivity();
        final planner = guest(document: original);
        addTearDown(planner.dispose);
        await pumpEditor(
          tester,
          planner: planner,
          destinations: destinations(),
          textScale: 1,
        );
        await press(tester, 'Sửa thông tin');
        await tester.enterText(
          find.byKey(const ValueKey('trip.end')),
          '2026-10-16',
        );
        await press(tester, 'Xem thay đổi');
        expect(planner.document!.days, hasLength(3));
        expect(find.text('Còn 1 hoạt động cần xử lý'), findsOneWidget);
        final apply = find.widgetWithText(FilledButton, 'Áp dụng thay đổi');
        expect(tester.widget<FilledButton>(apply).onPressed, isNull);
        final choice = find.byKey(const ValueKey('resize.choice'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        await press(
          tester,
          action == 'delete' ? 'Xóa hoạt động này' : 'Chuyển đến ngày 2',
        );
        if (action == 'delete') await press(tester, 'Xác nhận xóa');
        await press(tester, 'Áp dụng thay đổi');
        expect(planner.document!.days, hasLength(2));
        final actual = planner.document!.actualExpenses.single;
        expect(actual.amountVnd, 250000);
        expect(actual.paidOn, original.actualExpenses.single.paidOn);
        expect(actual.category, original.actualExpenses.single.category);
        expect(
          actual.sourceItemSnapshot!.toJson(),
          original.actualExpenses.single.sourceItemSnapshot!.toJson(),
        );
        if (action == 'delete') {
          expect(planner.document!.items, isEmpty);
          expect(actual.itemId, isNull);
          expect(planner.document!.estimates.first.active, isFalse);
        } else {
          expect(
            planner.document!.items.single.dayId,
            planner.document!.days.last.id,
          );
          expect(planner.document!.items.single.startMinute, 540);
          expect(actual.itemId, original.items.single.id);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('resize cancel and invalid counts keep original digest', (
    tester,
  ) async {
    final planner = guest(document: documentWithLinkedActivity());
    addTearDown(planner.dispose);
    await pumpEditor(tester, planner: planner, destinations: destinations());
    final before = EditableTripCodec.encode(planner.document!);
    await press(tester, 'Sửa thông tin');
    await press(tester, 'Xóa khoảng ngày');
    await tester.enterText(find.byKey(const ValueKey('trip.days')), '367');
    await press(tester, 'Xem thay đổi');
    expect(find.text('Nhập số ngày từ 1 đến 366.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('trip.days')), '2');
    await press(tester, 'Xem thay đổi');
    await press(tester, 'Hủy');
    await press(tester, 'Bỏ thay đổi');
    expect(EditableTripCodec.encode(planner.document!), before);
  });

  testWidgets(
    'move, delete and day notes are explicit actions with stable identity',
    (tester) async {
      final original = documentWithLinkedActivity();
      final planner = guest(document: original);
      addTearDown(planner.dispose);
      await pumpEditor(
        tester,
        planner: planner,
        destinations: destinations(),
        textScale: 1,
      );
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();
      await press(tester, 'Sửa ghi chú ngày');
      await tester.enterText(
        find.byKey(const ValueKey('day.notes')),
        'Tập trung buổi sáng',
      );
      await press(tester, 'Áp dụng thay đổi');
      expect(planner.document!.days.last.notes, 'Tập trung buổi sáng');
      await press(tester, 'Thêm thao tác');
      await press(tester, 'Chuyển ngày');
      await press(tester, 'Ngày 1 · 15/10/2026');
      expect(planner.document!.items.single.id, original.items.single.id);
      expect(planner.document!.items.single.dayId, original.days.first.id);
      await tester.tap(find.byTooltip('Ngày trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ngày trước'));
      await tester.pumpAndSettle();
      await press(tester, 'Thêm thao tác');
      await press(tester, 'Xóa hoạt động');
      await press(tester, 'Xác nhận xóa');
      expect(planner.document!.actualExpenses.single.amountVnd, 250000);
      expect(planner.document!.actualExpenses.single.itemId, isNull);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 800),
    const Size(640, 360),
  ]) {
    testWidgets('large text and keyboard remain usable at $size', (
      tester,
    ) async {
      final planner = guest();
      addTearDown(planner.dispose);
      await pumpEditor(
        tester,
        planner: planner,
        destinations: destinations(),
        width: size.width,
        height: size.height,
        textScale: size.width == 360 ? 2 : 1.5,
      );
      await press(tester, 'Thêm hoạt động');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height > 500 ? 320 : 144,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('activity.title')),
        'T' * 200,
      );
      await press(tester, 'Áp dụng thay đổi');
      expect(planner.document!.items.single.title, 'T' * 200);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '366 days and 1000 activities navigate without adding beyond the limit',
    (tester) async {
      final base = records.doc();
      final days = List.generate(
        366,
        (i) => TripDay(id: nextId(), ordinal: i + 1, date: null, notes: ''),
      );
      final doc = base.copyWith(
        input: TripInput.fromJson({
          ...base.input.toJson(),
          'startDate': null,
          'endDate': null,
        }),
        days: days,
        items: List.generate(
          1000,
          (i) => TripItem(
            id: nextId(),
            dayId: days.last.id,
            position: i,
            title: 'Hoạt động $i',
            placeId: null,
            startMinute: null,
            endMinute: null,
            notes: '',
            provenance: FieldProvenance(
              quality: 'user_provided',
              sourceRefs: [],
              observedAt: null,
            ),
          ),
        ),
      );
      final planner = guest(document: doc);
      addTearDown(planner.dispose);
      await pumpEditor(
        tester,
        planner: planner,
        destinations: destinations(),
        textScale: 1,
      );
      await tester.tap(find.byTooltip('Chọn ngày'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ngày 366 · Chưa chọn ngày'),
        1200,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await press(tester, 'Ngày 366 · Chưa chọn ngày');
      expect(find.text('Hoạt động 0'), findsOneWidget);
      expect(find.text('Hoạt động 999'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Thêm hoạt động'),
        18000,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('manual.timeline')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final addButton = find.widgetWithText(OutlinedButton, 'Thêm hoạt động');
      expect(tester.widget<OutlinedButton>(addButton).onPressed, isNull);
      expect(planner.document!.items, hasLength(1000));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open activity menu disappears when the workspace is invalidated',
    (tester) async {
      final planner = guest(document: documentWithLinkedActivity());
      addTearDown(planner.dispose);
      await pumpEditor(
        tester,
        planner: planner,
        destinations: destinations(),
        textScale: 1,
      );
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();
      final oldEdit = tester
          .widget<ManualItineraryTimeline>(find.byType(ManualItineraryTimeline))
          .onEdit;
      final oldItem = planner.document!.items.single;
      await press(tester, 'Thêm thao tác');
      expect(find.text('Chuyển ngày'), findsOneWidget);
      planner.invalidate();
      await tester.pumpAndSettle();
      expect(find.text('Hoạt động C'), findsNothing);
      expect(find.text('Chuyển ngày'), findsNothing);
      planner.openNew(records.doc());
      oldEdit(oldItem);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity.title')), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale edits cannot apply and session changes remove an open account form',
    (tester) async {
      await tester.runAsync(() async {
        await repository.run((ctx) async {
          await ctx.login();
          final planner = ManualPlannerProvider(
            repositoryLoader: () async => ctx.repository,
            lifecycle: ctx.lifecycle,
            newId: nextId,
          );
          try {
            planner.openNew(records.doc());
            await pumpEditor(
              tester,
              planner: planner,
              destinations: destinations(),
            );
            await press(tester, 'Thêm hoạt động');
            await tester.enterText(
              find.byKey(const ValueKey('activity.title')),
              'Dữ liệu riêng A',
            );
            ctx.lifecycle.invalidateAccountContext();
            await tester.pumpAndSettle();
            expect(find.text('Dữ liệu riêng A'), findsNothing);
            expect(
              find.text('Phiên chỉnh sửa không còn khả dụng.'),
              findsWidgets,
            );
            expect(find.byKey(const ValueKey('activity.title')), findsNothing);
            expect(ctx.server.creates, 0);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          } finally {
            planner.dispose();
          }
        });
      });
    },
  );
}
