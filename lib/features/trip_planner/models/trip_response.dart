class PlanTripResponse {
  final String winnerId;
  final List<DestinationCard> topDestinations;
  final List<TransportOption> transportOptions;
  final List<ItineraryDay> itineraryDays;
  final BudgetBreakdown? budgetBreakdown;
  final String aiExplanation;
  final Map<String, String> dataSources;
  final List<String> assumptions;

  PlanTripResponse({
    required this.winnerId,
    required this.topDestinations,
    required this.transportOptions,
    required this.itineraryDays,
    this.budgetBreakdown,
    required this.aiExplanation,
    required this.dataSources,
    required this.assumptions,
  });

  bool get isFallback =>
      dataSources.values.any((s) => s.toLowerCase().contains('fallback') || s.toLowerCase().contains('offline'));

  factory PlanTripResponse.fromJson(Map<String, dynamic> json) {
    return PlanTripResponse(
      winnerId: json['winnerId'] as String? ?? '',
      topDestinations: (json['topDestinations'] as List<dynamic>?)
              ?.map((e) => DestinationCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      transportOptions: (json['transportOptions'] as List<dynamic>?)
              ?.map((e) => TransportOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      itineraryDays: (json['itineraryDays'] as List<dynamic>?)
              ?.map((e) => ItineraryDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      budgetBreakdown: json['budgetBreakdown'] != null
          ? BudgetBreakdown.fromJson(json['budgetBreakdown'] as Map<String, dynamic>)
          : null,
      aiExplanation: json['aiExplanation'] as String? ?? '',
      dataSources: (json['dataSources'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
      assumptions: (json['assumptions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class DestinationCard {
  final String id;
  final String name;
  final double totalScore;
  final Map<String, double> normalizedScores;
  final Map<String, double> scoreContributions;
  final int estimatedCostVnd;
  final String weatherSource;
  final double avgTempMax;
  final double avgPrecipitation;
  final double? latitude;
  final double? longitude;
  final String region;

  DestinationCard({
    required this.id,
    required this.name,
    required this.totalScore,
    required this.normalizedScores,
    required this.scoreContributions,
    required this.estimatedCostVnd,
    required this.weatherSource,
    required this.avgTempMax,
    required this.avgPrecipitation,
    this.latitude,
    this.longitude,
    required this.region,
  });

  factory DestinationCard.fromJson(Map<String, dynamic> json) {
    return DestinationCard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0.0,
      normalizedScores: (json['normalizedScores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      scoreContributions: (json['scoreContributions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      estimatedCostVnd: (json['estimatedCostVnd'] as num?)?.toInt() ?? 0,
      weatherSource: json['weatherSource'] as String? ?? '',
      avgTempMax: (json['avgTempMax'] as num?)?.toDouble() ?? 0.0,
      avgPrecipitation: (json['avgPrecipitation'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      region: json['region'] as String? ?? '',
    );
  }
}

class TransportOption {
  final String mode;
  final String displayName;
  final int priceTotalVnd;
  final double durationHours;
  final int comfortScore;
  final bool isParetoOptimal;
  final String tradeoffType;
  final String recommendationReason;

  TransportOption({
    required this.mode,
    required this.displayName,
    required this.priceTotalVnd,
    required this.durationHours,
    required this.comfortScore,
    required this.isParetoOptimal,
    required this.tradeoffType,
    required this.recommendationReason,
  });

  factory TransportOption.fromJson(Map<String, dynamic> json) {
    return TransportOption(
      mode: json['mode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      priceTotalVnd: (json['priceTotalVnd'] as num?)?.toInt() ?? 0,
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 0.0,
      comfortScore: (json['comfortScore'] as num?)?.toInt() ?? 0,
      isParetoOptimal: (json['paretoOptimal'] as bool?) ??
          (json['isParetoOptimal'] as bool?) ??
          false,
      tradeoffType: json['tradeoffType'] as String? ?? '',
      recommendationReason: json['recommendationReason'] as String? ?? '',
    );
  }
}

class ItineraryDay {
  final int day;
  final String title;
  final List<Activity> activities;

  ItineraryDay({
    required this.day,
    required this.title,
    required this.activities,
  });

  factory ItineraryDay.fromJson(Map<String, dynamic> json) {
    return ItineraryDay(
      day: json['day'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      activities: (json['activities'] as List<dynamic>?)
              ?.map((e) => Activity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Activity {
  final String time;
  final String title;
  final int costVnd;
  final double durationHours;

  Activity({
    required this.time,
    required this.title,
    required this.costVnd,
    required this.durationHours,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      time: json['time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      costVnd: (json['costVnd'] as num?)?.toInt() ?? 0,
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BudgetBreakdown {
  final int transport;
  final int accommodation;
  final int food;
  final int attractions;
  final int remainingSafetyMargin;

  BudgetBreakdown({
    required this.transport,
    required this.accommodation,
    required this.food,
    required this.attractions,
    required this.remainingSafetyMargin,
  });

  int get totalAllocated => transport + accommodation + food + attractions;

  factory BudgetBreakdown.fromJson(Map<String, dynamic> json) {
    return BudgetBreakdown(
      transport: (json['transport'] as num?)?.toInt() ?? 0,
      accommodation: (json['accommodation'] as num?)?.toInt() ?? 0,
      food: (json['food'] as num?)?.toInt() ?? 0,
      attractions: (json['attractions'] as num?)?.toInt() ?? 0,
      remainingSafetyMargin: (json['remainingSafetyMargin'] as num?)?.toInt() ?? 0,
    );
  }
}
