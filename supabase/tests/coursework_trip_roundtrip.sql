\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.c5_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'C5 assertion: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.c5_canonical(doc jsonb) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT private.p32_canonical(doc) $$;
CREATE FUNCTION pg_temp.c5_hash(raw text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$ SELECT encode(extensions.digest(convert_to(raw,'UTF8'),'sha256'),'hex') $$;
CREATE FUNCTION pg_temp.c5_body(doc jsonb,commands jsonb DEFAULT NULL) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.p32_canonical(jsonb_build_object('payloadText',private.p32_canonical(doc),
 'contentDigest',encode(extensions.digest(convert_to(private.p32_canonical(doc),'UTF8'),'sha256'),'hex')) ||
 CASE WHEN commands IS NULL THEN jsonb_build_object('sourceBinding',NULL) ELSE jsonb_build_object('commands',commands) END) $$;
CREATE TEMP TABLE c5_state(key text PRIMARY KEY,value jsonb);
INSERT INTO auth.users(id,aud,role,email) VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','authenticated','authenticated','a@example.invalid'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','authenticated','authenticated','b@example.invalid');
DO $$ DECLARE doc jsonb; bad jsonb; name text; BEGIN
 SELECT raw_text::jsonb INTO doc FROM c5_fixture;
 PERFORM pg_temp.c5_assert(doc#>>'{input,destinationId}' IS NULL,'self entered has no invented ID');
 PERFORM pg_temp.c5_assert(doc#>>'{input,destinationName}'='Phú Yên','UTF8 name');
 PERFORM private.p32_validate(private.p32_canonical(doc),true);
 FOREACH name IN ARRAY ARRAY['','   ',repeat('a',181)] LOOP
  bad:=jsonb_set(doc,'{input,destinationName}',to_jsonb(name));
  BEGIN PERFORM private.p32_validate(private.p32_canonical(bad),true);
   RAISE EXCEPTION 'C5 expected invalid name rejection';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT IN ('assertion_failed','invalid_input') THEN RAISE; END IF; END;
 END LOOP;
 bad:=jsonb_set(doc,'{input,destinationId}','"NOT VALID"');
 BEGIN PERFORM private.p32_validate(private.p32_canonical(bad),true);
  RAISE EXCEPTION 'C5 expected invalid ID rejection';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_input' THEN RAISE; END IF; END;
END $$;
DO $$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated,anon',(SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $$;
GRANT SELECT ON c5_fixture TO authenticated;
GRANT SELECT,INSERT ON c5_state TO authenticated;
GRANT EXECUTE ON FUNCTION pg_temp.c5_assert(boolean,text),pg_temp.c5_canonical(jsonb),pg_temp.c5_hash(text),pg_temp.c5_body(jsonb,jsonb) TO authenticated;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claims','{"role":"authenticated","is_anonymous":false}',true);
DO $$ DECLARE doc jsonb; body text; result jsonb; replay jsonb; trip uuid; changed jsonb; req uuid; command jsonb; bad jsonb;
BEGIN
 SELECT raw_text::jsonb INTO doc FROM c5_fixture;
 body:=pg_temp.c5_body(doc); req:=gen_random_uuid();
 result:=public.create_editable_trip_v2(req,body,pg_temp.c5_hash(body));
 trip:=(result#>>'{receipt,tripId}')::uuid;
 PERFORM pg_temp.c5_assert(result#>>'{head,payloadText}'=pg_temp.c5_canonical(doc),'create exact bytes');
 PERFORM pg_temp.c5_assert(result#>>'{head,ownerId}'=auth.uid()::text,'head keeps owner for client validation');
 replay:=public.create_editable_trip_v2(req,body,pg_temp.c5_hash(body));
 PERFORM pg_temp.c5_assert(replay#>>'{receipt,tripId}'=trip::text,'lost ACK replay one trip');
 BEGIN PERFORM public.create_editable_trip_v2(gen_random_uuid(),body,repeat('0',64));
  RAISE EXCEPTION 'C5 expected digest denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_request' THEN RAISE; END IF; END;
 BEGIN PERFORM public.create_editable_trip_v2(req,body||' ',pg_temp.c5_hash(body||' '));
  RAISE EXCEPTION 'C5 expected request identity denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'request_identity_conflict' THEN RAISE; END IF; END;
 PERFORM pg_temp.c5_assert((SELECT count(*) FROM public.trips WHERE user_id=auth.uid())=1,'one owned trip');
 PERFORM pg_temp.c5_assert(public.get_editable_trip_v2(trip)#>>'{head,payloadText}'=pg_temp.c5_canonical(doc),'read exact bytes');
 PERFORM pg_temp.c5_assert(public.list_owned_trips_v2(NULL,NULL,25)#>>'{items,0,destinationName}'='Phú Yên','list keeps name');
 changed:=jsonb_set(doc,'{days,0,notes}','"Giữ ghi chú sau khi mở lại"');
 command:=jsonb_build_array(jsonb_build_object('op','setDayNotes','dayId',doc#>'{days,0,id}','notes','Giữ ghi chú sau khi mở lại'));
 body:=pg_temp.c5_body(changed,command);
 result:=public.update_editable_trip_v2(trip,1,gen_random_uuid(),body,pg_temp.c5_hash(body));
 PERFORM pg_temp.c5_assert((result#>>'{head,version}')::int=2,'update version');
 PERFORM pg_temp.c5_assert(result#>>'{head,payloadText}'=pg_temp.c5_canonical(changed),'update preserves actuals/estimates');
 BEGIN PERFORM public.update_editable_trip_v2(trip,1,gen_random_uuid(),body,pg_temp.c5_hash(body));
  RAISE EXCEPTION 'C5 expected conflict';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'version_conflict' THEN RAISE; END IF; END;
 BEGIN UPDATE public.trips SET title='bypass' WHERE id=trip;
  RAISE EXCEPTION 'C5 expected direct write denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'versioned_write_required' THEN RAISE; END IF; END;
 bad:=jsonb_set(doc,'{input,destinationId}','"invented-destination-123"'); body:=pg_temp.c5_body(bad);
 BEGIN PERFORM public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.c5_hash(body));
  RAISE EXCEPTION 'C5 expected fake catalogue ID denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_document' THEN RAISE; END IF; END;
 INSERT INTO c5_state VALUES('trip',to_jsonb(trip::text)),('document',changed);
END $$;
SELECT set_config('request.jwt.claim.sub','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',true);
DO $$ DECLARE trip uuid:=(SELECT (value#>>'{}')::uuid FROM c5_state WHERE key='trip'); body text; BEGIN
 PERFORM pg_temp.c5_assert(public.get_editable_trip_v2(trip)->>'status'='unavailable','B cannot read A');
 PERFORM pg_temp.c5_assert(jsonb_array_length(public.list_owned_trips_v2(NULL,NULL,25)->'items')=0,'B list excludes A');
 BEGIN PERFORM public.delete_editable_trip_v2(trip,2,gen_random_uuid());
  RAISE EXCEPTION 'C5 expected foreign owner denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'trip_unavailable' THEN RAISE; END IF; END;
 SELECT pg_temp.c5_body(value,'[]') INTO body FROM c5_state WHERE key='document';
 BEGIN PERFORM public.update_editable_trip_v2(trip,2,gen_random_uuid(),body,pg_temp.c5_hash(body));
  RAISE EXCEPTION 'C5 expected foreign update denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'trip_unavailable' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
DO $$ DECLARE trip uuid:=(SELECT (value#>>'{}')::uuid FROM c5_state WHERE key='trip'); r jsonb; BEGIN
 r:=public.delete_editable_trip_v2(trip,2,gen_random_uuid());
 PERFORM pg_temp.c5_assert(r->>'status'='deleted','delete acknowledged');
 PERFORM pg_temp.c5_assert(public.get_editable_trip_v2(trip)->>'status'='unavailable','deleted trip unavailable');
END $$;
RESET ROLE;
UPDATE private_admin.account_access SET state='locked' WHERE subject_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN PERFORM public.list_owned_trips_v2(NULL,NULL,25);
  RAISE EXCEPTION 'C5 expected locked account denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'account_locked' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
UPDATE private_admin.account_access SET state='enabled' WHERE subject_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
SET LOCAL ROLE authenticated;
DO $$ DECLARE doc jsonb; body text; result jsonb; trip uuid; BEGIN
 SELECT jsonb_set(jsonb_set(raw_text::jsonb,'{input,destinationId}','"hue"'),'{input,destinationName}','"Huế"') INTO doc FROM c5_fixture;
 body:=pg_temp.c5_body(doc);
 result:=public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.c5_hash(body));
 trip:=(result#>>'{receipt,tripId}')::uuid;
 PERFORM pg_temp.c5_assert(result#>>'{head,payloadText}'=pg_temp.c5_canonical(doc),'catalogue control retains ID and name');
 PERFORM public.delete_editable_trip_v2(trip,1,gen_random_uuid());
END $$;
RESET ROLE;
-- Synthetic release rows exercise the real publication-membership helper.
-- This is not an admin publication pipeline acceptance test.
INSERT INTO private_discovery_admin.release_candidates
 (preview_id,actor_id,session_id,request_id,source_revision,candidate_version,preview_digest,payload_text,expires_at)
SELECT ('00000000-0000-4000-8000-'||lpad(v::text,12,'0'))::uuid,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),gen_random_uuid(),1,v,repeat('a',64),
 jsonb_build_object('catalogue',jsonb_build_object('destinations',jsonb_build_array(jsonb_build_object('id',CASE WHEN v=1 THEN 'c5/phu-yen' ELSE 'c5/other' END))))::text,
 now()+interval '1 hour' FROM generate_series(1,2) AS v;
INSERT INTO private_discovery_admin.releases(version,candidate_id,object_key,sha256,byte_length,source_revision)
SELECT candidate_version,preview_id,'releases/v2/'||candidate_version||'.json',repeat('a',64),1,1
 FROM private_discovery_admin.release_candidates;
INSERT INTO public.discovery_release_manifest(id,version,object_key,sha256,byte_length)
VALUES('current',1,'releases/v2/1.json',repeat('a',64),1);
SET LOCAL ROLE authenticated;
DO $$ DECLARE doc jsonb; body text; result jsonb; BEGIN
 SELECT jsonb_set(raw_text::jsonb,'{input,destinationId}','"c5/phu-yen"') INTO doc FROM c5_fixture;
 body:=pg_temp.c5_body(doc);
 result:=public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.c5_hash(body));
 INSERT INTO c5_state VALUES('dynamic-trip',result#>'{receipt,tripId}'),('dynamic-doc',doc);
END $$;
RESET ROLE;
UPDATE public.discovery_release_manifest SET version=2,object_key='releases/v2/2.json';
SET LOCAL ROLE authenticated;
DO $$ DECLARE doc jsonb; body text; trip uuid; result jsonb; BEGIN
 SELECT value INTO doc FROM c5_state WHERE key='dynamic-doc';
 SELECT (value#>>'{}')::uuid INTO trip FROM c5_state WHERE key='dynamic-trip';
 body:=pg_temp.c5_body(doc);
 BEGIN PERFORM public.create_editable_trip_v2(gen_random_uuid(),body,pg_temp.c5_hash(body));
  RAISE EXCEPTION 'C5 expected inactive publication create denial';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_document' THEN RAISE; END IF; END;
 doc:=jsonb_set(doc,'{days,0,notes}','"Giữ điểm đến đã xuất bản trước đây"');
 body:=pg_temp.c5_body(doc,jsonb_build_array(jsonb_build_object('op','setDayNotes','dayId',doc#>'{days,0,id}','notes',doc#>'{days,0,notes}')));
 result:=public.update_editable_trip_v2(trip,1,gen_random_uuid(),body,pg_temp.c5_hash(body));
 PERFORM pg_temp.c5_assert(result#>>'{head,payloadText}'=pg_temp.c5_canonical(doc),'existing historical ID can still be edited');
 PERFORM public.delete_editable_trip_v2(trip,2,gen_random_uuid());
END $$;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM public.get_editable_trip_v2('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  RAISE EXCEPTION 'C5 expected anon permission denial';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
