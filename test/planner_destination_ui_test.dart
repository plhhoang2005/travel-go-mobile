import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'discovery_screen_test.dart' show pumpDiscovery;
import 'discovery_workspace_test.dart' show selectHue;
import 'guest_draft_planner_test.dart' show DraftApi;
import 'guest_draft_planner_test.dart' show planner;
import 'local_trip_store_test.dart' as fixtures;

void main() {
  sqfliteFfiInit();
  testWidgets(
    'completed save while confirmation is open invalidates the old choice',
    (tester) async {
      await tester.runAsync(
        () => fixtures.runWithStore((ctx) async {
          final c = CatalogueParser().parse(jsonEncode(catalogueData()));
          final d = DiscoveryProvider();
          final p = planner(ctx, DraftApi());
          p.updateRequest(p.currentRequest.copyWith(numDays: 6));
          await pumpDiscovery(
            tester,
            d,
            p,
            screen: DestinationDetailScreen(
              catalogue: c,
              destination: c.destinations.first,
            ),
          );
          await tester.tap(find.text('Chuẩn bị chuyến đi'));
          await tester.pumpAndSettle();
          final saved = await p.saveGuestDraft(title: 'Saved during dialog');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Tạo mới'));
          await tester.pumpAndSettle();
          expect(p.hasSelectedDestination, false);
          expect(p.activeDraftId, saved!.draftId);
          expect(p.currentMetadata.title, 'Saved during dialog');
          expect(p.isDraftDirty, false);
          expect(find.byType(HomePlannerScreen), findsNothing);
          await tester.pumpWidget(const SizedBox());
          d.dispose();
          p.dispose();
        }),
      );
    },
  );
  testWidgets(
    'Auth epoch changes during confirmation do not apply an old selection',
    (tester) async {
      final c = CatalogueParser().parse(jsonEncode(catalogueData()));
      final d = DiscoveryProvider(), p = TripProvider(apiService: DraftApi());
      addTearDown(d.dispose);
      addTearDown(p.dispose);
      p.updateRequest(p.currentRequest.copyWith(numDays: 6));
      await pumpDiscovery(
        tester,
        d,
        p,
        screen: DestinationDetailScreen(
          catalogue: c,
          destination: c.destinations.first,
        ),
      );
      await tester.tap(find.text('Chuẩn bị chuyến đi'));
      await tester.pumpAndSettle();
      p.setPlannerContext(
        isGuest: true,
        isDemo: false,
        ownerId: null,
        authEpoch: 1,
      );
      await tester.pump();
      await tester.tap(find.text('Tạo mới'));
      await tester.pumpAndSettle();
      expect(p.hasSelectedDestination, false);
      expect(p.currentRequest.numDays, 6);
      expect(find.byType(HomePlannerScreen), findsNothing);
    },
  );
  testWidgets(
    'dirty cancel/back/stale confirmation retain input and do not navigate',
    (tester) async {
      final c = CatalogueParser().parse(jsonEncode(catalogueData()));
      final d = DiscoveryProvider();
      final api = DraftApi();
      final p = TripProvider(apiService: api);
      addTearDown(d.dispose);
      addTearDown(p.dispose);
      p.updateRequest(p.currentRequest.copyWith(numDays: 6));
      await pumpDiscovery(
        tester,
        d,
        p,
        screen: DestinationDetailScreen(
          catalogue: c,
          destination: c.destinations.first,
        ),
      );
      await tester.tap(find.text('Chuẩn bị chuyến đi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(p.currentRequest.numDays, 6);
      expect(p.hasSelectedDestination, false);
      await tester.tap(find.text('Chuẩn bị chuyến đi'));
      await tester.pumpAndSettle();
      p.updateRequest(p.currentRequest.copyWith(numDays: 5));
      await tester.pump();
      await tester.tap(find.text('Tạo mới'));
      await tester.pumpAndSettle();
      expect(p.currentRequest.numDays, 5);
      expect(p.hasSelectedDestination, false);
      expect(find.byType(HomePlannerScreen), findsNothing);
      expect(api.plans, 0);
    },
  );
  for (final width in [360.0, 390.0]) {
    testWidgets(
      'account selected planner blocks submit, confirms auto mode at $width',
      (tester) async {
        final d = DiscoveryProvider(), api = DraftApi();
        final p = TripProvider(apiService: api);
        addTearDown(d.dispose);
        addTearDown(p.dispose);
        p.setPlannerContext(
          isGuest: false,
          isDemo: false,
          ownerId: 'A',
          authEpoch: 1,
        );
        expect(selectHue(p), true);
        await pumpDiscovery(
          tester,
          d,
          p,
          screen: const HomePlannerScreen(),
          width: width,
          scale: 1.5,
        );
        expect(find.text('Huế'), findsOneWidget);
        expect(find.text('Thông tin này chưa được lưu'), findsOneWidget);
        expect(api.health, 0);
        expect(api.plans, 0);
        await tester.tap(find.text('Để app gợi ý điểm đến'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tạo mới'));
        await tester.pumpAndSettle();
        expect(p.hasSelectedDestination, false);
        expect(p.activeDraftId, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
