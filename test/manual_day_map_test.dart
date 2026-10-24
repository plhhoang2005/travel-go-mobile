import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/manual_day_map_screen.dart';
import 'package:travelgo_mobile/features/map/services/manual_place_locations.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';

import 'manual_planner_screen_test.dart' as editor;
import 'editable_trip_repository_test.dart' as repository;

class _FailedTile extends Fake implements TileImage {}

EditableTripDocumentV2 mapDocument({bool onlyUnknown = false}) {
  final base = editor.documentWithLinkedActivity();
  final item = base.items.single;
  return base.copyWith(
    items: [
      TripItem.fromJson({
        ...item.toJson(),
        'title': 'Tham quan Kinh thành',
        'placeId': onlyUnknown ? null : 'hue/citadel',
      }),
      TripItem.fromJson({
        ...item.toJson(),
        'id': editor.nextId(),
        'title': 'Ăn trưa tự chọn',
        'position': 1,
        'placeId': null,
      }),
      TripItem.fromJson({
        ...item.toJson(),
        'id': editor.nextId(),
        'dayId': base.days.first.id,
        'title': 'Hồ ở ngày khác',
        'placeId': 'ha-noi/hoan-kiem',
      }),
    ],
  );
}

Future<void> pumpMap(
  WidgetTester tester,
  EditableTripDocumentV2 document, {
  bool network = false,
  String? dayId,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ManualDayMapScreen(
                  document: document,
                  dayId: dayId ?? document.days.last.id,
                  enableNetworkTiles: network,
                ),
              ),
            ),
            child: const Text('Mở bản đồ'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở bản đồ'));
  await tester.pumpAndSettle();
}

void main() {
  test('reference positions carry exact place IDs, dated sources and no default coordinates', () {
    final lake = ManualPlaceLocations.forPlace('ha-noi/hoan-kiem')!;
    expect(lake.position.latitude, closeTo(21.028888888889, .000001));
    expect(lake.sourceUrl, contains('Q1151254'));
    expect(lake.checkedAt, '2026-10-17');
    expect(
      ManualPlaceLocations.forPlace('hue/citadel')!.note,
      contains('bên trong Kinh thành'),
    );
    expect(ManualPlaceLocations.forPlace('hue/unknown'), isNull);
    expect(ManualPlaceLocations.forPlace(null), isNull);
  });

  testWidgets(
    'day map shows only selected-day ordered stops and preserves document',
    (tester) async {
      final document = mapDocument();
      final before = EditableTripCodec.encode(document);
      await pumpMap(tester, document);
      expect(find.text('1/2 hoạt động có vị trí tham khảo'), findsOneWidget);
      expect(find.text('Hồ ở ngày khác'), findsNothing);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(
        find.bySemanticsLabel('Vị trí 1: Tham quan Kinh thành'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Vị trí 1: Tham quan Kinh thành'));
      await tester.pumpAndSettle();
      expect(EditableTripCodec.encode(document), before);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Mở bản đồ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown coordinates never become city-center markers at large text',
    (tester) async {
      await pumpMap(tester, mapDocument(onlyUnknown: true), scale: 2);
      expect(find.text('0/2 hoạt động có vị trí tham khảo'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Ăn trưa tự chọn'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('manual.dayMap.scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Ăn trưa tự chọn'), findsOneWidget);
      expect(find.text('Hồ ở ngày khác'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing day never substitutes the first day', (tester) async {
    await pumpMap(tester, mapDocument(), dayId: 'missing');
    expect(find.text('Ngày này không còn trong lịch trình.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Hồ ở ngày khác'), findsNothing);
  });

  testWidgets('tile failure preserves the day list and back navigation', (
    tester,
  ) async {
    await pumpMap(tester, mapDocument(), network: true);
    tester.widget<TileLayer>(find.byType(TileLayer)).errorTileCallback!(
      _FailedTile(),
      StateError('offline'),
      StackTrace.current,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tải được nền bản đồ.'), findsOneWidget);
    // Drag the scroll-view gutter. Dragging its center correctly pans the map.
    await tester.dragFrom(const Offset(8, 700), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ăn trưa tự chọn'));
    expect(find.text('Ăn trưa tự chọn'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mở bản đồ'), findsOneWidget);
  });

  testWidgets(
    'editor map back keeps selected day, dirty state and unavailable AI is honest',
    (tester) async {
      final document = mapDocument();
      final planner = editor.guest(document: document);
      addTearDown(planner.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ManualPlannerScreen(
            planner: planner,
            destinations: editor.destinations(),
            enableMapNetworkTiles: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ngày sau'));
      await tester.pumpAndSettle();
      final before = EditableTripCodec.encode(planner.document!);
      final dirty = planner.dirty;
      await tester.tap(find.text('Bản đồ ngày này'));
      await tester.pumpAndSettle();
      expect(find.text('Bản đồ ngày 3'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ngày 3 · 17/10/2026'), findsOneWidget);
      await tester.tap(find.text('Trợ giúp AI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('AI chưa khả dụng.'), findsOneWidget);
      expect(EditableTripCodec.encode(planner.document!), before);
      expect(planner.dirty, dirty);
    },
  );

  testWidgets('Account invalidation hides an open private day map', (
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
        try {
          planner.openNew(mapDocument());
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: ManualPlannerScreen(
                planner: planner,
                destinations: editor.destinations(),
                enableMapNetworkTiles: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Bản đồ ngày này'));
          await tester.pumpAndSettle();
          expect(find.byType(ManualDayMapScreen), findsOneWidget);
          ctx.lifecycle.invalidateAccountContext();
          await tester.pumpAndSettle();
          expect(find.byType(ManualDayMapScreen), findsNothing);
          expect(find.byType(FlutterMap), findsNothing);
          expect(find.text('Hồ ở ngày khác'), findsNothing);
          expect(planner.document, isNull);
          expect(
            ctx.server.creates + ctx.server.updates + ctx.server.deletes,
            0,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        } finally {
          planner.dispose();
        }
      }),
    );
  });
}
