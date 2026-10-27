-- Forward C5: named manual destinations; schema-qualified pgcrypto.
-- Restore V2 owner/locking/write-permit/head contracts lost by the dynamic-ID
-- replacement, while retaining published/historical destination membership.
-- Historical files stay unchanged. Apply to cloud only with separate approval.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
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
  'fingerprint',encode(extensions.digest(convert_to(private.p32_canonical(jsonb_build_object('code',code,'itemIds',jsonb_build_array(a->'id',b->'id'),
  'scopedFields',jsonb_build_array(
    jsonb_build_object('date',(SELECT d->'date' FROM jsonb_array_elements(doc->'days') d WHERE d->'id'=a->'dayId'),'dayId',a->'dayId','endMinute',a->'endMinute','id',a->'id','position',a->'position','startMinute',a->'startMinute'),
    jsonb_build_object('date',(SELECT d->'date' FROM jsonb_array_elements(doc->'days') d WHERE d->'id'=b->'dayId'),'dayId',b->'dayId','endMinute',b->'endMinute','id',b->'id','position',b->'position','startMinute',b->'startMinute')
  ))),'UTF8'),'sha256'),'hex')) ORDER BY code,a->>'id',b->>'id'),'[]'::jsonb) FROM pairs $f$;

CREATE OR REPLACE FUNCTION private.p32_owner(writing boolean DEFAULT false)
    RETURNS uuid
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $f$
    DECLARE
      owner uuid := auth.uid();
      claims jsonb := coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb;
    BEGIN
      PERFORM private.p32_require(
        owner IS NOT NULL
        AND current_setting('role', true) = 'authenticated'
        AND claims->>'role' = 'authenticated'
        AND claims->'is_anonymous' IS DISTINCT FROM 'true'::jsonb,
        'unauthorized'
      );

      -- Check account is currently enabled via private_admin predicate
      PERFORM private.p32_require(private_admin.current_account_enabled(), 'account_locked');

      PERFORM 1 FROM auth.users WHERE id = owner FOR KEY SHARE;
      PERFORM private.p32_require(FOUND, 'unauthorized');

      IF writing THEN
        PERFORM pg_advisory_xact_lock(hashtextextended(owner::text, 73302));
      ELSE
        PERFORM pg_advisory_xact_lock_shared(hashtextextended(owner::text, 73302));
      END IF;

      RETURN owner;
    END;
    $f$;

CREATE OR REPLACE FUNCTION private.p32_head(trip uuid,owner uuid) RETURNS jsonb LANGUAGE sql SET search_path='' AS $f$
 SELECT jsonb_build_object('tripId',d.trip_id,'ownerId',d.owner_id,'version',d.content_version,
 'payloadText',d.payload_text,'contentDigest',d.content_digest,'fetchedAt',private.p32_utc(clock_timestamp()))
 FROM private.editable_trip_documents d JOIN public.trips t ON t.id=d.trip_id AND t.user_id=d.owner_id
 WHERE d.trip_id=trip AND d.owner_id=owner $f$;

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
   PERFORM private.p32_text(inp->'destinationName', 180, false, NOT account_save);
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

CREATE OR REPLACE FUNCTION public.create_editable_trip_v2(p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
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
 doc:=private.p32_validate(body->>'payloadText',true);
 IF doc#>>'{input,destinationId}' IS NOT NULL THEN
  PERFORM private.p32_require(private.is_valid_destination_id(doc#>>'{input,destinationId}',true),'invalid_document');
 END IF;
 source:=nullif(body->'sourceBinding','null'::jsonb);
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

CREATE OR REPLACE FUNCTION public.update_editable_trip_v2(p_trip_id uuid,p_expected_version bigint,p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
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
 IF doc#>>'{input,destinationId}' IS NOT NULL THEN
  PERFORM private.p32_require(private.is_valid_destination_id(doc#>>'{input,destinationId}',
    doc#>>'{input,destinationId}' IS DISTINCT FROM (d.payload_text::jsonb)#>>'{input,destinationId}'),'invalid_document');
 END IF;

 INSERT INTO private.editable_trip_write_permits VALUES(pg_backend_pid(),pg_current_xact_id(),p_trip_id,'UPDATE');
 UPDATE public.trips SET title=doc#>>'{input,title}',destination_name=doc#>>'{input,destinationName}',num_days=jsonb_array_length(doc->'days'),budget_total=(doc#>>'{input,totalBudgetVnd}')::numeric WHERE id=p_trip_id AND user_id=owner;
 UPDATE private.editable_trip_documents SET content_version=content_version+1,payload_text=body->>'payloadText',content_digest=body->>'contentDigest',updated_at=clock_timestamp() WHERE trip_id=p_trip_id AND owner_id=owner;
 DELETE FROM private.editable_trip_write_permits WHERE backend_pid=pg_backend_pid() AND transaction_id=pg_current_xact_id() AND trip_id=p_trip_id AND operation='UPDATE';
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,expected_version,result_version,request_digest,content_digest)
 VALUES(owner,p_request_id,'update',p_trip_id,p_expected_version,p_expected_version+1,p_request_digest,body->>'contentDigest');
 RETURN private.p32_reply(owner,p_request_id); END $f$;
COMMIT;
