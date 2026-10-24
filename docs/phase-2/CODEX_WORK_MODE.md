# TravelGO — Owner-authorized Codex work mode

Recorded 2026-10-11, Asia/Saigon. Owner requests this mode until explicitly returning to Codex + Antigravity collaboration. This document records task authorization/preferences; it does not amend permanent rules.

## Effective boundary

**Owner reaffirmed 2026-10-11 — applies to upcoming packets until explicitly revoked:** Codex-only uses superpowers for analysis and planning, then explicitly turns superpowers OFF before implementation, fixes and verification. Owner specifically activated this workflow for B3. Preserve this instruction during session handover; do not silently narrow it to B2 or ask for the same mode again. It does not authorize implementation of a new packet, database apply, merge, agents or changes to permanent rules.

Antigravity finishes the existing B2 repair packet first. Codex does not concurrently change the shared implementation. Once completion/handover is available in this chat, Codex verifies actual files, HEAD, status and evidence before taking over. Do not infer completion from elapsed time or earlier test results.

Codex then owns analysis, planning, implementation repairs and verification within the approved B2 contract and three-file allowlist. Owner has authorized those repairs; do not repeatedly ask for permission for necessary in-scope fixes. New packets/features, contract changes, dependencies/native configuration, database apply and merge remain subject to their existing approval boundaries.

## Workflow

- [ ] Receive Antigravity's completed handover and establish one active workspace writer.
- [ ] Inspect actual changes and rerun the relevant red controls; mark each existing F1–F4 finding resolved or open using current evidence. Preserve correct changes.
- [ ] Use superpowers for root-cause analysis and the concrete repair plan only: systematic-debugging and writing-plans, with brainstorming only if a real design decision needs clarification. Read relevant skill instructions and announce use.
- [ ] Record the remaining fixes, exact files, behavioral tests and completion criteria in docs/phase-2 or the task artifact directory. Never write to Owner-protected docs/superpowers/.
- [ ] Explicitly end superpowers use before code repair. Implement, test and verify through ordinary tools/workflow; do not invoke implementation, execution, test or completion superpowers skills in this phase. Owner's instruction overrides skill directions to invoke further skills or agents.
- [ ] Repair remaining B2 defects and missing required controls, preserving Direction A, schema/CAS/session invariants and original allowlist. Reproduce each defect before changing it, then verify repaired behavior.
- [ ] Run analyzer, targeted B2 real SQLite FFI tests, codec regression and full suite; inspect exits and actual coverage. Report PASS/FAIL/NOT RUN accurately.
- [ ] Hand back the result, open risks and evidence in Changed / Why / Testing / Problems / Lesson Candidate form. Owner retains merge authority.

## Fixed boundaries

No subagents, Docker, reset/clean, main push/merge, automatic database apply, backend changes or access to the six Owner-protected items. Retain budget limits: 25 tool calls per task, 5 changed files per task, 3 repair rounds. If a packet exceeds a limit, preserve a concrete checkpoint rather than silently bypass it. Usage reset availability does not change scope or safety limits.

## Current starting point

B2_IMPLEMENTATION_REVIEW.md defines F1–F4. Before Antigravity's current repair, analyzer and existing 235-test suite passed while four additional contract probes failed. Those are historical results, not evidence for the next handover. B6 auth/startup and server idempotency obligations remain outside B2; B2 repairs do not start B3–B6 automatically.

This mode starts after the existing Antigravity repair completes and persists until Owner says to return to Codex + Antigravity. There is no background monitor or scheduled takeover created by this document.

## Owner planning preference and B3 checkpoint — 2026-10-11

When a requirement is unclear during future packet planning, ask Owner in easy Vietnamese with a concrete user situation, a recommendation and short choices. Inspect source first for facts that need no product decision. Do not silently guess unresolved behavior or re-ask already approved choices. This records Owner preference without modifying permanent rules.

B2 PR #20 merged at main `8213e4aa0b0307fbf63ceb73816cf95f193511fa`; main CI SUCCESS. B3 inspection/plan authorized, implementation/database mutation not authorized. Owner confirmed importing input-only Guest drafts without rerunning Decision Engine, preserving exact JSON text in a companion trip column for retry, and retaining calendar dates in JSON with legacy timestamptz columns NULL on new imports. B2's current complete-plan account snapshot/ack contract needs a separate client compatibility packet before enabling that extension. B3 R2 uses brainstorming + writing-plans; live catalogue-only SELECT completed on primary at 2026-10-11T05:36:05.23418Z, recorded in B3_LIVE_SCHEMA_EVIDENCE.md. R2 spec/plan is ready for Owner review; proposed byte-preserving wire policy, explicit limits and own-import snapshot read RPC still need final design/code approval. PostgreSQL behavior tests/apply NOT RUN. See B3_IMPLEMENTATION_PLAN.md; design and metadata evidence are not implementation/runtime PASS.
