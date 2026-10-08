-- ==============================================================================
-- Staging Database Metadata Introspection: inspect.sql
-- Description: Queries and captures schema structure, functions, triggers,
--              RLS policies, and effective privilege dictionaries without
--              accessing or exporting any user data.
-- Target: STAGING ENVIRONMENT (bkocylxbuyvdgxccpixx)
-- ==============================================================================

\echo '=== 1. POSTGRESQL ENGINE VERSION ==='
SELECT version();

\echo '=== 2. APPLICATION TABLES & COLUMNS IN PUBLIC SCHEMA ==='
SELECT
  table_schema,
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

\echo '=== 3. CONSTRAINTS & DEFINITIONS ==='
SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  contype AS constraint_type,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY table_name, constraint_name;

\echo '=== 4. TRIGGER BINDINGS & DEFINITIONS (SCHEMA-QUALIFIED) ==='
SELECT
  n.nspname AS schema_name,
  t.tgname AS trigger_name,
  c.relname AS table_name,
  p.proname AS procedure_name,
  pg_get_triggerdef(t.oid) AS trigger_definition,
  t.tgenabled AS trigger_enabled
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgname IN ('on_auth_user_created', 'tr_profiles_updated_at')
ORDER BY schema_name, table_name, trigger_name;

\echo '=== 5. FUNCTIONS DEFINITIONS, SIGNATURE, OWNER, ACL & SEARCH_PATH (FULL IDENTITY) ==='
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  p.oid::regprocedure AS full_identity,
  pg_get_function_identity_arguments(p.oid) AS signature,
  pg_get_userbyid(p.proowner) AS function_owner,
  p.prosecdef AS is_security_definer,
  p.proconfig AS search_path_config,
  p.proacl AS function_acl,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname IN ('handle_new_user', 'set_profile_updated_at')
ORDER BY schema_name, function_name;

\echo '=== 6. ACTIVE ROW LEVEL SECURITY POLICIES ==='
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

\echo '=== 7. INFORMATION_SCHEMA TABLE PRIVILEGES ==='
SELECT
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated', 'public')
ORDER BY table_name, grantee, privilege_type;

\echo '=== 8. INFORMATION_SCHEMA COLUMN PRIVILEGES ==='
SELECT
  grantee,
  table_name,
  column_name,
  privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated', 'public')
ORDER BY table_name, column_name, grantee;

\echo '=== 9. ACTUAL EFFECTIVE INHERITED PRIVILEGES (HAS_TABLE_PRIVILEGE) ==='
SELECT
  r.rolname,
  t.relname AS table_name,
  p.priv AS privilege_type,
  has_table_privilege(r.rolname, t.oid, p.priv) AS has_effective_privilege
FROM (VALUES ('anon'), ('authenticated')) r(rolname)
CROSS JOIN (
  SELECT oid, relname FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
) t
CROSS JOIN (
  VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
) p(priv)
ORDER BY r.rolname, t.relname, p.priv;
