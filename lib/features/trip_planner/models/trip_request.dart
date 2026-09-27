class PlanTripRequest {
  final String origin;
  final int numDays;
  final int numPeople;
  final int budgetVnd;
  final List<String> preferences;
  final String priority; // "cheapest", "fastest", "balanced", "comfortable"

  PlanTripRequest({
    required this.origin,
    required this.numDays,
    required this.numPeople,
    required this.budgetVnd,
    required this.preferences,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'numDays': numDays,
      'numPeople': numPeople,
      'budgetVnd': budgetVnd,
      'preferences': preferences,
      'priority': priority,
    };
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
    );
  }

  PlanTripRequest copyWith({
    String? origin,
    int? numDays,
    int? numPeople,
    int? budgetVnd,
    List<String>? preferences,
    String? priority,
  }) {
    return PlanTripRequest(
      origin: origin ?? this.origin,
      numDays: numDays ?? this.numDays,
      numPeople: numPeople ?? this.numPeople,
      budgetVnd: budgetVnd ?? this.budgetVnd,
      preferences: preferences ?? this.preferences,
      priority: priority ?? this.priority,
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
