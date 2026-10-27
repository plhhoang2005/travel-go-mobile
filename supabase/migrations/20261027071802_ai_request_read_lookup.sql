-- A3 read-only replay lookup. No reserve/maintain writes or quota changes.
BEGIN;
CREATE FUNCTION public.lookup_ai_request_v1(p_subject uuid,p_is_guest boolean,p_request_id uuid,p_payload_digest text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r private_ai.requests%ROWTYPE; cap integer; reply jsonb;
BEGIN
  IF p_subject IS NULL OR p_is_guest IS NULL OR p_request_id IS NULL OR p_payload_digest IS NULL
     OR p_payload_digest !~ '^[0-9a-f]{64}$' THEN RAISE EXCEPTION 'Invalid quota binding' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM private_ai.requests WHERE subject=p_subject AND request_id=p_request_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','not_found'); END IF;
  IF r.digest<>p_payload_digest OR r.is_guest<>p_is_guest THEN RAISE EXCEPTION 'Request binding conflict' USING ERRCODE='22023'; END IF;
  SELECT CASE WHEN p_is_guest THEN guest_limit ELSE account_limit END INTO cap FROM private_ai.settings WHERE singleton;
  reply:=private_ai.envelope(r,cap) || jsonb_build_object('workerToken',NULL);
  IF r.state='reserved' AND r.expires_at<=clock_timestamp() THEN
    reply:=reply || jsonb_build_object('status','expired','result',NULL);
  ELSIF r.state='succeeded' AND (r.result IS NULL OR r.result_expires_at<=clock_timestamp()) THEN
    reply:=reply || jsonb_build_object('status','result_expired','result',NULL);
  END IF;
  RETURN reply;
END $$;
REVOKE ALL ON FUNCTION public.lookup_ai_request_v1(uuid,boolean,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_ai_request_v1(uuid,boolean,uuid,text) TO service_role;
COMMIT;