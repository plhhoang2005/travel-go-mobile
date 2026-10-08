# REPAIR-v1 — kế hoạch sửa theo batch

Ngày 2026-10-08. Base **41407120c7aac598b402e7e6aaef84e920ff7e2d**. Deadline **2026-10-28**.
Inputs: [evidence](EVIDENCE.md), [findings](SCHEMA_REVIEW.md), [handoff](ANTIGRAVITY_HANDOFF.md), docs/phase-1 tại baseline. Contracts dưới đây PROPOSED; owner truyền packet cho Antigravity là execution instruction cho batch A, không live rollout hoặc blanket approval Phase 3.

## Outcome và giới hạn

Profile A chỉ A đọc/sửa allowed fields; client không tự cấp admin/partner. App dùng trips.ai_plan_data, báo save success sau acknowledgement; request A cũ không cập nhật session B. Guest import atomic/retry-safe là batch B, chưa được claim từ batch A.

Giữ Provider/Supabase Auth/dashboard/feature layout; không tạo saved_trips để che mismatch, rewrite DecisionEngine, thêm dependencies/native config/permanent rules, reset/drop data hoặc chạy enterprise schema wholesale. Reuse repo/project; dùng local/staging synthetic fixtures.

AGENTS/.agent rules/workflow giữ feature branches/PR/human merge; tối đa5 changed files/task và3 test-fix attempts. Không superpowers. User instructions có precedence; không xin lại authorization đã bao phủ task. Pre-code cross-agent review inspect actual source; chỉ escalate material delta ngoài scope. Guidance LLM-only-explainer/ISSUE003 chưaAuth là known conflicts, batch A không sửa guidance/LLM; reviewed amendment trước batch AI.

## Sequence

| Task | Deliverable | Dependencies/gate |
| --- | --- | --- |
| R00 | Inspect cloud function/config/ACL, REST401 và checkout | Read-only; missing cloud access ghi BLOCKED phần live |
| R01 | Profile privacy/privileges/signup role migration + DB tests | Verified deployed body/ACL trước apply; local/staging target xác định |
| R02 | Live role trusted source + demo boundary | R01 contract; live tests sau staging R01 PASS |
| R03 | trips adapter + ack/error correctness | Known schema; unit work độc lập; live save sau R01/accessPASS |
| R04 | Session purge RAM/stale completion guard | R02/R03 |
| R05 | Codex review + rollout packet | R01–04evidence; owner merge/live rollout gate |
| R06 | Canonical/SQLite/durable receipt/version | Batch B, chưa exact approved packet |
| R07 | Gemini server/JWT/quota | Batch C, RC dependencies chưa đủ; NO-GO public AI |

Proposed schedule R00 08–09/10, R01–04 09–12/10, R05 sau checks; không guarantee deadline từ rough estimate. Không chặn independent tests vì cloud access thiếu, không provision/billing bypass blocker.

## R00 — readiness delta

No changed source; report ở PR body hoặc new docs/phase-2/execution/R00.md.
Inspect base/head/dirty files; preserve owner untracked; không reset/pull wholesale. Local8451fdb source-equivalent remote4140712 nhưng docs behind.

Read deployed handle_new_user/check_review_eligibility return type/body/search_path/ACL; Auth trigger event/timing; default expressions và actual column/table/default ACL. Không execute functions để inspect, không export auth.users/profile/trip rows hoặc secret literals. Repo signup function lấy raw_user_meta_data.role; cloud body UNKNOWN.

REST401: inspect correct project/key/config/exposure trong trusted environment; output safe status/code, không paste key hoặc rotate tùy ý. Missing access ghi UNKNOWN, dependent migration apply blocked; prepare unit-client parts. Metadata snapshots SRC-DB-001/002 không cần owner chạy lại.

## R01 — database privacy/role

Exact allowlist (new proposed paths, ≤3):
- supabase/migrations/202610080001_profile_privacy.sql
- supabase/tests/profile_privacy.sql
- docs/phase-2/execution/R01.md

If migration history already exists, inspect first; baseline-capture cần tách task trong5 files, không invent history hoặc remote db reset. Plain SQL assertions/transaction fixtures; không thêm pgtap/dependency mặc định.

Steps/contracts:
1. Capture baseline/recovery và verify expected schema/target; fail on drift. Migration transaction theo statements supported.
2. Replace public profiles SELECT true với authenticated own SELECT id=auth.uid(); không add owner permissive policy cùng true. Own UPDATE explicit WITH CHECK; no client profile INSERT/DELETE; signup qua Auth trigger.
3. Thu table UPDATE và residual actual client column/inherited privileges; grant UPDATE(full_name,phone,avatar_url,address) only. Protect role/email/id/created_at/updated_at. Không coi revoke riêng UPDATE(role) đủ khi table UPDATE còn. Nếu tự timestamp cần reviewed DB trigger trong migration.
4. anon chỉ SELECT destinations trong4 tables; authenticated catalogue SELECT, own trips/activities CRUD, own profile SELECT/allowed-column UPDATE. Thu client TRUNCATE/REFERENCES/TRIGGER/catalogue writes. Check PUBLIC/inherited/default grants; verify effective privileges sau migration. Preserve trusted server/Auth dependencies; không revoke service_role toàn bộ.
5. After deployed-body inspection: signup always customer, không trust raw metadata role; qualified object names/safe search_path; preserve Auth/OAuth no-email handling/fullname constraints. Review function EXECUTE ACL theo Auth dependency; không phá signup. Existing privileged records không auto downgrade hoặc auto trust; source of legitimate role assignments cần owner/admin verification riêng.

Meaningful DB tests trên disposable synthetic A/B subjects và anon: own profile read/allowed editPASS; B/anon không thấy A; protected-column updatesDENIED; signup metadata role=admin yields customer; email/OAuth signup tạo profile; catalogue readable/client writes DENIED. Own trip/activitiesCRUDPASS; B/anonDENIED; owner/reparent forgeryDENIED; FK cascade trên fixtures. Assert has_table_privilege TRUNCATE=false, không thử xóa bảng thật. Admin harness switch actual app role/JWT claims; postgres/service_role output không chứng minh RLS.

## R02 — trusted role và demo

Exact allowlist ≤3:
- lib/features/auth/providers/auth_provider.dart
- test/auth_navigation_test.dart
- test/auth_role_security_test.dart (new)

Live Auth không dùng userMetadata.role làm privileged role. Candidate trusted source owner-only profiles.role sau R01; default customer đến khi verified response. Role fetch binds subject/auth epoch; stale after logout/switch ignored; failure không cấp privileged role hoặc phá session. Server/RLS enforce authority, UI role không đủ.

Demo identities explicit provenance; keep existing demo tests/feature nếu có, nhưng demo role không remote credential. Active real Supabase session phải match app auth mode, no save/fetch bằng synthetic IDs hoặc stale live session. Nếu cần newfile ngoài allowlist, split amendment trước code.

Tests inject minimal service/client hooks trong same file: spoofedmetadata admin+trusted customer →customer; profilefailure non privileged; late A response ignored; demo không remotecall. Không thêm packages. Không xóa demo tests để che regression.

## R03 — trips adapter và save ack

Exact allowlist5:
- lib/features/trips/models/saved_trip_model.dart
- lib/features/trips/services/trips_service.dart
- lib/features/trips/providers/saved_trips_provider.dart
- test/saved_trip_model_test.dart (new)
- test/saved_trips_provider_test.dart (new)

Keep Dart tripPlanData property để preserve callsites; writer ai_plan_data, reader primary ai_plan_data + legacy trip_plan_data fallback cho old fixtures. Existing JSON roundtrip lossless; malformed payload/invalid ID không fake persistedtrip. Insert server UUID/default created_at, no empty id; required title/destination/owner; statusdefault planning. Canonical payload/version/date changes deferred R06, không silently timezone-migrate.

Service from('trips') cho fetch/save/delete; owner derived/validated active true SDKsession, reject caller-owner mismatch. Client filter không thayRLS. Injection để tests no package. Fetchfailure != legitimateemptyresult bằng typederror/result hoặc provider-caught exception; safe errors không log raw payload hoặc token.

Provider save success chỉ sau valid server ID + ownerack; no RAMfallback rowidempty/true. Failure giữ input/currenttrip; expose existing error state; nếu UI wiring cần extra files tách R03-UI allowlist trước code. ChưaSQLite nên không claim durable draft. Delete ack distinguish not found/wrong owner/error; optimisticrollback chỉ current epoch. Timeout with possible committedinsert hiển thị ambiguity; không auto-retryinsert tạo duplicate; durable import retry thuộcR06.

Tests: payload null/legacy/roundtrip; requesttable trips; failurefetch !=empty; savefail/401 nofake success/RAMinsert; invalidack/wrong owner rejected; validack once; deletefailrestore only currentaccount. Controlled fakes no live secrets/network.

## R04 — session lifecycle

Exact allowlist≤4:
- lib/main.dart
- lib/features/trips/providers/saved_trips_provider.dart
- test/saved_trips_provider_test.dart
- test/auth_navigation_test.dart

Provider-compatible Auth→SavedTrips lifecycle hook; true remote subject requires active session/mode match. Logout/switch clear account RAM/error/loading and increment epoch; newsubject loads separately. All fetch/save/delete capture subject/epoch, mutate only current matching state; lateack/rollback must not restoreAtoB. Dispose-safe notifications. clearLocal resetsloading and invalidateswork.

Keep Guest/manual TripProvider state; no blanketclearGuestdraft. Disk account snapshots not implemented batchA; diskpurge acceptance remainsR06.
Controlledcompleter tests: slowAfetch→logout/Blogin→B datawins; A save/delete completion afterswitch ignored; error exitsloading; Guest statekept; demo no remote access. Real signout test separately, quickdemo not OAuthevidence.

## R05 — verification/rollout

Conventional commits per task, fix/* branch, selective stage, ≤5 files/task; source baselines recorded, no ownerreset or caches/env/tokens/keystore. Format changed Dart only; targeted tests then flutter analyze --no-pub and flutter test --no-pub. Keep existing assertions; tile400not excuse. Unchangedbackend no repeatedMavenrequired; backenddelta outsidebatch needs amendedtask/Mavenchecks. R01 executedstaging DB tests/effectiveprivileges needed, staticSQLreview notPASS.

Codex reviews exact base→head, CI/logs/findings; owner review/merge. Live DB apply only after exact migration SHA, verified project oavbymauorhmrjcustzw, backup/recovery, staging PASS and owner specific rollout authorization. If blocked publishreviewablePR, no live DONE claim.

Recovery capture policies/grants/functions/schema + appropriatebackup before rollout; forwardfix/feature restriction preferred. Không rollbackmặcđịnh profilespublic hoặc rolewrite; privacy-preserving recovery reviewed. Approllback requirescompatible schema; preserveIDs/payload. Không deleteproject/DB.

## Batch B/C contracts chưa freeze

R06 cần canonical dates/IDs/payload/version, SQLite platform/dependencyapproval, importkey(owner,draftId,revision/digest), atomictrip+durablereceipt. Samekey retry same trip, different digest conflict, server ack trước transferred, failure keeps draft, logout purges account snapshots. Choose JSON/projection source of truth; no independent dualwrites. Proposed tables absent không nghĩa phải create all.

R07 Gemini key server only, verifiedmodel/account/cap/host/JWT; Guest sharedgeneration/chat/advice/modify3logical requests/day reset00:00Vietnam; system failure no usable result no charge; atomic reservation/idempotency/minimal context/redaction. Other TTL/authquota numbersPROPOSED. Not in batchAauthorization.

72 places/12 samples/source/license cầndata task riêng; officialsubmissionchecklistOPEN. Không bỏMUST để fitdeadline. Stop dependentaction khi unknown target/body, destructiveunapprovedchange, secrets, >5 files hoặc3unexplainedfixattempts; tiếp tục independentauthorizedwork. Return Changed/Why/Testing/Problems/Lesson with WRITTEN/TESTED/STAGING APPLIED/LIVE APPLIED phân biệt.


## Requirement traceability

| Task / finding | Phase 1 requirement / acceptance |
| --- | --- |
| R01 / DB-002–004 | FR-SEC-001/002; AC-034/054; RC-003/005 |
| R02 / DB-006 | FR-ACC-001–004, FR-SEC-001; AC-001–004/034; RC-005 |
| R03 / DB-001, INT-002 | FR-TRP-004–006; AC-014–016; server acknowledgement phần AC-053, durable import chưa đạt |
| R04 / INT-003 | DEC-010; AC-040/045/055; disk snapshot purge còn R06 |
| R06 / DB-005 | DEC-006; FR-ACC-005/006; AC-005/006/053/055, chưa thực thi |
| R07 / INT-004/007 | FR-AI-001–007; AC-017–023/034/035/051/054; chưa authorize public AI |

Task tests phải kiểm hành vi tương ứng; mapping requirement không biến NOT RUN thành PASS.
