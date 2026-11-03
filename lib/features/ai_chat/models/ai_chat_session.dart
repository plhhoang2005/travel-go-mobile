import 'dart:convert';

/// Vai trò người gửi tin nhắn
enum ChatSender { user, ai, system }

/// Model tin nhắn trong một phiên trò chuyện
class AiChatMessage {
  final String id;
  final String sessionId;
  final String content;
  final ChatSender sender;
  final DateTime timestamp;
  final List<String> citations;

  const AiChatMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.citations = const [],
  });

  bool get isUser => sender == ChatSender.user;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'content': content,
        'sender': sender.name,
        'timestamp': timestamp.toIso8601String(),
        'citations': citations,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => AiChatMessage(
        id: json['id'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        content: json['content'] as String? ?? '',
        sender: ChatSender.values.firstWhere(
          (e) => e.name == json['sender'],
          orElse: () => ChatSender.ai,
        ),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        citations: (json['citations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

/// Model phiên hội thoại (Chat Session)
class AiChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String previewSnippet;

  const AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.previewSnippet = '',
  });

  AiChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? previewSnippet,
  }) =>
      AiChatSession(
        id: id ?? this.id,
        title: title ?? this.title,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        previewSnippet: previewSnippet ?? this.previewSnippet,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'previewSnippet': previewSnippet,
      };

  factory AiChatSession.fromJson(Map<String, dynamic> json) => AiChatSession(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Cuộc trò chuyện mới',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        previewSnippet: json['previewSnippet'] as String? ?? '',
      );

  static String serializeList(List<AiChatSession> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<AiChatSession> deserializeList(String jsonStr) {
    try {
      final List<dynamic> raw = jsonDecode(jsonStr) as List<dynamic>;
      return raw
          .map((e) => AiChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
