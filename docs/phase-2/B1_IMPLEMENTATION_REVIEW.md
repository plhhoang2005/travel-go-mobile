# B1 implementation review — NEEDS FIX

Reviewed 2026-10-10. Role: Codex review; Antigravity implements. Owner approval remains bounded by B1_OWNER_APPROVAL_PACKET.md. No application source, dependency, platform or database changes made by this review.

## Review identity and scope

- Actual branch: feat/phase-2-batch-b1.
- Actual HEAD: 4525c4a08360e2666274ff6fdc6aadf48e600713. Implementation is an uncommitted working-tree diff, not an implementation commit or reviewed PR HEAD.
- The five approved implementation files are present. macos/Flutter/GeneratedPluginRegistrant.swift is also modified: the submitted working tree currently exceeds the five-file allowlist. Resolve generated-file disposition after the final verification commands, or request a specific scope amendment. Codex did not restore it.
- No Supabase apply or backend modification performed. No subagents or superpowers used for this task.

## Findings

### P1 — Storage validation allows normalization and content loss before hashing

In lib/features/trips/models/trip_payload_codec.dart, _validateRequestMap (line 434) and _validatePlanMap (line 445) validate only outer fields. decode then delegates to permissive API DTO parsers. The approved storage contract requires validation of every supported nested field/type and rejection of unknown content before those parsers run.

Concrete paths identified from source: preferences elements can become strings; a day containing only day can receive default title/activities; fractional integer budget fields can be truncated; unknown request/plan fields disappear. Unicode restrictions are enforced by encoding but not comprehensively before decode returns a readable payload. A digest generated after these conversions cannot prove that the original content was preserved.

Fix: validate closed shapes recursively, including list elements, nested DTO maps, score maps, integer money fields and string/key validity. Reject malformed content using the codec exception hierarchy before API parsing. Keep API defaults unchanged. Document the explicit legacy/derived compatibility exceptions; do not broadly permit unknown fields. Add behavioral rejection tests for each path. Validate construction/encoding boundaries as required by the approved contract as well as decoding.

### P2 — Required nullable keys and legacy numeric preservation are incomplete

decode checks unknown envelope/metadata keys but does not require every approved key to be present. An empty metadata map is accepted and re-emitted with null fields. Missing request/plan keys can likewise be treated as null. The contract requires the exact version-1 envelope and six explicitly nullable metadata keys. Metadata casts can also escape as TypeError instead of typed corruption errors.

decodeLegacySupabaseRow line 420 calls toInt on num_days. This loses fractional raw legacy numeric data, contrary to the approved separate legacy-context preservation requirement.

Fix: require exact supported keys for canonical version 1 and validate their types before casts. Preserve legacy numeric context without truncation, keeping compatibility adaptation distinct from canonical validation. Test both valid historical rows and malformed canonical rows.

### P2 — Several tests do not exercise the approved acceptance cases

test/trip_payload_codec_test.dart line 329 creates equivalent inputs without actually shuffling key insertion order. The BMP/non-BMP ordering test at line 371 checks ASCII envelope keys instead of competing BMP/non-BMP nested score keys. The freeze test does not cover all nested collections or mutation before first encoding. The SQLite smoke at lines 889–890 stores a hand-written invalid envelope with both request and plan null, and a placeholder digest, instead of actual codec output.

Fix: use independently shuffled nested maps, a real BMP/non-BMP ordering vector with literal expected bytes/hash, mutate all source collections before first encoding and between repeated calls, and write/reopen/decode a valid production-codec payload plus its actual digest in the FFI smoke. Cleanup must not silently hide a failure or replace the original operation failure. Keep tests independent of implementation helpers where literal expected results are required.

## Testing evidence and limits

- Antigravity reports analyze PASS, targeted 28 PASS and full 186 PASS. These are author-reported results, not independently reproduced in this review.
- Reviewer attempted flutter analyze --no-pub, the full flutter test suite and eight targeted contract probes. The Flutter wrapper produced no output and was cancelled. NOT VERIFIED by Codex.
- Reviewer also attempted direct flutter_tools.snapshot and a pure-Dart version of the probes. Both stopped before executing tests with: Empty value for option resolved_executable_name / Unrecognized flags: resolved_executable_name. Probe behavior is NOT RUN; no runtime failure count is claimed.
- Static inspection supports the findings above. Direct Dart SDK version output succeeded: 3.13.3. This does not establish analyze/test success.
- Android/iOS native smoke, Supabase receipt/idempotency integration and restore rehearsal: NOT RUN in this review. B1 does not authorize database apply or B2–B5 implementation.

External reviewer probes are saved under C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/ as b1_reviewer_probe_test.dart and b1_reviewer_probe_direct.dart. They use synthetic content only.

## Antigravity next action

Repair within the existing B1 approval and five-file implementation scope. First add meaningful failing behavioral tests for the listed contract violations, then correct the codec without weakening assertions or changing permissive API parsing globally. Resolve the SDK execution failure enough to run actual checks. Run analyze, targeted codec/FFI tests and the full suite; supply actual outputs, final status/diff and a fixed reviewable commit identity when available. Do not push/merge main, apply database, wire UI, implement repository/RPC, or alter protected Owner files. A hash is a content checksum; do not describe it as authentication, an unforgeable token, or an implemented server idempotency guarantee.

## Handover

- Changed: added this review document and two external synthetic probes; no implementation files modified by Codex.
- Why: the strict storage boundary must reject invalid or unsupported content before permissive DTO conversion changes it.
- Testing: source inspected; author PASS claims recorded separately; reviewer analyze/full suite/probes not verified for the tool failures above.
- Problems: P1/P2 findings remain open; generated sixth file remains modified; implementation has no commit identity beyond its baseline HEAD. B1 is NEEDS FIX, not approved for merge.
- Lesson Candidate: malformed storage content can be normalized before hashing → permissive API parsers are reused without recursive validation → validate the full closed storage shape before constructing DTOs, and test rejection using concrete malformed inputs.
