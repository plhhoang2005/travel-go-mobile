# C3 correction R2 — Codex independent re-review R3, 25/10/2026

**Verdict: REQUEST CHANGES, chưa chuyển C4.** Candidate lần này khớp hashes bàn giao, analyzer/Full/26 probes cũ đều PASS. C3-F05 CLOSED; F03/F04 giữ trạng thái đạt. C3-F01/F02 còn lỗi ownership trong chuỗi nhiều intent; hai probes mới FAIL và một control PASS. Lỗi session được xác nhận thêm bằng RecoveryIntentStore thật + SharedPreferences mock.

## 1. Changed — candidate đã kiểm và trạng thái findings

Actual branch `fix/ai-planning-stability`, HEAD base `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty source/tests/docs. Đối chiếu [review R2](C3_CODEX_REVIEW_R2_20261025.md), [handoff đã duyệt](COURSEWORK_C3_FIX_R2_ANTIGRAVITY_HANDOFF_20261025.md), [báo cáo Antigravity](COURSEWORK_C3_FIX_R2_ANTIGRAVITY_REPORT_20261025.md) và source thực. Không coi toàn bộ dirty C1/C2 là diff correction mới.

**8/8 hashes bàn giao khớp candidate**, gồm providers, store, ba regression suites, gate và auth navigation. Hai source providers hiện tại:

- AuthProvider SHA256 `3a11c6451850d224d8d1e08f6b22765a5203a612e5158723e2615f34bf730c89`.
- PasswordRecoveryProvider SHA256 `32973b640a4c22530e2675d50afcf64eac845965d5f50646eb20e5f5e80a07f7`.

Snapshot `.dart_tool/c3-codex-r3/source-snapshot.json` gồm 376 source/test/backend/tool/native/config files; toàn bộ giữ nguyên trong review. Codex chỉ review, tạo probes/logs ignored và cập nhật report/master/core checkpoint; không sửa app/permanent tests, không stage/commit/push/merge/deploy/DB/email/device changes. Superpowers không được invoke cho Codex review; Antigravity coding tiếp tục dùng theo chỉ thị owner.

| Finding | Kết luận R3 |
| --- | --- |
| C3-F01 | **PARTIALLY CLOSED**: sent→normal login B, same-user normal login, stale retry và các ca cũ PASS; old cancel vẫn phá **recovery mới** cùng subject |
| C3-F02 | **PARTIALLY CLOSED**: X1 và cancel B khi repair B pending PASS; khi có intent C mới hơn, write bù B + clear hậu kiểm vẫn làm mất marker C |
| C3-F03 | Giữ CLOSED ở mức source/automated đã kiểm; Full có permanent Guest/cleanup/lifecycle suites PASS |
| C3-F04 | Giữ CLOSED, error/retry marker write ban đầu PASS |
| C3-F05 | **CLOSED**: overrides/prefix đã sửa, assertion callback trước đó PASS trong Full; source khớp report, fresh Full exit0 |

### C3-F01 [P1] — Helper nhận intentId nhưng chưa dùng để bảo vệ recovery mới

**Source:** `lib/features/auth/providers/auth_provider.dart:107–145`, đặc biệt 117–141; `password_recovery_provider.dart:cancel` sau await clear, gọi helper và xóa RAM intent.

`performRecoverySignOut` bảo vệ khi `_currentUser != null`, nên normal login mới được giữ. Nhưng recovery mới cũng cố ý **không** cấp `_currentUser`. Khi hai recovery intents cùng user, `_currentUser == null` và SDK user ID khớp verifiedUserId cũ, helper vẫn signOut. Parameter `intentId` được nhận nhưng không được dùng trong body; helper chưa xác định operation/session nào còn thuộc cleanup cũ.

**Repro bằng public flows và controlled clear completion:**

1. Intent A ready; gọi cancel A, giữ completion clear A.
2. Tạo yêu cầu recovery mới B cho cùng tài khoản, xử lý callback B thành công. Assert SDK có user A, provider ready B, auth giữ intent B; `_currentUser` vẫn null đúng thiết kế recovery.
3. Thả clear A. Cancel A gọi helper rồi dọn RAM.

**Actual:** SDK user **null**, provider currentIntent **null**, marker B vẫn có và auth vẫn giữ quyền intent B. Expected phiên recovery B và state ready B được giữ. Đây là khác biệt giữa **normal login mới** và **recovery mới**; không nói các ca normal login từng FAIL vẫn đang lỗi.

Probe `production_new_recovery_test.dart` xác nhận lại bằng RecoveryIntentStore thật: `super.clear(expectedIntentId)` đã xóa marker A, chỉ chặn completion; B đã ready trước khi thả A. Kết quả vẫn FAIL. Control cùng flows nhưng cancel A hoàn tất trước khi bắt đầu B PASS.

**Cần sửa:** một ownership/ordering rule bảo vệ cả normal account và recovery operation mới, kiểm đúng operation sau await; helper nhận ID thì phải thực sự gắn quyền cleanup với ID/epoch/session tương ứng. Cancel cũ không được signOut hoặc xóa state của B. Giữ 0 PUT sau Hủy và các fixes normal-login đã đạt; không chỉ kiểm thêm user ID hoặc `_currentUser`.

### C3-F02 [P2] — Hậu kiểm sau write bù không ngăn phá dữ liệu intent mới hơn

**Source:** `password_recovery_provider.dart:374–382`.

Guard mới kiểm **sau** `store.write(targetIntent)`, rồi clear B nếu B đã hủy/superseded. Nó sửa được hồi sinh B khi không có successor, nhưng chưa ngăn stale write B ghi đè một marker mới hơn.

**Repro:** A ready-write pending → cancel A → request B → thả A để write bù B pending → cancel B → request C hoàn tất và assert marker C đã commit → thả write bù B. B ghi đè C; guard phát hiện stale rồi clear B.

**Actual:** marker **null**, trong khi RAM vẫn intent C và auth vẫn nhận intent C. Expected marker C được giữ. Chuỗi này kiểm chính contract “write/clear cũ không phá intent mới”, không mở thêm chức năng sản phẩm. Probe dùng controlled persistence seam như các ca đã duyệt; **không phải bằng chứng native storage ordering trên điện thoại**.

**Cần sửa:** bảo vệ quyền/ordering **trước hoặc tại commit**, xuyên mọi write/clear/cancel, thay giải pháp write bù rồi clear hậu kiểm. Không thêm write bù C từ operation cũ rồi lặp lại cùng race. Nếu serialization đúng khiến cancel/B/C phải chờ drain, điều chỉnh sequencing của test: launch futures, assert authority thu hồi ngay, thả I/O rồi await; không để harness await chính gate chưa thả và gọi timeout đó là bug. Giữ invariant/state assertions và các ca đã GREEN.

## 2. Why — phần đã đạt và nguyên nhân còn vòng vá

Các sửa lần này có tác dụng: helper bảo vệ normal login kể cả cùng user, verifiedUserId null không còn logout B, retry cleanup cũ không phá normal account, write bù được xóa khi B đã hủy và không có intent mới hơn. Candidate/verification cũng đã đồng nhất; không còn lỗi compile/hash drift như R2.

Tuy nhiên, bảo vệ normal user chưa phải bảo vệ recovery operation mới; cùng user ID vẫn có nhiều intent. Tương tự, phát hiện một write đã stale sau khi nó ghi đè storage không tự lấy lại được marker vừa mất. Hai findings là phần còn thiếu của **cùng ownership/ordering contract C3**, không phải yêu cầu thêm tính năng hoặc kiến trúc doanh nghiệp.

Ví dụ người dùng: hủy yêu cầu khôi phục thứ nhất, lập yêu cầu thứ hai và mở link mới trong lúc cleanup thứ nhất còn chờ. Link mới đã xác thực nhưng cleanup cũ vẫn làm form/SDK mất phiên. Nguyên tắc cần giữ là operation cũ không có quyền sửa phiên/state của operation mới, kể cả cùng tài khoản và chưa có normal login.

Không suy từ fixtures thành lộ dữ liệu thật; không cần xóa dữ liệu chuyến đi/SQLite. Giữ scope, stack và account guards hiện có. Chỉ thay điểm điều phối cần thiết cho invariant, không mở C4 hay refactor rộng.

## 3. Testing — reviewer chạy độc lập

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Full **exit0**. Logs `.dart_tool/travelgo-verification/20261025T060119650Z-21856/`, wrapper `.dart_tool/c3-codex-r3/full.log`.

| Check | Fresh result |
| --- | --- |
| Analyzer | No issues found, 6.9s, exit0 |
| Flutter Full | **1029/1029 PASS**, 2:00, exit0 |
| Node contracts | **91/91 PASS**, fail0/skipped0, exit0 |
| Original C3 reviewer probes | **19/19 PASS**, exit0 |
| R2 reviewer probes | **7/7 PASS**, exit0 |
| R3 ownership/persistence probes | **2 FAIL + 1 control PASS**, exit1 |
| R3 production-store session confirmation | **1 FAIL**, exit1; xác nhận cùng C3-F01, không phải root cause thứ ba |
| Hash consistency | 8/8 match author report; 376/376 snapshot files không đổi trong review |
| git diff --check | exit0; line-ending warnings |

Năm targeted suites mà author báo 116PASS đều thuộc Flutter Full đã chạy; reviewer không chạy lặp riêng targeted trong lượt này. Không dùng Full PASS để phủ nhận probe FAIL hoặc coi fixtures là device acceptance.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-review/original_c3_probe_test.dart .dart_tool/c3-codex-review/overlap_probe_test.dart .dart_tool/c3-codex-review/production_store_probe_test.dart --name 'CONTROL|R1 |R3 |R4 |R5 |R8 |R9 |R10 |C3X|C3P'
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-r2/remaining_races_test.dart .dart_tool/c3-codex-r2/production_cancel_variants_test.dart
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-r3/ownership_probe_test.dart
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-r3/production_new_recovery_test.dart
```

Logs trong `.dart_tool/c3-codex-r3/`: `prior19.log`, `prior7.log`, `ownership-probes.log`, `production-new-recovery.log`. Các reviewer artifacts cũ/expected giữ nguyên. Probes mới reuse synthetic fixture đã có; SDK đã cài + fake HTTP, UUID/JWT synthetic hợp lệ, không auth/email live. Marker C được assert trước release B; recovery B được assert ready/SDK đúng trước release cancel A; control tuần tự PASS. Không tính lặp hoặc confirmation thành findings mới.

Codex không build/install/hot reload, sửa app hoặc thao tác thiết bị. Device/iOS/live email NOT RUN. Superpowers usage của Antigravity là author-reported; reviewer xác nhận code/tests chứ không dùng việc gọi skill làm bằng chứng correctness.

## 4. Problems / tiếp theo

- **C3-F01/F02 còn mở một phần; C3-F03/F04/F05 CLOSED ở mức source/automated đã kiểm.** Không làm lại các phần đã đạt và không báo rằng 26 probes cũ đang FAIL.
- Antigravity cần sửa cùng ownership/ordering contract thay vì thêm các check đối phó từng ví dụ; dùng Superpowers theo chỉ thị owner, giữ scope/stack/dữ liệu đã duyệt. Đưa hai cases vào permanent regressions có positive controls và bằng chứng SDK/state/marker.
- Giữ guard tối đa ba vòng sửa lỗi đang hiệu lực; ghi chính xác vòng đã dùng, không tự reset hoặc mở budget khi đặt tên correction/review mới. Review này không cấp thêm quyền triển khai, live, native/dependency hoặc repair budget.
- C4 double-submit trước write-ahead, TTL/server revalidation, OTP/profile/live vẫn deferred. Không chuyển C4, commit/push/merge/deploy/SQL hoặc tự cài/clear thiết bị. C3 chưa ACCEPT; chưa chứng nhận toàn recovery/app.
- Reviewer tạo report này và cập nhật master/core checkpoint, không sửa source/permanent tests.

## 5. Lesson Candidate

Problem → Root cause → Rule: “normal login đã được bảo vệ nhưng recovery mới vẫn bị dọn” → “dùng trạng thái có user/subject thay cho operation ownership” → “mọi completion/cleanup phải chứng minh còn sở hữu đúng intent, không chỉ cùng danh tính”.

Problem → Root cause → Rule: “hậu kiểm phát hiện stale nhưng marker mới đã mất” → “kiểm sau write không bảo vệ commit” → “bảo vệ ordering/quyền ghi tại nơi mutation có hiệu lực; test cả cancel lẫn tạo successor trước khi thả I/O cũ”.
