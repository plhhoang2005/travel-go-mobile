import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/presentation/screens/place_reviews_list_screen.dart';
import 'package:travelgo_mobile/features/reviews/providers/place_reviews_provider.dart';
import 'package:travelgo_mobile/features/reviews/services/review_service.dart';

class _ScreenReviewService extends ReviewService {
  _ScreenReviewService(this.items) : super();
  final List<PlaceReview> items;

  @override
  Future<List<PlaceReview>> fetchReviews(String placeId) async => items;
}

Widget _screenWith(List<PlaceReview> reviews) {
  final provider = PlaceReviewsProvider(service: _ScreenReviewService(reviews));
  return MaterialApp(
    home: PlaceReviewsListScreen(
      placeId: 'p1',
      placeName: 'Hồ Xuân Hương',
      provider: provider,
    ),
  );
}

void main() {
  testWidgets('review screen renders title, filters and review cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screenWith([
        PlaceReview(
          id: '1',
          placeId: 'p1',
          userId: 'u1',
          userName: 'An',
          rating: 5,
          comment: 'Rất đẹp',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Hồ Xuân Hương'), findsWidgets);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '5 sao'), findsOneWidget);
    expect(find.text('Rất đẹp'), findsOneWidget);
  });

  testWidgets('five-star filter only shows five-star comments', (tester) async {
    await tester.pumpWidget(
      _screenWith([
        PlaceReview(
          id: '1',
          placeId: 'p1',
          userId: 'u1',
          userName: 'An',
          rating: 5,
          comment: 'Năm sao',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
        PlaceReview(
          id: '2',
          placeId: 'p1',
          userId: 'u2',
          userName: 'Bình',
          rating: 3,
          comment: 'Ba sao',
          createdAt: DateTime.utc(2026, 10, 2),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '5 sao'));
    await tester.pump();

    expect(find.text('Năm sao'), findsOneWidget);
    expect(find.text('Ba sao'), findsNothing);
  });
}
