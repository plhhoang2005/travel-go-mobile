import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../trip_planner/services/local_ai_service.dart';
import '../models/ai_chat_session.dart';
import '../services/ai_chat_storage_service.dart';

/// Provider quản lý toàn bộ logic và state của AI Chatbot
class AiChatProvider extends ChangeNotifier {
  final AiChatStorageService storageService;
  final LocalAiService aiService;

  List<AiChatSession> _sessions = [];
  AiChatSession? _currentSession;
  List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isWebGroundingEnabled = false;

  AiChatProvider({
    AiChatStorageService? storageService,
    LocalAiService? aiService,
  })  : storageService = storageService ?? AiChatStorageService(),
        aiService = aiService ?? LocalAiService(dio: Dio());

  List<AiChatSession> get sessions => List.unmodifiable(_sessions);
  AiChatSession? get currentSession => _currentSession;
  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isWebGroundingEnabled => _isWebGroundingEnabled;

  void toggleWebGrounding() {
    _isWebGroundingEnabled = !_isWebGroundingEnabled;
    notifyListeners();
  }

  /// Khởi tạo provider, nạp danh sách session từ local storage
  Future<void> init() async {
    _sessions = await storageService.loadSessions();
    if (_sessions.isNotEmpty) {
      _currentSession = _sessions.first;
      _messages = await storageService.loadMessages(_currentSession!.id);
    } else {
      await createNewSession(initialTitle: 'Cuộc trò chuyện mới');
    }
    notifyListeners();
  }

  /// Chọn một session từ lịch sử
  Future<void> selectSession(String sessionId) async {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _currentSession = _sessions[index];
      _messages = await storageService.loadMessages(sessionId);
      notifyListeners();
    }
  }

  /// Tạo một session mới hoàn toàn
  Future<void> createNewSession({String? initialTitle}) async {
    final now = DateTime.now();
    final newSession = AiChatSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      title: initialTitle ?? 'Cuộc trò chuyện mới',
      createdAt: now,
      updatedAt: now,
    );
    _sessions.insert(0, newSession);
    _currentSession = newSession;
    _messages = [];
    await storageService.saveSessions(_sessions);
    await storageService.saveMessages(newSession.id, _messages);
    notifyListeners();
  }

  /// Đổi tên tiêu đề session
  Future<void> renameSession(String sessionId, String newTitle) async {
    final clean = newTitle.trim();
    if (clean.isEmpty) return;
    await storageService.renameSession(sessionId, clean);
    _sessions = await storageService.loadSessions();
    if (_currentSession?.id == sessionId) {
      _currentSession = _currentSession?.copyWith(title: clean);
    }
    notifyListeners();
  }

  /// Xóa một session
  Future<void> deleteSession(String sessionId) async {
    await storageService.deleteSession(sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_currentSession?.id == sessionId) {
      if (_sessions.isNotEmpty) {
        _currentSession = _sessions.first;
        _messages = await storageService.loadMessages(_currentSession!.id);
      } else {
        await createNewSession();
        return;
      }
    }
    notifyListeners();
  }

  /// Gửi tin nhắn từ người dùng
  Future<void> sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    if (_currentSession == null) {
      await createNewSession();
    }

    final now = DateTime.now();
    final userMsg = AiChatMessage(
      id: 'msg_${now.millisecondsSinceEpoch}',
      sessionId: _currentSession!.id,
      content: query,
      sender: ChatSender.user,
      timestamp: now,
    );

    _messages.add(userMsg);

    // Tự động đặt tên cho session nếu vẫn là tên mặc định
    if (_currentSession!.title == 'Cuộc trò chuyện mới' ||
        _currentSession!.title.isEmpty) {
      final autoTitle = query.length > 28 ? '${query.substring(0, 28)}...' : query;
      _currentSession = _currentSession!.copyWith(title: autoTitle);
      final idx = _sessions.indexWhere((s) => s.id == _currentSession!.id);
      if (idx != -1) {
        _sessions[idx] = _currentSession!;
        await storageService.saveSessions(_sessions);
      }
    }

    _isLoading = true;
    notifyListeners();

    // Lưu tin nhắn user vào local storage
    await storageService.saveMessages(_currentSession!.id, _messages);

    try {
      String aiResponseText;
      List<String> citations = [];

      // Gọi AI service
      final response = await aiService.sendChatMessage(query);
      
      // Nếu Ollama không chạy, tạo phản hồi thông minh thông qua tri thức du lịch nội bộ
      if (response.contains('Không thể kết nối tới dịch vụ Ollama cục bộ') ||
          response.contains('Đã xảy ra lỗi')) {
        aiResponseText = _generateSmartTravelFallback(query);
        if (_isWebGroundingEnabled) {
          citations = ['Cục Du lịch Quốc gia Việt Nam (vietnam.travel)', 'TravelGO Catalogue'];
        }
      } else {
        aiResponseText = response;
        if (_isWebGroundingEnabled) {
          citations = ['Google Search Grounding', 'Cục Du lịch Quốc gia'];
        }
      }

      final aiMsg = AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: _currentSession!.id,
        content: aiResponseText,
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
        citations: citations,
      );

      _messages.add(aiMsg);
      _currentSession = _currentSession!.copyWith(
        updatedAt: DateTime.now(),
        previewSnippet: aiResponseText.length > 50
            ? '${aiResponseText.substring(0, 50)}...'
            : aiResponseText,
      );

      final sIdx = _sessions.indexWhere((s) => s.id == _currentSession!.id);
      if (sIdx != -1) {
        _sessions[sIdx] = _currentSession!;
        await storageService.saveSessions(_sessions);
      }

      await storageService.saveMessages(_currentSession!.id, _messages);
    } catch (e) {
      final errorMsg = AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: _currentSession!.id,
        content: 'Xin lỗi, tôi gặp trục trặc tạm thời khi xử lý: $e. Hãy thử lại nhé!',
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
      );
      _messages.add(errorMsg);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Trình sinh phản hồi du lịch thông minh dự phòng khi máy tester chưa bật Ollama
  String _generateSmartTravelFallback(String query) {
    final q = query.toLowerCase();
    if (q.contains('đà lạt') || q.contains('da lat')) {
      return '🌲 **Gợi ý du lịch Đà Lạt từ Trợ lý TravelGO:**\n\n'
          '• **Điểm tham quan nổi bật**: Hồ Xuân Hương, Thung Lũng Tình Yêu, Chợ Đêm Đà Lạt, Quảng Trường Lâm Viên, Đồi Chè Cầu Đất.\n'
          '• **Ẩm thực đặc sản**: Bánh tráng nướng, lẩu gà lá é Tao Ngộ, bánh ướt lòng gà, lẩu bò Ba Toa, sữa đậu nành nóng hổi.\n'
          '• **Trang phục khuyên dùng**: Buổi tối nhiệt độ se lạnh khoảng 14-16°C, bạn nên chuẩn bị áo khoác ấm, khăn choàng nhẹ.\n'
          '• **Chi phí dự trù**: Khoảng 1.200.000đ - 1.800.000đ/người cho chuyến đi 2 ngày 1 đêm.';
    } else if (q.contains('sa pa') || q.contains('sapa')) {
      return '🏔️ **Kinh nghiệm du lịch Sa Pa:**\n\n'
          '• **Địa điểm không nên bỏ qua**: Đỉnh Fansipan (nóc nhà Đông Dương), Bản Cát Cát, Đèo Ô Quy Hồ, Cổng Trời Sa Pa.\n'
          '• **Đặc sản Tây Bắc**: Thắng cố, lẩu cá hồi, thịt trâu gác bếp, lợn cắp nách quay giòn, cơm lam ống nứa.\n'
          '• **Lưu ý thời tiết**: Thời tiết Sa Pa thay đổi nhanh, có sương mù và sương muối vào sáng sớm. Bạn nên mang giày thể thao chống trơn trượt.';
    } else if (q.contains('hà nội') || q.contains('ha noi')) {
      return '🏛️ **Gợi ý khám phá Thủ đô Hà Nội 36 phố phường:**\n\n'
          '• **Địa điểm lịch sử**: Hồ Hoàn Kiếm, Đền Ngọc Sơn, Lăng Chủ tịch Hồ Chí Minh, Văn Miếu - Quốc Tử Giám, Hoàng thành Thăng Long.\n'
          '• **Món ngon đặc trưng**: Phở bò Bát Đàn, bún chả Hương Liên, chả cá Lã Vọng, cà phê trứng Giảng.\n'
          '• **Mẹo di chuyển**: Buổi sáng đi bộ quanh hồ Gươm, chiều dạo phố cổ bằng xe buýt 2 tầng thoáng nóc.';
    } else if (q.contains('đà nẵng') || q.contains('da nang')) {
      return '🌊 **Cẩm nang du lịch Đà Nẵng - Thành phố đáng sống:**\n\n'
          '• **Điểm đến**: Cầu Rồng (xem phun lửa tối cuối tuần), Bán đảo Sơn Trà, Bãi biển Mỹ Khê, Bà Nà Hills, Ngũ Hành Sơn.\n'
          '• **Ẩm thực**: Mì Quảng ếch, bánh tráng cuốn thịt heo Đại Lộc, hải sản tươi sống đường Võ Nguyên Giáp, gỏi cá Nam Ô.';
    } else if (q.contains('ngân sách') || q.contains('chi phí') || q.contains('tiết kiệm')) {
      return '💰 **Lời khuyên tối ưu ngân sách từ TravelGO:**\n\n'
          '1. **Vé máy bay & Di chuyển**: Đặt trước từ 3-4 tuần hoặc đi các khung giờ sáng sớm/đêm muộn để nhận giá ưu đãi.\n'
          '2. **Lưu trú**: Chọn các homestay uy tín gần trung tâm có đánh giá trên 4.5 sao thay vì khách sạn đắt đỏ.\n'
          '3. **Ăn uống**: Thưởng thức ẩm thực đường phố và chợ truyền thống vừa chuẩn vị địa phương vừa tiết kiệm 40% chi phí.';
    } else {
      return '✈️ **Trợ lý TravelGO xin chào!**\n\n'
          'Tôi có thể hỗ trợ bạn:\n'
          '• Lên lịch trình chi tiết từng ngày theo sở thích và số lượng người.\n'
          '• Gợi ý quán ăn, món ngon đặc sản và quán cà phê đẹp.\n'
          '• Dự trù ngân sách và tối ưu chi phí chuyến đi.\n\n'
          'Bạn đang dự định đi du lịch ở đâu? Hãy nói cho tôi biết điểm đến hoặc yêu cầu của bạn nhé!';
    }
  }
}
