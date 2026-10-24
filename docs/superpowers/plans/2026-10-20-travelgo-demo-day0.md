# TravelGO Demo Day 0 — Kế hoạch làm ngày 20/10/2026

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for Native execution after owner authorizes execution of this plan. Steps use checkbox (`- [ ]`) syntax. No subagents unless owner explicitly selects that method; do not infer delegation from this header.

**Goal:** Trong 4 giờ chính, tối đa 6 giờ gồm dự phòng, xác minh một luồng Discovery → manual → budget → Guest/Account save/reopen trên nền hiện có và chuẩn bị Generate + Modify để chạy thật ngày 21/10 nếu quota hôm nay đã hết.

**Architecture:** Reuse Flutter/Provider, SQLite và repository/RPC hiện có; không dựng tính năng hoặc editor mới. AI đi qua gateway hiện có, preview trả typed commands và chỉ `dispatchAll` sau xác nhận; lưu cloud là bước riêng. Hôm nay ưu tiên xác minh, ghi evidence và chỉ định đúng blocker; không giả định có bug cần patch trước khi kiểm.

**Tech Stack:** Flutter/Dart, Provider, Dio, Supabase Auth/PostgreSQL/RPC/Edge Functions, SQLite, Flutter tests, Node contracts; Android emulator x64 và DNY ARM64.

**Spec:** [Scope Baseline v2](../../phase-3/TRAVELGO_SCOPE_BASELINE_V2_20261020.md), bản sao nguyên byte từ file owner đưa tại `D:/Download/TRAVELGO_SCOPE_BASELINE_V2_20261020.md`. Trạng thái `PROPOSED` trong tài liệu được giữ nguyên. Đây là brief để lập kế hoạch, không tự thi hành Master Prompt đính kèm.

## Global Constraints

- Ngày làm: **thứ Ba 20/10/2026**, giờ Việt Nam. Deadline demo: **Chủ nhật 25/10**; mục tiêu nội bộ có bản ổn định tối 24/10. Kế hoạch này không phải lịch21–25 bị đổi nhãn.
- Owner yêu cầu ở lượt này: **lập plan hôm nay, dùng superpowers**. Đã được phép đọc bối cảnh và tạo tài liệu; **chưa triển khai code, tests, native hoặc gọi AI trong lượt lập plan**.
- Phạm vi chọn: **AI Generate + Modify proposal**, **Guest local + Email Account cloud**, một fixture **Huế**, 2 ngày/2 người. Giữ invariants privacy, receipts/version, actual preservation và consent.
- Scope deltas của v2 phải được ghi nhận trong quyết định thực thi; không biến old MUST/AC bị hoãn thành PASS. Không mở lại Google/chat/recommend/map/weather/community/engine/visual refresh trong ngày.
- Không tăng quota, đổi model/key/billing/config/deps/native/schema; không deploy/production; không stage/commit/push/merge/reset/clean. Không tạo worktree/copy toàn checkout cho task QA có dirty data.
- Giữ Guest drafts, Account data và file owner. Không clear/uninstall/wipe; không force-stop/logout/install khi còn draft RAM chưa có đường phục hồi xác minh được. Emulator5556 ngoài phạm vi.
- Mặc định một task execution tối đa **25 outer tool calls, 5 authored files, 3 repair rounds**; waits/rejections tính thật. Plan này đề nghị một packet QA tối đa 25 calls, **0 product repair rounds**, không phải quyền tự tăng budget.
- Giữ checkpoint/budget G2/G3/G4 cũ. G4 trước STOP là433/435 calls,7/7 rounds; C2/D3 sau có evidence riêng nhưng chưa thấy ledger counters hợp nhất. Không tự đặt lại counters hoặc mượn tên Day0 để sửa Auth/gói cũ đã hết rounds.
- Full suite chỉ chạy một lần trên snapshot không đổi. Nếu fail, phân loại và target đúng ca; không tự rerun toàn bộ nhiều lượt, thêm sleep hoặc hạ assertion.
- Native dùng context QA tổng hợp và test accounts được owner cho phép; không chép token/password vào artifact. Routine UI create/update chỉ trên fixture mới thuộc plan này sau khi được giao thực thi.
- Hết thời gian hoặc25 calls thì checkpoint rõ việc chưa làm; không tuyên bố Day0 READY nếu thiếu tiêu chí bắt buộc. Có thể bàn giao packet tiếp theo trong ngày sau khi owner giao phạm vi/ngân sách cụ thể.

## Review Focus

1. **Actual gắn với hoạt động bị xóa/sửa:** số tiền/ngày/ID khoản chi còn nguyên; chỉ thay snapshot/liên kết theo contract, không xóa tiền. Task 1 kiểm tests, Task 2 kiểm native.
2. **Cancel hoặc response AI đến muộn:** draft không đổi; Apply đúng một lần; cloud không tự ghi. Task 1 kiểm regression và Task 3 kiểm đường UI không gửi request khi chưa có consent.
3. **Đổi A→B/Guest trong loading:** dữ liệu A biến mất ngay và response cũ không quay lại. Task 1 kiểm suite; Task 2 kiểm một subset native sau khi draft đã lưu an toàn.
4. **App khởi động lại:** Guest đọc lại SQLite; Account cần server acknowledgement/readback, không chỉ RAM hoặc cached title. Task 2 kiểm theo đúng build.
5. **AI quota hết hoặc build không khớp:** không tự tạo identity để có lượt, không bật QA loss hook, không dùng native evidence build khác thay bản hiện tại. Task 0 chốt build, Task 3 lập ngân sách request và ghi trạng thái chờ quota.

---

## 1. Trạng thái đầu vào đã xác minh khi lập plan

| Mục | Observation / giới hạn |
| --- | --- |
| Checkout | `D:/Travel-Go-Android/travel-go`, branch `codex/phase-3-discovery-design` |
| HEAD | `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa` |
| Dirty |42 tracked modified,73 untracked entries trước khi tạo2 tài liệu của plan; không phải source packet sạch |
| Source Auth | SHA AuthProvider `1195C7D3…0FA6D`, lifecycle `55E6544C…30326C`, khớp checkpoint; không sửa trong task lập plan |
| Latest automated evidence | Đã đọc logs tại `.dart_tool/travelgo-verification/20261020T052246884Z-16184/`: analyzer clean 43.1s, Flutter 766 PASS, Node 89 PASS. **Historical, chưa chạy mới.** |
| Latest native evidence | Acceptance report cuối ngày 20/10: C2 PHONE03 emulator+DNY PASS; D3 stale conflict và main-UI reply-loss/retry PASS trong đúng subset; whole P3.2 NOT ACCEPTED |
| Normal main build theo report | x64 debug `B659857F500094F8B0AECC3E011A7CECC3C479099B498271F1D1C5EDB31AAD3B`; ARM64 profile `0AC26ADFCE52C350BAFF73A88923F16021AE6B6EE9229A5B922E4B6CD3F2BDE6` |
| AI live trước đó | Emulator có Generate/Modify thật và quota denial; không phải integrated Huế save/reopen trên final DNY |
| AI quota hôm nay | Ledger ghi A/B đã hết lượt 20/10; chưa kiểm live quota ở lượt plan. **Mặc định hôm nay không gọi AI thật.** Không dùng ngày giờ thiết bị để reset. |
| Model/context/data | Catalogue có `hue/citadel`, `hue/thien-mu`; openingHours/price/duration/coordinates còn null. Chi phí fixture là người dùng nhập, không phải giá vé. |

Những việc **không phải lỗi mới đang mở** chỉ từ lịch sử:4 full-run failures trước STOP đã có target PASS và full766 PASS về sau; interrupted-cold và reply-loss có C2/D3 mới hơn. Chỉ mở lại nếu source/build hoặc phép thử mới cho evidence trái chiều.

## 2. Kết quả cần có cuối hôm nay

- [ ] **DAY0-SOURCE:** snapshot source và build đang kiểm có định danh; automated checks thực chạy có log/exit, hoặc ghi rõ BLOCKED/FAIL.
- [ ] **DAY0-GUEST:** tạo/sửa/lưu, restart và mở lại đúng draft Huế có estimate+actual; xóa hoạt động đã chi không mất actual.
- [ ] **DAY0-ACCOUNT:** email Account lưu/mở lại/update fixture mới, server version đúng; subset A→B/Guest không lộ fixture vừa tạo.
- [ ] **DAY0-AI-READY:** Generated/Modify regression đạt, đường UI có consent/preview/apply tách save; script ngày 21 đã sẵn. Nếu quota hết, đánh `LIVE_PENDING_QUOTA`, không gọi hôm nay đã live PASS.
- [ ] **DAY0-HANDOVER:** một evidence report, tối đa3 blocker có trigger/impact/source candidate/next action; không đặt toàn bộ backlog cũ trở lại P0.

`DAY0_CORE_READY / AI_LIVE_PENDING_QUOTA` là kết quả hợp lệ của ngày 20 nếu3 mục core đầu đạt. Nó **không phải** hoàn thành demo v2, V2-04/05 hay whole P3.2. Thiếu Guest hoặc Account core thì dùng `DAY0_PARTIAL`.

## 3. File map và interfaces — kiểm đúng lớp, không mở refactor

### File tài liệu được tạo ở lượt plan

1. `docs/phase-3/TRAVELGO_SCOPE_BASELINE_V2_20261020.md`: bản sao nguyên byte của scope owner, để brief đi cùng plan.
2. `docs/superpowers/plans/2026-10-20-travelgo-demo-day0.md`: plan này.

### Khi thực thi, chỉ dự kiến tạo thêm

3. `docs/phase-3/DEMO_V2_DAY0_EVIDENCE_20261020.md`: command/exits/source/build/native steps/quota status/next-day handover. Không tạo thêm implementation plan/ledger cạnh tranh.

Logs/screenshots sử dụng artifact directory ignored theo công cụ hiện có; không stage APK hoặc secrets. **Không có product file được chỉ định sửa trước khi có finding.** Nếu phát hiện bug, kết quả là một repair packet cụ thể; không tự viết implementation cho bug chưa biết.

### Source và tests cần đọc/kiểm

| Trách nhiệm | File / interface đã thấy |
| --- | --- |
| Planner state/commands/save | `lib/features/trip_planner/providers/manual_planner_provider.dart`: `openNew(EditableTripDocumentV2,{SourceBinding? source})`, `dispatchAll(List<EditableCommand>)`, `SavePreview previewSave()`, `Future<bool> confirmSave(SavePreview)`, `Future<bool> retrySave()` |
| Manual UI nối AI | `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`: AI route returns typed preview; chỉ dispatch khi current/canApply; không tự confirmSave |
| Generate proposal | `lib/features/trip_planner/services/ai_generation_service.dart`: `AiPreparedProposal prepareAiProposal(EditableTripDocumentV2 before, AiItineraryProposal proposal, String Function() newId)` |
| Modify proposal | `lib/features/trip_planner/services/ai_assistant_service.dart`: `AiModificationPreview prepareAiModification(EditableTripDocumentV2 before, AiAssistantResult result, AiAssistantContext context, String Function() newId)` |
| Exact money | `lib/features/trip_planner/services/budget_calculator.dart`: `static BudgetTotals calculate(EditableTripDocumentV2 document)`; `trip_total` multiplier1; estimates và actual có remaining riêng |
| Local/cloud boundary | `lib/features/trips/services/editable_trip_repository.dart`, `editable_local_store.dart`, `editable_trip_service.dart`: read/create/update/list/receipt/version, không ghi trực tiếp DB để dựng PASS |
| Owner/session | `lib/features/auth/providers/auth_provider.dart`, `lib/features/trips/services/local_account_lifecycle_service.dart` |
| Contract tests | `test/ai_generation_test.dart`, `test/ai_assistant_test.dart`, `test/manual_budget_ui_test.dart`, `test/manual_planner_screen_test.dart`, `test/editable_saved_trip_ui_test.dart`, `test/manual_planner_end_to_end_test.dart`, `test/auth_navigation_test.dart`, `test/local_account_lifecycle_test.dart` |
| Verification entry | `tool/verify-travelgo.ps1`: `-Mode Full` chạy analyzer→full Flutter concurrency2→3 Node suites; `-Mode Targeted -TestPath ...` cho ca bị ảnh hưởng |

## 4. Khung thời gian: 4 giờ chính + tối đa 2 giờ dự phòng

T0 là lúc owner giao thực thi, không phải thời điểm lập file. Không giả định owner rảnh đúng giờ cố định. Ví dụ **bắt đầu16:45 → phần chính20:45, trần22:45**, giờ Việt Nam; lùi cả lịch nếu bắt đầu muộn.

| Khoảng từT0 | Task | Đầu ra |
| --- | --- | --- |
| 00:00–00:20 | Task 0: xác minh packet/build, bảo toàn dữ liệu | Đúng repo/source/device và quyền test; không reset |
| 00:20–01:00 | Task 1: source verification một lần | Analyzer/full Flutter/Node mới hoặc failure cụ thể |
| 01:00–02:15 | Task 2A: Guest + budget | Saved/restarted/reopened từ SQLite, actual giữ |
| 02:15–03:15 | Task 2B: Account save/update + ownership subset | Server acknowledgement/version và đúng chủ |
| 03:15–03:45 | Task 3: AI readiness/quota + script21/10 | Không đốt quota hết; readiness và live tách rõ |
| 03:45–04:00 | Handover | Evidence report và next smallest action |
| 04:00–06:00, chỉ nếu cần | Dự phòng cho task chậm/triage blocker | Không mở thêm features hoặc tự vượt guard |

Không coi40 phút chạy tests là thời gian engine bắt buộc. Full suite gần nhất khoảng 90s; phần còn lại để chốt snapshot, thu exits/logs và phân loại nếu có lỗi. Nếu không có thay đổi/source mismatch, không build/cài lại APK chỉ để có một build mới.

---

## Task 0: Chốt packet và preflight an toàn — 20 phút

**Files:** Read AGENTS/rules, scope, latest acceptance tail,5 source files ởmap; Create evidence report. Không modify source.

**Interfaces:** Consumes scope brief, actual checkout, historical hashes/C2 builds. Produces `SourcePacket + NativePreflight` ghi trong evidence report: branch/HEAD/dirty files/scoped hashes, device/package/ABI/build/hash, current owner enum/dirty flag và preservation result; không chứa credentials.

- [ ] **Step1:** Ghi quyết định hôm nay là QA core/readiness, scope giữ 2 AI modes. Giữ delta cũ như gaps; không yêu cầu owner trả lại bộ câu hỏi đã trả lời.
- [ ] **Step2:** Chạy `./tool/verify-travelgo.ps1 -Mode Status`; chụp hash của source liên quan bằng `Get-FileHash -Algorithm SHA256`. Giữ danh sách dirty ngoài task, không đọc nội dung file Word/script owner.
- [ ] **Step3:** Kiểm emulator5554 và DNY qua công cụ hiện có; xác minh package `com.travelgo.travelgo_mobile`, ABI và normal main build. Không đọc auth storage/credential fields; current owner chỉ ghi A/B/Guest.
- [ ] **Step4:** Nếu có draft RAM chưa lưu, dùng đường lưu/recovery được phép và đọc lại trước khi logout/restart. Không có đường recovery thì ghi BLOCKED cho thao tác cần restart; vẫn làm tests và các phần độc lập.
- [ ] **Step5:** Tạo evidence report với bảng trạng thái chưa tick. Nếu build khác C2 hoặc hook QA đang bật, dừng native ở bước này và nêu exact mismatch; không tự cài build cũ đè source mới.

**Done:** source packet định danh được, native target đủ điều kiện hoặc blocker cụ thể. C2/D3 được reuse đúng subset; chưa gọi fullv2 accepted.

## Task 1: Kiểm chứng source hiện tại — 40 phút

**Files:** Read/run helper và các tests trongmap; Update evidence report. Không thêm tests chỉ để mirror code hiện có.

**Interfaces:** Consumes Task 0 source hashes. Produces `VerificationResult`: command, SDK path, exit, counts, log root, unchanged-source confirmation và failed-case names nếu có.

- [ ] **Step1:** Xác minh cached SDK hiện có tại `D:/flutter/flutter`; nếu khác, dùng runtime thực đã cài và ghi đường dẫn, không install/upgrade.
- [ ] **Step2:** Chạy một lần:

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot 'D:/flutter/flutter'
```

- [ ] **Step3:** Thu tiến trình đang chạy tới final exit bằng poll ngắn; không chạy suite khác song song. PASS cần analyzer `No issues found!`, Flutter `All tests passed!`, Node fail0, exit0; ghi **count thực**, không buộc phải đúng766 nếu packet thay đổi.
- [ ] **Step4:** Đối chiếu các regression trong output/source:
  - `real planner AI consent -> preview -> confirm appends once and preserves actual; no automatic save`.
  - `Cancel during pending AI ignores the late response and keeps the manual editor usable`.
  - `modify shows before/after then applies exactly once, keeping linked actual and never saving automatically`.
  - `modify remove keeps financial ledger and records source snapshot; preview preparation never mutates input`.
  - `Guest edit persists after restart, explicit account import, offline view then B fencing`.
- [ ] **Step5:** Nếu fail, lưu raw failure, expected/actual và stage; target đúng file/case một lần để thu evidence. Không gọi target PASS là giải thích đủ full FAIL. Với bug chưa biết, viết repair packet `trigger→boundary→source+test paths→expected invariant`; không tự sửa Auth/G4 đã hết rounds.
- [ ] **Step6:** Xác nhận source hashes không đổi qua suite. Nếu đổi do task khác đang sửa thì ngừng claim exact packet; không đè thay đổi của người khác.

**Done:** checks có kết quả mới đọc được hoặc failure được phân loại rõ. Tests injected/fake AI chứng minh client behavior; không phải Gemini live hôm nay.

## Task 2: Một fixture manual đi hết Guest và Account — 135 phút

**Files:** Native thao tác UI đã có; Read planner/budget/store/repository khi cần; Update evidence report. Không SQL seed, migration, product patch hoặc QA hook mới.

**Interfaces:** Consumes Task 0 safe build, Task 1 source result. Produces `GuestPersistenceEvidence` và `AccountReadbackEvidence`: steps, screenshot/log paths, title/id/revision hoặc server version, exact totals, owner boundary; không private-data dump.

### Fixture khóa cho ngày 20

- Destination `hue`/Huế; ngày 20–21/10/2026,2 ngày,2 người; budget **4.000.000đ**.
- Guest title `V2D0_20261020_G_HUE`; Account title `V2D0_20261020_A_HUE`. Nếu đã tồn tại thì thêm suffix thời điểm và ghi exact title, không overwrite fixture cũ của owner.
- ActivityA: `hue/citadel`/Kinh thành Huế, ngày 1,09:00–10:00. ActivityB: `hue/thien-mu`/Chùa Thiên Mụ, ngày 1,11:00–12:00. Đây là thời gian QA do người dùng nhập, không chứng nhận giờ mở cửa/thời gian di chuyển.
- Estimate **100.000đ**, basis **`trip_total`**, không gắn activityA để bước xóaA không đổi tổng dự kiến.
- Actual **45.000đ**, paidOn20/10/2026, gắn activityA; ghi label QA chi phí ví dụ.
- Expected: knownEstimate100000; actualTotal45000; estimateRemaining3900000; actualRemaining3955000. Hai remaining là hai chỉ số riêng, **không trừ estimate+actual thành3.855.000đ**.

### Task 2A — Guest, 75 phút

- [ ] **Step1:** Sau preservation, vào Guest bằng UI; tìm Huế, tạo manual draft theo fixture. Xác nhận đúng destination/day/input, không gọi legacy engine hoặc AI.
- [ ] **Step2:** Thêm A/B; sửa notes/thứ tự bằng UI, xác nhận danh sách đổi đúng mà input/budget không đổi. Giữ khung giờ hợp lệ trước save.
- [ ] **Step3:** Thêm estimate/actual theo fixture; đối chiếu cả 4 tổng. Preview rồi Cancel: không lưu draft mới và editor vẫn giữ thay đổi.
- [ ] **Step4:** Mở xóa activityA, Cancel giữ A/actual; mở lại và Confirm: A biến mất nhưng actual 45000 còn với source snapshot. Không xóa actual riêng.
- [ ] **Step5:** Preview→confirm save Guest, đợi acknowledgement. Chuyển sang list đã mount và mở lại đúng row; ghi revision thực.
- [ ] **Step6:** Chỉ sau save acknowledged/không unsaved RAM, force-stop rồi mở lại. Mở draft từ list: title/Huế/2ngày/2người/4triệu/estimate100000/actual 45000 đúng; A đã xóa, B còn. Đây mới là evidence từ SQLite qua process restart.

**Done:** Guest persisted và actual giữ qua deletion/restart; không chỉ chụp editor trước khi kill.

### Task 2B — Account, 60 phút

- [ ] **Step1:** Đăng nhập email testA theo quyền owner; không đọc/paste credentials vào report. Tạo **workspace mới** từ Huế, không import Guest đang được defer.
- [ ] **Step2:** Nhập cùng fixture budget/activities/expenses, đủ start/end dates. Save explicit, ghi acknowledgement rồi từ list mở lại và dùng server-check hiện có; ghi title/id/version thực.
- [ ] **Step3:** Edit title thêm `_R2`, sửa một activity note; explicit update, đợiack. Quay list đã mount, xác nhận row cập nhật; server-check lại: cùng trip, version tăng1, actual/estimate còn đúng. Không retry create như một trip mới.
- [ ] **Step4:** Khi không còn dirty RAM, đổi A→B **hoặc** A→Guest bằng UI. Fixture A/profile A không xuất hiện trong UI của chủ mới; B hoặc Guest vẫn có empty/error/loading trung thực. Chọn một native subset để hôm nay không lặp toàn matrix; report ghi rõ subset nào chưa làm.
- [ ] **Step5:** Lưu evidence đối chiếu source/build/owner/version, không dùng screenshot title đơn lẻ làm server readback proof.

**Done:** local Guest và cloud Account được chứng minh là 2 đường lưu riêng, không claim đã kiểm Guest→Account import. Nếu account state sai hoặc actual mất: stop native mutation, giữ draft, report blocker.

## Task 3: AI readiness và chuẩn bị lượt live ngày 21 — 30 phút

**Files:** Read generation/assistant service vàmanual screen; Update evidence report/demo script. Không sửa gateway, flag, quota hoặc deploy.

**Interfaces:** Consumes Task 1 regression results, Task 2 account fixture, existing Generate/Modify evidence. Produces `AiReadiness + RequestBudget21`: ready gates, status live today, exact script ngày 21 và context/draft target an toàn.

- [ ] **Step1:** Trace hiện có: snapshot+owner/epoch stamp → consent → typed preview → Cancel/null khôngdispatch → Apply/current/canApply mới `dispatchAll(commands)`; không gọi `confirmSave` tự động. Ghi đúng functions từ filemap, không tạo service mới.
- [ ] **Step2:** Native mở Generate và assistant, chọn **Đề xuất chỉnh lịch**, xác minh có đường vào và Back/Cancel trước send giữ draft. **Không bấm Send/Generate** khi chưa xác nhận quota còn và context được phép; UI có nút không chứng minh endpoint live.
- [ ] **Step3:** Mặc định ghi `AI_LIVE_TODAY=DEFERRED_QUOTA`, căn cứ ledger A/B đã hết lượt 20/10. Không gửi request chỉ để dò quota; không đổi sang identity/tài khoản khác nhằm lách giới hạn. Không có quyền quota metadata thì giữ unknown và lên lịch21.
- [ ] **Step4:** Ghi script **ngày 21**, cùng account/fixture có quyền:
  1. Kiểm remaining/global cap từ metadata/cơ chế đã được phép nếu có; source Account limit1–3/ngày, không mặc định lúc nào cũng đủ 3. Reset server theo `Asia/Ho_Chi_Minh`, không theo đổi ngày thiết bị.
  2. Request1 Generate cho Huế2 ngày; preview chưa mutate; Apply một lần; actual 45000 không đổi; explicit save→server readback.
  3. Request2 Modify, chỉ đổi activity ngày 1, giữ khoản đã chi; preview differences→Apply; kiểm actual ledger trước/sau, explicit save/readback.
  4. Cancel được chứng minh bằng regression hôm nay và historical native đúng packet nếu còn phù hợp; nếu cần fresh live Cancel thì dùng lượt thứ3 **chỉ khi cap còn**, hoặc chuyển sang ngày khác. Không hứa cả GenerateCancel+Apply+ModifyCancel+Apply trong 4 request cùng account/ngày.
- [ ] **Step5:** Ghi trạng thái V2-04/05 là `HISTORICAL_SUBSET / LIVE_FINAL_PACKET_PENDING`, không PASS từ tests. Nếu remaining thấp hơn2 thì request budget21 phải điều chỉnh, không hạ tiêu chí2 AI modes đã chọn.

**Done:** không lãng phí ngày 20 chờ quota, và sáng 21 có fixture+script+regressions để gọi thật có mục tiêu. AI errors tiếp tục manual; không giả model response.

## 5. Triage và sử dụng 2 giờ dự phòng

Đây là ngân sách thời gian, không tự mở quyền source repair hoặc thêm round:

| Tình huống | Việc làm tiếp trong ngày | Điều không tự làm |
| --- | --- | --- |
| Core/AI checks đạt, quota hết | Hoàn tất report/fixture/script21; kết thúc sớm nếu đủ | Chạy lại suite hoặc tạo account để có lượt |
| Chậm UI/build/device | Dùng buffer để thu kết quả/preflight, hoặc dùng1 thiết bị cho core và ghi thiết bị khác pending | Reinstall/clear/reset để bỏ qua vấn đề |
| Bug native mới có trigger rõ | Tối đa30 phút xác định boundary; đề xuất1 repair packet với source/test/evidence files, Red/Green assertions và budget còn lại | Guess patch, mở rộng Auth/SDK/server, hoặc tự sửa nhiều feature |
| Fullsuite fail/target pass | Giữ cả 2 evidence, tìm stage completion/IO/owner; chỉ định test gắn invariant | Gán flaky, bỏ assertion, tăngsleep để xanh |
| Mất actual/leak/crossowner/duplicate | Dừng mutation, bảo toàn state và log an toàn; blocker ưu tiên đầu21/10 | Làm tiếp demo cho đẹp hoặc báo READY |

Nếu owner giao thực thi một repair packet sau finding: giữ test Red trước patch, sửa tối thiểu đúng lớp, target Green rồi kiểm theohelper; runtime reload/rebuild nếu có Dartchange. Không yêu cầu Red giả cho những tính năng đã có và chưa tìm thấy bug. Commit/push không phải bước bắt buộc của ngày này.

## 6. Handover và self-review

- [ ] Report có **Changed / Why / Testing / Problems / Lesson Candidate**, source/build/date, command/exits/counts/logs và bước native thực đã chạy; expected/actual có số tiền/version cụ thể.
- [ ] Phân biệt historical766/89 với run mới; tests AI giả với Gemini thật; Guestdisk vớiAccountserver; localApply vớicloudSave.
- [ ] Giữ owner-facing explanation: người dùng thao tác → Provider → local hoặc RPC → acknowledgement → list/readback. Xóa activity có actual không đồng nghĩa xóa khoản đã chi.
- [ ] Map hôm nay: V2-01/02/03/07/08/09 core; V2-10 native subset+tests; V2-11 reuse C2/D3 trong đúng build; V2-13checks. V2-04/05 live ngày 21; V2-12offlineP1 deferred; V2-14/15 bản giao cuối ngày 24/25.
- [ ] Self-review plan: không có speculative productfix, không thêm feature, không nhân audit thành cảngày, không vượtquota, không rewriteAuth; every task có input/output và expected result.
- [ ] Chỉ tạo report khi thực thi bắt đầu; không tạo evidence rỗng rồi gọi là đã kiểm. Task 0–3 trong file này vẫn unchecked cho tới khi có quan sát thực.

**Execution handoff:** đề xuất **Native, làm tuần tự trong chat hiện tại**, vì cùng một editor/account/draft và state thiết bị; chia agent dễ đụng state và nhân chi phí. Nếu owner chọn thực thi, đọc plan+scope rồi bắt đầu Task 0 trong phạm vi được giao; không tựspawn agents, không yêu cầu bỏ phiếu lại các routine choices đã chốt. Superpowers dùng hôm nay theo lời yêu cầu trực tiếp; không coi lời gọi này là quyền tự dùng trong task/session tương lai.

### Bàn giao của lượt lập plan này

- **Changed:** tạo plan này và copy scope nguyên byte vào repo để người thực thi đọc đủ brief.
- **Why:** dành ngày 20 để đóng core và chuẩn bị AI, tận dụng evidence C2/D3 mới; không hứa liveAI khi quota đã hết.
- **Testing:** đọc source/signatures/budget math/asset IDs, branch/HEAD/status và tail historical logs; kiểm file plan / scope copy sau khi ghi. **Không chạy mới analyzer/tests/build/native/AI trong lượt lập plan.**
- **Problems:** quota hiện hành/device state chưa live-check; scope deltas còn phải được ghi nhận khi giao thực thi; guard G4 cũ không tự mở; chưa chứng minh integratedGenerate→Modify→save trên finalphone.
- **Lesson Candidate:** quota được dùng khi có usable result dù người dùngCancel preview → lịch QA4 kết quả có thể vượt accountcap3 → tách regression/no-send checks,2livecalls có mục tiêu và requestbudget theo ngày server.
