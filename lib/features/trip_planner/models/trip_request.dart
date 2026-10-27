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

  static const Object _sentinel = Object();

  PlanTripRequest copyWith({
    String? origin,
    int? numDays,
    int? numPeople,
    int? budgetVnd,
    List<String>? preferences,
    String? priority,
    Object? destinationId = _sentinel,
    Object? destinationName = _sentinel,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    String? companionType,
    bool clearDestination = false,
    bool clearDates = false,
  }) {
    final resolvedDestinationId = clearDestination
        ? null
        : (identical(destinationId, _sentinel)
            ? this.destinationId
            : destinationId as String?);
    final resolvedDestinationName = clearDestination
        ? null
        : (identical(destinationName, _sentinel)
            ? this.destinationName
            : destinationName as String?);
    final resolvedStartDate = clearDates
        ? null
        : (identical(startDate, _sentinel)
            ? this.startDate
            : startDate as String?);
    final resolvedEndDate = clearDates
        ? null
        : (identical(endDate, _sentinel)
            ? this.endDate
            : endDate as String?);
    return PlanTripRequest(
      origin: origin ?? this.origin,
      numDays: numDays ?? this.numDays,
      numPeople: numPeople ?? this.numPeople,
      budgetVnd: budgetVnd ?? this.budgetVnd,
      preferences: preferences ?? this.preferences,
      priority: priority ?? this.priority,
      destinationId: resolvedDestinationId,
      destinationName: resolvedDestinationName,
      startDate: resolvedStartDate,
      endDate: resolvedEndDate,
      companionType: companionType ?? this.companionType,
    );
  }

  PlanTripRequest clearDestination() => copyWith(clearDestination: true);
  PlanTripRequest clearDates() => copyWith(clearDates: true);

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
