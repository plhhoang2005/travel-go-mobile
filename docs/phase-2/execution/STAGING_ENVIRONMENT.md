# TravelGO Isolated Staging Environment Specification

- **Date**: 2026-10-08
- **Scope**: Phase 2 / Batch A / PR #15 Security Remediation
- **Status**: Documented / Awaiting Project Reference Assignment

---

## 1. Environment Provenance & Identity

| Attribute | Specification | Current Value / Status |
| :--- | :--- | :--- |
| **Project Name** | `travel-go-staging` | Prepared in Supabase Dashboard |
| **Organization Name** | `Travelgo` | Verified |
| **Organization ID** | `npdpvvfxolkoekazloqg` | Verified (Free Plan) |
| **Target Region** | Singapore (`ap-southeast-1`) | Selected |
| **Primary Project Reference** | `oavbymauorhmrjcustzw` | **STRICTLY FORBIDDEN TARGET** |
| **Staging Project Reference** | Dedicated synthetic-only project | *Pending Owner submission in Dashboard* |
| **Target Host** | `db.<staging-ref>.supabase.co` | *Pending Staging Project Reference* |
| **PostgreSQL Version** | Target server reported version | *Pending execution of `SELECT version();`* |

---

## 2. Configuration & Security Boundary

1. **Dashboard Configuration**:
   - **Data API**: ON
   - **Automatically expose new tables in API**: OFF
   - **Automatic RLS on new tables**: OFF (RLS and policies are explicitly owned and verified by reviewed SQL)
   - **GitHub Connection**: OFF (No automated deployment pipeline connected)
   - **Billing Plan**: Free tier (No paid upgrades or tier changes)

2. **Strict Isolation Policy**:
   - **Zero Production Data**: No real customer data, production backups, or user records from `oavbymauorhmrjcustzw` may be imported or copied.
   - **Synthetic Users Only**: All fixtures in tests use generated synthetic UUIDs (`11111111-...`, `22222222-...`).
   - **Target Guard**: `supabase/staging/run-staging.ps1` hard-blocks any connection target containing or matching the primary reference `oavbymauorhmrjcustzw`.
   - **Credential Hygiene**: Database passwords and auth tokens are submitted and held directly by the owner through the secure Dashboard UI. No secrets are ever stored in code, chat, or git repositories.

---

## 3. Next Actionable Milestone

- **Owner Action**: Enter database credential in the Supabase Dashboard form for organization `Travelgo` and click create project.
- **Agent Action**: Once the staging reference is provided, update this document, bind the runner target guard, execute `supabase/staging/baseline.sql` and `supabase/staging/inspect.sql`, and proceed with migration and test harness execution.
