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
