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

| File | Purpose |
| :--- | :--- |
| `baseline.sql` | Staging-only bootstrap reconstructs audited application schema (`profiles`, `destinations`, `trips`, `trip_activities`, `services`) and legacy permissive policies for verification. |
| `inspect.sql` | Metadata-only schema, policy, and privilege introspection queries. |
| `run-staging.ps1` | Guarded PowerShell wrapper executing SQL files via `psql` with `ON_ERROR_STOP=1`. |
| `run-staging.Tests.ps1` | Comprehensive offline unit tests validating target guard logic, failure modes, canonical bootstrap, lookalike domains, and mock executor invocation. |
| `README.md` | This documentation. |

## 3. Usage Guide

### Running Offline Target Guard Tests
```powershell
powershell -NoProfile -File supabase/staging/run-staging.Tests.ps1
```

### DryRun Canonical Baseline Bootstrap
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "bkocylxbuyvdgxccpixx" `
  -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co" `
  -SqlFile "supabase/staging/baseline.sql" `
  -Bootstrap `
  -DryRun
```

### DryRun Corrective Staging Execution
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "bkocylxbuyvdgxccpixx" `
  -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co" `
  -SqlFile "supabase/staging/inspect.sql" `
  -ExpectedBaselineHash "<baseline-sha256>" `
  -DryRun
```

### Bootstrapping Staging Database
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "bkocylxbuyvdgxccpixx" `
  -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co" `
  -SqlFile "supabase/staging/baseline.sql" `
  -Bootstrap
```

### Corrective Migration Execution
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "bkocylxbuyvdgxccpixx" `
  -ConnectionHost "db.bkocylxbuyvdgxccpixx.supabase.co" `
  -SqlFile "supabase/migrations/202610080001_profile_privacy.sql" `
  -ExpectedBaselineHash "<baseline-sha256>"
```
