# Phase 2 Completion Plan — Codex only

Status: execution plan, 2026-10-13. Owner requested continuous Phase 2 work without separate packet approvals. Superpowers is used only to plan and diagnose; implementation, repair, and verification use ordinary tools. The Owner still reviews and merges PRs and authorizes a specific live database target before any apply.

## Goal and current evidence

Finish the outstanding Phase 2 integration without changing the Decision Engine or treating tests as proof of deployment. Main base is `92645ef7f9061c245e70c4ccad8314dff697e984` (PR #26 merge). B6.2 is an uncommitted five-file branch, `codex/phase-2-b6-2-auth-lifecycle`: analyzer clean; last full run 443 pass, 2 fail. B3 receipt migration and fault controls passed on staging `bkocylxbuyvdgxccpixx`; primary `oavbymauorhmrjcustzw` is not applied.

Owner-approved behavior: app-controlled foreground refresh; safe sealed offline return; unknown cleanup locks account cache while Guest remains usable; no auto import; explicit selected draft transfer only after server acknowledgement; account snapshots purge on logout/switch. No extra paid service, native permission, dependency, production database apply, or backend-repo edit is implied by this plan.

## Sequence and independent review surfaces

| Work | Source limit | Behavior proving completion |
| --- | --- | --- |
| B6.2 repair and release | Existing five-file allowlist in `B6_2_IMPLEMENTATION_PLAN.md` | Stable startup route/context; one title; Guest survives delayed authorization; SDK/SQLite lifecycle tests, analyzer, full Flutter tests, exact-head CI. |
| B6.3 raw snapshot adapter | Five-file allowlist in `B6_IMPLEMENTATION_PLAN.md` | Raw canonical data and receipt checked; nullable legacy metadata displayed honestly; A/B late results rejected. |
| B6.4 cache/import binding | Five-file allowlist in `B6_IMPLEMENTATION_PLAN.md` | Only current owner reads offline snapshot; delete/401/expiry handled; Guest drafts and pending quarantine preserved. |
| B7 explicit import consent | Four-file allowlist in `BATCH_B_DESIGN_REVIEW.md` | No preselection/auto import; chosen revisions and owner confirmed; retry and lost acknowledgement never duplicate. |
| B8 read-only snapshot viewer | Four-file allowlist in `BATCH_B_DESIGN_REVIEW.md` | Real saved itinerary read offline with age/source label; no offline remote edits or Decision Engine recomputation. |
| B9 integrated evidence | Inspect dependency/native need before edits; max five files | Real device/emulator restart, airplane mode and account switch; staged receipt/response loss controls; exact commit/CI and honest NOT RUN list. |
| R07 / Batch C | Separate source/DB surfaces, each at most five files; inspect model/host/key/quota first | Server-held Gemini key, verified caller, three Guest logical requests/day at 00:00 Vietnam, failed unusable request uncharged, idempotent quota reservation, minimum context and explicit AI label. Never claim live AI from mock results. |
| Catalogue and release evidence | Dataset/source/license packet after inspecting actual inventory | 12 destinations, at least six validated places and one sample itinerary each, acceptance mapping and submission checklist; no invented provenance. |

Internal source changes remain in reviewable units of at most five files. Codex can continue from one unit to the next without seeking a fresh design vote. PRs keep the human merge gate; dependents use verified merged main or an explicitly identified stacked base. An unresolved quality failure is repaired before claiming that unit complete. Preserve the Owner's six protected paths and all other untracked files. Never reset or clean the checkout.

## B6.2 root cause and repair contract

The pending bootstrap builds a nested `Navigator` with `SplashScreen`, then replaces that entire subtree when initialization/Guest choice completes. Existing planner tests retain the Splash context, which becomes deactivated. The overlay also adds a second `TravelGO Mobile` text. For an injected runtime lacking a registry path, the asynchronous fallback calls native `getDatabasesPath()` after test teardown. Repair the bootstrap at its source: keep a stable route/context while authorization state changes, show a single title, block Splash navigation until auth is resolved, and resolve the registry path using the injected runtime's store directory or an explicit safe injected path. Keep the existing tests' assertions; add only focused tests if a behavior is not already pinned.

## Gates and evidence labels

For each implementation unit: inspect exact git status/base and allowlist; run targeted behavior tests, `flutter analyze --no-pub`, full `flutter test --no-pub`, format/diff checks, then selective commit and PR/CI. Distinguish WRITTEN, LOCAL PASS, CI PASS, STAGING APPLIED, PRIMARY APPLIED, and device NOT RUN. B3 primary apply and any new live migration require a target-specific Owner approval; do not imply it from this implementation request. Android and live services must be observed before calling Phase 2 complete. Use no subagents or Docker.

Open business-only decisions are escalated if existing approved docs cannot settle them, particularly paid Gemini hosting/model/quota costs, personal-data retention, and live database application. Choose the no-cost option only when it is technically supported and does not weaken the approved security or acceptance contract. Do not ask for routine implementation choices.
