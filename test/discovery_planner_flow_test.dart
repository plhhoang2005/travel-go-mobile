import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/auth/presentation/screens/splash_screen.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'discovery_screen_test.dart' show pumpDiscovery;
import 'guest_draft_planner_test.dart' show DraftApi, planner;
import 'local_trip_store_test.dart' as fixtures;

void main() {
  sqfliteFfiInit();
  testWidgets(
    'production registration loads bundled catalogue without local DB',
    (tester) async {
      var opens = 0;
      final runtime = LocalTripStoreRuntime(
        factory: () {
          opens++;
          throw StateError('must stay lazy');
        },
      );
      await tester.pumpWidget(TravelGoApp(localStoreRuntime: runtime));
      final context = tester.element(find.byType(SplashScreen));
      final auth = context.read<AuthProvider>();
      auth.continueAsGuest();
      await tester.pump();
      final discovery = context.read<DiscoveryProvider>();
      await tester.runAsync(discovery.load);
      await tester.pump();
      expect(discovery.catalogue!.destinations.length, 12);
      expect(opens, 0);
      expect(context.read<PlannerInputProvider>().canReplaceWorkspace, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      await runtime.close();
    },
  );
  testWidgets(
    'offline Discovery to planner, UI save, disk reopen keeps selected destination',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          final api = DraftApi();
          final trip = planner(ctx, api);
          final discovery = DiscoveryProvider(
            repository: CatalogueRepository(
              loader: () async => jsonEncode(catalogueData()),
            ),
          );
          await pumpDiscovery(tester, discovery, trip);
          await tester.enterText(
            find.byKey(const ValueKey('destination-search')),
            'hue',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Huế'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Chuẩn bị chuyến đi'));
          await tester.pumpAndSettle();
          expect(find.byType(HomePlannerScreen), findsOneWidget);
          expect(trip.currentMetadata.destinationId, 'hue');
          expect(trip.activeDraftId, isNull);
          // In C1: Guest draft persistence UI button is removed from HomePlannerScreen
          expect(find.text('Lưu bản nháp trên máy'), findsNothing);
          expect(
            find.widgetWithText(ElevatedButton, 'Lập lịch trình cho Huế'),
            findsOneWidget,
          );
          // Underlying draft persistence and disk reload keep destination
          final savedRow = await trip.saveGuestDraft(title: 'Bản nháp Huế');
          expect(savedRow, isNotNull);
          final rows = await ctx.store.listGuestDrafts();
          expect(rows, hasLength(1));
          expect(trip.isDraftDirty, false);
          await tester.pumpWidget(const SizedBox());
          discovery.dispose();
          trip.dispose();
          await ctx.store.close();
          await ctx.store.open();
          final reopened = planner(ctx, api);
          expect(
            await reopened.openGuestDraft(
              draftId: rows.single.draftId,
              revision: rows.single.currentRevision,
              expectedWorkspaceGeneration: reopened.workspaceGeneration,
            ),
            true,
          );
          expect(reopened.currentMetadata.destinationName, 'Huế');
          expect(await reopened.submitPlan(), true);
          expect(api.plans, 1);
          reopened.dispose();
        }),
      );
    },
  );
}
