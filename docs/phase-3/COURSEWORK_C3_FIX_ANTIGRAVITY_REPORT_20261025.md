# BÁO CÁO NGHIỆM THU CANDIDATE — TASK C3 CORRECTION: SỬA FINDINGS C3-F01 ĐẾN C3-F04

**Thời điểm hoàn thành:** 2026-10-25T11:40:00+07:00  
**Repository:** `D:/Travel-Go-Android/travel-go`  
**Nhánh local:** `fix/ai-planning-stability`  
**Candidate Base HEAD:** `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`  
**Superpowers đã sử dụng:** `using-superpowers`, `executing-plans`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`.  
**Phạm vi:** Hoàn thành toàn diện việc khắc phục 4 nhóm lỗi C3 theo review độc lập của Codex: **C3-F01, C3-F02, C3-F03, C3-F04**. Các ca đã GREEN của C3 gốc (R1, R3, R4, R5, R8, R9, R10) được bảo toàn nguyên vẹn. **Task C4 vẫn OPEN / DEFERRED** (F03/R2 double-submit trước write-ahead hoàn tất, F05/R6 TTL expiration trong RAM, F06/R7 cold server revalidation, OTP/profile chi tiết và gửi email thật). Dừng trước C4 để Codex review độc lập.

---

## 1. Changed (Danh sách file đã sửa / bổ sung & Hashes SHA256)

So sánh trực tiếp với snapshot candidate được review (chỉ sửa 3 file mã nguồn nghiệp vụ auth/recovery và 3 file permanent tests):

### 1.1. Mã nguồn sản phẩm sửa đổi

| File | SHA256 Hash | Vai trò & Nội dung thay đổi |
| :--- | :--- | :--- |
| `lib/features/auth/providers/auth_provider.dart` | `E677135B411B0BB9FAE67D05430134E3081C6531EDC2F0560B56EAD12C538F2F` | **Thu hồi authority đồng bộ & Gate dọn dẹp xuyên suốt**: <br>1. Thêm `revokeRecoveryAuthority([String? intentId])`: tăng `_requestGeneration++` và xóa `_currentRecoveryIntentId = null` đồng bộ trước mọi điểm await, lập tức chặn đứng mọi mutation (X6, P2).<br>2. Thêm cờ `_recoveryCleanupPending` kết hợp với `_isRecovering`: bảo đảm trách nhiệm dọn dẹp không bị mất khi người dùng chọn Guest (`continueAsGuest`), và bắt buộc mọi luồng cấp tài khoản mới (`login`, `signInWithOAuth`, `register`, `verifyOtp`) phải await và hoàn tất cleanup trước khi cấp quyền (X5).<br>3. Trong `_drainAndCleanupRecovery`: thông báo kết quả tổng hợp (`totalSuccess`) cho `_recoveryCleanupResultListeners` để provider phản ánh trạng thái retry minh bạch khi SDK signOut thất bại (X4); kiểm tra không gọi `signOut(scope: local)` nếu tài khoản mới (User B) đã được xác thực.<br>4. Điều chỉnh `onLocalAccountInvalidated`: chỉ bật `_isGuest` khi người dùng thực sự chọn Guest (`_userChoseGuest`) hoặc khi đăng xuất (`_loggingOut`), không vô tình biến recovery flow thành Guest mode khi có session SDK.<br>5. Cập nhật `finishRecovery`: hỗ trợ hoàn tất phiên khi `_currentRecoveryIntentId == null` nhưng `_isRecovering` đang chờ đóng sau cleanup. |
| `lib/features/auth/providers/password_recovery_provider.dart` | `3F9AE9657DDD4DF4E850D86A693E8CE4E32FB968BBAB0B9BF7089DD81A13D920` | **Ownership vòng đời, Slot an toàn & Khôi phục marker bị ghi đè**: <br>1. Trong `cancel()`: gọi `auth.revokeRecoveryAuthority(intentId)` đồng bộ trước await, chuyển `_state = RecoveryState.idle` ngay tại chỗ; chỉ gọi `signOut(scope: local)` nếu session SDK hiện tại thuộc về `intent.verifiedUserId` (hoặc null), loại bỏ hoàn toàn việc đăng xuất nhầm User B (X2, P1).<br>2. Trong `submitNewPassword`: kiểm tra `if (!isReady) return false;` và `auth.isCurrentRecoveryIntent`, chặn 100% việc gửi PUT sau Hủy (X6, P2).<br>3. Trong `handleCallback`: lưu `exchangeFuture` cục bộ và chỉ giải phóng slot `_inFlightExchange` trong `finally` nếu nó vẫn là future của chính mình, bảo vệ slot của Intent B (C3-F02 slot race).<br>4. Trong `_performExchange`: sau khi ghi marker `ready`, nếu phát hiện bị đổi thế hệ hoặc superseded bởi Intent B (`_currentIntent!.intentId != intent.intentId`), lập tức ghi phục hồi lại marker của Intent B vào storage (`store.write(_currentIntent!)`) thay vì clear (X1).<br>5. Trong `requestEmail`: trong các khối catch, chỉ bỏ qua nếu operation đã đổi generation hoặc đã chọn Guest; không kiểm tra `!isCurrentRecoveryIntent` trước khi `beginRecovery` diễn ra, bảo đảm lỗi ghi marker đầu tiên hiển thị thông báo lỗi và cho phép thử lại (X3).<br>6. Đăng ký listener `_handleRecoveryCleanupResult`: khi SDK signout thất bại, giữ nguyên `_currentIntent` và chuyển sang `RecoveryState.cleanupRequired` để UI hiển thị nút Thử lại (X4). |
| `lib/features/auth/services/recovery_intent_store.dart` | `50F69DC05A38C3CC297EF69EE8EF907D1F7825605AFD9C2E61CBE60B5B36A725` | Duy trì conditional clear `clear([String? expectedIntentId])` đã đạt từ C3 gốc. |

### 1.2. Bộ kiểm thử hồi quy vĩnh viễn (Permanent Regression Tests)

| File | SHA256 Hash | Nội dung bổ sung |
| :--- | :--- | :--- |
| `test/password_recovery_authority_test.dart` | `FCD61BABD9C01687EC613C94EA9AA1745E3D95430AD951C333F345D7109FC59C` | Bổ sung `CompletionGatedStore` (SharedPreferences thật với delay completion sau clear) và 5 ca kiểm thử hồi quy vĩnh viễn: <br>• **X6** (hủy A giữ clear pending rồi submit mật khẩu $\rightarrow$ 0 PUT).<br>• **P2** (xác nhận tương tự X6 trên `CompletionGatedStore` SharedPreferences thật $\rightarrow$ 0 PUT).<br>• **X2** (hủy A giữ clear pending $\rightarrow$ login B $\rightarrow$ nhả clear A $\rightarrow$ SDK user vẫn đúng B, không bị signOut muộn).<br>• **P1** (xác nhận tương tự X2 trên `CompletionGatedStore` SharedPreferences thật $\rightarrow$ SDK user vẫn đúng B).<br>• **X3** (lỗi ghi marker đầu tiên kết thúc sending, hiển thị lỗi, sau khi storage phục hồi thì gửi đúng 1 email). |
| `test/password_recovery_callback_race_test.dart` | `E22A687CC1D3DD7655651DB0EB96355BFC2D9C815A992454D60FE2E071864A6D` | Bổ sung cơ chế `gates`/`entered` vào `BlockingStore` và 2 ca kiểm thử hồi quy vĩnh viễn: <br>• **X1** (giữ ready-write A $\rightarrow$ cancel A $\rightarrow$ requestEmail B $\rightarrow$ nhả gate A $\rightarrow$ store và RAM bảo toàn marker B, không bị A xóa thành null).<br>• **slot race** (callback A hoàn tất khi B có operation mới, `finally` của A không reset slot của B). |
| `test/password_recovery_cleanup_test.dart` | `C40FE479CB6AEA92635A5E9C395E92A18BDDA871ACEFC244906513678DB855B3` | Bổ sung 5 ca kiểm thử hồi quy vĩnh viễn: <br>• **X4** (marker clear thành công nhưng SDK signOut HTTP 500 $\rightarrow$ provider giữ trạng thái `cleanupRequired` và `currentIntent` hợp lệ để thử lại).<br>• **X5** (marker clear lỗi $\rightarrow$ chọn Guest $\rightarrow$ login B $\rightarrow$ bị chặn cấp quyền, 0 uncaught async error, marker A còn nguyên).<br>• **CONTROL Guest** (cleanup thành công $\rightarrow$ chọn Guest $\rightarrow$ login B thành công).<br>• **X5 + R10 SQLite + Lifecycle** (kiểm chứng tương tự X5 trên fixture SQLite thật + `LocalAccountLifecycleService`: failRemove=true chặn cấp handle B, failRemove=false cấp đúng handle B). |

---

## 2. Why (Căn cứ kỹ thuật & Luồng giải quyết)

### 2.1. C3-F01: Thu hồi quyền SDK đồng bộ và ngăn late signOut làm mất session B
* **Nguyên nhân gốc**: Trước đây, `cancel()` chỉ tăng `_generation` nội bộ của `PasswordRecoveryProvider` và sau đó `await store.clear(intentId)`. Trong lúc I/O xóa đĩa đang chạy, `AuthProvider` vẫn coi `intentId` là hợp lệ, nên nếu có thao tác `submitNewPassword`, yêu cầu PUT vẫn được gửi ra mạng. Thêm vào đó, sau khi clear xong, `cancel()` gọi `client.auth.signOut()` mà không kiểm tra xem session hiện tại trên SDK có còn thuộc về người dùng khôi phục hay đã được tài khoản B đăng nhập.
* **Giải pháp**:
  - `auth.revokeRecoveryAuthority(intentId)` được gọi **đồng bộ ngay dòng đầu tiên** của `cancel()`, tăng `_requestGeneration++` và xóa `_currentRecoveryIntentId = null`. `submitNewPassword` kiểm tra `if (!isReady) return false;` đồng bộ $\rightarrow$ 0 PUT (X6, P2).
  - Trước khi `signOut(scope: local)`, hệ thống đối chiếu: chỉ đăng xuất nếu session SDK hiện tại thuộc về `intent.verifiedUserId` (hoặc null). Nếu tài khoản B đã đăng nhập thành công (`session.user.id == ownerB != ownerA`), lệnh dọn dẹp A bỏ qua việc signOut SDK, bảo toàn 100% session của B (X2, P1).

### 2.2. C3-F02: Bảo vệ marker B trước stale write A và cô lập slot callback
* **Nguyên nhân gốc**: Khi Intent A đang chờ hoàn tất ghi marker `ready`, người dùng hủy A và tạo Intent B. Sau khi Intent B ghi marker vào storage thành công, gate của A mở ra, A ghi đè marker của nó lên B; sau đó A nhận thấy generation đã đổi nên gọi `store.clear(intentA)`, xóa luôn dữ liệu dẫn đến marker trong storage bị null. Ngoài ra, khối `finally` của `handleCallback` trước đây đặt `_inFlightExchange = null` vô điều kiện.
* **Giải pháp**:
  - Trong `_performExchange`, sau khi write xong, nếu phát hiện Intent B đã thay thế (`_currentIntent!.intentId != intent.intentId`), tiến trình phát hiện tình trạng bị superseded và tự động ghi phục hồi lại `_currentIntent!` vào storage, đồng thời không gọi lệnh xóa marker (X1).
  - Khối `finally` kiểm tra định danh `if (identical(_inFlightExchange, exchangeFuture))`, chỉ dọn slot nếu nó vẫn thuộc về chính mình.

### 2.3. C3-F03: Giữ rào chắn dọn dẹp qua chế độ Guest và bảo toàn trạng thái retry khi signOut lỗi
* **Nguyên nhân gốc**: Khi người dùng chọn "Tiếp tục với vai trò Khách" (`continueAsGuest`), mã nguồn cũ xóa cờ `_isRecovering = false` trước khi tiến hành dọn dẹp ngầm và gọi unawaited invalidator. Khi invalidator ném lỗi, lỗi trở thành uncaught async exception trong Zone. Tệ hơn, cờ `_isRecovering` đã bị xóa khiến lệnh `login B` sau đó bỏ qua kiểm tra dọn dẹp. Mặt khác, khi marker clear thành công nhưng SDK signOut gặp lỗi HTTP 500, provider đã vội xóa `_currentIntent = null` và chuyển về `idle`, làm mất khả năng thử lại.
* **Giải pháp**:
  - Tách biệt trạng thái hiển thị Guest (`_isGuest = true`) và trách nhiệm dọn dẹp (`_recoveryCleanupPending = true`). Lệnh cấp tài khoản (`login`, `register`,...) bắt buộc kiểm tra `_recoveryCleanupPending`. Nếu dọn dẹp lỗi, đăng nhập mới bị từ chối triệt để (X5).
  - Thu hồi toàn bộ lỗi invalidator về luồng có kiểm soát trong `_drainAndCleanupRecovery`, triệt tiêu 100% uncaught async error.
  - Thông báo kết quả dọn dẹp SDK về `PasswordRecoveryProvider` qua listener: nếu SDK signOut thất bại, provider giữ nguyên `_currentIntent` và chuyển sang `RecoveryState.cleanupRequired` để người dùng có thể bấm Thử lại (X4).

### 2.4. C3-F04: Xử lý lỗi ghi marker đầu tiên, giải phóng trạng thái sending
* **Nguyên nhân gốc**: Trong `requestEmail`, khối `catch` kiểm tra `if (!auth.isCurrentRecoveryIntent(intent.intentId)) return;`. Tuy nhiên, khi ghi marker đầu tiên bị lỗi (ví dụ bộ nhớ storage lỗi), lệnh `auth.beginRecovery` chưa từng được gọi, dẫn đến điều kiện trên luôn đúng và hàm âm thầm `return` mà không chuyển sang trạng thái lỗi, khiến form bị treo vĩnh viễn ở `sending`.
* **Giải pháp**: Trong khối catch của `requestEmail`, chỉ kiểm tra thế hệ `_generation != capturedGen || auth.isGuest`. Khi ghi marker lỗi, hệ thống cập nhật `_state = RecoveryState.error`, tắt cờ processing và lưu thông báo lỗi. Khi storage hoạt động trở lại, người dùng có thể gửi lại email thành công (X3).

---

## 3. Testing (Bằng chứng kiểm thử chi tiết)

### 3.1. Bảng đối chiếu ma trận Finding ↔ Probe / Regression ↔ Kết quả kiểm thử

| Finding / Scope | Ca kiểm thử / Probe | Cơ chế đồng bộ (Barrier / Fixture) | Trạng thái RED trước sửa | Trạng thái GREEN sau sửa |
| :--- | :--- | :--- | :--- | :--- |
| **C3-F01** | **X6** | `store.firstClearGate` (gated clear) | **FAIL** (PUT calls: actual 1, exp 0) | **PASS** (PUT = 0, submit = false) |
| **C3-F01** | **P2** | `CompletionGatedStore` (SharedPreferences thật) | **FAIL** (setup / authority leakage) | **PASS** (PUT = 0, submit = false) |
| **C3-F01** | **X2** | `store.firstClearGate` + late cancel A | **FAIL** (SDK user B bị null) | **PASS** (SDK user B giữ nguyên ownerB) |
| **C3-F01** | **P1** | `CompletionGatedStore` + late cancel A | **FAIL** (SDK user B bị null) | **PASS** (SDK user B giữ nguyên ownerB) |
| **C3-F02** | **X1** | `store.gates[ready]` + resume after B | **FAIL** (store value null, mất B) | **PASS** (store value = intentB) |
| **C3-F02** | **slot race** | Overlapping callback A & B | Đã bổ sung regression | **PASS** (B slot và authority được bảo toàn) |
| **C3-F03** | **X4** | Fake logout HTTP 500 (`failLogout=true`) | **FAIL** (state=idle, intent=null) | **PASS** (cleanupRequired=true, intent!=null) |
| **C3-F03** | **X5** | `failClear=true` + `continueAsGuest` | **FAIL** (login=true, uncaught error: 1) | **PASS** (login=false, uncaught errors: 0) |
| **C3-F03** | **CONTROL Guest** | `failClear=false` + `continueAsGuest` | Control ca thành công | **PASS** (login=true, isAuthenticated=true) |
| **C3-F03** | **X5 SQLite** | SQLite thật + `LocalAccountLifecycleService` | `failRemove=true` | **PASS** (login=false, handle=null) |
| **C3-F03** | **CONTROL SQLite**| SQLite thật + `LocalAccountLifecycleService` | `failRemove=false` | **PASS** (login=true, handle=ownerB) |
| **C3-F04** | **X3** | `failWrite=true` khi ghi marker đầu | **FAIL** (isProcessing=true, error=null) | **PASS** (isProcessing=false, retry = 1 email) |
| **C3 Baseline**| **R1, R3, R4, R5, R8, R9, R10** | Fixture C3 gốc | **PASS** | **PASS** (Toàn bộ 10/10 probes gốc đạt) |

### 3.2. Kết quả chạy bộ kiểm thử mục tiêu (Targeted Suites)

1. `test/password_recovery_authority_test.dart`:
   - Lệnh: `powershell.exe -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_authority_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **15 / 15 PASS (exit 0)**
2. `test/password_recovery_callback_race_test.dart`:
   - Lệnh: `powershell.exe -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_callback_race_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **8 / 8 PASS (exit 0)**
3. `test/password_recovery_cleanup_test.dart`:
   - Lệnh: `powershell.exe -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_cleanup_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **17 / 17 PASS (exit 0)**
4. `test/password_recovery_gate_test.dart`:
   - Lệnh: `powershell.exe -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_gate_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **6 / 6 PASS (exit 0)**
5. `test/auth_navigation_test.dart`:
   - Lệnh: `powershell.exe -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/auth_navigation_test.dart -FlutterRoot D:/flutter/flutter`
   - Kết quả: **64 / 64 PASS (exit 0)**

### 3.3. Kết quả Full Verification Suite (`verify-travelgo.ps1 -Mode Full`)

- **Lệnh thực thi:** `powershell.exe -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`
- **Chi tiết từng công đoạn:**
  - `flutter analyze`: **No issues found! (17.8s, exit 0)**
  - `flutter test` (Full Suite): **1.023 / 1.023 PASS (exit 0)** (tăng từ 1.011 lên 1.023 do bổ sung các permanent regression tests)
  - `node-contracts` (Edge Functions & Contracts): **91 / 91 PASS (exit 0)**
- **Kiểm tra định dạng git diff:**
  - `git diff --check`: **Clean (exit 0)** (không có trailing whitespace, không conflict markers).

### 3.4. Giới hạn kiểm chứng Runtime / Thiết bị
- Thiết bị vật lý / Emulator: **NOT RUN** (theo chỉ thị tại handoff: không tự ý can thiệp thiết bị cá nhân của Owner khi chưa có yêu cầu; tất cả kiểm chứng thực hiện bằng automated suites và fixtures SQLite thật).

---

## 4. Problems (Rủi ro kỹ thuật & Giới hạn phạm vi)

1. **Phạm vi Task C4 tiếp tục DEFERRED / OPEN**:
   - `F03 / R2`: Double submit đổi mật khẩu trước khi write-ahead hoàn tất (đòi hỏi UI double-tap lock hoặc write-ahead lock ở form UI).
   - `F05 / R6`: Expiry của intent trong RAM khi form mở quá thời hạn 60 phút.
   - `F06 / R7`: Revalidation cold server session khi form ready được mở lại.
   - Các chức năng gửi email thật, OTP verification chi tiết và UI polish của C4 vẫn được bảo lưu cho Phase C4.
2. **Quy tắc Git Safety**: Toàn bộ thay đổi mã nguồn nằm trong working directory, chưa thực hiện lệnh `git commit`, `git push`, hoặc `merge`.

---

## 5. Lesson Candidate

* **Problem**: Khi một tác vụ hủy (`cancel()`) diễn ra đồng thời với một luồng đăng nhập tài khoản mới (`login B`), lệnh dọn dẹp trễ của tác vụ hủy có thể gọi `signOut()` lên session của tài khoản mới vừa đăng nhập.
* **Root Cause**: Hàm dọn dẹp xem việc `signOut()` là thao tác không trạng thái (stateless) mà không đối chiếu quyền sở hữu (`owner`) của phiên hiện tại trên SDK trước khi phát lệnh đăng xuất.
* **Actionable Rule**: Mọi lệnh `signOut(scope: local)` trong các luồng dọn dẹp hoặc hủy bỏ bắt buộc phải kiểm tra xem phiên SDK hiện tại có thực sự thuộc về người dùng của phiên bị hủy hay không (`session.user.id == intent.verifiedUserId`). Tuyệt đối không gọi `signOut()` mù quáng khi phiên làm việc đã thuộc về một tài khoản mới.

---

## 6. Giải thích Coding và Review cho Owner (Owner Learning)

### 6.1. Luồng Hủy A → Đăng nhập B và hiện tượng "Đăng xuất oan"
Hãy tưởng tượng bạn đang thao tác trên điện thoại:
1. Bạn mở đường link khôi phục tài khoản A (`minh@example.com`). Ứng dụng bắt đầu kết nối máy chủ để xác thực.
2. Trong lúc đang chờ, bạn bấm **Hủy** và lập tức nhập thông tin để đăng nhập tài khoản công việc B (`work@example.com`).
3. Tài khoản B đăng nhập thành công, bạn thấy giao diện của tài khoản B hiện ra.
4. **Vấn đề trước đây:** Lệnh "Hủy" của tài khoản A lúc này mới chạy xong bước xóa dữ liệu tạm trên đĩa. Nó tiện tay gọi thêm một lệnh `signOut()` lên ứng dụng. Vì ứng dụng lúc này đang mở tài khoản B, lệnh này vô tình **đăng xuất luôn tài khoản B** của bạn!
5. **Cách sửa mới:** Lệnh Hủy của tài khoản A bây giờ được gắn "thẻ căn cước". Trước khi đăng xuất, nó nhìn vào phiên hiện tại: "Phiên này là của B, không phải của A, mình không được phép động vào!". Nhờ đó tài khoản B vẫn được giữ nguyên an toàn.

### 6.2. Vì sao chỉ đổi `generation` cục bộ là chưa đủ để thu hồi quyền?
- Trước đây, khi bấm Hủy, ứng dụng chỉ tăng một con số đếm nội bộ (`generation`) ở màn hình khôi phục mật khẩu.
- Nhưng quyền thực sự gửi yêu cầu đổi mật khẩu lên máy chủ Supabase lại do trung tâm quản lý tài khoản (`AuthProvider`) nắm giữ.
- Nếu trung tâm này chưa được thông báo là "Yêu cầu A đã bị hủy", thì trong lúc màn hình đang chờ xóa dữ liệu trên đĩa, nếu người dùng vô tình bấm Đổi mật khẩu, trung tâm vẫn nghĩ yêu cầu A còn hợp lệ và vẫn gửi lệnh đổi mật khẩu lên máy chủ.
- **Cách sửa mới:** Ngay khi bấm Hủy, ứng dụng lập tức tước quyền của yêu cầu A tại trung tâm `AuthProvider` ngay tức thì (đồng bộ), trước khi làm bất kỳ việc gì khác. Bất kỳ lệnh đổi mật khẩu nào gửi sau đó đều bị chặn đứng ngay lập tức (0 PUT).

### 6.3. Vì sao xóa marker thành công chưa đồng nghĩa với toàn bộ dọn dẹp thành công?
- Quá trình dọn dẹp tài khoản cũ gồm 2 bước:
  1. Xóa file ghi nhớ (`marker`) trên ổ đĩa điện thoại.
  2. Đăng xuất phiên làm việc (`signOut`) khỏi bộ thư viện kết nối máy chủ Supabase SDK.
- Trước đây, nếu bước 1 (xóa file) thành công, ứng dụng vội vàng tuyên bố "Đã xong" và xóa luôn thông tin phiên cũ. Nhưng lỡ như bước 2 (đăng xuất SDK) bị mất mạng hoặc máy chủ báo lỗi 500, thì phiên làm việc cũ vẫn còn kẹt trong bộ nhớ, mà ứng dụng thì đã quên mất phiên cũ là gì nên không thể hiển thị nút "Thử lại".
- **Cách sửa mới:** Hệ thống chỉ coi là hoàn tất khi **cả 2 bước** đều thành công. Nếu bước 2 lỗi, ứng dụng giữ lại thông tin phiên và hiển thị màn hình thông báo rõ ràng "Chưa thể hoàn tất dọn dẹp phiên, vui lòng Thử lại", đảm bảo tính minh bạch tuyệt đối và không để dữ liệu bị treo lơ lửng.

---

**Bàn giao candidate correction Task C3 hoàn tất. Sẵn sàng cho Codex Independent Re-Review. Dừng trước Task C4.**

