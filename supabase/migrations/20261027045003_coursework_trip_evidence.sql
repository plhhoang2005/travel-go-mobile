-- A2 additive evidence contract. Local verification first; no cloud rollout.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
ALTER TABLE private.editable_trip_mutations ADD COLUMN payload_kind text NOT NULL DEFAULT 'editable_v2'
 CHECK(payload_kind IN ('editable_v2','evidence_v1'));

CREATE FUNCTION private.pe_time(v jsonb,effective boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF v='null'::jsonb THEN RETURN; END IF;
 IF effective AND v#>>'{}' ~ '^\d{4}-\d{2}-\d{2}$' THEN PERFORM private.p32_date(v); RETURN; END IF;
 PERFORM private.p32_provenance(jsonb_build_object('quality','unknown','sourceRefs','[]'::jsonb,'observedAt',v));
END $$;
CREATE FUNCTION private.pe_refs(v jsonb,ids text[],needed boolean DEFAULT false) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE x jsonb; seen text[]:='{}'; name text;
BEGIN
 PERFORM private.p32_list(v,1048576);
 PERFORM private.p32_require(NOT needed OR jsonb_array_length(v)>0,'invalid_input');
 FOR x IN SELECT * FROM jsonb_array_elements(v) LOOP
  PERFORM private.p32_text(x,128); name:=x#>>'{}';
  PERFORM private.p32_require(name=ANY(ids) AND NOT name=ANY(seen),'invalid_input'); seen:=array_append(seen,name);
 END LOOP;
END $$;
CREATE FUNCTION private.pe_validate(raw text) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$
DECLARE env jsonb:=private.p32_parse(raw); doc jsonb; r jsonb; x jsonb; k text; name text;
 ids text[]:='{}'; claimids text[]:='{}'; extids text[]:='{}'; bound text[]:='{}'; item jsonb; authority text;
BEGIN
 PERFORM private.p32_require(env->>'contract'='travelgo.trip.evidence.v1','unsupported_schema');
 PERFORM private.p32_keys(env,'contract document evidence claims externalPlaces externalBindings');
 doc:=private.p32_validate(private.p32_canonical(env->'document'),true);
 PERFORM private.p32_list(env->'evidence',1048576);
 FOR r IN SELECT * FROM jsonb_array_elements(env->'evidence') LOOP
  PERFORM private.p32_keys(r,'id origin url title publisher factKey factValue retrievedAt checkedAt publishedAt effectiveFrom effectiveTo reviewed evidenceRequestId');
  PERFORM private.p32_text(r->'id',128); name:=r->>'id';
  PERFORM private.p32_require(NOT name=ANY(ids),'invalid_input'); ids:=array_append(ids,name);
  PERFORM private.p32_enum(r->'origin','catalogue web user');
  PERFORM private.p32_require(jsonb_typeof(r->'reviewed')='boolean' AND (r->>'origin'='catalogue' OR r->'reviewed'='false'::jsonb),'invalid_input');
  IF r->>'origin'='user' THEN PERFORM private.p32_require(r->'url'='null'::jsonb,'invalid_input');
  ELSE
   PERFORM private.p32_text(r->'url',1048576);
   PERFORM private.p32_require(r->>'url' ~* '^https://[^/?#[:space:]@]+' AND r->>'url' !~ '[[:space:][:cntrl:]]','invalid_input');
   authority:=substring(r->>'url' from '(?i)^https://([^/?#]+)');
   PERFORM private.p32_require(authority IS NOT NULL AND authority NOT LIKE '%@%' AND
    ((authority !~ '[\[\]]' AND authority ~ '^[^:]+(:[0-9]*)?$') OR authority ~ '^\[[0-9a-fA-F:.]+\](:[0-9]*)?$'),'invalid_input');
  END IF;
  FOREACH k IN ARRAY ARRAY['title','publisher'] LOOP PERFORM private.p32_text(r->k,1048576,false,true); END LOOP;
  PERFORM private.p32_text(r->'factKey',1048576); PERFORM private.p32_text(r->'factValue',1048576,true);
  FOREACH k IN ARRAY ARRAY['retrievedAt','checkedAt','publishedAt'] LOOP PERFORM private.pe_time(r->k); END LOOP;
  FOREACH k IN ARRAY ARRAY['effectiveFrom','effectiveTo'] LOOP PERFORM private.pe_time(r->k,true); END LOOP;
  IF r->>'effectiveFrom' IS NOT NULL AND r->>'effectiveTo' IS NOT NULL THEN
   PERFORM private.p32_require((length(r->>'effectiveFrom')=10)=(length(r->>'effectiveTo')=10) AND
    (r->>'effectiveFrom')::timestamptz<=(r->>'effectiveTo')::timestamptz,'invalid_input');
  END IF;
  PERFORM private.p32_id(r->'evidenceRequestId',true);
 END LOOP;
 PERFORM private.p32_list(env->'claims',1048576);
 FOR r IN SELECT * FROM jsonb_array_elements(env->'claims') LOOP
  PERFORM private.p32_keys(r,'id text kind evidenceIds'); PERFORM private.p32_text(r->'id',128);
  PERFORM private.p32_require(NOT r->>'id'=ANY(claimids),'invalid_input'); claimids:=array_append(claimids,r->>'id');
  PERFORM private.p32_text(r->'text',1048576); PERFORM private.p32_enum(r->'kind','fact inference unknown');
  PERFORM private.pe_refs(r->'evidenceIds',ids,r->>'kind'='fact');
 END LOOP;
 PERFORM private.p32_list(env->'externalPlaces',1048576);
 FOR r IN SELECT * FROM jsonb_array_elements(env->'externalPlaces') LOOP
  PERFORM private.p32_keys(r,'id name destinationName evidenceIds'); PERFORM private.p32_text(r->'id',128);
  PERFORM private.p32_require(NOT r->>'id'=ANY(extids),'invalid_input'); extids:=array_append(extids,r->>'id');
  PERFORM private.p32_text(r->'name',1048576); PERFORM private.p32_text(r->'destinationName',1048576);
  PERFORM private.pe_refs(r->'evidenceIds',ids,true);
 END LOOP;
 PERFORM private.p32_list(env->'externalBindings',1048576);
 FOR r IN SELECT * FROM jsonb_array_elements(env->'externalBindings') LOOP
  PERFORM private.p32_keys(r,'itemId externalPlaceId'); PERFORM private.p32_id(r->'itemId'); PERFORM private.p32_text(r->'externalPlaceId',128);
  SELECT value INTO item FROM jsonb_array_elements(doc->'items') WHERE value->>'id'=r->>'itemId';
  PERFORM private.p32_require(item IS NOT NULL AND item->'placeId'='null'::jsonb AND r->>'externalPlaceId'=ANY(extids) AND NOT r->>'itemId'=ANY(bound),'invalid_input');
  bound:=array_append(bound,r->>'itemId');
 END LOOP;
 FOREACH k IN ARRAY ARRAY['items','estimates','actualExpenses'] LOOP
  FOR r IN SELECT * FROM jsonb_array_elements(doc->k) LOOP PERFORM private.pe_refs(r#>'{provenance,sourceRefs}',ids); END LOOP;
 END LOOP;
 RETURN env;
END $$;

CREATE FUNCTION private.pe_trust(env jsonb,owner uuid,base jsonb DEFAULT NULL) RETURNS void LANGUAGE plpgsql SET search_path='' AS $$
DECLARE r jsonb; previous jsonb; claim jsonb; receipt private_ai.requests%ROWTYPE; k text; item jsonb; before_item jsonb; fields text[];
BEGIN
 FOR r IN SELECT * FROM jsonb_array_elements(env->'evidence') LOOP
  SELECT value INTO previous FROM jsonb_array_elements(coalesce(base->'evidence','[]'::jsonb)) WHERE value->>'id'=r->>'id';
  IF previous IS NOT NULL THEN PERFORM private.p32_require(previous=r,'evidence_immutable'); CONTINUE; END IF;
  IF r->>'origin'='user' THEN CONTINUE; END IF;
  SELECT * INTO receipt FROM private_ai.requests WHERE subject=owner AND request_id=(r->>'evidenceRequestId')::uuid AND NOT is_guest;
  PERFORM private.p32_require(FOUND AND receipt.state='succeeded' AND receipt.result IS NOT NULL AND receipt.result_expires_at>clock_timestamp(),'evidence_expired');
  PERFORM private.p32_require(receipt.result->>'contract' IN ('travelgo.itinerary.evidence.v1','travelgo.assistant.evidence.v1','travelgo.web.advice.v1','travelgo.web.proposal.v1') AND
   jsonb_typeof(receipt.result->'evidence')='array','evidence_untrusted');
  PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(receipt.result->'evidence') v WHERE v=r),'evidence_untrusted');
  IF r->>'origin'='catalogue' THEN
   PERFORM private.p32_require(jsonb_typeof(receipt.result->'catalogueVersion')='string' AND length(receipt.result->>'catalogueVersion')>0 AND receipt.result->>'catalogueDigest' ~ '^[0-9a-f]{64}$','evidence_untrusted');
  END IF;
 END LOOP;
 -- Source membership alone does not attest an arbitrary client-written fact.
 FOR claim IN SELECT * FROM jsonb_array_elements(env->'claims') WHERE value->>'kind'='fact' LOOP
  SELECT value INTO previous FROM jsonb_array_elements(coalesce(base->'claims','[]'::jsonb)) WHERE value->>'id'=claim->>'id';
  IF previous=claim THEN CONTINUE; END IF;
  SELECT value INTO r FROM jsonb_array_elements(env->'evidence') WHERE value->>'origin'<>'user' AND claim->'evidenceIds' ? (value->>'id') LIMIT 1;
  IF r IS NULL THEN CONTINUE; END IF;
  SELECT * INTO receipt FROM private_ai.requests WHERE subject=owner AND request_id=(r->>'evidenceRequestId')::uuid AND NOT is_guest;
  PERFORM private.p32_require(FOUND AND receipt.state='succeeded' AND receipt.result IS NOT NULL AND receipt.result_expires_at>clock_timestamp(),'evidence_expired');
  PERFORM private.p32_require(jsonb_typeof(receipt.result->'claims')='array' AND jsonb_typeof(receipt.result->'evidence')='array','evidence_untrusted');
  PERFORM private.p32_require(EXISTS(SELECT 1 FROM jsonb_array_elements(receipt.result->'claims') c WHERE c=claim) AND NOT EXISTS(
    SELECT 1 FROM jsonb_array_elements(env->'evidence') e WHERE claim->'evidenceIds' ? (e->>'id') AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(receipt.result->'evidence') verified WHERE verified=e)
   ),'evidence_untrusted');
 END LOOP;
 IF base IS NULL THEN RETURN; END IF;
 FOREACH k IN ARRAY ARRAY['items','estimates'] LOOP
  FOR item IN SELECT * FROM jsonb_array_elements(env#>ARRAY['document',k]) LOOP
   SELECT value INTO before_item FROM jsonb_array_elements(coalesce(base#>ARRAY['document',k],'[]'::jsonb)) WHERE value->>'id'=item->>'id';
   IF before_item IS NULL THEN CONTINUE; END IF;
   fields:=CASE WHEN k='items' THEN ARRAY['title','placeId','startMinute','endMinute'] ELSE ARRAY['unitAmountVnd','basis','customQuantity','category'] END;
   IF EXISTS(SELECT 1 FROM unnest(fields) f WHERE before_item->f IS DISTINCT FROM item->f) THEN
    PERFORM private.p32_require(item#>'{provenance,sourceRefs}'='[]'::jsonb,'evidence_stale_citation');
   END IF;
  END LOOP;
 END LOOP;
END $$;

CREATE FUNCTION public.get_trip_capabilities_v1() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN PERFORM private.p32_owner(); RETURN '{"evidenceV1":true,"ownedListV3":true}'::jsonb; END $$;
CREATE FUNCTION public.create_evidence_trip_v1(p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(true); body jsonb; envelope jsonb; doc jsonb; source jsonb; trip uuid; old private.editable_trip_mutations%ROWTYPE; source_digest text;
BEGIN
 PERFORM private.p32_require(p_request_id IS NOT NULL AND p_request_digest ~ '^[0-9a-f]{64}$' AND octet_length(p_request_text)<=3145728,'invalid_request');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(p_request_text,'UTF8'),'sha256'),'hex')=p_request_digest,'invalid_request');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.payload_kind='evidence_v1' AND old.operation='create' AND old.request_digest=p_request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 body:=private.p32_parse(p_request_text,3145728); PERFORM private.p32_keys(body,'payloadText contentDigest sourceBinding');
 PERFORM private.p32_text(body->'payloadText',1048576); PERFORM private.p32_hash(body->'contentDigest');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(body->>'payloadText','UTF8'),'sha256'),'hex')=body->>'contentDigest','invalid_request');
 envelope:=private.pe_validate(body->>'payloadText'); doc:=envelope->'document';
 IF doc#>>'{input,destinationId}' IS NOT NULL THEN
  PERFORM private.p32_require(private.is_valid_destination_id(doc#>>'{input,destinationId}',true),'invalid_document');
 END IF;
 PERFORM private.pe_trust(envelope,owner);
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
 UPDATE private.editable_trip_mutations SET payload_kind='evidence_v1' WHERE owner_id=owner AND request_id=p_request_id;
 RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.update_evidence_trip_v1(p_trip_id uuid,p_expected_version bigint,p_request_id uuid,p_request_text text,p_request_digest text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(true); old private.editable_trip_mutations%ROWTYPE; d private.editable_trip_documents%ROWTYPE; body jsonb; envelope jsonb; doc jsonb; replay jsonb;
BEGIN
 PERFORM private.p32_require(p_trip_id IS NOT NULL AND p_request_id IS NOT NULL AND p_expected_version BETWEEN 1 AND 9007199254740990 AND octet_length(p_request_text)<=3145728 AND p_request_digest ~ '^[0-9a-f]{64}$','invalid_request');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(p_request_text,'UTF8'),'sha256'),'hex')=p_request_digest,'invalid_request');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.payload_kind='evidence_v1' AND old.operation='update' AND old.trip_id=p_trip_id AND old.expected_version=p_expected_version AND old.request_digest=p_request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner FOR UPDATE; PERFORM private.p32_require(FOUND,'trip_unavailable');
 SELECT * INTO d FROM private.editable_trip_documents WHERE trip_id=p_trip_id AND owner_id=owner; PERFORM private.p32_require(FOUND,'trip_unavailable');
 PERFORM private.p32_require(d.content_version=p_expected_version,'version_conflict');
 body:=private.p32_parse(p_request_text,3145728); PERFORM private.p32_keys(body,'payloadText contentDigest commands'); PERFORM private.p32_hash(body->'contentDigest');
 PERFORM private.p32_require(encode(extensions.digest(convert_to(body->>'payloadText','UTF8'),'sha256'),'hex')=body->>'contentDigest','invalid_request');
 envelope:=private.pe_validate(body->>'payloadText'); doc:=envelope->'document'; PERFORM private.pe_trust(envelope,owner,CASE WHEN d.payload_text::jsonb->>'contract'='travelgo.trip.evidence.v1' THEN d.payload_text::jsonb ELSE jsonb_build_object('document',d.payload_text::jsonb,'evidence','[]'::jsonb) END); replay:=private.p32_replay(CASE WHEN d.payload_text::jsonb->>'contract'='travelgo.trip.evidence.v1' THEN d.payload_text::jsonb->'document' ELSE d.payload_text::jsonb END,body->'commands');
 PERFORM private.p32_require(replay=doc,'invalid_request'); PERFORM private.p32_validate(private.p32_canonical(replay),true);
 IF doc#>>'{input,destinationId}' IS NOT NULL THEN
  PERFORM private.p32_require(private.is_valid_destination_id(doc#>>'{input,destinationId}',
    doc#>>'{input,destinationId}' IS DISTINCT FROM coalesce((d.payload_text::jsonb)#>>'{document,input,destinationId}',(d.payload_text::jsonb)#>>'{input,destinationId}')),'invalid_document');
 END IF;

 INSERT INTO private.editable_trip_write_permits VALUES(pg_backend_pid(),pg_current_xact_id(),p_trip_id,'UPDATE');
 UPDATE public.trips SET title=doc#>>'{input,title}',destination_name=doc#>>'{input,destinationName}',num_days=jsonb_array_length(doc->'days'),budget_total=(doc#>>'{input,totalBudgetVnd}')::numeric WHERE id=p_trip_id AND user_id=owner;
 UPDATE private.editable_trip_documents SET content_version=content_version+1,payload_text=body->>'payloadText',content_digest=body->>'contentDigest',updated_at=clock_timestamp() WHERE trip_id=p_trip_id AND owner_id=owner;
 DELETE FROM private.editable_trip_write_permits WHERE backend_pid=pg_backend_pid() AND transaction_id=pg_current_xact_id() AND trip_id=p_trip_id AND operation='UPDATE';
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,expected_version,result_version,request_digest,content_digest)
 VALUES(owner,p_request_id,'update',p_trip_id,p_expected_version,p_expected_version+1,p_request_digest,body->>'contentDigest');
 UPDATE private.editable_trip_mutations SET payload_kind='evidence_v1' WHERE owner_id=owner AND request_id=p_request_id;
 RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.delete_evidence_trip_v1(p_trip_id uuid,p_expected_version bigint,p_request_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(true); old private.editable_trip_mutations%ROWTYPE; version bigint; request_digest text;
BEGIN
 PERFORM private.p32_require(p_trip_id IS NOT NULL AND p_request_id IS NOT NULL AND p_expected_version BETWEEN 1 AND 9007199254740990,'invalid_request');
 request_digest:=encode(extensions.digest(convert_to(private.p32_canonical(jsonb_build_object('op','delete','tripId',p_trip_id,'expectedVersion',p_expected_version)),'UTF8'),'sha256'),'hex');
 SELECT * INTO old FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id;
 IF FOUND THEN PERFORM private.p32_require(old.payload_kind='evidence_v1' AND old.operation='delete' AND old.trip_id=p_trip_id AND old.expected_version=p_expected_version AND old.request_digest=request_digest,'request_identity_conflict'); RETURN private.p32_reply(owner,p_request_id); END IF;
 PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner FOR UPDATE; PERFORM private.p32_require(FOUND,'trip_unavailable');
 SELECT content_version INTO version FROM private.editable_trip_documents WHERE trip_id=p_trip_id AND owner_id=owner; PERFORM private.p32_require(FOUND,'trip_unavailable');
 PERFORM private.p32_require(version=p_expected_version,'version_conflict');
 PERFORM private.p32_require(EXISTS(SELECT 1 FROM private.editable_trip_documents WHERE trip_id=p_trip_id AND owner_id=owner AND payload_text::jsonb->>'contract'='travelgo.trip.evidence.v1'),'unsupported_schema');
 INSERT INTO private.editable_trip_write_permits VALUES(pg_backend_pid(),pg_current_xact_id(),p_trip_id,'DELETE');
 DELETE FROM public.trips WHERE id=p_trip_id AND user_id=owner;
 DELETE FROM private.editable_trip_write_permits WHERE backend_pid=pg_backend_pid() AND transaction_id=pg_current_xact_id() AND trip_id=p_trip_id AND operation='DELETE';
 UPDATE private.editable_trip_mutations SET deleted=true WHERE owner_id=owner AND trip_id=p_trip_id;
 INSERT INTO private.editable_trip_mutations(owner_id,request_id,operation,trip_id,expected_version,result_version,request_digest,deleted)
 VALUES(owner,p_request_id,'delete',p_trip_id,p_expected_version,p_expected_version+1,request_digest,true);
 UPDATE private.editable_trip_mutations SET payload_kind='evidence_v1' WHERE owner_id=owner AND request_id=p_request_id; RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.get_evidence_trip_v1(p_trip_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(); head jsonb;
BEGIN PERFORM 1 FROM public.trips WHERE id=p_trip_id AND user_id=owner FOR SHARE;
 head:=private.p32_head(p_trip_id,owner);
 IF head IS NOT NULL THEN PERFORM private.p32_require((head->>'payloadText')::jsonb->>'contract'='travelgo.trip.evidence.v1','unsupported_schema'); END IF;
 RETURN jsonb_build_object('status',CASE WHEN head IS NULL THEN 'unavailable' ELSE 'ready' END,'head',head); END $f$;
CREATE FUNCTION public.get_evidence_mutation_v1(p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner();
BEGIN
 IF NOT EXISTS(SELECT 1 FROM private.editable_trip_mutations WHERE owner_id=owner AND request_id=p_request_id AND payload_kind='evidence_v1') THEN RETURN jsonb_build_object('status','not_found','receipt',NULL,'head',NULL); END IF;
 RETURN private.p32_reply(owner,p_request_id); END $f$;

CREATE FUNCTION public.list_owned_trips_v3(p_before_created_at timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL,p_limit integer DEFAULT 25) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE owner uuid:=private.p32_owner(); rows jsonb; items jsonb; cursor jsonb;
BEGIN
 PERFORM private.p32_require(p_limit BETWEEN 1 AND 50 AND (p_before_created_at IS NULL)=(p_before_id IS NULL),'invalid_request');
 SELECT coalesce(jsonb_agg(jsonb_build_object('kind',CASE WHEN d.trip_id IS NULL THEN 'legacy_v1' WHEN d.payload_text::jsonb->>'contract'='travelgo.trip.evidence.v1' THEN 'evidence_v1' ELSE 'editable_v2' END,
 'tripId',t.id,'ownerId',t.user_id,'title',t.title,'destinationName',t.destination_name,'createdAt',private.p32_utc(t.created_at),'version',d.content_version)
 ORDER BY t.created_at DESC,t.id DESC),'[]') INTO rows
 FROM (SELECT * FROM public.trips t WHERE t.user_id=owner AND (p_before_id IS NULL OR (t.created_at,t.id)<(p_before_created_at,p_before_id))
 ORDER BY t.created_at DESC,t.id DESC LIMIT p_limit+1) t LEFT JOIN private.editable_trip_documents d ON d.trip_id=t.id AND d.owner_id=t.user_id;
 SELECT coalesce(jsonb_agg(value ORDER BY ordinality),'[]') INTO items FROM jsonb_array_elements(rows) WITH ORDINALITY WHERE ordinality<=p_limit;
 cursor:=CASE WHEN jsonb_array_length(rows)>p_limit THEN jsonb_build_object('createdAt',items->(p_limit-1)->'createdAt','id',items->(p_limit-1)->'tripId') END;
 RETURN jsonb_build_object('items',items,'nextCursor',cursor); END $f$;

DO $acl$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature,n.nspname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE (n.nspname='private' AND p.proname LIKE 'pe_%') OR (n.nspname='public' AND p.proname IN ('get_trip_capabilities_v1','create_evidence_trip_v1','update_evidence_trip_v1','get_evidence_trip_v1','delete_evidence_trip_v1','get_evidence_mutation_v1','list_owned_trips_v3')) LOOP
 EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',f.signature);
 IF f.nspname='public' THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.signature); END IF;
 END LOOP; END $acl$;
COMMIT;
