-- ==============================================================================
-- TravelGO Staging Database Bootstrap: baseline.sql
-- Description: Reconstructs pre-remediation application schema on isolated
--              staging project (bkocylxbuyvdgxccpixx). Restores types, defaults,
--              nullability, check constraints, and FK dependencies faithfully from
--              audited repository SQL (supabase_enterprise_schema.sql),
--              client DTO contracts (saved_trip_model.dart), and
--              metadata snapshots (SRC-DB-001/002).
-- Target: STAGING ENVIRONMENT ONLY (travel-go-staging / bkocylxbuyvdgxccpixx)
-- Provenance: Reconstructed staging baseline. Note: Deployed production
--             function body and schema on oavbymauorhmrjcustzw remain UNKNOWN.
-- Safety: NEVER EXECUTE IN PRODUCTION
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 0. PRECONDITION: ABORT IF APPLICATION TABLES ALREADY EXIST (CLEAN ENV ONLY)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('profiles', 'destinations', 'services', 'trips', 'trip_activities')
  ) THEN
    RAISE EXCEPTION 'Bootstrap aborted: One or more application tables already exist in public schema. Bootstrap requires a clean environment.';
  END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 2. APPLICATION TABLES (Faithful reconstruction from audited repo and snapshots)
-- ------------------------------------------------------------------------------

-- 2.1 Profiles Table (matches enterprise schema lines 15-25: role IN customer, travel_expert, admin, partner)
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  phone text,
  email text,
  role text DEFAULT 'customer' CHECK (role IN ('customer', 'travel_expert', 'admin', 'partner')),
  avatar_url text,
  address text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.2 Destinations Catalogue Table (matches enterprise lines 122-130: id text slug, region check)
CREATE TABLE public.destinations (
  id text PRIMARY KEY,
  name text NOT NULL,
  description text,
  image_url text,
  region text NOT NULL CHECK (region IN ('Bắc', 'Trung', 'Nam', 'Tây Nguyên')),
  weather_cached_temp numeric,
  is_popular boolean DEFAULT false,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.3 Services Table (matches enterprise lines 140-156: title text, service_type check hotel/flight/bus/tour/combo)
CREATE TABLE public.services (
  id text PRIMARY KEY,
  destination_id text REFERENCES public.destinations(id) ON DELETE CASCADE,
  title text NOT NULL,
  service_type text NOT NULL CHECK (service_type IN ('hotel', 'flight', 'bus', 'tour', 'combo')),
  price_range text,
  rating numeric DEFAULT 5.0,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.4 Trips Table (matches SRC-DB-001/002, enterprise lines 391-404, & saved_trip_model.dart: destination_name text NOT NULL)
CREATE TABLE public.trips (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  destination_name text NOT NULL,
  num_days integer,
  budget_total numeric,
  start_date date,
  end_date date,
  status text DEFAULT 'planning' CHECK (status IN ('planning', 'confirmed', 'completed', 'cancelled')),
  ai_plan_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.5 Trip Activities Table (matches SRC-DB-001 & enterprise lines 407-423: 12 audited columns)
CREATE TABLE public.trip_activities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  day_number integer NOT NULL DEFAULT 1,
  start_time text NOT NULL,
  title text NOT NULL,
  cost numeric DEFAULT 0,
  service_id text REFERENCES public.services(id) ON DELETE SET NULL,
  is_completed boolean DEFAULT false,
  note text,
  location_name text,
  latitude numeric,
  longitude numeric,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 3. RECONSTRUCTED LEGACY SIGNUP TRIGGER (Demonstrates insecure metadata trust)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    new.id,
    COALESCE(NULLIF(TRIM(new.raw_user_meta_data->>'full_name'), ''), 'Thành viên TravelGO'),
    new.email,
    COALESCE(new.raw_user_meta_data->>'role', 'customer')
  );
  RETURN new;
END;
$$;

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
-- 4. LEGACY INSECURE POLICIES & PERMISSIVE GRANTS (Pre-remediation state)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_activities ENABLE ROW LEVEL SECURITY;

-- Legacy policy: public SELECT on profiles
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Legacy policy: trips & activities
CREATE POLICY "Users view own trips" ON public.trips FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users create own trips" ON public.trips FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own trips" ON public.trips FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own trips" ON public.trips FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users manage own trip activities" ON public.trip_activities FOR ALL USING (
  EXISTS (SELECT 1 FROM public.trips t WHERE t.id = trip_activities.trip_id AND t.user_id = auth.uid())
);

-- Legacy grants: broad table privileges
GRANT ALL ON TABLE public.profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.destinations TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.trips TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.trip_activities TO anon, authenticated, service_role;

COMMIT;
