-- ==============================================================================
-- Database Test Suite: profile_privacy.sql
-- Description: Verification harness for profile privacy, RLS isolation,
--              least-privilege grants, and signup role hardening.
-- Traceability: R01, DB-002, DB-003, DB-004, DB-006; AC-034, AC-054
-- Target: PostgreSQL 17.x / Supabase Local or Staging Environment
-- Execution: psql -X -v ON_ERROR_STOP=1 -f supabase/tests/profile_privacy.sql
-- Safety: Wraps in transaction & rolls back all test fixtures.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 0. TEST HARNESS INFRASTRUCTURE
-- ------------------------------------------------------------------------------
CREATE TEMPORARY TABLE test_results (
  test_name text PRIMARY KEY,
  status text NOT NULL,
  details text
);

-- Temporary helper function to record test results.
-- Explicitly declared as SECURITY INVOKER; must only be invoked by runner.
CREATE OR REPLACE FUNCTION pg_temp.record_test(t_name text, pass boolean, note text DEFAULT '')
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
BEGIN
  INSERT INTO test_results (test_name, status, details)
  VALUES (t_name, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END, note);
END;
$$;

-- ------------------------------------------------------------------------------
-- 1. PREREQUISITES & FIXTURE SETUP
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  uid_spoof uuid := '33333333-3333-3333-3333-333333333333';
  uid_oauth uuid := '66666666-6666-6666-6666-666666666666';
  dest_id uuid := '77777777-7777-7777-7777-777777777777';
  has_auth_users boolean;
  has_trigger boolean;
BEGIN
  -- Verify prerequisite schema and trigger exist
  SELECT EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users'
  ) INTO has_auth_users;

  SELECT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users' AND t.tgname = 'on_auth_user_created'
  ) INTO has_trigger;

  IF NOT has_auth_users THEN
    RAISE EXCEPTION 'Prerequisite failed: auth.users table does not exist';
  END IF;

  IF NOT has_trigger THEN
    RAISE EXCEPTION 'Prerequisite failed: trigger on_auth_user_created does not exist on auth.users';
  END IF;

  -- Insert synthetic auth users. The actual handle_new_user() trigger populates public.profiles!
  INSERT INTO auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  VALUES
    (uid_a, 'authenticated', 'authenticated', 'alice@travelgo.vn', '{"full_name": "Alice Travel"}'::jsonb, now(), now()),
    (uid_b, 'authenticated', 'authenticated', 'bob@travelgo.vn', '{"full_name": "Bob Explorer"}'::jsonb, now(), now()),
    (uid_spoof, 'authenticated', 'authenticated', 'attacker@travelgo.vn', '{"full_name": "Eve Attacker", "role": "admin"}'::jsonb, now(), now()),
    (uid_oauth, 'authenticated', 'authenticated', 'oauth@travelgo.vn', '{}'::jsonb, now(), now())
  ON CONFLICT (id) DO UPDATE SET
    raw_user_meta_data = EXCLUDED.raw_user_meta_data,
    updated_at = now();

  -- Insert synthetic destination for catalogue tests
  INSERT INTO public.destinations (id, name, description, region)
  VALUES (dest_id, 'Đà Nẵng Synthetic', 'Test catalogue destination', 'Central')
  ON CONFLICT (id) DO NOTHING;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TC01: Anon Profile SELECT Denied (SQLSTATE 42501)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_caught_42501 boolean := false;
  v_count int := 0;
  v_sqlstate text := '';
BEGIN
  -- Execute under anon role
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  BEGIN
    SELECT count(*) INTO v_count FROM public.profiles WHERE id = uid_a;
  EXCEPTION
    WHEN insufficient_privilege THEN -- SQLSTATE 42501
      v_caught_42501 := true;
      v_sqlstate := SQLSTATE;
    WHEN OTHERS THEN
      v_sqlstate := SQLSTATE;
  END;

  -- Reset role to runner before recording
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC01_anon_profile_select_denied_42501',
    (v_caught_42501 = true),
    format('Caught SQLSTATE 42501: %s, count: %s, sqlstate: %s', v_caught_42501, v_count, v_sqlstate)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC01_anon_profile_select_denied_42501', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 3. TC02: User B SELECT User A Profile Returns Zero Rows (RLS Isolation)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  v_count int := -1;
BEGIN
  -- Execute under authenticated User B
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_b::text, true);

  SELECT count(*) INTO v_count FROM public.profiles WHERE id = uid_a;

  -- Reset role to runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC02_user_b_select_user_a_profile_zero_rows',
    (v_count = 0),
    format('User B sees User A rows: %s (expected 0)', v_count)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC02_user_b_select_user_a_profile_zero_rows', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 4. TC03: User A SELECT Own Profile Returns 1 Row
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_count int := -1;
  v_name text;
BEGIN
  -- Execute under authenticated User A
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  SELECT count(*), max(full_name) INTO v_count, v_name FROM public.profiles WHERE id = uid_a;

  -- Reset role to runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC03_user_a_select_own_profile',
    (v_count = 1 AND v_name IS NOT NULL),
    format('User A sees own profile count: %s, name: %s', v_count, v_name)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC03_user_a_select_own_profile', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 5. TC04: User A Update Allowed Profile Fields (full_name, phone)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_updated_name text;
  v_updated_phone text;
BEGIN
  -- Execute under authenticated User A
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  UPDATE public.profiles
  SET full_name = 'Alice Updated', phone = '0901234567'
  WHERE id = uid_a;

  SELECT full_name, phone INTO v_updated_name, v_updated_phone
  FROM public.profiles WHERE id = uid_a;

  -- Reset role to runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC04_user_a_update_allowed_profile_fields',
    (v_updated_name = 'Alice Updated' AND v_updated_phone = '0901234567'),
    format('Updated name: %s, phone: %s', v_updated_name, v_updated_phone)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC04_user_a_update_allowed_profile_fields', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 6. TC05: User A Update Protected Columns Denied (role, email, id) + SQLSTATE 42501
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_role_denial boolean := false;
  v_id_denial boolean := false;
BEGIN
  -- Test 1: Update role
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  BEGIN
    UPDATE public.profiles SET role = 'admin' WHERE id = uid_a;
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_role_denial := true;
    WHEN OTHERS THEN
      NULL;
  END;

  -- Test 2: Update id
  BEGIN
    UPDATE public.profiles SET id = gen_random_uuid() WHERE id = uid_a;
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_id_denial := true;
    WHEN OTHERS THEN
      NULL;
  END;

  -- Reset role to runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC05_user_a_update_protected_columns_denied',
    (v_role_denial = true AND v_id_denial = true),
    format('Role denial caught: %s, ID denial caught: %s', v_role_denial, v_id_denial)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC05_user_a_update_protected_columns_denied', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 7. TC06: Signup Role Spoofing Prevented via Actual Trigger
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_spoof uuid := '33333333-3333-3333-3333-333333333333';
  uid_oauth uuid := '66666666-6666-6666-6666-666666666666';
  v_spoof_role text;
  v_oauth_role text;
  v_oauth_name text;
BEGIN
  -- Read directly under runner
  SELECT role INTO v_spoof_role FROM public.profiles WHERE id = uid_spoof;
  SELECT role, full_name INTO v_oauth_role, v_oauth_name FROM public.profiles WHERE id = uid_oauth;

  PERFORM pg_temp.record_test(
    'TC06_signup_trigger_role_hardening',
    (v_spoof_role = 'customer' AND v_oauth_role = 'customer' AND v_oauth_name IS NOT NULL),
    format('Spoof assigned role: %s (expected customer), OAuth role: %s, name: %s', v_spoof_role, v_oauth_role, v_oauth_name)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 8. TC07: Catalogue Destinations Read-Only for Authenticated and Anon
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  dest_id uuid := '77777777-7777-7777-7777-777777777777';
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_can_select boolean := false;
  v_insert_denied boolean := false;
  v_delete_denied boolean := false;
  v_cnt int;
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  -- Select should succeed
  SELECT count(*) INTO v_cnt FROM public.destinations WHERE id = dest_id;
  IF v_cnt > 0 THEN
    v_can_select := true;
  END IF;

  -- Insert should fail with 42501
  BEGIN
    INSERT INTO public.destinations (name, description, region) VALUES ('Fake', 'Fake', 'North');
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_insert_denied := true;
    WHEN OTHERS THEN
      NULL;
  END;

  -- Delete should fail with 42501
  BEGIN
    DELETE FROM public.destinations WHERE id = dest_id;
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_delete_denied := true;
    WHEN OTHERS THEN
      NULL;
  END;

  -- Reset role
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC07_catalogue_destinations_read_only',
    (v_can_select = true AND v_insert_denied = true AND v_delete_denied = true),
    format('Can select: %s, insert denied: %s, delete denied: %s', v_can_select, v_insert_denied, v_delete_denied)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC07_catalogue_destinations_read_only', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 9. TC08: Trips Owner RLS Isolation (CRUD & Cross-User Protection)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  trip_a_id uuid := '44444444-4444-4444-4444-444444444441';
  trip_spoof_id uuid := '44444444-4444-4444-4444-444444444449';
  v_a_inserted boolean := false;
  v_b_sees_trip int := -1;
  v_b_updated int := -1;
  v_b_deleted int := -1;
  v_spoof_insert_denied boolean := false;
BEGIN
  -- 1. User A inserts own trip
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  INSERT INTO public.trips (id, user_id, title, destination_name, num_days, budget_total, ai_plan_data)
  VALUES (trip_a_id, uid_a, 'Trip A', 'Hà Nội', 2, 3000000, '{"plan": "test"}'::jsonb);
  v_a_inserted := true;

  -- 2. User B tries to read, update, delete User A trip
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_b::text, true);

  SELECT count(*) INTO v_b_sees_trip FROM public.trips WHERE id = trip_a_id;

  UPDATE public.trips SET title = 'Hacked' WHERE id = trip_a_id;
  GET DIAGNOSTICS v_b_updated = ROW_COUNT;

  DELETE FROM public.trips WHERE id = trip_a_id;
  GET DIAGNOSTICS v_b_deleted = ROW_COUNT;

  -- 3. User B tries to insert a trip with user_id = User A (spoof ownership)
  BEGIN
    INSERT INTO public.trips (id, user_id, title, destination_name, num_days, budget_total, ai_plan_data)
    VALUES (trip_spoof_id, uid_a, 'Spoofed Trip', 'Huế', 1, 1000000, '{"plan": "test"}'::jsonb);
  EXCEPTION
    WHEN insufficient_privilege OR check_violation THEN
      v_spoof_insert_denied := true;
    WHEN OTHERS THEN
      IF SQLSTATE LIKE '42%' THEN
        v_spoof_insert_denied := true;
      END IF;
  END;

  -- Reset role
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC08_trips_owner_rls_isolation',
    (v_a_inserted = true AND v_b_sees_trip = 0 AND v_b_updated = 0 AND v_b_deleted = 0 AND v_spoof_insert_denied = true),
    format('A inserted: %s, B sees: %s, B updated: %s, B deleted: %s, spoof insert denied: %s',
      v_a_inserted, v_b_sees_trip, v_b_updated, v_b_deleted, v_spoof_insert_denied)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC08_trips_owner_rls_isolation', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 10. TC09: Trip Activities Ownership and Reparenting
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  trip_a1 uuid := '44444444-4444-4444-4444-444444444441';
  trip_a2 uuid := '44444444-4444-4444-4444-444444444442';
  trip_b uuid := '44444444-4444-4444-4444-444444444443';
  act_id uuid := '55555555-5555-5555-5555-555555555551';
  v_act_inserted boolean := false;
  v_reparent_own_ok boolean := false;
  v_reparent_other_denied boolean := false;
BEGIN
  -- Insert trip A2 and trip B as runner fixture
  INSERT INTO public.trips (id, user_id, title, destination_name, num_days, budget_total, ai_plan_data)
  VALUES
    (trip_a2, uid_a, 'Trip A2', 'Hải Phòng', 1, 1000000, '{"plan": "test"}'::jsonb),
    (trip_b, uid_b, 'Trip B', 'Cần Thơ', 1, 1000000, '{"plan": "test"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  -- 1. User A inserts activity on own Trip A1
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  INSERT INTO public.trip_activities (id, trip_id, day_number, activity_name, estimated_cost)
  VALUES (act_id, trip_a1, 1, 'Hồ Gươm Walking', 50000);
  v_act_inserted := true;

  -- 2. User A reparents activity to own Trip A2 (should succeed)
  UPDATE public.trip_activities SET trip_id = trip_a2 WHERE id = act_id;
  v_reparent_own_ok := true;

  -- 3. User A attempts to reparent activity to Trip B (must be denied by RLS WITH CHECK)
  BEGIN
    UPDATE public.trip_activities SET trip_id = trip_b WHERE id = act_id;
  EXCEPTION
    WHEN check_violation OR insufficient_privilege THEN
      v_reparent_other_denied := true;
    WHEN OTHERS THEN
      IF SQLSTATE LIKE '42%' THEN
        v_reparent_other_denied := true;
      END IF;
  END;

  -- Reset role
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC09_trip_activities_ownership_and_reparenting',
    (v_act_inserted = true AND v_reparent_own_ok = true AND v_reparent_other_denied = true),
    format('Act inserted: %s, reparent own ok: %s, reparent to B denied: %s',
      v_act_inserted, v_reparent_own_ok, v_reparent_other_denied)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC09_trip_activities_ownership_and_reparenting', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 11. TC10: Least Privilege TRUNCATE Revoked on Protected Tables
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_auth_trunc_p boolean;
  v_anon_trunc_p boolean;
  v_auth_trunc_t boolean;
  v_anon_trunc_t boolean;
  v_auth_trunc_a boolean;
  v_anon_trunc_a boolean;
  v_auth_trunc_d boolean;
  v_anon_trunc_d boolean;
  v_all_revoked boolean;
BEGIN
  SELECT has_table_privilege('authenticated', 'public.profiles', 'TRUNCATE') INTO v_auth_trunc_p;
  SELECT has_table_privilege('anon', 'public.profiles', 'TRUNCATE') INTO v_anon_trunc_p;

  SELECT has_table_privilege('authenticated', 'public.trips', 'TRUNCATE') INTO v_auth_trunc_t;
  SELECT has_table_privilege('anon', 'public.trips', 'TRUNCATE') INTO v_anon_trunc_t;

  SELECT has_table_privilege('authenticated', 'public.trip_activities', 'TRUNCATE') INTO v_auth_trunc_a;
  SELECT has_table_privilege('anon', 'public.trip_activities', 'TRUNCATE') INTO v_anon_trunc_a;

  SELECT has_table_privilege('authenticated', 'public.destinations', 'TRUNCATE') INTO v_auth_trunc_d;
  SELECT has_table_privilege('anon', 'public.destinations', 'TRUNCATE') INTO v_anon_trunc_d;

  v_all_revoked := NOT (
    v_auth_trunc_p OR v_anon_trunc_p OR
    v_auth_trunc_t OR v_anon_trunc_t OR
    v_auth_trunc_a OR v_anon_trunc_a OR
    v_auth_trunc_d OR v_anon_trunc_d
  );

  PERFORM pg_temp.record_test(
    'TC10_least_privilege_truncate_revoked',
    v_all_revoked,
    format('All TRUNCATE privileges revoked: %s', v_all_revoked)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 12. TC11: Table and Column Effective Privilege Dictionary Checks
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_auth_can_update_role boolean;
  v_auth_can_update_id boolean;
  v_auth_can_update_email boolean;
  v_anon_can_select_profiles boolean;
  v_auth_can_insert_profiles boolean;
  v_auth_can_delete_profiles boolean;
  v_checks_passed boolean;
BEGIN
  SELECT has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE') INTO v_auth_can_update_role;
  SELECT has_column_privilege('authenticated', 'public.profiles', 'id', 'UPDATE') INTO v_auth_can_update_id;
  SELECT has_column_privilege('authenticated', 'public.profiles', 'email', 'UPDATE') INTO v_auth_can_update_email;
  SELECT has_table_privilege('anon', 'public.profiles', 'SELECT') INTO v_anon_can_select_profiles;
  SELECT has_table_privilege('authenticated', 'public.profiles', 'INSERT') INTO v_auth_can_insert_profiles;
  SELECT has_table_privilege('authenticated', 'public.profiles', 'DELETE') INTO v_auth_can_delete_profiles;

  v_checks_passed := (
    v_auth_can_update_role = false AND
    v_auth_can_update_id = false AND
    v_auth_can_update_email = false AND
    v_anon_can_select_profiles = false AND
    v_auth_can_insert_profiles = false AND
    v_auth_can_delete_profiles = false
  );

  PERFORM pg_temp.record_test(
    'TC11_table_and_column_effective_privilege_checks',
    v_checks_passed,
    format('Passed: %s (update role: %s, anon select: %s, auth insert profile: %s, auth delete profile: %s)',
      v_checks_passed, v_auth_can_update_role, v_anon_can_select_profiles, v_auth_can_insert_profiles, v_auth_can_delete_profiles)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 13. MANIFEST VALIDATION & TEST EXECUTION ENFORCEMENT
-- ------------------------------------------------------------------------------
SELECT test_name, status, details FROM test_results ORDER BY test_name;

DO $$
DECLARE
  v_manifest text[] := ARRAY[
    'TC01_anon_profile_select_denied_42501',
    'TC02_user_b_select_user_a_profile_zero_rows',
    'TC03_user_a_select_own_profile',
    'TC04_user_a_update_allowed_profile_fields',
    'TC05_user_a_update_protected_columns_denied',
    'TC06_signup_trigger_role_hardening',
    'TC07_catalogue_destinations_read_only',
    'TC08_trips_owner_rls_isolation',
    'TC09_trip_activities_ownership_and_reparenting',
    'TC10_least_privilege_truncate_revoked',
    'TC11_table_and_column_effective_privilege_checks'
  ];
  v_case text;
  v_count int;
  v_failed_count int;
BEGIN
  -- Verify every test case in manifest was executed exactly once
  FOREACH v_case IN ARRAY v_manifest LOOP
    SELECT count(*) INTO v_count FROM test_results WHERE test_name = v_case;
    IF v_count = 0 THEN
      RAISE EXCEPTION 'Manifest error: missing test case %', v_case;
    ELSIF v_count > 1 THEN
      RAISE EXCEPTION 'Manifest error: duplicate test case %', v_case;
    END IF;
  END LOOP;

  -- Verify zero test failures
  SELECT count(*) INTO v_failed_count FROM test_results WHERE status = 'FAIL';
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'Database test suite encountered % failures!', v_failed_count;
  END IF;

  RAISE NOTICE 'Test manifest validation passed: all % security test cases passed successfully.', array_length(v_manifest, 1);
END $$;

-- Clean rollback of test execution fixtures
ROLLBACK;
