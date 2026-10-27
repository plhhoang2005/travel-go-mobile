# Prompt Antigravity — correction C3 sau Codex re-review R2

Owner trả lời **“duyệt” sau review R2 REQUEST CHANGES**: cho phép sửa phần còn mở **C3-F01, C3-F02 và C3-F05**. Đây là duyệt việc sửa, chưa nghiệm thu C3. Giữ C3-F03/F04 và 19 reviewer probes đã GREEN; chưa chuyển C4.

**Bắt buộc dùng Superpowers khi code** theo chỉ thị thường trực owner: áp dụng các skill phù hợp như using-superpowers, executing-plans, systematic-debugging, test-driven-development và verification-before-completion. Nêu skill và mục đích; nếu thiếu thì báo rõ, không giả đã dùng. Dùng skill không mở thêm scope/quyền, không yêu cầu owner duyệt lại cùng thiết kế.

## 1. Đọc đúng candidate

Repo `D:/Travel-Go-Android/travel-go`, branch bàn giao `fix/ai-planning-stability`, HEAD base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2/C3. Chạy status/HEAD, đối chiếu diff và hashes trước sửa; giữ mọi owner work, không reset/stash/clean hoặc rollback cả file về report cũ.

Đọc `AGENTS.md`, `.agent/rules.md`, `.agent/workflow.md`, [.agent/product-scope.md](../../.agent/product-scope.md), [review C3 R2](C3_CODEX_REVIEW_R2_20261025.md), [handoff correction trước](COURSEWORK_C3_FIX_ANTIGRAVITY_HANDOFF_20261025.md) và [Core R2 mục C3/C4](../superpowers/plans/2026-10-24-coursework-core-r2.md).

Candidate hiện tại khác ba hash trong report author trước. Hash `password_recovery_provider.dart` thực là `8cc099be29dd71ec8c12195b69467dce2c91a42b57def923874680fc51a8b12a`; hai test authority/cleanup và các hash còn lại xem review R2. Source ổn định suốt reviewer run; không coi report 1023PASS là evidence cho bytes hiện tại.

## 2. Thực hiện theo thứ tự

### Bước A — C3-F05: khôi phục verification trên đúng candidate

- Sửa override `clear()` ở `test/password_recovery_authority_test.dart:60` và `test/password_recovery_cleanup_test.dart:58` để khớp `clear([String? expectedIntentId])`, **forward expected ID** tới `super.clear(expectedIntentId)`. Giữ barriers và conditional-clear semantics, không chỉ ép compile.
- Thống nhất import prefix trong cleanup test: đang import `localFixtures` nhưng gọi `local_fixtures` dòng654; xử lý lint cùng thay đổi.
- Trace assertion fail của `F01_F02_stale_mutation_A_never_overwrites_or_clears_intent_B` ở callback test dòng332, expected ready=true nhưng actual=false. Kiểm bootstrap/auth initialization và fixture trên source thật; không đổi expected, xóa test hoặc bỏ guard quyền chỉ để xanh. Nếu fixture không mô tả recovery ownership hợp lệ, sửa fixture có giải thích và positive control chứng minh điều đó.
- Chạy analyzer/targeted trước khi diễn giải counts. Baseline thực: analyzer3errors+1info, targeted77PASS/1assertFAIL/2loadFAIL; Full dừng analyzer. Node chạy riêng91/91 PASS.

### Bước B — C3-F01: cleanup sở hữu đúng operation/phiên

Không dùng verifiedUserId hoặc null thay cho ownership của intent/account transition. Cần xử lý cùng quy tắc cho cancel, retryCleanup và success cleanup, phối hợp credential queue, kiểm lại sau await; tránh invalidator enqueue ngược rồi tự chờ deadlock. Giữ revoke đồng bộ trước await và 0 PUT sau Hủy đã đạt.

Các ca bắt buộc bổ sung permanent regression:

1. **Phase sent / verifiedUserId null:** cancel A clear pending → login B thành công → release A → SDK vẫn B. Null không cấp quyền signOut B.
2. **Đăng nhập mới cùng user:** ready A → cancel pending → login mới bằng mật khẩu cho cùng user A → release cleanup cũ → giữ phiên login mới. Cùng user ID không có nghĩa cùng recovery operation.
3. **Stale retry:** cancel A clear fail → retry giữ preflight read → login B cleanup thành công → release read cũ → retry không signOut B, không xóa marker mới hoặc thay state của operation mới.
4. Giữ control ready A → user B khác, cancellation khi chưa có phiên mới và retry cleanup thành công. Assert SDK user đúng **trước và sau** release, marker/state/lifecycle phù hợp; không chỉ boolean login.

Hai ca đầu đã được reviewer xác nhận thêm bằng RecoveryIntentStore thật + SharedPreferences mock, giữ completion **sau super.clear**. Đừng quy kết chúng chỉ là giả lập conditional clear sai.

### Bước C — C3-F02: không hồi sinh marker đã hủy bằng write bù

Hiện A write stale xong thì `store.write(_currentIntent!)` để phục hồi B. Giữ write bù B pending → cancel B hoàn tất → thả write bù: marker B lại xuất hiện dù RAM null/auth không recovering.

Bảo vệ ordering/commit theo owner cho mọi write/clear/cancel, thay vì vá thêm một write bù rồi nuốt lỗi. Thêm regression đúng chuỗi A pending → B → repair B pending → cancel B. Giữ X1 gốc bảo toàn B và future identity guard đã đúng. Test slot phải thực sự có callback B đang pending, đo duplicate/exchange/slot để biết finally A không giải phóng B; không chỉ tạo marker B rồi assert auth intent.

Đây là controlled I/O contract, không tuyên bố native-device ordering. Nếu queue đúng làm cancel/B phải chờ drain: launch futures, assert quyền đã thu hồi ngay và B chưa grant khi chưa cleanup, release barrier rồi await. Không await cancel đang chờ gate chỉ được release sau chính await đó; timeout harness không tự là product failure. Giữ expected hành vi và giải thích mọi đổi sequencing, không bỏ interleaving/negative assertions.

## 3. Kiểm thử và bằng chứng cuối

Reviewer artifacts giữ nguyên dưới `.dart_tool/c3-codex-review/` và `.dart_tool/c3-codex-r2/`; đây là ignored files, có thể thiếu ở máy khác. Nếu thiếu, tái tạo permanent regression từ chuỗi thao tác trong review, không coi thiếu artifact là blocker. Không sửa/xóa evidence reviewer cũ; harness mới đặt file riêng khi cần.

- 19 ca đã PASS: `original_c3_probe_test.dart`, `overlap_probe_test.dart`, `production_store_probe_test.dart` trong thư mục review đầu.
- Ca R2: `remaining_races_test.dart` và `production_cancel_variants_test.dart` trong `.dart_tool/c3-codex-r2/`, log `remaining-final.log` có6FAIL/1controlPASS; hai ca là confirmations, không phải root causes mới.
- Copy fixtures dùng SDK đã cài, HTTP synthetic, UUID/JWT có exp hợp lệ, SharedPreferences mock và SQLite temp. Không credentials thật/email/live calls. Permanent tests mới phải kiểm đúng authority/state/SDK side effect, giữ positive controls.

Chạy targeted và Full sau các thay đổi cuối:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/password_recovery_authority_test.dart','test/password_recovery_callback_race_test.dart','test/password_recovery_cleanup_test.dart','test/password_recovery_gate_test.dart','test/auth_navigation_test.dart') -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Chạy các reviewer probes hiện có với filter scope như review R2, hoặc bản harness điều chỉnh ordering đã giải thích. Không yêu cầu C4 R2/R6/R7 GREEN. Full phải thật sự đi qua analyzer, Flutter và Node trên candidate cuối; không lấy Node riêng hoặc targeted thay Full.

**Sau lần sửa cuối:** verify → xác nhận không đổi source → lấy hashes → viết report. Nếu còn sửa sau checks, verify lại phần cần thiết; report trỏ đúng bytes/log, không giữ con số/hash cũ. Không chỉ sửa báo cáo cho khớp khi source chưa qua kiểm chứng.

## 4. Phạm vi, báo cáo và điểm dừng

Sửa chính providers auth/recovery, marker store và permanent tests liên quan; UI/model/service/lifecycle chỉ khi trace trực tiếp của invariant yêu cầu, ghi lý do. Giữ stack, C1/C2, C3-F03/F04, saved trips/drafts và account guards. Không xóa dữ liệu SQLite của user để dọn marker SharedPreferences.

**C4 vẫn deferred:** double-submit trước write-ahead, TTL/revalidation, OTP/profile và live email. Không thêm dependency/framework, đổi SDK/native URL/permissions/schema, commit/push/merge/deploy/DB/email thật hoặc can thiệp/install/clear thiết bị owner. Giữ guard tối đa ba vòng sửa lỗi đang hiệu lực, ghi các vòng đã dùng; handoff/approval mới không tự reset budget. Không áp giới hạn file/tool calls cũ.

Tạo `docs/phase-3/COURSEWORK_C3_FIX_R2_ANTIGRAVITY_REPORT_20261025.md` theo **Changed / Why / Testing / Problems / Lesson Candidate**: bảng C3-F01/F02/F05 → regression/barrier/control → RED/GREEN/command/exit/log; status F03/F04 và 19 ca cũ; branch/base/diff/hashes thực; giải thích cho owner vì sao cùng user khác operation và vì sao write bù có thể stale. Ghi source/automated/device/live riêng, phần chưa chạy và vòng sửa lỗi đã dùng. Không tuyên bố lộ dữ liệu thật hoặc toàn recovery/app xong từ fixture.

**Dừng sau candidate C3 để Codex re-review. Không tự đánh dấu ACCEPT hoặc chuyển C4.**
