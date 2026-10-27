# B2 Pre-Code Review R3 — NEEDS FOCUSED PLAN CORRECTION

Date: 2026-10-10. Reviewed B2_IMPLEMENTATION_PLAN.md Revision R2 (660 lines), SHA-256 `0606768A108B0E9342876E0106AD164662DCE34EDB2EA05C0F1C41B09CD832AE`, against prior review F1–F7 and merged B1 source. This is design review, not implementation authorization.

## Checkpoint and conclusion

Actual checkout: main @`0cbebee70b1d2203349beaad8e040c19eaf21671`, tracked clean. All three B2 implementation files are absent. Preserve exactly the proposed records/store/test allowlist, existing dependencies and Owner decisions 1A–5A. No code, application database, Supabase, backend, native configuration, checkout, protected Owner content, subagents or superpowers changed.

R2 makes substantive improvements but is **not ready for Owner implementation approval**. The new FK exposes a wrong deletion order; repeated receipts remain under-validated; session fencing remains incomplete. Correct the plan narrowly rather than reopening approved architecture decisions.

| Previous finding | Current design disposition |
| --- | --- |
| F1 | REPLACE removed from journal: accepted. Scope/identity/state/reconciliation details remain open. |
| F2 | Consume source and preserve header on ack: accepted intent. Concrete ack order and general deleteDraft contradict it. |
| F3 | Typed receipt introduced: accepted. Complete bindings, validation-before-no-op and committed result behavior remain open. |
| F4 | Store authority fields and Future queue introduced: accepted. Three-layer checks, monotonic generation and public read/lifecycle contracts remain open. |
| F5 | Composite pointer FK, integer checks, blank checks, receipt state checks and pending-implies-blocked added: accepted. Hex CHECK incorrect; frozen API and corruption handling still incomplete. |
| F6 | encode/decode call signatures corrected. Stored-byte hash verification appears only in prepare; all-read canonical/schema validation remains open. |
| F7 | Known version comparison, equal-content conflict and null/known policy accepted in principle. Shared guarded writer and legacy ordering/result details need explicit contracts. |

## Remaining findings and exact corrections

### R3-1 / P1 — Consume order fails with the new FK; deleteDraft loses high-water identity (F2/F5)

Plan lines 481–485 DELETE the source before clearing current_revision. ON DELETE RESTRICT at lines 67–69 rejects that DELETE immediately while the header points to it, even within the same transaction. The common case of importing the current draft therefore cannot commit. Section 2.3 describes pointer-first intent, but section 5.2 implements the reverse.

Correction: inside the same transaction, conditionally clear the pointer ONLY if it equals the consumed source, then delete the exact scoped revision. Keep a newer pointer. Validate source existence/digest before consuming, and check affected rows. Apply pointer-safe order to deleteDraft too. SQLite documents the immediate RESTRICT behavior: [Foreign keys](https://www.sqlite.org/foreignkeys.html).

Line 419 deletes the header, contradicting NEVER-reused counters and permitting revision 1 again for the same draftId. This can collide with retained committed journal/server receipt identity. Retain a non-payload header tombstone and highest counter for an existing draftId; blank its content projections when no current revision remains. Alternatively define a genuinely new generated draftId for a new draft and reject reuse of deleted identities. The current save API accepts arbitrary draftId, so merely promising UUID callers is insufficient. Add consume -> deleteDraft -> save same ID regression, including after reopen and after logout clears committed journal.

### R3-2 / P1 — Repeated ack still bypasses full receipt validation and lacks source scope (F3)

LocalImportReceipt at lines 194–245 has no deviceScope, constructor validation, positive integer/nonblank/digest validation or permitted UTC timestamp contract. fromMap uses casts/DateTime.parse without typed local error mapping. The committed branch at lines 469–473 compares only receiptId/key/trip/version/digest: it omits targetOwner, draftId, sourceRevision, committedAt and device scope. It executes before the first-ack owner/digest guards. A repeated receipt with wrong targetOwner or changed committedAt can be accepted.

Correction: define one validated local receipt identity with all semantic fields, including source scope (or enforce singleton scope as described below). Compare captured context, selected journal scope/owner/source/key/digest and receipt BEFORE either committed or first-ack handling. For committed retries compare every stored receipt binding including normalized UTC time; reject conflicting supplied payload/full-plan digest before a no-op if payload remains an argument. Validate nonblank receipt/trip IDs, positive revisions/version, exact digest and timestamp semantics. Drop rawReceiptPayload from the retained model or guarantee it contains only the whitelisted local receipt serialization, never raw network payload/tokens.

For first ack, validate exact frozen source existence, state and stored bytes in this transaction rather than trusting the historical prepare call. Permit only explicit staged/pending_ack state transitions. Define missing journal/source and malformed receipt as typed no-write results.

After consumption there is no Guest source; after later refresh the account snapshot may be newer than the import receipt. Define repeated-ack result semantics (same receipt plus current valid snapshot, without rollback to imported version), and a typed missing/corrupt snapshot outcome. Do not promise a historical ImportCommitResult that is not stored anywhere.

### R3-3 / P1 — Three-layer fencing is not actually specified; bindSession can reuse an old epoch (F4)

Lines 357–360 assign any caller epoch. unbind increments it, but a later bind can lower/reuse it. Example A epoch 7 -> unbind -> A epoch 7: an old A handle becomes valid again. This is an ABA problem even with private active fields.

Only prepare/ack show _assertCurrentSession on entering the queue (435/464). No recheck inside mutations after awaits or before result publication is specified. replaceSnapshot and account read/list/journal APIs have no full guards or concrete contracts. Step 1's comment claiming it prevents in-flight execution is stronger than the actual guard.

Correction: generation is store-owned and monotonically advanced on every binding/invalidation; return a captured handle from binding, or compare a distinct store generation in addition to coordinator epoch. Reject stale/reused generations. Bind only through later trusted auth coordinator, with nonblank/non-demo validation. Keep operation guards at queue execution, within the transaction around awaited mutation boundaries, and immediately before publishing the result. Define that logout can occur during SQL commit: an already committed stale write must not publish, and queued purge must remove it before namespace readiness returns.

Define guarded get/list snapshots and owner journal queries, Guest revision/list/delete, pending state transition and explicit same-owner online quarantine reconciliation entry points. All DB open/read/write/close/recovery operations share serialization without recursively awaiting _enqueue from its own task or calling outer db from inside a transaction. The Future queue sketch itself is viable and recovers task failures; no synchronized dependency is needed. Add deterministic barriers proving stale read publication, already-running transaction, queued mutation and rebinding cases.

### R3-4 / P1 — Marker write failure has no durable restart policy; purge boundaries remain implicit (F4/F5)

Separate marker transaction and startup selection of ALL blocked markers are accepted. But after Step 2 fails (540–541), cache is disabled only in RAM. On restart no marker may exist; open then sees no blocked rows and old account snapshots can be exposed after binding. The prior review explicitly requested this scenario.

Correction: define a conservative startup policy independent of marker absence, e.g. serialized startup purge of retained account copies with quarantine preservation before enabling any account cache, or an equally concrete safe revalidation design. Absence of a marker is not evidence that a failed prior purge completed. No production restore gate is requested.

Keep Step 2/3/4 as separate transactions within ONE queued cleanup action. Block readiness while open/recovery/cleanup runs, including bind attempts; failed cleanup must remain unavailable. Step 4 failure retains the blocked marker and retries on reopen; never unlock on attempted deletion alone. Capture cleanup owner before unbinding and do not use expired account-access guards to prevent cleanup. Document behavior for corrupt marker contents and marker-read failure.

### R3-5 / P2 — Hex CHECK matches only a prefix; scope omitted from journal identity (F1/F5)

`digest GLOB '[0-9a-f][0-9a-f]*'` (43/88/110) requires two hex characters followed by arbitrary characters. The submitted DDL accepts `aa` + 62 `z` characters. Use `length(digest)=64 AND digest NOT GLOB '*[^0-9a-f]*'` plus typed validation; apply to all three digest columns. [SQLite expression documentation](https://www.sqlite.org/lang_expr.html). The new integer, blank, pointer and marker checks pass the isolated negative SQL probes.

Journal PK and identity SELECTs omit device_scope (115,157,442,467), though revision identities and reservation index include it. Same owner/draft/revision across two scopes collides; existing prepare returns another scope's row if key/digest match. Choose one coherent contract: enforce deviceScope='default' at every public and DB boundary (aligned with existing singleton design), or include scope in PK, identity SELECTs, all retry comparisons and local receipt. Discuss server source identity before enabling multiple scopes; do not silently change B3 wire contract here. No scope change should be hidden as an implementation detail.

Declare frozen revision mutations private and validated (no payload/digest UPDATE API), including state visibility and source deletion restrictions. A SQL FK does not prove maximum allocated revision never decreases; the private API must preserve that invariant and read validation must detect inconsistencies.

### R3-6 / P2 — Correct B1 API calls do not establish read integrity (F6)

encode, computeDigest and decode(jsonDecode(...)) now match merged B1. However getters at 263–277 only decode, and prepare checks byte SHA at 441 without canonical/schema consistency. G14's read-corruption promise is not backed by an all-read validation sequence.

Correction: before returning any Guest/account payload record, hash original UTF-8 bytes and compare stored digest; parse/map-check; require explicit supported v1 envelope and row/envelope version agreement; decode B1; verify re-encode is byte-identical. Reject malformed or noncanonical stored data with typed local error, never silently canonicalize it. B1 decode accepts bare legacy plans, so local v1 rows must not accidentally invoke that fallback. Preserve original rows/files on failure. Apply the same validator to selected source inside ack and snapshot writer/read paths.

### R3-7 / P2 — Snapshot policy improved; shared writer/freshness outcomes need closure (F7)

Known lower version rejection, same-version/different-digest conflict, legacy-to-known upgrade and known-to-legacy rejection are accepted design rules. Require both replaceSnapshot and commitImportAck to use the SAME fully specified _upsertSnapshotTxn with transaction executor, owner/session/readiness and codec validation. Include explicit higher-version replacement and return after equal-version unchanged-content handling; line 519 must not accidentally fall through and overwrite after a conflict/idempotent branch.

For both null versions specify fetchedAt as a trustworthy capture ordering value, not delayed response arrival time; use a local fetch generation/CAS if timestamps cannot prove ordering. Define exact retry at equal time/digest, projections with absent metadata, and preserve newer snapshot on old repeated receipt. Do not invent nonblank title/destination defaults or recalculate Decision Engine results.

## Fifteen-group test matrix disposition

Real FFI file tests, reopen, source consumption, conflict rows, queue failure and known-version negatives are appropriate proposed tests, **not executed evidence**. Add explicit cases within the existing groups:

| Groups | Required additions/precision |
| --- | --- |
| G1/G3/G4 | Hex with valid prefix/nonhex suffix; scoped pointer restriction; pointer-before-consume; high-water after consume/delete/save/reopen; frozen-content API; save rollback after revision and header steps. |
| G5 | Scope mismatch cannot return another journal; exact retry retains state/key/bytes; key reuse cannot erase first source; committed retry after source removed; explicit pending/quarantine state/resume contracts. |
| G6/G7 | Each binding independently mismatched on first AND committed ack: owner/scope/source/key/digest/trip/receipt/version/time; missing/corrupt source; request-only ack; repeat with changed payload; snapshot refreshed after ack. Fault after EACH receipt/snapshot/pointer/source step with reopen inspection. |
| G8 | Higher/lower/equal versions, both-null out-of-order response and exact retry; ack and replace share policy; bad digest/canonical/schema preserves valid snapshot; absent projection metadata explicit result. |
| G9/G11 | Store generation ABA/reused bind, demo/Guest, late account read result, queued and in-flight writes using barriers; cleanup after queue error; open/bind/close concurrency and no nested-queue deadlock. |
| G10/G12/G13 | No transferred payload or private header projections remain Guest; minimal quarantine; fail after marker, during deletion, after deletion/before completion and DURING completion; real close/reopen; blocked/nonpending marker; marker-write failure then process restart with no marker. |
| G14/G15 | Wrong JSON type, missing schema/bare legacy, noncanonical bytes with valid hash, row/envelope mismatch, invalid receipt, unreadable DB/marker; no destructive rebuild; cleanup ownership/error preservation. |

G15 currently says independent close/delete but does not define the harness. Use a test-created resolved temp directory; close store even when test fails, attempt delete even when close fails, preserve primary test error/stack and report secondary errors. Resolve and verify exact test-owned target before recursive deletion; never accept app DB paths. Deterministic fault/barrier hooks remain inside the 3-file allowlist and use production SQL transactions, not mock persistence or sleeps.

## Evidence, limitations and next packet

Isolated probe executed exact R2 SQL block with synthetic data in Python SQLite `:memory:` (3.50.4), no app/Supabase DB. Probe: `C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/b2_r2_sql_probe.py`.

- Final exit 0. FK enabled; three scoped FK columns. Dangling pointer, fractional revision, blank ID and pending/unblocked marker rejected.
- Ordinary active cross-owner insert and duplicate source insert rejected; original journal key preserved.
- Proposed ack DELETE-before-pointer fails. Pointer-first consume succeeds and retains counter 1.
- Nonhex digest suffix accepted. Different device scopes collide in journal PK.
- Revision-first deleteDraft fails with pointer; deleting header first then revisions and saving same ID permits revision 1 again.
- Initial `py -3` launch failed because launcher had no installed runtime; `python` executed probe successfully. These are SQL design checks, not Dart/FFI or B2 PASS.

B2 Flutter analyze/test, real FFI, native Android/iOS, RPC and E2E: **NOT RUN**. No implementation exists. No PASS inference from expected SOP commands or historical B1 tests.

Antigravity next packet: amend ONLY B2_IMPLEMENTATION_PLAN.md, resolving R3-1 through R3-7 and test precision above. Preserve allowlist, pins, approved 1A–5A, Provider/Decision Engine and server boundary. Provide exact public API and transaction/fencing order, not claims that missing guards already exist. Return for Codex review; do not code B2 or apply database. Owner alone authorizes implementation after design review.

## Handover and Owner explanation

- **Changed:** Codex created this report and isolated SQL probe only; Antigravity's changes reviewed here are plan changes, not implementation.
- **Why:** Importing the current TravelGO draft must first release its local pointer, then consume its bytes in one transaction. The new FK protects that pointer, so deleting bytes first fails. After logout/login A again, an old A handle must never become valid merely because a supplied epoch was reused.
- **Testing:** Actual base/clean tracked status, B1 APIs, full amended plan and isolated SQL behaviors checked. No B2 analyze/test/FFI/native/server execution.
- **Problems:** Plan not ready for approval. Good structural improvements remain, but ack order, complete receipt binding, generation fences and marker-failure restart policy are blockers.
- **Lesson Candidate:** Stronger constraints expose incompatible transaction order -> define invariants and exact statement sequence together. Matching owner without a unique current generation permits old results to return -> bind fresh store generation and check again before publishing.
