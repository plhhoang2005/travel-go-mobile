# B6 — Account lifecycle and snapshot cache: Owner review proposal

2026-10-13, Asia/Saigon. Codex-only. Superpowers brainstorming/writing-plans
for analysis/planning; OFF during implementation. No B6 source/database action.

## 1. Intent and evidence

Goal: partition saved snapshots by authenticated owner, purge account-local data on
logout/switch/expiry, retain remote trips and untransferred Guest drafts, quarantine
pending import metadata, and recover safely after restart. Keep B2 Direction A:
SQLite readiness is not auth authority; SessionHandle comes from a trusted coordinator.
Owner selected in this task: offline reads when the session is provably safe;
uncertain cleanup locks account cache pending safe verification, Guest remains usable.
No automatic import or snapshot restoration into Guest TripProvider.currentResponse.

GitHub #24 MERGED; main observed 6019dd4f9731c7db66b698caf303f5053d75fb5f.
Checkout remains codex/phase-2-b5-planner-drafts @be720927f4e9e98928f15bb0a0752418ada18329,
tracked clean. Planning did not move checkout. Historical B5 tests/CI are not B6 evidence.
B3 primary NOT APPLIED; historical staging verification does not authorize rollout.

Inspected gaps:
- SavedTripsProvider is RAM-only. B5 runtime is shared/lazy; no account coordinator.
- B2 open resumes committed purge markers, but marker-write failure has no durable
  fact. activateSession cannot prove subject from an old owner id or snapshot row.
- AuthProvider.logout clears RAM and ignores asynchronous signOut failure; profile
  shows 'Đã đăng xuất tài khoản' immediately without awaiting durable cleanup.
- SavedTrip.fromJson fabricates missing num_days=3, budget_total=0 and createdAt=now.
  Import input-only rows can be misrepresented by the existing saved list.
- TripsService parses raw rows before the cache sees them; no B3 read-RPC adapter.
- B4 provider requires ready store and binds synchronously; production registration
  and deferred lifecycle notifications are not present.

## 2. Options and packet scope

A recommended: four independently reviewed packets, each <=5 source/test files.
First establish lifecycle primitives, then truthful logout wiring, raw snapshot
transport/projection, finally cache/import binding. Keep each PR usable with account
offline/import features disabled until their dependencies are proven.
B fit everything into the old five-file B6 allowlist: cannot correct raw DTO defaults,
logout caller and restart primitives without hidden side channels or unsafe rawDb use.
C always require network on restart: simpler, but contradicts Owner's chosen policy
and AC-016. Do not silently adopt C or erase acceptance requirements.

This design adds one app-private lifecycle metadata file, NOT a database table,
native dependency, credential store or authority inferred from SQLite. Exact file
protocol and the four packet allowlists require Owner approval before code.

## 3. Trusted subject and lifecycle authority

New LocalAccountLifecycleService owns a monotonically increasing coordinator epoch,
one serialized control queue, checked real Supabase Session reader, store runtime,
expiration deadline, and registered account consumers. Consume SDK sessions, not
AuthProvider.currentUser/user-supplied ids alone. Validate non-demo, matching owner,
nonblank bearer and known unexpired expiresAt; use captured credentials for verification.
Installed gotrue getUser(jwt) accepts an explicit token; verification compares returned
subject and current coordinator epoch. Never decode an arbitrary JWT as authority.

Control transition: synchronously remove handle, invalidate consumer RAM/import
generations and store.unbindSession; then persist lifecycle intent and await B2 purge.
New owner's binding waits for prior cleanup, intent durability and live proof checks.
Queue jobs may finish necessary old-owner cleanup but may not bind obsolete B/C epochs.
Tokens/fingerprints are never logged; actual tokens only remain in SDK/ephemeral memory.
SDK credential-changing actions are mutually exclusive with logout until its captured
signOut invocation finishes; late logout must never sign out a newly logged-in B.

## 4. Durable restart protocol — proposed, proof required

Path: one fixed account_cache_lifecycle_v1.json beside the app-private SQLite DB.
Version1 strict metadata: state, ownerId, coordinator epoch, session SHA-256
fingerprint, expiresAt, updatedAt UTC and schemaVersion. No token/receipt/payload.
States: active, sealed, revoking, signedOut. Missing/malformed/unsupported record
with existing account data is UNCERTAIN; never delete the DB to repair it.
An SDK session is identity authority; this file is only a lifecycle eligibility fence.

Before any account cache authorization in a foreground process, consume any sealed
permit by durably writing active. Only after the write succeeds activate B2 and bind
consumers. A crash while active is distinguishable from a clean offline restart:
deny restoration, purge uncertain account data and require a fresh explicit successful
authentication. Merely restoring the same SDK token is insufficient in that branch.

When app pauses, synchronously disable account consumers and unbind store. Seal only
after the control/SQLite queues reach a safe point, with no pending logout, cleanup,
credential-changing action or blocked namespace, and same captured SDK subject/token/
epoch/expiry. Seal records that exact still-valid session; never extend token expiry.
On resume, consume seal before enabling account consumers again. Do not treat pause
as logout: snapshots and Guest sources remain, no remote mutations/imports are sent.
Pause while auth/import/cache operations are unresolved does not earn a safe seal.

Normal offline restart: SDK restores the same unexpired session and strict seal
matches its fingerprint/subject/expiry; B2 resumes committed markers first, purges
other owners, persists active, then issues a fresh store-owned handle for this owner.
Unclean restart, expired/different/missing session, active/revoking/signedOut record,
or unresolved cleanup: no cache read/binding; purge safely, keep Guest working.
Fresh explicit auth after cleanup can authorize an empty cache and refetch cloud.
This deliberately distinguishes normal restart from abrupt termination before seal.

Logout preflight must consume any seal before beginning auth mutation/cleanup.
An active durable record already makes startup conservative if SQLite marker write
fails. Persist revoking, complete B2 purge/quarantine, persist signedOut; only then
allow a local-clean completion result. Failed preflight never reports successful
logout; failed/ambiguous intent leaves consumers locked, no offline eligibility granted.
Logout/expiry/account-switch during sealing cancels seal generation and serializes a
revocation; auth mutations must not bypass that queue or occur under a valid seal.

File writer uses an owned same-directory temporary file, flush and atomic replace;
writer/read failure denies eligibility, never destroys the prior record first.
Production must validate replacement semantics on Windows/Android. Never describe
flush/rename as hardware power-loss proof: native hard-kill/filesystem tests remain
required evidence. If fault tests can produce a valid stale seal after accepted
revocation or a bypassed SDK subject change, block implementation completion and
revise protocol; do not weaken Owner's policy or substitute an online gate silently.

## 5. Store and auth integration boundaries

B2 gains neutral, queue-owned cleanup APIs: listAccountOwnersForCleanup and
checkAccountCleanupComplete(ownerId). Only coordinator uses them while no handle
is active; include snapshot owners, journal owners and account markers. Parse all
rows strictly; no production rawDb. No registry row in local_cleanup_state.
Purge owners through existing purgeAccountData (three transactions, marker first);
never nest enqueue calls. Failed marker blocks process; durable active/revoking
file prevents blind offline reuse after restart. No source/journal rewrites beyond B2.

AuthProvider receives lifecycle gates/reader through injected callbacks; await startup
authorization before exposing a restored account. signedOut/expiry/SDK owner change
invalidates immediately. Token refresh of same owner fences awaits without deleting
cache unnecessarily, but must refresh the eligibility proof through the coordinator.
Expiry deadline/resume checks prevent stale AuthProvider.currentUser from authorizing
local reads merely because no SDK event has fired yet. Cancel auth subscription on dispose.

logout becomes Future<bool> with synchronous RAM hiding, awaited lifecycle cleanup and
captured SDK signOut; do not swallow failures. Profile waits result, shows completion
only when true and a clear retry/blocked message on failure. No remote trip deletion.
Local logout evidence and server-session notification are distinct; offline signOut
failures cannot be described as server revocation. A durable signedOut record prevents
initial SDK state from silently reauthorizing a previously revoked cache session.

## 6. Raw snapshot transport and truthful model

Preserve raw headers before SavedTrip parsing. New TripSnapshotService contains typed
RemoteTripSnapshot(payload, ownerId, tripId, remoteVersion?, fetchedAt, raw headers),
strict B3 read-envelope/receipt/text validator and injectable transport.
Imported trips use get_import_trip_snapshot_v1(p_trip_id) for authoritative receipt
and exact text. Validate ten receipt fields, requested trip/owner, UTF-8 hash,
B1 canonical bytes and version1. Missing RPC = deploymentBlocked, not legacy fallback.
deleted/unavailable from that RPC never recreates/imports a trip or exposes another owner.
Legacy rows use B1 decodeLegacyRow(raw), retain raw missing/null headers and use
remoteVersion=null, monotonic per-fetch fetchedAt. Do not fabricate a server version
from timestamps, headers or client-writable ai_plan_data/canonical text.

Fetch/save acknowledgements use captured owner/epoch; preserve original nullable
num_days/budget_total/created_at in SavedTrip and null-aware cards. Missing display
labels: 'Chưa có số ngày', 'Chưa có ngân sách', 'Chưa có thời điểm lưu'. No invented
request from a legacy plan/header; retain calendar dates in canonical metadata.
Snapshot adapter projections use canonical request counts/dates when present, not
legacy model defaults. Model constructor defaults become null; existing populated
rows/normal CRUD remain compatible. Invalid/incomplete rows cannot replace good cache.
Only MyTripsScreen currently consumes numDays/budgetTotal directly; modify it with model.

## 7. Cache provider, import binding and offline behavior

SavedTripsProvider uses lifecycle-authorized handle and shared runtime; exposes
checked accountSnapshots plus cache state/fetchedAt/version for later B8. Online
list/save ack updates per-trip snapshots only with complete valid data. Preserve
good snapshot on CAS conflict/write failure; report cloud ack vs cache failure separately.
An atomic list cache replacement is NOT claimed: B2 commits per trip. Validate entire
remote batch before writes, publish only after epoch guards; failed batch keeps last
verified display snapshot set, with explicit cache-error state and later retry.
A normal paginated REST list is not an authoritative absence proof. Recheck each
absent cached trip with an owner-bound per-trip read before eviction; failed/partial
list or read cannot imply deletion. Validated deleted receipt or acknowledged cloud delete
removes local snapshot; failed delete leaves it and never retries remote mutations silently.

Only connectivity/timeouts allow fallback to checked current-owner snapshots with
cache labels. Unauthorized/expired/owner mismatch causes immediate deny/revalidation/
purge, not offline fallback. Unknown-schema/corrupt cache fails visibly. No write/delete
remote while offline. No cache = unavailable; no generated itinerary or DE request.
Offline ordinary list cards show nullable metadata truthfully; full read-only viewer
and final version/time UI are B8. Cached payload never enters Guest planner RAM.

Register B4 import service/provider only after shared store ready and account lifecycle
binding approved. Late provider initialization checks latest epoch before bind. On
logout/pause/switch clear selection/outcomes synchronously and defer notifications
past ProxyProvider.update. Same-owner explicit online retry reconciles quarantine;
B cannot resume A. Binding/reload sends no import and never preselects Guest sources.
Coordinator owns handle/purge; GuestDraftsProvider does not activate account itself.
Services/transports/subscriptions are disposed before runtime.close; no second DB.

## 8. Scope, evidence and approvals

Four-packet plan below; each <=5 files/25 calls/3 repairs, each Owner review/merge.
No new dependency/native/platform/database migration, backend, Gemini or B7/B8 viewer.
App-private lifecycle file is a new proposed local mechanism requiring design approval.
SQLite/file tests prove controlled failures; SDK/network adapters are deterministic
fixtures. Native Android pause/kill/restart and real staging auth/RPC E2E NOT RUN.
AC-015/016/040/045/055 remain mapped to final integration evidence; AC-038 is DEFERRED,
not silently upgraded by mentioning its ID. No claim of immediate offline server revocation.
Owner approves B6.1 first; later packet implementation follows separate concrete
approval after predecessor merge. These planning artifacts do not authorize code/apply.
