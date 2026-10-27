# B5 — Planner Guest drafts: design for Owner review

2026-10-13, Asia/Saigon. Codex-only. Brainstorming + writing-plans for planning;
superpowers OFF during future implementation. No B5 code/database action yet.

## 1. Intent, decisions and inspected state

User requests B5: connect planner to SQLite for deliberate Guest save/reopen.
Approved Batch B 1A–5A remain: no autosave/automatic import/editor/DE recomputation.
Owner confirmed in this task:
- Open through a draft list in planner; confirm before replacing unsaved work.
  Never automatically open the most recent draft or rerun Decision Engine.
- Saving an opened draft adds a revision to that draft. A separate explicit
  'Bản nháp mới' action starts another draft identity.

GitHub #23 MERGED; main observed 805dde1e79d99f10a7565985fddb367fe7b582bd.
Local remains codex/phase-2-b4-guest-import @cd4f5b4f151863d772ad0e5c44661b33a2e717c8,
tracked clean. No checkout update in this planning task.
TripProvider currently holds RAM request/result; updateRequest/applyPreset leave
old result in place and submitPlan has no operation fencing. Home has no draft
save/list; dashboard Guest cloud save asks for login. main has no local store.
B1 canonical payload deep-freezes request/plan. B2 supplies saveDraftRevision,
listGuestDrafts and checked getDraftRevision. B4 import coordinator is merged.
AC-005 requires actual Android offline restart; FFI proof alone does not close it.

## 2. Alternatives and chosen design proposal

A recommended: extend the existing TripProvider, two screens and main, add one
combined test file. Reuse B1/B2, lazy shared SQLite runtime, explicit save/open/new.
Five implementation files; no new dependency/schema/native permission.
B autosave/latest auto-open contradicts deliberate save and Owner's selection.
C a separate draft editor/navigation module duplicates planner and adds scope;
manual day/item editing remains deferred under decision 2A.
This is an architectural integration of existing approved components; the two
written artifacts are submitted together as concrete proposals for Owner review.

## 3. Storage and ownership

One app-scoped LocalTripStore runtime in main; path joins sqflite
getDatabasesPath() with LocalTripStore.defaultDatabaseName using existing path.
Runtime resolves/opens lazily when a draft action needs it, shares the same
in-flight initialization, and supports explicit retry after failed initialization.
Startup still renders app if storage is unavailable; fail visibly on local actions,
never report a RAM-only fallback as saved. Runtime owns close; TripProvider does not
close a shared injected store. Disposal during opening closes the late connection
and prevents publishing it. B6 will reuse this runtime rather than create another DB.

Use logical deviceScope 'default', as existing B2 defaults. It is a local namespace,
not an asserted hardware/installation identifier. Draft UUID v4 supplies distinct
source identity across installations; retry keeps original scope/id/revision.
Do not repurpose cleanup markers, introduce a new table or create a fresh scope per
launch. Any later scope migration needs its own compatibility design.
Guest draft APIs only; no SessionHandle activation, journal/receipt read, cloud
import registration or account snapshot access in B5. Demo cannot save real drafts.

## 4. Planner state and asynchronous integrity

Provider keeps working request, optional matched response, original metadata,
active draftId/revision, last saved fingerprint, workspace generation and operation
ids. Canonical payload creation uses B1; capture/freeze input and response at action
entry, before any await. Preserve calendar metadata/unknown optional values from
opened v1, with no invented dates/timezone/destination. A typed title can explicitly
replace metadata.title; default display placeholders are not inserted as user input.

updateRequest/applyPreset invalidate pending DE operations and clear currentResponse
when input changes; route presets through the same setter. DE submission captures
its immutable request and generation. Only its current operation may publish result,
error/loading changes; superseded/disposed operations cannot clear another operation's
loading flag. submitPlan returns whether a fresh response was accepted; Home navigates
only on true. Starting a new request clears old result, so save during loading stores
input-only instead of pairing new input with old result. Health init is also fenced.

Guest context is derived from AuthProvider.isGuest/isDemoSession/currentUser/authEpoch
in main's ProxyProvider; enforce Guest eligibility inside provider, not just UI.
Context changes invalidate in-flight DE/load/save publication, without deleting
Guest SQLite data. Preserve a detached Guest RAM checkpoint when leaving Guest;
signed-in/demo edits work on a separate RAM copy, never overwrite that checkpoint.
Returning Guest restores it; A→B starts from Guest checkpoint rather than A's edits.
Same-owner auth-epoch changes fence awaits but need not discard that owner's RAM.
This is a narrow RAM safety binding, not B6 durable account purge/startup authority.

## 5. Save/open/new contracts

Save is explicit and single-flight: use active draftId or allocate UUID once for a
new workspace. Concurrent taps share the same frozen save; every later explicit
save may allocate another immutable revision on that same header (no new list item).
Guest eligibility and generation checked before store access and after awaits.
Saving retains request even if SQLite fails. Only acknowledged disk writes show saved.
If user edits/new/restore/auth changes while a write is finishing, that captured
Guest revision may validly exist on disk, but it must not overwrite the new workspace
or mark it clean. Confirmation/toast refers to exact saved revision, not newer input.
Do not promise cancellation can undo a committed disk transaction.

Draft list is scoped Guest summaries, without automatic selection/open. Resolve each
displayed source through checked getDraftRevision to validate payload/digest and
derive a safe title; missing/consumed rows refresh list and report unavailable.
Selecting a row opens its exact displayed revision, never silently substitutes a
newer revision. Verify before replacing any workspace; failed/corrupt/unknown-schema
read leaves current input/result intact. Confirm when isDraftDirty; cancel changes
nothing. If workspace changes while read/confirmation awaits, reject stale confirmation
and re-prompt on a new explicit selection; no overwrite based on an obsolete dialog.

Request-only opens Home with input and no result; 'Chưa có kết quả lập lịch'.
Full payload restores matching input/result; explicit 'Xem kết quả đã lưu' opens
dashboard without submitPlan. Mark restored result 'Bản nháp trên máy', retaining
fallback labeling separately. Plan-only v1 opens dashboard as saved result without
inventing request/preset: hasPlannerInput=false, request controls/submit disabled
until 'Bản nháp mới' deliberately initializes a real preset request.
Keep currentRequest getter source-compatible for existing callers; its internal
placeholder is never serialized/displayed as the missing request in plan-only mode.

'Bản nháp mới' confirms replacing dirty work, then clears active identity/metadata/
response and starts preset input. It does not delete an existing saved draft.
No automatic save/import/cloud receipt on close, login, open or preset change.

## 6. UI and serializer boundary

Home: Guest-only 'Lưu bản nháp trên máy', 'Bản nháp trên máy', 'Bản nháp mới'; list
is a scrollable sheet with safe title/revision/time and exact-source open action.
Private helper widgets stay in the allowlisted screen; no new screen/widget file.
Input-only save allowed. Show local loading/retry/error independently from API loading.
Title editing is optional; controller owned/disposed by a small Stateful dialog.
Dialogs block dismissal while saving; no success snackbar after stale/unmounted await.
New/open confirmations explain replacing unsaved work; they do not initiate a save.
Dashboard Guest save action clearly saves locally. Existing real-account cloud action
remains separate; demo receives no persistent save path. No B7 import consent UI yet.

Use response.toJson() as shared DTO serialization core in local B1 and legacy cloud
serializer; legacy cloud wrapper may retain explicit isFallback. Do not send a B1
envelope to ordinary cloud CRUD or mutate its data contract. Calendar values stay
in local metadata; no conversion to legacy date columns in this packet.
Loaded values outside Home slider ranges remain exact in provider/labels. Clamp only
thumb presentation (budget 1M–15M, days1–7, people1–8); explain out-of-range value and
change actual value only on user gesture. Never clamp during restore or save.
Use Wrap/scroll/Theme tokens for new controls; widget checks at widths360/390.

## 7. Evidence and limits

Plan maps tests to save/open/error/races and real FFI close/reopen; fake DE counts
prove draft restoration sends no planning/cloud request. Android kill/reopen test
remains NOT RUN until an emulator/device task runs it; complete AC-005 is not inferred
from unit tests. No need to run live Supabase for Guest-only B5.
Scope excludes B6 durable auth/purge, B7 import UI, B8 account viewer, B9 integration,
manual itinerary editing, Gemini/quota and primary database apply. No backend edits.
Owner reviews/approves this spec and plan before implementation; then Codex-only,
superpowers OFF, <=5 files/25 calls/3 repair rounds, PR/Owner merge only.
