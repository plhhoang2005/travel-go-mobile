import test from 'node:test';
import assert from 'node:assert/strict';
import {createItineraryGateway, WEB_PROPOSAL} from '../supabase/functions/itinerary-proposal/gateway.mjs';

test('createItineraryGateway processes travelgo.web.proposal.v1 end-to-end', async () => {
  const userId = '11111111-1111-4111-8111-111111111111';
  const requestId = '22222222-2222-4222-8222-222222222222';
  const workerToken = '33333333-3333-4333-8333-333333333333';
  let finalizedResult = null;
  let providerCalls = 0;

  const mockCandidate = {
    finishReason: 'STOP',
    content: {
      parts: [
        {
          text: JSON.stringify({
            summary: 'Lịch trình 2 ngày tại Phú Yên khám phá Ghềnh Đá Đĩa và Bãi Xép.',
            activities: [
              {
                day: 1,
                title: 'Tham quan Ghềnh Đá Đĩa',
                startMinute: 480,
                endMinute: 660,
                costVnd: 40000,
                category: 'attractions',
                externalPlaceName: 'Ghềnh Đá Đĩa',
              },
              {
                day: 2,
                title: 'Dạo chơi Bãi Xép',
                startMinute: 900,
                endMinute: 1080,
                costVnd: null,
                category: 'attractions',
                externalPlaceName: 'Bãi Xép',
              },
            ],
            warnings: ['Kiểm tra thời tiết và sóng biển trước khi đi.'],
          }),
        },
      ],
    },
    groundingMetadata: {
      webSearchQueries: ['du lịch Phú Yên Ghềnh Đá Đĩa Bãi Xép'],
      groundingChunks: [
        {
          web: {
            uri: 'https://phuyen.gov.vn/ghenh-da-dia',
            title: 'Khu di tích danh thắng Ghềnh Đá Đĩa - Phú Yên',
          },
        },
      ],
      groundingSupports: [
        {
          segment: { startIndex: 0, endIndex: 15 },
          groundingChunkIndices: [0],
        },
      ],
    },
  };

  const handler = createItineraryGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'public-fixture',
    serviceKey: 'service-fixture',
    geminiKey: 'gemini-fixture',
    enabled: true,
    realContextAllowed: true,
    allowedSubjects: [userId],
    checkAccount: async () => ({ allowed: true }),
  }, async (url, init) => {
    if (url.endsWith('/auth/v1/user')) {
      return Response.json({ id: userId, aud: 'authenticated', is_anonymous: false });
    }
    if (url.includes('/rest/v1/rpc/check_gateway_account')) {
      return Response.json({ allowed: true });
    }
    if (url.includes('/rest/v1/rpc/reserve_ai_request_v1')) {
      return Response.json({
        status: 'reserved',
        requestId,
        acceptedDay: '2026-10-27',
        remaining: 2,
        workerToken,
        expiresAt: '2026-10-27T04:00:00Z',
        result: null,
        dispatch: true,
      });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      providerCalls++;
      const body = JSON.parse(init.body);
      assert.ok(body.tools?.some(t => t.google_search));
      return Response.json({ candidates: [mockCandidate] });
    }
    if (url.includes('/rest/v1/rpc/finalize_ai_request_v1')) {
      const body = JSON.parse(init.body);
      assert.equal(body.p_success, true);
      assert.equal(body.p_worker_token, workerToken);
      finalizedResult = body.p_result;
      return Response.json({
        status: 'succeeded',
        requestId,
        acceptedDay: '2026-10-27',
        remaining: 1,
        workerToken: null,
        result: finalizedResult,
      });
    }
    throw new Error(`Unexpected path: ${url}`);
  });

  const payload = {
    contract: WEB_PROPOSAL,
    requestId,
    consent: true,
    webConsent: true,
    prompt: 'Lập lịch trình Phú Yên 2 ngày',
    context: {
      destinationName: 'Phú Yên',
      dates: ['2026-11-20', '2026-11-21'],
      numPeople: 2,
      budgetVnd: 4000000,
      interests: ['biển', 'ngắm cảnh'],
      scope: 'whole_trip',
      baseDigest: 'c'.repeat(64),
    },
  };

  const req = new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal', {
    method: 'POST',
    headers: { authorization: 'Bearer token' },
    body: JSON.stringify(payload),
  });

  const res = await handler(req);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.status, 'succeeded');
  assert.equal(data.result.contract, WEB_PROPOSAL);
  assert.equal(data.result.proposal.activities.length, 2);
  assert.equal(data.result.evidence.length, 1);
  assert.equal(data.result.evidence[0].origin, 'web');
  assert.equal(data.result.evidence[0].reviewed, false);
  assert.equal(data.result.externalPlaces.length, 2);
  assert.equal(data.result.externalPlaces[0].name, 'Ghềnh Đá Đĩa');
  assert.equal(data.result.externalPlaces[0].destinationName, 'Phú Yên');
  assert.ok(data.result.warnings.some(w => w.includes('chưa được Admin kiểm duyệt')));
  assert.equal(providerCalls, 1);
});

test('createItineraryGateway denies anonymous guest for web proposal', async () => {
  const anon = '55555555-5555-4555-8555-555555555555';
  const requestId = '77777777-7777-4777-8777-777777777777';

  const handler = createItineraryGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'public-fixture',
    serviceKey: 'service-fixture',
    geminiKey: 'gemini-fixture',
    enabled: true,
    realContextAllowed: true,
    allowAnonymousGuests: true,
    allowedSubjects: [anon],
    checkAccount: async () => ({ allowed: true }),
  }, async (url) => {
    if (url.endsWith('/auth/v1/user')) {
      return Response.json({ id: anon, aud: 'authenticated', is_anonymous: true });
    }
    throw new Error(`Unexpected path: ${url}`);
  });

  const req = new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal', {
    method: 'POST',
    headers: { authorization: 'Bearer token' },
    body: JSON.stringify({
      contract: WEB_PROPOSAL,
      requestId,
      consent: true,
      webConsent: true,
      prompt: 'Lập lịch trình',
      context: {
        destinationName: 'Phú Yên',
        dates: ['2026-11-20'],
        numPeople: 2,
        budgetVnd: 2000000,
        interests: ['biển'],
        scope: 'whole_trip',
        baseDigest: 'd'.repeat(64),
      },
    }),
  });

  const res = await handler(req);
  assert.equal(res.status, 403);
  const body = await res.json();
  assert.equal(body.status, 'subject_denied');
});

test('createItineraryGateway rejects web proposal without consent or webConsent', async () => {
  const userId = '11111111-1111-4111-8111-111111111111';
  const handler = createItineraryGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'public-fixture',
    serviceKey: 'service-fixture',
    geminiKey: 'gemini-fixture',
    enabled: true,
    realContextAllowed: true,
    allowedSubjects: [userId],
    checkAccount: async () => ({ allowed: true }),
  }, async (url) => {
    if (url.endsWith('/auth/v1/user')) {
      return Response.json({ id: userId, aud: 'authenticated', is_anonymous: false });
    }
    throw new Error(`Unexpected path: ${url}`);
  });

  for (const bad of [
    { consent: false, webConsent: true },
    { consent: true, webConsent: false },
    { consent: true },
  ]) {
    const req = new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal', {
      method: 'POST',
      headers: { authorization: 'Bearer token' },
      body: JSON.stringify({
        contract: WEB_PROPOSAL,
        requestId: '88888888-8888-4888-8888-888888888888',
        prompt: 'Lập lịch',
        context: {
          destinationName: 'Phú Yên',
          dates: ['2026-11-20'],
          numPeople: 1,
          budgetVnd: 1000000,
          interests: [],
          scope: 'whole_trip',
          baseDigest: 'e'.repeat(64),
        },
        ...bad,
      }),
    });
    const res = await handler(req);
    assert.equal(res.status, 400);
  }
});

