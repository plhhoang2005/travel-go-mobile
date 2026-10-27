-- Migration: manual_dynamic_destination_ids
-- Replaces rigid 12-enum destinationId validation with dynamic published destination support.
-- Validates regex ^[a-z0-9][a-z0-9/-]{0,119}$, paired with nonblank destinationName <= 180 chars.
-- Enforces active publication membership on create, and historic published ID retention on update.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS private;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS canonical_payload_text text;

-- 1. Helper infrastructure & tables (idempotent setup)
CREATE TABLE IF NOT EXISTS private.editable_trip_documents(
  trip_id uuid PRIMARY KEY REFERENCES public.trips(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_version bigint NOT NULL CHECK(content_version BETWEEN 1 AND 9007199254740991),
  payload_text text NOT NULL,
  content_digest text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS private.editable_trip_mutations(
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  operation text NOT NULL CHECK(operation IN ('create','update','delete')),
  trip_id uuid NOT NULL,
  expected_version bigint,
  result_version bigint NOT NULL,
  request_digest text NOT NULL,
  content_digest text,
  source_binding jsonb,
  deleted boolean NOT NULL DEFAULT false,
  committed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (owner_id, request_id)
);

CREATE TABLE IF NOT EXISTS private.editable_trip_write_permits(
  backend_pid integer NOT NULL,
  transaction_id xid8 NOT NULL,
  trip_id uuid NOT NULL,
  operation text NOT NULL,
  PRIMARY KEY(backend_pid, transaction_id, trip_id, operation)
);

CREATE OR REPLACE FUNCTION private.p32_require(ok boolean, code text DEFAULT 'assertion_failed') RETURNS void LANGUAGE plpgsql AS $f$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',code; END IF; END $f$;

CREATE OR REPLACE FUNCTION private.p32_nonblank(v text) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT btrim(v,E' \t\n\r\f\u000b\u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff')<>'' $f$;

CREATE OR REPLACE FUNCTION private.p32_keys(v jsonb,names text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN PERFORM private.p32_require(jsonb_typeof(v)='object' AND
 (SELECT array_agg(k ORDER BY k COLLATE "C") FROM jsonb_object_keys(v) k)=
 (SELECT array_agg(k ORDER BY k COLLATE "C") FROM unnest(string_to_array(names,' ')) k)); END $f$;

CREATE OR REPLACE FUNCTION private.p32_text(v jsonb,max_chars integer,blank boolean DEFAULT false,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND char_length(v#>>'{}')<=max_chars AND (blank OR private.p32_nonblank(v#>>'{}'))); END $f$;

CREATE OR REPLACE FUNCTION private.p32_int(v jsonb,lo numeric,hi numeric,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='number' AND v::text ~ '^-?(0|[1-9][0-9]*)$');
 PERFORM private.p32_require(v::text::numeric BETWEEN lo AND hi); END $f$;

CREATE OR REPLACE FUNCTION private.p32_enum(v jsonb,choices text,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND v#>>'{}'=ANY(string_to_array(choices,' '))); END $f$;

CREATE OR REPLACE FUNCTION private.p32_id(v jsonb,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND v#>>'{}' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'); END $f$;

CREATE OR REPLACE FUNCTION private.p32_hash(v jsonb,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND v#>>'{}' ~ '^[0-9a-f]{64}$'); END $f$;

CREATE OR REPLACE FUNCTION private.p32_date(v jsonb,nullable boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE t text:=v#>>'{}'; d date;
BEGIN IF nullable AND v='null'::jsonb THEN RETURN; END IF;
 PERFORM private.p32_require(jsonb_typeof(v)='string' AND t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND left(t,4)<>'0000');
 BEGIN d:=t::date; EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_document'; END;
 PERFORM private.p32_require(to_char(d,'YYYY-MM-DD')=t); END $f$;

CREATE OR REPLACE FUNCTION private.p32_list(v jsonb,maximum integer) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN PERFORM private.p32_require(jsonb_typeof(v)='array'); PERFORM private.p32_require(jsonb_array_length(v)<=maximum); END $f$;

CREATE OR REPLACE FUNCTION private.p32_walk(v json,depth integer DEFAULT 0) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE entry record; item json;
BEGIN PERFORM private.p32_require(depth<=32,'invalid_input');
 CASE json_typeof(v)
 WHEN 'object' THEN FOR entry IN SELECT * FROM json_each(v) LOOP PERFORM private.p32_walk(entry.value,depth+1); END LOOP;
 WHEN 'array' THEN FOR item IN SELECT * FROM json_array_elements(v) LOOP PERFORM private.p32_walk(item,depth+1); END LOOP;
 WHEN 'number' THEN PERFORM private.p32_require(v::text ~ '^-?(0|[1-9][0-9]*)$','invalid_input');
 PERFORM private.p32_require(v::text::numeric BETWEEN -9007199254740991 AND 9007199254740991,'invalid_input');
 ELSE NULL; END CASE; END $f$;

CREATE OR REPLACE FUNCTION private.p32_parse(raw text,max_bytes integer DEFAULT 1048576) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN PERFORM private.p32_require(raw IS NOT NULL AND octet_length(raw)<=max_bytes,'invalid_input');
 PERFORM private.p32_require(raw IS JSON WITH UNIQUE KEYS,'invalid_input');
 PERFORM private.p32_walk(raw::json); RETURN raw::jsonb;
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'invalid_input'; END $f$;

CREATE OR REPLACE FUNCTION private.p32_provenance(v jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE r jsonb; t text;
BEGIN PERFORM private.p32_keys(v,'quality sourceRefs observedAt'); PERFORM private.p32_enum(v->'quality','user_provided estimated unknown');
 PERFORM private.p32_list(v->'sourceRefs',1000);
 FOR r IN SELECT * FROM jsonb_array_elements(v->'sourceRefs') LOOP PERFORM private.p32_text(r,128); END LOOP;
 PERFORM private.p32_require((SELECT count(*)=count(DISTINCT x) FROM jsonb_array_elements(v->'sourceRefs') x));
 IF v->'observedAt'<>'null'::jsonb THEN
 t:=v->>'observedAt'; PERFORM private.p32_require(jsonb_typeof(v->'observedAt')='string' AND t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?Z$');
 PERFORM private.p32_date(to_jsonb(left(t,10))); PERFORM private.p32_require(to_char(t::timestamptz AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS')=left(t,19)); END IF; END $f$;

CREATE OR REPLACE FUNCTION private.p32_sortkey(v text) RETURNS bytea LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE i integer; cp integer; answer bytea:=''::bytea;
BEGIN FOR i IN 1..char_length(v) LOOP cp:=ascii(substr(v,i,1));
 IF cp>65535 THEN cp:=cp-65536; answer:=answer||decode(lpad(to_hex(55296+cp/1024),4,'0')||lpad(to_hex(56320+cp%1024),4,'0'),'hex');
 ELSE answer:=answer||decode(lpad(to_hex(cp),4,'0'),'hex'); END IF; END LOOP; RETURN answer; END $f$;

CREATE OR REPLACE FUNCTION private.p32_canonical(v jsonb,float_value boolean DEFAULT false) RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
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

CREATE OR REPLACE FUNCTION private.p32_issues(doc jsonb) RETURNS jsonb LANGUAGE sql SET search_path = public, pg_temp AS $f$
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
  ) c(code) WHERE c.code IS NOT NULL
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('issueCode',code,'itemIds',jsonb_build_array(a->'id',b->'id'),
  'fingerprint',encode(digest(convert_to(private.p32_canonical(jsonb_build_object('code',code,'itemIds',jsonb_build_array(a->'id',b->'id'),
  'scopedFields',jsonb_build_array(
    jsonb_build_object('date',(SELECT d->'date' FROM jsonb_array_elements(doc->'days') d WHERE d->'id'=a->'dayId'),'dayId',a->'dayId','endMinute',a->'endMinute','id',a->'id','position',a->'position','startMinute',a->'startMinute'),
    jsonb_build_object('date',(SELECT d->'date' FROM jsonb_array_elements(doc->'days') d WHERE d->'id'=b->'dayId'),'dayId',b->'dayId','endMinute',b->'endMinute','id',b->'id','position',b->'position','startMinute',b->'startMinute')
  ))),'UTF8'),'sha256'),'hex')) ORDER BY code,a->>'id',b->>'id'),'[]'::jsonb) FROM pairs $f$;

CREATE OR REPLACE FUNCTION private.p32_owner(writing boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE owner uuid:=auth.uid(); claims jsonb:=coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb;
BEGIN
 PERFORM private.p32_require(owner IS NOT NULL,'unauthorized');
 PERFORM 1 FROM auth.users WHERE id=owner;
 PERFORM private.p32_require(FOUND,'unauthorized');
 RETURN owner; END $f$;

CREATE OR REPLACE FUNCTION private.p32_utc(t timestamptz) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT to_char(t AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') $f$;

CREATE OR REPLACE FUNCTION private.p32_head(trip uuid,owner uuid) RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 SELECT jsonb_build_object('tripId',d.trip_id,'version',d.content_version,'payloadText',d.payload_text,'contentDigest',d.content_digest,'updatedAt',private.p32_utc(d.updated_at),'fetchedAt',private.p32_utc(clock_timestamp()))
 FROM private.editable_trip_documents d
 WHERE d.trip_id=trip AND d.owner_id=owner $f$;

CREATE OR REPLACE FUNCTION private.p32_reply(owner uuid,request uuid) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE r private.editable_trip_mutations%ROWTYPE; head jsonb;
BEGIN
 SELECT * INTO r FROM private.editable_trip_mutations m WHERE m.owner_id=owner AND m.request_id=request;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','not_found','receipt',NULL,'head',NULL); END IF;
 PERFORM 1 FROM public.trips WHERE id=r.trip_id AND user_id=owner;
 SELECT * INTO r FROM private.editable_trip_mutations m WHERE m.owner_id=owner AND m.request_id=request;
 head:=private.p32_head(r.trip_id,owner);
 RETURN jsonb_build_object('status',CASE WHEN r.deleted THEN 'deleted' ELSE 'committed' END,
 'head',CASE WHEN r.deleted THEN NULL ELSE head END,
 'receipt',jsonb_build_object('requestId',r.request_id,'ownerId',r.owner_id,'tripId',r.trip_id,'operation',r.operation,
 'requestDigest',r.request_digest,'contentDigest',r.content_digest,'resultVersion',r.result_version,'committedAt',private.p32_utc(r.committed_at),'sourceBinding',r.source_binding));
END $f$;

CREATE OR REPLACE FUNCTION private.p32_order(doc jsonb,dayid text,ordered jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 SELECT jsonb_set(doc,'{items}',coalesce((SELECT jsonb_agg(value ORDER BY ordinality) FROM jsonb_array_elements(doc->'items') WITH ORDINALITY WHERE value->>'dayId'<>dayid),'[]')||
 coalesce((SELECT jsonb_agg(value||jsonb_build_object('position',ordinality-1) ORDER BY ordinality) FROM jsonb_array_elements(ordered) WITH ORDINALITY),'[]')) $f$;

CREATE OR REPLACE FUNCTION private.p32_remove(doc jsonb,itemid text) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE old jsonb; day jsonb; result jsonb;
BEGIN SELECT value INTO old FROM jsonb_array_elements(doc->'items') WHERE value->>'id'=itemid; PERFORM private.p32_require(old IS NOT NULL,'invalid_command');
 SELECT value INTO day FROM jsonb_array_elements(doc->'days') WHERE value->>'id'=old->>'dayId';
 result:=jsonb_set(doc,'{items}',coalesce((SELECT jsonb_agg(value ORDER BY ordinality) FROM jsonb_array_elements(doc->'items') WITH ORDINALITY WHERE value->>'id'<>itemid),'[]'));
 result:=jsonb_set(result,'{estimates}',coalesce((SELECT jsonb_agg(CASE WHEN value->>'itemId'=itemid THEN value||'{"active":false,"itemId":null}'::jsonb ELSE value END ORDER BY ordinality) FROM jsonb_array_elements(doc->'estimates') WITH ORDINALITY),'[]'));
 result:=jsonb_set(result,'{actualExpenses}',coalesce((SELECT jsonb_agg(CASE WHEN value->>'itemId'=itemid THEN value||jsonb_build_object('itemId',NULL,'sourceItemSnapshot',coalesce(nullif(value->'sourceItemSnapshot','null'::jsonb),jsonb_build_object('title',old->'title','dayId',old->'dayId','date',day->'date'))) ELSE value END ORDER BY ordinality) FROM jsonb_array_elements(doc->'actualExpenses') WITH ORDINALITY),'[]'));
 RETURN private.p32_order(result,old->>'dayId',coalesce((SELECT jsonb_agg(value ORDER BY (value->>'position')::integer) FROM jsonb_array_elements(result->'items') WHERE value->>'dayId'=old->>'dayId'),'[]')); END $f$;

CREATE OR REPLACE FUNCTION private.p32_insert(doc jsonb,item jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE ordered jsonb; pos integer;
BEGIN PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'days') d WHERE d->>'id'=item->>'dayId'),'invalid_command');
 PERFORM private.p32_int(item->'position',0,999); pos:=(item->>'position')::integer;
 SELECT coalesce(jsonb_agg(value ORDER BY (value->>'position')::integer),'[]') INTO ordered FROM jsonb_array_elements(doc->'items') WHERE value->>'dayId'=item->>'dayId';
 PERFORM private.p32_require(pos<=jsonb_array_length(ordered),'invalid_command'); ordered:=jsonb_insert(ordered,ARRAY[pos::text],item);
 RETURN private.p32_order(doc,item->>'dayId',ordered); END $f$;

CREATE OR REPLACE FUNCTION private.p32_move(doc jsonb,itemid text,dayid text,pos jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE old jsonb; result jsonb;
BEGIN SELECT value INTO old FROM jsonb_array_elements(doc->'items') WHERE value->>'id'=itemid; PERFORM private.p32_require(old IS NOT NULL,'invalid_command');
 result:=jsonb_set(doc,'{items}',coalesce((SELECT jsonb_agg(value ORDER BY ordinality) FROM jsonb_array_elements(doc->'items') WITH ORDINALITY WHERE value->>'id'<>itemid),'[]'));
 result:=private.p32_order(result,old->>'dayId',coalesce((SELECT jsonb_agg(value ORDER BY (value->>'position')::integer) FROM jsonb_array_elements(result->'items') WHERE value->>'dayId'=old->>'dayId'),'[]'));
 RETURN private.p32_insert(result,old||jsonb_build_object('dayId',dayid,'position',pos)); END $f$;

CREATE OR REPLACE FUNCTION private.p32_entity(v jsonb,names text) RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE e record; x jsonb; nullable boolean;
BEGIN
 PERFORM private.p32_keys(v,names);
 FOR e IN SELECT * FROM jsonb_each(v) LOOP
 nullable:=e.key=ANY(string_to_array('destinationId destinationName startDate endDate placeId itemId startMinute endMinute unitAmountVnd customQuantity observedAt sourceItemSnapshot date',' '));
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

CREATE OR REPLACE FUNCTION private.p32_replay(base jsonb,commands jsonb) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
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
 (SELECT count(*)=count(DISTINCT x) FROM jsonb_array_elements(c->'orderedItemIds') x),'invalid_command');
 SELECT jsonb_agg((SELECT value FROM jsonb_array_elements(doc->'items') WHERE value->'id'=id) ORDER BY ordinality) INTO ordered FROM jsonb_array_elements(c->'orderedItemIds') WITH ORDINALITY AS o(id,ordinality);
 doc:=private.p32_order(doc,c->>'dayId',ordered);
 ELSE RAISE EXCEPTION 'invalid_command'; END CASE; END LOOP; RETURN doc; END $f$;

-- 2. Destination ID validation and publication membership helper
CREATE OR REPLACE FUNCTION private.is_valid_destination_id(
  dest_id text,
  require_active boolean DEFAULT false
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private_discovery_admin, pg_temp
AS $$
DECLARE
  v_legacy_ids text := 'ha-noi ha-long sa-pa ninh-binh hue da-nang hoi-an nha-trang da-lat ho-chi-minh phu-quoc can-tho';
  v_active_version bigint;
BEGIN
  IF dest_id IS NULL THEN
    RETURN false;
  END IF;

  -- Syntax check: ^[a-z0-9][a-z0-9/-]{0,119}$
  IF dest_id !~ '^[a-z0-9][a-z0-9/-]{0,119}$' THEN
    RETURN false;
  END IF;

  -- Legacy IDs are always supported as active and historical
  IF dest_id = ANY(string_to_array(v_legacy_ids, ' ')) THEN
    RETURN true;
  END IF;

  -- If require_active = true, must match an active destination in discovery_release_manifest
  IF require_active THEN
    SELECT version INTO v_active_version
    FROM public.discovery_release_manifest
    WHERE id = 'current';

    IF v_active_version IS NULL THEN
      -- No active release exists yet; dynamic IDs are not active
      RETURN false;
    END IF;

    RETURN EXISTS (
      SELECT 1
      FROM private_discovery_admin.releases r
      JOIN private_discovery_admin.release_candidates c ON c.preview_id = r.candidate_id,
      jsonb_array_elements(c.payload_text::jsonb -> 'catalogue' -> 'destinations') d
      WHERE r.version = v_active_version
        AND d->>'id' = dest_id
    );
  END IF;

  -- If require_active = false, permit any historical released destination
  RETURN EXISTS (
    SELECT 1
    FROM private_discovery_admin.releases r
    JOIN private_discovery_admin.release_candidates c ON c.preview_id = r.candidate_id,
    jsonb_array_elements(c.payload_text::jsonb -> 'catalogue' -> 'destinations') d
    WHERE d->>'id' = dest_id
  );
END;
$$;

-- 3. Replace private.p32_validate to allow dynamic destination IDs
CREATE OR REPLACE FUNCTION private.p32_validate(raw text, account_save boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE doc jsonb:=private.p32_parse(raw); inp jsonb; d jsonb; i jsonb; e jsonb; x jsonb; snap jsonb; kind text; idx integer:=0;
 ids text[]:='{}'; dayids text[]:='{}'; active_ids text[]:='{}'; expenseids text[]; start_day date; end_day date;
 estimate numeric:=0; actual numeric:=0; amount numeric; quantity numeric; issues jsonb;
BEGIN
 IF doc->'schemaVersion' IS DISTINCT FROM '2'::jsonb THEN RAISE EXCEPTION 'unsupported_schema'; END IF;
 PERFORM private.p32_keys(doc,'schemaVersion input days items estimates actualExpenses exceptions source'); inp:=doc->'input';
 PERFORM private.p32_keys(inp,'title destinationId destinationName startDate endDate timezone origin travelerCount totalBudgetVnd interests priority');
 PERFORM private.p32_text(inp->'title',200,NOT account_save); PERFORM private.p32_text(inp->'origin',200,NOT account_save);
 
 -- Dynamic destination ID validation:
 IF inp->'destinationId' IS NOT NULL AND inp->'destinationId' <> 'null'::jsonb THEN
   PERFORM private.p32_require(
     jsonb_typeof(inp->'destinationId') = 'string' AND
     inp->>'destinationId' ~ '^[a-z0-9][a-z0-9/-]{0,119}$',
     'invalid_input'
   );
   PERFORM private.p32_text(inp->'destinationName', 180, false, false);
   PERFORM private.p32_require(private.p32_nonblank(inp->>'destinationName'), 'invalid_input');
 ELSE
   IF account_save THEN
     RAISE EXCEPTION 'invalid_input';
   END IF;
   PERFORM private.p32_text(inp->'destinationName', 180, false, true);
 END IF;

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
 PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'exceptions') AS exception_row(value) WHERE exception_row.value->>'issueCode'=i->>'issueCode' AND exception_row.value->>'fingerprint'=i->>'fingerprint'
 AND jsonb_array_length(exception_row.value->'itemIds')=jsonb_array_length(i->'itemIds') AND (exception_row.value->'itemIds') @> (i->'itemIds') AND private.p32_nonblank(exception_row.value->>'reason')));
 END LOOP; END IF; RETURN doc; END $f$;

-- 4. Replace public.create_editable_trip_v2 to enforce active destination membership
CREATE OR REPLACE FUNCTION public.create_editable_trip_v2(p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, private, pg_temp AS $f$
DECLARE owner uuid:=private.p32_owner(true); body jsonb; doc jsonb; source jsonb; trip uuid; old private.editable_trip_mutations%ROWTYPE; source_digest text;
BEGIN
 PERFORM private.p32_require(p_request_id IS NOT NULL AND p_request_digest ~ '^[0-9a-f]{64}$' AND octet_length(p_request_text)<=3145728,'invalid_request');
 PERFORM private.p32_require(encode(digest(convert_to(p_request_text,'UTF8'),'sha256'),'hex')=p_request_digest,'invalid_request');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.operation='create' AND old.request_digest=p_request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 body:=private.p32_parse(p_request_text,3145728); PERFORM private.p32_keys(body,'payloadText contentDigest sourceBinding');
 PERFORM private.p32_text(body->'payloadText',1048576); PERFORM private.p32_hash(body->'contentDigest');
 PERFORM private.p32_require(encode(digest(convert_to(body->>'payloadText','UTF8'),'sha256'),'hex')=body->>'contentDigest','invalid_request');
 doc:=private.p32_validate(body->>'payloadText',true); source:=nullif(body->'sourceBinding','null'::jsonb);

 -- Publication membership check: new trips must select an active published or legacy destination
 IF doc#>>'{input,destinationId}' IS NOT NULL THEN
   PERFORM private.p32_require(
     private.is_valid_destination_id(doc#>>'{input,destinationId}', true),
     'invalid_document'
   );
 END IF;

 trip:=gen_random_uuid();
 INSERT INTO public.trips(id,user_id,title,destination_name,num_days,budget_total,start_date,end_date,status,ai_plan_data,canonical_payload_text)
 VALUES(trip,owner,doc#>>'{input,title}',doc#>>'{input,destinationName}',jsonb_array_length(doc->'days'),(doc#>>'{input,totalBudgetVnd}')::numeric,NULL,NULL,'planning','{}',NULL);
 INSERT INTO private.editable_trip_documents(trip_id,owner_id,content_version,payload_text,content_digest)
 VALUES(trip,owner,1,body->>'payloadText',body->>'contentDigest');
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,result_version,request_digest,content_digest,source_binding)
 VALUES(owner,p_request_id,'create',trip,1,p_request_digest,body->>'contentDigest',source);
 RETURN private.p32_reply(owner,p_request_id); END $f$;

-- 5. Replace public.update_editable_trip_v2 to handle active vs historic destination IDs
CREATE OR REPLACE FUNCTION public.update_editable_trip_v2(p_trip_id uuid,p_expected_version bigint,p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, private, pg_temp AS $f$
DECLARE owner uuid:=private.p32_owner(true); old private.editable_trip_mutations%ROWTYPE; d private.editable_trip_documents%ROWTYPE; body jsonb; doc jsonb; replay jsonb;
BEGIN
 PERFORM private.p32_require(p_trip_id IS NOT NULL AND p_request_id IS NOT NULL AND p_expected_version BETWEEN 1 AND 9007199254740990 AND octet_length(p_request_text)<=3145728 AND p_request_digest ~ '^[0-9a-f]{64}$','invalid_request');
 PERFORM private.p32_require(encode(digest(convert_to(p_request_text,'UTF8'),'sha256'),'hex')=p_request_digest,'invalid_request');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.operation='update' AND old.trip_id=p_trip_id AND old.expected_version=p_expected_version AND old.request_digest=p_request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner; PERFORM private.p32_require(FOUND,'trip_unavailable');
 SELECT * INTO d FROM private.editable_trip_documents WHERE trip_id=p_trip_id AND owner_id=owner; PERFORM private.p32_require(FOUND,'trip_unavailable');
 PERFORM private.p32_require(d.content_version=p_expected_version,'version_conflict');
 body:=private.p32_parse(p_request_text,3145728); PERFORM private.p32_keys(body,'payloadText contentDigest commands'); PERFORM private.p32_hash(body->'contentDigest');
 PERFORM private.p32_require(encode(digest(convert_to(body->>'payloadText','UTF8'),'sha256'),'hex')=body->>'contentDigest','invalid_request');
 doc:=private.p32_validate(body->>'payloadText',true); replay:=private.p32_replay(d.payload_text::jsonb,body->'commands');
 PERFORM private.p32_require(replay=doc,'invalid_request'); PERFORM private.p32_validate(private.p32_canonical(replay),true);

 -- Destination publication membership check:
 -- If unchanged, permit valid historical released ID.
 -- If changed to a new destination, require that destination to be currently active.
 IF doc#>>'{input,destinationId}' IS NOT NULL THEN
   IF doc#>>'{input,destinationId}' IS DISTINCT FROM (d.payload_text::jsonb)#>>'{input,destinationId}' THEN
     PERFORM private.p32_require(
       private.is_valid_destination_id(doc#>>'{input,destinationId}', true),
       'invalid_document'
     );
   ELSE
     PERFORM private.p32_require(
       private.is_valid_destination_id(doc#>>'{input,destinationId}', false),
       'invalid_document'
     );
   END IF;
 END IF;

 UPDATE public.trips SET title=doc#>>'{input,title}',destination_name=doc#>>'{input,destinationName}',num_days=jsonb_array_length(doc->'days'),budget_total=(doc#>>'{input,totalBudgetVnd}')::numeric WHERE id=p_trip_id AND user_id=owner;
 UPDATE private.editable_trip_documents SET content_version=content_version+1,payload_text=body->>'payloadText',content_digest=body->>'contentDigest',updated_at=clock_timestamp() WHERE trip_id=p_trip_id AND owner_id=owner;
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,expected_version,result_version,request_digest,content_digest)
 VALUES(owner,p_request_id,'update',p_trip_id,p_expected_version,p_expected_version+1,p_request_digest,body->>'contentDigest');
 RETURN private.p32_reply(owner,p_request_id); END $f$;
