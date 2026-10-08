-- ==============================================================================
-- TravelGO Staging Database Bootstrap: baseline.sql
-- Description: Reconstructs pre-remediation application schema on isolated
--              staging project. Contains legacy permissive policies and
--              metadata-trusting signup trigger for regression demonstration.
-- Target: STAGING ENVIRONMENT ONLY (travel-go-staging)
-- Safety: NEVER EXECUTE IN PRODUCTION
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 2. APPLICATION TABLES
-- ------------------------------------------------------------------------------

-- 2.1 Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  email text,
  phone text,
  role text DEFAULT 'customer',
  avatar_url text,
  address text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.2 Destinations Catalogue Table
CREATE TABLE IF NOT EXISTS public.destinations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  description text,
  region text,
  image_url text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.3 Trips Table
CREATE TABLE IF NOT EXISTS public.trips (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  destination_name text,
  num_days integer NOT NULL CHECK (num_days > 0),
  budget_total numeric(12,2) NOT NULL CHECK (budget_total >= 0),
  ai_plan_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.4 Trip Activities Table (Schema matching SRC-DB-001 snapshot)
CREATE TABLE IF NOT EXISTS public.trip_activities (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  day_number integer NOT NULL DEFAULT 1,
  start_time text NOT NULL,
  end_time text,
  title text NOT NULL,
  description text,
  service_id text,
  cost numeric DEFAULT 0,
  has_conflict boolean DEFAULT false,
  conflict_reason text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 3. LEGACY SIGNUP TRIGGER (Trusts client metadata role — to be hardened by migration)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, created_at, updated_at)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    COALESCE(new.raw_user_meta_data->>'role', 'customer'),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    updated_at = now();
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

-- Legacy grants: broad table privileges
GRANT ALL ON TABLE public.profiles TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.destinations TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.trips TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.trip_activities TO anon, authenticated, service_role;

COMMIT;
