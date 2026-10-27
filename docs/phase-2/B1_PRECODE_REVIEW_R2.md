# B1 revised plan review R2 — targeted corrections required

2026-10-10. Input attachment: `c8d1889e-0b60-4f79-a356-6b3e6bae3f14/Pasted text.txt`.

Latest status: final delta `fb358172-00a6-418b-bfa7-087a8164a319` addresses remaining findings with binding technical amendments consolidated in [B1_OWNER_APPROVAL_PACKET.md](B1_OWNER_APPROVAL_PACKET.md). Corrected B1 packet ready for Owner approval; no code/resolver/runtime/SQL PASS and no implementation authorization inferred. No further broad rewrite needed.

Owner explicitly requested superpowers for THIS review. Applied using-superpowers, receiving-code-review (read/understand/verify/evaluate/respond) and verification-before-completion (fresh evidence/status boundaries). No subagents, implementation, package installation, native changes, backend changes or database execution. Owner 1A–5A unchanged.

## Changed

Codex wrote this report and appended the latest status to B1_PRECODE_REVIEW.md. Source checkout main @ `4525c4a08360e2666274ff6fdc6aadf48e600713`; tracked diff empty before report writes. Protected Owner entries not read. B1 implementation allowlist remains five files. These are findings in a plan, not reproduced implementation bugs.

Review checklist: complete attachment read; current request/saved model and previous findings inspected; proposed rules checked against actual supported shapes; PostgreSQL/FFI primary docs consulted; independent date/key-order probes run; previous finding status and concrete corrections recorded. No inferred implementation PASS.

## Why — previous findings

| Prior finding | Revised plan evidence | Status at design level |
| --- | --- | --- |
| B1-01 digest/metadata | Full envelope hashed; deep freeze; literal vectors; original canonical string to RPC | Partially addressed; input-only/legacy metadata, budget semantics and byte contract still need corrections |
| B1-02 permissive decoder | Validator before parser; explicit {} rejection; separate v1/legacy paths | Partially addressed; nested required fields, null/zero version, shape boundaries and metadata eligibility not fully defined |
| B1-03 dependencies/platform | Exact pins; Android24/36; host smoke; iOS NOT RUN | Addressed in plan, resolver/host/native execution NOT RUN; hook failure reporting needs correction |
| B1-04 flags/serializer | Derived fallback retained; single paretoOptimal writer; legacy reader; UI wiring deferred | Addressed in plan; regression behavior still must be tested after implementation |

## Problems — remaining actionable findings

### R2-01 [P1] Non-null destinationName blocks valid input-only drafts; legacy metadata cannot be reconstructed losslessly

Current PlanTripRequest has origin/days/people/budget/preferences/priority, no destination. Revised plan allows plan=null but requires nonempty destinationName. A Guest saving inputs before planning cannot satisfy the contract without inventing a destination or failing save. Bare legacy plan JSON has no title/startDate header, but metadata.title is also required. Saved row wrapper contains actual header data outside plan.

Technical amendment, no new Owner business choice: metadata.title/destinationId/destinationName may be null in the storage/read envelope when unknown. Non-null text must be nonblank. New user-named drafts require a title at save-use-case validation; cloud import requires complete valid plan and resolved destination, not merely any decoded envelope. At least request or plan must be valid; both null reject. Readable legacy plan does not automatically mean eligible for cloud import.

Legacy row adapter preserves known title/destination and header fields through explicit row context; bare plan adapter keeps unavailable metadata null, no fabricated dates/title/destination. Prefer a documented decodeLegacyPlan(raw, metadata/context) entry point over guessing row fields from plan. Preserve legacy start/end instants in snapshot header; do not drop known headers or silently convert to travel-date strings. Legacy compatibility cannot mean every arbitrary unversioned object accepted.

### R2-02 [P1] Proposed SQL does not express UTF-8 byte hashing and names an unsupported parser

Plan proposes `sha256(canonical_json_string::bytea)` and `jsonb_parse(canonical_json_string)`. Text-to-bytea cast is not the explicit text-encoding operation; bytea input interprets escape syntax, which matters for JSON backslashes/newlines. PostgreSQL provides `convert_to(text, 'UTF8')` for encoding text; `jsonb_parse` is not a built-in shown in the referenced docs and no custom definition exists in this packet.

Correct intended B3 protocol:

```sql
encode(sha256(convert_to(canonical_json_string, 'UTF8')), 'hex')
-- Parse exactly the same text after hash comparison:
canonical_json_string::jsonb
```

These expressions are design corrections, NOT RUN against Supabase. B3 must verify deployed PostgreSQL support and actual shared vectors. Validate original string size/JSON/closed shape/allowed types before persisting; derive all content projections from this parsed content, never unhashed parallel fields. Authoritative owner comes from verified auth, not the hashed payload. Idempotency identity is owner/draft/revision/request key; digest detects changed content, it does not alone distinguish new trip from retry.

Remove claim that digest mismatch risk is completely eliminated. Transport escaping and text encoding require tests including Unicode, literal backslash, escaped newline and quotes. Canonical duplicate-key/malformed text policy must be explicit in B3; jsonb parsing alone silently loses duplicate keys.

Primary docs: [text/binary conversion and SHA functions](https://www.postgresql.org/docs/current/functions-binarystring.html), [bytea representations](https://www.postgresql.org/docs/current/datatype-binary.html), [JSON types/casts](https://www.postgresql.org/docs/current/datatype-json.html). Docs are not evidence for the live project's version/functions.

### R2-03 [P2] Regex checks date shape, not real calendar validity; nested strictness remains underspecified

Independent read-only host probe: `2026-02-30` matches proposed regex, strict calendar parse rejects it. Dart date constructors can normalize overflowing dates, so check parsed year/month/day equals original components. Validate both endpoints, range and leap years; do not infer absent dates or timezone. Missing/unknown timezone may remain null; no new timezone dependency needed in B1.

Strict codec contract must enumerate required fields/types before invoking permissive fromJson: schemaVersion must be int1; explicit null/0/negative/string/1.0 reject, future positive int unsupported; absent key alone is legacy. Reject missing envelope keys, wrong nested types, both-null request/plan and malformed recognizable legacy plan. Close envelope/metadata unknown fields; nested supported DTO keys/compatibility fields must be documented so no silently discarded content is hashed one way and decoded another. Test partial request (which current parser otherwise fills with preset values) and partial plan separately.

Full snapshot/import eligibility and draft readability are separate validations. Do not require every valid draft to have complete itinerary, and do not turn a partial legacy response into complete saved data. No global parser-default changes needed for this packet.

### R2-04 [P2] Canonical ordering/normalization wording remains contradictory, and allocated cost is not requested budget

UTF-16 code-unit ordering (`codeUnitAt`) is not UTF-8 byte ordering or Unicode code-point ordering. Independent probe U+E000 vs U+1F600: UTF16 first units57344/55357, UTF8 first bytes238/240; order reverses. Choose UTF-16 ordinal ordering explicitly for the client codec and do not label it byte order.

Preserve original valid Unicode code-point sequence, no implicit NFC normalization in B1. Composed/decomposed Vietnamese forms can remain different content bytes/digests. Reject unpaired surrogates and U+0000 rather than silently replace characters before Postgres persistence. Specify finite-double emission (including exponent rules), -0.0 normalization, nullable-key presence and string escaping; golden vectors include non-BMP keys, escapes, Vietnamese, composed/decomposed strings, large/small finite doubles. These are a local versioned protocol, not a claim to implement RFC8785/JCS.

metadata.budgetVnd currently falls back from request budget to plan.totalAllocated. Source BudgetBreakdown has separate remainingSafetyMargin; allocation and requested budget are different meanings. Example budget4m, allocation3m, margin1m: storing allocation as requested budget changes input when reopening. Request.numDays and plan length likewise require explicit consistency handling.

Minimal amendment: remove duplicate budgetVnd/numDays from canonical metadata for B1; preserve them in request, allocations in plan, and legacy SavedTrip header in the account snapshot context. Existing master plan metadata did not require these extra projections. Future RPC derives necessary display projections from documented sources and validates mismatches; no recompute DE. If Antigravity keeps these fields instead, it must define one meaning/nullability/source and consistency rules without substituting allocated cost for input budget or truncating fractional legacy totals.

### R2-05 [P2] FFI hook error can prevent tests from starting; avoid global test factory mutation

Host smoke is an appropriate scoped check. Use `databaseFactoryFfi.openDatabase(...)` directly instead of assigning global databaseFactory, or restore global state reliably. Temp-directory creation/cleanup stays within test-owned temp scope; close handles in finally.

Build hooks may fail before any test group starts, so claim that group9 always catches hooks and groups1–8 are unaffected is inaccurate. Report failure phase truthfully; don't skip smoke or auto-add overrides/packages/toolchain upgrades to make PASS. FFI host smoke PASS never implies mobile plugin/storage schema/DB RPC PASS. [FFI docs](https://pub.dev/packages/sqflite_common_ffi/versions/2.4.3).

## Testing

- Git/source inspection: main4525c4a, no tracked implementation changes at inspection.
- Host date counterexample: regex=true, valid calendar=false for2026-02-30; command exit0.
- Host ordering counterexample: UTF16 vs UTF8 ordering differs for U+E000/U+1F600; command exit0.
- Primary docs checked for conversion/hash/JSON and FFI build hooks. No SQL execution or runtime compatibility proof.
- flutter analyze/test, pub get/resolver, FFI smoke, Android/iOS build, Supabase shared vectors and Batch B behavior: NOT RUN. Earlier baseline tests remain historical/author-reported as previously recorded.

Minimum new cases beyond prior plan: input-only unknown destination; bare legacy without title; known saved-row headers preserved; both null; request/plan nested missing fields; explicit version null/0/1.0; impossible/leap-year dates; Unicode/code-unit ordering and escaped-byte digest; requested budget vs allocated cost; frozen input lists/maps; Pareto false/legacy precedence and fallback dataSources; FFI close/reopen and failure phase reporting. No test count claims before implementation.

## Next action

Keep revised plan's accepted changes and apply ONLY this targeted delta to contract/tests. Do not re-interview Owner or rewrite the whole plan. B1 implementation remains not authorized by this review. Owner may review/approve the corrected packet; Antigravity implements; Codex reviews actual diff/evidence. No automatic database apply/merge. No new architecture/features/native platform upgrades.

## Lesson Candidate

Problem → input draft cannot be saved. Root cause → completed-trip requirements were applied to unknown metadata. Rule → distinguish readable draft from complete importable trip.

Problem → both sides use SHA256 but can hash different bytes. Root cause → implicit encoding/casts and incomplete canonical protocol. Rule → specify original bytes, explicit UTF8 conversion and independent cross-runtime vectors; never mark proposed protocol as proven.
