-- Migration: 20261103140000_fix_pgcrypto_digest.sql
-- Fixes RPC prepare_discovery_preview digest error by ensuring digest function exists in public schema
-- Contract: travelgo.admin.publication.v1

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    CREATE SCHEMA IF NOT EXISTS extensions;
    CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
  END IF;
END $$;

-- Create public alias functions for digest to ensure backwards compatibility when search_path = ''
DO $$
DECLARE
  v_ext_schema text;
BEGIN
  SELECT n.nspname INTO v_ext_schema
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE p.proname = 'digest' AND n.nspname IN ('extensions', 'public')
  LIMIT 1;

  IF v_ext_schema = 'extensions' THEN
    EXECUTE $func$
      CREATE OR REPLACE FUNCTION public.digest(data text, type text)
      RETURNS bytea LANGUAGE sql IMMUTABLE AS $f$
        SELECT extensions.digest(data, type);
      $f$;

      CREATE OR REPLACE FUNCTION public.digest(data bytea, type text)
      RETURNS bytea LANGUAGE sql IMMUTABLE AS $f$
        SELECT extensions.digest(data, type);
      $f$;
    $func$;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.digest(text, text) TO authenticated, service_role, anon, postgres;
GRANT EXECUTE ON FUNCTION public.digest(bytea, text) TO authenticated, service_role, anon, postgres;

COMMENT ON FUNCTION public.digest(text, text) IS 'Wrapper around extensions.digest for pgcrypto compatibility';
