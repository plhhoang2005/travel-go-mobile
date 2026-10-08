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
-- Gate 1: Fail-Closed Prerequisite Check for public.verify_profiles_policy_drift()
-- Must exist with exact signature (void, 0 args, SECURITY DEFINER, search_path).
-- Absolutely NO fallback creation; if migration is missing, this test MUST FAIL.
-- ------------------------------------------------------------------------------
DO $gate_check$
DECLARE
  v_gate_exists boolean := false;
  v_sig_matches boolean := false;
BEGIN
  SELECT
    true,
    (
      p.prorettype = 'void'::regtype
      AND p.prosecdef = true
      AND p.pronargs = 0
      AND p.proconfig::text LIKE '%search_path=public, pg_temp%'
    )
  INTO v_gate_exists, v_sig_matches
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'verify_profiles_policy_drift';

  IF NOT COALESCE(v_gate_exists, false) THEN
    PERFORM pg_temp.record_control(
      'NC00_drift_gate_prerequisite',
      false,
      'FAIL-CLOSED: public.verify_profiles_policy_drift() does NOT exist. Migration must be applied first.'
    );
    RAISE EXCEPTION 'PRECONDITION_FAILED: public.verify_profiles_policy_drift() does not exist.';
  END IF;

  IF NOT COALESCE(v_sig_matches, false) THEN
    PERFORM pg_temp.record_control(
      'NC00_drift_gate_prerequisite',
      false,
      'FAIL-CLOSED: public.verify_profiles_policy_drift() signature mismatch (requires void, 0 args, prosecdef=true, search_path=public, pg_temp).'
    );
    RAISE EXCEPTION 'PRECONDITION_FAILED: public.verify_profiles_policy_drift() signature mismatch.';
  END IF;

  PERFORM pg_temp.record_control(
    'NC00_drift_gate_prerequisite',
    true,
    'Prerequisite passed: public.verify_profiles_policy_drift() present with exact signature from migration.'
  );
END $gate_check$;

-- ------------------------------------------------------------------------------
-- NC01: Permissive ALL Policy Drift Detection & Restoration
-- Verifies that an injected permissive FOR ALL policy is caught by the migration gate,
-- and that dropping the mutant restores clean validation under the exact policy contract.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_initial_clean boolean := false;
  v_mutant_caught boolean := false;
  v_restored_clean boolean := false;
BEGIN
  -- 1. Verify clean migration state passes drift gate
  BEGIN
    PERFORM public.verify_profiles_policy_drift();
    v_initial_clean := true;
  EXCEPTION WHEN OTHERS THEN
    v_initial_clean := false;
  END;

  -- 2. Inject mutant: Permissive FOR ALL policy on profiles
  CREATE POLICY "NC01_Mutant_Permissive_All" ON public.profiles FOR ALL USING (true);

  -- 3. Execute shared drift gate: MUST FAIL-CLOSED on mutant policy
  BEGIN
    PERFORM public.verify_profiles_policy_drift();
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
    PERFORM public.verify_profiles_policy_drift();
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
-- NC02: Real Signup Role Escalation Mutant Detection & EXACT METADATA RESTORATION
-- Captures exact pg_get_functiondef and configuration before mutation, proves
-- mutant is caught, restores via captured definition, asserts metadata equality,
-- and proves restored safe signup.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_mutant_user_id uuid := '88888888-8888-8888-8888-888888888882';
  v_mutant_caught boolean := false;
  v_definition_restored_exact boolean := false;
  v_restored_safe_signup boolean := false;
  v_has_auth boolean;
  v_orig_funcdef text;
  v_orig_secdef boolean;
  v_orig_config text[];
  v_orig_owner oid;
  v_orig_acl aclitem[];
  v_orig_trig_oid oid;
  v_restored_funcdef text;
  v_restored_secdef boolean;
  v_restored_config text[];
  v_restored_owner oid;
  v_restored_acl aclitem[];
  v_restored_trig_oid oid;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_namespace n JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users'
  ) INTO v_has_auth;

  IF NOT v_has_auth THEN
    RAISE EXCEPTION 'Prerequisite failed: auth.users table missing for NC02';
  END IF;

  -- 1. CAPTURE COMPLETE ORIGINAL FUNCTION DEFINITION, METADATA & TRIGGER BINDING
  SELECT
    pg_get_functiondef(p.oid),
    p.prosecdef,
    p.proconfig,
    p.proowner,
    p.proacl
  INTO
    v_orig_funcdef,
    v_orig_secdef,
    v_orig_config,
    v_orig_owner,
    v_orig_acl
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'handle_new_user';

  IF v_orig_funcdef IS NULL THEN
    RAISE EXCEPTION 'Prerequisite failed: public.handle_new_user does not exist before NC02 mutation';
  END IF;

  SELECT t.oid INTO v_orig_trig_oid
  FROM pg_trigger t
  JOIN pg_proc p ON t.tgfoid = p.oid
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'auth' AND c.relname = 'users'
    AND t.tgname = 'on_auth_user_created'
    AND p.proname = 'handle_new_user';

  -- 2. INSTALL MUTANT TRIGGER FUNCTION (trusts raw_user_meta_data->>'role')
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

  -- 3. TRIGGER REAL SIGNUP UNDER MUTANT
  INSERT INTO auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  VALUES (v_mutant_user_id, 'authenticated', 'authenticated', 'mutant@travelgo.vn', '{"role": "admin"}'::jsonb, now(), now());

  -- 4. RUN SECURITY ASSERTION GATE: MUST FAIL-CLOSED ON ROLE ESCALATION
  BEGIN
    PERFORM pg_temp.gate_assert_signup_role(v_mutant_user_id);
    v_mutant_caught := false; -- should not reach here
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%ROLE_ASSERTION_FAILURE%' THEN
      v_mutant_caught := true;
    END IF;
  END;

  -- 5. CLEAN UP TEST ROW
  DELETE FROM public.profiles WHERE id = v_mutant_user_id;
  DELETE FROM auth.users WHERE id = v_mutant_user_id;

  -- 6. RESTORE EXACT CAPTURED ORIGINAL FUNCTION DEFINITION
  EXECUTE v_orig_funcdef;

  -- 7. VERIFY EXACT RESTORATION OF COMPLETE METADATA, DEFINITION & TRIGGER BINDING
  SELECT
    pg_get_functiondef(p.oid),
    p.prosecdef,
    p.proconfig,
    p.proowner,
    p.proacl
  INTO
    v_restored_funcdef,
    v_restored_secdef,
    v_restored_config,
    v_restored_owner,
    v_restored_acl
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'handle_new_user';

  SELECT t.oid INTO v_restored_trig_oid
  FROM pg_trigger t
  JOIN pg_proc p ON t.tgfoid = p.oid
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'auth' AND c.relname = 'users'
    AND t.tgname = 'on_auth_user_created'
    AND p.proname = 'handle_new_user';

  IF v_restored_funcdef = v_orig_funcdef
     AND v_restored_secdef = v_orig_secdef
     AND v_restored_config IS NOT DISTINCT FROM v_orig_config
     AND v_restored_owner = v_orig_owner
     AND v_restored_acl IS NOT DISTINCT FROM v_orig_acl
     AND v_restored_trig_oid IS NOT DISTINCT FROM v_orig_trig_oid THEN
    v_definition_restored_exact := true;
  END IF;

  -- 8. TRIGGER REAL SIGNUP UNDER RESTORED SECURE TRIGGER WITH ADMIN METADATA
  INSERT INTO auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  VALUES (v_mutant_user_id, 'authenticated', 'authenticated', 'mutant@travelgo.vn', '{"role": "admin"}'::jsonb, now(), now());

  -- 9. RUN SECURITY ASSERTION GATE: MUST SUCCEED (ROLE FORCED TO 'customer')
  BEGIN
    PERFORM pg_temp.gate_assert_signup_role(v_mutant_user_id);
    v_restored_safe_signup := true;
  EXCEPTION WHEN OTHERS THEN
    v_restored_safe_signup := false;
  END;

  -- CLEAN UP TEST ROW
  DELETE FROM public.profiles WHERE id = v_mutant_user_id;
  DELETE FROM auth.users WHERE id = v_mutant_user_id;

  PERFORM pg_temp.record_control(
    'NC02_role_escalation_detection',
    (v_mutant_caught = true AND v_definition_restored_exact = true AND v_restored_safe_signup = true),
    format('Mutant caught: %s, exact definition restored: %s, restored safe signup: %s',
      v_mutant_caught, v_definition_restored_exact, v_restored_safe_signup)
  );
END $$;

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
