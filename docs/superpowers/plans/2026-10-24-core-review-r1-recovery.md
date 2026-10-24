# Core Review R1 — Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Antigravity implements; Codex reviews. Do not dispatch subagents or switch implementer. Steps use checkbox syntax. Read the master handoff before execution.

**Goal:** Đóng CR1, CR2, CR5, CR6 bằng recovery UI liên tục, authority theo intent, callback một lần và cleanup không cập nhật mật khẩu lần hai.

**Architecture:** Giữ AuthProvider làm chủ credential queue và quyền SDK; PasswordRecoveryProvider giữ state/UI/marker. Mọi async continuation phải kiểm intent/generation; cleanup đi qua cùng queue. Bổ sung write-ahead marker trước update để cold restart không coi một update đã dispatch là quyền gửi lại.

**Tech Stack:** Flutter/Dart, Provider, Supabase Flutter 2.17.2 / gotrue 2.27.2, SharedPreferences 2.5.5; giữ lockfile.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`, S5; các quyết định sửa R1 và ID findings trong `docs/superpowers/plans/2026-10-24-core-review-r1-antigravity-handoff.md`.

## Global Constraints

- Baseline `147bd2050ae3a59e942b29945fbe54c9c9eae60c` + working tree dirty của owner; không reset/stash/clean/stage cả file dirty.
- URI `io.supabase.travelgo://login-callback?flow=recovery`, `detectSessionInUri=false`, PKCE do SDK sở hữu; không sửa Manifest/dependency/SQL/SMTP/allowlist.
- Không lưu/log code, verifier, token, email hoặc mật khẩu trong recovery marker/log tests; fake transport chỉ dùng dữ liệu synthetic.
- Không publish normal account, tải trips/role hoặc cấp local account handle bằng recovery session. Guest vẫn truy cập được khi recovery/storage lỗi.
- Mỗi task dưới đây <=5 file được sửa/tạo; tuân ngân sách hiện hành, checkpoint khi chạm ngưỡng, không tự reset counters.
- Các regressions bên dưới là yêu cầu CHƯA CHẠY ở lượt lập plan. Author phải chứng minh RED đúng hành vi trước khi sửa và GREEN sau sửa.

## Review Focus

1. Guest/login B trong khi exchange A pending: A không đổi UI/marker/authority sau khi trả về — A1.
2. Initial-link và stream cùng callback, hoặc startup đọc marker chậm: chỉ một exchange, không hạ ready thành error — A2.
3. Server đã ACK nhưng prefs write/remove/signout thất bại: chỉ cleanup, không PUT password lần hai — A3.
4. Process death sau dispatch nhưng trước ACK/ghi cleanup: không đoán kết quả, không tự retry update — A3/A4.
5. Nested navigator, bootstrap timer và resumed trong lúc update/error: form không bị tháo hoặc recovery session thành login — A1/A4.

## A1 — Authority và cancellation theo intent (CR2)

**Files:** Modify `lib/features/auth/providers/auth_provider.dart`, `lib/features/auth/providers/password_recovery_provider.dart`; Create `test/password_recovery_authority_test.dart`; Modify `test/password_recovery_flow_test.dart` (4 files).

**Interfaces:** Giữ `beginRecovery(String)`, `runRecoveryMutation<T>(String, Future<T> Function(SupabaseClient))`, `finishRecovery(String)`, `continueAsGuest()` và API login/OAuth/register/logout hiện có. Thêm vào AuthProvider:

```dart
bool isCurrentRecoveryIntent(String intentId);
VoidCallback registerRecoveryInvalidator(Future<void> Function() invalidate);
Future<void> cancelRecovery(String intentId);
```

Thêm `RecoveryIntentCancelledException` trong `auth_provider.dart`; không tạo file tiện ích mới. Registration trả hàm unregister; provider đăng ký trong constructor và unregister trong dispose. Invalidator là one-way: phần đồng bộ tăng generation/reset in-flight state; phần async chỉ serialize marker I/O, không gọi SDK hoặc enqueue ngược vào AuthProvider.

- [ ] **1. RED tests:** Dùng client thật qua fake HTTP + PKCE storage như flow test hiện có; dùng Completer chặn exchange/marker write. Các tên và assertions bắt buộc:
  - `cancelled_intent_never_dispatches_queued_mutation`: queue A, cancel trước dispatch; `expect(exchangeCalls, 0)` và không marker ready.
  - `guest_choice_fences_late_recovery_exchange`: exchange đã dispatch, chọn Guest rồi release; `expect(auth.isGuest, true)`, `expect(auth.isAuthenticated, false)`, `expect(provider.isReady, false)`, marker A không sống lại.
  - `new_login_waits_for_old_recovery_cleanup`: trace phải là `exchangeA -> cleanupA -> loginB`; cuối cùng SDK/auth cùng B; cleanup A đến muộn không signout B.
  - `old_marker_write_cannot_overwrite_new_intent`: chặn write A, bắt đầu B rồi release A; store/currentIntent đều là B.
  - `recovery_session_never_publishes_on_resume`: ready A -> inactive/paused/resumed; auth.currentUser null, không trips/role fetch, không lifecycle account grant.
- [ ] **2. Run RED:** `& ./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath @('test/password_recovery_authority_test.dart','test/password_recovery_flow_test.dart')`. Test mới phải fail assertions về race, không phải import/compile. Chưa có API mới thì viết behavioral repro bằng API hiện có trước, thêm interface tests cùng implementation sau.
- [ ] **3. Implement authority:** `runRecoveryMutation` capture generation/intent lúc nhận yêu cầu, kiểm trước dispatch và sau SDK await. Stale operation throw exception riêng; provider không publish error/ready của request đã stale. Serialize store writes/clear và kiểm generation trước/sau await; cleanup đã xếp sau write cũ phải hoàn tất trước write intent mới.
- [ ] **4. Implement cancellation:** Hủy quyền đồng bộ trước await cho cancel, Guest, login, OAuth, register, verifyOtp, logout và demo transition. Normal auth action chờ dọn recovery cũ trước SDK mutation mới, kể cả nhánh không lifecycle. Guest choice vẫn đồng bộ/khả dụng. Không await một public queued method từ callback đang giữ `_credentialTail`; tách private unqueued primitives khi cần. Cleanup lỗi phải chặn normal account grant và báo đúng lỗi, không âm thầm tiếp tục B.
- [ ] **5. Guard publication:** `_publish`, startup, SDK observer và lifecycle-resume không restore/publish normal account trong recovery/bootstrap-blocked/cleanup chưa xong. Không phá những đường login bình thường hoặc pause seal. `finishRecovery(oldId)` không được mở khóa intent mới. Cancel cleanup cũng phải dùng credential queue; không signout trực tiếp ngoài queue.
- [ ] **6. GREEN + integration:** Chạy lại RED command, rồi targeted `test/auth_navigation_test.dart`, `test/local_account_lifecycle_test.dart`, `test/auth_role_security_test.dart`. Kiểm account A→B, Guest draft còn nguyên; ghi command/exit/log.
- [ ] **7. Review/commit:** Chỉ hunks task; message đề xuất `fix(auth): fence recovery work to its active intent`. Không commit nếu chưa được owner cho phép hoặc đang lẫn hunks owner không tách được.

## A2 — Callback idempotency và bootstrap ordering (CR5)

**Depends on:** A1.

**Files:** Modify `lib/features/auth/providers/password_recovery_provider.dart`; Create `test/password_recovery_callback_race_test.dart`; Modify `test/password_recovery_cold_start_test.dart` (3 files).

**Interfaces:** Giữ `Future<void> initializeFromStore()` và `Future<bool> handleCallback(Uri)`. Initialization dùng một shared future; callback chờ future đó. In-flight exchange dùng shared Future<bool> theo active intent trong RAM; không persist code hoặc tự đụng SDK verifier key.

- [ ] **1. RED tests:**
  - `initial_and_stream_callback_exchange_once`: gọi cùng URI hai lần khi exchange bị chặn; release -> `expect(exchangeCalls, 1)`, cả futures hoàn tất, ready còn nguyên.
  - `duplicate_after_ready_preserves_ready`: gọi lại sau ready; `expect(exchangeCalls, 1)`, không error và không xóa marker.
  - `callback_waits_for_slow_bootstrap`: block store.read của initialize; gọi callback rồi release; chỉ một exchange, không bị initialization ghi đè ready thành emailRequested.
  - `different_or_replayed_code_never_reexchanges_ready_intent`: callback khác sau ready/completed không đổi session/state thành lỗi của request cũ, không exchange thêm.
  - `cold_ready_test_actually_initializes`: sửa test cold-start đang chỉ constructor/assert; seed SDK session synthetic khớp UID, gọi initializeFromStore thật. Cold ready phải server-revalidate trong recovery queue; wrong UID/expired/server denial không mở form và không cấp account.
  - `invalid_recovery_uri_has_no_sdk_effect`: sai path/scheme/host, fragment/token, duplicate flow/code hoặc thiếu marker -> exchangeCalls 0. Dùng queryParametersAll để không bỏ qua duplicate query.
- [ ] **2. Run RED:** Targeted với ba file A2 và `test/password_recovery_service_test.dart` bằng helper/array PowerShell ở A1.
- [ ] **3. Implement:** Guard cancellation từ A1 trước/sau bootstrap/exchange/persist. Chỉ phase sent/requesting hiện hành được claim exchange. Duplicate in-flight join future; khi ready thì giữ authority hiện có, không cấp quyền mới từ duplicate. Completed/cancelled/expired không re-exchange. Reset locks chỉ cho đúng intent/generation; callback A không xóa lock B.
- [ ] **4. GREEN:** Chạy lại A2 command và A1 authority suite. Không thay asserts thành chỉ kiểm method return value; quan sát SDK call count, phase, auth account grant.
- [ ] **5. Review/commit:** `fix(auth): process recovery callbacks once per intent` (selective hunks khi được phép).

## A3 — Update bền vững và cleanup-only retry (CR6)

**Depends on:** A1/A2.

**Files:** Modify `lib/features/auth/models/password_recovery_state.dart`, `lib/features/auth/services/recovery_intent_store.dart`, `lib/features/auth/providers/password_recovery_provider.dart`, `test/password_recovery_flow_test.dart`; Create `test/password_recovery_cleanup_test.dart` (5 files).

**Interfaces:** Bổ sung `RecoveryPhase.updating` vào local marker v1 như giá trị additive; giữ các field/key và phase cũ. `RecoveryState.uncertain` đã tồn tại. Giữ `submitNewPassword(String,String)`, `retryCleanup()` và `cancel()`; retryCleanup không được gọi updatePassword. `RecoveryIntentStore.clear()` phải kiểm bool remove; false/exception không phải cleanup thành công.

- [ ] **1. RED tests với fake HTTP/store có counters và các failure points:**
  - `failed_write_ahead_never_updates_password`: persist updating false/throw -> `expect(updateCalls, 0)`.
  - `acknowledged_update_and_marker_failure_is_cleanup_only`: updating marker thành công; PUT ACK; cleanup marker fail -> cleanupRequired, `expect(updateCalls, 1)`, submit lần nữa không PUT; retryCleanup chỉ signout/clear.
  - `acknowledged_update_and_signout_failure_retries_cleanup`: fail logout một lần -> retry thành công, updateCalls luôn 1.
  - `false_remove_keeps_recovery_blocked`: prefs.remove false -> không completed/finishRecovery; retry chỉ clear/signout.
  - `restart_after_dispatch_never_reissues_update`: marker updating + SDK session khớp -> initialize thật vào uncertain; updateCalls 0 đến khi người dùng xin flow mới sau cleanup.
  - `lost_update_ack_is_uncertain_not_retryable_ready`: fake transport nhận PUT rồi mất ACK -> uncertain, không khẳng định đã đổi/chắc chắn thất bại; không tự retry PUT.
  - `wrong_or_expired_session_cannot_update`: owner không khớp verifiedUserId, intent hết TTL hoặc session expired/server deny -> updateCalls 0.
  - `expired_cleanup_marker_does_not_unlock_sdk_session`: TTL qua 60 phút không được xóa dấu update chưa giải quyết rồi publish session thành normal account; Guest vẫn dùng được.
- [ ] **2. Run RED:** Targeted `test/password_recovery_cleanup_test.dart`, `test/password_recovery_flow_test.dart`, `test/password_recovery_service_test.dart`.
- [ ] **3. Implement write-ahead:** Validate password/confirmation và active intent/session/verified UID trong queue. Persist phase updating TRƯỚC dispatch PUT; failure trước dispatch không được gửi. Server revalidation dùng SDK `getUser()` trong cùng recovery queue, so UID với verifiedUserId; không coi local marker là quyền server.
- [ ] **4. Implement outcomes:** Khi ACK hợp lệ, chuyển cleanupRequired trong RAM trước await tiếp theo; phase cleanup sau ACK. Marker write/signout/clear lỗi đều giữ cleanup-only. Khi outcome mạng không xác định sau dispatch, giữ updating marker và state uncertain; không đưa về ready/retry update. Server reject xác định có thể quay về form sau khi bảo đảm marker/session hợp lệ; không retry tự động. Nếu không persist được marker khôi phục ready sau reject, giữ fail-closed thay vì đoán.
- [ ] **5. Implement cold/cleanup:** Updating -> uncertain, cleanup -> cleanupRequired, cả hai cấm PUT. Cleanup dùng queue A1, rồi clear đã kiểm kết quả, cuối cùng finish đúng intent. TTL60 vẫn giới hạn quyền sent/ready; updating/cleanup hết TTL không tự cho phép normal account với SDK session chưa dọn. Không hứa exactly-once toàn hệ thống: khi mất ACK, bảo đảm client không tự gửi lại và hiển thị chưa rõ kết quả.
- [ ] **6. GREEN:** Chạy lại A3 command + A1/A2 tests. Kiểm trace PUT trước/marker và call count; không chỉ kiểm state cuối.
- [ ] **7. Review/commit:** `fix(auth): persist recovery update intent before dispatch` (selective hunks khi được phép).

## A4 — Recovery gate/UI integration (CR1)

**Depends on:** A1–A3.

**Files:** Modify `lib/features/auth/presentation/widgets/password_recovery_gate.dart`, `lib/features/auth/presentation/screens/reset_password_screen.dart`, `lib/main.dart`, `test/password_recovery_cold_start_test.dart`; Create `test/password_recovery_gate_test.dart` (5 files).

**Interfaces:** Giữ `PasswordRecoveryGate({required Widget child})`, `ResetPasswordScreen`. Dùng state/phase/active authority từ provider. Tách branch loading-exchange khỏi password form; giữ cùng StatefulElement của ResetPasswordScreen xuyên ready -> updating -> recoverable error/cleanup/uncertain. Không push vào root Navigator để né gate. Main phải await/sequence bootstrap marker với dispatcher; không tạo hai nơi sở hữu PKCE exchange.

- [ ] **1. RED widget tests qua real provider/fake transport:**
  - `password_form_survives_pending_update`: nhập synthetic password, chặn PUT, tap submit/pump; ResetPasswordScreen vẫn mounted, submit disabled/loading, không Splash/Home/Onboarding.
  - `server_rejection_stays_on_reset_form`: release reject xác định; message hiển thị, có thể sửa/retry, provider không giữ raw password.
  - `cleanup_and_uncertain_never_show_update_button`: có retry cleanup/cancel an toàn; không nút PUT enabled; SDK call count không tăng khi retry.
  - `warm_and_cold_callbacks_override_nested_bootstrap`: chạy qua TravelGoApp seams `authCallbackLinks`/`initialAuthLinkLoader`, không chỉ MaterialApp(home: ResetPasswordScreen()). Dùng fake local runtime như auth_navigation fixtures; ready override navigator con, duplicate không thêm route.
  - `bootstrap_resume_timer_cannot_replace_recovery_form`: pending exchange/update + splash timer + lifecycle events -> recovery UI vẫn ưu tiên, auth.isAuthenticated false.
  - `cleanup_success_returns_to_login_flow`: không Home tự động; auth/SDK không session, marker đã xóa. Back/Guest không khôi phục password controller cũ.
- [ ] **2. Run RED:** Targeted `test/password_recovery_gate_test.dart`, `test/password_recovery_cold_start_test.dart`, `test/auth_navigation_test.dart`.
- [ ] **3. Implement gate/navigation:** Exchange chỉ loading, không mở password trước server verification. Khi cập nhật, giữ form và disable tương tác thay vì trả child. Error gắn verified ready intent giữ form; error callback không có authority chỉ hiện trạng thái an toàn, không lộ form. Cleanup/uncertain có copy đúng kết quả đã biết/chưa rõ; gửi yêu cầu mới chỉ sau cleanup, không lặp PUT. Startup store-read lỗi phải block normal account bootstrap, vẫn cho Guest/retry; không nuốt lỗi rồi restore recovery session như account.
- [ ] **4. GREEN:** Chạy lại A4 command, toàn bộ A1–A3 target suites; thêm `test/guest_draft_planner_test.dart`, `test/editable_guest_import_ui_test.dart`, `test/profile_preferences_test.dart` để bảo vệ draft/owner isolation.
- [ ] **5. Runtime check:** Sau thay Dart/Flutter, dùng Dart MCP hot reload/restart nếu app QA phù hợp đang kết nối; kiểm trước tránh mất draft owner. Không có runtime an toàn thì ghi NOT RUN, không khởi động/reset/cài đè thiết bị để làm xanh báo cáo.
- [ ] **6. Review/commit:** `fix(auth): preserve recovery form across async states` (selective hunks khi được phép).

## Exit criteria / owner explanation

- CR1/CR2/CR5/CR6 chỉ đóng khi có test đúng trigger ở trên và bằng chứng RED/GREEN; review source-ready không thay email thật/native acceptance.
- Luồng cần giải thích: email -> marker -> PKCE exchange -> verified recovery-only form -> write-ahead update -> ACK/uncertain -> cleanup -> login mới. AuthProvider quyết quyền; recovery provider không cấp normal account.
- Full verification duy nhất sau cả Recovery và Map/API theo master handoff; không chạy Full cho mỗi task.
