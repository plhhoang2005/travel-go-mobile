# TravelGO Isolated Staging Environment Specification

- **Date**: 2026-10-08
- **Scope**: Phase 2 / Batch A / PR #15 Security Remediation
- **Status**: Verified & Provisioned (0 application tables prior to bootstrap)

---

## 1. Environment Provenance & Identity

| Attribute | Specification | Verified Staging Value |
| :--- | :--- | :--- |
| **Project Name** | `travel-go-staging` | `travel-go-staging` |
| **Organization Name** | `Travelgo` | `Travelgo` |
| **Organization ID** | `npdpvvfxolkoekazloqg` | `npdpvvfxolkoekazloqg` (Free Plan) |
| **Target Region** | Singapore | `ap-southeast-1` |
| **Primary Project Reference** | `oavbymauorhmrjcustzw` | **STRICTLY FORBIDDEN TARGET** |
| **Staging Project Reference** | Dedicated synthetic-only project | **`bkocylxbuyvdgxccpixx`** |
| **Connection Host** | Direct Supabase PostgreSQL host | **`db.bkocylxbuyvdgxccpixx.supabase.co`** |
| **PostgreSQL Engine Version**| Target server reported version | **`PostgreSQL 17.11`** |
| **Pre-Bootstrap Table Count** | Initial application schema state | **`0 tables`** (`profiles`, `destinations`, `trips`, `trip_activities` absent) |

---

## 2. Configuration & Security Boundary

1. **Dashboard Configuration**:
   - **Data API**: ON
   - **Automatically expose new tables in API**: OFF
   - **Automatic RLS on new tables**: OFF (RLS and policies are explicitly owned and verified by reviewed SQL)
   - **GitHub Connection**: OFF (No automated deployment pipeline connected)
   - **Billing Plan**: Free tier (No paid upgrades or tier changes)

2. **Strict Isolation Policy & Target Guard**:
   - **Zero Production Data**: No real customer data, production backups, or user records from `oavbymauorhmrjcustzw` may be imported or copied.
   - **Synthetic Users Only**: All fixtures in tests use generated synthetic UUIDs (`11111111-...`, `22222222-...`).
   - **Pinned Target Guard**: `supabase/staging/run-staging.ps1` allows ONLY the verified staging reference `bkocylxbuyvdgxccpixx` and host `db.bkocylxbuyvdgxccpixx.supabase.co`. It strictly rejects primary `oavbymauorhmrjcustzw`, localhost, absent host, mismatched host/ref, and unverified projects.
   - **Offline Guard Verification**: 14/14 unit tests pass in `run-staging.Tests.ps1`; 4/4 reviewer probes pass in `staging_guard_review_probes.ps1`.
   - **Credential Hygiene**: Database passwords and auth tokens are submitted and held directly by the owner through the secure Dashboard UI. No secrets are ever stored in code, chat, or git repositories.

---

## 3. Operational Workflow

1. **Bootstrap Staging**:
   Execute `supabase/staging/baseline.sql` via `run-staging.ps1 -Bootstrap` to reconstruct application schema.
2. **Metadata Introspection**:
   Execute `supabase/staging/inspect.sql` to record pre-remediation metadata.
3. **Corrective Migration**:
   Apply `supabase/migrations/202610080001_profile_privacy.sql` with verified `-ExpectedBaselineHash`.
4. **Harness & Negative Controls**:
   Execute `supabase/tests/profile_privacy.sql` and `supabase/tests/profile_privacy_negative_controls.sql`.
