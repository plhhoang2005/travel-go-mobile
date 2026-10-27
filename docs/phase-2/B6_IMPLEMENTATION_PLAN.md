# B6 Account Lifecycle and Snapshot Cache Implementation Plan

> For agentic workers: Codex-only; superpowers OFF for coding/fixes/verification.
> No subagents/execution skills/Docker. Owner mode overrides skill default header.

**Status:** PROPOSED for Owner review, 2026-10-13; no B6 implementation.
**Goal:** Trusted owner cache, truthful acknowledgement, durable cleanup and safe restart.
**Architecture:** lifecycle authority -> B2 guarded store -> snapshot adapters/providers;
four packets preserve <=5 changed files per implementation task.
**Tech stack:** Existing Flutter/Provider/Supabase/Dio/SQLite/path/crypto plus Dart IO;
no added dependency or database schema. **Spec:** [B6_DESIGN_SPEC.md](B6_DESIGN_SPEC.md).

## Global constraints and base

Main observed 6019dd4f9731c7db66b698caf303f5053d75fb5f after #24 merge.
Reverify main/HEAD/status per packet; preserve Owner/untracked items. Feature branches
codex/phase-2-b6-1-lifecycle through codex/phase-2-b6-4-cache; no main push/merge.
Do not change checkout for this planning task. Each next packet starts from its
Owner-approved predecessor merge; never invent future merge SHAs.
New independent lifecycle metadata file is proposed; no secrets/payload or SQLite
registry hack. No auto import, unconditional startup purge replacing AC-016, implicit
cloud rollout or primary migration. Planning docs excluded from source allowlists.

## Review focus

- SQLite marker write fails, restart restores old SDK session: active registry denies
  cached reauthorization; Guest available, cleanup/fresh auth required.
- Logout while a pause seal is being written: no stale valid seal after accepted logout.
- Expired session without event/token refresh/A→B→C: monotonic latest authority only.
- Legacy/input-only DTO null headers: no 3 days/0 VND/now or invented remote version.
- Remote ack succeeds but disk write fails: server success does not mean cache success.

## B6.1 — Lifecycle primitives and real-file fault proof (3 files)

Exact allowlist:
- NEW lib/features/trips/services/local_account_lifecycle_service.dart
- MODIFY lib/features/trips/services/local_trip_store.dart
- NEW test/local_account_lifecycle_test.dart

Interfaces:
- Store `Future<List<String>> listAccountOwnersForCleanup()`; neutral queue/readiness,
  strict owner/marker rows, active session must be unbound. No owner authority inferred.
- Store `Future<bool> checkAccountCleanupComplete({required String ownerId})` checks
  RAM block and persisted marker under neutral queue after pending SQL operations.
- Lifecycle service receives `Future<LocalTripStore> Function() storeLoader`,
  `Session? Function() sessionReader`, injected registry-file path/writer and clock.
- `void invalidateAccountContext()` immediately increments epoch, drops handle,
  invalidates consumers, unbinds ready store; notification deferred.
- `Future<SessionHandle?> establishAccount({required bool freshAuthentication})`;
  fresh proof comes from successful SDK auth path, never a UI owner-id parameter.
- `Future<void> prepareAuthenticationMutation()` consumes any seal before SDK mutation.
- `Future<bool> revokeAccount()` persists intent/purges/signedOut, remains denied on error.
- `Future<bool> sealForPause()`; `Future<SessionHandle?> resumeAccount()`; `close()`.
- Checked getters epoch/handle/state/error; states resolving/ready/paused/denied/cleanupFailed.
- `AccountSessionProof` is an immutable capture of ownerId, epoch, accessToken and
  expiresAt from the service's checked SDK reader; token only in ephemeral memory,
  no token-bearing toString. Consumers cannot use a forged owner id as proof.
- `AccountSessionProof captureProof()` and `bool isCurrentProof(AccountSessionProof proof)`
  validate private service issuer, current epoch/subject/token/expiry/ready handle.
  Proof constructor is private; constructing a Map or old SessionHandle cannot issue it.
- Consumers register synchronous invalidate and async bind callbacks with unregister token;
  late registrations bind only current authorized epoch. Service owns no payload display.

- [ ] Write failing real SQLite FFI + owned app-private-file tests L01–L08 below.
- [ ] Verify new store primitives require readiness/unbound lifecycle and no rawDb access.
- [ ] Implement metadata parser/writer and active/sealed/revoking/signedOut protocol
  exactly spec4; expose deterministic failures around write/flush/replace/SQL markers.
- [ ] Inject checked session proof and serialized control queue, not AuthProvider ids.
- [ ] Implement cleanup via existing per-owner purgeAccountData, no nested enqueue/schema.
- [ ] Run targeted tests/analyze/codec+store regressions/full suite, inspect exact 3-file
  staged diff, PR/CI/Owner review. Do not wire account cache yet.

| Group | Primitive proof |
| --- | --- |
| L01 | safe sealed+same valid SDK -> active commit -> fresh handle; fingerprint/owner/expiry mismatch denied |
| L02 | missing/malformed/unknown/active/revoking/signedOut record -> no offline binding; preserve Guest |
| L03 | failed SQLite marker commit after active registry, close/reopen -> deny, safe purge/re-auth; never reopen stale A cache |
| L04 | registry write/flush/replace failure and partial file -> fail closed; no deletion of prior record or permit before successful transition |
| L05 | logout/expiry/account change concurrent with seal; all controlled interleavings; no valid stale seal after accepted revocation |
| L06 | A→B→C queues, stale activation/cancel/purge errors; only latest subject binds, no swallowed cleanup success |
| L07 | pause invalidation/drain/blocked namespace; unfinished auth/import/cache prevents seal; resume consumes permit before reads |
| L08 | remote trips untouched; committed local receipts/snapshots purge, pending metadata quarantine, Guest drafts/revision counters remain |

Tests use actual file + SQLite transactions, validated temp-directory ownership and
independent close/delete cleanup. No real tokens/credentials. Windows atomic replace
behavior must be proven; Android hardware power-loss is NOT inferred. Any stale-seal
counterexample blocks B6.1 completion; revise design before wiring, not add unsafe fallback.

## B6.2 — Auth/logout and app lifecycle wiring (5 files)

Allowlist: lib/features/auth/providers/auth_provider.dart;
lib/features/profile/presentation/screens/profile_screen.dart; lib/main.dart;
lib/features/trips/services/local_account_lifecycle_service.dart;
test/auth_navigation_test.dart.

Consumes merged B6.1 service/registration; extends AuthProvider with injected lifecycle
gates/session reader, startup authorization and cancellable SDK subscription. main
owns service once beside shared LocalTripStoreRuntime; registers app pause/resume
observer/deadline and disposes service before closing store. No cache/import activation
unless dependent consumers subsequently register with a valid handle.
`Future<bool> logout()` hides account RAM synchronously, awaits captured coordinator
revocation and SDK signOut, exposes failure/retry instead of catchError swallowing.
Profile awaits it, guards mounted, disables duplicate taps, never shows success first.
Credential-changing SDK actions cannot begin until prepareAuthenticationMutation
succeeds and cannot overtake a captured pending logout/signOut.

- [ ] Write failing A01 startup restored-session gate, A02 truthfully awaited logout
  with registry/SQL/SDK faults, A03 account switch/expiry deadline without SDK event,
  A04 pause/seal/late SDK events, A05 dispose/subscription and duplicate tap cases.
- [ ] Implement injected gates while preserving trusted server role mapping and
  Guest planner checkpoint. No local role inference or arbitrary owner constructors.
- [ ] Distinguish local-clean logout from failed server-session notification; report
  SDK errors, do not claim remote revocation while offline. Durable signedOut forbids
  initialSession/tokenRefresh from silently restoring account eligibility.
- [ ] Exercise production main/Profile widget paths and SDK fixtures, then regression
  suite/analyze/format/5-file PR/CI. Device background-kill proof remains NOT RUN.

## B6.3 — Raw snapshot adapter and nullable saved cards (5 files)

Allowlist: lib/features/trips/services/trips_service.dart;
lib/features/trips/models/saved_trip_model.dart;
lib/features/trips/presentation/screens/my_trips_screen.dart;
NEW lib/features/trips/services/trip_snapshot_service.dart;
NEW test/trip_snapshot_service_test.dart.

Interfaces in new service:
`RemoteTripSnapshot` carries ownerId/tripId/CanonicalTripPayloadV1/remoteVersion?/fetchedAt/
original nullable headers; `SnapshotLookup` distinguishes ready/deleted/unavailable/
deploymentBlocked/rejected. `SnapshotFetchBatch` carries an immutable list of validated
RemoteTripSnapshot rows, fetchedAt and complete=false for normal REST pagination.
`TripSnapshotService({required String projectUrl, required String publicKey,
required bool Function(AccountSessionProof) isCurrentProof, HttpClientAdapter? adapter,
DateTime Function()? clock})` uses a dedicated Dio transport.
Methods: `Future<SnapshotFetchBatch> fetchSnapshots({required AccountSessionProof proof})`,
`Future<SnapshotLookup> readImportedSnapshot({required AccountSessionProof proof,
required String tripId})`, and `Future<SnapshotLookup> readOwnedSnapshot({required
AccountSessionProof proof, required String tripId})`. Every call checks proof before
dispatch/after awaits and pins credentials; no algorithms or store binding.
TripsService adds an owner-bound raw-row entry point for snapshot adapters,
existing ordinary CRUD acknowledgement checks stay owner-bound.

- [ ] Failing S01 B3 exact-envelope/ten receipt/bytes/canonical/version/owner/trip tests.
- [ ] Failing S02 deleted/unavailable/legacy/missing RPC behavior; no fallback invented.
- [ ] Failing S03 original null/missing counts/budget/created_at/calendar/fractional
  integers/date errors; model/cards retain null, no default3/0/now or silent .toInt().
- [ ] Failing S04 captured auth headers and A→B late replies; no cross-owner publication.
- [ ] Implement B1 legacy adapter from raw row; canonical imported version ONLY from
  strict B3 receipt read. Legacy remoteVersion=null and ordered fetchedAt.
- [ ] Make SavedTrip.numDays/budgetTotal/createdAt nullable, update two card consumers
  in MyTripsScreen with explicit missing labels. Ordinary populated constructors/CRUD
  keep source compatibility; no metadata inferred from defaults or synthetic request.
- [ ] Run model/transport/card tests and existing trips/auth tests before standalone PR.
  Raw adapter is not enabled cache; primary B3 missing remains deployment diagnostics.

## B6.4 — Saved cache and B4 import binding (5 files)

Allowlist: lib/features/trips/providers/saved_trips_provider.dart;
lib/features/trips/providers/guest_drafts_provider.dart; lib/main.dart;
test/saved_trips_provider_test.dart; test/auth_navigation_test.dart.

SavedTripsProvider consumes authorized lifecycle handle, store runtime and B6.3 adapter;
new read-only `accountSnapshots`, `cacheState`, `cacheErrorMessage` and per-item cached
time/version feed B8. All entry points (including existing loadTrips/syncWithAuth)
must pass lifecycle authority, never bypass through a user-id-only compatibility path.
Old injection-only RAM tests remain valid via explicit test fixtures, not production
automatic fallback to unauthorized RAM. Cloud ack and local cache status are distinct.

main registers late-initialized GuestDraftsProvider from ready shared store plus B4
service/Dio transport, attaches invalidation/binding callbacks and unregisters on dispose.
Expose nullable/not-ready state through a stable FutureProvider/facade until initialized;
do not create a fake store/second DB. Guest provider defers notifications on lifecycle
calls, clears selection/results synchronously and binds only latest handle generation.

- [ ] Failing C01 online fetch/ack caches complete valid DTO, C02 current-owner-only
  offline connectivity fallback, C03 401/403/expiry/corruption denies rather than fallback.
- [ ] Failing C04 delayed disk write/A→B/restart/purge error; no account payload in Guest.
- [ ] Failing C05 save cloud ack/disk failure, CAS conflict, malformed/partial remote batch;
  good cache retained, cache failure distinct. Do not claim atomic multi-trip transaction.
- [ ] Failing C06 absent-list candidate requires authoritative per-trip recheck;
  ordinary/partial paginated lists never prove deletion; ack delete vs failed
  delete, imported deleted receipt. No remote mutation retry or offline delete.
- [ ] Failing C07 import pending quarantine, explicit online A retry, B denied; no
  auto/preselected import on registration/login/reload. Stale async provider creation denied.
- [ ] Implement provider adapter/cache and production registration; let B2 own transactions.
- [ ] Run new and existing B1–B6 suites, full analyze/tests/format/exact-five-file PR/CI.
  Do not implement B7 consent sheet or B8 full snapshot viewer in this packet.

## Acceptance, completion and handover

AC-015 own trip/version/list -> S01/C01/C06, final real API/RLS+Android still required.
AC-016 offline normal restart -> L01/A01/C02 plus B8 viewer/B9 airplane-mode E2E.
AC-040 logout/expiry/shared device -> L03/L06/A02/A03/C04/C07.
AC-045 corruption/write failure/reconnect -> L04/S01/C03/C05, no immediate offline
server revocation guarantee. AC-055 purge preserves remote/Guest -> L08/A02/C04.
AC-038 remains DEFERRED; read-only view boundary still applies under AC-016.

Native Android pause/kill/restart/storage/file-replace and real staging auth/RPC E2E:
NOT RUN here. No primary apply, Docker, backend changes or additional package/native
config. CI/local tests prove source plus controlled fixtures, not deployed acceptance.
Every packet is separately approved/verified/merged; budget25/5files/3repairs each.
If interfaces must expand after predecessor merge, present concrete delta before code.

Planning self-review: spec3–5 -> B6.1/B6.2, spec6 -> B6.3, spec7 -> B6.4; all five
review focus failures map to tests above. Logout caller/model consumers inspected.
No source changed. Changed: spec and plan only. Why: lifecycle authority/SDK session
and snapshot DTO gaps cannot be solved inside old B6 allowlist. Testing: inspect only;
B6 tests/Android/HTTP NOT RUN. Problems: local metadata protocol and four packet
scopes await Owner approval; security invariants must pass before feature enable.
Lesson: a restored SDK session and an old snapshot owner are insufficient evidence
that a failed local logout/cleanup may be safely forgotten.
