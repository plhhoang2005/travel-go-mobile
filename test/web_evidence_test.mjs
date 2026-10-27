import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeGoogleGrounding, sliceUtf8Bytes, isValidWebUri} from '../supabase/functions/itinerary-proposal/web-evidence.mjs';

test('normalizeGoogleGrounding extracts evidence records and claims with UTF-8 byte offsets', () => {
  const summary = 'Bảo tàng Lịch sử Quốc gia mở cửa từ 8:00 đến 17:00 tất cả các ngày trong tuần.';
  const prefix = 'Bảo tàng Lịch sử Quốc gia';
  const prefixBytes = Buffer.from(prefix, 'utf-8').length;

  const candidate = {
    content: { parts: [{ text: summary }] },
    groundingMetadata: {
      webSearchQueries: ['giờ mở cửa Bảo tàng Lịch sử Quốc gia'],
      groundingChunks: [
        {
          web: {
            uri: 'https://baotanglichsu.vn/vi/Articles/3096/gio-mo-cua.html',
            title: 'Giờ mở cửa và giá vé - Bảo tàng Lịch sử Quốc gia',
          },
        },
      ],
      groundingSupports: [
        {
          segment: { startIndex: 0, endIndex: prefixBytes },
          groundingChunkIndices: [0],
          confidenceScores: [0.95],
        },
      ],
      searchEntryPoint: {
        renderedContent: '<div class="google-search-chip">Google Search</div>',
      },
    },
  };

  const result = normalizeGoogleGrounding({
    candidate,
    retrievedAt: '2026-10-27T16:00:00.000Z',
    destinationName: 'Hà Nội',
    travelDates: ['2026-11-20', '2026-11-21'],
  });

  assert.equal(result.summary, summary);
  assert.equal(result.evidence.length, 1);
  assert.equal(result.evidence[0].origin, 'web');
  assert.equal(result.evidence[0].reviewed, false);
  assert.equal(result.evidence[0].sourceUri, 'https://baotanglichsu.vn/vi/Articles/3096/gio-mo-cua.html');
  assert.equal(result.evidence[0].sourceTitle, 'Giờ mở cửa và giá vé - Bảo tàng Lịch sử Quốc gia');
  assert.equal(result.evidence[0].retrievedAt, '2026-10-27T16:00:00.000Z');

  assert.equal(result.claims.length, 1);
  assert.equal(result.claims[0].kind, 'fact');
  assert.equal(result.claims[0].field, 'advice');
  assert.equal(result.claims[0].context, 'Bảo tàng Lịch sử Quốc gia');
  assert.deepEqual(result.claims[0].sourceIds, [result.evidence[0].id]);

  assert.deepEqual(result.searchQueries, ['giờ mở cửa Bảo tàng Lịch sử Quốc gia']);
  assert.ok(result.searchEntryPoint);
  assert.ok(result.warnings.some(w => w.includes('chưa được Admin kiểm duyệt')));
});

test('normalizeGoogleGrounding handles Vietnamese accent multi-byte drift without character corruption', () => {
  const summary = 'Đà Lạt có thời tiết mát mẻ quanh năm.';
  // 'Đà Lạt' is 10 UTF-8 bytes, 6 UTF-16 code units
  const daLatBytes = Buffer.from('Đà Lạt', 'utf-8').length;
  assert.equal(daLatBytes, 10);
  assert.equal('Đà Lạt'.length, 6);

  const candidate = {
    content: { parts: [{ text: summary }] },
    groundingMetadata: {
      webSearchQueries: ['thời tiết Đà Lạt'],
      groundingChunks: [
        {
          web: {
            uri: 'https://dalat.info/thoi-tiet',
            title: 'Khí hậu Đà Lạt',
          },
        },
      ],
      groundingSupports: [
        {
          segment: { startIndex: 0, endIndex: daLatBytes },
          groundingChunkIndices: [0],
        },
      ],
    },
  };

  const result = normalizeGoogleGrounding({
    candidate,
    retrievedAt: '2026-10-27T16:00:00.000Z',
    destinationName: 'Đà Lạt',
  });

  assert.equal(result.claims.length, 1);
  assert.equal(result.claims[0].context, 'Đà Lạt');
});

test('normalizeGoogleGrounding handles missing or empty groundingMetadata gracefully', () => {
  const summary = 'Lời khuyên không có nguồn tìm kiếm.';
  const candidate = { content: { parts: [{ text: summary }] } };

  const result = normalizeGoogleGrounding({
    candidate,
    retrievedAt: '2026-10-27T16:00:00.000Z',
    destinationName: 'Huế',
  });

  assert.equal(result.summary, summary);
  assert.equal(result.evidence.length, 0);
  assert.equal(result.claims.length, 0);
  assert.equal(result.searchQueries.length, 0);
  assert.equal(result.searchEntryPoint, null);
  assert.ok(result.warnings.some(w => w.includes('chưa được Admin kiểm duyệt')));
});

test('normalizeGoogleGrounding rejects malicious or invalid URI schemes', () => {
  const summary = 'Thử nghiệm bảo mật URL.';
  const candidate = {
    content: { parts: [{ text: summary }] },
    groundingMetadata: {
      webSearchQueries: ['test'],
      groundingChunks: [
        { web: { uri: 'javascript:alert(1)', title: 'XSS' } },
        { web: { uri: 'data:text/html,<script>alert(1)</script>', title: 'Data' } },
        { web: { uri: 'ftp://ftp.portal.vn', title: 'FTP' } },
        { web: { uri: 'https://safe.vn/info', title: 'Safe' } },
      ],
      groundingSupports: [
        {
          segment: { startIndex: 0, endIndex: 9 },
          groundingChunkIndices: [0, 1, 2, 3],
        },
      ],
    },
  };

  const result = normalizeGoogleGrounding({ candidate });

  assert.equal(result.evidence.length, 1);
  assert.equal(result.evidence[0].sourceUri, 'https://safe.vn/info');
  assert.deepEqual(result.claims[0].sourceIds, [result.evidence[0].id]);
});

test('normalizeGoogleGrounding filters out out-of-bounds or non-integer chunk indices', () => {
  const summary = 'Thử nghiệm chỉ số chunk sai.';
  const candidate = {
    content: { parts: [{ text: summary }] },
    groundingMetadata: {
      webSearchQueries: ['test'],
      groundingChunks: [
        { web: { uri: 'https://safe.vn/article', title: 'Article' } },
      ],
      groundingSupports: [
        {
          segment: { startIndex: 0, endIndex: 9 },
          groundingChunkIndices: [999, -1, 'invalid', null],
        },
      ],
    },
  };

  const result = normalizeGoogleGrounding({ candidate });

  assert.equal(result.evidence.length, 1);
  assert.equal(result.claims.length, 0); // No valid chunk matched, claim discarded
});

import {createItineraryGateway, WEB_ADVICE} from '../supabase/functions/itinerary-proposal/gateway.mjs';

test('createItineraryGateway processes travelgo.web.advice.v1 end-to-end', async () => {
  const owner = '22222222-2222-4222-8222-222222222222';
  const requestId = '33333333-3333-4333-8333-333333333333';
  const calls = [];
  let finalizedResult = null;

  const handler = createItineraryGateway({
    projectUrl: 'https://fixture.supabase.co',
    publicKey: 'public-fixture',
    serviceKey: 'service-fixture',
    geminiKey: 'gemini-fixture',
    enabled: true,
    realContextAllowed: true,
    allowedSubjects: [owner],
    checkAccount: async () => ({ allowed: true }),
  }, async (url, init = {}) => {
    const body = init.body ? JSON.parse(init.body) : null;
    calls.push({ url, init, body });
    if (url.endsWith('/auth/v1/user')) {
      return Response.json({ id: owner, aud: 'authenticated', is_anonymous: false });
    }
    if (url.endsWith('/reserve_ai_request_v1')) {
      return Response.json({
        status: 'reserved',
        requestId,
        acceptedDay: '2026-10-27',
        remaining: 2,
        expiresAt: '2026-10-27T17:00:00Z',
        workerToken: '44444444-4444-4444-8444-444444444444',
        dispatch: true,
        result: null,
      });
    }
    if (url.includes('generativelanguage.googleapis.com')) {
      return Response.json({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [{ text: 'Bảo tàng đóng cửa thứ Hai.' }],
            },
            groundingMetadata: {
              webSearchQueries: ['giờ mở cửa'],
              groundingChunks: [
                { web: { uri: 'https://baotang.vn/gio', title: 'Giờ mở cửa' } },
              ],
              groundingSupports: [
                {
                  segment: { startIndex: 0, endIndex: 8 },
                  groundingChunkIndices: [0],
                },
              ],
            },
          },
        ],
      });
    }
    if (url.endsWith('/finalize_ai_request_v1')) {
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
    contract: WEB_ADVICE,
    requestId,
    consent: true,
    webConsent: true,
    prompt: 'Bảo tàng mở cửa thứ mấy?',
    context: {
      destinationName: 'Hà Nội',
      dates: ['2026-11-20'],
      numPeople: 2,
      budgetVnd: 5000000,
      interests: ['văn hóa'],
      scope: 'whole_trip',
      baseDigest: 'a'.repeat(64),
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
  assert.equal(data.result.contract, WEB_ADVICE);
  assert.equal(data.result.evidence.length, 1);
  assert.equal(data.result.evidence[0].sourceUri, 'https://baotang.vn/gio');
  assert.equal(data.result.claims.length, 1);
  assert.ok(data.result.warnings.some(w => w.includes('chưa được Admin kiểm duyệt')));
});

test('createItineraryGateway denies anonymous guest for web advice', async () => {
  const anon = '55555555-5555-4555-8555-555555555555';
  const requestId = '66666666-6666-4666-8666-666666666666';

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
      contract: WEB_ADVICE,
      requestId,
      consent: true,
      webConsent: true,
      prompt: 'Hỏi thông tin',
      context: {
        destinationName: 'Đà Nẵng',
        dates: ['2026-11-20'],
        numPeople: 1,
        budgetVnd: 1000000,
        interests: ['ẩm thực'],
        scope: 'day',
        baseDigest: 'b'.repeat(64),
      },
    }),
  });

  const res = await handler(req);
  assert.equal(res.status, 403);
  const body = await res.json();
  assert.equal(body.status, 'subject_denied');
});
