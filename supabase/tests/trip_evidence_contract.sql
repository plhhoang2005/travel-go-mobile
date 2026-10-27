\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.e_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'A2 assertion: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.e_hash(raw text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT encode(extensions.digest(convert_to(raw,'UTF8'),'sha256'),'hex') $$;
CREATE FUNCTION pg_temp.e_body(doc jsonb,commands jsonb DEFAULT NULL) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.p32_canonical(jsonb_build_object('payloadText',private.p32_canonical(doc),'contentDigest',pg_temp.e_hash(private.p32_canonical(doc))) ||
 CASE WHEN commands IS NULL THEN jsonb_build_object('sourceBinding',NULL) ELSE jsonb_build_object('commands',commands) END) $$;
CREATE TEMP TABLE e_state(key text PRIMARY KEY,value jsonb);
INSERT INTO auth.users(id,aud,role,email) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','authenticated','authenticated','a@example.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','authenticated','authenticated','b@example.invalid');
DO $$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated,anon',(SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $$;
GRANT SELECT ON e_fixture TO authenticated;
GRANT SELECT,INSERT,UPDATE ON e_state TO authenticated;
GRANT EXECUTE ON FUNCTION pg_temp.e_assert(boolean,text),pg_temp.e_hash(text),pg_temp.e_body(jsonb,jsonb) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claims','{"role":"authenticated","is_anonymous":false}',true);
DO $$ DECLARE env jsonb; body text; r jsonb; again jsonb; trip uuid; req uuid:=gen_random_uuid(); changed jsonb;
BEGIN
 SELECT raw_text::jsonb INTO env FROM e_fixture;
 PERFORM pg_temp.e_assert(public.get_trip_capabilities_v1()='{"evidenceV1":true,"ownedListV3":true}'::jsonb,'capability');
 body:=pg_temp.e_body(env);
 r:=public.create_evidence_trip_v1(req,body,pg_temp.e_hash(body)); trip:=(r#>>'{head,tripId}')::uuid;
 PERFORM pg_temp.e_assert(r#>>'{head,payloadText}'=(SELECT raw_text FROM e_fixture),'canonical Dart/SQL create bytes');
 PERFORM pg_temp.e_assert(public.get_evidence_trip_v1(trip)#>>'{head,payloadText}'=(SELECT raw_text FROM e_fixture),'read full envelope');
 PERFORM pg_temp.e_assert(public.list_owned_trips_v3(NULL,NULL,25)#>>'{items,0,kind}'='evidence_v1','list discriminator');
 again:=public.create_evidence_trip_v1(req,body,pg_temp.e_hash(body));
 PERFORM pg_temp.e_assert(again#>>'{head,tripId}'=trip::text,'idempotency same trip');
 PERFORM pg_temp.e_assert((SELECT count(*) FROM public.trips WHERE user_id=auth.uid())=1,'no duplicate after lost ACK');
 PERFORM pg_temp.e_assert(public.get_evidence_mutation_v1(req)->>'status'='committed','status receipt');
 BEGIN PERFORM public.create_evidence_trip_v1(req,body||' ',pg_temp.e_hash(body||' ')); RAISE EXCEPTION 'expected identity denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'request_identity_conflict' THEN RAISE; END IF; END;
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,repeat('0',64)); RAISE EXCEPTION 'expected digest denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_request' THEN RAISE; END IF; END;
 changed:=jsonb_set(env,'{claims,0,text}','"Updated source explanation"'); body:=pg_temp.e_body(changed,'[]');
 r:=public.update_evidence_trip_v1(trip,1,gen_random_uuid(),body,pg_temp.e_hash(body));
 PERFORM pg_temp.e_assert((r#>>'{head,version}')::int=2,'source-only edit increments version');
 PERFORM pg_temp.e_assert(r#>>'{head,contentDigest}'<>again#>>'{head,contentDigest}','full digest changes');
 PERFORM pg_temp.e_assert((r#>>'{head,payloadText}')::jsonb->'document'=env->'document','money notes and document unchanged');
 BEGIN PERFORM public.update_evidence_trip_v1(trip,1,gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'expected version denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'version_conflict' THEN RAISE; END IF; END;
 body:=pg_temp.e_body(env->'document','[]');
 BEGIN PERFORM public.update_editable_trip_v2(trip,2,gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'expected downgrade denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT IN ('invalid_request','unsupported_schema','invalid_input') THEN RAISE; END IF; END;
 INSERT INTO e_state VALUES('trip',to_jsonb(trip::text)),('req',to_jsonb(req::text)),('envelope',changed);
END $$;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
DO $$ DECLARE trip uuid:=(SELECT (value#>>'{}')::uuid FROM e_state WHERE key='trip'); req uuid:=(SELECT (value#>>'{}')::uuid FROM e_state WHERE key='req'); body text;
BEGIN
 PERFORM pg_temp.e_assert(public.get_evidence_trip_v1(trip)->>'status'='unavailable','B read denied');
 PERFORM pg_temp.e_assert(public.get_evidence_mutation_v1(req)->>'status'='not_found','B status denied');
 PERFORM pg_temp.e_assert(jsonb_array_length(public.list_owned_trips_v3(NULL,NULL,25)->'items')=0,'B list isolated');
 SELECT pg_temp.e_body(value,'[]') INTO body FROM e_state WHERE key='envelope';
 BEGIN PERFORM public.update_evidence_trip_v1(trip,2,gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'expected B update denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'trip_unavailable' THEN RAISE; END IF; END;
 BEGIN PERFORM public.delete_evidence_trip_v1(trip,2,gen_random_uuid()); RAISE EXCEPTION 'expected B delete denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'trip_unavailable' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
DO $$ DECLARE trip uuid:=(SELECT (value#>>'{}')::uuid FROM e_state WHERE key='trip'); r jsonb;
BEGIN r:=public.delete_evidence_trip_v1(trip,2,gen_random_uuid());
 PERFORM pg_temp.e_assert(r->>'status'='deleted','delete');
 PERFORM pg_temp.e_assert(public.get_evidence_trip_v1(trip)->>'status'='unavailable','deleted unavailable'); END $$;
RESET ROLE;
-- Structural parity and source authority controls use synthetic server data only.
CREATE FUNCTION pg_temp.e_reject(env jsonb,expected text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 BEGIN PERFORM private.pe_validate(private.p32_canonical(env)); RAISE EXCEPTION 'A2 invalid envelope accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>expected THEN RAISE; END IF; END;
END $$;
DO $$ DECLARE env jsonb; bad jsonb; value text; r jsonb; req uuid:=gen_random_uuid(); rid uuid:=gen_random_uuid();
BEGIN
 SELECT raw_text::jsonb INTO env FROM e_fixture;
 bad:=jsonb_set(env,'{claims,0,evidenceIds}','["missing"]'); PERFORM pg_temp.e_reject(bad,'invalid_input');
 bad:=jsonb_set(env,'{evidence}',jsonb_build_array(env#>'{evidence,0}',env#>'{evidence,0}')); PERFORM pg_temp.e_reject(bad,'invalid_input');
 bad:=jsonb_set(env,'{externalBindings,0,itemId}','"00000000-0000-4000-8000-000000000099"'); PERFORM pg_temp.e_reject(bad,'invalid_input');
 bad:=jsonb_set(env,'{document,items,0,placeId}','"catalogue-place"'); PERFORM pg_temp.e_reject(bad,'invalid_input');
 bad:=jsonb_set(env,'{evidence,0,reviewed}','true'); PERFORM pg_temp.e_reject(bad,'invalid_input');
 bad:=jsonb_set(env,'{evidence,0,factValue}',to_jsonb(repeat('ế',1048576))); PERFORM pg_temp.e_reject(bad,'invalid_input');
 bad:=jsonb_set(env,'{evidence,0,origin}','"web"');
 FOREACH value IN ARRAY ARRAY['http://example.org','/relative','https:///no-host','https://user:pass@example.org/a','https://[bad','https://example.org:wrong/a'] LOOP
  PERFORM pg_temp.e_reject(jsonb_set(bad,'{evidence,0,url}',to_jsonb(value)),'invalid_input');
 END LOOP;
 -- A real finalized server receipt, not an input-owned reviewed bit.
 r:=jsonb_set(jsonb_set(env#>'{evidence,0}','{origin}','"web"'),'{url}','"https://example.org/a"');
 r:=jsonb_set(r,'{evidenceRequestId}',to_jsonb(req::text)); env:=jsonb_set(env,'{evidence,0}',r);
 INSERT INTO private_ai.usage(subject,accepted_day) VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',current_date),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',current_date);
 INSERT INTO private_ai.requests(subject,request_id,is_guest,digest,accepted_day,state,worker,expires_at,result,result_expires_at,created_at)
 VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',req,false,repeat('a',64),current_date,'succeeded',gen_random_uuid(),clock_timestamp()+interval '5 minutes',jsonb_build_object('contract','travelgo.web.advice.v1','evidence',jsonb_build_array(r),'claims',env->'claims'),clock_timestamp()+interval '1 hour',clock_timestamp());
 INSERT INTO e_state VALUES('proof-envelope',env),('proof',to_jsonb(req::text));
 -- Catalogue proof is minted only in this privileged server fixture.
 rid:=gen_random_uuid();
 r:=jsonb_set(jsonb_set(r,'{origin}','"catalogue"'),'{reviewed}','true');
 r:=jsonb_set(r,'{evidenceRequestId}',to_jsonb(rid::text));
 INSERT INTO private_ai.requests(subject,request_id,is_guest,digest,accepted_day,state,worker,expires_at,result,result_expires_at,created_at)
 VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',rid,false,repeat('c',64),current_date,'succeeded',gen_random_uuid(),clock_timestamp()+interval '5 minutes',
  jsonb_build_object('contract','travelgo.itinerary.evidence.v1','catalogueVersion','fixture-public-release-1','catalogueDigest',repeat('c',64),'evidence',jsonb_build_array(r),'claims',env->'claims'),clock_timestamp()+interval '1 hour',clock_timestamp());
 INSERT INTO e_state VALUES('catalogue-envelope',jsonb_set(env,'{evidence,0}',r)),('catalogue-proof',to_jsonb(rid::text));
 rid:=gen_random_uuid();
 BEGIN
  INSERT INTO private_ai.requests(subject,request_id,is_guest,digest,accepted_day,state,worker,expires_at,result,result_expires_at,created_at)
  VALUES('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',rid,false,repeat('b',64),current_date,'succeeded',gen_random_uuid(),clock_timestamp()+interval '5 minutes',jsonb_build_object('oversized',repeat('a',16384)),clock_timestamp()+interval '1 hour',clock_timestamp());
  RAISE EXCEPTION 'A2 receipt cap unexpectedly widened';
 EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE env jsonb; bad jsonb; body text; r jsonb; trip uuid;
BEGIN
 SELECT value INTO env FROM e_state WHERE key='proof-envelope';
 body:=pg_temp.e_body(env); r:=public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body)); trip:=(r#>>'{head,tripId}')::uuid;
 INSERT INTO e_state VALUES('proof-trip',to_jsonb(trip::text));
 SELECT value INTO bad FROM e_state WHERE key='catalogue-envelope';
 body:=pg_temp.e_body(bad);
 r:=public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body));
 PERFORM pg_temp.e_assert((r#>>'{head,payloadText}')::jsonb#>>'{evidence,0,origin}'='catalogue','catalogue snapshot from finalized versioned proof');
 PERFORM pg_temp.e_assert(((r#>>'{head,payloadText}')::jsonb#>>'{evidence,0,reviewed}')::boolean,'catalogue review metadata retained');
 bad:=jsonb_set(env,'{claims,0,text}','"Client invents a free admission fact"'); body:=pg_temp.e_body(bad);
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 forged fact claim accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_untrusted' THEN RAISE; END IF; END;
 bad:=jsonb_set(env,'{evidence,0,factValue}','"forged cost"'); body:=pg_temp.e_body(bad);
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 forged source accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_untrusted' THEN RAISE; END IF; END;
 body:=pg_temp.e_body(bad,'[]');
 BEGIN PERFORM public.update_evidence_trip_v1(trip,1,gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 immutable source changed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_immutable' THEN RAISE; END IF; END;
 bad:=jsonb_set(env,'{document,items,0,title}','"Changed activity"');body:=pg_temp.e_body(bad,'[]');
 BEGIN PERFORM public.update_evidence_trip_v1(trip,1,gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 stale citation accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_stale_citation' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
DO $$ DECLARE body text;
BEGIN SELECT pg_temp.e_body(value) INTO body FROM e_state WHERE key='proof-envelope';
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 wrong owner proof accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_expired' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
UPDATE private_ai.requests SET result=result-'catalogueVersion' WHERE request_id=(SELECT (value#>>'{}')::uuid FROM e_state WHERE key='catalogue-proof');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
DO $$ DECLARE body text;
BEGIN SELECT pg_temp.e_body(value) INTO body FROM e_state WHERE key='catalogue-envelope';
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 missing catalogue version accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_untrusted' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
UPDATE private_ai.requests SET result=NULL,result_expires_at=clock_timestamp()-interval '1 minute' WHERE request_id=(SELECT (value#>>'{}')::uuid FROM e_state WHERE key='proof');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
DO $$ DECLARE env jsonb; body text; trip uuid:=(SELECT (value#>>'{}')::uuid FROM e_state WHERE key='proof-trip');
BEGIN SELECT value INTO env FROM e_state WHERE key='proof-envelope';body:=pg_temp.e_body(env);
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.e_hash(body)); RAISE EXCEPTION 'A2 expired proof accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'evidence_expired' THEN RAISE; END IF; END;
 PERFORM pg_temp.e_assert((public.get_evidence_trip_v1(trip)#>>'{head,payloadText}')::jsonb=env,'saved source remains readable after receipt cleanup');
 body:=pg_temp.e_body(jsonb_set(jsonb_set(env,'{claims,0,text}','"Snapshot remains valid"'),'{claims,0,kind}','"inference"'),'[]');
 PERFORM public.update_evidence_trip_v1(trip,1,gen_random_uuid(),body,pg_temp.e_hash(body));
 -- Read the same account list with all supported historical/current kinds.
 body:=pg_temp.e_body(env->'document');
 PERFORM public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.e_hash(body));
 INSERT INTO public.trips(user_id,title,destination_name) VALUES(auth.uid(),'Legacy fixture','Phú Yên');
 PERFORM pg_temp.e_assert(EXISTS(SELECT 1 FROM jsonb_array_elements(public.list_owned_trips_v3(NULL,NULL,25)->'items') row WHERE row->>'kind'='legacy_v1'),'mixed list retains V1');
 PERFORM pg_temp.e_assert(EXISTS(SELECT 1 FROM jsonb_array_elements(public.list_owned_trips_v3(NULL,NULL,25)->'items') row WHERE row->>'kind'='editable_v2'),'mixed list retains V2');
 PERFORM pg_temp.e_assert(EXISTS(SELECT 1 FROM jsonb_array_elements(public.list_owned_trips_v3(NULL,NULL,25)->'items') row WHERE row->>'kind'='evidence_v1'),'mixed list retains evidence');
END $$;
RESET ROLE;
UPDATE private_admin.account_access SET state='locked' WHERE subject_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET LOCAL ROLE authenticated;
DO $$ BEGIN BEGIN PERFORM public.get_trip_capabilities_v1(); RAISE EXCEPTION 'A2 locked account accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'account_locked' THEN RAISE; END IF; END; END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN BEGIN PERFORM public.get_trip_capabilities_v1(); RAISE EXCEPTION 'A2 anon accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END; END $$;
RESET ROLE;
ROLLBACK;
