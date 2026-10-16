\set ON_ERROR_STOP on
\set p32_helpers_only true
\ir editable_trip_v2.sql
-- Both intentionally broken assertions must be caught by the test detector.
SELECT pg_temp.p32_error('SELECT pg_temp.p32_assert(false,''deliberately broken'')','assertion_failed:deliberately broken');
SELECT pg_temp.p32_error('SELECT pg_temp.p32_error(''SELECT 1'',''missing_error'')','expected_error_not_observed');
SELECT pg_temp.p32_error('SELECT private.p32_parse(''{"a":1,"a":2}'')','invalid_input');
SELECT pg_temp.p32_error('SELECT private.p32_parse(''{"n":1e0}'')','invalid_input');
SELECT pg_temp.p32_assert(private.p32_parse('{"n":-0}')='{"n":0}'::jsonb,'integer negative zero matches Dart');
SELECT pg_temp.p32_error('SELECT private.p32_parse(''{"n":9007199254740992}'')','invalid_input');
SELECT pg_temp.p32_error(format('SELECT private.p32_parse(%L)',repeat('[',34)||'0'||repeat(']',34)),'invalid_input');
SELECT pg_temp.p32_error(format('SELECT private.p32_parse(%L)',repeat(' ',1048577)),'invalid_input');
SELECT pg_temp.p32_error(format('SELECT private.p32_validate(%L,true)',raw_text),'invalid_document') FROM p32_vectors WHERE name='money_unknown_unicode';
SELECT pg_temp.p32_error(format('SELECT private.p32_validate(%L)',jsonb_set(value,'{actualExpenses,0,amountVnd}','-1')::text),'invalid_document') FROM p32_ctx WHERE key='base';
SELECT pg_temp.p32_error(format('SELECT private.p32_validate(%L)',jsonb_set(value,'{days}',(value->'days')||(value->'days'))::text),'invalid_document') FROM p32_ctx WHERE key='base';
SELECT pg_temp.p32_error(format('SELECT private.p32_validate(%L)',jsonb_set(value,'{estimates}',(value->'estimates')||(value->'estimates'))::text),'invalid_document') FROM p32_ctx WHERE key='base';
SET LOCAL ROLE anon;
SELECT pg_temp.p32_error('SELECT public.get_editable_trip_v2(gen_random_uuid())','42501');
SELECT pg_temp.p32_error('SELECT * FROM private.editable_trip_mutations','42501');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'p32_a','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'p32_a',true);
DO $f$ DECLARE doc jsonb:=(SELECT value FROM p32_ctx WHERE key='base'); body text; r jsonb; request uuid:=gen_random_uuid(); trip uuid;
BEGIN
 body:=pg_temp.p32_body(doc);
 PERFORM pg_temp.p32_error(format('SELECT public.create_editable_trip_v2(%L,%L,%L)',request,body,repeat('0',64)),'invalid_request');
 r:=public.create_editable_trip_v2(request,body,pg_temp.p32_hash(body)); trip:=(r#>>'{receipt,tripId}')::uuid;
 body:=pg_temp.p32_body(jsonb_set(doc,'{input,title}','"Changed"'));
 PERFORM pg_temp.p32_error(format('SELECT public.create_editable_trip_v2(%L,%L,%L)',request,body,pg_temp.p32_hash(body)),'request_identity_conflict');
 body:=pg_temp.p32_body(doc,NULL,jsonb_build_object('kind','v1_copy','sourceTripId',gen_random_uuid(),'sourceDigest',repeat('0',64)));
 PERFORM pg_temp.p32_error(format('SELECT public.create_editable_trip_v2(%L,%L,%L)',gen_random_uuid(),body,pg_temp.p32_hash(body)),'source_unavailable');
 body:=pg_temp.p32_body(doc,NULL,jsonb_build_object('kind','guest_import','deviceScope','test','draftId','test','sourceRevision',1));
 PERFORM public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.p32_hash(body));
 PERFORM pg_temp.p32_error(format('SELECT public.create_editable_trip_v2(%L,%L,%L)',gen_random_uuid(),body,pg_temp.p32_hash(body)),'source_identity_conflict');
 PERFORM pg_temp.p32_error(format('INSERT INTO public.trips(user_id,title,destination_name,ai_plan_data) VALUES(%L,%L,%L,%L)',
 (SELECT value#>>'{}' FROM p32_ctx WHERE key='owner'),'fake','fake','{"schemaVersion":2}'),'versioned_write_required');
 PERFORM pg_temp.p32_error('INSERT INTO private.editable_trip_write_permits VALUES(pg_backend_pid(),pg_current_xact_id(),gen_random_uuid(),''UPDATE'')','42501');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT value#>>'{}' FROM p32_ctx WHERE key='other'),'role','authenticated')::text,true);
 PERFORM set_config('request.jwt.claim.sub',(SELECT value#>>'{}' FROM p32_ctx WHERE key='other'),true);
 PERFORM pg_temp.p32_error(format('SELECT public.delete_editable_trip_v2(%L,1,%L)',trip,gen_random_uuid()),'trip_unavailable');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',(SELECT value#>>'{}' FROM p32_ctx WHERE key='owner'),'role','authenticated','is_anonymous',true)::text,true);
 PERFORM pg_temp.p32_error('SELECT public.list_owned_trips_v2()','unauthorized');
END $f$;
RESET ROLE;
ROLLBACK;
\echo P32_NEGATIVE_PASS
