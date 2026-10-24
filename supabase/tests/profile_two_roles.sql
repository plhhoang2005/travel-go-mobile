-- Actual PostgreSQL grant/RLS/trigger tests; synthetic fixtures, full rollback.
\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  RAISE NOTICE 'PASS: %',label;
END $$;
CREATE FUNCTION pg_temp.expect_error(statement text, expected text, label text) RETURNS void
LANGUAGE plpgsql AS $$ DECLARE actual text; BEGIN
  BEGIN EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE; END;
  PERFORM pg_temp.assert_true(actual=expected,label);
END $$;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM auth.users WHERE id IN
    ('a1911111-1111-4111-8111-111111111111','b1922222-2222-4222-8222-222222222222',
     'c1933333-3333-4333-8333-333333333333')) THEN
    RAISE EXCEPTION 'two_role_fixture_collision';
  END IF;
END $$;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('a1911111-1111-4111-8111-111111111111','roles-a@example.invalid','{"role":"admin"}'),
 ('b1922222-2222-4222-8222-222222222222','roles-b@example.invalid','{"role":"partner"}'),
 ('c1933333-3333-4333-8333-333333333333','roles-c@example.invalid','{}');
SELECT pg_temp.assert_true((SELECT count(*)=3 FROM public.profiles
  WHERE id IN ('a1911111-1111-4111-8111-111111111111','b1922222-2222-4222-8222-222222222222',
  'c1933333-3333-4333-8333-333333333333') AND role='customer'),'signup_spoof_admin_partner_forced_customer');
SELECT pg_temp.expect_error($q$UPDATE public.profiles SET role='partner'
  WHERE id='a1911111-1111-4111-8111-111111111111'$q$,'23514','partner_constraint_denied');
SELECT pg_temp.expect_error($q$UPDATE public.profiles SET role='superadmin'
  WHERE id='a1911111-1111-4111-8111-111111111111'$q$,'23514','unknown_constraint_denied');
SELECT pg_temp.expect_error($q$UPDATE public.profiles SET role=NULL
  WHERE id='a1911111-1111-4111-8111-111111111111'$q$,'23502','null_role_denied');
UPDATE public.profiles SET role=DEFAULT WHERE id='a1911111-1111-4111-8111-111111111111';
SELECT pg_temp.assert_true((SELECT role='customer' FROM public.profiles
  WHERE id='a1911111-1111-4111-8111-111111111111'),'default_is_customer');
UPDATE public.profiles SET role='admin' WHERE id='c1933333-3333-4333-8333-333333333333';
INSERT INTO public.trips(id,user_id,title,destination_name) VALUES
 ('d1944444-4444-4444-8444-444444444444','b1922222-2222-4222-8222-222222222222','Synthetic R1 trip','Synthetic');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','a1911111-1111-4111-8111-111111111111',true);
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.profiles),'customer_own_profile_only');
UPDATE public.profiles SET full_name='R1 owner update' WHERE id=auth.uid();
SELECT pg_temp.assert_true((SELECT full_name='R1 owner update' FROM public.profiles
  WHERE id=auth.uid()),'customer_safe_column_update');
SELECT pg_temp.expect_error($q$UPDATE public.profiles SET role='admin' WHERE id=auth.uid()$q$,
  '42501','customer_cannot_self_promote');
SELECT pg_temp.expect_error($q$INSERT INTO public.profiles(id,full_name,role)
  VALUES('e1955555-5555-4555-8555-555555555555','Forged','admin')$q$,
  '42501','customer_cannot_insert_admin_profile');
DO $$ DECLARE changed integer; BEGIN
  UPDATE public.profiles SET full_name='Cross-owner edit' WHERE id='b1922222-2222-4222-8222-222222222222';
  GET DIAGNOSTICS changed=ROW_COUNT;
  PERFORM pg_temp.assert_true(changed=0,'customer_cross_owner_update_denied');
END $$;
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.trips
  WHERE id='d1944444-4444-4444-8444-444444444444'),'customer_cannot_read_other_trip');
SELECT pg_temp.expect_error('SELECT * FROM private_admin.role_bootstrap_audit',
  '42501','customer_cannot_read_internal_audit');
SELECT pg_temp.expect_error($q$INSERT INTO private_admin.role_bootstrap_audit(subject_id,old_role,new_role,reason)
  VALUES(auth.uid(),'customer','admin','forged')$q$,'42501','customer_cannot_forge_audit');
SELECT set_config('request.jwt.claim.sub','c1933333-3333-4333-8333-333333333333',true);
SELECT pg_temp.assert_true((SELECT role='admin' FROM public.profiles WHERE id=auth.uid()),'admin_reads_own_trusted_role');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.profiles),'admin_no_private_profile_bypass');
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.trips
  WHERE id='d1944444-4444-4444-8444-444444444444'),'admin_no_private_trip_bypass');
SELECT pg_temp.expect_error($q$UPDATE public.profiles SET role='customer' WHERE id=auth.uid()$q$,
  '42501','admin_client_has_no_direct_role_update');
SELECT set_config('request.jwt.claim.sub','',true);
SELECT pg_temp.assert_true((SELECT count(*)=0 FROM public.profiles),'authenticated_missing_subject_sees_none');
SET LOCAL ROLE anon;
SELECT pg_temp.expect_error('SELECT * FROM public.profiles','42501','anon_profiles_denied');
SELECT pg_temp.expect_error('SELECT * FROM private_admin.role_bootstrap_audit','42501','anon_audit_denied');
RESET ROLE;
SELECT pg_temp.assert_true(NOT has_schema_privilege('service_role','private_admin','USAGE'),
  'service_role_no_internal_schema_grant');
ROLLBACK;
