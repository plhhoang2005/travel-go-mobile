# Phase 2 checkpoint — updated 2026-10-15

Codex-only continuous work. No subagents/Docker. Superpowers was used for the
earlier completion plan; implementation/verification here is ordinary tooling.
Owner reviews/merges PRs; database deployment is separately target-approved.
The six protected Owner paths and prior untracked review documents stay untouched.

## Observed source and verification

Main after B8 PR #31: `522c0d1958434c844302fdbff20872fd85e60e7c`.
PR #28 merged B6.3; #29/#30 originally merged into feature branches; #32/#33
promoted B6.4/B7 to main. Do not recreate or cherry-pick those source changes.

| Work | Source/review | Observed verification |
| --- | --- | --- |
| B9 | [PR #34](https://github.com/plhhoang2005/travel-go-mobile/pull/34), `0d6759ca0845840c577db7c4483d0aeb6571e5cb`, four files | Analyzer clean; 470 Flutter tests; 3 integrated FFI tests; native Android three launches/purge failure/owned cleanup and production app restore PASS; CI PASS. |
| C1 quota | [PR #35](https://github.com/plhhoang2005/travel-go-mobile/pull/35), `7b20d5bc5ffe2de274c0bee4f8a8c4d5dc1ea906`, five files | Native PostgreSQL SQL/role/rollback/midnight/refund/expiry and session races PASS; native/Flutter CI PASS. Staging bootstrap Owner-reported; 2026-10-15 Codex independently verified live ACL/RLS/caps and real-role quota/retry/refund behavior. |
| C2 gateway | [draft PR #36](https://github.com/plhhoang2005/travel-go-mobile/pull/36), `81c8874627cd36ed8bc378b293913d1a53cbf6d3`, five files, stacked on C1 | 20 core tests and CI PASS. Codex staging C3 technical acceptance PASS on 2026-10-15 with temporary synthetic-only entrypoint config; original reviewed bytes restored and hosted disabled. Language-quality caveat below; real-user runtime integration is not claimed. |
| Catalogue | Independent `codex/phase-2-catalogue-readiness` source unit, five files | 12 approved IDs, 72 named source references and 12 authored examples; unknown operational fields preserved. Exact PR/CI supplied at handover. Not runtime publication. |

Local test logs/output are observed by Codex. The earlier B3 extended native
staging controls were Owner-reported and separately recorded in
`R06_IMPORT_CONTRACT.md`; do not relabel them as this turn's new live execution.

## Concrete Owner gates before live closure

1. Review/merge #34 and #35 into main (independent). #36 remains draft so it cannot
   accidentally merge into its feature base. After #35 merges, Codex retargets
   #36 to main, confirms its five files/CI and marks ready. Catalogue is independent.
2. Staging-only approval received: "Duyệt thử trên staging, chưa thay đổi bản
   chính." Owner reported exact-target/absent-schema preflight and C1 apply/ACL
   postconditions PASS using pinned #35 bytes. Do not rerun bootstrap or infer
   schema absence now. This is Owner-reported authenticated evidence; independent
   authenticated schema/grant reconciliation was completed by Codex on 2026-10-15.
   No primary apply.
3. Completed staging setup: Owner saved the Gemini key privately in server
   Secrets and confirmed the no-billing/free-tier choice. Do not paste the key
   into chat/logs or Flutter. Codex observed
   actual model HTTP 200 and structured replay on 2026-10-15; key never retrieved.
4. Staging deployment is approved and Owner-reported complete with AI disabled.
   After private key/free-tier/test-subject setup, use the same approved staging
   scope for synthetic allowlisted acceptance. Keep SYNTHETIC_ONLY=true; enable
   only with a verified test-subject allowlist. Verify Auth/output/retry/refund;
   never switch to paid/private mode implicitly. No repeated staging approval.
5. Primary B3 on `oavbymauorhmrjcustzw` remains NOT APPLIED. Use its existing
   staging evidence, target preflight and separately approved rollout. The prior
   Owner-accepted backup/restore rehearsal boundary is unchanged; no new
   production restore rehearsal gate is invented here.

The source and local/CI checks above are concrete reviewable results. Merge,
staging secrets and target-specific apply are Owner-controlled operations, not
substitute PASS labels. No paid service was provisioned.

## Still open / phase boundary

- Continuous production mobile UI/auth-to-staging import, real A/B logout,
  offline recovery and remote re-download remains NOT RUN. B9 native probes
  use synthetic sessions and an isolated store; FFI remote transport is controlled.
- Hosted disabled function responds as independently observed by Codex. Enabled
  synthetic Auth/receipt/quota/Gemini route passed on 2026-10-15. Free-tier status
  is Owner-confirmed, not an independent billing-console audit. Source gate
  rejects real private/free-text context. Actual
  privacy consent/retention and account policy need deployment decisions before
  enabling real users; no personal data was sent during this work.
- Catalogue operational location/price/opening/travel data and runtime use are
  not verified; licence/distribution not declared cleared. Preparing the source
  names/examples is not a claim of AC-052 runtime PASS.
- Instructor submission rubric/checklist is still OPEN. Owner must supply actual
  course requirements; Codex will map existing artifacts without reading the
  protected presentation/Word/script assets.
- Manual itinerary/expense editing and the functional AI modules are Phase 3;
  do not claim AC-012/018/020/052 from a readiness gateway/data file.

Phase 2 is **source-prepared in the listed areas; not fully closed/deployed**.
Continue live verification after the required Owner actions. Prefer resuming
from these exact PR heads instead of redoing earlier approvals or implementations.

## Staging execution checklist and subsequent bootstrap evidence

Target is **travel-go-staging / bkocylxbuyvdgxccpixx**, never inferred from the
currently selected dashboard tab. Confirm the project ref/connection host before
any statement. Browser/native computer-use initialization failed (`failed to
write kernel assets`, path not found). The original checklist below was NOT RUN
when prepared; subsequent Owner execution of the pinned local helper is recorded
at the end of this document. The original metadata SQL below is a reference,
not a claim that Codex executed authenticated queries on staging.

Read-only SQL, no application rows or function secret literals exported:

```sql
SELECT current_database(), current_user, version();
SELECT rolname, rolbypassrls FROM pg_roles
WHERE rolname IN ('anon','authenticated','service_role');
SELECT nspname, nspacl FROM pg_namespace WHERE nspname IN ('private','private_ai');
SELECT n.nspname, c.relname, c.relrowsecurity, c.relacl
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'private_ai' AND c.relkind = 'r';
SELECT n.nspname, p.proname, p.prosecdef, p.proconfig, p.proacl,
       md5(pg_get_functiondef(p.oid)) AS body_hash
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname = 'private_ai') OR
      (n.nspname = 'public' AND p.proname IN
        ('reserve_ai_request_v1','finalize_ai_request_v1',
         'import_guest_draft_v1','get_import_trip_snapshot_v1'));
```

The bootstrap is now Owner-reported complete; do not apply this migration again.
If private_ai already exists, inspect and compare it to reviewed C1 source;
do not reapply blindly or drop it. After explicit staging approval, apply only
`supabase/migrations/202610130001_ai_quota.sql` from reviewed #35, transactionally.
The migration refuses an existing private_ai schema. Capture postconditions:
private schema/tables/helpers denied to anon/authenticated/service_role directly,
only the two public quota RPCs executable by service_role, no grants to clients,
definer search_path empty, settings Guest/account=3 and global attempts=20.
Do not run local fixtures that create database roles against Supabase.

Gateway source is #36; after source review/merge, deployment uses an available
Supabase CLI authenticated privately by Owner:

```text
supabase functions deploy ai-request --project-ref bkocylxbuyvdgxccpixx
```

CLI/runtime installation and real Edge execution are not claimed from Node tests.
Review `supabase/config.toml`: platform JWT decoding is disabled only for this
function; every enabled request is checked against the trusted project Auth /user
endpoint. Keep gateway disabled until this exact target/handler is verified.
Standard project environment supplies SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY.
Owner enters GEMINI_API_KEY in server Secrets privately. Additional safe readiness
settings are TRAVELGO_AI_ENABLED=true, TRAVELGO_AI_SYNTHETIC_ONLY=true and
TRAVELGO_AI_ALLOWED_SUBJECTS=<verified staging test UUID>. Do not place secrets
in Flutter, PR bodies, command history or chat. Confirm the API project has no
paid billing enabled and `gemini-3.5-flash-lite` is available on that actual key.

Synthetic live acceptance must observe all of:

- Missing/rejected bearer denied before provider; non-allowlisted verified subject
  denied; private/unknown fields rejected; server subject/classification used.
- A safe minimal synthetic context returns Vietnamese structured output with
  AI/unverified/model labels. No trip row changes or Decision Engine recompute.
- Same request UUID/context replays the same stored result without another charge.
  Guest fourth logical request is denied by the database; a forced unusable model
  result refunds user reservation while the global attempt budget remains bounded.
- Interrupted response is recovered by the same identity; do not manually reset
  quotas as part of retry. Complete tests under owned synthetic subject IDs and
  remove only those test subjects/results after inspecting ownership.

On deployment failure or uncertainty, set TRAVELGO_AI_ENABLED=false. Preserve
quota data for review; prefer a scoped forward fix rather than destructive drop.
No synthetic PoC permits real-user/private-context enablement or primary rollout.

Lesson Candidate: source, local tests, CI, native primitive tests and live user
acceptance are distinct evidence levels. Keep each level's identity/target and
limitations explicit when deciding whether a phase can close.

## Staging bootstrap outcome — 2026-10-13

Owner returned these safe output lines (no credential was provided to Codex):

```text
C_STAGING_TARGET_AND_ABSENT_SCHEMA_PREFLIGHT_PASS
C1_STAGING_MIGRATION_AND_ACL_POSTCONDITIONS_PASS
C2_STAGING_DISABLED_DEPLOYMENT_METADATA_PASS
C2_STAGING_HOSTED_DISABLED_GATEWAY_PASS
C_STAGING_BOOTSTRAP_PASS_GEMINI_STILL_DISABLED
```

The helper checks SHA-256 of the exact #35 migration and #36 index/core bytes,
refuses existing schema/RPC/function, applies only quota SQL, checks effective
ACL/RLS/definer settings and caps 3/3/20, then deploys with enabled=false and
synthetic-only=true. All authenticated bootstrap results above are Owner-reported,
not relabeled as Codex-run. Its postcondition SQL separately passed on Codex's
owned local PostgreSQL fixture, with owned shutdown/cleanup PASS.

Codex independently sent POST {} with a deliberately invalid bearer to:
https://bkocylxbuyvdgxccpixx.supabase.co/functions/v1/ai-request
Observed HTTP 503 and JSON status deployment_blocked, exit 0, at
2026-10-13T13:28:03.2221927Z (20:28 Asia/Saigon). This proves the hosted disabled
handler response only; it does not verify live ACLs, enabled Auth, model access,
quota/replay/refund, no-billing tier, or Vietnamese Gemini output.

Next Owner-only action: create/use a no-billing Gemini API project and privately
save GEMINI_API_KEY in staging Edge Function Secrets. Keep enabled=false until
test-subject setup and actual free-tier status are confirmed. Do not resend PATs,
keys or password screenshots, enable billing, or rerun ExecuteStaging bootstrap.
Primary unchanged by this approved staging-only operation; Phase 2 is still open.

## C3 live acceptance prepared — key saved by Owner

Owner confirmed "Đã lưu key Gemini trên staging." No key was sent to Codex and
the key value/model eligibility has not been independently verified. Key-creation
UI showed Default Gemini Project Free tier; live runner requires Owner to confirm
the actual key's project still has no paid billing.

Four-file private local helper prepared at the current chat's visualization root,
under C_AI_LIVE (probe.mjs, probe.test.mjs, RUN_LIVE.ps1, README.md). These files
are test orchestration artifacts, not a gateway redeployment or mobile change.
Runner needs existing staging-only PAT and staging Publishable key privately on
stdin; Gemini key is read only by the deployed server. PAT permissions unchanged.

It verifies target/deployment/key-name/caps and disabled state, creates two freshly
owned anonymous Auth test subjects (requires existing anonymous sign-ins; does not
change Auth configuration/bypass CAPTCHA), checks both with trusted Auth /user,
and temporarily allowlists only A. It tests missing/forged bearer, B/private field
denials, and denied Guest direct quota RPC. At most one real Gemini request is
dispatched; its completed response body is discarded and identical retry must
match the stored result with one charge. Two real service-role RPC reservations
fill the other slots; fourth gateway request must return 429, then RPC failure
acks refund those two user slots while global attempts remain counted. Finally,
independent actions disable AI, clear the allowlist and delete only nonce-owned
test Auth/ledger/usage rows, refusing non-Guest ownership or any trips. Known
subject ledger/usage absence is checked after cleanup. No reset of global budget.

Local evidence: launcher SelfTest 18/18 PASS; Node syntax PASS. PostgreSQL 18.6
native fixtures executed exported service-role RPC SQL (reserve/refund/role reset)
and exact cleanup predicates (non-Guest/trip refusal with atomic rollback, scoped
delete preserves other subject/global count), followed by owned shutdown/cleanup
PASS. Cleanup fixture represents only the needed Auth/trip columns, not the actual
Supabase Auth runtime/schema. No Flutter source changed; analyze/test NOT RUN in
this documentation/helper unit. Live C3 acceptance remains NOT RUN.

Limits: discarded completed reply is not an in-flight socket/worker cancellation
test; RPC failure acks are not injected live Gemini 429/timeout. Actual provider
failure emits a separate refund marker if observed, and prevents full model PASS.
Owner reviews the synthetic preview for Vietnamese. Hard process termination can
interrupt finally; nonce is printed before signup for scoped recovery. Source
remains disabled until Owner executes this approved staging-only exercise.

## C3 local launcher troubleshooting — 2026-10-15

Owner reported C3_LOCAL_LAUNCH_STOPPED_NO_CREDENTIAL_OUTPUT, without live C3 PASS
markers. Root cause cannot be identified from that generic catch output. Codex
reproduced it using synthetic `3.` instead of FREE; this proves an ambiguous error
path, not that Owner entered that value. Existing Node runtime is available
(24.16.0). Independent staging smoke at 2026-10-15T02:21:32.6659458Z returned 503
deployment_blocked. C3 live/Gemini success remains NOT RUN/UNCONFIRMED.

Repaired only local launcher diagnostics/instructions: numbered Vietnamese prompts,
case-insensitive trimmed FREE confirmation, empty/invalid input checks before
child launch, fixed safe stage codes and explicit uncertainty after stdin handoff.
No exception message/token/key is printed. Added eight isolated child-PowerShell
controls (synthetic inputs, no child probe launch/network); combined launcher
SelfTest: 8 controls plus existing 18 Node controls PASS, exit 0. The test mock's
script-scope issue was corrected before final PASS. Gateway/database/probe.mjs
source unchanged. Flutter analyze/test NOT RUN (no Flutter source change).

Next: Owner reruns the updated RUN_LIVE.ps1, entering FREE at prompt 1 (if the
actual Gemini project has no paid billing), staging PAT at prompt 2 and staging
Publishable key at prompt 3. Report safe C3 lines, never keys. Child-state-unknown
markers require inspection before another run. Do not rerun migration bootstrap.

## C3 Auth signup block — 2026-10-15

Owner returned target/disabled/key-name/cap preflight PASS, then generic anonymous
signup unavailable and owned fixture cleanup PASS. Synthetic nonce:
b2558a37-bd2e-43b9-93d3-ddb93d3b20d6. It appears twice because the runner prints
it at start and on failure. The reported execution did not reach enable/provider
stages; cleanup remains Owner-reported. Gemini/enabled route/quota acceptance
has not passed. No actual Auth error HTTP/code was included by the old wrapper.

Codex found that all signup HTTP failures were masked as ANONYMOUS_SIGNUP_UNAVAILABLE.
Changed only the private helper transport to allowlist known Auth classifications
and preserve safe HTTP status, never raw messages/body/token/unknown code values.
Disabled anonymous Auth is a likely cause, not an established live finding. Other
classes cover wrong public key/Auth denial, signup disabled, CAPTCHA, rate limit
or Auth-server/trigger errors. Owner inspects anonymous sign-ins on staging before
changing that setting; if already enabled, the updated diagnostic is needed.
No Auth configuration, migration, gateway source, RLS or trigger changed here.

Verification is recorded with the local helper: diagnostic controls use synthetic
HTTP responses and check secret-marker exclusion; they are not a live Auth fix.
Next remains Owner's private staging execution after checking its Auth provider
setting. Do not enable primary anonymous Auth or infer Gemini-key success.

## Connected staging audit and bounded C3 attempt — 2026-10-15

This section supersedes the earlier pending-connection/unknown-Auth next steps.
Supabase connector is now authenticated. Codex independently verified project
bkocylxbuyvdgxccpixx = travel-go-staging, ACTIVE_HEALTHY, expected database host.
Public Auth settings initially returned anonymous_users=false; after Owner enabled
Anonymous on staging, GET /auth/v1/settings returned anonymous_users=true and
disable_signup=false at 2026-10-15T02:41Z. This confirms the previous Guest signup
block's cause. No primary Auth configuration was changed.

Independent cloud SQL checks PASS: quota caps 3/3/20, RLS on all four quota tables,
private schema/table/helper denial, and service-role-only public RPC ACL. Actual
role-switched RPC tests for reserve/retry/digest conflict/quota/refund/success replay
passed in a transaction that was rolled back. These are live staging database
checks, not mock results or a migration reapply. Previous failed C3 nonce
b2558a37-bd2e-43b9-93d3-ddb93d3b20d6 had zero Auth fixtures remaining.

The connector has deployment/SQL access but no secret-write API. A new private
native connector-worker.mjs held Guest JWTs only in process RAM and called public
Auth/gateway endpoints; no PAT, service-role key or Gemini secret value was read.
Its six offline controls passed, including identity validation, no private token
output, denied arbitrary commands, result whitelist and no repeated initial
provider dispatch. Existing private PAT helper remains an alternative.

Live synthetic nonce: 1e26df7d-f24c-4b8e-98f3-bc500575b23f. Two new Guest subjects
were independently verified via trusted Auth /user. Original deployed index/core
bytes matched reviewed source. Only staging entrypoint test configuration was
temporarily changed to enabled=true, syntheticOnly=true and allowedSubjects=[A];
the gateway core and all server secret reads were unchanged. Secret flag values
were not edited. This tests the reviewed gateway with explicit test configuration,
not normal enabling through environment-secret changes.

Observed PASS: missing/forged Bearer, outsider B, private field and Guest direct
RPC were denied; SQL confirmed zero request rows and no global charge afterward.
Exactly one real Gemini request returned HTTP 200, then its completed response
body was deliberately discarded. The worker's next replay-result collection did
not complete as expected and was interrupted. Do not infer that the server retry
failed or passed: no independently captured replay body/stored-result comparison
was obtained. The subsequent fourth-request and two-reservation refund checks
were NOT RUN in this attempt. Full C3 acceptance is NOT PASS.

Safety unwind independently verified: gateway restored to original exact two-file
contents, version 4, verify_jwt=false as before. Known original SHA-256 values:
index.ts 30724e7c7fd9bf2aba555617d0deb96ba973bd666295ac954eafa42cc1948a53;
gateway.mjs 0abf15c9ebf792e30cdf3184cd5bb016ca7e0e81fe3b02d6620c30a5047dc507.
Independent hosted POST returned HTTP 503 / deployment_blocked at
2026-10-15T02:50:24.4965869Z. Guarded nonce-owned cleanup returned users=0,
requests=0, usage=0; global attempts=1 retained. No trip data was written, no
primary migration applied, no merge performed. No credentials were stored in
these evidence files. Do not rerun bootstrap or reset the global budget.

Checkpoint: task tool budget reached; extra calls were limited to safe unwind and
recording verified state. Next diagnose native interactive worker result collection
before another enabled run; use a bounded noninteractive transport if needed,
retain credentials only in RAM, and recheck target/disabled/global budget first.
Do not ask Owner to resend a key/PAT or re-enable Anonymous: those are resolved.
No Flutter source changed; flutter analyze/test NOT RUN in this helper/docs unit.
Existing PR heads and CI are prior evidence, not new checks for this uncommitted
closeout update. Phase 2 remains open; no commit/push/PR change in this unit.

## C3 technical acceptance completed — 2026-10-15T02:57:14.134Z

This successful subsequent run supersedes the incomplete retry/quota outcome
above; the earlier failed attempt remains historical evidence. Helper transport
now uses framed loopback HTTP, rejecting browser Origin/missing local header,
serializing commands and expiring idle sessions. No terminal-screen parsing or
JWT persistence. Nine controls PASS, including long Unicode JSON roundtrip and
safe native-error output. Initial sandbox loopback EACCES was resolved by running
the same tests with network permission; no test assertions were weakened. The
previous live stall is localized to helper result collection; a unique terminal
rendering failure was not independently reproduced, so no server bug is asserted.

Successful nonce: 196dce40-36ea-4c3b-bc45-aeb50d1f8ae9. Codex reverified the exact
staging project, Anonymous setting, two owned Guest identities through trusted
Auth, caps and baseline global attempts=1. Staging function version 5 temporarily
used only A's UUID, enabled=true and syntheticOnly=true in the entrypoint; core
bytes/secret reads unchanged. No server secret values were retrieved or edited.

Observed technical PASS:

- Missing/forged Bearer, outsider B, private-field input and direct Guest quota
  RPC denied; database requests=0 and attempts unchanged before provider call.
- One actual gemini-3.5-flash-lite request returned HTTP 200; completed body was
  discarded. Identical retry returned succeeded, remaining=2 and the AI/unverified
  labels, without workerToken. SQL independently compared complete result JSONB,
  digest and Guest binding: state=succeeded, used=1, reserved=0, one request row.
- Two additional reservations through actual service_role RPC filled the other
  slots without provider calls. Fourth gateway request returned 429/quota_exhausted.
  Real failure acknowledgments refunded those two slots. Final used=1, reserved=0,
  request rows=3, trips=0; global attempts increased from 1 to 4 exactly.
- Finally restored original exact reviewed index/core bytes, version 6, same
  verify_jwt=false/custom Auth handling; hosted response 503/deployment_blocked.
  Guarded cleanup independently returned users=0, requests=0, usage=0; global
  attempts=4 retained. Worker close released private session RAM.

Generated output was Vietnamese travel advice for synthetic Hue input, with
explicit unverified-price/weather/hours warnings. One word contained mixed Korean
characters ("hành동"). Record as an observed language-quality caveat; do not label
the output polished or universally Vietnamese. No extra model call/regeneration
was made to hide it. Technical contract acceptance is distinct from product copy
quality; real-user activation and functional AI modules remain outside this PoC.

Boundaries unchanged: completed-body discard is not in-flight socket/worker fault;
service-role failure acks are not injected live Gemini 429/timeouts. Primary B3
NOT APPLIED; mobile production-UI Auth/import/offline A/B acceptance and instructor
rubric still open. Owner merges #34/#35/#37; #36 stays draft on C1 until #35 merges,
then retarget main and recheck five-file diff/CI before readiness.

## Fresh local regression and publication checkpoint — 2026-10-15

On catalogue branch HEAD cc5bd5ab4eb5119efce89c6e0dec43f78a133a66 with only this
tracked document modified: flutter analyze returned No issues found (73.1s);
flutter test --reporter compact returned 467 tests passed, exit 0. This checkout
does not yet include B9 PR #34's three extra tests; its earlier 470-test evidence
belongs to the separate B9 head. Do not combine the counts. Helper controls 9/9
PASS separately; no Flutter/runtime/native/database source changed in this unit.

PR metadata rechecked: #34/#35/#37 open, non-draft and based on main 522c0d1;
#36 open draft based on C1 7b20d5b. Existing exact-head checks rechecked: #34 Flutter
38389990543 success; #35 native 38391706220 and Flutter 38391706083 success;
#36 gateway/native 38392935588 success. These are existing completed runs, not new
live executions. Publish this document selectively on the catalogue feature
branch; verify the new #37 commit's exact five-file scope and its new CI runs.
