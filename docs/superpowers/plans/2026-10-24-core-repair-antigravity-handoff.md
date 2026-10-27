# TravelGO Core Repair — Antigravity Handoff

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for implementation. Owner chọn Antigravity code/sửa findings, Codex phân tích/plan/review. Không đổi sang Codex code hoặc tự dispatch subagents. Thực hiện trọn phạm vi, các phần kế hoạch không tạo approval gate riêng.

**Goal:** Sửa 17 mục đã được owner xác nhận để cấu hình chuyến đi, kết quả, lưu/mở lại, bản đồ và tài khoản phản ánh dữ liệu thật.

**Architecture:** Sửa các điểm nối trong hệ thống hiện có, dùng chung policy ngày/result snapshot/catalogue và credential queue. Không viết lại Decision Engine, booking subsystem hoặc hệ thống auth.

**Tech Stack:** Flutter/Dart, Provider, Dio, fl_chart, flutter_map, Supabase, PostgreSQL local, SharedPreferences2.5.5.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`.

## Global Constraints

- Đọc AGENTS.md, .agent/rules.md, .agent/workflow.md và spec. Superpowers được owner yêu cầu cho phạm vi này.
- Mã nền `89659f5a7c48eca4053b3f1c5e519d42a7a4efa8` + dirty/untracked; không reset/stash/clean/stage chung. Nếu HEAD đổi, đối chiếu thay đổi liên quan trước thực hiện, không tự coi audit cũ là kết luận HEAD mới.
- Không giới hạn giả calls/files/task hoặc xin thêm calls. Không skip lỗi chưa sửa để báo hoàn thành.
- Không push main/merge/deploy/đổi SMTP/allowlist/billing/quota/DBlive. Chỉ source, migrations mới và kiểm thử synthetic/local. Dependency trực tiếp SharedPreferences cùng phiên bản lock đã nằm trong phạm vi thiết kế; native config không đổi.
- Giữ seed/cache/fallback có nhãn và draft cũ; không mint fake user/package/giá/vị trí/email delivery.

## Review Focus

1. Đầu vào và dữ liệu lưu không cùng thế hệ/account — P1/P2/R3.
2. Widget pass khi tự inject snapshot nhưng entry app không inject — P4/P5.
3. Source gateway đã đổi nhưng runtime chưa deploy — Q2; tách status source/live.
4. Session PKCE recovery thành normal account sau cold start — R3.
5. Test harness nuốt SQL failure hoặc fixture missing thành PASS — P2 và final review.

## Tài liệu thực thi và thứ tự

| Phần | Đọc plan | Tasks | Phụ thuộc |
|---|---|---|---|
| Gói1: planner/kết quả/bản đồ | `docs/superpowers/plans/2026-10-24-planner-results-map-repair.md` | P1–P6 | P2 sau P1; P3 sau P2; P4 trước P5; P6 phối hợp P5 |
| Gói2: danh sách/trợ giúp | `docs/superpowers/plans/2026-10-24-trip-management-assistant-repair.md` | Q1–Q2 | Q1 sau P2; Q2 sau P1/P4 |
| Cá nhân/tài khoản | `docs/superpowers/plans/2026-10-24-account-api-recovery-repair.md` | R1–R3 | R3 sau R1/R2; kết hợp R1/P6 trong test cuối |

Khuyến nghị thứ tự liên tục P1→P2→P3→P4→P5→P6→Q1→Q2→R1→R2→R3. Không cần owner duyệt lại từng task; chỉ báo vướng mắc thật không thể giải quyết trong phạm vi. Có blocker live thì vẫn hoàn thành code/tests local của các phần độc lập.

## Coverage từng lỗi

| ID | Kết quả cần chứng minh | Task |
|---|---|---|
| L1 | Ngày form→manual/cloud→mở lại không mất | P1,P2 |
| L2 | Ma trận chỉ dùng DTO thật/ngân sách gốc | P3 |
| L3 | Pareto có trục chứa điểm20giờ và safe zero/invalid | P3 |
| L4 | Pie không nhận section âm; vượt ngân sách vẫn rõ | P3 |
| L5 | Đủ hoạt động qua map, vị trí/thứ tự/ngày thật | P4,P5,P6 |
| L6 | Không có demo order/thẻ xác nhận giả | Q1 |
| L7 | Timeline có ngày thực hoặc nhãn thiếu ngày | P1,P3 |
| L8 | Detail AI tới composer thật, valid dynamic ID, không gọi ngầm | Q2 |
| A1 | URL persist/reset/cold start/profile build | R1 |
| A2 | OTP không tạo usr-verified, server/session authoritative | R2 |
| A3 | Email→PKCE→password→cleanup→login | R3 |
| N1 | Ngày và số ngày luôn thống nhất ở input mới | P1 |
| N2 | Lưu đủ origin/people/preferences/companion/budget gốc | P2 |
| N3 | New/saved/Guest/copy editor/map dùng release mới | P4 |
| N4 | Map và planner dùng cùng host mới, response cũ bị bỏ | R1,P6 |
| N5 | Không route của chuyến trước khi mở chuyến thiếu tọa độ | P6 |
| N6 | Phân nhóm thật theo ngày/dữ liệu đủ, pagination honest | Q1 |

## Các quyết định đã chốt, không tự thay bằng fake

- Ma trận so sánh điểm đến và phương tiện được trả về, không còn ba package trọn gói. Thiếu contract khách sạn/chính sách hủy thì không hiển thị những lời hứa này.
- Không đổi canonical activity V1. Bản đồ tự ghép duy nhất tên chính xác trong đúng destination + catalogue; unresolved vẫn có hàng và user chọn liên kết tạm, ghi rõ chưa lưu. V2 editor giữ placeId bền vững khi user chỉnh/lưu.
- Quản lý chuyến đi dùng ba nhóm ngày; bỏ tab hủy chưa được schema hỗ trợ, không phát sinh API cancel/booking.
- Recovery dùng lại host Manifest bằng query flow=recovery, không bật auto URI handler; cookie/token/session không được gửi sang API URL tùy chỉnh.
- Source migration duy nhất bổ sung optional request fields cho validator Guest, không đổi activity schema/digest/receipt cũ hoặc RPClist.

## Kiểm chứng cuối cùng

Các test chính dưới đây phải có tên và assertion rõ ràng trong task tương ứng; fixture setup viết theo seams/interfaces của plan, không mock bỏ tầng đang kiểm:

| Task | Test name | Assertion chính |
|---|---|---|
| P1 | `calendar_range_and_duration_are_one_state` | `expect(provider.currentRequest.endDate, '2026-11-05'); expect(provider.currentMetadata.startDate, '2026-11-01');` |
| P2 | `saved_result_roundtrips_original_input` | `expect(decoded.request!.numPeople, 4); expect(decoded.request!.budgetVnd, 6000000); expect(decoded.metadata.startDate, '2026-11-01');` |
| P3 | `pareto_includes_twenty_hour_option` | `expect(chart.data.maxX, greaterThanOrEqualTo(20)); expect(parsed.transportOptions.first.isParetoOptimal, true);` |
| P4 | `reopened_editor_keeps_published_place_location` | `expect(mapScreen.snapshot!.catalogue.destinations.any((d) => d.id == 'dest-quy-nhon-123'), true);` |
| P5 | `unresolved_activity_is_not_dropped_or_guessed` | `expect(mapContext.activities.length, 5); expect(mapContext.activities.last.positionOnMap, isNull);` |
| P6 | `reinitializing_without_destination_clears_previous_trip` | `expect(map.destination, isNull); expect(map.hasRoute, false);` |
| Q1 | `date_groups_use_vietnam_day_and_loaded_pages` | `expect(TripListClassifier.classify(rowEndingNov2, nowUtc: DateTime.parse('2026-11-02T17:00:00Z')), TripListBucket.past);` |
| Q2 | `dynamic_ai_uses_public_name_after_consent` | `expect(capturedContext['destinationId'], 'dest-quy-nhon-123'); expect(capturedContext['destinationName'], 'Quy Nhơn'); expect(callsBeforeConsent, 0);` |
| R1 | `cold_start_uses_persisted_host_for_both_clients` | `expect(plannerRequest.uri.host, '192.168.1.5'); expect(routeRequest.uri.host, '192.168.1.5');` |
| R2 | `otp_without_server_never_grants_identity` | `expect(await auth.verifyOtp('123456', email: 'qa@example.invalid'), false); expect(auth.currentUser, isNull);` |
| R3 | `recovery_cleanup_retry_does_not_update_password_twice` | `expect(recovery.state, RecoveryState.cleanupRequired); await recovery.retryCleanup(); expect(updateUserCalls, 1); expect(auth.isAuthenticated, false);` |

### 1. Trước sửa

- Ghi HEAD/branch/diff liên quan; rà các file đã dirty để không ghi đè phần owner. Không tạo worktree rồi bỏ sót source dirty làm baseline; nếu cần isolation phải snapshot có chọn lọc và giữ đầy đủ input đang review.
- Audit trước: 114 targeted PASS và probe1PASS/8FAIL trong `.dart_tool/codex-core-review/`. Đây là evidence của lượt audit trước, không phải kiểm chứng implementation mới.
- Copy 8 probe lỗi thành permanent tests trong các task tương ứng; chỉ giữ RED do assertion đúng, không do compile/finder lỗi.

### 2. Trong sửa

- Mỗi task có RED→minimal implementation→GREEN và selective commit sau diff review. Nếu file đã có thay đổi owner thì chỉ stage hunks task hoặc bàn giao patch rõ ràng; không `git add .`.
- Migration tạo qua CLI local, dùng tên sinh ra duy nhất và ghi vào report; chưa apply live. Test SQL chỉ server local do runner tạo và luôn cleanup.
- Không sửa expected count về72, không bỏ test auth/owner/consent/unknown-facts để làm xanh.

### 3. Sau khi source đã hoàn tất

```powershell
./tool/verify-planner-core.ps1 -Mode Sql -FlutterRoot D:/flutter/flutter
./tool/verify-planner-core.ps1 -Mode Sql -SelfTest -FlutterRoot D:/flutter/flutter
node --test test/itinerary_gateway_test.mjs
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

- Full bao gồm flutter analyze, toàn bộ Flutter tests và ba Node suites hiện có. Chạy một vòng cuối sau khi targeted pass, không lặp Full vô ích khi chưa thay source.
- SQL gate là bổ sung bắt buộc, Full hiện không kiểm SQL. Mọi exit phải đúng; thiếu PostgreSQL/fixture/tooling ghi BLOCKED, không làm skip thành PASS.
- Final end-to-end synthetic: Huế01–03/11/2026,4người,6triệu,family→result→save→reload→copy/editor→map; remote catalogue place mới và seedv1/remoterv1 khác hash; Guest save→account import payload có optionalfields.
- Race synthetic: accountA→B, dirtydraftcancel, routeA→B→Aresponse, đổiURLpending, recovery callbackduplicate/cold/replay/updateacklost/cleanupfail.
- Log dưới `.dart_tool/`, chỉ số tổng/trace đã làm sạch. Không ảnh chụp hoặc dump email/code/password/token thật.

### 4. Native/live acceptance sau Codex review và đúng quyền môi trường

| Flow | Tiêu chí | Nếu chưa chạy |
|---|---|---|
| API URL profile trên máy thật | save→forceclose→reopen cònURL; planner/map đúnghost; reset bền | NOT RUN, không suy từ widget test |
| Planner/save/map | calendar/budget/people đúng sau reload; dynamic place có marker; unknown giữ nhãn; không route cũ | NOT RUN |
| AI thật | detail→composer→consent→preview→Apply vào draft; không tựsave; gatewayhash khớp | NOT RUN nếu chưa deploy source mới |
| Recovery email thật | stagingQA mail/link warm+cold→newpassword→login; expired/replaydeny | BLOCKED nếu SMTP/redirect thiếu; không sửa thành fake |

## Báo cáo để Codex review

Tạo `docs/phase-3/CORE_REPAIR_IMPLEMENTATION_REPORT_20261024.md` gồm:

1. Changed: exactcommits, file/hunks, behavior trước/sau; nêu rõ dirty work giữ lại.
2. Why: giải thích form→provider→API/save→reload→map và recovery session khác normalaccount như thế nào.
3. Testing: command/exit/log/cases chứng minh từng ID; phân biệt author-run với owner/device evidence.
4. Problems: remaining/deferred/live blocked; source-ready khác deployment/native acceptance.
5. Lesson Candidate: mất context ở điểm nối và test component thiếu entry wiring → roundtrip test.

Codex review so diff với spec/coverage, chạy lại original repro ở code mới, kiểm minimal permission/dependency/SQL changes, kiểm test có bị nới không. Findings ảnh hưởng demo ưu tiên sửa; không nói đã sửa khi mới ghi đề xuất. Owner giữ merge/rollout cuối.

## Prompt gửi Antigravity

```text
Bạn là Antigravity implement TravelGO; Codex lập kế hoạch và review. Hãy thực hiện toàn bộ L1–L8, A1–A3, N1–N6 theo packet docs/superpowers/plans/2026-10-24-core-repair-antigravity-handoff.md, đọc spec và ba plan được liên kết trước khi code.

Giữ hai gói planner/bản đồ và UI/AI, cộng phần tài khoản/API; làm liên tục theo dependency, không dừng xin duyệt từng task, không xin thêm số calls/files. Dùng superpowers:executing-plans cho task này, không tự dispatch subagents. Bảo toàn mọi dirty/untracked có sẵn và không stage/commit chung việc owner.

Viết test tái hiện trước, sửa đủ dữ liệu đi xuyên qua form→result→save→reopen→map, OTP phải tin server, recovery PKCE phải hoàn chỉnh warm/cold. Không fake package/giá/tọa độ/user/email, không bỏ auth/consent/quota/owner fencing. Quyết định dữ liệu/contract và signatures nằm trong spec/plan; không thay bằng giải pháp giả để đủ demo.

Chỉ sửa source, thêm dependency SharedPreferences2.5.5 trực tiếp đã có trong lock và migration validator tương thích đã mô tả. Không deploy/apply live/đổi SMTP, allowlist, quota, billing hay native config. Nếu live bị chặn, hoàn tất phần local độc lập rồi ghi rõ; không giả PASS.

Sau targeted và SQL thật trên DB local disposable, chạy Full một lần cuối, kiểm exit và lưu log. Bàn giao exactcommits/diff cùng docs/phase-3/CORE_REPAIR_IMPLEMENTATION_REPORT_20261024.md để owner mang về Codex review. Giải thích flow/nguồn lỗi/cách kiểm chứng bằng tiếng Việt; không chỉ liệt kê tên file và số tests.
```
