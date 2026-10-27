-- Verification tests for Discovery Publication V2 schema and procedures.

BEGIN;

-- Test fixtures
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  v_admin_id uuid := 'e0000000-0000-0000-0000-000000000001'::uuid;
  v_cust_id  uuid := 'e0000000-0000-0000-0000-000000000002'::uuid;
  v_req_id   uuid := 'e0000000-0000-0000-0000-000000000010'::uuid;
  v_preview  jsonb;
  v_preview_id uuid;
  v_stage    jsonb;
  v_begin    jsonb;
  v_op_id    uuid;
  v_worker_token uuid;
  v_sha256   text;
  v_length   bigint;
  v_act      jsonb;
  v_manifest record;
BEGIN
  -- Setup test users
  INSERT INTO auth.users (id, email) VALUES
    (v_admin_id, 'admin_pub@travelgo.vn'),
    (v_cust_id, 'cust_pub@travelgo.vn')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.profiles (id, full_name, role) VALUES
    (v_admin_id, 'Admin Publisher', 'admin'),
    (v_cust_id, 'Customer User', 'customer')
  ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

  -- Ensure draft table has revision 1 for tests
  UPDATE private_discovery_admin.draft
  SET revision = 1
  WHERE singleton;

  -- 1. Non-admin caller MUST be rejected
  PERFORM set_config('request.jwt.claim.sub', v_cust_id::text, true);
  BEGIN
    PERFORM public.prepare_discovery_preview(v_req_id, 1);
    RAISE EXCEPTION 'Test failed: customer prepared preview without admin authority';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%forbidden: admin role required%' THEN
      RAISE EXCEPTION 'Unexpected error for customer: %', sqlerrm;
    END IF;
  END;

  -- 2. Admin caller prepares preview
  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  v_preview := public.prepare_discovery_preview(v_req_id, 1);
  v_preview_id := (v_preview->>'previewId')::uuid;

  IF (v_preview->>'expectedActiveVersion')::bigint <> 0 THEN
    RAISE EXCEPTION 'Expected active version 0, got %', v_preview->>'expectedActiveVersion';
  END IF;

  IF (v_preview->>'candidateVersion')::bigint <> 1 THEN
    RAISE EXCEPTION 'Expected candidate version 1, got %', v_preview->>'candidateVersion';
  END IF;

  -- 3. Stage candidate bytes
  v_stage := public.stage_discovery_candidate(
    v_preview_id,
    gen_random_uuid(),
    '{"contract": "travelgo.discovery.release.v2", "version": 1}'
  );
  v_sha256 := v_stage->>'sha256';
  v_length := (v_stage->>'byteLength')::bigint;

  -- 4. Begin publication
  v_begin := public.begin_discovery_publication(jsonb_build_object(
    'previewId', v_preview_id,
    'previewDigest', v_preview->>'previewDigest',
    'expectedDraftRevision', 1,
    'expectedActiveVersion', 0
  ));
  v_op_id := (v_begin->>'operationId')::uuid;
  v_worker_token := (v_begin->>'workerToken')::uuid;

  -- Same legacy request shape must replay, not start another operation.
  IF (public.begin_discovery_publication(jsonb_build_object(
    'previewId', v_preview_id, 'previewDigest', v_preview->>'previewDigest',
    'expectedDraftRevision', 1, 'expectedActiveVersion', 0
  ))->>'operationId')::uuid <> v_op_id THEN
    RAISE EXCEPTION 'C7 retry created a second operation';
  END IF;

  -- Frozen preview replay cannot read a newer draft under an old identity.
  UPDATE private_discovery_admin.draft SET revision=2 WHERE singleton;
  IF public.prepare_discovery_preview(v_req_id,1)->>'previewId' <> v_preview->>'previewId' THEN
    RAISE EXCEPTION 'Preview replay replaced candidate';
  END IF;
  BEGIN
    PERFORM public.prepare_discovery_preview(v_req_id,2);
    RAISE EXCEPTION 'FAILED expected request_payload_mismatch';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%request_payload_mismatch%' THEN RAISE; END IF;
  END;
  UPDATE private_discovery_admin.draft SET revision=1 WHERE singleton;
  BEGIN
    PERFORM public.begin_discovery_publication(jsonb_build_object(
      'previewId',v_preview_id,'previewDigest','altered','expectedDraftRevision',1,'expectedActiveVersion',0));
    RAISE EXCEPTION 'FAILED expected request_payload_mismatch';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%request_payload_mismatch%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.stage_discovery_candidate(v_preview_id,gen_random_uuid(),'different bytes');
    RAISE EXCEPTION 'FAILED expected candidate_immutable';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%candidate_immutable%' THEN RAISE; END IF;
  END;
  -- 5. Readback failure MUST NOT activate manifest
  BEGIN
    PERFORM public.activate_discovery_release(
      v_op_id,
      v_worker_token,
      '0000000000000000000000000000000000000000000000000000000000000000',
      v_length
    );
    RAISE EXCEPTION 'Test failed: readback mismatch did not abort activation';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%readback_integrity_failure%' THEN
      RAISE EXCEPTION 'Unexpected error on readback mismatch: %', sqlerrm;
    END IF;
  END;

  -- Reset operation to pending for clean activation test
  UPDATE private_discovery_admin.release_operations SET state = 'pending' WHERE id = v_op_id;

  -- 6. Successful activation
  v_act := public.activate_discovery_release(
    v_op_id,
    v_worker_token,
    v_sha256,
    v_length
  );

  IF v_act->>'state' <> 'completed' OR (v_act->>'version')::bigint <> 1 THEN
    RAISE EXCEPTION 'Activation failed: %', v_act;
  END IF;

  -- 7. Verify public manifest row
  SELECT * INTO v_manifest FROM public.discovery_release_manifest WHERE id = 'current';
  IF NOT FOUND OR v_manifest.version <> 1 OR v_manifest.sha256 <> v_sha256 THEN
    RAISE EXCEPTION 'Public manifest row does not match activated release: %', v_manifest;
  END IF;

  -- Completed replay is checked before candidate expiry / active-version checks.
  UPDATE private_discovery_admin.release_candidates SET expires_at=now()-interval '1 hour' WHERE preview_id=v_preview_id;
  IF public.begin_discovery_publication(jsonb_build_object(
    'previewId',v_preview_id,'previewDigest',v_preview->>'previewDigest',
    'expectedDraftRevision',1,'expectedActiveVersion',0))->>'state' <> 'completed' THEN
    RAISE EXCEPTION 'Completed operation did not replay';
  END IF;
  IF public.get_discovery_publication_operation(v_op_id)->>'state' <> 'completed' THEN RAISE EXCEPTION 'Outcome read failed'; END IF;
  -- Execute actual authenticated and anon roles, not only postgres with a synthetic subject.
  SET LOCAL ROLE authenticated;
  IF public.get_discovery_publication_operation(v_op_id)->>'state' <> 'completed' THEN RAISE EXCEPTION 'Admin role positive failed'; END IF;
  BEGIN
    PERFORM public.stage_discovery_candidate(v_preview_id,gen_random_uuid(),'x');
    RAISE EXCEPTION 'FAILED worker RPC exposed to authenticated';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('request.jwt.claim.sub',v_cust_id::text,true);
  BEGIN
    PERFORM public.get_discovery_publication_operation(v_op_id);
    RAISE EXCEPTION 'FAILED customer read operation';
  EXCEPTION WHEN OTHERS THEN
    IF sqlerrm NOT LIKE '%forbidden%' THEN RAISE; END IF;
  END;
  RESET ROLE;
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.prepare_discovery_preview(gen_random_uuid(),1);
    RAISE EXCEPTION 'FAILED anon preview';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
  -- 8. Verify public read-only access
  PERFORM set_config('request.jwt.claim.sub', '', true); -- anon
  SELECT * INTO v_manifest FROM public.discovery_release_manifest WHERE id = 'current';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Anon cannot read public manifest';
  END IF;

  RAISE NOTICE 'discovery_publication.sql: ALL 8 TEST INVARIANTS PASSED';
END;
$$;

ROLLBACK;

-- A real two-connection race on the same caller/request identity.
CREATE EXTENSION IF NOT EXISTS dblink;
DO $$
DECLARE v_actor uuid := 'e1000000-0000-4000-8000-000000000001'; v_preview jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES(v_actor,'c7-concurrent@example.invalid');
  INSERT INTO public.profiles(id,full_name,role) VALUES(v_actor,'C7 concurrent fixture','admin')
    ON CONFLICT(id) DO UPDATE SET role=EXCLUDED.role;
  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  SELECT public.prepare_discovery_preview('e1000000-0000-4000-8000-000000000010',revision)
    INTO v_preview FROM private_discovery_admin.draft WHERE singleton;
  PERFORM public.stage_discovery_candidate((v_preview->>'previewId')::uuid,gen_random_uuid(),'{"c7":"concurrent"}');
END $$;
DO $$
DECLARE v_c record; v_req jsonb; v_query text; v_a text; v_b text; v_dsn text;
BEGIN
  SELECT * INTO v_c FROM private_discovery_admin.release_candidates
    WHERE actor_id='e1000000-0000-4000-8000-000000000001';
  v_req:=jsonb_build_object('requestId','c7-concurrent','previewId',v_c.preview_id,
    'previewDigest',v_c.preview_digest,'expectedDraftRevision',v_c.source_revision,
    'expectedActiveVersion',v_c.expected_active_version);
  v_query:=format('SELECT public.begin_discovery_publication(%L::jsonb)::text FROM (SELECT set_config(''request.jwt.claim.sub'',%L,false) AS subject) a WHERE a.subject<>''''',v_req::text,v_c.actor_id::text);
  v_dsn:=format('host=127.0.0.1 port=%s dbname=%s user=postgres',current_setting('port'),current_database());
  PERFORM dblink_connect('c7a',v_dsn); PERFORM dblink_connect('c7b',v_dsn);
  PERFORM dblink_send_query('c7a',v_query); PERFORM dblink_send_query('c7b',v_query);
  SELECT result INTO v_a FROM dblink_get_result('c7a') AS t(result text);
  SELECT result INTO v_b FROM dblink_get_result('c7b') AS t(result text);
  PERFORM dblink_disconnect('c7a'); PERFORM dblink_disconnect('c7b');
  IF v_a::jsonb->>'operationId' IS DISTINCT FROM v_b::jsonb->>'operationId' THEN RAISE EXCEPTION 'Concurrent replay returned different operations'; END IF;
  IF (SELECT count(*) FROM private_discovery_admin.release_operations WHERE request_id='c7-concurrent')<>1 THEN RAISE EXCEPTION 'Concurrent duplicate operation'; END IF;
END $$;
