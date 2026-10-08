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

\echo '=== 4. TRIGGER BINDINGS & DEFINITIONS ==='
SELECT
  t.tgname AS trigger_name,
  c.relname AS table_name,
  p.proname AS procedure_name,
  pg_get_triggerdef(t.oid) AS trigger_definition,
  t.tgenabled AS trigger_enabled
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgname IN ('on_auth_user_created', 'tr_profiles_updated_at')
ORDER BY table_name, trigger_name;

\echo '=== 5. FUNCTIONS DEFINITIONS, SIGNATURE, OWNER, ACL & SEARCH_PATH ==='
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS signature,
  pg_get_userbyid(p.proowner) AS function_owner,
  p.prosecdef AS is_security_definer,
  p.proconfig AS search_path_config,
  p.proacl AS function_acl,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
WHERE p.proname IN ('handle_new_user', 'set_profile_updated_at')
ORDER BY function_name;

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

\echo '=== 7. EFFECTIVE TABLE PRIVILEGES ==='
SELECT
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated', 'public')
ORDER BY table_name, grantee, privilege_type;

\echo '=== 8. EFFECTIVE COLUMN PRIVILEGES ==='
SELECT
  grantee,
  table_name,
  column_name,
  privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated', 'public')
ORDER BY table_name, column_name, grantee;
