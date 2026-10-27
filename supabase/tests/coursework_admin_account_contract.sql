\set ON_ERROR_STOP on
BEGIN;
CREATE FUNCTION pg_temp.c6_check(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL C6: %', label; END IF;
  RAISE NOTICE 'PASS C6: %', label;
END $$;
CREATE FUNCTION pg_temp.c6_denied(statement text, expected text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text := 'none';
BEGIN
  BEGIN EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE; END;
  PERFORM pg_temp.c6_check(actual=expected,'deny '||expected||' actual '||actual);
END $$;
INSERT INTO auth.users(id,email,email_confirmed_at,created_at) VALUES
 ('a6666666-0000-4000-8000-000000000001','c6-admin@example.invalid',now(),'2026-10-01T00:00:00Z'),
 ('c6666666-0000-4000-8000-000000000001','c6-target@example.invalid',now(),'2026-10-01T00:00:00Z');
UPDATE public.profiles SET role='admin' WHERE id='a6666666-0000-4000-8000-000000000001';
INSERT INTO auth.sessions(id,user_id,not_after) VALUES
 ('e6666666-0000-4000-8000-000000000001','a6666666-0000-4000-8000-000000000001',now()+interval '1 day');
DO $$ BEGIN
  PERFORM set_config('request.jwt.claim.sub','a6666666-0000-4000-8000-000000000001',true);
  PERFORM set_config('request.jwt.claims','{"sub":"a6666666-0000-4000-8000-000000000001","session_id":"e6666666-0000-4000-8000-000000000001","role":"authenticated"}',true);
END $$;
SET LOCAL ROLE authenticated;
SELECT public.admin_accounts('mutate','{"requestId":"d6666666-0000-4000-8000-000000000001","targetId":"c6666666-0000-4000-8000-000000000001","expectedRevision":1,"action":"lock","reason":"C6 contract"}') AS operation \gset
SELECT pg_temp.c6_check((:'operation'::jsonb)->>'state'='pending','operation state is pending');
SELECT pg_temp.c6_check((public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}')->>'authSynced')::boolean=false,'pending lock readback is not Auth synced');
SELECT pg_temp.c6_check(public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}')->'pendingOperation'->>'id'='d6666666-0000-4000-8000-000000000001','detail exposes resumable operation identity');
SELECT pg_temp.c6_check(NOT (public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}')->'pendingOperation' ? 'workerToken'),'detail does not expose worker token');
SELECT public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}') - 'audit' - 'pendingOperation' AS lock_pending_user \gset
SELECT pg_temp.c6_check((public.admin_accounts('dispatch',jsonb_build_object('operationId',:'operation'::jsonb->>'id','workerToken',:'operation'::jsonb->>'workerToken','expectedRevision',2))->>'dispatch')::boolean,'first dispatch granted');
SELECT pg_temp.c6_check((public.admin_accounts('dispatch',jsonb_build_object('operationId',:'operation'::jsonb->>'id','workerToken',:'operation'::jsonb->>'workerToken','expectedRevision',2))->>'dispatch')::boolean=false,'duplicate dispatch denied');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT pg_temp.c6_denied(format('SELECT public.complete_admin_account_operation(%L,%L,2,true)',:'operation'::jsonb->>'id','00000000-0000-4000-8000-000000000000'),'40301');
SELECT public.complete_admin_account_operation((:'operation'::jsonb->>'id')::uuid,(:'operation'::jsonb->>'workerToken')::uuid,2,false) AS lock_retry \gset
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.admin_accounts('reconcile','{"requestId":"d6666666-0000-4000-8000-000000000002","operationId":"d6666666-0000-4000-8000-000000000001","expectedRevision":2,"reason":"C6 retry"}') AS reconciled \gset
SELECT pg_temp.c6_check(:'reconciled'::jsonb->>'state'='pending','reconcile preserves operation revision');
SELECT pg_temp.c6_check(public.admin_accounts('reconcile','{"requestId":"d6666666-0000-4000-8000-000000000002","operationId":"d6666666-0000-4000-8000-000000000001","expectedRevision":2,"reason":"C6 retry"}')=:'reconciled'::jsonb,'reconcile replay identity');
SELECT pg_temp.c6_check((public.admin_accounts('dispatch',jsonb_build_object('operationId',:'reconciled'::jsonb->>'id','workerToken',:'reconciled'::jsonb->>'workerToken','expectedRevision',2))->>'dispatch')::boolean,'retry dispatch granted');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.complete_admin_account_operation((:'reconciled'::jsonb->>'id')::uuid,(:'reconciled'::jsonb->>'workerToken')::uuid,2,true) AS lock_completed \gset
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}') - 'audit' - 'pendingOperation' AS lock_completed_user \gset
SELECT pg_temp.c6_check((:'lock_completed_user'::jsonb->>'authSynced')::boolean,'lock readback synced only after complete');
SELECT pg_temp.c6_check(public.admin_accounts('mutate','{"requestId":"d6666666-0000-4000-8000-000000000001","targetId":"c6666666-0000-4000-8000-000000000001","expectedRevision":1,"action":"lock","reason":"C6 contract"}')->>'state'='completed','completed replay remains completed');
SELECT public.admin_accounts('mutate','{"requestId":"d6666666-0000-4000-8000-000000000003","targetId":"c6666666-0000-4000-8000-000000000001","expectedRevision":2,"action":"unlock","reason":"C6 unlock"}') AS unlock_pending \gset
SELECT public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}') - 'audit' - 'pendingOperation' AS unlock_pending_user \gset
SELECT pg_temp.c6_denied(format('SELECT public.admin_accounts(''dispatch'',%L::jsonb)',jsonb_build_object('operationId',:'reconciled'::jsonb->>'id','workerToken',:'reconciled'::jsonb->>'workerToken','expectedRevision',2)),'40900');
SELECT pg_temp.c6_check((public.admin_accounts('dispatch',jsonb_build_object('operationId',:'unlock_pending'::jsonb->>'id','workerToken',:'unlock_pending'::jsonb->>'workerToken','expectedRevision',3))->>'dispatch')::boolean,'unlock dispatch granted');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT pg_temp.c6_denied(format('SELECT public.complete_admin_account_operation(%L,%L,2,true)',:'reconciled'::jsonb->>'id',:'reconciled'::jsonb->>'workerToken'),'40900');
SELECT public.complete_admin_account_operation((:'unlock_pending'::jsonb->>'id')::uuid,(:'unlock_pending'::jsonb->>'workerToken')::uuid,3,false) AS unlock_retry \gset
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.admin_accounts('reconcile','{"requestId":"d6666666-0000-4000-8000-000000000005","operationId":"d6666666-0000-4000-8000-000000000003","expectedRevision":3,"reason":"C6 unlock retry"}') AS unlock_reconciled \gset
SELECT pg_temp.c6_check((public.admin_accounts('dispatch',jsonb_build_object('operationId',:'unlock_reconciled'::jsonb->>'id','workerToken',:'unlock_reconciled'::jsonb->>'workerToken','expectedRevision',3))->>'dispatch')::boolean,'unlock retry dispatch granted');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.complete_admin_account_operation((:'unlock_reconciled'::jsonb->>'id')::uuid,(:'unlock_reconciled'::jsonb->>'workerToken')::uuid,3,true) AS unlock_completed \gset
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT public.admin_accounts('user','{"targetId":"c6666666-0000-4000-8000-000000000001"}') - 'audit' - 'pendingOperation' AS unlock_completed_user \gset
SELECT pg_temp.c6_check(:'unlock_completed_user'::jsonb->>'state'='enabled','unlock readback enabled');
SELECT pg_temp.c6_check(NOT has_table_privilege('authenticated','private_admin.account_reconcile_attempts','SELECT,INSERT,UPDATE,DELETE'),'reconcile state is private');
SELECT public.admin_accounts('mutate','{"requestId":"d6666666-0000-4000-8000-000000000004","targetId":"c6666666-0000-4000-8000-000000000001","expectedRevision":3,"action":"lock","reason":"C6 revoked actor"}') AS revoked_actor_op \gset
SELECT pg_temp.c6_check((public.admin_accounts('dispatch',jsonb_build_object('operationId',:'revoked_actor_op'::jsonb->>'id','workerToken',:'revoked_actor_op'::jsonb->>'workerToken','expectedRevision',4))->>'dispatch')::boolean,'actor granted before revocation');
RESET ROLE;
UPDATE public.profiles SET role='customer' WHERE id='a6666666-0000-4000-8000-000000000001';
SET LOCAL ROLE service_role;
SELECT pg_temp.c6_denied(format('SELECT public.complete_admin_account_operation(%L,%L,4,true)',:'revoked_actor_op'::jsonb->>'id',:'revoked_actor_op'::jsonb->>'workerToken'),'42501');
RESET ROLE;
UPDATE public.profiles SET role='admin' WHERE id='a6666666-0000-4000-8000-000000000001';
DELETE FROM auth.sessions WHERE id='e6666666-0000-4000-8000-000000000001';
SET LOCAL ROLE authenticated;
SELECT pg_temp.c6_denied('SELECT public.admin_accounts(''access'',''{}'')','42501');
RESET ROLE;
-- Output is consumed by both Dart and Node contract tests. No worker token leaves SQL.
SELECT jsonb_build_object('contract','travelgo.admin.v1','vectors',jsonb_build_array(
 jsonb_build_object('name','lock_pending','operation',:'operation'::jsonb-'workerToken','user',:'lock_pending_user'::jsonb),
 jsonb_build_object('name','lock_needs_retry','operation',:'lock_retry'::jsonb,'user',:'lock_pending_user'::jsonb),
 jsonb_build_object('name','lock_completed','operation',:'lock_completed'::jsonb,'user',:'lock_completed_user'::jsonb),
 jsonb_build_object('name','unlock_pending','operation',:'unlock_pending'::jsonb-'workerToken','user',:'unlock_pending_user'::jsonb),
 jsonb_build_object('name','unlock_needs_retry','operation',:'unlock_retry'::jsonb,'user',:'unlock_pending_user'::jsonb),
 jsonb_build_object('name','unlock_completed','operation',:'unlock_completed'::jsonb,'user',:'unlock_completed_user'::jsonb)
));
ROLLBACK;
