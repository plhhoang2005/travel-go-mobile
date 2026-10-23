-- Concurrency and actor boundary test suite for Admin Account Control
\set ON_ERROR_STOP on
BEGIN;

CREATE EXTENSION IF NOT EXISTS dblink;

CREATE FUNCTION pg_temp.check_conc(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: %', label;
  END IF;
  RAISE NOTICE 'PASS: %', label;
END $$;

CREATE FUNCTION pg_temp.denied_conc(statement text, expected_code text, label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
  BEGIN
    EXECUTE statement;
    actual := 'none';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS actual = RETURNED_SQLSTATE;
  END;
  PERFORM pg_temp.check_conc(actual = expected_code, label || format(' [actual=%s expected=%s]', actual, expected_code));
END $$;

-- 1. Fixture Setup for Concurrency & Boundary Tests
INSERT INTO auth.users(id, email, raw_user_meta_data, is_anonymous, deleted_at, banned_until, email_confirmed_at, created_at) VALUES
  ('b1111111-0000-4000-8000-000000000001', 'admin_a@example.invalid', '{}', false, null, null, now(), now()),
  ('b1111111-0000-4000-8000-000000000002', 'admin_b@example.invalid', '{}', false, null, null, now(), now()),
  ('b1111111-0000-4000-8000-000000000003', 'deleted_user@example.invalid', '{}', false, now(), null, now(), now()),
  ('b1111111-0000-4000-8000-000000000004', 'banned_user@example.invalid', '{}', false, null, now() + interval '1 day', now(), now()),
  ('b1111111-0000-4000-8000-000000000005', 'anon_user@example.invalid', '{}', true, null, null, now(), now());

UPDATE public.profiles SET role = 'admin' WHERE id IN ('b1111111-0000-4000-8000-000000000001', 'b1111111-0000-4000-8000-000000000002');
UPDATE public.profiles SET role = 'customer' WHERE id IN ('b1111111-0000-4000-8000-000000000003', 'b1111111-0000-4000-8000-000000000004', 'b1111111-0000-4000-8000-000000000005');

INSERT INTO auth.sessions(id, user_id, not_after, created_at) VALUES
  ('eb111111-0000-4000-8000-000000000001', 'b1111111-0000-4000-8000-000000000001', now() + interval '1 day', now()),
  ('eb111111-0000-4000-8000-000000000002', 'b1111111-0000-4000-8000-000000000002', now() + interval '1 day', now()),
  ('eb111111-0000-4000-8000-000000000003', 'b1111111-0000-4000-8000-000000000001', now() - interval '1 hour', now() - interval '2 hour'); -- expired session

COMMIT;

-- 2. Concurrency: Two-connection last admin preservation
-- Admin A attempts to demote Admin B while Admin B attempts to demote Admin A concurrently.
DO $$
DECLARE
  v_port int := inet_server_port();
  v_conn_str text;
  v_res1 text;
  v_res2 text;
  v_active_admins int;
  v_err1 text := 'NONE';
  v_err2 text := 'NONE';
BEGIN
  v_conn_str := format('host=127.0.0.1 port=%s dbname=%s user=postgres', v_port, current_database());

  -- Open two independent connections via dblink
  PERFORM dblink_connect('conn_admin_a', v_conn_str);
  PERFORM dblink_connect('conn_admin_b', v_conn_str);

  -- Setup actor claims on conn_admin_a
  PERFORM dblink_exec('conn_admin_a', 'BEGIN;');
  PERFORM dblink_exec('conn_admin_a', 'SET LOCAL ROLE authenticated;');
  PERFORM res FROM dblink('conn_admin_a', $q$SELECT set_config('request.jwt.claim.sub', 'b1111111-0000-4000-8000-000000000001', true);$q$) AS t(res text);
  PERFORM res FROM dblink('conn_admin_a', $q$SELECT set_config('request.jwt.claims', '{"sub":"b1111111-0000-4000-8000-000000000001","session_id":"eb111111-0000-4000-8000-000000000001","role":"authenticated"}', true);$q$) AS t(res text);

  -- Setup actor claims on conn_admin_b
  PERFORM dblink_exec('conn_admin_b', 'BEGIN;');
  PERFORM dblink_exec('conn_admin_b', 'SET LOCAL ROLE authenticated;');
  PERFORM res FROM dblink('conn_admin_b', $q$SELECT set_config('request.jwt.claim.sub', 'b1111111-0000-4000-8000-000000000002', true);$q$) AS t(res text);
  PERFORM res FROM dblink('conn_admin_b', $q$SELECT set_config('request.jwt.claims', '{"sub":"b1111111-0000-4000-8000-000000000002","session_id":"eb111111-0000-4000-8000-000000000002","role":"authenticated"}', true);$q$) AS t(res text);

  -- Admin A demotes Admin B (acquiring control_lock in open transaction)
  BEGIN
    SELECT res INTO v_res1 FROM dblink('conn_admin_a', $q$
      SELECT public.admin_accounts('mutate', '{"requestId":"c0000000-0000-4000-8000-000000000001","targetId":"b1111111-0000-4000-8000-000000000002","expectedRevision":1,"action":"demote","reason":"demoting B"}')::text;
    $q$) AS t(res text);
  EXCEPTION WHEN OTHERS THEN
    v_err1 := SQLSTATE;
  END;

  -- Admin B dispatches mutation concurrently via asynchronous query
  -- (blocks waiting for conn_admin_a's control_lock)
  PERFORM dblink_send_query('conn_admin_b', $q$
    SELECT public.admin_accounts('mutate', '{"requestId":"c0000000-0000-4000-8000-000000000002","targetId":"b1111111-0000-4000-8000-000000000001","expectedRevision":1,"action":"demote","reason":"demoting A"}')::text;
  $q$);

  -- Admin A commits, persisting demotion and releasing control_lock
  PERFORM dblink_exec('conn_admin_a', 'COMMIT;');

  -- Admin B unblocks, re-evaluates active admins count, and must be rejected
  BEGIN
    SELECT res INTO v_res2 FROM dblink_get_result('conn_admin_b') AS t(res text);
  EXCEPTION WHEN OTHERS THEN
    v_err2 := SQLSTATE;
  END;

  BEGIN
    PERFORM dblink_exec('conn_admin_b', 'ROLLBACK;');
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  PERFORM dblink_disconnect('conn_admin_a');
  PERFORM dblink_disconnect('conn_admin_b');

  -- Verify exact outcome: one succeeded, one failed with last_admin_preserved (40903) or demoted actor denial (42501)
  IF NOT ((v_err1 = 'NONE' AND v_err2 IN ('40903', '40900', '42501')) OR (v_err2 = 'NONE' AND v_err1 IN ('40903', '40900', '42501'))) THEN
    RAISE EXCEPTION 'Concurrency invariant failed: err1=%, err2=%', v_err1, v_err2;
  END IF;

  -- Verify activeAdmins count is at least 1
  SELECT count(*) INTO v_active_admins
  FROM public.profiles p
  JOIN private_admin.account_access a ON a.subject_id = p.id
  WHERE p.role = 'admin' AND a.state = 'enabled';

  IF v_active_admins < 1 THEN
    RAISE EXCEPTION 'Invariant violation: activeAdmins count dropped to %', v_active_admins;
  END IF;

  RAISE NOTICE 'PASS: concurrent_last_admin_preserved (activeAdmins=%, one rejected with last_admin_preserved)', v_active_admins;
END $$;

-- 3. Actor boundary negative checks
BEGIN;

CREATE FUNCTION pg_temp.claim_user(subject text, session_id text) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claim.sub', subject, true);
  SELECT set_config('request.jwt.claims', jsonb_build_object(
    'sub', subject,
    'session_id', session_id,
    'role', 'authenticated'
  )::text, true)::text;
$$;

SET LOCAL ROLE authenticated;

-- Absent user
SELECT pg_temp.claim_user('b9999999-0000-4000-8000-000000000099', 'eb111111-0000-4000-8000-000000000001');
SELECT pg_temp.denied_conc(
  'SELECT public.admin_accounts(''access'', ''{}''::jsonb)',
  '42501',
  'absent_actor_denied'
);

-- Anonymous user
SELECT pg_temp.claim_user('b1111111-0000-4000-8000-000000000005', 'eb111111-0000-4000-8000-000000000001');
SELECT pg_temp.denied_conc(
  'SELECT public.admin_accounts(''access'', ''{}''::jsonb)',
  '42501',
  'anonymous_actor_denied'
);

-- Deleted user
SELECT pg_temp.claim_user('b1111111-0000-4000-8000-000000000003', 'eb111111-0000-4000-8000-000000000001');
SELECT pg_temp.denied_conc(
  'SELECT public.admin_accounts(''access'', ''{}''::jsonb)',
  '42501',
  'deleted_actor_denied'
);

-- Banned user
SELECT pg_temp.claim_user('b1111111-0000-4000-8000-000000000004', 'eb111111-0000-4000-8000-000000000001');
SELECT pg_temp.denied_conc(
  'SELECT public.admin_accounts(''access'', ''{}''::jsonb)',
  '42501',
  'banned_actor_denied'
);

-- Expired session
SELECT pg_temp.claim_user('b1111111-0000-4000-8000-000000000001', 'eb111111-0000-4000-8000-000000000003');
SELECT pg_temp.denied_conc(
  'SELECT public.admin_accounts(''access'', ''{}''::jsonb)',
  '42501',
  'expired_session_actor_denied'
);

-- Mismatched session (session belonging to user 2 used by user 1)
SELECT pg_temp.claim_user('b1111111-0000-4000-8000-000000000001', 'eb111111-0000-4000-8000-000000000002');
SELECT pg_temp.denied_conc(
  'SELECT public.admin_accounts(''access'', ''{}''::jsonb)',
  '42501',
  'mismatched_session_actor_denied'
);

ROLLBACK;
