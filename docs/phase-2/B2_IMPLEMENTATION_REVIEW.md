# B2 Implementation Review — Repair Required

2026-10-11. Codex reviewed the uncommitted implementation supplied by Antigravity against approved Direction A / B2_IMPLEMENTATION_PLAN.md R5.1 and C01–C10. Used superpowers:using-superpowers, requesting-code-review, systematic-debugging and verification-before-completion. Owner's explicit no-subagents constraint overrides skill dispatch; review was performed directly. No implementation repair, dependency change, database application, staging, commit or merge performed.

## Verdict and exact checkpoint

**NOT READY FOR PR/MERGE — one repair packet required.** The design conclusion remains valid; these findings concern missing implementation behavior and tests already required by the frozen contract. Do not rewrite the plan or reopen Direction A/1A–5A.

Base HEAD: `0cbebee70b1d2203349beaad8e040c19eaf21671`. Three B2 files are untracked, not part of a feature commit. Tracked diff was empty. Reviewed content hashes remained unchanged during verification:

| File | SHA-256 |
| --- | --- |
| lib/features/trips/models/local_trip_records.dart | 4637A8C230EE487F514504DFA0E1D293F6EEBD26DD8A0AF00C0F446C81C1B314 |
| lib/features/trips/services/local_trip_store.dart | A943A28CF255CF8D1BFA272E4B0758E59480735D8E408512A95AA11E6D051402 |
| test/local_trip_store_test.dart | 9512D4B7210DDC0B7EBB92528ADA730244DD2EACD0A499F70E13890E29CBE518 |

Plan hash: `A19BA2FB6D5CACEB63F3C4683E151136573378D50F58FFB7B521C05B7016A64B`.

Correct foundations observed: owner-scoped account SQL and guarded queue, captured activation generation, ten-field receipt equality, common/first-ack digest checks, pointer-first consume, monotonic tombstones, scoped partial reservation index, shared authoritative CAS, and separate marker/purge/completion transactions. B2 introduces no auth session registry or Decision Engine recalculation. These parts should be retained.

## Findings

### F1 [P2] Committed prepare retry incorrectly requires the consumed Guest source

Location: local_trip_store.dart:798–810. Contract: plan §6.3:747, C06/C08.

After successful commitImportAck deletes the source, prepareImportJournal with exactly the same owner/scope/source/key throws ImportAttemptConflictException at line 806. The existing committed journal and durable receipt are available, but the retry path reads the deleted source before it can return them. This breaks the planned exact-existing-binding result and obstructs recovery/coordinator lookup after a completed transfer. It does not prove server duplicates occur; B4/server idempotency remains separate.

Root cause: the source-dependent validation used for an active attempt was also applied to terminal committed state. Fix the state-specific retry path: validate and return the existing committed identity/receipt unchanged without demanding a consumed source; still reject conflicting key/bindings and never authorize resending. Active attempts retain checked source/digest validation. Add commit -> consume -> prepare exact retry and conflicting retry controls, including file reopen.

Evidence: review probe 1 FAIL, `ImportAttemptConflictException: Source revision missing during retry.` Ordinary repeated commitImportAck works; that is a different API and does not cover this failure.

### F2 [P2] Checked read validation omits projection/UTC invariants and typed durable receipt errors

Locations: local_trip_store.dart:365–420, 433–475, 979–981, 1190–1208. Contract: plan §5:560, §6.3:750; C05/C07.

The snapshot mapper checks payload bytes but returns row.title/destination/date projections without checking the shared projection policy against explicit metadata. Changing only row.title to Tampered while retaining canonical payload/digest returns a contradictory snapshot. Timestamp parsing uses DateTime.parse(...).toUtc(), accepting a non-UTC offset rather than rejecting stored data that violates the strict UTC contract. Guest mapper/header dates use the same normalization pattern.

Journal read paths call jsonDecode/casts outside a checked wrapper. A committed receipt_payload of `{` satisfies the SQL nonblank constraint, but getJournalEntry emits raw FormatException rather than CorruptDatabaseException. The same parsing pattern appears in prepare/reconcile/repeated ack. A coordinator expecting typed local corruption cannot reliably handle these reads.

Root cause: validation covers the canonical payload but not all surrounding persisted row/receipt fields. Complete checked row validation, use the shared deterministic projection policy, reject invalid/non-UTC persisted timestamp syntax, and centralize checked journal/receipt parsing so syntax/type/date/binding errors become typed corruption. Preserve data on rejection. Do not silently repair or normalize corrupt rows. Also preserve the planned header/high-water validation on save/read paths; saveDraftRevision:505 currently casts the counter directly without validating it against present revisions.

Evidence: probes 2 and 3 FAIL because getSnapshot returned a record instead of rejecting projection/non-UTC corruption; probe 4 FAIL because getJournalEntry threw FormatException. These are real file-backed SQLite FFI checks.

### F3 [P2] Test cleanup does not implement the approved ownership/error contract

Location: local_trip_store_test.dart:132–145, 149–183. Contract: plan §9.1:1091–1096 / §9.3:1155; C10.

dispose compares startsWith(tempRoot) and contains(b2_test_), not the exact canonical directory acquired by that test. It cannot distinguish a different sibling directory or a changed path resolving elsewhere under the temp root. The current ordinary test inputs were owned temp directories; no unsafe target was supplied or deleted during this review.

It also silently swallows store.close errors. A cleanup-only close failure can therefore pass if deletion succeeds, and the failure is absent from diagnostics. Setup between temp acquisition and the try block is not covered by registered cleanup.

Fix: capture immutable canonical owned target/root at acquisition, use normalized path-aware strict-child/non-root checks and exact target equality immediately before recursive deletion, and reject changed/unowned/root/escape paths at runtime. Attempt close/delete independently, report each secondary error, fail on cleanup-only failure and preserve the primary error/stack. Establish cleanup responsibility immediately after acquiring temp state. Add deterministic negative ownership and setup/body/close/delete failure tests without actually deleting an unowned directory.

### F4 [P2] Fifteen group labels do not demonstrate the required behavioral matrix

Locations: local_trip_store_test.dart:239, 559, 759, 801, 841, 1171, 1277, 1373, 1413, 1495. Contract: plan §9.3:1149–1155; C02–C10.

Concrete gaps observed:

- The test named each_binding_independently_mismatched_rejects_ack tests only requestKey and digest. The next test changes receiptId only. There are no independent mutations of all ten incoming and all ten stored receipt fields.
- late_returning_account_read_rejected_at_publication_layer unbinds BEFORE starting the read. It exercises an already-stale handle at entry, not invalidation during the transaction or after commit/before publication. The queued write/purge test likewise starts no deterministic in-flight barrier and accepts arbitrary write exceptions.
- rollback_after_each_step injects one fault after pointer-null and checks the Guest record without a file reopen, rather than faults after every ack step and complete durable pre-state restoration.
- cross_owner_reservation_blocks_all_active_states tests staged only. Repeated ack never advances the current snapshot first. DDL negative controls cover Guest revisions only, not every relevant table.
- Startup recovery inserts a marker into an otherwise empty database, so it does not prove interrupted deletion actually removes old snapshots/committed receipts and preserves/quarantines the right pending state. Completion-transaction failure, blocked/nonpending/malformed marker, failed recovery-open, activation races, same-instance close/reopen after marker failure and harness failure negatives are not covered by the observed tests.

Root cause: a test name/group was treated as equivalent to the promised scenarios. Convert these into the frozen plan's concrete controls: deterministic barriers for activation/account API boundaries, per-field mutations, per-statement/transaction fault injection and actual reopen with preexisting data. No sleep-based race tests or mock persistence. Report actual scenario coverage, not only group/count totals. Keep changes within the three-file allowlist; hooks may be added there as already allowed by the plan.

## Current evidence and limits

- `flutter analyze --no-pub`: **PASS**, exit 0, No issues found, 5.7 seconds.
- `flutter test --no-pub --reporter expanded`: **PASS**, exit 0, **235 tests**, including the B2 and B1 codec test files. Existing map tests emit HTTP 400 tile diagnostics; the suite still completes successfully. Those map diagnostics are outside this packet and are not classified as a B2 regression.
- Independent review probe suite: **FAIL**, exit 1, **0 passed / 4 failed**. These red controls assert approved contract behavior; they demonstrate the four concrete divergences described under F1/F2, not an infrastructure failure.
- Initial sandbox Flutter analyze/targeted invocations did not start successfully and were canceled. Direct SDK snapshot invocation also failed with a VM launch error. Successful verification used the normal Flutter command outside sandbox. The combined targeted attempt is **NOT COMPLETED**, not separately claimed PASS; full-suite evidence is the completed regression run.
- Tracked diff empty and reviewed three-file hashes unchanged. Direct whitespace scan found no trailing whitespace in those untracked files; a tracked-only git diff cannot certify untracked content.
- Native device checks, B6 offline/startup AC-016, server/RPC idempotency, remote DB and E2E: **NOT RUN**. No database applied.

Artifacts outside the repo implementation:

- Probe source: `C:\Users\ASUS\.codex\visualizations\2026\10\10\01a124c1-6365-7d91-8364-080890d7a14e\b2_review_probe_test.dart`
- Probe output: same directory, `b2_review_probe.log`
- Full suite output: same directory, `b2_full_suite.log`

The probes reuse the existing fixture/harness only with its ordinarily acquired, owned temporary directories. They do not test unsafe cleanup by supplying an unowned target. Real temp SQLite mutations in probes never touch the app database or Supabase.

## Next repair packet

Antigravity should fix F1–F3 and complete F4 controls in exactly the original three files. Preserve approved architecture/DDL/CAS/fencing invariants, do not rewrite B2_IMPLEMENTATION_PLAN.md, add dependencies, modify platform configuration, apply database or start B3. Promote the four red review cases into the B2 suite; demonstrate they fail before and pass after the repair. Supply C01–C10 coverage with test names and actual exits/results for analyze, targeted B2, codec and full regression. Then hand back for review before commit/PR approval.

## Owner explanation / Handover

- **Changed:** Codex created this report, four external review probes and their logs. Antigravity's three implementation files remain unchanged. No Owner protected content was read or modified.
- **Why:** When a Guest draft has been successfully transferred, its source is intentionally consumed. Retrying the same journal lookup must use the durable identity rather than demand that deleted source. Corruption checks must cover display fields and surrounding receipt metadata as well as payload bytes.
- **Testing:** Existing suite 235 PASS and analyzer PASS; four added contract probes FAIL. Passing the original suite is evidence for its existing scenarios, not the scenarios it omitted.
- **Problems:** F1–F4 remain OPEN. Implementation is not yet ready for PR/merge; fixes are proposed, not applied by Codex. B6/server acceptance stays outside B2 without being waived or marked PASS.
- **Lesson Candidate:** Problem: broad test labels conceal missing branches. Root cause: counting tests instead of verifying each invariant. Actionable rule: map each promised race/failure/binding to a concrete negative control and verify its durable outcome after reopen.
