-- Discovery Publication V2 schema, tables, and transactional publication procedures.
-- Implements immutable release storage tracking, CAS manifest activation, and public read projections.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS private_discovery_admin;

-- 1. Candidates table: stores frozen draft previews bound to actor and session
CREATE TABLE IF NOT EXISTS private_discovery_admin.release_candidates (
  preview_id uuid PRIMARY KEY,
  actor_id uuid NOT NULL,
  session_id uuid NOT NULL,
  request_id uuid NOT NULL,
  source_revision bigint NOT NULL,
  expected_active_version bigint NOT NULL DEFAULT 0,
  candidate_version bigint NOT NULL,
  preview_digest text NOT NULL,
  payload_text text,
  sha256 text,
  byte_length bigint,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_release_candidates_actor_req UNIQUE (actor_id, request_id)
);

-- 2. Operations table: tracks background publication workflow and CAS worker tokens
CREATE TABLE IF NOT EXISTS private_discovery_admin.release_operations (
  id uuid PRIMARY KEY,
  candidate_id uuid NOT NULL REFERENCES private_discovery_admin.release_candidates(preview_id) ON DELETE RESTRICT,
  request_hash text NOT NULL,
  state text NOT NULL CHECK (state IN ('pending', 'completed', 'needs_retry', 'conflict')),
  worker_token uuid NOT NULL,
  source_revision bigint NOT NULL,
  version bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Releases table: append-only immutable record of published objects
CREATE TABLE IF NOT EXISTS private_discovery_admin.releases (
  version bigint PRIMARY KEY CHECK (version >= 1 AND version <= 9007199254740991),
  candidate_id uuid NOT NULL UNIQUE REFERENCES private_discovery_admin.release_candidates(preview_id) ON DELETE RESTRICT,
  object_key text NOT NULL UNIQUE CHECK (object_key ~ '^releases/v2/[1-9][0-9]*\.json$'),
  sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  byte_length bigint NOT NULL CHECK (byte_length >= 1 AND byte_length <= 2097152),
  source_revision bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_releases_composite UNIQUE (version, object_key, sha256, byte_length)
);

-- 4. Public Release Manifest table: singleton active public version
CREATE TABLE IF NOT EXISTS public.discovery_release_manifest (
  id text PRIMARY KEY CHECK (id = 'current'),
  version bigint NOT NULL,
  object_key text NOT NULL,
  sha256 text NOT NULL,
  byte_length bigint NOT NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  contract text NOT NULL DEFAULT 'travelgo.discovery.manifest.v2' CHECK (contract = 'travelgo.discovery.manifest.v2'),
  schema_version int NOT NULL DEFAULT 2 CHECK (schema_version = 2),
  CONSTRAINT fk_manifest_release FOREIGN KEY (version, object_key, sha256, byte_length)
    REFERENCES private_discovery_admin.releases(version, object_key, sha256, byte_length) ON DELETE RESTRICT
);

ALTER TABLE public.discovery_release_manifest ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public manifest read-only" ON public.discovery_release_manifest;
CREATE POLICY "Public manifest read-only" ON public.discovery_release_manifest
  FOR SELECT TO anon, authenticated USING (true);

GRANT SELECT ON public.discovery_release_manifest TO anon, authenticated;

-- Function 1: Prepare discovery preview (Freezes current draft)
CREATE OR REPLACE FUNCTION public.prepare_discovery_preview(
  p_request_id uuid,
  p_expected_draft_revision bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private_discovery_admin, auth, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_role text;
  v_draft_rec record;
  v_expected_active bigint;
  v_candidate_version bigint;
  v_preview_id uuid;
  v_preview_digest text;
  v_expires_at timestamptz;
  v_session_id uuid := '00000000-0000-0000-0000-000000000000'::uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthorized: authentication required';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_caller;
  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;

  -- Lock draft state for read
  SELECT revision, payload INTO v_draft_rec
  FROM private_discovery_admin.draft
  WHERE singleton;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'draft_state_not_found';
  END IF;

  IF v_draft_rec.revision <> p_expected_draft_revision THEN
    RAISE EXCEPTION 'draft_revision_mismatch: expected %, actual %', p_expected_draft_revision, v_draft_rec.revision;
  END IF;

  SELECT coalesce(max(version), 0) INTO v_expected_active
  FROM public.discovery_release_manifest
  WHERE id = 'current';

  v_candidate_version := v_expected_active + 1;
  v_preview_id := gen_random_uuid();
  v_expires_at := now() + interval '15 minutes';

  v_preview_digest := encode(digest(
    p_expected_draft_revision::text || ':' || v_candidate_version::text || ':' || p_request_id::text,
    'sha256'
  ), 'hex');

  INSERT INTO private_discovery_admin.release_candidates (
    preview_id,
    actor_id,
    session_id,
    request_id,
    source_revision,
    expected_active_version,
    candidate_version,
    preview_digest,
    expires_at
  ) VALUES (
    v_preview_id,
    v_caller,
    v_session_id,
    p_request_id,
    p_expected_draft_revision,
    v_expected_active,
    v_candidate_version,
    v_preview_digest,
    v_expires_at
  );

  RETURN jsonb_build_object(
    'previewId', v_preview_id,
    'sourceRevision', p_expected_draft_revision,
    'expectedActiveVersion', v_expected_active,
    'candidateVersion', v_candidate_version,
    'previewDigest', v_preview_digest,
    'expiresAt', to_char(v_expires_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'frozenDraft', v_draft_rec.payload
  );
END;
$$;

-- Function 2: Stage candidate bytes
CREATE OR REPLACE FUNCTION public.stage_discovery_candidate(
  p_preview_id uuid,
  p_worker_token uuid,
  p_payload_text text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private_discovery_admin, pg_temp
AS $$
DECLARE
  v_candidate record;
  v_byte_length bigint;
  v_sha256 text;
  v_object_key text;
BEGIN
  SELECT * INTO v_candidate
  FROM private_discovery_admin.release_candidates
  WHERE preview_id = p_preview_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'candidate_not_found';
  END IF;

  IF now() > v_candidate.expires_at THEN
    RAISE EXCEPTION 'candidate_expired';
  END IF;

  v_byte_length := octet_length(p_payload_text);
  IF v_byte_length > 2097152 THEN
    RAISE EXCEPTION 'payload_oversize: % bytes exceeds 2097152 limit', v_byte_length;
  END IF;

  v_sha256 := encode(digest(convert_to(p_payload_text, 'UTF8'), 'sha256'), 'hex');
  v_object_key := 'releases/v2/' || v_candidate.candidate_version || '.json';

  UPDATE private_discovery_admin.release_candidates
  SET payload_text = p_payload_text,
      sha256 = v_sha256,
      byte_length = v_byte_length
  WHERE preview_id = p_preview_id;

  RETURN jsonb_build_object(
    'previewId', p_preview_id,
    'sha256', v_sha256,
    'byteLength', v_byte_length,
    'objectKey', v_object_key
  );
END;
$$;

-- Function 3: Begin publication
CREATE OR REPLACE FUNCTION public.begin_discovery_publication(
  p_request jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private_discovery_admin, auth, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_role text;
  v_preview_id uuid := (p_request->>'previewId')::uuid;
  v_preview_digest text := p_request->>'previewDigest';
  v_exp_draft_rev bigint := (p_request->>'expectedDraftRevision')::bigint;
  v_exp_active_ver bigint := (p_request->>'expectedActiveVersion')::bigint;
  v_candidate record;
  v_current_active bigint;
  v_op_id uuid;
  v_worker_token uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthorized: authentication required';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_caller;
  IF v_role <> 'admin' THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;

  SELECT * INTO v_candidate
  FROM private_discovery_admin.release_candidates
  WHERE preview_id = v_preview_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'candidate_not_found';
  END IF;

  IF now() > v_candidate.expires_at THEN
    RAISE EXCEPTION 'candidate_expired';
  END IF;

  IF v_candidate.preview_digest <> v_preview_digest THEN
    RAISE EXCEPTION 'preview_digest_mismatch';
  END IF;

  IF v_candidate.source_revision <> v_exp_draft_rev THEN
    RAISE EXCEPTION 'draft_revision_mismatch';
  END IF;

  IF v_candidate.expected_active_version <> v_exp_active_ver THEN
    RAISE EXCEPTION 'active_version_mismatch';
  END IF;

  IF v_candidate.payload_text IS NULL OR v_candidate.sha256 IS NULL THEN
    RAISE EXCEPTION 'candidate_not_staged';
  END IF;

  -- CAS check: current manifest must still match expectedActiveVersion
  SELECT coalesce(max(version), 0) INTO v_current_active
  FROM public.discovery_release_manifest
  WHERE id = 'current';

  IF v_current_active <> v_exp_active_ver THEN
    RAISE EXCEPTION 'concurrency_conflict: active version changed to %', v_current_active;
  END IF;

  v_op_id := gen_random_uuid();
  v_worker_token := gen_random_uuid();

  INSERT INTO private_discovery_admin.release_operations (
    id,
    candidate_id,
    request_hash,
    state,
    worker_token,
    source_revision,
    version
  ) VALUES (
    v_op_id,
    v_preview_id,
    encode(digest(p_request::text, 'sha256'), 'hex'),
    'pending',
    v_worker_token,
    v_exp_draft_rev,
    v_candidate.candidate_version
  );

  RETURN jsonb_build_object(
    'operationId', v_op_id,
    'workerToken', v_worker_token,
    'candidateVersion', v_candidate.candidate_version,
    'objectKey', 'releases/v2/' || v_candidate.candidate_version || '.json',
    'payloadText', v_candidate.payload_text,
    'sha256', v_candidate.sha256,
    'byteLength', v_candidate.byte_length
  );
END;
$$;

-- Function 4: Activate discovery release (Atomic CAS activation)
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
