class PlaceReview {
  final String id;
  final String placeId;
  final String reviewerId;
  final String reviewerDisplayName;
  final int rating;
  final String content;
  final DateTime createdAt;

  const PlaceReview({
    required this.id,
    required this.placeId,
    required this.reviewerId,
    required this.reviewerDisplayName,
    required this.rating,
    required this.content,
    required this.createdAt,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'];
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    if (json['id'] is! String ||
        json['place_id'] is! String ||
        json['reviewer_id'] is! String ||
        json['reviewer_display_name'] is! String ||
        rating is! int ||
        rating < 1 ||
        rating > 5 ||
        json['content'] is! String ||
        createdAt == null) {
      throw const FormatException('Invalid place review payload.');
    }
    return PlaceReview(
      id: json['id'] as String,
      placeId: json['place_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      reviewerDisplayName: json['reviewer_display_name'] as String,
      rating: rating,
      content: json['content'] as String,
      createdAt: createdAt.toUtc(),
    );
  }
}

class PlaceReviewSummary {
  final int count;
  final double average;

  const PlaceReviewSummary({required this.count, required this.average});

  factory PlaceReviewSummary.fromReviews(Iterable<PlaceReview> reviews) {
    var count = 0;
    var total = 0;
    for (final review in reviews) {
      count++;
      total += review.rating;
    }
    return PlaceReviewSummary(
      count: count,
      average: count == 0 ? 0 : total / count,
    );
  }
}
