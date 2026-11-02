import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/services/review_service.dart';

void main() {
  test('service rejects invalid place IDs before network access', () async {
    final service = ReviewService(placeValidator: (id) => id == 'p1');

    expect(
      () => service.fetchReviews('unknown'),
      throwsA(isA<ReviewException>()),
    );
  });

  test('service rejects unauthenticated submissions', () async {
    final service = ReviewService(placeValidator: (_) => true);

    expect(
      () => service.submitReview(placeId: 'p1', rating: 5, comment: 'Tốt'),
      throwsA(isA<ReviewException>()),
    );
  });
}
