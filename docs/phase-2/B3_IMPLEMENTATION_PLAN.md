# B3 — Server import contract implementation plan (R2)

2026-10-11. Status: DESIGN DRAFT / NOT CODE-APPROVED / NOT APPLIED.
**Goal:** atomically import a selected Guest revision with a durable, owner-bound receipt and retry without duplicates or resurrection.
**Architecture:** Supabase RPC validates exact UTF-8 text, stores text + parsed JSON in trips, and creates a private metadata-only ledger in one transaction. Imported content is immutable in v1; receipts survive trip deletion.
**Tech stack:** existing Supabase PostgreSQL 17.6 / extensions.pgcrypto 1.3, native psql 18.6, B1 Dart codec, B2 SQLite client store.
**Spec:** [B3_DESIGN_SPEC.md](B3_DESIGN_SPEC.md). Live evidence: [B3_LIVE_SCHEMA_EVIDENCE.md](B3_LIVE_SCHEMA_EVIDENCE.md).
**Execution instruction:** Codex-only. Owner explicitly requires superpowers ON for analysis/planning, OFF before implementation/fixes/verification. No executing-plans, TDD skill, worktree skill or agents during implementation. Normal behavioral tests remain required. Owner location overrides skill defaults: docs/phase-2, never protected docs/superpowers/.

R1 was prepared without superpowers. R2 uses superpowers:brainstorming and writing-plans, with inline self-review and Owner's existing contract/storage/input-only approvals. No product code, checkout change, schema mutation or backend change. Read-only live catalogue SELECT was executed; that is not database apply. Owner requested easy-to-understand questions whenever an undecided requirement affects the plan.

## 1. Verified checkpoint and evidence limits

- PR #20 MERGED; main `8213e4aa0b0307fbf63ceb73816cf95f193511fa`. GitHub compare against B2 HEAD `7a11243754467246ded8880b3d45eca39006e9c6` returned no changed files.
- Main CI https://github.com/plhhoang2005/travel-go-mobile/actions/runs/38114642872: SUCCESS on that exact main SHA.
- Local checkout remains `codex/phase-2-b2-converged` @ `7a11243754467246ded8880b3d45eca39006e9c6`; tracked clean, unrelated untracked Owner/review files preserved. Do not assume local main has been updated.
- Source inspected: Batch A migration, staging baseline/inspect runner, TripsService, B1 codec and literal-vector review, B2 receipt/store, Phase 1 acceptance and Batch B design decisions. Baseline is a reconstruction, NOT current deployed schema evidence.
- Historical schema review (2026-10-08, Owner-exported metadata) has public.trips and trip_activities, no import receipt/version evidence. Batch A apply/postcondition PASS is historical accepted evidence; never reapply it.
- R1 had no usable Supabase browser session. R2 directly inspected the primary Dashboard project: captured_at 2026-10-11T05:36:05.23418Z, PostgreSQL 17.6. trips has 11 columns, no version/text companion; trip_activities 12 columns. Owner FK CASCADE and activities FK CASCADE validated, owner RLS present, app TRUNCATE/TRIGGER denied, no non-internal trip triggers or matching import functions/receipt table names in scoped inspection. pgcrypto lives in extensions. See live evidence for scope/limits; no application rows/credentials read.
- B3_SCHEMA_INSPECTION.sql remains the broader multi-result query, NOT RUN as that file. Actual single-result live catalogue query covered core tables/columns/FKs/policies/ACLs/indexes/triggers/functions/extensions. Namespace/default/column ACLs, staging parity and drift checks remain implementation preflight, not a stale-live-metadata blocker.

## 2. Product contract retained and new Owner answer

Retain 1A–5A: Supabase atomic RPC, explicit selection/account confirmation, no automatic import, preserve pending Guest source, owner quarantine, no Decision Engine recomputation, no Gemini/quota.

OWNER CONFIRMED in this task: input-only Guest drafts MAY be imported without generating an itinerary. A successful import retains request and metadata with `plan:null`; the app must distinguish this from a completed itinerary.

OWNER CONFIRMED while preparing R2: keep calendar dates in JSON, leave legacy timestamptz date columns NULL for new imports. Preserve exact JSON text on trips for retry. Codex-only planning uses superpowers; implementation does not.

Compatibility finding B3-P01: B2 currently rejects `plan:null` in commitImportAck (around line 1304), _upsertSnapshotTxn (1656), and checked snapshot mapper (584). This was the earlier B2 full-plan contract; the new answer extends behavior. B3 must not quietly patch B2 or claim end-to-end compatibility. Propose a separate two-file client compatibility packet (`local_trip_store.dart`, `local_trip_store_test.dart`) before B4 integration; preserve receipt bindings, digest checks, CAS and purge/fencing. Revisit display and read-only input snapshots in B6/B8. Owner code approval required for that packet.

## 3. Minimal server architecture

Proposed RPC `public.import_guest_draft_v1` accepts deviceScope, draftId, sourceRevision, requestKey, payloadText, contentDigest. Owner comes ONLY from auth.uid(); no supplied owner argument. Require authenticated role/subject. Demo and anonymous callers are rejected. Use the existing Supabase client/JWT; no service key on mobile or Spring endpoint.

Proposed private ledger `private.guest_import_receipts`:

| Field | Type / constraint / responsibility |
| --- | --- |
| receipt_id | UUID PK generated by server |
| owner_id | UUID NOT NULL, FK auth.users ON DELETE CASCADE; account deletion behavior follows existing account ownership lifecycle, no account-deletion feature |
| device_scope, draft_id | Nonblank text <=128 Unicode characters, valid Unicode; B2-compatible, no speculative UUID-only gate |
| source_revision | BIGINT, CHECK 1..9007199254740991 |
| request_key | Nonblank text <=256 Unicode characters; stable for attempt; server never infers owner from it |
| content_digest | TEXT, exactly 64 lowercase hex; server-computed SHA-256 checked against supplied digest |
| trip_id | UUID NOT NULL stable identity; deliberately NO cascading FK to trips, retained after deletion |
| remote_version | BIGINT positive, immutable import receipt version 1 |
| committed_at | TIMESTAMPTZ NOT NULL server timestamp; response UTC string ending Z |
| deleted_at | TIMESTAMPTZ nullable terminal tombstone |

Unique (owner_id, device_scope, draft_id, source_revision); unique(owner_id, request_key); unique(trip_id). Source scope is mandatory because B2 identities include device_scope. No itinerary, canonical payload, credentials or token in receipt ledger. No TTL purge that permits recreation. Payload/text belongs to trips, written together. Ledger private schema has no anon/authenticated direct read/write; enable RLS without client policies; RPC provides own-owner output. Existing service/admin privileges are inspected, not globally revoked. New RPCs SECURITY DEFINER, search_path='', schema-qualified references including extensions.digest; explicitly revoke PUBLIC/anon/default EXECUTE and grant authenticated only on the two public entry points. Private helpers have no app EXECUTE.

Identity cross-conflicts are errors: same source with another key; same key with another source/scope; same source/key with changed digest. Never REPLACE, overwrite or create a second trip to resolve a conflict.

### Atomic execution and races

1. Validate JWT, scalar types and bounded input sizes; independently verify exact payload UTF-8 SHA-256 and strict v1 shape before writes.
2. Serialize imports for that owner with a transaction advisory lock derived from trusted owner ID. This deliberately serializes one owner's imports for simple race reasoning; hash collision can only serialize unrelated work, never authorize it. Unique constraints remain the durable backstop. No exception handler may swallow a uniqueness failure and leave a partial trip.
3. Look up both source identity and owner/request key with plain reads. If either exists, validate ALL identity/digest bindings before returning. Lock live trip FOR SHARE, then re-read receipt; never lock receipt first. Delete holds trip then marks ledger; no owner advisory lock in delete. This removes receipt-lock/delete deadlock inversion. Retry returns the stored receipt, not a new timestamp/ID/version. Missing/deleted trip returns a terminal deleted response; never inserts again. Test actual interleavings, including a delete winning while the shared lock waits.
4. First import: validate payload; derive projections; insert trips and ledger in the same function transaction. No trip_activities dual writes; itinerary remains in canonical JSON. Fault after trip insert must roll back both rows.
5. Serialize the response from stored rows; PostgreSQL transaction must commit before an HTTP success reaches the caller. Connection/response loss leaves a durable receipt for retry. UI cancellation cannot undo a committed operation.

Proposed BEFORE DELETE trigger on trips marks matching receipt.deleted_at in the same delete transaction. Retain trip_id and receipt identity. Concurrent retry/delete must have a tested lock order; return may describe the live trip at its read point even if deleted immediately afterward. No promise to stop a later authorized delete. Account cascade deletes ledger through owner FK; test interaction with trigger/FK ordering on isolated fixtures.

Imported payload is immutable in B3. Add a narrowly scoped BEFORE UPDATE guard preventing changes to imported trip owner/content/projections; existing non-import trips retain existing CRUD. Receipt version 1 is authoritative only for this immutable imported content. Future editing/version increments need another contract. A client must not be able to change imported content via direct REST and leave a version-1 receipt unchanged. No invented version 1 for legacy trips.

## 4. Wire response / B2 bindings

Alive response envelope: status=committed; receipt (EXACT 10 keys); payloadText (the validated submitted bytes on initial import, and saved representation on retry). These outer keys do not go into LocalImportReceipt.fromMap.

Receipt keys exactly match B2: deviceScope, targetOwner, draftId, sourceRevision, requestKey, contentDigest, receiptId, tripId, remoteVersion, committedAt. Integers serialize as JSON integers; committedAt explicitly formatted UTC YYYY-MM-DDTHH:mm:ss.ffffffZ from stored timestamp. Compare stored receipt on retry, never reconstruct using request-only values. B4 validates all ten plus payload/source/journal digest and current subject/epoch before local acknowledgement.

Deleted response: status=deleted; stored receipt; payloadText=null. B4 must NOT feed this through commitImportAck or fabricate a snapshot. Terminal reconciliation/Guest-source disposition must be designed in B4 consent UI; user-visible explanation rather than reporting a new saved trip. Source survives until that separate policy is applied.

Import retry itself performs reconciliation. A separate read-only get_import_trip_snapshot_v1(p_trip_id uuid) returns the same committed/deleted envelope for an owned imported trip; unknown/not-owned/not-imported returns uniform unavailable with null receipt/text. This is needed by B6 to fetch authentic server version/digest without trusting a client-writable column or treating every legacy trip as version 1. Errors have stable safe codes: unauthenticated, invalid_input, unsupported_schema, digest_mismatch, identity_conflict, payload_conflict, stored_content_invalid. Do not include private payload/IDs from other owners in logs/errors.

## 5. Canonical bytes — key technical pre-code gate

B1 canonicalizes keys in UTF-16 ordinal order, preserves array order, encodes finite Dart doubles with Dart JSON spellings, normalizes negative zero, and rejects NUL/unpaired surrogates. Vector 3 explicitly includes 1e-7 and BMP/non-BMP keys. PostgreSQL jsonb::text is NOT the B1 byte protocol.

Recommended transport is payloadText TEXT, not a jsonb RPC argument: server computes SHA-256(convert_to(payloadText,'UTF8')), compares it with the client digest, parses/validates it, then stores semantic JSON in ai_plan_data. This recomputes the digest independently; hashing a jsonb reserialization would hash different bytes.

Transport alone would not solve exact retry payload reconstruction from jsonb. The previously considered SQL serializer would need to reproduce doubles, string escaping, UTF-16 key ordering, negative zero and exponent forms. Owner selected the companion-text direction below to remove this work. Strict shape validation still must inspect duplicate keys before conversion to jsonb. Do not silently substitute PostgreSQL numeric formatting or accept arbitrary JSON solely because its supplied hash matches.

OWNER CONFIRMED later in this task: store exact JSON text in the trip alongside existing JSON, avoiding a SQL reimplementation of Flutter number/Unicode formatting. Proposed additive column `public.trips.canonical_payload_text TEXT NULL`: legacy rows remain NULL with no backfill; first import writes payloadText and ai_plan_data together from one RPC; semantic equality, strict validation and digest consistency are checked before commit. The ledger still stores metadata only. Retry returns saved text, not jsonb::text or a newly generated encoding. This is design approval of the storage direction, NOT code/apply approval.

This removes server reconstruction. R2 proposes explicit byte-preserving wire acceptance: valid alternate whitespace/key order/string/finite-double spelling is preserved, not normalized by SQL, and is different digest content under a stable source/key. Server still independently validates strict v1 semantics/types and rejects duplicate keys recursively before jsonb conversion. Normal client always uses B1 canonical encoding; B4 requires decode->encode/hash equality before local ack. Thus raw RPC shape/hash PASS is not a claim of universal Dart-canonical formatting. This clarified acceptance policy is part of the final Owner design review. A semantic mismatch between text and ai_plan_data, missing text for an imported row, or stored digest inconsistency fails closed on retry, never rewrites ledger. Imported text/JSON/projections immutable together. Authority requires server-owned ledger binding, not just a client-writable companion column.

Shared vectors must use independently frozen B1 literal strings/hash, including input-only and full-plan examples. Require both first response and repeated response decode->encode in Dart to match the same digest. Any unresolved mismatch blocks code approval; no B1 rewrite or schemaVersion change without separate approval.

## 6. Projections and schema-dependent decisions

Canonical envelope is content truth; projections match B2 helpers EXACTLY: title=metadata.title, else 'Chuyến đi '+first plan destination name, else 'Chuyến đi '+first request preference, else 'Chuyến đi'; destination=metadata.destinationName, else first plan destination name, else 'Điểm đến'. Placeholder is display/projection only, never mutate envelope. No divergent input-only placeholders introduced in B3.

num_days=request.numDays or explicit NULL without request; budget_total=request.budgetVnd or explicit NULL without request. Existing columns are nullable: do not fabricate 3 days/0 budget or recompute a total. B6/B8 must display missing values truthfully using canonical content rather than legacy parser defaults. status planning; created_at explicit UTC server instant, bypass the current timezone-sensitive default for new imports only. No booking behavior.

start_date/end_date are live-confirmed timestamptz. Per Owner decision, both explicitly NULL for new imports, with all known/unknown calendar values preserved unchanged in JSON. No timezone conversion, fake time, legacy-date migration or new date columns. Existing MyTrips displays days/budget rather than these dates; future canonical viewers must read metadata dates.

Strict nested validation mirrors B1's key sets/predicates; both request and plan null invalid, input-only allowed. No algorithm recomputation. R2 proposes limits in B3_DESIGN_SPEC.md: 1 MiB UTF-8, depth32, arrays1000, object keys256, identity chars128/key256, safe integer ceiling 9007199254740991, positive request counts <=2147483647. Integer-typed JSON tokens reject 1.0/1e0; float fields must be finite IEEE-754 compatible. Before traversal enforce byte bound; each recursive call enforces depth/collection bound. Boundary and representative-fixture tests document acceptance subset explicitly; no claim of accepting arbitrarily large B1 payloads.

## 7. Future implementation packet allowlist (proposal)

No source implementation file is created by this inspection. Proposed B3 implementation task, at most five files:

1. supabase/migrations/202610100001_guest_import.sql — additive ledger/RPC/helpers/triggers; exact timestamp collision checked before coding.
2. supabase/tests/guest_import.sql — real PostgreSQL positive/atomicity/binding vectors.
3. supabase/tests/guest_import_negative_controls.sql — reject paths and controls proving assertions detect unsafe fixtures.
4. supabase/tests/run-guest-import-concurrency.ps1 — two independent native psql sessions, controlled barrier, no sleeps as correctness oracle, isolated staging-only target guard and safe fixture cleanup.
5. docs/phase-2/execution/R06_IMPORT_CONTRACT.md — frozen signature/response/errors/projections/fixtures/results.

No Docker, new dependency/native configuration, Spring edits, B4 UI or database apply. Work from verified main on codex/ feature branch with a single writer. Code review/PR and any staging database setup/apply/test are separately authorized tasks; WRITTEN is not APPLIED or PASS. No production restore rehearsal gate added; Owner's previously accepted scope remains.

## 8. Behavioral acceptance / test matrix

| Group | Proof required on actual PostgreSQL / role / independent connections |
| --- | --- |
| T01 preconditions | Exact columns/types/defaults/constraints/RLS/ACL/triggers/extensions and absence/name collisions; abort incompatible target without modifying it |
| T02 bytes | All frozen B1 literals UTF-8 hash; Unicode, double/int/exponent, array order, negative zero; retry reconstruction digest identical |
| T03 strict validation | Unknown/missing keys, duplicate keys, unsupported version, null-only content, bad dates/types/finite values/oversize rejected before writes |
| T04 first import | One trip + one receipt; exact 10 keys, source scope, owner, immutable version/time, full/input-only content preserved |
| T05 sequential retry | Identical receipt/trip and counts; no receipt timestamp refresh |
| T06 conflicts | Changed key/source/scope/digest and reused key across sources rejected; valid earlier row unchanged |
| T07 concurrency | Independent sessions, same request => exactly one trip/receipt; conflicting digest/key/source races => one valid winner, no orphan. SQL one-session loop does not count |
| T08 rollback | Real induced error between trip and receipt plus constraint/commit failure rolls back entire transaction; fixture fault hook cannot be exposed in production RPC |
| T09 dropped response | Execute/commit without consuming response; reconnect/retry => same receipt. HTTP-level drop remains B9 E2E NOT RUN unless exercised separately |
| T10 authorization | A/B/anon actual SET ROLE + JWT claim context and later SDK checks; null subject, caller-owner spoof, cross-owner lookup rejected; admin test alone insufficient |
| T11 ledger privileges | Direct SELECT/INSERT/UPDATE/DELETE/TRUNCATE and helper EXECUTE denied for app roles; function ACL/search_path inspected |
| T12 deletion | Delete imported trip retains terminal receipt, retry cannot resurrect; deletion/response races and account cascade fixtures |
| T13 version integrity | Imported direct updates cannot produce changed content under old receipt/version; legacy trip behavior unchanged |
| T14 projections | Known/unknown calendar dates retained in JSON and timestamptz NULL; input-only/plan-only; exact B2 title/destination; missing request yields NULL days/budget; fallback/explicit false preserved |
| T15 harness controls | Explicit staging ref/host (never primary), unique fixture ownership, cleanup after success/failure/cancel in independent phase, timeouts/connection termination, no secret logs; intentionally bad synthetic controls cause assertion failure |

SQL semantic tests use BEGIN/ROLLBACK fixtures where practical. Concurrency needs committed isolated fixtures and an independent cleanup action; both failure and cleanup diagnostics retained. Do not modify the existing staging runner to bypass its primary guard. Real staging tests NOT RUN until environment and execution are separately authorized. Flutter analyze/full tests run for final implementation regression, not for this documentation-only task.

## 9. Execution tasks and consolidated review

Execution is future work after code approval; SQL execution needs separate staging authorization. All tasks share the five-file allowlist above, not five new files per step.

### Task 1 — ledger, validation and additive preconditions
Files: migration, guest_import.sql, guest_import_negative_controls.sql, contract document.
Interfaces: private.validate_guest_payload_v1(p_text text) returns jsonb; exact public RPC signatures are defined in B3_DESIGN_SPEC.md. Ledger DDL follows section3 plus spec bounds.
- [ ] Write assertions before migration for missing function/ledger, duplicate/unknown keys, integer-vs-float tokens, text/hash preservation and limits. On authorized isolated staging, prove controls fail against the unmigrated baseline (not a production target).
- [ ] Implement preflight aborts for incompatible live-schema contract, name/signature collisions, missing extension schema and table/column/default ACL drift. Add nullable text column without backfill, private ledger/constraints/indexes, validator and explicit privileges in a single migration transaction.
- [ ] Run native psql -X -v ON_ERROR_STOP=1 against the authorized staging target using the existing target guard pattern. Verify T01–T03/T11; errors abort without partial DDL. Record target/ref/SQL hashes/exits. No primary apply.

### Task 2 — import/read RPC, immutable projections and delete tombstones
Same migration/tests/contract files. Produces import_guest_draft_v1/get_import_trip_snapshot_v1 and exact response envelope/10-key receipt; consumed later by B4/B6.
- [ ] Write first-import/retry/identity-conflict/role/isolation/rollback/read-RPC/deletion assertions; exact IDs/timestamp/version unchanged on retry. Independent literal vector3 hash must equal 57298dc9ac9c1e5fe1bcb299c0fb942fc60b90b073da20a082a419b9d74d46d3.
- [ ] Implement minimal RPCs and BEFORE UPDATE/DELETE guards using section3 lock order, exact projections and byte-preserving text; no fault-test entry point in production RPC.
- [ ] Verify T04–T06/T08–T14. Induce actual staging fixture failure after trip insert with a staging-only receipt constraint/trigger in rollback fixture, then assert both counts unchanged. Disabled-policy/permission synthetic negative controls are confined to isolated test objects; never weaken primary policies.

### Task 3 — independent-session races and final evidence
Files: run-guest-import-concurrency.ps1, positive/negative SQL tests, contract document. Harness requires explicit verified staging ProjectRef, ConnectionHost, connection options; primary ref/host guard fails before connection. Secret only via existing credential channel, never CLI output/body logs.
- [ ] Write failing harness controls for wrong target, barrier timeout, early connection failure, primary failure plus cleanup failure; identify fixtures with a unique run UUID and verify ownership before removal.
- [ ] Launch two native psql connections, owner/role contexts, controlled database barrier and bounded wait. Measure one trip/receipt for same identity; assert one conflict winner and zero orphan rows; exercise retry/delete both lock orders and account-cascade fixture. Always terminate owned processes and clean owned fixtures independently, preserving both failures.
- [ ] Verify T07/T12/T15 and run the real PostgreSQL suite with positive assertions plus controls that must deliberately fail. Missing authorization/environment means NOT RUN, never a fake PASS from one-session loops or mocks.
- [ ] Run Flutter analyze and Flutter test after implementation; exact allowlist/diff check, selective stage/feature commit/PR only when authorized. GitHub Flutter CI does not prove SQL tests; attach independent PostgreSQL evidence and preserve NOT RUN gates. Owner decides merge/apply.

### Self-review coverage and review focus
Inline review performed, no agents: receipt ten-key signatures match B2; source includes device_scope; text is not stored in ledger; exact title/destination match B2; input-only client gap remains explicit; imported version read needs authenticated binding RPC; locks acquire trip before ledger; legacy dates/defaults are not manufactured.
Review focus: (1) noncanonical but shape-valid input reaches raw RPC → preserved bytes/digest, normal client rejects noncanonical ack, Task1/2; (2) imported direct UPDATE corrupts version → rejected, Task2; (3) delete races retry → no resurrection/deadlock, Task3; (4) input-only acknowledgement currently blocked → separate client packet, not silently fixed by Task2; (5) metadata-only admin success mistaken for RLS runtime PASS → actual app roles, Task2/3. These are coverage requirements, not claims of runtime PASS.

## 10. Review exit

- LIVE-01 CLOSED in inspection scope by B3_LIVE_SCHEMA_EVIDENCE.md. Staging parity/default/column ACL/drift preflight still required before apply.
- BYTE-01 design specified: companion text approved, reconstruction removed, explicit shape+byte acceptance in spec for final review. Runtime proof remains NOT RUN.
- DATE-01 CLOSED by Owner answer: JSON dates retained; timestamptz NULL. PROJ-01 resolved proposal: match B2 title/destination; missing request yields NULL days/budget rather than fabricated totals.
- CLIENT-01: approved input-only extension requires separate client compatibility packet; B3 server PASS cannot bypass this.
- R2 design is concrete and ready for Owner review of spec + plan, including proposed wire acceptance/limits/read RPC/immutability. Code approval can cover B3 only while CLIENT-01 remains a separate prerequisite for feature enable; it does not require patching B2 during B3. Keep already-approved 1A–5A decisions; avoid repeated open-ended review cycles. No claim of implementation approval from this planning handover.

## Handover

Changed: R2 plan, design spec, live evidence and work-mode note; no product implementation/schema mutation. Why: exact text avoids competing serializers; immutable versioned imports plus retained receipts protect lost-response retry; shared lock order avoids delete race inversion. Testing: live metadata SELECT observed; inline plan/spec consistency review; Flutter/SQL behavior tests NOT RUN for planning. Problems: design/code approval and real PostgreSQL evidence still pending; input-only client extension remains separate. Lesson Candidate: semantic JSON equality is not byte identity; serialize and retain retry identity across resource deletion.
