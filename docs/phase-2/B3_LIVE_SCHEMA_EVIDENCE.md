# B3 live metadata evidence — 2026-10-11

Codex directly observed Supabase Dashboard, selected the primary project link from the Travelgo organization, and executed one SELECT over catalogue/information_schema only. No application rows, credentials, migration, grants, DDL, inserts/updates/deletes or saved snippets were accessed/created.

Project observed in URL and heading: `oavbymauorhmrjcustzw`, plhhoang2005's Project, main. Browser source: https://supabase.com/dashboard/project/oavbymauorhmrjcustzw

Query returned one `b3_metadata` cell; database captured_at `2026-10-11T05:36:05.23418+00:00` (12:36:05 Asia/Saigon), server_version 17.6. Query consisted of jsonb_pretty(jsonb_build_object(...)) with metadata subqueries for columns, constraints, tables/RLS, policies, indexes, effective grants, non-internal triggers, import/receipt/canonical function identities and pgcrypto/uuid-ossp extensions. SQL Editor's keyword warning was shown because the grant matrix contains strings DELETE/TRUNCATE; the submitted statement was SELECT only. The warning was accepted for this authorized read-only inspection; no destructive SQL was executed.

## Observed schema

public.trips: 11 columns. public.trip_activities: 12 columns. Both owned by postgres; RLS enabled, FORCE RLS false. No version or canonical_payload_text column on trips.

| trips column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| user_id | uuid | NO | none |
| title | text | NO | none |
| destination_name | text | NO | none |
| num_days | integer | YES | 3 |
| budget_total | numeric | YES | 0 |
| start_date | timestamptz | YES | none |
| end_date | timestamptz | YES | none |
| status | text | YES | planning |
| ai_plan_data | jsonb | YES | {} |
| created_at | timestamptz | NO | timezone('utc',now()) |

trip_activities columns: id uuid NOT NULL default gen_random_uuid(); trip_id uuid NOT NULL; day_number integer NOT NULL default 1; start_time text NOT NULL; end_time text nullable; title text NOT NULL; description text nullable; service_id text nullable; cost numeric nullable default 0; has_conflict boolean nullable default false; conflict_reason text nullable; created_at timestamptz NOT NULL default timezone('utc',now()).

Six constraints, all validated:
- trips_pkey: PK id.
- trips_status_check: planning/booked/completed.
- trips_user_id_fkey: user_id -> auth.users.id ON DELETE CASCADE.
- trip_activities_pkey: PK id.
- trip_activities_service_id_fkey: service_id -> services.id ON DELETE SET NULL.
- trip_activities_trip_id_fkey: trip_id -> trips.id ON DELETE CASCADE.

Indexes in this scope: trips_pkey and trip_activities_pkey only (unique B-tree id).

Policies: trips SELECT/DELETE use auth.uid()=user_id; INSERT has the same WITH CHECK; UPDATE has both USING and WITH CHECK. All TO authenticated, permissive. trip_activities ALL TO authenticated uses EXISTS owner trip in both USING and WITH CHECK.

Effective table privileges tested for both tables:
- anon: SELECT/INSERT/UPDATE/DELETE/TRUNCATE/TRIGGER all false.
- authenticated: SELECT/INSERT/UPDATE/DELETE true; TRUNCATE/TRIGGER false.
- service_role: all six true. This does not prove app-role runtime isolation.

No non-internal trigger rows on these tables. No matching import/receipt/canonical functions in non-system schemas under the queried name pattern. Neither import_receipts nor guest_import_receipts exists under the queried public/private schema names. This is scoped absence, not an inventory of every function/table in every schema.

Extensions: extensions.pgcrypto 1.3; extensions.uuid-ossp 1.1. Migration must use the observed extension schema, not assume public.digest. No extension installation is needed by the proposed design.

## Limits and implications

Live inspection resolves the earlier stale-metadata blocker for these objects. It is not a runtime A/B/anon test, an audit of all schemas/functions, proof of default/column ACLs, staging parity, backup inventory, or migration success. Existing multi-result B3_SCHEMA_INSPECTION.sql was not itself executed; this single-result query covered its core B3 fields but not namespace/default ACLs. Implementation preflight must inspect those and check target drift/name collisions before apply.

Batch A need not be reapplied. Additive receipt/RPC/text companion remains proposed and unapplied. No DB user rows or tokens were exported. No claim about cloud backup existence is drawn from Dashboard summary labels.
