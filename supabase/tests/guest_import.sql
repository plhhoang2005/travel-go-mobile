-- Isolated staging only; never run against primary. All fixtures roll back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.b3_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'assertion_failed:%',label; END IF; END $f$;
CREATE FUNCTION pg_temp.b3_error(command text,expected text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE observed boolean:=false;
BEGIN
 BEGIN EXECUTE command;
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>expected AND SQLSTATE<>expected THEN RAISE; END IF;
  observed:=true;
 END;
 IF NOT observed THEN RAISE EXCEPTION 'expected_error_not_observed'; END IF;
END $f$;
SELECT gen_random_uuid() AS b3_a,gen_random_uuid() AS b3_b \gset
GRANT EXECUTE ON FUNCTION pg_temp.b3_assert(boolean,text),pg_temp.b3_error(text,text) TO authenticated,anon;
INSERT INTO auth.users(id,aud,role,email,raw_user_meta_data,created_at,updated_at)
VALUES (:'b3_a','authenticated','authenticated',:'b3_a'||'@b3.invalid','{}',now(),now()),
       (:'b3_b','authenticated','authenticated',:'b3_b'||'@b3.invalid','{}',now(),now());
CREATE TEMP TABLE b3_vectors(name text PRIMARY KEY,payload text NOT NULL,digest text NOT NULL);
INSERT INTO b3_vectors VALUES
('input',$v${"metadata":{"destinationId":null,"destinationName":"Ha Noi","endDate":null,"startDate":null,"timezone":null,"title":"HN"},"plan":null,"request":{"budgetVnd":2000000,"numDays":2,"numPeople":1,"origin":"SG","preferences":["food"],"priority":"balanced"},"schemaVersion":1}$v$,'1a492d03942746d47ab927820b52ca8713b0a7f06d095616768915181fedb45e'),
('unicode',$v${"metadata":{"destinationId":"phu-quoc","destinationName":"Phú Quốc","endDate":"2026-11-05","startDate":"2026-11-02","timezone":"Asia/Ho_Chi_Minh","title":"Chuyến đi \"Phú Quốc\"\nnghỉ dưỡng"},"plan":null,"request":{"budgetVnd":4000000,"numDays":3,"numPeople":2,"origin":"TP. Hồ Chí Minh","preferences":["biển","ẩm thực"],"priority":"balanced"},"schemaVersion":1}$v$,'bb4c57ff86e93638f9c79e1877e1db3fd79a0afba3ef73de36225c677bc56d98'),
('full',$v${"metadata":{"destinationId":"hn-1","destinationName":"Hà Nội","endDate":"2026-12-12","startDate":"2026-12-10","timezone":"Asia/Bangkok","title":"Chuyến đi Hà Nội"},"plan":{"aiExplanation":"Lộ trình tối ưu","assumptions":["Thời tiết khô ráo"],"budgetBreakdown":{"accommodation":600000,"attractions":100000,"food":300000,"remainingSafetyMargin":500000,"transport":1500000},"dataSources":{"osm":"v1"},"itineraryDays":[{"activities":[{"costVnd":0,"durationHours":2.0,"time":"08:30","title":"Dạo Hồ Gươm"}],"day":1,"title":"Phố cổ và Hồ Gươm"}],"topDestinations":[{"avgPrecipitation":0.0,"avgTempMax":22.5,"estimatedCostVnd":2500000,"id":"hn-1","latitude":21.0285,"longitude":105.8542,"name":"Hà Nội","normalizedScores":{"p-value":1e-7,"weather":0.85},"region":"Bắc Bộ","scoreContributions":{"😀":0.55,"":0.35},"totalScore":92.5,"weatherSource":"OpenWeather"}],"transportOptions":[{"comfortScore":9,"displayName":"Máy bay","durationHours":1.25,"mode":"flight","paretoOptimal":true,"priceTotalVnd":1500000,"recommendationReason":"Tiết kiệm thời gian","tradeoffType":"fastest"}],"winnerId":"hn-1"},"request":{"budgetVnd":3000000,"numDays":2,"numPeople":1,"origin":"Đà Nẵng","preferences":["di tích","ẩm thực"],"priority":"balanced"},"schemaVersion":1}$v$,'57298dc9ac9c1e5fe1bcb299c0fb942fc60b90b073da20a082a419b9d74d46d3');
CREATE TEMP TABLE b3_replies(name text PRIMARY KEY,reply jsonb NOT NULL);
GRANT SELECT ON b3_vectors TO authenticated,anon;
GRANT SELECT,INSERT ON b3_replies TO authenticated;
DO $f$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated,anon',
 (SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $f$;
\if :{?b3_helpers_only}
-- Including suite owns rollback.
\else
SELECT pg_temp.b3_assert(encode(extensions.digest(convert_to(payload,'UTF8'),'sha256'),'hex')=digest,'literal hash:'||name) FROM b3_vectors;
SELECT pg_temp.b3_assert(private.validate_guest_payload_v1(payload)=payload::jsonb,'shape:'||name) FROM b3_vectors;
SELECT pg_temp.b3_assert(NOT has_table_privilege(role,'private.guest_import_receipts',privilege),'ledger denied')
FROM unnest(ARRAY['anon','authenticated']) role CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE']) privilege;
SELECT pg_temp.b3_assert(NOT has_function_privilege(role,p.oid,'EXECUTE'),'helper denied')
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN unnest(ARRAY['anon','authenticated']) role
WHERE n.nspname='private' AND (p.proname LIKE 'guest_b3_%' OR p.proname='validate_guest_payload_v1');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'b3_a','role','authenticated')::text,true),
 set_config('request.jwt.claim.sub',:'b3_a',true),set_config('request.jwt.claim.role','authenticated',true);
INSERT INTO b3_replies SELECT name,public.import_guest_draft_v1('b3-tests',name,1,name,payload,digest) FROM b3_vectors;
SELECT pg_temp.b3_assert(count(*)=3,'three imports') FROM b3_replies;
SELECT pg_temp.b3_assert(reply->>'status'='committed' AND reply->>'payloadText'=payload,'exact bytes:'||name) FROM b3_replies JOIN b3_vectors USING(name);
SELECT pg_temp.b3_assert((SELECT count(*) FROM jsonb_object_keys(reply->'receipt'))=10
 AND reply#>>'{receipt,targetOwner}'=:'b3_a' AND reply#>>'{receipt,remoteVersion}'='1'
 AND reply#>>'{receipt,committedAt}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$','receipt:'||name) FROM b3_replies;
SELECT pg_temp.b3_assert(public.import_guest_draft_v1('b3-tests',name,1,name,payload,digest)=reply,'retry:'||name) FROM b3_replies JOIN b3_vectors USING(name);
SELECT pg_temp.b3_assert(public.get_import_trip_snapshot_v1((reply#>>'{receipt,tripId}')::uuid)=reply,'read:'||name) FROM b3_replies;
RESET ROLE;
-- Admin-only synthetic corruption of an owned test receipt, rolled back on failure.
UPDATE private.guest_import_receipts SET content_digest=repeat('0',64) WHERE owner_id=:'b3_a' AND draft_id='full';
SET LOCAL ROLE authenticated;
SELECT pg_temp.b3_error(format('SELECT public.get_import_trip_snapshot_v1(%L)',reply#>>'{receipt,tripId}'),'stored_content_invalid') FROM b3_replies WHERE name='full';
RESET ROLE;
UPDATE private.guest_import_receipts SET content_digest=(SELECT digest FROM b3_vectors WHERE name='full') WHERE owner_id=:'b3_a' AND draft_id='full';
SET LOCAL ROLE authenticated;
SELECT pg_temp.b3_assert(t.num_days=(v.payload::jsonb#>>'{request,numDays}')::int
 AND t.budget_total=(v.payload::jsonb#>>'{request,budgetVnd}')::numeric
 AND t.start_date IS NULL AND t.end_date IS NULL AND t.canonical_payload_text=v.payload,'projection:'||v.name)
FROM public.trips t JOIN b3_replies r ON t.id=(r.reply#>>'{receipt,tripId}')::uuid JOIN b3_vectors v USING(name);
-- Legacy rows retain ordinary CRUD and are never presented as imported version 1.
INSERT INTO public.trips(user_id,title,destination_name) VALUES(:'b3_a','legacy','legacy') RETURNING id AS b3_legacy \gset
UPDATE public.trips SET title='legacy edited' WHERE id=:'b3_legacy';
SELECT pg_temp.b3_assert(public.get_import_trip_snapshot_v1(:'b3_legacy')=jsonb_build_object('status','unavailable','receipt',NULL,'payloadText',NULL),'legacy unavailable');
DELETE FROM public.trips WHERE id=:'b3_legacy';
SELECT pg_temp.b3_error(format('UPDATE public.trips SET title=%L WHERE id=%L','changed',reply#>>'{receipt,tripId}'),'imported_trip_immutable') FROM b3_replies WHERE name='full';
SELECT pg_temp.b3_error(format('UPDATE public.trips SET user_id=%L WHERE id=%L',:'b3_b',reply#>>'{receipt,tripId}'),'imported_trip_immutable') FROM b3_replies WHERE name='full';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','b3-tests','full','other-key',payload,digest),'identity_conflict') FROM b3_vectors WHERE name='full';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','other-scope','full','full',payload,digest),'identity_conflict') FROM b3_vectors WHERE name='full';
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','b3-tests','full','full',payload,digest),'payload_conflict') FROM b3_vectors WHERE name='input';
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'b3_b','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'b3_b',true);
SELECT pg_temp.b3_assert(public.get_import_trip_snapshot_v1((reply#>>'{receipt,tripId}')::uuid)
 =jsonb_build_object('status','unavailable','receipt',NULL,'payloadText',NULL),'other owner') FROM b3_replies;
SELECT pg_temp.b3_assert(count(*)=0,'RLS hides account A') FROM public.trips WHERE user_id=:'b3_a';
DELETE FROM public.trips WHERE user_id=:'b3_a';
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',:'b3_a','role','authenticated')::text,true),set_config('request.jwt.claim.sub',:'b3_a',true);
SELECT pg_temp.b3_assert(count(*)=3,'other account delete had no effect') FROM public.trips WHERE user_id=:'b3_a';
RESET ROLE;
CREATE TEMP TABLE b3_activity_ids AS
 SELECT gen_random_uuid() AS id,(reply#>>'{receipt,tripId}')::uuid AS trip_id FROM b3_replies;
INSERT INTO public.trip_activities(id,trip_id,day_number,start_time,title)
 SELECT id,trip_id,1,'08:00','B3 owned cascade fixture' FROM b3_activity_ids;
CREATE TEMP TABLE b3_unrelated_trip AS
 WITH inserted AS (INSERT INTO public.trips(user_id,title,destination_name)
 VALUES(:'b3_b','B3 unrelated','B3 unrelated') RETURNING id) SELECT id FROM inserted;
INSERT INTO public.trip_activities(trip_id,day_number,start_time,title)
 SELECT id,1,'09:00','B3 unrelated child' FROM b3_unrelated_trip;
SET LOCAL ROLE authenticated;
DELETE FROM public.trips WHERE id=(SELECT (reply#>>'{receipt,tripId}')::uuid FROM b3_replies WHERE name='full');
RESET ROLE;
SELECT pg_temp.b3_assert(count(*)=0,'trip cascade removes owned child') FROM public.trip_activities
 WHERE trip_id=(SELECT (reply#>>'{receipt,tripId}')::uuid FROM b3_replies WHERE name='full');
SELECT pg_temp.b3_assert(count(*)=1,'trip deletion preserves unrelated child') FROM public.trip_activities
 WHERE trip_id IN (SELECT id FROM b3_unrelated_trip);
SET LOCAL ROLE authenticated;
SELECT pg_temp.b3_assert(public.import_guest_draft_v1('b3-tests','full',1,'full',payload,digest)
 =jsonb_build_object('status','deleted','receipt',reply->'receipt','payloadText',NULL),'no resurrection')
FROM b3_vectors JOIN b3_replies USING(name) WHERE name='full';
RESET ROLE;
CREATE FUNCTION pg_temp.b3_fault() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN IF NEW.request_key='fault-after-trip' THEN RAISE EXCEPTION 'synthetic_receipt_fault'; END IF; RETURN NEW; END $f$;
CREATE TRIGGER b3_test_fault BEFORE INSERT ON private.guest_import_receipts FOR EACH ROW EXECUTE FUNCTION pg_temp.b3_fault();
SET LOCAL ROLE authenticated;
SELECT pg_temp.b3_error(format('SELECT public.import_guest_draft_v1(%L,%L,1,%L,%L,%L)','b3-tests','fault','fault-after-trip',payload,digest),'synthetic_receipt_fault') FROM b3_vectors WHERE name='input';
RESET ROLE;
SELECT pg_temp.b3_assert(count(*)=3,'no partial receipt') FROM private.guest_import_receipts WHERE owner_id=:'b3_a';
SELECT pg_temp.b3_assert(count(*)=2,'no orphan trip') FROM public.trips WHERE user_id=:'b3_a';
DROP TRIGGER b3_test_fault ON private.guest_import_receipts;
INSERT INTO b3_vectors SELECT 'plan-only',(payload::jsonb||'{"request":null}'::jsonb)::text,
 encode(extensions.digest(convert_to((payload::jsonb||'{"request":null}'::jsonb)::text,'UTF8'),'sha256'),'hex') FROM b3_vectors WHERE name='full';
SET LOCAL ROLE authenticated;
INSERT INTO b3_replies SELECT name,public.import_guest_draft_v1('b3-tests',name,1,name,payload,digest) FROM b3_vectors WHERE name='plan-only';
SELECT pg_temp.b3_assert(num_days IS NULL AND budget_total IS NULL AND start_date IS NULL AND end_date IS NULL,'plan-only unknowns')
FROM public.trips WHERE id=(SELECT (reply#>>'{receipt,tripId}')::uuid FROM b3_replies WHERE name='plan-only');
RESET ROLE;
DELETE FROM auth.users WHERE id=:'b3_a';
SELECT pg_temp.b3_assert(count(*)=0,'account cascade trips') FROM public.trips WHERE user_id=:'b3_a';
SELECT pg_temp.b3_assert(count(*)=0,'account cascade receipts') FROM private.guest_import_receipts WHERE owner_id=:'b3_a';
SELECT pg_temp.b3_assert(count(*)=0,'account cascade removes remaining owned children') FROM public.trip_activities
 WHERE id IN (SELECT id FROM b3_activity_ids);
SELECT pg_temp.b3_assert(count(*)=1,'account deletion preserves unrelated trip') FROM public.trips
 WHERE id IN (SELECT id FROM b3_unrelated_trip);
SELECT pg_temp.b3_assert(count(*)=1,'account deletion preserves unrelated child') FROM public.trip_activities
 WHERE trip_id IN (SELECT id FROM b3_unrelated_trip);
SELECT 'B3 positive suite PASS (rolled back)' AS result;
ROLLBACK;
\endif
