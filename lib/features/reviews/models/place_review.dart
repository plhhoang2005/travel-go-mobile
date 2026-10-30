import 'package:flutter/foundation.dart';

@immutable
class PlaceReview {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  PlaceReview({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.rating,
    this.comment,
    required this.createdAt,
  }) {
    if (id.trim().isEmpty ||
        placeId.trim().isEmpty ||
        userId.trim().isEmpty ||
        userName.trim().isEmpty ||
        rating < 1 ||
        rating > 5) {
      throw const FormatException('invalid_place_review');
    }
  }

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final rating = json['rating'];
    if (rating is! int || createdAt == null) {
      throw const FormatException('invalid_place_review_json');
    }
    return PlaceReview(
      id: json['id'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Người dùng TravelGO',
      rating: rating,
      comment: (json['comment'] as String?)?.trim(),
      createdAt: createdAt.toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'place_id': placeId,
    'user_id': userId,
    'user_name': userName,
    'rating': rating,
    'comment': comment,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

@immutable
class ReviewSummary {
  final int totalCount;
  final double? averageRating;
  final Map<int, int> counts;

  const ReviewSummary({
    required this.totalCount,
    required this.averageRating,
    required this.counts,
  });

  factory ReviewSummary.fromReviews(Iterable<PlaceReview> reviews) {
    final list = reviews.toList(growable: false);
    final counts = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
    for (final review in list) {
      counts[review.rating] = (counts[review.rating] ?? 0) + 1;
    }
    final average = list.isEmpty
        ? null
        : _roundOneDecimal(
            list.fold<int>(0, (sum, review) => sum + review.rating) /
                list.length,
          );
    return ReviewSummary(
      totalCount: list.length,
      averageRating: average,
      counts: Map.unmodifiable(counts),
    );
  }

  double ratioFor(int star) =>
      totalCount == 0 ? 0 : (counts[star] ?? 0) / totalCount;

  static double _roundOneDecimal(double value) => (value * 10).round() / 10;
}
