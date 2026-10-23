-- Test suite for Admin Account Control (Task A1)
\set ON_ERROR_STOP on
BEGIN;

CREATE FUNCTION pg_temp.check_a1(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: %', label;
  END IF;
  RAISE NOTICE 'PASS: %', label;
END $$;

CREATE FUNCTION pg_temp.denied_a1(statement text, expected_code text, label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
  BEGIN
    EXECUTE statement;
    actual := 'none';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS actual = RETURNED_SQLSTATE;
  END;
  IF expected_code = 'FK_RESTRICT' THEN
    PERFORM pg_temp.check_a1(actual IN ('23001', '23503'), label || format(' [actual=%s expected=23001/23503]', actual));
  ELSE
    PERFORM pg_temp.check_a1(actual = expected_code, label || format(' [actual=%s expected=%s]', actual, expected_code));
  END IF;
END $$;

CREATE FUNCTION pg_temp.claim_user(subject text, session_id text, user_role text DEFAULT 'authenticated', metadata_role text DEFAULT NULL) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claim.sub', subject, true);
  SELECT set_config('request.jwt.claims', jsonb_build_object(
    'sub', subject,
    'session_id', session_id,
    'role', user_role,
    'user_metadata', CASE WHEN metadata_role IS NOT NULL THEN jsonb_build_object('role', metadata_role) ELSE '{}'::jsonb END
  )::text, true)::text;
$$;

-- 1. Invariant Tests: Schema structure and constraints
DO $$
BEGIN
  -- Verify tables exist in private_admin
  IF to_regclass('private_admin.account_access') IS NULL
     OR to_regclass('private_admin.control_lock') IS NULL
     OR to_regclass('private_admin.account_operations') IS NULL
     OR to_regclass('private_admin.audit_events') IS NULL THEN
    RAISE EXCEPTION 'A1 tables missing in private_admin schema';
  END IF;
END $$;

-- Negative constraint tests on private_admin.account_access
SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_access(subject_id, state, revision, session_valid_after) VALUES (gen_random_uuid(), ''invalid_state'', 1, now())',
  '23514',
  'invalid_account_state_check'
);

SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_access(subject_id, state, revision, session_valid_after) VALUES (gen_random_uuid(), ''enabled'', 0, now())',
  '23514',
  'negative_revision_check'
);

SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_access(subject_id, state, revision, session_valid_after) VALUES (''e0000000-0000-4000-8000-000000000099''::uuid, ''enabled'', 1, now())',
  '23503',
  'account_access_fk_auth_users'
);

-- Negative constraint tests on private_admin.account_operations
SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_operations(id, target_id, actor_id, action, state, base_revision, reason, payload_hash) VALUES (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), ''invalid_action'', ''pending'', 1, ''reason'', repeat(''a'', 64))',
  '23514',
  'invalid_operation_action_check'
);

SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_operations(id, target_id, actor_id, action, state, base_revision, reason, payload_hash) VALUES (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), ''lock'', ''invalid_state'', 1, ''reason'', repeat(''a'', 64))',
  '23514',
  'invalid_operation_state_check'
);

SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_operations(id, target_id, actor_id, action, state, base_revision, reason, payload_hash) VALUES (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), ''lock'', ''pending'', 1, '''', repeat(''a'', 64))',
  '23514',
  'empty_reason_check'
);

SELECT pg_temp.denied_a1(
  'INSERT INTO private_admin.account_operations(id, target_id, actor_id, action, state, base_revision, reason, payload_hash) VALUES (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), ''lock'', ''pending'', 1, ''reason'', ''invalid_hash'')',
  '23514',
  'invalid_payload_hash_check'
);

-- 2. Fixtures Setup
INSERT INTO auth.users(id, email, raw_user_meta_data, email_confirmed_at, created_at) VALUES
  ('a1111111-0000-4000-8000-000000000001', 'admin1@example.invalid', '{}', now(), '2026-10-01 10:00:00+07'),
  ('a1111111-0000-4000-8000-000000000002', 'admin2@example.invalid', '{}', now(), '2026-10-02 10:00:00+07'),
  ('c1111111-0000-4000-8000-000000000001', 'cust1@example.invalid', '{"role":"admin"}', now(), '2026-10-23 00:05:00+07'),
  ('c1111111-0000-4000-8000-000000000002', 'cust2@example.invalid', '{}', now(), '2026-10-23 00:30:00+07');

UPDATE public.profiles SET role = 'admin' WHERE id IN ('a1111111-0000-4000-8000-000000000001', 'a1111111-0000-4000-8000-000000000002');
UPDATE public.profiles SET role = 'customer' WHERE id IN ('c1111111-0000-4000-8000-000000000001', 'c1111111-0000-4000-8000-000000000002');

INSERT INTO auth.sessions(id, user_id, not_after) VALUES
  ('e1111111-0000-4000-8000-000000000001', 'a1111111-0000-4000-8000-000000000001', now() + interval '1 day'),
  ('e1111111-0000-4000-8000-000000000002', 'a1111111-0000-4000-8000-000000000002', now() + interval '1 day'),
  ('e1111111-0000-4000-8000-000000000003', 'c1111111-0000-4000-8000-000000000001', now() + interval '1 day');

-- Initial backfill verification
SELECT pg_temp.check_a1(
  (SELECT count(*) FROM private_admin.account_access WHERE subject_id IN (
    'a1111111-0000-4000-8000-000000000001', 'a1111111-0000-4000-8000-000000000002',
    'c1111111-0000-4000-8000-000000000001', 'c1111111-0000-4000-8000-000000000002'
  )) = 4,
  'account_access_backfilled_for_all_users'
);

-- 3. Security & Direct Access Denial
SET LOCAL ROLE authenticated;
SELECT pg_temp.denied_a1('SELECT * FROM private_admin.account_access', '42501', 'authenticated_direct_account_access_denied');
SELECT pg_temp.denied_a1('SELECT * FROM private_admin.account_operations', '42501', 'authenticated_direct_account_operations_denied');
SELECT pg_temp.denied_a1('SELECT * FROM private_admin.audit_events', '42501', 'authenticated_direct_audit_events_denied');

-- Anonymous caller denied
SET LOCAL ROLE anon;
SELECT pg_temp.claim_user('', '');
SELECT pg_temp.denied_a1('SELECT public.admin_accounts(''access'', ''{}''::jsonb)', '42501', 'anon_admin_accounts_denied');

-- Customer caller with spoofed admin metadata denied
SET LOCAL ROLE authenticated;
SELECT pg_temp.claim_user('c1111111-0000-4000-8000-000000000001', 'e1111111-0000-4000-8000-000000000003', 'authenticated', 'admin');
SELECT pg_temp.denied_a1('SELECT public.admin_accounts(''access'', ''{}''::jsonb)', '42501', 'customer_metadata_spoof_denied');

-- Missing session denied
SELECT pg_temp.claim_user('a1111111-0000-4000-8000-000000000001', '');
SELECT pg_temp.denied_a1('SELECT public.admin_accounts(''access'', ''{}''::jsonb)', '42501', 'missing_session_denied');

-- 4. Valid Admin Operations via public.admin_accounts
SELECT pg_temp.claim_user('a1111111-0000-4000-8000-000000000001', 'e1111111-0000-4000-8000-000000000001');

-- 4.1 'access'
SELECT pg_temp.check_a1(
  (public.admin_accounts('access', '{}'::jsonb)->>'allowed')::boolean = true AND
  (public.admin_accounts('access', '{}'::jsonb)->>'role') = 'admin',
  'admin_access_positive'
);

-- 4.2 'dashboard'
SELECT pg_temp.check_a1(
  (public.admin_accounts('dashboard', '{"days":7}'::jsonb)->>'totalUsers')::int >= 4 AND
  (public.admin_accounts('dashboard', '{"days":7}'::jsonb)->>'activeAdmins')::int >= 2,
  'admin_dashboard_positive'
);

-- Pin case: dashboard_vietnam_midnight
-- Users created on 2026-10-23 00:05 and 00:30 Vietnam time must count for date '2026-10-23'
SELECT pg_temp.check_a1(
  EXISTS(
    SELECT 1 FROM jsonb_array_elements(public.admin_accounts('dashboard', '{"days":7}'::jsonb)->'registrations') r
    WHERE (r->>'date') = '2026-10-23' AND (r->>'count')::int >= 2
  ),
  'dashboard_vietnam_midnight'
);

-- 4.3 'users' pagination and cursor
SELECT pg_temp.check_a1(
  jsonb_array_length(public.admin_accounts('users', '{"limit":25}'::jsonb)->'items') >= 4,
  'admin_users_pagination_items'
);

-- 4.4 'user' details with audit events
SELECT pg_temp.check_a1(
  (public.admin_accounts('user', '{"targetId":"c1111111-0000-4000-8000-000000000001"}'::jsonb)->>'id') = 'c1111111-0000-4000-8000-000000000001',
  'admin_user_detail_positive'
);

-- 5. Mutation Tests
-- Self-change denied
SELECT pg_temp.denied_a1(
  'SELECT public.admin_accounts(''mutate'', ''{"requestId":"b0000000-0000-4000-8000-000000000001","targetId":"a1111111-0000-4000-8000-000000000001","expectedRevision":1,"action":"lock","reason":"self lock"}''::jsonb)',
  '40901', -- self_change_denied
  'self_change_denied'
);

-- Mutate Customer (Lock)
SELECT pg_temp.check_a1(
  (public.admin_accounts('mutate', '{"requestId":"b0000000-0000-4000-8000-000000000002","targetId":"c1111111-0000-4000-8000-000000000001","expectedRevision":1,"action":"lock","reason":"Lock customer 1"}'::jsonb)->>'state') = 'pending',
  'customer_lock_mutation_pending'
);

-- Same requestId replayed with exact same payload -> Idempotent replay
SELECT pg_temp.check_a1(
  (public.admin_accounts('mutate', '{"requestId":"b0000000-0000-4000-8000-000000000002","targetId":"c1111111-0000-4000-8000-000000000001","expectedRevision":1,"action":"lock","reason":"Lock customer 1"}'::jsonb)->>'id') = 'b0000000-0000-4000-8000-000000000002',
  'same_request_id_replay_idempotent'
);

-- Same requestId with DIFFERENT payload -> Conflict (request_identity_conflict)
SELECT pg_temp.denied_a1(
  'SELECT public.admin_accounts(''mutate'', ''{"requestId":"b0000000-0000-4000-8000-000000000002","targetId":"c1111111-0000-4000-8000-000000000001","expectedRevision":1,"action":"lock","reason":"DIFFERENT REASON"}''::jsonb)',
  '40902', -- request_identity_conflict
  'request_identity_conflict'
);

-- Missing access row denies
SELECT pg_temp.denied_a1(
  'SELECT public.admin_accounts(''mutate'', ''{"requestId":"b0000000-0000-4000-8000-000000000099","targetId":"f0000000-0000-4000-8000-000000000099","expectedRevision":1,"action":"lock","reason":"missing target"}''::jsonb)',
  '40401', -- missing_access_denies
  'missing_access_denies'
);

-- Worker completion
SET LOCAL ROLE service_role;
SELECT pg_temp.check_a1(
  (public.complete_admin_account_operation(
    'b0000000-0000-4000-8000-000000000002'::uuid,
    gen_random_uuid(),
    1::bigint,
    true
  )->>'state') = 'completed',
  'complete_admin_account_operation_completed'
);

RESET ROLE;

-- Verify locked user has state = 'locked' and revision = 2
SELECT pg_temp.check_a1(
  (SELECT state FROM private_admin.account_access WHERE subject_id = 'c1111111-0000-4000-8000-000000000001') = 'locked' AND
  (SELECT revision FROM private_admin.account_access WHERE subject_id = 'c1111111-0000-4000-8000-000000000001') = 2,
  'account_access_state_locked_revision_2'
);

ROLLBACK;
