# C4 — Kế hoạch triển khai chi tiết, 25/10/2026

**Trạng thái: OWNER ĐÃ DUYỆT — CODEX TRIỂN KHAI C4.** Ngày25/10/2026 owner xác nhận “duyệt nhưng mà lần này tôi cho phép codex code thay vì antigravity”. Chỉ thị này cho Codex implement riêng C4, không sửa permanent workflow. Đây là phần chi tiết hóa C4 trong kế hoạch Core R2 đã duyệt, không mở thêm phạm vi sản phẩm. Codex không dùng Superpowers theo chính sách hiện hành; nếu sau này giao Antigravity code, prompt/handoff vẫn bắt buộc yêu cầu dùng Superpowers phù hợp và ghi evidence thực tế. Kết quả thực hiện ghi ở [bàn giao C4](COURSEWORK_C4_CODEX_IMPLEMENTATION_20261025.md), không coi approval là evidence PASS.

Nguồn yêu cầu: [phạm vi sản phẩm](../../.agent/product-scope.md), [Core R2, mục C4](../superpowers/plans/2026-10-24-coursework-core-r2.md#c4--submitexpiryrevalidation-otp-và-hồ-sơ), [review recovery lịch sử](CORE_REVIEW_R1_CODEX_REVIEW_20261024.md), [bàn giao C3 cuối](COURSEWORK_C3_CODEX_IMPLEMENTATION_20261025.md). C3 là tiền đề source/automated; chưa phải nghiệm thu thiết bị hoặc email thật.

## 1. Hiện trạng và mục tiêu

Checkout kiểm tra trong lượt lập plan: `D:/Travel-Go-Android/travel-go`, branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty work C1/C2/C3. Đối chiếu snapshot C3 `.dart_tool/c3-codex-implementation/final-source-snapshot.json`: **377 files, 0 khác biệt**. HEAD một mình không định danh source chưa commit; giữ snapshot và hash candidate khi triển khai.

Evidence C3 kế thừa, **không chạy lại trong lượt chỉ lập plan**: targeted126 PASS; Full analyzer sạch, Flutter1039 PASS, Node91 PASS, exit0. Không dùng các số này làm kết quả C4.

| Phần | Quan sát source hiện tại | Đích C4 |
| --- | --- | --- |
| Gửi mật khẩu | `submitNewPassword` chuyển sang updating sau await `_writeMarker`; hai lời gọi có thể cùng đi qua kiểm tra ban đầu | Một yêu cầu giữ quyền submit ngay trước await đầu tiên; tối đa một PUT khi hai lời gọi chồng nhau |
| Hết hạn | TTL model là60 phút; store kiểm khi đọc, callback có kiểm; submit từ intent trong RAM chưa kiểm TTL | Kiểm lại TTL cả sau các lần chờ và ngay trước PUT, dùng clock/model hiện có |
| Mở lại app | Ready marker chỉ so SDK session local/UID/expiry | Server xác minh thành công, đúng user và còn authority mới mở form |
| Trước đổi mật khẩu | Có credential queue/authority fence C3, chưa có server preflight trong action update | Revalidate server trong cùng credential action; kiểm lại TTL/owner/session sau GET rồi mới PUT |
| OTP | Đã gọi Supabase verifyOTP, kiểm session, có test server authority | Giữ xác thực thật, kiểm cả đường lifecycle đang dùng; không tạo user từ OTP giả hoặc response thiếu session |
| Hồ sơ | Payload allowlist; UI email chỉ đọc; có tests quyền/epoch/ACK | Xác nhận tên/điện thoại/địa chỉ đúng owner, server ACK thật; lỗi/response muộn không làm đổi tài khoản mới |

Ba gap recovery trên được xác định bằng đọc source và đối chiếu findings lịch sử; **chưa tái chạy R2/R6/R7 trên candidate C4**. Bước đầu implementation phải có fresh regressions và positive controls, không coi báo cáo cũ là fresh RED.

Luồng đích: mở link hoặc phục hồi yêu cầu → xác minh server → nhập mật khẩu → giữ quyền gửi một lần → lưu trạng thái updating → xác minh lại trong hàng đợi → gửi đổi mật khẩu → xử lý kết quả → dọn phiên → đăng nhập bằng mật khẩu mới. Đăng ký vẫn dùng OTP hiện có, không thêm OTP cho recovery.

## 2. Gói C4.1 — Chống gửi đổi mật khẩu trùng

**Files chính:** `lib/features/auth/providers/password_recovery_provider.dart`; `test/password_recovery_flow_test.dart`; test mới `test/password_recovery_submit_guard_test.dart` nếu tách fixtures giúp đọc rõ.

1. Thêm regression giữ write-ahead chưa hoàn tất, gọi submit hai lần với cùng mật khẩu và với hai mật khẩu khác nhau. Đếm HTTP PUT thực tế qua fake transport; không chỉ đếm lời gọi UI hoặc service stub.
2. Giữ quyền submit đồng bộ trước await đầu tiên, kể cả nhánh phải đọc store. Quyền gắn với lần gọi/intent/generation; lời gọi thứ hai trả false, không tự xếp một lần đổi mật khẩu khác.
3. Giữ write-ahead trước PUT, không bỏ persistence để chống duplicate. Khi ghi thất bại: PUT0, báo lỗi, cho thử lại nếu intent vẫn hợp lệ.
4. Giải phóng quyền ở mọi đường thoát; continuation cũ không được giải phóng quyền của intent mới hoặc khôi phục state đã hủy. Không tái gửi ở uncertain/cleanup sau khi PUT đã đi.

**Đạt khi:** double-submit ở các điểm pending write, pending SDK/GET/PUT và cleanup không tạo PUT thứ hai; single-submit hợp lệ vẫn PUT1; write fail PUT0; retry trước dispatch hoạt động. Giữ nguyên marker FIFO và cleanup ownership của C3.

## 3. Gói C4.2 — Hạn yêu cầu và kiểm tra ngay trước dispatch

**Files chính:** recovery provider; service nếu cần helper dùng chung. Model/state chỉ sửa khi có nhu cầu được regression chứng minh, không đổi TTL/schema marker.

1. Dùng `PendingRecovery.isExpired(_clock())`, không dùng tuổi JWT thay cho tuổi yêu cầu recovery và không gia hạn bằng cách tạo requestedAt mới.
2. Kiểm TTL lúc submit; sau pending read/write; bên trong credential action khi tới lượt; sau await server revalidation và ngay trước gọi updatePassword.
3. Kiểm intent/generation, authority và SDK user/session tại các điểm tương ứng. Không gửi PUT khi cancel, Guest, đăng nhập khác hoặc yêu cầu mới đã thay thế.
4. Hết hạn trước dispatch: PUT0, không báo đổi mật khẩu thành công; hướng dẫn gửi yêu cầu mới. Cleanup theo cơ chế C3, lỗi dọn vẫn có retry.
5. Nếu PUT đã được gửi rồi mới qua TTL: không giả vờ hủy được server mutation. Giữ xử lý ACK/uncertain và cleanup hiện có theo kết quả thực tế.

**Đạt khi:** tại TTL−1ms còn hợp lệ nếu các điều kiện khác đạt; tại TTL và TTL+1ms không PUT. Hết hạn trong lúc chờ write, credential queue hoặc GET đều PUT0. Fake clock kiểm TTL intent độc lập với expiry của SDK token. Positive control phải chứng minh một PUT hợp lệ vẫn đi.

## 4. Gói C4.3 — Server revalidation khi mở lại và trước PUT

**Files chính:** `password_recovery_provider.dart`, `services/password_recovery_service.dart`; `auth_provider.dart` chỉ khi cần mở rộng tối thiểu contract queue hiện có. Tests: `password_recovery_cold_start_test.dart`, `password_recovery_service_test.dart`, submit guard suite.

1. Trước sửa, đối chiếu API server validation trong SDK đã khóa và tài liệu Supabase chính thức. Dự kiến helper service gọi `client.auth.getUser()` trả identity server; không dùng `currentUser` local thay cho GET và không nâng SDK.
2. Cold ready: giữ trạng thái đang kiểm tra cho đến khi GET thành công. Không publish normal account từ phiên recovery. Response đúng verifiedUserId, TTL còn hạn và authority hiện tại mới chuyển ready.
3. Trước PUT: GET và update chạy trong **cùng một action của `runRecoveryMutation`**, tránh normal credential operation chen giữa. Sau GET phải kiểm lại owner/generation, TTL và local session phù hợp rồi mới dispatch PUT.
4. Không gọi lồng credential queue hoặc await cleanup dùng cùng queue ngay bên trong action; trả lỗi có phân loại rồi cleanup bên ngoài để tránh tự deadlock.
5. GET401/403, user thiếu/sai hoặc phiên hết hạn: không ready/PUT, hướng dẫn tạo yêu cầu mới và dọn phiên thuộc recovery cũ. GET lỗi mạng/5xx: không coi đã xác minh; báo lỗi, có retry revalidation hoặc hủy. Nội dung đang nhập được giữ khi retry có thể tiếp tục an toàn.
6. Phân biệt rõ **GET chưa dispatch PUT** với **PUT đã gửi nhưng mất ACK**. Lỗi preflight không được gắn thông báo “không biết mật khẩu đã đổi chưa”; ngược lại, PUT uncertain không được tự retry password mutation.
7. Response GET tới muộn sau cancel/login/successor không mở form, không đổi state người mới và không đăng xuất phiên mới.

**Đạt khi:** cold server success đúng UID → ready và normal account vẫn null; revoked/wrong UID/malformed/offline → không ready, PUT0; retry online thành công → ready. Warm submit bị server deny → PUT0. Cancel/owner switch/TTL hết trong GET → PUT0. Server success + session hợp lệ → PUT1 và cleanup đúng. Tests phải assert GET thật được fake transport ghi nhận.

## 5. Gói C4.4 — Giao diện recovery, OTP và hồ sơ

**Files có thể sửa khi test chứng minh cần:** `password_recovery_state.dart`, `password_recovery_gate.dart`, `reset_password_screen.dart`, `forgot_password_screen.dart`, `login_screen.dart`, `register_screen.dart`, `otp_verification_screen.dart`, `profile_screen.dart`, `auth_provider.dart`.

**Recovery UI:** thể hiện đang xác minh, vô hiệu gửi khi bận; giữ form qua ready→updating, không mất mật khẩu đang nhập do rebuild. Khi GET lỗi mạng có thử lại/hủy rõ; khi hết hạn có đường gửi yêu cầu mới; cleanup retry vẫn hoạt động sau marker đã mất. Chỉ thêm state/helper cần thiết, không thiết kế lại màn hình.

**OTP:** chạy `test/otp_server_authority_test.dart` và auth navigation; kiểm đường lifecycle của app, không chỉ nhánh legacy. Ca bắt buộc: token sai định dạng không gọi server; OTP sai/hết hạn/network fail/thiếu session không cấp user; hợp lệ +session đúng user mới thành công. Nếu thiếu coverage thì thêm test với cấu hình lifecycle thật bằng fixtures local. Không mặc định OTP đang hỏng, không viết lại luồng đã đạt.

**Hồ sơ:** dùng thêm `test/auth_role_security_test.dart` vì tests cơ bản profile nằm ở đó; `profile_preferences_test.dart` chủ yếu kiểm preferences/owner persistence nên không thay thế kiểm profile. Giữ email chỉ đọc; PATCH chỉ gửi full_name/phone/avatar_url/address đúng owner. Kiểm ACK đúng row, lỗi giữ nội dung sửa, response A muộn không ghi sang B/Guest. Không mở chức năng đổi email/role; không nhân task này gỡ preferences chưa có quyết định riêng.

**Đạt khi:** thao tác thành công có phản hồi đúng từ server fixture; thất bại không báo thành công giả; không lẫn tài khoản; OTP/recovery không mở quyền admin. Chỉ sửa source OTP/profile khi có failing behavior cụ thể, không thêm refactor chỉ để mọi gói đều có diff.

## 6. Ma trận nghiệm thu và thứ tự chạy

Thứ tự thực hiện: **snapshot → C4.1 → C4.2 → C4.3 → C4.4 → targeted tổng hợp → Full → báo cáo/review**. Viết ca lỗi và đối chứng trước từng sửa; kiểm targeted của gói ngay sau sửa. Dùng Completer/gated fake I/O và clock để khóa đúng thứ tự, không dựa sleep ngẫu nhiên.

| Nhóm | Bằng chứng tối thiểu |
| --- | --- |
| Duplicate R2 | Cùng/khác mật khẩu khi write pending; pending GET/PUT/cleanup; PUT tối đa1 |
| Expiry R6 | RAM ready, sát biên TTL, quá TTL khi chờ read/write/queue/GET; PUT0 khi đã hết hạn |
| Revalidation R7 | GET success/401/UID sai/network/malformed; cold và warm; không PUT hoặc mở form sai |
| C3 regression | FIFO write→cancel→successor; cleanup fail/retry không cần marker; callback cũ; SDK owner trước ready-marker |
| OTP | Wrong/expired/no server/no session deny; success control; lifecycle path |
| Profile | Allowlist/email/role, đúng owner, server ACK, A→B/Guest late success/error; UI giữ input khi lỗi |
| Recovery outcome | Success → cleanup → yêu cầu login mới; server PUT reject cho retry an toàn; PUT uncertain không tự gửi lại |

Chạy targeted bằng helper hiện có, ví dụ:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/password_recovery_flow_test.dart,test/password_recovery_cold_start_test.dart,test/password_recovery_service_test.dart,test/password_recovery_gate_test.dart,test/password_recovery_authority_test.dart,test/password_recovery_callback_race_test.dart,test/password_recovery_cleanup_test.dart,test/password_recovery_marker_ordering_test.dart,test/otp_server_authority_test.dart,test/auth_navigation_test.dart,test/auth_role_security_test.dart,test/profile_preferences_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Thêm suite submit guard mới vào targeted nếu tạo. Trước chạy xác nhận cú pháp `TestPath` theo script hiện tại; không chạy đồng thời hai Full. Nếu cold fixture cũ trả `{}` cho mọi HTTP200, thay GET success bằng user payload hợp lệ và thêm negative tests; không bỏ assert server authority hoặc ready positive control để lấy PASS.

Old ignored R2/R6/R7 probes chỉ là đầu vào tái hiện. Không sửa probes cũ rồi gọi raw suite cũ PASS; mang hành vi vào permanent tests có sequencing phù hợp FIFO C3. Các ca await cancel trước release chính I/O gate cần thiết kế lại thứ tự, giữ nguyên invariant.

Full phải analyzer sạch, toàn Flutter và Node contracts exit0 trên cùng candidate bytes; ghi số thực tế, log và hashes. Kết quả C3 không thay verification C4. Repair guard hiện hành tối đa3 vòng vẫn giữ; không reset bằng đổi tên gói, không rollback dirty work của owner khi thất bại.

## 7. Nghiệm thu email/thiết bị tách riêng

Sau source/automated, nghiệm thu riêng trên tài khoản thử và đúng bản app: đăng ký → email OTP → đăng nhập → đăng xuất; recovery warm/cold → mật khẩu mới → login bằng mật khẩu mới; link/OTP sai, hết hạn và mạng lỗi. Mock HTTP PASS không chứng minh SMTP, redirect hoặc app link trên thiết bị.

Lượt lập plan này không gửi email, đổi mật khẩu thật, build/cài app, hot reload hay thao tác thiết bị. C3 từng bị automatic approval review từ chối hot reload vì không có app/DTD và quyền runtime cụ thể; không thử lại hoặc bypass từ plan. Live/device thiếu môi trường/quyền thì ghi BLOCKED/NOT RUN chính xác, không cản source C4 hoặc bắt buộc chặn C5. Không đổi dependency/native URL/cấu hình auth cloud/schema trong C4; nhu cầu phát sinh phải nêu riêng.

## 8. Điều kiện đóng C4 và bàn giao

1. Các ca trong ma trận đạt trên source cuối; C3 regressions giữ đạt; không làm yếu assertions.
2. Bảng sáu findings **của CORE_REVIEW_R1** dùng ID đầy đủ để tránh nhầm F03 cleanup của các review C3 mới: F01/F02/F04 giữ evidence C3 và fresh regression; F03 duplicate/F05 expiry/F06 revalidation chỉ CLOSED khi có test C4 thực tế. Ghi evidence/test/hash, không chỉ đánh dấu checkbox.
3. Báo cáo `docs/phase-3/COURSEWORK_C4_CODEX_IMPLEMENTATION_20261025.md` nếu Codex implement, hoặc report Antigravity tương ứng nếu owner giao bên đó. Đủ Changed/Why/Testing/Problems/Lesson Candidate; giải thích thao tác người dùng → queue/service/server → kết quả UI và giới hạn live.
4. Cập nhật checkpoint master/core sau khi có kết quả, không đánh dấu C4 done ngay khi plan được duyệt. Phân biệt self-review và review độc lập; không tự tạo agent review.
5. Không stage/commit/push/merge/deploy, không xóa dirty files ngoài scope. Trước implementation snapshot phần sẽ sửa để tách diff C4 khỏi C1–C3 chưa commit.

**Bàn giao lượt chỉ lập plan, trước approval:** Changed — chỉ thêm tài liệu plan. Why — chuyển C4 đã chốt thành các gói có trigger, file và tiêu chí kiểm chứng cụ thể. Testing — đọc source/test/plan và hash377 files C3 không đổi; lúc đó chưa chạy test C4. Problems — lúc lập plan chưa có fresh RED/GREEN C4 hoặc live acceptance. Lesson Candidate — kiểm tra trước await không bảo vệ điều kiện sau await; quyền submit, tuổi intent và quyền sở hữu phải còn đúng ngay tại điểm dispatch.

## 9. Kết quả triển khai sau owner duyệt — 25/10/2026

Codex đã implement C4 theo quyền riêng owner cấp: **SOURCE/AUTOMATED PASS, self-review**. Targeted220/220, Full analyzer sạch/Flutter1080/1080/Node91/91, exit0; snapshot378 files không drift. [Báo cáo và bảng sáu findings](COURSEWORK_C4_CODEX_IMPLEMENTATION_20261025.md). Store thay tối thiểu để giữ expired ready owner cho cleanup, có fresh regression; TTL/schema/native/dependencies không đổi. Runtime/email/thiết bị và review độc lập chưa nghiệm thu; chưa commit/push/merge/deploy, chưa bắt đầu C5.


## 10. Correction sau review R1 và review R2 — 25/10/2026

Owner duyệt Codex sửa C4-F01 rồi review. [Review R2](C4_CODEX_REVIEW_R2_20261025.md) đóng finding source/automated và self-review: Full1088/91 PASS, permanent8/8 và nguyên probes5/5 PASS; snapshot379 files0 drift. [Bàn giao correction](COURSEWORK_C4_FIX_CODEX_REPORT_20261025.md) ghi rõ RAM retry khác durable crash recovery. Không thay TTL/store/API/schema/dependency/native; không còn finding mở trong scope correction. Chưa nghiệm thu live/thiết bị hoặc independent review; chưa bắt đầu C5.
