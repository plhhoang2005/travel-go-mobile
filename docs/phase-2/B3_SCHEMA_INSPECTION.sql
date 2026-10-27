-- B3 metadata-only inspection. No application rows, credentials, DDL or writes.
-- Run in the explicitly verified Supabase project; record its project ref separately.
-- This file has NOT been executed against live/staging by Codex.
BEGIN TRANSACTION READ ONLY;
SELECT clock_timestamp() AS captured_at, current_database() AS database_name,
       current_setting('server_version') AS server_version;

SELECT c.table_schema, c.table_name, c.column_name, c.data_type,
       c.udt_name, c.is_nullable, c.column_default, c.ordinal_position
FROM information_schema.columns c
WHERE c.table_schema IN ('public','private')
  AND c.table_name IN ('trips','trip_activities','import_receipts','guest_import_receipts')
ORDER BY c.table_name, c.ordinal_position;

SELECT n.nspname AS schema_name, c.relname AS table_name,
       c.relrowsecurity, c.relforcerowsecurity,
       pg_get_userbyid(c.relowner) AS table_owner,
       k.conname, k.contype, k.convalidated, pg_get_constraintdef(k.oid) AS definition
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_constraint k ON k.conrelid = c.oid
WHERE n.nspname IN ('public','private')
  AND c.relname IN ('trips','trip_activities','import_receipts','guest_import_receipts')
ORDER BY c.relname, k.conname;

SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname IN ('public','private')
  AND tablename IN ('trips','trip_activities','import_receipts','guest_import_receipts')
ORDER BY tablename, indexname;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname IN ('public','private')
  AND tablename IN ('trips','trip_activities','import_receipts','guest_import_receipts')
ORDER BY tablename, policyname;

SELECT r.rolname, c.relname AS table_name, p.privilege,
       has_table_privilege(r.rolname, c.oid, p.privilege) AS effective_privilege
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN (VALUES ('anon'),('authenticated'),('service_role')) r(rolname)
CROSS JOIN (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('TRIGGER')) p(privilege)
WHERE n.nspname IN ('public','private')
  AND c.relname IN ('trips','trip_activities','import_receipts','guest_import_receipts')
ORDER BY c.relname, r.rolname, p.privilege;

SELECT n.nspname AS schema_name, c.relname AS table_name, t.tgname,
       t.tgenabled, pg_get_triggerdef(t.oid) AS trigger_definition,
       p.oid::regprocedure::text AS function_identity, p.prosecdef, p.proconfig
FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE NOT t.tgisinternal AND n.nspname IN ('public','private')
  AND c.relname IN ('trips','trip_activities','import_receipts','guest_import_receipts')
ORDER BY c.relname, t.tgname;

SELECT n.nspname AS schema_name, p.oid::regprocedure::text AS function_identity,
       pg_get_userbyid(p.proowner) AS function_owner, p.prosecdef, p.proconfig,
       p.proacl, pg_get_function_result(p.oid) AS result_type
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND p.proname ~ '(guest.*import|import.*guest|receipt|canonical)'
ORDER BY n.nspname, function_identity;
SELECT extname, extversion, extnamespace::regnamespace::text AS extension_schema
FROM pg_extension WHERE extname IN ('pgcrypto','uuid-ossp');
SELECT nspname, nspacl FROM pg_namespace WHERE nspname IN ('public','private','extensions');
SELECT defaclrole::regrole::text AS owner_role,
       defaclnamespace::regnamespace::text AS schema_name, defaclobjtype, defaclacl
FROM pg_default_acl;
ROLLBACK;
