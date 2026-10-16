-- T6 SOURCE ONLY; separate apply approval required for bkocylxbuyvdgxccpixx.
-- CLI 2.81.3 filename; staging catalog preflight captured 2026-10-16.
BEGIN;
DO $owner$ BEGIN IF current_user <> 'postgres' THEN RAISE EXCEPTION 'migration_owner_must_be_postgres'; END IF; END $owner$;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $preflight$
DECLARE expected jsonb:=$baseline${"tables":[{"acl":["postgres=arwdDxtm/postgres","service_role=arwdDxtm/postgres","authenticated=arwd/postgres"],"rls":true,"name":"trips","owner":"postgres","schema":"public"},{"acl":["postgres=arwdDxtm/postgres","service_role=arwdDxtm/postgres","authenticated=arwd/postgres"],"rls":true,"name":"trip_activities","owner":"postgres","schema":"public"},{"acl":["postgres=arwdDxtm/postgres"],"rls":true,"name":"guest_import_receipts","owner":"postgres","schema":"private"}],"columns":[{"name":"receipt_id","type":"uuid","table":"guest_import_receipts","schema":"private","default":"gen_random_uuid()","nullable":"NO","position":1},{"name":"owner_id","type":"uuid","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":2},{"name":"device_scope","type":"text","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":3},{"name":"draft_id","type":"text","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":4},{"name":"source_revision","type":"int8","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":5},{"name":"request_key","type":"text","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":6},{"name":"content_digest","type":"text","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":7},{"name":"trip_id","type":"uuid","table":"guest_import_receipts","schema":"private","default":null,"nullable":"NO","position":8},{"name":"remote_version","type":"int8","table":"guest_import_receipts","schema":"private","default":"1","nullable":"NO","position":9},{"name":"committed_at","type":"timestamptz","table":"guest_import_receipts","schema":"private","default":"clock_timestamp()","nullable":"NO","position":10},{"name":"deleted_at","type":"timestamptz","table":"guest_import_receipts","schema":"private","default":null,"nullable":"YES","position":11},{"name":"id","type":"uuid","table":"trip_activities","schema":"public","default":"gen_random_uuid()","nullable":"NO","position":1},{"name":"trip_id","type":"uuid","table":"trip_activities","schema":"public","default":null,"nullable":"NO","position":2},{"name":"day_number","type":"int4","table":"trip_activities","schema":"public","default":"1","nullable":"NO","position":3},{"name":"start_time","type":"text","table":"trip_activities","schema":"public","default":null,"nullable":"NO","position":4},{"name":"end_time","type":"text","table":"trip_activities","schema":"public","default":null,"nullable":"YES","position":5},{"name":"title","type":"text","table":"trip_activities","schema":"public","default":null,"nullable":"NO","position":6},{"name":"description","type":"text","table":"trip_activities","schema":"public","default":null,"nullable":"YES","position":7},{"name":"service_id","type":"text","table":"trip_activities","schema":"public","default":null,"nullable":"YES","position":8},{"name":"cost","type":"numeric","table":"trip_activities","schema":"public","default":"0","nullable":"YES","position":9},{"name":"has_conflict","type":"bool","table":"trip_activities","schema":"public","default":"false","nullable":"YES","position":10},{"name":"conflict_reason","type":"text","table":"trip_activities","schema":"public","default":null,"nullable":"YES","position":11},{"name":"created_at","type":"timestamptz","table":"trip_activities","schema":"public","default":"timezone('utc'::text, now())","nullable":"NO","position":12},{"name":"id","type":"uuid","table":"trips","schema":"public","default":"gen_random_uuid()","nullable":"NO","position":1},{"name":"user_id","type":"uuid","table":"trips","schema":"public","default":null,"nullable":"NO","position":2},{"name":"title","type":"text","table":"trips","schema":"public","default":null,"nullable":"NO","position":3},{"name":"destination_name","type":"text","table":"trips","schema":"public","default":null,"nullable":"NO","position":4},{"name":"num_days","type":"int4","table":"trips","schema":"public","default":"3","nullable":"YES","position":5},{"name":"budget_total","type":"numeric","table":"trips","schema":"public","default":"0","nullable":"YES","position":6},{"name":"start_date","type":"timestamptz","table":"trips","schema":"public","default":null,"nullable":"YES","position":7},{"name":"end_date","type":"timestamptz","table":"trips","schema":"public","default":null,"nullable":"YES","position":8},{"name":"status","type":"text","table":"trips","schema":"public","default":"'planning'::text","nullable":"YES","position":9},{"name":"ai_plan_data","type":"jsonb","table":"trips","schema":"public","default":"'{}'::jsonb","nullable":"YES","position":10},{"name":"created_at","type":"timestamptz","table":"trips","schema":"public","default":"timezone('utc'::text, now())","nullable":"NO","position":11},{"name":"canonical_payload_text","type":"text","table":"trips","schema":"public","default":null,"nullable":"YES","position":12}],"constraints":[{"name":"trips_pkey","table":"trips","definition":"PRIMARY KEY (id)"},{"name":"trips_status_check","table":"trips","definition":"CHECK ((status = ANY (ARRAY['planning'::text, 'booked'::text, 'completed'::text])))"},{"name":"trips_user_id_fkey","table":"trips","definition":"FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"},{"name":"trip_activities_pkey","table":"trip_activities","definition":"PRIMARY KEY (id)"},{"name":"trip_activities_service_id_fkey","table":"trip_activities","definition":"FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE SET NULL"},{"name":"trip_activities_trip_id_fkey","table":"trip_activities","definition":"FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE"},{"name":"guest_import_receipts_content_digest_check","table":"private.guest_import_receipts","definition":"CHECK (((length(content_digest) = 64) AND (content_digest !~ '[^0-9a-f]'::text)))"},{"name":"guest_import_receipts_device_scope_check","table":"private.guest_import_receipts","definition":"CHECK ((((char_length(device_scope) >= 1) AND (char_length(device_scope) <= 128)) AND (btrim(device_scope) <> ''::text)))"},{"name":"guest_import_receipts_draft_id_check","table":"private.guest_import_receipts","definition":"CHECK ((((char_length(draft_id) >= 1) AND (char_length(draft_id) <= 128)) AND (btrim(draft_id) <> ''::text)))"},{"name":"guest_import_receipts_owner_id_device_scope_draft_id_source_key","table":"private.guest_import_receipts","definition":"UNIQUE (owner_id, device_scope, draft_id, source_revision)"},{"name":"guest_import_receipts_owner_id_fkey","table":"private.guest_import_receipts","definition":"FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE"},{"name":"guest_import_receipts_owner_id_request_key_key","table":"private.guest_import_receipts","definition":"UNIQUE (owner_id, request_key)"},{"name":"guest_import_receipts_pkey","table":"private.guest_import_receipts","definition":"PRIMARY KEY (receipt_id)"},{"name":"guest_import_receipts_remote_version_check","table":"private.guest_import_receipts","definition":"CHECK ((remote_version = 1))"},{"name":"guest_import_receipts_request_key_check","table":"private.guest_import_receipts","definition":"CHECK ((((char_length(request_key) >= 1) AND (char_length(request_key) <= 256)) AND (btrim(request_key) <> ''::text)))"},{"name":"guest_import_receipts_source_revision_check","table":"private.guest_import_receipts","definition":"CHECK (((source_revision >= 1) AND (source_revision <= '9007199254740991'::bigint)))"},{"name":"guest_import_receipts_trip_id_key","table":"private.guest_import_receipts","definition":"UNIQUE (trip_id)"}],"triggers":[{"name":"guest_b3_trip_delete","table":"trips","definition":"CREATE TRIGGER guest_b3_trip_delete BEFORE DELETE ON public.trips FOR EACH ROW EXECUTE FUNCTION private.guest_b3_trip_guard()"},{"name":"guest_b3_trip_update","table":"trips","definition":"CREATE TRIGGER guest_b3_trip_update BEFORE UPDATE ON public.trips FOR EACH ROW EXECUTE FUNCTION private.guest_b3_trip_guard()"}],"policies":[{"cmd":"INSERT","qual":null,"roles":["authenticated"],"tablename":"trips","permissive":"PERMISSIVE","policyname":"Users create own trips","schemaname":"public","with_check":"(auth.uid() = user_id)"},{"cmd":"DELETE","qual":"(auth.uid() = user_id)","roles":["authenticated"],"tablename":"trips","permissive":"PERMISSIVE","policyname":"Users delete own trips","schemaname":"public","with_check":null},{"cmd":"UPDATE","qual":"(auth.uid() = user_id)","roles":["authenticated"],"tablename":"trips","permissive":"PERMISSIVE","policyname":"Users update own trips","schemaname":"public","with_check":"(auth.uid() = user_id)"},{"cmd":"SELECT","qual":"(auth.uid() = user_id)","roles":["authenticated"],"tablename":"trips","permissive":"PERMISSIVE","policyname":"Users view own trips","schemaname":"public","with_check":null},{"cmd":"ALL","qual":"(EXISTS ( SELECT 1\n   FROM trips t\n  WHERE ((t.id = trip_activities.trip_id) AND (t.user_id = auth.uid()))))","roles":["authenticated"],"tablename":"trip_activities","permissive":"PERMISSIVE","policyname":"Users manage own trip activities","schemaname":"public","with_check":"(EXISTS ( SELECT 1\n   FROM trips t\n  WHERE ((t.id = trip_activities.trip_id) AND (t.user_id = auth.uid()))))"}]}$baseline$::jsonb; actual jsonb;
BEGIN
 IF current_setting('server_version_num')::integer<160000 OR to_regprocedure('extensions.digest(bytea,text)') IS NULL THEN RAISE EXCEPTION 'p32_database_prerequisite'; END IF;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='private' AND c.relname IN ('editable_trip_documents','editable_trip_mutations','editable_trip_write_permits'))
 OR EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE (n.nspname='private' AND p.proname LIKE 'p32_%') OR (n.nspname='public' AND p.proname IN ('create_editable_trip_v2','update_editable_trip_v2','delete_editable_trip_v2','get_editable_trip_v2','get_editable_mutation_v2','list_owned_trips_v2'))) THEN RAISE EXCEPTION 'p32_object_collision'; END IF;
 SELECT jsonb_build_object(
 'tables',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'acl',c.relacl)) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE (n.nspname,c.relname) IN (('public','trips'),('public','trip_activities'),('private','guest_import_receipts'))),
 'columns',(SELECT jsonb_agg(jsonb_build_object('schema',table_schema,'table',table_name,'name',column_name,'type',udt_name,'nullable',is_nullable,'default',column_default,'position',ordinal_position)) FROM information_schema.columns WHERE (table_schema,table_name) IN (('public','trips'),('public','trip_activities'),('private','guest_import_receipts'))),
 'constraints',(SELECT jsonb_agg(jsonb_build_object('table',conrelid::regclass::text,'name',conname,'definition',pg_get_constraintdef(oid))) FROM pg_constraint WHERE conrelid IN ('public.trips'::regclass,'public.trip_activities'::regclass,'private.guest_import_receipts'::regclass)),
 'triggers',(SELECT jsonb_agg(jsonb_build_object('table',tgrelid::regclass::text,'name',tgname,'definition',pg_get_triggerdef(oid))) FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN ('public.trips'::regclass,'public.trip_activities'::regclass)),
 'policies',(SELECT jsonb_agg(to_jsonb(p)) FROM pg_policies p WHERE (schemaname,tablename) IN (('public','trips'),('public','trip_activities'),('private','guest_import_receipts')))
 ) INTO actual;
 IF NOT(actual @> expected AND expected @> actual) THEN RAISE EXCEPTION 'p32_baseline_drift'; END IF;
 IF (SELECT nspacl IS NOT NULL OR pg_get_userbyid(nspowner)<>'postgres' FROM pg_namespace WHERE nspname='private') THEN RAISE EXCEPTION 'p32_private_acl_drift'; END IF;
IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='get_import_trip_snapshot_v1(uuid)'::regprocedure AND md5(pg_get_functiondef(oid))='37296be3a0bfe0495195ebac85f3bea1' AND proacl=ARRAY['postgres=X/postgres'::aclitem,'authenticated=X/postgres'::aclitem] AND prosecdef AND proconfig=ARRAY['search_path=""'] AND pg_get_userbyid(proowner)='postgres') THEN RAISE EXCEPTION 'p32_b3_drift'; END IF;
IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='private.guest_b3_trip_guard()'::regprocedure AND md5(pg_get_functiondef(oid))='86dbec45babd7eb72937b9f8a455c65a' AND proacl=ARRAY['postgres=X/postgres'::aclitem] AND prosecdef AND proconfig=ARRAY['search_path=""'] AND pg_get_userbyid(proowner)='postgres') THEN RAISE EXCEPTION 'p32_b3_drift'; END IF;
IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='import_guest_draft_v1(text,text,bigint,text,text,text)'::regprocedure AND md5(pg_get_functiondef(oid))='8f96ede11466e66055b04b35c970d64e' AND proacl=ARRAY['postgres=X/postgres'::aclitem,'authenticated=X/postgres'::aclitem] AND prosecdef AND proconfig=ARRAY['search_path=""'] AND pg_get_userbyid(proowner)='postgres') THEN RAISE EXCEPTION 'p32_b3_drift'; END IF;
END $preflight$;

CREATE TABLE private.editable_trip_documents(
 trip_id uuid PRIMARY KEY REFERENCES public.trips(id) ON DELETE CASCADE,
 owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 content_version bigint NOT NULL CHECK(content_version BETWEEN 1 AND 9007199254740991),
 payload_text text NOT NULL CHECK(octet_length(payload_text)<=1048576),
 content_digest text NOT NULL CHECK(content_digest ~ '^[0-9a-f]{64}$'),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE INDEX editable_trip_documents_owner ON private.editable_trip_documents(owner_id,trip_id);
CREATE TABLE private.editable_trip_mutations(
 owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 request_id uuid NOT NULL, operation text NOT NULL CHECK(operation IN ('create','update','delete')),
 trip_id uuid NOT NULL, expected_version bigint,
 result_version bigint NOT NULL CHECK(result_version BETWEEN 1 AND 9007199254740991),
 request_digest text NOT NULL CHECK(request_digest ~ '^[0-9a-f]{64}$'),
 content_digest text CHECK(content_digest ~ '^[0-9a-f]{64}$'), source_binding jsonb,
 committed_at timestamptz NOT NULL DEFAULT clock_timestamp(), deleted boolean NOT NULL DEFAULT false,
 PRIMARY KEY(owner_id,request_id),
 CHECK((operation='create' AND expected_version IS NULL AND result_version=1) OR (operation<>'create' AND expected_version>=1 AND result_version=expected_version+1)),
 CHECK((operation='delete')=(content_digest IS NULL)));
CREATE INDEX editable_trip_mutations_trip ON private.editable_trip_mutations(owner_id,trip_id);
CREATE UNIQUE INDEX editable_trip_mutations_guest_source ON private.editable_trip_mutations
 (owner_id,(source_binding->>'deviceScope'),(source_binding->>'draftId'),(source_binding->>'sourceRevision'))
 WHERE source_binding->>'kind'='guest_import';
CREATE TABLE private.editable_trip_write_permits(
 backend_pid integer NOT NULL, transaction_id xid8 NOT NULL, trip_id uuid NOT NULL,
 operation text NOT NULL CHECK(operation IN ('INSERT','UPDATE','DELETE')),
 PRIMARY KEY(backend_pid,transaction_id,trip_id,operation));
ALTER TABLE private.editable_trip_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.editable_trip_mutations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.editable_trip_write_permits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.editable_trip_documents,private.editable_trip_mutations,private.editable_trip_write_permits FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION private.p32_require(ok boolean,code text DEFAULT 'invalid_document') RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',code; END IF; END $f$;
CREATE FUNCTION private.p32_nonblank(v text) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT btrim(v,E' \t\n\r\f\u000b\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff')<>'' $f$;
CREATE FUNCTION private.p32_keys(v jsonb,names text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN PERFORM private.p32_require(jsonb_typeof(v)='object' AND
 (SELECT array_agg(k ORDER BY k COLLATE "C") FROM jsonb_object_keys(v) k)=
 (SELECT array_agg(k ORDER BY k COLLATE "C") FROM unnest(string_to_array(names,' ')) k)); END $f$;
CREATE FUNCTION private.p32_text(v jsonb,max_chars integer,blank boolean DEFAULT false,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND char_length(v#>>'{}')<=max_chars AND (blank OR private.p32_nonblank(v#>>'{}'))); END $f$;
CREATE FUNCTION private.p32_int(v jsonb,lo numeric,hi numeric,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='number' AND v::text ~ '^-?(0|[1-9][0-9]*)$');
 PERFORM private.p32_require(v::text::numeric BETWEEN lo AND hi); END $f$;
CREATE FUNCTION private.p32_enum(v jsonb,choices text,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND v#>>'{}'=ANY(string_to_array(choices,' '))); END $f$;
CREATE FUNCTION private.p32_id(v jsonb,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND v#>>'{}' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'); END $f$;
CREATE FUNCTION private.p32_hash(v jsonb,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND v#>>'{}' ~ '^[0-9a-f]{64}$'); END $f$;
CREATE FUNCTION private.p32_date(v jsonb,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE t text:=v#>>'{}'; d date;
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND left(t,4)<>'0000');
 BEGIN d:=t::date; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_document'; END;
 PERFORM private.p32_require(to_char(d,'YYYY-MM-DD')=t); END $f$;
CREATE FUNCTION private.p32_list(v jsonb,maximum integer) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN PERFORM private.p32_require(jsonb_typeof(v)='array'); PERFORM private.p32_require(jsonb_array_length(v)<=maximum); END $f$;
CREATE FUNCTION private.p32_walk(v json,depth integer DEFAULT 0) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE entry record; item json;
BEGIN PERFORM private.p32_require(depth<=32,'invalid_input');
 CASE json_typeof(v)
 WHEN 'object' THEN FOR entry IN SELECT * FROM json_each(v) LOOP PERFORM private.p32_walk(entry.value,depth+1); END LOOP;
 WHEN 'array' THEN FOR item IN SELECT * FROM json_array_elements(v) LOOP PERFORM private.p32_walk(item,depth+1); END LOOP;
 WHEN 'number' THEN PERFORM private.p32_require(v::text ~ '^-?(0|[1-9][0-9]*)$','invalid_input');
 PERFORM private.p32_require(v::text::numeric BETWEEN -9007199254740991 AND 9007199254740991,'invalid_input');
 ELSE NULL; END CASE; END $f$;
CREATE FUNCTION private.p32_parse(raw text,max_bytes integer DEFAULT 1048576) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN PERFORM private.p32_require(raw IS NOT NULL AND octet_length(raw)<=max_bytes,'invalid_input');
 PERFORM private.p32_require(raw IS JSON WITH UNIQUE KEYS,'invalid_input');
 PERFORM private.p32_walk(raw::json); RETURN raw::jsonb;
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_input'; END $f$;
CREATE FUNCTION private.p32_provenance(v jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE r jsonb; t text;
BEGIN PERFORM private.p32_keys(v,'quality sourceRefs observedAt'); PERFORM private.p32_enum(v->'quality','user_provided estimated unknown');
 PERFORM private.p32_list(v->'sourceRefs',1000);
 FOR r IN SELECT * FROM jsonb_array_elements(v->'sourceRefs') LOOP PERFORM private.p32_text(r,128); END LOOP;
 PERFORM private.p32_require((SELECT count(*)=count(DISTINCT x) FROM jsonb_array_elements(v->'sourceRefs') x));
 IF v->'observedAt'<>'null'::jsonb THEN
 t:=v->>'observedAt'; PERFORM private.p32_require(jsonb_typeof(v->'observedAt')='string' AND t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?Z$');
 PERFORM private.p32_date(to_jsonb(left(t,10))); PERFORM private.p32_require(to_char(t::timestamptz AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS')=left(t,19)); END IF; END $f$;
-- Dart orders object keys by UTF-16 code units, not the database locale.
CREATE FUNCTION private.p32_sortkey(v text) RETURNS bytea LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE i integer; cp integer; answer bytea:=''::bytea;
BEGIN FOR i IN 1..char_length(v) LOOP cp:=ascii(substr(v,i,1));
 IF cp>65535 THEN cp:=cp-65536; answer:=answer||decode(lpad(to_hex(55296+cp/1024),4,'0')||lpad(to_hex(56320+cp%1024),4,'0'),'hex');
 ELSE answer:=answer||decode(lpad(to_hex(cp),4,'0'),'hex'); END IF; END LOOP; RETURN answer; END $f$;
CREATE FUNCTION private.p32_canonical(v jsonb,float_value boolean DEFAULT false) RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result text; t text; exponent integer;
BEGIN CASE jsonb_typeof(v)
 WHEN 'object' THEN SELECT '{'||coalesce(string_agg(to_jsonb(key)::text||':'||private.p32_canonical(value,
 float_value OR key IN ('durationHours','totalScore','avgTempMax','avgPrecipitation','latitude','longitude','normalizedScores','scoreContributions')),',' ORDER BY private.p32_sortkey(key)),'')||'}' INTO result FROM jsonb_each(v);
 WHEN 'array' THEN SELECT '['||coalesce(string_agg(private.p32_canonical(value,float_value),',' ORDER BY ordinality),'')||']' INTO result FROM jsonb_array_elements(v) WITH ORDINALITY;
 WHEN 'number' THEN IF float_value THEN
 t:=((v::text)::double precision)::text;
 IF lower(t) IN ('nan','infinity','-infinity') THEN RAISE EXCEPTION 'source_unavailable'; END IF;
 IF t::double precision=0 THEN RETURN '0.0'; END IF;
 IF position('e' IN lower(t))>0 THEN exponent:=split_part(lower(t),'e',2)::integer;
 IF exponent BETWEEN -6 AND 20 THEN t:=(t::numeric)::text;
 ELSE RETURN split_part(lower(t),'e',1)||'e'||CASE WHEN exponent>=0 THEN '+' ELSE '' END||exponent::text; END IF; END IF;
 result:=t||CASE WHEN position('.' IN t)=0 THEN '.0' ELSE '' END;
 ELSE result:=v::text; END IF;
 ELSE result:=v::text; END CASE; RETURN result; END $f$;

CREATE FUNCTION private.p32_issues(doc jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 WITH items AS MATERIALIZED (SELECT value FROM jsonb_array_elements(doc->'items')),
 pairs AS (
  SELECT a.value a,b.value b,c.code FROM items a JOIN items b ON a.value->>'dayId'=b.value->>'dayId' AND a.value->>'id'<>b.value->>'id'
  CROSS JOIN LATERAL (VALUES
   (CASE WHEN (a.value->>'position')::integer+1=(b.value->>'position')::integer
     AND a.value->>'startMinute' IS NOT NULL AND b.value->>'startMinute' IS NOT NULL
     AND (b.value->>'startMinute')::integer<(a.value->>'startMinute')::integer THEN 'time_order' END),
   (CASE WHEN a.value->>'id' COLLATE "C"<b.value->>'id' COLLATE "C"
     AND a.value->>'startMinute' IS NOT NULL AND a.value->>'endMinute' IS NOT NULL
     AND b.value->>'startMinute' IS NOT NULL AND b.value->>'endMinute' IS NOT NULL
     AND (a.value->>'endMinute')::integer>(a.value->>'startMinute')::integer
     AND (b.value->>'endMinute')::integer>(b.value->>'startMinute')::integer
     AND (a.value->>'startMinute')::integer<(b.value->>'endMinute')::integer
     AND (b.value->>'startMinute')::integer<(a.value->>'endMinute')::integer THEN 'overlap' END)
  ) c(code) WHERE c.code IS NOT NULL),
 fingerprints AS (
 SELECT code,ids,encode(extensions.digest(convert_to(private.p32_canonical(
 jsonb_build_object('code',code,'itemIds',ids,'scopedFields',scoped)),'UTF8'),'sha256'),'hex') fingerprint
 FROM pairs CROSS JOIN LATERAL (
  SELECT jsonb_agg(value->'id' ORDER BY value->>'id' COLLATE "C") ids,
  jsonb_agg(jsonb_build_object('id',value->'id','dayId',value->'dayId',
   'date',(SELECT d->'date' FROM jsonb_array_elements(doc->'days') d WHERE d->>'id'=value->>'dayId'),
   'position',value->'position','startMinute',value->'startMinute','endMinute',value->'endMinute')
   ORDER BY value->>'id' COLLATE "C") scoped
  FROM jsonb_array_elements(jsonb_build_array(a,b))) f)
 SELECT coalesce(jsonb_agg(jsonb_build_object('issueCode',code,'itemIds',ids,'fingerprint',fingerprint)),'[]') FROM fingerprints $f$;

CREATE FUNCTION private.p32_validate(raw text,account_save boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE doc jsonb:=private.p32_parse(raw); inp jsonb; d jsonb; i jsonb; e jsonb; x jsonb; snap jsonb; kind text; idx integer:=0;
 ids text[]:='{}'; dayids text[]:='{}'; active_ids text[]:='{}'; expenseids text[]; start_day date; end_day date;
 estimate numeric:=0; actual numeric:=0; amount numeric; quantity numeric; issues jsonb;
BEGIN
 IF doc->'schemaVersion' IS DISTINCT FROM '2'::jsonb THEN RAISE EXCEPTION 'unsupported_schema'; END IF;
 PERFORM private.p32_keys(doc,'schemaVersion input days items estimates actualExpenses exceptions source'); inp:=doc->'input';
 PERFORM private.p32_keys(inp,'title destinationId destinationName startDate endDate timezone origin travelerCount totalBudgetVnd interests priority');
 PERFORM private.p32_text(inp->'title',200,NOT account_save); PERFORM private.p32_text(inp->'origin',200,NOT account_save);
 PERFORM private.p32_enum(inp->'destinationId','ha-noi ha-long sa-pa ninh-binh hue da-nang hoi-an nha-trang da-lat ho-chi-minh phu-quoc can-tho',NOT account_save);
 PERFORM private.p32_text(inp->'destinationName',200,false,NOT account_save);
 PERFORM private.p32_date(inp->'startDate',NOT account_save); PERFORM private.p32_date(inp->'endDate',NOT account_save);
 PERFORM private.p32_enum(inp->'timezone','Asia/Ho_Chi_Minh'); PERFORM private.p32_int(inp->'travelerCount',1,2147483647); PERFORM private.p32_int(inp->'totalBudgetVnd',0,9007199254740991);
 PERFORM private.p32_enum(inp->'priority','balanced cheapest fastest comfortable'); PERFORM private.p32_list(inp->'interests',20);
 FOR x IN SELECT * FROM jsonb_array_elements(inp->'interests') LOOP PERFORM private.p32_text(x,80); END LOOP;
 PERFORM private.p32_list(doc->'days',366); PERFORM private.p32_require(jsonb_array_length(doc->'days')>0);
 IF inp->>'startDate' IS NOT NULL AND inp->>'endDate' IS NOT NULL THEN
 start_day:=(inp->>'startDate')::date; end_day:=(inp->>'endDate')::date;
 PERFORM private.p32_require(end_day>=start_day AND end_day-start_day+1=jsonb_array_length(doc->'days')); END IF;
 FOR d IN SELECT * FROM jsonb_array_elements(doc->'days') LOOP
 idx:=idx+1; PERFORM private.p32_keys(d,'id ordinal date notes'); PERFORM private.p32_id(d->'id'); PERFORM private.p32_int(d->'ordinal',idx,idx);
 PERFORM private.p32_date(d->'date',true); PERFORM private.p32_text(d->'notes',2000,true);
 PERFORM private.p32_require(NOT d->>'id'=ANY(dayids)); dayids:=array_append(dayids,d->>'id');
 IF start_day IS NOT NULL THEN PERFORM private.p32_require(d->>'date'=to_char(start_day+idx-1,'YYYY-MM-DD')); END IF; END LOOP;
 PERFORM private.p32_list(doc->'items',1000);
 FOR i IN SELECT * FROM jsonb_array_elements(doc->'items') LOOP
 PERFORM private.p32_keys(i,'id dayId position title placeId startMinute endMinute notes provenance'); PERFORM private.p32_id(i->'id'); PERFORM private.p32_id(i->'dayId');
 PERFORM private.p32_require(NOT i->>'id'=ANY(ids) AND i->>'dayId'=ANY(dayids)); ids:=array_append(ids,i->>'id');
 PERFORM private.p32_int(i->'position',0,999); PERFORM private.p32_text(i->'title',200); PERFORM private.p32_text(i->'placeId',128,false,true);
 PERFORM private.p32_int(i->'startMinute',0,1439,true); PERFORM private.p32_int(i->'endMinute',0,1439,true); PERFORM private.p32_text(i->'notes',2000,true); PERFORM private.p32_provenance(i->'provenance');
 IF i->>'startMinute' IS NOT NULL AND i->>'endMinute' IS NOT NULL THEN PERFORM private.p32_require((i->>'endMinute')::integer>(i->>'startMinute')::integer); END IF; END LOOP;
 PERFORM private.p32_require(NOT EXISTS(SELECT 1 FROM (SELECT value->>'dayId' dayid,(value->>'position')::integer pos,row_number() OVER(PARTITION BY value->>'dayId' ORDER BY (value->>'position')::integer)-1 expected FROM jsonb_array_elements(doc->'items')) q WHERE pos<>expected));
 FOREACH kind IN ARRAY ARRAY['estimates','actualExpenses'] LOOP
 expenseids:='{}'; PERFORM private.p32_list(doc->kind,1000);
 FOR e IN SELECT * FROM jsonb_array_elements(doc->kind) LOOP
 PERFORM private.p32_keys(e,CASE WHEN kind='estimates' THEN 'id itemId category unitAmountVnd basis customQuantity active description provenance' ELSE 'id itemId amountVnd category paidOn description sourceItemSnapshot provenance' END);
 PERFORM private.p32_id(e->'id'); PERFORM private.p32_require(NOT e->>'id'=ANY(expenseids)); expenseids:=array_append(expenseids,e->>'id');
 PERFORM private.p32_id(e->'itemId',true); PERFORM private.p32_require(e->>'itemId' IS NULL OR e->>'itemId'=ANY(ids));
 PERFORM private.p32_enum(e->'category','transport accommodation food attractions shopping other'); PERFORM private.p32_text(e->'description',2000,true); PERFORM private.p32_provenance(e->'provenance');
 IF kind='estimates' THEN
 PERFORM private.p32_int(e->'unitAmountVnd',0,9007199254740991,true); PERFORM private.p32_enum(e->'basis','trip_total per_person per_day per_person_day custom_quantity');
 PERFORM private.p32_require(jsonb_typeof(e->'active')='boolean');
 IF e->>'basis'='custom_quantity' THEN PERFORM private.p32_int(e->'customQuantity',1,2147483647); ELSE PERFORM private.p32_require(e->'customQuantity'='null'::jsonb); END IF;
 IF e->'unitAmountVnd'='null'::jsonb THEN PERFORM private.p32_require(e#>>'{provenance,quality}'='unknown'); END IF;
 IF (e->>'active')::boolean THEN
 IF e->>'itemId' IS NOT NULL THEN PERFORM private.p32_require(NOT e->>'itemId'=ANY(active_ids)); active_ids:=array_append(active_ids,e->>'itemId'); END IF;
 quantity:=CASE e->>'basis' WHEN 'trip_total' THEN 1 WHEN 'per_person' THEN (inp->>'travelerCount')::numeric WHEN 'per_day' THEN jsonb_array_length(doc->'days') WHEN 'per_person_day' THEN (inp->>'travelerCount')::numeric*jsonb_array_length(doc->'days') ELSE (e->>'customQuantity')::numeric END;
 amount:=coalesce((e->>'unitAmountVnd')::numeric,0)*quantity; PERFORM private.p32_require(amount<=9007199254740991); estimate:=estimate+amount; END IF;
 ELSE
 PERFORM private.p32_int(e->'amountVnd',0,9007199254740991); PERFORM private.p32_date(e->'paidOn'); PERFORM private.p32_require(e#>>'{provenance,quality}'='user_provided');
 actual:=actual+(e->>'amountVnd')::numeric; snap:=e->'sourceItemSnapshot';
 IF snap<>'null'::jsonb THEN PERFORM private.p32_keys(snap,'title dayId date'); PERFORM private.p32_text(snap->'title',200); PERFORM private.p32_id(snap->'dayId'); PERFORM private.p32_date(snap->'date',true); END IF; END IF;
 END LOOP; END LOOP;
 PERFORM private.p32_require(estimate<=9007199254740991 AND actual<=9007199254740991);
 PERFORM private.p32_list(doc->'exceptions',1000);
 FOR e IN SELECT * FROM jsonb_array_elements(doc->'exceptions') LOOP
 PERFORM private.p32_keys(e,'issueCode itemIds reason fingerprint'); PERFORM private.p32_enum(e->'issueCode','overlap known_closed time_order');
 PERFORM private.p32_text(e->'reason',2000); PERFORM private.p32_hash(e->'fingerprint'); PERFORM private.p32_list(e->'itemIds',1000);
 FOR x IN SELECT * FROM jsonb_array_elements(e->'itemIds') LOOP PERFORM private.p32_id(x); PERFORM private.p32_require(x#>>'{}'=ANY(ids)); END LOOP; END LOOP;
 PERFORM private.p32_keys(doc->'source','kind sourceId sourceDigest'); PERFORM private.p32_enum(doc#>'{source,kind}','new manual_v1_copy catalogue_reference');
 PERFORM private.p32_text(doc#>'{source,sourceId}',128,false,true); PERFORM private.p32_hash(doc#>'{source,sourceDigest}',true);
 IF account_save THEN
 issues:=private.p32_issues(doc);
 FOR i IN SELECT * FROM jsonb_array_elements(issues) LOOP
 PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'exceptions') e WHERE e->>'issueCode'=i->>'issueCode' AND e->>'fingerprint'=i->>'fingerprint'
 AND jsonb_array_length(e->'itemIds')=jsonb_array_length(i->'itemIds') AND e->'itemIds' @> i->'itemIds' AND private.p32_nonblank(e->>'reason')));
 END LOOP; END IF; RETURN doc; END $f$;

CREATE FUNCTION private.p32_order(doc jsonb,dayid text,ordered jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 SELECT jsonb_set(doc,'{items}',coalesce((SELECT jsonb_agg(value ORDER BY ordinality) FROM jsonb_array_elements(doc->'items') WITH ORDINALITY WHERE value->>'dayId'<>dayid),'[]')||
 coalesce((SELECT jsonb_agg(value||jsonb_build_object('position',ordinality-1) ORDER BY ordinality) FROM jsonb_array_elements(ordered) WITH ORDINALITY),'[]')) $f$;
CREATE FUNCTION private.p32_remove(doc jsonb,itemid text) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE old jsonb; day jsonb; result jsonb;
BEGIN SELECT value INTO old FROM jsonb_array_elements(doc->'items') WHERE value->>'id'=itemid; PERFORM private.p32_require(old IS NOT NULL,'invalid_command');
 SELECT value INTO day FROM jsonb_array_elements(doc->'days') WHERE value->>'id'=old->>'dayId';
 result:=jsonb_set(doc,'{items}',coalesce((SELECT jsonb_agg(value ORDER BY ordinality) FROM jsonb_array_elements(doc->'items') WITH ORDINALITY WHERE value->>'id'<>itemid),'[]'));
 result:=jsonb_set(result,'{estimates}',coalesce((SELECT jsonb_agg(CASE WHEN value->>'itemId'=itemid THEN value||'{"active":false,"itemId":null}'::jsonb ELSE value END ORDER BY ordinality) FROM jsonb_array_elements(doc->'estimates') WITH ORDINALITY),'[]'));
 result:=jsonb_set(result,'{actualExpenses}',coalesce((SELECT jsonb_agg(CASE WHEN value->>'itemId'=itemid THEN value||jsonb_build_object('itemId',NULL,'sourceItemSnapshot',coalesce(nullif(value->'sourceItemSnapshot','null'::jsonb),jsonb_build_object('title',old->'title','dayId',old->'dayId','date',day->'date'))) ELSE value END ORDER BY ordinality) FROM jsonb_array_elements(doc->'actualExpenses') WITH ORDINALITY),'[]'));
 RETURN private.p32_order(result,old->>'dayId',coalesce((SELECT jsonb_agg(value ORDER BY (value->>'position')::integer) FROM jsonb_array_elements(result->'items') WHERE value->>'dayId'=old->>'dayId'),'[]')); END $f$;
CREATE FUNCTION private.p32_insert(doc jsonb,item jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE ordered jsonb; pos integer;
BEGIN PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'days') d WHERE d->>'id'=item->>'dayId'),'invalid_command');
 PERFORM private.p32_int(item->'position',0,999); pos:=(item->>'position')::integer;
 SELECT coalesce(jsonb_agg(value ORDER BY (value->>'position')::integer),'[]') INTO ordered FROM jsonb_array_elements(doc->'items') WHERE value->>'dayId'=item->>'dayId';
 PERFORM private.p32_require(pos<=jsonb_array_length(ordered),'invalid_command'); ordered:=jsonb_insert(ordered,ARRAY[pos::text],item);
 RETURN private.p32_order(doc,item->>'dayId',ordered); END $f$;
CREATE FUNCTION private.p32_move(doc jsonb,itemid text,dayid text,pos jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE old jsonb; result jsonb;
BEGIN SELECT value INTO old FROM jsonb_array_elements(doc->'items') WHERE value->>'id'=itemid; PERFORM private.p32_require(old IS NOT NULL,'invalid_command');
 result:=jsonb_set(doc,'{items}',coalesce((SELECT jsonb_agg(value ORDER BY ordinality) FROM jsonb_array_elements(doc->'items') WITH ORDINALITY WHERE value->>'id'<>itemid),'[]'));
 result:=private.p32_order(result,old->>'dayId',coalesce((SELECT jsonb_agg(value ORDER BY (value->>'position')::integer) FROM jsonb_array_elements(result->'items') WHERE value->>'dayId'=old->>'dayId'),'[]'));
 RETURN private.p32_insert(result,old||jsonb_build_object('dayId',dayid,'position',pos)); END $f$;

-- Command decoding checks every entity before replay, even when a later command
-- overwrites/removes it. Match Dart casts without imposing final-state semantic
-- bounds on an intermediate batch state.
CREATE FUNCTION private.p32_entity(v jsonb,names text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE e record; x jsonb; nullable boolean;
BEGIN
 PERFORM private.p32_keys(v,names);
 FOR e IN SELECT * FROM jsonb_each(v) LOOP
 nullable:=e.key=ANY(string_to_array('destinationId destinationName startDate endDate placeId itemId startMinute endMinute unitAmountVnd customQuantity observedAt sourceItemSnapshot',' '));
 IF nullable AND e.value='null'::jsonb THEN CONTINUE; END IF;
 CASE e.key
 WHEN 'provenance' THEN PERFORM private.p32_entity(e.value,'quality sourceRefs observedAt');
 WHEN 'sourceItemSnapshot' THEN PERFORM private.p32_entity(e.value,'title dayId date');
 WHEN 'interests','itemIds','sourceRefs' THEN
  PERFORM private.p32_require(jsonb_typeof(e.value)='array');
  FOR x IN SELECT * FROM jsonb_array_elements(e.value) LOOP PERFORM private.p32_require(jsonb_typeof(x)='string'); END LOOP;
 WHEN 'active' THEN PERFORM private.p32_require(jsonb_typeof(e.value)='boolean');
 WHEN 'ordinal','position','travelerCount','totalBudgetVnd','amountVnd','startMinute','endMinute','unitAmountVnd','customQuantity' THEN
  PERFORM private.p32_require(jsonb_typeof(e.value)='number');
 ELSE PERFORM private.p32_require(jsonb_typeof(e.value)='string'); END CASE;
 END LOOP;
END $f$;
CREATE FUNCTION private.p32_replay(base jsonb,commands jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE doc jsonb:=base; c jsonb; op text; item jsonb; ordered jsonb; e jsonb; kind text; affected text[]; moved text[]; removed text[]; nextids text[]; issues jsonb; before_count integer;
BEGIN PERFORM private.p32_list(commands,4000);
 FOR c IN SELECT * FROM jsonb_array_elements(commands) LOOP op:=c->>'op';
 CASE op
 WHEN 'setInput' THEN PERFORM private.p32_keys(c,'op input');
 PERFORM private.p32_entity(c->'input','title destinationId destinationName startDate endDate timezone origin travelerCount totalBudgetVnd interests priority'); doc:=jsonb_set(doc,'{input}',c->'input');
 WHEN 'setDayNotes' THEN PERFORM private.p32_keys(c,'op dayId notes'); PERFORM private.p32_text(c->'notes',2000,true);
 PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'days') d WHERE d->'id'=c->'dayId'),'invalid_command');
 SELECT jsonb_agg(CASE WHEN value->'id'=c->'dayId' THEN value||jsonb_build_object('notes',c->'notes') ELSE value END ORDER BY ordinality) INTO ordered FROM jsonb_array_elements(doc->'days') WITH ORDINALITY; doc:=jsonb_set(doc,'{days}',ordered);
 WHEN 'addItem' THEN PERFORM private.p32_keys(c,'op item'); item:=c->'item'; PERFORM private.p32_entity(item,'id dayId position title placeId startMinute endMinute notes provenance');
 PERFORM private.p32_require(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'items') i WHERE i->'id'=item->'id'),'invalid_command'); doc:=private.p32_insert(doc,item);
 WHEN 'editItem' THEN PERFORM private.p32_entity(c,'op itemId title placeId startMinute endMinute notes provenance');
 PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'items') i WHERE i->'id'=c->'itemId'),'invalid_command');
 SELECT jsonb_agg(CASE WHEN value->'id'=c->'itemId' THEN value||(c-'op'-'itemId') ELSE value END ORDER BY ordinality) INTO ordered FROM jsonb_array_elements(doc->'items') WITH ORDINALITY; doc:=jsonb_set(doc,'{items}',ordered);
 WHEN 'moveItem' THEN PERFORM private.p32_keys(c,'op itemId dayId position'); doc:=private.p32_move(doc,c->>'itemId',c->>'dayId',c->'position');
 WHEN 'removeItem' THEN PERFORM private.p32_keys(c,'op itemId'); doc:=private.p32_remove(doc,c->>'itemId');
 WHEN 'reorderDay' THEN PERFORM private.p32_keys(c,'op dayId orderedItemIds'); PERFORM private.p32_list(c->'orderedItemIds',1000);
 PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'days') d WHERE d->'id'=c->'dayId'),'invalid_command');
 SELECT coalesce(jsonb_agg(value->'id'),'[]') INTO ordered FROM jsonb_array_elements(doc->'items') WHERE value->'dayId'=c->'dayId';
 PERFORM private.p32_require(jsonb_array_length(ordered)=jsonb_array_length(c->'orderedItemIds') AND ordered @> c->'orderedItemIds' AND c->'orderedItemIds' @> ordered AND
 (SELECT count(*)=count(DISTINCT value) FROM jsonb_array_elements(c->'orderedItemIds')),'invalid_command');
 SELECT coalesce(jsonb_agg(i.value ORDER BY o.ordinality),'[]') INTO ordered FROM jsonb_array_elements(c->'orderedItemIds') WITH ORDINALITY o JOIN jsonb_array_elements(doc->'items') i ON i.value->'id'=o.value;
 doc:=private.p32_order(doc,c->>'dayId',ordered);
 WHEN 'resizeDays' THEN PERFORM private.p32_keys(c,'op days moves removedItemIds'); PERFORM private.p32_list(c->'days',366); PERFORM private.p32_list(c->'moves',1000); PERFORM private.p32_list(c->'removedItemIds',1000);
 FOR e IN SELECT * FROM jsonb_array_elements(c->'days') LOOP PERFORM private.p32_entity(e,'id ordinal date notes'); END LOOP;
 SELECT coalesce(array_agg(value->>'id'),'{}') INTO nextids FROM jsonb_array_elements(c->'days');
 PERFORM private.p32_require(cardinality(nextids)=(SELECT count(DISTINCT x) FROM unnest(nextids) x),'invalid_command');
 SELECT coalesce(array_agg(value->>'id'),'{}') INTO affected FROM jsonb_array_elements(doc->'items') WHERE NOT value->>'dayId'=ANY(nextids);
 SELECT coalesce(array_agg(value->>'itemId'),'{}') INTO moved FROM jsonb_array_elements(c->'moves');
 SELECT coalesce(array_agg(value#>>'{}'),'{}') INTO removed FROM jsonb_array_elements(c->'removedItemIds');
 PERFORM private.p32_require(cardinality(moved)=(SELECT count(DISTINCT x) FROM unnest(moved) x) AND cardinality(removed)=(SELECT count(DISTINCT x) FROM unnest(removed) x) AND
 NOT moved&&removed AND affected @> moved AND affected @> removed AND (moved||removed) @> affected,'invalid_command');
 FOR e IN SELECT * FROM jsonb_array_elements(c->'removedItemIds') LOOP doc:=private.p32_remove(doc,e#>>'{}'); END LOOP;
 doc:=jsonb_set(doc,'{days}',c->'days');
 FOR e IN SELECT * FROM jsonb_array_elements(c->'moves') LOOP PERFORM private.p32_entity(e,'itemId dayId position'); doc:=private.p32_move(doc,e->>'itemId',e->>'dayId',e->'position'); END LOOP;
 WHEN 'putEstimate','putActual' THEN kind:=CASE WHEN op='putEstimate' THEN 'estimates' ELSE 'actualExpenses' END;
 PERFORM private.p32_keys(c,CASE WHEN op='putEstimate' THEN 'op estimate' ELSE 'op actual' END); e:=c->(CASE WHEN op='putEstimate' THEN 'estimate' ELSE 'actual' END);
 PERFORM private.p32_entity(e,CASE WHEN op='putEstimate' THEN 'id itemId category unitAmountVnd basis customQuantity active description provenance' ELSE 'id itemId amountVnd category paidOn description sourceItemSnapshot provenance' END);
 SELECT coalesce(jsonb_agg(CASE WHEN value->'id'=e->'id' THEN e ELSE value END ORDER BY ordinality),'[]'),count(*) FILTER(WHERE value->'id'=e->'id') INTO ordered,before_count FROM jsonb_array_elements(doc->kind) WITH ORDINALITY;
 IF before_count=0 THEN ordered:=ordered||jsonb_build_array(e); END IF; doc:=jsonb_set(doc,ARRAY[kind],ordered);
 WHEN 'deleteActual' THEN PERFORM private.p32_keys(c,'op expenseId'); PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'actualExpenses') e WHERE e->'id'=c->'expenseId'),'invalid_command');
 SELECT coalesce(jsonb_agg(value ORDER BY ordinality),'[]') INTO ordered FROM jsonb_array_elements(doc->'actualExpenses') WITH ORDINALITY WHERE value->'id'<>c->'expenseId'; doc:=jsonb_set(doc,'{actualExpenses}',ordered);
 WHEN 'acknowledgeIssue' THEN PERFORM private.p32_keys(c,'op exception'); e:=c->'exception'; PERFORM private.p32_entity(e,'issueCode itemIds reason fingerprint');
 PERFORM private.p32_require(private.p32_nonblank(e->>'reason') AND EXISTS(SELECT 1 FROM jsonb_array_elements(private.p32_issues(doc)) i WHERE i->>'issueCode'=e->>'issueCode' AND i->>'fingerprint'=e->>'fingerprint' AND jsonb_array_length(i->'itemIds')=jsonb_array_length(e->'itemIds') AND i->'itemIds' @> e->'itemIds' AND e->'itemIds' @> i->'itemIds'),'invalid_command');
 SELECT coalesce(jsonb_agg(value ORDER BY ordinality),'[]') INTO ordered FROM jsonb_array_elements(doc->'exceptions') WITH ORDINALITY WHERE value->>'fingerprint'<>e->>'fingerprint'; doc:=jsonb_set(doc,'{exceptions}',ordered||jsonb_build_array(e));
 ELSE RAISE EXCEPTION 'invalid_command'; END CASE; END LOOP;
 SELECT coalesce(jsonb_agg(i.value ORDER BY d.ordinality,(i.value->>'position')::integer),'[]') INTO ordered FROM jsonb_array_elements(doc->'items') i JOIN jsonb_array_elements(doc->'days') WITH ORDINALITY d ON d.value->'id'=i.value->'dayId';
 PERFORM private.p32_require(jsonb_array_length(ordered)=jsonb_array_length(doc->'items'),'invalid_command'); doc:=jsonb_set(doc,'{items}',ordered);
 issues:=private.p32_issues(doc);
 SELECT coalesce(jsonb_agg(e.value ORDER BY e.ordinality),'[]') INTO ordered FROM jsonb_array_elements(doc->'exceptions') WITH ORDINALITY e
 WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(issues) i WHERE i->>'issueCode'=e.value->>'issueCode' AND i->>'fingerprint'=e.value->>'fingerprint');
 RETURN jsonb_set(doc,'{exceptions}',ordered); END $f$;

-- User row first prevents the FK/cascade-versus-mutation lock inversion.
CREATE FUNCTION private.p32_owner(writing boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE owner uuid:=auth.uid(); claims jsonb:=coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb;
BEGIN
 PERFORM private.p32_require(owner IS NOT NULL AND current_setting('role',true)='authenticated' AND claims->>'role'='authenticated' AND claims->'is_anonymous' IS DISTINCT FROM 'true'::jsonb,'unauthorized');
 PERFORM 1 FROM auth.users WHERE id=owner FOR KEY SHARE;
 PERFORM private.p32_require(FOUND,'unauthorized');
 IF writing THEN PERFORM pg_advisory_xact_lock(hashtextextended(owner::text,73302));
 ELSE PERFORM pg_advisory_xact_lock_shared(hashtextextended(owner::text,73302)); END IF;
 RETURN owner; END $f$;
CREATE FUNCTION private.p32_utc(v timestamptz) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT to_char(v AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') $f$;
CREATE FUNCTION private.p32_head(trip uuid,owner uuid) RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 SELECT jsonb_build_object('tripId',d.trip_id,'ownerId',d.owner_id,'version',d.content_version,
 'payloadText',d.payload_text,'contentDigest',d.content_digest,'fetchedAt',private.p32_utc(clock_timestamp()))
 FROM private.editable_trip_documents d JOIN public.trips t ON t.id=d.trip_id AND t.user_id=d.owner_id
 WHERE d.trip_id=trip AND d.owner_id=owner $f$;
CREATE FUNCTION private.p32_reply(owner uuid,request uuid) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE r private.editable_trip_mutations%ROWTYPE; head jsonb;
BEGIN
 SELECT * INTO r FROM private.editable_trip_mutations m WHERE m.owner_id=owner AND m.request_id=request;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','not_found','receipt',NULL,'head',NULL); END IF;
 PERFORM 1 FROM public.trips WHERE id=r.trip_id AND user_id=owner FOR SHARE;
 -- Read again after the trip lock; do not attach a pre-delete receipt to a missing head.
 SELECT * INTO r FROM private.editable_trip_mutations m WHERE m.owner_id=owner AND m.request_id=request;
 head:=private.p32_head(r.trip_id,owner);
 RETURN jsonb_build_object('status',CASE WHEN r.deleted THEN 'deleted' ELSE 'committed' END,
 'head',CASE WHEN r.deleted THEN NULL ELSE head END,
 'receipt',jsonb_build_object('requestId',r.request_id,'ownerId',r.owner_id,'tripId',r.trip_id,'operation',r.operation,
 'requestDigest',r.request_digest,'contentDigest',r.content_digest,'resultVersion',r.result_version,'committedAt',private.p32_utc(r.committed_at),'sourceBinding',r.source_binding));
END $f$;
CREATE FUNCTION private.p32_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE trip uuid; owned uuid; versioned boolean; permitted boolean;
BEGIN
 IF TG_TABLE_NAME='trip_activities' THEN
  -- Parent removal is the only trusted activity-delete cascade. Generic deletes
  -- still see a live parent and cannot use this branch.
  IF TG_OP='DELETE' AND NOT EXISTS(SELECT 1 FROM public.trips WHERE id=OLD.trip_id) THEN RETURN OLD; END IF;
  IF TG_OP<>'INSERT' AND EXISTS(SELECT 1 FROM private.editable_trip_documents d WHERE d.trip_id=OLD.trip_id) THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  IF TG_OP<>'DELETE' AND EXISTS(SELECT 1 FROM private.editable_trip_documents d WHERE d.trip_id=NEW.trip_id) THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
 END IF;
 IF TG_OP='INSERT' THEN
  IF NEW.ai_plan_data->>'schemaVersion'='2' THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  IF NEW.canonical_payload_text IS NOT NULL AND NEW.canonical_payload_text IS JSON THEN
   IF NEW.canonical_payload_text::jsonb->>'schemaVersion'='2' THEN RAISE EXCEPTION 'versioned_write_required'; END IF;
  END IF;
  RETURN NEW;
 END IF;
 trip:=OLD.id; owned:=OLD.user_id;
 SELECT EXISTS(SELECT 1 FROM private.editable_trip_documents d WHERE d.trip_id=trip) INTO versioned;
 IF NOT versioned THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF; END IF;
 IF TG_OP='DELETE' AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=owned) THEN RETURN OLD; END IF;
 SELECT EXISTS(SELECT 1 FROM private.editable_trip_write_permits p WHERE p.backend_pid=pg_backend_pid() AND p.transaction_id=pg_current_xact_id() AND p.trip_id=trip AND p.operation=TG_OP) INTO permitted;
 PERFORM private.p32_require(permitted,'versioned_write_required');
 IF TG_OP='UPDATE' THEN
  PERFORM private.p32_require(NEW.id=OLD.id AND NEW.user_id=OLD.user_id AND NEW.ai_plan_data='{}'::jsonb AND NEW.canonical_payload_text IS NULL,'versioned_write_required');
  RETURN NEW;
 END IF; RETURN OLD; END $f$;
CREATE TRIGGER p32_trip_guard BEFORE INSERT OR UPDATE OR DELETE ON public.trips FOR EACH ROW EXECUTE FUNCTION private.p32_guard();
 CREATE TRIGGER p32_activity_guard BEFORE INSERT OR UPDATE OR DELETE ON public.trip_activities FOR EACH ROW EXECUTE FUNCTION private.p32_guard();

-- Normalize legacy DTO defaults only for source-digest verification; never rewrite V1.
CREATE FUNCTION private.p32_defaults(v jsonb,defaults jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT jsonb_object_agg(key,coalesce(nullif(v->key,'null'::jsonb),value)) FROM jsonb_each(defaults) $f$;
CREATE FUNCTION private.p32_legacy_plan(v jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE result jsonb; d jsonb; a jsonb; days jsonb:='[]'; activities jsonb; destinations jsonb:='[]'; transports jsonb:='[]';
BEGIN
 IF v IS NULL OR v='null'::jsonb THEN RETURN 'null'::jsonb; END IF;
 result:=private.p32_defaults(v,'{"winnerId":"","topDestinations":[],"transportOptions":[],"itineraryDays":[],"budgetBreakdown":null,"aiExplanation":"","dataSources":{},"assumptions":[]}'::jsonb);
 FOR d IN SELECT * FROM jsonb_array_elements(result->'topDestinations') LOOP
 d:=private.p32_defaults(d,'{"id":"","name":"","totalScore":0.0,"normalizedScores":{},"scoreContributions":{},"estimatedCostVnd":0,"weatherSource":"","avgTempMax":0.0,"avgPrecipitation":0.0,"latitude":null,"longitude":null,"region":""}'::jsonb);
 d:=jsonb_set(d,'{estimatedCostVnd}',to_jsonb(trunc((d->>'estimatedCostVnd')::numeric))); destinations:=destinations||jsonb_build_array(d); END LOOP;
 FOR d IN SELECT * FROM jsonb_array_elements(result->'transportOptions') LOOP
 d:=private.p32_defaults(d,'{"mode":"","displayName":"","priceTotalVnd":0,"durationHours":0.0,"comfortScore":0,"paretoOptimal":false,"tradeoffType":"","recommendationReason":""}'::jsonb)||
 jsonb_build_object('paretoOptimal',coalesce(nullif(d->'paretoOptimal','null'::jsonb),nullif(d->'isParetoOptimal','null'::jsonb),'false'::jsonb));
 d:=d||jsonb_build_object('priceTotalVnd',trunc((d->>'priceTotalVnd')::numeric),'comfortScore',trunc((d->>'comfortScore')::numeric)); transports:=transports||jsonb_build_array(d); END LOOP;
 FOR d IN SELECT * FROM jsonb_array_elements(result->'itineraryDays') LOOP
 d:=private.p32_defaults(d,'{"day":1,"title":"","activities":[]}'::jsonb); activities:='[]';
 FOR a IN SELECT * FROM jsonb_array_elements(d->'activities') LOOP
 a:=private.p32_defaults(a,'{"time":"","title":"","costVnd":0,"durationHours":0.0}'::jsonb);
 a:=jsonb_set(a,'{costVnd}',to_jsonb(trunc((a->>'costVnd')::numeric))); activities:=activities||jsonb_build_array(a); END LOOP;
 days:=days||jsonb_build_array(jsonb_set(d,'{activities}',activities)); END LOOP;
 IF result->'budgetBreakdown'<>'null'::jsonb THEN
 d:=private.p32_defaults(result->'budgetBreakdown','{"transport":0,"accommodation":0,"food":0,"attractions":0,"remainingSafetyMargin":0}'::jsonb);
 SELECT jsonb_object_agg(key,to_jsonb(trunc(value::text::numeric))) INTO d FROM jsonb_each(d); result:=jsonb_set(result,'{budgetBreakdown}',d); END IF;
 RETURN result||jsonb_build_object('topDestinations',destinations,'transportOptions',transports,'itineraryDays',days);
END $f$;
CREATE FUNCTION private.p32_copy_hash(source_trip uuid,owner uuid) RETURNS text LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE t public.trips%ROWTYPE; payload jsonb; plan jsonb; raw text;
BEGIN
 SELECT * INTO t FROM public.trips WHERE id=source_trip AND user_id=owner FOR SHARE;
 PERFORM private.p32_require(FOUND AND NOT EXISTS(SELECT 1 FROM private.editable_trip_documents WHERE trip_id=source_trip),'source_unavailable');
 IF t.canonical_payload_text IS NOT NULL THEN
 PERFORM private.validate_guest_payload_v1(t.canonical_payload_text);
 RETURN encode(extensions.digest(convert_to(t.canonical_payload_text,'UTF8'),'sha256'),'hex'); END IF;
 payload:=t.ai_plan_data;
 IF payload->>'schemaVersion'='1' THEN
 payload:=jsonb_set(payload,'{plan}',private.p32_legacy_plan(payload->'plan'));
 ELSE
 PERFORM private.p32_require(jsonb_typeof(payload)='object' AND (payload ? 'winnerId' OR payload ? 'topDestinations' OR payload ? 'itineraryDays'),'source_unavailable');
 plan:=private.p32_legacy_plan(payload);
 payload:=jsonb_build_object('schemaVersion',1,'request',NULL,'plan',plan,'metadata',jsonb_build_object(
 'title',CASE WHEN private.p32_nonblank(t.title) THEN t.title END,'destinationId',plan->'winnerId',
 'destinationName',CASE WHEN private.p32_nonblank(t.destination_name) THEN t.destination_name END,'startDate',NULL,'endDate',NULL,'timezone',NULL));
 END IF;
 raw:=private.p32_canonical(payload); PERFORM private.validate_guest_payload_v1(raw);
 RETURN encode(extensions.digest(convert_to(raw,'UTF8'),'sha256'),'hex');
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'source_unavailable'; END $f$;

CREATE FUNCTION public.create_editable_trip_v2(p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(true); body jsonb; doc jsonb; source jsonb; trip uuid; old private.editable_trip_mutations%ROWTYPE; source_digest text;
BEGIN
 PERFORM private.p32_require(p_request_id IS NOT NULL AND p_request_digest ~ '^[0-9a-f]{64}$' AND octet_length(p_request_text)<=3145728,'invalid_request');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(p_request_text,'UTF8'),'sha256'),'hex')=p_request_digest,'invalid_request');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.operation='create' AND old.request_digest=p_request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 body:=private.p32_parse(p_request_text,3145728); PERFORM private.p32_keys(body,'payloadText contentDigest sourceBinding');
 PERFORM private.p32_text(body->'payloadText',1048576); PERFORM private.p32_hash(body->'contentDigest');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(body->>'payloadText','UTF8'),'sha256'),'hex')=body->>'contentDigest','invalid_request');
 doc:=private.p32_validate(body->>'payloadText',true); source:=nullif(body->'sourceBinding','null'::jsonb);
 IF source IS NOT NULL THEN
 CASE source->>'kind'
 WHEN 'guest_import' THEN PERFORM private.p32_keys(source,'kind deviceScope draftId sourceRevision'); PERFORM private.p32_text(source->'deviceScope',2147483647); PERFORM private.p32_text(source->'draftId',2147483647); PERFORM private.p32_int(source->'sourceRevision',1,9007199254740991);
 PERFORM private.p32_require(NOT EXISTS(SELECT 1 FROM private.editable_trip_mutations m WHERE m.owner_id=owner AND m.source_binding->>'kind'='guest_import' AND m.source_binding->>'deviceScope'=source->>'deviceScope' AND m.source_binding->>'draftId'=source->>'draftId' AND m.source_binding->>'sourceRevision'=source->>'sourceRevision'),'source_identity_conflict');
 WHEN 'v1_copy' THEN PERFORM private.p32_keys(source,'kind sourceTripId sourceDigest'); PERFORM private.p32_id(source->'sourceTripId'); PERFORM private.p32_hash(source->'sourceDigest');
 source_digest:=private.p32_copy_hash((source->>'sourceTripId')::uuid,owner); PERFORM private.p32_require(source_digest=source->>'sourceDigest','source_unavailable');
 PERFORM private.p32_require(doc#>>'{source,kind}'='manual_v1_copy' AND doc#>>'{source,sourceId}'=source->>'sourceTripId' AND doc#>>'{source,sourceDigest}'=source_digest,'invalid_document');
 ELSE RAISE EXCEPTION 'invalid_request'; END CASE; END IF;
 IF doc#>>'{source,kind}'='manual_v1_copy' AND source->>'kind' IS DISTINCT FROM 'v1_copy' THEN
 PERFORM private.p32_id(doc#>'{source,sourceId}'); source_digest:=private.p32_copy_hash((doc#>>'{source,sourceId}')::uuid,owner);
 PERFORM private.p32_require(source_digest=doc#>>'{source,sourceDigest}','source_unavailable'); END IF;
 trip:=gen_random_uuid();
 INSERT INTO public.trips(id,user_id,title,destination_name,num_days,budget_total,start_date,end_date,status,ai_plan_data,canonical_payload_text)
 VALUES(trip,owner,doc#>>'{input,title}',doc#>>'{input,destinationName}',jsonb_array_length(doc->'days'),(doc#>>'{input,totalBudgetVnd}')::numeric,NULL,NULL,'planning','{}',NULL);
 INSERT INTO private.editable_trip_documents(trip_id,owner_id,content_version,payload_text,content_digest)
 VALUES(trip,owner,1,body->>'payloadText',body->>'contentDigest');
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,result_version,request_digest,content_digest,source_binding)
 VALUES(owner,p_request_id,'create',trip,1,p_request_digest,body->>'contentDigest',source);
 RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.update_editable_trip_v2(p_trip_id uuid,p_expected_version bigint,p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(true); old private.editable_trip_mutations%ROWTYPE; d private.editable_trip_documents%ROWTYPE; body jsonb; doc jsonb; replay jsonb;
BEGIN
 PERFORM private.p32_require(p_trip_id IS NOT NULL AND p_request_id IS NOT NULL AND p_expected_version BETWEEN 1 AND 9007199254740990 AND octet_length(p_request_text)<=3145728 AND p_request_digest ~ '^[0-9a-f]{64}$','invalid_request');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(p_request_text,'UTF8'),'sha256'),'hex')=p_request_digest,'invalid_request');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.operation='update' AND old.trip_id=p_trip_id AND old.expected_version=p_expected_version AND old.request_digest=p_request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner FOR UPDATE; PERFORM private.p32_require(FOUND,'trip_unavailable');
 SELECT * INTO d FROM private.editable_trip_documents WHERE trip_id=p_trip_id AND owner_id=owner; PERFORM private.p32_require(FOUND,'trip_unavailable');
 PERFORM private.p32_require(d.content_version=p_expected_version,'version_conflict');
 body:=private.p32_parse(p_request_text,3145728); PERFORM private.p32_keys(body,'payloadText contentDigest commands'); PERFORM private.p32_hash(body->'contentDigest');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(body->>'payloadText','UTF8'),'sha256'),'hex')=body->>'contentDigest','invalid_request');
 doc:=private.p32_validate(body->>'payloadText',true); replay:=private.p32_replay(d.payload_text::jsonb,body->'commands');
 PERFORM private.p32_require(replay=doc,'invalid_request'); PERFORM private.p32_validate(private.p32_canonical(replay),true);
 INSERT INTO private.editable_trip_write_permits VALUES(pg_backend_pid(),pg_current_xact_id(),p_trip_id,'UPDATE');
 UPDATE public.trips SET title=doc#>>'{input,title}',destination_name=doc#>>'{input,destinationName}',num_days=jsonb_array_length(doc->'days'),budget_total=(doc#>>'{input,totalBudgetVnd}')::numeric WHERE id=p_trip_id AND user_id=owner;
 UPDATE private.editable_trip_documents SET content_version=content_version+1,payload_text=body->>'payloadText',content_digest=body->>'contentDigest',updated_at=clock_timestamp() WHERE trip_id=p_trip_id AND owner_id=owner;
 DELETE FROM private.editable_trip_write_permits WHERE backend_pid=pg_backend_pid() AND transaction_id=pg_current_xact_id() AND trip_id=p_trip_id AND operation='UPDATE';
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,expected_version,result_version,request_digest,content_digest)
 VALUES(owner,p_request_id,'update',p_trip_id,p_expected_version,p_expected_version+1,p_request_digest,body->>'contentDigest');
 RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.delete_editable_trip_v2(p_trip_id uuid,p_expected_version bigint,p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(true); old private.editable_trip_mutations%ROWTYPE; version bigint; request_digest text;
BEGIN
 PERFORM private.p32_require(p_trip_id IS NOT NULL AND p_request_id IS NOT NULL AND p_expected_version BETWEEN 1 AND 9007199254740990,'invalid_request');
 request_digest:=encode(extensions.digest(convert_to(private.p32_canonical(jsonb_build_object('op','delete','tripId',p_trip_id,'expectedVersion',p_expected_version)),'UTF8'),'sha256'),'hex');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.operation='delete' AND old.trip_id=p_trip_id AND old.expected_version=p_expected_version AND old.request_digest=request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner FOR UPDATE; PERFORM private.p32_require(FOUND,'trip_unavailable');
 SELECT content_version INTO version FROM private.editable_trip_documents WHERE trip_id=p_trip_id AND owner_id=owner; PERFORM private.p32_require(FOUND,'trip_unavailable');
 PERFORM private.p32_require(version=p_expected_version,'version_conflict');
 INSERT INTO private.editable_trip_write_permits VALUES(pg_backend_pid(),pg_current_xact_id(),p_trip_id,'DELETE');
 DELETE FROM public.trips WHERE id=p_trip_id AND user_id=owner;
 DELETE FROM private.editable_trip_write_permits WHERE backend_pid=pg_backend_pid() AND transaction_id=pg_current_xact_id() AND trip_id=p_trip_id AND operation='DELETE';
 UPDATE private.editable_trip_mutations SET deleted=true WHERE owner_id=owner AND trip_id=p_trip_id;
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,expected_version,result_version,request_digest,deleted)
 VALUES(owner,p_request_id,'delete',p_trip_id,p_expected_version,p_expected_version+1,request_digest,true);
 RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.get_editable_trip_v2(p_trip_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(); head jsonb;
BEGIN PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner FOR SHARE;
 head:=private.p32_head(p_trip_id,owner);
 RETURN jsonb_build_object('status',CASE WHEN head IS NULL THEN 'unavailable' ELSE 'ready' END,'head',head); END $f$;
CREATE FUNCTION public.get_editable_mutation_v2(p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner();
BEGIN RETURN private.p32_reply(owner,p_request_id); END $f$;
CREATE FUNCTION public.list_owned_trips_v2(p_before_created_at timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL,p_limit integer DEFAULT 25) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(); rows jsonb; items jsonb; cursor jsonb;
BEGIN
 PERFORM private.p32_require(p_limit BETWEEN 1 AND 50 AND (p_before_created_at IS NULL)=(p_before_id IS NULL),'invalid_request');
 SELECT coalesce(jsonb_agg(jsonb_build_object('kind',CASE WHEN d.trip_id IS NULL THEN 'legacy_v1' ELSE 'editable_v2' END,
 'tripId',t.id,'ownerId',t.user_id,'title',t.title,'destinationName',t.destination_name,'createdAt',private.p32_utc(t.created_at),'version',d.content_version)
 ORDER BY t.created_at DESC,t.id DESC),'[]') INTO rows
 FROM (SELECT * FROM public.trips t WHERE t.user_id=owner AND (p_before_id IS NULL OR (t.created_at,t.id)<(p_before_created_at,p_before_id))
 ORDER BY t.created_at DESC,t.id DESC LIMIT p_limit+1) t LEFT JOIN private.editable_trip_documents d ON d.trip_id=t.id AND d.owner_id=t.user_id;
 SELECT coalesce(jsonb_agg(value ORDER BY ordinality),'[]') INTO items FROM jsonb_array_elements(rows) WITH ORDINALITY WHERE ordinality<=p_limit;
 cursor:=CASE WHEN jsonb_array_length(rows)>p_limit THEN jsonb_build_object('createdAt',items->(p_limit-1)->'createdAt','id',items->(p_limit-1)->'tripId') END;
 RETURN jsonb_build_object('items',items,'nextCursor',cursor); END $f$;

-- Default function grants can include anon/authenticated/service_role on Supabase.
-- Revoke them explicitly per new function; do not alter any existing B3 grants.
DO $acl$ DECLARE f record;
BEGIN FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='private' AND p.proname LIKE 'p32_%') OR (n.nspname='public' AND p.proname IN
 ('create_editable_trip_v2','update_editable_trip_v2','delete_editable_trip_v2','get_editable_trip_v2','get_editable_mutation_v2','list_owned_trips_v2')) LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.signature);
 END LOOP; END $acl$;
GRANT EXECUTE ON FUNCTION public.create_editable_trip_v2(uuid,text,text),public.update_editable_trip_v2(uuid,bigint,uuid,text,text),
 public.delete_editable_trip_v2(uuid,bigint,uuid),public.get_editable_trip_v2(uuid),public.get_editable_mutation_v2(uuid),
 public.list_owned_trips_v2(timestamptz,uuid,integer) TO authenticated;
COMMIT;
