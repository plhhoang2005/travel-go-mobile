import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';

import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart' as catalogue;
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_assistant_service.dart';
import 'package:travelgo_mobile/features/trip_planner/services/ai_generation_service.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/providers/editable_drafts_provider.dart';
import 'package:travelgo_mobile/main.dart';

import 'editable_local_store_test.dart' as records;
import 'editable_trip_repository_test.dart' as repository;
import 'guest_draft_planner_test.dart' show DraftApi;

PublicCatalogueSnapshot createTestSnapshot({
  required List<Map<String, dynamic>> destinations,
}) {
  final bundle = {
    'contract': 'travelgo.discovery.release.v2',
    'schemaVersion': 2,
    'version': 1,
    'preparedAt': '2026-10-24T00:00:00.000Z',
    'catalogue': {
      'sources': [
        {
          'id': 'src-01',
          'title': 'Cổng du lịch',
          'publisher': 'Sở Du lịch',
          'url': 'https://dulich.vn',
          'checkedAt': '2026-10-24T00:00:00Z',
        }
      ],
      'destinations': destinations,
    },
    'visitDetails': {
      'sources': [],
      'packages': [],
      'places': [],
    },
  };
  final text = jsonEncode(bundle);
  final bytes = utf8.encode(text);
  final sha = sha256.convert(bytes).toString();
  final manifest = DiscoveryManifest(
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version: 1,
    objectKey: 'releases/v2/1.json',
    sha256: sha,
    byteLength: bytes.length,
    publishedAt: DateTime.parse('2026-10-24T00:00:00Z'),
  );
  return PublicCatalogueParser.parse(
    payloadText: text,
    manifest: manifest,
    now: DateTime.parse('2026-10-24T01:00:00Z'),
    origin: 'storage',
  );
}

void main() {
  const dynamicDestId = 'dest-quy-nhon-123';
  const dynamicDestName = 'Quy Nhơn';

  final testDestinations = [
    {
      'id': dynamicDestId,
      'name': dynamicDestName,
      'scope': 'destination_region',
      'routingReady': true,
      'places': [
        {
          'id': '$dynamicDestId/eo-gio',
          'name': 'Eo Gió',
          'sourceId': 'src-01',
          'sourceRefs': ['src-01'],
          'referenceStatus': 'verified',
          'coordinates': {'latitude': 13.78, 'longitude': 109.22},
        }
      ],
    },
    {
      'id': 'hue',
      'name': 'Huế',
      'scope': 'destination_region',
      'routingReady': true,
      'places': [],
    }
  ];

  group('Task Q2: Dynamic AI Destination & Assistant Entry', () {
    test('AiGenerationContext serializes sanitized public name and rejects mismatched IDs or contact patterns', () {
      final doc = records.doc().copyWith(
        input: TripInput.fromJson({
          ...records.doc().input.toJson(),
          'destinationId': dynamicDestId,
          'destinationName': 'Tên tự nhập tự do',
        }),
      );

      final validRef = catalogue.DestinationReference(
        id: dynamicDestId,
        name: dynamicDestName,
        region: 'Miền Trung',
        places: const [],
        sample: catalogue.SampleReference.unavailable(id: dynamicDestId),
      );

      // Context takes the public catalogue name "Quy Nhơn", NOT the free input "Tên tự nhập tự do"
      final context = AiGenerationContext.fromDocument(doc, destination: validRef);
      expect(context.destinationId, dynamicDestId);
      expect(context.destinationName, dynamicDestName);

      final json = context.toJson();
      expect(json['destinationId'], dynamicDestId);
      expect(json['destinationName'], dynamicDestName);
      expect(json.containsKey('notes'), isFalse);

      // Mismatched destination ID is rejected before network
      final wrongRef = catalogue.DestinationReference(
        id: 'hue',
        name: 'Huế',
        region: 'Miền Trung',
        places: const [],
        sample: validRef.sample,
      );
      expect(
        () => AiGenerationContext.fromDocument(doc, destination: wrongRef),
        throwsFormatException,
      );

      // Destination with phone or url pattern in name is rejected
      final dirtyRef = catalogue.DestinationReference(
        id: dynamicDestId,
        name: 'Quy Nhơn 0901234567',
        region: 'Miền Trung',
        places: const [],
        sample: validRef.sample,
      );
      expect(
        () => AiGenerationContext.fromDocument(doc, destination: dirtyRef),
        throwsFormatException,
      );
    });

    test('AiAssistantContext includes sanitized destinationName from destination reference', () {
      final doc = records.doc().copyWith(
        input: TripInput.fromJson({
          ...records.doc().input.toJson(),
          'destinationId': dynamicDestId,
        }),
      );

      final validRef = catalogue.DestinationReference(
        id: dynamicDestId,
        name: dynamicDestName,
        region: 'Miền Trung',
        places: const [],
        sample: catalogue.SampleReference.unavailable(id: dynamicDestId),
      );

      final assistantContext = AiAssistantContext.fromDocument(
        doc,
        destination: validRef,
        selectedDay: 1,
      );

      final json = assistantContext.toJson();
      expect(json['destinationId'], dynamicDestId);
      expect(json['destinationName'], dynamicDestName);
      expect(json['selectedDay'], 1);
    });

    testWidgets('DetailScreen Trợ giúp AI navigates to ManualPlannerEntryScreen with aiAssistant intent', (tester) async {
      await tester.runAsync(() => repository.run((ctx) async {
        final snapshot = createTestSnapshot(destinations: testDestinations);
        final tripProvider = TripProvider(apiService: DraftApi());
        final auth = AuthProvider()..continueAsGuest();
        final runtime = ManualPlannerRuntime(
          factory: () async => ManualPlannerResources(
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
          ),
        );
        addTearDown(tripProvider.dispose);
        addTearDown(auth.dispose);

        final destination = snapshot.catalogue.destinations.firstWhere((d) => d.id == dynamicDestId);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              Provider<ManualPlannerRuntime>.value(value: runtime),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: DestinationDetailScreen(
                catalogue: snapshot.catalogue,
                destination: destination,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final aiButton = find.widgetWithText(OutlinedButton, 'Trợ giúp AI');
        expect(aiButton, findsOneWidget);

        await tester.tap(aiButton);
        await tester.pumpAndSettle();

        // Verified navigation moved to ManualPlannerEntryScreen with the selected destination
        expect(find.byType(ManualPlannerEntryScreen), findsOneWidget);
        expect(tripProvider.currentMetadata.destinationId, dynamicDestId);
        expect(tripProvider.currentMetadata.destinationName, dynamicDestName);
      }));
    });

    testWidgets('ManualPlannerScreen with openAssistantOnReady opens composer once without making network requests', (tester) async {
      int aiCalls = 0;
      final snapshot = createTestSnapshot(destinations: testDestinations);
      final destination = snapshot.catalogue.destinations.firstWhere((d) => d.id == dynamicDestId);

      final doc = records.doc().copyWith(
        input: TripInput.fromJson({
          ...records.doc().input.toJson(),
          'destinationId': dynamicDestId,
          'destinationName': dynamicDestName,
        }),
      );

      final planner = ManualPlannerProvider(
        repositoryLoader: () async => throw StateError('Unexpected save call'),
        newId: () => 'item-id-1',
      );
      planner.openNew(doc);
      final auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ManualPlannerScreen(
              planner: planner,
              destinations: snapshot.catalogue.destinations,
              snapshot: snapshot,
              openAssistantOnReady: true,
              assistantGenerate: (intent, prompt, history, reqId) async {
                aiCalls++;
                throw StateError('AI should not be dispatched automatically');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Composer dialog is opened automatically
      expect(find.text('AI cho ngày 1'), findsOneWidget);
      // Zero network calls before user confirms and consents
      expect(aiCalls, 0);

      // Cancel button pops dialog without modifying document
      final initialDigest = EditableTripCodec.digest(planner.document!);
      final cancelButton = find.byKey(const ValueKey('ai-assistant-cancel'));
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(EditableTripCodec.digest(planner.document!), initialDigest);
      expect(aiCalls, 0);
    });

    testWidgets('unlisted or hidden destination is not AI eligible and blocks AI calls', (tester) async {
      int aiCalls = 0;
      final snapshot = createTestSnapshot(destinations: testDestinations);

      // Document with unlisted destination
      final doc = records.doc().copyWith(
        input: TripInput.fromJson({
          ...records.doc().input.toJson(),
          'destinationId': 'dest-unlisted-hidden',
        }),
      );

      final planner = ManualPlannerProvider(
        repositoryLoader: () async => throw StateError('Unexpected save call'),
        newId: () => 'item-id-1',
      );
      planner.openNew(doc);
      final auth = AuthProvider()..continueAsGuest();
      addTearDown(planner.dispose);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ManualPlannerScreen(
              planner: planner,
              destinations: snapshot.catalogue.destinations,
              snapshot: snapshot,
              assistantGenerate: (intent, prompt, history, reqId) async {
                aiCalls++;
                throw StateError('Must not be called');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final aiButton = find.byKey(const ValueKey('ai-assistant-open'));
      expect(aiButton, findsOneWidget);
      await tester.tap(aiButton);
      await tester.pumpAndSettle();

      expect(aiCalls, 0);
      expect(find.text('AI cho ngày 1'), findsNothing);
    });
  });
}
