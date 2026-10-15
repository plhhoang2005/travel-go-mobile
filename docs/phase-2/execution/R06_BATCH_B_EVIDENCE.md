# Batch B integration evidence — B9

2026-10-13. Codex-only implementation and verification; superpowers OFF.
Base: `522c0d1958434c844302fdbff20872fd85e60e7c`, main after PR #31.
Branch: `codex/phase-2-b9-integration-evidence`. Owner retains PR merge and
target-specific database deployment approval. Primary B3 NOT APPLIED.

## Changed / Why

Four files only:

- `test/batch_b_fault_test.dart`: lifecycle, Guest consent/import and account
  cache providers share the real SQLite FFI store. The controlled transport
  retains server state between reconstructed runtimes.
- `test/native/batch_b_probe.dart`: standalone native sqflite/filesystem probe,
  isolated database directory, synthetic sessions and three app launches.
- `tool/run-batch-b-native-probe.ps1`: builds/installs the probe only on an
  emulator, force-stops between launches, checks explicit results, restores the
  ordinary `lib/main.dart` APK in `finally`. No app data clear/uninstall.
- This evidence record.

No dependency, native permission/configuration, production entry-point, schema,
Decision Engine or live database change. Existing Owner/untracked documents are
excluded from staging. Native probe data is confined to `b9_native_probe_v1`
under the app-private database directory; existing directory without its exact
ownership marker is refused. Cleanup removes only named owned files and refuses
recursive deletion if unexpected files remain.

## Testing observed by Codex

| Check | Result and scope |
| --- | --- |
| `flutter analyze --no-pub` | PASS: No issues found, final Dart source, 37.5s. |
| `flutter test --no-pub test/batch_b_fault_test.dart --reporter expanded` | PASS: 3 tests, real SQLite FFI/reconstructed store and lifecycle. |
| `flutter test --no-pub --reporter expanded` | PASS: 470 tests, 26s. Includes existing consent and snapshot widget tests. |
| `tool/run-batch-b-native-probe.ps1` | PASS on existing Pixel_8 emulator `emulator-5554`, `sdk_gphone64_x86_64`; real Android sqflite and app-private registry file. |
| Probe/ordinary Android debug APK builds and installs | PASS. Final ordinary entry point restored after second complete probe run. |

Native runner output:

```text
B9_NATIVE_STAGE1_PASS
B9_NATIVE_STAGE2_PASS
B9_NATIVE_STAGE3_AND_OWNED_CLEANUP_PASS
B9_NATIVE_THREE_LAUNCHES_PASS
B9_PRODUCTION_ENTRYPOINT_RESTORED
```

Stage 1 stores a Guest payload and account snapshot, then seals the registry.
The runner force-stops the Android process. Stage 2 restores that same synthetic
safe session and exact Guest payload, reads its account snapshot, then injects
an actual pre-marker purge exception: cleanup reports failure and no account
handle remains. Another force-stop follows. Stage 3 rejects unsafe A restoration,
observes zero account snapshot rows after startup cleanup, retains the Guest
draft, establishes B without exposing A, revokes B and removes owned fixtures.
This validates native storage/process restart primitives. It does not emulate
physical power loss or use a real Supabase login.

Cross-layer FFI cases validate:

1. Select only draft X; server simulator commits but loses its reply. A newer X
   revision and unselected Y remain. Safe restart does not auto-import or select.
   Explicit retry sends the identical six arguments/key, yields one remote row,
   consumes only the imported old revision and exposes its checked offline
   snapshot. Logout clears account RAM/SQLite copies and acknowledged journal,
   while remote X and untransferred X/Y stay intact.
2. Pending A is quarantined on logout/restart. B has no A journal/cache and
   cannot dispatch A's retry. Fresh A login plus explicit retry reconciles the
   same attempt without a second remote row.
3. A SQLite marker failure after durable registry revocation invalidates visible
   snapshots immediately. Reconstructed startup denies the stale session,
   completes cleanup and preserves Guest without a transport request.

## Acceptance boundary / Problems

| Acceptance | Evidence now | Still NOT RUN |
| --- | --- | --- |
| AC-005/045 | Guest and read-only snapshot codec/store/widget tests; native exact payload close/kill/reopen | Complete production planner UI save/open across Android kill; manual itinerary/expense editor requirements are not completed by Batch B. |
| AC-006/053 | Exact selection, lost-response retry, edited revision, account quarantine integrated with providers/SQLite | One continuous live authenticated mobile-to-staging import/UI/restart path. Controlled transport is not live Supabase. |
| AC-040/055 | Owner invalidation, native durable failed purge/restart, B isolation and Guest retention | Live account A/B logout/re-login and remote trip re-download in the production UI. |
| B3 server receipt | Historical staging SQL/races/fault cleanup evidence in `R06_IMPORT_CONTRACT.md` | Primary rollout remains NOT APPLIED. New B9 checks do not reapply B3. |

GitHub exact commit, PR and CI are recorded in the B9 PR after selective commit.
Do not mark all Batch B acceptance or all Phase 2 complete from this report.
No user credentials, real profile/itinerary, or Gemini requests were needed.

## Lesson Candidate

Lost reply correctness crosses several boundaries: preserve the frozen source
and attempt identity on disk, reconstruct without auto-dispatch, validate the
server receipt, then consume only the acknowledged revision. Test these layers
together and distinguish native storage evidence from live authentication.
