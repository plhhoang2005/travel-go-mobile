# Bàn giao Sửa Dữ liệu Quản trị và Đồng bộ Bản đồ — 03/11/2026

## 1. Tóm tắt cho Owner / Tech Lead

Đã hoàn thành toàn bộ 5 Task trong Kế hoạch **Admin Data Repair and Map Sync** (`docs/superpowers/plans/2026-11-03-admin-data-repair-and-map-sync.md`) trên nhánh `codex/admin-data-repair-map-sync`.
* **Vừa làm gì:**
  1. Khắc phục lỗi tải danh sách tài khoản Admin (tăng Dio timeout từ 5s lên 15s/20s; nới lỏng DTO decode `UserSummary` hỗ trợ vai trò `partner` và fallback an toàn khi `fullName`/`email` trống).
  2. Xử lý dứt điểm lỗi RPC `prepare_discovery_preview` thiếu hàm `public.digest` (`SQLSTATE 42883`) bằng migration tạo 2 hàm wrapper `public.digest(text, text)` và `public.digest(bytea, text)` trỏ về `extensions.digest` của `pgcrypto`.
  3. Đảm bảo form địa điểm không tự ý gán toạ độ mặc định ngầm (giữ giá trị null "Chưa có vị trí" nếu người dùng không bấm "Toạ độ mẫu"), chống tạo trùng khi thử lại lưu nháp.
  4. Chuẩn hóa Bản đồ Khám phá: tự động rebind điểm đến và địa điểm khi snapshot xuất bản thay đổi (tự động unselect nếu điểm đến bị ẩn/xóa), bỏ ghim lệch tâm giả khi địa điểm thiếu toạ độ, loại bỏ snackbar ảo.
* **Để làm gì:** Giúp luồng Quản trị (Admin) hoạt động ổn định trên môi trường Supabase thật, dữ liệu sau khi xuất bản đồng bộ trung thực sang Bản đồ và Khám phá phía người dùng.
* **Ảnh hưởng:** Các chức năng người dùng chính (Auth, Trips, Lập lịch, Ngân sách, Chatbot AI Local) tiếp tục hoạt động trơn tru. Giao diện Admin không còn bị văng phiên hoặc báo lỗi kết nối giả định.
* **Đã kiểm tra tới đâu:**
  - `flutter analyze`: **No issues found** (0 warnings, 0 errors).
  - Toàn bộ nhóm kiểm thử Admin & Map: **70/70 tests PASS** (`flutter test`).
  - Toàn bộ nhóm kiểm thử hợp đồng Gateway & Storage: **37/37 tests PASS** (`node --test`).

---

## 2. Changed (Danh sách tệp thay đổi)

1. `lib/features/admin/models/admin_account_models.dart`: Hỗ trợ role `'partner'`, fallback `fullName` thành `'Chưa đặt tên'` và `email` thành `'Chưa có email'` thay vì ném `FormatException`.
2. `lib/features/admin/presentation/screens/admin_shell_screen.dart`: Cấu hình timeout Dio trong `_createAdminDio()` (15s connect, 20s receive, 15s send) phòng ngừa cold-start và mạng di động trễ.
3. `lib/features/admin/providers/admin_account_provider.dart`: Chỉ gọi `_fail(f)` thu hồi quyền khi lỗi phân quyền thật (`forbidden`, `unauthorized`, `account_locked`, `actor_role_revoked`); các lỗi mạng khác giữ lại để hiển thị banner thử lại.
4. `lib/features/admin/providers/admin_catalogue_provider.dart`: Dịch thông báo lỗi `public.digest` / `42883` thành tiếng Việt rõ ràng, giữ trạng thái `savedNotPublished` khi bản nháp đã được lưu thành công trên máy chủ.
5. `lib/features/admin/presentation/widgets/admin_place_form.dart`: Giữ toạ độ null khi người dùng không nhập hoặc không chọn toạ độ mẫu, đổi nhãn thành "Tuỳ chọn".
6. `lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart`: Rebind `_selectedDestination` và `_selectedMarker` theo snapshot mới; bỏ marker giả lệch tâm; thay thông báo ẩn cục bộ bằng hướng dẫn quản trị trung thực.
7. `supabase/migrations/20261103140000_fix_pgcrypto_digest.sql`: Migration PostgreSQL chuẩn hoá 2 hàm `public.digest` tương thích ngược.
8. `tool/verify-flutter-admin.ps1`: Tích hợp migration digest vào chế độ kiểm thử Publication.
9. `test/admin_account_service_test.dart`: Bổ sung test DTO cho role `partner` và fallback null.
10. `test/admin_account_provider_test.dart`: Bổ sung test thu hồi quyền khi forbidden và bảo lưu quyền khi gặp lỗi mạng.
11. `test/admin_catalogue_forms_test.dart`: Bổ sung test không gán toạ độ mặc định ngầm.
12. `test/catalogue_discovery_map_screen_test.dart`: Bổ sung test không tạo ghim giả và tự động unselect khi điểm đến bị ẩn.

---

## 3. Why (Căn cứ kỹ thuật)

1. **DTO Decode**: Schema `public.profiles` cho phép `role IN ('customer', 'partner', 'admin')` và `full_name` có thể null. Parser cũ chỉ chấp nhận `customer`/`admin` và `full_name` dạng String không null, dẫn tới lỗi `invalid_response` làm sập danh sách người dùng.
2. **PostgreSQL search_path**: `prepare_discovery_preview` chạy với `SECURITY DEFINER SET search_path = ''` và gọi `public.digest()`. Do Supabase cài `pgcrypto` trong schema `extensions`, hàm `public.digest` không tồn tại (SQLSTATE 42883). Tạo hàm wrapper IMMUTABLE trong `public` là giải pháp an toàn nhất, tương thích 100% với các RPC hiện có mà không cần sửa đổi bảng hay thuật toán băm SHA-256.
3. **Data Integrity trên Bản đồ**: Bản đồ không được hiển thị vị trí giả lệch tâm quanh điểm đến khi địa điểm thực tế chưa có toạ độ. Thao tác ẩn địa điểm phải có hiệu lực toàn hệ thống qua pipeline lưu nháp $\rightarrow$ xuất bản, không dùng state cục bộ tạm thời.

---

## 4. Testing (Kết quả kiểm thử)

### 4.1. Phân tích tĩnh
```powershell
flutter analyze
# Output: No issues found! (ran in 3.5s)
```

### 4.2. Kiểm thử tự động Dart / Flutter
```powershell
flutter test test/admin_account_service_test.dart test/admin_account_provider_test.dart test/admin_account_ui_test.dart test/admin_catalogue_provider_test.dart test/admin_catalogue_forms_test.dart test/admin_catalogue_publish_flow_test.dart test/admin_publication_provider_test.dart test/catalogue_discovery_map_screen_test.dart test/map_feature_test_suite.dart
# Output: 00:04 +70: All tests passed! (70/70 PASS)
```

### 4.3. Kiểm thử hợp đồng Node.js
```powershell
node --test test/admin_control_gateway_test.mjs test/admin_account_gateway_test.mjs test/admin_publication_storage_test.mjs test/discovery_public_bundle_test.mjs test/admin_publication_gateway_test.mjs
# Output: ℹ tests 37, pass 37, fail 0 (37/37 PASS)
```

---

## 5. Problems & Deployment Note

- **Áp dụng lên Supabase thật:** Để sửa dứt điểm lỗi `SQLSTATE 42883` trên môi trường Supabase production của owner, cần chạy tệp migration `supabase/migrations/20261103140000_fix_pgcrypto_digest.sql` trong giao diện SQL Editor của Supabase Dashboard.
- **Không tự động push/merge:** Toàn bộ thay đổi đang nằm trên nhánh làm việc `codex/admin-data-repair-map-sync`, tuân thủ nghiêm ngặt Git Safety và Human Merge Gate.

---

## 6. Lesson Candidate

* **Problem:** RPC Supabase báo lỗi `function public.digest does not exist (SQLSTATE 42883)` dù extension `pgcrypto` đã được bật.
* **Root Cause:** RPC sử dụng `SECURITY DEFINER SET search_path = ''`, trong khi `pgcrypto` được cài vào schema `extensions` chứ không phải `public`.
* **Actionable Rule:** Khi viết PostgreSQL RPC có `SET search_path = ''`, luôn định danh rõ schema của extension (`extensions.digest(...)`) hoặc tạo wrapper tương thích ngược trong `public`.
