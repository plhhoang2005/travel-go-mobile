# Chẩn đoán kỹ thuật Quản trị Dữ liệu và Pipeline Xuất bản
**Ngày lập:** 03/11/2026  
**Baseline HEAD:** `7bf77cb97641bfaf461d5a0c1e3141b539b65dd2` (Branch: `codex/admin-data-repair-map-sync`)  
**Tài liệu tham chiếu:** `docs/superpowers/plans/2026-11-03-admin-data-repair-and-map-sync.md`, `docs/superpowers/specs/2026-11-03-admin-catalogue-local-ai-assessment.md`

---

## 1. Baseline & Khảo sát tệp Dirty / Untracked

### 1.1. Bốn tệp đang Dirty
1. `lib/features/admin/presentation/screens/admin_shell_screen.dart`:
   - Bổ sung `_createAdminDio()` áp đặt `connectTimeout: 5s`, `receiveTimeout: 8s`, `sendTimeout: 5s`.
   - **Tác động:** Khi Edge Function cold-start hoặc mạng di động có độ trễ cao, timeout 5s–8s bị kích hoạt, Dio ném `DioExceptionType.connectionTimeout` / `receiveTimeout`, ánh xạ thành `upstream_unavailable` ("Chưa thể kết nối máy chủ. Vui lòng thử lại.").
2. `lib/features/admin/presentation/widgets/admin_place_form.dart`:
   - Bổ sung danh sách toạ độ mẫu `_defaultCoordinates` và địa điểm gợi ý `_presetPlaces`.
   - Gắn nút "Toạ độ mẫu".
   - **Tác động:** Cần bảo đảm toạ độ mẫu không bị tự động lưu âm thầm thành toạ độ thật đã xác minh khi người dùng chưa chọn.
3. `lib/features/admin/providers/admin_account_provider.dart`:
   - Phân biệt `f.code == 'account_locked'` thì gọi `_fail(f)` (đóng giao diện quản trị), các lỗi khác thì gán `_error = f` để hiển thị banner lỗi có nút thử lại.
   - **Tác động:** Giúp màn hình không bị crash văng ra ngoài khi lỗi mạng, nhưng cần bảo đảm dọn dẹp state và không giữ dữ liệu phiên cũ khi chuyển đổi tài khoản.
4. `lib/features/admin/providers/admin_catalogue_provider.dart`:
   - Bổ sung xử lý khi lỗi chứa `public.digest` hoặc `42883`: không coi outcome là uncertain, giữ `_savePhase = savedNotPublished` và sinh thông báo tiếng Việt rõ ràng.
   - **Tác động:** Ngăn chặn việc báo sai rằng lưu nháp thất bại khi thực chất bước lưu nháp đã thành công ở server.

### 1.2. Các tệp SQL Untracked
- `supabase/fix_admin_accounts.sql`: Cập nhật logic `complete_admin_account_operation`, bỏ điều kiện `worker_token` kiểm tra ngặt nghèo của worker cũ. Bản này chưa được kiểm chứng đầy đủ và không được chạy bừa bãi khi chưa xác định lớp lỗi của `users`.
- `supabase/fix_prepare_discovery_preview.sql`: Bản vá trực tiếp `prepare_discovery_preview` dùng `extensions.digest` thay vì `public.digest`.
- `supabase/migrations/20261103140000_fix_pgcrypto_digest.sql`: Tạo hàm alias `public.digest(text, text)` và `public.digest(bytea, text)` trỏ về `extensions.digest`. Đây là giải pháp an toàn nhất, tương thích ngược với mọi RPC đang có `SET search_path = ''`.

---

## 2. Khoanh vùng nguyên nhân lỗi `users` (Danh sách người dùng Admin)

### 2.1. Phân tích luồng gọi
- **Contract:** `travelgo.admin.v1`
- **Action:** `users`
- **Request payload:** `{"query": "", "limit": 25, "role": null, "state": null}`
- **Edge Function:** `supabase/functions/admin-control/gateway.mjs` chuyển tiếp qua POST `/rest/v1/rpc/admin_accounts` với header `Authorization: Bearer <token>`.

### 2.2. Lớp lỗi 1: Timeout và mạng (Dio Client)
- `_createAdminDio()` đặt `connectTimeout: 5s`. Khi Edge Function Supabase cold start hoặc mạng di động chậm, request quá 5s bị abort.
- `AdminAccountService` bắt `DioException` timeout $\rightarrow$ mã lỗi `upstream_unavailable` $\rightarrow$ UI hiển thị banner: *"Chưa thể kết nối máy chủ. Vui lòng thử lại."* (Trùng khớp với Ảnh 1–2).

### 2.3. Lớp lỗi 2: Kiểm tra dữ liệu ngặt nghèo trong DTO Decode (`UserSummary.fromJson`)
- `UserSummary.fromJson` kiểm tra:
  ```dart
  if (role is! String || (role != 'customer' && role != 'admin')) {
    throw const FormatException('UserSummary unknown role');
  }
  ```
  Trong khi đó, schema `public.profiles` cho phép `role IN ('customer', 'partner', 'admin')`. Nếu trong cơ sở dữ liệu có bất kỳ người dùng nào mang vai trò `'partner'`, `UserSummary.fromJson` sẽ ném `FormatException`.
- Tương tự, nếu `fullName` hoặc `email` trong database bị null (ví dụ tài khoản tạo qua phương thức đặc thù hoặc dữ liệu seed cũ), DTO cũng ném `FormatException`.
- Khi ném `FormatException`, `_execute` chuyển thành `AdminFailure(code: 'invalid_response')` $\rightarrow$ UI hiển thị: *"Chưa thể hoàn tất yêu cầu. Vui lòng tải lại hoặc thử lại."*

### 2.4. Lớp lỗi 3: Database RPC Join (`admin_accounts`)
- RPC `admin_accounts` dùng `INNER JOIN` giữa 3 bảng:
  `auth.users u JOIN public.profiles p ON p.id = u.id JOIN private_admin.account_access a ON a.subject_id = u.id`.
- Nếu có người dùng trong `auth.users` nhưng chưa có bản ghi tương ứng trong `private_admin.account_access` (do trigger chưa bắn hoặc tài khoản tạo trước migration), người dùng đó bị loại trừ khỏi danh sách mà không có log cảnh báo.

---

## 3. Khoanh vùng nguyên nhân lỗi `prepare_discovery_preview` (SQLSTATE 42883)

### 3.1. Bằng chứng lỗi
- Ảnh 3–6 của owner hiển thị thông báo:
  `prepare_discovery_preview failed: function public.digest(text, unknown) does not exist (SQLSTATE 42883)`

### 3.2. Căn cứ kỹ thuật
1. Trong migration `supabase/migrations/20261027063524_coursework_catalogue_publication_retry.sql`:
   - Dòng 53: `encode(public.digest(p_expected_draft_revision::text || ':' || (v_active+1)::text || ':' || p_request_id::text, 'sha256'), 'hex')` (Tham số: `text, text`).
   - Dòng 72: `encode(public.digest(convert_to(p_payload_text, 'UTF8'), 'sha256'), 'hex')` (Tham số: `bytea, text`).
   - Dòng 85: `encode(public.digest(p_request::text, 'sha256'), 'hex')` (Tham số: `text, text`).
2. Hàm `prepare_discovery_preview` được khai báo với `SECURITY DEFINER SET search_path = ''`.
3. Trên nền tảng Supabase thật, extension `pgcrypto` được cài đặt vào schema `extensions`, **không nằm trong schema `public`**.
4. Do có `SET search_path = ''` và gọi đích danh `public.digest(...)`, PostgreSQL tìm kiếm hàm `digest` trong schema `public`. Vì không tồn tại hàm này trong `public`, hệ thống trả về lỗi SQLSTATE `42883`.

### 3.3. Giải pháp chuẩn xác
- Triển khai migration tạo 2 hàm wrapper trong schema `public`:
  ```sql
  CREATE OR REPLACE FUNCTION public.digest(data text, type text)
  RETURNS bytea LANGUAGE sql IMMUTABLE AS $$
    SELECT extensions.digest(data, type);
  $$;

  CREATE OR REPLACE FUNCTION public.digest(data bytea, type text)
  RETURNS bytea LANGUAGE sql IMMUTABLE AS $$
    SELECT extensions.digest(data, type);
  $$;
  ```
- Cấp quyền `EXECUTE` cho `authenticated`, `service_role`, `postgres`.
- Điều này khắc phục dứt điểm lỗi `42883` mà không làm thay đổi logic nghiệp vụ, không thay đổi thuật toán băm SHA256 và giữ tính bất biến (IMMUTABLE).

---

## 4. Kế hoạch khắc phục theo thứ tự các Task

1. **Task 1 (Sửa Client & RPC User List):**
   - Tăng timeout trong `_createAdminDio()` lên mức an toàn (connect 15s, receive 20s) tránh timeout oan trên mạng di động.
   - Nới lỏng kiểm tra DTO `UserSummary.fromJson`: hỗ trợ fallback `role: 'partner'` hoặc gán vai trò an toàn, hỗ trợ `fullName` rỗng (`fullName ?? 'Chưa đặt tên'`).
   - Đảm bảo cơ chế dọn dẹp state khi đổi tài khoản (`_clearUsersOnRevocation`).
2. **Task 2 (Sửa lỗi digest publication):**
   - Đưa migration `20261103140000_fix_pgcrypto_digest.sql` vào bộ migration chính thức `supabase/migrations/20261103190100_repair_discovery_digest_schema.sql`.
   - Cập nhật test harness `tool/verify-flutter-admin.ps1` để nạp migration này trước khi chạy kiểm thử publication.
3. **Task 3 (CRUD Idempotency & Form Validation):**
   - Khắc phục `retrySave()` không mint request ID mới khi bản nháp đã được lưu.
   - Loại bỏ việc gán toạ độ mặc định ngầm định; toạ độ thiếu phải hiển thị rõ "Chưa có vị trí".
4. **Task 4 (Bản đồ đồng bộ snapshot xuất bản):**
   - Xóa bỏ việc lưu state ẩn cục bộ `_hiddenPlaceIds` trong `catalogue_discovery_map_screen.dart`.
   - Rebind marker và selection khi snapshot hash thay đổi.
5. **Task 5 (Kiểm chứng đầu cuối & Bàn giao):**
   - Chạy toàn bộ test suites (`verify-flutter-admin.ps1`, flutter tests, node contract tests) và xuất biên bản bàn giao.
