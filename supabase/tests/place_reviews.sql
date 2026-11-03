BEGIN;

DO $contract$
BEGIN
  IF to_regclass('public.place_reviews') IS NULL THEN
    RAISE EXCEPTION 'place_reviews table is missing';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.place_reviews'::regclass) THEN
    RAISE EXCEPTION 'place_reviews RLS is disabled';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'place_reviews'
      AND cmd = 'SELECT' AND roles @> ARRAY['anon'::name, 'authenticated'::name]
  ) THEN
    RAISE EXCEPTION 'public review read policy is missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'place_reviews'
      AND cmd = 'INSERT' AND with_check ~ 'auth\.uid\(\)'
  ) THEN
    RAISE EXCEPTION 'authenticated review insert policy is missing';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'place_reviews'
      AND cmd IN ('UPDATE', 'DELETE', 'ALL')
  ) THEN
    RAISE EXCEPTION 'place_reviews exposes an unapproved mutation policy';
  END IF;
  IF has_table_privilege('anon', 'public.place_reviews', 'INSERT') OR
     has_table_privilege('authenticated', 'public.place_reviews', 'UPDATE') OR
     has_table_privilege('authenticated', 'public.place_reviews', 'DELETE') THEN
    RAISE EXCEPTION 'place_reviews grants exceed the approved surface';
  END IF;
END;
$contract$;

ROLLBACK;
