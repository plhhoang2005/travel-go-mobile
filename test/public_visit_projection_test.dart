// Tests for VisitCatalogue.fromPublicProjection bridge without weakening V1 invariants.

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/explore/models/place_visit_details.dart';

void main() {
  group('VisitCatalogue.fromPublicProjection (Task P4a)', () {
    final now = DateTime.utc(2026, 10, 23, 12, 0);

    test('public_projection_preserves_unknown_and_rejects_orphans', () {
      final validSource = {
        'id': 'src-01',
        'title': 'Cổng du lịch',
        'publisher': 'Sở Du lịch',
        'url': 'https://example.com/source',
        'checkedAt': '2026-10-20T08:00:00Z',
      };

      final validPlaceData = {
        'sources': [validSource],
        'packages': [],
        'places': [
          {
            'placeId': 'da-nang/ba-na-hills',
            'visitScopeLabel': 'Khu du lịch',
            'price': {
              'status': 'unverified',
              'options': [],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': ['src-01'],
                'conditions': ['Chưa xác minh'],
                'unresolvedIssues': ['Chưa có thông tin giá'],
              },
            },
            'hours': {
              'status': 'unverified',
              'rules': [],
              'notes': ['Chưa xác minh giờ'],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': ['src-01'],
                'conditions': ['Chưa xác minh'],
                'unresolvedIssues': ['Chưa có thông tin giờ'],
              },
            },
          },
        ],
      };

      // 1. Valid projection parsing
      final result = VisitCatalogue.fromPublicProjection(
        version: 1,
        publishedAt: DateTime.utc(2026, 10, 23, 10, 0),
        releaseSha256: 'a' * 64,
        data: validPlaceData,
        expectedPlaceIds: {'da-nang/ba-na-hills'},
        now: now,
      );

      // Invariant: bindingKind is release_v2
      expect(result.bindingKind, 'release_v2');
      expect(result.version, 1);
      expect(result.places.length, 1);
      expect(result.places['da-nang/ba-na-hills']!.price.status, 'unverified');

      // 2. Orphan place (in data but NOT in expectedPlaceIds) MUST throw
      expect(
        () => VisitCatalogue.fromPublicProjection(
          version: 1,
          publishedAt: DateTime.utc(2026, 10, 23, 10, 0),
          releaseSha256: 'a' * 64,
          data: validPlaceData,
          expectedPlaceIds: {'different-place-id'},
          now: now,
        ),
        throwsA(isA<VisitDataException>()),
      );

      // 3. Reviewed status lacking reviewed evidence MUST throw
      final invalidReviewedPlaceData = {
        'sources': [validSource],
        'packages': [],
        'places': [
          {
            'placeId': 'da-nang/ba-na-hills',
            'visitScopeLabel': 'Khu du lịch',
            'price': {
              'status': 'priced',
              'options': [
                {
                  'id': 'opt-1',
                  'label': 'Vé người lớn',
                  'audience': 'adult',
                  'amountVnd': 900000,
                  'currency': 'VND',
                  'unit': 'person',
                }
              ],
              'evidence': {
                'reviewState': 'unverified', // Claims priced but evidence is unverified!
                'sourceIds': ['src-01'],
                'conditions': [],
                'unresolvedIssues': [],
              },
            },
            'hours': {
              'status': 'no_fixed_hours',
              'notes': ['Tự do'],
              'evidence': {
                'reviewState': 'unverified',
                'sourceIds': ['src-01'],
                'conditions': ['Tự do'],
                'unresolvedIssues': [],
              },
            },
          },
        ],
      };

      expect(
        () => VisitCatalogue.fromPublicProjection(
          version: 1,
          publishedAt: DateTime.utc(2026, 10, 23, 10, 0),
          releaseSha256: 'a' * 64,
          data: invalidReviewedPlaceData,
          expectedPlaceIds: {'da-nang/ba-na-hills'},
          now: now,
        ),
        throwsA(isA<VisitDataException>()),
      );
    });
  });
}
