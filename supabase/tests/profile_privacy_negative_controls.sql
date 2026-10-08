-- ==============================================================================
-- Database Test Suite: profile_privacy_negative_controls.sql
-- Description: Realistic negative controls verifying that security test gates,
--              postcondition checks, and assertion helpers correctly FAIL-CLOSED
--              when security flaws or schema deviations are present, using real
--              rollback-contained schema mutations and proving clean restoration.
-- Execution: psql -X -v ON_ERROR_STOP=1 -f supabase/tests/profile_privacy_negative_controls.sql
-- Safety: Wraps in transaction & rolls back all changes.
-- ==============================================================================

BEGIN;

CREATE TEMPORARY TABLE control_results (
  control_name text PRIMARY KEY,
  status text NOT NULL,
  details text
);

CREATE OR REPLACE FUNCTION pg_temp.record_control(c_name text, pass boolean, note text DEFAULT '')
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
BEGIN
  INSERT INTO control_results (control_name, status, details)
  VALUES (c_name, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END, note);
END;
$$;

-- ------------------------------------------------------------------------------
-- Gate 1: Reusable Policy Drift Gate (matches migration postcondition logic)
-- Detects ANY unexpected permissive policy, including FOR ALL policies.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.gate_check_profiles_policy_drift()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_unexpected int;
BEGIN
  SELECT count(*) INTO v_unexpected
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'profiles'
    AND NOT (
      (policyname = 'profiles_self_select' AND permissive = 'PERMISSIVE' AND cmd = 'SELECT')
      OR (policyname = 'profiles_self_update' AND permissive = 'PERMISSIVE' AND cmd = 'UPDATE')
    );

  IF v_unexpected > 0 THEN
    RAISE EXCEPTION 'DRIFT_GATE_FAILURE: unexpected policy detected on public.profiles (count: %)', v_unexpected;
  END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- NC01: Permissive ALL Policy Drift Detection & Restoration
-- Verifies that an injected permissive FOR ALL policy is caught by the real gate,
-- and that dropping the mutant restores clean validation.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_initial_clean boolean := false;
  v_mutant_caught boolean := false;
  v_restored_clean boolean := false;
BEGIN
  -- 1. Verify baseline passes drift gate
  BEGIN
    PERFORM pg_temp.gate_check_profiles_policy_drift();
    v_initial_clean := true;
  EXCEPTION WHEN OTHERS THEN
    v_initial_clean := false;
  END;

  -- 2. Inject mutant: Permissive FOR ALL policy on profiles
  CREATE POLICY "NC01_Mutant_Permissive_All" ON public.profiles FOR ALL USING (true);

  -- 3. Execute drift gate: MUST FAIL-CLOSED
  BEGIN
    PERFORM pg_temp.gate_check_profiles_policy_drift();
    v_mutant_caught := false; -- should not reach here
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%DRIFT_GATE_FAILURE%' THEN
      v_mutant_caught := true;
    END IF;
  END;

  -- 4. Restore: Drop mutant policy
  DROP POLICY IF EXISTS "NC01_Mutant_Permissive_All" ON public.profiles;

  -- 5. Verify gate passes again after restoration
  BEGIN
    PERFORM pg_temp.gate_check_profiles_policy_drift();
    v_restored_clean := true;
  EXCEPTION WHEN OTHERS THEN
    v_restored_clean := false;
  END;

  PERFORM pg_temp.record_control(
    'NC01_permissive_policy_drift_detection',
    (v_initial_clean = true AND v_mutant_caught = true AND v_restored_clean = true),
    format('Initial clean: %s, mutant caught: %s, restored clean: %s',
      v_initial_clean, v_mutant_caught, v_restored_clean)
  );
END $$;

-- ------------------------------------------------------------------------------
-- Gate 2: Signup Role Security Assertion Helper (matches TC06 harness check)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.gate_assert_signup_role(target_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_actual_role text;
BEGIN
  SELECT role INTO v_actual_role FROM public.profiles WHERE id = target_id;
  IF v_actual_role IS NULL THEN
    RAISE EXCEPTION 'ROLE_ASSERTION_FAILURE: profile not found for user %', target_id;
  END IF;
  IF v_actual_role <> 'customer' THEN
    RAISE EXCEPTION 'ROLE_ASSERTION_FAILURE: role escalation detected (actual role: %)', v_actual_role;
  END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- NC02: Real Signup Role Escalation Mutant Detection & Restoration
-- Injects a vulnerable handle_new_user trigger in the transaction, performs
-- actual auth signup with admin role metadata, proves the assertion helper fails,
-- then restores the secure trigger and proves the assertion passes.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_mutant_user_id uuid := '88888888-8888-8888-8888-888888888882';
  v_mutant_caught boolean := false;
  v_restored_clean boolean := false;
  v_has_auth boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_namespace n JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users'
  ) INTO v_has_auth;

  IF NOT v_has_auth THEN
    RAISE EXCEPTION 'Prerequisite failed: auth.users table missing for NC02';
  END IF;

  -- 1. Install MUTANT trigger function: trusts user_metadata->>'role'
  CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $tg$
  BEGIN
    INSERT INTO public.profiles (id, full_name, email, role)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'Mutant Admin'),
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'role', 'customer') -- VULNERABLE: trusts client role!
    );
    RETURN NEW;
  END;
  $tg$;

  -- 2. Trigger real signup under mutant
  INSERT INTO auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  VALUES (v_mutant_user_id, 'authenticated', 'authenticated', 'mutant@travelgo.vn', '{"role": "admin"}'::jsonb, now(), now());

  -- 3. Run security assertion gate: MUST FAIL-CLOSED because role is 'admin'
  BEGIN
    PERFORM pg_temp.gate_assert_signup_role(v_mutant_user_id);
    v_mutant_caught := false; -- should not reach here
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%ROLE_ASSERTION_FAILURE%' THEN
      v_mutant_caught := true;
    END IF;
  END;

  -- 4. Clean up test row
  DELETE FROM public.profiles WHERE id = v_mutant_user_id;
  DELETE FROM auth.users WHERE id = v_mutant_user_id;

  -- 5. Restore SECURE trigger function: forces 'customer' role unconditionally
  CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
  SET search_path = public, pg_temp AS $tg$
  DECLARE
    v_full_name text;
    v_phone text;
  BEGIN
    v_full_name := COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
      CASE
        WHEN NEW.email IS NOT NULL AND position('@' IN NEW.email) > 1
          THEN split_part(NEW.email, '@', 1)
        ELSE 'Thành viên TravelGO'
      END
    );
    v_phone := COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''),
      NULLIF(TRIM(NEW.phone), ''),
      ''
    );
    INSERT INTO public.profiles (id, full_name, email, phone, role)
    VALUES (NEW.id, v_full_name, NEW.email, v_phone, 'customer')
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      email = EXCLUDED.email,
      phone = EXCLUDED.phone,
      updated_at = now();
    RETURN NEW;
  END;
  $tg$;

  -- 6. Trigger real signup under restored secure trigger with same spoofed metadata
  INSERT INTO auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  VALUES (v_mutant_user_id, 'authenticated', 'authenticated', 'mutant@travelgo.vn', '{"role": "admin"}'::jsonb, now(), now());

  -- 7. Run security assertion gate: MUST SUCCEED because role is forced to 'customer'
  BEGIN
    PERFORM pg_temp.gate_assert_signup_role(v_mutant_user_id);
    v_restored_clean := true;
  EXCEPTION WHEN OTHERS THEN
    v_restored_clean := false;
  END;

  -- Clean up test row
  DELETE FROM public.profiles WHERE id = v_mutant_user_id;
  DELETE FROM auth.users WHERE id = v_mutant_user_id;

  PERFORM pg_temp.record_control(
    'NC02_role_escalation_detection',
    (v_mutant_caught = true AND v_restored_clean = true),
    format('Mutant escalation caught: %s, restored secure signup passed: %s',
      v_mutant_caught, v_restored_clean)
  );
END $$;

-- ------------------------------------------------------------------------------
-- Gate 3: Query Error Classifier
-- Harness classifier must distinguish 42703 (undefined_column) from 42501 (insufficient_privilege)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.classify_query_error(p_sql text)
RETURNS text LANGUAGE plpgsql AS $$
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
$$;

-- ------------------------------------------------------------------------------
-- NC03: Schema Column Mismatch Must NOT Disguise as Authorization Denial
-- Verifies that querying a non-existent column produces UNDEFINED_COLUMN_42703
-- and is NOT classified as an authorization denial (42501).
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_classification text;
  v_is_correct boolean := false;
BEGIN
  v_classification := pg_temp.classify_query_error('SELECT non_existent_column_probe FROM public.trip_activities LIMIT 1');

  IF v_classification = 'UNDEFINED_COLUMN_42703' THEN
    v_is_correct := true;
  END IF;

  PERFORM pg_temp.record_control(
    'NC03_column_mismatch_not_disguised_as_auth_denial',
    (v_is_correct = true),
    format('Classification result: %s (expected UNDEFINED_COLUMN_42703, not DENIED_42501)', v_classification)
  );
END $$;

-- ------------------------------------------------------------------------------
-- Gate 4: Reparent Assertion Gate Helper (matches TC09 harness check)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.gate_assert_reparent_success(p_act_id uuid, p_target_trip_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
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
$$;

-- ------------------------------------------------------------------------------
-- NC04: Zero-Row Reparent UPDATE Must NOT Report Success
-- Verifies that the reparent assertion helper correctly catches a zero-row update
-- and fails closed instead of reporting success.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  non_existent_id uuid := '99999999-9999-9999-9999-999999999999';
  target_trip_id uuid := '44444444-4444-4444-4444-444444444442';
  v_zero_row_caught boolean := false;
BEGIN
  BEGIN
    PERFORM pg_temp.gate_assert_reparent_success(non_existent_id, target_trip_id);
    v_zero_row_caught := false; -- should not reach here
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%REPARENT_ASSERTION_FAILURE%' THEN
      v_zero_row_caught := true;
    END IF;
  END;

  PERFORM pg_temp.record_control(
    'NC04_zero_row_reparent_rejected',
    (v_zero_row_caught = true),
    format('Zero-row reparent caught by assertion helper: %s', v_zero_row_caught)
  );
END $$;

-- ------------------------------------------------------------------------------
-- MANIFEST VALIDATION FOR NEGATIVE CONTROLS
-- ------------------------------------------------------------------------------
SELECT control_name, status, details FROM control_results ORDER BY control_name;

DO $$
DECLARE
  v_manifest text[] := ARRAY[
    'NC01_permissive_policy_drift_detection',
    'NC02_role_escalation_detection',
    'NC03_column_mismatch_not_disguised_as_auth_denial',
    'NC04_zero_row_reparent_rejected'
  ];
  v_ctrl text;
  v_count int;
  v_failed_count int;
BEGIN
  -- Verify every control in manifest executed exactly once
  FOREACH v_ctrl IN ARRAY v_manifest LOOP
    SELECT count(*) INTO v_count FROM control_results WHERE control_name = v_ctrl;
    IF v_count = 0 THEN
      RAISE EXCEPTION 'Negative controls manifest error: missing control %', v_ctrl;
    ELSIF v_count > 1 THEN
      RAISE EXCEPTION 'Negative controls manifest error: duplicate control %', v_ctrl;
    END IF;
  END LOOP;

  -- Verify zero failures
  SELECT count(*) INTO v_failed_count FROM control_results WHERE status = 'FAIL';
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'Negative controls suite failed with % failures!', v_failed_count;
  END IF;

  RAISE NOTICE 'Negative controls manifest validation passed: all % controls passed (gates fail-closed).', array_length(v_manifest, 1);
END $$;

ROLLBACK;
