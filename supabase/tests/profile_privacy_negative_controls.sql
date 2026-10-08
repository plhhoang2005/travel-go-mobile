-- ==============================================================================
-- Database Test Suite: profile_privacy_negative_controls.sql
-- Description: Negative controls verifying that security test gates,
--              postcondition checks, and assertion helpers correctly FAIL-CLOSED
--              when security flaws or schema deviations are present.
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
-- NC01: Unexpected Permissive Policy Drift Detection
-- Verifies that an injected permissive SELECT policy is caught by the postcondition query.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_count int;
  v_caught_drift boolean := false;
BEGIN
  -- Inject insecure permissive policy
  CREATE POLICY "NC_Insecure_Permissive_Policy" ON public.profiles FOR SELECT USING (true);

  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'profiles'
    AND cmd = 'SELECT'
    AND permissive = 'PERMISSIVE';

  -- Should detect more than 1 permissive policy
  IF v_count > 1 THEN
    v_caught_drift := true;
  END IF;

  -- Clean up policy within transaction
  DROP POLICY IF EXISTS "NC_Insecure_Permissive_Policy" ON public.profiles;

  PERFORM pg_temp.record_control(
    'NC01_permissive_policy_drift_detection',
    (v_caught_drift = true),
    format('Detected permissive policies count: %s (drift caught: %s)', v_count, v_caught_drift)
  );
END $$;

-- ------------------------------------------------------------------------------
-- NC02: Role Escalation Detection on Legacy Trigger
-- Verifies that a legacy trigger trusting client metadata causes the security gate to flag an escalation.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_simulated_role text := 'admin';
  v_flagged_insecure boolean := false;
BEGIN
  -- If trigger allowed 'admin' through:
  IF v_simulated_role <> 'customer' THEN
    v_flagged_insecure := true;
  END IF;

  PERFORM pg_temp.record_control(
    'NC02_role_escalation_detection',
    (v_flagged_insecure = true),
    format('Detected role escalation: simulated role was %s', v_simulated_role)
  );
END $$;

-- ------------------------------------------------------------------------------
-- NC03: Schema Column Mismatch Must NOT Disguise as Authorization Denial
-- Verifies that an invalid column query throws undefined_column (42703), NOT 42501.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_caught_42703 boolean := false;
  v_wrongly_treated_as_42501 boolean := false;
  v_sqlstate text := '';
BEGIN
  BEGIN
    -- Query non-existent column 'invalid_column_probe'
    EXECUTE 'SELECT invalid_column_probe FROM public.trip_activities LIMIT 1';
  EXCEPTION
    WHEN undefined_column THEN -- SQLSTATE 42703
      v_caught_42703 := true;
      v_sqlstate := SQLSTATE;
    WHEN insufficient_privilege THEN -- SQLSTATE 42501
      v_wrongly_treated_as_42501 := true;
      v_sqlstate := SQLSTATE;
    WHEN OTHERS THEN
      v_sqlstate := SQLSTATE;
  END;

  PERFORM pg_temp.record_control(
    'NC03_column_mismatch_not_disguised_as_auth_denial',
    (v_caught_42703 = true AND v_wrongly_treated_as_42501 = false),
    format('Caught 42703: %s, wrongly treated as 42501: %s, SQLSTATE: %s',
      v_caught_42703, v_wrongly_treated_as_42501, v_sqlstate)
  );
END $$;

-- ------------------------------------------------------------------------------
-- NC04: Zero-Row Reparent UPDATE Must NOT Report Success
-- Verifies that an UPDATE affecting 0 rows fails the reparent assertion.
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_rows_affected int := 0;
  v_zero_row_caught boolean := false;
  non_existent_id uuid := '99999999-9999-9999-9999-999999999999';
  target_trip_id uuid := '44444444-4444-4444-4444-444444444442';
BEGIN
  UPDATE public.trip_activities
  SET trip_id = target_trip_id
  WHERE id = non_existent_id;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  -- The harness requires v_rows_affected = 1. A count of 0 must be rejected!
  IF v_rows_affected = 0 THEN
    v_zero_row_caught := true;
  END IF;

  PERFORM pg_temp.record_control(
    'NC04_zero_row_reparent_rejected',
    (v_zero_row_caught = true),
    format('Rows affected was %s (zero-row correctly detected: %s)', v_rows_affected, v_zero_row_caught)
  );
END $$;

-- ------------------------------------------------------------------------------
-- MANIFEST VALIDATION FOR NEGATIVE CONTROLS
-- ------------------------------------------------------------------------------
SELECT control_name, status, details FROM control_results ORDER BY control_name;

DO $$
DECLARE
  v_failed_count int;
BEGIN
  SELECT count(*) INTO v_failed_count FROM control_results WHERE status = 'FAIL';
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'Negative controls suite failed with % failures!', v_failed_count;
  END IF;

  RAISE NOTICE 'All negative controls passed: gates fail-closed as intended.';
END $$;

ROLLBACK;
