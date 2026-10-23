-- Test: supabase/tests/planner_request_context.sql
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='30s';

CREATE FUNCTION pg_temp.b3_assert(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'assertion_failed:%', label; END IF; END $f$;

CREATE FUNCTION pg_temp.b3_error(command text, expected text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE observed boolean := false;
BEGIN
  BEGIN EXECUTE command;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> expected AND SQLSTATE <> expected THEN RAISE; END IF;
    observed := true;
  END;
  IF NOT observed THEN RAISE EXCEPTION 'expected_error_not_observed: %', expected; END IF;
END $f$;

-- 1. Legacy payload without optional request keys passes validation
SELECT pg_temp.b3_assert(
  private.validate_guest_payload_v1(
    $v${"metadata":{"destinationId":"hue","destinationName":"Huế","endDate":null,"startDate":null,"timezone":null,"title":"Huế"},"plan":null,"request":{"budgetVnd":4000000,"numDays":3,"numPeople":2,"origin":"TP. Hồ Chí Minh","preferences":["ẩm thực"],"priority":"balanced"},"schemaVersion":1}$v$
  ) IS NOT NULL,
  'legacy payload passes'
);

-- 2. New payload with valid optional request keys passes validation
SELECT pg_temp.b3_assert(
  private.validate_guest_payload_v1(
    $v${"metadata":{"destinationId":"hue","destinationName":"Huế","endDate":"2026-11-03","startDate":"2026-11-01","timezone":"Asia/Ho_Chi_Minh","title":"Huế cùng gia đình"},"plan":null,"request":{"budgetVnd":6000000,"companionType":"family","destinationId":"hue","destinationName":"Huế","endDate":"2026-11-03","numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":["văn hóa","ẩm thực"],"priority":"balanced","startDate":"2026-11-01"},"schemaVersion":1}$v$
  ) IS NOT NULL,
  'full adaptive request payload passes'
);

-- 3. Negative controls:
-- 3.1 Unknown key in request
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced","unknownKey":"forbidden"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

-- 3.2 Invalid companionType
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"companionType":"backpackers","numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

-- 3.3 End date before start date
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"endDate":"2026-11-01","numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced","startDate":"2026-11-05"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

-- 3.4 Date count mismatch with numDays (2026-11-01 to 2026-11-03 is 3 days, but numDays is 5)
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"endDate":"2026-11-03","numDays":5,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced","startDate":"2026-11-01"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

-- 3.5 Only startDate provided without endDate
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced","startDate":"2026-11-01"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

-- 3.6 Invalid destinationId format (uppercase or spaces)
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"destinationId":"HUE CITY","numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

-- 3.7 Blank destinationName
SELECT pg_temp.b3_error(
  $q$SELECT private.validate_guest_payload_v1($v${"metadata":{"destinationId":null,"destinationName":null,"endDate":null,"startDate":null,"timezone":null,"title":null},"plan":null,"request":{"budgetVnd":6000000,"destinationName":"   ","numDays":3,"numPeople":4,"origin":"Hà Nội","preferences":[],"priority":"balanced"},"schemaVersion":1}$v$)$q$,
  'invalid_input'
);

ROLLBACK;
