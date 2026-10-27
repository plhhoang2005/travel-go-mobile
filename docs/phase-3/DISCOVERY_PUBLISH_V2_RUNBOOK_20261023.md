# TravelGO Discovery Release V2 & Admin Publication Runbook

**Date:** 2026-10-23 (Asia/Saigon)  
**System:** TravelGO Decision Intelligence Client & Backend Ecosystem  
**Target Release:** Discovery Release V2 Contract (`travelgo.discovery.release.v2`) & Admin Account / Catalogue Control  
**Security & Authority:** Strict Stage-Gate, Least-Privilege RLS, Server-Authored Projections, Zero Live Mutate Without Staging Approval  

---

## 1. Overview & Architecture Blueprint

Discovery Release V2 delivers dynamic catalogue publishing, atomic manifest management, un-bannable customer/admin protection, and client-side safe synchronization:

```
[ Admin Web / Mobile UI (F1–F6) ]
               │
               ▼
   [ Edge Function / RPC ]
   • admin-discovery-commands (A5)
   • admin-publication (P2)
   • admin-control (A3)
               │
               ▼
   [ PostgreSQL Private Schema & Staging (P1, A1, A2) ]
   • private.discovery_draft_revisions
   • private.discovery_publication_candidates
   • public.discovery_manifest (single active pointer)
               │
               ▼
   [ Storage Bucket: discovery-releases ]
   • releases/v2/{version}.json (immutable release bundle)
               │
               ▼
   [ Client App: Discovery & Planner (P4–P10) ]
   • PublicCatalogueRepository (ETag / version polling)
   • PublicCatalogueCache (memory + atomic disk cache)
   • ManualTripFactory (preserves dynamic destination identity)
   • SelectedDestinationControls (AI quota guard for non-legacy destinations)
```

---

## 2. Staging Deployment Packet

### 2.1. Sequential Migrations Map & SHA-256 Hashes

The following migrations must be executed sequentially in this strict topological order:

| Order | Migration File | SHA-256 Checksum | Purpose |
|---|---|---|---|
| 1 | `20261020145005_two_role_foundation.sql` | `86c71288f0133f94c67813fcb575ab32a08b630a1fe463fbd3e946963fced5c8` | Base two-role (`customer`, `admin`) mapping, RLS policies |
| 2 | `20261020151440_admin_discovery_drafts.sql` | `22c3c9bb88d5d67a1be6048991790a622a386c2b7cf97055474f59bfc6c42dc3` | Draft revisions table, seed catalogue and visit facts |
| 3 | `20261023062634_admin_account_control.sql` | `c9dd101e10fa034691e113b2111e4d823e529172d7f3b410e6d69f3f4adf13cb` | Account lock/unlock, last-admin guard, sync tracking |
| 4 | `20261023065337_admin_account_guards.sql` | `2a4504b5e321bf7c58229b92289f2ed219f632d14788688f32a7bfc2cab40538` | Hardened surface guards, prevent profile deletion |
| 5 | `20261023074312_admin_discovery_commands.sql` | `ebe7f0222a1691110fe5d75a12401bce94945e4077d3a8948c7ae2841a0d3c62` | Server-side catalogue command processor (`admin_discovery_commands_v1`) |
| 6 | `20261023160000_discovery_publication_v2.sql` | `dd18f61f4230edd79676d265b7a1b87509cdc3524ddf55ba9d8d9101e5dde709` | Publication staging candidate, bundle projection, activation & rollback |
| 7 | `20261023170000_manual_dynamic_destination_ids.sql` | `3b3fd25ef337eabd1464aa2b8e9ae6b09af10b7a01549af644d16032be034451` | Trip document validation with typed dynamic destination identities |

### 2.2. Edge Functions

| Function Name | Entry Point | Required Capabilities |
|---|---|---|
| `admin-control` | `supabase/functions/admin-control/index.ts` | Auth ban synchronization, service_role execution, lock/unlock RPCs |
| `admin-discovery` | `supabase/functions/admin-discovery/index.ts` | Draft read & command mutation, revision concurrency check |
| `admin-publication`| `supabase/functions/admin-publication/index.ts` | Staging preview, bundle storage upload, verified readback, manifest activation |

### 2.3. Storage Bucket Configuration

- **Bucket Name:** `discovery-releases`
- **Public Access:** Enabled for `GET /storage/v1/object/public/discovery-releases/*`
- **Write Policy:** Restrict to `service_role` only. No direct client writes.
- **Objects Layout:** `releases/v2/{version}.json`

### 2.4. Required Environment Variables

The deployment environment must define the following standard configuration variables (no secrets recorded in repository):
- `SUPABASE_URL`: API gateway URL.
- `SUPABASE_SERVICE_ROLE_KEY`: Edge function privileged service role token.
- `SUPABASE_ANON_KEY`: Public anonymous client token.
- `GEMINI_API_KEY`: Server-side AI model integration key.

---

## 3. Step-by-Step Staging & Publication Lifecycle SOP

### Phase 1: Catalogue Editing & Draft Commands
1. Admin logs into Flutter Admin UI (`/admin/login`).
2. Admin navigates to Catalogue Tab (`AdminCatalogueScreen`).
3. Changes (adding destination, editing visit facts, archiving destination) dispatch atomic commands via `public.admin_discovery_commands_v1`.
4. Commands validate:
   - Server-authored IDs (slug-based `dest-*`, `place-*`).
   - Coordinate bounds (`latitude [-90, 90]`, `longitude [-180, 180]`).
   - Parent existence (no orphan places).
   - No hard deletes; soft hide preserves referential history.

### Phase 2: Candidate Freezing & Storage Upload
1. Admin initiates publication preview from Flutter Admin UI or gateway.
2. System calls `public.admin_stage_publication_candidate_v2(p_draft_revision)`.
3. Candidate candidate bundle is generated:
   - Filters out hidden destinations and places.
   - Computes UTF-8 byte length and SHA-256 digest.
4. Edge function `admin-publication` uploads candidate to Storage:
   - `releases/v2/{candidate_version}.json`.
5. Edge function performs **Verified Readback**:
   - Re-reads uploaded object from Storage via HTTP.
   - Computes SHA-256 and byte length of readback bytes.
   - If mismatch: abort immediately with 500 error; candidate remains unactivated.

### Phase 3: Atomic Activation & Rollback
1. Upon verified readback, system executes `public.admin_activate_publication_v2(p_candidate_version)`.
2. PostgreSQL transaction updates `public.discovery_manifest`:
   - Points active manifest version to `{candidate_version}`.
   - Sets `published_at = now()`.
3. **Emergency Rollback Procedure:**
   - In case of critical operational regression, run:
     ```sql
     SELECT public.admin_rollback_publication_v2(p_target_version => :previous_version);
     ```
   - Transaction re-points `public.discovery_manifest` to the previous verified release version without re-uploading storage objects.

---

## 4. Native Acceptance Specification

### Evidence Case: `native_same_apk_draft_publish_refresh_offline`

| Step | Action | Expected State & Verification |
|---|---|---|
| **1. Baseline State** | Launch customer app on Device / Emulator with initial release `v1`. | App displays 12 standard destinations. Background poller checks `discovery_manifest` (`version: 1`). |
| **2. Admin Draft Action** | Admin creates new destination `dest-quy-nhon-123` ("Quy Nhơn") in draft mode. | Customer app remains on `version: 1`. "Quy Nhơn" is NOT visible to customers. |
| **3. Staging & Publish** | Admin previews, uploads bundle `releases/v2/2.json`, and activates `version: 2`. | `public.discovery_manifest` updates to `version: 2`. |
| **4. Live App Refresh** | Same customer APK triggers foreground refresh or 15-minute periodic poll. | `PublicCatalogueRepository` detects `manifest.version == 2`, downloads and validates `releases/v2/2.json`. New destination "Quy Nhơn" appears on Home & Explore without APK reinstall. |
| **5. Offline Restart** | Enable Airplane mode / terminate network, kill app process and relaunch. | `PublicCatalogueCache` restores last-known-good `version: 2` from local cache. "Quy Nhơn" and all cached details remain available offline. |
| **6. Dynamic Trip Integrity**| Create manual trip for "Quy Nhơn", add activity at "Eo Gió", and save. | Trip codec and local store preserve `destinationId: dest-quy-nhon-123`, `destinationName: Quy Nhơn`, and expense records without fallback corruption. |
