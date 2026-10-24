# B2 Pre-Code Review R5 — TARGETED PLAN CORRECTIONS REQUIRED

2026-10-10. Reviewed B2_IMPLEMENTATION_PLAN.md Revision R4, 1012 lines, SHA-256 `F51A4D7265120DC4804127B8F8423773CF373D97E258CF7E908328EC52D828B9`, against previous review R4-1–R4-5 and merged B1 API signatures.

## Conclusion / checkpoint

**Not ready for Owner implementation approval.** Parser and all-read mapper corrections substantially close previous defects, but lifecycle activation/revalidation is not yet executable as a coherent contract, and the ten-field stored receipt comparison regressed to four fields.

Actual workspace is main @`0cbebee70b1d2203349beaad8e040c19eaf21671`, tracked clean. All three B2 implementation files are absent. Only this review document is created. No implementation, application DB, Supabase, dependencies, native/backend, checkout or protected Owner content changed/accessed. No subagents or superpowers. Existing 1A–5A and 3-file implementation allowlist preserved.

## Disposition of previous findings

| Previous finding | Revision R4 result |
| --- | --- |
| R4-1 | Active registry written before normal account operations is a useful design improvement; asynchronous activation and synchronous unbind introduced. Recovery states, activation cancellation and revalidation API still incomplete. |
| R4-2 | Strict is-int parsing, exact permitted keys, Z timestamp and direct constructor checks accepted at design level. Common incoming receipt/journal/handle checks and first-ack source digest comparison added. Stored receipt ten-field comparison remains open. |
| R4-3 | Checked row mappers now explicitly run in same-version/no-op and repeated committed ack. Raw-byte hash, canonical check, row schema and codec exception mapping accepted at design level. Account row completeness/type errors need final contract precision. |
| R4-4 | API table and common queue/transaction/publication template added. Need runnable open lifecycle, readiness/revalidation and activation fencing. |
| R4-5 | Legacy same-digest policy and max fetchedAt touch now agree with matrix; display-placeholder policy named. fetchedAt ordering origin still undefined. |

No design disposition means implemented or tests PASS. Previously accepted DDL/pointer/tombstone/generation architecture remains accepted; do not reopen it unnecessarily.

## Findings and focused changes

### R5-1 / P1 — Registry recovery and revalidation do not yet form a complete state machine (R4-1)

Registry at 333–351 now leaves a durable indication of a prior active session even if a later logout marker write fails. That closes the earlier absence-of-any-evidence problem in principle. However:

- Pending Revalidation at 348 is not specified as an exact durable or in-memory state, and neither activateSession (423–429) nor the common account template checks it explicitly. Both only mention ordinary cleanup blocking.
- revalidateAccountSession(ownerId) at 350 has no entry in the API table, no trusted proof/current generation parameter, transaction sequence, permitted state transition or publication guard. If pending revalidation uses is_blocked=1, activation refuses it and no valid handle exists; define how trusted revalidation can safely run without bypassing ordinary account restrictions.
- Case A at 345 treats ANY blocked namespace as a purge namespace. session:active is not account:<owner>. Define registry-specific dispatch using validated owner in reason, not string-stripping the registry namespace or treating reason as an arbitrary cleanup reason. Case B must enumerate every retained owner and handle malformed/orphan registry state explicitly.
- Clean close versus logout versus crash is not specified. The only registry insertion is active=0/0; the only documented deletion is logout completion. Consequently normal close/reopen also looks unclean and requires online session validation. State the intended offline reopen behavior and clean-close durable transition explicitly; do not call this preserved offline behavior without a mechanism.

Correction: add a compact lifecycle state/transition table for closed/opening/recovering/ready/account-revalidation-required/unavailable. Specify exact registry and account marker meaning, trusted revalidation API and failure/restart behavior. Preserve Guest sources and minimal owner-scoped quarantine; database unreadability cannot promise that Guest disk data is '100% accessible' (352), and B must still not see/resume A's journal. Revalidation must never remove a genuine unfinished purge marker merely because login succeeded.

Keep prior 5-step purge details (separate durable marker commit, purge, completion commit, errors at every step) explicitly in this revision or by an unambiguous normative reference. Current revision reduces those details to registry prose. Step 2 registry update plus owner marker must be atomic; Step 4 may clear registry only when it belongs to the cleaned owner/session.

### R5-2 / P1 — Pending activateSession can resurrect after synchronous logout (R4-1/R4-4)

At 423 activateSession awaits marker query, then sets active RAM state at 432–435 and awaits registry insert. If unbindSession executes while the query is pending, it invalidates RAM, but activation resumes and assigns the old owner again. There is no captured activation-generation check. It can then return a handle for a session already logged out. If registry insertion fails, active RAM fields already changed. If unbind occurs during insert, handle publication uses mutable current generation rather than a captured completed activation identity.

Correction: capture an activation request token/generation synchronously when activation is requested; unbind invalidates pending activation requests too. Check it on queue execution, after async marker/readiness work, before activation commit and before publication. Persist registry successfully before publishing active RAM/handle; handle failure and logout racing registry commit conservatively, retaining recovery evidence if necessary. Return a handle using the captured generation, never a later mutable generation. Queue serialization alone cannot serialize synchronous unbind with awaits.

Also remove `_enqueue`'s `action != open` exemption at 388/398. open normally passes a closure, which is not the open method tear-off; the lifecycle method must not authorize itself via function identity. Keep the queue executor neutral and enforce lifecycle readiness in operation-specific wrappers, or use an explicit lifecycle path. Avoid recursively awaiting the same queue. Replace uninitialized `T result` at 620 with a transaction return value (`final result = await db.transaction<T>(...)`) or an explicitly valid late binding; result! does not establish assignment.

Common 3-layer account guards at 617/624/632 are accepted at design level. Add explicit account readiness checks and a final in-transaction generation check after awaited action so stale work rolls back where possible; if logout races actual commit, suppress publication and serialize cleanup before account readiness returns. Do not claim all in-flight SQL can be cancelled.

### R5-3 / P1 — Stored committed receipt compares only four of ten fields (R4-2)

Common guards at 812–821 validate incoming payload/receipt against journal and handle. But storedReceipt at 826 is compared only for receiptId, tripId, remoteVersion and committedAt (829–832). Its deviceScope, targetOwner, draftId, sourceRevision, requestKey and contentDigest can be altered while remaining validly shaped; repeated ack still returns that stored receipt with wrong bindings. Checking incoming against journal does not certify stored against journal.

Correction: compare all ten stored receipt fields against incoming receipt before no-op; also bind selected journal to current handle. Use one named equality/binding helper so later sketches cannot regress to a partial comparison. Tests must tamper EACH stored binding independently, not only the incoming receipt.

Clarify digest lifecycle: BEFORE branch selection verify supplied canonical payload == incoming receipt == journal digest (three-way). For FIRST ack validate exact frozen source via checked mapper and extend to four-way equality before any mutation. For COMMITTED retry the source was already consumed; compare stored receipt digest as durable source identity and validate current snapshot, which may legitimately be newer. Do not require reading a deleted Guest source or equating a refreshed current snapshot digest with the imported digest. Current first-ack check at 864–866 correctly adds source validation; retain it.

### R5-4 / P2 — Remaining boundary/test contracts are incomplete (R4-3/R4-5)

The mapper connection to CAS/no-op and repeated ack is now accepted. Specify `_mapAccountSnapshotRow` rejects request-only payloads (B1-valid Guest data is not a complete account snapshot), and maps row type/date failures to typed local errors. The byte helper alone cannot validate SQL identity fields, projection consistency or complete account plan. Keep all Guest/account read paths through checked mappers.

fetchedAt at 651 still has no defined origin. The unversioned compare at 739 therefore still permits delayed older responses with a later arrival timestamp to replace content. Define request-capture ordering or local fetch generation/CAS. The same-digest max timestamp rule is accepted and does not need another rewrite. Placeholder text is display-only; top-ranked destination fallback must not be interpreted as an owner-selected destination or mutate canonical content.

Add precise allowed transitions for markJournalPendingAck and reconcileQuarantinedAttempt: preserve owner/source/key/digest, never regress committed to pending, and require trusted same-owner online reconciliation through B4. API names alone do not establish these rules. Preserve save/prepare/delete transaction and immutable revision contracts explicitly; current revision has detailed ack but only table descriptions for those operations.

Temp harness at 932 validates only `path.contains('b2_test_')`. A substring does not prove the resolved deletion target is the unique directory created by THIS test. Retain the exact createTemp-returned directory, resolve/canonicalize it, and verify exact owned target and intended temp-root containment immediately before recursive deletion. Use a runtime check, not only assert. Independent close/delete and primary/secondary error preservation are accepted; don't delete any app DB fallback path.

## Fifteen test groups: final additions needed

The matrix now includes receipt fractions, validly replaced source, corrupted bytes on CAS no-op, monotonic touches and marker-failure restart. These are useful specified behaviors, not executed tests. Keep the 15 groups and add explicit cases:

- G6/G7: both integer fields; missing/extra/wrong-type keys; non-Z/malformed timestamps; ten independent STORED receipt mutations on committed retry; three-way common digest and four-way first ack; repeat after current snapshot refresh.
- G9/G11: pending activation -> unbind during marker query and registry insert; registry insert failure; activation publication after cancellation; neutral open/close queue; no nested queue; unavailable/revalidation state enforcement for ALL reads/writes.
- G10/G12/G13: active registry but no account marker; blocked registry owner dispatch; orphan snapshot owners; clean close/offline reopen; Step 2/3/4 fault and reopen; revalidation proof stale/other-owner/rejected; revalidation cannot unlock unfinished purge; retained quarantine owner isolation.
- G8/G14: unversioned out-of-order capture versus arrival, all same/different digest/time cases; request-only account row with internally valid digest; invalid row type/date and schema/canonical drift; source missing/state restriction; no destructive rebuild.
- G3/G4/G5/G15: high-water consume/delete/save/reopen, private frozen mutations, save faults after each statement, exact retry preserves existing state, key reuse doesn't remove another journal, guarded reconciliation, setup failure cleanup and exact resolved deletion-target rejection.

Use real file SQLite FFI with deterministic fault/barrier hooks. Actual close/reopen tests must validate rows, not just exception names or proposed expected outputs.

## Verification and handover

Read full plan in bounded slices (re-read truncated output); compared previous R4 report and B1 encode/computeDigest/decode signatures. Verified actual HEAD, tracked clean diff, unchanged reviewed plan hash and absence of all 3 implementation files. No new runtime probe or Flutter test was run this round; historical SQL probes are not current R4 registry evidence.

`flutter analyze`, B2 targeted tests, real FFI/native persistence, registry crash/reopen, RPC/E2E: **NOT RUN**, implementation absent. No live database or deployment action.

Antigravity next packet: edit only B2_IMPLEMENTATION_PLAN.md with R5-1–R5-4 and exact tests above. Keep already accepted parser, checked mappers, DDL/pointer/tombstone/generation and timestamp-touch rules. Provide compact executable lifecycle/transaction contracts rather than growing duplicate pseudocode. No code B2, dependencies/native/backend edit or database apply; return for Codex review. Owner alone grants implementation authorization.

- **Changed:** Codex created this report only; Antigravity changes reviewed are design amendments.
- **Why:** A logout while activation waits for disk must also cancel that pending activation. A valid-looking stored receipt still needs all identity fields checked before returning it.
- **Testing:** Base/clean status/plan/source contracts inspected; runtime/FFI/native/server tests NOT RUN. No implementation PASS claimed.
- **Problems:** Activation cancellation, executable recovery/revalidation and complete stored-receipt identity remain blocking. Remaining ordering/harness/test details require focused closure.
- **Lesson Candidate:** Serialization does not prevent synchronous invalidation during await -> activation needs its own captured cancellation generation. Incoming validation does not validate stored data -> verify both sides of an idempotent return.
