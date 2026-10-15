# Upstream provenance

- Repository: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- Pinned revision: 56ea9cf174ed86786187daa9de0e6247cb0747e4
- Source package: .claude/skills/ui-ux-pro-max
- Installed: 2026-10-15, project-local .agents/skills/ui-ux-pro-max.
- Installer: Codex skill-installer/install-skill-from-github.py, download mode.
- Upstream package: 73 files. Data/scripts/references copied without modification.
- Licence: upstream MIT, preserved in LICENSE at this directory.

## Local adaptations

- SKILL.md: replace the Claude plugin root prefix with <absolute-skill-dir>,
  resolved from the location of SKILL.md; add the TravelGO integration entry.
- TRAVELGO.md: project-specific routing/precedence and Flutter design constraints.
- SOURCE.md and LICENSE: provenance and upstream licensing.
- No global installation, package manager hooks, submodule or nested Git checkout.

## Updates

Review a specific upstream revision and its diff before updating. Preserve the
TravelGO adapter and local rules; do not overwrite the package from a moving
branch or regenerate the app design system as part of an update. Re-run the
search smoke checks and report results after any update.
## Installation verification — 2026-10-15

- GitHub tree inventory: 73 upstream package files; 72 unmodified files match
  pinned Git blob SHA-1. SKILL.md is the one intentionally adapted upstream file.
- Local additions: LICENSE, SOURCE.md and TRAVELGO.md; package total 76 files.
- Search smoke: "large fonts" --stack flutter returned Flutter guidance; PASS.
- Search smoke: "touch target" --domain ux returned touch guidance; PASS.
- Design-system --json smoke: valid JSON, no --persist and no app theme generated;
  PASS. Search results are recommendations, not an approved TravelGO redesign.
- flutter analyze --no-pub: No issues found, 49.1s, exit 0.
- flutter test --no-pub --reporter expanded: 527 tests passed, 28s, exit 0.
- Installation does not change application source, APK, permanent project rules,
  Flutter dependencies or the pre-existing Owner macOS generated file.
- This verifies installation and tool execution. Visual/accessibility audit of
  the running app is a separate task, not a result of installing this package.

Lesson: preserve upstream provenance and use project constraints to select design
recommendations; adding a design skill alone does not prove UI quality.