-- C6: account/operation truth, fenced Auth dispatch and idempotent reconcile.
-- Forward-only; historical migrations remain unchanged.
BEGIN;
ALTER TABLE private_admin.account_operations
  ADD COLUMN IF NOT EXISTS dispatched_at timestamptz,
  ADD COLUMN IF NOT EXISTS dispatch_actor_id uuid,
  ADD COLUMN IF NOT EXISTS dispatch_session_id uuid;
CREATE TABLE private_admin.account_reconcile_attempts(
  request_id uuid PRIMARY KEY, operation_id uuid NOT NULL REFERENCES private_admin.account_operations(id),
  actor_id uuid NOT NULL, payload_hash text NOT NULL CHECK(length(payload_hash)=64)
);
ALTER TABLE private_admin.account_reconcile_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private_admin.account_reconcile_attempts FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.admin_accounts(p_action text, p_request jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
  v_worker_token uuid;
  v_req_id uuid;
  v_target_id uuid;
  v_expected_rev bigint;
  v_action text;
  v_reason text;
  v_payload_hash text;
  v_target_state text;
  v_target_rev bigint;
  v_target_role text;
  v_active_admins bigint;
  v_new_rev bigint;
  v_op_state text;
  v_existing record;
  v_result jsonb;
  v_limit int;
  v_items jsonb;
  v_next_cursor jsonb := NULL;
BEGIN
  -- Authenticate and authorize admin actor
  v_actor_id := private_admin.require_admin();

  IF p_action = 'access' THEN
    SELECT a.revision INTO v_target_rev
    FROM private_admin.account_access a
    WHERE a.subject_id = v_actor_id;

    RETURN jsonb_build_object(
      'subjectId', v_actor_id,
      'role', 'admin',
      'accountRevision', coalesce(v_target_rev, 1),
      'allowed', true
    );

  ELSIF p_action = 'dashboard' THEN
    RETURN private_admin.read_dashboard((p_request->>'days')::int);

  ELSIF p_action = 'users' THEN
    v_limit := least(greatest(coalesce((p_request->>'limit')::int, 25), 1), 25);
    
    WITH filtered_users AS (
      SELECT
        u.id,
        p.full_name AS "fullName",
        u.email,
        p.role,
        a.state,
        a.revision,
        to_char(u.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS "createdAt",
        NULL::text AS "lastSignInAt",
        (a.state <> 'unlocking' AND NOT EXISTS (SELECT 1 FROM private_admin.account_operations op WHERE op.target_id=a.subject_id AND op.state <> 'completed')) AS "authSynced",
        u.created_at AS raw_created_at,
        row_number() OVER (ORDER BY u.created_at DESC, u.id DESC) AS rn,
        count(*) OVER () AS total_count
      FROM auth.users u
      JOIN public.profiles p ON p.id = u.id
      JOIN private_admin.account_access a ON a.subject_id = u.id
      WHERE u.deleted_at IS NULL
        AND (p_request->>'role' IS NULL OR p.role = p_request->>'role')
        AND (p_request->>'state' IS NULL OR a.state = p_request->>'state')
        AND (p_request->>'query' IS NULL OR (
          u.email ILIKE '%' || (p_request->>'query') || '%' OR
          p.full_name ILIKE '%' || (p_request->>'query') || '%'
        ))
        AND (
          p_request->'cursor' IS NULL OR
          (u.created_at, u.id) < (
            (p_request->'cursor'->>'createdAt')::timestamptz,
            (p_request->'cursor'->>'id')::uuid
          )
        )
      ORDER BY u.created_at DESC, u.id DESC
      LIMIT v_limit + 1
    )
    SELECT
      coalesce(jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'fullName', f."fullName",
          'email', f.email,
          'role', f.role,
          'state', f.state,
          'revision', f.revision,
          'createdAt', f."createdAt",
          'lastSignInAt', f."lastSignInAt",
          'authSynced', f."authSynced"
        ) ORDER BY f.rn ASC
      ) FILTER (WHERE f.rn <= v_limit), '[]'::jsonb),
      (
        SELECT jsonb_build_object('createdAt', last_item."createdAt", 'id', last_item.id)
        FROM filtered_users last_item
        WHERE last_item.rn = v_limit AND last_item.total_count > v_limit
      )
    INTO v_items, v_next_cursor
    FROM filtered_users f;

    RETURN jsonb_build_object(
      'items', coalesce(v_items, '[]'::jsonb),
      'nextCursor', v_next_cursor
    );

  ELSIF p_action = 'user' THEN
    v_target_id := (p_request->>'targetId')::uuid;
    IF v_target_id IS NULL THEN
      RAISE EXCEPTION 'missing targetId' USING ERRCODE = '42201';
    END IF;

    SELECT
      jsonb_build_object(
        'id', u.id,
        'fullName', p.full_name,
        'email', u.email,
        'role', p.role,
        'state', a.state,
        'revision', a.revision,
        'createdAt', to_char(u.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'lastSignInAt', NULL,
        'authSynced', (a.state <> 'unlocking' AND NOT EXISTS (SELECT 1 FROM private_admin.account_operations op WHERE op.target_id=a.subject_id AND op.state <> 'completed')),
        'audit', coalesce((
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', ae.id,
              'operationId', ae.operation_id,
              'actorId', ae.actor_id,
              'targetId', ae.target_id,
              'eventKind', ae.event_kind,
              'reason', ae.reason,
              'createdAt', to_char(ae.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
            ) ORDER BY ae.created_at DESC
          )
          FROM (
            SELECT * FROM private_admin.audit_events
            WHERE target_id = v_target_id
            ORDER BY created_at DESC
            LIMIT 50
          ) ae
        ), '[]'::jsonb),
        'pendingOperation', (
          SELECT jsonb_build_object('id',op.id,'targetId',op.target_id,'action',op.action,
            'state',op.state,'targetRevision',coalesce(op.result_revision,op.base_revision+1),'authSynced',false)
          FROM private_admin.account_operations op WHERE op.target_id=u.id
            AND op.state IN ('pending','needs_retry') LIMIT 1
        )
      ) INTO v_result
    FROM auth.users u
    JOIN public.profiles p ON p.id = u.id
    JOIN private_admin.account_access a ON a.subject_id = u.id
    WHERE u.id = v_target_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'target_not_found' USING ERRCODE = '40401';
    END IF;

    RETURN v_result;

  ELSIF p_action = 'mutate' THEN
    -- Parse parameters
    v_req_id := (p_request->>'requestId')::uuid;
    v_target_id := (p_request->>'targetId')::uuid;
    v_expected_rev := (p_request->>'expectedRevision')::bigint;
    v_action := (p_request->>'action');
    v_reason := trim(p_request->>'reason');

    IF v_req_id IS NULL OR v_target_id IS NULL OR v_expected_rev IS NULL OR v_action IS NULL OR v_reason IS NULL OR char_length(v_reason) < 1 OR char_length(v_reason) > 500 THEN
      RAISE EXCEPTION 'invalid_mutation_parameters' USING ERRCODE = '42201';
    END IF;

    IF v_action NOT IN ('lock', 'unlock', 'promote', 'demote') THEN
      RAISE EXCEPTION 'invalid_action' USING ERRCODE = '42201';
    END IF;

    -- Self-change is strictly denied
    IF v_target_id = v_actor_id THEN
      RAISE EXCEPTION 'self_change_denied' USING ERRCODE = '40901';
    END IF;

    -- Compute canonical payload hash
    v_payload_hash := encode(sha256(convert_to(p_request::text, 'UTF8')), 'hex');

    -- Acquire global serialization control lock
    PERFORM singleton FROM private_admin.control_lock WHERE singleton = true FOR UPDATE;
    PERFORM private_admin.require_admin();

    -- Idempotency check on requestId
    SELECT * INTO v_existing
    FROM private_admin.account_operations
    WHERE id = v_req_id;

    IF FOUND THEN
      IF v_existing.payload_hash = v_payload_hash AND v_existing.actor_id = v_actor_id THEN
        -- Replay existing operation
        RETURN jsonb_build_object(
          'id', v_existing.id,
          'targetId', v_existing.target_id,
          'action', v_existing.action,
          'state', v_existing.state,
          'targetRevision', coalesce(v_existing.result_revision, v_existing.base_revision + 1),
          'workerToken', v_existing.worker_token,
          'authSynced', (v_existing.state = 'completed')
        );
      ELSE
        RAISE EXCEPTION 'request_identity_conflict' USING ERRCODE = '40902';
      END IF;
    END IF;

    -- Fetch and lock target access and profile rows
    SELECT state, revision INTO v_target_state, v_target_rev
    FROM private_admin.account_access
    WHERE subject_id = v_target_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'missing_access_denies' USING ERRCODE = '40401';
    END IF;

    IF v_target_rev <> v_expected_rev THEN
      RAISE EXCEPTION 'revision_conflict' USING ERRCODE = '40900';
    END IF;

    SELECT role INTO v_target_role
    FROM public.profiles
    WHERE id = v_target_id
    FOR UPDATE;

    -- Last admin invariant protection: if target is active admin and action is lock or demote
    IF v_action IN ('lock', 'demote') AND v_target_role = 'admin' AND v_target_state = 'enabled' THEN
      SELECT count(*) INTO v_active_admins
      FROM public.profiles p
      JOIN private_admin.account_access a ON a.subject_id = p.id
      WHERE p.role = 'admin' AND a.state = 'enabled';

      IF v_active_admins <= 1 THEN
        RAISE EXCEPTION 'last_admin_preserved' USING ERRCODE = '40903';
      END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM private_admin.account_operations WHERE target_id=v_target_id AND state IN ('pending','needs_retry')) THEN
      RAISE EXCEPTION 'operation_in_progress' USING ERRCODE='40904';
    END IF;
    -- Apply mutation
    v_new_rev := v_expected_rev + 1;

    IF v_action = 'lock' THEN
      UPDATE private_admin.account_access
      SET state = 'locked', revision = v_new_rev, session_valid_after = now(), updated_at = now()
      WHERE subject_id = v_target_id;
      v_op_state := 'pending';

    ELSIF v_action = 'unlock' THEN
      UPDATE private_admin.account_access
      SET state = 'unlocking', revision = v_new_rev, updated_at = now()
      WHERE subject_id = v_target_id;
      v_op_state := 'pending';

    ELSIF v_action = 'promote' THEN
      UPDATE public.profiles SET role = 'admin', updated_at = now() WHERE id = v_target_id;
      UPDATE private_admin.account_access SET revision = v_new_rev, updated_at = now() WHERE subject_id = v_target_id;
      v_op_state := 'completed';

    ELSIF v_action = 'demote' THEN
      UPDATE public.profiles SET role = 'customer', updated_at = now() WHERE id = v_target_id;
      UPDATE private_admin.account_access SET revision = v_new_rev, updated_at = now() WHERE subject_id = v_target_id;
      v_op_state := 'completed';
    END IF;

    v_worker_token := gen_random_uuid();

    -- Record operation
    INSERT INTO private_admin.account_operations (
      id, target_id, actor_id, action, state, worker_token, base_revision, result_revision, reason, payload_hash
    ) VALUES (
      v_req_id, v_target_id, v_actor_id, v_action, v_op_state, v_worker_token, v_expected_rev,
      CASE WHEN v_op_state = 'completed' THEN v_new_rev ELSE NULL END,
      v_reason, v_payload_hash
    );

    -- Record audit events
    INSERT INTO private_admin.audit_events (operation_id, actor_id, target_id, event_kind, reason)
    VALUES (v_req_id, v_actor_id, v_target_id, 'begun', v_reason);

    IF v_op_state = 'completed' THEN
      INSERT INTO private_admin.audit_events (operation_id, actor_id, target_id, event_kind, reason)
      VALUES (v_req_id, v_actor_id, v_target_id, 'completed', v_reason);
    END IF;

    RETURN jsonb_build_object(
      'id', v_req_id,
      'targetId', v_target_id,
      'action', v_action,
      'state', v_op_state,
      'targetRevision', v_new_rev,
      'workerToken', v_worker_token,
      'authSynced', (v_op_state = 'completed')
    );


  ELSIF p_action = 'dispatch' THEN
    PERFORM singleton FROM private_admin.control_lock WHERE singleton=true FOR UPDATE;
    PERFORM private_admin.require_admin();
    SELECT * INTO v_existing FROM private_admin.account_operations WHERE id=(p_request->>'operationId')::uuid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'operation_not_found' USING ERRCODE='40401'; END IF;
    IF v_existing.worker_token IS DISTINCT FROM (p_request->>'workerToken')::uuid THEN
      RAISE EXCEPTION 'invalid_worker_token' USING ERRCODE='40301';
    END IF;
    IF coalesce(v_existing.dispatch_actor_id,v_existing.actor_id) <> v_actor_id THEN
      RAISE EXCEPTION 'admin_required' USING ERRCODE='42501';
    END IF;
    SELECT revision INTO v_target_rev FROM private_admin.account_access WHERE subject_id=v_existing.target_id FOR UPDATE;
    IF v_target_rev IS DISTINCT FROM (p_request->>'expectedRevision')::bigint
       OR v_target_rev <> coalesce(v_existing.result_revision,v_existing.base_revision+1) THEN
      RAISE EXCEPTION 'revision_conflict' USING ERRCODE='40900';
    END IF;
    IF v_existing.state <> 'pending' OR v_existing.dispatched_at IS NOT NULL THEN
      RETURN jsonb_build_object('dispatch',false);
    END IF;
    UPDATE private_admin.account_operations SET dispatched_at=clock_timestamp(), dispatch_actor_id=v_actor_id,
      dispatch_session_id=(nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'session_id')::uuid
      WHERE id=v_existing.id;
    RETURN jsonb_build_object('dispatch',true);

  ELSIF p_action = 'reconcile' THEN
    v_req_id := (p_request->>'requestId')::uuid;
    v_reason := trim(p_request->>'reason');
    IF v_req_id IS NULL OR v_reason IS NULL OR char_length(v_reason) NOT BETWEEN 1 AND 500 THEN
      RAISE EXCEPTION 'invalid_mutation_parameters' USING ERRCODE='42201';
    END IF;
    v_payload_hash := encode(sha256(convert_to(p_request::text,'UTF8')),'hex');
    PERFORM singleton FROM private_admin.control_lock WHERE singleton=true FOR UPDATE;
    PERFORM private_admin.require_admin();
    SELECT * INTO v_existing FROM private_admin.account_operations WHERE id=(p_request->>'operationId')::uuid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'operation_not_found' USING ERRCODE='40401'; END IF;
    SELECT revision INTO v_target_rev FROM private_admin.account_access WHERE subject_id=v_existing.target_id FOR UPDATE;
    IF v_target_rev IS DISTINCT FROM (p_request->>'expectedRevision')::bigint
       OR v_target_rev <> coalesce(v_existing.result_revision,v_existing.base_revision+1) THEN
      RAISE EXCEPTION 'revision_conflict' USING ERRCODE='40900';
    END IF;
    IF EXISTS (SELECT 1 FROM private_admin.account_reconcile_attempts WHERE request_id=v_req_id) THEN
      IF NOT EXISTS (SELECT 1 FROM private_admin.account_reconcile_attempts WHERE request_id=v_req_id
          AND actor_id=v_actor_id AND payload_hash=v_payload_hash) THEN
        RAISE EXCEPTION 'request_identity_conflict' USING ERRCODE='40902';
      END IF;
    ELSIF v_existing.state <> 'completed' THEN
      IF v_existing.state='pending' AND v_existing.dispatched_at > clock_timestamp()-interval '30 seconds' THEN
        RAISE EXCEPTION 'operation_in_progress' USING ERRCODE='40904';
      END IF;
      v_worker_token := gen_random_uuid();
      INSERT INTO private_admin.account_reconcile_attempts(request_id,operation_id,actor_id,payload_hash)
        VALUES(v_req_id,v_existing.id,v_actor_id,v_payload_hash);
      UPDATE private_admin.account_operations SET state='pending',worker_token=v_worker_token,
        dispatched_at=NULL,dispatch_actor_id=v_actor_id,dispatch_session_id=NULL,updated_at=now()
        WHERE id=v_existing.id;
      INSERT INTO private_admin.audit_events(operation_id,actor_id,target_id,event_kind,reason)
        VALUES(v_existing.id,v_actor_id,v_existing.target_id,'reconciled',v_reason)
        ON CONFLICT(operation_id,event_kind) DO NOTHING;
    END IF;
    RETURN public.admin_accounts('operation',jsonb_build_object('operationId',v_existing.id));

  ELSIF p_action = 'operation' THEN
    v_req_id := (p_request->>'operationId')::uuid;
    SELECT * INTO v_existing
    FROM private_admin.account_operations
    WHERE id = v_req_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'operation_not_found' USING ERRCODE = '40401';
    END IF;

    RETURN jsonb_build_object(
      'id', v_existing.id,
      'targetId', v_existing.target_id,
      'action', v_existing.action,
      'state', v_existing.state,
      'targetRevision', coalesce(v_existing.result_revision, v_existing.base_revision + 1),
      'workerToken', v_existing.worker_token,
      'authSynced', (v_existing.state = 'completed')
    );

  ELSE
    RAISE EXCEPTION 'unknown_action' USING ERRCODE = '42201';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_accounts(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_accounts(text, jsonb) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.complete_admin_account_operation(
  p_operation_id uuid,
  p_worker_token uuid,
  p_expected_revision bigint,
  p_auth_synced boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_op record;
  v_access record;
BEGIN
  IF current_setting('role', true) IS DISTINCT FROM 'service_role'
     AND session_user IS DISTINCT FROM 'service_role'
     AND coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;

  PERFORM singleton FROM private_admin.control_lock WHERE singleton = true FOR UPDATE;

  SELECT * INTO v_op
  FROM private_admin.account_operations
  WHERE id = p_operation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'operation_not_found' USING ERRCODE = '40401';
  END IF;

  IF p_worker_token IS NULL OR p_worker_token IS DISTINCT FROM v_op.worker_token THEN
    RAISE EXCEPTION 'invalid_worker_token' USING ERRCODE = '40301';
  END IF;

  SELECT * INTO v_access
  FROM private_admin.account_access
  WHERE subject_id = v_op.target_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'target_not_found' USING ERRCODE = '40401';
  END IF;

  IF v_access.revision IS DISTINCT FROM p_expected_revision OR coalesce(v_op.result_revision,v_op.base_revision+1) IS DISTINCT FROM p_expected_revision THEN
    RAISE EXCEPTION 'revision_mismatch' USING ERRCODE = '40900';
  END IF;

  IF v_op.state='completed' THEN
    RETURN jsonb_build_object('id',v_op.id,'targetId',v_op.target_id,'action',v_op.action,
      'state','completed','targetRevision',v_access.revision,'authSynced',true);
  END IF;
  IF v_op.dispatch_actor_id IS NOT NULL THEN
    PERFORM private_admin.require_account(v_op.dispatch_actor_id,v_op.dispatch_session_id);
    IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=v_op.dispatch_actor_id AND role='admin') THEN
      RAISE EXCEPTION 'admin_required' USING ERRCODE='42501';
    END IF;
  END IF;
  IF p_auth_synced THEN
    IF v_op.action = 'unlock' THEN
      UPDATE private_admin.account_access
      SET state = 'enabled', session_valid_after = now(), updated_at = now()
      WHERE subject_id = v_op.target_id;
    END IF;

    UPDATE private_admin.account_operations
    SET state = 'completed', result_revision = v_access.revision, updated_at = now()
    WHERE id = p_operation_id;

    INSERT INTO private_admin.audit_events (operation_id, actor_id, target_id, event_kind, reason)
    VALUES (p_operation_id, v_op.actor_id, v_op.target_id, 'completed', v_op.reason)
    ON CONFLICT (operation_id, event_kind) DO NOTHING;

    RETURN jsonb_build_object(
      'id', v_op.id,
      'targetId', v_op.target_id,
      'action', v_op.action,
      'state', 'completed',
      'targetRevision', v_access.revision,
      'authSynced', true
    );
  ELSE
    UPDATE private_admin.account_operations
    SET state = 'needs_retry', result_revision = v_access.revision, updated_at = now()
    WHERE id = p_operation_id;

    INSERT INTO private_admin.audit_events (operation_id, actor_id, target_id, event_kind, reason)
    VALUES (p_operation_id, v_op.actor_id, v_op.target_id, 'retry_required', v_op.reason)
    ON CONFLICT (operation_id, event_kind) DO NOTHING;

    RETURN jsonb_build_object(
      'id', v_op.id,
      'targetId', v_op.target_id,
      'action', v_op.action,
      'state', 'needs_retry',
      'targetRevision', v_access.revision,
      'authSynced', false
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_admin_account_operation(uuid, uuid, bigint, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_admin_account_operation(uuid, uuid, bigint, boolean) TO service_role;


COMMIT;
