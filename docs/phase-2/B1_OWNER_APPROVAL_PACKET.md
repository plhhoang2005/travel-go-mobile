# B1 implementation packet — Owner approved, implementation pending

2026-10-10. Codex reviewed final delta from attachment `fb358172-00a6-418b-bfa7-087a8164a319/Pasted text.txt` together with revised plan and R2. This document is the consolidated Owner-approved implementation instruction for B1; its binding details supersede ambiguous wording in pasted plans. Explicit approval is recorded below; approval is not implementation/test evidence. No superpowers invoked this turn; permission from R2 is task-specific. No subagents.

## Owner implementation approval — CONFIRMED 2026-10-10

Owner explicitly approved in chat: **“Đồng ý triển khai B1 theo B1_OWNER_APPROVAL_PACKET.md”**.

Authorization: Antigravity implements this exact five-file B1 packet, adds its five pinned dependencies, runs flutter pub get and the specified verification, using a feature branch from the verified base. Codex remains reviewer. Do not ask again for package installation already authorized within this packet. Additional dependencies/native configuration/platform upgrades/files require an amendment if needed. Approval does not include B2–B9, database apply, backend changes, main push or merge. No superpowers authorization for this implementation task; R2 permission was limited to that review.

Pre-dispatch checkpoint recorded by Codex: main @4525c4a08360e2666274ff6fdc6aadf48e600713, tracked unchanged; Owner protected entries and planning reports untracked. Antigravity must recheck actual state immediately before acting; one writer at a time. This approval record is documentation only, not evidence B1 has been implemented or tests passed.

## Changed / review verdict

Codex only writes this packet and updates the R2 report with current status. Main HEAD `4525c4a08360e2666274ff6fdc6aadf48e600713`; tracked implementation unchanged at inspect. Owner 1A–5A stays confirmed. Six protected entries remain untouched. Final delta addresses input-only metadata, requested-vs-allocated budget, explicit UTF8 hashing, real calendar validation, FFI factory isolation and failure reporting.

No further broad plan rewrite or Owner A/B interview is required. B1 implementation is Owner-approved **using this corrected packet**, not the attachment alone. All runtime PASS claims await implementation and evidence.

## Exact scope / dependencies

Implementation allowlist exactly five files:

1. pubspec.yaml
2. pubspec.lock
3. lib/features/trip_planner/models/trip_response.dart
4. lib/features/trips/models/trip_payload_codec.dart NEW
5. test/trip_payload_codec_test.dart NEW

Runtime exact pins: sqflite2.4.4+1, crypto3.0.7, uuid4.6.0, path1.9.1. Dev exact pin: sqflite_common_ffi2.4.3. crypto used in B1; uuid/path prepare B2. Existing-lock evidence is not new resolver PASS. No upgrade-all, overrides, new sqlite3 direct dependency, platform bump or native config changes without amended scope. Auth/Provider/DE/UI wiring remain unchanged. Branch from approved actual main; never commit/push main. Codex reviews; Antigravity implements.

## Why / binding contract

### 1. Content envelope and strict validation

Envelope keys exactly schemaVersion(int1), metadata(object), request(object|null), plan(object|null). At least one content object valid. Metadata keys exactly title, destinationId, destinationName, startDate, endDate, timezone; nullable string values explicitly emitted. Non-null title/destination strings must be nonblank. No duplicated budgetVnd/numDays in metadata; request retains original budget/days; plan retains allocation/itinerary without recalculating DE. Unknown content fields reject rather than silently drop. Allowed DTO compatibility/derived keys must be explicit in validator and covered in tests.

Validate ALL supported required request/plan nested fields and types before permissive existing fromJson methods. Missing required fields cannot become presets/empty structures via defaults. Preserve optional nulls such as budgetBreakdown/coordinates. schemaVersion explicit null/0/negative/string/1.0 invalid; positive future integer unsupported; only absent key invokes legacy handling. Closed valid request-only draft need not have destination. Both null reject. Keep global API parser compatibility unchanged.

Calendar dates are real YYYY-MM-DD values with component roundtrip validation and supported four-digit year range1..9999. Validate each present endpoint; compare range only if both present. Do not infer missing dates/timezone. B1 stores timezone as optional nonblank metadata when supplied by known app context, not a claim that arbitrary string is a verified IANA identifier; do not add timezone runtime or use this field for calculations in B1.

Draft readability != cloud import eligibility. New user-named draft title requirement belongs to save-use-case validation at B5, not bare legacy decoder. B4/server must later require title, full usable plan, resolved destination consistent with winner/selected IDs and names, allowed content, current true authenticated owner/epoch and receipt bindings. Plan !=null/name !=null alone is not complete authorization/validation. No network/import implementation in B1.

### 2. Legacy context is separate from travel-date metadata

decodeBareLegacyPlan accepts recognizable legacy plan only, returns request=null and unknown header metadata=null. Preserve winnerId/plan fields; don't invent missing headers.

decodeLegacyRow chooses ai_plan_data first then trip_plan_data only when primary null/absent, validates recognizable payload and preserves known row headers. Return a typed local adapter result in the SAME codec file containing payload plus immutable legacyHeader/context; do not put raw timestamptz into metadata.startDate/endDate (which require date-only). Legacy context holds original id/user_id/title/destination_name/num_days/budget_total/status/start_date/end_date/created_at values when supplied, including timestamps as original strings and numeric legacy totals without truncation. Header is not authenticated authority, and is not part of new canonical import content or digest. Later snapshot owner/session validation remains B6.

No automatic backfill, silent timestamp truncation or mutation of original legacy row. This separate result/context avoids an impossible test requiring both date-only validation and original timestamptz inside the same metadata field. Missing dates remain null; known raw header times remain preserved outside metadata. Both legacy entry points require shape checks, not just permissive fromJson.

### 3. Exact canonical protocol

Use recursive string-key ordering by Dart String.compareTo (UTF16 code-unit ordinal), list order unchanged. Preserve original Unicode, no NFC normalization. Reject U+0000/unpaired surrogates and nonfinite numbers, unsupported value types/nonstring map keys. Metadata null keys retained; no whitespace outside string content.

Replace vague 'no strange exponent' with this rule: after typed validation, integers encoded as Dart jsonEncode integer tokens; finite doubles normalized only for -0.0→0.0 then encoded with Dart dart:convert jsonEncode scalar number representation, including exponent output when encoder produces it. Do not toInt/round/change double into int;1 and1.0 remain distinct token types. String escaping uses the same Dart JSON encoder. This is a versioned Dart protocol with literal golden vectors, not RFC8785/JCS or independent cross-language reserialization. SDK changes must retain frozen vector bytes or use an explicit payload protocol upgrade; not silently rewrite pending frozen content.

SHA256 covers UTF8 bytes of the entire frozen canonical content envelope. Context owner/session/fetchedAt/retryCount/draftId/revision stays outside. Encoded canonical bytes are what future journal freezes/retries. Deep-copy all mutable DTO collections at payload construction/freeze, not merely when encoding. Tests mutate nested original lists/maps BEFORE first encode and between repeated encode/digest calls; frozen payload must stay unchanged. Testing that an already-created immutable String doesn't change is insufficient.

Golden test vectors include full field/null roundtrip, metadata changes, array order, shuffled nested map keys, Vietnamese composed/decomposed and non-BMP keys, escapes/backslash/newline/quotes, int/double/negativezero/exponents, rejection cases, derived fallback/Paretofalse precedence, immutable freeze and legacy context. Literal expected canonical text and expected hex hashes must not be generated by the function under test. Context-independence test constructs same content with different external contexts, not unknown context keys accepted inside closed envelope.

### 4. Future B3 boundary, not B1 SQL implementation

Server expression design: encode(sha256(convert_to(canonical_json_string,'UTF8')),'hex'); parse SAME string with ::jsonb, validate and derive projections only from hashed content. Shared Dart/PostgreSQL vectors NOT RUN. Receipt key must retain UNIQUE(owner_id,draft_id,source_revision), plus owner-scoped request_key uniqueness/binding; do NOT replace this with only UNIQUE(owner,draft,revision,request_key), which permits another request key to create another trip for the same revision. Digest is a content conflict check, not new/retry identity on its own. Atomic trip+receipt and remote owner derive from auth remain approved architecture. No SQL/database mutation in B1.

### 5. FFI smoke and verification

Use databaseFactoryFfi directly. Temp test DB: open/create/write canonical/read/close/reopen/read/close; handles and temp cleanup in finally, scoped to test-owned resolved temp directory. Cleanup errors must not hide original failures. Toolchain/build-hook failure before tests starts is reported as such, not test assertion failure or group1–8 PASS. No skipping smoke or dependency overrides to claim success.

After Owner approves implementation: flutter pub get and review complete lock delta; flutter analyze; targeted trip_payload_codec_test; full flutter test. Preserve existing assertions; record exact head/exits/results. Baseline158 is historical, actual test count reported after run. Host smoke does not prove Android/iOS/storage schema/RPC. Android defaults24/36 and iOS15 are source facts, native build still NOT RUN until respective packets.

## Testing — this review

Read final delta, R2 and current source; verified main4525c4a and no tracked code changes. Consulted primary Dart docs for String.compareTo code-unit ordering and jsonEncode API. No implementation generated, no analyzer/test/resolver/FFI/native/database execution. Earlier R2 date/key-order probes stay historical, not rerun or applied to nonexistent codec.

Sources: https://api.dart.dev/dart-core/String/compareTo.html and https://api.dart.dev/dart-convert/jsonEncode.html. These document API behavior, not a claim runtime golden vectors already PASS.

## Problems / Owner action

Owner has approved B1 implementation with this five-file packet and its exact pins/contract, as recorded above. Antigravity proceeds within this scope; Codex reviews actual diff/evidence. SQL apply/merge/UI/local repository implementation are outside B1 authorization. Actual codec/package compatibility evidence remains NOT RUN until implementation checks complete. Reviewed/approved design != implemented or tested feature. Antigravity's attachment starts 'Viewed SKILL.md' without its path; no inference is made about which skill it read or its authorization, and this does not authorize superpowers in a later task.

## Lesson Candidate

Problem → legacy timestamps break strict travel-date validation. Root cause → historical row context and new itinerary metadata mixed together. Rule → preserve legacy values separately and normalize only under an explicit migration contract.

Problem → changing request key could bypass retry protection. Root cause → adding transport request key into the only source uniqueness constraint. Rule → keep business identity unique independently of per-request identity.
