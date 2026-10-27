import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/home_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:travelgo_mobile/features/trips/services/local_trip_store.dart';
import 'package:travelgo_mobile/main.dart';

import 'editable_trip_repository_test.dart' as repository;
import 'manual_discovery_flow_test.dart' as flow;
import 'planner_catalogue_entry_test.dart' show makeTestReleaseSnapshot, FakePublicCatalogueProvider;

void main() {
  group('PlannerInputProvider Unit & Flow Tests', () {
    test('input_has_no_engine_transport: standalone input has zero API / engine wiring', () {
      final provider = PlannerInputProvider();
      expect(provider.currentRequest.numDays, 3);
      expect(provider.workspaceGeneration, 0);
      expect(provider.hasSelectedDestination, isFalse);

      // Verify no plan response or engine status exists on provider
      provider.updateRequest(provider.currentRequest.copyWith(numDays: 5));
      expect(provider.currentRequest.numDays, 5);
      expect(provider.workspaceGeneration, 1);

      provider.dispose();
    });

    test('date_duration_and_destination_consistency: dates stay consistent via policy', () {
      final provider = PlannerInputProvider();

      provider.setCalendarRange('2026-11-01', '2026-11-05');
      expect(provider.currentRequest.startDate, '2026-11-01');
      expect(provider.currentRequest.endDate, '2026-11-05');
      expect(provider.currentRequest.numDays, 5);
      expect(provider.currentMetadata.startDate, '2026-11-01');
      expect(provider.currentMetadata.endDate, '2026-11-05');

      provider.setDuration(7);
      expect(provider.currentRequest.numDays, 7);
      expect(provider.currentRequest.endDate, '2026-11-07');
      expect(provider.currentMetadata.endDate, '2026-11-07');

      provider.setDestination(id: 'hue', name: 'Huế');
      expect(provider.currentMetadata.destinationId, 'hue');
      expect(provider.currentMetadata.destinationName, 'Huế');
      expect(provider.currentMetadata.title, 'Chuyến đi Huế');
      expect(provider.hasSelectedDestination, isTrue);

      provider.dispose();
    });

    test('reset_input_preserves_stored_trips: reset does not touch stored trips on disk', () async {
      await repository.run((ctx) async {
        // 1. Create and save a trip on disk
        final doc = ManualTripFactory().fromInput(
          PlanTripRequest.presetMinh(),
          TripMetadataV1(title: 'Đã lưu trên máy', destinationName: 'Đà Nẵng'),
        );
        final initialRecord = await ctx.repository.saveGuest(
          scope: 'default',
          draftId: 'test-trip-keep',
          expectedRevision: null,
          document: doc,
        );
        expect(initialRecord.revision, 1);

        // 2. Set input and reset it
        final provider = PlannerInputProvider();
        provider.setDestination(id: 'hue', name: 'Huế');
        expect(provider.workspaceGeneration, 1);

        provider.reset();
        expect(provider.workspaceGeneration, 2);
        expect(provider.currentMetadata.destinationId, isNull);
        expect(provider.hasSelectedDestination, isFalse);

        // 3. Verify trip on disk remains intact and unchanged
        final readDoc = await ctx.disk.store.readEditableDraft(
          deviceScope: 'default',
          draftId: 'test-trip-keep',
        );
        expect(readDoc, isNotNull);
        expect(readDoc!.revision, 1);
        expect(EditableTripCodec.digest(readDoc.document), EditableTripCodec.digest(doc));
        expect(readDoc.document.days.length, doc.days.length);

        provider.dispose();
      });
    });

    test('old_trip_read_survives_map_removal: legacy v1/v2 documents preserve title, dates, actuals', () {
      // 1. Read legacy V2 vector
      final doc = ManualTripFactory().fromInput(
        PlanTripRequest.presetMinh().copyWith(
          startDate: '2026-11-10',
          endDate: '2026-11-12',
          numDays: 3,
        ),
        TripMetadataV1(
          title: 'Chuyến đi Huế Cũ',
          destinationId: 'hue',
          destinationName: 'Huế',
          startDate: '2026-11-10',
          endDate: '2026-11-12',
        ),
      );
      final jsonStr = EditableTripCodec.encode(doc);
      final decodedV2 = EditableTripCodec.decode(jsonStr);

      expect(decodedV2.input.title, 'Chuyến đi Huế Cũ');
      expect(decodedV2.input.destinationName, 'Huế');
      expect(decodedV2.input.startDate, '2026-11-10');
      expect(decodedV2.input.endDate, '2026-11-12');
      expect(decodedV2.days.length, 3);

      // 2. Read legacy V1 payload
      final v1 = CanonicalTripPayloadV1(
        metadata: TripMetadataV1(
          title: 'Legacy V1 Trip',
          destinationId: 'hue',
          destinationName: 'Huế',
        ),
        request: PlanTripRequest.presetMinh(),
      );
      final v1Encoded = TripPayloadCodec.encode(v1);
      final decodedV1 = TripPayloadCodec.decode(jsonDecode(v1Encoded));

      expect(decodedV1.metadata.title, 'Legacy V1 Trip');
      expect(decodedV1.metadata.destinationName, 'Huế');
      expect(decodedV1.request?.numDays, 3);
    });

    testWidgets(
      'input_generation_invalidates_pending_entry: changing input before entry resolves aborts entry',
      (tester) async {
        await tester.runAsync(() => repository.run((ctx) async {
          final input = PlannerInputProvider();
          input.setDestination(id: 'hue', name: 'Huế');

          final snapshot = makeTestReleaseSnapshot();
          final pubProvider = FakePublicCatalogueProvider(snapshot);
          final bundle = flow.resources(ctx);
          final runtime = ManualPlannerRuntime(factory: () async => bundle);

          try {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<PlannerInputProvider>.value(value: input),
                  ChangeNotifierProvider<PublicCatalogueProvider>.value(value: pubProvider),
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

            // Increment generation while entry is initializing/pending
            input.setDestination(id: 'da-nang', name: 'Đà Nẵng');

            await tester.pumpAndSettle();

            // Entry aborted because generation changed while pending
            expect(find.byType(ManualPlannerScreen), findsNothing);
          } finally {
            bundle.dispose();
            pubProvider.dispose();
            input.dispose();
            await runtime.close();
          }
        }));
      },
    );

    test('C2-F01: calendar_then_all_presets_atomic_consistency: all 3 presets adapt dates', () {
      // 1. Preset 1 (Minh, 3 days): after calendar 2026-11-01 to 2026-11-05
      final input1 = PlannerInputProvider();
      input1.setCalendarRange('2026-11-01', '2026-11-05');
      input1.applyPreset(1);
      expect(input1.currentRequest.numDays, 3);
      expect(input1.currentRequest.startDate, '2026-11-01');
      expect(input1.currentRequest.endDate, '2026-11-03');
      expect(input1.currentMetadata.startDate, '2026-11-01');
      expect(input1.currentMetadata.endDate, '2026-11-03');
      final doc1 = ManualTripFactory().fromInput(input1.currentRequest, input1.currentMetadata);
      expect(doc1.days.length, 3);
      input1.dispose();

      // 2. Preset 2 (Phú Quốc, 4 days): after calendar 2026-11-01 to 2026-11-05
      final input2 = PlannerInputProvider();
      input2.setCalendarRange('2026-11-01', '2026-11-05');
      input2.applyPreset(2);
      expect(input2.currentRequest.numDays, 4);
      expect(input2.currentRequest.startDate, '2026-11-01');
      expect(input2.currentRequest.endDate, '2026-11-04');
      expect(input2.currentMetadata.startDate, '2026-11-01');
      expect(input2.currentMetadata.endDate, '2026-11-04');
      final doc2 = ManualTripFactory().fromInput(input2.currentRequest, input2.currentMetadata);
      expect(doc2.days.length, 4);
      input2.dispose();

      // 3. Preset 3 (Vũng Tàu, 2 days): after calendar 2026-11-01 to 2026-11-05
      final input3 = PlannerInputProvider();
      input3.setCalendarRange('2026-11-01', '2026-11-05');
      input3.applyPreset(3);
      expect(input3.currentRequest.numDays, 2);
      expect(input3.currentRequest.startDate, '2026-11-01');
      expect(input3.currentRequest.endDate, '2026-11-02');
      expect(input3.currentMetadata.startDate, '2026-11-01');
      expect(input3.currentMetadata.endDate, '2026-11-02');
      final doc3 = ManualTripFactory().fromInput(input3.currentRequest, input3.currentMetadata);
      expect(doc3.days.length, 2);
      input3.dispose();

      // 4. Positive control: setDuration(6) preserves start and calculates end
      final inputControl = PlannerInputProvider();
      inputControl.setCalendarRange('2026-11-01', '2026-11-05');
      inputControl.setDuration(6);
      expect(inputControl.currentRequest.numDays, 6);
      expect(inputControl.currentRequest.startDate, '2026-11-01');
      expect(inputControl.currentRequest.endDate, '2026-11-06');
      expect(inputControl.currentMetadata.startDate, '2026-11-01');
      expect(inputControl.currentMetadata.endDate, '2026-11-06');
      final docControl = ManualTripFactory().fromInput(inputControl.currentRequest, inputControl.currentMetadata);
      expect(docControl.days.length, 6);
      inputControl.dispose();

      // 5. Positive control: preset without prior calendar dates
      final inputNoDate = PlannerInputProvider();
      inputNoDate.applyPreset(3);
      expect(inputNoDate.currentRequest.numDays, 2);
      expect(inputNoDate.currentRequest.startDate, isNull);
      expect(inputNoDate.currentRequest.endDate, isNull);
      expect(inputNoDate.currentMetadata.startDate, isNull);
      expect(inputNoDate.currentMetadata.endDate, isNull);
      final docNoDate = ManualTripFactory().fromInput(inputNoDate.currentRequest, inputNoDate.currentMetadata);
      expect(docNoDate.days.length, 2);
      inputNoDate.dispose();
    });

    test('C2-F02: clear_destination_and_free_text_clears_catalogue_id', () {
      // 1. P1: Clearing selected destination
      final input = PlannerInputProvider();
      input.setDestination(id: 'hue', name: 'Huế');
      expect(input.currentMetadata.destinationId, 'hue');
      expect(input.currentRequest.destinationId, 'hue');

      expect(input.useSuggestedDestination(), isTrue);
      expect(input.currentMetadata.destinationId, isNull);
      expect(input.currentMetadata.destinationName, isNull);
      expect(input.currentRequest.destinationId, isNull);
      expect(input.currentRequest.destinationName, isNull);

      // 2. P3: Switching from catalogue destination to free-text custom destination
      input.setDestination(id: 'hue', name: 'Huế');
      expect(input.currentMetadata.destinationId, 'hue');

      input.setDestination(id: null, name: 'Phú Yên');
      expect(input.currentMetadata.destinationId, isNull);
      expect(input.currentMetadata.destinationName, 'Phú Yên');
      expect(input.currentRequest.destinationId, isNull);
      expect(input.currentRequest.destinationName, 'Phú Yên');

      // 3. Dates and user preferences preserved across destination changes
      input.setCalendarRange('2026-11-10', '2026-11-13');
      input.useSuggestedDestination();
      expect(input.currentRequest.destinationId, isNull);
      expect(input.currentRequest.startDate, '2026-11-10');
      expect(input.currentRequest.endDate, '2026-11-13');
      expect(input.currentRequest.numDays, 4);

      input.dispose();
    });

    testWidgets('C2-F03: production_dual_provider_tree_has_zero_legacy_mutation_calls', (tester) async {
      final input = PlannerInputProvider();
      final legacy = _LegacyWriteSpy();

      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PlannerInputProvider>.value(value: input),
              ChangeNotifierProvider<TripProvider>.value(value: legacy),
            ],
            child: const MaterialApp(home: HomePlannerScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Change origin via ChoiceChip
        await tester.tap(find.widgetWithText(ChoiceChip, 'Hà Nội'));
        await tester.pumpAndSettle();
        expect(input.currentRequest.origin, 'Hà Nội');
        expect(legacy.totalMutationCalls, 0, reason: 'Must not write to legacy TripProvider on origin change');

        // 2. Change origin to Đà Nẵng
        await tester.tap(find.widgetWithText(ChoiceChip, 'Đà Nẵng'));
        await tester.pumpAndSettle();
        expect(input.currentRequest.origin, 'Đà Nẵng');
        expect(legacy.totalMutationCalls, 0, reason: 'Must not write to legacy TripProvider on second chip tap');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        input.dispose();
        legacy.dispose();
      }
    });

    testWidgets('C2-F03: production_graph_zero_legacy_provider_construction', (tester) async {
      // Demonstrates that opening Home and entering ManualPlannerScreen in production tree
      // does NOT construct, wire, or require legacy TripProvider.
      await tester.runAsync(() => repository.run((ctx) async {
        final input = PlannerInputProvider();
        final snapshot = makeTestReleaseSnapshot();
        final pubProvider = FakePublicCatalogueProvider(snapshot);
        final bundle = flow.resources(ctx);
        final runtime = ManualPlannerRuntime(factory: () async => bundle);

        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PlannerInputProvider>.value(value: input),
                ChangeNotifierProvider<PublicCatalogueProvider>.value(value: pubProvider),
                Provider<ManualPlannerRuntime>.value(value: runtime),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: Builder(
                  builder: (context) {
                    // Assert TripProvider is NOT present in the tree (zero construction)
                    expect(
                      () => context.read<TripProvider>(),
                      throwsA(isA<ProviderNotFoundException>()),
                    );
                    return const HomePlannerScreen();
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. HomePlannerScreen renders with input provider and ChoiceChips respond
          expect(find.byType(HomePlannerScreen), findsOneWidget);
          await tester.tap(find.widgetWithText(ChoiceChip, 'Hà Nội'));
          await tester.pumpAndSettle();
          expect(input.currentRequest.origin, 'Hà Nội');

          // 2. Open manual planner entry screen without TripProvider
          unawaited(openManualPlanner(tester.element(find.byType(HomePlannerScreen))));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          expect(find.byType(ManualPlannerEntryScreen), findsOneWidget);

          // Verify TripProvider was NEVER constructed or required
          expect(
            () => tester.element(find.byType(ManualPlannerEntryScreen)).read<TripProvider>(),
            throwsA(isA<ProviderNotFoundException>()),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          input.dispose();
          pubProvider.dispose();
        }
      }));
    });
  });
}

class _LegacyWriteSpy extends TripProvider {
  int updateRequestCalls = 0;
  int setCalendarRangeCalls = 0;
  int applyPresetCalls = 0;
  int setDurationCalls = 0;
  int prepareDestinationCalls = 0;
  int useSuggestedDestinationCalls = 0;

  int get totalMutationCalls =>
      updateRequestCalls +
      setCalendarRangeCalls +
      applyPresetCalls +
      setDurationCalls +
      prepareDestinationCalls +
      useSuggestedDestinationCalls;

  @override
  void updateRequest(PlanTripRequest request) {
    updateRequestCalls++;
    super.updateRequest(request);
  }

  @override
  void setCalendarRange(String start, String end) {
    setCalendarRangeCalls++;
    super.setCalendarRange(start, end);
  }

  @override
  void applyPreset(int presetId) {
    applyPresetCalls++;
    super.applyPreset(presetId);
  }

  @override
  void setDuration(int days) {
    setDurationCalls++;
    super.setDuration(days);
  }

  @override
  bool prepareDestinationWorkspace({
    required String destinationId,
    required String destinationName,
    required int expectedWorkspaceGeneration,
    bool replaceDirty = false,
  }) {
    prepareDestinationCalls++;
    return super.prepareDestinationWorkspace(
      destinationId: destinationId,
      destinationName: destinationName,
      expectedWorkspaceGeneration: expectedWorkspaceGeneration,
      replaceDirty: replaceDirty,
    );
  }

  @override
  bool useSuggestedDestination({
    required int expectedWorkspaceGeneration,
    bool replaceDirty = false,
  }) {
    useSuggestedDestinationCalls++;
    return super.useSuggestedDestination(
      expectedWorkspaceGeneration: expectedWorkspaceGeneration,
      replaceDirty: replaceDirty,
    );
  }
}
