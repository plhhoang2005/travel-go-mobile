-- Migration: 20261023065337_admin_account_guards.sql
-- M_GUARDS: Guard existing account surfaces, receipts, and AI gateway.
BEGIN;

-- 1. Restrictive RLS policies on existing account-bound tables
-- A restrictive policy acts as a mandatory conjunct (AND) with existing permissive policies.
-- Even if an ownership policy evaluates to true, the restrictive policy will deny if account is not enabled.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.profiles;
    CREATE POLICY account_enabled_restrictive ON public.profiles
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'trips') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.trips;
    CREATE POLICY account_enabled_restrictive ON public.trips
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'trip_activities') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.trip_activities;
    CREATE POLICY account_enabled_restrictive ON public.trip_activities
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'partner_profiles') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.partner_profiles;
    CREATE POLICY account_enabled_restrictive ON public.partner_profiles
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'services') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.services;
    CREATE POLICY account_enabled_restrictive ON public.services
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_vouchers') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.user_vouchers;
    CREATE POLICY account_enabled_restrictive ON public.user_vouchers
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'favorites') THEN
    DROP POLICY IF EXISTS account_enabled_restrictive ON public.favorites;
    CREATE POLICY account_enabled_restrictive ON public.favorites
      AS RESTRICTIVE FOR ALL TO authenticated
      USING (private_admin.current_account_enabled())
      WITH CHECK (private_admin.current_account_enabled());
  END IF;
END $$;

-- 2. Guard editable trips private helper if present
DO $$
BEGIN
  IF to_regprocedure('private.p32_owner(boolean)') IS NOT NULL OR to_regproc('private.p32_owner') IS NOT NULL THEN
    CREATE OR REPLACE FUNCTION private.p32_owner(writing boolean DEFAULT false)
    RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $f$
    DECLARE
      owner uuid := auth.uid();
      claims jsonb := coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
    BEGIN
      PERFORM private.p32_require(
        owner IS NOT NULL
        AND current_setting('role', true) = 'authenticated'
        AND claims->>'role' = 'authenticated'
        AND claims->'is_anonymous' IS DISTINCT FROM 'true'::jsonb,
        'unauthorized'
      );

      -- Check account is currently enabled via private_admin predicate
      PERFORM private.p32_require(private_admin.current_account_enabled(), 'account_locked');

      PERFORM 1 FROM auth.users WHERE id = owner FOR KEY SHARE;
      PERFORM private.p32_require(FOUND, 'unauthorized');

      IF writing THEN
        PERFORM pg_advisory_xact_lock(hashtextextended(owner::text, 73302));
      ELSE
        PERFORM pg_advisory_xact_lock_shared(hashtextextended(owner::text, 73302));
      END IF;

      RETURN owner;
    END;
    $f$;
  END IF;
END $$;

-- 3. Service-role gateway account check function
-- public.check_gateway_account(p_subject uuid, p_session_id uuid, p_is_guest boolean) RETURNS jsonb
CREATE OR REPLACE FUNCTION public.check_gateway_account(
  p_subject uuid,
  p_session_id uuid,
  p_is_guest boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user record;
  v_access record;
  v_session record;
BEGIN
  -- Service role check
  IF current_setting('role', true) IS DISTINCT FROM 'service_role'
     AND session_user IS DISTINCT FROM 'service_role'
     AND coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;

  -- Guest check: guest cannot bypass truth if an authenticated subject is provided
  IF p_is_guest THEN
    IF p_subject IS NOT NULL THEN
      SELECT * INTO v_user FROM auth.users WHERE id = p_subject;
      IF FOUND AND NOT coalesce(v_user.is_anonymous, false) THEN
        RAISE EXCEPTION 'guest_bypass_denied' USING ERRCODE = '42501';
      END IF;
    END IF;
    RETURN jsonb_build_object('allowed', true, 'guest', true);
  END IF;

  -- Authenticated user validation
  IF p_subject IS NULL THEN
    RAISE EXCEPTION 'unauthorized: missing subject' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_user
  FROM auth.users
  WHERE id = p_subject;

  IF NOT FOUND OR v_user.deleted_at IS NOT NULL OR (v_user.banned_until IS NOT NULL AND v_user.banned_until > now()) THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_access
  FROM private_admin.account_access
  WHERE subject_id = p_subject;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'missing_access_denies' USING ERRCODE = '40401';
  END IF;

  IF v_access.state <> 'enabled' THEN
    RAISE EXCEPTION 'account_locked' USING ERRCODE = '40301';
  END IF;

  IF p_session_id IS NOT NULL THEN
    SELECT * INTO v_session
    FROM auth.sessions
    WHERE id = p_session_id AND user_id = p_subject;

    IF NOT FOUND OR (v_session.not_after IS NOT NULL AND v_session.not_after <= now()) OR v_session.created_at < v_access.session_valid_after THEN
      RAISE EXCEPTION 'invalid_session' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$$;

REVOKE ALL ON FUNCTION public.check_gateway_account(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_gateway_account(uuid, uuid, boolean) TO service_role;

COMMIT;
