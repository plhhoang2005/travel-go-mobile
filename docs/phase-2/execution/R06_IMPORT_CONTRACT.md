# B3 R2 — frozen implementation contract and verification

2026-10-11. Owner approved B3 R2 design/plan and source implementation.
Codex-only; superpowers OFF for implementation/fixes/verification.
Branch: codex/phase-2-b3-import-contract.
Base: 8213e4aa0b0307fbf63ceb73816cf95f193511fa (main after PR #20).

Latest status: STAGING APPLIED, including Owner-approved cascade trigger repair.
Dashboard positive and negative SQL suites PASS. Owner's native runner screenshot
reports suites/races and owned-fixture cleanup PASS; Codex independently checked
post-run fixture absence and ACL/trigger state. Acceptance gaps remain below.
Primary NOT APPLIED. The execution history below predates review-draft preparation;
GitHub review metadata identifies the eventual commit/PR. No merge, B4 UI or backend change.
The earlier R2 planning files retain their historical draft status; this record
captures the later Owner approval without editing outside the five-file packet.

Current follow-up: extended SQL positive/negative suites PASS on staging;
B3-E1/B3-E2 closed below. Fault-cleanup controls written and syntax checked,
native execution of those new controls pending Owner-local credential entry.
Fresh Flutter analyze/test PASS. A review draft may be prepared with that limit;
this is not a merge-ready approval or authorization to deploy primary.

## Changed / Why

Exactly five new implementation files:

1. supabase/migrations/202610100001_guest_import.sql: additive raw-text column,
   private receipt ledger, strict validator, two authenticated RPCs and trip guards.
2. supabase/tests/guest_import.sql: rolled-back real SQL fixtures, literal B1
   vectors, retry/binding/ownership/projection/immutability/cascade/rollback tests.
3. supabase/tests/guest_import_negative_controls.sql: strict reject paths,
   actual role denial, limits, Unicode and assertion detector controls.
4. supabase/tests/run-guest-import-concurrency.ps1: native independent sessions,
   observed database lock barriers, same-source and conflicting retries,
   lost-response retry, both delete/read lock orders, owned fixture cleanup.
5. This contract and evidence record.

A first import writes trip plus receipt in one transaction. Retry reuses the
stored receipt and submitted text. Receipt identity remains after trip deletion,
so retry returns deleted instead of recreating a trip. Trusted owner identity is
auth.uid(), never an argument supplied by the caller. Receipt ledger contains
metadata only. Imported trip content/projections/version are immutable in v1;
ordinary legacy trip CRUD remains available.

## Public contract

import_guest_draft_v1(p_device_scope text, p_draft_id text,
p_source_revision bigint, p_request_key text, p_payload_text text,
p_content_digest text) -> jsonb.

get_import_trip_snapshot_v1(p_trip_id uuid) -> jsonb.

Both require authenticated role and non-null subject. Only these public entry
points grant authenticated EXECUTE. Private helper/table access is denied.
SECURITY DEFINER functions use empty search_path and qualified table/digest names.

Envelope has exactly status, receipt, payloadText. Status committed returns
validated stored text; deleted retains receipt with null text; read lookup
unavailable returns null receipt/text for unknown, other-owner or legacy trips.
Receipt has EXACTLY ten keys:

deviceScope, targetOwner, draftId, sourceRevision, requestKey, contentDigest,
receiptId, tripId, remoteVersion, committedAt.

Version is integer 1 from private ledger; committedAt is stable UTC with fractional
seconds and trailing Z. There is no inferred version for legacy trips.

Errors: unauthenticated, invalid_input, unsupported_schema, digest_mismatch,
identity_conflict, payload_conflict, stored_content_invalid. Direct imported trip
updates additionally raise imported_trip_immutable. Preflight/ACL errors are
deployment diagnostics, not successful RPC acknowledgements.

## Bytes, input limits and projections

SHA-256 hashes the exact UTF-8 submitted text independently. Semantic JSON is
validated before insertion and checked against stored text on reads/retries.
Duplicate keys are rejected before conversion to jsonb, recursively.
The server preserves valid alternate formatting; it does not recreate the Dart
serializer or assert that arbitrary RPC input is Dart-canonical.
B4 must decode/encode/hash through B1 before local acknowledgement.

Limits: 1 MiB UTF-8; depth 32; each array 1000; each object 256 keys.
Identity lengths 128 Unicode characters; request key 256. Revision positive
and <=9007199254740991; money non-negative with the same upper bound; request
counts positive and <=2147483647. Integer fields reject fractional/exponent
tokens. Numeric fields must be finite float8-compatible values. Calendar dates
are validated and remain in JSON; legacy start_date/end_date are explicitly NULL.

Input-only payloads with plan:null are supported; request:null with plan is also
supported; both null are rejected. No algorithm is run or recomputed.
Title/destination use the approved B2 projection order and Vietnamese placeholders.
Days/budget come from request or explicit NULL; status planning; explicit
clock_timestamp() avoids the legacy created_at default.

## Transactions, ACL and races

Owner-scoped advisory transaction lock serializes import attempts. Unique owner/
source/scope/revision and owner/request-key constraints are the durable backstop.
No REPLACE or receipt overwrites. Reply reads ledger, takes a shared trip lock,
then re-reads ledger. Delete takes trip lock then marks receipt; it never takes
the import owner lock. Missing trip with a receipt is terminal deleted.

Preflight verifies exact base trip column types/nullability/count, required
extensions/functions, owner/activity cascade FKs, RLS, table-owner migration
authority, name/trigger collisions and effective app privilege drift. New ledger
and helper privileges are explicitly revoked and checked after creation.
Legacy defaults are bypassed explicitly for imports. Broader deployment review
must still compare live defaults, constraints, policies, column/default ACLs and
staging parity against the approved evidence before applying this source.
No existing unrelated ACL or default is rewritten.

Runner rejects every project/host except bkocylxbuyvdgxccpixx and its exact direct
database hostname, including primary oavbymauorhmrjcustzw. Default is dry run;
SelfTest never connects. ExecuteStaging is only for separately approved execution
after migration apply. Native psql is hidden, uses environment/PGPASSFILE, verifies
TLS, limits connection/query/process time, drains both output streams, withholds
private SQL stderr and cleans only its random UUID + matching synthetic email.
No migration execution exists inside the runner. It uses pipes, no temp DB/files.

## Testing — source task, before staging apply (historical)

Actual checks in this source task:

- Flutter analyze --no-pub: PASS, no issues (44.4s).
- Flutter test --no-pub: PASS, all 272 existing tests (including B1 golden vectors).
- PowerShell parser: PASS before final source inspection; rechecked at handover.
- Runner SelfTest: PASS, including primary/localhost/lookalike target rejects.
- Runner default staging dry run: PASS; no connection.
- Independent UTF-8 SHA-256 over three frozen SQL literal vectors: PASS (3/3).
- Unicode reject fixtures checked for actual single JSON escape sequences.

Logs: B3_flutter_analyze.log and B3_flutter_test.log in the current Codex
visualizations artifact directory. Flutter tests are application regression
evidence; they do NOT execute or prove the new PostgreSQL contract.

SQL positive/negative tests, concurrent native sessions, fault rollback,
lost-response durability, account/delete cascades and actual RLS/ACL behavior:
**NOT RUN**. PostgreSQL parsing/function compilation is also NOT RUN.
No claim of SQL runtime PASS or deployment readiness.

Acceptance matrix (written source, all database runtime proof pending):

| Group | Written coverage / remaining evidence |
| --- | --- |
| 01 Precondition | Migration fail-closed checks; broader deployment catalogue comparison pending |
| 02 B1 bytes | Three frozen strings/hash; response round-trip remains runtime pending |
| 03 Strict rejection | Duplicate/unknown keys, dates, integers, Unicode and finite numbers |
| 04 First import | Three imports and exactly ten receipt fields |
| 05 Stable retry | Entire response equality and fresh-session retry |
| 06 Conflict | Source/key/scope/digest tests and three lock-waiting conflict sessions |
| 07 Stored consistency | Synthetic fixture ledger digest corruption must fail closed |
| 08 Atomicity | Ledger-insert fault must roll back preceding trip insert |
| 09 Lost response | Discard response then retry in fresh session; abrupt network-drop proof pending |
| 10 Owner roles | Actual authenticated A/B and anon; legacy read uniformity |
| 11 Private ACL | Effective privileges and actual direct table/helper/TRUNCATE rejection |
| 12 Delete/cascade | Terminal receipt, account cascade and both trip-lock order races; child-activity fixture proof pending |
| 13 Version | Immutable title/owner, unchanged receipt/version and retained legacy CRUD |
| 14 Projection | Input-only/full/plan-only, dates, explicit false/fallback, nullable counts/budget |
| 15 Limits/harness | Bounds/rejects, native timeouts/owned cleanup, isolated negative controls; full boundary runtime pending |

## Problems / next authorized boundary — before apply (historical)

Source is available for review. Before calling B3 complete/merge-ready, separately
approve isolated staging apply and database tests, inspect any schema drift, and
resolve runtime findings within a new bounded packet. Primary apply remains a
separate decision. There is no production restore rehearsal gate.

B2 currently rejects plan:null snapshots. That two-file compatibility change
requires its own packet before B4 integration; it was not silently patched here.
Deleted import handling/Guest consent, Provider integration and display remain
B4/B6/B8 work. No independent-agent review occurred in Codex-only mode.

## Lesson Candidate

Problem: application tests can pass while a new database RPC is still unverified.
Root cause: Flutter regression coverage does not execute PostgreSQL transactions,
role ACLs or independent connection interleavings.
Actionable rule: record source, offline checks and database runtime proof separately;
require observed database barriers and exact receipt comparisons for retry races.

## Follow-up staging readiness — 2026-10-11, before apply (historical)

Owner approved source and requested the next step. Codex inspected the actual
staging Dashboard: travel-go-staging, project bkocylxbuyvdgxccpixx, Healthy.
Metadata-only query captured at 2026-10-11T06:02:30.307428Z; executor postgres,
PostgreSQL 17.11. Core trip columns/defaults/constraints and owner CRUD policies
match the earlier primary inspection; no import ledger or non-internal trip
triggers. App TRUNCATE/TRIGGER/REFERENCES are denied for both relevant tables.
Staging is a newer PostgreSQL minor release than the historical primary 17.6
inspection, so this is not evidence of exact runtime environment equality.
Default ACLs were inspected; private schema is absent. Additional metadata query
captured at 2026-10-11T06:04:32.229520Z confirms both tables owned by postgres,
RLS enabled, force-RLS false, no explicit column ACLs, no matching function-name
collisions, pgcrypto in extensions and no app CREATE on inspected schemas.
No application rows, credentials or database writes were performed.

Native psql exists, but PGUSER/PGDATABASE/PGPASSFILE/PGPASSWORD are unset and the
default pgpass/root certificate files are absent. Thus the two-connection runtime
suite cannot currently run. Do not reset database credentials or downgrade TLS.
Owner must configure the existing staging credential locally (not in chat) and
provide a trusted PostgreSQL CA file for verify-full before native execution.

Readiness review tightened the runner within the existing allowlist: postgres
user/database binding, existing pgpass assertion, explicit PowerShell 7 support,
no interactive password prompt, and removal of inherited PGHOSTADDR. The last
prevents an environment variable from changing the actual connection address
while the advertised PGHOST passes the target guard.
Migration source remains unchanged by this follow-up. No apply or new database
runtime PASS is claimed. Separate action-time confirmation is needed before a
Dashboard apply creates the two new authenticated RPC permissions.

Follow-up verification: PowerShell 7.6.5 parser, target SelfTest and staging dry
run PASS without connecting. Flutter analyze --no-pub PASS (3.6s); Flutter test
--no-pub PASS (272 tests, 19s). No PostgreSQL behavioral suite ran.
Frozen migration SHA-256:
1c1bfa26995fa27cb2f4ddde7e27cb43f09813fbebe6f072d9bb4830f2ee29b7.
Screenshot: B3_staging_preflight.png in the current visualizations artifact directory.
Owner was asked for action-time confirmation of staging apply and local native
connection setup. Pending response is NOT approval. No database writes performed.

## Staging execution and cascade repair — 2026-10-11 (before native Owner run)

Owner explicitly approved staging apply/tests and then explicitly approved the
prepared trigger repair after the automatic approval review blocked that repair.
Target remained travel-go-staging / bkocylxbuyvdgxccpixx. Primary was untouched.
Codex-only; superpowers OFF. Checkout still codex/phase-2-b3-import-contract,
base HEAD 8213e4aa0b0307fbf63ceb73816cf95f193511fa; source remains uncommitted.

### Changed / Why

Initial migration (SHA-256 1c1bfa26995fa27cb2f4ddde7e27cb43f09813fbebe6f072d9bb4830f2ee29b7)
applied successfully. Postcondition confirmed the text column, ledger and two
trip guards. Runtime positive tests exposed SQLSTATE 23503 on account deletion:
auth.users had already been removed when the trip delete trigger updated its
receipt; that update rechecked the immediate owner FK before receipt cascade.

Corrected source checks whether the owning auth.users row still exists before
tombstoning. Ordinary trip deletion retains receipt; account deletion leaves
trip/receipt removal to their owner cascades. Owner approved the one-function
CREATE OR REPLACE repair, which was applied and exercised by the unchanged
positive suite. No weakened assertions or client permissions changed.

Current complete migration source SHA-256:
ea550f8fe8c62cb7c949ff6409a117fa49653837a68ff3c6707d7a921f86147c.
Staging reached this state via initial migration plus targeted repair; the
complete corrected migration was not reapplied onto an already migrated schema.

### Testing / evidence

- Dashboard positive suite: PASS after repair, including literal bytes, exact
  receipt/retry, ownership, rollback fault, immutable content, terminal deletion,
  plan-only/input-only projections, legacy CRUD and account cascade.
- Dashboard negative suite: PASS both before and after repair, including actual
  role ACL rejects and synthetic assertion/error/duplicate detector controls.
- Both suites end in ROLLBACK; fixture cleanup is checked separately.
- Post-repair check at 2026-10-11T06:22:46.143498Z: fixtureAccounts=0,
  fixtureReceipts=0, cascadeGuardInstalled=true, authenticatedImport=true,
  anonImport=false and directLedger=false. Saved in B3_post_repair.txt/.png.
- Dashboard adapter replaces psql directives/quoted variables with a temporary
  UUID holder table. Explicit text casts were needed for JWT settings and owner
  text comparisons. Assertions remain identical; an earlier adapter type error
  is not hidden or counted as PASS.
- Flutter analyze --no-pub: PASS (4.3s), latest source correction unchanged since.
- Flutter test --no-pub: PASS, 272 tests (19s), confirmed from the completed
  session after the previous handover had reported it still running.
- Native target SelfTest: PASS; local secure-password helper parses successfully.
  Neither native runtime suite nor credential helper has been executed.

Artifacts in the current visualizations directory:
B3_dashboard_positive.sql, B3_dashboard_negative.sql,
B3_staging_trigger_repair.sql, B3_staging_positive_PASS.txt/.png,
B3_staging_negative_after_repair.txt/.png, B3_staging_analyze.log,
B3_staging_test.log. Post-repair catalogue/cleanup result is saved separately.

### Problems / remaining work

Native independent-connection races, durable lost-response retry and native
fixture cleanup remain NOT RUN because no local staging credential/CA is
configured. Child-activity fixture proof and complete boundary runtime coverage
remain pending from the acceptance matrix. Dashboard suite PASS alone is not a
claim that all fifteen groups are complete or that B3 is merge-ready.
Primary deployment and B2 input-only compatibility remain separate decisions.

### Local connection handoff

1. In STAGING Database Settings download its server root certificate. Do not
   change SSL enforcement or reset the database password.
2. Run B3_RUN_STAGING_LOCALLY.ps1 from the current visualizations directory using
   PowerShell 7. It asks for the certificate path and existing staging password
   locally, with password input hidden. Never put that password in chat/history.
3. The helper restricts a temporary pgpass file to the current Windows user and
   SYSTEM before writing it, runs only the staging test runner, restores process
   environment and deletes its single owned temporary file afterward.
   It applies no migrations. Share only the PASS summary or a redacted error.

Certificate guidance: https://supabase.com/docs/guides/database/connecting-to-postgres

### Lesson Candidate

Problem: receipt tombstone update failed during account cascade despite working
for individual trip deletion. Root cause: parent disappearance and immediate FK
revalidation follow a different ordering during account deletion.
Actionable rule: test parent-account and child-trip deletion independently; use
the parent's existence to choose retained tombstone versus owner cascade.

## Evidence reconciliation and five-file review — 2026-10-11

### Changed / Why

Only this report changed in the reconciliation task; the four SQL/runner sources
remain unchanged. Branch/base are still codex/phase-2-b3-import-contract at
8213e4aa0b0307fbf63ceb73816cf95f193511fa. All five packet files are untracked;
tracked and staged diffs are empty. No commit/PR SHA exists for B3 yet.
Old NOT RUN statements above are historical, not the latest native status.

Owner supplied a screenshot of the final local helper execution at approximately
13:51 Asia/Saigon. It shows both final runner messages:
`B3 staging suites/races PASS; cleanup must still complete.` and
`B3 staging execution and owned-fixture cleanup PASS.`
This is Owner-executed runtime evidence, not a native run performed by Codex.
No full native transcript, run UUID or hashes from execution time were captured;
the screenshot alone cannot cryptographically bind that run to these source hashes.
Do not archive the original terminal screenshot in the repository: it contains
earlier user-entered text unrelated to the test evidence.

### Testing / independent corroboration

Codex read all five packet files and traced the runner success path: positive and
negative native psql suites, observed lock barriers for duplicate/conflict races,
discarded response followed by a fresh-connection retry, both deletion/read lock
orders, terminal receipt equality, and independent owned-fixture cleanup must
finish without an exception before its final PASS message can print.
The discarded-response test is not an abrupt network fault or HTTP E2E test.

Read-only SELECT on the verified staging tab at
2026-10-11T06:55:10.466339Z independently returned:
fixtureAccounts=0, fixtureReceipts=0 for both @b3.invalid and
@b3-concurrency.invalid; cascadeGuardInstalled=true;
authenticatedImport=true; anonImport=false; directLedger=false.
It corroborates current cleanup/permissions, not past lock interleavings.
An initial audit query used a wrong SQL-suite email suffix; the corrected query
above supersedes it. No database mutation was made during reconciliation.
Evidence: B3_evidence_audit.txt/.png in the current visualizations directory.

PowerShell parser, target guard SelfTest and default dry run were re-run PASS,
without a database connection. Historical current-source Flutter evidence remains
analyze no issues (4.3s), full tests 272 PASS (19s); fresh checks are recorded below.

Fresh `flutter analyze --no-pub` and `flutter test --no-pub --reporter compact`
attempts produced no output within the task command budget and were stopped.
Both sessions ended with exit 1 after interruption; neither is a fresh PASS nor
evidence of an assertion/linter failure. Cause of the startup stall is unverified.
Historical regression PASS above is retained with its provenance; retry fresh
regression checks after resolving the startup stall before an eventual commit.

Source fingerprints at reconciliation (SHA-256):

| Source | SHA-256 |
| --- | --- |
| migration | ea550f8fe8c62cb7c949ff6409a117fa49653837a68ff3c6707d7a921f86147c |
| positive SQL | acc7b772a9ead0f7703a93dd92ff6e2c57d8e6ad52416dd3e9d726eb430bc409 |
| negative SQL | 2d36a99591f6b52220af2a8b6c3b383214ac381ca0c450fb8ba69709a2c93185 |
| native runner | 8c384d8f3c9742d826ad7e85cb95edf1c052dd72af1d429e3246b175964efad2 |

### Problems / acceptance findings

Core retry/transaction/role behavior has runtime evidence; no new implementation
defect was found in this source review. Tests passing does not close uncovered cases.

| Finding | Evidence gap | Concrete closure |
| --- | --- | --- |
| B3-E1 | Positive SQL has no trip_activities INSERT fixture; a validated CASCADE FK alone is not behavioral proof | Add owned child activity fixtures, assert removal for trip deletion and account deletion, and keep an unrelated owned fixture intact |
| B3-E2 | Limits coverage is partial: 1000/1001 arrays and safe integer boundary exist, but exact UTF-8 byte limit, identity/key bounds, valid depth/object boundaries and projection placeholder assertions are incomplete | Add valid-at-limit and rejected-above-limit fixtures through the relevant validator/RPC, and assert no writes on rejected import; test exact title/destination fallback order |
| B3-E3 | Successful native cleanup is corroborated; timeout/failure/cancel cleanup paths have source review but no runtime fault exercise | Exercise a controlled owned-session failure/timeout and verify independent cleanup, process ownership and preserved diagnostics; record cancellation limitations explicitly |

T01–T06/T08/T10–T14 have positive/negative runtime coverage, with the specific
T12/T14 gaps above; T07/T09 have Owner-native evidence for the implemented races
and response discard; T15 has success-path and offline guard evidence, with E2/E3
remaining. This is partial coverage across groups, not a claim of fifteen fully
completed groups. HTTP drop/SDK JWT end-to-end belongs to later integration.
Corrected full migration first-apply from a clean baseline is NOT RUN: staging
was migrated once and repaired by the explicitly approved function replacement.
Do not reapply the full additive migration onto existing staging.
Primary apply and B2 plan:null compatibility remain separate future packets.

### Commit / PR preparation

The allowlist remains exactly the five paths listed at the top. No Owner assets,
unrelated untracked planning/review docs, credentials, artifacts or build files
are eligible for staging. No file is staged in this task. No merge/push occurred.
Proposed eventual title: `feat(trips): add atomic guest import receipt contract`.
Reviewer summary: preserve submitted UTF-8 trip text and atomically create a
private owner-bound receipt; retries reuse the original receipt and deleted trips
cannot be recreated by retry. Include staging evidence, cascade repair history,
the exact reviewed commit and explicit limits in the final PR body.
Status: source/evidence ready for Owner review, NOT yet certified merge-ready;
close E1–E3 in the existing packet before publishing a completion claim.

### Lesson Candidate

Problem: a final PASS screenshot can be mistaken for complete acceptance coverage.
Root cause: the runner proves only the behaviors it actually exercises, and its
summary does not contain per-case evidence or execution-time source fingerprints.
Actionable rule: reconcile source, runtime provenance, independent postconditions
and uncovered acceptance cases before preparing a merge-ready handoff.

## Extended acceptance repair packet — 2026-10-11

Owner authorized missing tests, verification and commit/PR preparation. Codex-only,
superpowers OFF. Same base/branch and five-file allowlist; migration unchanged.
Only the two SQL suites, native runner and this report changed in this follow-up.

### Changed / Why

- B3-E1 CLOSED: owned trip activity fixtures now prove child deletion on trip
  deletion and account cascade, while another account's trip/child remain intact.
- B3-E2 CLOSED for the identified missing cases: exact 1048576 UTF-8 bytes accepted,
  1048577 rejected using a multibyte vector; 128/129 scope/draft and 256/257 key
  bounds; maximum/above-maximum/zero source revision; traversal depth 32/33 and
  object size 256/257; exact preference/destination/placeholder projection order.
  Traversal bounds use the private walker because valid DTO shape has fewer nesting
  levels/keys. Existing reject-no-write and other assertions remain intact.
- B3-E3 IMPLEMENTED / native runtime NOT RUN: default staging runner additionally
  exercises SQL error, owned child process timeout and cooperative cancellation.
  Each uses an independent synthetic owner with committed legacy/import trip and
  receipt, then checks account/trips/receipts absent via a fresh connection.
  This does not simulate external host kill, power loss or HTTP network failure.
  Final extended PASS is printed only after all three fault controls and cleanup.

### Testing

- Extended positive SQL: Dashboard PASS (rolled back), including new child cascades.
- Extended negative/boundary SQL: Dashboard PASS (rolled back). Native psql variables
  were adapted to a temporary UUID holder; assertions unchanged.
- Flutter analyze --no-pub: exit 0, no issues (5.6s).
- Flutter test --no-pub --reporter compact: exit 0, all 272 PASS (24s).
- Runner parser and target SelfTest: PASS, without DB connection.
- Native extended fault controls: pending Owner rerun of secure local helper.
  Earlier native screenshot proves the previous runner only, not these added controls.
  Codex has no stored password and has not claimed a new native runtime PASS.

The initial Flutter attempt inside sandbox failed during VM initialization before
analysis. Running the standard Flutter command with approved sandbox escalation
succeeded; no Flutter SDK or application source was changed.
Proof screenshots: B3_extended_positive_PASS.png and
B3_extended_negative_result.png in the current visualizations directory.

### Problems / review handoff

Remaining merge-readiness gate: actual native extended-control result (B3-E3).
Primary NOT APPLIED; B2 plan:null compatibility and B4 integration remain separate.
Review draft must prominently disclose the pending native check, earlier staging
migration-plus-repair history and corrected-first-apply limitation. No auto merge.

### Lesson Candidate

Problem: success cleanup alone did not prove handling of failed native sessions.
Root cause: lifecycle error paths were inspected but never deliberately triggered.
Actionable rule: isolate owned fault processes and fixtures, check typed cancellation,
and require independent cleanup proof before printing extended acceptance PASS.
