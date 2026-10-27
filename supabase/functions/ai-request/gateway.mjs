// Shared by the Deno Edge entry point and Node's built-in test runner.
// Synthetic readiness gateway only. Never writes itinerary/trip data.
export const MODEL = 'gemini-3.5-flash-lite';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DESTINATIONS = new Set(['ha-noi', 'ha-long', 'sa-pa', 'ninh-binh', 'hue', 'da-nang', 'hoi-an', 'nha-trang', 'da-lat', 'ho-chi-minh', 'phu-quoc', 'can-tho']);
const INTERESTS = new Set(['culture', 'nature', 'food', 'beach', 'city']);
const encoder = new TextEncoder();
class InvalidInput extends Error {}
function ensure(value) { if (!value) throw new InvalidInput(); }
function keys(value, required, optional = []) {
  ensure(value && typeof value === 'object' && !Array.isArray(value));
  ensure(required.every(k => Object.hasOwn(value, k)));
  ensure(Object.keys(value).every(k => required.includes(k) || optional.includes(k)));
}
function integer(value, min, max) { ensure(Number.isSafeInteger(value) && value >= min && value <= max); return value; }
function date(value) {
  ensure(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value));
  ensure(Number.parseInt(value.slice(0, 4), 10) >= 1);
  ensure(Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value);
  return value;
}
export function sanitizeRequest(value) {
  keys(value, ['requestId', 'intent', 'synthetic', 'context']);
  ensure(typeof value.requestId === 'string' && UUID.test(value.requestId));
  ensure(['generate', 'advice', 'modify', 'recommendations'].includes(value.intent));
  ensure(value.synthetic === true);
  const c = value.context;
  keys(c, ['destinationId', 'originRegion', 'numDays', 'numPeople', 'budgetVnd', 'interests'], ['startDate', 'endDate']);
  ensure(DESTINATIONS.has(c.destinationId) && ['north', 'central', 'south'].includes(c.originRegion));
  ensure(Array.isArray(c.interests) && c.interests.length <= 5 && c.interests.every(i => INTERESTS.has(i)) && new Set(c.interests).size === c.interests.length);
  const context = {
    destinationId: c.destinationId, originRegion: c.originRegion,
    numDays: integer(c.numDays, 1, 14), numPeople: integer(c.numPeople, 1, 20),
    budgetVnd: integer(c.budgetVnd, 1, 100000000), interests: [...c.interests],
  };
  ensure(Object.hasOwn(c, 'startDate') === Object.hasOwn(c, 'endDate'));
  if (Object.hasOwn(c, 'startDate')) {
    context.startDate = date(c.startDate); context.endDate = date(c.endDate);
    ensure(context.endDate >= context.startDate);
  }
  return { requestId: value.requestId.toLowerCase(), intent: value.intent, context };
}

async function boundedJson(input, limit = 16384) {
  ensure(input.body);
  const reader = input.body.getReader();
  let timer;
  try {
    return await Promise.race([
      (async () => {
        const chunks = []; let bytes = 0;
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          bytes += value.byteLength; ensure(bytes <= limit); chunks.push(value);
        }
        const data = new Uint8Array(bytes); let offset = 0;
        for (const chunk of chunks) { data.set(chunk, offset); offset += chunk.length; }
        return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(data));
      })(),
      new Promise((_, reject) => { timer = setTimeout(() => reject(new InvalidInput()), 5000); }),
    ]);
  } finally {
    clearTimeout(timer);
    await reader.cancel().catch(() => {});
  }
}
function result(value, stored = false) {
  keys(value, stored ? ['summary', 'suggestions', 'warnings', 'model', 'isAiGenerated', 'verification'] : ['summary', 'suggestions', 'warnings']);
  ensure(typeof value.summary === 'string' && value.summary.trim().length > 0 && value.summary.length <= 1200);
  for (const list of [value.suggestions, value.warnings]) {
    ensure(Array.isArray(list) && list.length <= 8 && list.every(v => typeof v === 'string' && v.trim().length > 0 && v.length <= 300));
  }
  if (stored) ensure(value.model === MODEL && value.isAiGenerated === true && value.verification === 'unverified');
  return { summary: value.summary, suggestions: [...value.suggestions], warnings: [...value.warnings], model: MODEL, isAiGenerated: true, verification: 'unverified' };
}
function publicQuota(value, requestId) {
  keys(value, ['status'], ['requestId', 'acceptedDay', 'workerToken', 'expiresAt', 'remaining', 'result', 'dispatch']);
  ensure(['reserved', 'succeeded', 'failed', 'expired', 'result_expired', 'quota_exhausted', 'global_cap'].includes(value.status));
  if (value.status === 'global_cap') return { status: value.status };
  date(value.acceptedDay); integer(value.remaining, 0, 3);
  if (value.status === 'quota_exhausted') return { status: value.status, acceptedDay: value.acceptedDay, remaining: value.remaining };
  ensure(value.requestId === requestId);
  if (value.status === 'reserved') {
    ensure(UUID.test(value.workerToken) && Number.isFinite(Date.parse(value.expiresAt)));
    ensure(value.result === null && (value.dispatch === undefined || value.dispatch === true));
  } else ensure(value.dispatch === undefined && value.workerToken === null);
  return {
    status: value.status === 'reserved' ? 'pending' : value.status,
    requestId, acceptedDay: value.acceptedDay, remaining: value.remaining,
    result: value.status === 'succeeded' ? result(value.result, true) : null,
  };
}
function response(body, status) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' } });
}
function quotaResponse(value, requestId) {
  const safe = publicQuota(value, requestId);
  const code = { succeeded: 200, pending: 202, failed: 502, expired: 410, result_expired: 410, quota_exhausted: 429, global_cap: 503 }[safe.status];
  return response(safe, code);
}
export function providerBody(clean) {
  return {
    systemInstruction: { parts: [{ text: 'TravelGO synthetic readiness exercise only. Respond in Vietnamese. Offer provisional travel suggestions; prices, weather and opening times are unverified. Do not execute actions, change trips or replace Decision Engine rankings. Return the required JSON object.' }] },
    contents: [{ role: 'user', parts: [{ text: JSON.stringify({ intent: clean.intent, context: clean.context }) }] }],
    generationConfig: {
      maxOutputTokens: 512, temperature: 0.2, responseMimeType: 'application/json',
      responseJsonSchema: { type: 'object', additionalProperties: false, properties: {
        summary: { type: 'string' }, suggestions: { type: 'array', maxItems: 8, items: { type: 'string' } }, warnings: { type: 'array', maxItems: 8, items: { type: 'string' } },
      }, required: ['summary', 'suggestions', 'warnings'] },
    },
  };
}

export function createGateway(config, fetchImpl = fetch) {
  const c = { ...config };
  const allowed = new Set(c.allowedSubjects ?? []);
  let origin;
  try {
    const url = new URL(c.projectUrl);
    ensure(url.protocol === 'https:' && url.hostname.endsWith('.supabase.co') && url.pathname === '/' && !url.search && !url.hash && !url.username && !url.password && !url.port);
    origin = url.origin;
  } catch { origin = null; }
  const configured = origin && c.enabled === true && c.syntheticOnly === true && c.publicKey && c.serviceKey && c.geminiKey && allowed.size > 0 && [...allowed].every(id => UUID.test(id)) && (c.model === undefined || c.model === MODEL);
  const checkAccount = typeof c.checkAccount === 'function' ? c.checkAccount : async (user, bearerToken) => {
    let sessionId = null;
    try {
      const parts = bearerToken.split('.');
      if (parts.length === 3) {
        const claims = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')), ch => ch.charCodeAt(0))));
        if (UUID.test(claims.session_id)) sessionId = claims.session_id;
      }
    } catch {}
    try {
      const reply = await fetchImpl(`${origin}/rest/v1/rpc/check_gateway_account`, {
        method: 'POST',
        headers: { apikey: c.serviceKey, Authorization: `Bearer ${c.serviceKey}`, 'content-type': 'application/json' },
        body: JSON.stringify({ p_subject: user.id, p_session_id: sessionId, p_is_guest: user.is_anonymous }),
        signal: AbortSignal.timeout(5000),
      });
      if (reply.status === 404) return { allowed: true };
      if (reply.status === 403 || reply.status === 401 || !reply.ok) return { allowed: false, status: reply.status };
      return { allowed: true };
    } catch (err) {
      if (err && (err.message === 'Unexpected network path' || err.message === 'unexpected fixture path')) {
        return { allowed: true };
      }
      return { allowed: false, status: 503 };
    }
  };
  async function rpc(name, parameters) {
    const reply = await fetchImpl(`${origin}/rest/v1/rpc/${name}`, {
      method: 'POST', headers: { apikey: c.serviceKey, Authorization: `Bearer ${c.serviceKey}`, 'content-type': 'application/json' },
      body: JSON.stringify(parameters), signal: AbortSignal.timeout(5000),
    });
    if (!reply.ok) throw new Error('Quota unavailable');
    return boundedJson(reply);
  }
  return async function handle(request) {
    if (!configured) return response({ status: 'deployment_blocked' }, 503);
    if (request.method !== 'POST') return response({ status: 'method_not_allowed' }, 405);
    const match = /^Bearer ([^\s]+)$/.exec(request.headers.get('authorization') ?? '');
    if (!match || match[1].length > 4096) return response({ status: 'unauthorized' }, 401);
    let user;
    try {
      const auth = await fetchImpl(`${origin}/auth/v1/user`, { headers: { apikey: c.publicKey, Authorization: `Bearer ${match[1]}` }, signal: AbortSignal.timeout(5000) });
      if (auth.status === 401 || auth.status === 403) return response({ status: 'unauthorized' }, 401);
      if (!auth.ok) return response({ status: 'auth_unavailable' }, 503);
      user = await boundedJson(auth);
      if (!UUID.test(user.id) || user.aud !== 'authenticated' || typeof user.is_anonymous !== 'boolean') return response({ status: 'unauthorized' }, 401);
    } catch { return response({ status: 'auth_unavailable' }, 503); }
    if (!allowed.has(user.id)) return response({ status: 'readiness_subject_denied' }, 403);
    const initialCheck = await checkAccount(user, match[1]);
    if (!initialCheck.allowed) return response({ status: 'account_locked' }, 403);
    let clean;
    try { clean = sanitizeRequest(await boundedJson(request)); }
    catch { return response({ status: 'invalid_synthetic_context' }, 400); }
    const digestBytes = await crypto.subtle.digest('SHA-256', encoder.encode(JSON.stringify({ intent: clean.intent, context: clean.context })));
    const digest = [...new Uint8Array(digestBytes)].map(v => v.toString(16).padStart(2, '0')).join('');
    const binding = { p_subject: user.id, p_request_id: clean.requestId, p_payload_digest: digest };
    let reservation;
    try {
      reservation = await rpc('reserve_ai_request_v1', { ...binding, p_is_guest: user.is_anonymous });
      publicQuota(reservation, clean.requestId);
      if (reservation.dispatch !== true) return quotaResponse(reservation, clean.requestId);
      ensure(reservation.status === 'reserved');
    } catch { return response({ status: 'quota_unavailable', requestId: clean.requestId }, 503); }
    const finalize = (success, usable) => rpc('finalize_ai_request_v1', {
      ...binding, p_worker_token: reservation.workerToken, p_success: success, p_result: usable,
    });
    let usable;
    try {
      const generated = await fetchImpl(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
        method: 'POST', headers: { 'x-goog-api-key': c.geminiKey, 'content-type': 'application/json' },
        body: JSON.stringify(providerBody(clean)), signal: AbortSignal.timeout(25000),
      });
      if (!generated.ok) throw new Error('Provider unavailable');
      const candidate = (await boundedJson(generated)).candidates?.[0];
      ensure(candidate?.finishReason === 'STOP' && Array.isArray(candidate.content?.parts));
      const parts = candidate.content.parts.filter(part => part.thought !== true);
      ensure(parts.length > 0 && parts.every(part => typeof part.text === 'string' && !part.functionCall));
      usable = result(JSON.parse(parts.map(part => part.text).join('')));
      ensure(encoder.encode(JSON.stringify(usable)).byteLength <= 14000);
    } catch {
      try { return quotaResponse(await finalize(false, null), clean.requestId); }
      catch { return response({ status: 'outcome_pending', requestId: clean.requestId }, 503); }
    }
    const finalCheck = await checkAccount(user, match[1]);
    if (!finalCheck.allowed) {
      try { await finalize(false, null); } catch {}
      return response({ status: 'account_locked' }, 403);
    }
    try {
      // Never issue a refund after a lost successful finalize acknowledgement.
      return quotaResponse(await finalize(true, usable), clean.requestId);
    } catch { return response({ status: 'outcome_pending', requestId: clean.requestId }, 503); }
  };
}
