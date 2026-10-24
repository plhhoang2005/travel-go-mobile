# B1 implementation review R3 — NEEDS FIX (two small P2 gaps)

2026-10-10. Codex reviewed Antigravity's repair handoff in attachment 331e00f1-9555-4a7e-8c01-ede9dc7c7c9f/Pasted text.txt. This is the current review status; R2 remains historical. No application source edited by Codex.

## Checkpoint

Branch feat/phase-2-batch-b1; HEAD 4525c4a08360e2666274ff6fdc6aadf48e600713. B1 implementation is still uncommitted. Four implementation file hashes match R2; only the test file changed. Current test SHA-256: 2E10F657F29F3954AB018743369C820D59DC85A20697A38BE7C54C575B7B02C9. The four unchanged hashes are recorded in R2. Final status shows macOS registrant clean and the same five implementation files changed/untracked. Planning documents and protected Owner files are separate existing untracked entries; the entire working tree is not clean.

No database apply, backend change, implementation edits, main push/merge, subagents or superpowers performed by Codex.

## Findings closed or partially resolved

- Freeze acceptance gap: CLOSED. At test/trip_payload_codec_test.dart:1332 the payload is compared with independent expected original content BEFORE its first encoding. All original source collections, including days, are mutated; repeated encoding and unmodifiable-collection assertions remain. This catches a copy delayed until encoding.
- Full-plan literal vector: substantially resolved. Vector 3 includes the complete plan, competing nested BMP/non-BMP keys, integer/double fields, array order and negative-zero normalization. Independent .NET SHA-256 over the literal UTF-8 bytes matches 44724205456e949bd5f5f91cf7dc69257634f7e6ac0a8efc282cf22f5ba67c63. The exponent case remains missing below.
- SQLite cleanup: substantially resolved. Both close and directory cleanup are attempted; the primary error retains its stack; a cleanup-only failure throws. Concurrent primary and cleanup failures still lose the cleanup diagnostic below.
- Earlier P1 application rejection probes remain closed from R2. Production codec/DTO hashes are unchanged; those eight probes were not rerun this turn.

## Remaining P2 findings

### 1. Literal vector still omits exponent formatting

test/trip_payload_codec_test.dart:1512–1596 adds a complete literal plan vector, but all finite doubles use ordinary decimal values. There is no exponent input/expected token in the file. R2 explicitly requested exponent cases, and the approved canonical protocol freezes Dart jsonEncode number representation, including exponent output.

Repair within this test file: retain the existing vectors and add an independently checked literal vector or extend the new vector to include a supported finite double such as a tiny score producing exponent output. Assert the exact expected canonical text and independently checked SHA-256. Confirm the actual Dart formatting rather than guessing exponent spelling. This is an existing acceptance requirement, not a new dependency or codec change.

### 2. Cleanup diagnostic is discarded when the main operation also fails

At test/trip_payload_codec_test.dart:1705, primaryError is thrown before the cleanupError branch at line 1709. If both are set, the cleanup error and its stack are never reported. Also, cleanupError ??= retains only the first of a close and delete failure. Thus the main error is correctly preserved, but the handoff's claim of zero swallowed errors is broader than the code supports.

Repair within this test file: when a primary error exists, explicitly report each cleanup error/stack as secondary diagnostic information before rethrowing the original error with its original stack. When no primary error exists, cleanup failure must still fail the test. Do not let diagnostic reporting replace the primary failure. Attempt close and delete independently. Do not broaden cleanup beyond the test-owned temp directory. No change to production code is requested.

This is a test failure-reporting defect identified from control flow, not a reproduced production persistence failure. Concurrent-error branches were not fault-injected in this review.

## Actual reviewer evidence

Executed outside the sandbox, where the SDK worked in R2:

- flutter analyze --no-pub: PASS, exit 0, No issues found, 4.9s.
- flutter test --no-pub --reporter expanded test/trip_payload_codec_test.dart: PASS, exit 0, 35 tests, including freeze, all three literal vectors and real SQLite FFI smoke.
- flutter test --no-pub --reporter expanded: PASS, exit 0, 193 tests, 20s. Full output saved at C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/B1_R3_FULL_TEST.log.
- Independent .NET SHA-256 of Vector 3 literal UTF-8: PASS, matches expected hash.
- git diff --check: PASS for tracked diff. New untracked codec/test files were inspected separately; this command does not cover them.
- Android/iOS persistence and server shared-vector/receipt integration: NOT RUN, outside this review. No Supabase apply.

PASS establishes the executed assertions; it does not establish exponent formatting coverage or concurrent cleanup-error reporting.

## Next repair packet

Antigravity: only modify test/trip_payload_codec_test.dart under existing B1 approval. Finish the two P2 points above: exponent bytes/hash fixture and reporting secondary cleanup failures while preserving the primary error/stack. Keep all original assertions and vectors. No codec refactor, new dependency, native/platform change, B2–B5 work, backend change or database apply. Run analyze, targeted codec/FFI and full suite; hand over actual outputs, final hashes/status and a reviewable identity. Respect task budgets and checkpoint if exhausted. Owner retains merge authority.

## Handover / explanation for Owner

- Changed: Codex added this review document and saved full-suite output; Antigravity's repair changes only the test file, verified by hashes.
- Why: a saved Guest draft now has a test proving the original itinerary is preserved immediately. Fixed bytes/hash protect the same content across retries; exponent-format bytes still need a fixed example. A failing smoke test should show both the operation error and any cleanup problem, so diagnosis does not miss the reason a temp database remains.
- Testing: reviewer analyze PASS, targeted 35 PASS, full 193 PASS, independent vector-3 hash PASS. Native/server and concurrent cleanup failure injection NOT RUN.
- Problems: two narrow P2 acceptance gaps remain; no new reproduced P1. No implementation commit or PR reviewed yet. B1 is NEEDS FIX until the existing requirements are complete.
- Lesson Candidate: a fixed protocol example omits a numeric representation branch → compatible-looking serializers can drift → lock exponent bytes with a literal independent hash. Primary error is preserved but secondary errors disappear → early rethrow skips diagnostics → report secondary cleanup errors before rethrowing the primary error with its stack.
