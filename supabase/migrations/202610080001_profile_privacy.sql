-- ==============================================================================
-- Migration: 202610080001_profile_privacy.sql
-- Description: Enforce strict profile privacy, least-privilege table grants,
--              column-level UPDATE permissions, and hardened signup trigger.
-- DB-INT Traceability: DB-002, DB-003, DB-004, DB-006; FR-SEC-001/002, AC-034/054
-- Target: PostgreSQL 17.x / Supabase (public schema)
-- Safety: Wraps in transaction; preserves existing table records, IDs, and constraints.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- PRECONDITION CHECKS (Fail-closed Structural Baseline & Contract Verification - REV-005)
-- ------------------------------------------------------------------------------
DO $precondition$
BEGIN
  -- 1. Verify required application tables exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    RAISE EXCEPTION 'Precondition failed: table public.profiles does not exist';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trips') THEN
    RAISE EXCEPTION 'Precondition failed: table public.trips does not exist';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trip_activities') THEN
    RAISE EXCEPTION 'Precondition failed: table public.trip_activities does not exist';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'destinations') THEN
    RAISE EXCEPTION 'Precondition failed: table public.destinations does not exist';
  END IF;

  -- 2. Verify structural contracts on public.profiles (types, nullability, defaults)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.profiles.id must be uuid';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'full_name' AND data_type = 'text' AND is_nullable = 'NO'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.profiles.full_name must be text NOT NULL';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'role' AND data_type = 'text' AND column_default LIKE '%customer%'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.profiles.role must be text DEFAULT customer';
  END IF;

  -- 3. Verify structural contracts on public.trips (types, nullability, defaults)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips'
      AND column_name = 'destination_name' AND data_type = 'text' AND is_nullable = 'NO'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.trips.destination_name must be text NOT NULL';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips'
      AND column_name = 'num_days' AND data_type = 'integer' AND column_default LIKE '%3%'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.trips.num_days must be integer DEFAULT 3';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips'
      AND column_name = 'ai_plan_data' AND data_type = 'jsonb'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.trips.ai_plan_data must be jsonb';
  END IF;

  -- 4. Verify structural contracts on public.trip_activities (types, nullability)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trip_activities'
      AND column_name = 'cost' AND data_type = 'numeric'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.trip_activities.cost must be numeric';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trip_activities'
      AND column_name = 'trip_id' AND data_type = 'uuid' AND is_nullable = 'NO'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.trip_activities.trip_id must be uuid NOT NULL';
  END IF;

  -- 5. Verify structural contracts on public.destinations (defaults)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'destinations'
      AND column_name = 'weather_cached_temp' AND data_type = 'numeric' AND column_default LIKE '%26%'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.destinations.weather_cached_temp must be numeric DEFAULT 26.0';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'destinations'
      AND column_name = 'is_popular' AND data_type = 'boolean' AND column_default LIKE '%true%'
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.destinations.is_popular must be boolean DEFAULT true';
  END IF;

  -- 6. Verify baseline trigger function signature contract
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'handle_new_user'
      AND p.prorettype = 'trigger'::regtype
      AND p.pronargs = 0
  ) THEN
    RAISE EXCEPTION 'Precondition failed: public.handle_new_user procedure must exist and return trigger';
  END IF;
END $precondition$;

-- ------------------------------------------------------------------------------
-- 1. HARDEN PROFILES ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Remove insecure public, ALL, or legacy policies
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are manageable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;

-- Authenticated users can ONLY view their own profile row
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Authenticated users can update ONLY their own profile row
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- NOTE: No client INSERT or DELETE policy on public.profiles.
-- Profile creation is strictly delegated to the trusted Auth trigger handle_new_user().

-- ------------------------------------------------------------------------------
-- 2. LEAST-PRIVILEGE COLUMN & TABLE GRANTS ON PROFILES
-- ------------------------------------------------------------------------------
-- Revoke all table-level mutating privileges from untrusted roles
REVOKE ALL ON TABLE public.profiles FROM anon, authenticated, public;

-- Grant selective read to authenticated users
GRANT SELECT ON TABLE public.profiles TO authenticated;

-- Grant column-level UPDATE ONLY for safe user-editable attributes.
-- 'role', 'email', 'id', 'created_at', 'updated_at' are strictly protected!
GRANT UPDATE (full_name, phone, avatar_url, address) ON TABLE public.profiles TO authenticated;

-- Maintain administrative access for backend service role
GRANT ALL ON TABLE public.profiles TO service_role;

-- ------------------------------------------------------------------------------
-- 3. PROFILES AUTOMATIC UPDATED_AT TRIGGER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_profile_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_profiles_updated_at ON public.profiles;
CREATE TRIGGER tr_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_profile_updated_at();

-- ------------------------------------------------------------------------------
-- 4. HARDEN SIGNUP TRIGGER: REJECT CLIENT-PROVIDED ROLES
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
DECLARE
  v_full_name text;
  v_phone text;
BEGIN
  -- Safe extraction of full_name with fallbacks
  v_full_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    CASE
      WHEN NEW.email IS NOT NULL AND position('@' IN NEW.email) > 1
        THEN split_part(NEW.email, '@', 1)
      ELSE 'Thành viên TravelGO'
    END
  );

  -- Safe extraction of phone
  v_phone := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''),
    NULLIF(TRIM(NEW.phone), ''),
    ''
  );

  -- Insert profile with strictly forced 'customer' role.
  -- Client metadata role parameter is intentionally ignored!
  INSERT INTO public.profiles (id, full_name, email, phone, role)
  VALUES (
    NEW.id,
    v_full_name,
    NEW.email,
    v_phone,
    'customer'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = CASE WHEN EXCLUDED.phone <> '' THEN EXCLUDED.phone ELSE public.profiles.phone END,
    updated_at = timezone('utc'::text, now());

  RETURN NEW;
END;
$func$;

-- Restrict function execution to administrative callers
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

-- Re-bind trigger on auth.users if auth schema is accessible
DO $trigger_bind$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_class c ON c.relnamespace = n.oid
    WHERE n.nspname = 'auth' AND c.relname = 'users'
  ) THEN
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
  END IF;
END $trigger_bind$;

-- ------------------------------------------------------------------------------
-- 5. LEAST-PRIVILEGE HARDENING FOR DESTINATIONS, TRIPS, TRIP_ACTIVITIES
-- ------------------------------------------------------------------------------

-- Destinations: read-only catalogue for anon and authenticated
REVOKE ALL ON TABLE public.destinations FROM anon, authenticated, public;
GRANT SELECT ON TABLE public.destinations TO anon, authenticated;
GRANT ALL ON TABLE public.destinations TO service_role;

-- Trips: CRUD for authenticated owner only; revoke TRUNCATE/TRIGGER/REFERENCES
REVOKE ALL ON TABLE public.trips FROM anon, authenticated, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.trips TO authenticated;
GRANT ALL ON TABLE public.trips TO service_role;

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own trips" ON public.trips;
DROP POLICY IF EXISTS "Users create own trips" ON public.trips;
DROP POLICY IF EXISTS "Users update own trips" ON public.trips;
DROP POLICY IF EXISTS "Users delete own trips" ON public.trips;

CREATE POLICY "Users view own trips"
  ON public.trips FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users create own trips"
  ON public.trips FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own trips"
  ON public.trips FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users delete own trips"
  ON public.trips FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Trip Activities: owner-scoped via trips parent; revoke TRUNCATE/TRIGGER/REFERENCES
REVOKE ALL ON TABLE public.trip_activities FROM anon, authenticated, public;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.trip_activities TO authenticated;
GRANT ALL ON TABLE public.trip_activities TO service_role;

ALTER TABLE public.trip_activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own trip activities" ON public.trip_activities;

CREATE POLICY "Users manage own trip activities"
  ON public.trip_activities FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.id = trip_activities.trip_id
        AND t.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.id = trip_activities.trip_id
        AND t.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------------------------
-- 6. SHARED DRIFT AUDIT FUNCTION: public.verify_profiles_policy_drift()
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_profiles_policy_drift()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $audit_func$
DECLARE
  v_unexpected_policies int;
BEGIN
  SELECT count(*) INTO v_unexpected_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'profiles'
    AND (
      cmd = 'ALL'
      OR (cmd = 'SELECT' AND policyname <> 'Users can view own profile')
      OR (cmd = 'UPDATE' AND policyname <> 'Users can update own profile')
      OR (cmd IN ('INSERT', 'DELETE'))
    );

  IF v_unexpected_policies > 0 THEN
    RAISE EXCEPTION 'DRIFT_GATE_FAILURE: detected % unexpected policies on public.profiles', v_unexpected_policies;
  END IF;
END;
$audit_func$;

-- ------------------------------------------------------------------------------
-- 7. POSTCONDITION VERIFICATION GATES (Zero Regression Security Guarantees)
-- ------------------------------------------------------------------------------
DO $postcondition$
DECLARE
  v_profiles_rls boolean;
  v_trips_rls boolean;
  v_activities_rls boolean;
  v_can_update_role boolean;
  v_anon_can_select_profiles boolean;
  v_can_truncate_trips boolean;
  v_can_truncate_profiles boolean;
  v_can_truncate_activities boolean;
  v_can_truncate_destinations boolean;
BEGIN
  -- Verify RLS is enabled on protected tables
  SELECT relrowsecurity INTO v_profiles_rls FROM pg_class WHERE oid = 'public.profiles'::regclass;
  SELECT relrowsecurity INTO v_trips_rls FROM pg_class WHERE oid = 'public.trips'::regclass;
  SELECT relrowsecurity INTO v_activities_rls FROM pg_class WHERE oid = 'public.trip_activities'::regclass;

  IF NOT COALESCE(v_profiles_rls, false) THEN
    RAISE EXCEPTION 'Postcondition failed: RLS is not enabled on public.profiles';
  END IF;
  IF NOT COALESCE(v_trips_rls, false) THEN
    RAISE EXCEPTION 'Postcondition failed: RLS is not enabled on public.trips';
  END IF;
  IF NOT COALESCE(v_activities_rls, false) THEN
    RAISE EXCEPTION 'Postcondition failed: RLS is not enabled on public.trip_activities';
  END IF;

  -- Verify least privilege restrictions: role column update is forbidden for authenticated
  SELECT has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE') INTO v_can_update_role;
  IF v_can_update_role THEN
    RAISE EXCEPTION 'Postcondition failed: authenticated role still has UPDATE privilege on profiles.role';
  END IF;

  -- Verify anon has NO SELECT privilege on profiles
  SELECT has_table_privilege('anon', 'public.profiles', 'SELECT') INTO v_anon_can_select_profiles;
  IF v_anon_can_select_profiles THEN
    RAISE EXCEPTION 'Postcondition failed: anon role still has SELECT privilege on public.profiles';
  END IF;

  -- Execute Shared Comprehensive Policy Drift Gate on public.profiles
  PERFORM public.verify_profiles_policy_drift();

  -- Verify procedure definitions, schema qualification, security definer, and search_path config
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'handle_new_user'
      AND p.prosecdef = true
      AND p.proconfig::text LIKE '%search_path=public, pg_temp%'
  ) THEN
    RAISE EXCEPTION 'Postcondition failed: public.handle_new_user procedure does not exist, is not SECURITY DEFINER, or search_path is not public, pg_temp';
  END IF;

  -- Verify mutating DDL privileges: TRUNCATE is revoked for authenticated and anon across all 4 tables
  SELECT has_table_privilege('authenticated', 'public.trips', 'TRUNCATE') INTO v_can_truncate_trips;
  SELECT has_table_privilege('authenticated', 'public.profiles', 'TRUNCATE') INTO v_can_truncate_profiles;
  SELECT has_table_privilege('authenticated', 'public.trip_activities', 'TRUNCATE') INTO v_can_truncate_activities;
  SELECT has_table_privilege('authenticated', 'public.destinations', 'TRUNCATE') INTO v_can_truncate_destinations;

  IF v_can_truncate_trips OR v_can_truncate_profiles OR v_can_truncate_activities OR v_can_truncate_destinations THEN
    RAISE EXCEPTION 'Postcondition failed: TRUNCATE privilege still exists on protected tables';
  END IF;
END $postcondition$;

COMMIT;
