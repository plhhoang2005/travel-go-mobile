import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/providers/place_reviews_provider.dart';
import 'package:travelgo_mobile/features/reviews/services/review_service.dart';

class _FakeReviewService extends ReviewService {
  _FakeReviewService() : super();

  final Map<String, List<PlaceReview>> reviewsByPlace = {};
  Completer<List<PlaceReview>>? nextFetch;
  bool authenticated = true;
  int submitCount = 0;

  @override
  bool get canSubmit => authenticated;

  @override
  Future<List<PlaceReview>> fetchReviews(String placeId) {
    final pending = nextFetch;
    if (pending != null) {
      nextFetch = null;
      return pending.future;
    }
    return Future.value(reviewsByPlace[placeId] ?? const []);
  }

  @override
  Future<PlaceReview> submitReview({
    required String placeId,
    required int rating,
    required String comment,
    String? expectedUserId,
  }) async {
    submitCount++;
    final review = PlaceReview(
      id: '$submitCount',
      placeId: placeId,
      userId: 'u1',
      userName: 'An',
      rating: rating,
      comment: comment,
      createdAt: DateTime.utc(2026, 10, 29),
    );
    reviewsByPlace.putIfAbsent(placeId, () => []).insert(0, review);
    return review;
  }
}

void main() {
  test('provider filters reviews locally without a second request', () async {
    final service = _FakeReviewService()
      ..reviewsByPlace['p1'] = [
        PlaceReview(
          id: '1',
          placeId: 'p1',
          userId: 'u1',
          userName: 'An',
          rating: 5,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
        PlaceReview(
          id: '2',
          placeId: 'p1',
          userId: 'u2',
          userName: 'Bình',
          rating: 4,
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      ];
    final provider = PlaceReviewsProvider(service: service);
    addTearDown(provider.dispose);

    await provider.load('p1');
    provider.setFilter(5);

    expect(provider.visibleReviews, hasLength(1));
    expect(provider.visibleReviews.single.rating, 5);
    expect(provider.summary.totalCount, 2);
  });

  test(
    'late response from an old place cannot replace the current place',
    () async {
      final service = _FakeReviewService();
      final provider = PlaceReviewsProvider(service: service);
      addTearDown(provider.dispose);
      final oldResult = Completer<List<PlaceReview>>();
      service.nextFetch = oldResult;

      final oldLoad = provider.load('old-place');
      await Future<void>.delayed(Duration.zero);
      service.reviewsByPlace['new-place'] = [
        PlaceReview(
          id: 'new',
          placeId: 'new-place',
          userId: 'u2',
          userName: 'Bình',
          rating: 4,
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      ];
      await provider.load('new-place');
      oldResult.complete([
        PlaceReview(
          id: 'old',
          placeId: 'old-place',
          userId: 'u1',
          userName: 'An',
          rating: 1,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ]);
      await oldLoad;

      expect(provider.placeId, 'new-place');
      expect(provider.reviews.single.id, 'new');
    },
  );

  test('duplicate submit taps dispatch only one request', () async {
    final service = _FakeReviewService();
    final provider = PlaceReviewsProvider(service: service);
    addTearDown(provider.dispose);

    final first = provider.submit(placeId: 'p1', rating: 5, comment: 'Tốt');
    final second = provider.submit(placeId: 'p1', rating: 5, comment: 'Tốt');
    await Future.wait([first, second]);

    expect(service.submitCount, 1);
  });

  test('account switch invalidates an in-flight place load', () async {
    final service = _FakeReviewService();
    final provider = PlaceReviewsProvider(service: service);
    addTearDown(provider.dispose);
    final pending = Completer<List<PlaceReview>>();
    service.nextFetch = pending;
    provider.bindAuthContext(userId: 'user-a', authEpoch: 1);
    final load = provider.load('p1');
    provider.bindAuthContext(userId: 'user-b', authEpoch: 2);
    pending.complete([
      PlaceReview(
        id: 'old',
        placeId: 'p1',
        userId: 'user-a',
        userName: 'An',
        rating: 5,
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    ]);
    await load;

    expect(provider.reviews, isEmpty);
    expect(provider.placeId, isNull);
  });
}
