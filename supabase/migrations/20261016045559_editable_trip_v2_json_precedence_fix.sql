-- Forward fix only. Original applied migration stays immutable.
-- CLI returned: 20261016045559_editable_trip_v2_json_precedence_fix.sql
-- Separate exact staging repair approval required before apply.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $baseline$
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'repair_owner_must_be_postgres'; END IF;
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261016034905' AND name='editable_trip_v2') THEN RAISE EXCEPTION 'repair_base_missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='private.p32_validate(text,boolean)'::regprocedure AND md5(pg_get_functiondef(oid))='51256cfeb2a57bf023e90da33503bd08' AND proacl=ARRAY['postgres=X/postgres'::aclitem] AND pg_get_userbyid(proowner)='postgres' AND proconfig=ARRAY['search_path=""']) THEN RAISE EXCEPTION 'repair_validate_drift'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='private.p32_replay(jsonb,jsonb)'::regprocedure AND md5(pg_get_functiondef(oid))='713fa2d3b6c0f836e19dec6b2cdf485a' AND proacl=ARRAY['postgres=X/postgres'::aclitem] AND pg_get_userbyid(proowner)='postgres' AND proconfig=ARRAY['search_path=""']) THEN RAISE EXCEPTION 'repair_replay_drift'; END IF;
END $baseline$;
CREATE OR REPLACE FUNCTION private.p32_validate(raw text,account_save boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
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
 AND jsonb_array_length(e->'itemIds')=jsonb_array_length(i->'itemIds') AND (e->'itemIds') @> (i->'itemIds') AND private.p32_nonblank(e->>'reason')));
 END LOOP; END IF; RETURN doc; END $f$;

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
 PERFORM private.p32_require(jsonb_array_length(ordered)=jsonb_array_length(c->'orderedItemIds') AND ordered @> (c->'orderedItemIds') AND (c->'orderedItemIds') @> ordered AND
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
 PERFORM private.p32_require(private.p32_nonblank(e->>'reason') AND EXISTS(SELECT 1 FROM jsonb_array_elements(private.p32_issues(doc)) i WHERE i->>'issueCode'=e->>'issueCode' AND i->>'fingerprint'=e->>'fingerprint' AND jsonb_array_length(i->'itemIds')=jsonb_array_length(e->'itemIds') AND (i->'itemIds') @> (e->'itemIds') AND (e->'itemIds') @> (i->'itemIds')),'invalid_command');
 SELECT coalesce(jsonb_agg(value ORDER BY ordinality),'[]') INTO ordered FROM jsonb_array_elements(doc->'exceptions') WITH ORDINALITY WHERE value->>'fingerprint'<>e->>'fingerprint'; doc:=jsonb_set(doc,'{exceptions}',ordered||jsonb_build_array(e));
 ELSE RAISE EXCEPTION 'invalid_command'; END CASE; END LOOP;
 SELECT coalesce(jsonb_agg(i.value ORDER BY d.ordinality,(i.value->>'position')::integer),'[]') INTO ordered FROM jsonb_array_elements(doc->'items') i JOIN jsonb_array_elements(doc->'days') WITH ORDINALITY d ON d.value->'id'=i.value->'dayId';
 PERFORM private.p32_require(jsonb_array_length(ordered)=jsonb_array_length(doc->'items'),'invalid_command'); doc:=jsonb_set(doc,'{items}',ordered);
 issues:=private.p32_issues(doc);
 SELECT coalesce(jsonb_agg(e.value ORDER BY e.ordinality),'[]') INTO ordered FROM jsonb_array_elements(doc->'exceptions') WITH ORDINALITY e
 WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(issues) i WHERE i->>'issueCode'=e.value->>'issueCode' AND i->>'fingerprint'=e.value->>'fingerprint');
 RETURN jsonb_set(doc,'{exceptions}',ordered); END $f$;

-- Synthetic JSON values only: no users, trips or ledger rows are written.
-- Reversed order creates both time_order and overlap; acknowledge and validate
-- exercises all repaired containment sites before COMMIT.
DO $regression$
DECLARE doc jsonb:=$fixture${"schemaVersion":2,"input":{"title":"Chuyến đi Huế","destinationId":"hue","destinationName":"Huế","startDate":"2026-10-15","endDate":"2026-10-15","timezone":"Asia/Ho_Chi_Minh","origin":"TP. Hồ Chí Minh","travelerCount":3,"totalBudgetVnd":500000,"interests":["ẩm thực"],"priority":"balanced"},"days":[{"id":"00000000-0000-4000-8000-000000000001","ordinal":1,"date":"2026-10-15","notes":""}],"items":[{"id":"00000000-0000-4000-8000-000000000010","dayId":"00000000-0000-4000-8000-000000000001","position":0,"title":"Activity 10","placeId":null,"startMinute":540,"endMinute":600,"notes":"","provenance":{"quality":"user_provided","sourceRefs":[],"observedAt":null}},{"id":"00000000-0000-4000-8000-000000000011","dayId":"00000000-0000-4000-8000-000000000001","position":1,"title":"Activity 11","placeId":null,"startMinute":570,"endMinute":630,"notes":"","provenance":{"quality":"user_provided","sourceRefs":[],"observedAt":null}}],"estimates":[{"id":"00000000-0000-4000-8000-000000000002","itemId":null,"category":"food","unitAmountVnd":100000,"basis":"per_person","customQuantity":null,"active":true,"description":"Ăn uống","provenance":{"quality":"user_provided","sourceRefs":[],"observedAt":null}},{"id":"00000000-0000-4000-8000-000000000003","itemId":null,"category":"other","unitAmountVnd":null,"basis":"trip_total","customQuantity":null,"active":true,"description":"Chưa biết","provenance":{"quality":"unknown","sourceRefs":[],"observedAt":null}}],"actualExpenses":[{"id":"00000000-0000-4000-8000-000000000004","itemId":null,"amountVnd":250000,"category":"food","paidOn":"2026-10-15","description":"Đã trả","sourceItemSnapshot":null,"provenance":{"quality":"user_provided","sourceRefs":[],"observedAt":null}}],"exceptions":[],"source":{"kind":"new","sourceId":null,"sourceDigest":null}}$fixture$::jsonb;
 result jsonb; issue jsonb; issue_count integer;
BEGIN
 result:=private.p32_replay(doc,jsonb_build_array(jsonb_build_object('op','reorderDay','dayId',doc#>'{days,0,id}',
 'orderedItemIds',jsonb_build_array(doc#>'{items,1,id}',doc#>'{items,0,id}'))));
 IF result#>>'{items,0,id}' IS DISTINCT FROM doc#>>'{items,1,id}' THEN RAISE EXCEPTION 'repair_reorder_regression'; END IF;
 SELECT jsonb_array_length(private.p32_issues(result)) INTO issue_count;
 IF issue_count<>2 THEN RAISE EXCEPTION 'repair_issue_fixture_regression'; END IF;
 FOR issue IN SELECT value FROM jsonb_array_elements(private.p32_issues(result)) LOOP
  result:=private.p32_replay(result,jsonb_build_array(jsonb_build_object('op','acknowledgeIssue','exception',issue||jsonb_build_object('reason','Synthetic repair regression'))));
 END LOOP;
 PERFORM private.p32_validate(result::text,true);
 IF result->'actualExpenses' IS DISTINCT FROM doc->'actualExpenses' THEN RAISE EXCEPTION 'repair_actual_regression'; END IF;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid IN ('private.p32_validate(text,boolean)'::regprocedure,'private.p32_replay(jsonb,jsonb)'::regprocedure) AND
 (proacl IS DISTINCT FROM ARRAY['postgres=X/postgres'::aclitem] OR pg_get_userbyid(proowner)<>'postgres' OR proconfig IS DISTINCT FROM ARRAY['search_path=""'])) THEN RAISE EXCEPTION 'repair_acl_drift'; END IF;
END $regression$;
COMMIT;
