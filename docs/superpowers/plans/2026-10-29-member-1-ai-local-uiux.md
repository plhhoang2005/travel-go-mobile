# Thành Viên 1 (Team Lead) — AI Local (Chat, Hybrid Search & Gợi Ý Rating) & UI/UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng Trợ lý Du lịch Toàn năng (Local AI Travel Assistant) chạy 100% Offline với Ollama kết hợp Internet Search Fallback: bao gồm **AI Chat** (trò chuyện tự do), **AI Tra cứu & Tìm kiếm thông tin Hybrid** (ưu tiên CSDL nội bộ, nếu không có tự động tìm kiếm trên mạng với trích dẫn nguồn), và **AI Gợi ý thông minh** (lọc địa điểm có Rating $\ge$ 4.5 sao từ cộng đồng), đồng thời nâng cấp giao diện xúc giác toàn app (Shimmer, Empty States, Toasts).

**Architecture:** Mở rộng `lib/features/trip_planner/services/local_ai_service.dart` kết nối Ollama JSON API, tích hợp cơ chế Hybrid RAG: tra cứu `PublicCatalogueSnapshot` trước, nếu rỗng sẽ chuyển sang gọi `requestWebAdvice` (Google Search Grounding đã có sẵn trong dự án). Giao diện xây dựng `LocalAiAssistantScreen` gồm 3 Tab tương tác (`Trò chuyện`, `Tra cứu & Web Search`, `Gợi ý theo Rating`). Cải thiện UI/UX toàn hệ thống thông qua `lib/core/widgets/`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Dio, Ollama REST API (`qwen2.5:1.5b`), Google Search Grounding (Web Fallback), Provider, Material 3.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Cơ chế Hybrid Search:** Khi tra cứu địa điểm, luôn kiểm tra CSDL Admin Catalogue trước; chỉ gọi tìm kiếm Internet khi địa điểm không tồn tại trong hệ thống.
- **Minh bạch nguồn thông tin:** Thông tin tìm từ Internet bắt buộc phải có liên kết nguồn trích dẫn (`citations`) và nhãn cảnh báo: *"Thông tin từ Internet, chưa qua Admin kiểm duyệt"*.
- **Bảo vệ CSDL Admin:** Dữ liệu tìm từ web tuyệt đối không tự ý lưu vào bảng `discovery_places` chung.
- **Ưu tiên Rating cao:** AI Gợi ý thông minh bắt buộc phải tích hợp tiêu chí lọc các địa điểm có điểm đánh giá từ 4.5 sao trở lên từ bảng đánh giá của Thành viên 3.

## Review Focus
1. **Ollama chưa bật:** Hiển thị thông báo hướng dẫn người dùng bật Ollama trên máy tính hoặc chuyển sang Cloud Gemini, tuyệt đối không văng app.
2. **Không có mạng khi tìm kiếm Internet:** Nếu địa điểm không có trong CSDL và máy tính cũng không có mạng, AI báo rõ: *"Đang ngoại tuyến (Offline), không tìm thấy trong CSDL đã lưu"*.
3. **Trích dẫn nguồn web hợp lệ:** Link nguồn bài viết từ web phải bấm mở được bằng trình duyệt (`url_launcher`).
4. **Gợi ý có nút hành động:** Các địa điểm được AI gợi ý phải có nút *"Thêm vào chuyến đi"* để người dùng đưa ngay vào lịch trình cá nhân.
5. **Hiệu năng cuộn mượt mà:** Khung chat tự động cuộn xuống dưới cùng khi có tin nhắn mới, không giật lag khi cuộn lịch sử tin nhắn.

---

### Task 1: Cấu hình Local AI Constants và Data Models cho 3 Năng Lực

**Files:**
- Modify: `lib/core/constants/api_constants.dart`
- Create: `lib/features/trip_planner/models/local_ai_models.dart`
- Create: `test/local_ai_models_test.dart`

**Interfaces:**
- Produces: `LocalChatMessage`, `PlaceInfoResult`, `AiRecommendationItem`, `LocalAiMode { chat, search, recommend }`

- [ ] **Step 1: Viết failing test cho các Data Model**
```dart
// test/local_ai_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/models/local_ai_models.dart';

void main() {
  test('LocalChatMessage and PlaceInfoResult initialize with web source support', () {
    final msg = LocalChatMessage(text: 'Xin chào', isUser: true, timestamp: DateTime.now());
    expect(msg.isUser, isTrue);

    final info = PlaceInfoResult(
      placeName: 'Đảo Điệp Sơn',
      summary: 'Con đường đi bộ giữa biển độc đáo',
      priceInfo: 'Vé tàu khoảng 100.000 VNĐ',
      openingHours: '06:00 - 18:00',
      tips: 'Canh thủy triều rút để đi bộ trên con đường cát',
      sourceUrl: 'https://vnexpress.net/diep-son',
      isFromWeb: true,
    );
    expect(info.isFromWeb, isTrue);
    expect(info.sourceUrl, isNotNull);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_models_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model trong `lib/features/trip_planner/models/local_ai_models.dart`**
Xây dựng `LocalChatMessage`, `PlaceInfoResult` (có cờ `isFromWeb`, `sourceUrl`), và `AiRecommendationItem` (có trường `averageRating`, `reviewCount`).

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_models_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/core/constants/api_constants.dart lib/features/trip_planner/models/local_ai_models.dart test/local_ai_models_test.dart
git commit -m "feat(ai): define data models for Local AI Chat, Hybrid Search, and Recommendations"
```

---

### Task 2: Xây dựng `LocalAiService` với Hybrid Search & Rating Filtering

**Files:**
- Create: `lib/features/trip_planner/services/local_ai_service.dart`
- Create: `test/local_ai_service_test.dart`

**Interfaces:**
- Produces: 
  - `Future<String> sendChatMessage(String prompt, List<LocalChatMessage> history)`
  - `Future<PlaceInfoResult> searchPlaceInfoHybrid(String query, {required List<Map<String, dynamic>> localCataloguePlaces})`
  - `Future<List<AiRecommendationItem>> getRecommendationsWithRatings({required String destination, required int budgetVnd, List<String>? tags, required List<Map<String, dynamic>> ratedPlaces})`

- [ ] **Step 1: Viết failing test cho `LocalAiService`**
```dart
// test/local_ai_service_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/trip_planner/services/local_ai_service.dart';

void main() {
  test('searchPlaceInfoHybrid prioritizes local catalogue place before web fallback', () async {
    final service = LocalAiService(dio: Dio());
    final localCatalogue = [
      {'name': 'Hồ Xuân Hương', 'description': 'Hồ nước trung tâm', 'price': 'Miễn phí'}
    ];
    final result = await service.searchPlaceInfoHybrid('Hồ Xuân Hương', localCataloguePlaces: localCatalogue);
    expect(result.placeName, equals('Hồ Xuân Hương'));
    expect(result.isFromWeb, isFalse);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai 3 phương thức trong `LocalAiService`**
1. `sendChatMessage`: Gửi prompt tới Ollama `/api/chat` với vai trò Trợ lý du lịch TravelGO.
2. `searchPlaceInfoHybrid`: Kiểm tra tên trong `localCataloguePlaces`. Nếu khớp $\rightarrow$ Trả về `isFromWeb: false`. Nếu không có $\rightarrow$ Gọi API tìm kiếm web hoặc Ollama tổng hợp web, trả về `isFromWeb: true` kèm link nguồn.
3. `getRecommendationsWithRatings`: Gửi danh sách các địa điểm có rating cao vào prompt để Ollama ưu tiên lựa chọn.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/local_ai_service_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/services/local_ai_service.dart test/local_ai_service_test.dart
git commit -m "feat(ai): implement chat, hybrid search and rating-backed recommendations"
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
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Triển khai Màn hình và 3 Tab Widgets**:
  - Tab 1: Khung chat tin nhắn hai chiều mượt mà.
  - Tab 2: Thanh tra cứu địa điểm, hiển thị thẻ thông tin; nếu từ web có banner màu vàng: *"Thông tin từ Internet, chưa qua kiểm duyệt"* kèm nút mở nguồn.
  - Tab 3: Chọn sở thích & ngân sách, hiển thị các địa điểm rating $\ge$ 4.5 sao kèm nút *"Thêm vào chuyến đi"*.
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/trip_planner/presentation/ test/local_ai_assistant_screen_test.dart
git commit -m "feat(ai): create LocalAiAssistantScreen with Chat, Hybrid Search, and Recommend tabs"
```

---

### Task 4: Nâng cấp UI/UX Toàn App với Skeleton Shimmer, Empty States & Floating Toasts

**Files:**
- Create: `lib/core/widgets/shimmer_loading.dart`
- Create: `lib/core/widgets/empty_state_view.dart`
- Create: `lib/core/widgets/app_toast.dart`
- Create: `test/ui_ux_widgets_test.dart`

**Interfaces:**
- Produces: `ShimmerCardLoading()`, `EmptyStateView(...)`, `AppToast.showSuccess(...)`

- [ ] **Step 1: Viết test cho `EmptyStateView`**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Triển khai các widget Shimmer skeleton, Empty state minh họa và Floating Toast**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/core/widgets/ test/ui_ux_widgets_test.dart
git commit -m "feat(ui): add polished shimmer loading, empty states, and floating toast widgets"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test AI Chat (Trò chuyện hỏi đáp):**
   - **Thao tác:** Vào Tab "Trò chuyện", gõ: *"Đi Đà Lạt mùa này nên mặc đồ gì?"*.
   - **Kỳ vọng:** AI trả lời bằng tiếng Việt thân thiện, khuyên mang áo ấm vì thời tiết se lạnh.
2. **Test AI Tra Cứu Hybrid & Tìm kiếm Internet:**
   - **Thao tác A (Có trong CSDL):** Tra cứu *"Hồ Xuân Hương"* $\rightarrow$ Thẻ hiện ra ngay tức thì từ CSDL nội bộ, không có nhãn cảnh báo.
   - **Thao tác B (Ngoài CSDL):** Tra cứu *"Đảo Điệp Sơn"* $\rightarrow$ AI tự động tra cứu trên Internet, trả về thông tin con đường đi bộ giữa biển kèm banner vàng: *"Thông tin từ Internet, chưa qua kiểm duyệt"* và link bài viết gốc.
3. **Test AI Gợi Ý Theo Rating:**
   - **Thao tác:** Vào Tab "Gợi ý", chọn "Đà Lạt", chọn sở thích "Sống ảo", bấm "Gợi ý địa điểm".
   - **Kỳ vọng:** Xuất hiện các địa điểm có điểm đánh giá cao ($\ge$ 4.5 sao) kèm badge ⭐ và nút *"Thêm vào chuyến đi"*.
4. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
