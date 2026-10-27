# C4 — Codex implementation, 25/10/2026

> **Cập nhật sau owner duyệt sửa: C4-F01 CLOSED, review R2 đạt ở mức source/automated và self-review.** [Review R1](C4_CODEX_REVIEW_20261025.md) từng tìm lỗi GET + restore-ready write failure; [bản sửa và review R2](C4_CODEX_REVIEW_R2_20261025.md) đạt Full1088/91, probes gốc5/5 và8 permanent regressions mới. Phần dưới là evidence implementation trước correction, không thay kết quả R2; chưa nghiệm thu live/thiết bị hoặc review độc lập.

Owner duyệt [plan C4](COURSEWORK_C4_IMPLEMENTATION_PLAN_20261025.md) và cho phép **Codex code thay Antigravity riêng lần này**. Codex trực tiếp implement và self-review; không dùng Superpowers, không giao subagent, không thay permanent workflow. Phạm vi vẫn theo [Core R2](../superpowers/plans/2026-10-24-coursework-core-r2.md) và [product scope](../../.agent/product-scope.md).

**Kết quả: C4 SOURCE/AUTOMATED PASS, self-review.** Targeted cuối220/220 PASS; Full analyzer sạch, Flutter1080/1080 và Node91/91, exit0 trên cùng candidate378 files,0 source drift. Runtime/email/thiết bị và review độc lập chưa nghiệm thu.

## 1. Changed

Checkout `D:/Travel-Go-Android/travel-go`; branch `fix/ai-planning-stability`, base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty work C1/C2/C3. Trước sửa, snapshot C3 có377 files,0 khác biệt. Task-start backups122 auth/profile/test files và Git status lưu trong `.dart_tool/c4-codex-implementation/before/`, `start-snapshot.json`, `status-before.txt`.

Codex sửa **13 files hiện có, thêm1 test file**, so với bản bắt đầu task. Không coi toàn bộ dirty diff C1–C3 là thay đổi C4.

| File | Vai trò thay đổi C4 |
| --- | --- |
| `lib/features/auth/providers/password_recovery_provider.dart` | Giữ submit slot trước await đầu tiên; kiểm TTL/session/owner; cold và warm server preflight trong credential queue; phân biệt lỗi trước PUT với PUT uncertain; retry verification; cleanup intent hết hạn |
| `lib/features/auth/services/password_recovery_service.dart` | Helper `verifyUser` gọi SDK `getUser()` tới Auth server |
| `lib/features/auth/services/recovery_intent_store.dart` | Giữ ready marker đã hết hạn để bootstrap còn biết owner cần signOut; provider thu hồi quyền/dọn, không dùng marker này để cho submit |
| `lib/features/auth/models/password_recovery_state.dart` | Hai state runtime verifying/verificationFailed; không đổi RecoveryPhase schema hoặc TTL60 phút |
| `lib/features/auth/presentation/widgets/password_recovery_gate.dart` | Loading khi xác minh server; lỗi có retry/hủy; không mở form khi cold verification chưa đạt; thông báo có thể cuộn |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` | Cleanup UI dùng thông báo trung tính, không tự khẳng định đã đổi mật khẩu khi cleanup xuất phát từ Hủy/hết hạn |
| `test/password_recovery_submit_guard_test.dart` (mới) | 33 ca guard/control: duplicate tại read/write/GET/PUT/cleanup, TTL và queue, cold/warm server authority, retry, cancel/Guest/login B, outcome sau dispatch |
| `test/password_recovery_cold_start_test.dart` | GET success fixture trả đúng user, giữ assertions recovery ready và không cấp normal account |
| `test/password_recovery_authority_test.dart` | Fake GET giải mã subject của JWT synthetic đúng owner; một seed token dùng JWT cùng format; giữ assertions authority/session |
| `test/password_recovery_callback_race_test.dart` | Thêm GET fixture đúng subject cho cold ready, giữ race assertions |
| `test/password_recovery_cleanup_test.dart` | GET fixture trả subject A/B theo token thay vì luôn B, giữ các tests cleanup/lifecycle/SQLite |
| `test/password_recovery_gate_test.dart` | Hai tests UI retry/giữ password input; GET fixtures và bootstrap fake/real async harness; giữ các tests form/cleanup cũ |
| `test/otp_server_authority_test.dart` | Năm tests signup OTP với AuthProvider lifecycle và LocalAccountLifecycleService/SQLite fixtures thật của dự án |
| `test/auth_role_security_test.dart` | UI test PATCH bị từ chối: giữ input, không đổi local profile/email; SDK fixture được đóng sau khi drain fake/real async |

AuthProvider credential queue/SDK ownership từ C3 được tái sử dụng nguyên trạng, không sửa file này. Profile và OTP production code đã có hành vi phù hợp, lượt này thêm evidence thay vì viết lại. Backend, DB/schema, dependencies, native config và redirect không đổi.

## 2. Why — luồng trước/sau

**Duplicate:** trước đây hai lời gọi cùng thấy ready trong khi write-ahead còn chờ, nên đều có thể gửi PUT. Bây giờ lời gọi đầu giữ một slot ngay trong RAM trước await, rồi mới lưu marker updating. Lời gọi chồng nhau bị từ chối; finally chỉ nhả đúng slot của mình, không nhả quyền của successor. Ghi marker thất bại vẫn PUT0 và có thể thử lại an toàn.

**TTL và server authority:** form mở lâu không làm intent được gia hạn. Khi tới lượt credential action, provider kiểm intent/generation/TTL/SDK session → GET user từ Auth server → kiểm lại các điều kiện sau await → PUT password. GET và PUT nằm trong cùng action, không có credential operation khác chen giữa; cleanup dùng queue được gọi bên ngoài action để tránh tự deadlock. Server trả UID sai/từ chối hoặc TTL đã hết thì PUT0.

**Cold start:** marker ready và SDK session lưu trong máy không đủ để mở form. App hiển thị đang xác minh; chỉ GET đúng user và authority còn hiệu lực mới ready. Mất mạng/5xx có retry; không phát normal account từ recovery session. Response cũ sau Hủy/Guest/login khác không mở lại form hoặc gửi PUT cho tài khoản mới.

**Hai loại lỗi khác nhau:** GET lỗi trước PUT nghĩa là chưa gửi mật khẩu, nên cho thử lại xác minh và giữ input. PUT đã gửi nhưng mất ACK vẫn uncertain theo cơ chế có sẵn, không tự gửi lại. PUT đã nhận ACK rồi mới qua TTL vẫn xử lý thành công/cleanup theo kết quả thực tế.

**Expired bootstrap owner:** store trước đây xóa ready marker hết hạn ngay trong lần đọc đầu, trước khi app biết SDK session đó thuộc recovery nào. Bản này giữ marker chỉ để provider từ chối/dọn đúng phiên; không gia hạn hoặc cấp quyền đổi mật khẩu. Với retry sau lỗi mạng, expired intent cũng không bị quên owner rồi để SDK session tồn tại. Marker sent/requesting hết hạn vẫn theo chính sách cũ; updating/cleanup vẫn được giữ cho xử lý kết quả chưa rõ hoặc dọn phiên.

Đối chiếu tài liệu Supabase về [server request của getUser](https://supabase.com/docs/reference/javascript/auth-getuser) và source SDK Dart **gotrue2.27.2 đã khóa**, `getUser` tại `gotrue_client.dart:874` thực hiện GET `/user`; không dùng trang JavaScript để suy đoán chữ ký Dart. Trang Dart `auth-getuser` trả404 trong lượt này, nên kiểm bằng source cài thực tế và search_docs chính thức. Không đổi SDK hoặc config cloud để làm tests xanh.

## 3. Testing — evidence thực tế

**Targeted cuối:220/220 PASS, exit0,24s.** 13 suites theo plan, bao gồm toàn bộ C3 ordering/authority/callback/cleanup và các tests OTP/profile/navigation. Log `.dart_tool/c4-codex-implementation/targeted-final.log`.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=2 --reporter=expanded --timeout=20s test/password_recovery_submit_guard_test.dart test/password_recovery_flow_test.dart test/password_recovery_cold_start_test.dart test/password_recovery_service_test.dart test/password_recovery_gate_test.dart test/password_recovery_authority_test.dart test/password_recovery_callback_race_test.dart test/password_recovery_cleanup_test.dart test/password_recovery_marker_ordering_test.dart test/otp_server_authority_test.dart test/auth_navigation_test.dart test/auth_role_security_test.dart test/profile_preferences_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

**Full cuối exit0:** analyzer **No issues found,3.8s**; Flutter **1080/1080 PASS,1:54**; Node **91/91 PASS,fail0/skipped0**,241ms. Wrapper `.dart_tool/c4-codex-implementation/full-final.log`; logs suite `.dart_tool/travelgo-verification/20261025T152847517Z-33692/`. Đây là kết quả đã thu completion của process, không suy diễn từ tiến độ.

Candidate snapshot trước targeted cuối và Full: **378 files** trong `.dart_tool/c4-codex-implementation/final-source-snapshot.json`. Diffcheck exit0,0 khác biệt so snapshot trước và sau Full. So snapshot C3, chỉ14 source/test files của C4 thay đổi; AuthProvider/backend/native và phần khác không drift. Diff riêng task được giữ ở `.dart_tool/c4-codex-implementation/c4-final.patch`. Các hashes chính:

| File | SHA256 |
| --- | --- |
| password_recovery_provider.dart | `4acb41d598231a1c4575b543ef165f779e38c0ad174e01d3e16a36db71bd95a8` |
| password_recovery_service.dart | `01d05d03731213691eff0a1bfb34ade216cc6bcc74da32495c6adb9b47b983e7` |
| recovery_intent_store.dart | `af40628081e6f63dad2f101d8d0fa2377463696ff876bd7eab83599d8684a086` |
| password_recovery_submit_guard_test.dart | `e40757ffd5611be0176efd88459233c304587f4c9303cade54f6a788f8959f70` |

### Tái hiện và kết quả trung gian

- `red.log`: fresh baseline6 PASS/18 FAIL trước sửa; chứng minh duplicate, TTL và server preflight thiếu. `green-1.log`:24/24 sau implementation đầu.
- `expiry-retry-red.log`: hết hạn khi chờ retry vẫn còn auth.isRecovering=true; sau sửa dọn đúng owner, nằm trong suite cuối.
- `bootstrap-expiry-red.log`: read expired ready làm mất owner; sau giữ marker cho owned cleanup, ca cold TTL đạt trong suite cuối.
- `recovery-2.log`:76 PASS/16 FAIL do old fake GET trả B hoặc404 khi yêu cầu A; `recovery-3.log`:92/92 sau sửa transport fixtures, không bỏ assertions.
- `targeted-candidate.log`:220/220 trước bước định dạng; **không thay targeted-final** trên bytes cuối.
- `targeted-1.log`, `auth-ui-1.log`, `auth-ui-2.log`, `auth-ui-final-candidate.log`: các lượt chưa hoàn tất do widget fixtures chờ I/O/SDK dispose trong fakeAsync. Chỉ dừng process trees do task tạo; không dừng IDE/app/device. `profile-trace.log` xác định lưu và giữ input đã chạy xong, chỉ dispose SDK chưa drain; `profile-final.log`1/1 sau flush cả hai async zones. Không bỏ ca UI để tránh chờ.
- `analyze-1.log`: bước định dạng chọn hunk không an toàn làm hỏng cú pháp test cleanup; khôi phục từ task-start backups và bản formatter đầy đủ, giữ mọi assertion. `analyze-2.log` chỉ còn5 lint thiếu braces; đã sửa cơ học. Không đổi analyzer config hoặc suppress lints. Full cuối phải xác nhận source sau khôi phục.
- Lần thử chạy test đầu bị chặn quyền lockfile ở Flutter SDK; các lần chạy sau được automatic review cho phép quyền cache SDK. Không cài/nâng package hoặc thao tác app để vượt giới hạn.

### Bảng findings CORE_REVIEW_R1

Các ID dưới đây thuộc **CORE_REVIEW_R1**, khác với F01–F05 trong các review C3 sau đó.

| Finding gốc | Trạng thái source/targeted | Evidence |
| --- | --- | --- |
| F01 stale marker/bootstrap | CLOSED source/automated, giữ C3 | authority/callback/ordering suites trong220 targeted và Full1080; response GET sau cancel cũng bị chặn |
| F02 cancel/SDK session | CLOSED source/automated, giữ C3 | marker-ordering, cleanup, account-transition tests; login B trong preflight giữ SDK B |
| F03 duplicate submit /R2 | CLOSED source/automated C4 | Double-submit same/different password; pending read/write/GET/PUT/cleanup → tối đa1 PUT |
| F04 cleanup failure/account bypass | CLOSED source/automated, giữ C3 | Cleanup failure/retry, marker gone, SQLite/lifecycle negative và positive controls |
| F05 ready intent expiry /R6 | CLOSED source/automated C4 | TTL−1ms/TTL/TTL+1ms, pending read/write/queue/GET, retry và bootstrap expiry |
| F06 cold server revalidation /R7 | CLOSED source/automated C4 | GET observed; cold/warm success/denied/wrong UID/malformed/network/5xx; no ready/PUT sai |

Các trạng thái CLOSED trên dựa vào targeted và Full đã hoàn tất cùng candidate; hashes/snapshot định danh dirty source trên base HEAD nêu ở đầu. Đây là self-review có fresh tests, chưa independent review hoặc live acceptance. Không sửa/run raw old probes rồi gọi raw suite cũ PASS.

## 4. Problems / giới hạn

Runtime/thiết bị/email thật **NOT RUN**: chưa thử signup gửi email/OTP thật, link warm/cold trên APK, đổi mật khẩu tài khoản thật và login lại. SMTP/redirect/native acceptance không được thay bằng mocks. C3 từng bị automatic approval review từ chối hot reload do không có app/DTD và quyền runtime cụ thể; C4 không thử lại/bypass hoặc build/install/clear thiết bị từ quyền code này.

Không stage/commit/push/merge/deploy, không SQL/cloud mutation, không đụng dữ liệu/draft thiết bị. Toàn bộ dirty owner work được giữ. Chưa bắt đầu C5. Sau source/automated, có thể review độc lập và bố trí nghiệm thu live riêng theo môi trường/quyền cụ thể.

Scope model/TTL/schema không thay; store thay tối thiểu để giữ expired ready owner được regression chứng minh cần. Ba nhóm behavior gồm submit/preflight chính, expired retry cleanup và expired bootstrap owner; không dùng tên gói mới để reset repair guard. Các chỉnh fixture/async/format được ghi riêng, không gọi là product fixes mới hoặc xóa bằng chứng thất bại.

## 5. Lesson Candidate

Problem → Root Cause → Rule: “bấm hai lần khi ghi local còn chờ dẫn đến hai request” → “khóa sau await” → “giữ quyền đồng bộ ở entry, release theo đúng owner, kiểm lại điều kiện khi dispatch”.

Problem → Root Cause → Rule: “yêu cầu hết hạn nhưng SDK session còn tồn tại” → “xóa marker đồng nghĩa quên owner cleanup” → “hết quyền mutation vẫn phải giữ trách nhiệm dọn phiên; kiểm TTL sau await và bảo toàn owner qua bootstrap”.
