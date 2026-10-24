# B2 Pre-Code Review — NEEDS PLAN COMPLETION

2026-10-10. Codex review only. Owner 1A–5A unchanged. No B2 code, local application database initialization, Supabase apply, backend change, checkout change, subagents or superpowers.

## 1. Evidence and verdict

Actual workspace is main @0cbebee70b1d2203349beaad8e040c19eaf21671, the merge commit of PR #19. Tracked files are clean; existing Owner entries and review documents remain untracked. The three proposed B2 implementation files do not exist.

Read BATCH_B_DESIGN_REVIEW.md sections 3/5/6/7, REPAIR_PLAN R06, Phase 1 local schema/ownership and AC-005/006/038/039/040/045/053/055, merged B1 codec APIs and existing SavedTripsProvider auth/epoch guards. Dependencies already pinned by B1: sqflite 2.4.4+1, sqflite_common_ffi 2.4.3, crypto 3.0.7, uuid 4.6.0, path 1.9.1.

The proposed five-table division and three-file implementation allowlist fit Batch B. However, the submission supplies table names and review objectives, not exact DDL, public record/API definitions, state transitions or ordered transaction steps. No separate detailed B2 plan was found under docs/phase-2. The findings below are missing design specifications, not detected implementation bugs. Do not label unprovided DDL/transactions as reviewed PASS.

Antigravity should return an amended plan containing sections 2–7 below. Codex reviews that plan; Owner separately approves implementation. This report is not code authorization and does not reopen the five product decisions.

## 2. Schema requirements to make concrete

| Table | Minimum identity/content | Required constraints and disposition |
| --- | --- | --- |
| guest_draft_revisions | device_scope + draft_id + revision; exact canonical payload_json, payload schema, digest, UTC updated_at and explicit lifecycle state if retained | Composite PK, required nonblank identity, positive integer revision. Content/schema/digest/time of a frozen revision immutable; edits append. Show how API/DDL enforces immutability. Never REPLACE an existing revision. Pending source cannot be deleted or garbage-collected. |
| guest_drafts | device_scope + draft_id; current_revision; durable highest allocated revision or equivalent monotonic allocation mechanism | Composite PK; current pointer references an existing revision of the SAME scope/draft. Define null pointer/empty header behavior after acknowledged transfer. Revision numbers must not be reused after source deletion. Pointer and revision insertion commit together. |
| account_trip_snapshots | owner_id + trip_id; remote_version nullable, payload schema, fetched_at, canonical payload_json/digest | Composite PK. Full readable plan and owner/trip context required. Version null explicitly means unversioned legacy, not version 1. Only complete validated replacement; no partial independent projections. Reject stale replacement or define an explicit compare-and-set/write-generation policy. |
| local_import_journal | target_owner + draft_id + source_revision; device scope/source reference, stable request_key, digest, explicit state, optional receipt metadata | Business identity unique independently of request_key; request_key also owner-unique. Frozen source, digest and request key cannot be rebound. Pending/quarantine rows contain only permitted recovery metadata, no trip JSON/token/profile/private account payload. Committed rows have complete receipt bindings. Explain source-reference handling after source removal. |
| local_cleanup_state | typed account namespace/owner identity; blocked/purge_pending or one explicit equivalent state | Unique namespace; valid enumerated values. No secrets/payload. Durable blocked state survives a failed deletion transaction; generic API callers cannot clear it. Unlock only after the specified recovery/revalidation path. |

Show exact SQL types, NOT NULL/CHECK constraints, composite foreign keys, UNIQUE rules, indexes, lifecycle states and conflict behavior. CHECK alone is insufficient if required values can be null; avoid implicit SQLite type coercion for identity/revision/version validation. Parameterize all values. Do not require optional JSON extensions, STRICT tables or newer UPSERT syntax without native compatibility evidence.

Important schema traps to resolve in the plan:

1. A pointer foreign key must include device_scope and draft_id, not only revision. Explain first-draft insertion order; if cyclic references are chosen, make the deferral/order explicit and prove final integrity.
2. An unconditional journal FK to a source revision can prevent successful transfer from removing that Guest source. Choose an explicit nullable auxiliary reference or controlled equivalent, keeping owner/draft/sourceRevision identity and receipt bindings intact after acknowledgement. Do not cascade away pending recovery metadata.
3. A successful transfer of the current revision must remove its writable Guest pointer; when a newer current revision exists, leave that newer pointer/content alone. An old untransferred revision must not silently become current again. Preserve monotonic numbering even when the last visible source is consumed.
4. Define cross-owner attempts for one pending source. Safe recommendation: atomically reserve each device/draft/revision to its outstanding attempt, so B cannot bypass A's quarantined attempt by creating another key for that SAME source. A new explicitly saved revision is a different source and still needs selection/confirmation. Return a generic unavailable/pending outcome, not A's journal contents. This technical rule must appear in the amended plan and tests; it is not an implemented guarantee.

Enable foreign-key enforcement for every connection in onConfigure, before transactional schema work, and assert PRAGMA foreign_keys=1. Composite and deferred-FK behavior must match the actual DDL. [SQLite foreign-key documentation](https://www.sqlite.org/foreignkeys.html).

## 3. Atomic operations and immutable revisions — P1 plan gap

Specify each public operation's inputs, returned typed result, guards, SQL sequence, failure result and commit boundary. Minimum behavior:

- Save/edit Guest: validate/freeze via B1; within one transaction resolve current pointer and monotonic revision, insert new immutable row and update pointer. Concurrent saves either serialize to distinct revisions or return an explicit optimistic-conflict result. Inject failure after insertion and before pointer update: neither half may remain committed.
- Prepare import: current verified account + explicitly selected source reference; verify the persisted source bytes/digest, then persist stable journal identity before any future network send. Retry returns the same frozen attempt; a different digest/key binding conflicts. Edit creates a new revision; pending source remains byte-identical.
- Commit acknowledged import: B4 supplies a validated receipt candidate; store independently checks identity/digest/source and current session. In ONE local transaction record receipt, replace complete account snapshot, detach/consume exactly the source revision and adjust only a pointer still pointing at that source. Repeat same receipt is locally idempotent; mismatches reject. Local transaction failure leaves Guest source and pending attempt intact. B2 provides a local primitive, not server acknowledgement authenticity or actual RPC integration.
- Snapshot replacement: validate complete content before mutation and guard owner/epoch and freshness. Failed replacement preserves the last valid snapshot. fetched_at is context, not content hash or proof of remote version. No offline saved-trip editor.
- No network await inside a database transaction. Use the transaction executor throughout; do not call the outer Database object from its callback. Let failures propagate so the entire intended unit rolls back. Migration callbacks already run in a transaction. [Pinned sqflite transaction documentation](https://pub.dev/packages/sqflite/versions/2.4.4%2B1).

Make receipt/local-commit boundaries ready for B3/B4 without inventing finalized RPC field names that B3 has not frozen. The required semantic bindings are owner, draft, source revision, request key, digest, trip, committed version/time and receipt identity. No ordinary TripsService insert fallback.

## 4. Owner partition, quarantine and fail-closed recovery — P1 plan gap

An arbitrary ownerId argument is not authentication. Define a store-owned active-session handle or guarded session-context supplier populated only by the future trusted auth coordinator. Require captured owner/epoch and real authenticated/non-demo mode for all account reads/writes/journal operations. Recheck when queued work actually runs and before returning a read/result. Never expose an unrestricted all-owner snapshot/journal API. Epoch is process-local fencing, not persisted authentication authority.

Serialize database mutations and purge. Specify queued-write behavior, already-running transaction behavior, invalidation timing and result publication. Logout/switch synchronously invalidates the old handle and closes access immediately; stale queued writes/late callbacks cannot recreate data after purge. If auth changes while a write is finishing, its result cannot be published and the serialized cleanup path must remove any account copy before unlocking. Existing Provider RAM guards do not themselves protect disk; B2 tests the primitive, B6 wires it into real lifecycle.

Required durable cleanup order:

1. Block the namespace in memory immediately; invalidate its epoch/handles.
2. Persist blocked/purge_pending in a separately committed operation BEFORE the deletion transaction. Putting marker creation inside the transaction that may roll back would erase evidence of failed cleanup.
3. In the serialized purge transaction remove account snapshots, transferred account copies and acknowledged local receipt cache; retain untransferred Guest sources. Redact pending attempts to approved recovery-only quarantine metadata, retaining their frozen Guest source. Do not call a remote trip delete.
4. Complete/delete the marker only after successful cleanup, then allow the specified future verified-session recovery. A failed purge leaves the durable marker blocked. Startup checks/retries it before access, including login again as A.
5. Marker-write/open failure is NOT successful durable cleanup. Disable account-cache access and report a typed failure. Define conservative startup/revalidation behavior for unreadable/unknown cleanup state; do not claim disk persistence can guarantee a marker when its write failed. Do not solve this by deleting all Guest data or silently unlocking stale snapshots.

State diagram must distinguish pending, quarantined and acknowledged/committed; exact names are up to the amended plan. Quarantine is NOT acknowledged receipt cache. B cannot list/read/resume A's attempt; only newly verified A can reconcile through future online B4. Retained Guest drafts remain device-shared as Owner selected, not a promised private account store. Do not keep transferred payload in the Guest namespace just to simplify recovery.

## 5. B1 compatibility and open/migration policy — P2 plan gap

- Reuse CanonicalTripPayloadV1, TripPayloadCodec.encode/decode/computeDigest and the explicit legacy adapter; no second serializer, normalizer or ranking algorithm. Local DB version, payload version, Guest revision and remote version remain distinct.
- Write canonical bytes once, retain those exact bytes for pending retries. On read, verify payload schema/closed shape, context identity and digest over the stored UTF-8 string; do not silently rewrite stored content. For new v1 rows enforce canonical representation consistency as well as digest. Legacy adaptation is explicit and does not make corrupt/future-version content valid.
- Same-key source JSON/digest/revision cannot be silently edited by a journal UPDATE. Snapshot projections, if any, derive only from the same validated content in the same transaction.
- Inject DatabaseFactory and path so tests use databaseFactoryFfi directly without global factory mutation. Runtime path is app-private getDatabasesPath; no storage permissions or token storage. Existing dependencies suffice; do not modify pubspec/platform files under the proposed three-file scope.
- Publish database filename/version=1, connection ownership, open/close behavior, first-create callback and supported upgrade/downgrade rules. Unknown future version, malformed row or corrupt DB returns a typed unavailable/corrupt/unsupported result and preserves the file/Guest rows. Never deleteDatabase/recreate as generic error recovery. Startup reopen and failed migration must have explicit outcomes.
- Snapshot fetched_at/updated_at/receipt times use checked UTC instants; travel dates stay in B1 metadata. Do not fill missing remote versions or dates. Inject a clock/identity source where it makes tests deterministic.

## 6. Required real-SQLite behavioral tests

Use a fresh test-owned file and actual B2 production store with databaseFactoryFfi. Synthetic trip inputs and controlled auth/fault callbacks are valid test inputs; in-memory map repositories or mocked SQL results are not persistence evidence. Fault injection must occur around actual SQL steps with deterministic barriers, not sleeps. Inspect durable rows after close/reopen.

| Case | Expected evidence |
| --- | --- |
| Create/open/reopen | Exactly five tables and intended constraints/indexes; FK enabled on reopen; valid B1 payload/hash restored. |
| Draft content | Complete planner input/result/Pareto false/fallback/metadata survive close/reopen without DE calls; input-only Guest draft supported. |
| Revision integrity | Edits append; old content unchanged; pointer scoped correctly; simultaneous saves no revision collision; consumed revision number never reused. |
| Pointer rollback | Failure between insert and pointer update restores the entire previous committed state after reopen. |
| Pending source | Journal uses exact existing source bytes/key/digest; edit to next revision does not mutate/delete that source. Delete/GC of pinned source rejects. |
| Local ack atomicity | Failure after receipt or snapshot step leaves source/pointer/pending state intact; success consumes only selected source; newer revision stays Guest; repeated matching receipt is no-op/equivalent. |
| Receipt rejection | Wrong owner/draft/revision/key/digest/trip/version or stale session rejects before changing any table. |
| Snapshot safety | Valid replacement atomic; malformed/partial/hash mismatch or stale write leaves previous valid snapshot; remote null version remains null. |
| Account isolation | A/B snapshots with overlapping trip IDs remain separate; Guest/demo cannot access account rows; old handle cannot read/write after switch or return late data. |
| Quarantine 4A | Purge removes snapshots and committed receipt cache but preserves minimal pending metadata/source; B cannot enumerate/resume A; same-source new-owner attempt follows the frozen policy. |
| Purge serialization | Deterministic queued/late write versus logout cannot resurrect A after completed purge; Guest sources remain. |
| Marker rollback/restart | Force deletion failure: prior committed marker survives; reopen blocks A and B access to A until successful recovery; successful retry clears/completes marker. |
| Marker/open error | No false purge success or automatic unlock; conservative unavailable state; original Guest data not destroyed. |
| Bad row/future schema | Typed corrupt/unsupported result, no fake defaults, no destructive downgrade or generic DB recreation; good unrelated Guest content preserved where database remains readable. |
| Cleanup | Always attempt close/delete independently; retain primary stack and report secondary cleanup failures; cleanup-only error fails. Delete only resolved test-owned temp directory. |

After future Owner code approval: targeted local_trip_store_test, flutter analyze and full flutter test with actual exits/counts; final status/allowlist/native generated-file disposition. Windows FFI PASS is not Android/iOS runtime PASS. Plan a separate authorized device smoke or record NOT RUN; do not silently claim host close/reopen equals AC-005 Android app restart. Store-level cases contribute to acceptance but do not complete UI/server E2E AC-006/039/040/053/055.

## 7. Exact next submission and scope

Return one concrete amended B2 plan with: five-table DDL/constraints; record/API definitions; state/ownership diagrams; transaction and purge/recovery sequences; B1 read/write/digest rules; conflict/error policy; test-to-invariant matrix and command plan. Preserve the proposed three implementation files:

1. lib/features/trips/models/local_trip_records.dart — immutable typed local records/context/results/errors.
2. lib/features/trips/services/local_trip_store.dart — connection/schema/guarded atomic local operations.
3. test/local_trip_store_test.dart — actual SQLite FFI behavioral evidence.

No UI/main/Provider wiring, Supabase/RPC, backend, extra dependencies/native settings or protected Owner files. SQL inside this plan is a design proposal, not executed SQL. Owner approval is still required before implementation. Keep implementation tasks within 25 calls/three repair loops; checkpoint when exhausted rather than broadening scope.

## Handover

- Changed: Codex adds only this review document; application/source/database unchanged.
- Why: five table names do not establish crash recovery. For example, X revision 1 pending under A, user saves revision 2, then response is lost and A logs out: revision 1 must remain frozen, revision 2 must remain Guest, B must not replay A, and failed purge must leave account access blocked.
- Testing: checkpoint/source/document inspection performed. B2 implementation absent; B2 SQLite tests, flutter analyze/test for B2, native smoke and server integration NOT RUN. B1 PASS is historical evidence at its reviewed commit, not B2 PASS.
- Problems: missing concrete DDL/API/order/error policies prevent final pre-code acceptance. Schema/allowlist direction is appropriate; no product decision needs to be re-asked. This is NEEDS PLAN COMPLETION, not approved implementation.
- Lesson Candidate: cleanup marker rolled back with deletion → restart loses proof of pending cleanup → commit the blocking marker before the deletions. Editing current draft overwrites retry source → response-loss retry sends another payload → append immutable revisions and pin the selected source until validated acknowledgement.
