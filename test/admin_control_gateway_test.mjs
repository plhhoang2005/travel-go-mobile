import test from 'node:test';
import assert from 'node:assert/strict';
import { createAdminControl } from '../supabase/functions/admin-control/gateway.mjs';

const adminId = '11111111-1111-4111-8111-111111111111';
const adminSessionId = '22222222-2222-4222-8222-222222222222';
const targetId = '33333333-3333-4333-8333-333333333333';
const workerToken = '44444444-4444-4444-8444-444444444444';
const requestId = '55555555-5555-4555-8555-555555555555';

function makeAdminToken(sub = adminId, sess = adminSessionId) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({ sub, session_id: sess, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })).toString('base64url');
  return `${header}.${claims}.fake_signature`;
}

const json = (val, code = 200) => new Response(JSON.stringify(val), { status: code });

function createHarness(options = {}) {
  const calls = [];
  let opRevision = 1n;
  let accessState = options.initialTargetState ?? 'enabled';
  let authBanned = options.initialAuthBanned ?? false;

  const fetchImpl = async (url, init) => {
    const body = init.body ? JSON.parse(init.body) : null;
    calls.push({ url, headers: init.headers, body });

    // Auth verification of caller
    if (url.endsWith('/auth/v1/user')) {
      if (options.authStatus && options.authStatus !== 200) {
        return json({ error: 'unauthorized' }, options.authStatus);
      }
      return json({
        id: adminId,
        aud: 'authenticated',
        is_anonymous: false,
        email: 'admin@travelgo.vn'
      });
    }

    // SQL admin_accounts endpoint
    if (url.endsWith('/rest/v1/rpc/admin_accounts')) {
      const { p_action, p_request } = body;
      if (p_action === 'access') {
        return json({ subjectId: adminId, role: 'admin', accountRevision: 1, allowed: true });
      }
      if (p_action === 'users') {
        return json({
          items: [{
            id: targetId,
            fullName: 'Target User',
            email: 'target@example.com',
            role: 'customer',
            state: accessState,
            revision: Number(opRevision),
            createdAt: '2026-10-23T00:00:00Z',
            lastSignInAt: null,
            authSynced: true
          }],
          nextCursor: null
        });
      }
      if (p_action === 'mutate') {
        const { action, expectedRevision } = p_request;
        if (expectedRevision !== undefined && BigInt(expectedRevision) !== opRevision) {
          return json({ code: 'conflict', message: 'revision mismatch' }, 409);
        }
        opRevision++;
        if (action === 'lock') {
          accessState = 'locked';
        } else if (action === 'unlock') {
          accessState = 'unlocking';
        }
        return json({
          id: requestId,
          targetId,
          action,
          state: options.replayCompleted ? 'completed' : 'pending',
          targetRevision: Number(opRevision),
          workerToken,
          authSynced: options.replayCompleted === true
        });
      }
      if (p_action === 'reconcile') {
        return json({
          id: '77777777-7777-4777-8777-777777777777',
          targetId,
          action: 'unlock',
          state: 'pending',
          targetRevision: Number(opRevision),
          workerToken,
          authSynced: false
        });
      }
      if (p_action === 'dispatch') {
        if (options.dispatchDenied) return json({ code: 'revision_conflict' }, 409);
        return json({ dispatch: true });
      }
      return json({ code: 'invalid_action' }, 422);
    }

    // Auth Admin API: /auth/v1/admin/users/{id}
    if (url.includes('/auth/v1/admin/users/')) {
      if (options.authAdminTimeout) {
        throw new DOMException('Auth timeout', 'AbortError');
      }
      if (options.authAdminFails) {
        return json({ error: 'upstream_unavailable' }, 503);
      }
      if (init.method === 'PUT') {
        if (body.ban_duration && body.ban_duration !== 'none') {
          authBanned = true;
        } else if (body.banned_until) {
          authBanned = true;
        } else {
          authBanned = false;
        }
        return json({ id: targetId, banned: authBanned });
      }
      if (init.method === 'GET') {
        return json({ id: targetId, banned: authBanned });
      }
    }

    // SQL complete_admin_account_operation
    if (url.endsWith('/rest/v1/rpc/complete_admin_account_operation')) {
      const { p_operation_id, p_worker_token, p_expected_revision, p_auth_synced } = body;
      if (p_worker_token !== workerToken) {
        return json({ code: 'invalid_worker_token' }, 403);
      }
      if (options.staleRevisionCompletion) {
        return json({ code: 'stale_revision', message: 'revision already superseded' }, 409);
      }
      if (p_auth_synced && accessState === 'unlocking') {
        accessState = 'enabled';
      }
      return json({
        id: p_operation_id,
        targetId,
        action: options.initialTargetState === 'locked' || options.initialTargetState === 'unlocking' ? 'unlock' : 'lock',
        state: p_auth_synced ? 'completed' : 'needs_retry',
        authSynced: p_auth_synced,
        targetRevision: Number(opRevision)
      });
    }

    throw new Error(`Unexpected harness URL: ${url}`);
  };

  return {
    calls,
    fetchImpl,
    getState: () => accessState,
    getAuthBanned: () => authBanned,
    getRevision: () => opRevision
  };
}

test('admin-control rejects missing or invalid contract envelope', async () => {
  const harness = createHarness();
  const handler = createAdminControl({
    projectUrl: 'https://fixture.supabase.co',
    serviceKey: 'svc_key'
  }, harness.fetchImpl);

  // Missing contract
  const res1 = await handler(new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({ action: 'access', request: {} })
  }));
  assert.equal(res1.status, 422);

  // Invalid contract
  const res2 = await handler(new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({ contract: 'invalid.contract', action: 'access', request: {} })
  }));
  assert.equal(res2.status, 422);
});

test('admin-control rejects oversized body (> 64 KiB)', async () => {
  const harness = createHarness();
  const handler = createAdminControl({
    projectUrl: 'https://fixture.supabase.co',
    serviceKey: 'svc_key'
  }, harness.fetchImpl);

  const bigBody = JSON.stringify({
    contract: 'travelgo.admin.v1',
    action: 'access',
    request: { filler: 'a'.repeat(70000) }
  });

  const res = await handler(new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: bigBody
  }));
  assert.equal(res.status, 413);
});

test('lock RPC occurs before Auth ban; success completes with authSynced: true', async () => {
  const harness = createHarness();
  const handler = createAdminControl({
    projectUrl: 'https://fixture.supabase.co',
    serviceKey: 'svc_key'
  }, harness.fetchImpl);

  const req = new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      contract: 'travelgo.admin.v1',
      action: 'mutate',
      request: {
        requestId,
        targetId,
        expectedRevision: 1,
        action: 'lock',
        reason: 'Violated terms'
      }
    })
  });

  const res = await handler(req);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.status, 'ok');
  assert.equal(data.data.state, 'completed');
  assert.equal(data.data.authSynced, true);

  // Assert ordering: SQL mutate called BEFORE Auth Admin PUT
  const mutateIdx = harness.calls.findIndex(c => c.url.endsWith('/rest/v1/rpc/admin_accounts'));
  const authIdx = harness.calls.findIndex(c => c.url.includes('/auth/v1/admin/users/'));
  const completeIdx = harness.calls.findIndex(c => c.url.endsWith('/rest/v1/rpc/complete_admin_account_operation'));
  assert.ok(mutateIdx >= 0 && authIdx > mutateIdx && completeIdx > authIdx);
  assert.equal(harness.getAuthBanned(), true);
  assert.equal(harness.getState(), 'locked');
});

test('lock: Auth timeout leaves locked + authSynced: false (needs_retry)', async () => {
  const harness = createHarness({ authAdminTimeout: true });
  const handler = createAdminControl({
    projectUrl: 'https://fixture.supabase.co',
    serviceKey: 'svc_key'
  }, harness.fetchImpl);

  const req = new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      contract: 'travelgo.admin.v1',
      action: 'mutate',
      request: {
        requestId,
        targetId,
        expectedRevision: 1,
        action: 'lock',
        reason: 'Violated terms'
      }
    })
  });

  const res = await handler(req);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.data.state, 'needs_retry');
  assert.equal(data.data.authSynced, false);

  // complete RPC called with authSynced = false
  const completeCall = harness.calls.find(c => c.url.endsWith('/rest/v1/rpc/complete_admin_account_operation'));
  assert.equal(completeCall.body.p_auth_synced, false);
});

test('unlock: unban failure leaves unlocking and authSynced: false', async () => {
  const harness = createHarness({ initialTargetState: 'locked', authAdminFails: true });
  const handler = createAdminControl({
    projectUrl: 'https://fixture.supabase.co',
    serviceKey: 'svc_key'
  }, harness.fetchImpl);

  const req = new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      contract: 'travelgo.admin.v1',
      action: 'mutate',
      request: {
        requestId,
        targetId,
        expectedRevision: 1,
        action: 'unlock',
        reason: 'Appeal granted'
      }
    })
  });

  const res = await handler(req);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.data.state, 'needs_retry');
  assert.equal(data.data.authSynced, false);
  assert.equal(harness.getState(), 'unlocking');
});

test('stale_auth_completion_cannot_enable_new_revision: completion for old revision rejected', async () => {
  const harness = createHarness({ initialTargetState: 'unlocking', staleRevisionCompletion: true });
  const handler = createAdminControl({
    projectUrl: 'https://fixture.supabase.co',
    serviceKey: 'svc_key'
  }, harness.fetchImpl);

  const req = new Request('https://fixture.supabase.co/functions/v1/admin-control', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeAdminToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      contract: 'travelgo.admin.v1',
      action: 'mutate',
      request: {
        requestId,
        targetId,
        expectedRevision: 1,
        action: 'unlock',
        reason: 'Appeal granted'
      }
    })
  });

  const res = await handler(req);
  // Target cannot be transitioned to enabled if revision is stale
  assert.equal(harness.getState(), 'unlocking');
});

for (const options of [{ replayCompleted: true }, { dispatchDenied: true }]) {
  test(`replayed completed or superseded operation never calls Auth Admin: ${JSON.stringify(options)}`, async () => {
    const harness = createHarness(options);
    const handler = createAdminControl({ projectUrl: 'https://fixture.supabase.co', serviceKey: 'svc_key' }, harness.fetchImpl);
    const response = await handler(new Request('https://fixture.supabase.co/functions/v1/admin-control', {
      method: 'POST', headers: { authorization: `Bearer ${makeAdminToken()}` },
      body: JSON.stringify({ contract: 'travelgo.admin.v1', action: 'mutate',
        request: { requestId, targetId, expectedRevision: 1, action: 'lock', reason: 'test' } })
    }));
    assert.equal(response.status, options.dispatchDenied ? 409 : 200);
    assert.equal(harness.calls.filter(c => c.url.includes('/auth/v1/admin/users/')).length, 0);
    const body = await response.json();
    assert.equal(body.data?.workerToken, undefined);
  });
}
