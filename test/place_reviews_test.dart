import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/presentation/screens/place_reviews_screen.dart';
import 'package:travelgo_mobile/features/reviews/presentation/widgets/rating_stars_widget.dart';
import 'package:travelgo_mobile/features/reviews/providers/place_reviews_provider.dart';
import 'package:travelgo_mobile/features/reviews/services/place_reviews_service.dart';

PlaceReview review(String id, int rating, {String placeId = 'place/a'}) =>
    PlaceReview(
      id: id,
      placeId: placeId,
      reviewerId: 'user-$id',
      reviewerDisplayName: 'Reviewer $id',
      rating: rating,
      content: 'Review $id',
      createdAt: DateTime.utc(2026, 10, rating),
    );

class FakeReviewsRepository implements PlaceReviewsRepository {
  List<PlaceReview> items;
  Completer<List<PlaceReview>>? pendingFetch;
  PlaceReview? created;
  PlaceReviewFailure? createFailure;
  int fetchCalls = 0;

  FakeReviewsRepository(this.items);

  @override
  Future<List<PlaceReview>> fetchForPlace(String placeId) {
    fetchCalls++;
    return pendingFetch?.future ?? Future.value(items);
  }

  @override
  Future<PlaceReview> create({
    required String placeId,
    required int rating,
    required String content,
  }) async {
    if (createFailure case final failure?) throw failure;
    return created ?? review('created', rating, placeId: placeId);
  }
}

void main() {
  test('model parses strict payload and summary is exact', () {
    final parsed = PlaceReview.fromJson({
      'id': 'r1',
      'place_id': 'place/a',
      'reviewer_id': 'u1',
      'reviewer_display_name': 'Minh',
      'rating': 4,
      'content': 'Tốt',
      'created_at': '2026-10-31T01:02:03Z',
    });
    expect(parsed.rating, 4);
    expect(parsed.createdAt.isUtc, true);
    final summary = PlaceReviewSummary.fromReviews([parsed, review('r2', 2)]);
    expect(summary.count, 2);
    expect(summary.average, 3);
    expect(
      () => PlaceReview.fromJson({
        'id': 'bad',
        'place_id': 'place/a',
        'reviewer_id': 'u1',
        'reviewer_display_name': 'Minh',
        'rating': 6,
        'content': 'Bad',
        'created_at': '2026-10-31T01:02:03Z',
      }),
      throwsFormatException,
    );
  });

  test(
    'provider keeps aggregate stable while filtering visible reviews',
    () async {
      final repository = FakeReviewsRepository([
        review('a', 5),
        review('b', 3),
      ]);
      final provider = PlaceReviewsProvider(
        repository: repository,
        placeId: 'place/a',
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(provider.summary.count, 2);
      expect(provider.summary.average, 4);
      provider.setRatingFilter(5);
      expect(provider.visibleReviews.map((item) => item.rating), [5]);
      expect(provider.summary.count, 2);
    },
  );

  test(
    'failed submit retains loaded reviews and exposes actionable error',
    () async {
      final repository = FakeReviewsRepository([review('a', 5)])
        ..createFailure = const PlaceReviewFailure('network_error');
      final provider = PlaceReviewsProvider(
        repository: repository,
        placeId: 'place/a',
      );
      addTearDown(provider.dispose);
      await provider.load();
      expect(
        await provider.submit(rating: 4, content: 'Không mất nội dung'),
        false,
      );
      expect(provider.errorCode, 'network_error');
      expect(provider.reviews.single.id, 'a');
    },
  );

  test('disposing provider ignores a late response', () async {
    final repository = FakeReviewsRepository([])
      ..pendingFetch = Completer<List<PlaceReview>>();
    final provider = PlaceReviewsProvider(
      repository: repository,
      placeId: 'place/a',
    );
    final pending = provider.load();
    provider.dispose();
    repository.pendingFetch!.complete([review('late', 5)]);
    await pending;
  });

  testWidgets('interactive stars expose five 48dp targets and callback', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RatingStarsWidget(
            rating: selected.toDouble(),
            onRatingChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNWidgets(5));
    for (var value = 1; value <= 5; value++) {
      final target = find.byKey(ValueKey('rating-star-$value'));
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.byKey(const ValueKey('rating-star-4')));
    expect(selected, 4);
  });

  testWidgets('read-only stars support fractional rating semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RatingStarsWidget(rating: 4.5))),
      );
      expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Đánh giá 4.5 trên 5 sao'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('all reviews screen filters without changing aggregate', (
    tester,
  ) async {
    final repository = FakeReviewsRepository([
      review('five', 5),
      review('three', 3),
    ]);
    final provider = PlaceReviewsProvider(
      repository: repository,
      placeId: 'place/a',
    );
    addTearDown(provider.dispose);
    await provider.load();
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceReviewsScreen(placeName: 'Test place', provider: provider),
      ),
    );
    expect(find.text('Review five'), findsOneWidget);
    expect(find.text('Review three'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '5 sao'));
    await tester.pump();
    expect(find.text('Review five'), findsOneWidget);
    expect(find.text('Review three'), findsNothing);
    expect(provider.summary.count, 2);
    expect(provider.summary.average, 4);
  });
}
