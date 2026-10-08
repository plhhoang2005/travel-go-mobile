-- ==============================================================================
-- Database Test Suite: profile_privacy.sql
-- Description: Verification harness for profile privacy, RLS isolation,
--              least-privilege grants, and signup role hardening.
-- Traceability: R01, DB-002, DB-003, DB-004, DB-006; AC-034, AC-054
-- Target: PostgreSQL 17.x / Supabase Local or Staging Environment
-- Execution: psql -f supabase/tests/profile_privacy.sql (Wraps in transaction & rolls back)
-- ==============================================================================

BEGIN;

-- Setup temporary test schemas and helper functions for role simulation
CREATE TEMPORARY TABLE test_results (
  test_name text PRIMARY KEY,
  status text NOT NULL,
  details text
);

-- Helper to record test results
CREATE OR REPLACE FUNCTION record_test(t_name text, pass boolean, note text DEFAULT '')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO test_results (test_name, status, details)
  VALUES (t_name, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END, note);
END;
$$;

-- ------------------------------------------------------------------------------
-- 1. FIXTURE SETUP (Synthetic Users in auth.users and public.profiles)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  has_auth_users boolean;
BEGIN
  -- Check if auth.users exists in current environment
  SELECT EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users'
  ) INTO has_auth_users;

  IF has_auth_users THEN
    -- Insert synthetic auth users first to avoid FK constraint violations
    INSERT INTO auth.users (
      id, aud, role, email, raw_user_meta_data, created_at, updated_at
    )
    VALUES
      (uid_a, 'authenticated', 'authenticated', 'alice@travelgo.vn', '{"full_name": "Alice Travel"}'::jsonb, now(), now()),
      (uid_b, 'authenticated', 'authenticated', 'bob@travelgo.vn', '{"full_name": "Bob Explorer"}'::jsonb, now(), now())
    ON CONFLICT (id) DO UPDATE SET
      raw_user_meta_data = EXCLUDED.raw_user_meta_data,
      updated_at = now();
  END IF;

  -- Ensure matching profiles exist
  INSERT INTO public.profiles (id, full_name, email, phone, role)
  VALUES
    (uid_a, 'Alice Travel', 'alice@travelgo.vn', '0901111111', 'customer'),
    (uid_b, 'Bob Explorer', 'bob@travelgo.vn', '0902222222', 'customer')
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = EXCLUDED.role;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TEST CASE 1: Profile Privacy Isolation (A vs B vs Anon)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  cnt_a_sees_a int;
  cnt_b_sees_a int;
  cnt_anon_sees_a int;
BEGIN
  -- Simulate User A
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);
  SELECT count(*) INTO cnt_a_sees_a FROM public.profiles WHERE id = uid_a;

  -- Simulate User B
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_b::text, true);
  SELECT count(*) INTO cnt_b_sees_a FROM public.profiles WHERE id = uid_a;

  -- Simulate Anon
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  SELECT count(*) INTO cnt_anon_sees_a FROM public.profiles WHERE id = uid_a;

  PERFORM record_test(
    'TC1_profile_privacy_isolation',
    (cnt_a_sees_a = 1 AND cnt_b_sees_a = 0 AND cnt_anon_sees_a = 0),
    format('A sees A: %s, B sees A: %s, Anon sees A: %s', cnt_a_sees_a, cnt_b_sees_a, cnt_anon_sees_a)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 3. TEST CASE 2: Allowed Column Updates for Own Profile
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  updated_name text;
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  UPDATE public.profiles
  SET full_name = 'Alice Updated', phone = '0909999999'
  WHERE id = uid_a;

  SELECT full_name INTO updated_name FROM public.profiles WHERE id = uid_a;

  PERFORM record_test(
    'TC2_profile_allowed_column_update',
    (updated_name = 'Alice Updated'),
    format('Updated name: %s', updated_name)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 4. TEST CASE 3: Protected Column Updates Denied (role, email, id) + SQLSTATE 42501
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  has_role_update_privilege boolean;
  denial_caught boolean := false;
  caught_sqlstate text := '';
BEGIN
  -- 1. Check metadata privilege dictionary
  SELECT has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE')
  INTO has_role_update_privilege;

  -- 2. Negative assertion: attempt runtime UPDATE on protected column 'role' as authenticated role
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

    UPDATE public.profiles SET role = 'admin' WHERE id = uid_a;
  EXCEPTION
    WHEN insufficient_privilege THEN -- PostgreSQL SQLSTATE 42501
      denial_caught := true;
      caught_sqlstate := '42501';
    WHEN OTHERS THEN
      caught_sqlstate := SQLSTATE;
  END;

  PERFORM record_test(
    'TC3_protected_column_role_update_denied',
    (has_role_update_privilege = false AND denial_caught = true),
    format('has_column_privilege: %s, runtime denial caught: %s, SQLSTATE: %s', has_role_update_privilege, denial_caught, caught_sqlstate)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 5. TEST CASE 4: Signup Role Spoofing Prevention via Actual Auth Trigger
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  test_signup_id uuid := '33333333-3333-3333-3333-333333333333';
  assigned_role text;
  has_auth_users boolean;
BEGIN
  -- Check if auth.users exists
  SELECT EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users'
  ) INTO has_auth_users;

  IF has_auth_users THEN
    -- Insert into auth.users with malicious userMetadata role='admin' to trigger handle_new_user()
    INSERT INTO auth.users (
      id, aud, role, email, raw_user_meta_data, created_at, updated_at
    )
    VALUES (
      test_signup_id,
      'authenticated',
      'authenticated',
      'attacker@travelgo.vn',
      '{"full_name": "Eve Attacker", "role": "admin"}'::jsonb,
      now(),
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- Isolated schema testing fallback: directly invoke handle_new_user with synthetic record
    PERFORM public.handle_new_user();
  END IF;

  SELECT role INTO assigned_role FROM public.profiles WHERE id = test_signup_id;

  PERFORM record_test(
    'TC4_signup_role_spoofing_prevented',
    (assigned_role = 'customer'),
    format('Assigned role for attacker via trigger: %s (expected customer)', assigned_role)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 6. TEST CASE 5: Least-Privilege Grants (TRUNCATE & Catalogue Writes Denied)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  can_auth_truncate boolean;
  can_anon_truncate boolean;
  can_auth_insert_dest boolean;
BEGIN
  SELECT has_table_privilege('authenticated', 'public.trips', 'TRUNCATE') INTO can_auth_truncate;
  SELECT has_table_privilege('anon', 'public.trips', 'TRUNCATE') INTO can_anon_truncate;
  SELECT has_table_privilege('authenticated', 'public.destinations', 'INSERT') INTO can_auth_insert_dest;

  PERFORM record_test(
    'TC5_least_privilege_grants',
    (can_auth_truncate = false AND can_anon_truncate = false AND can_auth_insert_dest = false),
    format('auth TRUNCATE: %s, anon TRUNCATE: %s, auth INSERT dest: %s', can_auth_truncate, can_anon_truncate, can_auth_insert_dest)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 7. TEST CASE 6: Trips & Activities Owner RLS Isolation
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  test_trip_id uuid := '44444444-4444-4444-4444-444444444444';
  test_act_id uuid := '55555555-5555-5555-5555-555555555555';
  b_sees_trip_a int;
  a_sees_own_trip int;
  b_sees_act_a int;
  a_sees_own_act int;
BEGIN
  -- Insert trip and activity for User A (as postgres/service_role fixture)
  INSERT INTO public.trips (id, user_id, title, destination_name, num_days, budget_total, ai_plan_data)
  VALUES (test_trip_id, uid_a, 'Trip to Da Nang', 'Đà Nẵng', 3, 5000000, '{"plan": "test"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.trip_activities (id, trip_id, day_number, activity_name, estimated_cost)
  VALUES (test_act_id, test_trip_id, 1, 'Bà Nà Hills', 1000000)
  ON CONFLICT (id) DO NOTHING;

  -- User A selects trip & activity
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);
  SELECT count(*) INTO a_sees_own_trip FROM public.trips WHERE id = test_trip_id;
  SELECT count(*) INTO a_sees_own_act FROM public.trip_activities WHERE id = test_act_id;

  -- User B selects trip & activity
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_b::text, true);
  SELECT count(*) INTO b_sees_trip_a FROM public.trips WHERE id = test_trip_id;
  SELECT count(*) INTO b_sees_act_a FROM public.trip_activities WHERE id = test_act_id;

  PERFORM record_test(
    'TC6_trips_rls_isolation',
    (a_sees_own_trip = 1 AND b_sees_trip_a = 0 AND a_sees_own_act = 1 AND b_sees_act_a = 0),
    format('A sees trip: %s, B sees trip: %s; A sees act: %s, B sees act: %s', a_sees_own_trip, b_sees_trip_a, a_sees_own_act, b_sees_act_a)
  );
END $$;

-- ------------------------------------------------------------------------------
-- DISPLAY RESULTS & VERIFY ZERO FAILURES
-- ------------------------------------------------------------------------------
SELECT test_name, status, details FROM test_results ORDER BY test_name;

DO $$
DECLARE
  failed_count int;
BEGIN
  SELECT count(*) INTO failed_count FROM test_results WHERE status = 'FAIL';
  IF failed_count > 0 THEN
    RAISE EXCEPTION 'Test suite encountered % failures!', failed_count;
  END IF;
END $$;

-- Clean rollback of test execution
ROLLBACK;
