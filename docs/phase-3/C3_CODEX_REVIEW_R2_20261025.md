# C3 correction — Codex independent re-review R2, 25/10/2026

**Verdict: REQUEST CHANGES. C3 chưa đạt, chưa chuyển C4.** Có tiến bộ: toàn bộ 19 reviewer probes cũ PASS, gồm các ca từng FAIL. Tuy nhiên candidate hiện tại không qua analyzer, hai permanent suites không compile và một assertion callback FAIL. Probes bổ sung tiếp tục tái hiện cleanup muộn đăng xuất phiên mới và repair-write khôi phục marker đã hủy.

## 1. Changed — source thực tế và findings

Actual branch `fix/ai-planning-stability`, HEAD base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty source/tests/docs. So với snapshot review C3 R1, có **5** source/test files đổi: hai providers và ba permanent test files; RecoveryIntentStore giữ nguyên hash. Không coi các sửa dirty C1/C2 là diff correction mới.

Đối chiếu [review C3 R1](C3_CODEX_REVIEW_20261025.md), [handoff correction đã duyệt](COURSEWORK_C3_FIX_ANTIGRAVITY_HANDOFF_20261025.md), [báo cáo Antigravity](COURSEWORK_C3_FIX_ANTIGRAVITY_REPORT_20261025.md) với candidate thực. Codex không sửa app/permanent tests/native/dependency; chỉ đọc, kiểm thử và viết report/checkpoint cùng artifacts ignored. Superpowers không được invoke cho Codex review; Antigravity coding vẫn phải dùng theo chỉ thị owner.

| Finding R1 | Kết luận R2 |
| --- | --- |
| C3-F01 cancel/late cleanup | **PARTIALLY CLOSED**: 0 PUT sau Hủy và ready A → user B khác đã PASS; intent chưa verified, login mới cùng user và retry cleanup muộn vẫn đăng xuất phiên mới |
| C3-F02 marker/slot | **PARTIALLY CLOSED**: X1 cũ PASS nhờ ghi bù marker B, future-slot có identity guard; repair-write lại có thể hồi sinh marker B sau cancel B |
| C3-F03 Guest gate / signOut retry state | **CLOSED cho source và X4/X5 reviewer probes đã chạy**; X5 login=false, uncaught0; X4 giữ cleanupRequired và intent. Permanent lifecycle tests của candidate chưa compile, không gọi là whole-flow/device acceptance |
| C3-F04 lỗi write đầu tiên | **CLOSED**: X3 báo lỗi, thoát processing, retry dispatch đúng1 request |
| C3-F05 mới — verification/candidate | **OPEN**: analyzer errors, targeted compilation/assertion failures và ba hash không khớp report |

### C3-F01 [P1] — User ID chưa đủ xác định phiên mà cleanup được phép đăng xuất

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:596–600`; `retryCleanup:525–539`. `cancel` vẫn gọi signOut ngoài credential queue; `retryCleanup` cũng chưa có owner recheck sau await preflight read.

Bản mới chỉ tránh logout B khi A đã có verifiedUserId và B mang user ID khác. Ba ca còn lỗi:

1. **A ở phase sent**, verifiedUserId null: cancel A giữ clear pending → login B thành công và SDK user=B → thả clear A. Nhánh `verifiedUserId == null || ...` cho phép signOut B. Expected B, actual SDK user **null**.
2. **Đăng nhập lại cùng tài khoản**: ready A → cancel giữ clear pending → đăng nhập mới bằng mật khẩu cho cùng user A → thả clear. So sánh user ID vẫn khớp nhưng phiên đăng nhập mới không thuộc intent đã hủy; actual SDK user **null**, expected user A của login mới.
3. **Retry cleanup muộn**: cancel A clear fail → retry bắt đầu, giữ preflight store.read → login B cleanup thành công và SDK đã giữ B → trả read cũ → retry A signOut B trực tiếp. Actual SDK user **null**. Probe có readCalls barrier chứng minh đã vào đúng read trước login B.

**Xác nhận thêm bằng store thật:** hai ca đầu được chạy lại qua RecoveryIntentStore + SharedPreferences mock, chỉ giữ completion sau `super.clear(expectedIntentId)` đã thực sự xóa marker. Cả hai FAIL; không phải lỗi conditional clear giả hoặc ordering native được suy đoán. B/new A đã được assert tồn tại trong SDK trước khi thả cleanup cũ. Các HTTP responses đều synthetic qua installed SDK.

**Cần sửa:** ownership theo operation/intent và phiên/account transition, không dùng user ID hoặc null như quyền signOut bất kỳ. Cancel/retry/success cleanup phải phối hợp ordering với credential queue, recheck ownership sau await và không hoàn tất intent khác. Giữ yêu cầu revoke đồng bộ/0 PUT đã đạt. Chỉ thêm một if null khác sẽ không giải quyết ca cùng user hoặc stale retry.

### C3-F02 [P2] — Ghi bù marker B vẫn là mutation cũ có thể hồi sinh B sau Hủy

**Source:** `password_recovery_provider.dart:364–368`.

X1 cũ đã PASS: A write muộn xong thì ghi lại `_currentIntent` B. Nhưng write bù chưa gắn owner/commit guard và lỗi bị nuốt. Probe mới giữ A ready-write → cancel A → request B hoàn tất → thả A để bắt đầu write bù B, giữ write bù → cancel B hoàn tất (auth không recovering, provider intent null) → thả write bù. **Marker B xuất hiện lại**, expected null. Completion A vừa phục hồi một intent đã bị hủy.

Đây vẫn là controlled persistence seam theo contract C3, không phải native-device ordering proof. Ca control ready A → user B khác và X1 nguyên bản đều PASS; không báo lại chúng như failure. Phần identity guard future-slot là cải thiện đúng. Test permanent có tên `slot_callback_A_finally_does_not_reset_in_flight_slot_of_B` hiện tạo marker/auth intent B nhưng không khởi chạy callback B và không đo slot B, nên tên rộng hơn coverage.

**Cần sửa:** bảo vệ ordering/commit của marker mutations xuyên write/clear/cancel, thay vì để operation cũ ghi bù state có thể đã stale. Nếu queue đúng buộc B hoặc cancel chờ drain, test phải launch futures, xác nhận authority thu hồi ngay, release barrier rồi await; không giữ thứ tự await gây deadlock giả và không bỏ negative assertions. Không chữa bằng xóa tùy ý marker của user/intent khác.

### C3-F05 [P1] — Candidate không đạt verification; report PASS thuộc hashes khác

**Analyzer hiện tại: 3 errors + 1 info, exit1:**

- `test/password_recovery_authority_test.dart:60`: override `clear()` thiếu optional positional `expectedIntentId` của base `clear([String?])`.
- `test/password_recovery_cleanup_test.dart:58`: cùng lỗi override.
- `test/password_recovery_cleanup_test.dart:654`: gọi `local_fixtures.runWithStore` nhưng import dùng `localFixtures` ở dòng17. Prefix hiện tại cũng bị lint library_prefixes.

Hai override còn gọi `super.clear()` không forward expected ID; khi sửa chữ ký cần giữ conditional-clear semantics của production, không chỉ ép compile. Reviewer không sửa các tests này để tiếp tục báo PASS.

Lượt chạy trực tiếp năm targeted suites kết thúc **77 PASS + 1 assertion FAIL + 2 load/compile FAIL**, exit1. Ca assertion fail: `password_recovery_callback_race_test.dart`, `F01_F02_stale_mutation_A_never_overwrites_or_clears_intent_B`, dòng332 `provider.isReady`: expected true, actual false. Phải trace bootstrap/fixture và guard trên source hiện tại; không đổi expected hoặc bỏ test chỉ để xanh, cũng chưa gọi riêng assertion này là exploit/lỗi production đã chứng minh.

Ba file không khớp SHA256 report author:

| File | Report author | Candidate reviewer |
| --- | --- | --- |
| password_recovery_provider.dart | `3f9ae9657ddd4df4e850d86a693e8ce4e32fb968bbab0b9bf7089dd81a13d920` | `8cc099be29dd71ec8c12195b69467dce2c91a42b57def923874680fc51a8b12a` |
| password_recovery_authority_test.dart | `fcd61babd9c01687ec613c94ea9aa1745e3d95430ad951c333f345d7109fc59c` | `874c39d3c2c353b996a7857753335ed957435d436b240d6ab5e7137ef0d9cea1` |
| password_recovery_cleanup_test.dart | `c40fe479cb6aea92635a5e9c395e92a18bdda871acefc244906513678db855b3` | `3df0786722b3f2aeb5998b5263a2c4411a2e0e44e0571cee90db6e41726c8612` |

AuthProvider (`e677135b411b0bb9fae67d05430134e3081c6531edc2f0560b56ead12c538f2f`), store (`50f69dc05a38c3cc297ef69ee8ef907d1f7825605afd9c2e61cbe60b5b36a725`) và callback test (`e22a687cc1d3dd7655651db0eb96355bfc2d9c815a992454d60fe2e071864a6d`) khớp report. Snapshot **376 files không đổi trong reviewer run**, nên không phải reviewer sửa source giữa chừng. Không suy đoán ai/vì sao có hash drift. Report nói có guard `if (!isReady)` trong submit nhưng candidate hiện tại cũng không có guard đó; 0 PUT probe đạt nhờ auth authority mới.

**Cần sửa:** ổn định candidate, sửa compile/trace assertion, chạy fresh checks sau thay đổi cuối rồi mới lấy hashes và viết báo cáo. Báo cáo 1023PASS không phải evidence cho candidate hiện tại. Không khôi phục cả file từ report/HEAD và làm mất dirty owner work.

## 2. Why — ý nghĩa đối với luồng người dùng

Ví dụ điển hình còn lỗi: người dùng bấm Hủy khi email khôi phục đang ở phase sent, rồi đăng nhập B; vì intent chưa verified, code coi null là quyền dọn session hiện tại và logout B. Hoặc đăng nhập lại cùng tài khoản thì user ID vẫn giống, dù đây là phiên mới. Vì vậy “cùng user” không đồng nghĩa “operation cũ còn sở hữu phiên này”.

Phần đã sửa đúng gồm revoke quyền mutation ở AuthProvider, chặn Guest vượt cleanup, giữ retry state khi signOut lỗi và xử lý storage failure trước beginRecovery. Không yêu cầu viết lại các fixes đó. Phần còn thiếu là áp cùng ownership/ordering cho mọi cleanup và persistence continuation, thay vì sửa riêng các chuỗi thao tác từng được test.

Không khẳng định có dữ liệu thật bị lộ hoặc phải xóa dữ liệu SQLite. Evidence là SDK session, provider state, marker và assertions trong controlled fixtures. Recovery marker thuộc SharedPreferences; chuyến đi/draft/account guards phải được giữ.

## 3. Testing — commands, kết quả và giới hạn

| Check reviewer chạy | Kết quả |
| --- | --- |
| Full helper | **exit1 tại analyzer**, 3 errors + 1 info, 7.3s; Flutter Full và Node bước Full **NOT RUN** vì helper fail-fast |
| Năm targeted suites | **77 PASS / 1 assertion FAIL / 2 load FAIL**, exit1, 22s |
| Node chạy độc lập Mode Ai | **91/91 PASS**, fail0/skipped0, exit0 |
| Original reviewer probes + X1–X6/control + P1/P2 | **19/19 PASS**, exit0, assertions giữ nguyên |
| New variants + actual-store confirmation | **6 FAIL / 1 control PASS**, exit1; gồm hai confirmations của cùng lỗi, không phải sáu root causes mới |
| Source consistency | **376/376 files không đổi** trong review; chỉ artifacts ignored/docs được reviewer tạo |
| git diff --check | exit0, line-ending warnings |

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Ai
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=2 --reporter=expanded test/password_recovery_authority_test.dart test/password_recovery_callback_race_test.dart test/password_recovery_cleanup_test.dart test/password_recovery_gate_test.dart test/auth_navigation_test.dart
```

Full analyzer log `.dart_tool/travelgo-verification/20261025T044740586Z-36320/analyze.log`, wrapper `.dart_tool/c3-codex-r2/full.log`; targeted `.dart_tool/c3-codex-r2/targeted.log`; Node wrapper `node.log`, suite log `.dart_tool/travelgo-verification/20261025T045141807Z-16852/node-contracts.log`.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-review/original_c3_probe_test.dart .dart_tool/c3-codex-review/overlap_probe_test.dart .dart_tool/c3-codex-review/production_store_probe_test.dart --name 'CONTROL|R1 |R3 |R4 |R5 |R8 |R9 |R10 |C3X|C3P'
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-r2/remaining_races_test.dart .dart_tool/c3-codex-r2/production_cancel_variants_test.dart
```

Logs `.dart_tool/c3-codex-r2/prior-probes.log` (19PASS), `remaining-final.log` (6FAIL/1PASS). New fixture copied to `fixture.dart`, bổ sung loginOwner và readCalls để kiểm cùng-user và entry barrier; không sửa reviewer artifacts cũ/permanent tests. `remaining-races.log` là lượt đầu trước khi củng cố read-entry signal, không cộng lặp vào counts. Snapshot `source-snapshot.json` cùng thư mục xác định candidate.

Không build/install/hot reload/device/live/email/AI/DB mutation, không đọc/log token thật. SDK fixtures dùng UUID/JWT synthetic hợp lệ và fake HTTP. Notices trusted-role unavailable không thay proof: new SDK user đã được assert đúng trước khi release cleanup. Không coi automated tests là native acceptance.

## 4. Problems / việc cần làm tiếp

- **C3-F01/F02 còn mở một phần; C3-F05 mới OPEN.** Sửa trong cùng scope C3, giữ F03/F04 và 19 probes đã GREEN. Antigravity tiếp tục dùng Superpowers theo chỉ thị owner.
- Ưu tiên candidate/compile integrity, sau đó unified cleanup ownership và marker ordering; không chỉ vá verifiedUserId null hoặc riêng hai test mới rồi bỏ stale retry/success cleanup.
- Bổ sung permanent tests cho sent/unverified → B, login lại cùng user, stale retry, cancel B lúc repair B pending; kiểm state/SDK/marker trước và sau barriers. Tách fixture/setup failure với behavior failure, giữ positive controls và conditional-clear semantics.
- Chạy fresh Full sau source/tests cuối; hashes/report phải trỏ đúng bytes đã verify. Giữ tối đa ba vòng sửa lỗi hiện hành, ghi các vòng đã dùng, không tự reset budget khi đổi handoff/review. Reviewer không cấp thêm quyền hoặc repair budget.
- C4 R2/R6/R7, OTP/profile/live vẫn deferred; chưa bắt đầu C4. Không sửa schema/SDK/native/dependency, commit/push/merge/deploy hoặc can thiệp thiết bị từ review này. Mọi dirty owner work giữ nguyên.

Reviewer chỉ tạo report này và cập nhật checkpoint master/core; app không đổi trong lượt review. Device/iOS/live NOT RUN; C3 chưa ACCEPT.

## 5. Lesson Candidate

Problem → Root cause → Rule: “kiểm user ID nhưng vẫn logout phiên đăng nhập mới” → “subject identity bị dùng thay operation/session ownership; null được coi là quyền bất kỳ” → “cleanup phải thuộc đúng intent/account transition và được ordering với mutations, kể cả khi đăng nhập lại cùng user”.

Problem → Root cause → Rule: “report Full PASS nhưng source hiện tại không compile” → “hashes và checks không cùng candidate cuối” → “sau thay đổi cuối, verify rồi hash/report; review phải xác minh bytes thay vì tin số test trong bàn giao”.
