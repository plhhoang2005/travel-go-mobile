# Prompt Antigravity — sửa findings C3, chưa chuyển C4

Owner đã trả lời **“duyệt” sau review C3 REQUEST CHANGES**: cho phép sửa tiếp C3-F01–F04. Đây là duyệt việc sửa, không phải nghiệm thu candidate đang lỗi. Triển khai đúng phạm vi dưới đây, không cần xin lại scope đã duyệt.

**Bắt buộc sử dụng Superpowers khi code** theo chỉ thị thường trực của owner. Đọc và áp dụng các skill phù hợp: using-superpowers, executing-plans, systematic-debugging, test-driven-development, verification-before-completion. Nêu skill đang dùng và mục đích; nếu thiếu skill thì báo rõ, không giả đã dùng. Skill không mở thêm quyền hoặc bắt owner phê duyệt lại thiết kế đã chốt. Codex review độc lập sau khi bạn bàn giao.

## 1. Candidate và tài liệu cần đọc

Repo `D:/Travel-Go-Android/travel-go`; branch bàn giao `fix/ai-planning-stability`, HEAD base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2/C3. Xác minh status/HEAD và diff hiện tại trước khi sửa; không reset/stash/clean hoặc bỏ các sửa C3 đã đạt.

Đọc `AGENTS.md`, `.agent/rules.md`, `.agent/workflow.md`, [.agent/product-scope.md](../../.agent/product-scope.md), [review C3](C3_CODEX_REVIEW_20261025.md), [handoff C3 gốc](COURSEWORK_C3_ANTIGRAVITY_HANDOFF_20261025.md), [Core R2 mục C3/C4](../superpowers/plans/2026-10-24-coursework-core-r2.md). Report C3 có exact candidate hashes; nếu source đã thay, ghi rõ khác biệt trước khi diễn giải evidence.

Baseline review vừa chạy: analyzer PASS, **1011 Flutter / 91 Node PASS**; original scoped C3 probes10/10 PASS nhưng X1–X6 FAIL, control PASS; production-store P1/P2 FAIL xác nhận hai lỗi cancellation. Đây là evidence trước correction, không phải kết quả sau sửa. Không làm lại fixes R1/R3/R4/R5/R8/R9/R10 đã GREEN.

## 2. Sửa bốn nhóm lỗi, kiểm từng trigger

| Finding | Trigger và kết quả bắt buộc |
| --- | --- |
| **C3-F01 / X6, P2** | Gọi cancel A, giữ clear pending, rồi submit → **0 PUT**. Thu hồi quyền SDK dùng chung đồng bộ trước await, không chỉ tăng generation riêng của recovery provider hoặc disable UI. Khi RAM chưa có intent, cũng không chờ store.read rồi mới thu hồi quyền. |
| **C3-F01 / X2, P1** | Cleanup A pending, yêu cầu login B chồng lấn → B chỉ được cấp sau cleanup hợp lệ; sau khi mọi continuation A kết thúc, SDK vẫn đúng B. Không có direct signOut muộn tác động session B. |
| **C3-F02 / X1** | Ready-write/clear A pending, yêu cầu intent B → sau khi queue hoàn tất, marker và RAM nhất quán cho B; A không ghi đè/xóa B. Bảo vệ ordering/commit theo owner xuyên write/clear, không chỉ clear(expected A) sau stale write. |
| **C3-F02 / slot** | Callback A hoàn tất khi B có operation mới → finally A không reset in-flight/code slot của B. Kiểm bằng barrier thực sự, không chỉ test A xong rồi mới B. |
| **C3-F03 / X5** | Marker clear A fail → chọn Guest → login B → không cấp account; Guest vẫn dùng được, cleanup/retry vẫn còn và **0 uncaught async error**. Kiểm cả AuthProvider thường và lifecycle + SQLite, có control cleanup success cấp đúng owner B. |
| **C3-F03 / X4** | Clear marker thành công nhưng SDK signOut fail → auth và provider giữ owner/trạng thái cleanup lỗi có thể retry; không idle/null intent trong khi auth còn recovering. Retry chỉ dọn phiên, không gửi lại PUT mật khẩu. |
| **C3-F04 / X3** | Write marker đầu tiên fail trước beginRecovery → 0 email, kết thúc sending, báo lỗi; storage phục hồi thì retry gửi đúng một yêu cầu. Phân biệt operation chưa begin auth với operation đã hủy. |

Bảo toàn các invariant sau:

- Một quy tắc ownership/generation nhất quán giữa provider, auth, marker và SDK queue. Không chỉ vá một nhánh UI hoặc thêm check sau side effect đã xảy ra.
- Cleanup pending/failed là trách nhiệm độc lập với quyền ready và lựa chọn Guest. Mọi đường cấp account liên quan phải kiểm/await cleanup, kể cả sau Guest; chỉ bỏ owner/retry khi toàn cleanup thành công.
- Cancel, retryCleanup và success cleanup có ordering chung với credential/account transitions. Không invalidator enqueue ngược rồi tự chờ gây deadlock; lỗi phải trả về state/kết quả rõ.
- Giữ account invalidation, lifecycle handles, saved trips/drafts và input reset C1/C2. Marker recovery thuộc SharedPreferences; không xóa chuyến đi hoặc SQLite của user để “dọn sạch A”.

Sửa chính ba file `lib/features/auth/providers/password_recovery_provider.dart`, `lib/features/auth/providers/auth_provider.dart`, `lib/features/auth/services/recovery_intent_store.dart`; permanent tests authority/callback-race/cleanup. Model/service/gate/reset UI/lifecycle chỉ sửa nếu trace trực tiếp của các invariant trên cần, ghi rõ lý do. Giữ stack/API phù hợp; không refactor rộng, thêm framework/dependency, đổi SDK/native config/URL hoặc schema.

## 3. Tests trước và sau sửa

Reviewer artifacts ignored hiện có:

- `.dart_tool/c3-codex-review/original_c3_probe_test.dart`
- `.dart_tool/c3-codex-review/overlap_probe_test.dart` (X1–X6 và control)
- `.dart_tool/c3-codex-review/production_store_probe_test.dart` (P1/P2)
- Logs `probes.log`, `overlap-final.log`, `production-store.log` cùng thư mục; [report](C3_CODEX_REVIEW_20261025.md) giải thích giới hạn fixture.

Chuyển regression vào permanent tests, dùng Completer/barrier và fixtures SDK thật đã cài + fake HTTP, UUID/JWT synthetic hợp lệ. Hai ca production-store giữ completion **sau super.clear**, bảo toàn comparison/cache semantics thật. X1 giữ write trước commit theo seam permanent test đã có; ghi đúng là controlled I/O contract, không gọi nó bằng chứng native-device ordering.

**Giữ hành vi expected, không khóa cách triển khai vào thứ tự await của probe cũ.** Nếu cancel/queue đúng phải chờ operation đang pending, hãy khởi chạy `cancelFuture`, assert authority đã bị thu hồi ngay, thả I/O gate rồi mới await cancelFuture. Nếu B phải chờ A drain, assert B chưa dispatch/grant, thả A, sau đó assert B hoàn tất và không bị A tác động. Không await cancel đang drain rồi đợi gate chỉ được release sau chính await đó; timeout kiểu này chưa chứng minh lỗi sản phẩm. Ghi rõ mọi điều chỉnh harness và giữ interleaving/negative assertions; không bỏ test, mock kết quả thành công hoặc nới validation để xanh.

Ghi RED actual assertion và positive controls trước sửa; nếu ca đã PASS ở candidate hiện tại thì ghi evidence thay vì tạo RED giả. Không sửa/xóa bản reviewer artifact để che kết quả cũ; khi cần harness mới, tạo file riêng và giải thích ordering. Giữ tests đã đạt và assertions chống lẫn tài khoản.

Chạy targeted có regression mới và auth/recovery bị ảnh hưởng, sau đó Full:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_authority_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_callback_race_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_cleanup_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_gate_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/auth_navigation_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Không yêu cầu các ca C4 R2/R6/R7 của probe lịch sử GREEN trong correction C3. **C4 double-submit, TTL/revalidation, OTP/profile/live vẫn deferred.** Riêng PUT sau Hủy thuộc authority C3 và phải sửa trong gói này.

Giữ guard tối đa ba vòng sửa lỗi đang hiệu lực; ghi các vòng C3 đã dùng, không coi handoff mới là reset budget. Không áp giới hạn file/tool calls cũ. Không commit/push/merge, deploy/SQL/email/live AI, đổi thiết bị, install/clear dữ liệu hoặc đọc/log credentials thật. Nếu có runtime phù hợp được phép dùng thì reload/restart theo tooling và ghi kết quả; nếu không có thì ghi NOT RUN, không can thiệp thiết bị owner để ép có evidence.

## 4. Báo cáo và điểm dừng

Tạo `docs/phase-3/COURSEWORK_C3_FIX_ANTIGRAVITY_REPORT_20261025.md` theo **Changed / Why / Testing / Problems / Lesson Candidate**. Ghi:

- Branch/base HEAD, diff/source hashes cuối, file sửa và vai trò; đối chiếu candidate reviewer thay vì toàn dirty repo.
- Bảng C3-F01–F04 → X/P hoặc permanent regression → barrier → RED/GREEN/command/exit/log; control hợp lệ, lifecycle/SQLite và UI retry/Guest behavior.
- Giải thích cho owner luồng Hủy A → B, vì sao local generation không đủ thu hồi quyền SDK, và vì sao clear marker thành công chưa đồng nghĩa toàn cleanup thành công.
- Thay đổi harness nếu có; phân biệt assertions mới đo được với chỉ kiểm source, automated với device/live. Không tuyên bố có lộ dữ liệu thật từ fixture hoặc toàn recovery/app đã hoàn thiện.
- Findings C4 vẫn OPEN/deferred; vòng sửa lỗi đã dùng và phần NOT RUN/BLOCKED.

**Dừng sau candidate correction C3 để Codex independent re-review. Không tự chuyển C4 hoặc tự đánh dấu C3 ACCEPT.**
