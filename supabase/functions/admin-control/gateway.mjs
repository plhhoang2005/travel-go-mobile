// Edge Function Gateway: admin-control
// Contract: travelgo.admin.v1
// Manages administrative actions and synchronizes account locks with Supabase Auth.

const ALLOWED_ACTIONS = new Set(['access', 'users', 'user', 'dashboard', 'mutate', 'operation', 'reconcile']);
const MAX_BODY_BYTES = 64 * 1024; // 64 KiB

export function createAdminControl(config = {}, fetchImpl = fetch) {
  const projectUrl = config.projectUrl ? config.projectUrl.replace(/\/$/, '') : '';
  const serviceKey = config.serviceKey || '';

  return async function handleAdminControl(request) {
    if (request.method !== 'POST') {
      return jsonError('method_not_allowed', 405);
    }

    // 1. Authorization check
    const authHeader = request.headers.get('authorization') || '';
    const bearerMatch = authHeader.match(/^Bearer\s+([a-zA-Z0-9\._\-]+)$/);
    if (!bearerMatch) {
      return jsonError('unauthorized', 401);
    }
    const callerToken = bearerMatch[1];

    // 2. Validate payload size
    let rawBody;
    try {
      rawBody = await request.text();
    } catch {
      return jsonError('invalid_body', 400);
    }

    if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
      return jsonError('body_too_large', 413);
    }

    let parsed;
    try {
      parsed = JSON.parse(rawBody);
    } catch {
      return jsonError('invalid_json', 400);
    }

    // 3. Contract envelope validation
    if (parsed.contract !== 'travelgo.admin.v1') {
      return jsonError('invalid_contract', 422);
    }

    const { action, request: actionRequest } = parsed;
    if (!action || typeof action !== 'string' || !ALLOWED_ACTIONS.has(action)) {
      return jsonError('invalid_action', 422);
    }
    if (!actionRequest || typeof actionRequest !== 'object' || Array.isArray(actionRequest)) {
      return jsonError('invalid_request_field', 422);
    }

    // 4. Verify caller with Auth
    try {
      const userRes = await fetchImpl(`${projectUrl}/auth/v1/user`, {
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${callerToken}`
        },
        signal: AbortSignal.timeout(5000)
      });
      if (!userRes.ok) {
        return jsonError('unauthorized', 401);
      }
      const callerUser = await userRes.json();
      if (!callerUser || !callerUser.id || callerUser.is_anonymous) {
        return jsonError('unauthorized', 401);
      }
    } catch {
      return jsonError('auth_verification_failed', 401);
    }

    // 5. Execute action via SQL
    try {
      if (action === 'mutate' || action === 'reconcile') {
        return await handleMutation(projectUrl, serviceKey, callerToken, action, actionRequest, fetchImpl);
      }

      // Read-only or direct actions: access, users, user, dashboard, operation
      const rpcRes = await fetchImpl(`${projectUrl}/rest/v1/rpc/admin_accounts`, {
        method: 'POST',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${callerToken}`,
          'content-type': 'application/json'
        },
        body: JSON.stringify({
          p_action: action,
          p_request: actionRequest
        }),
        signal: AbortSignal.timeout(30000)
      });

      if (!rpcRes.ok) {
        const errJson = await rpcRes.json().catch(() => ({}));
        const status = rpcRes.status >= 400 && rpcRes.status < 600 ? rpcRes.status : 500;
      return rpcError(errJson, status);
      }

      const rpcData = await rpcRes.json();
      return jsonResponse({
        status: 'ok',
        data: sanitizeOutput(rpcData)
      }, 200);
    } catch {
      return jsonError('upstream_unavailable', 503);
    }
  };
}

async function handleMutation(projectUrl, serviceKey, callerToken, action, actionRequest, fetchImpl) {
  // Step 1: Call SQL admin_accounts mutate/reconcile with caller's token
  const mutateRes = await fetchImpl(`${projectUrl}/rest/v1/rpc/admin_accounts`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${callerToken}`,
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      p_action: action,
      p_request: actionRequest
    }),
    signal: AbortSignal.timeout(10000)
  });

  if (!mutateRes.ok) {
    const errJson = await mutateRes.json().catch(() => ({}));
    const status = mutateRes.status >= 400 && mutateRes.status < 600 ? mutateRes.status : 500;
    return rpcError(errJson, status);
  }

  const op = await mutateRes.json();
  const opId = op.id;
  const targetId = op.targetId;
  const targetRevision = op.targetRevision;
  const workerToken = op.workerToken;
  const opAction = op.action;

  if (!validOperation(op) || targetId !== actionRequest.targetId && action === 'mutate' ||
      action === 'mutate' && (opId !== actionRequest.requestId || opAction !== actionRequest.action)) {
    return jsonError('invalid_response', 503);
  }
  // A replay is a receipt. Only SQL can grant a fresh dispatch for this worker,
  // after rechecking the actor, target revision and operation state.
  if (op.state !== 'pending') return jsonResponse({ status: 'ok', data: sanitizeOutput(op) });
  const claimRes = await fetchImpl(`${projectUrl}/rest/v1/rpc/admin_accounts`, {
    method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${callerToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ p_action: 'dispatch', p_request: { operationId: opId, workerToken, expectedRevision: targetRevision } }),
    signal: AbortSignal.timeout(10000)
  });
  if (!claimRes.ok) return rpcError(await claimRes.json().catch(() => ({})), claimRes.status);
  const claim = await claimRes.json();
  if (claim.dispatch !== true) return jsonResponse({ status: 'pending', data: sanitizeOutput(op) });

  // Step 2: Handle Auth Sync based on operation action
  let authSynced = false;
  let finalState = op.state;

  if (opAction === 'promote' || opAction === 'demote') {
    authSynced = true;
  } else if (opAction === 'lock') {
    try {
      const banRes = await fetchImpl(`${projectUrl}/auth/v1/admin/users/${targetId}`, {
        method: 'PUT',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'content-type': 'application/json'
        },
        body: JSON.stringify({ ban_duration: '876600h' }),
        signal: AbortSignal.timeout(5000)
      });
      if (banRes.ok) {
        authSynced = true;
      }
    } catch {
      authSynced = false;
    }
  } else if (opAction === 'unlock') {
    try {
      const unbanRes = await fetchImpl(`${projectUrl}/auth/v1/admin/users/${targetId}`, {
        method: 'PUT',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'content-type': 'application/json'
        },
        body: JSON.stringify({ ban_duration: 'none' }),
        signal: AbortSignal.timeout(5000)
      });
      if (unbanRes.ok) {
        // Readback check
        const getRes = await fetchImpl(`${projectUrl}/auth/v1/admin/users/${targetId}`, {
          method: 'GET',
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`
          },
          signal: AbortSignal.timeout(5000)
        });
        if (getRes.ok) {
          const userMeta = await getRes.json();
          if (userMeta.id === targetId && !userMeta.banned &&
              (!userMeta.banned_until || Date.parse(userMeta.banned_until) <= Date.now())) {
            authSynced = true;
          }
        }
      }
    } catch {
      authSynced = false;
    }
  }

  // Step 3: Complete operation in database via service_role RPC
  try {
    const completeRes = await fetchImpl(`${projectUrl}/rest/v1/rpc/complete_admin_account_operation`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'content-type': 'application/json'
      },
      body: JSON.stringify({
        p_operation_id: opId,
        p_worker_token: workerToken,
        p_expected_revision: targetRevision,
        p_auth_synced: authSynced
      }),
      signal: AbortSignal.timeout(10000)
    });

    if (completeRes.ok) {
      const completeData = await completeRes.json();
      if (!validOperation(completeData) || completeData.id !== opId || completeData.targetId !== targetId ||
          completeData.action !== opAction || completeData.targetRevision !== targetRevision) {
        return jsonError('invalid_response', 503);
      }
      finalState = completeData.state;
      authSynced = completeData.authSynced;
    } else {
      authSynced = false;
      finalState = op.state;
    }
  } catch {
    authSynced = false;
    finalState = op.state;
  }

  // Strip worker token from output returned to Flutter
  return jsonResponse({
    status: 'ok',
    data: {
      id: opId,
      targetId,
      action: opAction,
      state: finalState,
      targetRevision,
      authSynced
    }
  }, 200);
}

function sanitizeOutput(data) {
  if (!data || typeof data !== 'object') return data;
  if (Array.isArray(data)) return data.map(sanitizeOutput);
  const copy = { ...data };
  delete copy.workerToken;
  delete copy.worker_token;
  return copy;
}

function validOperation(op) {
  return op && typeof op.id === 'string' && typeof op.targetId === 'string' &&
    ['lock', 'unlock', 'promote', 'demote'].includes(op.action) &&
    ['pending', 'completed', 'needs_retry'].includes(op.state) &&
    Number.isSafeInteger(op.targetRevision) && op.targetRevision >= 1 && typeof op.authSynced === 'boolean';
}

function rpcError(error, status) {
  const known = ['admin_required', 'account_locked', 'invalid_session', 'unauthorized',
    'revision_conflict', 'request_identity_conflict', 'self_change_denied', 'last_admin_preserved',
    'operation_not_found', 'operation_in_progress', 'invalid_worker_token', 'revision_mismatch'];
  const code = known.find(code => error.code === code || String(error.message ?? '').startsWith(code)) ?? 'rpc_error';
  return jsonError(code, status);
}

function jsonResponse(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json' }
  });
}

function jsonError(code, status = 400) {
  return jsonResponse({
    status: 'error',
    code
  }, status);
}
