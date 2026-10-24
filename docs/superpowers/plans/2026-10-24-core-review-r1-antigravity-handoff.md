# Core Review R1 — Antigravity Handoff

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for implementation. Owner yêu cầu Codex lập plan bằng Superpowers và bàn giao Antigravity code. Codex chỉ lập/review tài liệu ở lượt này. Không dispatch subagents, không gửi chat khác, không tự bắt đầu implementation từ việc file này tồn tại.

**Goal:** Sửa đủ bảy findings của review Core Repair mà không mở lại các gói planner/catalogue/AI đã ngoài scope.

**Architecture:** Hai plan độc lập theo subsystem, thực hiện tuần tự và giữ Provider/Dio/credential queue/route generation hiện có. Thêm regression đúng điểm nối thay vì refactor hệ thống auth/map.

**Tech Stack:** Flutter/Dart, Provider, Supabase Flutter, SharedPreferences, Dio, flutter_map; giữ dependency/native/schema hiện có.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`, tập trung S3/S5. Đây là repair plan theo review, không phải spec kiến trúc mới.

## Global Constraints / quyền hạn

- Repo `D:/Travel-Go-Android/travel-go`; branch lúc lập plan `codex/phase-3-discovery-design`; HEAD `147bd2050ae3a59e942b29945fbe54c9c9eae60c`.
- Working tree có 40 tracked dirty files và nhiều untracked của owner. Các source chứa bảy findings đã đối chiếu khớp HEAD ở lượt review. Tests hiện tại có dirty owner work; không coi green working tree là green clean checkout.
- Không reset/stash/clean, xóa draft, stage toàn bộ, thay permanent rules, dependency/lockfile, Manifest/native config, schema/SQL, deploy/config staging, SMTP/allowlist/billing/quota hoặc merge/push main.
- Plan này không cấp quyền deployment hoặc sửa cấu hình ngoài source. Khi owner chuyển prompt thực thi bên dưới, đó là authorization sửa source trong phạm vi plan; commit/push/PR chỉ khi owner cấp tương ứng. Human review/merge gate giữ nguyên.
- Trước sửa: đọc AGENTS/rules/workflow, actual HEAD/diff và cả hai plan. Nếu HEAD khác thì đối chiếu phần liên quan; không ghi đè dirty owner. Không tạo checkout sạch rồi bỏ mất dirty baseline cần thiết.
- Tuân budget/retry/file guard hiện hành. File lists là scope từng task, không phải quyền sửa tùy ý. Nếu không tách được hunks owner hoặc chạm guard, checkpoint việc đã làm/còn thiếu; không báo hoàn thành giả hoặc tự reset counters.
- Superpowers được yêu cầu rõ cho lượt lập plan. Prompt thực thi bên dưới yêu cầu rõ Superpowers cho Antigravity; không dùng lịch sử này để tự bật skill ở task khác.

## Phạm vi findings và bằng chứng

| ID | Mức | Trigger / nguyên nhân source | Task đóng |
|---|---|---|---|
| CR1 | P1 | Gate chỉ ready/cleanup, nên ready→updating tháo ResetPasswordScreen | Recovery A4 |
| CR2 | P1 | runRecoveryMutation không kiểm intentId/generation; late result/cancel không được fence | Recovery A1 |
| CR3 | P1 | Screen tính first-stop origin nhưng init vẫn lấy GPS, bỏ điểm đầu khỏi request | Map B1 |
| CR4 | P1 | Đổi ngày/binding tái dùng token; completion/camera ngày cũ vẫn active | Map B2 |
| CR5 | P2 | Callback lặp exchange lần hai sau verifier đã tiêu thụ, ready thành error | Recovery A2 |
| CR6 | P2 | PUT ACK rồi write cleanup fail rơi generic error, intent vẫn ready/retryable | Recovery A3 |
| CR7 | P2 | Backend revision check không bao OSRM await; provider generic catch tạo offline line | Map B3 |

Review trước chỉ đọc source/chạy suite; chưa có regression tái hiện riêng cho bảy findings, chưa native repro, chưa sửa. Không coi bảng này là bằng chứng các test mới đã RED/GREEN.

Evidence reviewer-run 24/10/2026: `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`, process exit0, analyzer 0 issues (98.6s), Flutter 1057 tests PASS (3:21), Node 91 PASS/0 fail. Logs `.dart_tool/travelgo-verification/20261024T032200639Z-5584/{analyze,flutter-tests,node-contracts}.log`. Lần đầu sandbox không mở được SDK lockfile; lần chạy có quyền SDK mới là kết quả PASS. Đây là evidence của lượt review trước trên HEAD + dirty tree, không phải checks cho implementation mới.

## Quyết định thiết kế và phương án đã cân nhắc

- **Chọn sửa đúng điểm sở hữu:** AuthProvider quản credential authority/queue, recovery provider quản marker/state, gate chỉ điều phối hiển thị; MapProvider nhận stops rõ ràng và screen cấp token mới cho mỗi rebuild. Lợi ích: giữ kiến trúc hiện có và test được I/O thật giả lập. Tradeoff: cần kiểm cả entry wiring/UI/caller, không chỉ unit từng lớp.
- **Không chọn vá riêng widget/service:** chỉ thêm updating vào gate hoặc chỉ check revision tại backend sẽ bỏ sót authority/cold restart/OSRM/camera. Đây là các lớp bảo vệ bổ sung của cùng bảy findings.
- **Không chọn viết lại auth/router/map:** phạm vi lớn hơn lỗi, rủi ro Guest/owner/Radar và cần quyết định kiến trúc mới. Plan không yêu cầu hướng này.
- Durable `RecoveryPhase.updating` là write-ahead intent, không chứng minh mật khẩu đã đổi. Cold restart/mất ACK phải uncertain và chỉ cleanup; không hứa exactly-once server nếu SDK/API không có idempotency key. Không lưu mật khẩu để retry tự động.

## Review Focus

1. Completion A sau cancel/Guest/login B không được thay session/marker/UI B — A1.
2. Duplicate/cold callback và marker load chậm không exchange hai lần — A2/A4.
3. ACK/uncertain + lỗi local giữ cleanup-only, không PUT lại hoặc restore recovery thành account — A3/A4.
4. GPS khác destination, đổi ngày nhanh và dispose không lẫn tọa độ/geometry/camera — B1/B2.
5. Đổi URL khi OSRM pending không sinh response/offline line cũ; standalone/Radar giữ hành vi — B3.

## Thứ tự thực thi / checklist

- [ ] Đọc [Recovery plan](2026-10-24-core-review-r1-recovery.md), thực hiện A1 → A2 → A3 → A4, mỗi task RED → minimal fix → GREEN → diff review.
- [ ] Đọc [Map/API plan](2026-10-24-core-review-r1-map-api.md), thực hiện B1 → B2 → B3 theo cùng chu kỳ. Không song song hai người sửa MapProvider/recovery provider.
- [ ] Thực hiện source self-review cuối theo bảy ID, kể cả caller/UI/cleanup branches. Nếu một finding không tái hiện, giữ test đúng và báo evidence cho Codex, không sửa cho có hoặc nới assertions.
- [ ] Sau sửa Dart/Flutter, thực hiện hot reload/restart qua Dart MCP khi có runtime QA phù hợp và không mất nháp; thiếu kết nối/quyền ghi NOT RUN. Không tự reset/cài app của owner.
- [ ] Chạy Full một lần sau targets green bằng command dưới; nếu fail phân tích lỗi đúng root cause theo retry guard, không lặp Full vô ích.
- [ ] Kiểm selective diff, làm report `docs/phase-3/CORE_REVIEW_R1_IMPLEMENTATION_REPORT_20261024.md` với bảng từng CR → commit/hunks → RED/GREEN/log → status; đưa owner mang lại Codex review.

```powershell
& ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Command này chạy flutter analyze --no-pub, toàn Flutter test --no-pub --concurrency=2 và ba Node suites. Dùng array `-TestPath @('test/a_test.dart','test/b_test.dart')` khi gọi targeted trong PowerShell hiện tại; không truyền comma-list như một filename từ shell khác. Log dưới `.dart_tool/`, không commit artifacts. Không cần chạy SQL/build/APK/deploy cho patch này.

## Handover bắt buộc

1. **Changed:** actual branch/base/final HEAD, từng task/file/hunk/commit nếu có; phần dirty owner giữ lại.
2. **Why:** giải thích hai luồng user→UI→provider→SDK/service→response→UI. Ví dụ trước: Ngày2 hiển thị nhưng route ngày1; sau: token mới chỉ nhận geometry/camera ngày2. Recovery ACK và cleanup là hai kết quả riêng.
3. **Testing:** từng regression RED/GREEN, exact commands/exits/counts/log paths; Full mới, runtime hot reload/restart thực sự chạy hoặc NOT RUN. Không tái dùng số1057 làm expected count mới.
4. **Problems:** ID chưa đóng, giới hạn known/uncertain, email/native chưa chạy, permission/budget blockers; source-ready khác live accepted.
5. **Lesson Candidate:** late async result → scope không được recheck → guard cả dispatch, completion và side effect; success server khác success cleanup → persist before dispatch, retry đúng bước.

## Prompt owner copy sang Antigravity sau khi xem plan

> Hãy dùng Superpowers để thực thi gói Core Review R1 tại D:/Travel-Go-Android/travel-go. Tôi duyệt phạm vi và giao bạn sửa source/test theo docs/superpowers/plans/2026-10-24-core-review-r1-antigravity-handoff.md cùng hai plan Recovery và Map/API được link trong đó. Đọc actual HEAD/diff, AGENTS/rules/workflow; giữ mọi dirty/untracked ngoài task. Dùng superpowers:executing-plans, systematic-debugging và test-driven-development; không dispatch subagents. Thực hiện A1–A4 rồi B1–B3, viết regression RED trước fix, GREEN sau fix, kiểm cả entry wiring/UI/session/store/geometry/camera. Tuân budget guard hiện hành và checkpoint khi cần; không tự bỏ task để báo hoàn thành. Không sửa dependency/native/schema/permanent rules, không deploy/config môi trường, không reset/dọn dữ liệu owner, không tự commit/push/merge. Chạy Full sau targets green, thực hiện hot reload/restart nếu có runtime QA an toàn, ghi NOT RUN cho phần thiếu. Xuất docs/phase-3/CORE_REVIEW_R1_IMPLEMENTATION_REPORT_20261024.md theo 5 mục, map đủ CR1–CR7 với bằng chứng và prompt gửi lại Codex review. Không coi source tests PASS là email thật hoặc nghiệm thu thiết bị.

## Self-review của lượt lập plan

- [x] CR1–CR7 đều có task, files, nguyên nhân, test names/assertions và lệnh kiểm chứng.
- [x] Tách Recovery và Map/API; signatures liên task khớp và không thêm dependency/native/backend contract.
- [x] Mỗi task <=5 files; không yêu cầu tắt guard hay ghi đè hunks owner.
- [x] Bao gồm UI/camera, caller catch, startup/cancel/late write và write-ahead/uncertain; không chỉ vá symptom đầu tiên.
- [x] Baseline evidence tách implementation chưa làm; owner giữ quyền giao thực thi và human review/merge gate.
