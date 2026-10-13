import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createGateway, MODEL, sanitizeRequest } from '../supabase/functions/ai-request/gateway.mjs';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const requestId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const worker = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const usable = { summary: 'Gợi ý cho dữ liệu giả lập.', suggestions: ['Tham khảo hoạt động văn hóa.'], warnings: ['Giá và giờ mở cửa chưa xác minh.'] };
function payload(intent = 'advice') {
  return { requestId, intent, synthetic: true, context: { destinationId: 'hue', originRegion: 'south', numDays: 2, numPeople: 1, budgetVnd: 2000000, interests: ['culture'] } };
}
function request(body = payload(), token = 'fixture-user-bearer') {
  return new Request('https://fixture.supabase.co/functions/v1/ai-request', { method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: typeof body === 'string' ? body : JSON.stringify(body) });
}
const json = (value, code = 200) => new Response(JSON.stringify(value), { status: code });
function fixture(options = {}) {
  const calls = [];
  let state = 'new'; let stored = null;
  const envelope = (status, dispatch) => ({ status, requestId, acceptedDay: '2026-10-13', workerToken: status === 'reserved' ? worker : null, expiresAt: '2026-10-13T12:00:00+00:00', remaining: status === 'failed' || status === 'expired' ? 3 : 2, result: status === 'succeeded' ? stored : null, ...(dispatch ? { dispatch: true } : {}) });
  const handler = createGateway({
    projectUrl: 'https://fixture.supabase.co', publicKey: 'fixture-public-key', serviceKey: 'fixture-service-key', geminiKey: 'fixture-gemini-key',
    enabled: true, syntheticOnly: true, allowedSubjects: [owner], ...options.config,
  }, async (url, init) => {
    const body = init.body ? JSON.parse(init.body) : null;
    calls.push({ url, headers: init.headers, body, signal: init.signal });
    if (url.endsWith('/auth/v1/user')) return json({ id: owner, aud: 'authenticated', is_anonymous: options.anonymous !== false, email: 'private@example.test', user_metadata: { private: 'do not forward' } }, options.authStatus ?? 200);
    if (url.endsWith('/reserve_ai_request_v1')) {
      if (options.reserve) return json(options.reserve);
      if (state !== 'new') return json(envelope(state));
      state = 'reserved'; return json(envelope(state, true));
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      options.onProvider?.();
      if (options.providerWait) await options.providerWait;
      if (options.providerThrows) throw new DOMException('Fixture timeout', 'AbortError');
      if (options.providerStatus) return json({ error: 'fixture provider error' }, options.providerStatus);
      return json({ candidates: [{ finishReason: options.finishReason ?? 'STOP', content: { parts: options.parts ?? [{ text: JSON.stringify(options.providerValue ?? usable) }] } }] });
    }
    if (url.endsWith('/finalize_ai_request_v1')) {
      if (options.fenceExpiry) { state = 'expired'; return json(envelope(state)); }
      stored = body.p_result; state = body.p_success ? 'succeeded' : 'failed';
      if (options.dropFinalize) throw new Error('Fixture lost successful ack');
      return json(envelope(state));
    }
    throw new Error('Unexpected network path');
  });
  return { handler, calls, provider: () => calls.filter(c => c.url.includes('generativelanguage')), reserves: () => calls.filter(c => c.url.endsWith('/reserve_ai_request_v1')), finals: () => calls.filter(c => c.url.endsWith('/finalize_ai_request_v1')) };
}

test('disabled default, missing allowlist and paid/alternate model fail closed', async () => {
  for (const config of [{ enabled: false }, { allowedSubjects: [] }, { syntheticOnly: false }, { geminiKey: '' }, { model: 'different-model' }, { projectUrl: 'http://fixture.supabase.co' }]) {
    const f = fixture({ config });
    assert.equal((await f.handler(request())).status, 503);
    assert.equal(f.calls.length, 0);
  }
});
test('thin Edge entry point is disabled when no readiness environment exists', async () => {
  const previous = globalThis.Deno;
  let installed;
  globalThis.Deno = { env: { get: () => undefined }, serve: handle => { installed = handle; } };
  try {
    await import('../supabase/functions/ai-request/index.ts');
    assert.equal(typeof installed, 'function');
    assert.equal((await installed(request())).status, 503);
  } finally {
    if (previous === undefined) delete globalThis.Deno;
    else globalThis.Deno = previous;
  }
});
test('trusted Auth rejection precedes quota/provider; no local JWT trust', async () => {
  const f = fixture({ authStatus: 401 });
  assert.equal((await f.handler(request(payload(), 'forged.jwt.token'))).status, 401);
  assert.equal(f.reserves().length, 0);
  assert.equal(f.provider().length, 0);
  assert.equal(f.calls[0].headers.Authorization, 'Bearer forged.jwt.token');
});
test('readiness caller must be server-verified and allowlisted', async () => {
  const f = fixture({ config: { allowedSubjects: ['dddddddd-dddd-4ddd-8ddd-dddddddddddd'] } });
  assert.equal((await f.handler(request())).status, 403);
  assert.equal(f.reserves().length, 0);
});
for (const intent of ['generate', 'advice', 'modify', 'recommendations']) {
  test(`${intent} shares verified subject quota; only minimal synthetic context reaches provider`, async () => {
    const f = fixture({ anonymous: intent !== 'modify' });
    const reply = await f.handler(request(payload(intent)));
    assert.equal(reply.status, 200);
    const body = await reply.json();
    assert.equal(body.result.isAiGenerated, true);
    assert.equal(body.result.verification, 'unverified');
    assert.equal(body.result.model, MODEL);
    assert.equal(body.workerToken, undefined);
    assert.equal(f.reserves()[0].body.p_subject, owner);
    assert.equal(f.reserves()[0].body.p_is_guest, intent !== 'modify');
    const upstream = f.provider()[0];
    assert.equal(upstream.headers['x-goog-api-key'], 'fixture-gemini-key');
    assert.equal(upstream.headers.Authorization, undefined);
    assert.equal(upstream.headers.apikey, undefined);
    const prompt = JSON.stringify(upstream.body);
    for (const forbidden of [owner, requestId, 'fixture-user-bearer', 'fixture-service-key', 'private@example.test', 'do not forward']) assert.equal(prompt.includes(forbidden), false);
    assert.equal(upstream.body.tools, undefined);
    assert.equal(upstream.body.generationConfig.maxOutputTokens, 512);
    assert.equal(upstream.body.generationConfig.responseMimeType, 'application/json');
    assert.equal(f.finals()[0].body.p_success, true);
    assert.equal(f.reserves()[0].headers.Authorization, 'Bearer fixture-service-key');
    assert.equal(f.reserves()[0].body.p_payload_digest, createHash('sha256').update(JSON.stringify({ intent, context: sanitizeRequest(payload(intent)).context })).digest('hex'));
  });
}
test('private/free-text/GPS/client-owner fields and invalid dates/numbers reject before reservation', async () => {
  const variants = [];
  for (const key of ['email', 'password', 'gps', 'prompt', 'targetOwner', 'model']) { const v = payload(); v[key] = 'private'; variants.push(v); }
  for (const key of ['email', 'gps', 'text']) { const v = payload(); v.context[key] = 'private'; variants.push(v); }
  variants.push({ ...payload(), synthetic: false });
  const fractional = payload(); fractional.context.numDays = 1.5; variants.push(fractional);
  const badDate = payload(); badDate.context.startDate = '2026-02-31'; badDate.context.endDate = '2026-03-02'; variants.push(badDate);
  for (const v of variants) {
    const f = fixture(); assert.equal((await f.handler(request(v))).status, 400);
    assert.equal(f.reserves().length, 0); assert.equal(f.provider().length, 0);
  }
});
test('bounded body rejects oversized JSON without quota charge', async () => {
  const f = fixture();
  assert.equal((await f.handler(request('{"large":"' + 'x'.repeat(20000) + '"}'))).status, 400);
  assert.equal(f.reserves().length, 0);
});
test('quota exhausted/global cap do not call Gemini', async () => {
  for (const reserve of [{ status: 'quota_exhausted', acceptedDay: '2026-10-13', remaining: 0 }, { status: 'global_cap' }]) {
    const f = fixture({ reserve });
    assert.ok([429, 503].includes((await f.handler(request())).status));
    assert.equal(f.provider().length, 0);
  }
});
test('in-flight duplicate gets pending without second dispatch', async () => {
  let entered, release;
  const ready = new Promise(resolve => { entered = resolve; });
  const providerWait = new Promise(resolve => { release = resolve; });
  const f = fixture({ onProvider: entered, providerWait });
  const first = f.handler(request());
  await ready;
  const second = await f.handler(request());
  assert.equal(second.status, 202);
  assert.equal((await second.json()).workerToken, undefined);
  release();
  assert.equal((await first).status, 200);
  assert.equal(f.provider().length, 1);
  assert.equal(f.finals().length, 1);
});
test('lost successful finalize reply stays ambiguous; retry replays once without refund', async () => {
  const f = fixture({ dropFinalize: true });
  const first = await f.handler(request());
  assert.equal(first.status, 503);
  assert.equal((await first.json()).status, 'outcome_pending');
  const retry = await f.handler(request());
  assert.equal(retry.status, 200);
  assert.equal((await retry.json()).result.summary, usable.summary);
  assert.equal(f.provider().length, 1);
  assert.equal(f.finals().length, 1);
  assert.equal(f.finals()[0].body.p_success, true);
});
for (const options of [{ providerStatus: 429 }, { providerThrows: true }, { providerValue: { unexpected: 'bad JSON schema' } }, { finishReason: 'MAX_TOKENS' }, { parts: [{ functionCall: { name: 'deleteTrip' } }] }]) {
  test(`unusable result releases user quota: ${JSON.stringify(options)}`, async () => {
    const f = fixture(options);
    assert.equal((await f.handler(request())).status, 502);
    assert.equal(f.finals().length, 1);
    assert.equal(f.finals()[0].body.p_success, false);
    assert.equal(f.finals()[0].body.p_result, null);
    assert.equal((await f.handler(request())).status, 502);
    assert.equal(f.provider().length, 1);
  });
}
test('expired worker never publishes a late model candidate', async () => {
  const f = fixture({ fenceExpiry: true });
  const reply = await f.handler(request());
  assert.equal(reply.status, 410);
  assert.equal((await reply.json()).result, null);
});
test('malformed quota receipt binding fails closed before external call', async () => {
  const f = fixture({ reserve: { status: 'reserved', requestId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', acceptedDay: '2026-10-13', workerToken: worker, expiresAt: '2026-10-13T12:00:00Z', remaining: 2, result: null, dispatch: true } });
  assert.equal((await f.handler(request())).status, 503);
  assert.equal(f.provider().length, 0);
});
