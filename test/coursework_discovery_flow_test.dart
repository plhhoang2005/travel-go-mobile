import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';

import 'public_catalogue_consumers_test.dart' show createSnapshot;

import 'package:travelgo_mobile/main.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';

import 'editable_trip_repository_test.dart' as repository;
import 'manual_discovery_flow_test.dart' as flow;
import 'guest_draft_planner_test.dart' show DraftApi, planner;
import 'manual_budget_ui_test.dart' show tapText;

class C6Public extends ChangeNotifier implements PublicCatalogueProvider {
  @override
  PublicCatalogueSnapshot snapshot;
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  C6Public(this.snapshot);
  void replace(PublicCatalogueSnapshot value) {
    snapshot = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PublicCatalogueSnapshot c6DiscoverySnapshot(
  int version, {
  bool hidden = false,
}) => createSnapshot(
  version: version,
  destinations: hidden
      ? []
      : [
          {
            'id': 'coursework-phu-yen',
            'name': 'Phú Yên bản $version',
            'region': 'Miền Trung',
            'places': [
              {
                'id': 'coursework-phu-yen/dam-o-loan',
                'destinationId': 'coursework-phu-yen',
                'name': 'Đầm Ô Loan bản $version',
                'sourceRefs': ['src-01'],
              },
            ],
          },
        ],
);

void main() {
  testWidgets(
    'search dynamic place opens parent detail then exact manual editor with zero engine calls',
    (tester) async {
      await tester.runAsync(
        () => repository.run((ctx) async {
          final snapshot = c6DiscoverySnapshot(1);
          final public = C6Public(snapshot);
          final discovery = DiscoveryProvider()..bindPublicSnapshot(snapshot);
          final input = PlannerInputProvider();
          final api = DraftApi();
          final trip = planner(ctx.disk, api);
          final runtime = ManualPlannerRuntime(
            factory: () async => flow.resources(ctx),
          );
          try {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<PublicCatalogueProvider>.value(
                    value: public,
                  ),
                  ChangeNotifierProvider<DiscoveryProvider>.value(
                    value: discovery,
                  ),
                  ChangeNotifierProvider<PlannerInputProvider>.value(
                    value: input,
                  ),
                  ChangeNotifierProvider<TripProvider>.value(value: trip),
                  Provider<ManualPlannerRuntime>.value(value: runtime),
                ],
                child: const MaterialApp(home: ExploreScreen()),
              ),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('destination-search')),
              'dam o loan',
            );
            await tester.pumpAndSettle();
            expect(
              find.textContaining('Khớp địa điểm: Đầm Ô Loan bản 1'),
              findsOneWidget,
            );
            await tapText(tester, 'Phú Yên bản 1');
            expect(find.text('Đầm Ô Loan bản 1'), findsOneWidget);
            await tapText(tester, 'Chuẩn bị chuyến đi');
            await tapText(tester, 'Tự lập lịch trình');
            final resources = await runtime.getResources();
            expect(find.byType(ManualPlannerScreen), findsOneWidget);
            expect(
              resources.planner.document!.input.destinationId,
              'coursework-phu-yen',
            );
            expect(
              resources.planner.document!.input.destinationName,
              'Phú Yên bản 1',
            );
            expect(api.plans, 0);
            expect(api.health, 0);
            expect(ctx.server.creates, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await runtime.close();
            input.dispose();
            trip.dispose();
            discovery.dispose();
            public.dispose();
          }
        }),
      );
    },
  );
  testWidgets(
    'detail resolves destination and place from one current snapshot; hide blocks CTA',
    (tester) async {
      final initial = c6DiscoverySnapshot(1);
      final public = C6Public(initial);
      addTearDown(public.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<PublicCatalogueProvider>.value(
          value: public,
          child: MaterialApp(
            home: DestinationDetailScreen(
              catalogue: initial.catalogue,
              destination: initial.catalogue.destinations.single,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Phú Yên bản 1'), findsOneWidget);
      public.replace(c6DiscoverySnapshot(2));
      await tester.pumpAndSettle();
      expect(find.text('Phú Yên bản 2'), findsOneWidget);
      expect(find.text('Phú Yên bản 1'), findsNothing);
      expect(find.text('Đầm Ô Loan bản 1'), findsNothing);
      public.replace(c6DiscoverySnapshot(3, hidden: true));
      await tester.pumpAndSettle();
      expect(find.text('Chuẩn bị chuyến đi'), findsNothing);
      expect(find.textContaining('không còn trong danh mục'), findsOneWidget);
    },
  );
}
