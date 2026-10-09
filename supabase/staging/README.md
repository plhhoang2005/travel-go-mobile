# TravelGO Isolated Staging Environment & Guarded Runner

This directory contains artifacts for bootstrapping, inspecting, and running verification against the isolated `travel-go-staging` Supabase database.

## 1. Safety Architecture & Target Guard

The runner script `run-staging.ps1` implements fail-closed target guards:
- **Verified Staging Allowlist**: Strictly allows ONLY the verified staging project `bkocylxbuyvdgxccpixx`. All other project references are rejected before any executor invocation.
- **Exact Connection Endpoint Binding**: Requires exact match against `db.bkocylxbuyvdgxccpixx.supabase.co`. Substring matching is prohibited; lookalike domains, prefixed hosts, empty hosts, and localhost are strictly rejected.
- **Primary Project Protection**: Strictly aborts if `-ProjectRef` or `-ConnectionHost` matches or contains the primary production project reference `oavbymauorhmrjcustzw`.
- **Baseline Verification**: Corrective writes require `-ExpectedBaselineHash` validating the LF-normalized SHA-256 of `baseline.sql`. Input file hash is verified separately via optional `-ExpectedSqlHash` using consistent LF-normalized UTF-8 SHA-256.
- **Canonical Bootstrap Mode**: `-Bootstrap` is strictly restricted to the canonical reviewed artifact `baseline.sql`. Applying migrations, harnesses, or arbitrary files under `-Bootstrap` is rejected.
- **DryRun Capability**: `-DryRun` validates guard parameters and configuration without opening any network database connection.
- **Zero Secrets**: Credentials must be supplied via standard secure environment variables or interactive prompt; they are never passed as command-line arguments or saved to repository files.

## 2. Directory Contents

| File / Directory | Purpose |
| :--- | :--- |
| `baseline.sql` | Staging-only bootstrap reconstructs audited application schema (`profiles`, `destinations`, `trips`, `trip_activities`, `services`) and legacy permissive policies for verification. |
| `inspect.sql` | Metadata-only schema, policy, and privilege introspection queries. |
| `build-bundles.ps1` | Automation script that flattens modular test suites and `profile_privacy_test_helpers.sql` into pure-SQL execution bundles with zero meta-commands. |
| `bundles/` | Pure-SQL execution bundles for Supabase Dashboard SQL Editor & runner execution (`profile_privacy.bundle.sql`, `profile_privacy_negative_controls.bundle.sql`). |
| `run-staging.ps1` | Guarded PowerShell wrapper executing SQL files via native host `psql` (or PATH) with `ON_ERROR_STOP=1`. Enforces target guard, baseline hash, and dependency helper hash. |
| `run-staging.Tests.ps1` | Comprehensive offline unit tests validating target guard logic, failure modes, canonical bootstrap, lookalike domains, dependency integrity guards, and mock executor invocation. |
| `README.md` | This documentation. |

## 3. Usage Guide

### Running Offline Target Guard Tests (26 Tests)
```powershell
powershell -NoProfile -File supabase/staging/run-staging.Tests.ps1
```

### Building Pure-SQL Execution Bundles
```powershell
powershell -NoProfile -File supabase/staging/build-bundles.ps1
```

### DryRun Canonical Baseline Bootstrap
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "bkocylxbuyvdgxccpixx" `
  -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co" `
  -SqlFile "supabase/staging/baseline.sql" `
  -Bootstrap `
  -ExpectedBaselineHash "<baseline-sha256>" `
  -DryRun
```

### DryRun Test Harness Execution with Dependency Guard
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "bkocylxbuyvdgxccpixx" `
  -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co" `
  -SqlFile "supabase/staging/bundles/profile_privacy.bundle.sql" `
  -ExpectedBaselineHash "<baseline-sha256>" `
  -ExpectedSqlHash "<bundle-sha256>" `
  -ExpectedHelperHash "<helper-sha256>" `
  -DryRun
```

## 4. Supabase Dashboard SQL Editor Execution Line (Staging `bkocylxbuyvdgxccpixx`)

For running on Supabase Dashboard SQL Editor (`https://supabase.com/dashboard/project/bkocylxbuyvdgxccpixx/sql`):
1. **Pre-Inspection**: Run `supabase/staging/inspect.sql` to verify environment is clean (no application tables).
2. **Bootstrap (Clean Only)**: Run `supabase/staging/baseline.sql` to reconstruct baseline schema. Precondition aborts if tables already exist.
3. **Migration**: Run `supabase/migrations/202610080001_profile_privacy.sql`. Precondition validates structural metadata contracts (REV-005).
4. **Test Suite Bundle**: Run `supabase/staging/bundles/profile_privacy.bundle.sql` (12 test cases PASS, rolls back cleanly).
5. **Negative Controls Bundle**: Run `supabase/staging/bundles/profile_privacy_negative_controls.bundle.sql` (5 controls PASS, rolls back cleanly).
