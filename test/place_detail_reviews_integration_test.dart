import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:travelgo_mobile/features/explore/presentation/screens/destination_detail_screen.dart';
import 'package:travelgo_mobile/features/explore/services/catalogue_parser.dart';
import 'package:travelgo_mobile/features/reviews/models/place_review.dart';
import 'package:travelgo_mobile/features/reviews/services/review_service.dart';

import 'catalogue_parser_test.dart' show catalogueData;

class _EmptyReviewService extends ReviewService {
  _EmptyReviewService() : super();

  @override
  Future<List<PlaceReview>> fetchReviews(String placeId) async => const [];
}

void main() {
  testWidgets(
    'destination detail includes review summary for catalogue places',
    (tester) async {
      final catalogue = CatalogueParser().parse(jsonEncode(catalogueData()));
      await tester.pumpWidget(
        Provider<ReviewService>.value(
          value: _EmptyReviewService(),
          child: MaterialApp(
            home: DestinationDetailScreen(
              catalogue: catalogue,
              destination: catalogue.destinations.first,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đánh giá '), findsWidgets);
      expect(find.text('Chưa có đánh giá nào cho địa điểm này.'), findsWidgets);
    },
  );
}
