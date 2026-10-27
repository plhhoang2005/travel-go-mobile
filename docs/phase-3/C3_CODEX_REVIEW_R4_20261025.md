# C3 correction R3 — Codex independent re-review R4, 25/10/2026

**Verdict: REQUEST CHANGES, chưa chuyển C4.** F01 đạt các ca ownership đã kiểm; 30 probes cũ và Full đều PASS. F02 vẫn chưa đóng vì thêm write bù C chưa có ordering tại commit. F03 bị regression: cancel xóa owner trong RAM, clear marker thành công nhưng SDK logout fail thì retry không còn intent để dọn tiếp. Hai probes mới FAIL, một control PASS; regression retry được xác nhận thêm bằng RecoveryIntentStore production + SharedPreferences mock.

## 1. Changed — candidate và findings

Actual branch `fix/ai-planning-stability`, HEAD base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty owner work. So với snapshot review R3, chỉ bốn source/test files đổi: hai providers và tests authority/callback-race. Store/cleanup test giữ nguyên. Đối chiếu [review R3](C3_CODEX_REVIEW_R3_20261025.md), [handoff đã duyệt](COURSEWORK_C3_FIX_R3_ANTIGRAVITY_HANDOFF_20261025.md), [báo cáo author](COURSEWORK_C3_FIX_R3_ANTIGRAVITY_REPORT_20261025.md) và source thực.

**6/6 candidate hashes khớp report.** AuthProvider `253268b0d71f3dd6bd50e213c1d1ae127523d63d0f358cefce19665a4f54eb33`; PasswordRecoveryProvider `a31b07ec5fb36b07786a2cdc522a6515324633b810b505624dcc9059c27a91f3`. Snapshot `.dart_tool/c3-codex-r4/source-snapshot.json`: 376 source/test/backend/tool/config files không đổi trong review.

| Finding | Trạng thái R4 |
| --- | --- |
| C3-F01 cleanup phá successor/session mới | **CLOSED ở mức source/automated đã kiểm**: normal login, same-user login, newer recovery, retry và production-store confirmations trong 30 probes PASS |
| C3-F02 marker ordering | **OPEN**: case R3 giữ C đã PASS, nhưng write phục hồi C mới thêm có thể hồi sinh C sau cancel C |
| C3-F03 cleanup error/retry | **REOPENED — regression ở cancel**: clear marker thành công + logout500 → cleanupRequired nhưng owner RAM/storage đều null, retry no-op |
| C3-F04 first write failure | Giữ CLOSED, probes và Full PASS |
| C3-F05 candidate/verification | Giữ CLOSED, hash match/analyzer/Full PASS |

### C3-F02 [P2] — Write phục hồi C lặp lại race của write phục hồi B

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:383–386`.

Candidate sửa case R3 bằng cách ghi lại C sau khi write bù B stale được xóa. Nhưng lệnh `await store.write(_currentIntent!)` mới lại không có ownership/ordering bảo vệ commit và lỗi bị nuốt.

**Repro có barrier:** A ready-write pending → cancel A → request B → repair B pending → cancel B → request C hoàn tất → release repair B để bắt đầu restore C, giữ restore C pending → cancel C hoàn tất (provider intent null, auth không recovering) → release restore C.

**Actual:** marker C xuất hiện lại, trong khi auth recovering=false và provider idle. Expected marker null sau khi tất cả operations kết thúc. Probe chỉ thêm Hủy tại chính await write C mới đưa vào; đây là cùng cancellation/persistence contract, không phải tính năng mới hoặc native-device ordering proof.

[Handoff R3](COURSEWORK_C3_FIX_R3_ANTIGRAVITY_HANDOFF_20261025.md) đã ghi rõ **“Không thêm write bù C hoặc xóa tùy ý marker”** và yêu cầu ordering cho toàn mutation tại commit. Candidate đang thêm đúng write bù C, nên chưa giải quyết nguyên nhân dù case R3 cụ thể PASS.

**Cần sửa:** dùng ownership/ordering bao toàn mutation write/clear/cancel, không chữa bằng thêm write bù D hoặc thêm hậu kiểm ở từng tầng. Revoke phải đồng bộ; operation stale không được commit sau successor hoặc sau cancel của chính target. Nếu queue đúng cần drain, điều chỉnh test sequencing bằng launch futures → assert authority đã thu hồi → release I/O → await; không để test tự deadlock. Không bỏ negative assertions hoặc nới conditional-clear semantics.

### C3-F03 [P2] — Cancel mất cleanup owner khi marker đã xóa nhưng logout lỗi

**Source:** `password_recovery_provider.dart:629–643,646–677`; `retryCleanup:549–551`.

Để tránh cancel A xóa RAM B mới, candidate đặt `_currentIntent = null` ngay đầu cancel. Intent A chỉ còn trong biến local của cancel. Nếu clear thành công nhưng SDK signOut HTTP500, cancel giữ state cleanupRequired nhưng không giữ lại owner cho lần retry. Marker cũng đã bị clear nên retry lấy `_currentIntent ?? await store.read()` ra null và return.

**Repro:** ready A → fake logout500 → cancel → assert marker null và cleanupRequired → phục hồi logout → gọi retryCleanup. **Actual sau retry:** intent null, state vẫn cleanupRequired, auth.isRecovering=true. Expected cleanup kết thúc, thoát trạng thái retry; 0 password PUT.

Confirmation dùng **RecoveryIntentStore production không override** với SharedPreferences mock và installed SDK qua fake HTTP, kết quả cùng FAIL. SDK logout lỗi có thể đã xóa local session trước khi trả lỗi; điều đó không tự hoàn tất auth/provider cleanup và không cung cấp owner cho retry.

**Cần sửa:** tách quyền mutation/active intent đã revoke khỏi thông tin owner cần để cleanup/retry. Chỉ bỏ cleanup owner khi toàn operation hoàn tất hoặc được supersede an toàn; giữ failure/retry UI thật, không cấp account vượt cleanup. Không khôi phục RAM A đè B đang active để chữa mất owner. Bao phủ clear fail, signOut fail, cả hai fail, retry success và successor, giữ F01 mới đạt.

Đây là regression trong **C3 error/cleanup**, không thuộc C4 double-submit/TTL/revalidation. Probe X4 cũ kiểm signOut lỗi qua normal login cleanup; nhánh cancel hiện tại là nhánh khác, nên X4 cũ vẫn PASS không phủ nhận failure mới.

## 2. Why — luồng và ý nghĩa cho owner

F01 đã cải thiện đúng: helper thực sự kiểm intent đang active khác với intent cleanup; cancel/retry không reset state của successor. Các ca normal login và recovery mới cùng user hiện PASS. Không yêu cầu làm lại các fixes đó.

Hai phần còn lại cần cùng nguyên tắc ownership rõ ràng: **thu hồi quyền sửa không đồng nghĩa quên thông tin cần để dọn lỗi**; **ghi xong rồi sửa bù không ngăn commit cũ phá state mới**. Ví dụ người dùng Hủy, mất mạng lúc logout rồi bấm “Thử hoàn tất dọn dẹp phiên”: ứng dụng phải nhớ cần dọn intent nào dù marker đã xóa, thay vì nút không làm gì.

Không chứng minh có lộ dữ liệu thật hoặc cần xóa SQLite/trips của user. Marker recovery nằm ở SharedPreferences; các fixtures kiểm SDK session/state/marker. Giữ stack, dữ liệu, account guards và phạm vi đồ án; không thêm framework/dependency hoặc mở C4.

## 3. Testing — fresh reviewer evidence

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Full **exit0**. Logs `.dart_tool/travelgo-verification/20261025T063346606Z-14080/`; wrapper `.dart_tool/c3-codex-r4/full.log`.

| Check | Fresh result |
| --- | --- |
| Analyzer | No issues found, 4.5s, exit0 |
| Flutter Full | **1032/1032 PASS**, 1:57, exit0 |
| Node contracts | **91/91 PASS**, fail0/skipped0, exit0 |
| Original reviewer group | **19/19 PASS**, exit0 |
| R2 reviewer group | **7/7 PASS**, exit0 |
| R3 reviewer group + confirmation | **4/4 PASS**, exit0 |
| R4 persistence/cancel-retry + control | **2 FAIL / 1 control PASS**, exit1 |
| R4 production-store retry confirmation | **1 FAIL**, exit1; xác nhận lại F03, không phải root cause thứ ba |
| Candidate consistency | 6/6 hashes match author; 376/376 snapshot files không đổi |
| git diff --check | exit0; line-ending warnings |

Ba permanent suites author báo 49PASS nằm trong Full đã chạy; không chạy lặp targeted chỉ để lặp số đếm. 30 reviewer probes giữ assertions, không sửa permanent tests/source.

Lượt đầu reviewer chạy các probe groups song song với Full gặp **sqlite3.dll đang bị khóa** ở native-assets preparation, trước khi test assertion chạy. Đây là xung đột môi trường reviewer, không phải product failure. Không xóa DLL/clear build/kill tiến trình owner. Sau khi thu Full exit0, reviewer chạy lại ba groups **tuần tự**, kết quả 30/30 PASS. Logs lỗi ban đầu `prior19.log`, `prior7.log`, `prior4.log` được giữ; kết quả cuối `prior19-final.log`, `prior7-final.log`, `prior4-final.log` là evidence được dùng.

Commands các nhóm cũ giữ như [review R3](C3_CODEX_REVIEW_R3_20261025.md). Probes mới:

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-r4/remaining_invariants_test.dart
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-r4/production_cancel_retry_test.dart
```

Logs `.dart_tool/c3-codex-r4/remaining-invariants.log`, `production-cancel-retry.log`; original group logs và snapshot cùng thư mục. Fixtures synthetic reuse SDK/fake HTTP đã có, UUID/JWT hợp lệ; không network auth/email thật hoặc đọc/log token thật. Confirmation retry dùng base store production + SharedPreferences mock; write C race dùng controlled persistence seam. Control successful cancel PASS. Không cộng confirmation/lượt chạy lặp thành findings mới.

Codex chỉ tạo artifacts ignored, report và cập nhật hai plan checkpoints. Không sửa app/permanent tests, build/install/hot reload, deploy/SQL hoặc can thiệp thiết bị. Device/iOS/live NOT RUN; không coi Full PASS là whole recovery acceptance.

## 4. Problems / bước tiếp theo

- **C3 chưa ACCEPT.** Chỉ sửa F02 và regression F03; giữ F01/F04/F05 cùng 30 probes đã đạt. Antigravity coding dùng Superpowers theo chỉ thị owner.
- F02 cần ordering tại commit như handoff đã duyệt, không thêm write phục hồi tầng tiếp theo. F03 cần retained cleanup ownership độc lập với mutation authority và active successor.
- Bổ sung permanent regressions cho cancel trong restore C và cancel→marker removed→logout fail→retry; cả success controls và successor phải giữ đúng. Chạy fresh checks sau thay đổi cuối rồi lấy hashes/report.
- Giữ guard tối đa ba vòng sửa lỗi đang hiệu lực, ghi chính xác vòng đã dùng; review/handoff mới không tự reset budget hoặc cấp thêm vòng. Báo cáo author chưa có số vòng cụ thể, không suy ra còn budget từ nhãn correction.
- C4 double-submit, TTL/server revalidation, OTP/profile/live vẫn deferred; không commit/push/merge, đổi SDK/native/dependency/schema hoặc can thiệp thiết bị từ review này. C3 source vẫn dirty/chưa commit.

## 5. Lesson Candidate

Problem → Root cause → Rule: “UI hiện retry nhưng retry không làm gì” → “active intent bị xóa cùng thông tin cleanup owner trước khi biết kết quả SDK” → “revoke mutation authority ngay, giữ owner cleanup đến khi success hoặc superseded an toàn”.

Problem → Root cause → Rule: “case cũ PASS nhờ write bù, cùng lỗi xuất hiện tại write bù mới” → “bảo vệ hậu kiểm từng mutation thay vì ordering/commit chung” → “mọi mutation mới phải tuân cùng ownership tại critical point; không kéo dài chuỗi compensation”.
