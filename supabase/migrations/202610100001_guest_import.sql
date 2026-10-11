-- B3 v1. Additive migration; source approval does NOT authorize execution.
-- No backfill, algorithm recomputation, application rows or receipt payload copies.
BEGIN;

DO $preflight$
DECLARE c record; r text; p text;
BEGIN
  IF to_regclass('public.trips') IS NULL OR to_regclass('public.trip_activities') IS NULL
     OR to_regprocedure('auth.uid()') IS NULL OR to_regprocedure('auth.role()') IS NULL
     OR to_regprocedure('extensions.digest(bytea,text)') IS NULL THEN
    RAISE EXCEPTION 'guest_import_precondition';
  END IF;
  FOR c IN SELECT * FROM (VALUES
    ('id','uuid','NO'),('user_id','uuid','NO'),('title','text','NO'),
    ('destination_name','text','NO'),('num_days','integer','YES'),
    ('budget_total','numeric','YES'),('start_date','timestamp with time zone','YES'),
    ('end_date','timestamp with time zone','YES'),('status','text','YES'),
    ('ai_plan_data','jsonb','YES'),('created_at','timestamp with time zone','NO')
  ) AS expected(name,kind,nullable) LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='trips' AND column_name=c.name
        AND data_type=c.kind AND is_nullable=c.nullable) THEN
      RAISE EXCEPTION 'guest_import_schema_mismatch';
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM information_schema.columns
      WHERE table_schema='public' AND table_name='trips') <> 11
    OR to_regclass('private.guest_import_receipts') IS NOT NULL
    OR EXISTS (SELECT 1 FROM pg_proc f JOIN pg_namespace n ON n.oid=f.pronamespace
      WHERE (n.nspname='private' AND (f.proname LIKE 'guest_b3_%' OR f.proname='validate_guest_payload_v1'))
         OR (n.nspname='public' AND f.proname IN ('import_guest_draft_v1','get_import_trip_snapshot_v1')))
    OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.trips'::regclass AND NOT tgisinternal)
    THEN RAISE EXCEPTION 'guest_import_name_or_trigger_collision'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
    WHERE conrelid='public.trips'::regclass AND confrelid='auth.users'::regclass
      AND contype='f' AND confdeltype='c' AND convalidated
      AND conkey=ARRAY[(SELECT attnum FROM pg_attribute
        WHERE attrelid='public.trips'::regclass AND attname='user_id')]::smallint[])
    OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.trips'::regclass)
    OR NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.trip_activities'::regclass)
    THEN RAISE EXCEPTION 'guest_import_owner_precondition'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
    WHERE conrelid='public.trip_activities'::regclass AND confrelid='public.trips'::regclass
      AND contype='f' AND confdeltype='c' AND convalidated
      AND conkey=ARRAY[(SELECT attnum FROM pg_attribute
        WHERE attrelid='public.trip_activities'::regclass AND attname='trip_id')]::smallint[])
    OR current_user IS DISTINCT FROM (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='public.trips'::regclass)
    THEN RAISE EXCEPTION 'guest_import_migration_authority'; END IF;
  -- Effective privileges include PUBLIC/inherited grants, not just explicit ACL rows.
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
    FOREACH p IN ARRAY ARRAY['TRUNCATE','TRIGGER','REFERENCES'] LOOP
      IF has_table_privilege(r,'public.trips',p)
         OR has_table_privilege(r,'public.trip_activities',p) THEN
        RAISE EXCEPTION 'guest_import_privilege_drift';
      END IF;
    END LOOP;
  END LOOP;
  FOREACH p IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE'] LOOP
    IF has_table_privilege('anon','public.trips',p)
       OR NOT has_table_privilege('authenticated','public.trips',p) THEN
      RAISE EXCEPTION 'guest_import_access_drift';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_namespace
    WHERE nspname='private' AND (has_schema_privilege('anon',oid,'CREATE')
      OR has_schema_privilege('authenticated',oid,'CREATE'))) THEN
    RAISE EXCEPTION 'guest_import_private_schema_drift';
  END IF;
END $preflight$;

CREATE SCHEMA IF NOT EXISTS private;
ALTER TABLE public.trips ADD COLUMN canonical_payload_text text;
CREATE TABLE private.guest_import_receipts (
  receipt_id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_scope text NOT NULL CHECK (char_length(device_scope) BETWEEN 1 AND 128 AND btrim(device_scope)<>''),
  draft_id text NOT NULL CHECK (char_length(draft_id) BETWEEN 1 AND 128 AND btrim(draft_id)<>''),
  source_revision bigint NOT NULL CHECK (source_revision BETWEEN 1 AND 9007199254740991),
  request_key text NOT NULL CHECK (char_length(request_key) BETWEEN 1 AND 256 AND btrim(request_key)<>''),
  content_digest text NOT NULL CHECK (length(content_digest)=64 AND content_digest !~ '[^0-9a-f]'),
  trip_id uuid NOT NULL UNIQUE,
  remote_version bigint NOT NULL DEFAULT 1 CHECK (remote_version=1),
  committed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  UNIQUE(owner_id,device_scope,draft_id,source_revision),
  UNIQUE(owner_id,request_key)
);
ALTER TABLE private.guest_import_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.guest_import_receipts FROM PUBLIC,anon,authenticated;

-- Scan original json (not jsonb) so duplicate keys and integer token types survive.
-- Separate recursive traversal keeps counts independent from depth fencing.
CREATE FUNCTION private.guest_b3_walk(p_value json,p_depth integer DEFAULT 1)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE kind text; child record; total integer; distinct_keys integer; ignored jsonb;
BEGIN
  IF p_depth>32 THEN RAISE EXCEPTION 'invalid_input'; END IF;
  kind:=json_typeof(p_value);
  IF kind='object' THEN
    SELECT count(*),count(DISTINCT key) INTO total,distinct_keys FROM json_each(p_value);
    IF total>256 OR total<>distinct_keys THEN RAISE EXCEPTION 'invalid_input'; END IF;
    FOR child IN SELECT * FROM json_each(p_value) LOOP
      ignored:=to_json(child.key)::jsonb; -- Decode/validate Unicode keys.
      PERFORM private.guest_b3_walk(child.value,p_depth+1);
    END LOOP;
  ELSIF kind='array' THEN
    IF json_array_length(p_value)>1000 THEN RAISE EXCEPTION 'invalid_input'; END IF;
    FOR child IN SELECT value FROM json_array_elements(p_value) LOOP
      PERFORM private.guest_b3_walk(child.value,p_depth+1);
    END LOOP;
  ELSE
    ignored:=p_value::jsonb; -- Reject NUL/unpaired surrogate escapes on string leaves.
  END IF;
END $fn$;

CREATE FUNCTION private.guest_b3_keys(p_value json,p_required text[],p_optional text[] DEFAULT ARRAY[]::text[])
RETURNS void LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE k text;
BEGIN
  IF json_typeof(p_value) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'invalid_input'; END IF;
  FOREACH k IN ARRAY p_required LOOP
    IF NOT EXISTS (SELECT 1 FROM json_each(p_value) WHERE key=k) THEN RAISE EXCEPTION 'invalid_input'; END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM json_each(p_value) WHERE NOT key=ANY(p_required||p_optional)) THEN
    RAISE EXCEPTION 'invalid_input';
  END IF;
END $fn$;

CREATE FUNCTION private.guest_b3_value(p_value json,p_kind text,p_min bigint DEFAULT 0,p_max bigint DEFAULT 9007199254740991)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE v text; f double precision;
BEGIN
  IF p_kind='integer' THEN
    IF json_typeof(p_value) IS DISTINCT FROM 'number' OR p_value::text !~ '^-?(0|[1-9][0-9]*)$' THEN
      RAISE EXCEPTION 'invalid_input';
    END IF;
    IF (p_value::text)::numeric NOT BETWEEN p_min AND p_max THEN RAISE EXCEPTION 'invalid_input'; END IF;
  ELSIF p_kind='number' THEN
    IF json_typeof(p_value) IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'invalid_input'; END IF;
    f:=(p_value::text)::double precision;
    IF f IN ('Infinity'::float8,'-Infinity'::float8,'NaN'::float8) THEN RAISE EXCEPTION 'invalid_input'; END IF;
  ELSIF p_kind='nonblank' THEN
    IF json_typeof(p_value) IS DISTINCT FROM 'string' THEN RAISE EXCEPTION 'invalid_input'; END IF;
    v:=p_value#>>'{}';
    IF v !~ '[^[:space:]]' THEN RAISE EXCEPTION 'invalid_input'; END IF;
  ELSIF json_typeof(p_value) IS DISTINCT FROM p_kind THEN
    RAISE EXCEPTION 'invalid_input';
  END IF;
END $fn$;

CREATE FUNCTION private.validate_guest_payload_v1(p_text text)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE root json; m json; req json; plan json; item json; sub json; val json;
  k text; date_text text; date_value date; first_date date; last_date date;
BEGIN
  IF p_text IS NULL OR octet_length(convert_to(p_text,'UTF8'))>1048576 THEN RAISE EXCEPTION 'invalid_input'; END IF;
  root:=p_text::json;
  PERFORM private.guest_b3_walk(root);
  PERFORM private.guest_b3_keys(root,ARRAY['schemaVersion','metadata','request','plan']);
  PERFORM private.guest_b3_value(root->'schemaVersion','integer',1);
  IF (root->>'schemaVersion')::bigint<>1 THEN RAISE EXCEPTION 'unsupported_schema'; END IF;
  m:=root->'metadata'; req:=root->'request'; plan:=root->'plan';
  PERFORM private.guest_b3_keys(m,ARRAY['title','destinationId','destinationName','startDate','endDate','timezone']);
  FOREACH k IN ARRAY ARRAY['title','destinationId','destinationName','timezone'] LOOP
    IF json_typeof(m->k)<>'null' THEN PERFORM private.guest_b3_value(m->k,'nonblank'); END IF;
  END LOOP;
  FOREACH k IN ARRAY ARRAY['startDate','endDate'] LOOP
    IF json_typeof(m->k)<>'null' THEN
      PERFORM private.guest_b3_value(m->k,'string'); date_text:=m->>k;
      IF date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' OR substring(date_text,1,4)='0000' THEN
        RAISE EXCEPTION 'invalid_input';
      END IF;
      date_value:=date_text::date;
      IF to_char(date_value,'YYYY-MM-DD')<>date_text THEN RAISE EXCEPTION 'invalid_input'; END IF;
      IF k='startDate' THEN first_date:=date_value; ELSE last_date:=date_value; END IF;
    END IF;
  END LOOP;
  IF last_date<first_date THEN RAISE EXCEPTION 'invalid_input'; END IF;
  IF json_typeof(req)='null' AND json_typeof(plan)='null' THEN RAISE EXCEPTION 'invalid_input'; END IF;
  IF json_typeof(req)<>'null' THEN
    PERFORM private.guest_b3_keys(req,ARRAY['origin','numDays','numPeople','budgetVnd','preferences','priority']);
    PERFORM private.guest_b3_value(req->'origin','nonblank');
    PERFORM private.guest_b3_value(req->'numDays','integer',1,2147483647);
    PERFORM private.guest_b3_value(req->'numPeople','integer',1,2147483647);
    PERFORM private.guest_b3_value(req->'budgetVnd','integer');
    PERFORM private.guest_b3_value(req->'priority','string');
    PERFORM private.guest_b3_value(req->'preferences','array');
    FOR val IN SELECT value FROM json_array_elements(req->'preferences') LOOP
      PERFORM private.guest_b3_value(val,'string');
    END LOOP;
  END IF;
  IF json_typeof(plan)<>'null' THEN
    PERFORM private.guest_b3_keys(plan,ARRAY['winnerId','topDestinations','transportOptions','itineraryDays','budgetBreakdown','aiExplanation','dataSources','assumptions'],ARRAY['isFallback']);
    PERFORM private.guest_b3_value(plan->'winnerId','string');
    PERFORM private.guest_b3_value(plan->'aiExplanation','string');
    IF plan->'isFallback' IS NOT NULL AND json_typeof(plan->'isFallback')<>'null' THEN
      PERFORM private.guest_b3_value(plan->'isFallback','boolean');
    END IF;
    PERFORM private.guest_b3_value(plan->'dataSources','object');
    FOR val IN SELECT value FROM json_each(plan->'dataSources') LOOP PERFORM private.guest_b3_value(val,'string'); END LOOP;
    PERFORM private.guest_b3_value(plan->'assumptions','array');
    FOR val IN SELECT value FROM json_array_elements(plan->'assumptions') LOOP PERFORM private.guest_b3_value(val,'string'); END LOOP;
    IF json_typeof(plan->'budgetBreakdown')<>'null' THEN
      sub:=plan->'budgetBreakdown';
      PERFORM private.guest_b3_keys(sub,ARRAY['transport','accommodation','food','attractions','remainingSafetyMargin']);
      FOR val IN SELECT value FROM json_each(sub) LOOP PERFORM private.guest_b3_value(val,'integer'); END LOOP;
    END IF;
    PERFORM private.guest_b3_value(plan->'topDestinations','array');
    FOR item IN SELECT value FROM json_array_elements(plan->'topDestinations') LOOP
      PERFORM private.guest_b3_keys(item,ARRAY['id','name','totalScore','normalizedScores','scoreContributions','estimatedCostVnd','weatherSource','avgTempMax','avgPrecipitation','latitude','longitude','region']);
      FOREACH k IN ARRAY ARRAY['id','name','weatherSource','region'] LOOP PERFORM private.guest_b3_value(item->k,'string'); END LOOP;
      FOREACH k IN ARRAY ARRAY['totalScore','avgTempMax','avgPrecipitation'] LOOP PERFORM private.guest_b3_value(item->k,'number'); END LOOP;
      FOREACH k IN ARRAY ARRAY['latitude','longitude'] LOOP
        IF json_typeof(item->k)<>'null' THEN PERFORM private.guest_b3_value(item->k,'number'); END IF;
      END LOOP;
      PERFORM private.guest_b3_value(item->'estimatedCostVnd','integer');
      FOREACH k IN ARRAY ARRAY['normalizedScores','scoreContributions'] LOOP
        PERFORM private.guest_b3_value(item->k,'object');
        FOR val IN SELECT value FROM json_each(item->k) LOOP PERFORM private.guest_b3_value(val,'number'); END LOOP;
      END LOOP;
    END LOOP;
    PERFORM private.guest_b3_value(plan->'transportOptions','array');
    FOR item IN SELECT value FROM json_array_elements(plan->'transportOptions') LOOP
      PERFORM private.guest_b3_keys(item,ARRAY['mode','displayName','priceTotalVnd','durationHours','comfortScore','tradeoffType','recommendationReason'],ARRAY['paretoOptimal','isParetoOptimal']);
      IF item->'paretoOptimal' IS NULL AND item->'isParetoOptimal' IS NULL THEN RAISE EXCEPTION 'invalid_input'; END IF;
      FOREACH k IN ARRAY ARRAY['paretoOptimal','isParetoOptimal'] LOOP
        IF item->k IS NOT NULL THEN PERFORM private.guest_b3_value(item->k,'boolean'); END IF;
      END LOOP;
      FOREACH k IN ARRAY ARRAY['mode','displayName','tradeoffType','recommendationReason'] LOOP PERFORM private.guest_b3_value(item->k,'string'); END LOOP;
      PERFORM private.guest_b3_value(item->'priceTotalVnd','integer');
      PERFORM private.guest_b3_value(item->'durationHours','number'); PERFORM private.guest_b3_value(item->'comfortScore','number');
    END LOOP;
    PERFORM private.guest_b3_value(plan->'itineraryDays','array');
    FOR item IN SELECT value FROM json_array_elements(plan->'itineraryDays') LOOP
      PERFORM private.guest_b3_keys(item,ARRAY['day','title','activities']);
      PERFORM private.guest_b3_value(item->'day','integer',1); PERFORM private.guest_b3_value(item->'title','string');
      PERFORM private.guest_b3_value(item->'activities','array');
      FOR sub IN SELECT value FROM json_array_elements(item->'activities') LOOP
        PERFORM private.guest_b3_keys(sub,ARRAY['time','title','costVnd','durationHours']);
        PERFORM private.guest_b3_value(sub->'time','string'); PERFORM private.guest_b3_value(sub->'title','string');
        PERFORM private.guest_b3_value(sub->'costVnd','integer'); PERFORM private.guest_b3_value(sub->'durationHours','number');
      END LOOP;
    END LOOP;
  END IF;
  RETURN root::jsonb;
EXCEPTION WHEN OTHERS THEN
  IF SQLSTATE='P0001' AND SQLERRM IN ('invalid_input','unsupported_schema') THEN RAISE; END IF;
  RAISE EXCEPTION 'invalid_input'; -- Never return input/parser details to API clients.
END $fn$;

CREATE FUNCTION private.guest_b3_projection(p jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
  SELECT jsonb_build_object(
    'title',coalesce(p#>>'{metadata,title}',
      CASE WHEN jsonb_array_length(coalesce(nullif(p->'plan','null'::jsonb)->'topDestinations','[]'::jsonb))>0
        THEN 'Chuyến đi '||(p#>>'{plan,topDestinations,0,name}')
        WHEN jsonb_array_length(coalesce(nullif(p->'request','null'::jsonb)->'preferences','[]'::jsonb))>0
        THEN 'Chuyến đi '||(p#>>'{request,preferences,0}') ELSE 'Chuyến đi' END),
    'destination',coalesce(p#>>'{metadata,destinationName}',p#>>'{plan,topDestinations,0,name}','Điểm đến'),
    'days',p#>'{request,numDays}','budget',p#>'{request,budgetVnd}');
$fn$;

CREATE FUNCTION private.guest_b3_reply(p_receipt uuid,p_owner uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r private.guest_import_receipts%ROWTYPE; t public.trips%ROWTYPE;
  receipt jsonb; content jsonb; projection jsonb; live boolean;
BEGIN
  SELECT * INTO r FROM private.guest_import_receipts WHERE receipt_id=p_receipt AND owner_id=p_owner;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','unavailable','receipt',NULL,'payloadText',NULL); END IF;
  SELECT * INTO t FROM public.trips WHERE id=r.trip_id AND user_id=p_owner FOR SHARE;
  live:=FOUND;
  -- Re-read after trip lock; delete takes trip then ledger, never the reverse.
  SELECT * INTO r FROM private.guest_import_receipts WHERE receipt_id=p_receipt AND owner_id=p_owner;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','unavailable','receipt',NULL,'payloadText',NULL); END IF;
  receipt:=jsonb_build_object('deviceScope',r.device_scope,'targetOwner',r.owner_id,
    'draftId',r.draft_id,'sourceRevision',r.source_revision,'requestKey',r.request_key,
    'contentDigest',r.content_digest,'receiptId',r.receipt_id,'tripId',r.trip_id,
    'remoteVersion',r.remote_version,'committedAt',to_char(r.committed_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
  IF NOT live OR r.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('status','deleted','receipt',receipt,'payloadText',NULL);
  END IF;
  BEGIN
    content:=private.validate_guest_payload_v1(t.canonical_payload_text);
    projection:=private.guest_b3_projection(content);
    IF content IS DISTINCT FROM t.ai_plan_data
      OR encode(extensions.digest(convert_to(t.canonical_payload_text,'UTF8'),'sha256'),'hex') IS DISTINCT FROM r.content_digest
      OR t.title IS DISTINCT FROM projection->>'title'
      OR t.destination_name IS DISTINCT FROM projection->>'destination'
      OR t.num_days IS DISTINCT FROM (projection->>'days')::integer
      OR t.budget_total IS DISTINCT FROM (projection->>'budget')::numeric
      OR t.start_date IS NOT NULL OR t.end_date IS NOT NULL OR t.status IS DISTINCT FROM 'planning'
      THEN RAISE EXCEPTION 'stored_content_invalid'; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'stored_content_invalid'; END;
  RETURN jsonb_build_object('status','committed','receipt',receipt,'payloadText',t.canonical_payload_text);
END $fn$;

CREATE FUNCTION public.import_guest_draft_v1(p_device_scope text,p_draft_id text,p_source_revision bigint,
  p_request_key text,p_payload_text text,p_content_digest text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_owner uuid:=auth.uid(); r private.guest_import_receipts%ROWTYPE;
  by_key private.guest_import_receipts%ROWTYPE; content jsonb; projection jsonb; trip uuid;
BEGIN
  IF v_owner IS NULL OR auth.role() IS DISTINCT FROM 'authenticated' THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF p_device_scope IS NULL OR p_device_scope !~ '[^[:space:]]' OR char_length(p_device_scope)>128
    OR p_draft_id IS NULL OR p_draft_id !~ '[^[:space:]]' OR char_length(p_draft_id)>128
    OR p_request_key IS NULL OR p_request_key !~ '[^[:space:]]' OR char_length(p_request_key)>256
    OR p_source_revision IS NULL OR p_source_revision NOT BETWEEN 1 AND 9007199254740991
    OR p_content_digest IS NULL OR length(p_content_digest)<>64 OR p_content_digest ~ '[^0-9a-f]'
    THEN RAISE EXCEPTION 'invalid_input'; END IF;
  content:=private.validate_guest_payload_v1(p_payload_text);
  IF encode(extensions.digest(convert_to(p_payload_text,'UTF8'),'sha256'),'hex')<>p_content_digest THEN
    RAISE EXCEPTION 'digest_mismatch';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_owner::text,73103));
  SELECT * INTO r FROM private.guest_import_receipts g WHERE g.owner_id=v_owner
    AND device_scope=p_device_scope AND draft_id=p_draft_id AND source_revision=p_source_revision;
  SELECT * INTO by_key FROM private.guest_import_receipts g WHERE g.owner_id=v_owner AND request_key=p_request_key;
  IF r.receipt_id IS NOT NULL THEN
    IF r.request_key<>p_request_key OR by_key.receipt_id IS DISTINCT FROM r.receipt_id THEN
      RAISE EXCEPTION 'identity_conflict';
    END IF;
    IF r.content_digest<>p_content_digest THEN RAISE EXCEPTION 'payload_conflict'; END IF;
    RETURN private.guest_b3_reply(r.receipt_id,v_owner);
  ELSIF by_key.receipt_id IS NOT NULL THEN RAISE EXCEPTION 'identity_conflict'; END IF;
  projection:=private.guest_b3_projection(content);
  INSERT INTO public.trips(user_id,title,destination_name,num_days,budget_total,start_date,end_date,status,ai_plan_data,canonical_payload_text,created_at)
  VALUES(v_owner,projection->>'title',projection->>'destination',(projection->>'days')::integer,
    (projection->>'budget')::numeric,NULL,NULL,'planning',content,p_payload_text,clock_timestamp()) RETURNING id INTO trip;
  INSERT INTO private.guest_import_receipts(owner_id,device_scope,draft_id,source_revision,request_key,content_digest,trip_id)
  VALUES(v_owner,p_device_scope,p_draft_id,p_source_revision,p_request_key,p_content_digest,trip) RETURNING * INTO r;
  RETURN private.guest_b3_reply(r.receipt_id,v_owner);
END $fn$;

CREATE FUNCTION public.get_import_trip_snapshot_v1(p_trip_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_owner uuid:=auth.uid(); receipt uuid;
BEGIN
  IF v_owner IS NULL OR auth.role() IS DISTINCT FROM 'authenticated' THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  SELECT receipt_id INTO receipt FROM private.guest_import_receipts g WHERE g.trip_id=p_trip_id AND g.owner_id=v_owner;
  RETURN private.guest_b3_reply(receipt,v_owner);
END $fn$;

CREATE FUNCTION private.guest_b3_trip_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
  IF TG_OP='UPDATE' THEN
    IF NEW IS DISTINCT FROM OLD AND EXISTS (SELECT 1 FROM private.guest_import_receipts WHERE trip_id=OLD.id) THEN
      RAISE EXCEPTION 'imported_trip_immutable';
    END IF;
    RETURN NEW;
  END IF;
  -- During auth.users ON DELETE CASCADE the parent is already absent. Updating
  -- its receipt would recheck the immediate owner FK before the receipt cascade
  -- removes it. Account deletion needs no retained receipt; ordinary trip
  -- deletion still atomically marks a terminal tombstone.
  IF EXISTS (SELECT 1 FROM auth.users WHERE id=OLD.user_id) THEN
    UPDATE private.guest_import_receipts SET deleted_at=coalesce(deleted_at,clock_timestamp()) WHERE trip_id=OLD.id;
  END IF;
  RETURN OLD;
END $fn$;
CREATE TRIGGER guest_b3_trip_update BEFORE UPDATE ON public.trips FOR EACH ROW EXECUTE FUNCTION private.guest_b3_trip_guard();
CREATE TRIGGER guest_b3_trip_delete BEFORE DELETE ON public.trips FOR EACH ROW EXECUTE FUNCTION private.guest_b3_trip_guard();

-- Revoke default/inherited app access on each new helper, not unrelated functions.
DO $acl$
DECLARE f record;
BEGIN
  FOR f IN SELECT p.oid::regprocedure AS identity FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='private' AND (p.proname LIKE 'guest_b3_%' OR p.proname='validate_guest_payload_v1') LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.identity);
  END LOOP;
END $acl$;
REVOKE ALL ON FUNCTION public.import_guest_draft_v1(text,text,bigint,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.get_import_trip_snapshot_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.import_guest_draft_v1(text,text,bigint,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_import_trip_snapshot_v1(uuid) TO authenticated;

DO $postcondition$
DECLARE r text; p text; f record;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
    FOREACH p IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
      IF has_table_privilege(r,'private.guest_import_receipts',p) THEN RAISE EXCEPTION 'guest_import_acl_postcondition'; END IF;
    END LOOP;
    FOR f IN SELECT t.oid FROM pg_proc t JOIN pg_namespace n ON n.oid=t.pronamespace
      WHERE n.nspname='private' AND (t.proname LIKE 'guest_b3_%' OR t.proname='validate_guest_payload_v1') LOOP
      IF has_function_privilege(r,f.oid,'EXECUTE') THEN RAISE EXCEPTION 'guest_import_acl_postcondition'; END IF;
    END LOOP;
  END LOOP;
  FOREACH p IN ARRAY ARRAY['public.import_guest_draft_v1(text,text,bigint,text,text,text)','public.get_import_trip_snapshot_v1(uuid)'] LOOP
    IF has_function_privilege('anon',p,'EXECUTE') OR NOT has_function_privilege('authenticated',p,'EXECUTE') THEN
      RAISE EXCEPTION 'guest_import_acl_postcondition';
    END IF;
  END LOOP;
END $postcondition$;
COMMIT;
