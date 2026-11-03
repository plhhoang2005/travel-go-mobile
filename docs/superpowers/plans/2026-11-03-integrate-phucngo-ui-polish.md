# Kế hoạch Triển khai: Tích hợp Tinh hoa UI/UX từ PR #57 (Phúc Ngô) An toàn & Chuẩn mực

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chắt lọc và tích hợp toàn bộ cải tiến UI/UX xuất sắc từ PR #57 của bạn Phúc (`phucngo1707`) vào nhánh `main` mới nhất (đã có PR #58), đảm bảo bảo toàn 100% tính năng Quota AI, Map Sync, và nút lưu chuyến của Hậu, đồng thời loại bỏ rủi ro thư viện native chưa cấu hình và ảnh nhị phân nặng.

**Architecture:** 
- Tái cấu trúc dựa trên nhánh mới `integrate/phucngo-ui-polish` bắt nguồn từ `origin/main` (commit `f3958cc`).
- Áp dụng các widget UI độc lập của Phúc: Linh vật vector `GoAiMascot`, bộ gom nhóm hoạt động theo ngày `_buildGroupedActivities`, bảng so sánh trước/sau khi lưu `manual_save_preview.dart`, phân tab chi tiết điểm đến và rút gọn nhận xét `_ExpandableReviewComment`.
- Giữ nguyên vẹn 100% logic dịch vụ nền tảng: `LocalAiQuotaService`, `AdminAccountProvider`, `EditableTripService` (`clearPendingSave`), `CatalogueDiscoveryMapScreen`.
- Về Avatar Profile: Không dùng `image_picker` native gây rủi ro crash Android/iOS; triển khai giải pháp thuần Flutter với Avatar Presets + Image URL sạch sẽ.

**Tech Stack:** Flutter / Dart, Provider, CustomPainter vector graphics, fl_chart, flutter_map.

**Spec:** Theo yêu cầu của Tech Lead/Owner, tuân thủ `.agent/product-scope.md` và `AGENTS.md`.

---

## Global Constraints

- **KHÔNG** push trực tiếp vào nhánh `main` (tuân thủ Human Merge Gate).
- **KHÔNG** thêm dependency `image_picker` vào `pubspec.yaml` (giữ an toàn Permission Boundary, không sửa `AndroidManifest.xml`).
- **KHÔNG** commit các file ảnh nhị phân nặng trong `img/` vào git repository.
- **BẢO TOÀN 100%**:
  - Hạn mức Quota AI (Admin không giới hạn, User giới hạn theo ngày, chỉnh sửa quota trên Admin AI screen).
  - Bản vá lỗi kẹt nút lưu chuyến (`clearPendingSave`, `detachBaseForNewSave`) của Hậu.
  - Bộ chọn giờ bắt đầu/kết thúc trên form khoản chi dự kiến.
  - Tìm kiếm không dấu cộng đồng và quyền tác giả xoá chuyến đi.
- **Tiêu chuẩn nghiệm thu**: `flutter analyze` 0 warnings, 0 errors; `flutter test` toàn bộ bài test liên quan pass 100%.

---

## Review Focus

1. **Quota AI không bị mất khi gắn GoAiMascot vào Chatbot**: AppBar của `AiChatbotScreen` phải hiển thị badge quota và tự động khóa ô nhập khi hết lượt.
2. **Kẹt nút lưu chuyến đi không bị tái diễn**: Nút lưu trong `manual_planner_screen.dart` và `manual_save_preview.dart` phải gọi đúng các luồng mở khóa khi có lỗi từ server.
3. **Màn hình Profile không crash khi bấm đổi Avatar**: Modal đổi avatar hiển thị danh sách ảnh mẫu (presets) và ô nhập URL, lưu thành công vào `AuthProvider` mà không cần quyền thiết bị native.
4. **Giao diện Chi tiết Điểm đến không làm gãy test**: Đảm bảo các widget keys (`toggle-place-...`, `visit-price-...`) hoạt động trơn tru trong cả giao diện người dùng và widget test.
5. **Hiệu năng & Tràn viền (Overflow-safe)**: Mọi text nhận xét dài phải co giãn mượt mà với `_ExpandableReviewComment` trên màn hình nhỏ (360px).

---

## Danh sách Task Thực thi Chi tiết

### Task 1: Khởi tạo Nhánh Tích hợp từ Main & Bổ sung Linh vật `GoAiMascot`
**Files:**
- Create: `lib/core/widgets/go_ai_mascot.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/widget_test.dart` hoặc widget test kiểm tra render mascot

- [ ] **Step 1: Chuyển sang nhánh mới `integrate/phucngo-ui-polish` từ `origin/main`**
```bash
git checkout -b integrate/phucngo-ui-polish origin/main
```
- [ ] **Step 2: Cập nhật `lib/core/theme/app_theme.dart`**
Bổ sung các mã màu thương hiệu mới (`tealPrimary`, `mintLight`, `coralColor`, `warmCream`, `amberAccent`) và tối ưu radius button/chip vừa phải (16-20px), giữ tương thích toàn hệ thống.
- [ ] **Step 3: Tạo mới `lib/core/widgets/go_ai_mascot.dart`**
Triển khai widget linh vật GoAI sử dụng `CustomPainter` vector thuần Flutter (không phụ thuộc asset ảnh ngoài).
- [ ] **Step 4: Kiểm tra phân tích tĩnh**
Chạy: `flutter analyze`
Kỳ vọng: 0 errors.
- [ ] **Step 5: Commit Task 1**
```bash
git add lib/core/widgets/go_ai_mascot.dart lib/core/theme/app_theme.dart
git commit -m "feat(ui): add GoAiMascot vector widget and brand color tokens"
```

---

### Task 2: Gắn Linh vật GoAI vào FAB Navigation, Banner Trang Chủ & Tích hợp Quota Chatbot
**Files:**
- Modify: `lib/features/navigation/presentation/screens/main_navigation_shell.dart`
- Modify: `lib/features/home/presentation/screens/main_home_screen.dart`
- Modify: `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart`
- Test: `test/ai_chat_flow_test.dart`

- [ ] **Step 1: Cập nhật FAB trong `main_navigation_shell.dart`**
Thay nút FAB dài bằng nút tròn có linh vật `GoAiMascot(size: 44)` kèm badge sao lấp lánh và tooltip rõ ràng.
- [ ] **Step 2: Cập nhật Banner Chào mừng trong `main_home_screen.dart`**
Thêm chú sóc GoAI vẫy tay (`isWaving: true`) bên cạnh lời chào khám phá du lịch Việt Nam.
- [ ] **Step 3: Tích hợp GoAI vào `ai_chatbot_screen.dart` mà BẢO TOÀN QUOTA AI**
Giữ nguyên vẹn 100% `LocalAiQuotaService`, badge quota trên AppBar (`Còn X/10 lượt` hoặc `Admin · Không giới hạn`), trạng thái khóa nhập khi hết lượt, kết hợp với avatar linh vật GoAI trong bong bóng tin nhắn của trợ lý.
- [ ] **Step 4: Chạy test luồng AI Chat**
Chạy: `flutter test test/ai_chat_flow_test.dart`
Kỳ vọng: PASS 100%.
- [ ] **Step 5: Commit Task 2**
```bash
git add lib/features/navigation/presentation/screens/main_navigation_shell.dart lib/features/home/presentation/screens/main_home_screen.dart lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart
git commit -m "feat(ui,ai): integrate GoAi mascot into FAB, home header, and chat with quota guard"
```

---

### Task 3: Tích hợp Giao diện Xem Trước Lịch Trình theo Ngày & So Sánh Lưu Chuyến Đi
**Files:**
- Modify: `lib/features/trip_planner/presentation/widgets/ai_generation_preview.dart`
- Modify: `lib/features/trip_planner/presentation/widgets/manual_save_preview.dart`
- Modify: `lib/features/trip_planner/presentation/widgets/manual_budget_panel.dart`
- Test: `test/manual_planner_test.dart`

- [ ] **Step 1: Cập nhật `ai_generation_preview.dart`**
Tích hợp hàm `_buildGroupedActivities` phân nhóm các hoạt động AI đề xuất theo Ngày 1, Ngày 2... kèm chip và đường kẻ phân cách timeline trực quan.
- [ ] **Step 2: Cập nhật `manual_save_preview.dart`**
Bổ sung danh sách chi tiết các thay đổi trước khi lưu (`_previewChanges`: tên chuyến, số người, thời gian, ngân sách, lý do chấp nhận cảnh báo). Giữ nguyên vẹn logic mở khóa kẹt nút lưu.
- [ ] **Step 3: Tinh chỉnh `manual_budget_panel.dart`**
Cập nhật bố cục thẻ chi phí gọn gàng, sắc nét.
- [ ] **Step 4: Chạy test luồng Trip Planner**
Chạy: `flutter test test/manual_planner_test.dart`
Kỳ vọng: PASS 100%.
- [ ] **Step 5: Commit Task 3**
```bash
git add lib/features/trip_planner/presentation/widgets/ai_generation_preview.dart lib/features/trip_planner/presentation/widgets/manual_save_preview.dart lib/features/trip_planner/presentation/widgets/manual_budget_panel.dart
git commit -m "feat(planner): group proposed activities by day and show comprehensive diff in save preview"
```

---

### Task 4: Cải tiến Chi Tiết Điểm Đến, Mở Rộng Nhận Xét & Giao Diện Profile An Toàn
**Files:**
- Modify: `lib/features/explore/presentation/screens/destination_detail_screen.dart`
- Modify: `lib/features/reviews/presentation/widgets/place_review_tile.dart`
- Modify: `lib/features/community/presentation/screens/shared_trip_detail_screen.dart`
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`
- Create: `test/place_review_tile_test.dart`
- Test: `test/destination_detail_test.dart`, `test/place_review_tile_test.dart`

- [ ] **Step 1: Cập nhật `destination_detail_screen.dart`**
Chia 2 tab *Tổng quan* và *Điểm tham quan*, hỗ trợ accordion mở rộng từng địa điểm tham quan mà không làm gãy các test case hiện có.
- [ ] **Step 2: Thêm `_ExpandableReviewComment` và `PlaceReviewTile` mở rộng/thu gọn**
Tích hợp logic tự động rút gọn nhận xét quá 3 dòng kèm nút *Xem thêm / Thu gọn*, chống tràn màn hình.
- [ ] **Step 3: Nâng cấp `profile_screen.dart` theo phong cách mới của Phúc NHƯNG KHÔNG DÙNG NATIVE IMAGE_PICKER**
Hỗ trợ chọn từ 6 Avatar mẫu chuẩn du lịch + nhập đường dẫn ảnh trực tiếp, cập nhật vào `AuthProvider` mượt mà, bảo mật tuyệt đối, 100% không crash.
- [ ] **Step 4: Chạy test chi tiết điểm đến và nhận xét**
Chạy: `flutter test test/destination_detail_test.dart test/place_review_tile_test.dart`
Kỳ vọng: PASS 100%.
- [ ] **Step 5: Commit Task 4**
```bash
git add lib/features/explore/presentation/screens/destination_detail_screen.dart lib/features/reviews/presentation/widgets/place_review_tile.dart lib/features/community/presentation/screens/shared_trip_detail_screen.dart lib/features/profile/presentation/screens/profile_screen.dart test/place_review_tile_test.dart
git commit -m "feat(ui): add tabbed destination details, expandable reviews, and safe avatar presets"
```

---

### Task 5: Kiểm Thử Toàn Diện Toàn Bộ Hệ Thống (Verification & CI Readiness)
**Files:**
- Toàn bộ codebase liên quan

- [ ] **Step 1: Chạy phân tích tĩnh mã nguồn**
Chạy: `flutter analyze`
Kỳ vọng: `No issues found!`
- [ ] **Step 2: Chạy kiểm thử toàn bộ các bộ test trọng yếu**
Chạy:
```bash
flutter test test/coursework_admin_account_flow_test.dart
flutter test test/manual_planner_test.dart
flutter test test/ai_chat_flow_test.dart
flutter test test/destination_detail_test.dart
flutter test test/place_review_tile_test.dart
flutter test test/discovery_screen_test.dart
flutter test test/community_service_test.dart
```
Kỳ vọng: Tất cả bài test đều PASS 100%.
- [ ] **Step 3: Báo cáo kết quả và trình Tech Lead tạo Pull Request tích hợp**
Gửi Handover Report đầy đủ 5 mục theo AGENTS.md.
