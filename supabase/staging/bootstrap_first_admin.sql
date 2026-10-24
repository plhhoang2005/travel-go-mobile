-- STAGING ONLY: bkocylxbuyvdgxccpixx. Separate explicit rollout approval required.
-- Subject resolved from the owner's chosen, confirmed account; never all customers.
-- Execute with a privileged SQL runner, never via a client RPC or embedded secret.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
LOCK TABLE public.profiles IN ACCESS EXCLUSIVE MODE;
LOCK TABLE private_admin.role_bootstrap_audit IN EXCLUSIVE MODE;
DO $bootstrap$
DECLARE
  subject constant uuid := '6346607e-40e0-4182-b887-2cf9d33321f9';
  changed integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='role'
      AND is_nullable='NO')
    OR NOT EXISTS (SELECT 1 FROM pg_constraint
      WHERE conrelid='public.profiles'::regclass AND conname='profiles_role_check'
        AND convalidated AND pg_get_constraintdef(oid)=
          'CHECK ((role = ANY (ARRAY[''customer''::text, ''admin''::text])))') THEN
    RAISE EXCEPTION 'bootstrap_requires_two_role_migration';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE role='admin')
    OR EXISTS (SELECT 1 FROM private_admin.role_bootstrap_audit) THEN
    RAISE EXCEPTION 'bootstrap_already_initialized';
  END IF;
  -- Lock the auth subject so a concurrent account deletion cannot race promotion.
  PERFORM 1 FROM auth.users WHERE id=subject AND email_confirmed_at IS NOT NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'bootstrap_subject_missing_or_unconfirmed'; END IF;
  UPDATE public.profiles SET role='admin' WHERE id=subject AND role='customer';
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>1 THEN RAISE EXCEPTION 'bootstrap_requires_exact_customer'; END IF;
  INSERT INTO private_admin.role_bootstrap_audit(subject_id,old_role,new_role,reason)
    VALUES(subject,'customer','admin','Owner-designated first administrator; approved R1 staging rollout');
  IF (SELECT count(*) FROM public.profiles WHERE role='admin')<>1 THEN
    RAISE EXCEPTION 'bootstrap_admin_count_mismatch';
  END IF;
END $bootstrap$;
COMMIT;
