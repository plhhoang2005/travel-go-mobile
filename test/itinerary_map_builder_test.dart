import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/catalogue_reference.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/map/services/itinerary_map_builder.dart';
import 'package:travelgo_mobile/features/trip_planner/models/planner_result_snapshot.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_request.dart';
import 'package:travelgo_mobile/features/trip_planner/models/trip_response.dart';
import 'package:travelgo_mobile/features/trips/models/trip_payload_codec.dart';

void main() {
  group('ItineraryMapBuilder Matching and Scoping Tests', () {
    late PublicCatalogueSnapshot snapshot;
    late PlannerResultSnapshot result;

    setUp(() {
      snapshot = PublicCatalogueSnapshot(
        version: 2,
        sha256: 'a' * 64,
        origin: 'test',
        manifest: DiscoveryManifest(
          contract: 'travelgo.discovery.manifest.v2',
          schemaVersion: 2,
          version: 2,
          objectKey: 'releases/v2/2.json',
          sha256: 'a' * 64,
          byteLength: 500,
          publishedAt: DateTime.parse('2026-10-24T00:00:00Z'),
        ),
        catalogue: CatalogueReference(
          checkedAt: '2026-10-24',
          sources: [
            const SourceReference(
              id: 'src-1',
              title: 'Source 1',
              url: 'https://test.example',
              publisher: 'Test Publisher',
              checkedAt: '2026-10-24',
            ),
          ],
          destinations: [
            DestinationReference(
              id: 'hue',
              name: 'Huế',
              region: 'Miền Trung',
              places: const [
                PlaceReference(
                  id: 'hue/dai-noi',
                  destinationId: 'hue',
                  name: 'Đại Nội Huế',
                  sourceId: 'src-1',
                  latitude: 16.469,
                  longitude: 107.577,
                ),
                PlaceReference(
                  id: 'hue/thien-mu',
                  destinationId: 'hue',
                  name: 'Chùa Thiên Mụ',
                  sourceId: 'src-1',
                  latitude: 16.453,
                  longitude: 107.545,
                ),
                PlaceReference(
                  id: 'hue/dong-ba',
                  destinationId: 'hue',
                  name: 'Chợ Đông Ba',
                  sourceId: 'src-1',
                  latitude: 16.471,
                  longitude: 107.588,
                ),
                PlaceReference(
                  id: 'hue/dup-1',
                  destinationId: 'hue',
                  name: 'Cà phê bờ sông',
                  sourceId: 'src-1',
                  latitude: 16.460,
                  longitude: 107.580,
                ),
                PlaceReference(
                  id: 'hue/dup-2',
                  destinationId: 'hue',
                  name: 'Cà phê bờ sông',
                  sourceId: 'src-1',
                  latitude: 16.465,
                  longitude: 107.585,
                ),
              ],
              sample: SampleReference(
                id: 'sample-hue',
                editorialReview: EditorialReview(
                  status: 'unverified',
                  reviewedAt: '2026-10-24',
                  sourceIds: const [],
                  conditions: const [],
                  reviewNotes: const [],
                ),
                days: [],
                warnings: [],
              ),
            ),
            DestinationReference(
              id: 'da-nang',
              name: 'Đà Nẵng',
              region: 'Miền Trung',
              places: const [
                PlaceReference(
                  id: 'da-nang/cau-rong',
                  destinationId: 'da-nang',
                  name: 'Cầu Rồng',
                  sourceId: 'src-1',
                  latitude: 16.061,
                  longitude: 108.227,
                ),
                PlaceReference(
                  id: 'da-nang/chua-thien-mu',
                  destinationId: 'da-nang',
                  name: 'Chùa Thiên Mụ Quán',
                  sourceId: 'src-1',
                  latitude: 16.050,
                  longitude: 108.220,
                ),
              ],
              sample: SampleReference(
                id: 'sample-danang',
                editorialReview: EditorialReview(
                  status: 'unverified',
                  reviewedAt: '2026-10-24',
                  sourceIds: const [],
                  conditions: const [],
                  reviewNotes: const [],
                ),
                days: [],
                warnings: [],
              ),
            ),
          ],
        ),
        visits: VisitCatalogue.fromPublicProjection(
          version: 2,
          publishedAt: DateTime.parse('2026-10-24T00:00:00Z'),
          releaseSha256: 'a' * 64,
          data: {
            'sources': [],
            'packages': [],
            'places': [],
          },
          expectedPlaceIds: {},
          now: DateTime.parse('2026-10-24T01:00:00Z'),
        ),
        fetchedAt: DateTime.now(),
      );

      final request = PlanTripRequest(
        origin: 'TP. Hồ Chí Minh',
        numDays: 3,
        numPeople: 2,
        budgetVnd: 5000000,
        preferences: ['culture'],
        priority: 'balanced',
        destinationId: 'hue',
        destinationName: 'Huế',
        startDate: '2026-11-01',
        endDate: '2026-11-03',
      );

      final plan = PlanTripResponse(
        winnerId: 'hue',
        topDestinations: [
          DestinationCard(
            id: 'hue',
            name: 'Huế',
            totalScore: 9.0,
            normalizedScores: const {},
            scoreContributions: const {},
            estimatedCostVnd: 4500000,
            weatherSource: 'test',
            avgTempMax: 27.0,
            avgPrecipitation: 0.1,
            region: 'Miền Trung',
          ),
        ],
        transportOptions: [],
        itineraryDays: [
          ItineraryDay(
            day: 1,
            title: 'Ngày 1: Cố đô',
            activities: [
              Activity(
                time: '08:00',
                title: 'Đại Nội Huế',
                costVnd: 150000,
                durationHours: 3.0,
              ),
              Activity(
                time: '14:00',
                title: 'Chùa Thiên Mụ',
                costVnd: 0,
                durationHours: 1.5,
              ),
            ],
          ),
          ItineraryDay(
            day: 2,
            title: 'Ngày 2: Chợ và Ẩm thực',
            activities: [
              Activity(
                time: '09:00',
                title: 'Chợ Đông Ba',
                costVnd: 200000,
                durationHours: 2.0,
              ),
              Activity(
                time: '15:00',
                title: 'Cà phê bờ sông', // Ambiguous match in Hue
                costVnd: 50000,
                durationHours: 1.0,
              ),
            ],
          ),
          ItineraryDay(
            day: 3,
            title: 'Ngày 3: Rời đi',
            activities: [
              Activity(
                time: '10:00',
                title: 'Cầu Rồng', // Exists in Đà Nẵng, NOT in Huế!
                costVnd: 0,
                durationHours: 1.0,
              ),
            ],
          ),
        ],
        aiExplanation: 'Lịch trình Huế 3 ngày',
        dataSources: {},
        assumptions: [],
      );

      result = PlannerResultSnapshot(
        request: request,
        metadata: TripMetadataV1(
          destinationId: 'hue',
          destinationName: 'Huế',
          startDate: '2026-11-01',
          endDate: '2026-11-03',
        ),
        plan: plan,
        workspaceGeneration: 1,
      );
    });

    test('exact unique match resolves to catalogueName within destination', () {
      final context = ItineraryMapBuilder.build(
        result: result,
        snapshot: snapshot,
      );

      final day1 = context.activitiesForDay(1);
      expect(day1.length, 2);

      // Đại Nội Huế -> unique match
      expect(day1[0].key, 'day:1/activity:0');
      expect(day1[0].placeId, 'hue/dai-noi');
      expect(day1[0].resolution, 'catalogueName');
      expect(day1[0].isLocated, isTrue);
      expect(day1[0].positionOnMap!.latitude, closeTo(16.469, 0.001));

      // Chùa Thiên Mụ -> unique match
      expect(day1[1].key, 'day:1/activity:1');
      expect(day1[1].placeId, 'hue/thien-mu');
      expect(day1[1].resolution, 'catalogueName');
      expect(day1[1].isLocated, isTrue);
    });

    test('ambiguous duplicate match resolves to unresolved', () {
      final context = ItineraryMapBuilder.build(
        result: result,
        snapshot: snapshot,
      );

      final day2 = context.activitiesForDay(2);
      expect(day2.length, 2);

      // Chợ Đông Ba -> unique match
      expect(day2[0].resolution, 'catalogueName');

      // Cà phê bờ sông -> duplicate in Hue -> unresolved
      expect(day2[1].resolution, 'unresolved');
      expect(day2[1].placeId, isNull);
      expect(day2[1].positionOnMap, isNull);
      expect(day2[1].isLocated, isFalse);
    });

    test('place from different destination is never matched', () {
      final context = ItineraryMapBuilder.build(
        result: result,
        snapshot: snapshot,
      );

      final day3 = context.activitiesForDay(3);
      expect(day3.length, 1);

      // Cầu Rồng only exists in da-nang, current destination is hue -> unresolved
      expect(day3[0].title, 'Cầu Rồng');
      expect(day3[0].resolution, 'unresolved');
      expect(day3[0].placeId, isNull);
      expect(day3[0].positionOnMap, isNull);
    });

    test('user place binding overrides unresolved state when valid', () {
      final context = ItineraryMapBuilder.build(
        result: result,
        snapshot: snapshot,
        userPlaceBindings: {
          'day:2/activity:1': 'hue/dup-1', // User selects one of the duplicates
        },
      );

      final day2 = context.activitiesForDay(2);
      expect(day2[1].resolution, 'user');
      expect(day2[1].placeId, 'hue/dup-1');
      expect(day2[1].isLocated, isTrue);
      expect(day2[1].positionOnMap!.latitude, closeTo(16.460, 0.001));
    });

    test('user place binding to foreign destination place is rejected', () {
      final context = ItineraryMapBuilder.build(
        result: result,
        snapshot: snapshot,
        userPlaceBindings: {
          'day:3/activity:0': 'da-nang/cau-rong', // Foreign destination!
        },
      );

      final day3 = context.activitiesForDay(3);
      expect(day3[0].resolution, 'unresolved');
      expect(day3[0].placeId, isNull);
      expect(day3[0].isLocated, isFalse);
    });

    test('snapshot version and hash getters pass through cleanly', () {
      final context = ItineraryMapBuilder.build(
        result: result,
        snapshot: snapshot,
      );

      expect(context.snapshotVersion, 2);
      expect(context.snapshotSha256, 'a' * 64);
      expect(context.dayNumbers, [1, 2, 3]);
    });
  });
}
