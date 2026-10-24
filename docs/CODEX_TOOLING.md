# Codex tooling for TravelGO

Setup date: 2026-10-19. This document records development tooling, not product
acceptance. Existing project rules remain in `AGENTS.md` and `.agent/`.

## Installed tooling

- Official `dart-flutter@dart-flutter` plugin, version 1.0.6, from
  `https://github.com/flutter/agent-plugins.git`. Codex CLI reports installed and
  enabled. It bundles Flutter/Dart skills and the `dart-mcp-server` stdio server.
- Existing Flutter 3.47.4 and Dart 3.13.3 are retained. The MCP runtime was
  downloaded to the SDK package cache; the app's dependencies were not changed.
- The original Codex config was backed up without printing it to
  `C:/Users/ASUS/.codex/config.travelgo-tooling-20261019.bak`.
- The local `travelgo-session` skill is installed at
  `C:/Users/ASUS/.codex/skills/travelgo-session/`. It points to existing rules and
  the latest delivery ledger rather than duplicating mutable project status.

See the [official Flutter installation guide](https://docs.flutter.dev/ai/get-started).
The current chat may need a new turn or an app restart to discover newly
installed tools. Use `codex plugin list --marketplace dart-flutter --json` to
check installation; runtime readiness is a separate check.

## Repeatable checks

Run in PowerShell from this repository:

```powershell
./tool/verify-travelgo.ps1 -Mode Status
./tool/verify-travelgo.ps1 -Mode Ai
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/ai_generation_test.dart
./tool/verify-travelgo.ps1 -Mode Full
```

Use `-DryRun` to print commands without running checks, and `-FlutterRoot` if the
SDK is not on PATH. Full runs analyzer, the entire Flutter suite at concurrency 2
and the three existing Node contract suites. Flutter checks invoke the cached
Flutter CLI through its Dart executable to avoid the Windows bootstrap launcher
hang previously recorded in the delivery ledger. `--no-pub` keeps dependency
resolution separate. Logs are saved under ignored
`.dart_tool/travelgo-verification/<run>/`; the first failed check stops the run.

## Scope and remaining work

This setup does not add `integration_test`/Patrol, change native configuration,
deploy an AI function, run paid/live Gemini requests or operate existing
emulator sessions. A dedicated integration-test task should define synthetic
fixtures and which native flows it will cover before adding test dependencies.

Do not copy generic architecture/routing/package rules over the project's
Provider/Dio contracts. Adding skills and tools does not authorize changing
those contracts. Superpowers remains explicit-owner-request only.

## Verification record

Fresh evidence on 2026-10-19, checkout `codex/phase-3-discovery-design` at
`cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa` with the pre-existing dirty work retained:

| Check | Observed result |
| --- | --- |
| Plugin list | Version 1.0.6, installed=true, enabled=true |
| MCP protocol | initialize + tools/list PASS; server 1.2.1; 14 tools |
| MCP inside this Codex chat | Root registration succeeded; analyze_files on test/ai_generation_test.dart returned No errors, with applyFixes=false |
| Skill | Official quick_validate.py: Skill is valid!; UI YAML validation PASS |
| Analyzer | No issues found! in 53.9s, exit 0 |
| Flutter suite | 757/757 All tests passed! in 1:24, exit 0 |
| Node gateway/catalogue suites | 87/87 passed, exit 0 |
| Helper | PowerShell parse and dry-run PASS; invalid outside-test path rejected with exit 1 |
| Final helper Targeted mode | test/ai_generation_test.dart: 12/12 passed; helper exit 0 |
| Config preservation | Comparison with backup found only marketplaces.dart-flutter and plugins.dart-flutter@dart-flutter added |

Analyzer/Flutter logs:
`.dart_tool/travelgo-verification/20261019T162506012Z-21276/`.
Node log:
`.dart_tool/travelgo-verification/20261019T162556953Z-17972/node-contracts.log`.
Final Targeted-mode log:
`.dart_tool/travelgo-verification/20261019T162807656Z-28708/flutter-tests.log`.

The first helper invocation found multiple SDK commands on PATH and stopped
before analyzer execution. SDK selection was corrected to use the first resolved
application. A subsequent in-flight Full run passed analyzer and all Flutter
tests, then exited 1 at Node discovery using its already-loaded older helper
code. Node selection was corrected too; a fresh Ai invocation then passed all
87 tests. Do not describe the earlier combined process as exit 0. Final dry-run
resolves one Flutter executable and one Node executable.

The initial sandboxed MCP attempt could not access pub.dev; authorized runtime
download and subsequent real protocol/tool calls succeeded. Existing image HTTP
400 notices in widget tests do not establish native image acceptance. No fresh
Gemini/native/physical-device acceptance was performed. Product blockers remain
in the delivery ledger.

Why: typed MCP tools replace repeated shell guesses; the local skill routes to
the latest evidence; the helper standardizes cached-SDK checks and preserves
nonzero failures. Lesson candidate: multiple SDK installations on PATH can turn
an executable lookup into an array; resolve one executable and verify its actual
execution before treating a wrapper failure as an app defect.

Review prompt: Review tool/verify-travelgo.ps1 and this setup record against the
existing TravelGO rules. Check command/exit propagation, ignored logs and scope;
distinguish the successful individual checks from the older combined-process
failure. The local skill is at the installation path above. Do not operate
emulators or external services as part of this tooling review.
