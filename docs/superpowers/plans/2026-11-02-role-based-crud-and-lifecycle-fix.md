# Kế Hoạch Triển Khai Chi Tiết: Sửa Lỗi Phím Đa Nhiệm Mất Session & Kịch Bản Test Tự Động Toàn Diện CRUD Theo Roles

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để lỗi phím đa nhiệm (nút hình chữ nhật / Overview) làm mất phiên đăng nhập khi ẩn ứng dụng, đồng thời xây dựng kịch bản kiểm thử tự động toàn diện các chức năng CRUD cơ bản phân loại chi tiết theo từng vai trò người dùng (Guest, Customer, Admin).

**Architecture:** 
1. Cải tiến logic `handleAppLifecycleState` trong `AuthProvider`: chỉ thu hồi ngữ cảnh tài khoản khi ứng dụng bị huỷ hoàn toàn (`AppLifecycleState.detached`). Khi ứng dụng bị tạm dừng (`inactive`, `paused`, `hidden`), hệ thống niêm phong bảo vệ ngữ cảnh an toàn và tự động phục hồi nguyên vẹn khi người dùng quay lại (`resumed`), không xoá `_currentUser`.
2. Xây dựng bộ kiểm thử phân quyền 3 tầng (Role-Based CRUD Flow) bao quát đầy đủ hành vi: Khách (Guest Drafts), Người dùng thường (Customer Itinerary CRUD & Reviews & Community Clone), và Quản trị viên (Admin Catalogue & Visibility Controls).

**Tech Stack:** Flutter 3.x, Dart 3.x, Provider, Supabase Auth/Lifecycle, Material 3, Flutter Test & Integration Test.

**Spec:** Yêu cầu người dùng (Role-based CRUD test scenario & Android overview lifecycle fix).

---

## Global Constraints
- Không được phá vỡ 1.306 bài test hiện có của dự án.
- Giữ nguyên kiến trúc Feature-First và các quy chuẩn phân quyền trong `rules.md` (Law 2, Law 3, Law 4).
- Phải đảm bảo `flutter analyze` đạt 0 issues và `flutter test` đạt 100% PASS.

## Review Focus
1. **Chuyển đổi đa nhiệm không mất session**: Khi chuyển từ `resumed` sang `inactive` $\rightarrow$ `paused` rồi quay lại `resumed`, thông tin `currentUser` và quyền hạn vẫn phải giữ nguyên 100%.
2. **Guest Isolation**: Khách tạo chuyến đi nháp cục bộ trong SQLite mà không được phép lưu vào tài khoản hay gửi review công khai nếu chưa đăng nhập.
3. **Customer Trip CRUD**: Tạo chuyến đi (thủ công/AI) $\rightarrow$ Đọc hiển thị $\rightarrow$ Sửa hoạt động/ngân sách $\rightarrow$ Xoá chuyến đi với popup xác nhận an toàn.
4. **Admin Access Control**: Quyền ẩn/hiện địa điểm trên bản đồ chỉ dành riêng cho Admin, Customer và Guest không nhìn thấy nút này.
5. **Dọn dẹp bộ nhớ**: Toàn bộ Controller, Provider mock và database connection phải được dispose sau khi chạy test để chống rò rỉ bộ nhớ.

---

### Task 1: Khắc Phục Lỗi Mất Đăng Nhập Khi Nhấn Phím Đa Nhiệm (Overview / App Lifecycle)

**Files:**
- Modify: `lib/features/auth/providers/auth_provider.dart:1500-1535`
- Test: `test/auth_lifecycle_background_test.dart`

**Interfaces:**
- Consumes: `AppLifecycleState` từ Flutter WidgetsBinding.
- Produces: `AuthProvider.handleAppLifecycleState(AppLifecycleState)` bảo toàn `_currentUser` khi app ở chế độ nền.

- [ ] **Step 1: Viết test kiểm chứng lỗi (Failing Test)**
  Tạo `test/auth_lifecycle_background_test.dart` mô phỏng hành vi bấm phím đa nhiệm:
  - Khởi tạo `AuthProvider` đăng nhập tài khoản (demo Customer hoặc live).
  - Gọi `auth.handleAppLifecycleState(AppLifecycleState.inactive)`.
  - Gọi `auth.handleAppLifecycleState(AppLifecycleState.paused)`.
  - Kiểm tra `auth.isAuthenticated` vẫn phải là `true`, `auth.currentUser` không bị gán về `null`.
  - Gọi `auth.handleAppLifecycleState(AppLifecycleState.resumed)`.
  - Xác nhận phiên hoạt động bình thường, không bị đá về Guest hay Login.

- [ ] **Step 2: Chạy test để xác nhận test thất bại (Red)**
  Chạy lệnh: `flutter test test/auth_lifecycle_background_test.dart`
  Kỳ vọng: Thất bại do `onLocalAccountInvalidated()` hiện tại xoá `_currentUser = null`.

- [ ] **Step 3: Cập nhật logic trong `auth_provider.dart`**
  Trong `handleAppLifecycleState`:
  - Chỉ gọi `onLocalAccountInvalidated()` khi `state == AppLifecycleState.detached`.
  - Với `inactive`, `hidden`, `paused`: giữ nguyên `_currentUser`, chỉ gọi `suspendForegroundContext()` và `sealForPause()`.
  - Với `resumed`: phục hồi ngữ cảnh qua `resumeForegroundContext()` và tiếp tục phiên làm việc mượt mà.

- [ ] **Step 4: Chạy lại test xác nhận thành công (Green)**
  Chạy lệnh: `flutter test test/auth_lifecycle_background_test.dart`
  Kỳ vọng: PASS.

- [ ] **Step 5: Chạy toàn bộ test Auth hiện có**
  Chạy lệnh: `flutter test test/auth_navigation_test.dart`
  Kỳ vọng: Tất cả bài test lifecycle cũ vẫn vượt qua 100%.

- [ ] **Step 6: Commit**
  ```bash
  git add lib/features/auth/providers/auth_provider.dart test/auth_lifecycle_background_test.dart
  git commit -m "fix(auth): preserve user session across background and overview app lifecycle transitions"
  ```

---

### Task 2: Xây Dựng Kịch Bản Test Tự Động CRUD Theo Từng Roles (`test/role_based_crud_flow_test.dart`)

**Files:**
- Create: `test/role_based_crud_flow_test.dart`

**Interfaces:**
- Consumes: `AuthProvider`, `DiscoveryProvider`, `TripProvider`, `ManualPlannerProvider`, `SavedTripsProvider`, `PlaceReviewsProvider`, `CommunityService`.
- Produces: Kịch bản kiểm thử headless độc lập bao quát trọn vẹn 3 vai trò người dùng.

- [ ] **Step 1: Viết kịch bản kiểm thử Nhóm 1 - Khách (Guest Role)**
  - Người dùng truy cập ở chế độ Guest (`continueAsGuest`).
  - Khám phá danh mục điểm đến công khai.
  - Tự lập lịch trình chuyến đi nháp cục bộ (Guest Draft).
  - Kiểm tra tính năng bảo vệ: Khi cố gắng gửi đánh giá hoặc sao chép chuyến đi lên đám mây, hệ thống yêu cầu đăng nhập (bảo vệ quyền truy cập).

- [ ] **Step 2: Viết kịch bản kiểm thử Nhóm 2 - Người Dùng Thường (Customer Role)**
  - Đăng nhập với quyền `UserRole.customer` (Minh).
  - **Create**: Tạo một chuyến đi mới (Manual / AI) với các hoạt động cụ thể (Điểm đến: Đà Lạt, 3 ngày).
  - **Read**: Truy cập `MyTripsScreen`, xác nhận chuyến đi xuất hiện trong danh sách.
  - **Update**: Mở `EditableTripDetailScreen`, thêm 1 hoạt động mới vào Ngày 1, đổi ngân sách dự kiến, lưu thay đổi thành công.
  - **Delete**: Nhấn nút Xoá chuyến đi, hộp thoại xác nhận hiện ra, chọn xác nhận xoá và kiểm tra danh sách đã được dọn sạch.
  - **Reviews CRUD**: Mở địa danh, tạo 1 đánh giá 5 sao kèm bình luận, kiểm tra đánh giá hiển thị trên danh sách.
  - **Phím Đa Nhiệm**: Ẩn app xuống background rồi mở lại, xác nhận dữ liệu và phiên người dùng vẫn nguyên vẹn.

- [ ] **Step 3: Viết kịch bản kiểm thử Nhóm 3 - Quản Trị Viên (Admin Role)**
  - Đăng nhập với quyền `UserRole.admin`.
  - Mở Admin Dashboard, kiểm tra các thẻ chỉ số và nút chuyển đổi chu kỳ 7/30 ngày.
  - Mở Bản đồ khám phá (`CatalogueDiscoveryMapScreen`): Kiểm tra quyền Admin có thêm nút biểu tượng Ẩn/Hiện địa điểm (`Icons.visibility_off`).
  - Thử ẩn một địa điểm và khôi phục lại, kiểm tra SnackBar thông báo xác nhận thành công.

- [ ] **Step 4: Chạy kịch bản kiểm thử tự động**
  Chạy lệnh: `flutter test test/role_based_crud_flow_test.dart`
  Kỳ vọng: Toàn bộ 3 vai trò Guest, Customer, Admin chạy trơn tru và vượt qua 100%.

- [ ] **Step 5: Commit**
  ```bash
  git add test/role_based_crud_flow_test.dart
  git commit -m "test(crud): add automated role-based CRUD test suite for guest, customer, and admin"
  ```

---

### Task 3: Kịch Bản Chạy Trên Máy Ảo Android / Thiết Bị Thật (`integration_test/role_based_crud_test.dart`)

**Files:**
- Create: `integration_test/role_based_crud_test.dart`

**Interfaces:**
- Consumes: `IntegrationTestWidgetsFlutterBinding`.
- Produces: File kiểm thử On-Device có thể chạy trực tiếp bằng `flutter test integration_test/role_based_crud_test.dart` trên máy ảo Android.

- [ ] **Step 1: Viết Integration Test Driver**
  Thiết lập `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` và tích hợp toàn bộ luồng 3 Roles với giao diện thực tế.

- [ ] **Step 2: Kiểm tra cú pháp và kiểu dữ liệu**
  Chạy lệnh: `flutter analyze`
  Kỳ vọng: 0 lỗi, 0 cảnh báo.

- [ ] **Step 3: Commit**
  ```bash
  git add integration_test/role_based_crud_test.dart
  git commit -m "test(integration): add on-device role-based CRUD integration test"
  ```

---

### Task 4: Kiểm Tra Hồi Quy Toàn Bộ Dự Án & Bàn Giao

- [ ] **Step 1: Chạy kiểm tra tĩnh toàn diện**
  Chạy lệnh: `flutter analyze`
  Kỳ vọng: 0 issues found.

- [ ] **Step 2: Chạy toàn bộ test suite dự án**
  Chạy lệnh: `flutter test`
  Kỳ vọng: Toàn bộ 1.306+ bài test đều PASS.

- [ ] **Step 3: Báo cáo bàn giao chi tiết cho Tech Lead theo mẫu chuẩn 5 mục.**
