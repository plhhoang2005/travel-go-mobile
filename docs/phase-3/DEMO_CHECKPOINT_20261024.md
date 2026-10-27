# Demo source checkpoint — 24/10/2026

## Changed

Owner authorized commit and push of the current project. This checkpoint collects
the existing mobile source, catalogue asset, admin page, Supabase source, tests,
verification tools and project reports on `codex/phase-3-discovery-design`.
Base HEAD: `147bd2050ae3a59e942b29945fbe54c9c9eae60c`.
Codex did not change application behavior in this checkpoint task.
Local screenshots, emulator XML, root document/presentation generators, generated
presentation/Word files and Supabase CLI temporary files remain outside Git.

## Why

Preserve a source checkpoint for the team's demo preparation and handover.
Owner chose to defer the six recovery findings if password recovery is excluded
from the demo. This decision does not close the findings or supersede the
REQUEST CHANGES verdict in `CORE_REVIEW_R1_CODEX_REVIEW_20261024.md`.

## Testing

Fresh verification against the staged source candidate, before this documentation:

- `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`: exit 0.
- Analyzer: no issues, exit 0.
- Flutter: 1097 tests passed, exit 0.
- Node gateway/catalogue contracts: 91 tests passed, exit 0.
- `node --test test/admin_discovery_web_test.mjs`: 26 tests passed, exit 0.
- Full verification logs (local, ignored):
  `.dart_tool/travelgo-verification/20261024T055725176Z-29272/`.

These passing suites do not cover all recovery races. The previous independent
review reproduced ten failing recovery assertions with three passing controls;
see the review report for reproduction details and limits.

## Problems

Demo assessment: a candidate for a guided demo of planning, saved trips and maps;
final acceptance on the intended APK, device and network is still NOT RUN in this
task. Live login/registration, email delivery, API availability and AI rollout are
not certified by these automated results. Backend-unavailable tests exercised
labelled fallback; passing them does not prove the live decision engine is up.
No APK build/install, database migration, deployment or merge was performed.

Before the presentation, rehearse login with the intended demo account, create a
plan, save/reopen it and view its map on the actual presentation setup. Exclude
password recovery. If AI is part of the presentation, validate that flow against
the deployed environment too. A GitHub source checkpoint does not supply SDKs,
server configuration or a running backend to a new machine.

## Lesson Candidate

Problem: an automated green suite can be mistaken for a ready live demo.
Root cause: local contracts and fallback behavior do not prove external services
or the presentation device work. Rule: keep source verification and a complete
rehearsal on the actual demo setup as separate evidence.
