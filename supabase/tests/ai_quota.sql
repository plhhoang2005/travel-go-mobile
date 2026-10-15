-- Run only through the owned local PostgreSQL runner. All fixtures roll back.
BEGIN;
CREATE FUNCTION pg_temp.assert_ok(p_value boolean, p_message text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF p_value IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %', p_message; END IF;
END $$;

SELECT pg_temp.assert_ok(NOT has_schema_privilege('anon', 'private_ai', 'USAGE'), 'anon private schema');
SELECT pg_temp.assert_ok(NOT has_table_privilege('authenticated', 'private_ai.requests', 'SELECT'), 'authenticated ledger');
SELECT pg_temp.assert_ok(NOT has_table_privilege('service_role', 'private_ai.requests', 'SELECT'), 'service direct ledger');
SELECT pg_temp.assert_ok(NOT has_function_privilege('anon', 'public.reserve_ai_request_v1(uuid,boolean,uuid,text)', 'EXECUTE'), 'anon RPC');
SELECT pg_temp.assert_ok(NOT has_function_privilege('authenticated', 'public.finalize_ai_request_v1(uuid,uuid,uuid,text,boolean,jsonb)', 'EXECUTE'), 'authenticated finalize');
SELECT pg_temp.assert_ok(NOT has_function_privilege('service_role', 'private_ai.reserve(uuid,boolean,uuid,text,timestamp with time zone)', 'EXECUTE'), 'service helper');
SELECT pg_temp.assert_ok(has_function_privilege('service_role', 'public.reserve_ai_request_v1(uuid,boolean,uuid,text)', 'EXECUTE'), 'service reserve grant');
DO $$ BEGIN
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM public.reserve_ai_request_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true,gen_random_uuid(),repeat('a',64));
    RAISE EXCEPTION 'Anonymous RPC unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE service_role';
  BEGIN
    PERFORM count(*) FROM private_ai.requests;
    RAISE EXCEPTION 'Direct private ledger unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public.reserve_ai_request_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true,gen_random_uuid(),repeat('a',64));
  EXECUTE 'RESET ROLE';
END $$;
TRUNCATE private_ai.requests, private_ai.usage, private_ai.global_attempts;

CREATE FUNCTION pg_temp.fail_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Injected insertion failure' USING ERRCODE = '23514'; END $$;
CREATE TRIGGER ai_fixture_fail_insert BEFORE INSERT ON private_ai.requests FOR EACH ROW EXECUTE FUNCTION pg_temp.fail_insert();
DO $$ BEGIN
  BEGIN
    PERFORM private_ai.reserve('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true,gen_random_uuid(),repeat('a',64),'2026-10-13T10:00:00Z');
    RAISE EXCEPTION 'Fault control not triggered';
  EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.assert_ok((SELECT count(*) = 0 FROM private_ai.usage), 'atomic usage rollback');
  PERFORM pg_temp.assert_ok((SELECT count(*) = 0 FROM private_ai.global_attempts), 'atomic attempt rollback');
  PERFORM pg_temp.assert_ok((SELECT count(*) = 0 FROM private_ai.requests), 'atomic request rollback');
END $$;
DROP TRIGGER ai_fixture_fail_insert ON private_ai.requests;

DO $$
DECLARE subject uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  id1 uuid := gen_random_uuid(); id2 uuid := gen_random_uuid(); id3 uuid := gen_random_uuid();
  now_at timestamptz := '2026-10-13T10:00:00Z'; a jsonb; b jsonb; w uuid;
BEGIN
  a := private_ai.reserve(subject,true,id1,repeat('a',64),now_at);
  PERFORM pg_temp.assert_ok(a->>'status' = 'reserved' AND (a->>'dispatch')::boolean, 'first dispatch');
  w := (a->>'workerToken')::uuid;
  b := private_ai.reserve(subject,true,id1,repeat('a',64),now_at);
  PERFORM pg_temp.assert_ok(NOT b ? 'dispatch' AND b->>'workerToken' = w::text, 'retry no dispatch');
  BEGIN
    PERFORM private_ai.reserve(subject,true,id1,repeat('b',64),now_at);
    RAISE EXCEPTION 'digest conflict allowed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM private_ai.reserve(subject,false,id1,repeat('a',64),now_at);
    RAISE EXCEPTION 'classification conflict allowed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM private_ai.reserve(subject,true,id2,repeat('a',64),now_at);
  PERFORM private_ai.reserve(subject,true,id3,repeat('a',64),now_at);
  PERFORM pg_temp.assert_ok(private_ai.reserve(subject,true,gen_random_uuid(),repeat('a',64),now_at)->>'status' = 'quota_exhausted', 'fourth denied');
  BEGIN
    PERFORM private_ai.finalize(subject,id1,gen_random_uuid(),repeat('a',64),true,'{"answer":"wrong worker"}',now_at);
    RAISE EXCEPTION 'worker forgery allowed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  a := private_ai.finalize(subject,id1,w,repeat('a',64),false,NULL,now_at);
  PERFORM pg_temp.assert_ok(a->>'status' = 'failed' AND (a->>'remaining')::int = 1, 'failure refunds user');
  PERFORM pg_temp.assert_ok(private_ai.reserve(subject,true,id1,repeat('a',64),now_at)->>'status' = 'failed', 'terminal error replay');
  PERFORM private_ai.reserve(subject,true,gen_random_uuid(),repeat('a',64),now_at);
  PERFORM pg_temp.assert_ok((SELECT attempts = 4 FROM private_ai.global_attempts), 'retry not global charged; failure attempt kept');
END $$;
TRUNCATE private_ai.requests, private_ai.usage, private_ai.global_attempts;

DO $$ DECLARE
  subject uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; id uuid := gen_random_uuid(); a jsonb; w uuid;
  before_midnight timestamptz := '2026-10-13T16:59:59Z'; after_midnight timestamptz := '2026-10-13T17:00:00Z';
BEGIN
  a := private_ai.reserve(subject,true,id,repeat('a',64),before_midnight); w := (a->>'workerToken')::uuid;
  a := private_ai.finalize(subject,id,w,repeat('a',64),true,'{"answer":"usable"}',after_midnight);
  PERFORM pg_temp.assert_ok(a->>'acceptedDay' = '2026-10-13' AND a->>'status' = 'succeeded', 'midnight original bucket');
  PERFORM private_ai.finalize(subject,id,w,repeat('a',64),true,'{"answer":"usable"}',after_midnight);
  PERFORM pg_temp.assert_ok((SELECT used = 1 AND reserved = 0 FROM private_ai.usage), 'repeat finish one charge');
  BEGIN
    PERFORM private_ai.finalize(subject,id,w,repeat('a',64),true,'{"answer":"tampered"}',after_midnight);
    RAISE EXCEPTION 'committed tamper allowed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  a := private_ai.reserve(subject,true,gen_random_uuid(),repeat('a',64),after_midnight);
  PERFORM pg_temp.assert_ok(a->>'acceptedDay' = '2026-10-14' AND (a->>'remaining')::int = 2, 'new day resets');
  a := private_ai.reserve(subject,true,id,repeat('a',64),after_midnight + interval '24 hours');
  PERFORM pg_temp.assert_ok(a->>'status' = 'result_expired' AND a->'result' = 'null'::jsonb AND NOT a ? 'dispatch', 'expired result no regeneration');
END $$;
TRUNCATE private_ai.requests, private_ai.usage, private_ai.global_attempts;

DO $$ DECLARE subject uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; id uuid := gen_random_uuid(); a jsonb; w uuid;
  now_at timestamptz := '2026-10-13T10:00:00Z';
BEGIN
  a := private_ai.reserve(subject,true,id,repeat('a',64),now_at); w := (a->>'workerToken')::uuid;
  a := private_ai.finalize(subject,id,w,repeat('a',64),true,'{"answer":"late"}',now_at + interval '90 seconds');
  PERFORM pg_temp.assert_ok(a->>'status' = 'expired' AND (a->>'remaining')::int = 3 AND a->'result' = 'null'::jsonb, 'expired worker fenced');
  PERFORM pg_temp.assert_ok((SELECT used = 0 AND reserved = 0 FROM private_ai.usage), 'expiry refunds');
  BEGIN
    PERFORM private_ai.reserve(subject,true,gen_random_uuid(),repeat('A',64),now_at);
    RAISE EXCEPTION 'invalid digest allowed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
TRUNCATE private_ai.requests, private_ai.usage, private_ai.global_attempts;

DO $$ DECLARE i integer; a jsonb; now_at timestamptz := '2026-10-13T10:00:00Z';
BEGIN
  FOR i IN 1..20 LOOP
    a := private_ai.reserve(('00000000-0000-4000-8000-' || lpad(to_hex(i),12,'0'))::uuid,true,gen_random_uuid(),repeat('a',64),now_at);
    PERFORM pg_temp.assert_ok(a->>'status' = 'reserved', 'global first twenty');
  END LOOP;
  PERFORM pg_temp.assert_ok(private_ai.reserve('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true,gen_random_uuid(),repeat('a',64),now_at)->>'status' = 'global_cap', 'global cap');
  PERFORM pg_temp.assert_ok((SELECT count(*) = 20 FROM private_ai.requests), 'global no extra row');
END $$;
ROLLBACK;
\echo AI_QUOTA_SQL_ACCEPTANCE_PASS
