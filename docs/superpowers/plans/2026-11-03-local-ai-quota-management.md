# Local AI Quota Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cung cấp tính năng quản lý hạn mức số lượt sử dụng AI Chatbot theo ngày cho User thường (Customer/Guest) với khả năng cấu hình từ màn hình Admin, đồng thời cấp quyền không giới hạn (Unlimited) cho tài khoản Admin.

**Architecture:** Sử dụng kiến trúc Client-side Quota Guard gọn nhẹ dựa trên `SharedPreferences`. Dữ liệu cấu hình hạn mức ngày (`dailyQuota`) được lưu trong `LocalAiSettings`. Dịch vụ `LocalAiQuotaService` theo dõi số lượt chat theo ngày lịch (`YYYY-MM-DD`). `AiChatProvider` kiểm tra quota trước khi gửi yêu cầu tới `LocalAiService`; nếu hết lượt và không phải Admin, provider trả về `LocalAiFailureCode.quotaExceeded` và chặn yêu cầu để bảo vệ tài nguyên máy tính. Giao diện `AiChatbotScreen` và `AdminAiManagementScreen` hiển thị chỉ báo quota và biểu mẫu điều chỉnh trực quan.

**Tech Stack:** Flutter/Dart, Provider state management, SharedPreferences, Flutter Test.

**Spec:** Quy tắc Stage-Gate Approval Protocol (AGENTS.md Law 5), Quy chuẩn Clean Architecture của dự án trong `.agent/rules.md`.

## Global Constraints

- Không thay đổi các test hiện có ngoài việc cập nhật tương thích với `dailyQuota`.
- Không gọi backend mutation hoặc tạo bảng database server mới; giữ giải pháp độc lập trên client an toàn cho demo.
- Không cho phép số âm hoặc 0 cho `dailyQuota`; giá trị hợp lệ nằm trong khoảng 1–1000 lượt/ngày.
- Tài khoản `admin` luôn được miễn trừ giới hạn (`isUnlimited == true`).
- Tuân thủ Verification SOP: Sau mỗi task chạy `flutter analyze` và `flutter test`.

## Review Focus

1. **Đổi ngày lịch (Midnight Rollover):** Khi sang ngày mới, số lượt đã dùng tự động reset về 0 mà không cần khởi động lại app.
2. **Admin miễn trừ tuyệt đối:** Admin gửi chat liên tục không bao giờ bị chặn bởi quota.
3. **Chặn yêu cầu trước khi gọi AI:** Khi hết quota, `AiChatProvider` không thực hiện HTTP request đến Ollama, tiết kiệm tài nguyên.
4. **Hiển thị giao diện rõ ràng:** Màn hình chat hiển thị số lượt còn lại (ví dụ: `Còn 10/10 lượt hôm nay`) và chuyển sang trạng thái cảnh báo khi chạm 0.
5. **Cấu hình Admin lưu thành công:** Admin đổi quota từ 10 thành 20 thì User áp dụng ngay mức 20 sau khi cấu hình được lưu.

---

### Task 1: Bổ sung `quotaExceeded` vào `LocalAiFailureCode` và `dailyQuota` vào `LocalAiSettings`

**Files:**
- Modify: `lib/features/trip_planner/models/local_ai_models.dart:3-12`
- Modify: `lib/features/trip_planner/models/local_ai_settings.dart:15-64`
- Modify: `test/local_ai_settings_test.dart`

**Interfaces:**
- Produces: `LocalAiFailureCode.quotaExceeded`
- Produces: `LocalAiSettings.dailyQuota` (int, default: 10, valid: 1..1000)

- [ ] **Step 1: Viết test kiểm tra `dailyQuota` trong `test/local_ai_settings_test.dart`**
  - Kiểm tra `LocalAiSettings()` có `dailyQuota == 10`.
  - Kiểm tra serialization `toJson()` và `fromJson()` giữ nguyên `dailyQuota`.
  - Kiểm tra `dailyQuota <= 0` hoặc `> 1000` ném `FormatException`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
  - Run: `flutter test test/local_ai_settings_test.dart`

- [ ] **Step 3: Cập nhật `LocalAiFailureCode` và `LocalAiSettings`**
  - Thêm `quotaExceeded` vào `enum LocalAiFailureCode`.
  - Thêm thuộc tính `final int dailyQuota;` vào `LocalAiSettings` với validation.

- [ ] **Step 4: Chạy test để xác nhận PASS**
  - Run: `flutter test test/local_ai_settings_test.dart`

---

### Task 2: Xây dựng `LocalAiQuotaService` theo dõi lượt dùng theo ngày

**Files:**
- Create: `lib/features/ai_chat/services/local_ai_quota_service.dart`
- Create: `test/local_ai_quota_service_test.dart`

**Interfaces:**
- Produces: `class LocalAiQuotaService`
  - `Future<int> getUsedCountToday()`
  - `Future<int> getRemainingQuota({required int dailyQuota, required bool isAdmin})`
  - `Future<bool> canSend({required int dailyQuota, required bool isAdmin})`
  - `Future<int> recordUsage({required bool isAdmin})`
  - `Future<void> resetTodayQuota()`

- [ ] **Step 1: Viết unit tests trong `test/local_ai_quota_service_test.dart`**
  - Kiểm tra ngày mới trả về used = 0.
  - Kiểm tra `recordUsage` tăng used count khi không phải admin.
  - Kiểm tra `recordUsage` không tăng khi là admin.
  - Kiểm tra `canSend` trả về false khi used == dailyQuota và không phải admin.
  - Kiểm tra `canSend` luôn trả về true cho admin.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
  - Run: `flutter test test/local_ai_quota_service_test.dart`

- [ ] **Step 3: Cài đặt `LocalAiQuotaService`**
  - Cài đặt đọc/ghi mốc ngày `YYYY-MM-DD` và bộ đếm qua `SharedPreferences`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
  - Run: `flutter test test/local_ai_quota_service_test.dart`

---

### Task 3: Tích hợp Quota Guard vào `AiChatProvider`

**Files:**
- Modify: `lib/features/ai_chat/providers/ai_chat_provider.dart`
- Modify: `test/local_ai_chat_provider_test.dart`

**Interfaces:**
- Consumes: `LocalAiQuotaService`
- Produces:
  - `bool get isAdmin`
  - `int get remainingQuota`
  - `void updateRole({required bool isAdmin})`
  - `Future<void> refreshQuota()`
  - Chặn `sendMessage` khi `!canSend` do quota và gán lỗi `LocalAiFailureCode.quotaExceeded`.

- [ ] **Step 1: Viết test cho `AiChatProvider` quota enforcement trong `test/local_ai_chat_provider_test.dart`**
  - Test: khi quota còn 0 và user không phải admin, `sendMessage` không gọi `aiService` và báo lỗi `LocalAiFailureCode.quotaExceeded`.
  - Test: khi user là admin, `sendMessage` vẫn gửi thành công dù used count chạm trần.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
  - Run: `flutter test test/local_ai_chat_provider_test.dart`

- [ ] **Step 3: Cập nhật `AiChatProvider`**
  - Tích hợp `LocalAiQuotaService`.
  - Thêm getter `remainingQuota`, `isAdmin`.
  - Kiểm tra quota trước `_sendExisting`. Nếu hết lượt, ném `LocalAiFailure(LocalAiFailureCode.quotaExceeded, ...)`.
  - Ghi nhận lượt sau khi `aiService.requestReply` thành công.

- [ ] **Step 4: Chạy test để xác nhận PASS**
  - Run: `flutter test test/local_ai_chat_provider_test.dart`

---

### Task 4: Cập nhật màn hình `AdminAiManagementScreen` cho phép chỉnh `dailyQuota`

**Files:**
- Modify: `lib/features/admin/presentation/screens/admin_ai_management_screen.dart`
- Modify: `test/admin_ai_management_test.dart`

**Interfaces:**
- Produces: Trường nhập liệu `ollama_quota_field` trên form cấu hình Admin.
- Validation: 1..1000.

- [ ] **Step 1: Viết widget test trong `test/admin_ai_management_test.dart`**
  - Test trường quota hiển thị giá trị hiện tại (10).
  - Test nhập giá trị không hợp lệ (0, -5, chữ) hiển thị lỗi validation.
  - Test lưu giá trị mới (ví dụ: 25) được ghi vào `LocalAiSettingsStore`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
  - Run: `flutter test test/admin_ai_management_test.dart`

- [ ] **Step 3: Thêm `TextFormField` cho `dailyQuota` vào `AdminAiManagementScreen`**
  - Bổ sung `TextEditingController _dailyQuota`.
  - Đọc và lưu `dailyQuota` trong `_load()` và `_save()`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
  - Run: `flutter test test/admin_ai_management_test.dart`

---

### Task 5: Cập nhật giao diện `AiChatbotScreen` hiển thị Quota Badge và thông báo hết lượt

**Files:**
- Modify: `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart`

**Interfaces:**
- Hiển thị badge: `Hôm nay: còn X/Y lượt` (hoặc `Không giới hạn (Admin)`).
- Hiển thị banner/thông báo cảnh báo khi hết lượt và vô hiệu hóa nút gửi.
- Cập nhật vai trò từ `AuthProvider` sang `AiChatProvider`.

- [ ] **Step 1: Cập nhật `AiChatbotScreen`**
  - Trong `initState` / `build`: lấy `AuthProvider`, truyền `isAdmin = auth?.currentUser?.role == 'admin'` vào `AiChatProvider.updateRole`.
  - Hiển thị chip thông tin số lượt còn lại ở AppBar hoặc dưới tiêu đề.
  - Khi hết lượt, hiển thị thông báo thân thiện và vô hiệu hoá nút gửi.

- [ ] **Step 2: Chạy kiểm tra tĩnh và test giao diện**
  - Run: `flutter analyze`

---

### Task 6: Kiểm thử toàn diện và Bàn giao (Verification SOP)

- [ ] **Step 1: Chạy `flutter analyze` đảm bảo 0 issues.**
- [ ] **Step 2: Chạy toàn bộ test suites liên quan đến AI và Admin.**
  - `flutter test test/local_ai_settings_test.dart test/local_ai_quota_service_test.dart test/local_ai_chat_provider_test.dart test/admin_ai_management_test.dart`
- [ ] **Step 3: Tạo báo cáo bàn giao Handover Report chuẩn AGENTS.md.**
