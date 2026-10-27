# BÁO CÁO NGHIỆM THU CANDIDATE — TASK C3: RECOVERY OWNERSHIP, CANCEL VÀ CLEANUP

**Thời điểm tạo:** 2026-10-25T08:08:00+07:00  
**Repository:** `D:/Travel-Go-Android/travel-go`  
**Nhánh local:** `fix/ai-planning-stability`  
**Candidate Base HEAD:** `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`  
**Superpowers đã sử dụng:** `using-superpowers`, `executing-plans`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`.  
**Phạm vi:** Hoàn thành triển khai **duy nhất Task C3** (F01, F02, F04). **Task C4 vẫn OPEN / DEFERRED** (F03/R2 double-submit, F05/R6 expiry, F06/R7 cold server-revalidation, OTP/profile và email thật).  

---

## 1. Changed (Danh sách file đã sửa / bổ sung & Hashes SHA256)

### 1.1. Mã nguồn sản phẩm sửa đổi

| File | SHA256 Hash | Vai trò & Nội dung thay đổi |
| :--- | :--- | :--- |
| `lib/features/auth/providers/password_recovery_provider.dart` | `957B2876ABD5EBD0D8E117F401ADA68C4782AF1FA9D7B58338E93FA0EC75D504` | Quản lý ownership vòng đời khôi phục: theo dõi generation (`_generation`), kiểm tra authority đồng bộ trước và sau mọi điểm `await` (bootstrap, requestEmail, exchange, marker write/clear), cơ chế hủy thực sự giải phóng slot và dọn marker theo `expectedIntentId`, lưu vết `cleanupRequired` khi dọn thất bại (R9) thay vì nuốt lỗi vào `idle`. |
| `lib/features/auth/providers/auth_provider.dart` | `7D34EF6184DD8AABF250247B3F131B438FAF7C8344023682E77290DD0FA7B1AF` | Đảm bảo an toàn tài khoản và phiên SDK: thu hồi authority ngay lập tức, `runRecoveryMutation` tự động dọn session SDK trễ (`signOut(scope: local)`) nếu mutation bị hủy khi đang bay (R3); hàm `_drainAndCleanupRecovery()` bắt buộc hoàn tất cleanup trước khi cấp phép đăng nhập (`login`, `signInWithOAuth`, `register`, `verifyOtp`); chặn đăng nhập mới nếu cleanup A thất bại (R5, R10); điều chỉnh `onLocalAccountInvalidated` không biến recovery đang chạy thành Guest mode. |
| `lib/features/auth/services/recovery_intent_store.dart` | `50F69DC05A38C3CC297EF69EE8EF907D1F7825605AFD9C2E61CBE60B5B36A725` | Bổ sung tham số tùy chọn `expectedIntentId` cho phương thức `clear([String? expectedIntentId])`, ngăn chặn tình trạng mutation/cleanup trễ của intent A xóa nhầm marker hợp lệ của intent B. |

### 1.2. Bộ kiểm thử hồi quy vĩnh viễn (Permanent Regression Tests)

| File | Nội dung bổ sung |
| :--- | :--- |
| `test/password_recovery_authority_test.dart` | Bổ sung `PausableRecoveryIntentStore` với cổng phase, bổ sung 5 ca kiểm thử hồi quy: **R1** (hủy khi ghi ready marker không được hồi sinh ready), **R3** (hủy khi SDK exchange đang bay phải dọn sạch session SDK A), **R4** (chọn Guest khi bootstrap đang đọc store không được kích hoạt lại recovery), **R8** (chọn Guest khi đang ghi requesting marker không được gửi email), và **F02 bổ sung** (hủy A đang exchange chồng lấn login B thì B thành công và không bị đăng xuất muộn). |
| `test/password_recovery_callback_race_test.dart` | Bổ sung ca kiểm thử hồi quy **F01/F02 bổ sung**: mutation/cleanup trễ từ intent A không bao giờ được ghi đè hoặc xóa marker của intent B, slot callback không bị release nhầm. |
| `test/password_recovery_cleanup_test.dart` | Bổ sung `MemoryPkce`, bổ sung 3 ca kiểm thử hồi quy: **R5** (marker cleanup thất bại phải chặn đăng nhập tài khoản B), **R9** (hủy thất bại cleanup phải giữ trạng thái `cleanupRequired` có thể thử lại), và **R10 + CONTROL** (kiểm chứng với fixture thật SQLite + `LocalAccountLifecycleService`: cleanup lỗi chặn cấp handle B, cleanup thành công cấp đúng B). |

---

## 2. Why (Căn cứ kỹ thuật & Luồng giải quyết)

### 2.1. Vấn đề cốt lõi trước khi sửa
1. **F01 / R1, R4, R8 (Async continuation revival & phantom dispatch)**: Sau các điểm `await` I/O (đọc store, ghi marker), code không kiểm tra lại authority generation hoặc trạng thái người dùng (ví dụ: đã bấm Hủy hoặc chọn Tiếp tục với vai trò Khách). Dẫn đến việc marker hoặc recovery flow cũ tiếp tục chạy ngầm, gửi email hoặc mở form đổi mật khẩu trái ý muốn người dùng.
2. **F02 / R3, Cross-account overlap (Cancellation authority & Session leakage)**: Khi người dùng bấm Hủy trong lúc mạng đang trao đổi mã PKCE (`service.exchange`), Supabase SDK vẫn nhận response và ghi session A vào SDK memory. Phương thức `cancel()` cũ chạy `signOut()` trước khi exchange kết thúc nên không dọn được session đến muộn này. Ngoài ra, nếu người dùng đăng nhập tài khoản B, việc dọn dẹp không kiểm soát có nguy cơ đăng xuất nhầm tài khoản B mới.
3. **F04 / R5, R9, R10 (Swallowed cleanup failures & Account grant leakage)**: Phương thức `cancel()` cũ dùng `catch (_) {}` nuốt toàn bộ lỗi khi `store.clear()` hoặc `signOut()` thất bại, tự động chuyển state về `idle` như thể đã thành công. Khi đăng nhập tài khoản mới, hệ thống không chờ dọn dẹp xong, dẫn đến việc cấp phiên tài khoản B trong khi marker của A vẫn còn trên đĩa, vi phạm cách ly dữ liệu.

### 2.2. Giải pháp kiến trúc thống nhất (Unified Ownership Model)
- **Token / Generation Fence**: Mọi luồng khôi phục đều gắn liền với generation và intentId. Trước và sau mỗi lệnh `await` (đọc marker, ghi marker, gọi SDK), hệ thống đối chiếu lại thế hệ hiện tại và kiểm tra `auth.isCurrentRecoveryIntent(intentId)`. Nếu có sự thay đổi, tiến trình dừng ngay lập tức và dọn dẹp tài nguyên dở dang.
- **Draining & In-flight Session Cleanup**: Trong `runRecoveryMutation`, nếu mutation bị hủy khi đang chờ mạng hoàn tất, ngay sau khi SDK exchange trả về session, block finally/post-await sẽ lập tức kích hoạt `signOut(scope: local)` để dọn session A vừa xuất hiện, bảo đảm SDK session trở về `null`.
- **Cleanup Barrier trước khi cấp tài khoản mới**: Phương thức `login` (cùng các phương thức cấp quyền tài khoản khác) bắt buộc phải `await _drainAndCleanupRecovery()`. Nếu việc xóa marker trên đĩa hoặc đăng xuất SDK thất bại, quá trình đăng nhập B lập tức bị chặn (`return false`), bảo vệ tuyệt đối tính cô lập dữ liệu.
- **Trạng thái Retry minh bạch**: Khi việc dọn dẹp thất bại, UI giữ nguyên trạng thái `cleanupRequired` với nút thử lại, không giả vờ thành công (`idle`).

---

## 3. Testing (Bằng chứng kiểm thử TDD: RED → GREEN)

### 3.1. Bảng đối chiếu ma trận Finding ↔ Probe ↔ Kết quả kiểm thử

| Finding / Scope | Ca kiểm thử / Probe | Cơ chế đồng bộ (Barrier / Fixture) | Trạng thái RED ban đầu | Trạng thái GREEN sau sửa |
| :--- | :--- | :--- | :--- | :--- |
| **F01** | **R1** | `store.gates[RecoveryPhase.ready]` | **FAIL** (`Expected: false, Actual: true`) | **PASS** (exit 0) |
| **F01** | **R4** | `store.readGate` | **FAIL** (`Expected: false, Actual: true`) | **PASS** (exit 0) |
| **F01** | **R8** | `store.gates[RecoveryPhase.requesting]` | **FAIL** (`Expected: 0, Actual: 1`) | **PASS** (exit 0) |
| **F02** | **R3** | `exchangeGate` (held in MockClient `/token`) | **FAIL** (`Expected: null, Actual: Session:A`) | **PASS** (exit 0) |
| **F02 bổ sung** | `cancel A -> login B` | `exchangeEntered` + `exchangeRelease` | Đã bổ sung regression | **PASS** (exit 0, user=B, B không bị logout) |
| **F01/F02 bổ sung**| `retryCleanup A -> B` | Phối hợp 2 intent liên tiếp trên Store | **FAIL** (`Expected: true, Actual: false`) | **PASS** (exit 0, marker B được bảo toàn) |
| **F04** | **R5** | `store.failRemove = true` trên MockClient | **FAIL** (`Expected: false, Actual: true`) | **PASS** (exit 0, login B bị chặn) |
| **F04** | **R9** | `store.failRemove = true` khi `cancel()` | **FAIL** (`Expected: true, Actual: false`) | **PASS** (exit 0, giữ `cleanupRequired`) |
| **F04** | **R10** | Fixture thật SQLite + `LocalAccountLifecycleService` (`failRemove=true`) | **FAIL** (`Expected: false, Actual: true`) | **PASS** (exit 0, lifecycle handle B bị chặn) |
| **Control** | **CONTROL R10** | Fixture thật SQLite + `LocalAccountLifecycleService` (`failRemove=false`) | **PASS** (Positive control hợp lệ) | **PASS** (exit 0, cấp đúng handle B) |

### 3.2. Kết quả chạy bộ kiểm thử mục tiêu (Targeted Verification)

1. `test/password_recovery_authority_test.dart`:
   - Lệnh: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_authority_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **10/10 PASS (exit 0)**.
2. `test/password_recovery_callback_race_test.dart`:
   - Lệnh: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_callback_race_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **6/6 PASS (exit 0)**.
3. `test/password_recovery_cleanup_test.dart`:
   - Lệnh: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_cleanup_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **12/12 PASS (exit 0)**.
4. `test/password_recovery_gate_test.dart`:
   - Lệnh: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_gate_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **6/6 PASS (exit 0)**.
5. `test/auth_navigation_test.dart`:
   - Lệnh: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/auth_navigation_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **64/64 PASS (exit 0)**.

### 3.3. Kết quả chạy toàn bộ Full Verification Suite

- **Lệnh thực thi:** `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`
- **Kết quả tổng hợp:**
  - `flutter analyze`: **No issues found! (exit 0)**
  - `flutter test` (Full Suite): **1.010 / 1.010 PASS (exit 0)**
  - `node-contracts` (Edge Functions & Contracts): **91 / 91 PASS (exit 0)**
- **Kiểm tra định dạng git diff:**
  - `git diff --check`: **Clean (exit 0)** (không có whitespace thừa, không conflict markers).

### 3.4. Phạm vi thiết bị / Runtime thực tế
- Thiết bị vật lý / Emulator: **NOT RUN** (theo chỉ thị tại handoff: không tự ý can thiệp thiết bị cá nhân của Owner khi chưa có yêu cầu; tất cả kiểm chứng thực hiện bằng automated suites và fixtures SQLite thật).

---

## 4. Problems (Rủi ro kỹ thuật & Giới hạn phạm vi)

1. **Phạm vi Task C4 tiếp tục DEFERRED / OPEN**:
   - `F03 / R2`: Double submit đổi mật khẩu trước khi write-ahead kết thúc.
   - `F05 / R6`: Expiry của intent trong RAM khi form mở quá thời hạn 60 phút.
   - `F06 / R7`: Revalidation cold server session khi form ready được mở lại.
   - Các chức năng gửi email thật, OTP verification chi tiết và UI polish của C4 vẫn được bảo lưu cho Phase C4. Không claim hoàn thành toàn bộ hệ thống khôi phục mật khẩu.
2. **Quy tắc Git Safety**: Toàn bộ thay đổi mã nguồn nằm trong working directory, chưa thực hiện lệnh `git commit`, `git push`, hoặc `merge`.

---

## 5. Lesson Candidate

* **Problem**: Hủy một tác vụ bất đồng bộ (`cancel()`) ở tầng UI chỉ dừng việc cập nhật state UI nhưng không thu hồi được side-effect của các request mạng SDK đang bay dở dang (ví dụ: Supabase SDK vẫn lưu session A vào RAM sau khi nhận response HTTP trễ).
* **Root Cause**: Bất đồng bộ mạng và SDK persistence hoạt động độc lập với vòng đời widget. Nếu hủy không đăng ký hủy quyền ở queue điều phối credential, response trễ sẽ âm thầm ghi đè session mới.
* **Actionable Rule**: Khi thiết kế các luồng xác thực / đổi mật khẩu / phiên làm việc, việc "Hủy" phải đồng thời thu hồi token quyền lực (generation fence) và đặt một chốt dọn dẹp hậu kỳ trong hàng đợi credential (`_enqueueCredential`) để đảm bảo session sinh ra muộn lập tức bị `signOut(scope: local)`.

---

## 6. Giải thích Coding và Cơ chế giải quyết cho Owner (Owner Learning)

### 6.1. Tình huống: Người dùng Hủy khôi phục A và Đăng nhập tài khoản B
Hãy hình dung kịch bản thực tế sau:
1. Bạn gửi yêu cầu khôi phục mật khẩu cho tài khoản `minh@example.com` (A) và nhấn vào đường link từ email.
2. Ứng dụng bắt đầu kết nối máy chủ Supabase để xác minh mã code (quá trình này mất khoảng 1-2 giây trên mạng di động).
3. Trong lúc đang chờ, bạn đổi ý, bấm nút **"Hủy"** trên màn hình và chuyển sang màn hình Đăng nhập để vào tài khoản công việc `work@example.com` (B).

### 6.2. Lỗ hổng trước đây (Trước khi sửa C3)
- Khi bạn bấm "Hủy", app lập tức ẩn màn hình khôi phục đi.
- Tuy nhiên, 1 giây sau đó, yêu cầu xác minh tài khoản A từ máy chủ trả về thành công. Bộ thư viện Supabase SDK âm thầm lưu phiên đăng nhập của A vào bộ nhớ!
- Hậu quả: Dù bạn đang ở màn hình đăng nhập tài khoản B, bên dưới hệ thống vẫn đang mang danh nghĩa của tài khoản A. Nếu bạn đăng nhập tiếp tài khoản B, hai phiên làm việc này sẽ giẫm chân lên nhau, gây ra lỗi lộ dữ liệu hoặc tài khoản B vừa đăng nhập xong thì bị lệnh dọn dẹp trễ của A đăng xuất ra ngoài.
- Tệ hơn nữa: Nếu việc xóa file ghi nhớ của A bị lỗi (ví dụ bộ nhớ máy đầy), app cũ sẽ lờ đi và cho phép tài khoản B đăng nhập đè lên, khiến dữ liệu của A và B bị trộn lẫn.

### 6.3. Cách giải quyết mới của C3
1. **Chốt kiểm soát thế hệ (Generation Fence)**:
   Mỗi khi có một yêu cầu mới, hệ thống tăng số thứ tự thế hệ (`generation`). Khi bạn bấm "Hủy", số thứ tự này lập tức thay đổi. Khi phản hồi của A đến muộn, hệ thống phát hiện thế hệ của A đã hết hạn, lập tức ra lệnh đăng xuất cục bộ tài khoản A ngay tại chỗ.
2. **Hàng đợi tuần tự (Credential Queue)**:
   Yêu cầu đăng nhập B sẽ xếp hàng ngay sau yêu cầu dọn dẹp A. Hệ thống bảo đảm A đã bị xóa sạch hoàn toàn khỏi bộ nhớ và ổ đĩa trước khi bắt đầu nạp phiên làm việc của B.
3. **Cửa chặn an toàn tuyệt đối (Cleanup Gate)**:
   Nếu việc xóa dữ liệu cũ của A gặp trục trặc (bộ nhớ lỗi), ứng dụng kiên quyết dừng lại và thông báo "Cần hoàn tất dọn dẹp phiên trước khi tiếp tục" kèm nút Thử lại, tuyệt đối không cấp quyền mở tài khoản B khi dữ liệu cũ chưa an toàn.

---

**Bàn giao candidate hoàn tất. Sẵn sàng cho Codex Review độc lập.**

