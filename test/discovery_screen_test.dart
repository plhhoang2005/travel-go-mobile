import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'guest_draft_planner_test.dart' show DraftApi;

Future<void> pumpDiscovery(
  WidgetTester tester,
  DiscoveryProvider discovery,
  TripProvider trip, {
  Widget? screen,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: discovery),
        ChangeNotifierProvider.value(value: trip),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen ?? const ExploreScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'search/filter/reset and detail navigate without HomeCatalog or plan calls',
    (tester) async {
      final discovery = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () async => jsonEncode(catalogueData()),
        ),
      );
      final api = DraftApi();
      final trip = TripProvider(apiService: api);
      addTearDown(discovery.dispose);
      addTearDown(trip.dispose);
      await pumpDiscovery(tester, discovery, trip);
      await tester.enterText(
        find.byKey(const ValueKey('destination-search')),
        'hue',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Huế'));
      await tester.pumpAndSettle();
      expect(find.byType(DestinationDetailScreen), findsOneWidget);
      expect(find.text('Ví dụ đang được rà soát'), findsOneWidget);
      expect(api.plans, 0);
      expect(api.health, 0);
    },
  );
  for (final width in [360.0, 390.0]) {
    testWidgets(
      'loading/error retry and long empty query at $width, scale 1.5',
      (tester) async {
        var calls = 0;
        final d = DiscoveryProvider(
          repository: CatalogueRepository(
            loader: () async {
              if (++calls == 1) throw StateError('bad');
              return jsonEncode(catalogueData());
            },
          ),
        );
        final trip = TripProvider(apiService: DraftApi());
        addTearDown(d.dispose);
        addTearDown(trip.dispose);
        await pumpDiscovery(tester, d, trip, width: width, scale: 1.5);
        expect(find.text('Thử lại'), findsOneWidget);
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('destination-search')),
          'unknown',
        );
        await tester.pumpAndSettle();
        expect(find.text('Không tìm thấy điểm đến phù hợp.'), findsOneWidget);
        await tester.tap(find.byTooltip('Xóa tìm kiếm'));
        await tester.pumpAndSettle();
        expect(d.visibleDestinations.length, 12);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
