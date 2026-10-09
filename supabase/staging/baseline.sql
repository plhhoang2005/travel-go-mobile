-- ==============================================================================
-- TravelGO Staging Database Bootstrap: baseline.sql
-- Description: Reconstructs pre-remediation application schema on isolated
--              staging project (bkocylxbuyvdgxccpixx). Restores types, defaults,
--              nullability, check constraints, and FK dependencies faithfully from
--              owner metadata snapshots (SRC-DB-001/002), client DTO contracts
--              (saved_trip_model.dart), and repository schema (supabase_enterprise_schema.sql).
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
      AND table_name IN ('profiles', 'destinations', 'partner_profiles', 'services', 'trips', 'trip_activities')
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
-- 2. APPLICATION TABLES (Faithful reconstruction matching SRC-DB-001/002 & enterprise)
-- ------------------------------------------------------------------------------

-- 2.1 Profiles Table (matches enterprise lines 15-25: role IN customer, partner, admin)
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  phone text,
  email text,
  role text DEFAULT 'customer' CHECK (role IN ('customer', 'partner', 'admin')),
  avatar_url text,
  address text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.2 Destinations Catalogue Table (matches SRC-DB-001 & enterprise lines 122-130)
CREATE TABLE public.destinations (
  id text PRIMARY KEY,
  name text NOT NULL,
  region text NOT NULL CHECK (region IN ('Bắc', 'Trung', 'Nam', 'Tây Nguyên')),
  description text,
  image_url text,
  weather_cached_temp numeric DEFAULT 26.0,
  is_popular boolean DEFAULT true,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.3 Partner Profiles Table (Dependency for services.partner_id, enterprise lines 93-108)
CREATE TABLE public.partner_profiles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  business_name text NOT NULL,
  business_type text CHECK (business_type IN ('hotel', 'bus', 'tour', 'combo', 'airline')),
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.4 Services Table (Polymorphic catalog, enterprise lines 140-156)
CREATE TABLE public.services (
  id text PRIMARY KEY,
  partner_id uuid REFERENCES public.partner_profiles(id) ON DELETE SET NULL,
  destination_id text NOT NULL REFERENCES public.destinations(id) ON DELETE CASCADE,
  service_type text NOT NULL CHECK (service_type IN ('hotel', 'flight', 'bus', 'tour', 'combo')),
  title text NOT NULL,
  description text,
  location text,
  base_price numeric DEFAULT 0 NOT NULL,
  rating numeric DEFAULT 5.0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.5 Trips Table (matches SRC-DB-001/002, enterprise lines 391-404, & saved_trip_model.dart)
CREATE TABLE public.trips (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  destination_name text NOT NULL,
  num_days integer DEFAULT 3,
  budget_total numeric DEFAULT 0,
  start_date timestamptz,
  end_date timestamptz,
  status text DEFAULT 'planning' CHECK (status IN ('planning', 'booked', 'completed')),
  ai_plan_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.6 Trip Activities Table (matches SRC-DB-001 exact 12 columns & enterprise lines 407-423)
CREATE TABLE public.trip_activities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  day_number integer DEFAULT 1 NOT NULL,
  start_time text NOT NULL,
  end_time text,
  title text NOT NULL,
  description text,
  service_id text REFERENCES public.services(id) ON DELETE SET NULL,
  cost numeric DEFAULT 0,
  has_conflict boolean DEFAULT false,
  conflict_reason text,
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
ALTER TABLE public.destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_activities ENABLE ROW LEVEL SECURITY;

-- Legacy policy: public SELECT on profiles
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Legacy policy: catalogue & partner profiles
CREATE POLICY "Destinations are viewable by everyone" ON public.destinations FOR SELECT USING (true);
CREATE POLICY "Approved partners are viewable by everyone" ON public.partner_profiles FOR SELECT USING (true);
CREATE POLICY "Active services viewable by everyone" ON public.services FOR SELECT USING (true);

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
GRANT ALL ON TABLE public.partner_profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.services TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.trips TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.trip_activities TO anon, authenticated, service_role;

COMMIT;
