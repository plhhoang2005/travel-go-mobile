class PlanTripRequest {
  final String origin;
  final int numDays;
  final int numPeople;
  final int budgetVnd;
  final List<String> preferences;
  final String priority; // "cheapest", "fastest", "balanced", "comfortable"
  final String? destinationId;
  final String? destinationName;
  final String? startDate;
  final String? endDate;
  final String companionType; // "solo", "couple", "family", "group"

  PlanTripRequest({
    required this.origin,
    required this.numDays,
    required this.numPeople,
    required this.budgetVnd,
    required this.preferences,
    required this.priority,
    this.destinationId,
    this.destinationName,
    this.startDate,
    this.endDate,
    this.companionType = 'group',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'origin': origin,
      'numDays': numDays,
      'numPeople': numPeople,
      'budgetVnd': budgetVnd,
      'preferences': preferences,
      'priority': priority,
    };
    if (destinationId != null) map['destinationId'] = destinationId;
    if (destinationName != null) map['destinationName'] = destinationName;
    if (startDate != null) map['startDate'] = startDate;
    if (endDate != null) map['endDate'] = endDate;
    if (companionType != 'group') map['companionType'] = companionType;
    return map;
  }

  factory PlanTripRequest.fromJson(Map<String, dynamic> json) {
    return PlanTripRequest(
      origin: json['origin'] as String? ?? 'TP. Hồ Chí Minh',
      numDays: json['numDays'] as int? ?? 3,
      numPeople: json['numPeople'] as int? ?? 2,
      budgetVnd: (json['budgetVnd'] as num?)?.toInt() ?? 4000000,
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['biển', 'nghỉ dưỡng'],
      priority: json['priority'] as String? ?? 'balanced',
      destinationId: json['destinationId'] as String?,
      destinationName: json['destinationName'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      companionType: json['companionType'] as String? ?? 'group',
    );
  }

  PlanTripRequest copyWith({
    String? origin,
    int? numDays,
    int? numPeople,
    int? budgetVnd,
    List<String>? preferences,
    String? priority,
    String? destinationId,
    String? destinationName,
    String? startDate,
    String? endDate,
    String? companionType,
  }) {
    return PlanTripRequest(
      origin: origin ?? this.origin,
      numDays: numDays ?? this.numDays,
      numPeople: numPeople ?? this.numPeople,
      budgetVnd: budgetVnd ?? this.budgetVnd,
      preferences: preferences ?? this.preferences,
      priority: priority ?? this.priority,
      destinationId: destinationId ?? this.destinationId,
      destinationName: destinationName ?? this.destinationName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      companionType: companionType ?? this.companionType,
    );
  }

  // Pre-configured Presets according to Persona Minh & Project Requirements
  static PlanTripRequest presetMinh() {
    return PlanTripRequest(
      origin: 'TP. Hồ Chí Minh',
      numDays: 3,
      numPeople: 2,
      budgetVnd: 4000000,
      preferences: ['nghỉ dưỡng', 'ẩm thực', 'biển'],
      priority: 'balanced',
    );
  }

  static PlanTripRequest presetPhuQuoc() {
    return PlanTripRequest(
      origin: 'TP. Hồ Chí Minh',
      numDays: 4,
      numPeople: 3,
      budgetVnd: 8000000,
      preferences: ['biển', 'ẩm thực', 'nghỉ dưỡng'],
      priority: 'comfortable',
    );
  }

  static PlanTripRequest presetVungTau() {
    return PlanTripRequest(
      origin: 'TP. Hồ Chí Minh',
      numDays: 2,
      numPeople: 2,
      budgetVnd: 1500000,
      preferences: ['biển', 'ẩm thực'],
      priority: 'cheapest',
    );
  }
}
