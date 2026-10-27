-- C7: retry the same preview/publication without replacing immutable source bytes.
BEGIN;
ALTER TABLE private_discovery_admin.release_candidates
  ADD COLUMN frozen_draft jsonb, ADD COLUMN prepared_at timestamptz;
ALTER TABLE private_discovery_admin.release_operations
  ADD COLUMN actor_id uuid, ADD COLUMN request_id text;
CREATE UNIQUE INDEX discovery_publication_request_identity
  ON private_discovery_admin.release_operations(actor_id,request_id)
  WHERE request_id IS NOT NULL;
ALTER TABLE private_discovery_admin.release_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_discovery_admin.release_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_discovery_admin.releases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA private_discovery_admin FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private_discovery_admin.c7_admin() RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid := auth.uid(); v_role text;
BEGIN
  -- Reuse the stricter account authority guard when it is installed (C6).
  IF to_regprocedure('private_admin.require_admin()') IS NOT NULL THEN
    EXECUTE 'SELECT private_admin.require_admin()' INTO v_id;
    RETURN v_id;
  END IF;
  IF v_id IS NULL THEN RAISE EXCEPTION 'unauthorized'; END IF;
  SELECT p.role INTO v_role FROM public.profiles p JOIN auth.users u ON u.id=p.id
    WHERE p.id=v_id AND u.deleted_at IS NULL AND (u.banned_until IS NULL OR u.banned_until <= now());
  IF v_role IS DISTINCT FROM 'admin' THEN RAISE EXCEPTION 'forbidden: admin role required'; END IF;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION private_discovery_admin.c7_admin() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.prepare_discovery_preview(p_request_id uuid,p_expected_draft_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid; v_c record; v_d record; v_active bigint; v_now timestamptz := now();
BEGIN
  v_actor := private_discovery_admin.c7_admin();
  IF p_request_id IS NULL OR p_expected_draft_revision IS NULL THEN RAISE EXCEPTION 'invalid_parameters'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text || ':preview:' || p_request_id::text,0));
  SELECT * INTO v_c FROM private_discovery_admin.release_candidates WHERE actor_id=v_actor AND request_id=p_request_id;
  IF FOUND THEN
    IF v_c.source_revision <> p_expected_draft_revision THEN RAISE EXCEPTION 'request_payload_mismatch'; END IF;
    IF v_c.frozen_draft IS NULL THEN RAISE EXCEPTION 'legacy_preview_replay_unavailable'; END IF;
  ELSE
    SELECT revision,payload INTO v_d FROM private_discovery_admin.draft WHERE singleton FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'draft_state_not_found'; END IF;
    IF v_d.revision <> p_expected_draft_revision THEN RAISE EXCEPTION 'draft_revision_mismatch'; END IF;
    SELECT coalesce(max(version),0) INTO v_active FROM public.discovery_release_manifest WHERE id='current';
    INSERT INTO private_discovery_admin.release_candidates(
      preview_id,actor_id,session_id,request_id,source_revision,expected_active_version,
      candidate_version,preview_digest,expires_at,frozen_draft,prepared_at)
    VALUES(gen_random_uuid(),v_actor,coalesce(nullif(auth.jwt()->>'session_id','')::uuid,'00000000-0000-0000-0000-000000000000'::uuid),
      p_request_id,p_expected_draft_revision,v_active,v_active+1,
      encode(public.digest(p_expected_draft_revision::text || ':' || (v_active+1)::text || ':' || p_request_id::text,'sha256'),'hex'),
      v_now+interval '15 minutes',v_d.payload,v_now) RETURNING * INTO v_c;
  END IF;
  RETURN jsonb_build_object('previewId',v_c.preview_id,'sourceRevision',v_c.source_revision,
    'expectedActiveVersion',v_c.expected_active_version,'candidateVersion',v_c.candidate_version,
    'previewDigest',v_c.preview_digest,'expiresAt',to_char(v_c.expires_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'preparedAt',to_char(v_c.prepared_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'frozenDraft',v_c.frozen_draft);
END $$;

CREATE OR REPLACE FUNCTION public.stage_discovery_candidate(p_preview_id uuid,p_worker_token uuid,p_payload_text text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_c record; v_sha text; v_len bigint;
BEGIN
  SELECT * INTO v_c FROM private_discovery_admin.release_candidates WHERE preview_id=p_preview_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'candidate_not_found'; END IF;
  IF v_c.payload_text IS NOT NULL AND v_c.payload_text IS DISTINCT FROM p_payload_text THEN RAISE EXCEPTION 'candidate_immutable'; END IF;
  IF v_c.payload_text IS NULL AND now()>v_c.expires_at THEN RAISE EXCEPTION 'candidate_expired'; END IF;
  v_len:=octet_length(p_payload_text);
  IF v_len IS NULL OR v_len<1 OR v_len>2097152 THEN RAISE EXCEPTION 'payload_oversize'; END IF;
  v_sha:=encode(public.digest(convert_to(p_payload_text,'UTF8'),'sha256'),'hex');
  UPDATE private_discovery_admin.release_candidates SET payload_text=p_payload_text,sha256=v_sha,byte_length=v_len WHERE preview_id=p_preview_id;
  RETURN jsonb_build_object('sha256',v_sha,'byteLength',v_len,'objectKey','releases/v2/' || v_c.candidate_version || '.json');
END $$;

CREATE OR REPLACE FUNCTION public.begin_discovery_publication(p_request jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid; v_c record; v_op record; v_id uuid := (p_request->>'previewId')::uuid;
  v_request text; v_hash text; v_active bigint;
BEGIN
  v_actor:=private_discovery_admin.c7_admin();
  v_request:=coalesce(p_request->>'requestId','legacy:' || v_id::text);
  IF v_request IS NULL OR length(v_request)>128 OR length(v_request)=0 THEN RAISE EXCEPTION 'invalid_parameters'; END IF;
  v_hash:=encode(public.digest(p_request::text,'sha256'),'hex');
  PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text || ':publish:' || v_request,0));
  SELECT * INTO v_op FROM private_discovery_admin.release_operations WHERE actor_id=v_actor AND request_id=v_request;
  IF FOUND THEN
    IF v_op.request_hash<>v_hash THEN RAISE EXCEPTION 'request_payload_mismatch'; END IF;
  ELSE
    SELECT * INTO v_c FROM private_discovery_admin.release_candidates WHERE preview_id=v_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'candidate_not_found'; END IF;
    IF v_c.actor_id<>v_actor THEN RAISE EXCEPTION 'forbidden: candidate owner'; END IF;
    IF v_c.preview_digest IS DISTINCT FROM p_request->>'previewDigest' THEN RAISE EXCEPTION 'preview_digest_mismatch'; END IF;
    IF v_c.source_revision IS DISTINCT FROM (p_request->>'expectedDraftRevision')::bigint THEN RAISE EXCEPTION 'draft_revision_mismatch'; END IF;
    IF v_c.expected_active_version IS DISTINCT FROM (p_request->>'expectedActiveVersion')::bigint THEN RAISE EXCEPTION 'active_version_mismatch'; END IF;
    -- Historical operations remain intact. Reuse an exact matching historical request without inventing an identity.
    SELECT * INTO v_op FROM private_discovery_admin.release_operations
      WHERE candidate_id=v_id AND request_hash=v_hash AND request_id IS NULL ORDER BY created_at,id LIMIT 1;
    IF NOT FOUND THEN
      IF now()>v_c.expires_at THEN RAISE EXCEPTION 'candidate_expired'; END IF;
      IF v_c.payload_text IS NULL THEN RAISE EXCEPTION 'candidate_not_staged'; END IF;
      SELECT coalesce(max(version),0) INTO v_active FROM public.discovery_release_manifest WHERE id='current';
      IF v_active<>v_c.expected_active_version THEN RAISE EXCEPTION 'concurrency_conflict'; END IF;
      INSERT INTO private_discovery_admin.release_operations(id,candidate_id,request_hash,state,worker_token,source_revision,version,actor_id,request_id)
      VALUES(gen_random_uuid(),v_id,v_hash,'pending',gen_random_uuid(),v_c.source_revision,v_c.candidate_version,v_actor,v_request)
      RETURNING * INTO v_op;
    END IF;
  END IF;
  SELECT * INTO v_c FROM private_discovery_admin.release_candidates WHERE preview_id=v_op.candidate_id;
  IF v_c.actor_id<>v_actor THEN RAISE EXCEPTION 'forbidden: candidate owner'; END IF;
  RETURN jsonb_build_object('operationId',v_op.id,'workerToken',v_op.worker_token,'candidateVersion',v_op.version,
    'state',v_op.state,'sourceRevision',v_op.source_revision,'objectKey','releases/v2/' || v_op.version || '.json',
    'payloadText',v_c.payload_text,'sha256',v_c.sha256,'byteLength',v_c.byte_length);
END $$;

CREATE FUNCTION public.get_discovery_publication_operation(p_operation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid; v_op record;
BEGIN
  v_actor:=private_discovery_admin.c7_admin();
  SELECT o.* INTO v_op FROM private_discovery_admin.release_operations o
    JOIN private_discovery_admin.release_candidates c ON c.preview_id=o.candidate_id
    WHERE o.id=p_operation_id AND c.actor_id=v_actor;
  IF NOT FOUND THEN RAISE EXCEPTION 'operation_not_found'; END IF;
  RETURN jsonb_build_object('state',v_op.state,'version',v_op.version,'sourceRevision',v_op.source_revision);
END $$;

REVOKE ALL ON FUNCTION public.prepare_discovery_preview(uuid,bigint),public.begin_discovery_publication(jsonb),public.get_discovery_publication_operation(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.prepare_discovery_preview(uuid,bigint),public.begin_discovery_publication(jsonb),public.get_discovery_publication_operation(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.stage_discovery_candidate(uuid,uuid,text),public.activate_discovery_release(uuid,uuid,text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.stage_discovery_candidate(uuid,uuid,text),public.activate_discovery_release(uuid,uuid,text,bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.activate_discovery_release(
  p_operation_id uuid,
  p_worker_token uuid,
  p_readback_sha256 text,
  p_readback_length bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private_discovery_admin, auth, pg_temp
AS $$
DECLARE
  v_op record;
  v_candidate record;
  v_actor_role text;
  v_object_key text;
  v_current_active bigint;
BEGIN
  -- Lock operation
  SELECT * INTO v_op
  FROM private_discovery_admin.release_operations
  WHERE id = p_operation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'operation_not_found';
  END IF;

  IF v_op.worker_token <> p_worker_token THEN
    RAISE EXCEPTION 'invalid_worker_token';
  END IF;

  IF v_op.state = 'completed' THEN
    RETURN jsonb_build_object(
      'operationId', p_operation_id,
      'state', 'completed',
      'version', v_op.version
    );
  END IF;

  IF v_op.state <> 'pending' THEN
    RAISE EXCEPTION 'operation_not_pending: current state is %', v_op.state;
  END IF;

  SELECT * INTO v_candidate
  FROM private_discovery_admin.release_candidates
  WHERE preview_id = v_op.candidate_id;

  -- Re-verify actor still has admin role
  SELECT role INTO v_actor_role FROM public.profiles WHERE id = v_candidate.actor_id;
  IF v_actor_role <> 'admin' THEN
    UPDATE private_discovery_admin.release_operations SET state = 'conflict', updated_at = now() WHERE id = p_operation_id;
    RAISE EXCEPTION 'actor_role_revoked: candidate actor is no longer admin';
  END IF;

  -- A revoked/locked account or expired session cannot finish an in-flight publication.
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=v_candidate.actor_id
      AND deleted_at IS NULL AND (banned_until IS NULL OR banned_until<=now())) THEN
    RAISE EXCEPTION 'forbidden: candidate actor unavailable';
  END IF;
  IF v_candidate.session_id <> '00000000-0000-0000-0000-000000000000'::uuid AND NOT EXISTS (
      SELECT 1 FROM auth.sessions WHERE id=v_candidate.session_id AND user_id=v_candidate.actor_id
      AND (not_after IS NULL OR not_after>now())) THEN
    RAISE EXCEPTION 'forbidden: candidate session expired';
  END IF;
  -- Verify readback integrity
  IF v_candidate.sha256 <> p_readback_sha256 OR v_candidate.byte_length <> p_readback_length THEN
    UPDATE private_discovery_admin.release_operations SET state = 'needs_retry', updated_at = now() WHERE id = p_operation_id;
    RAISE EXCEPTION 'readback_integrity_failure';
  END IF;

  -- CAS check: current active version
  SELECT coalesce(max(version), 0) INTO v_current_active
  FROM public.discovery_release_manifest
  WHERE id = 'current';

  IF v_current_active <> v_candidate.expected_active_version THEN
    UPDATE private_discovery_admin.release_operations SET state = 'conflict', updated_at = now() WHERE id = p_operation_id;
    RAISE EXCEPTION 'concurrency_conflict: active version changed';
  END IF;

  v_object_key := 'releases/v2/' || v_candidate.candidate_version || '.json';

  -- 1. Insert immutable release record
  INSERT INTO private_discovery_admin.releases (
    version,
    candidate_id,
    object_key,
    sha256,
    byte_length,
    source_revision
  ) VALUES (
    v_candidate.candidate_version,
    v_candidate.preview_id,
    v_object_key,
    v_candidate.sha256,
    v_candidate.byte_length,
    v_candidate.source_revision
  );

  -- 2. Activate in public manifest
  INSERT INTO public.discovery_release_manifest (
    id,
    version,
    object_key,
    sha256,
    byte_length,
    published_at
  ) VALUES (
    'current',
    v_candidate.candidate_version,
    v_object_key,
    v_candidate.sha256,
    v_candidate.byte_length,
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    version = EXCLUDED.version,
    object_key = EXCLUDED.object_key,
    sha256 = EXCLUDED.sha256,
    byte_length = EXCLUDED.byte_length,
    published_at = EXCLUDED.published_at;

  -- 3. Mark operation completed
  UPDATE private_discovery_admin.release_operations
  SET state = 'completed',
      version = v_candidate.candidate_version,
      updated_at = now()
  WHERE id = p_operation_id;

  RETURN jsonb_build_object(
    'operationId', p_operation_id,
    'state', 'completed',
    'version', v_candidate.candidate_version,
    'publishedAt', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  );
END;
$$;
COMMIT;