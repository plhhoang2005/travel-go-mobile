import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/home/presentation/screens/main_home_screen.dart';
import 'package:travelgo_mobile/core/presentation/travel_image.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/place_visit_details_provider.dart';
import 'package:travelgo_mobile/features/explore/services/place_visit_details_repository.dart';
import 'package:travelgo_mobile/features/explore/presentation/widgets/place_visit_details_widget.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'guest_draft_planner_test.dart' show DraftApi;
import 'place_visit_details_model_test.dart' show visitTestHash, visitTestNow;
import 'place_visit_details_repository_test.dart' show MemoryVisitCache;

PlaceVisitDetailsProvider discoveryVisitsFixture({bool fail = false}) =>
    PlaceVisitDetailsProvider(
      repositoryFactory: (catalogue) async {
        if (fail) throw StateError('Synthetic loader failure');
        return VisitDetailsRepository(
          dio: Dio(),
          ownsDio: true,
          cache: MemoryVisitCache(),
          seedLoader: () async =>
              File('assets/catalogue/place_visit_details_v1.json')
                  .readAsStringSync(),
          projectOrigin: Uri.parse('https://bkocylxbuyvdgxccpixx.supabase.co'),
          expectedPlaceIds: catalogue.destinations
              .expand((d) => d.places)
              .map((p) => p.id)
              .toSet(),
          expectedCatalogueSha256: visitTestHash,
          now: () => visitTestNow,
          remoteEnabled: false,
        );
      },
      now: () => visitTestNow,
    );

Future<void> pumpDiscovery(
  WidgetTester tester,
  DiscoveryProvider discovery,
  TripProvider trip, {
  Widget? screen,
  AuthProvider? auth,
  PlaceVisitDetailsProvider? visits,
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
        if (visits != null) ChangeNotifierProvider.value(value: visits),
        if (auth != null) ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
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
    'Explore binds the shared visit provider to exactly six Hanoi places',
    (tester) async {
      final discovery = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () async => jsonEncode(catalogueData()),
        ),
      );
      final trip = TripProvider(apiService: DraftApi());
      final visits = discoveryVisitsFixture();
      addTearDown(discovery.dispose);
      addTearDown(trip.dispose);
      addTearDown(visits.dispose);
      await pumpDiscovery(tester, discovery, trip, visits: visits);
      await tester.enterText(
        find.byKey(const ValueKey('destination-search')),
        'ha noi',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hà Nội'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaceVisitDetailsWidget), findsNWidgets(6));
      expect(find.textContaining('70.000 ₫'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('visit-price-ha-noi/van-mieu')),
        findsOneWidget,
      );
      expect(
        identical(
          tester
              .widget<DestinationDetailScreen>(
                find.byType(DestinationDetailScreen),
              )
              .visitProvider,
          visits,
        ),
        true,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(discovery.query, 'ha noi');
      expect(discovery.visibleDestinations.single.id, 'ha-noi');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Home photo discovery keeps selected destination and interest on back',
    (tester) async {
      final d = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () async => jsonEncode(catalogueData()),
        ),
      );
      final api = DraftApi();
      final trip = TripProvider(apiService: api);
      final auth = AuthProvider()..continueAsGuest();
      final visits = discoveryVisitsFixture();
      addTearDown(d.dispose);
      addTearDown(trip.dispose);
      addTearDown(auth.dispose);
      addTearDown(visits.dispose);
      await pumpDiscovery(
        tester,
        d,
        trip,
        screen: const MainHomeScreen(),
        auth: auth,
        visits: visits,
      );
      expect(find.text('Lập chuyến đi'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Văn hóa'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Huế'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(TravelImage), findsWidgets);
      await tester.tap(find.text('Huế'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DestinationDetailScreen>(
              find.byType(DestinationDetailScreen),
            )
            .destination
            .id,
        'hue',
      );
      expect(api.plans, 0);
      expect(
        identical(
          tester
              .widget<DestinationDetailScreen>(
                find.byType(DestinationDetailScreen),
              )
              .visitProvider,
          visits,
        ),
        true,
      );
      expect(find.byType(PlaceVisitDetailsWidget), findsNWidgets(6));
      expect(
        find.byKey(const ValueKey('visit-price-hue/citadel')),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Văn hóa'),
        -400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Văn hóa'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo failure keeps Discovery destination and source actions usable',
    (tester) async {
      final d = DiscoveryProvider(
        repository: CatalogueRepository(
          loader: () async => jsonEncode(catalogueData()),
        ),
      );
      final api = DraftApi();
      final trip = TripProvider(apiService: api);
      addTearDown(d.dispose);
      addTearDown(trip.dispose);
      await pumpDiscovery(tester, d, trip, scale: 2, width: 360);
      await tester.enterText(
        find.byKey(const ValueKey('destination-search')),
        'hue',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(TravelImage), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Nguồn ảnh'));
      await tester.tap(find.byTooltip('Nguồn ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh: Lưu Ly'), findsOneWidget);
      await tester.ensureVisible(find.text('Đóng'));
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Huế'));
      await tester.tap(find.text('Huế'));
      await tester.pumpAndSettle();
      expect(find.byType(DestinationDetailScreen), findsOneWidget);
      expect(api.plans, 0);
      expect(tester.takeException(), isNull);
    },
  );

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
