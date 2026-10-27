# Báo Cáo Triển Khai Sửa Lỗi C3 (Correction R2) — 25/10/2026

Báo cáo bàn giao kết quả xử lý các findings **C3-F01, C3-F02 và C3-F05** theo handoff [`COURSEWORK_C3_FIX_R2_ANTIGRAVITY_HANDOFF_20261025.md`](COURSEWORK_C3_FIX_R2_ANTIGRAVITY_HANDOFF_20261025.md) và review độc lập [`C3_CODEX_REVIEW_R2_20261025.md`](C3_CODEX_REVIEW_R2_20261025.md).

---

## 1. Changed — Danh Sách File Đã Sửa / Cập Nhật

| File | Vai trò | Thay đổi chính |
| :--- | :--- | :--- |
| `lib/features/auth/providers/auth_provider.dart` | Auth state ownership | Bổ sung `performRecoverySignOut({required String intentId, required String? verifiedUserId})`: kiểm tra 5 ranh giới quyền sở hữu phiên (`_currentUser != null`, `verifiedUserId == null`, session SDK null, session user ID không khớp) trước khi cho phép `signOut`. Cập nhật `cancelRecovery` để bảo vệ `_currentUser != null`. |
| `lib/features/auth/providers/password_recovery_provider.dart` | Recovery coordination & storage | 1. Xóa guard `auth.isAuthenticated` gây chặn khôi phục phiên `ready` tại `_performInitializeFromStore`.<br>2. Thay thế toàn bộ lệnh gọi `client.auth.signOut` trực tiếp trong `cancel()`, `retryCleanup()`, và `submitNewPassword` bằng `auth.performRecoverySignOut`.<br>3. Thêm commit guard vào write bù trong `_performExchange`: kiểm tra generation, `auth.isRecovering` và intent ID ngay sau `store.write` để xóa marker nếu bị hủy/superseded trong lúc ghi.<br>4. Thêm dọn dẹp phiên SDK trễ trong `_performExchange` nếu exchange hoàn tất sau khi intent đã bị hủy và chưa có user mới đăng nhập. |
| `test/password_recovery_authority_test.dart` | Permanent regression (Authority & Cancel) | 1. Cập nhật chữ ký override `clear([String? expectedIntentId])` và chuyển tiếp parameter tới `super.clear`.<br>2. Bổ sung `readCalls` tracking vào `PausableRecoveryIntentStore`.<br>3. Cập nhật MockClient để phân biệt đăng nhập lại cùng User A (`usr-recovery-A`) và User B (`usr-user-B`).<br>4. Bổ sung 5 permanent regressions: `X2_sent_phase_unverified_cancel_A_cleanup_cannot_sign_out_account_B`, `X2_same_user_new_login_is_not_signed_out_by_old_cancel_cleanup`, `X2_stale_retry_cleanup_cannot_sign_out_account_B_after_preflight_read`, `P1_production_store_unverified_sent_cancel_cannot_log_out_B`, `P1_production_store_same_user_new_login_preserved_after_cancel`. |
| `test/password_recovery_callback_race_test.dart` | Permanent regression (Race & Marker ordering) | 1. Bổ sung endpoint `/recover` vào MockClient setUp.<br>2. Thêm permanent regression `R2_repair_write_from_A_cannot_revive_B_after_B_was_cancelled`.<br>3. Điều chỉnh và hoàn thiện test `slot_callback_A_finally_does_not_reset_in_flight_slot_of_B`. |
| `test/password_recovery_cleanup_test.dart` | Permanent regression (Cleanup & Lifecycle) | 1. Cập nhật chữ ký override `clear([String? expectedIntentId])` chuyển tiếp tới `super.clear`.<br>2. Chuẩn hóa prefix import `local_fixtures` dòng 17 và sửa các vị trí gọi `local_fixtures.runWithStore`. |

### Git State & Hashes Baseline Thực Tế

- **Repo**: `D:/Travel-Go-Android/travel-go`
- **Branch**: `fix/ai-planning-stability`
- **HEAD Base**: `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`
- **Owner Dirty Files**: Giữ nguyên toàn bộ uncommitted source, scripts, images, and documents.

#### SHA-256 Hashes Candidate Cuối Cùng (Đã Verify):

| File | SHA-256 Checksum |
| :--- | :--- |
| `lib/features/auth/providers/auth_provider.dart` | `3a11c6451850d224d8d1e08f6b22765a5203a612e5158723e2615f34bf730c89` |
| `lib/features/auth/providers/password_recovery_provider.dart` | `32973b640a4c22530e2675d50afcf64eac845965d5f50646eb20e5f5e80a07f7` |
| `lib/features/auth/services/recovery_intent_store.dart` | `50f69dc05a38c3cc297ef69ee8ef907d1f7825605afd9c2e61cbe60b5b36a725` |
| `test/password_recovery_authority_test.dart` | `5b84a9138737d745133ef094943e04f919a0646eee33c75375c53edda12e99ea` |
| `test/password_recovery_callback_race_test.dart` | `e881a311e8b03d92f708e863a991d85e9742f0cc21c1d797a4861ce5c7464d5d` |
| `test/password_recovery_cleanup_test.dart` | `c40fe479cb6aea92635a5e9c395e92a18bdda871acefc244906513678db855b3` |
| `test/password_recovery_gate_test.dart` | `1430ab344b1a86b60f228c4970c189cabc0bcecee43c434d93d684205e5da3d5` |
| `test/auth_navigation_test.dart` | `a30136e22717b66d634c7d219ae2f3f95e5b0e057de2b2f248e3ddc78170dfb5` |

---

## 2. Why — Căn Cứ Kỹ Thuật & Giải Thích Cho Owner

### 1. Vì sao "cùng User ID" không đồng nghĩa với "thuộc cùng recovery operation"?
- Khi User A thực hiện khôi phục mật khẩu, Supabase SDK tạo ra một session tạm thời (chỉ dùng để đặt mật khẩu mới). Trong suốt quá trình này, `AuthProvider` không thiết lập `_currentUser` (UI không coi người dùng là đã đăng nhập bình thường).
- Nếu người dùng bấm Hủy (Cancel) hoặc dọn dẹp bị treo/trễ, và ngay sau đó thực hiện **Đăng nhập bình thường bằng mật khẩu cho chính User A**: lúc này `AuthProvider.login` hoàn tất và cấp một phiên đăng nhập hợp lệ mới (`_currentUser` mang ID của User A).
- Nếu thao tác dọn dẹp cũ (`cancel` hoặc `retryCleanup`) thức dậy sau await và chỉ so sánh đơn giản:
  $$\text{session.user.id} == \text{actualIntent.verifiedUserId}$$
  thì do cả hai đều mang ID User A, code cũ sẽ nhầm tưởng phiên đăng nhập mới này là session khôi phục cũ và gọi `signOut()`. Kết quả là người dùng vừa đăng nhập thành công thì bị văng ra ngoài ngay lập tức.
- **Giải pháp triệt để**: Quá trình khôi phục mật khẩu KHÔNG BAO GIỜ gán `_currentUser`. Do đó, bất kỳ khi nào `_currentUser != null`, phiên SDK đó chắc chắn thuộc về một phiên đăng nhập chính thức (dù là User B hay User A). Thao tác dọn dẹp khôi phục tuyệt đối không được phép gọi `signOut()` khi `_currentUser != null`.

### 2. Vì sao "write bù" (compensatory write) có thể làm hồi sinh marker đã hủy?
- Trong xử lý bất đồng bộ, khi Callback của Intent A ghi nhận trạng thái `readyIntent` bị trễ, nó ghi đè lên marker của Intent B đã được người dùng yêu cầu mới hơn.
- Bản vá trước đây cố gắng "bù đắp" bằng cách: sau khi Intent A ghi xong, nếu thấy intent hiện tại trong RAM là Intent B thì gọi `store.write(_currentIntent!)` để ghi đè lại B.
- Tuy nhiên, trong thời gian thao tác ghi bù đang chờ I/O storage, người dùng có thể đã bấm **Hủy Intent B** (`cancel()` xóa marker và gán RAM về `null`). Khi write bù hoàn tất ghi xuống đĩa, nó vô tình ghi đè lại marker Intent B vào storage — tạo ra một **ghost marker** (marker ma) tồn tại vĩnh viễn trên đĩa dù trong bộ nhớ và UI người dùng đã hủy khôi phục.
- **Giải pháp triệt để**: Gắn **Commit Guard** cho mọi thao tác ghi/sửa marker. Ngay sau khi `store.write` hoàn tất, code kiểm tra xem generation có bị tăng hay không (`_generation != repairGen`), intent có còn đang active hay không (`auth.isRecovering`), và intent hiện tại có còn trùng khớp hay không. Nếu phát hiện intent đã bị hủy hoặc superseded trong lúc ghi, code lập tức phát lệnh `store.clear(targetIntent.intentId)` để xóa sạch marker vừa ghi nhầm, ngăn chặn triệt để hiện tượng hồi sinh marker đã hủy.

---

## 3. Testing — Bằng Chứng Kiểm Thử Chi Tiết

### Bảng Ma Trận Kiểm Thử Lỗi R2 (RED $\rightarrow$ GREEN)

| Finding / Ca kiểm thử | Trạng thái trước sửa (Review R2 Baseline) | Trạng thái sau sửa (Candidate Cuối) | Lệnh & Bằng chứng thực tế |
| :--- | :--- | :--- | :--- |
| **C3-F05**: Chữ ký `clear([String?])` & prefix `local_fixtures` | **FAIL** (Analyzer 3 errors, 2 suites compile error) | **GREEN (PASS)** | `dart analyze`: No issues found! (exit 0) |
| **C3-F05**: Callback test dòng 332 (`provider.isReady == true`) | **FAIL** (Expected `true`, Actual `false`) | **GREEN (PASS)** | Gỡ bỏ check `auth.isAuthenticated` sai tại `_performInitializeFromStore`. Test PASS. |
| **C3-F01**: Cancel pending sent phase $\rightarrow$ Login B | **FAIL** (SDK user B bị signOut thành `null`) | **GREEN (PASS)** | `remaining_races_test.dart` & `P1_production_store_unverified_sent_cancel_cannot_log_out_B`: PASS |
| **C3-F01**: Cancel pending ready A $\rightarrow$ Login mới cùng User A | **FAIL** (SDK user A bị signOut thành `null`) | **GREEN (PASS)** | `remaining_races_test.dart` & `X2_same_user_new_login_is_not_signed_out_by_old_cancel_cleanup`: PASS |
| **C3-F01**: Stale retry cleanup $\rightarrow$ Login B | **FAIL** (Retry cleanup signOut User B) | **GREEN (PASS)** | `remaining_races_test.dart` & `X2_stale_retry_cleanup_cannot_sign_out_account_B_after_preflight_read`: PASS |
| **C3-F02**: Repair write A không hồi sinh B sau khi B đã hủy | **FAIL** (Marker B xuất hiện lại sau cancel) | **GREEN (PASS)** | `remaining_races_test.dart` & `R2_repair_write_from_A_cannot_revive_B_after_B_was_cancelled`: PASS |
| **C3-F03 & C3-F04**: Giữ nguyên trạng thái đạt | **GREEN** | **GREEN (PASS)** | X3, X4, X5, R5, R9, R10 đều đạt exit 0. |

### Kết Quả Chạy Toàn Bộ Bộ Probe Reviewer (26 / 26 PASS)

1. **19 Reviewer Probes Ban Đầu (C3 R1)**:
   ```powershell
   & 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-review/original_c3_probe_test.dart .dart_tool/c3-codex-review/overlap_probe_test.dart .dart_tool/c3-codex-review/production_store_probe_test.dart --name 'CONTROL|R1 |R3 |R4 |R5 |R8 |R9 |R10 |C3X|C3P'
   ```
   **Kết quả**: `19 / 19 PASS (exit 0, ran in 2s)`.
2. **7 Reviewer Probes Bổ Sung (C3 R2)**:
   ```powershell
   & 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --reporter=expanded .dart_tool/c3-codex-r2/remaining_races_test.dart .dart_tool/c3-codex-r2/production_cancel_variants_test.dart
   ```
   **Kết quả**: `7 / 7 PASS (exit 0, ran in 1s)`.

### Kết Quả Bộ Kiểm Thử Bền Vững Targeted (116 / 116 PASS)

```powershell
powershell -ExecutionPolicy Bypass -Command "& ./tool/verify-travelgo.ps1 -Mode Targeted -TestPath 'test/password_recovery_authority_test.dart','test/password_recovery_callback_race_test.dart','test/password_recovery_cleanup_test.dart','test/password_recovery_gate_test.dart','test/auth_navigation_test.dart' -FlutterRoot D:/flutter/flutter"
```
- `test/password_recovery_authority_test.dart`: 20 / 20 PASS
- `test/password_recovery_callback_race_test.dart`: 9 / 9 PASS
- `test/password_recovery_cleanup_test.dart`: 17 / 17 PASS
- `test/password_recovery_gate_test.dart`: 6 / 6 PASS
- `test/auth_navigation_test.dart`: 64 / 64 PASS
**Tổng Targeted**: `116 / 116 PASS (exit 0, ran in 23s)`.

### Kết Quả Kiểm Thử Toàn Diện Full Suite (`verify-travelgo.ps1 -Mode Full`)

```powershell
powershell -ExecutionPolicy Bypass -Command "& ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter"
```
1. **`flutter analyze`**: `No issues found! (ran in 15.8s, exit 0)`.
2. **`flutter test` (Full Suite)**: `1.029 / 1.029 PASS (exit 0)`.
3. **`node-contracts`**: `91 / 91 PASS (exit 0, ran in 261ms)`.
4. **`git diff --check`**: `Clean (exit 0)`.

---

## 4. Problems & Rủi Ro Tiềm Ẩn / Trạng Thái Giới Hạn

1. **Phần Chưa Chạy (NOT RUN)**:
   - Các bài test thực hiện trong môi trường synthetic unit/widget test với `SharedPreferences.setMockInitialValues` và `MockClient`.
   - Chưa kiểm thử runtime trên thiết bị Android/iOS thật hoặc gửi email thật qua dịch vụ SMTP Supabase (nằm ngoài scope C3).
2. **Task C4 Vẫn Được Bảo Lưu (DEFERRED)**:
   - Toàn bộ các hạng mục C4 (`F03/R2 double-submit trước write-ahead`, `F05/R6 TTL expiration trong RAM`, `F06/R7 cold server revalidation`, OTP/live email) vẫn ở trạng thái **chưa thực hiện**.
3. **Budget Guard**:
   - Sử dụng vòng sửa lỗi correction R2 có kiểm soát theo chỉ đạo của Owner.
   - Tuyệt đối không tự ý commit, push, merge hoặc deploy.

---

## 5. Lesson Candidate (Đề Xuất Bài Học Kinh Nghiệm)

- **Problem**: Khôi phục mật khẩu cho User A bị hủy, sau đó User A đăng nhập lại bình thường nhưng lập tức bị logout ngoài ý muốn do cleanup của intent cũ chạy ngầm.
- **Root Cause**: Code kiểm tra quyền sở hữu phiên bằng cách so sánh `session.user.id == intent.verifiedUserId`, đồng nhất danh tính người dùng (Subject Identity) với quyền sở hữu thao tác (Operation/Session Ownership).
- **Actionable Rule**: Không bao giờ dùng `userId` đơn thuần để quyết định quyền xóa phiên đăng nhập. Phải phân biệt rõ ràng giữa "phiên khôi phục tạm thời" và "phiên người dùng đã xác thực chính thức (`_currentUser`)". Khi `_currentUser != null`, mọi tiến trình dọn dẹp khôi phục ngầm đều phải từ chối gọi `signOut()`.

---

> [!IMPORTANT]
> **Điểm dừng**: Antigravity dừng lượt làm việc tại đây để bàn giao toàn bộ candidate source, checksum và báo cáo cho **Codex tiến hành Independent Re-Review R3**. Không tự ý chuyển sang Task C4.

