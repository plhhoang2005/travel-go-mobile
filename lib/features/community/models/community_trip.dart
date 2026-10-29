class CommunityTrip {
  final String id;
  final String title;
  final String destination;
  final int? daysCount;
  final double? estimatedCostVnd;
  final String authorId;
  final String? authorName;
  final bool isPublic;
  final int likeCount;
  final double averageRating;
  final int reviewCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final Map<String, dynamic> tripData;
  final DateTime? createdAt;

  const CommunityTrip({
    required this.id,
    required this.title,
    required this.destination,
    this.daysCount,
    this.estimatedCostVnd,
    required this.authorId,
    this.authorName,
    this.isPublic = false,
    this.likeCount = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.startDate,
    this.endDate,
    this.status = 'planning',
    this.tripData = const {},
    this.createdAt,
  });

  // Getters tương thích với schema trips và model SavedTrip
  String get userId => authorId;
  String get destinationName => destination;
  int? get numDays => daysCount;
  double? get budgetTotal => estimatedCostVnd;
  Map<String, dynamic> get aiPlanData => tripData;

  factory CommunityTrip.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['ai_plan_data'] ??
        json['trip_plan_data'] ??
        json['trip_data'];
    final planMap = rawPlan is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawPlan)
        : (rawPlan is Map
            ? Map<String, dynamic>.from(rawPlan)
            : <String, dynamic>{});

    final numDaysRaw = json['num_days'] ?? json['days_count'];
    final budgetRaw = json['budget_total'] ?? json['estimated_cost_vnd'];
    final ratingRaw = json['average_rating'] ?? json['rating'];

    return CommunityTrip(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      destination: (json['destination_name'] ?? json['destination'] ?? '')
          as String,
      daysCount: numDaysRaw is int
          ? numDaysRaw
          : (numDaysRaw is num ? numDaysRaw.toInt() : null),
      estimatedCostVnd: budgetRaw is num ? budgetRaw.toDouble() : null,
      authorId: (json['user_id'] ?? json['author_id'] ?? '') as String,
      authorName: json['author_name'] as String?,
      isPublic: json['is_public'] is bool ? json['is_public'] as bool : false,
      likeCount: json['like_count'] is int
          ? json['like_count'] as int
          : (json['like_count'] is num ? (json['like_count'] as num).toInt() : 0),
      averageRating: ratingRaw is num ? ratingRaw.toDouble() : 0.0,
      reviewCount: json['review_count'] is int
          ? json['review_count'] as int
          : (json['review_count'] is num
              ? (json['review_count'] as num).toInt()
              : 0),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      status: json['status'] as String? ?? 'planning',
      tripData: planMap,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'user_id': authorId,
      'title': title,
      'destination_name': destination,
      'num_days': daysCount,
      'budget_total': estimatedCostVnd,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'is_public': isPublic,
      'author_name': authorName,
      'like_count': likeCount,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'ai_plan_data': tripData,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  CommunityTrip copyWith({
    String? id,
    String? title,
    String? destination,
    int? daysCount,
    double? estimatedCostVnd,
    String? authorId,
    String? authorName,
    bool? isPublic,
    int? likeCount,
    double? averageRating,
    int? reviewCount,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    Map<String, dynamic>? tripData,
    DateTime? createdAt,
  }) {
    return CommunityTrip(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      daysCount: daysCount ?? this.daysCount,
      estimatedCostVnd: estimatedCostVnd ?? this.estimatedCostVnd,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      isPublic: isPublic ?? this.isPublic,
      likeCount: likeCount ?? this.likeCount,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      tripData: tripData ?? this.tripData,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
