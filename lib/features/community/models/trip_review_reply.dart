class TripReviewReply {
  final String id;
  final String tripId;
  final String reviewId;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;

  const TripReviewReply({
    required this.id,
    required this.tripId,
    required this.reviewId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
  });

  factory TripReviewReply.fromJson(Map<String, dynamic> json) {
    return TripReviewReply(
      id: json['id'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      reviewId: json['review_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Thành viên TravelGO',
      comment: json['comment'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String)?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'trip_id': tripId,
      'review_id': reviewId,
      'user_id': userId,
      'user_name': userName,
      'comment': comment,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  TripReviewReply copyWith({
    String? id,
    String? tripId,
    String? reviewId,
    String? userId,
    String? userName,
    String? comment,
    DateTime? createdAt,
  }) {
    return TripReviewReply(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      reviewId: reviewId ?? this.reviewId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
