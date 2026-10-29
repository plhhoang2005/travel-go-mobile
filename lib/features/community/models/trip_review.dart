class TripReview {
  final String id;
  final String tripId;
  final String userId;
  final String userName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TripReview({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
  }) : assert(rating >= 1 && rating <= 5, 'Điểm đánh giá phải từ 1 đến 5 sao.');

  factory TripReview.fromJson(Map<String, dynamic> json) {
    final rawRating = json['rating'];
    final parsedRating = rawRating is int
        ? rawRating
        : (rawRating is num ? rawRating.toInt() : 5);

    return TripReview(
      id: json['id'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Thành viên TravelGO',
      rating: parsedRating.clamp(1, 5),
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'trip_id': tripId,
      'user_id': userId,
      'user_name': userName,
      'rating': rating,
      'comment': comment,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }
    return map;
  }

  TripReview copyWith({
    String? id,
    String? tripId,
    String? userId,
    String? userName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripReview(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
