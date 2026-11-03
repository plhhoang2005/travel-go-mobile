import 'package:flutter/foundation.dart';

enum LocalAiMode {
  chat,
  search,
  recommend,
}

/// Tin nhắn trao đổi hai chiều giữa người dùng và Trợ lý AI.
@immutable
class LocalChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  const LocalChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'isError': isError,
      };

  factory LocalChatMessage.fromJson(Map<String, dynamic> json) => LocalChatMessage(
        text: json['text'] as String? ?? '',
        isUser: json['isUser'] as bool? ?? false,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        isError: json['isError'] as bool? ?? false,
      );
}

/// Kết quả tra cứu thông tin địa điểm theo cơ chế Hybrid Search.
@immutable
class PlaceInfoResult {
  final String placeName;
  final String summary;
  final String priceInfo;
  final String openingHours;
  final String tips;
  final bool isFromWeb;
  final String? sourceUrl;

  const PlaceInfoResult({
    required this.placeName,
    required this.summary,
    required this.priceInfo,
    required this.openingHours,
    required this.tips,
    this.isFromWeb = false,
    this.sourceUrl,
  });

  Map<String, dynamic> toJson() => {
        'placeName': placeName,
        'summary': summary,
        'priceInfo': priceInfo,
        'openingHours': openingHours,
        'tips': tips,
        'isFromWeb': isFromWeb,
        'sourceUrl': sourceUrl,
      };

  factory PlaceInfoResult.fromJson(Map<String, dynamic> json) => PlaceInfoResult(
        placeName: json['placeName'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        priceInfo: json['priceInfo'] as String? ?? '',
        openingHours: json['openingHours'] as String? ?? '',
        tips: json['tips'] as String? ?? '',
        isFromWeb: json['isFromWeb'] as bool? ?? false,
        sourceUrl: json['sourceUrl'] as String?,
      );
}

/// Mục gợi ý địa điểm thông minh dựa trên đánh giá thực tế từ cộng đồng.
@immutable
class AiRecommendationItem {
  final String placeId;
  final String placeName;
  final String destination;
  final String description;
  final int estimatedCostVnd;
  final double averageRating;
  final int reviewCount;
  final List<String> tags;

  const AiRecommendationItem({
    required this.placeId,
    required this.placeName,
    required this.destination,
    required this.description,
    required this.estimatedCostVnd,
    required this.averageRating,
    this.reviewCount = 0,
    this.tags = const [],
  });

  bool get isTopRated => averageRating >= 4.5;

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'placeName': placeName,
        'destination': destination,
        'description': description,
        'estimatedCostVnd': estimatedCostVnd,
        'averageRating': averageRating,
        'reviewCount': reviewCount,
        'tags': tags,
      };

  factory AiRecommendationItem.fromJson(Map<String, dynamic> json) => AiRecommendationItem(
        placeId: json['placeId'] as String? ?? '',
        placeName: json['placeName'] as String? ?? '',
        destination: json['destination'] as String? ?? '',
        description: json['description'] as String? ?? '',
        estimatedCostVnd: (json['estimatedCostVnd'] as num?)?.toInt() ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      );
}
