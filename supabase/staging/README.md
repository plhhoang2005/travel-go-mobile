# TravelGO Isolated Staging Environment & Runner

This directory contains artifacts for bootstrapping, inspecting, and running verification against the isolated `travel-go-staging` Supabase database.

## 1. Safety Architecture & Target Guard

The runner script `run-staging.ps1` implements fail-closed target guards:
- **Primary Project Protection**: Strictly aborts if `-ProjectRef` or `-ConnectionHost` matches or contains the primary production project reference `oavbymauorhmrjcustzw`.
- **Baseline Verification**: Optional `-ExpectedBaselineHash` ensures that migrations are applied only against an audited baseline.
- **DryRun Capability**: `-DryRun` validates guard parameters and configuration without opening any network database connection.
- **Zero Secrets**: Credentials must be supplied via standard secure environment variables or interactive prompt; they are never passed as command-line arguments or saved to repository files.

## 2. Directory Contents

| File | Purpose |
| :--- | :--- |
| `baseline.sql` | Staging-only bootstrap reconstructs legacy pre-remediation schema (`profiles`, `destinations`, `trips`, `trip_activities`) and permissive policies for verification. |
| `inspect.sql` | Metadata-only schema, policy, and privilege introspection queries. |
| `run-staging.ps1` | Guarded PowerShell wrapper executing SQL files via `psql` with `ON_ERROR_STOP=1`. |
| `run-staging.Tests.ps1` | Offline unit tests validating target guard logic and failure modes. |
| `README.md` | This documentation. |

## 3. Usage Guide

### Running Offline Target Guard Tests
```powershell
powershell -NoProfile -File supabase/staging/run-staging.Tests.ps1
```

### DryRun Target Guard Verification
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "<staging-project-ref>" `
  -ConnectionHost "db.<staging-project-ref>.supabase.co" `
  -SqlFile "supabase/staging/inspect.sql" `
  -DryRun
```

### Bootstrapping Staging Database
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "<staging-project-ref>" `
  -ConnectionHost "db.<staging-project-ref>.supabase.co" `
  -SqlFile "supabase/staging/baseline.sql" `
  -Bootstrap
```

### Metadata Introspection
```powershell
powershell -NoProfile -File supabase/staging/run-staging.ps1 `
  -ProjectRef "<staging-project-ref>" `
  -ConnectionHost "db.<staging-project-ref>.supabase.co" `
  -SqlFile "supabase/staging/inspect.sql"
```
