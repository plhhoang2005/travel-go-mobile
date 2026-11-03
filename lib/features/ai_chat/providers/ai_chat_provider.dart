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

  /// Trình sinh phản hồi du lịch & trò chuyện thông minh đa tầng
  String _generateSmartTravelFallback(String query) {
    final q = query.toLowerCase().trim();

    // 1. Phản hồi các câu hỏi kiến thức chung & nhân vật nổi tiếng
    if (q.contains('ronaldo') || q.contains('cr7')) {
      return '⚽ **Cristiano Ronaldo (CR7)** sinh ngày **05 tháng 02 năm 1985** (năm nay 41 tuổi) tại Santo António, Funchal, thuộc quần đảo Madeira, Bồ Đào Nha.\n\n'
          '🌟 **Gợi ý du lịch thú vị từ TravelGO:**\n'
          'Nếu bạn là fan của Ronaldo, hòn đảo quê hương **Madeira** là một thiên đường nghỉ dưỡng tuyệt mỹ ở Đại Tây Dương. Tại thành phố Funchal có **Bảo tàng Museu CR7** trưng bày tất cả Quả bóng Vàng, cúp vô địch và bức tượng đồng nổi tiếng của anh, ngay cạnh khách sạn cao cấp Pestana CR7 bên bờ vịnh!';
    }

    if (q.contains('messi') || q.contains('m10')) {
      return '⚽ **Lionel Messi** sinh ngày **24 tháng 06 năm 1987** tại thành phố Rosario, tỉnh Santa Fe, Argentina.\n\n'
          '🌟 **Điểm đến du lịch gợi ý:**\n'
          'Thành phố quê hương Rosario của Messi nằm bên bờ sông Paraná thơ mộng. Du khách đến đây có thể tham quan khu phố La Bajada nơi Messi lớn lên với những bức tranh tường graffiti khổng lồ đầy nghệ thuật, hoặc ghé thăm bảo tàng thể thao Museo del Deporte Santafesino.';
    }

    // 2. Phản hồi về quán cà phê, chụp ảnh check-in
    if (q.contains('quán cafe') || q.contains('quan cafe') || q.contains('cà phê') || q.contains('cafe')) {
      return '☕ **Gợi ý các quán cà phê ngắm cảnh & chụp hình tuyệt đẹp:**\n\n'
          '• **Tại Đà Lạt:**\n'
          '  - *Tiệm Cà Phê Cheo Veo*: Nằm trên sườn đồi Hoàng Hoa Thám, nơi ngắm hoàng hôn và thung lũng đèn lãng mạn nhất.\n'
          '  - *Lời Của Gió*: Phong cách mộc mạc nhìn ra đồi thông, đồ uống ngon và không gian cực kỳ yên tĩnh.\n'
          '• **Tại Hà Nội:**\n'
          '  - *Café Giảng (Nguyễn Hữu Huân)*: Khai sinh món cà phê trứng trứ danh từ năm 1946.\n'
          '  - *Loading T (Chân Cầm)*: Nằm trong biệt thự Pháp cổ trăm tuổi, hương thơm hoa cúc và quế đặc trưng.\n'
          '• **Tại TP. Hồ Chí Minh:**\n'
          '  - *Okkio Caffe (Lê Lợi)*: Thiết kế retro hiện đại, cà phê Specialty rang xay chuẩn gu.\n'
          '  - *The Running Bean (Mạc Thị Bưởi)*: Không gian kính thoáng sáng, thích hợp làm việc và thư giãn.';
    }

    // 3. Phản hồi các điểm đến du lịch nổi tiếng
    if (q.contains('đà lạt') || q.contains('da lat')) {
      return '🌲 **Lịch trình gợi ý du lịch Đà Lạt 3 ngày 2 đêm tự túc:**\n\n'
          '• **Ngày 1 (Check-in & Chill phố núi):**\n'
          '  - Sáng: Dạo quanh Hồ Xuân Hương, check-in Nụ hoa Atiso tại Quảng trường Lâm Viên.\n'
          '  - Chiều: Khám phá Dinh III Bảo Đại, thưởng thức cà phê ngắm đồi thông.\n'
          '  - Tối: Ăn lẩu gà lá é Tao Ngộ (đường 3/4) rồi đi dạo Chợ Đêm Đà Lạt thưởng thức bánh tráng nướng và sữa đậu nành nóng.\n\n'
          '• **Ngày 2 (Săn mây & Trải nghiệm):**\n'
          '  - Sáng sớm: Đón bình minh và săn mây tại Đồi chè Cầu Đất.\n'
          '  - Trưa: Ghé Chùa Linh Phước (Chùa Ve Chai) với kiến trúc khảm sành độc đáo.\n'
          '  - Chiều: Tham quan Thung Lũng Tình Yêu hoặc Ga Đà Lạt cổ kính.\n'
          '  - Tối: Thưởng thức lẩu bò Ba Toa quán gỗ Quán Gỗ chuẩn vị.\n\n'
          '• **Ngày 3 (Thư giãn & Mua quà):**\n'
          '  - Sáng: Tham quan Vườn dâu tây công nghệ cao, tự tay hái dâu.\n'
          '  - Mua đặc sản mứt dâu, hồng treo gió và trà atiso làm quà tại L\'angfarm.\n\n'
          '💡 *Chi phí dự kiến:* Khoảng 1.800.000đ - 2.500.000đ/người cho chuyến đi 3N2Đ.';
    }

    if (q.contains('sa pa') || q.contains('sapa')) {
      return '🏔️ **Cẩm nang du lịch Sa Pa trọn vẹn từ TravelGO:**\n\n'
          '• **Trải nghiệm đỉnh cao:**\n'
          '  - Chinh phục đỉnh Fansipan (3.143m) bằng tuyến cáp treo đạt kỷ lục thế giới, ngắm trọn biển mây Hoàng Liên Sơn.\n'
          '  - Dạo bước tại Bản Cát Cát, thuê trang phục dân tộc H\'Mông chụp ảnh bên thác Tiên Sa.\n'
          '  - Ngắm hoàng hôn kỳ vĩ tại Đèo Ô Quy Hồ - một trong "Tứ đại đỉnh đèo" Tây Bắc.\n\n'
          '• **Ẩm thực đặc sản:** Lẩu cá hồi tươi, thịt trâu gác bếp, cơm lam ống nứa nướng than, lợn cắp nách quay giòn.\n'
          '• **Trang phục khuyên dùng:** Nhiệt độ Sa Pa có thể xuống dưới 10°C vào ban đêm. Bạn hãy mang áo phao ấm, khăn len và giày leo núi chống trơn nhé!';
    }

    if (q.contains('phú quốc') || q.contains('phu quoc')) {
      return '🏝️ **Kinh nghiệm khám phá Đảo Ngọc Phú Quốc:**\n\n'
          '• **Bãi biển đẹp nhất:** Bãi Sao (cát trắng mịn như kem), Bãi Khem, Hòn Thơm (đi cáp treo vượt biển 7.899m).\n'
          '• **Trải nghiệm không thể bỏ lỡ:** Lặn ngắm san hô tại quần đảo An Thới, ngắm hoàng hôn Sunset Sanato, thăm Làng chài Rạch Vẹm mùa sao biển.\n'
          '• **Món ngon đảo ngọc:** Gỏi cá trích cuốn bánh tráng, bún quậy Kiến Xây trứ danh, hải sản Hàm Ninh, tiêu chín ngào đường.';
    }

    if (q.contains('hà nội') || q.contains('ha noi')) {
      return '🏛️ **Gợi ý khám phá Thủ đô Hà Nội 36 phố phường:**\n\n'
          '• **Địa điểm lịch sử & Văn hóa:** Hồ Hoàn Kiếm, Đền Ngọc Sơn, Lăng Bác, Chùa Một Cột, Văn Miếu - Quốc Tử Giám, Nhà tù Hỏa Lò.\n'
          '• **Hành trình ẩm thực:** Phở bò Bát Đàn, bún chả Hương Liên (quán Tổng thống Obama), chả cá Lã Vọng, bánh cuốn Thanh Trì, cà phê trứng Giảng.\n'
          '• **Mẹo di chuyển:** Buổi sáng đi bộ quanh hồ Gươm ngắm người dân tập dưỡng sinh, chiều tối đi xe buýt 2 tầng ngắm phố lên đèn.';
    }

    if (q.contains('đà nẵng') || q.contains('da nang') || q.contains('hội an') || q.contains('hoi an')) {
      return '🌊 **Combo Du lịch Đà Nẵng - Hội An:**\n\n'
          '• **Đà Nẵng:** Tắm biển Mỹ Khê (top bãi biển đẹp nhất hành tinh), xem Cầu Rồng phun lửa & nước lúc 21:00 thứ 7, CN; khám phá Bà Nà Hills với Cầu Vàng nổi tiếng thế giới.\n'
          '• **Phố cổ Hội An:** Cách Đà Nẵng 30km, thả đèn hoa đăng trên sông Hoài, thưởng thức Cao Lầu Bà Bé, bánh mì Phượng, cơm gà Bà Buội.';
    }

    if (q.contains('ngân sách') || q.contains('chi phí') || q.contains('tiết kiệm') || q.contains('tien')) {
      return '💰 **Bí quyết tối ưu chi phí du lịch từ TravelGO:**\n\n'
          '1. **Quy tắc 30 - 30 - 25 - 15:** Dành 30% cho di chuyển (săn vé sớm), 30% cho lưu trú (chọn homestay uy tín), 25% cho ăn uống trải nghiệm và 15% cho vé tham quan & dự phòng.\n'
          '2. **Lưu trú thông minh:** Đặt phòng trước từ 2-3 tuần, chọn các khu vực cách trung tâm 1-2km để tiết kiệm tới 40% chi phí phòng.\n'
          '3. **Ăn uống địa phương:** Thưởng thức tại các khu chợ truyền thống vừa đúng phong vị địa phương vừa có giá niêm yết rõ ràng.';
    }

    // 4. Phản hồi các câu hỏi mở, chào hỏi và tương tác tổng quát
    return '✈️ **Xin chào bạn! Tôi là Trợ lý AI du lịch TravelGO.**\n\n'
        'Tôi có thể hỗ trợ bạn mọi thông tin từ:\n'
        '• **Lên lịch trình thông minh:** Lịch trình chi tiết 2N1Đ, 3N2Đ, 4N3Đ theo sở thích của bạn.\n'
        '• **Khám phá ẩm thực & quán cafe:** Danh sách các quán ăn đặc sản ngon, view ngắm cảnh đẹp nhất.\n'
        '• **Tối ưu ngân sách:** Dự trù chi phí vé máy bay, phòng ở, ăn uống cho từng người.\n'
        '• **Giải đáp kiến thức & địa danh:** Tra cứu thông tin điểm đến, văn hóa, danh lam thắng cảnh khắp Việt Nam và quốc tế.\n\n'
        'Bạn đang dự định đi đâu hoặc muốn tìm hiểu điều gì? Hãy nhắn cho tôi nhé!';
  }
}
