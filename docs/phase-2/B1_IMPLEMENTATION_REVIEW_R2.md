# B1 implementation review R2 — NEEDS FIX (P2 acceptance gaps)

2026-10-10. Codex reviews Antigravity's repair handoff from attachment 23bf1a97-1f7c-407f-964c-e912a2faba19/Pasted text.txt. This report supersedes the current-status conclusions of B1_IMPLEMENTATION_REVIEW.md; that report remains historical evidence. No application source edited by Codex.

## Identity and scope

- Branch: feat/phase-2-batch-b1.
- HEAD: 4525c4a08360e2666274ff6fdc6aadf48e600713; implementation remains uncommitted. Review binds to working-file hashes below, not an implementation commit.
- Implementation diff remains the approved five files. macos/Flutter/GeneratedPluginRegistrant.swift is clean after the review commands; Codex did not restore it.
- No database apply, backend change, UI/repository/RPC implementation, main push/merge, protected Owner file access, subagents or superpowers.

## Closed findings and verified improvements

The old P1 rejection paths are repaired: unknown request/plan content, non-string preferences, missing nested day fields, fractional integer budget fields and forbidden Unicode now reject in the independent probes. Required metadata keys reject when missing. Constructor validation and recursive DTO field checks are present. API parser defaults have not been globally changed.

Legacy context numDays now remains num and the authored test preserves 3.5 and fractional budget totals. The SQLite smoke now stores actual valid codec output and digest, closes/reopens, decodes and compares. Shuffled input maps now have different insertion orders. BMP/non-BMP keys are actually present in nested scores. These improvements are implemented, not merely proposed.

## Remaining findings

### P2 — Freeze test does not prove preservation before first encoding

test/trip_payload_codec_test.dart:1247–1341 mutates source collections before first encoding, but first records its reference digest AFTER those mutations (line 1324). It only compares two subsequent digests and checks selected collections are unmodifiable. A regression that freezes an already-mutated DTO at the first encoding could pass these assertions. The original days list is not mutated either.

The production deep-copy implementation currently appears correct on inspection. This finding is an acceptance-test gap, not a reproduced production mutation bug.

Repair: before the first encode, after mutating sources, assert the frozen payload retains every original list length/value/map entry and excludes additions. Include the original days list and all source collections; then verify changes between repeated calls cannot alter content. An independently constructed original-content expected payload or literal expected bytes can serve as the reference. Do not derive the reference from the mutated sources or from the first encoding under test.

### P2 — Literal vectors do not freeze the plan/numeric/non-BMP protocol

The BMP/non-BMP test at line 408 checks relative key indexes and self-consistent repeated hashes. Both literal golden vectors at lines 1409 and 1442 have plan=null and integer-only request values. They therefore do not lock the full canonical plan bytes, competing nested Unicode keys, double formatting or exponent representation required by the approved packet and the previous review.

Repair: add a literal full-envelope expected canonical string and independently checked SHA-256 for a valid plan containing competing U+E000/U+1F600 nested keys, finite double values including negative zero and exponent cases, integer fields and preserved array order. Keep the existing two literal vectors. Expected output must not be computed by the production codec. This protects later server verification against both sides of a self-comparison drifting together.

### P2 — SQLite cleanup still hides or replaces failures

test/trip_payload_codec_test.dart:1553–1563 still catches and discards directory deletion errors. Also, await db.close() in finally can throw and replace the original test/write/decode failure and prevent directory cleanup. This conflicts with the already-approved cleanup/error-reporting requirement and the previous review's repair request.

Repair: attempt both close and directory cleanup, preserve the primary failure and stack when one exists, and surface cleanup failures without silently swallowing them. Cleanup-only failure must fail the test. Keep cleanup limited to the directory created by this test. No new dependency or platform change is needed.

## Actual reviewer verification

Sandbox execution initially hung before output. A direct Dart attempt failed before executing probes with resolved_executable_name VM flag errors. These were not assertion failures. Running the authorized checks outside the sandbox worked; no SDK or project toolchain changes were made.

| Check | Result |
| --- | --- |
| flutter analyze --no-pub | PASS, exit 0, No issues found (5.4s) |
| flutter test --no-pub --reporter expanded test/trip_payload_codec_test.dart | PASS, exit 0, 34 tests including real SQLite FFI host smoke |
| flutter test --no-pub --reporter compact | PASS, exit 0, 192 tests (24s) |
| Eight external reviewer rejection/roundtrip probes | PASS, exit 0, 8 tests |
| Independent .NET SHA-256 over manually supplied UTF-8 literal vectors 1 and 2 | PASS, matches both expected hashes |
| Android/iOS native persistence, Supabase receipt/shared vectors | NOT RUN; outside this B1 review |

The eight probes are saved at C:/Users/ASUS/.codex/visualizations/2026/10/10/01a124c1-6365-7d91-8364-080890d7a14e/b1_reviewer_probe_test.dart. The full-suite count does not include these eight external probes. PASS proves the executed assertions; it does not close the missing acceptance assertions above.

## Working-file SHA-256

| Approved file | SHA-256 |
| --- | --- |
| pubspec.yaml | FB420FEC4186C0FB46CD1104C95365197AB0C999C8ABC709C7CD9CF42C826DB6 |
| pubspec.lock | 26C6753A1160A0813F76510763FC18FB5840B0E032A0D64783DB8892FA680E32 |
| lib/features/trip_planner/models/trip_response.dart | 0E532BC9AC1A5076CC2E2EFC1540EB130722560B1665770F62898FC0CFB6392B |
| lib/features/trips/models/trip_payload_codec.dart | 1E042B6BA450F619514BFD8B5D6BC1153962E827810003A1005727997270DE46 |
| test/trip_payload_codec_test.dart | EA53E4D0CC8779A7A0BF048F56B4D13E33150D89354CCDC08CB075D6E4FDF7C2 |

## Next repair packet for Antigravity

Only test/trip_payload_codec_test.dart needs modification for these three findings. Stay inside the existing B1 approval. Add original-content assertions before first encode, one independently verified literal plan/Unicode/numeric vector, and truthful cleanup failure handling. Preserve existing assertions. Run analyze, targeted codec/FFI and the full suite; report actual outputs and final status. Do not refactor codec or API parsers without a newly evidenced defect. Do not implement B2–B5, apply database or merge. Observe the 25-call/five-file/three-fix-loop budget; checkpoint rather than exceeding it. Codex will review the resulting diff.

## Owner explanation and handover

- Changed: Codex added only this review document. Antigravity's five-file implementation was inspected and tested.
- Why: a Guest draft must preserve the exact selected planner content. The old invalid-content normalization paths now reject, but a future freeze regression could still pass the present test if it captures its reference after the damage. Assert the original content before computing its first hash.
- Testing: analyze, 34 codec/FFI tests, 192 full-suite tests and eight independent probes PASS as detailed above. Native and server integration NOT RUN.
- Problems: three P2 acceptance gaps remain. No currently reproduced P1 from the previous probes. No implementation commit or PR HEAD yet. B1 remains NEEDS FIX for the approved acceptance criteria, not ready for merge.
- Lesson Candidate: tests compare two outputs after a possible mutation → their reference can already be wrong → establish an independent original-content reference before the first operation. Cleanup hides a failure → the test reports incomplete success or the wrong cause → retain the primary error and report cleanup errors explicitly.
