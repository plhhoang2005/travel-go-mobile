# B4 Guest Import Implementation Plan

> For agentic workers: Owner requires Codex-only implementation with superpowers
> OFF. Do not invoke execution/TDD/subagent skills; follow the ordinary verified
> test-first workflow below. This overrides the writing-plans default header.

**Status:** PROPOSED for Owner review, 2026-10-13. No B4 source implemented.
**Goal:** Explicit selected-revision import with durable retries and owner fencing.
**Architecture:** Service coordinates existing B2 transactions and exact B3 RPC.
Provider holds consent/display state; store adds owner-scoped journal inventory.
**Tech stack:** Existing Dart/Provider/Dio/Supabase/uuid/crypto/SQLite FFI only.
**Spec:** [B4_DESIGN_SPEC.md](B4_DESIGN_SPEC.md); frozen B3
[R06_IMPORT_CONTRACT.md](execution/R06_IMPORT_CONTRACT.md).

## Global constraints and exact allowlist

Base observed main: cc729498959dab615900d61bff0b5bbb1390a79e (#22 merge).
At execution reverify actual main/head/status; preserve all untracked Owner files.
Create codex/phase-2-b4-guest-import from approved base, never commit/push main.
Do not move checkout during this planning task. Owner approves the fifth-file
scope addition below as part of this concrete plan, not implicitly from old B4.

1. MODIFY lib/features/trips/services/local_trip_store.dart — inventory API only.
2. NEW lib/features/trips/services/guest_import_service.dart — coordinator, typed
   import/confirmation/result/auth/transport structures in the same focused file.
3. NEW lib/features/trips/providers/guest_drafts_provider.dart — selection/state.
4. NEW test/guest_import_service_test.dart — real store + fake HTTP; inventory tests.
5. NEW test/guest_drafts_provider_test.dart — provider lifecycle/consent tests.

This five-file implementation excludes this planning document and the spec;
keep review docs local, or submit a separately approved docs-only packet.
No changes to local models/schema, main/auth/UI, dependencies/native, Supabase
migration, backend or protected docs/superpowers. No auto database execution.
No automatic import/retry at login/startup, no Decision Engine recomputation.
Scope includes input-only and plan-only; primary rollout remains separate.

## Review focus

- Old revision pending after newer edit/restart: discover from journal inventory.
- Auth changes immediately before HTTP dispatch: frozen A bearer never becomes B.
- Remote commit succeeds/local acknowledgement fails: retained source, same-key retry.
- Server deleted receipt: retained Guest source and attention outcome, no recreation.
- Duplicate tap/partial batch/dispose: no duplicate dispatch or stale UI success.

## Interfaces to freeze on Owner approval

In local store:
`Future<List<LocalImportJournalRecord>> listImportJournals({required SessionHandle handle})`.
Returns checked owner-only metadata, states staged/pending_ack/quarantined/committed;
order updated_at DESC, device_scope ASC, draft_id ASC, source_revision ASC.
Use existing _executeGuardedAccountOperation; validate receipt/timestamps/identity
and active source+digest before returning. No unguarded raw SQL access from service.

In service file, public immutable types:
`ImportSource(deviceScope:String, draftId:String, revision:int, digest:String)`;
`ImportConfirmation` contains owner, handle generation, exact sources; constructor
not public. Service/provider create it only via an explicit confirmation method.
`GuestImportOutcome` contains source, status, optional ImportCommitResult and
sanitized reason. Status enum: committed, alreadyCommitted, pendingRetry,
deletedNeedsAttention, rejected, deploymentBlocked, sessionInvalidated.
No receipt/payload/account details published after generation invalidation.

`GuestImportAuthContext` supplies current real Supabase Session (nullable) through
an injected reader; production reader uses configured client's auth.currentSession.
`GuestImportTransport.importDraft` takes frozen auth credentials and journal/source
text; production uses injected Dio with fixed HTTPS RPC URL and per-call headers.
Test adapter captures outbound requests without exposing real credentials.
`GuestImportService({required LocalTripStore store, required GuestImportAuthContext auth,
required GuestImportTransport transport, String Function()? requestKeyFactory})`.
Methods: `void bindSession(SessionHandle handle)`, `void unbindSession()`,
`ImportConfirmation confirmSelection(List<ImportSource> sources)`,
`Future<List<GuestImportOutcome>> importConfirmed(ImportConfirmation confirmation)`,
`Future<GuestImportOutcome> retry(ImportSource source)`, `void dispose()`.
bind verifies real auth owner and demo exclusion; never activates store itself.
retry is explicit and may only resume an existing same-owner journal.

Provider: `GuestDraftsProvider({required LocalTripStore store,
required GuestImportService service, required String deviceScope})`.
Methods: `void bindSession(SessionHandle handle)`, `void unbindSession()`,
`Future<void> reload()`, `void select(ImportSource source, bool selected)`,
`Future<List<GuestImportOutcome>> confirmAndImport()`,
`Future<GuestImportOutcome> retry(ImportSource source)`, `void dispose()`.
Read-only getters: drafts, attempts, selectedSources, outcomes, isLoading, isImporting,
errorMessage. Lists immutable. Guest reload works without session (no journal read).
Bind/unbind synchronously clears selection/outcomes; bind starts no RPC.
Provider methods preserve ChangeNotifier disposal/generation checks after awaits.
B6 caller activates/invalidate/purges B2; provider does not duplicate that authority.

## Task 1 — Inventory and durable coordinator

Files: local_trip_store.dart, guest_import_service.dart, guest_import_service_test.dart.

- [ ] Verify base tree/status and create approved feature branch. Record exact base.
- [ ] Build independently owned temp SQLite directory harness with FFI; teardown
  separately attempts store close then deletion, verifies resolved directory is
  the exact harness-created child of system temp. No wildcard/parent deletion.
- [ ] Write failing inventory tests: owner A cannot list B; stale/demo/blocked
  handle rejects; pending revision1 remains discoverable after revision2 edit and
  reopen; corrupted active source/receipt/timestamp rejects; committed needs no source.
- [ ] Run new tests red; add listImportJournals without schema change or broad refactor.
- [ ] Write failing coordinator tests in groups G01–G12 below using real store,
  deterministic HTTP adapter/Completer and seeded fake auth sessions. No real tokens.
- [ ] Implement interfaces and spec sections4–7. Reuse getJournalEntry,
  prepareImportJournal, markJournalPendingAck, getDraftRevision(revision:...),
  reconcileQuarantinedAttempt and commitImportAck exactly as their existing APIs.
- [ ] Use persisted key, exact payloadJson, captured bearer and single-flight;
  no network within store queue, no imported receipt as fallback.
- [ ] Enforce three-key envelope and B1 raw/canonical/digest checks before ack.
  Check v1 explicitly because B1 decode supports a legacy adapter.
- [ ] Run service suite green and B1/local-store regressions. Resolve only findings
  in allowlist; if schema/API expansion becomes necessary, stop with exact evidence.

| Group | Required assertions |
| --- | --- |
| G01 Inventory | owner/stale/demo/blocked/source corruption; old pending revision survives edit+reopen |
| G02 Consent/source | no confirmation/no send; edited digest rejected; plan:null and request:null exact bytes preserved |
| G03 Durability/order | HTTP adapter asserts pending row exists before dispatch; marker/preparation failure sends zero requests |
| G04 Same-key retry | lost reply after simulated remote commit, close/reopen, new service instance: identical six arguments; one fake remote trip |
| G05 Double tap | one in-flight dispatch; different revision remains separate; batch partial failure gives per-source outcomes |
| G06 Strict response | extra/missing envelope/receipt keys, status/type/version/UUID/owner/key/scope/revision/digest mismatch rejects without consume |
| G07 Bytes/limits | Unicode/false/date/fallback exact; altered whitespace/number formatting rejects; size/depth/count/identity boundaries reject before send |
| G08 Local ack rollback | inject each B2 ack hook; no success/source consumed; reopen then same-key retry commits once |
| G09 Account race | A→B before dispatch/while waiting/before local commit; captured A header only; no A receipt reaches B or B snapshots |
| G10 Quarantine | B cannot resume A; explicit A retry reconciles; malformed/unauthorized/deleted reply keeps source pinned |
| G11 Deleted | verified deleted+null text yields attention; source+journal remain after reopen; no new key/snapshot/recreated trip |
| G12 Already committed | checked stored receipt/snapshot returns idempotent result without consumed source or network; corruption fails |

Every receipt mutation case starts from a valid fixture and changes only its
tested field; fake transport proves dispatch/order/argument behavior, not SQL atomicity.
When conflicting selection calls race, loser may safely reject before HTTP; assert
persisted key identity is never replaced. Invalidating an operation may leave server
committed; test later explicit retry resolves it, not fictional remote rollback.

## Task 2 — Provider selection and lifecycle

Files: guest_drafts_provider.dart, guest_drafts_provider_test.dart.
Consumes Task1 exact interfaces; produces callable state for future B5–B7.

- [ ] Write failing G13 consent tests: constructor/reload/bind sends zero RPC;
  no preselection; confirmation binds exact digest/revision/account; cancellation
  before confirmation sends nothing; newer edit is never auto-selected/imported.
- [ ] Write failing G14 restart/status tests with real SQLite: reload exposes Guest
  current drafts and this owner's older pending attempts; partial batch outcomes;
  deleted attention remains distinguishable after explicit retry post-reopen.
- [ ] Write failing G15 lifecycle tests: logout/account switch/dispose while loading
  or importing; immediate selection/private-result clear; late awaits cannot call
  notifyListeners or republish prior owner data. Guest source persists.
- [ ] Implement provider getters/actions with operation generation and disposal guards.
  Delegate durable acknowledgements to service/store, never mutate journal SQL.
- [ ] Run provider tests green; verify B4 does not wire production startup/auth/UI.

## Task 3 — Exact-head verification and review handoff

- [ ] Run format check on five allowlist files; no unrelated formatting.
- [ ] Run `D:\flutter\flutter\bin\flutter.bat test --no-pub test/guest_import_service_test.dart test/guest_drafts_provider_test.dart`.
- [ ] Run codec/local-store regression suites, then full `flutter test --no-pub`.
- [ ] Run `flutter analyze --no-pub`; record actual exit/counts/commands, not estimates.
- [ ] Inspect diff/whitespace/status; stage ONLY exact five approved paths; verify
  no untracked docs/review/Owner items entered commit. Conventional commit and PR.
- [ ] Attach created PR and check GitHub CI on exact final HEAD; no Owner merge.
- [ ] Handover Changed/Why/Testing/Problems/Lesson Candidate; describe lost-response
  sequence and where evidence is simulated vs real SQLite vs prior B3 SQL.

## Deployment and completion limitations

Implementation completion is source+FFI tests+CI, not enabled Guest import in app.
Staging HTTP/auth E2E is a separate explicitly authorized task with controlled
real auth identities; do not use primary creds or infer E2E from fake HTTP.
Primary B3 apply also requires a separate concrete rollout and Owner authorization.
B5 planner save, B6 auth/startup/purge, B7 consent UI, B8 viewer, B9 integration remain.
If a 25-call/5-file/3-repair bound is reached, preserve a checkpoint; do not silently
create a larger packet, invoke subagents or change permanent rules.

## Planning self-review and handover

Spec1–2 -> scope/base; spec3 -> Task1 inventory; spec4–6 -> Task1 G02–G12;
spec7 -> Task2 G13–G15; spec8 -> Task3 exact-head and deployment separation.
All proposed public interfaces are declared above; no new DB states or receipt
mutation required. Selection and deviceScope lifecycle boundary explicit.
Changed: two planning docs only. Why: missing old-revision inventory and auth
dispatch fencing need concrete design before code. Testing: source/docs inspected;
B4 analyze/test/HTTP E2E NOT RUN. Problems: fifth-file extension awaits Owner;
primary deployment remains unapplied. Lesson: persist and rediscover attempt
identity independently of a draft's latest revision; pin both identity and auth.
