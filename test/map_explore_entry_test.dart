import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/catalogue_discovery_map_screen.dart';

import 'catalogue_parser_test.dart' show catalogueData;

void main() {
  testWidgets('ExploreScreen AppBar displays map icon button and navigates to CatalogueDiscoveryMapScreen', (tester) async {
    final repo = CatalogueRepository(loader: () async => jsonEncode(catalogueData()));
    final provider = DiscoveryProvider(repository: repo);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<DiscoveryProvider>.value(
        value: provider,
        child: const ExploreScreen(),
      ),
    ));

    final mapButtonFinder = find.byTooltip('Xem bản đồ khám phá');
    expect(mapButtonFinder, findsOneWidget);

    await tester.tap(mapButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CatalogueDiscoveryMapScreen), findsOneWidget);
  });
}
