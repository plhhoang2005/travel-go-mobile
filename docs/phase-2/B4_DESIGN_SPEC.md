# B4 — Guest import coordinator: design for Owner review

2026-10-13, Asia/Saigon. Codex-only. Superpowers brainstorming/writing-plans
used for analysis/planning only. No implementation or database authorization.

## 1. Goal, evidence and boundary

User explicitly requests analysis and a plan for the next packet after PR #22.
Goal: transfer only explicitly selected/confirmed Guest revisions to the real
authenticated account, preserving source until a valid server acknowledgement
has been durably committed locally. Include request-only and plan-only payloads.
Never rerun Decision Engine, auto-import at login, or silently generate a plan.

Approved foundation: BATCH_B_DESIGN_REVIEW.md decisions 1A–5A and B4 scope;
B3's frozen execution/R06_IMPORT_CONTRACT.md; B2 compatibility merged in #22.
GitHub main observed cc729498959dab615900d61bff0b5bbb1390a79e.
Local checkout remains codex/b2-input-only-compatibility @45d94603d0d3aa2e308f275a9da7e0571d9c1e65;
tracked clean. Do not claim local checkout has moved to main.
Historical B3 staging execution PASS; primary B3 NOT APPLIED. No new live check.

Owner decision in this task: if a retry returns a verified deleted trip receipt,
KEEP Guest source and report that manual attention is required; never recreate.
The API/allowlist additions below are proposals awaiting Owner review.

## 2. Options and recommended scope

A (recommended): five implementation files, add owner-guarded journal inventory
to B2 and implement service/provider plus two tests. Finds pending older revisions
after restart even when current_revision now points to a newer edit.
B: original four files, exact-source retry only. Requires caller to retain every
pending identity elsewhere; current Guest summaries cannot rediscover old attempts.
This leaves the specified restart behavior incomplete, so do not select B.
C: expand B4 into UI, startup orchestration and database rollout. Exceeds a single
packet's review boundary; retain B5–B9 and separate rollout tasks instead.

## 3. Responsibilities

LocalTripStore stays sole owner of SQLite transactions, session-handle fencing,
source reservations, CAS, consume and durable receipt. Add listImportJournals
for the current owner: metadata only, all four existing states, deterministic
ordering. Reuse strict receipt/timestamp validation and guarded account execution.
For noncommitted rows, validate the exact source exists and its checked digest
equals journal digest; never return another owner's journals or payload.

GuestImportService owns RPC dispatch, frozen identities, strict response checking,
retry and typed outcomes. It receives an already active store-owned SessionHandle;
does not invent or activate handles, open databases or own app logout/purge.
GuestDraftsProvider owns selection, explicit confirmation and display state.
Authentication/startup wiring is B6; planner save wiring is B5; consent UI is B7.
B4 methods are callable/testable but are not registered in main or enabled in UI.

## 4. Authentication and transport

Use existing Dio for POST /rest/v1/rpc/import_guest_draft_v1, with an injectable
HTTP adapter. Capture Supabase currentSession user id, unexpired accessToken and
expiry at dispatch; reject absent/demo/mismatched sessions. Compare real auth owner
with handle.ownerId, never trust caller owner strings alone. Request header
Authorization is the captured bearer token; apikey is the configured public key.
No shared-client token mutation, mutable auth interceptor, automatic HTTP retry,
redirect forwarding, credential logs or persisted tokens. Fixed validated HTTPS
project URL; injected explicit staging config for separately authorized E2E.
Per-call headers pin A's credentials even if global auth switches to B.
Recheck current owner, service generation and store handle before dispatch,
after network awaits and immediately before local commit; B2 fences in transaction.
Same-owner token refresh may use a fresh token on the next explicit retry.
Existing dependencies only: Dio, Supabase, crypto, uuid, Provider and SQLite FFI.
No native configuration, DB schema, migration, backend or permanent-rule change.

## 5. Consent and durable request sequence

Provider selects exact (deviceScope,draftId,revision,digest), not a moving pointer.
Confirmation is provider-issued, immutable, bound to owner/session generation and
exact selection. Refreshing/reloading/binding a session does not confirm or send.
Only confirmAndImport after the user's explicit action starts a new attempt.
Use validated caller deviceScope matching B2 source; do not generate a fresh scope
per retry. App installation-scope lifecycle belongs to B5/B6, not this service.

For each confirmed source, sequentially:
1. Revalidate session and checked source; preflight B3 limits before any send.
2. Look up exact journal. Reuse its persisted requestKey if present; otherwise
   generate UUID v4 once and prepareImportJournal durably before sending.
3. staged -> markJournalPendingAck durably BEFORE dispatch. pending_ack retries
   unchanged. quarantined requires explicit same-owner online retry; transition
   through reconcileQuarantinedAttempt, with source still pinned.
4. Read exact revision, compare canonical text/digest with frozen selection and
   journal; send its payloadJson plus the six exact B3 RPC arguments.
5. Validate envelope/receipt/text and session; call commitImportAck once.
6. Report success only after local commit returns. This transaction records
   receipt, writes snapshot and consumes only this source revision.

Per-source single-flight map includes owner, storeGeneration, scope/id/revision.
Double tap shares an in-flight attempt; conflicting selection is rejected.
No network wait inside SQLite queue/transaction. Batch items run sequentially;
stop dispatch on session invalidation, otherwise return individual outcomes.
New revision edits never mutate or automatically replace the confirmed revision.

## 6. Envelope and failure semantics

Envelope keys EXACTLY status,receipt,payloadText. Import accepts committed/deleted
only; unavailable is only a read-RPC status and is invalid here. Receipt parser
is LocalImportReceipt.fromMap; verify source/key/owner/scope/digest against journal,
version 1, UUID receiptId/tripId and all ten fields on repeated committed receipt.
For committed: payloadText must be String, within limits, exact original source
text (or checked committed snapshot text), UTF-8 digest must match receipt/journal.
Decode jsonDecode(text) via B1, reject non-v1 before legacy adapter, then require
encode(decoded)==text and computeDigest(decoded)==receipt.contentDigest.
Do not merely hash reserialized server JSON. Dates/fallback/explicit false remain.
Preflight B3 bounds: 1 MiB UTF-8, depth32, arrays1000, objects256; identity128,
requestKey256, positive revision <=9007199254740991. Reject rather than truncate.

deleted: require null payloadText and a strictly bound receipt. Return deletedNeedsAttention;
keep source and pending journal, no commitImportAck, no fabricated snapshot and
no new requestKey. Do not persist receipt or add a terminal SQL state in this packet.
After reopen, explicit same-key retry rediscovers server deletion.
committed local journal: checked snapshot plus stored receipt can return alreadyCommitted
without resending or requiring consumed source; missing/corrupt snapshot is error.

Timeout/offline/unknown response/malformed ack/HTTP failure: retain source+journal.
Local commit failure after server success: pending remains; same-key retry safely
obtains original receipt. Never report cloud rollback or local success prematurely.
Unauthorized/conflict/deployment/corruption are distinct typed outcomes, sanitized
messages. No fallback acknowledgement. Missing RPC is deploymentBlocked, not success.
unbind/dispose: invalidate service/provider generations synchronously, discard late
response/display updates. B6 invokes B2 unbind/purge; B4 does not own durable cleanup.
Cancellation cannot undo server commit; preserve unresolved journal for reconciliation.

## 7. Restart and privacy

Provider reload uses checked Guest summaries PLUS listImportJournals for active
owner so older staged/pending/quarantined attempts remain visible. It sends nothing.
Other-account reservations surface as unavailable/busy without disclosing A identity,
receipt or private status. Logging/outcome toString must omit token and payload.
Selection is empty on bind/reload/account switch. Retry requires explicit action,
original revision/key and current owner; quarantined A is never resumed by B.
B2 source reservations remain in force for unresolved/deleted attempts. Releasing
them or reimporting a deleted source is a future explicit design, not B4 behavior.

## 8. Acceptance and review boundary

Implementation plan maps these sections to tasks/tests; real SQLite FFI verifies
durability while deterministic fake HTTP controls lost-response/races. Fake HTTP
is not PostgreSQL/SDK E2E. Live staging E2E and primary apply are NOT RUN here.
Owner reviews this design and implementation plan before any product code.
Implementation remains Codex-only, superpowers OFF, <=5 files/25 calls/3 repairs;
Owner merge only. No subagents/Docker/Owner-protected file access.
