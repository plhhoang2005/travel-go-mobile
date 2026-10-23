import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_command.dart';
import 'package:travelgo_mobile/features/trip_planner/models/editable_trip_document.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/widgets/selected_destination_controls.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/manual_planner_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/trip_provider.dart';
import 'package:travelgo_mobile/features/trip_planner/services/manual_trip_factory.dart';
import 'package:travelgo_mobile/features/trips/models/editable_trip_codec.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';
import 'package:provider/provider.dart';

String Function() _idGenerator() {
  var count = 1;
  return () => '00000000-0000-4000-8000-${(count++).toString().padLeft(12, '0')}';
}

PublicCatalogueSnapshot createSyntheticSnapshot({
  int version = 1,
  List<Map<String, dynamic>> destinations = const [],
}) {
  final bundle = {
    'contract': 'travelgo.discovery.release.v2',
    'schemaVersion': 2,
    'version': version,
    'preparedAt': '2026-10-20T10:00:00.000Z',
    'catalogue': {
      'sources': [
        {
          'id': 'src-01',
          'title': 'Cổng du lịch Quy Nhơn',
          'publisher': 'Sở Du lịch Bình Định',
          'url': 'https://quynhon.travel',
          'checkedAt': '2026-10-20T08:00:00Z',
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

  final payloadText = jsonEncode(bundle);
  final rawBytes = utf8.encode(payloadText);
  final sha = sha256.convert(rawBytes).toString();

  final manifest = DiscoveryManifest(
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version: version,
    objectKey: 'releases/v2/$version.json',
    sha256: sha,
    byteLength: rawBytes.length,
    publishedAt: DateTime.parse('2026-10-20T10:00:00Z'),
  );

  return PublicCatalogueParser.parse(
    payloadText: payloadText,
    manifest: manifest,
    now: DateTime.parse('2026-10-20T12:00:00Z'),
    origin: 'storage',
  );
}

void main() {
  group('P10: Dynamic Catalogue & Manual Planner UI Integration', () {
    const dynamicDestId = 'dest-quy-nhon-123';
    const dynamicDestName = 'Quy Nhơn';
    const dynamicPlaceId = 'dest-quy-nhon-123/eo-gio';
    const dynamicPlaceName = 'Eo Gió Quy Nhơn';

    final testDestinations = [
      {
        'id': dynamicDestId,
        'name': dynamicDestName,
        'scope': 'destination_region',
        'routingReady': true,
        'places': [
          {
            'id': dynamicPlaceId,
            'name': dynamicPlaceName,
            'sourceId': 'src-01',
            'referenceStatus': 'verified',
            'coordinates': {'latitude': 13.78, 'longitude': 109.22},
          }
        ],
      },
      {
        'id': 'ha-noi',
        'name': 'Hà Nội',
        'scope': 'destination_region',
        'routingReady': true,
        'places': [],
      }
    ];

    testWidgets('unsupported_destination_never_consumes_ai_quota', (tester) async {
      int aiRequestCalls = 0;
      final ids = _idGenerator();
      final factory = ManualTripFactory(newId: ids);

      final doc = factory.fromInput(
        PlanTripRequest.presetMinh(),
        TripMetadataV1(
          title: 'Khám phá Quy Nhơn',
          destinationId: dynamicDestId,
          destinationName: dynamicDestName,
          startDate: '2026-11-01',
          endDate: '2026-11-03',
        ),
      );

      final snapshot = createSyntheticSnapshot(destinations: testDestinations);
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => throw StateError('Unexpected store call'),
        newId: ids,
      );
      planner.openNew(doc);
      addTearDown(planner.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ManualPlannerScreen(
            planner: planner,
            destinations: snapshot.catalogue.destinations,
            snapshot: snapshot,
            generateAi: (doc, reqId) async {
              aiRequestCalls++;
              throw StateError('AI must never be invoked for unsupported dynamic destination');
            },
            assistantGenerate: (intent, prompt, history, reqId) async {
              aiRequestCalls++;
              throw StateError('AI must never be invoked for unsupported dynamic destination');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AI actions are disabled or blocked
      final aiAssistantButton = find.byKey(const ValueKey('ai-assistant-open'));
      expect(aiAssistantButton, findsOneWidget);
      // Tap on AI assistant button should not execute or consume quota
      await tester.tap(aiAssistantButton);
      await tester.pumpAndSettle();
      expect(aiRequestCalls, 0);

      // Verify manual editing remains completely functional
      final addBtn = find.text('Thêm nơi muốn ghé hoặc một hoạt động của riêng bạn.');
      expect(addBtn, findsOneWidget);

      final initialItemsCount = planner.document!.items.length;
      final day1 = planner.document!.days.first;
      planner.dispatch(
        AddItemCommand(
          TripItem(
            id: ids(),
            dayId: day1.id,
            position: 0,
            title: 'Tham quan Eo Gió',
            placeId: dynamicPlaceId,
            startMinute: 480,
            endMinute: 600,
            notes: 'Gió biển trong lành',
            provenance: FieldProvenance(
              quality: 'user_provided',
              sourceRefs: const [],
              observedAt: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(planner.document!.items.length, initialItemsCount + 1);
      expect(planner.document!.items.first.title, 'Tham quan Eo Gió');
      expect(aiRequestCalls, 0);
    });

    testWidgets('dynamic destination selected controls displays non-AI disclaimer', (tester) async {
      final tripProvider = TripProvider();
      addTearDown(tripProvider.dispose);

      tripProvider.prepareDestinationWorkspace(
        destinationId: dynamicDestId,
        destinationName: dynamicDestName,
        expectedWorkspaceGeneration: tripProvider.workspaceGeneration,
      );

      expect(tripProvider.supportsSelectedDestinationAi, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ChangeNotifierProvider<TripProvider>.value(
              value: tripProvider,
              child: const SelectedDestinationControls(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tính năng tự động và AI chưa hỗ trợ điểm đến này. Bạn có thể tự lập lịch trình.'),
        findsOneWidget,
      );
    });

    testWidgets('handle active destination disappearing during dirty editor', (tester) async {
      final ids = _idGenerator();
      final factory = ManualTripFactory(newId: ids);

      final doc = factory.fromInput(
        PlanTripRequest.presetMinh(),
        TripMetadataV1(
          title: 'Điểm đến sắp bị gỡ',
          destinationId: 'dest-old-disappeared',
          destinationName: 'Vùng đất cũ',
          startDate: '2026-11-01',
          endDate: '2026-11-03',
        ),
      );

      // Snapshot without dest-old-disappeared
      final snapshot = createSyntheticSnapshot(destinations: testDestinations);
      final planner = ManualPlannerProvider(
        repositoryLoader: () async => throw StateError('Unexpected store call'),
        newId: ids,
      );
      planner.openNew(doc);
      addTearDown(planner.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ManualPlannerScreen(
            planner: planner,
            destinations: snapshot.catalogue.destinations,
            snapshot: snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Warning banner must be displayed
      expect(find.byKey(const ValueKey('destination-unavailable-warning')), findsOneWidget);
      expect(
        find.text('Điểm đến này không còn trong danh mục hiện tại. Hãy chọn điểm đến mới để lưu.'),
        findsOneWidget,
      );

      // Input title, dates and actuals must be preserved
      expect(planner.document!.input.title, 'Điểm đến sắp bị gỡ');
      expect(planner.document!.input.destinationId, 'dest-old-disappeared');
    });

    test('dynamic destination survives roundtrip with typed place ID and expenses', () {
      final ids = _idGenerator();
      final factory = ManualTripFactory(newId: ids);

      final doc = factory.fromInput(
        PlanTripRequest.presetMinh(),
        TripMetadataV1(
          title: 'Khám phá Quy Nhơn',
          destinationId: dynamicDestId,
          destinationName: dynamicDestName,
          startDate: '2026-11-01',
          endDate: '2026-11-03',
        ),
      );

      final expense = ActualExpense(
        id: ids(),
        itemId: null,
        amountVnd: 250000,
        category: 'food',
        paidOn: '2026-11-01',
        description: 'Bún chả cá Quy Nhơn',
        sourceItemSnapshot: null,
        provenance: FieldProvenance(
          quality: 'user_provided',
          sourceRefs: const [],
          observedAt: null,
        ),
      );

      final withExpense = EditableTripDocumentV2(
        input: doc.input,
        days: doc.days,
        items: [
          TripItem(
            id: ids(),
            dayId: doc.days.first.id,
            position: 0,
            title: 'Kỳ Co Eo Gió',
            placeId: dynamicPlaceId,
            startMinute: 480,
            endMinute: 660,
            notes: 'Bãi biển đẹp',
            provenance: FieldProvenance(
              quality: 'user_provided',
              sourceRefs: const [],
              observedAt: null,
            ),
          )
        ],
        estimates: doc.estimates,
        actualExpenses: [expense],
        exceptions: doc.exceptions,
        source: doc.source,
      );

      final encoded = EditableTripCodec.encode(withExpense);
      final decoded = EditableTripCodec.decode(encoded);

      expect(decoded.input.destinationId, dynamicDestId);
      expect(decoded.input.destinationName, dynamicDestName);
      expect(decoded.items.single.placeId, dynamicPlaceId);
      expect(decoded.actualExpenses.single.amountVnd, 250000);
      expect(decoded.actualExpenses.single.description, 'Bún chả cá Quy Nhơn');
    });
  });
}
