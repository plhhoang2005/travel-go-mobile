class SavedTrip {
  final String id;
  final String userId;
  final String title;
  final String destinationName;
  final int numDays;
  final double budgetTotal;
  final DateTime? startDate;
  final DateTime? endDate;
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
    required this.tripPlanData,
    required this.createdAt,
  });

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
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
      tripPlanData: (json['trip_plan_data'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'destination_name': destinationName,
      'num_days': numDays,
      'budget_total': budgetTotal,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'trip_plan_data': tripPlanData,
    };
  }
}
