import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';

void main() {
  test('ReviewSummary rounds average and computes every star ratio', () {
    final reviews = [
      PlaceReview(
        id: '1',
        placeId: 'da-nang/my-khe',
        userId: 'u1',
        userName: 'An',
        rating: 5,
        comment: 'Đẹp',
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      PlaceReview(
        id: '2',
        placeId: 'da-nang/my-khe',
        userId: 'u2',
        userName: 'Bình',
        rating: 5,
        comment: 'Tuyệt',
        createdAt: DateTime.utc(2026, 10, 2),
      ),
      PlaceReview(
        id: '3',
        placeId: 'da-nang/my-khe',
        userId: 'u3',
        userName: 'Chi',
        rating: 4,
        comment: 'Khá tốt',
        createdAt: DateTime.utc(2026, 10, 3),
      ),
    ];

    final summary = ReviewSummary.fromReviews(reviews);

    expect(summary.totalCount, 3);
    expect(summary.averageRating, 4.7);
    expect(summary.ratioFor(5), closeTo(2 / 3, 0.001));
    expect(summary.ratioFor(4), closeTo(1 / 3, 0.001));
    expect(summary.ratioFor(1), 0);
  });

  test('PlaceReview rejects ratings outside one through five', () {
    expect(
      () => PlaceReview(
        id: '1',
        placeId: 'p1',
        userId: 'u1',
        userName: 'An',
        rating: 0,
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => PlaceReview.fromJson({
        'id': '1',
        'place_id': 'p1',
        'user_id': 'u1',
        'user_name': 'An',
        'rating': 6,
        'created_at': '2026-10-01T00:00:00Z',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'ReviewSummary handles an empty place without inventing zero-star reviews',
    () {
      final summary = ReviewSummary.fromReviews(const []);

      expect(summary.totalCount, 0);
      expect(summary.averageRating, isNull);
      expect(summary.ratioFor(5), 0);
    },
  );
}
