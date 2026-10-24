# B5 Planner SQLite Guest Drafts Implementation Plan

> For agentic workers: Codex-only, superpowers OFF for implementation/fixes/tests.
> Owner's mode overrides default execution/subagent-skill instructions. No agents.

**Status:** PROPOSED for Owner approval, 2026-10-13. No B5 source implemented.
**Goal:** Deliberately save/open Guest planner drafts, with exact request/result binding.
**Architecture:** TripProvider coordinates B1/B2; main owns a lazy shared SQLite runtime;
two existing screens provide explicit save/list/open/new actions.
**Tech stack:** Existing Flutter/Provider/SQLite/path/uuid/codec. No dependency changes.
**Spec:** [B5_DESIGN_SPEC.md](B5_DESIGN_SPEC.md), incorporating Owner's two answers.

## Global constraints and allowlist

Approved foundation main observed 805dde1e79d99f10a7565985fddb367fe7b582bd (#23 merge).
Execution must reverify main/base/head/status, preserve untracked Owner assets, and
create codex/phase-2-b5-planner-drafts from approved base. No checkout change in plan.
Exactly five implementation files:
1. lib/features/trip_planner/providers/trip_provider.dart — persistence/race-safe state.
2. lib/features/trip_planner/presentation/screens/home_planner_screen.dart — Guest UI.
3. lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart — save/result.
4. lib/main.dart — shared runtime and narrow planner auth-context injection.
5. test/guest_draft_planner_test.dart — provider/runtime/FFI/widget tests.

Review docs remain local/excluded from the five-file implementation commit. No change
to codec/models/store/service, pubspec, native, SQL, backend, permanent rules or Owner
protected items. No schema/database apply, automatic import/autosave, manual editor,
account snapshots or receipt UI. Every confirmed Guest save preserves original scope.

## Review focus

- Request edited while DE awaits: no mismatched request/response persisted.
- Workspace switched while SQLite save/load awaits: no false clean/success/overwrite.
- Failed initialization and disposal during open: no RAM fallback or leaked connection.
- Plan-only/out-of-range restored values: no fabricated input or slider crash.
- Guest→A→B→Guest: local Guest state retained, A's edited workspace never exposed to B.

## Interfaces

TripProvider constructor extends existing apiService injection with
`Future<LocalTripStore> Function()? localStoreLoader` and
`String Function()? draftIdFactory`. No persistence access unless loader provided.
Public additions:
- `void setPlannerContext({required bool isGuest, required bool isDemo,
  required String? ownerId, required int authEpoch})` — synchronous fencing/RAM context.
- `Future<GuestDraftRevisionRecord?> saveGuestDraft({String? title})` — exact acknowledged
  row, null on failure/stale publication; sanitized draftErrorMessage. No throw-to-UI.
- `Future<List<GuestDraftSummaryRecord>> listGuestDrafts()` — validate each exact current
  source before presenting summaries; fail visibly rather than hide corruption.
- `Future<bool> openGuestDraft({required String draftId, required int revision,
  required int expectedWorkspaceGeneration})` — exact revision/read/canonical restore.
- `bool startNewGuestDraft({required int expectedWorkspaceGeneration})` — caller confirms
  dirty work; sync return false for obsolete confirmation or unavailable Guest context.
- `Future<bool> submitPlan()` — true only for newly accepted matched response.
- getters `activeDraftId`, `activeDraftRevision`, `workspaceGeneration`, `isDraftDirty`,
  `isSavingDraft`, `isLoadingDraft`, `draftErrorMessage`, `hasPlannerInput`,
  `isRestoredLocalDraft`, `canPersistGuestDraft`.
Use B1 deepFreezeRequest/deepFreezePlan or captured canonical DTO. Preserve loaded
metadata internally; request edits/presets clear mismatched response; no new DTO file.
Existing currentRequest/currentResponse/getters remain source-compatible.

main adds `LocalTripStoreRuntime({required Future<LocalTripStore> Function() factory})`
with `Future<LocalTripStore> getStore()` and `Future<void> close()`; one cached opening
future, retry after failure, dispose prevents late return and closes connection.
Production factory resolves getDatabasesPath/path.join and awaits store.open().
Provider owns runtime once per app lifetime; TripProvider receives runtime.getStore.
AuthProvider is registered before ChangeNotifierProxyProvider<AuthProvider,TripProvider>.
Proxy updates fence RAM synchronously but defer/coalesce notifyListeners until
after the build stack; never notify directly from ProxyProvider.update.
Optional runtime injection for tests avoids native paths/network; no production
service locator silently creates a second DB. No new B4 coordinator registration.

## Task 1 — Real-store planner and runtime

Files: TripProvider, main, test/guest_draft_planner_test.dart.

- [ ] Verify base/source, create approved branch, record exact HEAD and allowlist.
- [ ] Create test harness using real SQLite FFI and independently owned temp directory;
  verify resolved target ownership under system temp before recursive deletion.
  Closing failure must not skip deletion; preserve primary assertion/failure.
- [ ] Add deterministic fake TripApiService counters/Completers (no real endpoint),
  injected runtime/store and exact canonical fixtures, including input-only/full/plan-only.
- [ ] Write failing T01–T09 cases below; observe relevant red controls before code.
- [ ] Implement runtime deferred getStore/close, no app startup gate or silent fallback.
  Retrying explicitly after storage error must never delete/reset an unknown DB.
- [ ] Implement provider save/list/exact-open/new APIs and dirty fingerprint/state.
  Reuse saveDraftRevision/getDraftRevision/listGuestDrafts only. Use scope 'default',
  UUID v4 once per new workspace; preserve existing scope/id/revision on open.
- [ ] Implement operation/workspace/context generations and Guest checkpoint isolation.
  Freeze before awaits; capture active identity; obsolete saves may persist disk row
  but cannot overwrite newer RAM identity or mark it clean.
- [ ] Fence init/submitPlan/updateRequest/applyPreset/dispose. No notify after dispose;
  older operation cannot set error/loading/result on a newer operation.
- [ ] Run provider/runtime tests green and B1/B2/B4 regressions; no store/model edits.

| ID | Required behavior/tests |
| --- | --- |
| T01 Durable save | request-only and full Guest save; FFI close/reopen exact bytes/digest/metadata/calendar/false/fallback |
| T02 Identity | opened draft edits save new revision under same header; new action uses distinct UUID; no deletion; concurrent save taps one write |
| T03 Save faults | fail initialization/open or actual B2 after_revision_insert hook: input intact, no false saved; explicit retry succeeds |
| T04 DE races | edit/preset/new/open/context change during response; latest only; input-only save while loading; superseded submit returns false |
| T05 Save races | edit/new/context change/dispose while queued save; persisted old row may remain but new RAM cannot be marked saved or overwritten |
| T06 Open safety | corrupt/unsupported/consumed source does not change RAM; exact listed revision; no plan/cloud/health request caused by open |
| T07 Missing/range | plan-only stays request:null when saved; new explicitly initializes input; ranges beyond Home sliders remain exact |
| T08 Auth safety | Guest RAM/disk survives A/B/logout; account/demo cannot persist Guest draft; A edits/results never appear in B/Guest; stale awaits discarded |
| T09 Runtime | one initialization for concurrent actions; retry after error; dispose during opening closes late store; injected store not closed by planner |

Inspected B2 exposes only onSaveDraftStepForTesting('after_revision_insert'), before
the pointer write. Do not invent a before_pointer_update hook or edit B2 for it.
T03 tests must fail inside the
actual transaction and prove reopened pointer/source state, not just fake a button error.

## Task 2 — Deliberate Guest save/open UI

Files: HomePlannerScreen, DashboardResultScreen, same test file.

- [ ] Write failing T10–T14 widget tests against injected real-store provider and
  AuthProvider Guest/demo/account states; override fake API/runtime in test tree.
- [ ] Add Guest save/list/new controls as Wrap/scrollable actions in Home; safe list
  and title/dialog helpers stay private classes in the existing screen file.
- [ ] Resolve exact revision before open; show confirmation only when dirty; capture
  workspaceGeneration and fail stale confirmations. Cancel does not save or alter RAM.
- [ ] Restore input-only to Home; full result uses explicit 'Xem kết quả đã lưu'; plan-only
  goes to saved-result dashboard with input controls disabled until new draft action.
- [ ] Adapt Guest dashboard save to local label/action. Retain separate real-account
  cloud save. Reduce manual DTO duplication using response.toJson core plus existing
  explicit fallback wrapper; keep ordinary cloud payload shape distinct from B1 envelope.
- [ ] Show 'Bản nháp trên máy', fallback indication and actual storage failures;
  state-owned title controller dispose/PopScope while saving, no stale/unmounted toast.
- [ ] Preserve actual loaded values outside slider ranges; clamp thumb only, explain
  display range, update payload only on actual gesture. No arbitrary default substitution.
- [ ] Submit navigation uses bool fresh-response result; no navigation from stale DE reply.

| ID | Widget acceptance |
| --- | --- |
| T10 Save | Guest input-only/full save succeeds; no login requirement; loading/double tap/failure retry; account cloud action stays distinct |
| T11 Open | list/manual selection/unsaved confirmation/cancel; restored result opened without API; new action requires confirmation when dirty |
| T12 Safety | open failure keeps workspace; stale confirmation rejected; disposal during save/load has no controller/notify/late snackbar errors |
| T13 Layout | widths360/390, text scale1.3, long Vietnamese title, empty/many drafts, scroll and bounds; no overflow or Slider assertion |
| T14 Auth/display | no demo local write; no preselection/auto-import; plan-only and input-only labels truthful; offline cached/fallback labels retained |

## Task 3 — Verification and Owner review

- [ ] Targeted guest_draft_planner_test.dart PASS with real SQLite FFI.
- [ ] Codec, local-store, B4 and auth-navigation regressions PASS; full Flutter suite PASS.
- [ ] flutter analyze --no-pub clean; format check exactly five paths; git diff --check.
- [ ] Inspect exact staged allowlist and source diff; no Owner/private/untracked docs
  included. Commit feature branch, create/attach PR, CI on exact HEAD, Owner merge.
- [ ] Handover Changed/Why/Testing/Problems/Lesson Candidate; distinguish source checks
  from actual Android restart and cloud E2E. Do not call all of AC-005 PASS from FFI.

Commands use D:\flutter\flutter\bin\flutter.bat and its bundled dart.exe; if sandbox
runtime fails, retry approved execution without changing source/dependencies.
Record actual counts/exits and failing-before-fix evidence, not planned numbers.
Android kill/reopen/offline lifecycle and platform storage smoke remain separate
evidence until run. If plugin requires native changes, stop with exact required diff.
No manual day/item editor, Gemini, server apply or B6–B9 implementation in this PR.

## Self-review and handover

Spec1–3 -> scope/runtime Task1; spec4 -> T04/T05/T08; spec5 -> T01–T07/T11/T12;
spec6 -> T10–T14; spec7 -> Task3. Existing test helpers and acceptance were inspected.
All caller/provider/runtime signatures above match proposed consumers; the actual
save fault label is verified above. No new dependency/schema/library needed.
Changed: two proposed design/plan files only. Why: RAM mismatch/stale-response gaps
must close with persistence, not simply add a SQLite save button. Testing: inspect
only; B5 analyze/test/Android restart NOT RUN. Problems: source implementation
awaits Owner approval; complete AC-005 needs device evidence. Lesson: capture a
matched immutable request/result and fence publication independently of disk commit.
