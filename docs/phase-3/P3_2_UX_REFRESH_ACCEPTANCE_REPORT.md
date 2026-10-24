
# P3.2 UX refresh — acceptance checkpoint 2026-10-18

**PARTIAL / NOT ACCEPTED.** Codex-only. Owner explicitly requested Superpowers in this continuation: using-superpowers, executing-plans, verification-before-completion, systematic-debugging (probe startup observation). No new app source edits. Existing approved plan remains binding; no reapproval, subagents, commits, deployment or database changes.

## Identity and evidence

- Branch codex/phase-3-discovery-design; HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa plus preserved uncommitted P3.2 work. HEAD alone does not identify the tested dirty source.
- Pixel_8/emulator-5554, Android14/API34 from handoff; ABI x86_64 verified live. Physical1080x2400, density420 verified live (~411dp width). DNY-NX9 absent from live ADB inventory.
- Installed staging base.apk hash verified before and after probe restoration:122AE3A65457B1FA3CBD47EAF59E8F3E365DCCF8B3682D534D9A1EC8D5D27A15. STAGING ribbon visually verified in captured screenshot. Existing external staging defines were used; no credentials printed.
- Fresh source checks: flutter analyze --no-pub: No issues found,28.7s,exit0; flutter test --no-pub --reporter expanded:702PASS47s,exit0; node --test test/catalogue_readiness_test.mjs:40PASS0FAIL,exit0. git diff --check for Guest fix source/test:exit0. No source changed in this QA continuation.

## Native observations on staging122AE3A6

1. Guest save/list/reopen: Trips mounted before new save. Created synthetic P32G1810,3days/2people/budget4000000,no destination/dates/activities. Preview -> save -> acknowledged -> Back twice -> Home -> Trips. New revision1 row appeared alongside original synthetic Guest draft WITHOUT tapping reload. Opened the new row and confirmed title, saved state, budget4000000 and actual0. PASS for this exact native regression. Does not prove Account save-refresh or full Guest import.
2. Guest delete routing: added synthetic P32Activity in P32G1810. Delete -> Cancel retained editor/activity. Delete -> Android Back retained editor/activity. Delete -> Confirm removed the activity and retained editor with0 activities. Add+delete returned document to original saved content; no additional save/revision was claimed. No actual expense was attached to the deleted activity: attached-ledger preservation and Account dialog cases remain pending.
3. Native synthetic persistence probe: preflight verified databases/p32_owned_native_v2 absent. Built dedicated target test/native/editable_trip_probe.dart, debug x86_64 with staging defines; build23.1s exit0. Probe APK hash95575E86FFD1B4F4644F73E114824AED6ED564F0107D235ECF2B8976910A6EEF. Installed -r, first process logged P32_NATIVE_STAGE1_PASS_RELAUNCH_REQUIRED with marker stage1. Force-stop/relaunch logged P32_NATIVE_STAGE2_PASS with marker stage2. Confirms real Android SQLite/sealed restart, actual20000, synthetic A purge/B isolation/outbox and Guest retention under the probe's synthetic session reader. NOT a real SDK Account/session/latency/conflict test. Initial immediate stage2 read was too early (marker1/null UI root); later process log/marker verified completion without changing code or restarting a third time.
4. Restored staging APK -r from backed-up122AE3A6, verified installed hash. Explicit onboarding Skip entered Guest. P32G1810 persisted through process death and probe/install cycle. Original synthetic Guest draft also remained: actual123456,paidOn2026-10-16,remaining3876544 against budget4000000. No Owner data cleared/uninstalled.
5. Large text: temporarily set emulator system font_scale2.0, inspected budget screenshot: totals123456/3876544 readable, chart labels wrapped, save action visible, no obvious clipping in that view. Restored original setting (unset/null) in finally. Evidence C:/Users/ASUS/.codex/visualizations/2026/10/18/01a14d0e-364c-7f12-9aa2-807bcde49ac3/P32_NATIVE_BUDGET_SCALE2.png. This is one ~411dp portrait screen, not full E12 or a phone performance result.
6. Map unknown-day case: day1/no date,0/0 reference positions, explicit no verified coordinates/no activities, no invented default destination/route; Android system Back returned to editor. PASS for zero-position map/Back case only. Online tiles/known markers/day-switch and offline failure matrix remain pending. AI entry was opened afterward; final text recorded in live tool evidence, not used to close full E11.

## Emulator matrix status (this checkpoint)

| Case | Status | Remaining evidence |
| --- | --- | --- |
| E01 | BLOCKED / NOT RUN live A/B | Owner credential entry directly on device; first/second login durations |
| E02 | PARTIAL | Guest process retention and synthetic sealed probe passed; real valid/expired/revoked SDK sessions pending |
| E03 | PARTIAL | Synthetic probe A/B cache isolation passed; live logout/A-to-B/late callbacks pending |
| E04 | NOT RUN in this continuation | Offline auth/resume/error and network restoration |
| E05 | PARTIAL | Guest create/save/list/reopen passed; login/no-autoimport/cancel/confirm import pending |
| E06 | PARTIAL | Manual title/preview/apply/default amounts observed; full destination/date/limits/resize matrix pending |
| E07 | PARTIAL | Add/delete synthetic activity observed; full edit/reorder/move/notes/resize pending |
| E08 | PARTIAL | Guest Cancel/Back/Confirm routing passed; barrier, Account switch and attached actual preservation pending |
| E09 | BLOCKED / NOT RUN live Account | Create/update/readback/list/paging/delete on authorized test owner |
| E10 | PARTIAL | Native SQLite/sealed probe two stages passed; real offline/receipt/two-session/V1 fixtures pending |
| E11 | PARTIAL | Home photo and zero-position map/Back observed; full sources/known-marker/tile matrix pending |
| E12 | PARTIAL | One budget screen at system font2/portrait411dp;360dp/landscape/all changed screens/TalkBack/reduced motion/touch/profile pending |

All DNY critical retests NOT RUN in this continuation. Prior phone failures remain open in historical report. No real Account credentials entered/read/logged. No cloud mutation or SQL applied by this QA pass. P3.2 remains NOT COMPLETE/NOT ACCEPTED.

## Next bounded continuation

Finish emulator Guest E06/E07/E08/E11/E12 matrices; prepare real staging Account A/B login timing with Owner entering credentials directly (do not dump auth EditText). Connect DNY for independent second session, then critical phone acceptance after emulator critical cases pass. Do not treat702tests or synthetic probe as live auth acceptance. Staging emulator currently in the original synthetic Guest editor budget view; AI-entry tap did not yield a retained unavailable-message observation, so AI native status is NOT VERIFIED; preserve both Guest drafts and synthetic probe directory. Build/app/outputs/flutter-apk/app-debug.apk currently contains the PROBE, not the app: use backed-up travelgo-staging-122AE3A6.apk or explicitly rebuild main before any app installation. No install to DNY until ABI/build target/profile/defines verified.

## Changed / Why / Problems / Lesson Candidate

Changed: this acceptance report plus shared progress report only; one PNG and two APK backups outside Git. Why: separate persistence, list freshness, process restart and real SDK authority evidence. Problems: remaining matrix/live Account/DNY gaps prevent acceptance. Lesson Candidate: UI dump before engine readiness -> stale/null root can resemble failure -> require fresh process status plus persisted marker before judging startup; synthetic session probes validate storage guards but cannot prove live authentication.

## 2026-10-18 — Two-emulator continuation; live PHONE-03 reproduced FAIL

**PARTIAL / NOT ACCEPTED. Priority is now PHONE-03 session restoration.** Owner currently has no physical phone and requests completion of emulator cases. DNY-specific touch/OEM/profile results are deferred due unavailability; they are not emulator PASS. User authorization to use Superpowers continues; executing-plans, verification-before-completion and systematic-debugging used, Codex-only/no subagents. Same approved plan and preservation limits remain binding.

### Changed and environment

No app source/test changed. This report is the only repository document changed in this continuation. Two external emulator launcher logs plus two fresh AVD profile files were created/updated (5 explicit files total including this report; ordinary emulator-generated runtime images are artifacts). Existing Pixel_8 userdata and snapshots were NOT copied or cleared. External profile: C:/Users/ASUS/.android/avd/TravelGO_QA_2.ini; config: current2026/10/18 artifact root/TravelGO_QA_2.avd/config.ini. Launcher logs: P32_EMU2_STDOUT.log and P32_EMU2_STDERR.log in that artifact root.

- Actual Git remains codex/phase-3-discovery-design, HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa, prior dirty/untracked work retained. Owner macOS hash reverified A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74. Protected Owner paths untouched. No stage/commit/push/merge/deploy/database apply/dependencies/native app config changes.
- Two independent Android VM processes now visible in ADB: emulator-5554 (original Pixel_8), emulator-5556 (fresh TravelGO_QA_2). Both use installed Android34 Google Play x86_64 image; no SDK/image download. QA RAM1536MB and userdata allocation4GB. Installed QA base.apk hash independently verified122AE3A65457B1FA3CBD47EAF59E8F3E365DCCF8B3682D534D9A1EC8D5D27A15, matching primary staging.
- Provisioning evidence: same-AVD read-only launch rejected because original instance was not read-only; preserved original instead of restarting it. Fresh hardware config initially inherited12GB userdata allocation with only11GB disk free; reduced only NEW QA partition to4GB. Boot then succeeded. Host free RAM dropped to about714MB; do not infer physical-phone performance or launch heavy parallel builds/tests. A command used reserved PowerShell HOME variable; corrected the harness variable before login (no credentials captured). Viewport misses after adding a sourced image were selector/scroll limitations, not diagnosed app regressions.

### Live Account A login and cold restart

Owner entered test A directly on emulator-5554 and reported Home. No password/email/token was read, written or logged. Safe timing trace on primary: credential_queue13ms, lifecycle_load1ms, authentication_prepare118ms, authentication_sdk2384ms, foreground_wait6ms, account_authorize326ms. One real sample only; these are component timings, NOT a measured submit-to-Home total/median or full E01 A/B acceptance.

After Owner confirmed Home, Codex checked UI booleans only: Home observed=True; Guest label present=False; login CTA present=False. Then issued am force-stop com.travelgo.travelgo_mobile followed by am start, without logout, Guest selection, uninstall or clear. Owner's explicit result after restart: **Guest or login requested**. Therefore PHONE-03 / valid-session cold restoration is **FAIL / OPEN** on current staging122AE...; prior source/synthetic probe PASS does not close it. Root cause not yet established. Do not assert token loss, SDK loss or lifecycle registry failure without tracing. No re-login was performed to bypass this failure. Exact shell-date command returned only date due argument splitting; do not use it as a complete restart timestamp.

Next diagnosis: preserve both VMs/data; inspect SDK initialization -> lifecycle registry resume -> authorization/bind -> published auth state -> bootstrap routing with existing safe timing hooks. Distinguish SDK session presence (boolean only, never expose token) from local lifecycle refusal and Guest publication. Add regression for the actual cause before a minimal correction; use systematic-debugging/TDD when new source work starts, then analyzer/full tests and real cold-restart retest. P3.2 approval persists; no new design approval needed. Account tests can run only with explicit known authority; do not fabricate authenticated state.

### Additional Guest observations on QA emulator-5556

On fresh QA selected Guest explicitly through onboarding Skip -> Home -> Hanoi detail -> Prepare trip -> Manual planner. Hanoi destination was retained. Added Ho Hoan Kiem through the actual reference-place dropdown; image made Apply button scroll below viewport, then scrolling reached Apply. Day1 map showed1/1 reference positions and marker1 Ho Hoan Kiem, matching item order, position-source expansion and explicit no-route/no-ETA/unverified access copy. This proves known-place binding/marker presence; no screenshot confirmed full tile loading, so online-map PASS remains open. Opening map and returning with Android Back was followed by an offscreen activity-action selector miss; do not turn that miss into an app navigation failure or a completed move-day test.

QA current state: Guest manual Hanoi workspace in RAM, one Ho Hoan Kiem activity day1, unsaved; after map Back, activity actions may require scrolling. Primary current state: Guest/login after failed Account cold restoration; do not dump auth EditText. Two VMs are independent, but only primary has completed one real Account login; a real two-Account-session/conflict test has NOT run. Do not claim emulator-5556 is already authenticated.

### Verification and matrix implications

No source changes, so no redundant flutter analyze/flutter test run this continuation. Last recorded source checks remain previous continuation's analyzer clean28.7s,702testsPASS47s, catalogue40PASS; this batch adds actual native evidence, not a new source PASS claim. E01 advances to PARTIAL (A login+Home observed, B/repeats/end-to-end timing pending). E02 is now FAIL for valid-session cold restart. E06/E11 gain Hanoi/manual/reference-marker observations but remain PARTIAL. E03/E04/E05 import/E07 remainder/E08 attached actual+Account/E09/E10 real sessions/E12 full accessibility matrix remain incomplete. DNY is deferred, not tested. Entire emulator matrix and P3.2 remain NOT ACCEPTED.

### Problems / Lesson Candidate / bounded stop

25-call boundary reached; stop after this checkpoint. No source repair rounds in this batch. First next action is diagnose PHONE-03 with the newly reproduced real Account evidence, not more AVD provisioning or re-login to hide state loss. Keep staging backup path and probe/app hash distinction from prior checkpoint. No emulator shutdown/cleanup or Owner data changes were performed. Lesson Candidate: real SDK login can succeed while cold restart still loses authorized UI -> test startup authority and storage/session evidence separately; an independent synthetic SQLite probe cannot prove real SDK restoration. Two emulator sessions can cover functional concurrency when each is independently authenticated; they do not establish phone-specific behavior.

## 2026-10-18 — PHONE-03 repair execution ledger (native retest pending)

Plan: P3_2_PHONE03_REPAIR_PLAN.md. Owner explicitly requested Superpowers diagnosis/plan/repair; Codex-only, no subagents. Ruling: keep approved dirty checkout and use this report as ledger, no worktree copy/new approval/commit/helper-generated files. Five-file scope: lifecycle service, local lifecycle tests, auth navigation tests, repair plan, this report. Progress report intentionally not touched.

Root-cause source/reproduction: cold startup calls resumeAccount -> establishAccount(false), which accepted sealed registry only; an active foreground process killed before sealing was purged/denied before server validation. Pinned Supabase Flutter2.17.2 initialization restores persisted SDK session but cannot itself grant local authority. New PHONE03 regression exercises real temporary SQLite/registry across lifecycle-service recreation and AuthProvider startup. RED:7new cases failed before production edit (server verification checks0; Account restoration denied). No pre-existing assertions changed.

Minimal repair: a new lifecycle service's first authorization attempt may recover an active record only when owner, fingerprint and expiry match a valid SDK subject and an existing server verifier is available. Matching server user must return before cache activation; owner/token/expiry/epoch are rechecked afterward. Sealed offline permits unchanged. Same-process active/unsolicited-token denial remains unchanged. No password re-login or UI Account flag fabricated. Safe debug trace uses only sdk_valid boolean, registry state, active_online boolean and active_server_verified boolean; no owner/token/credentials logged.

Tests: added6active-cold cases (verified, offline, wrong owner, late owner, late expiry, late invalidation) plus1AuthProvider startup case. Targeted125PASS18s including all prior lifecycle/auth/security tests. Analyzer initially found unnecessary ! and multiline-if braces; corrected in one lint repair round without changing behavior/assertions. Analyzer rerun clean3.3s exit0. Full suite/build commands are in progress or in live tool output; do not infer native PASS yet.

Docs/SDK: official changelog markdown fetch unavailable; Dart getUser page404. Existing pinned gotrue2.27.2 source and official getUser network/server-validation documentation were inspected (https://supabase.com/docs/reference/javascript/auth-getuser). No SDK API/version/dependency changes, DB queries/migrations or service config changes. Existing callbacks still own server subject validation.

Actual state preserved: branch codex/phase-3-discovery-design, HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa plus prior dirty work. Both emulator5554/5556 connected,5556 unsaved Hanoi Guest workspace untouched. Owner macOS hash rechecked A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74. No protected Owner reads/edits, reset/clean/stage/commit/push/merge/deploy/native config/dependency/DB apply. PHONE03 remains OPEN until real SDK login/cold restart on the new APK passes.

PHONE03 source/build evidence update: final analyzer No issues found3.3s exit0; full709PASS43s exit0; explicit main staging x86_64 build21.2s exit0. APK D5B3651234633A87D11B8A0F3724A1B4577753583CAC8B4B058453C00FB4F96F installed -r successfully on5554 after ABI check.5556 was not rebuilt/reinstalled/restarted; its unsaved Guest workspace remains untouched. Primary login form opened on repaired main staging without reading auth fields; Owner asked to enter test A directly. Native cold restart is still PENDING, no PHONE03 closure yet. Only one lint correction round; no behavior repair loops. Self-review: server verification precedes _write(active)/cache bind; _current checks owner/token/expiry/epoch again after await; only first service authorization attempt eligible; existing same-process active denial, sealed offline and invalid registry tests passed. No merge/independent-review claim.

## PHONE03 repaired source verified — waiting for Owner real-login retest

Changed: exactly5files this repair (one lifecycle source, two test files, one plan, this acceptance report). Root-cause reproduction RED7 -> targeted125PASS -> final analyzer clean3.3s -> full709PASS43s -> explicit main staging build21.2s. Installed5554 base.apk hash independently matches D5B3651234633A87D11B8A0F3724A1B4577753583CAC8B4B058453C00FB4F96F. Source diff check clean. No source changes after successful full run/build.

Live safe diagnostic on repaired process after install: sdk_valid=true, registry=signedOut, active_online=false; startup_resume1484ms. This confirms a persisted valid SDK subject is present while local authority rejects the previously denied/signedOut registry. It does NOT authorize restoring signedOut, nor prove native active-record recovery yet. Requiring explicit login now preserves logout/revocation semantics after the earlier failed test. Do not change signedOut handling to skip this step.

Owner-input gate: repaired login form is open on emulator5554; Owner was asked to enter test A directly and report Home. No reply/login completion observed in this continuation after bounded waits. No auth EditText or credential storage read; no agent credential entry/relogin. Native login -> active registry -> force-stop -> cold Account Home, and background/resume are NOT RUN on this repaired APK. Therefore PHONE03 remains OPEN / native acceptance PENDING; do not call fixed/accepted from709tests alone.

Next continuation (no new plan approval): await Owner report that test A is in Home on5554; inspect Home/Guest/login-CTA booleans and matching authority, then force-stop/start the same app without logout/Guest/clear. Expect safe trace sdk_valid=true registry=active active_online=true then active_server_verified=true, and native Account Home for the same user. Check background/resume. On mismatch, keep evidence and diagnose within remaining repair budget; do not sign in repeatedly to hide failure.5556 remains untouched on prior122AE... APK with unsaved Hanoi Guest/Ho Hoan Kiem. No physical-phone claim.

Task limits:21outer tool calls used at this checkpoint, including waits and required read/verification; five-file cap retained, one lint correction round, no behavior repair rounds after first implementation. Stop solely waiting for the required Owner credential entry (outside agent scope), not a new approval. No tool sessions still running. Superpowers explicitly requested and used; no subagents; no reset/clean/stage/commit/push/merge/deploy/DB/native config/dependency/rules modifications. Existing source and Owner work preserved. Lesson Candidate: SDK session persistence and local cache authority are distinct -> recover an unsealed active checkpoint only with live identity verification and current epoch, while signedOut and offline-active stay denied.

## 2026-10-18 — PHONE-03 emulator valid-session cold restart VERIFIED PASS

Changed: repair remains exactly5files: lib/features/trips/services/local_account_lifecycle_service.dart, test/local_account_lifecycle_test.dart, test/auth_navigation_test.dart, P3_2_PHONE03_REPAIR_PLAN.md, this acceptance report. No source changed after analyzer/full709PASS/build. Existing Owner and dirty/untracked work retained; no stage/commit/push/merge/deploy/DB/dependency/native config modifications. Superpowers diagnosis/TDD/verification, Codex-only/no subagents.25outer calls total across repair and Owner-input continuation; one lint correction round.

Why/before-after: the old startup accepted only sealed checkpoints and purged/denied an active record left by foreground process death. New cold-service first resolution may use the existing server subject verifier for an active registry matching the valid SDK subject; it checks owner/token/expiry/epoch again before cache activation. Offline unsealed, invalid/signedOut/revoking registry, no verifier and same-process unsolicited authorization remain denied. Sealed offline behavior remains unchanged. Native trace now independently confirms sdk_valid=true while registry=active and server verification succeeds, rather than guessing that tokens were lost.

Testing/source:7regressions watched RED before code; targeted125PASS18s; final analyzer clean3.3s; full709PASS43s, all exit0. Exact explicit lib/main.dart staging x86_64 APK D5B3651234633A87D11B8A0F3724A1B4577753583CAC8B4B058453C00FB4F96F built21.2s, installed -r and installed hash independently checked. Existing security assertions retained. Source checks were not needlessly rerun during the waiting-only continuation; source/APK unchanged.

Testing/native real SDK on5554:
- Owner entered test A directly on repaired APK and confirmed Home. Codex then verified AccountHome=True with no Guest label/login CTA before restart. Live component timings: authentication_prepare87ms, authentication_sdk1922ms, account_authorize242ms (not total login-to-Home latency).
- am force-stop -> am start without logout, Guest selection, uninstall or clear. Process changed8962 ->9392. Owner explicitly confirmed still Home test A after restart.
- New-process safe trace: sdk_valid=true registry=active active_online=true; active_server_verified=true; startup_resume1765ms (component only, not full launch-to-Home measurement).
- Fresh uniquely named hierarchy dump was required to report success (did not reuse stale UI on null root). Native cold AccountHome=True; no Guest label/login CTA. Identity server callback checks same SDK/registry owner; no identity/token/credential values printed.
- Press Android Home; dumpsys verified launcher was top resumed; bring same app task foreground. Fresh hierarchy resume AccountHome=True, same process9392. No credential entry for cold or background restoration. No Account cloud mutation or new data fixture created by this retest.

Result: PHONE-03's reproduced valid-session cold-restart defect is FIXED/VERIFIED on emulator5554 with this APK; background/resume passed for the same Account. This supersedes the previous native PHONE03 failure ONLY for this exact repaired emulator flow. Not a DNY result, not acceptance of expired/revoked live-session/offline/A-B/conflict matrices, not a whole-P3.2 completion claim. Negative late owner/expiry/generation, offline verifier and wrong-subject regressions passed; real server revocation/offline device scenarios remain separate pending QA.

Problems/remaining: entire P3.2 still NOT ACCEPTED. PHONE01 full repeated A/B timing and other E01-E12 gaps remain open; no phone currently available.5556 was never reinstalled/restarted or controlled during this repair and still retains prior122AE... Guest Hanoi/Ho Hoan Kiem unsaved workspace.5554 now remains Account test A Home on repairedD5B365...; do not dump auth fields if Owner later navigates to auth. The two VMs intentionally run different app revisions until a separately planned data-preserving QA5556 update; do not claim they already provide same-build two-Account-session acceptance.

Next bounded task: resume remaining emulator acceptance with PHONE03 valid-session case closed. Preserve both devices and current authority, identify exact test data/owner before cloud mutations, use Owner-entered credentials for B/second Account session. DNY-specific checks remain deferred. No new P3.2 plan approval needed. Lesson Candidate: SDK persistence and local authorization are distinct -> recover active crash checkpoints through live subject validation, and prove both new-process and foreground-resume UI before claiming persistence fixed.

## 2026-10-18 — PHONE-04 Account create AND update native PASS (single bounded QA run)

Owner narrowed the grouped QA request to PHONE04 only. No Superpowers skill was newly invoked for this QA task; ordinary read/verify tools used. Scope: existing test A on emulator5554; only new synthetic P32PHONE04_1810_A1 then rename that SAME trip to P32PHONE04_1810_A1_R2.5556 and all pre-existing trips/Guest work untouched. No app source/test edits; no reset/clean/stage/commit/push/merge/deploy/SDK/dependency/native app config/DB migration or schema apply.

Identity: branch codex/phase-3-discovery-design, HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa plus preserved dirty work. Installed5554 main staging SHA256D5B3651234633A87D11B8A0F3724A1B4577753583CAC8B4B058453C00FB4F96F verified before QA; STAGING ribbon visually verified in final screenshot. Owner macOS hash reverified A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74.

Changed (3files including artifacts): this acceptance entry; external current2026/10/18 artifact root/P32_PHONE04_DRIVER.ps1; external P32_PHONE04_V2_READBACK.png. No production fix needed in this pass: existing acknowledged-save owner-scoped refresh implementation passed native testing. Helper requires a successful fresh UI dump before reads and does not reuse stale hierarchy. Existing source regressions remain at editable_saved_trip_ui_test.dart359/402/421 (empty-list refresh, refresh failure/no duplicate mutation, late-owner refresh guard).

Testing — create:
1. Opened Account Trips BEFORE any write. Confirmed list mounted and synthetic test title absent. Did not pull-refresh/tap reload at any point in this run.
2. Home -> Hanoi -> Prepare trip -> manual; set title P32PHONE04_1810_A1, dates2026-10-20 through2026-10-22,3days/2people,budget5123456VND. No activities/estimates/actuals added. Preview title/date/exact budget matched.
3. Tapped Luu vao tai khoan ONCE. First observation still Saving; waited for actual acknowledgement, did not retry mutation. UI then showed Da luu vao tai khoan and closed preview.
4. Returned through the Hanoi detail/planner stack to existing Trips. Exactly1synthetic row appeared WITHOUT manual reload, marked saved on cloud. Opened that row: correct title,Hanoi,dates,3days/2people,exact5123456; server-checked version1. PASS.

Testing — update in the SAME run:
5. From that synthetic version1 -> Edit -> Input; renamed to P32PHONE04_1810_A1_R2, preserving dates/people/budget. Preview matched. Sent one update save; observed Saving then acknowledged without retry.
6. Returned to detail: server-checked version2, new title, exact budget preserved. Returned to Trips WITHOUT reload: exactly1new-title row,0old-title rows. No duplicate trip produced.
7. Opened the updated list row again: titleR2,server-checked version2,dates20–22October,exact5123456 matched. Captured and visually inspected screenshot P32_PHONE04_V2_READBACK.png: correct title/version/dates/budget and STAGING ribbon. PASS.
8. Returned to Account Trips at end; syntheticR2 row count1. Left that single synthetic cloud trip in place for Owner review; did not delete test evidence or touch any other trip.

Why/flow verified: preview -> mutation acknowledgement -> existing owner-scoped list refresh -> already mounted Trips updates -> correct server-backed detail. Account update modifies the existing version rather than inserting a duplicate row. No fabricated UI rows, app reload, forced refresh or repeated save used to obtain PASS.

Harness problems (resolved without app edits): legacy text helper sent Android Back and opened dirty-form discard; chose Continue Editing and retained input. IME-based conditional Back also routed to discard; final helper never uses Back to dismiss text input, types/scrolls directly. Hanoi entry has an extra navigation level; final return walks visible Back actions until actual Trips tab exists. These were harness/navigation-state issues, not Account persistence failures. No data discarded, mutation retried, assertions weakened or app repair loops performed.

Verification limits: no new flutter analyze/full flutter test run because app source/APK unchanged during this UI-only QA; last source evidence for this exact APK remains analyzer clean +709testsPASS from PHONE03 repair. Fresh evidence HERE is real staging UI create/update/server-readback/list freshness. List was pre-mounted, but initial total count was not recorded as zero: do NOT claim a fresh empty Account native case or B account coverage. Existing empty-list regression is source evidence only. Paging/pull-refresh/delete/A-B isolation/import/offline/receipt/conflict/accessibility and DNY remain separate pending tests, not covered by this PHONE04 PASS.

Result: PHONE04 native Account save->automatic list update->correct readback verified for both CREATE and UPDATE on test A/emulator5554. This supersedes earlier Account native NOT RUN for these exact flows. Whole E09/P3.2 remains NOT ACCEPTED. No physical-phone acceptance claim. Source implementation unchanged; no new regression needed because no app bug was discovered.

Lesson Candidate: verify acknowledgement, list invalidation and server readback independently -> pre-mount list, use a unique synthetic title, verify exactly one row and server versions1->2 while preserving exact input. A selector miss or still-saving screen is not permission to resend a committed mutation.

Continuation:5554 Account Trips shows P32PHONE04_1810_A1_R2/version2 (one synthetic fixture retained);5556 still prior122AE... unsaved Guest Hanoi/Ho Hoan Kiem. Next selected task can reuse this fixture for Account deletion or proceed to Guest import/A-B grouping after preserving/updating5556 safely.19outer calls for this PHONE04 run; complete within25calls/5files, no app-code repair rounds.

## 2026-10-18 — Combined four-group emulator acceptance, bounded checkpoint

Owner authorized one combined run, 50 outer tool calls for the WHOLE run, max5 explicitly edited files and3 app repair rounds. Codex-only; no subagents; Superpowers OFF for this task. Supabase skill used for Auth review. No app implementation/test edits or repair rounds. Changed files: this report and external current2026/10/18 artifact root/P32_PHONE04_DRIVER.ps1 (scroll coordinates corrected to stay above IME). No dependency/SDK/native config/permanent rule edits, credential storage access, DB apply, reset/clean/stage/commit/push/merge/deploy. Existing dirty/untracked work preserved. Branch codex/phase-3-discovery-design, HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa. Owner macOS file SHA256 remains A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74.

Setup/data preservation:5556's prior unsaved Guest Hanoi/Ho Hoan Kiem workspace was saved as local revision1 BEFORE install-r. Installed main staging D5B3651234633A87D11B8A0F3724A1B4577753583CAC8B4B058453C00FB4F96F; verified installed APK hash. Both emulators now same main APK; no data clear/uninstall. Following startup onboarding Skip, reopened Guest revision1 successfully. Guest fixture subsequently became P32BATCH_1810_G,2026-10-20..22,3days/2people,5123456VND. Original Owner workspace used as authorized synthetic QA fixture; no unrelated trip modified.

Fresh source verification: flutter analyze --no-pub -> No issues found,14.3s; flutter test --no-pub --reporter compact ->709 tests passed,55s. Some image fixtures logged HTTP400 load failures while expected UI fallback tests passed. These are source tests, NOT emulator acceptance of negative Auth/retry/conflict/V1 cases.

Native results on5556:
- Form:0days and0people rejected with exact range messages; budget9007199254740992 rejected against maximum9007199254740991. Valid minimum1day/1person/0VND accepted in preview. Resize3->1 then Cancel/Discard left original editor title,2people and Ho Hoan Kiem intact; completed later dates/budget saved and reopened. Invalid2026-02-30 caused stale-valid-preview warning, but explicit invalid-date submission was NOT completed before clearing dates; do not claim full invalid-date matrix PASS. Upper valid bounds/negative/fractional/reversed dates/full resize-with-affected-items remain pending.
- Timeline: moved linked Ho Hoan Kiem item day1->day2; day1 empty/day2 contained exact item. Added day2 note P32DAY2NOTE. Renamed moved activity P32ACT_EDIT (expected reference removed when name changed), added P32ACT_SECOND, then Up on SECOND showed SECOND before EDIT. Deleted only EDIT after explicit confirmation; SECOND remained. Native source after save/reopen retained title/date, day2 note and SECOND; EDIT absent. Item times/activity notes/reorder persistence with both items still present were not fully checked.
- Actual ledger: created123456VND paid2026-10-20 linked to original activity BEFORE move/rename/delete. After linked item deletion, actual remained123456; remaining5000000 from5123456 budget. Saved Guest and reopened budget ->123456 preserved. This is real linked-actual deletion preservation, not the older no-actual deletion case.
- Guest->Account: Owner directly entered testA and confirmed Home. Trips initially had prior P32PHONE04_1810_A1_R2 and no P32BATCH_1810_G (no autoimport observed). Explicit Guest import -> select exact fixture -> preview matched one activity/one actual/exact budget -> Cancel kept source -> reopen preview -> tap confirmation ONCE. Source removed only after successful result; selection empty. Return to pre-mounted Account Trips without manual reload showed exactly1 imported synthetic row. Opened server-checked version1;5123456 budget and123456 actual retained. No duplicate confirmation/retry performed. Source revision consumed as designed; no other Guest source existed on5556 at this point. No source deletion before acknowledgement.
- LogoutA returned Guest; Trips showed neither synthetic A fixture. Guest empty-list area label was not observed, so no broad Guest-area layout claim. B verification is recorded separately below after Owner input.

Native result on5554: existing synthetic A detail P32PHONE04_1810_A1_R2 was verified online/server-checked before test. Disabled Wi-Fi/mobile data only on5554; tapped Check again; correct synthetic title remained and label became 'Ngoai tuyen · ban tren may chi doc' (Vietnamese accented on actual UI). Finally restored both network switches to their ORIGINAL states. This verifies cached offline labeling/readback; did not attempt a disabled write or uncached detail.5556 login was not network-interrupted.

Harness/approval evidence: old helper swiped on IME and added NJ text to synthetic activity name. Corrected helper scroll to800,1100->800,500, restored exact synthetic name BEFORE applying. No app fix/assertion weakening. One automatic approval review rejected a command containing broad UI-node output that could expose private Account titles; command did not execute. Continued through a safer exact-synthetic/static-action allowlist; no private Account list dumped. No credentials/token values read or printed.

OPEN, NOT PASS: real expired/revoked sessions; offline/timeout login and pending-login->Guest->login; late live callbacks; full A/B cache/detail isolation (B next); uncached offline; lost server response/retry idempotency on emulator; live two-session conflict; approved synthetic V1 read/copy; full form boundary/invalid matrix; affected-item resize; activity time/notes variants; Account linked-actual deletion. Existing709tests may cover logic but do not close any of these device cases. P3.2 remains NOT ACCEPTED; no DNY/physical-device claim. No production bug discovered/fixed in this bounded subset.

Continuation state before B:5554 remains A synthetic detail, network restored.5556 logged out A and opened B login form, Owner must enter directly. P32BATCH_1810_G is now a SINGLE cloud A trip version1, with SECOND onday2 and retained123456 actual; its consumed Guest source is absent by expected import behavior. P32PHONE04_1810_A1_R2 still retained unchanged. Reuse these synthetic fixtures rather than redoing preparation. Count includes waits/questions/rejected tool call, and final evidence/report calls must fit50. Lesson Candidate: invalid input/preview/cancel/acknowledgement/readback are separate observations; preserve linked ledger through item edits/deletion and prove import/list/server readback independently. Native UI tooling must scroll above IME and never dump broad Account or auth fields.

Final B result / Budget Guard checkpoint: Owner entered testB directly and confirmed Home. Safe boolean checks found testb in Home and Profile, Logout present, Account import action present. Trips after load:0 rows for BOTH A synthetic fixtures, no loading/error label. Returned through Profile to Trips;5556 now B Trips;5554 remains A detail with original networking restored. PASS for this concrete A->logout->B list-isolation flow, including previously loaded A list on5556. Do NOT extend to direct stale-A-detail/deep-link, delayed live responses or all cache tables. The OPEN list above is narrowed only by this native B-list PASS; all other missing cases remain NOT RUN/PENDING.

Stopped at50/50 outer tool calls for the entire combined run (including questions, waits, rejected command and this final checkpoint).2 explicit file edits including helper/report;0 app-code repair rounds. Full four-group acceptance is INCOMPLETE; no blanket PASS. Next priority with NEW owner-authorized budget: leverage current simultaneous A5554/B5556 for deeper stale-detail isolation and pending-login->Guest; obtain Owner A on5556 when two-A-session conflict is ready, then test conflict without repeating unrelated form setup. Need a controlled authorized response-loss/timeout method before claiming real retry receipt behavior; no fault injection/backend changes were made here. Need an explicitly identified synthetic V1 fixture before read/copy; do not mutate Owner V1 records. Live expiry/revocation still needs actual server/session evidence; do not substitute synthetic lifecycle tests. All four groups remain partially open as itemized; physical DNY checks deferred.

## 2026-10-18 — Continuation QA, real conflict/receipt evidence and OPEN conflict-recovery bug

Owner explicitly granted another50calls, max5files/3repair rounds. Same branch/HEAD and preserved dirty/untracked work; Codex-only, Superpowers OFF. No production source fix, SDK/dependency/native config/permanent rule changes, credential-storage reads, DB apply or Git publication. Conservative explicit file-touch budget5: this report; new test/native/p32_live_receipt_probe.dart; test/manual_planner_provider_test.dart; external current2026/10/18 artifact root/P32_MAIN_D5B365.apk backup; build/app/outputs/flutter-apk/app-debug.apk copied BACK to original main at the end. Ordinary generated build/cache outputs are not authored source.2 harness correction rounds (missing extension import; incorrect post-commit retry assertion);0 production repair rounds. Stop at50calls including final checkpoint/checks; do not erase RED regression to claim a green handover.

Auth/isolation observations:
-5556 B offline list refresh: both A synthetic fixture titles absent, error/offline state visible. Offline force-stop/start observation after6s was NOT a settled Auth result; networking was restored and UI later stabilized. Do NOT close offline cold-start, expired or revoked Auth based on that observation.
- Owner entered A credentials directly on offline5556. Owner reported 'cannot complete authentication' BEFORE choosing Guest, then Home Guest; independently confirmed Guest profile afterward. PASS for offline error->Guest, NOT pending-request->Guest/late login. Restored original Wi-Fi/mobile states1/1 and Owner logged A online successfully.
- During conflict preparation5554 editor became 'Phien chinh sua khong con kha dung'; preview/save disappeared. Profile still had Logout; reloading the exact fixture re-established online version2 without another credential entry. Cause of that lifecycle invalidation is NOT proven to be token expiry. Guard blocked old editor; no mutation sent during this failed preparation. Do not claim expired/revoked-session acceptance.

Real two-session conflict on MAIN staging:
1. Both emulators authorized as A and opened P32PHONE04_1810_A1_R2/serverversion2.5554 candidate renamed P32CONFLICT_WIN_1810;5556 candidate P32CONFLICT_STALE_1810, both from2. After re-opening the invalidated5554 editor from2, sent winner ONCE and observed acknowledgement.
2. Sent5556 stale save ONCE. Preview Save disabled; Back to editor retained stale title. Exact warning: 'Chuyen di da co phien ban moi. Cac chinh sua cua ban van duoc giu.' (accented on UI).5554 Back->server read confirmed WIN/version3 and no STALE title. PASS for detecting/rejecting concurrent stale update and preventing overwrite. This is NOT full conflict recovery PASS; see finding below.

Real server response-loss native probe, distinct from main UI retry:
- New standalone staging x86_64 target test/native/p32_live_receipt_probe.dart starts actual main SDK/lifecycle, requires real Account and exact existing WIN synthetic anchor; never reads credential storage itself or logs request/token/response contents. Fixed-origin adapter receives and drains a REAL successful create response, then raises receiveTimeout before the service/repository sees it. Creates ONLY P32LOSTREPLY_1810_01 with fixed frozen request00000000-0000-4000-8000-000000001810; no edits/deletes to other trips.
- First probe APK BF0BAB0BDB6C51493AF81C2EB17A9DBAFD0465D07DEEC83F0BAF91012360E01B: safe marker at12:29:34 committed_response_dropped=true. First retry committed locally, but harness then incorrectly invoked retryPending a SECOND time AFTER commit. listEditableAttempts intentionally excludes committed rows; that assertion was a HARNESS bug, not an app failure. No duplicate create retry was sent.
- Corrected probe6F4AF178AFE377B8C42F6E3BA83BFAA965DCBD720FB692F21FEA0218A7B836BC resumed the SAME fixture/request, verified exact committed outbox state (only state selected), looked up same receipt twice and server-read headversion1; list had exactly1 synthetic row. Safe markers12:32:17..18: recovering_prior_dropped_reply=true; prior_pending_retry_locally_committed=true; retry_same_receipt=true version=1 synthetic_row_count=1; PASS_NATIVE_REAL_SERVER_NOT_MAIN_UI recovery=true new_creates=0. This is native real-SDK/SQLite/server receipt recovery evidence across probe processes; NOT a main-screen Retry button acceptance.
- Restored5554 by install-r of verified external P32_MAIN_D5B365.apk, preserving data; installed SHA256 and build/app/outputs/flutter-apk/app-debug.apk both D5B3651234633A87D11B8A0F3724A1B4577753583CAC8B4B058453C00FB4F96F. Main reopened Account testA. build app-debug.apk is MAIN again, NOT probe. No need to reinstall a probe for ordinary QA.

Offline/detail follow-up on main5556:
- Explicitly left ONLY the stale synthetic candidate after verifying conflict retained it. Refreshed Trips and found exactly1 P32LOSTREPLY_1810_01. Disabled network BEFORE opening it; it still rendered because mixed-list loading PREFETCHES editable heads into cache. Follow-up confirmed offline read-only label and BOTH Edit/Delete enabled=false. Networks restored in finally. PASS for cached read-only actions; NOT uncached acceptance. Online Check again then server-checked version1 on5556 independently verified the new receipt fixture in MAIN.
- Attempted Edit on this valid new synthetic detail to finish date-invalid cases, but it silently stayed on detail. No date inputs were changed and those date cases remain NOT RUN here. This exposed the OPEN bug below.

### OPEN P2 finding: known rejected conflict blocks subsequent editor replacement

Native trigger: stale save returns version_conflict -> Back retains edits -> explicitly leave editor -> open another authorized online synthetic trip -> tap Edit. Actual: remains detail, no editor and no replacement confirmation. Native booleans: StillSavedDetailAfterEditTap=True, NoReplacementDialog=True, NoEditorInputAction=True.

Root cause evidence: ManualPlannerProvider.confirmSave sets _pending before account submit. Its catch for EditableRemoteException/code version_conflict changes state/error but leaves _pending. hasPendingSave is _pending!=null. confirmManualReplacement in editable_trip_detail_screen.dart returns false immediately for hasPendingSave, before presenting its dirty-work confirmation. Thus a known rejected command is treated like an unresolved possibly committed command; subsequent editor entry is blocked. Unknown outcomes MUST retain that fence.

TDD checkpoint: added paired regression in test/manual_planner_provider_test.dart named 'P32 rejected conflict releases pending but uncertain retains it'. Uses existing real local lifecycle/test store, injected typed service outcome, retains stale document/base/dirty assertions. Command flutter test --no-pub test/manual_planner_provider_test.dart --plain-name 'P32 rejected conflict' --reporter expanded -> exit1: version_conflict expected hasPendingSave false, actual true; outcome_unknown negative-control PASS. Production code NOT FIXED. Existing assertions unchanged; no skip/disable to hide RED.

Verification chronology: analyzer initially found native harness missing local-store extension import; corrected. Analyzer then clean3.8s; full suite709PASS47s BEFORE adding this new RED pair. Final probe correction analyzer clean5.1s/build12.9s. Latest targeted regression is1PASS/1FAIL; therefore CURRENT tree must NOT be called all-tests-green or P3.2 accepted. Final analyzer result, if run, is appended below. Full suite needs rerun after actual fix; older709PASS does not supersede current RED.

### Budget checkpoint / next exact work

End state: BOTH emulators mainD5 staging and testA.5554 HomeA after restoring main.5556 online detail P32LOSTREPLY_1810_01/version1; shared planner still holds conflict/pending state from deliberate synthetic stale attempt even though its route was explicitly left. Do not logout/reset5556 merely to hide this reproduction. Synthetic cloud WIN is original PHONE04 trip/version3; imported P32BATCH_1810_G/version1 retained; lost-reply fixture/version1 exactly1 retained. Guest data and all other trips/files untouched. Owner macOS hash recheck required in final tool.

Next priority within already approved P3.2 (no plan reapproval): minimal fix ONLY known version_conflict branch to release its rejected pending flag, preserve stale edits/conflict state, leave uncertain outcomes fenced. Run paired regression RED->GREEN, analyzer/full suite, explicit main staging x86_64 build/hash/install-r. Reproduce two-session conflict then verify opening another online trip now asks dirty replacement confirmation; Cancel retains stale edits; Confirm allows new editor. Native stale-request journal may also need review: don't assume clearing RAM resolves persisted staged attempt/receipt semantics. Preserve identity/epoch/subject guards and check exact service rejection before classifying as known.

Remaining NOT ACCEPTED: full conflict recovery (finding), pending-login->Guest and late callbacks, real expired/revoked sessions, timeout-vs-offline distinction, deep stale-detail A/B transition, uncached offline (list prefetch requires controlled synthetic cache setup), main UI lost-reply/retry, synthetic V1 read/copy, full form/timeline negative/boundary cases and prior matrix gaps. No physical DNY claims. Lesson Candidate: known rejection and unknown commit outcome need different recovery paths; verify 'what the user can do next' after correctly displaying conflict. A safe rejection alone is not usable conflict recovery. Never call a cached prefetch an uncached test, or a failed post-ack pending assertion a product defect.

Final call50/50: flutter analyze --no-pub -> No issues found (exit0), after the RED regression was added. Current targeted version_conflict regression remains RED intentionally; no production fix attempted. Checkpoint complete; stop Budget Guard.

## 2026-10-18 — Conflict recovery repair (current bounded run)

Owner authorized50calls/max5files/3repair rounds for this existing P3.2 bug. Codex-only, Superpowers OFF. Same codex/phase-3-discovery-design/HEAD cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa plus preserved dirty/untracked work. Protected Owner paths never read/edited. No dependency/SDK/native app config/permanent rule changes, reset/clean, credential dumps, Git publication or remote DB apply.

Five authored paths ONLY: ManualPlannerProvider; EditableTripRepository; editable_local_store.dart; existing manual_planner_provider_test.dart; this report. No native-probe edits or new screenshot/log/backup files in this run. Ordinary generated Flutter outputs are not authored source. Repair round1 production change, round2 curly-braces lint correction in new test adapter; no third repair used so far.

Root/plan: server version_conflict was definitive rejection, but RAM _pending and the staged update outbox both remained. Dirty replacement helper rejects hasPendingSave before showing its dialog. Fix the rejection lifecycle at both layers, retain stale document/dirty/conflict, and keep unknown outcomes fenced. No automatic retry, silent overwrite, Account flag workaround or weakened subject/epoch checks.

Changes:
- Provider releases RAM pending only for rejected/version_conflict with an existing saved base. An uncertain exception bearing the same code stays uncertain, with pending retained.
- Repository cleans a rejected update ONLY after receipt lookup returned not_found and the subsequent frozen UPDATE returned rejected/version_conflict. Receipt lookup/protocol/uncertain/create/delete paths do not invoke this cleanup.
- Local store deletes exactly one STAGED update with matching owner/request/full canonical frozen bytes, through existing serialized owner/epoch/transaction guards. Refuses changed identity/bytes and committed rows. No Guest draft/import journal/snapshot/receipt sweep or schema change.
- Historical staged rows from the old APK are NOT blindly deleted or assumed rejected without a fresh definitive response. No background recover/resubmit was added. Current fix prevents newly confirmed update conflicts from becoming such orphaned staged rows; legacy outbox cleanup is not claimed.

TDD evidence: checkpoint pair rerun before code -> known conflict RED, outcome_unknown PASS. Added uncertainty-kind/code control and actual-repository/SQLite outbox cases BEFORE implementation: known RAM pending RED, uncertain version_conflict wrongly classified RED, rejected update staged row remains RED; both uncertain controls PASS. After round1, all12provider tests PASS. Added safety regression refusing altered frozen bytes and same-request committed receipt; all13provider tests PASS. Existing assertions retained.

Verification/resource observations so far: initial analyzer found one curly-braces lint in new test helper, corrected in round2. Analyzer clean6.6s. First full default-concurrency run overlapped two AVD boots with about0.5GB RAM free and reported6UI failures (not accepted as green). Shutdown5556 normally without wiping userdata; isolated BOTH affected files then20testsPASS9s unchanged. Full suite rerun with concurrency2, no skips/assertion edits. Final full/build/native results appended below when complete. Resource contention is an observed condition, not a proven root cause for every initial UI failure.

Device setup: initially no emulators were running/connected; existing Pixel_8 and TravelGO_QA_2 AVDs reopened with their existing userdata, not recreated/reset.5556 temporarily shut down normally to release RAM for verification; must reopen for same-build two-session retest. Actual state/auth after install must be checked; old cached SDK credentials are not a reason to claim valid Account without authorization. Owner enters any needed credentials directly.

Source/build verification completed in this run: provider13testsPASS; isolated previously failing UI files20testsPASS9s unchanged; full flutter test --no-pub --concurrency2 --reporter expanded ->715PASS96s. No skips, reduced assertions or default-concurrency false-PASS claim. Analyzer clean after lint correction. Explicit flutter build apk --debug --no-pub --target-platform android-x64 -t lib/main.dart with existing external staging defines -> success50.1s. MAIN SHA256E2BC894D0F8743D55E82ED2BFC74BBC031C5EDF7985F19E77ABE24652F469D70. Install-r succeeded on BOTH5554/5556; each installed base.apk independently matched E2BC...; no uninstall/clear/wipe. Build output now this fixed MAIN, not receipt probe. Native Auth initially needed Owner login (safe5554trace sdk_valid=false registry=active active_online=false; no inference that credentials were deleted). Both form entries prepared, Owner asked to enter A directly on both. No hierarchy/credential reads while Owner types. Native conflict recovery still PENDING until below evidence is recorded.

### Native retest COMPLETE — conflict recovery P2 CLOSED for this repaired flow

Owner clarified that the 'cannot check session' message appeared BEFORE entering credentials, not after submitting a fresh login. Owner then explicitly confirmed BOTH emulators Home testA. No new Auth production change or credential inspection; do not label that pre-login message a regression from this repair or expired-session acceptance.

1.5554 and5556 each opened the same existing cloud fixture P32CONFLICT_WIN_1810 and independently verified serverversion3. Prepared5554 title P32CONFLICT_WIN_1810_R4 and5556 title P32CONFLICT_STALE_1810_R4 from that same3; no new cloud trip created.
2.5554 sent one save, acknowledged.5556 sent one stale save; exact 'Chuyen di da co phien ban moi. Cac chinh sua cua ban van duoc giu.' warning (accented on device), stale title still present. No retry, overwrite, Guest conversion or auto-save. Definitive conflict is distinct from uncertainty.
3. Explicitly left only the synthetic stale editor, returned to Trips, opened existing OTHER synthetic P32LOSTREPLY_1810_01/version1, tapped Edit. ReplacementDialogAfterConflict=True: the dirty-work confirmation now appears instead of the old silent block.
4. Chose 'Giu ban dang sua': remained server-checked detailversion1, no new editor. Tapped Edit again: replacement confirmation appeared AGAIN, proving canceled replacement did not clear dirty workspace. Source regression also verifies stale document/base/dirty remain intact after rejection. Native booleans CancelKeepsDetailAndNoNewEditor=True and CancelRetainsDirtyWorkspace=True. No claim of a direct inspection of the hidden RAM document after Cancel.
5. Chose 'Thay ban chinh sua': opened editor for P32LOSTREPLY_1810_01, input action available, stale title absent. ConfirmedNewEditorCorrect=True; NativeConflictRecoveryPASS=True. Did NOT save or modify that replacement trip. The stale test workspace is replaced only after explicit confirmation.
6.5554 Back->detail->Check again: authoritative WIN_R4/serverversion4, STALE_R4 absent. ServerWinnerVersion4=True; NoStaleOverwrite=True. Both installed hashes rechecked E2BC...; Owner macOS hash unchanged A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74. Git branch/HEAD unchanged, staged diff empty, scoped whitespace check clean (existing LF/CRLF notices only).

Result: the known-conflict editor recovery finding at the previous OPEN P2 section is FIXED and VERIFIED on main staging/two real AccountA emulator sessions. This supersedes that finding for the exact new flow; not a whole-P3.2 or DNY acceptance. Persisted cleanup verified by actual-repository SQLite regressions (known rejection removed, uncertainty retained, unrelated/same-request committed receipts retained, changed frozen bytes rejected). No native raw-database dump/count was used or claimed.

End state:5554 AccountA detail P32CONFLICT_WIN_1810_R4/version4;5556 AccountA clean editor P32LOSTREPLY_1810_01/version1. Original imported P32BATCH_1810_G/version1 and other trips/Guest data were not mutated by this repair. No logout/reset used to obtain the post-fix PASS. No dependency/SDK/config/permanent rule changes, stage/commit/push/merge/deploy or server DB apply. Source repair complete within5authoredfiles/2repair rounds; final calls below record total. Historical old-APK outbox entries are not swept or claimed migrated; only a freshly validated definitive rejected update is eligible for removal.

Why/before-after: rejected version conflict previously remained 'pending' in RAM/disk -> helper refused editor entry. Now exact rejected update is removed from unresolved outbox under existing guards -> RAM pending released -> stale edits/conflict retained -> explicit Cancel/Confirm controls replacement. Unknown outcomes still keep frozen request/outbox/RAM fences and cannot masquerade as known rejection.

Remaining P3.2 matrix outside this repair remains OPEN as previously itemized (Auth negative/late transitions, deeper A-B cache/detail isolation, uncached/offline setup, main UI lost-reply, syntheticV1, form/timeline variants and physicalDNY). No redundant retest or new scope started after this repair passed. Lesson Candidate: model definitive rejection separately from uncertain commit, resolve both persistent and in-memory pending state, and verify the next permitted user action rather than stopping at a correct error message.

Completed at44/50 outer tool calls,5authoredfiles,2repair rounds (production fix + test-helper lint). All required repair work/source checks/native conflict-recovery retest complete; no Budget Guard stop needed. Latest source evidence715PASS/concurrency2, analyzer clean; installed mainE2BC894D... on both emulators. P2 repaired flow closed; wholeP3.2 remains open as documented.


## 2026-10-18 - Dot 1/4 Auth interruption checkpoint (Budget Guard 50 calls)

Scope/authority: test A only, Codex-only/no subagents. Superpowers systematic-debugging and writing-plans used for analysis/short plan in chat only; OFF for emulator control and code. No protected Owner files/docs/superpowers read or changed. Existing dirty/untracked work preserved; no stage/commit/push/merge/deploy/database apply/dependency/native/permanent configuration change.

Native baseline: both devices installed MAIN staging SHA256 E2BC894D0F8743D55E82ED2BFC74BBC031C5EDF7985F19E77ABE24652F469D70 (verified this run). 5554 Owner confirmed Account screen; Back reached navigation without discard dialog. Logged out only 5554 local session. 5556 preserved at last confirmed Account A clean editor; its CURRENT UI was not inspected in this run.

AUTH-01 native evidence on E2: temporary cellular network delay=12000ms, Wi-Fi off. Owner confirmed only Guest remained enabled during pending authentication, submit disabled, Guest selected while pending, then Home Guest. Safe logs: first attempt21:30:23->21:30:36 sdk12787ms and authorization; second attempt21:31:08->21:31:21 sdk12439ms, exact SDK local-signout at21:31:21.299 and NO later account_authorize for that attempt. Source shows obsolete successful SDK response enters local-signout before authorization. Native subsequent UI guestGreeting=True/home=True/loginForm=False. Thus pending escape/late successful response suppression observed; not full AUTH-01 PASS because fresh login then exposed a defect.

Finding/root cause: Owner reopened login during the next offline test and reported 'dang null', email/password unavailable, submit disabled; Guest still worked. continueAsGuest increments request generation but password-login loading was not cleared. _cancelOAuth exits early with no OAuth intent. Old mutation finally clears loading only if generation matches. New LoginScreen derives busy from auth.isLoading but its own _action starts null. This explains the persistent disabled form after canceled password login, NOT an offline SDK error.

Repair (2 authored source/test files, 2 repair rounds including test Navigator harness correction):
- lib/features/auth/providers/auth_provider.dart: continueAsGuest clears canceled UI _isLoading immediately. Credential queue, request-generation/subject/session guards and stale-response local-signout remain intact.
- test/auth_navigation_test.dart: existing late_login_after_guest_exit_cannot_navigate_to_account regression expanded; asserts Guest releases loading, obsolete login cannot publish, reopened form enabled/no null, explicit second login succeeds as ownerA, two password requests. Navigator disposed before constructing a fresh form.
TDD RED observed Expected:false Actual:true at loading assertion BEFORE production fix. GREEN observed expanded regression +1 PASS after fix/harness correction. Existing assertions retained.

Verification: pre-repair targeted Auth/navigation/lifecycle/role suite125 PASS. Post-repair analyzer 'No issues found! (ran in46.6s)'. Full concurrency2 tests then explicit MAIN staging x86_64 build run sequentially; see continuation below. Initial sandbox test command stalled with no output and was interrupted; no PASS attributed. One escalated regression invocation hit automatic approval-review timeout; retry once was allowed and succeeded. It was an environment timeout, not a safety denial.

Current acceptance matrix:
| Case | Status | Evidence/remaining |
| AUTH-01 | FAIL on E2; source repaired; native retest NOT RUN | Native pending Guest/late suppression observed, but reopened form stuck. Regression RED->GREEN. Must repeat full sequence on new main APK including explicit login A. |
| AUTH-02 | NOT RUN (offline attempt blocked by AUTH-01 defect) | Network truly wifi0/data0, but Owner could not submit because stale loading; no real offline SDK failure or timeout established. 12s delayed successful request is NOT timeout. |
| AUTH-03 | BLOCKED | No identified naturally expired/unrecoverable test session with safe reason evidence. Old sdk_valid=false/timings not evidence of expiry. No clock/TTL/Auth-config changes made; valid refresh vs unrecoverable expiry not natively exercised. |
| AUTH-04 | BLOCKED | No available safe independent exact-session revocation route without reading token/credential storage or forbidden DB/global Auth change. Local logout used only for setup, not claimed external-revocation acceptance. Refresh revocation vs still-valid JWT not exercised. |

Final device/network at checkpoint: 5554 Owner last confirmed Home Guest on OLD E2; no credential UI dumps. Both devices wifi_on=1/mobile_data=1 restored and console delay0ms/unlimited speed verified; 5556 otherwise untouched. No new APK installed by this run yet. Physical DNY unavailable, no physical or whole-P3.2 acceptance claimed.

Budget: 50/50 outer calls reserved/used through final collection, 3 authored files total including this report, 2/3 repair rounds. No further actions after call50. Long-running command session85683 must be polled if continuation says still running; it runs expanded regression -> analyze -> full test concurrency2 -> main staging build -> SHA256, stopping on any nonzero exit. Build target lib/main.dart, android-x64, debug, existing 2026/10/15 staging defines; do not print defines. Before any install, verify final build/hash/target; install -r only to preserve app data.

Next: finish verification if active; verify/hash main APK; install -r on5554; use Owner credentials directly to retest delayed login -> Guest -> late cleanup -> reopened enabled form -> explicit login A. Then offline/recovery and actual timeout with reason evidence. Keep AUTH03/04 blocked until a safe real fixture/method exists. Do not close Dot1 based on tests.
Lesson Candidate: canceling an authentication intent must release its visible loading while keeping SDK serialization and stale-publication guards; regression must cover the next login, not stop at Guest navigation.


Verification continuation at Budget Guard: Full suite 715 tests PASS. Build reports Built; verify full target/hash before install. SHA256 observed B91CA7E8B716E4D2B71569C2FD68CC4F1FB4590E88D97870708104FE5C64A0A5. Command completed exit_code=0. No install/native retest performed. Final boundary 50/50 calls,3 authored files,2 repair rounds.


## 2026-10-18 — Đợt 1 tiếp tục sau Budget Guard

Owner yêu cầu tiếp tục Đợt1; lượt tiếp tục giữ trần mặc định25 calls, không đặt lại tổng file/vòng sửa:3/5 file,2/3 vòng sửa từ checkpoint. Không đổi source/test; Superpowers OFF khi thao tác emulator. Git vẫn codex/phase-3-discovery-design @cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa; dirty/untracked và file Owner được giữ nguyên. Hash macOS Owner vẫn A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74.

Đã kiểm hash APK main staging B91CA7E8B716E4D2B71569C2FD68CC4F1FB4590E88D97870708104FE5C64A0A5; install -r thành công chỉ trên5554, hash base.apk cài đặt khớp, launch COLD/MainActivity thành công. Không clear/uninstall/reset.5556 không cài lại/không đổi phiên.

AUTH01 retest native bằng Owner trên B91: cellular delay12000ms/Wi-Fi off được xác minh console. Owner làm loginA -> sau2-3giây chọn Guest khi còn spinner -> chờ30giây -> mở form lại -> nhập lạiA. Owner xác nhận nguyên văn: 'không có tự vào account trước bước 4, form có nhập được, có vào home a'. Tiếp đó Owner logout ONLINE và mở form trống, xác nhận 'form đã mở và nhập được'. Vì vậy finding form khóa/Đang null đã có retest native đạt theo Owner; không chỉ dựa715testsPASS. Chưa có trace SDK thành công-muộn độc lập của B91: hai lượt đọc log/đối chiếu UI bị automatic approval review timeout TRƯỚC thực thi (không phải lỗi app hay quyết định thao tác unsafe); không suy SDK callback thành công chỉ từ30giây chờ. Late-success trace trước đó trên E2 và regression vẫn là bằng chứng lịch sử riêng.

Sau phép thử, lệnh khôi phục delay none và Wi-Fi enable đã thành công. Để kiểm AUTH02, sau khi Owner logout ONLINE/mở form trống, đã tắt Wi-Fi và mobile_data trên5554, đọc xác minh0/0. Owner đang được yêu cầu submitA offline rồi báo lỗi/Guest. Kết quả offline/recovery và trạng thái mạng cuối cập nhật bên dưới. Không dump EditText, không đọc/in credentials/token/storage hoặc dữ liệu chuyến riêng. Máy5556 giữ nguyên.

AUTH03/04 vẫn BLOCKED như checkpoint: chưa có fixture hết hạn không thể phục hồi được xác định bằng lý do an toàn hoặc route thu hồi độc lập đúng phiên trong quyền hạn. Không đổi giờ/TTL/Auth configuration hoặc apply DB; logoutlocal không được tính là thu hồi từ bên ngoài. AUTH02 timeout thật vẫn CHƯA KIỂM; generic error/offline/delay12giây không phải bằng chứng timeout.

Verification source giữ checkpoint trước: regression RED->GREEN, analyze sạch, full715PASS/concurrency2, main build B91. Lượt tiếp tục chưa sửa code và không chạy lại checks để thay nghiệm thu native. Lượt này tới21/25calls khi lưu phần này; cập nhật cuối bên dưới là trạng thái cuối.

### Đợt1 tiếp tục — offline đã quan sát, mạng đã phục hồi (24/25 calls)

Owner trả lời ca5554 offline: khi submitA hiện 'không thể hoàn tất xác thực', sau đó chọn Guest vào Home Guest; cũng báo sau45giây chưa có lỗi. Chỉ ghi nhận error -> Guest và không có lỗi mới được báo sau đó; không diễn giải đoạn45giây thành timeout hoặc một request còn chờ. Không có dump màn credentials hay log exception riêng tư. AUTH02 nhánh offline/thoát Guest đạt theo quan sát native Owner; timeout thật chưa kiểm.

Đã thực thi khôi phục mạng5554 thành công: console delay none, Wi-Fi enable, data enable. Đọc xác minh wifi_on=1/mobile_data=1, network status min/max latency0ms, unlimited speed.5556 không bị tác động trong lượt này, vẫn APK E2 theo checkpoint/không có cài mới hay thay đổi mạng/phiên5556. APK5554 là main stagingB91 đã kiểm hash cài đặt ở trên.

Đã yêu cầu Owner từ Home Guest mở form/đăng nhậpA trực tiếp để kiểm phục hồi online; kết quả đang chờ và sẽ cập nhật dưới đây. Không tự gửi lại credentials. Không sửa source/test thêm; tổng3/5 authoredfiles,2/3repairrounds. Source checks/analyzer715tests/build là kết quả checkpoint bảnB91, không chạy lại và không thay native evidence. Lượt tiếp tục hiện24/25calls, còn1call dành cập nhật kết quả/kiểm report. Giữ nguyên history/dirty/untracked/Owner files; staged diff chưa có thay đổi.

### Đợt1 — CHECKPOINT 25/25: phục hồi online FAIL, chưa nghiệm thu xong

Owner trả lời sau khi mạng5554 được phục hồi: 'nó vẫn hiện không thể hoàn tất xác thực trước khi bấm đăng nhập và sau khi đăng nhập thì vẫn bị lỗi không thể hoàn tất xác thực'. Tách bằng chứng thành (1) thông báo cũ hiện trước lần submit mới, và (2) sau lần submit mới vẫn có lỗi; KHÔNG coi thông báo trước submit là kết quả của request mới. Không có xác nhận HomeA sau phép thử offline/recovery. AUTH02 nhánh ONLINE RECOVERY hiện FAIL theo native observation Owner; timeout thật vẫn CHƯA KIỂM. Thông báo generic không xác định lỗi SDK, transport, subject authorization hay lifecycle/publication.

Chưa xác định root cause. Wi-Fi=1/mobile_data=1/delay0 là trạng thái cấu hình đã kiểm, không tự chứng minh DNS/route/Auth server reachability hay request đã được gửi thành công. Không suy token bị xóa, tài khoản sai/hết hạn/thu hồi, hoặc lỗi do bản sửa loading. Không chữa bằng tự giữ Account, tự gửi lại credentials hay bỏ guard. Thông báo cũ còn hiện là finding riêng cần phân tích với kết quả submit mới.

Ma trận cuối lượt:
| Ca | Trạng thái | Bằng chứng/giới hạn |
| AUTH01 | BLOCKED phần đối chiếu late-success SDK trên B91 | Owner native xác nhận pending -> Guest, không tự Account trong30giây, form mới nhập được/không null, explicit login mới vào HomeA. Finding stuck-loading sửa và native Owner retest đạt. Trace successful-late completion trên bản B91 chưa đối chiếu độc lập do automatic approval review timeout; trace E2 và regression không được chuyển thành native B91 PASS. |
| AUTH02 | FAIL | Native Owner offline submit báo lỗi -> Guest dùng được; sau phục hồi cấu hình mạng, fresh submit vẫn lỗi. Không đạt online recovery. Actual timeout chưa kiểm. |
| AUTH03 | BLOCKED | Chưa có expired/unrecoverable session fixture và reason evidence thật; không thay clock/TTL/config. |
| AUTH04 | BLOCKED | Chưa có safe independent exact-session revoke trong quyền hạn; local logout không thay phép thử này. |

Trạng thái cuối:5554 installed MAIN stagingB91CA7E8B716E4D2B71569C2FD68CC4F1FB4590E88D97870708104FE5C64A0A5, Owner hiện báo lỗi ở luồng đăng nhập, KHÔNG xác nhận HomeA; không dump UI/EditText vì credentials có thể còn trên form. Network cuối được kiểm wifi1/data1, delay0/unlimited; không có thay đổi mạng sau đó.5556 giữ nguyên/không cài hay sửa phiên, UI hiện tại chưa kiểm. Hash macOS Owner vẫn A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74 ở lượt kiểm24. Dirty/untracked/Owner files preserved, không stage/commit/push/merge/deploy/applyDB/dependency/native/permanent config change.

Changed lượt này: chỉ cập nhật report này và cài đè/QA5554; không sửa source/test. Tổng authored files của đợt vẫn3/5, repair rounds2/3. Source evidence giữ nguyên checkpoint: expanded regression RED->GREEN, analyzer sạch,715 full testsPASS/concurrency2, buildB91/main/x86_64; không suy thành native recovery PASS. Superpowers OFF trong lượt điều khiển emulator; không subagents.

Budget Guard: lượt tiếp tục kết thúc25/25 outercalls (kể cả waits/approval timeouts/questions), trước đó50calls đã dùng ở checkpoint sửa. Không đặt lại counters file/vòng sửa. Dừng tại đây; Đợt1/P3.2/DNY NOT ACCEPTED. Automatic approval review hai lượt đọc log/đối chiếu bị hết deadline trước thực thi; không phải kết luận unsafe, không có native trace từ các lệnh đó. Lệnh network-only sau đó thực thi được.

Next actions được giao tiếp tục: thu evidence reason-code/boolean an toàn cho fresh failed login sau offline -> kiểm actual Auth connectivity, SDK sign-in outcome -> lifecycle prepare/subject verification/binding -> publish/navigation. Phân biệt stale error UI với fresh-submit failure. Không đọc credential storage/token/password/dump EditText. Nếu cần đăng nhập, Owner nhập trực tiếp. Nếu tìm được lỗi source, TDD trước, minimal fix trong remaining1 repair round và2 file slots (ưu tiên file đã dùng), analyzer/fulltests/main staging build/hash/install-r/native retest. Không hỏi duyệt lại P3.2; cần cấp tiếp calls sau Budget Guard trước khi điều tra tiếp. Không lặp lại conflict repair hay mở A-B/V1/form scope.

Lesson Candidate: thông báo generic và network toggles không chứng minh nguyên nhân request -> ghi riêng lỗi cũ/lỗi submit mới và xác minh đường đi Auth thực -> nghiệm thu recovery phải có lần đăng nhập mới thành công sau phục hồi mạng.

## 2026-10-18 — Đợt1: xác định lỗi SDK, sửa lỗi thông báo cũ, retest native CEDE

Scope giữ Đợt1/testA, Codex-only/no subagents. Owner yêu cầu tiếp tục; lượt này giữ trần mặc định25calls, không đặt lại authoredfiles/repairrounds. Superpowers không invoke trong lượt này; OFF khi code/emulator. Dùng hướng dẫn Supabase cho phân tích Auth; SDK pin gotrue2.27.2/supabase2.16.1 chỉ đọc, không upgrade. AGENTS/rules/workflow/plan/checkpoint đã đối chiếu; Git codex/phase-3-discovery-design @cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa, dirty/untracked được giữ.

### Bằng chứng phân biệt SDK với lifecycle và thông báo cũ

1. Đọc safe fixed-stage log thành công trong lượt này, không dump credentials. Lượt phục hồi trước22:11:17.038 bắt đầu -> prepare70ms -> authentication_sdk1809ms tại22:11:18.918, không có foreground_wait/account_authorize theo sau. Vì vậy failure thuộc lần gọi SDK trước authorization, không đủ căn cứ đổ cho lifecycle/publication.
2. Query Supabase unified logs READ-ONLY, chỉ stagingbkocylxbuyvdgxccpixx, cửa sổ2026-10-18T15:11:10Z..15:11:30Z (22:11giờVN). Chỉ đọc source/count, TÊN keys metadata rồi whitelist status/error_code và boolean path/grant; KHÔNG đọc request body/headers values/email/userID/token/password. Đúng cửa sổ có1auth_logs+1edge_logs: password_grant=true, /token=true, authstatus400/error_code=invalid_credentials; edge /auth/v1/token=true/status400/x_sb_error_code=invalid_credentials. Request được server từ chối; không kết luận Owner nhập sai trường nào hay token bị xóa. Mã lỗi tham chiếu official https://supabase.com/docs/guides/auth/debugging/error-codes . Không apply DB/config/Auth mutation qua connector.
3. Host public health401 (phản hồi endpoint); sau kiểm tra lại với nc-q1, emulatorTCP443exit0/DNSresolved=true/routePresent=true/validatedNetwork=true. Probe nc-q0 trước đóexit1 không được diễn giải thành chứng cứ mất mạng. Không packet capture hay đọc storage.
4. Owner xóa trắng/gõ lạiA trực tiếp và xác nhận đăng nhập được trên B91. Native Codex Home=True/GuestGreeting=False/LoginForm=False, safe trace22:19:26.573 prepare101ms -> SDK2049ms -> account_authorize237ms tại22:19:28.963. Điều này supersede trạng thái phục hồi còn FAIL trước đó cho lần thử hợp lệ này; lần400 trước vẫn giữ lịch sử, không biến thành PASS.
5. Thông báo TRƯỚC submit là finding riêng có root cause source: guarded continueAsGuest không clear _errorMessage trong khi UI form mới render cùng provider.errorMessage. Legacy Guest đã clear. Không cần thay quyền/SDK/lifecycle để giải quyết lỗi hiển thị này.

### Repair round3/3 — lỗi cũ không được mang sang form mới

Files (vẫn3 authoredfiles tổng cộng): auth_provider.dart thêm đúng _errorMessage=null trong guarded continueAsGuest; test/auth_navigation_test.dart thêm mock password400invalid_credentials và regression failed_login_guest_exit_clears_error_on_reopened_form; report này cập nhật. Không thay assertions cũ. Regression giữ lỗi hiện sau thất bại/không Account -> Guest xóa lỗi -> form mới sạch -> chỉ response đăng nhập mới hợp lệ mới publish ownerA. Guard/SDK queue/epoch/subject/session checks không đổi.

TDD RED trước sửa: Expected:null Actual:'Không thể hoàn tất xác thực tài khoản.' tại Guest transition. Sau1line fix, GREEN +1PASS. Dart format0filechanges. flutter analyze --no-pub sạch6.1s; full flutter test --no-pub --concurrency=2 --reporter expanded ->716PASS89s. Không skip/assertion giảm. Full suite bao gồm late-callback/refresh/ownership regressions. Một lệnh build bị chặn vì agent gõ nhầm đường dẫn staging-defines; không tạo APK mới từ lệnh lỗi. Đã xác minh đường dẫn đúng, rerun CHỈ build với lib/main.dart/debug/android-x64/existing defines: thành công14.9s. Không sửa SDK/config, không tạo file defines mới.

MAIN staging SHA256 CEDEBB1145B6C37B09E62D54987514563FF5A3C6C6804DA7B0B7D8F137724B45. Install-r thành công chỉ5554, installed base.apk hash khớp. MainActivity COLD launch thành công5417ms. Không clear/uninstall/wipe/reset. Safe startup trace sdk_valid=true/registry=active/active_online=true, active_server_verified=true. Owner chỉ xác nhận đã ở form trống khi được yêu cầu logout/mở login; KHÔNG suy ra một lần PHONE03 cold-HomeA acceptance mới từ timing hoặc câu trả lời thiếu bước đó.

### Native retest bản CEDE — stale-error fix + offline/recovery ĐẠT trong phạm vi này

- Owner chuẩn bị form trống khi ONLINE; Codex sau đó tắt wifi/data, đọc0/0. Owner nhậpA trực tiếp, submit báo 'Không thể hoàn tất xác thực tài khoản', chọn Guest -> mở lại form, xác nhận đã HẾT thông báo lỗi cũ. Đây là native repro của stale-error finding, không chỉ unit test.
- Khôi phục delay none, Wi-Fi/data enable; đọc xác minh1/1, console latency0ms/unlimited. Không tự retry credentials.
- Owner nhập đúngA trực tiếp trên form sạch và trả lời: 'có vào home a và không hiện lỗi'. Codex sau xác nhận này mới đọc UI safe booleans: FinalHome=True; FinalGuestGreeting=False; FinalLoginForm=False. Không dump login EditText/private trip list.
- Current process9336: offline SDK75ms tại22:24:54.383 (generic failure, không gọi timeout); retry22:32:02.775 prepare103ms -> SDK2197ms -> foreground_wait4ms -> account_authorize229ms tại22:32:05.311, cộng OwnerHomeA+UI booleans xác nhận publication/navigation. Timing riêng không được coi là PASS.
- Finding thông báo cũ trước submit: FIXED/NATIVE VERIFIED trên CEDE. Offline -> error -> Guest -> clean login -> online recovery đã PASS theo đúng luồng này. Không suy timeout, expired/revoked từ lỗi generic.

### Bổ sung AUTH01: gỡ blocker đối chiếu trace B91

Đã đối chiếu safe process8054/B91: SDK cũ21:59:54.094 -> hoàn tất22:00:07.116 (13021ms), đúng fixed SDK_local_signout22:00:07.117, không foreground_wait/account_authorize cho attempt đó. Source chỉ chạy obsolete-success local-signout sau SDK success khi generation cũ đã bị Guest hủy. Owner trước đó đã xác nhận chọn Guest khi pending, không tự Account trong30giây, form mở lại nhập được và explicit new loginA thành công. Attempt mới22:01:05.959 -> SDK22:01:18.653 -> account_authorize22:01:18.986. Vì vậy AUTH01 luồng native đã chạy trên B91 có đủ bằng chứng late-success cleanup, không còn blocker log trước đây. Không gán trace này cho CEDE; CEDE chỉ sửa clearerror, các guards giữ nguyên/716testsPASS, và native error->Guest->fresh-login ở trên. Không lặp riêng pending-late-success trên CEDE trong lượt này.

| Ca | Trạng thái cuối/phạm vi bằng chứng | Còn thiếu |
| AUTH01 | PASS cho native pending->Guest->late-success cleanup->newA trên B91, từng bị BLOCKED trace nay đã đối chiếu. Native CEDE error->Guest->freshA đạt, guard regression PASS. | Chưa lặp riêng pending-late-success trên CEDE; không coi trace B91 là trace CEDE. |
| AUTH02 | BLOCKED phần timeout; nhánh offline/error/Guest/form sạch/online recovery PASS native CEDE. Lần400invalid_credentials đã giải thích bằng server evidence, không giữ kết luận app không thể recovery. | Actual timeout với bằng chứng reason riêng chưa chạy; generic error/45giây/delay12giây không thay thế. |
| AUTH03 | BLOCKED | Chưa có fixture naturally expired/unrecoverable và reason evidence thật; không đổi clock/TTL/Auth config. |
| AUTH04 | BLOCKED | Chưa có phương thức thu hồi độc lập đúng1session trong quyền hạn; không đọc token/storage, không global revoke/DB apply. Local logout không phải acceptance thu hồi từ ngoài. |

Kết luận: đã sửa/native retest2finding loading và stale-error trong Đợt1, offline/recovery nhánh hợp lệ đạt; Đợt1 toàn bộ/P3.2/DNY vẫn NOT ACCEPTED vì ca bắt buộc còn thiếu. Không co715/716tests hoặc trace timing thành nghiệm thu thiết bị. Không có điện thoại thật.

Final state đã kiểm:5554 HomeAccountA theo Owner + safe UI, installed mainCEDE..., wifi1/data1, delay0/unlimited.5556 không đổi app/phiên/UI trong lượt này; chỉ kiểm network1/1/delay0 và installed hashE2BC894D0F8743D55E82ED2BFC74BBC031C5EDF7985F19E77ABE24652F469D70, không khẳng định UI Account hiện tại khi chưa nhìn. MacOS Owner hash giữ A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74. Staged diff empty, scoped diff--check sạch. Không stage/commit/push/merge/deploy/applyDB/SDK/dependency/native/permanent-rule changes; protected Owner files/docs/superpowers không đọc/sửa.

Budget kết thúc sau kiểm report:24/25 outercalls cho lượt tiếp tục này, tổng authoredfiles vẫn3/5, repairrounds3/3 ĐÃ ĐẠT NGƯỠNG. Không tự mở vòng sửa4. Checks/build/native cần thiết của round3 đã xong. Không mở sang B/V1/form/timeline/conflict repair. Không có long-running session còn chờ.

Next: chỉ tiếp tục QA/thiết kế phương thức tái hiện actual timeout, naturally expired/unrecoverable và exact-session revoke trong quyền hạn hiện có; giữ BLOCKED/CHƯA KIỂM cho tới khi có fixture/method thật. Nếu cần sửa source thêm phải Owner mở thêm repair budget; không tự reset3/3 hoặc dùng instrumentation để né giới hạn. Native pending-late-success nếu cần re-run theo exact latest hash phải ghi version rõ. Không hỏi duyệt lại plan P3.2.

Lesson Candidate: generic UI error dễ khiến nhầm offline recovery với server từ chối thông tin đăng nhập -> đối chiếu safe status/code trong cửa sổ request và tách error cũ/error mới -> chỉ xóa lỗi hiển thị khi Owner rời flow, giữ nguyên guard và yêu cầu login hợp lệ mới để publish Account.

## 2026-10-20 — C2 key rotation, staging rebuild, PHONE03 emulator retest

**PARTIAL / NOT ACCEPTED.** No product source or test edit in this continuation. The staging publishable key embedded in the previous APKs had been rotated/revoked: the gateway returned `401 UNAUTHORIZED_INVALID_API_KEY`; a missing key returned `UNAUTHORIZED_MISSING_API_KEY`. Owner saved a replacement staging key outside the repo at `C:\Users\ASUS\.config\travelgo\staging.defines.json`; `/auth/v1/health` returned `200`. The key value is not recorded here.

- Rebuilt only the APK artifacts:
  - `.dart_tool/p32-c2-main-x64-debug.apk` SHA256 `B659857F500094F8B0AECC3E011A7CECC3C479099B498271F1D1C5EDB31AAD3B`
  - `.dart_tool/p32-c2-main-arm64-profile.apk` SHA256 `0AC26ADFCE52C350BAFF73A88923F16021AE6B6EE9229A5B922E4B6CD3F2BDE6`
  - Exact key present; receipt probe absent; x64 engine `x86_64`; profile contains `arm64-v8a/libapp.so` and only staging URL. Debug contains both URL constants from source, as expected.
- `install -r` succeeded on both devices. Installed `base.apk` hashes match the build artifacts exactly. No clear/uninstall/wipe.
  - `5554` installed hash `B659...AD3B`; `firstInstallTime=2026-09-26 16:51:39`; local DB observed `139.264 bytes` before account switching.
  - DNY installed hash `0AC26...BDE6`; `firstInstallTime=2026-10-20 10:27:14`; DNY data preserved.
- PHONE03 exact interrupted-cold retest on `5554`/debug C2 with valid Account B:
  - force-stop → launch without `-W` → HOME after `301 ms` → wait `1568 ms` → resume.
  - Safe logs: `sdk_valid=true registry=active active_online=true`; `active_server_verified=true`; `startup_resume 2149ms`.
  - UI after resume: `testb=true`, `testa=false`, `Đăng xuất=true`, `Đăng nhập=false`, Guest greeting=false. PID remained `8569`.
  - **PASS for the exact interrupted-cold emulator case**, including no Guest fallback and no Account A exposure. This does not replace the DNY device case or the source negative suite.
- DNY C2 remains **BLOCKED**: keyguard `showing=true`, `mIsShowing=true`, focus `AOD`; no login or native PHONE03 observation was possible. No attempt to bypass the lock.
- D matrix and E/F evidence remain not started. P3.2 remains **NOT ACCEPTED**; this section does not close DNY, offline/USB, expiry/revoke, two-session, a11y, D1–D5, or Owner visual signoff.
- Evidence log: `.dart_tool/p32-c2-phone03-exact-emulator.log`. Build/install logs: `.dart_tool/p32-c2-build-x64.log`, `.dart_tool/p32-c2-build-arm64.log`, `.dart_tool/p32-c2-install-5554.log`, `.dart_tool/p32-c2-install-dny.log`.
- Next: Owner unlocks DNY; pull/verify installed hash, login test A/B, run the same interrupted-cold sequence, then continue D1–D5.

## 2026-10-20 — DNY unlocked, PHONE03 DNY PASS, D3 two-session conflict PASS/PARTIAL

**PARTIAL / NOT ACCEPTED.** This section supersedes the DNY-blocked status above only for the DNY device case. No product source or test edit in this continuation.

- DNY blocker resolved by the Owner: keyguard `showing=false`, wireless ADB connected. Installed C2 `base.apk` re-pulled and matched `0AC26...BDE6`; `firstInstallTime`/data preserved. Baseline `1264x2736`, density `560`, font `1.0`, Wi-Fi/data on.
- Owner authorized direct credential entry for the test accounts; no credential/token was recorded. DNY logged in as test A. `5554` was switched from B to A via logout/login (no clear/uninstall); both sessions then used the same Account A. `5556` remained untouched.
- PHONE03 exact interrupted-cold on DNY/profile C2:
  - `force-stop` → launch without `-W` → HOME after `584 ms` (ADB command latency; still before restore) → wait `1816 ms` → resume.
  - After `10 s`: Home `testA=true`, `Đăng xuất=false`, `Đăng nhập=false`, Guest=false; Profile `testA=true`, `testB=false`, `Đăng xuất=true`, `Đăng nhập=false`, Guest=false.
  - No profile stage logs were emitted. **PASS for the exact interrupted-cold DNY case**, no Guest fallback and no Account B exposure. Evidence: `.dart_tool/p32-c2-phone03-exact-dny.log`.
- D3 two-session conflict on the same Account/fixture `P32CONFLICT_WIN_1810_R4`/server version4:
  1. `5554` saved winner `p32conflict_win_1810_r5` from version4; save acknowledged; server version5.
  2. DNY opened its editor from version4, prepared stale `p32stale_1810_r5`, and sent the save once. It received the exact warning `Chuyến đi đã có phiên bản mới. Các chỉnh sửa của bạn vẫn được giữ.`; no Retry was sent; the stale title remained after returning to the editor.
  3. DNY server reload then showed `p32conflict_win_1810_r5`/version5 and no stale title. **PASS for stale save cannot overwrite.** Evidence: `.dart_tool/p32-d3-two-session-conflict-dny.log`.
- D3 is **not fully closed**: main-UI lost-reply/retry still needs an audited test-only response-loss hook (the existing native probe is not main UI), and V1 read/copy still needs an Owner-designated exact synthetic V1 fixture/source. Network-off is not a substitute for post-commit loss. No hook or V1 fixture was created here.
- D1/D2/D4/D5, E/F, DNY offline/USB, expiry/revoke, a11y/perf and Owner visual HomeA/PlannerB remain open. P3.2 remains **NOT ACCEPTED**.

## 2026-10-20  E D3 main-UI lost-reply on 5554 PASS; DNY pending unlock

**PARTIAL / NOT ACCEPTED.** This section records a test-only QA hook and one emulator PASS; it does not close D3 on DNY or any other matrix row.

- Test-only source added: `lib/core/testing/p32_drop_committed_reply_adapter.dart`; `lib/main.dart` injects it only when `TRAVELGO_P32_DROP_UI_REPLY=true`. The adapter matches `update_editable_trip_v2` with target title `P32_UI_1810_A`, drains the first real successful response after server commit, then raises `receiveTimeout`. Normal builds do not install the adapter.
- QA APK: `.dart_tool/p32-d3-main-ui-reply-loss.apk`, SHA256 `FFC49F9E4201E4667644E24B0F11D4E5D5CA10CEABF4FCA195387258279FB56A`; installed `-r` on `5554` and DNY without clear/uninstall.
- `flutter analyze --no-pub`: `No issues found!`; `flutter test --no-pub`: `766` PASS, `All tests passed!`.
- `5554` Account A, existing synthetic `P32LOSTREPLY_1810_01`/version1, changed title to `P32_UI_1810_A` through the real main UI:
  1. First save produced logcat `10-20 15:16:34.307 ... [P32 UI reply] committed_response_dropped=true`.
  2. UI showed `Chưa xác nhận được kết quả lưu. Thử lại sẽ dùng đúng yêu cầu đã gửi.` and `Thử lại lần lưu trước`.
  3. One Retry produced no second drop marker; uncertainty cleared.
  4. Detail showed `P32_UI_1810_A`; `Kiểm tra lại` displayed `Đã kiểm tra với máy chủ · phiên bản 2`.
  - **PASS for main-UI post-commit response loss + Retry on `5554`**, version advanced `1 -> 2`, no duplicate create observed. Evidence: `.dart_tool/p32-d3-main-ui-reply-loss-emulator.log`, `.dart_tool/p32-d3-main-ui-reply-loss-emulator.png`.
- DNY result after Owner unlock/login:
  - First QA install used the x64 APK and crashed with `MissingLibraryException: libflutter.so ... only found x86_64`. Fixed by building/installing the arm64 profile QA APK `6A033946...ACB9A`; app data/`firstInstallTime` remained intact.
  - DNY opened existing `P32_UI_1810_A`/server version2, changed title to `P32_UI_1810_A_DNY` through the main UI. First save showed the same uncertain message; `Thử lại lần lưu trước` succeeded; server check showed `P32_UI_1810_A_DNY`/version3.
  - The profile build does not expose the QA adapter `debugPrint` line in logcat; post-commit loss is evidenced by the uncertain UI plus server version `2 -> 3` after retry.
  - **PASS for main-UI post-commit response loss + Retry on DNY.** Evidence: `.dart_tool/p32-d3-main-ui-reply-loss-dny.log`, `.dart_tool/p32-d3-main-ui-reply-loss-dny.png`.
- C2 restored with `install -r`: `5554` hash `B659...AD3B`; DNY hash `0AC26...BDE6`; both match artifacts and retained data.
- No commit/stage/push/merge/deploy; no production config change. P3.2 remains **NOT ACCEPTED**; D3 V1 and the remaining matrix are still open.
