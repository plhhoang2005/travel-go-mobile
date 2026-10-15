import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trips/providers/editable_drafts_provider.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'editable_trip_repository_test.dart' as repository;
import 'editable_local_store_test.dart' as records;
import 'guest_draft_planner_test.dart' show DraftApi, planner;
import 'manual_budget_ui_test.dart' show tapText, finishSave;

ManualPlannerResources resources(repository.Context ctx) =>
    ManualPlannerResources(
      planner: ManualPlannerProvider(
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
      ),
      drafts: EditableDraftsProvider(
        storeLoader: () async => ctx.disk.store,
        repositoryLoader: () async => ctx.repository,
        lifecycle: ctx.lifecycle,
        deviceScope: 'default',
      ),
      repository: ctx.repository,
    );

Future<void> pumpFlow(
  WidgetTester tester,
  TripProvider trip,
  DiscoveryProvider discovery,
  ManualPlannerRuntime runtime, {
  Widget home = const HomePlannerScreen(),
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: trip),
        ChangeNotifierProvider.value(value: discovery),
        Provider<ManualPlannerRuntime>.value(value: runtime),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void selectHue(TripProvider trip) {
  expect(
    trip.prepareDestinationWorkspace(
      destinationId: 'hue',
      destinationName: 'Huế',
      expectedWorkspaceGeneration: trip.workspaceGeneration,
      replaceDirty: true,
    ),
    isTrue,
  );
}

void main() {
  testWidgets(
    'Discovery Hue manual save reopens exact V2 without engine or AI',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final api = DraftApi();
          final counted = planner(ctx.disk, api);
          final discovery = DiscoveryProvider(
            repository: CatalogueRepository(
              loader: () async => jsonEncode(catalogueData()),
            ),
          );
          final runtime = ManualPlannerRuntime(
            factory: () async => resources(ctx),
          );
          try {
            await pumpFlow(
              tester,
              counted,
              discovery,
              runtime,
              home: const ExploreScreen(),
            );
            await tester.enterText(
              find.byKey(const ValueKey('destination-search')),
              'hue',
            );
            await tester.pumpAndSettle();
            await tapText(tester, 'Huế');
            await tapText(tester, 'Chuẩn bị chuyến đi');
            await tapText(tester, 'Tự lập lịch trình');
            final bindings = await runtime.getResources();
            await tester.pumpAndSettle();
            expect(find.byType(ManualPlannerScreen), findsOneWidget);
            expect(bindings.planner.document!.input.destinationId, 'hue');
            expect(bindings.planner.document!.input.startDate, isNull);
            expect(bindings.planner.document!.items, isEmpty);
            await tapText(tester, 'Thêm hoạt động', scroll: 'manual.timeline');
            await tester.enterText(
              find.byKey(const ValueKey('activity.title')),
              'Tự chọn ở Huế',
            );
            await tapText(tester, 'Áp dụng thay đổi');
            await tapText(tester, 'Xem lại trước khi lưu');
            await tapText(
              tester,
              'Lưu bản nháp trên máy',
              scroll: 'manual.preview',
            );
            await finishSave(bindings.planner);
            await tester.pumpAndSettle();
            final id = bindings.planner.draftId!;
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            await ctx.disk.store.close();
            await ctx.disk.store.open();
            final saved = await ctx.disk.store.readEditableDraft(
              deviceScope: 'default',
              draftId: id,
            );
            expect(saved!.document.input.destinationId, 'hue');
            expect(saved.document.input.startDate, isNull);
            expect(saved.document.items.single.title, 'Tự chọn ở Huế');
            expect(api.plans, 0);
            expect(api.health, 0);
            expect(ctx.server.creates, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            discovery.dispose();
            counted.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'catalogue failure offers retry and keeps manual workspace unopened',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final api = DraftApi();
          final trip = planner(ctx.disk, api);
          var calls = 0, opens = 0;
          final discovery = DiscoveryProvider(
            repository: CatalogueRepository(
              loader: () async {
                if (++calls == 1) throw StateError('catalogue offline');
                return jsonEncode(catalogueData());
              },
            ),
          );
          final runtime = ManualPlannerRuntime(
            factory: () async {
              opens++;
              return resources(ctx);
            },
          );
          try {
            selectHue(trip);
            await pumpFlow(tester, trip, discovery, runtime);
            await tapText(tester, 'Tự lập lịch trình');
            expect(
              find.text('Không tải được danh mục địa điểm. Hãy thử lại.'),
              findsOneWidget,
            );
            expect(opens, 0);
            await tapText(tester, 'Thử lại');
            await runtime.getResources();
            await tester.pumpAndSettle();
            expect(find.byType(ManualPlannerScreen), findsOneWidget);
            expect(opens, 1);
            expect(calls, 2);
            expect(api.plans, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            discovery.dispose();
            trip.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'workspace change during runtime load rejects late editor publication',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final trip = planner(ctx.disk, DraftApi());
          selectHue(trip);
          final discovery = DiscoveryProvider(
            repository: CatalogueRepository(
              loader: () async => jsonEncode(catalogueData()),
            ),
          );
          final ready = Completer<ManualPlannerResources>();
          final runtime = ManualPlannerRuntime(factory: () => ready.future);
          final bindings = resources(ctx);
          try {
            await pumpFlow(tester, trip, discovery, runtime);
            await tester.ensureVisible(find.text('Tự lập lịch trình'));
            await tester.tap(find.text('Tự lập lịch trình'));
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 20));
            trip.setPlannerContext(
              isGuest: false,
              isDemo: false,
              ownerId: records.ownerA,
              authEpoch: 1,
            );
            ready.complete(bindings);
            await runtime.getResources();
            await tester.pumpAndSettle();
            expect(find.byType(ManualPlannerScreen), findsNothing);
            expect(bindings.planner.document, isNull);
            expect(
              find.text(
                'Thông tin hoặc phiên đã thay đổi. Quay lại và mở lại lịch trình.',
              ),
              findsOneWidget,
            );
          } finally {
            if (!ready.isCompleted) ready.complete(bindings);
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            discovery.dispose();
            trip.dispose();
          }
        }),
      );
    },
  );

  testWidgets('Back while catalogue is loading never opens a workspace later', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.run((ctx) async {
        final trip = planner(ctx.disk, DraftApi());
        selectHue(trip);
        final loaded = Completer<String>();
        var opens = 0;
        final discovery = DiscoveryProvider(
          repository: CatalogueRepository(loader: () => loaded.future),
        );
        final runtime = ManualPlannerRuntime(
          factory: () async {
            opens++;
            return resources(ctx);
          },
        );
        try {
          await pumpFlow(tester, trip, discovery, runtime);
          await tester.ensureVisible(find.text('Tự lập lịch trình'));
          await tester.tap(find.text('Tự lập lịch trình'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(BackButton), findsWidgets);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          loaded.complete(jsonEncode(catalogueData()));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pumpAndSettle();
          expect(find.byType(ManualPlannerScreen), findsNothing);
          expect(opens, 0);
        } finally {
          if (!loaded.isCompleted) loaded.complete(jsonEncode(catalogueData()));
          await tester.pumpWidget(const SizedBox.shrink());
          await runtime.close();
          discovery.dispose();
          trip.dispose();
        }
      }),
    );
  });

  testWidgets(
    'account entry stays in RAM and lifecycle revocation hides editor',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          await ctx.login();
          final api = DraftApi();
          final trip = planner(ctx.disk, api);
          trip.setPlannerContext(
            isGuest: false,
            isDemo: false,
            ownerId: records.ownerA,
            authEpoch: 1,
          );
          selectHue(trip);
          final discovery = DiscoveryProvider(
            repository: CatalogueRepository(
              loader: () async => jsonEncode(catalogueData()),
            ),
          );
          final runtime = ManualPlannerRuntime(
            factory: () async => resources(ctx),
          );
          try {
            await pumpFlow(tester, trip, discovery, runtime);
            await tapText(tester, 'Tự lập lịch trình');
            final bindings = await runtime.getResources();
            await tester.pumpAndSettle();
            expect(bindings.planner.currentOwnerId, records.ownerA);
            expect(
              await ctx.disk.store.rawDb.query('guest_editable_drafts'),
              isEmpty,
            );
            expect(ctx.server.creates, 0);
            expect(api.plans, 0);
            expect(api.health, 0);
            ctx.lifecycle.invalidateAccountContext();
            await tester.pumpAndSettle();
            expect(bindings.planner.document, isNull);
            expect(
              find.text('Phiên chỉnh sửa không còn khả dụng.'),
              findsOneWidget,
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            discovery.dispose();
            trip.dispose();
          }
        }),
      );
    },
  );

  testWidgets(
    'manual runtime retries failed opening and shares one resources bundle',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          var opens = 0;
          final runtime = ManualPlannerRuntime(
            factory: () async {
              if (++opens == 1) throw StateError('storage unavailable');
              return resources(ctx);
            },
          );
          try {
            await expectLater(runtime.getResources(), throwsStateError);
            final pair = await Future.wait([
              runtime.getResources(),
              runtime.getResources(),
            ]);
            expect(identical(pair.first, pair.last), isTrue);
            expect(opens, 2);
          } finally {
            await runtime.close();
          }
          await expectLater(runtime.getResources(), throwsStateError);
        }),
      );
    },
  );

  testWidgets(
    'cancel replacing dirty manual workspace preserves its exact bytes',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final trip = planner(ctx.disk, DraftApi());
          selectHue(trip);
          final discovery = DiscoveryProvider(
            repository: CatalogueRepository(
              loader: () async => jsonEncode(catalogueData()),
            ),
          );
          final existing = resources(ctx);
          existing.planner.openNew(records.doc());
          final before = EditableTripCodec.encode(existing.planner.document!);
          final runtime = ManualPlannerRuntime(factory: () async => existing);
          try {
            await pumpFlow(tester, trip, discovery, runtime);
            await tapText(tester, 'Tự lập lịch trình');
            expect(find.text('Thay bản chỉnh sửa đang mở?'), findsOneWidget);
            await tapText(tester, 'Giữ bản đang sửa');
            expect(
              EditableTripCodec.encode(existing.planner.document!),
              before,
            );
            expect(find.byType(ManualPlannerScreen), findsNothing);
            expect(ctx.server.creates, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            discovery.dispose();
            trip.dispose();
          }
        }),
      );
    },
  );
  testWidgets(
    'closing manual runtime disposes a late bundle without publishing it',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final ready = Completer<ManualPlannerResources>();
          final runtime = ManualPlannerRuntime(factory: () => ready.future);
          final opening = runtime.getResources();
          final rejected = expectLater(opening, throwsStateError);
          final closing = runtime.close();
          final late = resources(ctx);
          ready.complete(late);
          await rejected;
          await closing;
          expect(() => late.planner.openNew(records.doc()), throwsStateError);
          await expectLater(runtime.getResources(), throwsStateError);
        }),
      );
    },
  );
}
