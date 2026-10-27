# C3 — Codex independent review, 25/10/2026

**Verdict: REQUEST CHANGES. Chưa chấp nhận C3, chưa chuyển C4.** Các ca đơn lẻ R1/R3/R4/R5/R8/R9/R10 đã PASS, nhưng chưa đóng toàn bộ invariant ownership/cancel/cleanup. Reviewer tái hiện sáu ca lỗi bổ sung; hai lỗi quan trọng được xác nhận thêm bằng RecoveryIntentStore thật với SharedPreferences mock và SDK đã cài qua fake HTTP. Không sửa app trong review này.

## 1. Changed — candidate và findings

Actual branch `fix/ai-planning-stability`; base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty working tree, chưa commit. So với source snapshot C2 đã review, chỉ sáu source/test files khác: ba file recovery/auth/store và ba test authority/callback-race/cleanup. Các sửa C1/C2 còn nguyên; không dùng toàn bộ dirty diff của repo làm diff C3.

Đối chiếu [handoff C3](COURSEWORK_C3_ANTIGRAVITY_HANDOFF_20261025.md), [báo cáo Antigravity](COURSEWORK_C3_ANTIGRAVITY_REPORT_20261025.md), [Core review R1](CORE_REVIEW_R1_CODEX_REVIEW_20261024.md) và source thực. Antigravity là implementer; Codex chỉ review, chạy tests và tạo probes/logs ignored. Codex không invoke Superpowers cho review này; chỉ thị thường trực dùng Superpowers áp cho Antigravity coding, vẫn áp cho lượt sửa tiếp.

### C3-F01 [P1] — Hủy chưa thu hồi quyền SDK ngay và cleanup A có thể đăng xuất B

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:542–585`, đặc biệt local `_generation++`, await clear ở 553 và direct signOut ở 565. Liên quan `auth_provider.dart:runRecoveryMutation` và credential queue.

`cancel()` chỉ đổi generation riêng của recovery provider. Trong lúc chờ clear marker, AuthProvider vẫn nhận intent A là current; form cũng còn state ready, chưa notify một trạng thái chặn submit. Một submit sau khi đã gọi Hủy vẫn qua `runRecoveryMutation` và gửi PUT mật khẩu. Đây là cancellation authority của **C3**, khác R2 double-submit của C4.

Ngoài ra, direct signOut của cancel chạy ngoài credential queue và không kiểm owner sau await. Nếu login B hoàn tất qua một cleanup khác trong lúc clear A đang chờ, continuation của cancel A gọi signOut lên **session B hiện tại**.

**Reviewer evidence:**

- X6: cancel A → giữ clear pending → submit → actual PUT **1**, expected **0**.
- X2: giữ clear của cancel A → login B thành công, SDK user đúng B → thả clear A → SDK user **null**, expected B.
- P1/P2 xác nhận lại với **RecoveryIntentStore thật**: `super.clear(expectedIntentId)` đã hoàn tất xóa SharedPreferences rồi chỉ giữ completion của clear đầu. Không giả định xóa marker sai hoặc bỏ conditional check. SDK B vẫn bị signOut; submit sau Hủy vẫn PUT1.

**Cần sửa:** thu hồi authority dùng chung đồng bộ trước await đầu, chặn mutation từ intent đã hủy; cancellation/cleanup phải có owner và ordering chung với account transitions/credential queue. Không chỉ disable nút UI hoặc thêm check sau khi PUT đã dispatch. Cleanup A không được tác động session B. Giữ quyền retry cleanup khi thất bại; không gọi invalidator enqueue ngược rồi tự chờ gây deadlock.

### C3-F02 [P2] — Pending write A vẫn có thể làm mất marker B trong contract I/O đã yêu cầu

**Source:** `password_recovery_provider.dart:345–350`, các store.write khác và `recovery_intent_store.dart:write/clear`. Chưa có cơ chế tuần tự hóa marker mutations theo owner; `finally` callback ở 317–321 vẫn giải phóng slot vô điều kiện.

X1 giữ ready-write A trước commit → cancel A → requestEmail B hoàn tất và xác nhận marker B đã có → cho write A tiếp tục. A ghi đè marker B rồi nhánh stale gọi clear(expected A), lúc này marker đang là A nên xóa thành null. Conditional clear chỉ bảo vệ khi dữ liệu hiện tại vẫn là B; không ngăn stale write ghi A trước đó.

**Actual X1:** provider giữ intent B nhưng store marker **null**, expected marker B. Đây là controlled storage seam giữ write trước persistence, cùng loại cut point `PausableRecoveryIntentStore.write` trong permanent authority tests; **không phải tái hiện thứ tự native storage trên điện thoại**. Review chỉ kết luận contract I/O/ownership được giao chưa đạt. Không suy ra mọi native backend nhất thiết hoàn tất writes theo thứ tự này.

Permanent test `F01_F02_stale_mutation_A_never_overwrites_or_clears_intent_B` hiện tạo B xong mới gọi retry A, không có write/clear A đang pending; nó kiểm một trường hợp khác và vẫn hữu ích, nhưng không chứng minh contract chồng lấn. Test R1 có pending write nhưng chưa tạo B.

**Cần sửa:** bảo vệ ordering/commit của marker theo owner xuyên write/clear, không chỉ kiểm sau write và cố clear. Slot/finally chỉ giải phóng operation sở hữu slot; thêm regression chồng lấn A → B ở cut point đã quy định. Không xóa marker B hoặc nới schema để xanh.

### C3-F03 [P1] — Cleanup gate mất qua Guest; signOut failure còn làm mất trạng thái retry

**Source:** `auth_provider.dart:104–119,124–154,435–444`; `password_recovery_provider.dart:37–64,501–539`.

**Nhánh Guest:** `continueAsGuest()` dùng `_handleRecoveryCancellation`, xóa `_isRecovering/currentRecoveryIntentId` trước cleanup rồi chạy invalidators unawaited. Invalidator mới ném lỗi khi clear thất bại. Sau Guest, provider vẫn cleanupRequired và marker A còn, nhưng login B thấy hai cờ auth đã xóa nên **bỏ qua `_drainAndCleanupRecovery`**.

X5 dùng marker clear thất bại: actual login **true**, expected false; marker vẫn A; provider cleanupRequired true. Zone kiểm thử còn ghi nhận **1 uncaught async error** từ invalidator. Guest phải khả dụng, nhưng không được xóa trách nhiệm cleanup cho lần account grant tiếp theo. Đây là test AuthProvider + SDK fixture không gắn lifecycle; không báo đã quan sát cấp handle production hoặc lộ dữ liệu thật từ ca này. Source gate đầu login là chung cho cả nhánh có/không có lifecycle, còn R10 cũ chỉ kiểm login trực tiếp chưa qua Guest.

**Nhánh signOut failure:** `_drainAndCleanupRecovery` gọi invalidator trước, invalidator clear thành công và chuyển provider idle/currentIntent null. SDK signOut sau đó fail thì AuthProvider còn recovering và login bị chặn, nhưng provider đã mất owner lẫn cleanupRequired. Gate UI dựa provider state nên không có màn retry tương ứng; retryCleanup không có intent để làm tiếp.

X4 fake logout HTTP500: actual `state=idle`, `currentIntent=null`, `authRecovering=true`, expected trạng thái cleanup có thể retry. SDK gotrue **2.27.2** thực sự dùng trong repo được đọc tại cache: signOut xóa local session rồi mới await logout API; lỗi HTTP không tự khôi phục cleanup UI của app.

**Cần sửa:** biểu diễn cleanup pending/failed độc lập với quyền ready và lựa chọn Guest; mọi đường cấp account phải kiểm/await kết quả cleanup có owner, kể cả sau Guest. Provider chỉ bỏ owner/retry khi **toàn bộ** cleanup thành công. Thu lỗi invalidator về state/kết quả, không để unhandled hoặc nuốt lỗi để cấp quyền. Bổ sung control Guest→cleanup success→login và ca failure với lifecycle/SQLite như R10.

### C3-F04 [P2] — Lỗi ghi marker đầu tiên bị bỏ qua, form kẹt sending

**Source:** `password_recovery_provider.dart:179–194,217–226`, đặc biệt catch guard ở 223.

`requestEmail` đặt state sending rồi ghi marker trước `auth.beginRecovery`. Nếu write đầu tiên ném lỗi, AuthProvider chưa biết ID mới; catch thấy `!isCurrentRecoveryIntent` và return luôn dù operation chưa hủy. State không trở về error, không có thông báo, lần thử sau bị early-return vì vẫn sending.

**Actual X3:** `isProcessing=true`, `errorMessage=null`, recoverCalls sau khi storage phục hồi và gọi lại **0**. Expected kết thúc loading, báo lỗi, cho thử lại và không gửi email trong lần persistence thất bại.

**Cần sửa:** phân biệt authority trước/sau beginRecovery; dùng owner/generation đã claim cho operation từ trước persistence. Lỗi thực của operation còn current phải được thông báo, trong khi completion của operation đã hủy vẫn bị bỏ qua.

## 2. Why — phần đã tốt và phần chưa đạt

Các kiểm tra sau await mới đã chặn được các ca cũ: ready không tự sống lại sau cancel, Guest chặn bootstrap và email muộn; SDK exchange A bị hủy đơn lẻ được dọn; login trực tiếp bị chặn khi clear fail. Không yêu cầu làm lại các fixes đã GREEN.

Điểm còn thiếu là **ownership chung**. Ví dụ Hủy A → clear đang chờ → đăng nhập B thành công → clear A trả về: check ở đầu lệnh Hủy đã cũ. Lệnh dọn dẹp phải biết nó còn được phép tác động session nào khi tiếp tục. Tương tự, generation chỉ ở recovery provider không chặn được quyền PUT do AuthProvider cấp.

Giải thích author về “xóa sạch dữ liệu A trên SQLite”, “trộn/lộ dữ liệu” hoặc “an toàn tuyệt đối” rộng hơn evidence. Marker recovery nằm trong SharedPreferences; C3 không phải yêu cầu xóa chuyến đi/SQLite của A. Reviewer chứng minh SDK session/state/marker/account result qua fixtures, không chứng minh đã có lộ dữ liệu người dùng thật. Giữ dữ liệu và các account guards hiện có.

## 3. Testing — reviewer-run

Full command:

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Full **exit0**, logs `.dart_tool/travelgo-verification/20261025T035820582Z-13420/`; wrapper `.dart_tool/c3-codex-review/full.log`.

| Check | Fresh result |
| --- | --- |
| flutter analyze | No issues found, 42.2s, exit0 |
| Flutter Full | **1011/1011 PASS**, 1:59, exit0; khác con số author ghi 1010 |
| Node contracts | **91/91 PASS**, fail0/skipped0, exit0 |
| Original scoped C3 probes | **10/10 PASS**: bảy R1/R3/R4/R5/R8/R9/R10 và ba positive controls |
| Overlap/new error probes X1–X6 + control | **6 FAIL / 1 control PASS**, exit1 |
| Production-store confirmation P1/P2 | **2 FAIL**, exit1; xác nhận lại hai lỗi cancellation, không phải hai root cause mới |
| git diff --check | exit0; line-ending warnings |
| Source snapshot | 376/376 source/test/config files giữ nguyên trong review |

Probes gốc được copy sang `.dart_tool/c3-codex-review/original_c3_probe_test.dart`, chỉ cập nhật override clear nhận optional expectedIntentId để khớp API C3, conditional clear và thêm seam/flags; giữ expected hành vi. Không sửa probe R1 gốc hoặc permanent tests để có PASS. Các fixture UUID/JWT synthetic có exp hợp lệ; lifecycle/SQLite positive control PASS.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-review/original_c3_probe_test.dart .dart_tool/c3-codex-review/overlap_probe_test.dart --name 'CONTROL|R1 |R3 |R4 |R5 |R8 |R9 |R10 |C3X'
```

Log `.dart_tool/c3-codex-review/probes.log`: original C3 10PASS và bản X đầu 5FAIL/1controlPASS. Sau bổ sung X6, chạy lại riêng file overlap, log `.dart_tool/c3-codex-review/overlap-final.log`: **6FAIL/1PASS**. X3/X4/X5 có diagnostics actual trước assertion. Không cộng các lần lặp thành số ca độc lập.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-review/overlap_probe_test.dart
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/c3-codex-review/production_store_probe_test.dart
```

Production confirmation log `.dart_tool/c3-codex-review/production-store.log`. Probes dùng installed SDK/fake HTTP, controlled persistence seams/SharedPreferences mock; không gửi email thật, gọi Supabase live hoặc đọc token thật. Notices trusted-role unavailable trong fixture không thay kết quả: B đã được assert có trong SDK trước khi thả cleanup A. Không build/install/device/hot reload/live acceptance vì reviewer không sửa app và không thao tác thiết bị.

Candidate hashes SHA256:

| File | SHA256 |
| --- | --- |
| password_recovery_provider.dart | `957b2876abd5ebd0d8e117f401ada68c4782af1fa9d7b58338e93fa0ec75d504` |
| auth_provider.dart | `7d34ef6184dd8aabf250247b3f131b438faf7c8344023682e77290dd0fa7b1af` |
| recovery_intent_store.dart | `50f69dc05a38c3cc297ef69ee8ef907d1f7825605afd9c2e61cbe60b5b36a725` |
| password_recovery_authority_test.dart | `7160f3487bf10c6933c2ab7cd0a20b33053ff08402673b6572b3803bc2a06754` |
| password_recovery_callback_race_test.dart | `ad1a97404076069f0b218241ac567873bc18ce3427e55e44c6859a8f92b34726` |
| password_recovery_cleanup_test.dart | `86d6637c9e1ea4021632c317a23994c4cf1a7513b387954a2068a0930bad75bf` |

Snapshot `.dart_tool/c3-codex-review/source-snapshot.json`. Reviewer cập nhật report này và checkpoint trong master/core plan; chỉ artifacts ignored khác được tạo. Không app/permanent test edits, commit/push/merge/deploy/DB/email/device changes.

## 4. Problems / bước sửa tiếp

- F01/F02/F04 lịch sử **PARTIALLY CLOSED**: các probes cũ đã đạt, contract chồng lấn và error paths phía trên chưa đạt. Không báo lại R1/R3/R5 cũ đang FAIL; cũng không gọi toàn finding CLOSED chỉ vì chúng PASS.
- Antigravity sửa **chỉ C3-F01–F04**, dùng Superpowers theo chỉ thị owner; chuyển các ca trên thành permanent regressions, kiểm RED/GREEN với positive controls. Giữ fixes cũ, C1/C2 và toàn bộ dirty owner work. Dừng để Codex re-review sau candidate mới.
- C4 F03/R2, F05/R6, F06/R7 và OTP/live vẫn deferred; không dùng các failure C4 để đánh trượt C3, cũng không tự sửa C4 trong correction này. PUT sau Hủy là authority C3, không đẩy sang C4 vì cùng gọi submit.
- Giữ guard tối đa ba vòng sửa lỗi hiện hành, ghi vòng đã dùng; review không cấp lại budget hay quyền native/dependency/live. Không giới hạn file/tool calls cũ, không xin lại scope đã duyệt.
- Device/iOS/live NOT RUN; chưa có nghiệm thu toàn recovery/app. C2 acceptance vẫn là evidence ở candidate C2 trước thay auth này, không tự mở rộng sang source C3 mới.

## 5. Lesson Candidate

Problem → Root cause → Rule: “generation đã tăng nhưng PUT sau Hủy vẫn được gửi” → “quyền thao tác nằm ở lớp khác với generation vừa đổi” → “thu hồi quyền ở nơi thực sự cấp mutation trước await; UI loading chỉ là lớp thể hiện”.

Problem → Root cause → Rule: “test A và test B đều PASS, khi chồng lấn thì B bị logout” → “test tuần tự không giữ cửa sổ cleanup cũ đang pending” → “assert session B đúng trước khi release A, rồi assert lại sau completion A; kiểm cả state/marker và SDK side effect”.
