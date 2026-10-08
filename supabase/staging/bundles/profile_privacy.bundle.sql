-- ==============================================================================
-- Database Test Suite: profile_privacy.sql
-- Description: Verification harness for profile privacy, RLS isolation,
--              least-privilege grants, and signup role hardening.
-- Traceability: R01, DB-002, DB-003, DB-004, DB-006; AC-034, AC-054
-- Target: PostgreSQL 17.x / Supabase Staging Environment (bkocylxbuyvdgxccpixx)
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
-- Shared Test Helpers (single authoritative source)
-- ------------------------------------------------------------------------------
-- >>> START INJECTED DEPENDENCY: profile_privacy_test_helpers.sql (LF-SHA256: F2FC32DF66CEE51B7CAA34C06854C27D1254D39CF6826E600345108CFDD127F7) <<<
-- ==============================================================================
-- Test Suite Shared Helpers: profile_privacy_test_helpers.sql
-- Description: Authoritative single source of test assertion and classification
--              helpers for database test suites. Strictly scoped to pg_temp
--              (session-scoped temporary schema).
-- Safety: Never creates persistent public API objects.
-- ==============================================================================

-- 1. Shared query error classifier helper
-- Distinguishes insufficient_privilege (42501) vs undefined_column (42703) vs others
CREATE OR REPLACE FUNCTION pg_temp.classify_query_error(p_sql text)
RETURNS text LANGUAGE plpgsql AS $helper$
BEGIN
  EXECUTE p_sql;
  RETURN 'SUCCESS';
EXCEPTION
  WHEN insufficient_privilege THEN
    RETURN 'DENIED_42501';
  WHEN undefined_column THEN
    RETURN 'UNDEFINED_COLUMN_42703';
  WHEN OTHERS THEN
    RETURN 'OTHER_' || SQLSTATE;
END;
$helper$;

-- 2. Shared reparent assertion gate helper
-- Enforces that reparenting updates exactly 1 row and matches target parent trip
CREATE OR REPLACE FUNCTION pg_temp.gate_assert_reparent_success(p_act_id uuid, p_target_trip_id uuid)
RETURNS void LANGUAGE plpgsql AS $helper$
DECLARE
  v_rows int;
  v_stored_parent uuid;
BEGIN
  UPDATE public.trip_activities SET trip_id = p_target_trip_id WHERE id = p_act_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'REPARENT_ASSERTION_FAILURE: expected exactly 1 row updated, got %', v_rows;
  END IF;

  SELECT trip_id INTO v_stored_parent FROM public.trip_activities WHERE id = p_act_id;
  IF v_stored_parent <> p_target_trip_id THEN
    RAISE EXCEPTION 'REPARENT_ASSERTION_FAILURE: stored parent % does not match target %', v_stored_parent, p_target_trip_id;
  END IF;
END;
$helper$;
-- >>> END INJECTED DEPENDENCY: profile_privacy_test_helpers.sql <<<
-- ------------------------------------------------------------------------------
-- 1. PREREQUISITES & FIXTURE SETUP (Fails on Collision; Audited Schema)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  uid_spoof uuid := '33333333-3333-3333-3333-333333333333';
  uid_oauth uuid := '66666666-6666-6666-6666-666666666666';
  uid_no_email uuid := '77777777-7777-7777-7777-777777777777';
  dest_id text := 'da-nang-synthetic';
  svc_id text := 'svc-ba-na-synthetic';
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

  -- Ensure unique test identities: fail closed on collision rather than silent upsert
  IF EXISTS (SELECT 1 FROM auth.users WHERE id IN (uid_a, uid_b, uid_spoof, uid_oauth, uid_no_email)) THEN
    RAISE EXCEPTION 'Fixture collision: synthetic test user IDs already exist in auth.users';
  END IF;

  -- Insert synthetic auth users. The actual handle_new_user() trigger populates public.profiles!
  INSERT INTO auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  VALUES
    (uid_a, 'authenticated', 'authenticated', 'alice@travelgo.vn', '{"full_name": "Alice Travel"}'::jsonb, now(), now()),
    (uid_b, 'authenticated', 'authenticated', 'bob@travelgo.vn', '{"full_name": "Bob Explorer"}'::jsonb, now(), now()),
    (uid_spoof, 'authenticated', 'authenticated', 'attacker@travelgo.vn', '{"full_name": "Eve Attacker", "role": "admin"}'::jsonb, now(), now()),
    (uid_oauth, 'authenticated', 'authenticated', 'oauth@travelgo.vn', '{}'::jsonb, now(), now()),
    (uid_no_email, 'authenticated', 'authenticated', NULL, '{}'::jsonb, now(), now());

  -- Insert synthetic destination for catalogue tests (audited schema: id text, region check)
  INSERT INTO public.destinations (id, name, description, region, is_popular)
  VALUES (dest_id, 'Đà Nẵng Synthetic', 'Test catalogue destination', 'Trung', true)
  ON CONFLICT (id) DO NOTHING;

  -- Insert synthetic service (dependency for trip_activities.service_id, audited: title text, service_type tour)
  INSERT INTO public.services (id, destination_id, title, service_type)
  VALUES (svc_id, dest_id, 'Bà Nà Tour Cable Car', 'tour')
  ON CONFLICT (id) DO NOTHING;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TC01: Anon Profile SELECT Denied (SQLSTATE 42501)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_res text;
BEGIN
  -- Execute under anon role
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  v_res := pg_temp.classify_query_error(format('SELECT count(*) FROM public.profiles WHERE id = %L', uid_a));

  -- Reset role to runner before recording
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC01_anon_profile_select_denied_42501',
    (v_res = 'DENIED_42501'),
    format('Classification result: %s (expected DENIED_42501)', v_res)
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
-- 5. TC04: User A Update Allowed Profile Fields (full_name, phone, address, avatar_url)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_updated_name text;
  v_updated_phone text;
  v_updated_address text;
BEGIN
  -- Execute under authenticated User A
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  UPDATE public.profiles
  SET full_name = 'Alice Updated', phone = '0901234567', address = '123 Da Nang'
  WHERE id = uid_a;

  SELECT full_name, phone, address INTO v_updated_name, v_updated_phone, v_updated_address
  FROM public.profiles WHERE id = uid_a;

  -- Reset role to runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC04_user_a_update_allowed_profile_fields',
    (v_updated_name = 'Alice Updated' AND v_updated_phone = '0901234567' AND v_updated_address = '123 Da Nang'),
    format('Updated name: %s, phone: %s, address: %s', v_updated_name, v_updated_phone, v_updated_address)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC04_user_a_update_allowed_profile_fields', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 6. TC05: User A Update Protected Columns Denied (role, email, id, created_at, updated_at) + SQLSTATE 42501
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_role_res text;
  v_id_res text;
  v_email_res text;
  v_created_res text;
  v_updated_res text;
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  -- 1. Update role
  v_role_res := pg_temp.classify_query_error(format('UPDATE public.profiles SET role = %L WHERE id = %L', 'admin', uid_a));

  -- 2. Update id
  v_id_res := pg_temp.classify_query_error(format('UPDATE public.profiles SET id = %L WHERE id = %L', gen_random_uuid(), uid_a));

  -- 3. Update email
  v_email_res := pg_temp.classify_query_error(format('UPDATE public.profiles SET email = %L WHERE id = %L', 'attacker@travelgo.vn', uid_a));

  -- 4. Update created_at
  v_created_res := pg_temp.classify_query_error(format('UPDATE public.profiles SET created_at = %L WHERE id = %L', now() - interval '1 year', uid_a));

  -- 5. Update updated_at
  v_updated_res := pg_temp.classify_query_error(format('UPDATE public.profiles SET updated_at = %L WHERE id = %L', now() - interval '1 day', uid_a));

  -- Reset role to runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC05_user_a_update_protected_columns_denied',
    (v_role_res = 'DENIED_42501' AND v_id_res = 'DENIED_42501' AND v_email_res = 'DENIED_42501' AND
     v_created_res = 'DENIED_42501' AND v_updated_res = 'DENIED_42501'),
    format('Role: %s, ID: %s, Email: %s, Created: %s, Updated: %s (all must be DENIED_42501)',
      v_role_res, v_id_res, v_email_res, v_created_res, v_updated_res)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC05_user_a_update_protected_columns_denied', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 7. TC06: Signup Role Spoofing Prevented & Safe OAuth Fallbacks
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_spoof uuid := '33333333-3333-3333-3333-333333333333';
  uid_oauth uuid := '66666666-6666-6666-6666-666666666666';
  uid_no_email uuid := '77777777-7777-7777-7777-777777777777';
  v_spoof_role text;
  v_oauth_role text;
  v_oauth_name text;
  v_no_email_role text;
  v_no_email_name text;
  v_no_email_addr text;
BEGIN
  -- Read directly under runner
  SELECT role INTO v_spoof_role FROM public.profiles WHERE id = uid_spoof;
  SELECT role, full_name INTO v_oauth_role, v_oauth_name FROM public.profiles WHERE id = uid_oauth;
  SELECT role, full_name, email INTO v_no_email_role, v_no_email_name, v_no_email_addr FROM public.profiles WHERE id = uid_no_email;

  PERFORM pg_temp.record_test(
    'TC06_signup_trigger_role_hardening',
    (v_spoof_role = 'customer' AND v_oauth_role = 'customer' AND v_oauth_name IS NOT NULL AND v_oauth_name <> '' AND
     v_no_email_role = 'customer' AND v_no_email_name = 'Thành viên TravelGO' AND v_no_email_addr IS NULL),
    format('Spoof role: %s, OAuth role: %s (name: %s), Missing email role: %s (name: %s, email: %s)',
      v_spoof_role, v_oauth_role, v_oauth_name, v_no_email_role, v_no_email_name, v_no_email_addr)
  );
END $$;

-- ------------------------------------------------------------------------------
-- 8. TC07: Catalogue Destinations Read-Only for Authenticated and Anon
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  dest_id text := 'da-nang-synthetic';
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_auth_can_select boolean := false;
  v_auth_insert_denied boolean := false;
  v_auth_delete_denied boolean := false;
  v_anon_can_select boolean := false;
  v_anon_insert_denied boolean := false;
  v_cnt int;
BEGIN
  -- Authenticated role assertions
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  SELECT count(*) INTO v_cnt FROM public.destinations WHERE id = dest_id;
  IF v_cnt > 0 THEN v_auth_can_select := true; END IF;

  BEGIN
    INSERT INTO public.destinations (id, name, description, region) VALUES ('fake-id', 'Fake', 'Fake', 'Bắc');
  EXCEPTION
    WHEN insufficient_privilege THEN -- SQLSTATE 42501
      v_auth_insert_denied := true;
  END;

  BEGIN
    DELETE FROM public.destinations WHERE id = dest_id;
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_auth_delete_denied := true;
  END;

  -- Anon role assertions
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  SELECT count(*) INTO v_cnt FROM public.destinations WHERE id = dest_id;
  IF v_cnt > 0 THEN v_anon_can_select := true; END IF;

  BEGIN
    INSERT INTO public.destinations (id, name, description, region) VALUES ('fake-anon', 'Fake', 'Fake', 'Bắc');
  EXCEPTION
    WHEN insufficient_privilege THEN
      v_anon_insert_denied := true;
  END;

  -- Reset role
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC07_catalogue_destinations_read_only',
    (v_auth_can_select = true AND v_auth_insert_denied = true AND v_auth_delete_denied = true AND
     v_anon_can_select = true AND v_anon_insert_denied = true),
    format('Auth read: %s, Auth write denied: %s, Anon read: %s, Anon write denied: %s',
      v_auth_can_select, v_auth_insert_denied, v_anon_can_select, v_anon_insert_denied)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC07_catalogue_destinations_read_only', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 9. TC08: Trips Owner RLS Isolation (CRUD, Cross-User & Owner-Change Protection)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  dest_id text := 'da-nang-synthetic';
  trip_a_id uuid := '44444444-4444-4444-4444-444444444441';
  trip_spoof_id uuid := '44444444-4444-4444-4444-444444444449';
  v_a_inserted boolean := false;
  v_b_sees_trip int := -1;
  v_b_updated int := -1;
  v_b_deleted int := -1;
  v_spoof_insert_denied boolean := false;
  v_owner_change_denied boolean := false;
BEGIN
  -- 1. User A inserts own trip (audited schema with destination_name text)
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  INSERT INTO public.trips (id, user_id, title, destination_name, num_days, budget_total, ai_plan_data)
  VALUES (trip_a_id, uid_a, 'Trip A', 'Đà Nẵng Synthetic', 3, 3000000, '{"plan": "test"}'::jsonb);
  v_a_inserted := true;

  -- 2. User B tries to read, update, delete User A trip (must affect 0 rows)
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
    VALUES (trip_spoof_id, uid_a, 'Spoofed Trip', 'Đà Nẵng Synthetic', 1, 1000000, '{"plan": "test"}'::jsonb);
  EXCEPTION
    WHEN insufficient_privilege THEN -- RLS WITH CHECK violation (SQLSTATE 42501)
      v_spoof_insert_denied := true;
  END;

  -- 4. User A tries to change owner of own trip to User B (must be rejected by WITH CHECK)
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  BEGIN
    UPDATE public.trips SET user_id = uid_b WHERE id = trip_a_id;
  EXCEPTION
    WHEN insufficient_privilege THEN -- SQLSTATE 42501
      v_owner_change_denied := true;
  END;

  -- Reset role
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC08_trips_owner_rls_isolation',
    (v_a_inserted = true AND v_b_sees_trip = 0 AND v_b_updated = 0 AND v_b_deleted = 0 AND
     v_spoof_insert_denied = true AND v_owner_change_denied = true),
    format('A inserted: %s, B sees: %s, B updated: %s, B deleted: %s, spoof denied: %s, owner change denied: %s',
      v_a_inserted, v_b_sees_trip, v_b_updated, v_b_deleted, v_spoof_insert_denied, v_owner_change_denied)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC08_trips_owner_rls_isolation', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 10. TC09: Trip Activities Ownership, Full CRUD & Reparenting
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  uid_b uuid := '22222222-2222-2222-2222-222222222222';
  dest_id text := 'da-nang-synthetic';
  svc_id text := 'svc-ba-na-synthetic';
  trip_a1 uuid := '44444444-4444-4444-4444-444444444441';
  trip_a2 uuid := '44444444-4444-4444-4444-444444444442';
  trip_b uuid := '44444444-4444-4444-4444-444444444443';
  act_id uuid := '55555555-5555-5555-5555-555555555551';
  v_act_inserted boolean := false;
  v_reparent_own_ok boolean := false;
  v_reparent_other_denied boolean := false;
  v_rows_affected int := 0;
  v_stored_parent uuid;
  v_b_sees_act int := -1;
  v_b_updated_act int := -1;
  v_b_deleted_act int := -1;
  v_a_updated_act int := -1;
  v_a_deleted_act int := -1;
BEGIN
  -- Insert trip A2 and trip B as runner fixture
  INSERT INTO public.trips (id, user_id, title, destination_name, num_days, budget_total, ai_plan_data)
  VALUES
    (trip_a2, uid_a, 'Trip A2', 'Đà Nẵng Synthetic', 1, 1000000, '{"plan": "test"}'::jsonb),
    (trip_b, uid_b, 'Trip B', 'Đà Nẵng Synthetic', 1, 1000000, '{"plan": "test"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  -- 1. User A inserts activity on own Trip A1 using audited schema:
  -- (id, trip_id, day_number, start_time, title, cost, service_id)
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  INSERT INTO public.trip_activities (id, trip_id, day_number, start_time, title, cost, service_id)
  VALUES (act_id, trip_a1, 1, '08:00', 'Hồ Gươm Walking', 50000, svc_id);
  v_act_inserted := true;

  -- 2. User A updates own activity title (verifying own activity update works)
  UPDATE public.trip_activities SET title = 'Hồ Gươm Morning Walk' WHERE id = act_id;
  GET DIAGNOSTICS v_a_updated_act = ROW_COUNT;

  -- 2b. Full CRUD verification: User A inserts and deletes a temporary activity on own trip
  INSERT INTO public.trip_activities (id, trip_id, day_number, start_time, title, cost, service_id)
  VALUES ('55555555-5555-5555-5555-555555555559'::uuid, trip_a1, 1, '10:00', 'Temp Coffee', 30000, svc_id);
  DELETE FROM public.trip_activities WHERE id = '55555555-5555-5555-5555-555555555559'::uuid;
  GET DIAGNOSTICS v_a_deleted_act = ROW_COUNT;

  -- 3. User B tries to read, update, delete User A's activity (must affect 0 rows)
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_b::text, true);

  SELECT count(*) INTO v_b_sees_act FROM public.trip_activities WHERE id = act_id;
  UPDATE public.trip_activities SET title = 'Hacked Act' WHERE id = act_id;
  GET DIAGNOSTICS v_b_updated_act = ROW_COUNT;
  DELETE FROM public.trip_activities WHERE id = act_id;
  GET DIAGNOSTICS v_b_deleted_act = ROW_COUNT;

  -- 4. User A reparents activity to own Trip A2 via shared gate helper
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  BEGIN
    PERFORM pg_temp.gate_assert_reparent_success(act_id, trip_a2);
    v_reparent_own_ok := true;
  EXCEPTION WHEN OTHERS THEN
    v_reparent_own_ok := false;
  END;

  -- 5. User A attempts to reparent activity to Trip B (must be denied by RLS WITH CHECK with exact 42501)
  BEGIN
    UPDATE public.trip_activities SET trip_id = trip_b WHERE id = act_id;
  EXCEPTION
    WHEN insufficient_privilege THEN -- Exact 42501 expected
      v_reparent_other_denied := true;
  END;

  -- Reset role
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  PERFORM pg_temp.record_test(
    'TC09_trip_activities_ownership_and_reparenting',
    (v_act_inserted = true AND v_a_updated_act = 1 AND v_a_deleted_act = 1 AND v_reparent_own_ok = true AND
     v_reparent_other_denied = true AND v_b_sees_act = 0 AND v_b_updated_act = 0 AND v_b_deleted_act = 0),
    format('Act inserted: %s, own update: %s, own delete: %s, reparent own ok: %s (rows: %s, stored: %s), reparent to B denied: %s, B sees: %s',
      v_act_inserted, v_a_updated_act, v_a_deleted_act, v_reparent_own_ok, v_rows_affected, v_stored_parent, v_reparent_other_denied, v_b_sees_act)
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
-- 13. TC12: Foreign Key Cascade Deletion Integrity (Row Count & Existence Verified)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  trip_a2 uuid := '44444444-4444-4444-4444-444444444442';
  act_id uuid := '55555555-5555-5555-5555-555555555551';
  uid_a uuid := '11111111-1111-1111-1111-111111111111';
  v_act_before int := -1;
  v_trip_deleted int := -1;
  v_act_after int := -1;
BEGIN
  -- 1. Assert child activity exists before parent trip deletion
  SELECT count(*) INTO v_act_before FROM public.trip_activities WHERE id = act_id AND trip_id = trip_a2;

  -- 2. User A deletes parent trip A2
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', uid_a::text, true);

  DELETE FROM public.trips WHERE id = trip_a2;
  GET DIAGNOSTICS v_trip_deleted = ROW_COUNT;

  -- Reset role to check under runner
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);

  -- 3. Assert child activity was cascaded (count is now 0)
  SELECT count(*) INTO v_act_after FROM public.trip_activities WHERE id = act_id;

  PERFORM pg_temp.record_test(
    'TC12_fk_cascade_deletion_integrity',
    (v_act_before = 1 AND v_trip_deleted = 1 AND v_act_after = 0),
    format('Child before: %s, Parent deleted: %s, Child after: %s', v_act_before, v_trip_deleted, v_act_after)
  );
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM pg_temp.record_test('TC12_fk_cascade_deletion_integrity', false, 'Unexpected runner error: ' || SQLSTATE);
END $$;

-- ------------------------------------------------------------------------------
-- 14. MANIFEST VALIDATION & TEST EXECUTION ENFORCEMENT
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
    'TC11_table_and_column_effective_privilege_checks',
    'TC12_fk_cascade_deletion_integrity'
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
