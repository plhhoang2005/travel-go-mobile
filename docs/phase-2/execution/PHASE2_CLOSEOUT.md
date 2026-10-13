# Phase 2 checkpoint — 2026-10-13

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
| C1 quota | [PR #35](https://github.com/plhhoang2005/travel-go-mobile/pull/35), `7b20d5bc5ffe2de274c0bee4f8a8c4d5dc1ea906`, five files | Native PostgreSQL 18.6 SQL/role/rollback/midnight/refund/expiry tests; four-session and duplicate races; owned cleanup PASS. Native Linux CI and Flutter CI PASS after isolating Unix socket path. |
| C2 gateway | [draft PR #36](https://github.com/plhhoang2005/travel-go-mobile/pull/36), `81c8874627cd36ed8bc378b293913d1a53cbf6d3`, five files, stacked on C1 | 20 Node tests PASS including thin entrypoint via Deno shim; gateway/native quota CI PASS. Deno hosted runtime/Gemini live NOT RUN. Disabled/synthetic/allowlist mode only. |
| Catalogue | Independent `codex/phase-2-catalogue-readiness` source unit, five files | 12 approved IDs, 72 named source references and 12 authored examples; unknown operational fields preserved. Exact PR/CI supplied at handover. Not runtime publication. |

Local test logs/output are observed by Codex. The earlier B3 extended native
staging controls were Owner-reported and separately recorded in
`R06_IMPORT_CONTRACT.md`; do not relabel them as this turn's new live execution.

## Concrete Owner gates before live closure

1. Review/merge #34 and #35 into main (independent). #36 remains draft so it cannot
   accidentally merge into its feature base. After #35 merges, Codex retargets
   #36 to main, confirms its five files/CI and marks ready. Catalogue is independent.
2. Authorize additive C1 migration on staging `bkocylxbuyvdgxccpixx` only, using
   the reviewed #35 source. Live quota schema state is UNKNOWN; local tests do
   not establish its absence. Actual target/schema/grants still need read-only
   preflight. No implicit primary apply or reapplication of Batch A/B3.
3. Configure a Gemini API key privately in the staging gateway's server secrets
   for a synthetic PoC, verify the API project is a no-billing/free-tier project
   and model access/rate limits. Do not paste the key into chat/logs or Flutter.
   Codex has no configured key and cannot claim live model success.
4. Approve staging Edge deployment with `TRAVELGO_AI_ENABLED=true`,
   `TRAVELGO_AI_SYNTHETIC_ONLY=true` and a specific test-subject allowlist.
   Verify valid/rejected Auth, structured Vietnamese output, retry and failed
   provider refund; never switch to paid/private mode implicitly.
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
- Gemini model/account/tier, Deno hosted function and live receipt/quota route
  remain NOT RUN. Source gate rejects real private/free-text context. Actual
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

## Staging execution checklist ready for Owner authorization

Target is **travel-go-staging / bkocylxbuyvdgxccpixx**, never inferred from the
currently selected dashboard tab. Confirm the project ref/connection host before
any statement. The browser automation tool in this session failed to initialize
(`failed to write kernel assets`, path not found), so the following live preflight
is **NOT RUN**, rather than an inferred schema state.

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
