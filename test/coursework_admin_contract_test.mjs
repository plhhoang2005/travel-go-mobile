import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createAdminControl } from '../supabase/functions/admin-control/gateway.mjs';

const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/coursework_admin_account_vectors.json', import.meta.url), 'utf8').replace(/^\uFEFF/, ''));
for (const vector of fixture.vectors) {
  test(`gateway preserves actual SQL vector ${vector.name}`, async () => {
    let authCalls = 0;
    const gateway = createAdminControl({ projectUrl: 'https://fixture.supabase.co', serviceKey: 'synthetic' }, async (url, init) => {
      if (url.endsWith('/auth/v1/user')) return Response.json({ id: 'synthetic-admin' });
      if (url.includes('/auth/v1/admin/')) authCalls++;
      assert.ok(url.endsWith('/admin_accounts'));
      const body = JSON.parse(init.body);
      if (body.p_action === 'dispatch') return Response.json({ dispatch: false });
      if (body.p_action === 'user') return Response.json({ ...vector.user, audit: [] });
      return Response.json(vector.operation);
    });
    const request = (action, payload) => new Request('https://fixture.supabase.co/admin-control', {
      method: 'POST', headers: { authorization: 'Bearer synthetic-token' },
      body: JSON.stringify({ contract: fixture.contract, action, request: payload })
    });
    const op = vector.operation;
    const response = await gateway(request('mutate', { requestId: op.id, targetId: op.targetId,
      expectedRevision: op.targetRevision - 1, action: op.action, reason: 'synthetic' }));
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).data, op);
    const user = await gateway(request('user', { targetId: op.targetId }));
    assert.deepEqual((await user.json()).data, { ...vector.user, audit: [] });
    assert.equal(authCalls, 0);
  });
}
