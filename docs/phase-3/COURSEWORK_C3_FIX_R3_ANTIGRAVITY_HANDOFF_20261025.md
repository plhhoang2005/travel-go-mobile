# Prompt Antigravity — đóng ownership C3 sau review R3

Owner đã trả lời **“duyệt” sau review R3**: cho phép sửa phần còn mở **C3-F01/F02**. Giữ F03/F04/F05 và 26 reviewer probes đã PASS. C3 chưa ACCEPT; không mở C4. Không xin lại scope đã duyệt.

**Bắt buộc sử dụng Superpowers khi code** theo chỉ thị thường trực owner. Đọc và áp dụng skills phù hợp: using-superpowers, executing-plans, systematic-debugging, test-driven-development, verification-before-completion; nêu skill và mục đích. Nếu thiếu thì báo rõ, không giả đã dùng. Workflow skill không mở scope/quyền hoặc bắt duyệt lại cùng thiết kế.

## 1. Candidate và mục tiêu

Repo `D:/Travel-Go-Android/travel-go`; branch bàn giao `fix/ai-planning-stability`; HEAD base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty owner source/tests/docs. Xác minh status/HEAD và diff trước sửa, không reset/stash/clean hoặc rollback cả file. Hai provider hashes tại bàn giao vẫn khớp review R3:

- AuthProvider: `3a11c6451850d224d8d1e08f6b22765a5203a612e5158723e2615f34bf730c89`.
- PasswordRecoveryProvider: `32973b640a4c22530e2675d50afcf64eac845965d5f50646eb20e5f5e80a07f7`.

Đọc `AGENTS.md`, `.agent/rules.md`, `.agent/workflow.md`, [.agent/product-scope.md](../../.agent/product-scope.md), [review R3](C3_CODEX_REVIEW_R3_20261025.md), [handoff trước](COURSEWORK_C3_FIX_R2_ANTIGRAVITY_HANDOFF_20261025.md), [Core R2 C3/C4](../superpowers/plans/2026-10-24-coursework-core-r2.md).

Baseline reviewer: analyzer PASS, Flutter1029/1029, Node91/91, 26 probes cũ PASS, 8/8 hashes khớp; hai ownership/persistence probes mới FAIL, một control PASS và một production-store confirmation FAIL. Không gọi các ca cũ vẫn lỗi hoặc sửa lại F05 đã đóng.

**Mục tiêu chung:** mỗi mutation/completion/cleanup chỉ tác động intent/session/state mà operation đó còn sở hữu; operation cũ không có quyền ghi/xóa/signOut/state-reset operation mới, kể cả cùng user và chưa có normal login. Giải quyết bằng ownership và ordering tại nơi side effect có hiệu lực; không tiếp tục thêm điều kiện theo từng ví dụ hoặc write bù hậu kiểm.

## 2. C3-F01 — bảo vệ cả recovery mới, không chỉ normal account

Repro phải chuyển vào permanent regression:

1. A ready; cancel A, giữ clear completion.
2. Request recovery B cho **cùng tài khoản**, callback B thành công. Assert B ready, SDK có user, auth giữ B; `_currentUser == null` đúng vì đây là recovery, không phải normal login.
3. Release clear A: SDK và provider phải giữ B; A không signOut, clear RAM B hoặc finish nhầm authority B.

Helper hiện nhận `intentId` nhưng chưa dùng, chỉ nhìn `_currentUser` và verified user ID. Các điều kiện này bảo vệ normal login nhưng không phân biệt recovery intents cùng user.

Sửa tối thiểu trong điều phối auth/recovery hiện có:

- Gắn ownership operation/epoch cho quyền cleanup và state completion; dùng thực sự ở critical point, không chỉ truyền tham số.
- Thu hồi quyền mutation đồng bộ trước await như phần đã đạt. Dọn SDK qua ordering phù hợp với credential/account transitions và kiểm lại owner trước side effect; đồng thời bảo toàn SDK session được exchange muộn khi chưa có successor.
- Chặn stale completion khỏi reset `_currentIntent`, state hoặc auth flags của intent mới. Áp cùng rule cho cancel, retryCleanup và success cleanup; bảo vệ normal login và recovery mới, cùng/different user.
- Không giữ queue rồi await ngược một invalidator cần chính queue đó. Giữ Guest, error/retry và account gate đã đạt.

Có production-store confirmation: RecoveryIntentStore thật + SharedPreferences mock, clear A đã hoàn tất qua `super.clear`, chỉ giữ completion. B đã ready trước khi thả A; SDK/state B vẫn bị mất. Control cancel A xong rồi mới tạo B PASS.

## 3. C3-F02 — bảo vệ marker trước/tại commit

Repro phải chuyển vào permanent regression:

1. A ready-write pending → cancel A → request B.
2. Release A để write bù B pending → cancel B.
3. Request C hoàn tất, assert marker C đã commit và RAM/auth giữ C.
4. Release write bù B: marker C phải được giữ. Hiện B ghi đè C rồi clear B để lại null.

Không thêm write bù C hoặc xóa tùy ý marker. Đây là controlled I/O contract như các tests đã duyệt, không phải khẳng định native-device ordering.

- Đặt ownership/ordering cho toàn mutation write/clear, bao cả entry qua overridable/pausable store, để write cũ đang chờ không thể commit sau intent mới rồi phá dữ liệu mới.
- Xử lý các mutation theo quy tắc nhất quán; cancel phải revoke đồng bộ rồi drain/dọn đúng owner, không báo hoàn tất sai hoặc xóa marker khác.
- Hậu kiểm sau await vẫn cần để chặn state publication cũ, nhưng không dùng nó thay bảo vệ persistence commit.
- Giữ identity guard của in-flight slot; finally/state updates chỉ giải phóng operation của mình. Không mở lại đường dual-write/engine/map.

**Test sequencing:** nếu ordering đúng khiến cancel/B/C chờ drain, launch futures và assert quyền đã thu hồi ngay, assert successor chưa grant/commit trước khi an toàn, release gate rồi await. Không await một cancel đang chờ chính gate chỉ được release sau await đó. Giữ expected hành vi và negative/control assertions; giải thích mọi đổi harness, không bỏ interleaving hoặc gọi timeout harness là product failure.

## 4. Verification và bàn giao

Reviewer artifacts ignored, giữ nguyên evidence cũ:

- `.dart_tool/c3-codex-r3/ownership_probe_test.dart`: hai ca mới và control.
- `.dart_tool/c3-codex-r3/production_new_recovery_test.dart`: confirmation store thật.
- Logs `ownership-probes.log`, `production-new-recovery.log`; 26 probes cũ và commands xem review R3.

Nếu artifact thiếu trên máy khác, tái tạo từ repro vào permanent tests; không coi thiếu ignored file là blocker. Dùng SDK đã cài/fake HTTP, UUID/JWT synthetic hợp lệ, SharedPreferences mock/SQLite temp. Không sửa/xóa reviewer files để che kết quả; harness điều chỉnh đặt file riêng, nêu vì sao ordering mới vẫn kiểm đúng invariant.

Chạy regression có barriers trước sửa và ghi RED actual assertion/control. Sau sửa, chạy affected auth/recovery suites, toàn bộ 26 ca đã đạt, ca R3 và Full:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/password_recovery_authority_test.dart','test/password_recovery_callback_race_test.dart','test/password_recovery_cleanup_test.dart','test/password_recovery_gate_test.dart','test/auth_navigation_test.dart') -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Giữ assertions conditional-clear, Guest cleanup failure, signOut retry, same-user/different-user normal login, new recovery, 0 PUT sau Hủy và lifecycle handles. Không yêu cầu C4 R2/R6/R7 GREEN trong task này; không sửa double-submit/TTL/server revalidation/OTP/profile/live ngoài scope.

Sửa chủ yếu auth/recovery providers, marker store và permanent tests; UI/service/model/lifecycle chỉ khi trace trực tiếp cần và ghi lý do. Giữ stack/API phù hợp, không thêm dependency/framework, đổi native/SDK/schema hoặc xóa dữ liệu chuyến đi để dọn marker SharedPreferences.

Tạo `docs/phase-3/COURSEWORK_C3_FIX_R3_ANTIGRAVITY_REPORT_20261025.md` theo **Changed / Why / Testing / Problems / Lesson Candidate**. Nêu quy tắc ownership/ordering chung và điểm side effect được bảo vệ; bảng F01/F02 → test/barrier/control → RED/GREEN/exit/log; status F03/F04/F05 và 26 ca cũ; branch/base/diff/hashes cuối. Verify sau thay đổi cuối rồi lấy hashes/report; source đổi sau checks thì kiểm lại phần phù hợp. Phân biệt automated, production-store fixture và device/live, không tuyên bố lộ dữ liệu thật hay toàn app hoàn thiện.

Giữ guard tối đa ba vòng sửa lỗi đang hiệu lực, ghi chính xác các vòng đã dùng; duyệt sửa không tự reset hoặc mở rộng budget. Không giới hạn file/tool calls cũ. Không commit/push/merge/deploy/SQL/email thật, đọc/log credentials hoặc install/clear/can thiệp thiết bị owner. Không có runtime phù hợp thì ghi NOT RUN.

**Dừng sau candidate C3 để Codex re-review; không tự ACCEPT hoặc chuyển C4.**
