# PHONE-03 cold restart repair plan

Goal: restore an existing valid Account on cold restart without weakening offline or in-process authority.
Spec: P3_2_UX_REFRESH_IMPLEMENTATION_PLAN.md T1; latest native failure in P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md.
Execution: Codex-only, no subagents, no new approval gate. Superpowers systematic-debugging/TDD/executing-plans/verification-before-completion; Owner constraints override worktree/commit/reviewer defaults. Preserve the current dirty checkout.

Source finding: startup calls resumeAccount; establishAccount(false) accepts sealed only. A foreground process kill leaves active. The rejected record is purged before any server verifier runs. SDK2.17.2 restores persisted SDK session on initialize; this alone is not local authorization. No SDK API/config/dependency change planned.

Files: this plan; lifecycle service; local lifecycle tests; auth navigation tests; acceptance report (5 total). Use acceptance report as execution ledger; no separate progress file in this repair.

- [x] Watch PHONE03 regressions fail against old source: real temporary SQLite/registry active restart, server-gated AuthProvider publication.
- [x] Add a first-authorization-attempt-only recovery path for active records matching the valid SDK owner/fingerprint/expiry, only when the existing server verifier is available. Await matching server owner before any cache activation. Keep sealed offline path unchanged.
- [x] Refuse server failure/wrong owner/late expiry/late owner/invalidated generation; keep Guest data and existing tests/assertions. Existing same-process active denial and unsolicited-token tests must still pass.
- [x] Run targeted lifecycle/auth/security tests, flutter analyze --no-pub, flutter test --no-pub. No weaker assertions or broad refactor.
- [x] Build explicit lib/main.dart staging x86_64 using existing external defines. Verify hash/target; install -r only on5554. Preserve5556 unsaved Guest workspace.
- [x] Owner enters test A directly when ready. Verify authorized Home, force-stop/restart, Home still Account with matching authority, background/resume. Never dump auth fields or credentials. Collect safe enum/boolean trace only.

Review focus: unsealed offline denial; mismatched registry; no verifier; token/owner/epoch change during verifier; a second in-process attempt cannot re-mint authority; no Account cache exposed before verifier; Guest retention; sealed restart unchanged. Expired/revoked SDK sessions retain existing denial behavior. Online verification is identity validation through the existing getUser callback, not password login.

No reset/clean/stage/commit/push/merge/deploy/DB/native config/dependency changes.25calls/5files/3repair rounds. Physical phone unavailable; native evidence is emulator only. PHONE-03 remains OPEN until real SDK cold restart passes.

Docs check: official changelog.md fetch unavailable in this environment; Dart auth-getuser URL404. Existing pinned gotrue2.27.2 source and official getUser server-validation documentation inspected; no SDK migration proposed.

Execution result2026-10-18: source checks709PASS/analyzer clean; stagingD5B365... native Account testA cold restart and background/resume verified PASS. Details in P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md. PHONE03 valid-session emulator defect closed; full P3.2/DNY acceptance remains pending.
