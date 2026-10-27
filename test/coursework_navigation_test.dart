import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/discovery_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/place_visit_details_provider.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_repository.dart';
import 'package:travelgo_mobile/features/navigation/presentation/screens/main_navigation_shell.dart';
import 'package:travelgo_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trip_planner/services/trip_api_service.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/providers/saved_trips_provider.dart';
import 'package:travelgo_mobile/main.dart';

import 'catalogue_parser_test.dart' show catalogueData;
import 'discovery_screen_test.dart' show discoveryVisitsFixture;
import 'editable_trip_repository_test.dart' as repository;
import 'manual_discovery_flow_test.dart' as flow;
import 'planner_catalogue_entry_test.dart'
    show makeTestReleaseSnapshot, FakePublicCatalogueProvider;
import 'public_catalogue_consumers_test.dart' show createSnapshot;

class SpyTripApiService extends TripApiService {
  int engineCalls = 0;
  @override
  Future<PlanTripResponse> planTrip(PlanTripRequest request) async {
    engineCalls++;
    throw StateError(
      'Decision Engine must never be called in coursework flows',
    );
  }
}

void main() {
  group('Coursework C1 - Navigation & Scope Tests', () {
    testWidgets(
      'profile_tab_after_favorites_removed: 4 destinations only, index 3 opens CustomerProfileScreen',
      (tester) async {
        final auth = AuthProvider()..continueAsGuest();
        final trip = TripProvider();
        final discovery = DiscoveryProvider(
          repository: CatalogueRepository(
            loader: () async => jsonEncode(catalogueData()),
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<PlannerInputProvider>(
                create: (_) => PlannerInputProvider(),
              ),
              ChangeNotifierProvider<TripProvider>.value(value: trip),
              ChangeNotifierProvider<DiscoveryProvider>.value(value: discovery),
              ChangeNotifierProvider<SavedTripsProvider>(
                create: (_) => SavedTripsProvider(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(initialIndex: 3),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify NavigationBar has exactly 4 items
        final navBarFinder = find.byType(NavigationBar);
        expect(navBarFinder, findsOneWidget);
        final destinationsFinder = find.descendant(
          of: navBarFinder,
          matching: find.byType(NavigationDestination),
        );
        expect(destinationsFinder, findsNWidgets(4));

        // 2. Favorites is completely removed
        expect(find.text('Yêu thích'), findsNothing);

        // 3. Tab labels: Trang chủ, Khám phá, Chuyến đi, Cá nhân
        expect(find.text('Trang chủ'), findsOneWidget);
        expect(find.text('Khám phá'), findsOneWidget);
        expect(find.text('Chuyến đi'), findsOneWidget);
        expect(find.text('Cá nhân'), findsOneWidget);

        // 4. At initialIndex 3, CustomerProfileScreen is directly displayed
        expect(find.byType(CustomerProfileScreen), findsOneWidget);
        expect(find.text('Tài Khoản'), findsOneWidget);

        auth.dispose();
        trip.dispose();
        discovery.dispose();
      },
    );

    testWidgets(
      'opens_manual_without_engine: HomePlanner CTA opens manual editor with destination, 0 engine calls, no map entry in day bar',
      (tester) async {
        await tester.runAsync(
          () => repository.run((ctx) async {
            final spyApi = SpyTripApiService();
            final trip = TripProvider(apiService: spyApi);
            final input = PlannerInputProvider();
            input.setDestination(id: 'hue', name: 'Huế');

            final snapshot = makeTestReleaseSnapshot();
            final pubProvider = FakePublicCatalogueProvider(snapshot);
            final discovery = DiscoveryProvider(
              repository: CatalogueRepository(
                loader: () async => jsonEncode(catalogueData()),
              ),
            );
            final bundle = flow.resources(ctx);
            final runtime = ManualPlannerRuntime(factory: () async => bundle);

            try {
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<PlannerInputProvider>.value(
                      value: input,
                    ),
                    ChangeNotifierProvider<TripProvider>.value(value: trip),
                    ChangeNotifierProvider<DiscoveryProvider>.value(
                      value: discovery,
                    ),
                    ChangeNotifierProvider<PublicCatalogueProvider>.value(
                      value: pubProvider,
                    ),
                    Provider<ManualPlannerRuntime>.value(value: runtime),
                  ],
                  child: MaterialApp(
                    theme: AppTheme.lightTheme,
                    home: const HomePlannerScreen(),
                  ),
                ),
              );

              await tester.pumpAndSettle();

              // Locate primary CTA button on HomePlannerScreen
              final ctaFinder = find.widgetWithText(
                ElevatedButton,
                'Lập lịch trình cho Huế',
              );
              expect(ctaFinder, findsOneWidget);

              // Tap CTA button
              await tester.ensureVisible(ctaFinder);
              await tester.tap(ctaFinder);
              await tester.pumpAndSettle();

              // Assertions:
              // 1. Manual editor opened
              expect(find.byType(ManualPlannerScreen), findsOneWidget);

              // 2. Destination matches Huế
              final bindings = await runtime.getResources();
              expect(bindings.planner.document?.input.destinationId, 'hue');
              expect(bindings.planner.document?.input.destinationName, 'Huế');

              // 3. Engine calls == 0
              expect(spyApi.engineCalls, 0);

              // 4. Map entry absent in day bar / manual editor
              expect(find.text('Bản đồ ngày này'), findsNothing);
            } finally {
              bundle.dispose();
              input.dispose();
              trip.dispose();
              discovery.dispose();
              pubProvider.dispose();
              await runtime.close();
            }
          }),
        );
      },
    );

    testWidgets(
      'explore_and_home_planner_navigation_without_map: Explore has no map entry, opens planner with Huế, no map in editor',
      (tester) async {
        await tester.runAsync(
          () => repository.run((ctx) async {
            final auth = AuthProvider()..continueAsGuest();
            final spyApi = SpyTripApiService();
            final trip = TripProvider(apiService: spyApi);
            final input = PlannerInputProvider();
            // Discovery and public facts must describe the same release.
            final snapshot = createSnapshot(
              destinations: [
                {'id': 'hue', 'name': 'Huế', 'region': 'Trung', 'places': []},
              ],
            );
            final pubProvider = FakePublicCatalogueProvider(snapshot);
            final discovery = DiscoveryProvider(
              repository: CatalogueRepository(
                loader: () async => jsonEncode(catalogueData()),
              ),
            );
            final visits = discoveryVisitsFixture();
            final bundle = flow.resources(ctx);
            final runtime = ManualPlannerRuntime(factory: () async => bundle);

            try {
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<AuthProvider>.value(value: auth),
                    ChangeNotifierProvider<PlannerInputProvider>.value(
                      value: input,
                    ),
                    ChangeNotifierProvider<TripProvider>.value(value: trip),
                    ChangeNotifierProvider<DiscoveryProvider>.value(
                      value: discovery,
                    ),
                    ChangeNotifierProvider<PlaceVisitDetailsProvider>.value(
                      value: visits,
                    ),
                    ChangeNotifierProvider<PublicCatalogueProvider>.value(
                      value: pubProvider,
                    ),
                    ChangeNotifierProvider<SavedTripsProvider>(
                      create: (_) => SavedTripsProvider(),
                    ),
                    Provider<ManualPlannerRuntime>.value(value: runtime),
                  ],
                  child: MaterialApp(
                    theme: AppTheme.lightTheme,
                    home: const MainNavigationShell(initialIndex: 1),
                  ),
                ),
              );

              await tester.pumpAndSettle();

              // 1. Explore screen has no map button / tooltip / icon
              expect(find.byTooltip('Bản đồ'), findsNothing);
              expect(find.byIcon(Icons.map_outlined), findsNothing);

              // 2. Search and tap destination 'Huế' in explore screen
              await tester.enterText(
                find.byKey(const ValueKey('destination-search')),
                'hue',
              );
              await tester.testTextInput.receiveAction(TextInputAction.done);
              await tester.pumpAndSettle();

              final hueFinder = find.text('Huế');
              expect(hueFinder, findsWidgets);
              await tester.ensureVisible(hueFinder.first);
              await tester.tap(hueFinder.first);
              await tester.pumpAndSettle();

              // 3. On destination detail screen, tap 'Chuẩn bị chuyến đi'
              final prepareCta = find.text('Chuẩn bị chuyến đi');
              expect(prepareCta, findsOneWidget);
              await tester.tap(prepareCta);
              await tester.pumpAndSettle();

              // 4. On HomePlannerScreen, destination is preserved
              expect(find.byType(HomePlannerScreen), findsOneWidget);
              expect(input.currentMetadata.destinationId, 'hue');
              expect(find.text('Bản đồ ngày này'), findsNothing);

              // 5. Tap 'Lập lịch trình cho Huế'
              final ctaPlanner = find.widgetWithText(
                ElevatedButton,
                'Lập lịch trình cho Huế',
              );
              expect(ctaPlanner, findsOneWidget);
              await tester.ensureVisible(ctaPlanner);
              await tester.tap(ctaPlanner);
              await tester.pumpAndSettle();

              // 6. Manual editor opened with Huế, 0 engine calls, no map entry
              expect(find.byType(ManualPlannerScreen), findsOneWidget);
              final bindings = await runtime.getResources();
              expect(bindings.planner.document?.input.destinationId, 'hue');
              expect(spyApi.engineCalls, 0);
              expect(find.text('Bản đồ ngày này'), findsNothing);
            } finally {
              bundle.dispose();
              input.dispose();
              trip.dispose();
              discovery.dispose();
              visits.dispose();
              pubProvider.dispose();
              auth.dispose();
              await runtime.close();
            }
          }),
        );
      },
    );

    testWidgets(
      'preserves_unsaved_editor_on_cancel_replace: editor digest and unsaved changes unchanged after cancel dialog',
      (tester) async {
        await tester.runAsync(
          () => repository.run((ctx) async {
            final input = PlannerInputProvider();
            final snapshot = makeTestReleaseSnapshot();
            final pubProvider = FakePublicCatalogueProvider(snapshot);
            final bundle = flow.resources(ctx);
            final runtime = ManualPlannerRuntime(factory: () async => bundle);

            try {
              // 1. Setup an existing dirty document in ManualPlannerProvider
              final originalDoc = ManualTripFactory().fromInput(
                PlanTripRequest.presetMinh(),
                TripMetadataV1(
                  title: 'Lịch Đang Soạn',
                  destinationName: 'Đà Nẵng',
                ),
              );
              bundle.planner.openNew(originalDoc);
              bundle.planner.dispatch(
                DayNotesCommand(originalDoc.days.first.id, 'Ghi chú chưa lưu'),
              );

              expect(bundle.planner.dirty, isTrue);
              final originalDigest = EditableTripCodec.digest(
                bundle.planner.document!,
              );
              final originalNotes = bundle.planner.document?.days.first.notes;

              // 2. Pump ManualPlannerEntryScreen which attempts to open new document
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<PlannerInputProvider>.value(
                      value: input,
                    ),
                    ChangeNotifierProvider<PublicCatalogueProvider>.value(
                      value: pubProvider,
                    ),
                    Provider<ManualPlannerRuntime>.value(value: runtime),
                  ],
                  child: MaterialApp(
                    theme: AppTheme.lightTheme,
                    home: const ManualPlannerEntryScreen(
                      intent: ManualPlannerEntryIntent.edit,
                    ),
                  ),
                ),
              );

              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));

              // 3. Replace confirmation dialog appears
              expect(find.text('Thay bản chỉnh sửa đang mở?'), findsOneWidget);
              expect(find.text('Giữ bản đang sửa'), findsOneWidget);

              // 4. Tap "Giữ bản đang sửa" (Cancel)
              await tester.tap(find.text('Giữ bản đang sửa'));
              await tester.pumpAndSettle();

              // 5. Assert: dirty state and document digest are completely preserved!
              expect(bundle.planner.dirty, isTrue);
              expect(
                EditableTripCodec.digest(bundle.planner.document!),
                originalDigest,
              );
              expect(bundle.planner.document?.days.first.notes, originalNotes);
            } finally {
              bundle.dispose();
              input.dispose();
              pubProvider.dispose();
              await runtime.close();
            }
          }),
        );
      },
    );
  });
}
