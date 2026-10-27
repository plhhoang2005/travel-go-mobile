import test from 'node:test';
import assert from 'node:assert/strict';
import { createGateway, MODEL as AI_MODEL } from '../supabase/functions/ai-request/gateway.mjs';
import { createItineraryGateway, MODEL as ITINERARY_MODEL } from '../supabase/functions/itinerary-proposal/gateway.mjs';

const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const requestId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const worker = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const sessionId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

// Helper to create a fake valid JWT token with session_id claim
function makeToken(sub = owner, sess = sessionId) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({ sub, session_id: sess, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })).toString('base64url');
  return `${header}.${claims}.fake_signature`;
}

const usableAi = { summary: 'Gợi ý du lịch', suggestions: ['Điểm tham quan'], warnings: [] };
const aiPayload = () => ({
  requestId,
  intent: 'advice',
  synthetic: true,
  context: { destinationId: 'hue', originRegion: 'south', numDays: 2, numPeople: 1, budgetVnd: 2000000, interests: ['culture'] }
});

const itineraryPayload = () => ({
  contract: 'travelgo.itinerary.v1',
  intent: 'generate',
  requestId,
  consent: true,
  context: { destinationId: 'hue', originRegion: 'unknown', numDays: 2, numPeople: 2, budgetVnd: 500000, interests: ['văn hóa'] }
});

const json = (val, code = 200) => new Response(JSON.stringify(val), { status: code });

function createMockHarness(options = {}) {
  const calls = [];
  let checkAccountCallCount = 0;

  const fetchImpl = async (url, init) => {
    const body = init.body ? JSON.parse(init.body) : null;
    calls.push({ url, headers: init.headers, body });

    if (url.endsWith('/auth/v1/user')) {
      return json({
        id: owner,
        aud: 'authenticated',
        is_anonymous: options.anonymous === true,
        email: 'user@example.com'
      }, options.authStatus ?? 200);
    }

    if (url.endsWith('/rest/v1/rpc/check_gateway_account')) {
      checkAccountCallCount++;
      if (options.midFlightRevocation && checkAccountCallCount > 1) {
        return json({ error: 'account_locked' }, 403);
      }
      if (options.accountLocked) {
        return json({ error: 'account_locked' }, 403);
      }
      return json({ allowed: true });
    }

    if (url.endsWith('/reserve_ai_request_v1')) {
      return json({
        status: 'reserved',
        requestId,
        acceptedDay: '2026-10-23',
        workerToken: worker,
        expiresAt: new Date(Date.now() + 60000).toISOString(),
        remaining: 2,
        result: null,
        dispatch: true
      });
    }

    if (url.includes('generativelanguage.googleapis.com')) {
      const isItinerary = url.includes('itinerary') || options.isItinerary;
      const text = isItinerary
        ? JSON.stringify({ summary: 'Lịch trình', activities: [{ day: 1, title: 'Hoạt động 1', startMinute: 480, endMinute: 600, costVnd: 50000, category: 'attractions' }], warnings: [] })
        : JSON.stringify(usableAi);
      return json({
        candidates: [{ finishReason: 'STOP', content: { parts: [{ text }] } }]
      });
    }

    if (url.endsWith('/finalize_ai_request_v1')) {
      return json({
        status: body.p_success ? 'succeeded' : 'failed',
        requestId,
        acceptedDay: '2026-10-23',
        workerToken: null,
        remaining: 2,
        result: body.p_result
      });
    }

    throw new Error(`Unexpected URL in harness: ${url}`);
  };

  return { calls, fetchImpl, getCheckAccountCalls: () => calls.filter(c => c.url.endsWith('/check_gateway_account')) };
}

test('locked_gateway_never_dispatches: ai-request returns 403 and never calls reserve or provider', async () => {
  const harness = createMockHarness({ accountLocked: true });
  const gateway = createGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'pk',
    serviceKey: 'sk',
    geminiKey: 'gk',
    enabled: true,
    syntheticOnly: true,
    allowedSubjects: [owner]
  }, harness.fetchImpl);

  const token = makeToken();
  const req = new Request('https://fixture.supabase.co/functions/v1/ai-request', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(aiPayload())
  });

  const res = await gateway(req);
  assert.equal(res.status, 403);

  const reserveCalls = harness.calls.filter(c => c.url.endsWith('/reserve_ai_request_v1')).length;
  const providerCalls = harness.calls.filter(c => c.url.includes('generativelanguage')).length;
  assert.equal(reserveCalls, 0);
  assert.equal(providerCalls, 0);

  const checks = harness.getCheckAccountCalls();
  assert.equal(checks.length, 1);
  assert.equal(checks[0].body.p_subject, owner);
  assert.equal(checks[0].body.p_session_id, sessionId);
});

test('locked_gateway_never_dispatches: itinerary-proposal returns 403 and never calls reserve or provider', async () => {
  const harness = createMockHarness({ accountLocked: true, isItinerary: true });
  const gateway = createItineraryGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'pk',
    serviceKey: 'sk',
    geminiKey: 'gk',
    enabled: true,
    realContextAllowed: true,
    allowedSubjects: [owner]
  }, harness.fetchImpl);

  const token = makeToken();
  const req = new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(itineraryPayload())
  });

  const res = await gateway(req);
  assert.equal(res.status, 403);

  const reserveCalls = harness.calls.filter(c => c.url.endsWith('/reserve_ai_request_v1')).length;
  const providerCalls = harness.calls.filter(c => c.url.includes('generativelanguage')).length;
  assert.equal(reserveCalls, 0);
  assert.equal(providerCalls, 0);
});

test('mid_flight_revocation_denies_payload_and_releases_quota: ai-request denies payload', async () => {
  const harness = createMockHarness({ midFlightRevocation: true });
  const gateway = createGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'pk',
    serviceKey: 'sk',
    geminiKey: 'gk',
    enabled: true,
    syntheticOnly: true,
    allowedSubjects: [owner]
  }, harness.fetchImpl);

  const token = makeToken();
  const req = new Request('https://fixture.supabase.co/functions/v1/ai-request', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(aiPayload())
  });

  const res = await gateway(req);
  // Denied because mid-flight revocation occurred before return
  assert.equal(res.status, 403);

  // Quota must be cleanly finalized with failure
  const finals = harness.calls.filter(c => c.url.endsWith('/finalize_ai_request_v1'));
  assert.equal(finals.length, 1);
  assert.equal(finals[0].body.p_success, false);
});

test('mid_flight_revocation_denies_payload_and_releases_quota: itinerary-proposal denies payload', async () => {
  const harness = createMockHarness({ midFlightRevocation: true, isItinerary: true });
  const gateway = createItineraryGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'pk',
    serviceKey: 'sk',
    geminiKey: 'gk',
    enabled: true,
    realContextAllowed: true,
    allowedSubjects: [owner]
  }, harness.fetchImpl);

  const token = makeToken();
  const req = new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(itineraryPayload())
  });

  const res = await gateway(req);
  assert.equal(res.status, 403);

  const finals = harness.calls.filter(c => c.url.endsWith('/finalize_ai_request_v1'));
  assert.equal(finals.length, 1);
  assert.equal(finals[0].body.p_success, false);
});

test('guest quota and consent unchanged: anonymous user skips session validation cleanly', async () => {
  const harness = createMockHarness({ anonymous: true });
  const gateway = createGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'pk',
    serviceKey: 'sk',
    geminiKey: 'gk',
    enabled: true,
    syntheticOnly: true,
    allowedSubjects: [owner]
  }, harness.fetchImpl);

  const req = new Request('https://fixture.supabase.co/functions/v1/ai-request', {
    method: 'POST',
    headers: { authorization: `Bearer ${makeToken()}`, 'content-type': 'application/json' },
    body: JSON.stringify(aiPayload())
  });

  const res = await gateway(req);
  assert.equal(res.status, 200);

  const checks = harness.getCheckAccountCalls();
  assert.equal(checks.length, 2);
  assert.equal(checks[0].body.p_is_guest, true);
});
