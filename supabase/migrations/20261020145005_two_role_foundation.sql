-- R1: two application roles. No account is promoted by this migration.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
LOCK TABLE public.profiles IN ACCESS EXCLUSIVE MODE;

DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='role'
      AND data_type='text' AND is_nullable='YES' AND column_default='''customer''::text')
    OR NOT EXISTS (SELECT 1 FROM pg_constraint
      WHERE conrelid='public.profiles'::regclass AND conname='profiles_role_check'
        AND convalidated AND pg_get_constraintdef(oid)=
          'CHECK ((role = ANY (ARRAY[''customer''::text, ''partner''::text, ''admin''::text])))') THEN
    RAISE EXCEPTION 'two_role_baseline_drift';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass)
    OR has_column_privilege('anon','public.profiles','role','UPDATE')
    OR has_column_privilege('authenticated','public.profiles','role','UPDATE')
    OR has_table_privilege('anon','public.profiles','SELECT')
    OR has_table_privilege('authenticated','public.profiles','INSERT') THEN
    RAISE EXCEPTION 'two_role_requires_protected_profiles';
  END IF;
  IF (SELECT count(*) FROM pg_policy WHERE polrelid='public.profiles'::regclass)<>2
    OR NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid='public.profiles'::regclass
      AND polcmd='r' AND pg_get_expr(polqual,polrelid)='(id = auth.uid())'
      AND polroles=ARRAY['authenticated'::regrole::oid])
    OR NOT EXISTS (SELECT 1 FROM pg_policy WHERE polrelid='public.profiles'::regclass
      AND polcmd='w' AND pg_get_expr(polqual,polrelid)='(id = auth.uid())'
      AND pg_get_expr(polwithcheck,polrelid)='(id = auth.uid())'
      AND polroles=ARRAY['authenticated'::regrole::oid]) THEN
    RAISE EXCEPTION 'two_role_owner_policy_drift';
  END IF;
  IF to_regnamespace('private_admin') IS NOT NULL THEN
    RAISE EXCEPTION 'two_role_private_schema_collision';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE role IS NOT NULL
    AND role NOT IN ('customer','partner','admin')) THEN
    RAISE EXCEPTION 'two_role_unknown_legacy_role';
  END IF;
END $guard$;

-- Normalize legacy non-admin states without changing ownership or deleting data.
UPDATE public.profiles SET role='customer' WHERE role='partner' OR role IS NULL;
ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
ALTER TABLE public.profiles
  ALTER COLUMN role SET DEFAULT 'customer',
  ALTER COLUMN role SET NOT NULL,
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('customer','admin'));

-- Internal evidence for the separate, owner-approved first-admin operation.
-- No exposed function, new client grants, or general role-assignment endpoint.
CREATE SCHEMA private_admin;
REVOKE ALL ON SCHEMA private_admin FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE private_admin.role_bootstrap_audit (
  event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id uuid NOT NULL,
  old_role text NOT NULL CHECK (old_role='customer'),
  new_role text NOT NULL CHECK (new_role='admin'),
  actor_db_role name NOT NULL DEFAULT session_user,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT one_first_admin_event UNIQUE (subject_id)
);
ALTER TABLE private_admin.role_bootstrap_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private_admin.role_bootstrap_audit FROM PUBLIC,anon,authenticated,service_role;
-- No FK: preserve the historical subject identifier if an account is later deleted.
NOTIFY pgrst,'reload schema';
COMMIT;
