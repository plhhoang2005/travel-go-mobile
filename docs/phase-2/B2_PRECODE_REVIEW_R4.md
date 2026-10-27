# B2 Pre-Code Review R4 — FOCUSED CORRECTIONS STILL REQUIRED

2026-10-10. Codex reviewed B2_IMPLEMENTATION_PLAN.md Revision R3, 801 lines, SHA-256 `67A7434224481955B93F0919FB0AC4BE5EFC6ACDA5D1F36570C79FECBBF57DC1`, against B2_PRECODE_REVIEW_R3.md findings R3-1–R3-7 and B1 codec contracts.

## Conclusion and checkpoint

**Not ready for Owner implementation approval yet.** Important R3 corrections are accepted at design level. The marker-write-failure restart hole remains unchanged, receipt deserialization silently truncates fractional identity numbers, and explicit snapshot reads bypass the new validator.

Actual checkout main @`0cbebee70b1d2203349beaad8e040c19eaf21671`; tracked clean. All three B2 files remain absent. This review creates only this report and an isolated reviewer probe. No B2 implementation, dependency/native change, app DB/Supabase apply, backend change, checkout change, protected Owner content access, subagents or superpowers. Approved 1A–5A remain intact.

## Previous findings: closure at design level

| Finding | R3 disposition |
| --- | --- |
| R3-1 | **Closed at design level:** ack clears matching pointer before deleting exact revision, checks deleted row count, clears projections and retains counter. deleteDraft retains tombstone. Newer pointer stays intact. SQL probe verifies the core sequence. |
| R3-2 | **Mostly addressed:** receipt has exactly 10 whitelisted fields, removes raw payload, validates direct constructor, compares all 10 on committed retry, validates supplied payload before no-op, returns current snapshot. Strict parser and common journal/context validation remain open below. |
| R3-3 | **ABA fix accepted:** bind/unbind advance a store-owned generation and return a handle; queue recovery retained. Three-layer fencing is stated for prepare/ack, but complete read/lifecycle readiness contracts remain incomplete. |
| R3-4 | **Open, blocking:** startup/bind still checks only markers; failed marker commit can leave no marker after restart. |
| R3-5 | **DDL corrections accepted:** all three hex checks fixed; scope in journal PK, source query and receipt; composite FK and active reservation retained. Revision immutability still needs explicit private mutation/read contracts. |
| R3-6 | **Helper accepted in principle:** raw-byte hash, explicit v1 envelope, B1 decode and exact re-encode implemented in sketch. Concrete existing-snapshot/no-op branches bypass it. |
| R3-7 | **Versioned CAS accepted:** shared txn helper, lower/equal/higher and known/null rules explicit. Unversioned ordering and test expectation remain inconsistent. |

These are plan dispositions, not implementation or FFI PASS.

## Required corrections

### R4-1 / P1 — Durable Startup Policy still does not cover absence of a failed marker

Lines 685–686 only set unavailable in the running process. Lines 708–715 subsequently enumerate stored markers and deny bind only if a marker/read error exists. If marker write failed before committing, old snapshots remain and there is no marker; next process can bind A and read them. Renaming marker checks 'Conservative Startup Revalidation' does not add revalidation.

Isolated SQL state probe confirms: after representing a failed marker transaction, reconstructed DB has zero markers, marker-only bind check does not block A, and A's old snapshot still exists. This is a SQL-state demonstration, not a production crash/FFI test.

Specify a real policy independent of marker presence. Options include startup invalidation/purge of account copies before enabling cache (preserving untransferred Guest and quarantined pending), or refusing retained account snapshots until trusted server revalidation has completed for the current session. If retained offline snapshots must stay usable across ordinary restart, document how the design safely distinguishes that case from unrecorded cleanup failure; a marker-only check cannot do so. Do not silently sacrifice approved offline behavior to close the hole. No encrypted driver or production restore rehearsal is requested.

Define readiness/unavailable state checked by all account entry points, and serialized open/recovery/purge/close. Step 4 transaction failure must leave access blocked; bind must not race cleanup. The synchronous bindSession code at 336–352 cannot itself perform the asynchronous SQLite query promised at 715: resolve by an asynchronous guarded activation API or precomputed verified readiness under the queue. Preserve synchronous invalidation before waiting on the queue.

### R4-2 / P1 — Receipt fromMap changes invalid bindings instead of rejecting them

Lines 239/244 use `(value as num).toInt()`. A sourceRevision or remoteVersion of 1.9 becomes 1, then passes constructor >=1 validation. Such a receipt may match an integer journal after silent modification. Dart explicitly defines toInt as truncation: [num.toInt documentation](https://api.dart.dev/dart-core/num/toInt.html).

Require integer JSON values (the same strict principle as B1), reject fractional numbers instead of rounding/truncating; require exactly the permitted local receipt keys and explicit UTC/offset timestamp syntax before normalization. Map malformed shape/types/time to typed errors without storing raw data. Direct constructor validation and ten-field serialization/comparison are otherwise accepted.

Before BOTH ack branches, compare receipt owner/scope/source/key/digest against the selected journal AND current handle, not only stored receipt versus incoming receipt. The committed branch currently trusts that stored receipt belongs to that row. Define journal query arguments explicitly as current handle owner plus receipt source identity. A validly-shaped but wrongly bound stored receipt must not be accepted merely because the incoming receipt matches it.

For first ack, source byte hash matching its own stored digest at 521 is insufficient: validate its full canonical content and require source digest == journal digest == receipt digest == supplied payload digest. A replaced source with a different internally valid digest must not be consumed as the original frozen import. Specify acceptable source states and private no-update mutation API.

### R4-3 / P1 — Concrete no-op snapshot branches bypass all-read validation

The global statement at 394 says all reads use _validateAndDecodePayload, but _upsertSnapshotTxn at 565–597 reads digest/version and returns existing payloadJson without invoking it. If payload_json was tampered while digest column stayed unchanged, incoming same-version/same-digest takes the no-op branch and returns corrupt bytes. The both-null branch at 610–611 has the same issue. Repeated committed ack at 515–517 similarly says 'currentSnapshot' without an explicit validated record mapper.

Route every existing payload row through one checked record mapper before comparing/returning it. Include row schema_version == explicit envelope schema_version == 1. Map JSON syntax/B1 validation failures into the local typed corruption result (current helper lets FormatException/B1 exceptions escape). Keep original data intact and reject invalid replacements; never return a fabricated good record or silently normalize stored bytes.

The helper body itself is a substantial correction: exact SHA-256, explicit v1, decode and canonical byte comparison are accepted. Connect it concretely to Guest reads, source reads, snapshot reads/lists, repeat ack, and same-content CAS returns. No B1 source modification is required.

### R4-4 / P2 — Public read/state/lifecycle contract is still missing

R3 adds save/delete/prepare/ack and an internal writer, but omits concrete getLatestDraft/getDraftRevision/listGuestDrafts, get/list snapshots, owner journal read, mark pending and same-owner reconciliation primitives, replaceSnapshot wrapper, open/close signatures and readiness/error behavior. Tests reference those behaviors. 'All 3 layers' on imports does not specify account reads or snapshot replacement.

Add a compact API table and one common execution template: capture handle -> queue/readiness/owner guard -> txn executor guard -> awaited operation checks -> post-transaction/pre-publication guard. If logout races commit, committed disk mutation may finish but must not publish; serialized cleanup removes it before reactivation. No nested enqueue awaited from its own action and no outer DB calls within transaction. State transitions must not let returning a quarantined record silently authorize sending; B4 owns online orchestration, B2 provides guarded primitives only.

Generation ABA correction is accepted; no further change to its basic monotonic design or dependency is needed. Scope is now local identity; keep B3 server scope/key contract explicit before multi-scope wire integration.

### R4-5 / P2 — Unversioned freshness and acceptance tests disagree

Line 608 still compares fetchedAt without defining its origin. A delayed older response stamped at arrival can overwrite newer legacy content. Define capture-time ordering or a local fetch generation/CAS supplied through the later coordinator; do not call arrival order authoritative content version.

Line 610 returns unchanged content when time is older/equal and digest matches, but G8 at 758 promises older/equal always throws. Choose one explicit policy (same-content no-op is reasonable) and make tests match all timestamp/digest combinations. Prevent versioned same-content touch from decreasing fetchedAt if it represents last successful capture.

Projection extraction is now deterministic. Clarify that generated 'Chuyến đi...' text and 'Điểm đến' are display placeholders, not asserted destination selection. Do not mutate canonical payload or claim an unselected top-ranked destination was selected. An explicit metadata/known-plan projection policy is sufficient; no new UI work or Owner interview is needed here.

## Test matrix and harness

The 15-group structure and real SQLite FFI/file intent are accepted. Pointer-safe consumption, tombstone, scope, all-binding tests, late read, ABA and step-by-step ack rollback were added. Complete these specific remaining cases within the existing groups:

- G6/G7: strict fractional receipt rejection; wrong/extra keys/time; corrupted stored receipt binding; replaced source with internally valid hash but different journal digest; each receipt mismatch on first AND committed ack; request-only ack; current snapshot refreshed since import.
- G8/G14: tamper existing payload_json but leave digest unchanged, then same-version/same-digest replacement and repeated ack; valid-hash noncanonical JSON; row/envelope schema mismatch; bare legacy/missing schema; each unversioned time/content combination and out-of-order responses.
- G9/G11: all read/list and snapshot paths use guards; bind while open/recovery/cleanup; already-running SQL and late publication with deterministic barriers; queue failure and close without deadlock.
- G10/G12/G13: Step 2 failure followed by actual close/reopen with NO marker; Step 4 completion failure; blocked/nonpending and unreadable marker; prove old account data cannot be exposed while Guest sources remain. Current G13 checks only RAM disablement, so it does not close R4-1.
- G1/G3/G4: consume -> delete -> save -> reopen preserves counter; private frozen revision API; save faults after both revision and header writes; checks on all digest-bearing tables, not just one.

Temp harness now creates its own unique directory and independently attempts close/delete, with secondary error reporting. Accept that structure. Add explicit resolved-path ownership verification before recursive delete (no app-path fallback), and define primary error capture via test body try/finally or the test framework rather than assuming tearDown can rethrow an unavailable primary error. Attempt cleanup even for setup/test failure; report cleanup-only failure. Keep hooks and harness within the 3-file implementation allowlist.

## Evidence and scope limits

Probe: `C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/b2_r3_sql_probe.py`. Executes exact R3 DDL with synthetic data in SQLite 3.50.4 :memory:, then serializes/reconstructs a separate memory connection for marker-absence state. No application DB/file or Supabase touched.

Final probe exit 0: FK on; invalid hex suffix rejected; pointer-first consumption leaves null pointer/projections and high-water 1; delete tombstone then save allocates 2; two scopes coexist; cross-owner active reservation and reused owner request key rejected. Marker-absence reconstruction retains old snapshot and marker-only bind does not block. This reconstruction is NOT real crash durability or FFI evidence.

B2 analyze/Flutter tests/real FFI/native/RPC/E2E **NOT RUN** because B2 implementation is absent. Historical B1 test results and expected SOP output do not establish B2 PASS. Three proposed files still absent; tracked workspace clean.

## Next correction packet

Antigravity: amend only B2_IMPLEMENTATION_PLAN.md, focused on R4-1–R4-5 and listed tests/API contracts. Preserve accepted pointer/tombstone/hex/scope/generation corrections; do not rebuild the design or reopen 1A–5A. Resolve startup policy explicitly, avoid silent offline behavior changes, and return for Codex review. No code B2, new dependency, native/backend edit or database apply. Owner alone authorizes implementation.

## Handover / Owner explanation

- **Changed:** Codex created this review and isolated SQL probe only; reviewed Antigravity's amended plan.
- **Why:** If A logs out and marker write fails, restart loses the RAM lock while A's saved snapshots remain. Checking for a marker cannot distinguish this from successful cleanup. Separately, an unchanged digest column cannot certify bytes that the code never hashes before returning.
- **Testing:** Actual base and clean tracked state verified; exact R3 DDL sequence/constraints probed. SQL probe exit 0; B2 implementation tests and real restart/native/server evidence NOT RUN.
- **Problems:** R3 closes major SQL/counter/ABA design errors, but startup without marker and validator bypasses remain blocking; receipt parser and API/test contracts need focused completion.
- **Lesson Candidate:** A failed attempt to record cleanup cannot prove cleanup happened -> access recovery needs a policy independent of marker existence. A validated helper protects data only on paths that actually invoke it -> check every no-op and existing-record return.
