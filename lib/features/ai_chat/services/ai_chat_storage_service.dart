import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_chat_session.dart';

/// Dịch vụ lưu trữ cục bộ các phiên hội thoại và tin nhắn chat AI
class AiChatStorageService {
  static const String _sessionsKey = 'travelgo_ai_chat_sessions_v1';
  static const String _messagesPrefix = 'travelgo_ai_chat_msgs_v1_';

  final SharedPreferences? prefs;

  AiChatStorageService({this.prefs});

  Future<SharedPreferences> _getPrefs() async =>
      prefs ?? await SharedPreferences.getInstance();

  /// Tải danh sách tất cả các phiên hội thoại, sắp xếp theo thời gian cập nhật mới nhất
  Future<List<AiChatSession>> loadSessions() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = AiChatSession.deserializeList(raw);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Lưu toàn bộ danh sách phiên hội thoại
  Future<void> saveSessions(List<AiChatSession> sessions) async {
    final prefs = await _getPrefs();
    final raw = AiChatSession.serializeList(sessions);
    await prefs.setString(_sessionsKey, raw);
  }

  /// Tải lịch sử tin nhắn của một phiên
  Future<List<AiChatMessage>> loadMessages(String sessionId) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString('$_messagesPrefix$sessionId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AiChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Lưu danh sách tin nhắn của một phiên
  Future<void> saveMessages(
    String sessionId,
    List<AiChatMessage> messages,
  ) async {
    final prefs = await _getPrefs();
    final raw = jsonEncode(messages.map((e) => e.toJson()).toList());
    await prefs.setString('$_messagesPrefix$sessionId', raw);
  }

  /// Xóa vĩnh viễn một phiên cùng toàn bộ tin nhắn liên quan
  Future<void> deleteSession(String sessionId) async {
    final prefs = await _getPrefs();
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveSessions(sessions);
    await prefs.remove('$_messagesPrefix$sessionId');
  }

  /// Đổi tên tiêu đề một phiên
  Future<void> renameSession(String sessionId, String newTitle) async {
    final sessions = await loadSessions();
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      sessions[index] = sessions[index].copyWith(
        title: newTitle.trim(),
        updatedAt: DateTime.now(),
      );
      await saveSessions(sessions);
    }
  }
}
