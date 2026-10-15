BEGIN;

DO $$ BEGIN
  IF to_regnamespace('private_ai') IS NOT NULL THEN
    RAISE EXCEPTION 'AI schema exists; inspect drift before applying';
  END IF;
END $$;

CREATE SCHEMA private_ai;
REVOKE ALL ON SCHEMA private_ai FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE private_ai.settings (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  guest_limit integer NOT NULL CHECK (guest_limit = 3),
  account_limit integer NOT NULL CHECK (account_limit BETWEEN 1 AND 3),
  global_attempt_limit integer NOT NULL CHECK (global_attempt_limit BETWEEN 1 AND 20)
);
INSERT INTO private_ai.settings VALUES (true, 3, 3, 20);

CREATE TABLE private_ai.usage (
  subject uuid NOT NULL,
  accepted_day date NOT NULL,
  used integer NOT NULL DEFAULT 0 CHECK (used >= 0),
  reserved integer NOT NULL DEFAULT 0 CHECK (reserved >= 0),
  PRIMARY KEY (subject, accepted_day),
  CHECK (used + reserved <= 3)
);
CREATE TABLE private_ai.global_attempts (
  accepted_day date PRIMARY KEY,
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 20)
);
CREATE TABLE private_ai.requests (
  subject uuid NOT NULL,
  request_id uuid NOT NULL,
  is_guest boolean NOT NULL,
  digest text NOT NULL CHECK (length(digest) = 64 AND digest !~ '[^0-9a-f]'),
  accepted_day date NOT NULL,
  state text NOT NULL CHECK (state IN ('reserved', 'succeeded', 'failed', 'expired')),
  worker uuid NOT NULL,
  expires_at timestamptz NOT NULL,
  result jsonb,
  result_expires_at timestamptz,
  created_at timestamptz NOT NULL,
  PRIMARY KEY (subject, request_id),
  FOREIGN KEY (subject, accepted_day) REFERENCES private_ai.usage(subject, accepted_day),
  CHECK ((state = 'succeeded') = (result_expires_at IS NOT NULL)),
  CHECK (result IS NULL OR (state = 'succeeded' AND jsonb_typeof(result) = 'object' AND octet_length(result::text) <= 16384))
);
CREATE INDEX ai_request_expiry ON private_ai.requests(expires_at) WHERE state = 'reserved';
ALTER TABLE private_ai.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_ai.usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_ai.global_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_ai.requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA private_ai FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION private_ai.maintain(p_now timestamptz) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE expired_request private_ai.requests%ROWTYPE;
BEGIN
  -- All callers first lock settings; this orders reserve/finalize/expiry globally.
  FOR expired_request IN SELECT * FROM private_ai.requests WHERE state = 'reserved' AND expires_at <= p_now FOR UPDATE LOOP
    UPDATE private_ai.usage SET reserved = reserved - 1 WHERE subject = expired_request.subject AND accepted_day = expired_request.accepted_day;
    UPDATE private_ai.requests SET state = 'expired' WHERE subject = expired_request.subject AND request_id = expired_request.request_id;
  END LOOP;
  UPDATE private_ai.requests SET result = NULL WHERE state = 'succeeded' AND result_expires_at <= p_now AND result IS NOT NULL;
  DELETE FROM private_ai.requests WHERE state <> 'reserved' AND created_at < p_now - interval '30 days';
  DELETE FROM private_ai.usage u WHERE accepted_day < (p_now AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 30
    AND NOT EXISTS (SELECT 1 FROM private_ai.requests r WHERE r.subject = u.subject AND r.accepted_day = u.accepted_day);
  DELETE FROM private_ai.global_attempts WHERE accepted_day < (p_now AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 30;
END $$;

CREATE FUNCTION private_ai.envelope(r private_ai.requests, p_limit integer) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'status', CASE WHEN (r).state = 'succeeded' AND (r).result IS NULL THEN 'result_expired' ELSE (r).state END,
    'requestId', (r).request_id, 'acceptedDay', (r).accepted_day,
    'workerToken', CASE WHEN (r).state = 'reserved' THEN (r).worker ELSE NULL END,
    'expiresAt', (r).expires_at, 'result', (r).result,
    'remaining', greatest(0, p_limit - u.used - u.reserved)
  ) FROM private_ai.usage u WHERE u.subject = (r).subject AND u.accepted_day = (r).accepted_day;
$$;

CREATE FUNCTION private_ai.reserve(p_subject uuid, p_guest boolean, p_id uuid, p_digest text, p_now timestamptz) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE cfg private_ai.settings%ROWTYPE; r private_ai.requests%ROWTYPE;
  bucket date; cap integer; amount integer; global_amount integer;
BEGIN
  IF p_subject IS NULL OR p_guest IS NULL OR p_id IS NULL OR p_digest IS NULL
     OR length(p_digest) <> 64 OR p_digest ~ '[^0-9a-f]' OR p_now IS NULL THEN
    RAISE EXCEPTION 'Invalid quota binding' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO STRICT cfg FROM private_ai.settings WHERE singleton FOR UPDATE;
  PERFORM private_ai.maintain(p_now);
  cap := CASE WHEN p_guest THEN cfg.guest_limit ELSE cfg.account_limit END;
  SELECT * INTO r FROM private_ai.requests WHERE subject = p_subject AND request_id = p_id;
  IF FOUND THEN
    IF r.digest <> p_digest OR r.is_guest <> p_guest THEN
      RAISE EXCEPTION 'Request binding conflict' USING ERRCODE = '22023';
    END IF;
    RETURN private_ai.envelope(r, cap);
  END IF;
  bucket := (p_now AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  INSERT INTO private_ai.usage(subject, accepted_day) VALUES(p_subject, bucket) ON CONFLICT DO NOTHING;
  SELECT used + reserved INTO amount FROM private_ai.usage WHERE subject = p_subject AND accepted_day = bucket;
  IF amount >= cap THEN RETURN jsonb_build_object('status', 'quota_exhausted', 'acceptedDay', bucket, 'remaining', 0); END IF;
  INSERT INTO private_ai.global_attempts(accepted_day) VALUES(bucket) ON CONFLICT DO NOTHING;
  SELECT attempts INTO global_amount FROM private_ai.global_attempts WHERE accepted_day = bucket;
  IF global_amount >= cfg.global_attempt_limit THEN RETURN jsonb_build_object('status', 'global_cap'); END IF;
  UPDATE private_ai.usage SET reserved = reserved + 1 WHERE subject = p_subject AND accepted_day = bucket;
  UPDATE private_ai.global_attempts SET attempts = attempts + 1 WHERE accepted_day = bucket;
  INSERT INTO private_ai.requests VALUES(p_subject, p_id, p_guest, p_digest, bucket, 'reserved', gen_random_uuid(), p_now + interval '90 seconds', NULL, NULL, p_now)
    RETURNING * INTO r;
  RETURN private_ai.envelope(r, cap) || jsonb_build_object('dispatch', true);
END $$;

CREATE FUNCTION private_ai.finalize(p_subject uuid, p_id uuid, p_worker uuid, p_digest text, p_success boolean, p_result jsonb, p_now timestamptz) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE cfg private_ai.settings%ROWTYPE; r private_ai.requests%ROWTYPE; cap integer;
BEGIN
  IF p_subject IS NULL OR p_id IS NULL OR p_worker IS NULL OR p_digest IS NULL OR p_success IS NULL OR p_now IS NULL THEN
    RAISE EXCEPTION 'Invalid finalize binding' USING ERRCODE = '22023';
  END IF;
  IF (p_success AND (p_result IS NULL OR jsonb_typeof(p_result) <> 'object' OR octet_length(p_result::text) > 16384))
    OR (NOT p_success AND p_result IS NOT NULL) THEN
    RAISE EXCEPTION 'Invalid usable result' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO STRICT cfg FROM private_ai.settings WHERE singleton FOR UPDATE;
  PERFORM private_ai.maintain(p_now);
  SELECT * INTO r FROM private_ai.requests WHERE subject = p_subject AND request_id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('status', 'not_found'); END IF;
  IF r.worker <> p_worker OR r.digest <> p_digest THEN
    RAISE EXCEPTION 'Finalize binding conflict' USING ERRCODE = '22023';
  END IF;
  cap := CASE WHEN r.is_guest THEN cfg.guest_limit ELSE cfg.account_limit END;
  IF r.state = 'succeeded' THEN
    IF NOT p_success OR (r.result IS NOT NULL AND r.result <> p_result) THEN
      RAISE EXCEPTION 'Committed result conflict' USING ERRCODE = '22023';
    END IF;
    RETURN private_ai.envelope(r, cap);
  ELSIF r.state <> 'reserved' THEN
    RETURN private_ai.envelope(r, cap);
  END IF;
  UPDATE private_ai.usage SET reserved = reserved - 1, used = used + CASE WHEN p_success THEN 1 ELSE 0 END
    WHERE subject = r.subject AND accepted_day = r.accepted_day;
  UPDATE private_ai.requests SET state = CASE WHEN p_success THEN 'succeeded' ELSE 'failed' END,
    result = p_result, result_expires_at = CASE WHEN p_success THEN p_now + interval '24 hours' ELSE NULL END
    WHERE subject = p_subject AND request_id = p_id RETURNING * INTO r;
  RETURN private_ai.envelope(r, cap);
END $$;

CREATE FUNCTION public.reserve_ai_request_v1(p_subject uuid, p_is_guest boolean, p_request_id uuid, p_payload_digest text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT private_ai.reserve(p_subject, p_is_guest, p_request_id, p_payload_digest, clock_timestamp());
$$;
CREATE FUNCTION public.finalize_ai_request_v1(p_subject uuid, p_request_id uuid, p_worker_token uuid, p_payload_digest text, p_success boolean, p_result jsonb) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT private_ai.finalize(p_subject, p_request_id, p_worker_token, p_payload_digest, p_success, p_result, clock_timestamp());
$$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private_ai FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.reserve_ai_request_v1(uuid,boolean,uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_ai_request_v1(uuid,uuid,uuid,text,boolean,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_ai_request_v1(uuid,boolean,uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_ai_request_v1(uuid,uuid,uuid,text,boolean,jsonb) TO service_role;
COMMIT;
