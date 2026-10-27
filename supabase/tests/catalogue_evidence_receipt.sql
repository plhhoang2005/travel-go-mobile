BEGIN;
CREATE FUNCTION pg_temp.a3_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'A3 receipt: %',label; END IF; END $$;
CREATE FUNCTION pg_temp.a3_hash(raw text) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT encode(extensions.digest(convert_to(raw,'UTF8'),'sha256'),'hex') $$;
CREATE FUNCTION pg_temp.a3_body(env jsonb) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT private.p32_canonical(jsonb_build_object('payloadText',private.p32_canonical(env),'contentDigest',pg_temp.a3_hash(private.p32_canonical(env)),'sourceBinding',NULL)) $$;
DO $$ BEGIN EXECUTE format('GRANT USAGE ON SCHEMA %I TO authenticated',(SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema())); END $$;
GRANT EXECUTE ON FUNCTION pg_temp.a3_assert(boolean,text),pg_temp.a3_hash(text),pg_temp.a3_body(jsonb) TO authenticated;
GRANT SELECT ON a3_fixture TO authenticated;
DO $$ DECLARE r private_ai.requests%ROWTYPE; captured jsonb;
BEGIN
 SELECT receipt INTO captured FROM a3_fixture;
 SELECT * INTO r FROM private_ai.requests WHERE subject='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
   AND request_id='a3000000-0000-4000-8000-000000000003';
 PERFORM pg_temp.a3_assert(FOUND AND r.state='succeeded' AND r.result=captured,'actual finalize result matches gateway receipt');
 PERFORM pg_temp.a3_assert(octet_length(r.result::text)<=16384,'actual jsonb cap');
 PERFORM pg_temp.a3_assert((SELECT used FROM private_ai.usage WHERE subject=r.subject AND accepted_day=r.accepted_day)=1,'one AI use despite replay');
 PERFORM pg_temp.a3_assert(captured->>'baseDigest'=(SELECT pg_temp.a3_hash(private.p32_canonical(envelope->'document')) FROM a3_fixture),'Dart base digest binds saved document');
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true);
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claims','{"role":"authenticated","is_anonymous":false}',true);
DO $$ DECLARE env jsonb; body text; result jsonb; trip uuid; bad jsonb;
BEGIN
 SELECT envelope INTO env FROM a3_fixture;body:=pg_temp.a3_body(env);
 result:=public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.a3_hash(body));trip:=(result#>>'{head,tripId}')::uuid;
 PERFORM pg_temp.a3_assert(public.get_evidence_trip_v1(trip)#>>'{head,payloadText}'=env::text OR
   public.get_evidence_trip_v1(trip)#>>'{head,payloadText}'=(result#>>'{head,payloadText}'),'authenticated source readback');
 PERFORM pg_temp.a3_assert((public.get_evidence_trip_v1(trip)#>>'{head,payloadText}')::jsonb=env,'whole registry roundtrip');
 bad:=jsonb_set(env,'{claims,0,text}','"forged claim"');body:=pg_temp.a3_body(bad);
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.a3_hash(body));RAISE EXCEPTION 'forged claim accepted';
 EXCEPTION WHEN OTHERS THEN IF sqlerrm<>'evidence_untrusted' THEN RAISE; END IF;END;
 bad:=jsonb_set(env,'{evidence,0,factValue}','"forged fact"');body:=pg_temp.a3_body(bad);
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.a3_hash(body));RAISE EXCEPTION 'forged source accepted';
 EXCEPTION WHEN OTHERS THEN IF sqlerrm<>'evidence_untrusted' THEN RAISE; END IF;END;
 PERFORM set_config('a3.saved_trip',trip::text,true);
END $$;
RESET ROLE;
UPDATE private_ai.requests SET result_expires_at=now()-interval '1 hour'
 WHERE subject='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' AND request_id='a3000000-0000-4000-8000-000000000003';
SET LOCAL ROLE authenticated;
DO $$ DECLARE env jsonb; body text;trip uuid:=current_setting('a3.saved_trip')::uuid;
BEGIN
 SELECT envelope INTO env FROM a3_fixture;
 PERFORM pg_temp.a3_assert((public.get_evidence_trip_v1(trip)#>>'{head,payloadText}')::jsonb=env,'saved source survives receipt expiry');
 body:=pg_temp.a3_body(env);
 BEGIN PERFORM public.create_evidence_trip_v1(gen_random_uuid(),body,pg_temp.a3_hash(body));RAISE EXCEPTION 'expired receipt accepted for new save';
 EXCEPTION WHEN OTHERS THEN IF sqlerrm<>'evidence_expired' THEN RAISE; END IF;END;
END $$;
RESET ROLE;
ROLLBACK;
