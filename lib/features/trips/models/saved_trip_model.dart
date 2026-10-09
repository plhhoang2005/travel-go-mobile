class SavedTrip {
  final String id;
  final String userId;
  final String title;
  final String destinationName;
  final int numDays;
  final double budgetTotal;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final Map<String, dynamic> tripPlanData;
  final DateTime createdAt;

  const SavedTrip({
    required this.id,
    required this.userId,
    required this.title,
    required this.destinationName,
    this.numDays = 3,
    this.budgetTotal = 0,
    this.startDate,
    this.endDate,
    this.status = 'planning',
    required this.tripPlanData,
    required this.createdAt,
  });

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['ai_plan_data'] ?? json['trip_plan_data'];
    final planMap = rawPlan is Map<String, dynamic>
        ? rawPlan
        : (rawPlan is Map ? Map<String, dynamic>.from(rawPlan) : <String, dynamic>{});

    return SavedTrip(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      destinationName: json['destination_name'] as String? ?? '',
      numDays: (json['num_days'] as num?)?.toInt() ?? 3,
      budgetTotal: (json['budget_total'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      status: json['status'] as String? ?? 'planning',
      tripPlanData: planMap,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'destination_name': destinationName,
      'num_days': numDays,
      'budget_total': budgetTotal,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'ai_plan_data': tripPlanData,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toLegacyJson() {
    final map = toJson(includeId: id.isNotEmpty);
    map['trip_plan_data'] = tripPlanData;
    return map;
  }
}
