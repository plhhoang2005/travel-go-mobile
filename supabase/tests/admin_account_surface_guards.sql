-- Test suite for Admin Account Surface Guards (Task A2)
\set ON_ERROR_STOP on
BEGIN;

CREATE FUNCTION pg_temp.check_a2(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: %', label;
  END IF;
  RAISE NOTICE 'PASS: %', label;
END $$;

CREATE FUNCTION pg_temp.denied_a2(statement text, expected_code text, label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
  BEGIN
    EXECUTE statement;
    actual := 'none';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS actual = RETURNED_SQLSTATE;
  END;
  PERFORM pg_temp.check_a2(actual = expected_code, label || format(' [actual=%s expected=%s]', actual, expected_code));
END $$;

CREATE FUNCTION pg_temp.claim_user(subject text, session_id text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claim.sub', subject, true);
  SELECT set_config('request.jwt.claims', jsonb_build_object(
    'sub', subject,
    'session_id', session_id,
    'role', 'authenticated'
  )::text, true)::text;
$$;

-- 1. Versioned Preflight Enumeration
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'public.profiles'::regclass
      AND polname = 'account_enabled_restrictive'
      AND polpermissive = false
  ) THEN
    RAISE EXCEPTION 'Missing account_enabled_restrictive policy on public.profiles';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'public.trips'::regclass
      AND polname = 'account_enabled_restrictive'
      AND polpermissive = false
  ) THEN
    RAISE EXCEPTION 'Missing account_enabled_restrictive policy on public.trips';
  END IF;

  IF to_regprocedure('public.check_gateway_account(uuid,uuid,boolean)') IS NULL AND to_regproc('public.check_gateway_account') IS NULL THEN
    RAISE EXCEPTION 'Missing public.check_gateway_account function';
  END IF;
END $$;

-- 2. Fixture Setup
INSERT INTO auth.users(id, email, raw_user_meta_data, email_confirmed_at, created_at) VALUES
  ('d1111111-0000-4000-8000-000000000001', 'user_enabled@example.invalid', '{}', now(), now()),
  ('d1111111-0000-4000-8000-000000000002', 'user_locked@example.invalid', '{}', now(), now());

INSERT INTO auth.sessions(id, user_id, not_after, created_at) VALUES
  ('ed111111-0000-4000-8000-000000000001', 'd1111111-0000-4000-8000-000000000001', now() + interval '1 day', now()),
  ('ed111111-0000-4000-8000-000000000002', 'd1111111-0000-4000-8000-000000000002', now() + interval '1 day', now()),
  ('ed111111-0000-4000-8000-000000000003', 'd1111111-0000-4000-8000-000000000001', now() - interval '1 hour', now() - interval '2 hour');

-- Update user 2 state to locked
UPDATE private_admin.account_access
SET state = 'locked', updated_at = now()
WHERE subject_id = 'd1111111-0000-4000-8000-000000000002';

-- Add a trip for user 1 and user 2
INSERT INTO public.trips (id, user_id, title, destination_name, start_date, end_date) VALUES
  ('c1111111-0000-4000-8000-000000000001', 'd1111111-0000-4000-8000-000000000001', 'Đà Lạt Trip', 'Đà Lạt', '2026-11-01', '2026-11-03'),
  ('c1111111-0000-4000-8000-000000000002', 'd1111111-0000-4000-8000-000000000002', 'Huế Trip', 'Huế', '2026-11-05', '2026-11-07');

-- 3. RLS Negative Tests on Locked Account
SET LOCAL ROLE authenticated;

-- 3.1 Locked user cannot SELECT own profile
SELECT pg_temp.claim_user('d1111111-0000-4000-8000-000000000002', 'ed111111-0000-4000-8000-000000000002');
SELECT pg_temp.check_a2(
  (SELECT count(*) FROM public.profiles WHERE id = 'd1111111-0000-4000-8000-000000000002') = 0,
  'locked_user_profile_select_denied_by_restrictive_policy'
);

-- 3.2 Locked user cannot SELECT own trips
SELECT pg_temp.check_a2(
  (SELECT count(*) FROM public.trips WHERE id = 'c1111111-0000-4000-8000-000000000002') = 0,
  'locked_user_trips_select_denied_by_restrictive_policy'
);

-- 3.3 Locked user cannot INSERT trip
SELECT pg_temp.denied_a2(
  'INSERT INTO public.trips(id, user_id, title, destination_name, start_date, end_date) VALUES (gen_random_uuid(), ''d1111111-0000-4000-8000-000000000002'', ''Hà Nội Trip'', ''Hà Nội'', ''2026-12-01'', ''2026-12-03'')',
  '42501',
  'locked_user_trip_insert_denied'
);

-- 3.4 Locked user cannot UPDATE own profile (RLS USING filters out row, 0 rows affected)
DO $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.profiles SET full_name = 'Hacked' WHERE id = 'd1111111-0000-4000-8000-000000000002';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM pg_temp.check_a2(v_count = 0, 'locked_user_profile_update_affects_zero_rows');
END $$;

-- 3.5 Locked user cannot DELETE own trip (RLS USING filters out row, 0 rows affected)
DO $$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.trips WHERE id = 'c1111111-0000-4000-8000-000000000002';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  PERFORM pg_temp.check_a2(v_count = 0, 'locked_user_trip_delete_affects_zero_rows');
END $$;

-- 4. Enabled User Positive and Isolation Tests
SELECT pg_temp.claim_user('d1111111-0000-4000-8000-000000000001', 'ed111111-0000-4000-8000-000000000001');

-- Enabled user CAN select own profile
SELECT pg_temp.check_a2(
  (SELECT count(*) FROM public.profiles WHERE id = 'd1111111-0000-4000-8000-000000000001') = 1,
  'enabled_user_profile_select_allowed'
);

-- Enabled user CAN select own trip
SELECT pg_temp.check_a2(
  (SELECT count(*) FROM public.trips WHERE id = 'c1111111-0000-4000-8000-000000000001') = 1,
  'enabled_user_trip_select_allowed'
);

-- Enabled user CANNOT select other user's trip
SELECT pg_temp.check_a2(
  (SELECT count(*) FROM public.trips WHERE id = 'c1111111-0000-4000-8000-000000000002') = 0,
  'enabled_user_cannot_read_other_user_trip'
);

-- 5. Public Catalogue Reads Remain Public
SET LOCAL ROLE anon;
SELECT pg_temp.check_a2(
  (SELECT count(*) FROM public.destinations) >= 0,
  'public_catalogue_destinations_readable_by_anon'
);

-- 6. Check Gateway Account RPC Tests
-- 6.1 Direct caller without service_role denied
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a2(
  'SELECT public.check_gateway_account(''d1111111-0000-4000-8000-000000000001''::uuid, ''ed111111-0000-4000-8000-000000000001''::uuid, false)',
  '42501',
  'authenticated_direct_check_gateway_account_denied'
);

-- 6.2 Service role execution
SET LOCAL ROLE service_role;

-- Valid guest allowed
SELECT pg_temp.check_a2(
  (public.check_gateway_account(null, null, true)->>'allowed')::boolean = true,
  'gateway_check_valid_guest_allowed'
);

-- Guest claiming real authenticated user denied
SELECT pg_temp.denied_a2(
  'SELECT public.check_gateway_account(''d1111111-0000-4000-8000-000000000001''::uuid, null, true)',
  '42501',
  'gateway_check_guest_bypass_denied'
);

-- Valid enabled user allowed
SELECT pg_temp.check_a2(
  (public.check_gateway_account('d1111111-0000-4000-8000-000000000001'::uuid, 'ed111111-0000-4000-8000-000000000001'::uuid, false)->>'allowed')::boolean = true,
  'gateway_check_enabled_user_allowed'
);

-- Locked user denied
SELECT pg_temp.denied_a2(
  'SELECT public.check_gateway_account(''d1111111-0000-4000-8000-000000000002''::uuid, ''ed111111-0000-4000-8000-000000000002''::uuid, false)',
  '40301',
  'gateway_check_locked_user_denied'
);

-- Expired session denied
SELECT pg_temp.denied_a2(
  'SELECT public.check_gateway_account(''d1111111-0000-4000-8000-000000000001''::uuid, ''ed111111-0000-4000-8000-000000000003''::uuid, false)',
  '42501',
  'gateway_check_expired_session_denied'
);

ROLLBACK;
