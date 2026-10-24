# Admin Account Control Implementation Plan

> **Owner-selected execution, 23/10/2026:** Codex lập kế hoạch và review; Antigravity viết code, chạy kiểm thử và sửa findings. Đây là phân công do owner chọn, thay thế đề xuất Codex-native/subagent trước đó. Steps use checkbox (`- [ ]`) syntax for tracking. Không tự dispatch agents hoặc coi lựa chọn người code là duyệt toàn bộ scope/budget/deployment. Xem [handoff](2026-10-23-admin-antigravity-handoff.md).

**Goal:** Cung cấp API quản trị tài khoản và dashboard thật, bảo vệ cả các đường account cũ khi khóa hoặc thu hồi quyền.

**Architecture:** PostgreSQL giữ current role, account access, revision và operations/audit. Edge Function gọi RPC bằng bearer của caller, chỉ dùng service credential phía server để đồng bộ Auth và hoàn tất operation đã được ràng buộc; không tin actor/session do client gửi. Khu quản trị Flutter và publication tiêu thụ hợp đồng dưới đây qua hai plan kế tiếp.

**Tech Stack:** Supabase Auth/PostgreSQL/RLS/Edge Functions, JavaScript modules được Deno import, Node built-in tests, Flutter/Dart/Provider/Dio/SQLite hiện có.

**Spec:** [Thiết kế đã được owner duyệt](../specs/2026-10-23-flutter-admin-design.md), commit thiết kế `6385e3d`. Approval thiết kế ban đầu cho phép viết kế hoạch. Chỉ thị mới ngày 23/10/2026 “bạn hãy hoàn thành hết a0-a5 luôn đi không cần chia nhỏ ra đâu” giao trọn A0–A5 trong một đợt, theo phân công Codex plan/review, Antigravity code. Xem [packet thực thi chung](2026-10-23-admin-a0-a5-antigravity-packet.md): không xin giao lại từng task; chưa cấp quyền live rollout hoặc merge.

## Global Constraints

- Giữ hai role `customer`/`admin`. Guest là trạng thái chưa đăng nhập.
- Không thêm dependency/native permission, không sửa permanent rules, quota/key/model/billing hoặc engine algorithms.
- Giữ owner isolation, Guest drafts và canonical trip data; không reset/stash/clean dirty checkout.
- Mục tiêu staging duy nhất `bkocylxbuyvdgxccpixx`; local verification không phải staging rollout. Live mutation cần concrete packet được duyệt.
- UI không báo thành công trước acknowledgement; retry giữ request ID; current server role/session quyết định quyền, không user_metadata.
- Ngày dashboard theo `Asia/Ho_Chi_Minh`; reason 1–500 Unicode code points; user page size 25; 7/30 ngày gồm hôm nay.
- Owner đã bỏ trần tool/call nhân tạo. Với packet A0–A5 hiện tại, allowlist là hợp 23 execution files của sáu mục dưới đây; các số Files ở từng mục giúp truy vết, không phải gate xin phép mỗi năm file hoặc mỗi task. Đây là phạm vi riêng của packet, không sửa permanent rules hoặc mở scope F/P. Giữ RCA tối đa 3 vòng cho cùng vấn đề; không reset hoặc vay counters các gói G2/G3/G4.
- Antigravity là người duy nhất sửa source implementation. Codex kiểm diff, constraints và tests, báo findings kèm bằng chứng rồi Antigravity sửa; không tự chuyển sang Codex repair nếu owner chưa đổi phân công.
- Mọi migration mới được tạo khi execution bằng `supabase migration new <suffix>`; bind đúng filename CLI trả về vào evidence trước edit. Không invent timestamp. Các alias `M_*` dưới đây đại diện duy nhất file có suffix được chỉ định, không phải chỗ cho implementer tùy chọn thiết kế.

## Review Focus

1. Retry lock/unlock API đến muộn không được mở lại target revision mới — A3 kiểm stale completion và operation đối nghịch.
2. Cached receipt của trip/import và AI result không được bypass account guard — A2 kiểm từng đường đọc lại.
3. Hai admin cuối thao tác đồng thời không được làm active-admin count về 0 — A1 SQL hai connections.
4. User chưa có access row hoặc vừa signup không được lọt qua khoảng hở — A1 backfill/trigger/deny-missing tests.
5. Local cold/resume đang pending không bị hook access mới làm mất session hoặc Guest drafts — A4 tái chạy regressions hiện có và thêm delay/denial cases.

## File bindings, integrity và security contract

Tạo alias khi tới task tương ứng: `M_CONTROL = supabase migration new admin_account_control`; `M_GUARDS = ... admin_account_guards`; `M_DRAFT = ... admin_discovery_commands`. Tất cả có directory `supabase/migrations/`, giữ CLI version/tên/hash trong acceptance report. Prepared A1 chỉ apply ở database biệt lập hoặc sau live preflight; nếu đã applied thì dùng additive migration, không sửa applied file.

| Đối tượng | Constraint/index bắt buộc | Enforcement và negative test |
|---|---|---|
| `private_admin.account_access` | `subject_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT`; state NOT NULL CHECK enabled/locked/unlocking; revision bigint CHECK 1..9007199254740991; session_valid_after timestamptz NOT NULL | Missing row deny; signup/backfill atomic; không biến existing Auth ban thành enabled capability |
| `private_admin.control_lock` | Một row `singleton boolean PRIMARY KEY CHECK(singleton)` | Lock row trước mutation; rồi access/profiles rows theo UUID tăng dần, không gọi network trong DB transaction |
| `private_admin.account_operations` | UUID `id` PK; FK target→access RESTRICT; action CHECK lock/unlock/promote/demote/reconcile; state CHECK pending/completed/needs_retry; base/result revisions; reason CHECK 1..500; SHA256 CHECK `[0-9a-f]{64}` | UUID collision khác actor/target/content→request_identity_conflict; một partial UNIQUE target_id khi state pending/needs_retry; index target_id/created_at |
| `private_admin.audit_events` | UUID event PK, FK operation_id→operations RESTRICT; UNIQUE(operation_id,event_kind); CHECK event_kind begun/completed/retry_required/reconciled | Actor/target UUID snapshots không FK Auth để giữ audit lịch sử; append-only qua endpoint; không lưu email/token/raw provider response |
| `public.profiles.role` | Existing NOT NULL/CHECK customer/admin; không cấp UPDATE(role) cho authenticated | Đổi role qua transaction có current actor guard, expected revision và last-admin count; không dùng CHECK cross-row |
| Account state và role | Không self-change; giữ >=1 active admin; transition enabling chỉ sau Auth readback đúng revision | RPC + control_lock + audit cùng transaction; test hai connections khóa/hạ quyền lẫn nhau |
| Existing account tables/RPC | Existing ownership predicate AND current-account/session predicate; giữ column grants | SQL role fixtures thử direct REST/RPC, replay receipt và spoof service payload |
| Draft/catalogue | Existing PK/FK/UNIQUE/CHECK từ A1; FK place parent RESTRICT, index destination_id; immutable IDs; no hard delete | A5 giữ nguyên validators giá/giờ/nguồn/date, tests không weakening |

Private tables bật RLS; revoke default PUBLIC/anon/authenticated table privileges. Public RPC là SECURITY INVOKER wrapper; elevated code ở private schema, empty search_path, qualified identifiers, explicit execute grants. Service-only worker wrappers không EXECUTE cho anon/authenticated. Không mở SELECT toàn bộ profiles để làm admin list. Index FK/filter/cursor; xem EXPLAIN trên synthetic fixtures, không thêm extension để tìm kiếm.

### API wire contract dùng chung cả ba plan

HTTP `POST /functions/v1/admin-control`, JSON `{contract:"travelgo.admin.v1", action, request}`; bearer là caller session. Strict allowlist keys, body <=64 KiB, query <=180 code points, timeout Auth verification 5s, tổng xử lý request 30s. Response `{status:"ok",data}` hoặc `{status:"pending",data:Operation}`; lỗi `{status:"error",code,field?}` không PII. HTTP 401 unauthorized; 403 account_locked/admin_required; 409 conflict/self_change_denied/last_admin/request_identity_conflict; 422 invalid_field; 503 upstream_unavailable/outcome_pending.

| action | request | data |
|---|---|---|
| `access` | `{}` | `AdminAccess{subjectId,role,accountRevision,allowed:true}` |
| `users` | `{query,role:null|customer|admin,state:null|enabled|locked|unlocking,cursor:null|{createdAt,id},limit:25}` | `{items:UserSummary[],nextCursor}`; descending `(createdAt,id)` |
| `user` | `{targetId}` | `UserDetail{...UserSummary,audit:AuditEvent[]}`; last 50 events |
| `dashboard` | `{days:7|30}` | `DashboardSnapshot{asOf,days,totalUsers,lockedUsers,activeAdmins,registrations:[{date,count}],draft:{revision,activeDestinations,hiddenDestinations,activePlaces,hiddenPlaces},published:null|{version,sourceRevision,activeDestinations,activePlaces}}` |
| `mutate` | `{requestId,targetId,expectedRevision,action:lock|unlock|promote|demote,reason}` | `AccountOperation{id,targetId,action,state,targetRevision,authSynced}` |
| `operation` | `{operationId}` | Same operation plus sanitized current target; current admin required |
| `reconcile` | `{requestId,operationId,expectedRevision,reason}` | New operation referencing prior operation, retaining original actor audit |

`UserSummary{id,fullName,email,role,state,revision,createdAt,lastSignInAt:null|string,authSynced}`. `AuditEvent{id,operationId,actorId,targetId,eventKind,reason,createdAt}`. Dates ISO UTC except registrations date `YYYY-MM-DD` in Vietnam. Counts/revisions safe integers. Unknown action/fields rejected; cursor validation does not allow raw SQL/filter syntax.

SQL interfaces: `public.admin_accounts(p_action text,p_request jsonb) RETURNS jsonb` forwards caller context to private `private_admin.accounts_endpoint`. `public.current_account_access() RETURNS jsonb` returns only own `{subjectId,role,revision,state,sessionValid}` and fails unauthorized for missing/expired session; locked status may be returned for the owner so client can clear RAM. `private_admin.require_account(p_subject uuid,p_session_id uuid) RETURNS uuid`; `private_admin.require_admin() RETURNS uuid`. The subject/session overload is private, callable only by guarded endpoints/worker, never a client-selected actor. RLS consumes `private_admin.current_account_enabled() RETURNS boolean`: no arguments, derives only current auth.uid/session claims, SECURITY DEFINER with empty search_path, minimal own-state boolean output. Grant authenticated schema USAGE/EXECUTE only for this safe predicate as required by policy evaluation; other private helpers/table grants remain revoked.

Edge module `createAdminControl({verifyCaller,callAsCaller,completeAsWorker,authAdmin,now}) => (Request)=>Promise<Response>`. All reads/begin mutations call SQL with caller bearer; `authAdmin` has only ban/unban/readback methods. Completion wrapper `public.complete_admin_account_operation(p_operation_id uuid,p_worker_token uuid,p_expected_revision bigint,p_auth_synced boolean) RETURNS jsonb`, service_role-only, target/actor/session taken from persisted operation. Worker token never returned to Flutter. Fresh role/session checked for every replay/reconcile; a worker cannot authorize a new target mutation.

## Task A0: Baseline và verification harness

**Review hiện tại:** commit `02db19e7dd9005f441e541c45630abb20be0807a` đã có hai file A0 nhưng NEEDS CHANGES. Sửa bốn findings fail-open exit code, SelfTest nhận nhầm exception, thiếu PostgreSQL vẫn xanh và timeout vô hạn trước khi dùng harness nghiệm thu A1–A5. Chi tiết và regression controls có trong packet chung; việc mở rộng scope không đóng findings.

**Files (2):** `tool/verify-flutter-admin.ps1` (Create), `docs/phase-3/FLUTTER_ADMIN_ACCEPTANCE_20261023.md` (Create).

**Interfaces:** `verify-flutter-admin.ps1 -Mode Account|Draft|Publication|All -FlutterRoot 'D:/flutter/flutter'`; temporary local PostgreSQL uses unique loopback port/data root, synthetic auth/session/profile fixtures, `ON_ERROR_STOP=1`, cleanup only owned process. All mode chains existing Full plus every new SQL/Node suite listed here; modes do not deploy or install SDKs. Report records exact CLI migration alias bindings, hashes, used/max budgets, baseline versus new results.

- [ ] Inspect git/dirty dependencies, CLI/PostgreSQL/Node/Flutter versions and local SQL tools; only read live staging schema/history/ACL when needed, without selecting real user data. Preserve current source as execution baseline; do not create a worktree from bare HEAD that omits dirty dependencies.
- [ ] Pin regression `harness_propagates_nonzero`: verify child SQL and Node exits are nonzero for deliberate failures and the harness itself rejects them; this is a harness self-test, not permission to weaken product assertions. CLI was not on PATH in the planning shell; discover existing approved cached CLI/runtime first, no automatic installation/upgrade.
- [ ] Add harness checks that deliberate SQL assertion failure and Node failure propagate nonzero; no test failure may be converted to PASS. Each mode runs tests added by its owning tasks, without duplicate full suites.
- [ ] Giữ logs Full tại baseline A0 đã có; chạy Full lại sau thay đổi implementation cuối packet và thu kết quả thực. Chỉ lặp giữa chừng khi có failure hoặc thay đổi cần kiểm chứng. Historical failures ghi riêng; không sửa code/assertions ngoài scope hoặc tự suy nguyên nhân khi chưa có bằng chứng.
- [ ] Run `./tool/verify-flutter-admin.ps1 -Mode Account -DryRun` after defining DryRun alongside Mode; expected explicit command inventory and no database/network mutation. Commit only these two task files after scoped checks; message `test(admin): add isolated verification harness`.

## Task A1: Account schema, authority và atomic mutation

**Files (4):** `M_CONTROL` (Create via CLI), `supabase/tests/admin_account_control.sql` (Create), `supabase/tests/admin_account_concurrency.sql` (Create), `tool/verify-flutter-admin.ps1` (Modify).

**Consumes:** R1 profiles protected role and synthetic fixture harness A0. **Produces:** all SQL account interfaces above, operation/audit tables and private `private_admin.read_dashboard(p_days integer) RETURNS jsonb`.

- [ ] Write SQL regressions asserting invalid enum/negative revision/FK fail; missing access row denies; signup creates profile+access atomically; actor metadata admin is denied; self-change denied; duplicate same request has one operation/audit; different content same ID raises conflict.
- [ ] Pin cases `concurrent_last_admin_preserved` (`activeAdmins >= 1` after both transactions), `missing_access_denies`, `request_identity_conflict` and `dashboard_vietnam_midnight`; constraints must fail with their expected SQLSTATE, not any exception.
- [ ] Run `./tool/verify-flutter-admin.ps1 -Mode Account`; RED must name missing account interfaces/constraints, not a broken fixture. Then create/bind M_CONTROL with CLI and implement the integrity matrix and endpoint contracts.
- [ ] Initial enabled-account backfill and signup use session_valid_after='-infinity'::timestamptz so valid existing sessions are not forcibly invalidated by deployment; existing banned users remain denied. Implement lock: locked+new session_valid_after commits before Auth work. Unlock: unlocking remains deny until matching Auth success; existing pre-unlock session created before the cutoff remains denied after enabled. Enabling never trusts JWT iat. Promote/demote never alter target's customer ownership.
- [ ] Add assertions `active_admin_count >= 1` after two-connection opposite lock/demote transactions; absent/anonymous/deleted/banned/mismatched-session actors all deny. Dashboard uses one SQL snapshot; test null lastSignIn, filtered cursor, zero dates, Vietnam midnight, page 25 and user 26. Pending-unlock is excluded from activeAdmins.
- [ ] Run Account suite; expected all assertions pass, revoked-role/direct-grant negative probes deny, zero orphan rows after rollback. Commit only task files: `feat(admin): enforce account control and audit invariants`.

## Task A2: Guard existing account surfaces và AI

**Files (5):** `M_GUARDS` (Create via CLI), `supabase/tests/admin_account_surface_guards.sql` (Create), `supabase/functions/itinerary-proposal/gateway.mjs` (Modify), `supabase/functions/ai-request/gateway.mjs` (Modify), `test/admin_account_gateway_test.mjs` (Create).

**Consumes:** A1 require_account; existing profile/favorites/trips/activities/user_vouchers RLS and `private.p32_owner`, V1 import/snapshot RPC; AI service-role reservation path. **Produces:** same public legacy API signatures with added current account/session checks; service-only `public.check_gateway_account(p_subject uuid,p_session_id uuid,p_is_guest boolean) RETURNS jsonb` deriving auth/session facts server-side. It returns `{allowed:true}` only; p_is_guest does not bypass truth in Auth.

- [ ] SQL negative matrix: locked/missing-access/old-session users cannot SELECT/INSERT/UPDATE/DELETE own private rows or read cached V1/V2/import receipts; enabled A still cannot read B. Public catalogue reads stay public. Enumerate actual grants/RLS first; add restrictive account policies for ordinary tables so old permissive ownership policies cannot OR-bypass them.
- [ ] Node RED code example: `assert.equal((await lockedGateway(validRequest)).status,403); assert.equal(reserveCalls,0); assert.equal(providerCalls,0);` test cached result/revoked mid-flight denies returned payload, finalization still releases/resolves reserved quota correctly, guest quota/consent unchanged, session UUID from verified caller context rather than body.
- [ ] Pin `locked_receipt_read_is_denied` and `locked_gateway_never_dispatches`; assert no owned-trip payload returned and `assert.equal(providerCalls,0)` on denied new dispatch. Enumerate legacy account-bound tables, functions and grants into a versioned preflight section of the SQL test before changing them; abort on an unclassified account endpoint rather than claiming full lock coverage.
- [ ] Bind M_GUARDS; replace/extend legacy private helpers and definer RPC guards in this new migration, preserving their signatures and receipt semantics. RLS restrictive policies call A1 current_account_enabled() without a client-selected subject; ownership remains a separate conjunct. Verify the predicate's execute privilege in actual authenticated-role tests so permission errors are not mistaken for successful denies. Only account-bound entry points change; no ownership broadening.
- [ ] Add gateway checks before reservation, dispatch, and final response. Gateway dependency `checkAccount(user, bearer)` verifies trusted `session_id` through server JWT verification + database; no unverified decode may decide authority. Never pass target token to admin-control or logs. Keep quota worker finalization separate from permission to deliver a result.
- [ ] Run `node --test test/admin_account_gateway_test.mjs test/ai_gateway_test.mjs test/itinerary_gateway_test.mjs` and Account SQL surfaces. Expected new denies plus old AI contracts PASS; commit `fix(auth): enforce account lock across existing data paths`.

## Task A3: Edge Function Auth synchronization

**Files (4):** `supabase/functions/admin-control/index.ts` (Create), `supabase/functions/admin-control/gateway.mjs` (Create), `test/admin_control_gateway_test.mjs` (Create), `tool/verify-flutter-admin.ps1` (Modify).

**Consumes/Produces:** wire contract and createAdminControl factory above; no new app/client secrets or Admin API in Flutter.

- [ ] Tests: lock RPC occurs before Auth ban; Auth timeout leaves locked+needs_retry; unban failure leaves unlocking; only successful readback+matching revision completes enabled; retries do not add audit/mutation; invalid origin/action/oversize/body actor/session fields rejected. Assert `assert.equal(unlockResult.authSynced,false); assert.equal(await canRead(target),false);` on upstream error.
- [ ] Pin `stale_auth_completion_cannot_enable_new_revision`; assert completion for old revision leaves current access state unchanged. Enabling requires persisted actor's current admin/session or a valid successor reconcile; finishing a committed lock may keep deny but cannot authorize new access.
- [ ] Run `node --test test/admin_control_gateway_test.mjs` to RED; implement injected handler, deny flags by default, fixed project origin, 5s Auth verification, 30s request limit, no response body/token logging. `index.ts` binds existing server env only.
- [ ] Test opposite operations against one unresolved target, stale worker completion, worker token reuse/mismatch and admin-B reconcile after admin-A demotion. Worker results cannot set enabled for a newer revision. Global Auth signOut is not used with unavailable target credentials.
- [ ] Run combined gateway/SQL tests; expected protocol status/error mappings exact, no private data in diagnostics. Commit `feat(admin): synchronize account locks through guarded Auth operations`.

## Task A4: Flutter account access verification and lifecycle

**Files (5):** `lib/features/auth/services/account_access_service.dart` (Create), `lib/main.dart` (Modify), `lib/features/auth/providers/auth_provider.dart` (Modify), `test/account_access_service_test.dart` (Create), `test/auth_navigation_test.dart` (Modify).

**Interfaces:** immutable `AccountAccess{subjectId,role,revision,state,sessionValid}` and `AccountAccessService.verify(String token) -> Future<AccountAccess>` in the new service file. Typed `AccountAccessDenied(code)` distinguishes account_locked from transport; use existing Dio. Replace the existing `main.dart` verifySubject closure internals with Auth getUser + own-access RPC check, returning subject string only after both succeed; do not change lifecycle store format.

- [ ] RED: delayed access verification with cold→HOME→resume preserves valid account and Guest draft; locked server response denies account publishing; network failure is not misreported as lock. Mismatched returned subject, stale response after A→B/Guest and invalid session are rejected.
- [ ] Pin `interrupted_startup_waits_for_access_verification`: `expect(auth.currentUser?.id,ownerA)` only after both checks, `expect(guestDraftStillExists,isTrue)` after denial/Guest switch; missing verification never issues a SessionHandle.
- [ ] Implement service and caller proof checks; AuthProvider verifies on foreground/own access failure and updates trusted role from server; denied account uses current lifecycle revocation to clear RAM and discard late data, preserving Guest drafts. Admin feature provider will react to Auth changes in F1; no new global role from local flags.
- [ ] Run `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/account_access_service_test.dart','test/auth_navigation_test.dart','test/local_account_lifecycle_test.dart','test/auth_role_security_test.dart') -FlutterRoot 'D:/flutter/flutter'`; assert all pass including interrupted-startup negatives, no assertions removed. Attempt hot reload only with active Dart app; otherwise NOT RUN.
- [ ] Scoped analyzer then commit `fix(auth): verify account access before restoring protected state`.

## Task A5: Discovery command API và compatibility

**Files (5):** `M_DRAFT` (Create via CLI), `supabase/tests/admin_discovery.sql` (Modify), `admin/index.html` (Modify), `test/admin_discovery_web_test.mjs` (Modify), `test/admin_discovery_commands_test.mjs` (Create).

**Consumes:** dynamic A1 draft/revision/history contract. **Produces:** `public.admin_discovery_command(p_request_id uuid,p_expected_revision bigint,p_command jsonb,p_reason text) RETURNS jsonb` (guarded invoker wrapper), returns current `{revision,payload,history,entityId}`. Commands strict: createDestination/createPlace/updateDestination/updatePlace/archiveDestination/archivePlace/restoreVersion; new entity ID minted by server, client cannot pick it; restore creates new revision and retains newly added IDs as hidden.

- [ ] RED SQL tests: server creates 13th destination/73rd place, rejects duplicate slug/orphan/missing coordinate pair/active-child-hidden-parent; update name/move parent keeps ID; archive parent+children atomic; restore old snapshot does not delete newer IDs. Expected revision/request ID replay semantics match existing endpoint.
- [ ] Pin `server_identity_survives_move_and_restore`: after restore, assert the same IDs still exist and newer ones have is_active=false; invalid parent raises FK violation and rolls back draft, projection and version together.
- [ ] Bind M_DRAFT after preflight confirms prepared A1 applied locally; add source/image-rights metadata needed by V2 preview without changing reviewed facts. Define strict fields: name 1..180, slug 1..120 pattern existing, description <=10000, region <=80, notes/URLs per existing validators; sourceRefs list <=1000; imageRights null or `{sourceUrl,permission:owned|licensed,credit,licenseUrl:null|string}` with credit 1..500 and HTTPS URLs; licensed requires licenseUrl. Optional pairs preserve existing price/hour/source/package payloads byte-equivalent under JSONB semantics.
- [ ] Command fields include `sourceEdits:[{id:null|string,title,publisher,url,checkedAt}]`: null id asks server to create a source ID and append it to entity sourceRefs in the same draft transaction; existing id updates referenced source after explicit warning that it is shared. Title/publisher trimmed 1..180, HTTPS URL <=2048 without credentials, checkedAt real date <=today Vietnam. This permits new names with new evidence from Flutter, rather than forcing reuse of unrelated old sources.
- [ ] Full-payload legacy save may edit existing IDs but cannot introduce new IDs or delete historical IDs. Route web create buttons through command API only after existing unsaved edits are saved; keep existing read/edit/history functions. Web messages clearly state dirty-save dependency, rather than silently throwing away local edits.
- [ ] Run `node --test test/admin_discovery_web_test.mjs test/admin_discovery_commands_test.mjs` and `./tool/verify-flutter-admin.ps1 -Mode Draft`; expect all old integrity checks retained plus new commands. Commit `feat(admin): expose server-authored catalogue editing commands`.

## Completion and handoff

- A0→A1→A2→A3→A4; A5 after A1 and local prepared A1, before Flutter editor F4. Do not publish admin-control while A2 guards are absent. F1–F3 can be developed against these tested contracts; no live-ready claim from mocks.
- Update một acceptance report chung với trạng thái A0–A5, commands/exits/hashes, baseline failures và exact migrations. Một handover cuối đợt dùng Changed/Why/Testing/Problems/Lesson Candidate; không dừng xin giao/review sau mỗi nhãn A. Commit nhỏ theo dependency được phép, không phải approval gate.
- Run Account, Draft, mọi SQL/Node suite A0–A5 và existing Full ở cuối packet; kiểm actual suite inventory, không dùng Publication/All đòi suites F/P chưa triển khai làm điều kiện giả. New suite pass không xóa historical failures. Live schema/API rollout vẫn là packet riêng cần duyệt với SQL/advisor readback.
- Codex review toàn packet sau khi Antigravity bàn giao. Các plan [Flutter UI](2026-10-23-flutter-admin-ui.md) và [Publication/consumer](2026-10-23-discovery-publication-v2.md) vẫn là giai đoạn kế tiếp, không nằm trong chỉ thị A0–A5 hiện tại. Trần calls cũ trong bảng plan 3 đã được owner bỏ; file scope F/P không được cộng vào packet này.
