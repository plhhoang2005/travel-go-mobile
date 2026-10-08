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
-- PRECONDITION CHECKS (Fail-closed Baseline & Schema Verification)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  -- Verify required tables exist
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

  -- Verify baseline columns exist on public.profiles
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role') THEN
    RAISE EXCEPTION 'Precondition failed: column role does not exist on public.profiles';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'full_name') THEN
    RAISE EXCEPTION 'Precondition failed: column full_name does not exist on public.profiles';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'email') THEN
    RAISE EXCEPTION 'Precondition failed: column email does not exist on public.profiles';
  END IF;

  -- Verify baseline columns exist on public.trips
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'ai_plan_data') THEN
    RAISE EXCEPTION 'Precondition failed: column ai_plan_data does not exist on public.trips';
  END IF;

  -- Verify baseline columns exist on public.trip_activities (matching SRC-DB-001)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trip_activities' AND column_name = 'start_time') THEN
    RAISE EXCEPTION 'Precondition failed: column start_time does not exist on public.trip_activities';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trip_activities' AND column_name = 'title') THEN
    RAISE EXCEPTION 'Precondition failed: column title does not exist on public.trip_activities';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trip_activities' AND column_name = 'cost') THEN
    RAISE EXCEPTION 'Precondition failed: column cost does not exist on public.trip_activities';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 1. HARDEN PROFILES ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Remove insecure public / legacy policies
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
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
AS $$
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
$$;

-- Restrict function execution to administrative callers
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

-- Re-bind trigger on auth.users if auth schema is accessible
DO $$
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
END $$;

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
-- 6. POSTCONDITION VALIDATIONS (Fail-closed Assertions)
-- ------------------------------------------------------------------------------
DO $$
DECLARE
  v_profiles_rls boolean;
  v_trips_rls boolean;
  v_activities_rls boolean;
  v_can_update_role boolean;
  v_can_truncate_trips boolean;
  v_can_truncate_profiles boolean;
  v_can_truncate_activities boolean;
  v_can_truncate_destinations boolean;
  v_anon_can_select_profiles boolean;
  v_permissive_select_policies int;
BEGIN
  -- Verify RLS is enabled on protected tables
  SELECT rowsecurity INTO v_profiles_rls FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles';
  SELECT rowsecurity INTO v_trips_rls FROM pg_tables WHERE schemaname = 'public' AND tablename = 'trips';
  SELECT rowsecurity INTO v_activities_rls FROM pg_tables WHERE schemaname = 'public' AND tablename = 'trip_activities';

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

  -- Verify no unexpected permissive SELECT policies exist on profiles (drift check)
  SELECT count(*) INTO v_permissive_select_policies
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'profiles'
    AND cmd = 'SELECT'
    AND permissive = 'PERMISSIVE';
  IF v_permissive_select_policies <> 1 THEN
    RAISE EXCEPTION 'Postcondition failed: expected exactly 1 permissive SELECT policy on profiles, found %', v_permissive_select_policies;
  END IF;

  -- Verify mutating DDL privileges: TRUNCATE is revoked for authenticated and anon across all 4 tables
  SELECT has_table_privilege('authenticated', 'public.trips', 'TRUNCATE') INTO v_can_truncate_trips;
  SELECT has_table_privilege('authenticated', 'public.profiles', 'TRUNCATE') INTO v_can_truncate_profiles;
  SELECT has_table_privilege('authenticated', 'public.trip_activities', 'TRUNCATE') INTO v_can_truncate_activities;
  SELECT has_table_privilege('authenticated', 'public.destinations', 'TRUNCATE') INTO v_can_truncate_destinations;

  IF v_can_truncate_trips OR v_can_truncate_profiles OR v_can_truncate_activities OR v_can_truncate_destinations THEN
    RAISE EXCEPTION 'Postcondition failed: TRUNCATE privilege still exists on protected tables';
  END IF;
END $$;

COMMIT;
