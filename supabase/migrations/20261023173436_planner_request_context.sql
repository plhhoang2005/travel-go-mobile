-- Migration: 20261023173436_planner_request_context.sql
-- Allow optional request context fields (destinationId, destinationName, startDate, endDate, companionType) in guest payload validator.

CREATE OR REPLACE FUNCTION private.validate_guest_payload_v1(p_text text)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $fn$
DECLARE root json; m json; req json; plan json; item json; sub json; val json;
  k text; date_text text; date_value date; first_date date; last_date date;
  req_start_text text; req_end_text text; req_start_date date; req_end_date date;
  dest_id text; dest_name text; comp text;
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
    PERFORM private.guest_b3_keys(req,ARRAY['origin','numDays','numPeople','budgetVnd','preferences','priority'],ARRAY['destinationId','destinationName','startDate','endDate','companionType']);
    PERFORM private.guest_b3_value(req->'origin','nonblank');
    PERFORM private.guest_b3_value(req->'numDays','integer',1,2147483647);
    PERFORM private.guest_b3_value(req->'numPeople','integer',1,2147483647);
    PERFORM private.guest_b3_value(req->'budgetVnd','integer');
    PERFORM private.guest_b3_value(req->'priority','string');
    PERFORM private.guest_b3_value(req->'preferences','array');
    FOR val IN SELECT value FROM json_array_elements(req->'preferences') LOOP
      PERFORM private.guest_b3_value(val,'string');
    END LOOP;
    IF json_typeof(req->'destinationId')<>'null' AND req->'destinationId' IS NOT NULL THEN
      PERFORM private.guest_b3_value(req->'destinationId','string');
      dest_id:=req->>'destinationId';
      IF dest_id !~ '^[a-z0-9][a-z0-9/-]{0,119}$' THEN RAISE EXCEPTION 'invalid_input'; END IF;
    END IF;
    IF json_typeof(req->'destinationName')<>'null' AND req->'destinationName' IS NOT NULL THEN
      PERFORM private.guest_b3_value(req->'destinationName','nonblank');
    END IF;
    IF (json_typeof(req->'startDate')<>'null' AND req->'startDate' IS NOT NULL) OR (json_typeof(req->'endDate')<>'null' AND req->'endDate' IS NOT NULL) THEN
      IF req->'startDate' IS NULL OR json_typeof(req->'startDate')='null' OR req->'endDate' IS NULL OR json_typeof(req->'endDate')='null' THEN
        RAISE EXCEPTION 'invalid_input';
      END IF;
      PERFORM private.guest_b3_value(req->'startDate','string');
      PERFORM private.guest_b3_value(req->'endDate','string');
      req_start_text:=req->>'startDate';
      req_end_text:=req->>'endDate';
      IF req_start_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' OR substring(req_start_text,1,4)='0000' OR
         req_end_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' OR substring(req_end_text,1,4)='0000' THEN
        RAISE EXCEPTION 'invalid_input';
      END IF;
      req_start_date:=req_start_text::date;
      req_end_date:=req_end_text::date;
      IF to_char(req_start_date,'YYYY-MM-DD')<>req_start_text OR to_char(req_end_date,'YYYY-MM-DD')<>req_end_text THEN
        RAISE EXCEPTION 'invalid_input';
      END IF;
      IF req_end_date < req_start_date THEN RAISE EXCEPTION 'invalid_input'; END IF;
      IF (req_end_date - req_start_date + 1) <> (req->>'numDays')::bigint THEN RAISE EXCEPTION 'invalid_input'; END IF;
    END IF;
    IF json_typeof(req->'companionType')<>'null' AND req->'companionType' IS NOT NULL THEN
      PERFORM private.guest_b3_value(req->'companionType','string');
      comp:=req->>'companionType';
      IF comp NOT IN ('solo','couple','family','group') THEN RAISE EXCEPTION 'invalid_input'; END IF;
    END IF;
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
