-- Migration: 20261023062634_admin_account_control.sql
-- M_CONTROL: Admin account control, integrity matrix, authority, and audit invariants.
BEGIN;

-- 1. Create tables in private_admin schema
CREATE TABLE IF NOT EXISTS private_admin.account_access (
  subject_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  state text NOT NULL CHECK (state IN ('enabled', 'locked', 'unlocking')),
  revision bigint NOT NULL CHECK (revision >= 1 AND revision <= 9007199254740991),
  session_valid_after timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private_admin.account_access ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private_admin.account_access FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS private_admin.control_lock (
  singleton boolean PRIMARY KEY CHECK (singleton = true)
);

INSERT INTO private_admin.control_lock (singleton) VALUES (true)
ON CONFLICT (singleton) DO NOTHING;

ALTER TABLE private_admin.control_lock ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private_admin.control_lock FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS private_admin.account_operations (
  id uuid PRIMARY KEY,
  target_id uuid NOT NULL REFERENCES private_admin.account_access(subject_id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('lock', 'unlock', 'promote', 'demote', 'reconcile')),
  state text NOT NULL CHECK (state IN ('pending', 'completed', 'needs_retry')),
  base_revision bigint NOT NULL CHECK (base_revision >= 1),
  result_revision bigint CHECK (result_revision IS NULL OR result_revision >= base_revision),
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS one_pending_operation_per_target
  ON private_admin.account_operations(target_id)
  WHERE state IN ('pending', 'needs_retry');

CREATE INDEX IF NOT EXISTS idx_account_operations_target_created
  ON private_admin.account_operations(target_id, created_at DESC);

ALTER TABLE private_admin.account_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private_admin.account_operations FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS private_admin.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id uuid NOT NULL REFERENCES private_admin.account_operations(id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL,
  target_id uuid NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN ('begun', 'completed', 'retry_required', 'reconciled')),
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT one_event_kind_per_op UNIQUE (operation_id, event_kind)
);

CREATE INDEX IF NOT EXISTS idx_audit_events_target_created
  ON private_admin.audit_events(target_id, created_at DESC);

ALTER TABLE private_admin.audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private_admin.audit_events FROM PUBLIC, anon, authenticated, service_role;

-- 2. Backfill existing users in auth.users
INSERT INTO private_admin.account_access (subject_id, state, revision, session_valid_after)
SELECT
  u.id,
  CASE WHEN u.banned_until IS NOT NULL AND u.banned_until > now() THEN 'locked' ELSE 'enabled' END,
  1,
  '-infinity'::timestamptz
FROM auth.users u
ON CONFLICT (subject_id) DO NOTHING;

-- 3. Automatic account_access creation on new auth.users
CREATE OR REPLACE FUNCTION private_admin.handle_auth_user_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO private_admin.account_access (subject_id, state, revision, session_valid_after)
  VALUES (
    NEW.id,
    CASE WHEN NEW.banned_until IS NOT NULL AND NEW.banned_until > now() THEN 'locked' ELSE 'enabled' END,
    1,
    '-infinity'::timestamptz
  )
  ON CONFLICT (subject_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_access ON auth.users;
CREATE TRIGGER on_auth_user_created_access
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION private_admin.handle_auth_user_created();

-- 4. Schema USAGE grant for authenticated (to evaluate current_account_enabled predicate)
GRANT USAGE ON SCHEMA private_admin TO authenticated, service_role;

-- 5. Helper & Security Functions

-- 5.1 private_admin.current_account_enabled()
CREATE OR REPLACE FUNCTION private_admin.current_account_enabled()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sub uuid;
  v_session_id uuid;
  v_jwt jsonb;
  v_state text;
  v_valid_after timestamptz;
  v_session_created timestamptz;
  v_session_not_after timestamptz;
  v_banned_until timestamptz;
  v_deleted_at timestamptz;
  v_is_anon boolean;
BEGIN
  BEGIN
    v_sub := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    RETURN false;
  END;
  IF v_sub IS NULL THEN
    RETURN false;
  END IF;

  BEGIN
    v_jwt := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
    v_session_id := nullif(v_jwt->>'session_id', '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_session_id := NULL;
  END;

  SELECT is_anonymous, deleted_at, banned_until
  INTO v_is_anon, v_deleted_at, v_banned_until
  FROM auth.users
  WHERE id = v_sub;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF coalesce(v_is_anon, false) OR v_deleted_at IS NOT NULL OR (v_banned_until IS NOT NULL AND v_banned_until > now()) THEN
    RETURN false;
  END IF;

  SELECT state, session_valid_after
  INTO v_state, v_valid_after
  FROM private_admin.account_access
  WHERE subject_id = v_sub;

  IF NOT FOUND OR v_state <> 'enabled' THEN
    RETURN false;
  END IF;

  IF v_session_id IS NOT NULL THEN
    SELECT created_at, not_after
    INTO v_session_created, v_session_not_after
    FROM auth.sessions
    WHERE id = v_session_id AND user_id = v_sub;

    IF NOT FOUND THEN
      RETURN false;
    END IF;

    IF (v_session_not_after IS NOT NULL AND v_session_not_after <= now()) OR v_session_created < v_valid_after THEN
      RETURN false;
    END IF;
  END IF;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION private_admin.current_account_enabled() TO authenticated;

-- 5.2 private_admin.require_account(p_subject uuid, p_session_id uuid)
CREATE OR REPLACE FUNCTION private_admin.require_account(p_subject uuid, p_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_state text;
  v_valid_after timestamptz;
  v_session_created timestamptz;
  v_session_not_after timestamptz;
  v_banned_until timestamptz;
  v_deleted_at timestamptz;
  v_is_anon boolean;
BEGIN
  IF p_subject IS NULL THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT is_anonymous, deleted_at, banned_until
  INTO v_is_anon, v_deleted_at, v_banned_until
  FROM auth.users
  WHERE id = p_subject;

  IF NOT FOUND OR coalesce(v_is_anon, false) OR v_deleted_at IS NOT NULL OR (v_banned_until IS NOT NULL AND v_banned_until > now()) THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT state, session_valid_after
  INTO v_state, v_valid_after
  FROM private_admin.account_access
  WHERE subject_id = p_subject;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'missing_access_denies' USING ERRCODE = '40401';
  END IF;

  IF v_state <> 'enabled' THEN
    RAISE EXCEPTION 'account_locked' USING ERRCODE = '40301';
  END IF;

  IF p_session_id IS NOT NULL THEN
    SELECT created_at, not_after
    INTO v_session_created, v_session_not_after
    FROM auth.sessions
    WHERE id = p_session_id AND user_id = p_subject;

    IF NOT FOUND OR (v_session_not_after IS NOT NULL AND v_session_not_after <= now()) OR v_session_created < v_valid_after THEN
      RAISE EXCEPTION 'invalid_session' USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN p_subject;
END;
$$;

-- 5.3 private_admin.require_admin()
CREATE OR REPLACE FUNCTION private_admin.require_admin()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sub uuid;
  v_session_id uuid;
  v_jwt jsonb;
  v_role text;
BEGIN
  BEGIN
    v_sub := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_sub := NULL;
  END;

  IF v_sub IS NULL THEN
    RAISE EXCEPTION 'unauthorized: missing sub claim' USING ERRCODE = '42501';
  END IF;

  BEGIN
    v_jwt := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
    v_session_id := nullif(v_jwt->>'session_id', '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_session_id := NULL;
  END;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: missing session_id' USING ERRCODE = '42501';
  END IF;

  -- Verify account integrity
  PERFORM private_admin.require_account(v_sub, v_session_id);

  -- Server role verification from public.profiles (never trust JWT user_metadata)
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = v_sub;

  IF v_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'admin_required' USING ERRCODE = '42501';
  END IF;

  RETURN v_sub;
END;
$$;

-- 5.4 private_admin.read_dashboard(p_days integer)
CREATE OR REPLACE FUNCTION private_admin.read_dashboard(p_days integer)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_days integer := coalesce(p_days, 7);
  v_as_of text;
  v_total_users bigint;
  v_locked_users bigint;
  v_active_admins bigint;
  v_registrations jsonb;
  v_draft jsonb;
  v_published jsonb := NULL;
BEGIN
  IF v_days NOT IN (7, 30) THEN
    v_days := 7;
  END IF;

  v_as_of := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');

  SELECT count(*) INTO v_total_users
  FROM auth.users
  WHERE deleted_at IS NULL;

  SELECT count(*) INTO v_locked_users
  FROM private_admin.account_access
  WHERE state IN ('locked', 'unlocking');

  -- Active admins: profile role = admin AND account state = enabled (unlocking/locked excluded)
  SELECT count(*) INTO v_active_admins
  FROM public.profiles p
  JOIN private_admin.account_access a ON a.subject_id = p.id
  WHERE p.role = 'admin' AND a.state = 'enabled';

  -- Registrations grouped by Vietnam calendar date (Asia/Ho_Chi_Minh)
  WITH dates AS (
    SELECT (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') - (n || ' days')::interval)::date AS d
    FROM generate_series(0, v_days - 1) AS n
  ),
  counts AS (
    SELECT (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS d, count(*) AS c
    FROM auth.users
    WHERE created_at >= (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') - ((v_days - 1) || ' days')::interval)
    GROUP BY 1
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'date', to_char(dates.d, 'YYYY-MM-DD'),
      'count', coalesce(counts.c, 0)
    ) ORDER BY dates.d ASC
  )
  INTO v_registrations
  FROM dates
  LEFT JOIN counts ON counts.d = dates.d;

  -- Draft overview (safe if discovery tables are absent or present)
  IF to_regclass('private_admin.discovery_drafts') IS NOT NULL THEN
    SELECT jsonb_build_object(
      'revision', coalesce((SELECT revision FROM private_admin.discovery_drafts WHERE id = 1), 0),
      'activeDestinations', coalesce((SELECT count(*) FROM public.destinations WHERE is_active = true), 0),
      'hiddenDestinations', coalesce((SELECT count(*) FROM public.destinations WHERE is_active = false), 0),
      'activePlaces', coalesce((SELECT count(*) FROM public.places WHERE is_active = true), 0),
      'hiddenPlaces', coalesce((SELECT count(*) FROM public.places WHERE is_active = false), 0)
    ) INTO v_draft;
  ELSE
    v_draft := jsonb_build_object(
      'revision', 0,
      'activeDestinations', 0,
      'hiddenDestinations', 0,
      'activePlaces', 0,
      'hiddenPlaces', 0
    );
  END IF;

  RETURN jsonb_build_object(
    'asOf', v_as_of,
    'days', v_days,
    'totalUsers', v_total_users,
    'lockedUsers', v_locked_users,
    'activeAdmins', v_active_admins,
    'registrations', coalesce(v_registrations, '[]'::jsonb),
    'draft', v_draft,
    'published', v_published
  );
END;
$$;

-- 6. Public Wire Endpoints (SECURITY INVOKER wrappers)

-- 6.1 public.current_account_access()
CREATE OR REPLACE FUNCTION public.current_account_access()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sub uuid;
  v_jwt jsonb;
  v_session_id uuid;
  v_role text;
  v_state text;
  v_revision bigint;
  v_valid_after timestamptz;
  v_session_valid boolean := false;
  v_session_created timestamptz;
  v_session_not_after timestamptz;
BEGIN
  BEGIN
    v_sub := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_sub := NULL;
  END;

  IF v_sub IS NULL THEN
    RAISE EXCEPTION 'unauthorized: missing claim sub' USING ERRCODE = '42501';
  END IF;

  BEGIN
    v_jwt := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
    v_session_id := nullif(v_jwt->>'session_id', '')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_session_id := NULL;
  END;

  SELECT p.role, a.state, a.revision, a.session_valid_after
  INTO v_role, v_state, v_revision, v_valid_after
  FROM public.profiles p
  LEFT JOIN private_admin.account_access a ON a.subject_id = p.id
  WHERE p.id = v_sub;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unauthorized: profile not found' USING ERRCODE = '42501';
  END IF;

  IF v_session_id IS NOT NULL THEN
    SELECT created_at, not_after
    INTO v_session_created, v_session_not_after
    FROM auth.sessions
    WHERE id = v_session_id AND user_id = v_sub;

    IF FOUND AND (v_session_not_after IS NULL OR v_session_not_after > now()) AND (v_valid_after IS NULL OR v_session_created >= v_valid_after) THEN
      v_session_valid := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'subjectId', v_sub,
    'role', coalesce(v_role, 'customer'),
    'revision', coalesce(v_revision, 1),
    'state', coalesce(v_state, 'enabled'),
    'sessionValid', v_session_valid
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.current_account_access() TO authenticated;

-- 6.2 public.admin_accounts(p_action text, p_request jsonb)
CREATE OR REPLACE FUNCTION public.admin_accounts(p_action text, p_request jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
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
        (a.state <> 'unlocking') AS "authSynced",
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
        'authSynced', (a.state <> 'unlocking'),
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
        ), '[]'::jsonb)
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

    -- Idempotency check on requestId
    SELECT * INTO v_existing
    FROM private_admin.account_operations
    WHERE id = v_req_id;

    IF FOUND THEN
      IF v_existing.payload_hash = v_payload_hash THEN
        -- Replay existing operation
        RETURN jsonb_build_object(
          'id', v_existing.id,
          'targetId', v_existing.target_id,
          'action', v_existing.action,
          'state', v_existing.state,
          'targetRevision', coalesce(v_existing.result_revision, v_existing.base_revision + 1),
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

    -- Record operation
    INSERT INTO private_admin.account_operations (
      id, target_id, actor_id, action, state, base_revision, result_revision, reason, payload_hash
    ) VALUES (
      v_req_id, v_target_id, v_actor_id, v_action, v_op_state, v_expected_rev,
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
      'authSynced', (v_op_state = 'completed')
    );

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
      'authSynced', (v_existing.state = 'completed')
    );

  ELSE
    RAISE EXCEPTION 'unknown_action' USING ERRCODE = '42201';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_accounts(text, jsonb) TO anon, authenticated, service_role;

-- 6.3 public.complete_admin_account_operation
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

  SELECT * INTO v_access
  FROM private_admin.account_access
  WHERE subject_id = v_op.target_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'target_not_found' USING ERRCODE = '40401';
  END IF;

  IF v_op.base_revision <> p_expected_revision AND v_access.revision <> p_expected_revision THEN
    RAISE EXCEPTION 'revision_mismatch' USING ERRCODE = '40900';
  END IF;

  IF v_op.action = 'unlock' AND p_auth_synced THEN
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
    'authSynced', p_auth_synced
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_admin_account_operation(uuid, uuid, bigint, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_admin_account_operation(uuid, uuid, bigint, boolean) TO service_role;

COMMIT;
