# B2 compatibility with B3 input-only imports

2026-10-11. Planning record below is historical; Owner subsequently approved it.
Latest execution: IMPLEMENTED, local checks PASS, PR #22 OPEN; see handoff below.
Codex-only, superpowers OFF for this task. No database apply or dependency change.

## Verified checkpoint

PR #21 merged. Remote main is 23971a8dfa530ad6b794aa7e4cf15403be68f203.
Local checkout remains codex/phase-2-b3-import-contract at
fb9a90562565c303f6fa6e371e042acbe9ee24c6, tracked clean before this plan.
GitHub compare between these commits has no changed files. Source inspection is
therefore content-equivalent to merged main, although local branch/HEAD differ.
No checkout, fetch, reset, implementation or database mutation occurred.

Owner previously approved importing Guest drafts containing only input, without
running the Decision Engine. B3 preserves request plus metadata with plan:null.
B1 CanonicalTripPayloadV1 already accepts request-only or plan-only and rejects
request:null AND plan:null. B2 still rejects request-only in three places:

- local_trip_store.dart:584, _mapAccountSnapshotRow, corruption exception.
- local_trip_store.dart:1304, commitImportAck, argument exception before digest checks.
- local_trip_store.dart:1656, _upsertSnapshotTxn, argument exception before CAS.
- local_trip_store_test.dart:2721 currently treats a valid request-only payload as
  invalid. This expectation predates the approved B3 input-only contract.

Projection helpers already support absent plan and use request/metadata fallbacks.
SQLite stores canonical JSON and digest, with no SQL CHECK requiring a plan.
No changes to local records, B1 codec, schema version or database DDL are needed.

## Implementation allowlist: exactly two existing source files

1. lib/features/trips/services/local_trip_store.dart
2. test/local_trip_store_test.dart

This planning document is local review material and is excluded from the proposed
two-file code commit, following the earlier review-document convention.

## Minimal implementation

Remove only the three requirements that a valid canonical snapshot must have a
non-null plan. Preserve B1 validation, UTF-8 digest/canonical checks, receipt
bindings and all ten-field retry equality, ownership, fencing, quarantine,
transaction rollback, pointer-safe consume and snapshot CAS ordering.
Use the existing projection helpers for title/destination/calendar dates.
Do not invent an itinerary, mark input-only as complete, or recompute algorithms.
This store packet does not add UI; B4/B6 must distinguish payload.plan == null
when presenting imported input-only records.

## Behavioral tests on real SQLite FFI

1. Request-only replaceSnapshot -> getSnapshot/listSnapshots -> close/reopen:
   exact canonical text, digest, request/metadata retained; plan stays null.
2. Input-only draft -> prepare journal -> first valid commitImportAck:
   snapshot written, receipt committed and Guest source consumed atomically.
   Repeat identical ack after reopen: same receipt, no duplicate or source recreation.
3. Missing/lost acknowledgement leaves Guest source and pending journal intact.
   Wrong digest or receipt binding for input-only remains rejected, with no transfer.
4. Inject acknowledgement failure at existing transaction hooks for input-only:
   reopen verifies source/journal retained and no committed snapshot/receipt.
5. Snapshot version and integrity: equal-version changed input rejected; lower version
   rejected; good snapshot retained after rejection. Input-only no-op validates
   stored bytes; corrupted JSON/digest/projection still fails closed on reads/retries.
6. Owner isolation, stale session and purge remain valid for request-only snapshots;
   account snapshot removed on logout while unrelated Guest draft remains.
7. Metadata/preference/empty preference fallback title and destination remain exact;
   dates stay calendar strings; no synthesized plan. Plan-only/full cases regress cleanly.

Replace the old request-only rejection test with the valid request-only persistence
case and distinct conflict/corruption rejection cases. This updates the superseded
business expectation; it must not delete or weaken integrity assertions to force PASS.
Reuse existing owned temporary-directory harness and independent tearDown cleanup.

## Verification and delivery

After Owner plan approval, fetch verified main and create
codex/b2-input-only-compatibility from 23971a8; single workspace writer, preserve
all unrelated untracked Owner/review items, no stash/reset/clean.
First write behavioral tests and observe failures against the three current guards.
Implement minimal removal, run targeted SQLite FFI tests, Flutter analyze and full
Flutter tests, inspect diff/allowlist, then selective commit and PR for Owner review.
No Supabase execution, primary apply, native configuration/dependencies or B4 UI.

Planning checks: actual HEAD/status and remote main/compare verified. Tests and
implementation NOT RUN in this inspect/plan task. Three-round/25-call/5-file budget
applies to the following implementation task.

## Changed / Why / Testing / Problems / Lesson Candidate

Changed: this plan only. Why: server accepts valid input-only payload but local
store applies an older completed-itinerary requirement. Testing: source and
content parity inspected; no runtime test PASS claimed for compatibility yet.
Problems: before implementation, Owner must approve the concrete packet under
AGENTS.md section 2 Law 5 steps 3–5; primary rollout remains separate.
Lesson Candidate: contract expansion at the server needs matching local read,
write and acknowledgement coverage, not just a permissive JSON codec.

## Implementation handoff — 2026-10-11

Owner explicitly approved this concrete packet. Codex-only, superpowers OFF.
Base 23971a8dfa530ad6b794aa7e4cf15403be68f203; branch
codex/b2-input-only-compatibility; reviewed HEAD
45d94603d0d3aa2e308f275a9da7e0571d9c1e65.
PR: https://github.com/plhhoang2005/travel-go-mobile/pull/22.

Changed: exactly the two approved files in the commit/PR. Production diff removes
14 lines implementing three plan-required checks. Tests add 13 FFI behavior cases
and replace the superseded request-only rejection expectation with a same-version
content conflict test that still asserts good snapshot preservation.
This local planning/handoff file is untracked and excluded from the PR.

Why: input-only is a valid B1/B3 payload; the local store now accepts it at read,
write and acknowledgement boundaries without creating a plan or recalculating
Decision Engine results. No schema/model/dependency or database changes.

Testing: before implementation, all 11 initial new tests failed against the old
plan guards (observed red). After implementation, full local-store suite at that
stage passed 90 tests; then two further cases added plan-only regression and
unversioned fetchedAt ordering. Final targeted compatibility suite 13 PASS;
full Flutter suite 285 PASS (22s); final analyzer no issues (3.0s);
format check and staged diff check PASS. Analyzer warnings in newly added tests
were fixed in two rounds; no expectations weakened to obtain PASS.
GitHub changed-path set verified exactly two files; tracked checkout clean.
CI status is authoritative at the PR exact HEAD; do not infer it from local PASS.

Problems: UI presentation/import integration, HTTP E2E and primary B3 deployment
remain separate. No merge, primary apply, Docker, subagent, reset/clean or Owner
asset change. B4/B6 must display input-only as incomplete input rather than invent
an itinerary; stored plan remains null.

Lesson Candidate: persisted contract changes require file reopen and repeated
acknowledgement tests alongside rejected receipt, version and corruption cases.

### Final CI evidence
- GitHub Flutter CI `Analyze and test`: SUCCESS on exact PR HEAD `45d94603d0d3aa2e308f275a9da7e0571d9c1e65`.
- Run: https://github.com/plhhoang2005/travel-go-mobile/actions/runs/38150685620/job/114503331465
- PR #22: OPEN, non-draft, MERGEABLE; Owner review/merge remains pending.
- This local report is excluded from the two-file implementation commit and PR. No database apply performed in this packet.