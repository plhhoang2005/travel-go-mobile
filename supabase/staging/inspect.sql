-- ==============================================================================
-- Staging Database Metadata Introspection: inspect.sql
-- Description: Queries and captures schema structure, functions, triggers,
--              RLS policies, and effective privilege dictionaries without
--              accessing or exporting any user data.
-- ==============================================================================

\echo '=== 1. POSTGRESQL ENGINE VERSION ==='
SELECT version();

\echo '=== 2. APPLICATION TABLES & COLUMNS IN PUBLIC SCHEMA ==='
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

\echo '=== 3. CONSTRAINTS & FOREIGN KEYS ==='
SELECT
  conname AS constraint_name,
  conrelid::regclass AS table_name,
  contype AS constraint_type,
  confrelid::regclass AS foreign_table_name
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
ORDER BY table_name, constraint_name;

\echo '=== 4. TRIGGER BINDINGS & PROCEDURES ==='
SELECT
  t.tgname AS trigger_name,
  c.relname AS table_name,
  p.proname AS procedure_name,
  p.prosecdef AS is_security_definer,
  t.tgenabled AS trigger_enabled
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgname IN ('on_auth_user_created', 'tr_profiles_updated_at')
ORDER BY table_name, trigger_name;

\echo '=== 5. FUNCTIONS DEFINITIONS & SEARCH_PATH ==='
SELECT
  proname,
  prosecdef AS is_security_definer,
  proconfig AS custom_settings
FROM pg_proc
WHERE proname IN ('handle_new_user', 'set_profile_updated_at');

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
