-- Role-based high cap quota for administrators (100 daily quota limit), preserving 3 daily quota limit for standard users and guests.
BEGIN;

ALTER TABLE private_ai.settings
  ADD COLUMN IF NOT EXISTS admin_limit integer NOT NULL DEFAULT 100 CHECK (admin_limit BETWEEN 10 AND 500);

ALTER TABLE private_ai.settings DROP CONSTRAINT IF EXISTS settings_global_attempt_limit_check;
ALTER TABLE private_ai.settings ADD CONSTRAINT settings_global_attempt_limit_check CHECK (global_attempt_limit BETWEEN 1 AND 1000);

UPDATE private_ai.settings SET admin_limit = 100, global_attempt_limit = 500 WHERE singleton;

ALTER TABLE private_ai.usage DROP CONSTRAINT IF EXISTS usage_check;
ALTER TABLE private_ai.usage ADD CONSTRAINT usage_check CHECK (used + reserved <= 500);

ALTER TABLE private_ai.global_attempts DROP CONSTRAINT IF EXISTS global_attempts_attempts_check;
ALTER TABLE private_ai.global_attempts ADD CONSTRAINT global_attempts_attempts_check CHECK (attempts BETWEEN 0 AND 1000);

CREATE OR REPLACE FUNCTION private_ai.envelope(r private_ai.requests, p_limit integer) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS $$
  SELECT jsonb_build_object(
    'status', CASE WHEN (r).state = 'succeeded' AND (r).result IS NULL THEN 'result_expired' ELSE (r).state END,
    'requestId', (r).request_id, 'acceptedDay', (r).accepted_day,
    'workerToken', CASE WHEN (r).state = 'reserved' THEN (r).worker ELSE NULL END,
    'expiresAt', (r).expires_at, 'result', (r).result,
    'remaining', greatest(0, p_limit - u.used - u.reserved)
  ) FROM private_ai.usage u WHERE u.subject = (r).subject AND u.accepted_day = (r).accepted_day;
$$;

CREATE OR REPLACE FUNCTION private_ai.reserve(p_subject uuid, p_guest boolean, p_id uuid, p_digest text, p_now timestamptz) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE cfg private_ai.settings%ROWTYPE; r private_ai.requests%ROWTYPE;
  bucket date; cap integer; amount integer; global_amount integer;
  v_is_admin boolean := false;
BEGIN
  IF p_subject IS NULL OR p_guest IS NULL OR p_id IS NULL OR p_digest IS NULL
     OR length(p_digest) <> 64 OR p_digest ~ '[^0-9a-f]' OR p_now IS NULL THEN
    RAISE EXCEPTION 'Invalid quota binding' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO STRICT cfg FROM private_ai.settings WHERE singleton FOR UPDATE;
  PERFORM private_ai.maintain(p_now);

  IF NOT p_guest THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = p_subject AND role = 'admin'
    ) INTO v_is_admin;
  END IF;

  cap := CASE
    WHEN p_guest THEN cfg.guest_limit
    WHEN v_is_admin THEN cfg.admin_limit
    ELSE cfg.account_limit
  END;

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

CREATE OR REPLACE FUNCTION private_ai.finalize(p_subject uuid, p_id uuid, p_worker uuid, p_digest text, p_success boolean, p_result jsonb, p_now timestamptz) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE cfg private_ai.settings%ROWTYPE; r private_ai.requests%ROWTYPE; cap integer;
  v_is_admin boolean := false;
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

  IF NOT r.is_guest THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = r.subject AND role = 'admin'
    ) INTO v_is_admin;
  END IF;

  cap := CASE
    WHEN r.is_guest THEN cfg.guest_limit
    WHEN v_is_admin THEN cfg.admin_limit
    ELSE cfg.account_limit
  END;

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

CREATE OR REPLACE FUNCTION public.lookup_ai_request_v1(p_subject uuid,p_is_guest boolean,p_request_id uuid,p_payload_digest text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r private_ai.requests%ROWTYPE; cap integer; reply jsonb; v_is_admin boolean := false;
BEGIN
  IF p_subject IS NULL OR p_is_guest IS NULL OR p_request_id IS NULL OR p_payload_digest IS NULL
     OR p_payload_digest !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'Invalid quota binding' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM private_ai.requests WHERE subject=p_subject AND request_id=p_request_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','not_found'); END IF;
  IF r.digest<>p_payload_digest OR r.is_guest<>p_is_guest THEN RAISE EXCEPTION 'Request binding conflict' USING ERRCODE='22023'; END IF;

  IF NOT p_is_guest THEN
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_subject AND role = 'admin') INTO v_is_admin;
  END IF;

  SELECT CASE
    WHEN p_is_guest THEN guest_limit
    WHEN v_is_admin THEN admin_limit
    ELSE account_limit
  END INTO cap FROM private_ai.settings WHERE singleton;

  reply:=private_ai.envelope(r,cap) || jsonb_build_object('workerToken',NULL);
  IF r.state='reserved' AND r.expires_at<=clock_timestamp() THEN
    reply:=reply || jsonb_build_object('status','expired','result',NULL);
  ELSIF r.state='succeeded' AND (r.result IS NULL OR r.result_expires_at<=clock_timestamp()) THEN
    reply:=reply || jsonb_build_object('status','result_expired','result',NULL);
  END IF;
  RETURN reply;
END $$;

COMMIT;

