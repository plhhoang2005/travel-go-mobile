\set ON_ERROR_STOP on
-- Source only until exact staging apply/test approval. Runner injects raw T1
-- vectors into pg_temp.p32_vectors in THIS connection, without reserializing.
BEGIN;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='10s';
CREATE FUNCTION pg_temp.p32_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'assertion_failed:%',label; END IF; END $f$;
CREATE FUNCTION pg_temp.p32_error(sql_text text,expected text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE observed boolean:=false;
BEGIN
 BEGIN EXECUTE sql_text;
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>expected AND SQLSTATE<>expected THEN RAISE; END IF;
  observed:=true;
 END;
 IF NOT observed THEN RAISE EXCEPTION 'expected_error_not_observed'; END IF;
END $f$;
CREATE FUNCTION pg_temp.p32_hash(raw text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
 SELECT encode(extensions.digest(convert_to(raw,'UTF8'),'sha256'),'hex') $f$;
CREATE FUNCTION pg_temp.p32_body(doc jsonb,commands jsonb DEFAULT NULL,source jsonb DEFAULT NULL) RETURNS text
 LANGUAGE sql SECURITY DEFINER SET search_path='' AS $f$
 SELECT private.p32_canonical(jsonb_build_object('payloadText',private.p32_canonical(doc),'contentDigest',pg_temp.p32_hash(private.p32_canonical(doc)))||
 CASE WHEN commands IS NULL THEN jsonb_build_object('sourceBinding',source) ELSE jsonb_build_object('commands',commands) END) $f$;
CREATE TEMP TABLE p32_ctx(key text PRIMARY KEY,value jsonb NOT NULL);
SELECT gen_random_uuid() AS p32_a,gen_random_uuid() AS p32_b \gset
INSERT INTO auth.users(id,aud,role,email,raw_user_meta_data,created_at,updated_at) VALUES
 (:'p32_a','authenticated','authenticated',:'p32_a'||'@p32-sql.invalid','{}',now(),now()),
 (:'p32_b','authenticated','authenticated',:'p32_b'||'@p32-sql.invalid','{}',now(),now());
INSERT INTO p32_ctx VALUES ('owner',to_jsonb(:'p32_a'::text)),('other',to_jsonb(:'p32_b'::text));
INSERT INTO p32_ctx SELECT 'base',jsonb_set(jsonb_set(jsonb_set(raw_text::jsonb,
 '{input,startDate}','"2026-10-15"'),'{input,endDate}','"2026-10-15"'),'{days,0,date}','"2026-10-15"')
 FROM p32_vectors WHERE name='money_unknown_unicode';
GRANT SELECT,INSERT,UPDATE ON p32_ctx TO authenticated;
GRANT SELECT ON p32_vectors TO authenticated,anon;
DO $f$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated,anon',
 (SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.p32_assert(boolean,text),pg_temp.p32_error(text,text),pg_temp.p32_hash(text),pg_temp.p32_body(jsonb,jsonb,jsonb) TO authenticated,anon;
\if :{?p32_helpers_only}
-- Negative suite owns the following checks and rollback.
\else
DO $f$ DECLARE v record; BEGIN
 PERFORM pg_temp.p32_assert((SELECT count(*) FROM p32_vectors)=5,'complete T1 corpus');
 FOR v IN SELECT * FROM p32_vectors LOOP
  IF v.expected_error IS NULL THEN
   PERFORM pg_temp.p32_assert(private.p32_validate(v.raw_text)=v.raw_text::jsonb,'T1 decode:'||v.name);
   PERFORM pg_temp.p32_assert(private.p32_canonical(v.raw_text::jsonb)=v.canonical_text,'T1 canonical:'||v.name);
   PERFORM pg_temp.p32_assert(pg_temp.p32_hash(v.raw_text)=v.expected_digest,'T1 exact submitted digest:'||v.name);
  ELSE PERFORM pg_temp.p32_error(format('SELECT private.p32_validate(%L)',v.raw_text),v.expected_error); END IF;
 END LOOP;
END $f$;
SELECT pg_temp.p32_assert(NOT has_table_privilege(r,t,p),'private table denied')
 FROM unnest(ARRAY['anon','authenticated','service_role']) r
 CROSS JOIN unnest(ARRAY['private.editable_trip_documents','private.editable_trip_mutations','private.editable_trip_write_permits']) t
 CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE']) p;
SELECT pg_temp.p32_assert(NOT has_function_privilege(r,p.oid,'EXECUTE'),'private helper denied')
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN unnest(ARRAY['anon','authenticated','service_role']) r
 WHERE n.nspname='private' AND p.proname LIKE 'p32_%';
SELECT pg_temp.p32_assert(NOT has_function_privilege('anon',p.oid,'EXECUTE') AND p.prosecdef AND p.proconfig=ARRAY['search_path=""'],'RPC ACL/path')
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN
 ('create_editable_trip_v2','update_editable_trip_v2','delete_editable_trip_v2','get_editable_trip_v2','get_editable_mutation_v2','list_owned_trips_v2');
SELECT pg_temp.p32_assert(private.p32_validate(value::text,true)=value,'account-ready base') FROM p32_ctx WHERE key='base';
SELECT private.p32_entity('{"id":"x","ordinal":1,"date":null,"notes":""}','id ordinal date notes');
SELECT pg_temp.p32_assert(private.p32_nonblank('v') AND NOT private.p32_nonblank(E'\u000b'),'Dart trim vertical tab without trimming letter v');
SELECT pg_temp.p32_assert(value#>>'{input,totalBudgetVnd}'='500000' AND value#>>'{input,travelerCount}'='3'
 AND (value#>>'{estimates,0,unitAmountVnd}')::bigint*3=300000 AND value#>'{estimates,1,unitAmountVnd}'='null'::jsonb
 AND value#>>'{actualExpenses,0,amountVnd}'='250000','money: budget/known/unknown/actual independent') FROM p32_ctx WHERE key='base';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'p32_a','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'p32_a',true);
DO $f$ DECLARE raw text:=$v${"metadata":{"destinationId":null,"destinationName":"Ha Noi","endDate":null,"startDate":null,"timezone":null,"title":"HN"},"plan":null,"request":{"budgetVnd":2000000,"numDays":2,"numPeople":1,"origin":"SG","preferences":["food"],"priority":"balanced"},"schemaVersion":1}$v$;
 original jsonb; doc jsonb; body text; source jsonb; r jsonb; legacy uuid; page jsonb; next_page jsonb;
BEGIN
 original:=public.import_guest_draft_v1('p32-sql','v1-source',1,'v1-source',raw,pg_temp.p32_hash(raw));
 legacy:=(original#>>'{receipt,tripId}')::uuid;
 SELECT value INTO doc FROM p32_ctx WHERE key='base';
 doc:=jsonb_set(doc,'{source}',jsonb_build_object('kind','manual_v1_copy','sourceId',legacy,'sourceDigest',pg_temp.p32_hash(raw)));
 source:=jsonb_build_object('kind','v1_copy','sourceTripId',legacy,'sourceDigest',pg_temp.p32_hash(raw));
 body:=pg_temp.p32_body(doc,NULL,source); r:=public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.p32_hash(body));
 PERFORM pg_temp.p32_assert(r#>>'{receipt,tripId}'<>legacy::text AND public.get_import_trip_snapshot_v1(legacy)=original,'copy leaves V1 exact bytes/receipt unchanged');
 PERFORM pg_temp.p32_error(format('UPDATE public.trips SET title=%L WHERE id=%L','changed',legacy),'imported_trip_immutable');
 INSERT INTO public.trips(user_id,title,destination_name) VALUES((SELECT (value#>>'{}')::uuid FROM p32_ctx WHERE key='owner'),'ordinary V1','Hue');
 page:=public.list_owned_trips_v2(NULL,NULL,1);
 PERFORM pg_temp.p32_assert(jsonb_array_length(page->'items')=1 AND page->'nextCursor'<>'null'::jsonb,'pagination cursor');
 next_page:=public.list_owned_trips_v2((page#>>'{nextCursor,createdAt}')::timestamptz,(page#>>'{nextCursor,id}')::uuid,1);
 PERFORM pg_temp.p32_assert(page#>>'{items,0,tripId}'<>next_page#>>'{items,0,tripId}','pagination no duplicate');
END $f$;
DO $f$ DECLARE doc jsonb; changed jsonb; body text; r jsonb; retry jsonb; req uuid:=gen_random_uuid(); trip uuid; commands jsonb; old_actual jsonb;
BEGIN
 SELECT value INTO doc FROM p32_ctx WHERE key='base';
 body:=pg_temp.p32_body(doc); r:=public.create_editable_trip_v2(req,body,pg_temp.p32_hash(body)); trip:=(r#>>'{receipt,tripId}')::uuid;
 PERFORM pg_temp.p32_assert(r->>'status'='committed' AND r#>>'{receipt,resultVersion}'='1' AND r#>>'{head,version}'='1','create v1');
 PERFORM pg_temp.p32_assert(r#>>'{receipt,committedAt}' ~ 'Z$' AND r#>>'{head,fetchedAt}' ~ 'Z$','UTC wire timestamps');
 retry:=public.create_editable_trip_v2(req,body,pg_temp.p32_hash(body));
 PERFORM pg_temp.p32_assert(retry->'receipt'=r->'receipt' AND retry#>>'{head,payloadText}'=r#>>'{head,payloadText}','lost reply retry');
 INSERT INTO p32_ctx VALUES ('trip',to_jsonb(trip::text)),('create',r),('createRequest',to_jsonb(req::text)),('createBody',to_jsonb(body));
 changed:=jsonb_set(doc,'{days,0,notes}','"Owner edited notes"');
 commands:=jsonb_build_array(jsonb_build_object('op','setDayNotes','dayId',doc#>'{days,0,id}','notes','Owner edited notes'));
 body:=pg_temp.p32_body(changed,commands); req:=gen_random_uuid();
 r:=public.update_editable_trip_v2(trip,1,req,body,pg_temp.p32_hash(body));
 PERFORM pg_temp.p32_assert(r#>>'{head,version}'='2' AND (r#>>'{head,payloadText}')::jsonb->'actualExpenses'=doc->'actualExpenses','update/actual unchanged');
 retry:=public.get_editable_mutation_v2((SELECT (value#>>'{}')::uuid FROM p32_ctx WHERE key='createRequest'));
 PERFORM pg_temp.p32_assert(retry#>>'{receipt,resultVersion}'='1' AND retry#>>'{head,version}'='2','old receipt plus newer head');
 PERFORM pg_temp.p32_error(format('SELECT public.update_editable_trip_v2(%L,1,%L,%L,%L)',trip,gen_random_uuid(),body,pg_temp.p32_hash(body)),'version_conflict');
 PERFORM pg_temp.p32_assert(public.update_editable_trip_v2(trip,1,req,body,pg_temp.p32_hash(body))->'receipt'=r->'receipt','retry before expected-version check');
 PERFORM pg_temp.p32_error(format('SELECT public.update_editable_trip_v2(%L,2,%L,%L,%L)',trip,req,body,pg_temp.p32_hash(body)),'request_identity_conflict');
 -- A forged payload cannot change the actual ledger through an itinerary op.
 changed:=jsonb_set(changed,'{actualExpenses,0,amountVnd}','1'); body:=pg_temp.p32_body(changed,commands);
 PERFORM pg_temp.p32_error(format('SELECT public.update_editable_trip_v2(%L,2,%L,%L,%L)',trip,gen_random_uuid(),body,pg_temp.p32_hash(body)),'invalid_request');
 PERFORM pg_temp.p32_assert(public.get_editable_trip_v2(trip)#>>'{head,version}'='2','invalid batch atomic');
 PERFORM pg_temp.p32_error(format('UPDATE public.trips SET title=%L WHERE id=%L','forged',trip),'versioned_write_required');
 PERFORM set_config('travelgo.editable_write_permit','true',true);
 PERFORM pg_temp.p32_error(format('DELETE FROM public.trips WHERE id=%L',trip),'versioned_write_required');
 PERFORM pg_temp.p32_error(format('INSERT INTO public.trip_activities(trip_id,title,start_time) VALUES(%L,%L,%L)',trip,'forged','09:00'),'versioned_write_required');
 PERFORM pg_temp.p32_error('SELECT * FROM private.editable_trip_write_permits','42501');
 PERFORM pg_temp.p32_assert(EXISTS(SELECT 1 FROM jsonb_array_elements(public.list_owned_trips_v2(NULL,NULL,50)->'items') i WHERE i->>'kind'='editable_v2')
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(public.list_owned_trips_v2(NULL,NULL,50)->'items') i WHERE i->>'kind'='legacy_v1'),'mixed list tags');
END $f$;
-- Another account cannot read A's guessed trip, receipt or copy source.
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'p32_b','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'p32_b',true);
SELECT pg_temp.p32_assert(public.get_editable_trip_v2((value#>>'{}')::uuid)->>'status'='unavailable','cross-owner head') FROM p32_ctx WHERE key='trip';
SELECT pg_temp.p32_assert(public.get_editable_mutation_v2((value#>>'{}')::uuid)->>'status'='not_found','cross-owner receipt') FROM p32_ctx WHERE key='createRequest';
SELECT pg_temp.p32_assert(public.list_owned_trips_v2()->'items'='[]'::jsonb,'owner scoped list');
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'p32_a','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'p32_a',true);
DO $f$ DECLARE trip uuid:=(SELECT (value#>>'{}')::uuid FROM p32_ctx WHERE key='trip'); r jsonb; req uuid:=gen_random_uuid(); body text;
BEGIN
 r:=public.delete_editable_trip_v2(trip,2,req);
 PERFORM pg_temp.p32_assert(r->>'status'='deleted' AND r#>>'{receipt,resultVersion}'='3' AND r->'head'='null'::jsonb,'delete tombstone');
 PERFORM pg_temp.p32_assert(public.delete_editable_trip_v2(trip,2,req)=r,'delete retry');
 SELECT value#>>'{}' INTO body FROM p32_ctx WHERE key='createBody';
 r:=public.create_editable_trip_v2((SELECT (value#>>'{}')::uuid FROM p32_ctx WHERE key='createRequest'),body,pg_temp.p32_hash(body));
 PERFORM pg_temp.p32_assert(r->>'status'='deleted' AND r#>>'{receipt,resultVersion}'='1','create retry never resurrects deleted trip');
 -- Leave a fresh V2 aggregate for exact account cascade check below.
 body:=pg_temp.p32_body((SELECT value FROM p32_ctx WHERE key='base'));
 r:=public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.p32_hash(body));
END $f$;
RESET ROLE;
-- Exercise every typed op, including intermediate resize state, acknowledgments
-- and the explicit actual-ledger boundary. No activity operation changes money.
DO $f$ DECLARE doc jsonb; a jsonb; b jsonb; day2 jsonb; estimate jsonb; expense jsonb; commands jsonb;
 inp jsonb; issue jsonb; expected_amount jsonb; day1 text;
BEGIN
 SELECT value INTO doc FROM p32_ctx WHERE key='base'; day1:=doc#>>'{days,0,id}';
 a:=jsonb_build_object('id',gen_random_uuid(),'dayId',day1,'position',0,'title','A','placeId',NULL,'startMinute',540,'endMinute',600,'notes','',
 'provenance',jsonb_build_object('quality','user_provided','sourceRefs','[]'::jsonb,'observedAt',NULL));
 b:=a||jsonb_build_object('id',gen_random_uuid(),'position',1,'title','B','startMinute',600,'endMinute',660);
 estimate:=(doc#>'{estimates,0}')||jsonb_build_object('itemId',a->'id');
 expense:=(doc#>'{actualExpenses,0}')||jsonb_build_object('itemId',b->'id'); expected_amount:=expense->'amountVnd';
 commands:=jsonb_build_array(jsonb_build_object('op','addItem','item',a),jsonb_build_object('op','addItem','item',b),
 jsonb_build_object('op','putEstimate','estimate',estimate),jsonb_build_object('op','putActual','actual',expense),
 jsonb_build_object('op','setDayNotes','dayId',day1,'notes','Notes'));
 doc:=private.p32_replay(doc,commands); PERFORM private.p32_validate(doc::text,true);
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','moveItem','itemId',a->'id','dayId',day1,'position',1),
 jsonb_build_object('op','reorderDay','dayId',day1,'orderedItemIds',jsonb_build_array(a->'id',b->'id'))));
 PERFORM pg_temp.p32_assert(doc#>>'{items,0,id}'=a->>'id' AND doc#>'{actualExpenses,0,amountVnd}'=expected_amount,'move/reorder keep actual');
 b:=b||jsonb_build_object('startMinute',570,'endMinute',630);
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','editItem','itemId',b->'id')||(b-'id'-'dayId'-'position')));
 SELECT value INTO issue FROM jsonb_array_elements(private.p32_issues(doc)) WHERE value->>'issueCode'='overlap';
 PERFORM pg_temp.p32_assert(issue IS NOT NULL,'overlap fingerprint exists');
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','acknowledgeIssue','exception',issue||jsonb_build_object('reason','Owner accepts this overlap'))));
 PERFORM private.p32_validate(doc::text,true);
 inp:=(doc->'input')||'{"endDate":"2026-10-16"}'::jsonb;
 day2:=jsonb_build_object('id',gen_random_uuid(),'ordinal',2,'date','2026-10-16','notes','');
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','setInput','input',inp),
 jsonb_build_object('op','resizeDays','days',(doc->'days')||jsonb_build_array(day2),'moves','[]'::jsonb,'removedItemIds','[]'::jsonb),
 jsonb_build_object('op','moveItem','itemId',b->'id','dayId',day2->'id','position',0)));
 PERFORM private.p32_validate(doc::text,true);
 PERFORM pg_temp.p32_assert(doc->'exceptions'='[]'::jsonb AND doc#>'{actualExpenses,0,amountVnd}'=expected_amount,'move invalidates scoped acknowledgment without changing actual');
 inp:=(doc->'input')||'{"endDate":"2026-10-15"}'::jsonb;
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','setInput','input',inp),
 jsonb_build_object('op','resizeDays','days',jsonb_build_array(doc#>'{days,0}'),'moves','[]'::jsonb,'removedItemIds',jsonb_build_array(b->'id'))));
 PERFORM private.p32_validate(doc::text,true);
 PERFORM pg_temp.p32_assert(doc#>'{actualExpenses,0,amountVnd}'=expected_amount AND doc#>'{actualExpenses,0,itemId}'='null'::jsonb
 AND doc#>>'{actualExpenses,0,sourceItemSnapshot,title}'='B','resize removes only item and keeps actual snapshot/money');
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','removeItem','itemId',a->'id')));
 PERFORM pg_temp.p32_assert(doc->'items'='[]'::jsonb AND doc#>'{actualExpenses,0,amountVnd}'=expected_amount,'remove actual protection');
 doc:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','deleteActual','expenseId',expense->'id')));
 PERFORM private.p32_validate(doc::text,true);
 PERFORM pg_temp.p32_assert(doc->'actualExpenses'='[]'::jsonb AND jsonb_array_length(doc->'estimates')=2,'explicit deleteActual leaves estimates');
END $f$;
DO $f$ DECLARE doc jsonb; result jsonb; item jsonb; BEGIN
 SELECT value INTO doc FROM p32_ctx WHERE key='base';
 item:=jsonb_build_object('id',gen_random_uuid(),'dayId',doc#>'{days,0,id}','position',0,'title','Museum','placeId',NULL,'startMinute',540,'endMinute',600,'notes','',
 'provenance',jsonb_build_object('quality','user_provided','sourceRefs','[]'::jsonb,'observedAt',NULL));
 doc:=jsonb_set(doc,'{items}',jsonb_build_array(item)); doc:=jsonb_set(doc,'{actualExpenses,0,itemId}',item->'id');
 doc:=jsonb_set(doc,'{estimates,0,itemId}',item->'id');
 result:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','removeItem','itemId',item->'id')));
 PERFORM private.p32_validate(result::text,true);
 PERFORM pg_temp.p32_assert(result->'items'='[]'::jsonb AND result#>>'{actualExpenses,0,amountVnd}'='250000'
 AND result#>'{actualExpenses,0,itemId}'='null'::jsonb AND result#>>'{actualExpenses,0,sourceItemSnapshot,title}'='Museum'
 AND result#>>'{estimates,0,active}'='false','remove keeps actual and disables derived estimate');
END $f$;
DELETE FROM auth.users WHERE id=:'p32_a' AND email=:'p32_a'||'@p32-sql.invalid';
SELECT pg_temp.p32_assert(NOT EXISTS(SELECT 1 FROM private.editable_trip_documents WHERE owner_id=:'p32_a')
 AND NOT EXISTS(SELECT 1 FROM private.editable_trip_mutations WHERE owner_id=:'p32_a')
 AND NOT EXISTS(SELECT 1 FROM public.trips WHERE user_id=:'p32_a'),'account cascade');
SELECT pg_temp.p32_assert(md5(pg_get_functiondef('private.guest_b3_trip_guard()'::regprocedure))='86dbec45babd7eb72937b9f8a455c65a'
 AND md5(pg_get_functiondef('public.import_guest_draft_v1(text,text,bigint,text,text,text)'::regprocedure))='8f96ede11466e66055b04b35c970d64e'
 AND md5(pg_get_functiondef('public.get_import_trip_snapshot_v1(uuid)'::regprocedure))='37296be3a0bfe0495195ebac85f3bea1','B3 definitions unchanged');
SELECT pg_temp.p32_assert(NOT EXISTS(SELECT 1 FROM private.editable_trip_write_permits),'permits consumed');
ROLLBACK;
\echo P32_POSITIVE_PASS
\endif
