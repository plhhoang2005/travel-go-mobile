# TravelGO — packet A0–A5 cho Antigravity

Ngày 23/10/2026, Asia/Saigon. Trạng thái: **đã giao phạm vi một đợt; implementation chưa được Codex nghiệm thu**.

## Chỉ thị và phạm vi hiện tại

Owner: “bạn hãy hoàn thành hết a0-a5 luôn đi không cần chia nhỏ ra đâu”. Áp dụng cùng phân công đã chọn: **Codex lập kế hoạch/review; Antigravity code, test và sửa findings**. Owner đã bỏ giới hạn tool/calls nhân tạo; không dừng xin thêm 10 calls, không áp trần 20/25 mỗi task hoặc 500 tổng. Giới hạn thực của nền tảng vẫn tồn tại, prompt không thay đổi được chúng.

Thực hiện A0–A5 của [account-control plan](2026-10-23-admin-account-control.md) liên tục theo dependency; các nhãn A chỉ là checklist kỹ thuật. Không dừng chờ owner giao A1, A2… hoặc đợi Codex review từng nhãn. Một handover cuối đợt để Codex review chung. Cho phép toàn bộ hợp **23 execution files** dưới đây cho packet này, thay gate năm file mỗi task; không sửa permanent rules. Không tự gọi subagents hoặc tự bật Superpowers từ grant cũ.

Gói này cung cấp nền tảng account control, dashboard API, bảo vệ dữ liệu/AI, kiểm tra access Flutter và lệnh chỉnh draft có compatibility web. **Flutter admin screens F1–F6 và xuất bản danh mục/app khách P không thuộc A0–A5**. Hoàn tất packet không đồng nghĩa toàn bộ khu quản trị Flutter đã xong.

## Baseline cần giữ

- Repo `D:/Travel-Go-Android/travel-go`; branch lúc giao `codex/phase-3-discovery-design`; reviewed HEAD A0 `02db19e7dd9005f441e541c45630abb20be0807a`. Kiểm actual HEAD trước sửa; không mặc định nó còn giống baseline.
- Checkout có nhiều modified/untracked owner files, gồm dependencies của feature. Không reset/stash/clean, không tạo checkout chỉ từ HEAD rồi làm mất dependencies. Ghi baseline/hash của file đã dirty để phân biệt phần mình thay.
- A0 đã có source và author logs nhưng Codex kết luận NEEDS CHANGES. [Review A0](../../phase-3/A0_CODEX_REVIEW_20261023.md) là evidence lịch sử, không bị vô hiệu vì được giao cả A0–A5.
- Baseline logs author-run đã được reviewer đọc: Full 854 Flutter PASS, 89 Node PASS, analyzer clean; targeted hai file lịch sử 20 PASS. Đây là kết quả của source cũ. Không kết luận nguyên nhân concurrency của lỗi cũ khi chưa chứng minh.
- Supabase CLI chưa trên PATH trong shell A0. Tìm existing approved cached executable/version trước; không tự cài/nâng hoặc tự invent timestamp migration. PostgreSQL local synthetic không phải Supabase staging.

## Allowlist hợp nhất: 23 execution files

Alias migration được bind bằng tên thật do CLI trả về và ghi vào acceptance report. Không tạo thêm migration ngoài ba alias hoặc sửa migration đã applied.

| # | File / alias | Mục |
|---|---|---|
| 1 | `tool/verify-flutter-admin.ps1` | A0/A1/A3 |
| 2 | `docs/phase-3/FLUTTER_ADMIN_ACCEPTANCE_20261023.md` | A0 và handover chung |
| 3 | `M_CONTROL`: `supabase/migrations/<CLI>_admin_account_control.sql` | A1 |
| 4 | `supabase/tests/admin_account_control.sql` | A1 |
| 5 | `supabase/tests/admin_account_concurrency.sql` | A1 |
| 6 | `M_GUARDS`: `supabase/migrations/<CLI>_admin_account_guards.sql` | A2 |
| 7 | `supabase/tests/admin_account_surface_guards.sql` | A2 |
| 8 | `supabase/functions/itinerary-proposal/gateway.mjs` | A2 |
| 9 | `supabase/functions/ai-request/gateway.mjs` | A2 |
| 10 | `test/admin_account_gateway_test.mjs` | A2 |
| 11 | `supabase/functions/admin-control/index.ts` | A3 |
| 12 | `supabase/functions/admin-control/gateway.mjs` | A3 |
| 13 | `test/admin_control_gateway_test.mjs` | A3 |
| 14 | `lib/features/auth/services/account_access_service.dart` | A4 |
| 15 | `lib/main.dart` | A4 |
| 16 | `lib/features/auth/providers/auth_provider.dart` | A4 |
| 17 | `test/account_access_service_test.dart` | A4 |
| 18 | `test/auth_navigation_test.dart` | A4 |
| 19 | `M_DRAFT`: `supabase/migrations/<CLI>_admin_discovery_commands.sql` | A5 |
| 20 | `supabase/tests/admin_discovery.sql` | A5 |
| 21 | `admin/index.html` | A5 |
| 22 | `test/admin_discovery_web_test.mjs` | A5 |
| 23 | `test/admin_discovery_commands_test.mjs` | A5 |

## Thứ tự thực hiện và tiêu chí kết thúc

1. **Sửa A0 trước:** actual child exit phải xác định được; unavailable/null/timeout không được suy thành 0. SelfTest cần positive control chạy được và deliberate failure đúng marker + nonzero child exit; missing executable, lỗi log/kết nối không phải expected failure. Account/Draft/SelfTest thiếu required PostgreSQL phải BLOCKED/nonzero, không báo tất cả verified. Timed wait phải thực sự kết thúc trong giới hạn, cleanup chỉ owned processes kể cả startup fail. Bổ sung regression controls trong harness file hiện có cho bốn findings; không chỉ tìm chuỗi ERROR. Chứng minh success control, nonzero không marker, unknown exit, missing Node/PG và timeout đều có kết quả đúng. Không nghiệm thu A1–A5 bằng harness chưa sửa.
2. **A1 schema/API:** triển khai đầy đủ integrity/security/API wire matrix của plan; private account/operation/audit, current-account guard, last-admin serialization, idempotency và dashboard theo ngày Việt Nam. Kiểm hai connections thật cho last-admin invariant; không thay bằng mock tuần tự. Missing access/session, metadata spoof và direct grants đều có negative tests. Giữ valid existing sessions và existing Auth bans đúng thiết kế.
3. **A2 bảo vệ các đường cũ:** kiểm kê thực tế table/RPC/receipt/AI rồi thêm current account/session predicate cùng ownership. Test cả cached receipt/result, revoke giữa request và service-role paths; locked request không dispatch AI. Quota/consent Guest không đổi. Không chỉ ẩn UI để coi là khóa tài khoản.
4. **A3 Edge/Auth sync:** strict protocol; caller bearer cho RPC, service credential chỉ ở server cho Auth/worker. Lock deny trước Auth; unlock tiếp tục deny đến successful readback đúng revision. Test retries, opposite operations, stale worker, actor bị hạ quyền, reconcile và timeout. Không báo authSynced khi chưa có acknowledgement.
5. **A4 Flutter access:** Auth getUser + own-access RPC phải hoàn tất trước SessionHandle/protected restore; refresh trusted role ở lifecycle phù hợp. Test cold start/resume, missing/locked/invalid access, A→B/Guest và response đến muộn; giữ Guest draft và dữ liệu canonical. Network error không được báo nhầm là account locked.
6. **A5 draft commands:** xác minh prepared draft schema có trong database local biệt lập; không sửa applied migration. IDs do server cấp, parent FK, slug unique, không hard delete; restore giữ IDs mới ở trạng thái ẩn. Giữ giá/giờ/nguồn/package cũ; validate source/image-rights theo plan. Web create dùng command API và xử lý unsaved edits rõ ràng. Test rollback atomic, retry/conflict và legacy save không thêm/xóa IDs lịch sử.

Các hợp đồng chi tiết, fields, SQLSTATE, named regressions và API signatures trong account-control plan vẫn bắt buộc; bảng trên không thay thế chúng. Nếu phát hiện thiếu entry point hoặc contract mâu thuẫn, inspect và xử lý trong scope đã duyệt; ghi blocker cụ thể nếu buộc phải đổi kiến trúc/allowlist. Không tự thiết kế hợp đồng khác để vượt test.

## Verification chung

Thu RED/GREEN cho hành vi mới, không weaken hoặc xóa assertions cũ. Dùng fixtures synthetic và local PostgreSQL riêng, không dữ liệu người thật. Chạy bằng đúng executable/path đã xác minh; ghi command, exit, suite inventory, log và hash/source commit. Các lệnh dưới đây là mục tiêu sau khi harness được sửa; hiện chưa được tuyên bố PASS:

```powershell
./tool/verify-flutter-admin.ps1 -Mode Account -DryRun -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -SelfTest -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -Mode Account -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -Mode Draft -FlutterRoot D:/flutter/flutter
node --test test/admin_account_gateway_test.mjs test/admin_control_gateway_test.mjs test/ai_gateway_test.mjs test/itinerary_gateway_test.mjs test/admin_discovery_web_test.mjs test/admin_discovery_commands_test.mjs
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/account_access_service_test.dart','test/auth_navigation_test.dart','test/local_account_lifecycle_test.dart','test/auth_role_security_test.dart') -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Account phải thực sự chạy ba SQL suites account/control/concurrency/surfaces và gateway tests mới; Draft phải chạy existing integrity + new command tests. Full phải có analyzer và toàn bộ Flutter tests; không suy từ Node PASS rằng SQL/Flutter đã chạy. Chỉ chạy Full cuối đợt một lần khi không còn thay đổi; lặp khi failure hoặc sửa sau đó cần xác minh. Không yêu cầu Publication/All chứa suites P chưa triển khai rồi báo skip là hoàn thành A0–A5. Có active Dart app thì hot reload sau Dart changes, nếu không ghi NOT RUN; không tự đụng emulator/phone hay bản nháp đang mở.

Giữ tối đa ba vòng RCA liên tiếp cho cùng vấn đề; khi không thể tiến triển, checkpoint với root cause và công việc độc lập đã hoàn tất. Không dừng chỉ vì hết calls tự đặt hoặc qua một nhãn A. Không tự rollback owner work. Thiếu runtime phải phân biệt BLOCKED với PASS và tiếp tục phần độc lập có thể làm.

## Ranh giới và bàn giao cuối

Không tự sửa dependencies/native config/permanent rules, đọc dữ liệu tài khoản thật, deploy Edge, apply SQL live, publish catalogue, khóa/cấp quyền người thật, merge hoặc push main. Local migration files và SQL tests biệt lập nằm trong phạm vi đã giao; live rollout cần packet cụ thể cuối đợt để owner duyệt. Không cấp service credential cho Flutter hoặc ghi token vào log.

Selective stage đúng phần mình sửa; review staged diff trước commit. Commit theo dependency được phép trong cùng đợt; không commit dirty source của owner vào tên mình. Không tạo approval gate từ số commits hoặc số task.

Antigravity cập nhật acceptance report chung: A0–A5 từng mục IMPLEMENTED/VERIFIED/FAILED/BLOCKED/NOT RUN, exact migrations, base/final commit và hashes, commands/exits/counts/logs, từng finding A0 còn mở/đã khắc phục bằng evidence nào. Handover cuối đợt có Changed/Why/Testing/Problems/Lesson Candidate và giải thích luồng người dùng → client → server/database → acknowledgement. Phân biệt local, mock, chưa deploy và chưa nghiệm thu thiết bị. Không đánh completed khi còn required check thiếu hoặc fail.

Codex review toàn bộ packet sau handover, kiểm cả actual diff, negative controls của harness và account/draft invariants. Author ghi “đã sửa” không tự đóng findings. Không tuyên bố A0–A5 đã hoàn thành chỉ vì đã viết tài liệu này.

## Prompt giao việc — copy nguyên khối

```text
Bạn là Antigravity, người implement TravelGO. Giữ phân công Codex plan/review, Antigravity code/test/sửa findings. Tôi giao trọn A0–A5 một đợt theo docs/superpowers/plans/2026-10-23-admin-a0-a5-antigravity-packet.md và account-control plan được dẫn trong đó. Đọc AGENTS.md, rules/workflow và packet trước khi sửa.

Bắt đầu sửa cả bốn findings A0 tại reviewed commit 02db19e; chứng minh harness fail đúng rồi tự tiếp tục A1–A5 theo dependency. Không dừng sau A0 hoặc xin tôi giao từng task, từng năm file hay thêm 10 tool calls. Tôi bỏ trần tool/calls nhân tạo và cho phép hợp allowlist 23 execution files A0–A5 trong packet; không mở scope F/P hoặc thay permanent rules. Giữ tối đa ba vòng RCA cho cùng vấn đề và các ranh giới live/native/dependency/merge của packet. Superpowers mặc định OFF cho đợt này nếu tôi chưa yêu cầu riêng.

Bảo toàn mọi dirty/untracked owner work, không reset/stash/clean; tự tìm runtime đã có, không tự cài/nâng. Viết source và tests, chạy required local SQL/Node/Flutter checks thật, không weaken assertions hay biến missing runtime thành PASS. Tiếp tục phần độc lập khi có blocker, ghi rõ phần chưa xác minh.

Kết thúc toàn đợt, bàn giao một acceptance report chung A0–A5 kèm exact diff/commits/hashes, commands/exits/logs, trạng thái bốn findings A0 và giải thích luồng cho owner để Codex review chung. Chưa deploy/apply SQL live/publish/thao tác người thật hoặc merge main. Không tuyên bố completed nếu required checks còn fail/thiếu.
```
