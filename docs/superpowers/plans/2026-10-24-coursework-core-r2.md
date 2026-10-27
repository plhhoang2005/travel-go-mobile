# TravelGO Core R2 Implementation Plan

> **For agentic workers:** ĐÃ ĐƯỢC OWNER DUYỆT; thực thi từng task bằng checkbox. Khi owner cho phép dùng Superpowers để thực thi, chọn executing-plans hoặc subagent-driven-development theo phương thức owner chọn. Không tự dùng skill cho session sau, không tự commit/deploy.

> **Cập nhật owner 25/10/2026:** Antigravity phải dùng Superpowers phù hợp khi code, gồm C3 và các task coding tiếp theo; Codex ghi rõ yêu cầu trong handoff. Chỉ thị thường trực này thay trạng thái Superpowers OFF cho Antigravity coding ở các checkpoint trước. Codex review/planning vẫn chỉ dùng khi được yêu cầu; scope và các quyền khác giữ nguyên.

**Goal:** Có app core theo tài khoản chạy độc lập với AI/engine/map; giữ dữ liệu cũ và quyền admin.

**Architecture:** Tách UI trước code riêng, giữ adapter input tạm ở C1 rồi tách ở C2. Recovery và ngân sách dùng các service hiện có; chỉ sửa gap được tái hiện.

**Tech Stack:** Flutter/Dart + Provider/Dio, backend và scripts hiện có.

**Spec:** [Phạm vi](../../../.agent/product-scope.md), [thiết kế AI](../../../.agent/ai-planner-design.md), [master R2](2026-10-24-coursework-r2.md). Baseline và mọi Global Constraints/Review Focus trong master áp dụng ở đây.

Các signatures ghi NEW là quyết định đã duyệt cho implementation, không phải symbol đã tồn tại. Tests/fixtures mới chỉ được tạo khi task được duyệt. Chưa có bước nào được thực thi. RED phải fail ở đúng hành vi đang sửa, không phải do compile error ngẫu nhiên. Nếu regression đã PASS, giữ test và không sửa thêm.

**Tiến độ mới nhất 24/10/2026:** C1 source/automated review ACCEPT; F01/F02 CLOSED, Full exit 0 (Flutter1125/1125, Node91/91, analyzerPASS). [Evidence](../../phase-3/C1_CODEX_REVIEW_R2_20261024.md). Runtime NOT RUN; C2 chưa bắt đầu. Checkboxes dưới đây là hướng dẫn thực thi gốc, không thay báo cáo trạng thái mới này; reviewer không chứng nhận lại RED lịch sử hoặc commit chưa làm.

## C1 — Điều hướng đúng scope, tạo chuyến không gọi engine

**Files — Modify:** `lib/features/navigation/presentation/screens/main_navigation_shell.dart`, `lib/features/home/presentation/screens/main_home_screen.dart`, `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`, `manual_planner_entry_screen.dart`, `manual_planner_screen.dart`, `lib/features/explore/presentation/screens/destination_detail_screen.dart`, `lib/features/profile/presentation/screens/profile_screen.dart`, `lib/features/trips/presentation/screens/my_trips_screen.dart`.
**Test — Create:** `test/coursework_navigation_test.dart`. Modify các navigation/destination entry tests bị đổi flow.

**Interfaces:** consume `TripProvider.currentRequest/currentMetadata/workspaceGeneration/canReplaceWorkspace` và `ManualTripFactory.fromInput(PlanTripRequest, TripMetadataV1) -> EditableTripDocumentV2`; produce bốn tab Trang chủ/Khám phá/Chuyến đi/Cá nhân, CTA đi manual entry. Giữ adapter input hiện có tới C2; không gọi `submitPlan` để mở editor. Không tạo route mới chưa cần.

- [ ] RED: `opens_manual_without_engine`, `profile_tab_after_favorites_removed`, `preserves_unsaved_editor_on_cancel_replace`. Inject engine spy và network spy; asserts: editor thấy đúng destination, `engineCalls==0`, `mapCalls==0`; profile mở đúng tab sau bỏ index 3 cũ; hủy thay editor giữ digest. Tìm mọi `initialIndex` callers, không chỉ sửa label/tab count.
- [ ] Run: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/coursework_navigation_test.dart -FlutterRoot D:/flutter/flutter`; trước sửa phải FAIL ở route/engine call cũ.
- [ ] GREEN: đổi CTA/tab/callers; bỏ UI map/favorites/guest-import/Decision Engine và copy cũ, giữ budget/timeline/AI. Giữ logic save account không cần guest UI. Không xóa modules trong C1.
- [ ] Verify: chạy lại command trên PASS, analyzer+Full khi chốt. Không mở live service. Review Focus không lẫn editor/account.
- [ ] Review/checkpoint: diff chỉ C1; proposed commit `refactor(navigation): align coursework flows`; stage/commit chỉ theo quyền owner, còn không lưu checkpoint chưa commit.

## C2 — Tách input khỏi engine rồi dọn code chỉ dùng riêng

**Depends:** C1.
**Create:** `lib/features/trip_planner/providers/planner_input_provider.dart`, `test/planner_input_provider_test.dart`.
**Modify:** main.dart; callers input trong C1; `lib/features/trip_planner/providers/trip_provider.dart` và `lib/features/trips/services/legacy_trip_copy_adapter.dart` chỉ nếu legacy reader cần adapter. `pubspec.yaml`, `pubspec.lock`, manifest/Info.plist là diff riêng được review trước apply.
**Remove candidates:** `lib/features/map/`, `lib/features/favorites/`, gateway/service/UI engine chỉ riêng runtime đã hết caller; guest import UI/service riêng; tests map/favorites/engine cũ không còn feature. Không delete file chỉ dựa tên/thư mục.

**Interfaces NEW:** `PlannerInputProvider extends ChangeNotifier`: constructor nhận request/metadata ban đầu; getters `PlanTripRequest currentRequest`, `TripMetadataV1 currentMetadata`, `int workspaceGeneration`, `bool hasSelectedDestination`; methods `void updateRequest(PlanTripRequest value)`, `void setCalendarRange(String startDate,String endDate)`, `void setDuration(int days)`, `void reset()`. Catalogue selection metadata được cập nhật qua `void setDestination({required String? id, required String name})`; user-defined nhận id=null. Metadata/request được freeze và giữ ngày thống nhất theo TripDatePolicy. Provider không sở hữu remote save, auth hoặc backend health. ManualPlannerProvider sở hữu dirty/save/replace guard; xóa dependency activeGuestDraft của entry thay bằng input generation + manual editor stamp.

- [ ] RED: `input_generation_invalidates_pending_entry`, `input_has_no_engine_transport`, `old_trip_read_survives_map_removal`; ghi test thay input khi entry pending → không mở request cũ, document legacy v1/v2 giữ title/dates/actual, no engine/map calls. Input reset không tự xóa saved trip.
- [ ] Run targeted input + `test/saved_trip_snapshot_test.dart` + `test/editable_trip_codec_test.dart`; ca legacy phải PASS trước và sau, ca entry mới FAIL trước.
- [ ] GREEN: tách input; chuyển callers; tìm toàn repo runtime imports của module cần xóa, chuyển helper catalogue chung sang explore nếu cần. Giữ read-only legacy adapters/fixture. Remove providers/obsolete tests sau callers; giữ auth lifecycle/cache. Bỏ location packages/permissions chỉ khi usage=0; giữ INTERNET, app_links, auth URL scheme. Không nâng SDK/deps khác.
- [ ] Verify: targeteds PASS, Full PASS sau dọn test runner. Search `features/map`, `features/favorites` không còn runtime imports. Build Android khi config/dependency diff được duyệt; auth callback scheme còn. Legacy screen không còn CTA map/decision nhưng đọc trip được. iOS build không môi trường → NOT RUN.
- [ ] Review/checkpoint: liệt kê chính xác file/dependency/quyền bị gỡ và helpers giữ; commit đề nghị `refactor(core): remove retired coursework features` theo quyền hiện có. Không drop tables/rewrite migration/uninstall/clear data.

## C3 — Recovery ownership, cancel và cleanup

**Modify:** `lib/features/auth/providers/password_recovery_provider.dart`, `auth_provider.dart`, `lib/features/auth/services/recovery_intent_store.dart`; lifecycle chỉ khi trace liên quan.
**Test:** `test/password_recovery_authority_test.dart`, `password_recovery_callback_race_test.dart`, `password_recovery_cleanup_test.dart`.
**Interfaces:** giữ APIs recovery hiện có; mọi callback/bootstrap/marker/SDK op có cùng intent ownership. Cancel đồng bộ thu hồi authority trước cleanup await. Normal login phải nhận cleanup success trước account grant. Không thêm public API nếu internal guard đủ.

- [ ] RED: chuyển R1/R3/R4/R5/R8/R9/R10 trong review R1 thành regression ổn định dùng Completer giữ marker write/read, SDK exchange và cleanup. `cancel_pending_exchange_then_login_b_keeps_b`: callback A muộn không ready A, session cuối B, marker B nguyên; `cleanup_failure_blocks_account_grant` nhưng UI có retry. Không assert false từ fixture UUID/JWT lỗi.
- [ ] Run các file test trên; phân biệt actual failing assertion với positive control. Nếu already PASS ghi đóng bằng actual HEAD.
- [ ] GREEN: một ownership token xuyên async store+SDK queue; recheck sau await; serialize cleanup theo owner, không signout B; retry UI còn khi clear/signOut fail. Giữ server authority.
- [ ] Verify: control happy path, guest/cancel, A→B và cold callback đều PASS; full auth/Flutter checks. Không log/read SDK token thật. Không gửi email live trong regression.
- [ ] Review/checkpoint: map từng finding cũ sang test mới/exact result; proposed `fix(auth): fence recovery cancellation and cleanup`. Không tuyên bố toàn recovery xong trước C4/live.

## C4 — Submit/expiry/revalidation, OTP và hồ sơ

**Depends:** C3 cho recovery. OTP/profile local tests không phụ thuộc email live.
**Modify:** password_recovery_provider/service/state/gate, login/register/OTP/forgot/reset screens khi regression cần; profile screen cho thông tin cơ bản.
**Test:** `test/password_recovery_flow_test.dart`, `password_recovery_cold_start_test.dart`, `password_recovery_gate_test.dart`, `otp_server_authority_test.dart`, `auth_navigation_test.dart`, `profile_preferences_test.dart` (giữ asserts liên quan, bỏ UI preferences ngoài scope nếu đã quyết định gỡ).
**Interfaces:** signUp→Supabase verifyOTP thật; recovery link hiện có; mọi password update phải có unexpired intent + server revalidation + claimed slot trước await. Không OTP recovery flow thứ hai.

- [ ] RED: `double_submit_dispatches_one_password_update` chặn write-ahead hai submit; `expired_intent_before_dispatch_has_zero_put`; `cold_revoked_session_never_ready` server GET từ chối; OTP sai/no server không cấp user; profile email không bị client tự đổi trái flow xác thực. R2/R6/R7 cũ có test/control.
- [ ] Run targeted từng file chứa regression; expected một PUT ở double-submit, zero PUT expired/denied; thử boundary TTL theo model hiện có, không hardcode TTL mới.
- [ ] GREEN: claim slot đồng bộ; kiểm TTL/identity trong queue ngay trước dispatch; cold revalidate server. Sửa UI error/retry cần thiết, không thay Supabase SDK/version/native URLs tùy tiện.
- [ ] Verify local Full/auth suites; acceptance riêng signUp→email OTP→login→logout, password reset cold/warm→login bằng password mới, error/expired. Thiếu SMTP/redirect/live account thì LIVE BLOCKED không chặn C5. Build/restart sau thay native config nếu có quyền.
- [ ] Review/checkpoint: sáu findings recovery có bảng OPEN/CLOSED/test/head; suggested `fix(auth): validate recovery dispatch and otp authority`. Chưa có evidence thì không gọi hoàn thiện 100%.

## C5 — Manual, ngân sách và save/read/update/delete

**Files:** `lib/features/trip_planner/{providers/manual_planner_provider.dart,services/manual_trip_factory.dart,services/budget_calculator.dart,services/editable_trip_mutator.dart,services/editable_trip_validator.dart}`; input/activity/expense/budget/save UI; `lib/features/trips/{services/editable_trip_repository.dart,services/editable_trip_service.dart,models/editable_trip_codec.dart,presentation/screens/my_trips_screen.dart}`.
**Tests:** manual factory/end_to_end/budget UI, budget calculator, editable codec/repository/service/saved trip UI có sẵn; NEW `test/coursework_trip_roundtrip_test.dart`.
**Interfaces:** giữ `BudgetCalculator.calculate(EditableTripDocumentV2)->BudgetTotals`, previewSave/confirmSave/retrySave và repository save/read/update/delete. `destinationId=null,destinationName='Phú Yên'` phải được factory giữ; hiện factory chỉ giữ name khi ID hợp lệ, nên đây là gap cụ thể cần sửa client/server thay vì fake slug.

- [x] RED/control và money vector: self-entered destination giữ tên qua factory→save→read; unknown khác0. Evidence26/10 ở bàn giao C5, phân biệt3 lỗi fixture ban đầu với3 gap thật.
- [x] Run calculator/factory/new roundtrip và các suite liên quan; arithmetic đúng được giữ nguyên.
- [x] GREEN: giữ tên qua các lớp; actual/snapshot và frozen request/retry giữ đạt; không viết lại account lifecycle.
- [x] Verify source/automated: Full1100 Flutter/91 Node/analyzer sạch, SQL contract disposable PASS có bootstrap adapters được công khai; product editor yêu cầu tài khoản. Chưa cloud/native acceptance hoặc fresh migration-chain deploy PASS.
- [x] Self-review/checkpoint: [bàn giao C5](../../phase-3/COURSEWORK_C5_CODEX_IMPLEMENTATION_20261026.md), [tự review](../../phase-3/C5_CODEX_REVIEW_20261026.md). Chưa commit; suggested commit không phải lệnh được tự thực hiện.

## C6 — Admin user/account và khám phá

**Files:** admin account providers/services/screens, `supabase/functions/admin-control/gateway.mjs`; explore/search/detail/public catalogue provider; profile admin entry. SQL chỉ additive khi có gap.
**Tests:** `admin_account_*`, `auth_role_security_test.dart`, `admin_navigation_test.dart`, `public_catalogue_consumers_test.dart`.
**Interfaces:** giữ existing `AdminAccountService.listUsers/getUser/mutate` và server account checks; customer không được mutate admin dù gọi API trực tiếp. Search theo data hiện có, không hardcode 12/72.

- [x] RED/control và GREEN C6: owner/role/epoch, query/filter/page, mutation/readback/retry/resume, gateway/SQL và discovery động có regressions; giữ guards và scope.
- [x] Account cuối201 Flutter/19 Node, SQL6 vectors; final-schema account/control/concurrency/guards/C5 roundtrip PASS local. Không dùng cloud thay local.
- [x] UI vào Người dùng, bỏ Tổng quan/promote-demote entry theo plan đã duyệt; giữ backend guards và catalogue/lịch sử cho C7.
- [x] Full cuối analyzer sạch, Flutter1123/1123, Node91/91; snapshot434 files0 drift. Live lock/unlock/native vẫn NOT RUN.
- [x] Codex self-review/bàn giao: [C6 implementation](../../phase-3/COURSEWORK_C6_CODEX_IMPLEMENTATION_20261026.md), [review](../../phase-3/C6_CODEX_REVIEW_20261026.md). Chưa commit hoặc independent review; không suy source PASS thành live ACCEPT.

## C7 — Admin publish → User refresh

**Depends:** C6; cần cho A2.
**Files:** `lib/features/admin/providers/admin_catalogue_provider.dart`, admin forms/services/publication UI; public catalogue repo/parser/cache/sync; `supabase/functions/admin-publication/{gateway,bundle}.mjs`.
**Tests:** `test/admin_catalogue_publish_flow_test.dart`, `admin_catalogue_provider_test.dart`, `catalogue_sync_coordinator_test.dart`, `public_catalogue_consumers_test.dart`; admin Publication mode.
**Interfaces:** save ACK→preview revision R→publish R→consumer atomic snapshot. Giữ `savedNotPublished` khi publish fail; source builder A2 tiêu thụ exact version/digest này.

- [ ] RED/control: dynamic fixture destination/place không thuộc seed, command ack→publish→User refresh thấy record; preview fail giữ savedNotPublished; retry không create trùng; hide không làm trip đã lưu biến mất.
- [ ] Run targeted provider/flow + `./tool/verify-flutter-admin.ps1 -Mode Publication -FlutterRoot D:/flutter/flutter` theo runbook flags/fixture, required integration không skip. Source đã nối pipeline không cần viết lại.
- [ ] GREEN: chỉ vá gap producer/schema/consumer được chứng minh, giữ last-known-good atomic snapshot khi refresh lỗi. Không tự publish live từ việc sửa code.
- [ ] Verify Public catalogue/SQL dynamic integration, không trộn bản cũ/mới; Account customer denied và admin positive control. Full khi chốt source.
- [ ] Review/checkpoint: suggested `fix(catalogue): verify admin to customer publication`; local PASS và live admin publish/refresh ghi riêng. Sau đây mở A1/A2; W1 có thể kiểm sớm theo quyền owner.

## Handover Core

Cho mỗi task ghi Changed/Why/Testing/Problems/Lesson Candidate, exact HEAD và commands/exits/logs, runtime NOT RUN/BLOCKED. Đã có implementation không đồng nghĩa còn cần sửa. Chưa chạy bất kỳ checklist nào trong lượt kế hoạch; master R2 đã được owner duyệt; phần triển khai chưa bắt đầu.


## Nhật ký duyệt — 24/10/2026

Owner đã trả lời **“duyệt”** cho R2 trong chat. Phê duyệt bao gồm master và ba plan con, không phải nghiệm thu code hoặc cấp quyền thao tác live ngoài phạm vi. Các checkbox vẫn chưa tick. Handoff đầu tiên là C1 theo workflow Antigravity implement/Codex review.


## Tiến độ C2 — review ngày 24/10/2026

C2 có implementation candidate trong dirty tree, **REQUEST CHANGES**: C2-F01 ngày/preset không nhất quán; C2-F02 null không clear destination; C2-F03 production còn dual-write TripProvider cũ. Fresh suite 997 Flutter/91 Node PASS nhưng probe độc lập 4 FAIL + 1 control PASS. [Review chi tiết](../../phase-3/C2_CODEX_REVIEW_20261024.md). C1 vẫn được chấp nhận ở revision đã review trước đó; không áp approval ấy cho source C2 mới. C3 chưa bắt đầu; chờ sửa/re-review C2, không xin lại scope đã duyệt.


## Tiến độ C2 re-review R2 — 25/10/2026

C2-F01/F02 CLOSED; dual-write của F03 đã sửa và original probes5/5 PASS. F03 còn root/caller legacy wiring; mới F04 proposal native patch không apply-check được. Full reviewer analyzer PASS, Flutter1000/1000, Node91/91; verdict C2 tổng **REQUEST CHANGES**, chưa C3. [Evidence](../../phase-3/C2_CODEX_REVIEW_R2_20261025.md). Source fixes không cần làm lại; dọn wiring và chuẩn hóa proposal trước bước duyệt/apply native.


## Owner duyệt hoàn tất C2 — 25/10/2026

Owner trả lời “duyệt” sau review R2: tiếp tục dọn wiring F03 và cleanup dependency/native theo GeoPoint. [Handoff triển khai](../../phase-3/COURSEWORK_C2_FINALIZE_HANDOFF_20261025.md) kèm patch mới apply-check PASS; chưa apply/build/source change trong lượt ghi nhận này. Giữ C2 IN PROGRESS, không tick complete hoặc mở C3 từ phê duyệt. Không cần xin lại scope cleanup đã duyệt; live/merge/key/model/quota/billing giữ nguyên boundary.

## Tiến độ C2 final review — 25/10/2026

**C2 ACCEPT: SOURCE/AUTOMATED/ANDROID DEBUG BUILD**, F01–F04 CLOSED trên dirty candidate cùng HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`. Reviewer fresh analyzer PASS, Flutter1001/1001, Node91/91, original probes5/5 + actual-root probe1/1 PASS; Android build exit0, merged manifest không location, giữ network/auth callback. Lockfile gỡ16 package, không thêm/đổi version còn lại. [Review cuối và giới hạn](../../phase-3/C2_CODEX_REVIEW_FINAL_20261025.md). Source chưa commit; device/iOS/live NOT RUN. C3 chưa bắt đầu, là task kế tiếp; checkpoint này thay trạng thái REQUEST CHANGES/pending C2 ở các snapshot trước, không chứng nhận các checkbox RED/commit lịch sử.

## Owner duyệt C2 / chuẩn bị giao C3 — 25/10/2026

Owner trả lời “duyệt” sau final review C2 và bước tiếp theo C3. Ghi nhận C2 được duyệt trong giới hạn evidence nêu trên; [handoff Antigravity C3](../../phase-3/COURSEWORK_C3_ANTIGRAVITY_HANDOFF_20261025.md) đã chuẩn bị theo plan hiện có. **C3 READY FOR IMPLEMENTATION, chưa sửa app trong lượt chuẩn bị này**; Codex giữ vai trò planning/review, Antigravity implement. C3 chỉ F01/F02/F04 recovery ownership/cancel/cleanup; C4 submit/expiry/revalidation/OTP vẫn deferred. Không tự gửi sang chat khác, commit/push/merge hoặc thao tác live/device từ phê duyệt này. Superpowers OFF.

## Tiến độ C3 independent review — 25/10/2026

**C3 REQUEST CHANGES**, candidate ba auth/store files và ba permanent tests, HEAD base vẫn `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty. Fresh reviewer analyzer PASS, Flutter1011/1011, Node91/91, scoped original C3 probes10/10 PASS; sáu overlap/error probes FAIL, control PASS; hai production-store confirmations cũng FAIL. Chưa đóng toàn bộ F01/F02/F04: cancel chưa thu hồi SDK authority ngay/cleanup muộn logout B, stale write làm mất marker B trong controlled I/O contract, cleanup gate qua Guest/signOut failure chưa đầy đủ và first marker write failure kẹt sending. [Review và evidence](../../phase-3/C3_CODEX_REVIEW_20261025.md). Antigravity sửa tiếp **chỉ C3**, dùng Superpowers theo chỉ thị owner hiện hành; C4 chưa bắt đầu. Reviewer không sửa app; source chưa commit, device/live NOT RUN.

## Owner duyệt correction C3 — 25/10/2026

Owner trả lời “duyệt” sau review C3 REQUEST CHANGES: cho phép Antigravity sửa **C3-F01–F04**, bắt buộc dùng Superpowers. [Prompt correction C3](../../phase-3/COURSEWORK_C3_FIX_ANTIGRAVITY_HANDOFF_20261025.md) đã chuẩn bị; Codex chỉ cập nhật tài liệu, chưa sửa app. **C3 vẫn REQUEST CHANGES / correction authorized**, không phải ACCEPT; C4 chưa bắt đầu. Giữ scope/quyền và repair guard hiện hành, không reset budget, commit/push/live/device từ approval này. Candidate mới cần Codex re-review.

## Tiến độ C3 correction re-review R2 — 25/10/2026

**C3 REQUEST CHANGES** trên candidate thực. 19 reviewer probes cũ PASS; F03/F04 đạt các ca đã kiểm, F01/F02 còn biến thể cleanup/repair race. Mới F05: analyzer3errors+1info, targeted77PASS/1assertFAIL/2loadFAIL; Full dừng analyzer, không có Flutter Full PASS hiện tại. Node độc lập91/91 PASS. New variants/confirmation6FAIL+1controlPASS; ba hash source/tests khác report author, 376files giữ nguyên trong review. [Review R2 và exact evidence](../../phase-3/C3_CODEX_REVIEW_R2_20261025.md). Antigravity sửa tiếp đúng C3 bằng Superpowers, giữ fixes đã đạt và repair guard; C4 chưa bắt đầu. Codex chỉ review/docs, chưa sửa app/commit/live/device.

## Owner duyệt sửa C3 sau re-review R2 — 25/10/2026

Owner trả lời “duyệt”: cho phép correction **C3-F01/F02/F05**, giữ F03/F04 và các ca đã GREEN. [Prompt Antigravity R2](../../phase-3/COURSEWORK_C3_FIX_R2_ANTIGRAVITY_HANDOFF_20261025.md) đã chuẩn bị, bắt buộc dùng Superpowers; thứ tự candidate/compile → cleanup ownership → marker ordering → fresh verification/hashes. Đây là approval sửa, **C3 vẫn REQUEST CHANGES / correction authorized**, C4 chưa bắt đầu. Codex chỉ cập nhật tài liệu; không sửa app hoặc tự cấp thêm repair budget/live/merge/device permissions. Candidate mới phải re-review.

## Tiến độ C3 re-review R3 — 25/10/2026

**C3 REQUEST CHANGES**: fresh analyzer PASS, Flutter1029/1029, Node91/91, reviewer probes26/26 PASS; 8/8 hash khớp bàn giao, 376files không đổi trong review. F05 CLOSED, F03/F04 giữ đạt; F01/F02 còn ownership nhiều intent: cancel A phá recovery B mới cùng user (confirmed production-store fixture), repair B ghi đè/xóa marker C. R3 probes2FAIL+1controlPASS và1confirmationFAIL. [Review R3](../../phase-3/C3_CODEX_REVIEW_R3_20261025.md). Không sửa lại các ca đã GREEN; không mở C4 hoặc tự cấp thêm repair budget. Codex chỉ review/docs, source chưa commit, device/live NOT RUN; Antigravity coding dùng Superpowers.

## Owner duyệt sửa phần còn mở sau R3 — 25/10/2026

Owner trả lời “duyệt”: correction **C3-F01/F02** được giao tiếp; giữ F03/F04/F05 và 26 probes đã đạt. [Prompt Antigravity R3](../../phase-3/COURSEWORK_C3_FIX_R3_ANTIGRAVITY_HANDOFF_20261025.md) yêu cầu Superpowers và xử lý ownership/ordering chung, bảo vệ recovery successor và marker tại commit. Codex chỉ tạo tài liệu, chưa sửa app. **C3 vẫn REQUEST CHANGES / correction authorized**, C4 chưa bắt đầu; không tự reset repair guard hoặc mở quyền live/merge/native/device. Candidate mới cần review độc lập.

## Tiến độ C3 re-review R4 — 25/10/2026

**C3 REQUEST CHANGES**: fresh analyzer PASS, Flutter1032/1032, Node91/91, probes30/30 PASS chạy tuần tự sau Full; 6/6 hash khớp, 376files giữ nguyên. F01 đạt các ca đã kiểm; F02 còn restore C hồi sinh C sau Hủy; F03 REOPENED do cancel mất cleanup owner khi marker clear success + SDK logout fail, retry no-op (confirmed production-store fixture). R4 probes2FAIL+1controlPASS và1confirmationFAIL. [Review R4](../../phase-3/C3_CODEX_REVIEW_R4_20261025.md). Giữ F01/F04/F05 và các ca đã GREEN, không thêm write bù tầng tiếp theo; không mở C4/reset repair guard. Codex chỉ review/docs, chưa sửa app/commit/live/device; Antigravity coding dùng Superpowers.

## Owner yêu cầu Codex implement C3 — source/automated verified 25/10/2026

Owner yêu cầu trực tiếp “hay bạn sửa c3 đi”, cho phép Codex implement riêng task này. **C3 SOURCE/AUTOMATED PASS, self-review**, chưa independent/native/live acceptance. Marker FIFO thay toàn bộ write bù; cleanup owner giữ riêng khi lỗi; SDK owner gắn tại exchange, cancel/retry dùng credential queue và callback bị chặn khi đang drain. [Bàn giao Codex](../../phase-3/COURSEWORK_C3_CODEX_IMPLEMENTATION_20261025.md): targeted126/126 PASS; Full analyzer sạch, Flutter1039/1039, Node91/91, exit0; snapshot377files giữ nguyên. Tests race đổi sequencing theo FIFO nhưng giữ invariant/negative assertions; không báo raw30 harness cũ vẫn chạy nguyên trạng. C4 chưa bắt đầu; chưa commit/push/live. Hot reload bị automatic approval review từ chối vì không có app/DTD và quyền runtime cụ thể; runtime NOT RUN. Chính sách Superpowers của Codex không đổi.

## Owner duyệt Codex implement C4 — source/automated verified 25/10/2026

Owner duyệt [plan C4](../../phase-3/COURSEWORK_C4_IMPLEMENTATION_PLAN_20261025.md) và cho phép Codex code riêng lần này. **C4 SOURCE/AUTOMATED PASS, self-review**: submit slot trước await; TTL/server identity revalidation ngay trong credential action trước PUT; cold verification/retry; expired ready owner giữ cho cleanup. OTP lifecycle và profile có evidence, production OTP/profile không cần viết lại. [Bàn giao C4](../../phase-3/COURSEWORK_C4_CODEX_IMPLEMENTATION_20261025.md): targeted220/220, Full analyzer sạch/Flutter1080/1080/Node91/91, exit0; snapshot378 files không drift. C3 regressions giữ đạt; sáu findings CORE_REVIEW_R1 CLOSED ở mức source/automated. Chưa independent/native/email acceptance; không hot reload/install/live/commit/push/merge, chưa bắt đầu C5. Không dùng Superpowers cho Codex; chỉ thị thường trực Antigravity vẫn giữ.


## C4 review bổ sung bởi Codex — REQUEST CHANGES, 25/10/2026

Owner yêu cầu Codex review lại C4. [Review C4](../../phase-3/C4_CODEX_REVIEW_20261025.md): **C4-F01 OPEN [P2]** — GET preflight lỗi mạng rồi ghi restore-ready thất bại khiến UI ready nhưng intent RAM còn updating, lần bấm tiếp bị chặn dù PUT0. Đã tái hiện và xác nhận bằng RecoveryIntentStore production với SharedPreferences platform fixture trảfalse. Fresh Full vẫn analyzer sạch/Flutter1080/1080/Node91/91, exit0; thiếu coverage tổ hợp lỗi trong permanent suite. Source378 files khớp candidate C4,0 drift. Lượt này chỉ review/docs/probes ignored, chưa sửa app hoặc bắt đầu C5, chưa runtime/email/commit/push/live. Đây là review bổ sung của cùng Codex, không gọi independent cross-agent acceptance; giữ repair guard hiện hành.


## Owner duyệt Codex sửa C4-F01 và review — PASS, 25/10/2026

Owner giao “sửa c4 sau đó review”. **C4-F01 CLOSED; C4 source/automated và self-review PASS.** [Bàn giao sửa](../../phase-3/COURSEWORK_C4_FIX_CODEX_REPORT_20261025.md) và [review R2](../../phase-3/C4_CODEX_REVIEW_R2_20261025.md): chỉ sửa RAM phase/ownership trong recovery provider, thêm8 permanent regressions dùng production store. Lỗi restore marker không còn khóa retry; vẫn write-ahead trước GET/PUT, TTL/cancel/successor giữ đạt, cold updating vẫn uncertain. Full cuối analyzer sạch/Flutter1088/1088/Node91/91, exit0; focused8/8 và nguyên probes R1 giữ hash5/5 PASS, snapshot379 files không drift. Targeted C3/C4 đạt228/228 trước hai braces cuối trong fixture; Full/focused là evidence bytes cuối. Không phát hiện finding mới trong diff sửa; đây là self-review của Codex, chưa independent/native/email acceptance. Không Superpowers cho Codex, không reset repair guard hoặc thay permanent workflow; chưa commit/push/merge/live, chưa bắt đầu C5.

## Owner duyệt Codex triển khai C5 — 26/10/2026

**C5 source/automated và SQL contract local PASS; self-review.** Owner duyệt plan C5 trong chat và yêu cầu tiếp tục. [Bàn giao C5](../../phase-3/COURSEWORK_C5_CODEX_IMPLEMENTATION_20261026.md), [review C5](../../phase-3/C5_CODEX_REVIEW_20261026.md): giữ tên tự nhập/null-ID và tên lịch sử qua form/factory/validator/lưu; product editor yêu cầu tài khoản; roundtrip ngân sách/actual/lost ACK. Forward migration giữ owner/account guard, ownerId reply, locks/version/write permits và membership động. Không sửa calculator đúng hoặc14 migration lịch sử.

Full cuối analyzer sạch, Flutter1100/1100, Node91/91 exit0; targeted162/162 rồi correction27/27. Snapshot383 files0 drift, historical migrations kiểm riêng14/14. SQL thật với authenticated/anon trên PostgreSQL local đạt CRUD/replay/digest/version/owner/locked/publication controls; runner negative self-test và stop PASS. **Bootstrap local có adapters cho PG18/digest/p32_utc; không chứng minh toàn historical chain cài nguyên trạng hoặc cloud đã cập nhật.** Full đầu có test Discovery trái scope đã sửa và một ca legacy import vượt thời gian chờ; nguyên helper không đổi, isolated/targeted/Full cuối đạt, nguyên nhân gián đoạn chưa kết luận.

Chưa commit/push/merge/deploy/apply cloud/build/install/hot reload/device/email/AI thật; chưa review độc lập. Codex không dùng Superpowers, không reset repair guard hoặc thay permanent workflow. **C6 chưa bắt đầu; bước kế tiếp là rà soát/lập plan C6**, chưa tự mở quyền code C6 hoặc live rollout từ checkpoint này.

## C6 — Plan được lập, chờ owner duyệt, 26/10/2026

Owner yêu cầu lập kế hoạch quản trị user/account và Khám phá. [Plan C6](../../phase-3/COURSEWORK_C6_IMPLEMENTATION_PLAN_20261026.md) đã chia6 gói: quyền/phiên; tìm-lọc-phân trang user; lock/unlock contract/retry/readback; tìm destination/place động và detail; thu UI theo scope; verification/review. Contract/SQL trước provider/UI cho luồng mutation. Đề xuất shell vào Người dùng, bỏ entry Tổng quan và nút promote/demote; giữ backend guards và đường catalogue/lịch sử cho C7.

Lượt này chỉ đọc source/test/SQL và ghi tài liệu. C5 snapshot383 files0 drift khi bắt đầu; Account DryRun đã kiểm inventory, chưa chạy Dart/Node/SQL C6. Các gap async/filter/retry/operation-state/consumer phải tái hiện bằng RED/control trước sửa. C5 Full1100/91 là evidence trước đó, không phải nghiệm thu C6. **C6 chưa code, chưa được duyệt triển khai; C7/live/native/commit/push không được mở quyền.** Codex không dùng Superpowers; nếu giao Antigravity code, phải yêu cầu Superpowers theo chỉ thị thường trực owner.

## Owner duyệt và Codex triển khai C6 — 26/10/2026

Owner trả lời **“duyệt”** sau checkpoint khôi phục và link đúng plan C6. **C6 source/automated và SQL contract local PASS, Codex self-review.** [Bàn giao](../../phase-3/COURSEWORK_C6_CODEX_IMPLEMENTATION_20261026.md), [review](../../phase-3/C6_CODEX_REVIEW_20261026.md): guard caller/epoch và PII, query/filter/cursor, frozen mutation/reconcile/readback/resume, SQL dispatch/worker/revision, dynamic place search và snapshot detail, shell3 mục.22 file cũ +7 mới so before C6; giữ dirty owner và14 migration lịch sử/C5 forward.

Full cuối analyzer sạch, Flutter1123/1123, Node91/91 exit0; Account201/19 và6 vectors SQL exact-match; final-schema C5 roundtrip + admin control/concurrency(dblink)/surface guards/C6 contract PASS; SelfTest/stop PASS. Snapshot434 files0 drift. SQL vẫn có bootstrap adapters C5, chưa chứng minh historical chain fresh deploy nguyên trạng. Đây không phải gateway/Auth live integration hoặc independent acceptance.

Không Superpowers/subagent cho Codex; không cloud/deploy/live users/device/build/install/commit/push/merge. DTD không có app, hot reload attempt không tác động app.3 vòng correction hành vi đã dùng, không reset guard. **C7 chưa bắt đầu**, owner quyết định review/next task; không tự rollout từ PASS local.
