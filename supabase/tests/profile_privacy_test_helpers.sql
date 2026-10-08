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
