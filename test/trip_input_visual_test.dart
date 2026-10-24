import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';

import 'guest_draft_planner_test.dart' show DraftApi;

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/manual_trip_input_form.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/trip_live_preview.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';

import 'editable_local_store_test.dart' as records;
import 'manual_planner_screen_test.dart' as editor;

Future<void> showInputs(
  WidgetTester tester,
  EditableTripDocumentV2 document, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ManualTripInputForm(
        initialDocument: document,
        destinations: editor.destinations(),
        newId: editor.nextId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

TripLivePreview preview(WidgetTester tester) =>
    tester.widget<TripLivePreview>(find.byType(TripLivePreview));

void main() {
  testWidgets(
    'planner landing separates manual entry from automatic suggestions at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DraftApi();
      final trip = TripProvider(apiService: api);
      addTearDown(trip.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: trip,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const HomePlannerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tự lập lịch trình'), findsOneWidget);
      expect(find.text('Gợi ý điểm đến tự động'), findsOneWidget);
      expect(find.textContaining('MCDA'), findsNothing);
      expect(find.textContaining('Spring Boot'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('4 ngày · 8 triệu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 ngày · 8 triệu'));
      await tester.pumpAndSettle();
      expect(trip.currentRequest.numDays, 4);
      expect(trip.currentRequest.budgetVnd, 8000000);
      await tester.scrollUntilVisible(
        find.text('Xem gợi ý chuyến đi'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(api.plans, 0);
      expect(trip.currentMetadata.destinationId, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group navigation preserves unsaved values and budget exact entry',
    (tester) async {
      final document = records.doc();
      final before = EditableTripCodec.encode(document);
      await showInputs(tester, document);
      await tester.enterText(
        find.byKey(const ValueKey('trip.title')),
        'Huế cùng bạn',
      );
      await tester.tap(find.byKey(const ValueKey('trip.section.2')));
      await tester.pumpAndSettle();
      await tapText(tester, '5 triệu');
      expect(preview(tester).input.totalBudgetVnd, 5000000);
      await tester.enterText(
        find.byKey(const ValueKey('trip.budget')),
        '5123456',
      );
      await tester.pumpAndSettle();
      expect(preview(tester).input.totalBudgetVnd, 5123456);
      await tester.tap(find.byKey(const ValueKey('trip.section.0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('trip.title')))
            .controller!
            .text,
        'Huế cùng bạn',
      );
      await tapText(tester, 'Xem thay đổi');
      expect(find.text('Xem thay đổi thông tin'), findsOneWidget);
      await tapText(tester, 'Quay lại thông tin');
      expect(preview(tester).input.totalBudgetVnd, 5123456);
      expect(EditableTripCodec.encode(document), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar updates inclusive days and preview without mutating document',
    (tester) async {
      final document = records.doc();
      final before = EditableTripCodec.encode(document);
      await showInputs(tester, document);
      await tester.tap(find.byKey(const ValueKey('trip.section.1')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Chọn ngày trên lịch');
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 10, 20));
      await tester.pumpAndSettle();
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2026, 10, 22));
      await tester.pumpAndSettle();
      expect(preview(tester).dayCount, 3);
      expect(preview(tester).input.startDate, '2026-10-20');
      expect(preview(tester).input.endDate, '2026-10-22');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('trip.days')))
            .enabled,
        isFalse,
      );
      expect(EditableTripCodec.encode(document), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom interests survive chip edits and numeric bounds remain exact',
    (tester) async {
      final base = records.doc();
      final document = base.copyWith(
        input: TripInput.fromJson({
          ...base.input.toJson(),
          'interests': ['kiến trúc cổ', 'ẩm thực'],
        }),
      );
      await showInputs(tester, document);
      await tester.tap(find.byKey(const ValueKey('trip.section.2')));
      await tester.pumpAndSettle();
      await tapText(tester, 'biển');
      expect(preview(tester).input.interests, [
        'kiến trúc cổ',
        'ẩm thực',
        'biển',
      ]);
      await tester.enterText(
        find.byKey(const ValueKey('trip.budget')),
        '${EditableTripCodec.maxMoney}',
      );
      await tester.pumpAndSettle();
      expect(preview(tester).input.totalBudgetVnd, EditableTripCodec.maxMoney);
      await tester.enterText(
        find.byKey(const ValueKey('trip.budget')),
        '${EditableTripCodec.maxMoney + 1}',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('thông tin hợp lệ gần nhất'), findsOneWidget);
      expect(preview(tester).input.totalBudgetVnd, EditableTripCodec.maxMoney);
      await tester.enterText(find.byKey(const ValueKey('trip.budget')), '0');
      await tester.enterText(
        find.byKey(const ValueKey('trip.travelers')),
        '${EditableTripCodec.maxCount}',
      );
      await tester.pumpAndSettle();
      expect(preview(tester).input.totalBudgetVnd, 0);
      expect(preview(tester).input.travelerCount, EditableTripCodec.maxCount);
      await tester.enterText(find.byKey(const ValueKey('trip.travelers')), '0');
      await tapText(tester, 'Xem thay đổi');
      expect(
        find.text('Nhập số người nguyên, từ 1 đến 2147483647.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large text and keyboard keep preview and form action accessible',
    (tester) async {
      await showInputs(tester, records.doc(), scale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('trip.budget')));
      await tester.enterText(
        find.byKey(const ValueKey('trip.budget')),
        '3000001',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip.livePreview')), findsOneWidget);
      expect(find.textContaining('3.000.001'), findsOneWidget);
      await tapText(tester, 'Xem thay đổi');
      expect(find.text('Xem thay đổi thông tin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
