# Thành Viên 1 (Team Lead) — AI Local (Chat, Tìm Kiếm & Gợi Ý) & UI/UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp bộ 3 năng lực AI cục bộ mạnh mẽ (Ollama Local Server chạy 100% offline): **AI Chat (Trò chuyện hỏi đáp)**, **AI Tìm kiếm thông tin (Tra cứu địa điểm Local RAG)**, và **AI Gợi ý thông minh (Smart Recommendations)**, kết hợp cải thiện UI/UX toàn diện (Skeleton Shimmer, Empty States, Floating SnackBar).

**Architecture:** Mở rộng `lib/features/trip_planner/services/local_ai_service.dart` với 3 phương thức chuyên biệt cho 3 chế độ: `chatWithLocalAi`, `searchPlaceInfoWithLocalAi` và `getRecommendationsWithLocalAi`. Phía giao diện xây dựng màn hình `LocalAiAssistantScreen` gồm 3 Tab tương tác trực quan (💬 Chat — 🔍 Tra cứu — 💡 Gợi ý). Cải thiện UI/UX toàn app thông qua thư mục `lib/core/widgets/`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Dio, Ollama REST API (`qwen2.5:1.5b` hoặc `gemma2:2b`), Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Hoạt động Offline 100%:** Cả 3 tính năng (Chat, Tra cứu, Gợi ý) đều kết nối trực tiếp tới Ollama chạy trên máy tính (`http://10.0.2.2:11434` hoặc IP nội bộ), không phụ thuộc vào internet hay API key bên ngoài.
- **Local RAG Tra cứu an toàn:** Khi tìm kiếm thông tin địa điểm, AI ưu tiên đọc dữ liệu từ Catalogue có sẵn trong app để tránh hiện tượng ảo giác (hallucination), không tự bịa giá vé.
- **Giao diện đa năng (3-in-1):** Cung cấp 3 Tab rõ ràng để người dùng chuyển đổi linh hoạt giữa Trò chuyện, Tra cứu và Gợi ý.
- **Không phá vỡ kiểm thử hiện tại:** 1.257 Flutter tests hiện có phải tiếp tục PASS.

## Review Focus
1. **Lỗi ngắt kết nối Ollama:** Khi chưa bật Ollama trên máy tính, app phải hiện banner thông báo: *"Chưa kết nối được với Local AI Server. Vui lòng bật Ollama trên máy tính hoặc chuyển sang Cloud Gemini"*, không được crash.
2. **AI Chat không bị lặp từ:** Prompt hệ thống phải được tối ưu để câu trả lời tiếng Việt ngắn gọn, súc tích, văn phong du lịch thân thiện.
3. **AI Tìm kiếm trả về thẻ thông tin rõ ràng:** Khi tra cứu địa danh, kết quả phải bóc tách thành các trường: Tên, Giờ mở cửa, Giá vé tham khảo, Mẹo tham quan.
4. **AI Gợi ý có nút hành động:** Địa điểm được AI gợi ý phải có nút *"Thêm vào lịch trình của tôi"* để người dùng đưa ngay vào chuyến đi.
5. **Hiệu năng cuộn tin nhắn:** Màn hình Chat cuộn mượt mà khi có nhiều tin nhắn, tự động cuộn xuống dưới cùng khi có tin nhắn mới.

---

### Task 1: Cấu hình Local AI Constants và Data Models cho 3 Năng Lực

**Files:**
- Modify: `lib/core/constants/api_constants.dart`
- Create: `lib/features/trip_planner/models/local_ai_models.dart`
- Create: `test/local_ai_models_test.dart`

**Interfaces:**
- Produces: `LocalChatMessage`, `PlaceInfoResult`, `AiRecommendationItem`, `LocalAiMode { chat, search, recommend }`

- [ ] **Step 1: Viết failing test cho các Model**
```dart
// test/local_ai_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';

void main() {
  test('LocalChatMessage and PlaceInfoResult initialize correctly', () {
    final msg = LocalChatMessage(text: 'Xin chào', isUser: true, timestamp: DateTime.now());
    expect(msg.isUser, isTrue);

    final info = PlaceInfoResult(
      placeName: 'Hồ Xuân Hương',
      summary: 'Hồ nước đẹp tại trung tâm Đà Lạt',
      priceInfo: 'Miễn phí',
      openingHours: 'Cả ngày',
      tips: 'Nên đi dạo vào sáng sớm hoặc chiều tà',
    );
    expect(info.placeName, equals('Hồ Xuân Hương'));
    expect(info.priceInfo, equals('Miễn phí'));
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_models_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model trong `lib/features/trip_planner/models/local_ai_models.dart`**
1. `LocalChatMessage`: Lưu nội dung tin nhắn, cờ `isUser`, thời gian.
2. `PlaceInfoResult`: Lưu thông tin tra cứu địa điểm có cấu trúc.
3. `AiRecommendationItem`: Lưu địa điểm gợi ý, lý do gợi ý, chi phí ước tính.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_models_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/core/constants/api_constants.dart lib/features/trip_planner/models/local_ai_models.dart test/local_ai_models_test.dart
git commit -m "feat(ai): define data models for Local AI Chat, Search, and Recommendations"
```

---

### Task 2: Xây dựng `LocalAiService` với 3 Phương Thức (Chat, Search, Recommend)

**Files:**
- Create: `lib/features/trip_planner/services/local_ai_service.dart`
- Create: `test/local_ai_service_test.dart`

**Interfaces:**
- Produces: 
  - `Future<String> sendChatMessage(String prompt, List<LocalChatMessage> history)`
  - `Future<PlaceInfoResult> searchPlaceInfo(String query, {String? destinationHint})`
  - `Future<List<AiRecommendationItem>> getRecommendations({required String destination, required int budgetVnd, List<String>? tags})`

- [ ] **Step 1: Viết failing test cho `LocalAiService`**
```dart
// test/local_ai_service_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

void main() {
  test('LocalAiService parses structured JSON for Search and Recommendations', () {
    final service = LocalAiService(dio: Dio());
    const mockSearchJson = '''{
      "placeName": "Chùa Linh Phước",
      "summary": "Ngôi chùa ve chai nổi tiếng Đà Lạt",
      "priceInfo": "Miễn phí vé vào",
      "openingHours": "07:30 - 17:00",
      "tips": "Nên mặc trang phục lịch sự"
    }''';
    final parsed = service.parsePlaceInfo(mockSearchJson);
    expect(parsed.placeName, equals('Chùa Linh Phước'));
    expect(parsed.openingHours, equals('07:30 - 17:00'));
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai 3 phương thức trong `LocalAiService`**
1. `sendChatMessage`: Gọi Ollama `/api/chat` với vai trò Trợ lý du lịch thân thiện, trả về câu trả lời tự nhiên.
2. `searchPlaceInfo`: Yêu cầu Ollama trả về JSON với các trường (`placeName`, `summary`, `priceInfo`, `openingHours`, `tips`).
3. `getRecommendations`: Nhận `destination`, `budgetVnd`, `tags`, yêu cầu Ollama gợi ý 3–5 địa điểm định dạng danh sách JSON.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/services/local_ai_service.dart test/local_ai_service_test.dart
git commit -m "feat(ai): implement chat, search and recommendation methods in LocalAiService"
```

---

### Task 3: Xây dựng Giao Diện Trung Tâm Trợ Lý AI 3-in-1 (`LocalAiAssistantScreen`)

**Files:**
- Create: `lib/features/trip_planner/presentation/screens/local_ai_assistant_screen.dart`
- Create: `lib/features/trip_planner/presentation/widgets/local_ai_chat_tab.dart`
- Create: `lib/features/trip_planner/presentation/widgets/local_ai_search_tab.dart`
- Create: `lib/features/trip_planner/presentation/widgets/local_ai_recommend_tab.dart`
- Create: `test/local_ai_assistant_screen_test.dart`

**Interfaces:**
- Produces: `LocalAiAssistantScreen()` với 3 Tab bar: `[Trò Chuyện 💬, Tra Cứu 🔍, Gợi Ý 💡]`

- [ ] **Step 1: Viết widget test cho `LocalAiAssistantScreen`**
```dart
// test/local_ai_assistant_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/presentation/screens/local_ai_assistant_screen.dart';

void main() {
  testWidgets('LocalAiAssistantScreen displays 3 tabs for Chat, Search and Recommend', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LocalAiAssistantScreen(),
    ));
    expect(find.text('Trò chuyện'), findsOneWidget);
    expect(find.text('Tra cứu'), findsOneWidget);
    expect(find.text('Gợi ý'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_assistant_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Màn hình và 3 Tab Widgets**
1. `local_ai_chat_tab.dart`: Khung chat tin nhắn hai chiều, ô nhập tin nhắn và nút gửi hình mũi tên.
2. `local_ai_search_tab.dart`: Thanh tìm kiếm địa điểm, hiển thị thẻ thông tin đẹp mắt (Giờ mở cửa, Giá vé, Mẹo).
3. `local_ai_recommend_tab.dart`: Bộ chọn sở thích (Ẩm thực, Sống ảo, Thư giãn), thanh kéo ngân sách, nút "Gợi ý cho tôi" hiển thị các Card địa điểm kèm nút "Thêm vào chuyến đi".
4. `local_ai_assistant_screen.dart`: Bọc `DefaultTabController(length: 3)` hiển thị 3 tab mượt mà.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_assistant_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/presentation/ test/local_ai_assistant_screen_test.dart
git commit -m "feat(ai): create 3-in-1 LocalAiAssistantScreen with Chat, Search, and Recommend tabs"
```

---

### Task 4: Nâng cấp UI/UX Toàn App với Skeleton Shimmer, Empty States & Floating Toasts

**Files:**
- Create: `lib/core/widgets/shimmer_loading.dart`
- Create: `lib/core/widgets/empty_state_view.dart`
- Create: `lib/core/widgets/app_toast.dart`
- Test: `test/ui_ux_widgets_test.dart`

**Interfaces:**
- Produces: `ShimmerCardLoading()`, `EmptyStateView(...)`, `AppToast.showSuccess(...)`

- [ ] **Step 1: Viết test cho `EmptyStateView`**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Triển khai các widget Shimmer, Empty States và Toasts**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/core/widgets/ test/ui_ux_widgets_test.dart
git commit -m "feat(ui): add polished shimmer loading, empty states, and floating toast widgets"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Năng Lực 1 — AI Chat (Trò chuyện tự do):**
   - **Thao tác:** Mở app $\rightarrow$ Vào mục "Trợ lý Local AI" $\rightarrow$ Chọn Tab **"Trò chuyện"**. Gõ câu hỏi: *"Đi Đà Lạt mùa này nên mặc đồ gì?"* $\rightarrow$ Bấm Gửi.
   - **Kỳ vọng:** Sau 2–3 giây, AI trả lời bằng tiếng Việt thân thiện, đưa ra lời khuyên mang áo ấm, khăn quàng vì sáng sớm và tối trời lạnh.
2. **Test Năng Lực 2 — AI Tìm kiếm Thông tin (Tra cứu địa điểm):**
   - **Thao tác:** Chuyển sang Tab **"Tra cứu"**. Gõ vào ô tìm kiếm: *"Dinh Bảo Đại"* $\rightarrow$ Bấm Tra cứu.
   - **Kỳ vọng:** Thẻ kết quả hiện ra với đầy đủ thông tin: Địa chỉ, Giờ mở cửa tham khảo, Giá vé và Mẹo tham quan (nên thuê trang phục hoàng gia chụp ảnh).
3. **Test Năng Lực 3 — AI Gợi ý Thông minh (Recommendations):**
   - **Thao tác:** Chuyển sang Tab **"Gợi ý"**. Chọn điểm đến: "Đà Nẵng", chọn sở thích "Sống ảo & Ẩm thực", bấm **"Gợi ý địa điểm"**.
   - **Kỳ vọng:** Xuất hiện 3 thẻ địa điểm gợi ý (ví dụ: Cầu Vàng Bà Nà, Chợ đêm Helio, Bán đảo Sơn Trà) kèm lý do vì sao phù hợp và nút *"Thêm vào chuyến đi"*.
4. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
