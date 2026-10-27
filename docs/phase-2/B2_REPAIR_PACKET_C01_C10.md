# B2 Direction A Repair Packet — Documentation Handover

Date: 2026-10-10. Author of this delta: Codex, at Owner's direct request to amend the plan. This is a self-check/handover for review, not an independent reviewer approval or code authorization.

## Checkpoint and changed scope

Workspace main @`0cbebee70b1d2203349beaad8e040c19eaf21671`, tracked clean. At inspection the plan was already R5 / Direction A Converged, input SHA-256 `32A41FEE53CE4E060912DDF5508FF87E532BB4D66A5DD4D4D040AE808ED24AA2`; therefore the repair used that actual file, not an assumed R4 version. Owner approval of direction A is recorded in B2_CONVERGENCE_PROPOSAL.md:7.

Updated B2_IMPLEMENTATION_PLAN.md to **Revision R5.1 / Direction A Delta**, SHA-256 `A19BA2FB6D5CACEB63F3C4683E151136573378D50F58FFB7B521C05B7016A64B`. The line references below bind to that exact hash. Preserve the three-file implementation allowlist; none of those files exists yet. No code, driver/dependency/native edits, application DB/Supabase apply, backend changes, checkout operations or Owner protected content access. Prior review documents are historical and unchanged.

## C01–C10 traceability table

Status **RESOLVED IN PLAN / SELF-CHECK** means the contract is present and the visible contradictions have been addressed in this delta. It does not mean tests PASS or independent review completed.

| ID | Plan section and verified line | Concrete delta / retained invariant | Status |
| --- | --- | --- | --- |
| C01 | §1.2, B2_IMPLEMENTATION_PLAN.md:21 | B2 DB readiness separate from auth; trusted B6 binding; no active registry. B6/B9 retain AC-016/offline restart and failed-logout startup proof before feature wiring. | RESOLVED IN PLAN / SELF-CHECK; integration NOT RUN |
| C02 | §4.1, B2_IMPLEMENTATION_PLAN.md:366 | Neutral queue; readiness set only after recovery; failed retained connection requires close retry. Activation reserves unique generation synchronously, checks it after awaited marker read; close/unbind cancel pending handles. | RESOLVED IN PLAN / SELF-CHECK |
| C03 | §6.1–6.2, B2_IMPLEMENTATION_PLAN.md:684 | All account APIs use scoped guarded wrapper; transaction returns T directly, generation rechecked after marker/action awaits and before publication; blocked owners refused. | RESOLVED IN PLAN / SELF-CHECK |
| C04 | §8, B2_IMPLEMENTATION_PLAN.md:1042 | Process-local block installed before queue; marker/purge/completion separate transactions; startup recovery before readiness; completion failure never unlocks; Step 2 failure is not called durable success. | RESOLVED IN PLAN / SELF-CHECK; cross-process auth proof belongs B6 |
| C05 | §3.2, B2_IMPLEMENTATION_PLAN.md:201; §7.2, line 945 | Strict parser and one equality helper for all ten stored/incoming fields, used before committed no-op. | RESOLVED IN PLAN / SELF-CHECK |
| C06 | §7.2, B2_IMPLEMENTATION_PLAN.md:904 | Common payload/journal/receipt digest; first ack extends with checked source; committed retry uses stored receipt identity and returns validated current snapshot, without requiring deleted source or stale snapshot digest. | RESOLVED IN PLAN / SELF-CHECK |
| C07 | §5, B2_IMPLEMENTATION_PLAN.md:558 | Raw UTF-8 hash/schema/canonical verification retained; public mapper wrappers map SQL type/date errors; account plan completeness required; all existing/no-op paths use checked mapper. | RESOLVED IN PLAN / SELF-CHECK |
| C08 | §2, B2_IMPLEMENTATION_PLAN.md:48; §6.3, line 741; §7.2, line 904 | Existing FK/hex/index preserved; save INSERT-first, delete/consume pointer-first, immutable revisions/private mutations, tombstone monotonicity, no journal REPLACE, stable retries and owner-scoped reconcile rules explicit. | RESOLVED IN PLAN / SELF-CHECK |
| C09 | §7.1, B2_IMPLEMENTATION_PLAN.md:756 | Authoritative known-version CAS retained; legacy UTC capture ordering defined, not arrival; same-content touch max; placeholder projections not selection or payload mutation. | RESOLVED IN PLAN / SELF-CHECK |
| C10 | §9.1–9.3, B2_IMPLEMENTATION_PLAN.md:1090; §10, line 1159 | Exact resolved test-owned temp target/runtime rejection; independent cleanup; added stored receipt mutations, activation barriers, recovery/rollback/file reopen negatives; analyze/targeted/codec/full SOP retained. | RESOLVED IN PLAN / SELF-CHECK; execution NOT RUN |

## Testing and practical explanation

Actual HEAD and tracked diff were checked before/after. All 3 proposed B2 source/test paths are absent. Reviewed updated generation checks, wrapper return path and section anchors; final hash recorded above. Markdown/source-contract checks are document checks only. Because the plan is untracked, `git diff --stat`/`git diff --check` alone cannot certify its content; the hash, explicit inspected sections and traceability table are the evidence for this artifact.

Scenario: activation of A waits on disk; logout calls unbind immediately. The pending request now holds its own generation, which no longer matches after the disk read, so it cannot restore A into RAM. A failed purge marker also installs an in-process owner block that remains through close/reopen of the same store until purge succeeds. B6 must separately prove the cross-process auth recovery contract; this packet does not claim that integration solved.

`flutter analyze`, B2 targeted SQLite FFI tests, codec/full regressions, native Android/iOS, auth startup/AC-016, RPC and E2E: **NOT RUN**. No new runtime/SQL probe in this documentation packet. Tests are specified behaviors for future implementation, not already executed evidence.

## Handover / next action

- **Changed:** B2_IMPLEMENTATION_PLAN.md R5.1 delta plus this traceability document. Preserved existing schema/parser/equality/payload/CAS sections; repaired lifecycle/wrapper contracts and filled transaction/test boundaries.
- **Why:** Prevent activation resurrection, failed recovery readiness and uninitialized result sketches; keep B2/B6 responsibilities and review criteria stable.
- **Testing:** Exact checkpoint/hash/line mappings and absence of implementation verified; runtime checks NOT RUN.
- **Problems:** Independent pre-code review against C01–C10 remains pending; only Owner can approve code after review. B6/B9 still owe integration evidence; do not call it B2 PASS.
- **Lesson Candidate:** Reserve cancellation generation before an async request waits, then check after await; publish readiness only after recovery actually succeeds.

Next reviewer: inspect this exact R5.1 hash against the approved convergence contract and table, retaining previously accepted invariants. Report concrete blockers/regressions; do not reopen 1A–5A or introduce style-based approval gates. This handover does not grant Antigravity implementation permission and does not authorize apply/merge.
