import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/core/theme/app_theme.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/providers/public_catalogue_provider.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_parser.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';
import 'package:travelgo_mobile/features/explore/services/manual_place_locations.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/manual_planner_screen.dart';
import 'package:travelgo_mobile/features/trip_planner/providers/planner_input_provider.dart';
import 'package:travelgo_mobile/main.dart';

import 'editable_trip_repository_test.dart' as repository;
import 'manual_discovery_flow_test.dart' as flow;

PublicCatalogueSnapshot makeTestReleaseSnapshot() {
  final bundle = {
    'contract': 'travelgo.discovery.release.v2',
    'schemaVersion': 2,
    'version': 2,
    'preparedAt': '2026-10-24T10:00:00.000Z',
    'catalogue': {
      'sources': [
        {
          'id': 'src-quynhon-01',
          'title': 'Cổng du lịch Quy Nhơn',
          'publisher': 'Bình Định Tourism',
          'url': 'https://quynhon.travel',
          'checkedAt': '2026-10-24T08:00:00Z',
        }
      ],
      'destinations': [
        {
          'id': 'dest-quy-nhon-123',
          'name': 'Quy Nhơn',
          'slug': 'quy-nhon',
          'region': 'Miền Trung',
          'places': [
            {
              'id': 'dest-quy-nhon-123/eo-gio',
              'destinationId': 'dest-quy-nhon-123',
              'name': 'Eo Gió',
              'slug': 'eo-gio',
              'latitude': 13.78,
              'longitude': 109.22,
              'sourceRefs': ['src-quynhon-01'],
            },
            {
              'id': 'dest-quy-nhon-123/ky-co',
              'destinationId': 'dest-quy-nhon-123',
              'name': 'Kỳ Co',
              'slug': 'ky-co',
              'latitude': null,
              'longitude': null,
              'sourceRefs': ['src-quynhon-01'],
            },
          ],
          'sample': {
            'id': 'sample-quynhon',
            'days': [],
            'editorialReview': {
              'reviewer': 'TravelGO',
              'reviewedAt': '2026-10-24T00:00:00Z',
            },
            'warnings': [],
          },
        }
      ],
    },
    'visitDetails': {
      'sources': [
        {
          'id': 'src-quynhon-01',
          'title': 'Cổng du lịch Quy Nhơn',
          'publisher': 'Bình Định Tourism',
          'url': 'https://quynhon.travel',
          'checkedAt': '2026-10-24T08:00:00Z',
        }
      ],
      'packages': [],
      'places': [
        {
          'placeId': 'dest-quy-nhon-123/eo-gio',
          'visitScopeLabel': 'Điểm tham quan',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-quynhon-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
          'hours': {
            'status': 'unverified',
            'rules': [],
            'notes': ['Chưa xác minh'],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-quynhon-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
        },
        {
          'placeId': 'dest-quy-nhon-123/ky-co',
          'visitScopeLabel': 'Bãi biển',
          'price': {
            'status': 'unverified',
            'options': [],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-quynhon-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
          'hours': {
            'status': 'unverified',
            'rules': [],
            'notes': ['Chưa xác minh'],
            'evidence': {
              'reviewState': 'unverified',
              'sourceIds': ['src-quynhon-01'],
              'conditions': ['Chưa xác minh'],
              'unresolvedIssues': ['Chưa có thông tin'],
            },
          },
        },
      ],
    },
  };

  final fixtureText = jsonEncode(bundle);
  final rawBytes = utf8.encode(fixtureText);
  final computedSha = sha256.convert(rawBytes).toString();

  final manifest = DiscoveryManifest(
    contract: 'travelgo.discovery.manifest.v2',
    schemaVersion: 2,
    version: 2,
    objectKey: 'releases/v2/2.json',
    sha256: computedSha,
    byteLength: rawBytes.length,
    publishedAt: DateTime.parse('2026-10-24T10:00:00Z'),
  );

  return PublicCatalogueParser.parse(
    payloadText: fixtureText,
    manifest: manifest,
    now: DateTime.parse('2026-10-24T12:00:00Z'),
    origin: 'test',
  );
}

class FakePublicCatalogueProvider extends ChangeNotifier
    implements PublicCatalogueProvider {
  final PublicCatalogueSnapshot _testSnapshot;

  FakePublicCatalogueProvider(this._testSnapshot);

  @override
  PublicCatalogueSnapshot? get snapshot => _testSnapshot;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  DateTime? get lastRefreshedAt => DateTime.now();

  @override
  PublicCatalogueRepository get repository => throw UnimplementedError();

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> onResume() async {}
}

void main() {
  group('ManualPlaceLocations Dynamic Snapshot Tests', () {
    final snapshot = makeTestReleaseSnapshot();

    test('locates dynamic place with valid coordinates in published snapshot', () {
      final loc = ManualPlaceLocations.find(
        'dest-quy-nhon-123/eo-gio',
        snapshot: snapshot,
      );
      expect(loc, isNotNull);
      expect(loc!.placeId, 'dest-quy-nhon-123/eo-gio');
      expect(loc.position.latitude, closeTo(13.78, 0.001));
      expect(loc.position.longitude, closeTo(109.22, 0.001));
      expect(loc.sourceUrl, 'https://quynhon.travel');
      expect(loc.checkedAt, '2026-10-24');
    });

    test('does not fabricate coordinates for place lacking lat/lng in snapshot', () {
      final loc = ManualPlaceLocations.find(
        'dest-quy-nhon-123/ky-co',
        snapshot: snapshot,
      );
      expect(loc, isNull);
    });

    test('preserves legacy static places when not superseded', () {
      final loc = ManualPlaceLocations.find(
        'ha-noi/hoan-kiem',
        snapshot: snapshot,
      );
      expect(loc, isNotNull);
      expect(loc!.position.latitude, closeTo(21.0288, 0.001));
    });
  });

  group('ManualPlannerEntryScreen Integration', () {
    testWidgets('renders ManualPlannerScreen with dynamic snapshot destinations',
        (tester) async {
      await tester.runAsync(() => repository.run((ctx) async {
        final snapshot = makeTestReleaseSnapshot();
        final pubProvider = FakePublicCatalogueProvider(snapshot);

        final inputProvider = PlannerInputProvider();
        inputProvider.setCalendarRange('2026-11-01', '2026-11-03');

        final bundle = flow.resources(ctx);
        final runtime = ManualPlannerRuntime(
          factory: () async => bundle,
        );

        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PublicCatalogueProvider>.value(
                  value: pubProvider,
                ),
                ChangeNotifierProvider<PlannerInputProvider>.value(
                  value: inputProvider,
                ),
                Provider<ManualPlannerRuntime>.value(
                  value: runtime,
                ),
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
          await tester.pumpAndSettle();

          expect(find.byType(ManualPlannerScreen), findsOneWidget);
          final manualScreen = tester.widget<ManualPlannerScreen>(
            find.byType(ManualPlannerScreen),
          );
          expect(
            manualScreen.destinations.any((d) => d.id == 'dest-quy-nhon-123'),
            isTrue,
          );
          expect(
            manualScreen.snapshot?.catalogue.destinations.any((d) => d.id == 'dest-quy-nhon-123'),
            isTrue,
          );
        } finally {
          bundle.dispose();
          inputProvider.dispose();
          pubProvider.dispose();
        }
      }));
    });
  });
}
