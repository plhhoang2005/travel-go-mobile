// Edge Function Gateway: admin-publication
// Contract: travelgo.admin.publication.v1
// Manages draft freezing, public V2 projection, immutable Storage uploads, and atomic CAS activation.

import crypto from 'node:crypto';
import { Buffer } from 'node:buffer';
import { validateAndProjectPublicBundle, encodePublicBundle } from './bundle.mjs';

const ALLOWED_ACTIONS = new Set(['preview', 'publish', 'operation']);
const MAX_BODY_BYTES = 64 * 1024; // 64 KiB
const BUCKET_NAME = 'discovery-catalogue';

export function createPublicationGateway(deps = {}) {
  const {
    verifyCaller = async () => ({ id: 'mock-admin', role: 'admin' }),
    callAsCaller = async () => ({}),
    callAsWorker = async () => ({}),
    storage = {
      uploadOnce: async () => true,
      readback: async () => ({ bytes: Buffer.from('{}'), sha256: '', byteLength: 2 }),
    },
    now = () => new Date(),
  } = deps;

  return async function handlePublication(request) {
    try {
      if (request.method !== 'POST') {
      return jsonResponse({ code: 'method_not_allowed', message: 'Method not allowed' }, 405);
    }

    // 1. Authorization check
    const authHeader = request.headers.get('authorization') || '';
    const bearerMatch = authHeader.match(/^Bearer\s+([a-zA-Z0-9\._\-]+)$/);
    if (!bearerMatch) {
      return jsonResponse({ code: 'unauthorized', message: 'Missing or malformed Authorization header' }, 401);
    }
    const callerToken = bearerMatch[1];

    // 2. Validate payload size
    let rawBody;
    try {
      rawBody = await request.text();
    } catch {
      return jsonResponse({ code: 'invalid_body', message: 'Could not read request body' }, 400);
    }

    if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
      return jsonResponse({ code: 'body_too_large', message: 'Payload exceeds 64 KiB limit' }, 413);
    }

    let parsed;
    try {
      parsed = JSON.parse(rawBody);
    } catch {
      return jsonResponse({ code: 'invalid_json', message: 'Malformed JSON payload' }, 400);
    }

    // 3. Contract envelope validation
    if (parsed.contract !== 'travelgo.admin.publication.v1') {
      return jsonResponse({ code: 'invalid_contract', message: 'Expected travelgo.admin.publication.v1' }, 422);
    }

    const { action, request: actionReq } = parsed;
    if (!action || !ALLOWED_ACTIONS.has(action)) {
      return jsonResponse({ code: 'invalid_action', message: 'Unsupported publication action' }, 422);
    }
    if (!actionReq || typeof actionReq !== 'object' || Array.isArray(actionReq)) {
      return jsonResponse({ code: 'invalid_request_field', message: 'Request field must be an object' }, 422);
    }

    // 4. Verify caller authority
    let caller;
    try {
      caller = await verifyCaller(callerToken);
      if (!caller || caller.role !== 'admin') {
        return jsonResponse({ code: 'forbidden', message: 'Admin role required' }, 403);
      }
    } catch {
      return jsonResponse({ code: 'unauthorized', message: 'Token verification failed' }, 401);
    }

    // 5. Dispatch action
    try {
      if (action === 'preview') {
        return await handlePreview({ actionReq, callerToken, callAsCaller, callAsWorker, now });
      } else if (action === 'publish') {
        return await handlePublish({ actionReq, callerToken, callAsCaller, callAsWorker, storage });
      } else if (action === 'operation') {
        return await handleOperation({ actionReq, callerToken, callAsCaller });
      }
    } catch (err) {
      const msg = err.message || String(err);
      if (msg.includes('forbidden') || msg.includes('admin role required')) {
        return jsonResponse({ code: 'forbidden', message: msg }, 403);
      }
      if (msg.includes('unauthorized')) {
        return jsonResponse({ code: 'unauthorized', message: msg }, 401);
      }
      if (msg.includes('concurrency_conflict') || msg.includes('revision_mismatch')) {
        return jsonResponse({ code: 'conflict', message: msg }, 409);
      }
      for (const code of ['candidate_expired','candidate_not_staged','candidate_not_found','request_payload_mismatch','preview_digest_mismatch','active_version_mismatch','candidate_immutable','legacy_preview_replay_unavailable']) {
        if (msg.includes(code)) {
          return jsonResponse({code,message:msg},code==='candidate_expired' || code==='candidate_not_staged' ? 422 : 409);
        }
      }
      return jsonResponse({ code: 'internal_error', message: msg }, 500);
    }
    } catch (topErr) {
      console.error('PUBLICATION_TOP_LEVEL_ERROR:', topErr);
      return jsonResponse({ code: 'internal_error', message: topErr.message || String(topErr) }, 500);
    }
  };
}

async function handlePreview({ actionReq, callerToken, callAsCaller, callAsWorker, now }) {
  const { requestId, draftRevision } = actionReq;
  if (!requestId || !Number.isInteger(draftRevision)) {
    return jsonResponse({ code: 'invalid_parameters', message: 'requestId and integer draftRevision required' }, 422);
  }

  // 1. Prepare preview and freeze draft in DB
  const prepRes = await callAsCaller('prepare_discovery_preview', {
    p_request_id: requestId,
    p_expected_draft_revision: draftRevision,
  }, callerToken);

  const {
    previewId,
    sourceRevision,
    expectedActiveVersion,
    candidateVersion,
    previewDigest,
    expiresAt,
    frozenDraft,
  } = prepRes;

  // 2. Validate and project public V2 bundle
  const { bundle, blockers, warnings } = validateAndProjectPublicBundle({
    frozenDraft,
    version: candidateVersion,
    preparedAt: prepRes.preparedAt || now().toISOString(),
  });

  // 3. Deterministically encode and stage candidate bytes via worker
  const { payloadText } = encodePublicBundle(bundle);
  if (blockers.length === 0) await callAsWorker('stage_discovery_candidate', {
    p_preview_id: previewId,
    p_worker_token: '00000000-0000-0000-0000-000000000000',
    p_payload_text: payloadText,
  });

  return jsonResponse({
    contract: 'travelgo.admin.publication.v1',
    action: 'preview',
    preview: {
      previewId,
      sourceRevision,
      expectedActiveVersion,
      previewDigest,
      summary: {
        added: bundle.catalogue.destinations.length,
        changed: 0,
        hidden: 0,
      },
      warnings,
      blockers,
      expiresAt,
    },
  }, 200);
}

async function handlePublish({ actionReq, callerToken, callAsCaller, callAsWorker, storage }) {
  const { requestId, previewId, previewDigest, expectedDraftRevision, expectedActiveVersion } = actionReq;
  if (!requestId || !previewId || !previewDigest || !Number.isInteger(expectedDraftRevision) || !Number.isInteger(expectedActiveVersion)) {
    return jsonResponse({ code: 'invalid_parameters', message: 'Incomplete publish request' }, 422);
  }

  // 1. Begin publication via caller RPC
  const beginRes = await callAsCaller('begin_discovery_publication', {
    p_request: {
      requestId,
      previewId,
      previewDigest,
      expectedDraftRevision,
      expectedActiveVersion,
    },
  }, callerToken);

  const { operationId, workerToken, candidateVersion, objectKey, payloadText, sha256, byteLength } = beginRes;

  // Completed retries do not upload or activate again. The caller RPC owns replay/CAS authority.
  if (beginRes.state === 'completed' || beginRes.state === 'conflict') {
    return jsonResponse({contract:'travelgo.admin.publication.v1',action:'publish',operation:{
      id:operationId,state:beginRes.state,version:candidateVersion,
      sourceRevision:beginRes.sourceRevision ?? expectedDraftRevision,
    }},200);
  }

  // 2. Upload immutable object to Storage
  const payloadBytes = Buffer.from(payloadText, 'utf8');
  await storage.uploadOnce(BUCKET_NAME, objectKey, payloadBytes, {
    contentType: 'application/json',
  });

  // 3. Verified readback
  const readback = await storage.readback(BUCKET_NAME, objectKey);
  const readbackSha = readback.sha256;
  const readbackLen = readback.byteLength;

  if (readbackSha !== sha256 || readbackLen !== byteLength) {
    // Readback mismatch! Abort activation without switching manifest!
    return jsonResponse({
      contract: 'travelgo.admin.publication.v1',
      action: 'publish',
      operation: {
        id: operationId,
        state: 'needs_retry',
        version: candidateVersion,
        sourceRevision: expectedDraftRevision,
      },
    }, 200);
  }

  // 4. Activate in DB via worker RPC
  const actRes = await callAsWorker('activate_discovery_release', {
    p_operation_id: operationId,
    p_worker_token: workerToken,
    p_readback_sha256: readbackSha,
    p_readback_length: readbackLen,
  });

  return jsonResponse({
    contract: 'travelgo.admin.publication.v1',
    action: 'publish',
    operation: {
      id: operationId,
      state: actRes.state,
      version: actRes.version,
      sourceRevision: expectedDraftRevision,
    },
  }, 200);
}

async function handleOperation({ actionReq, callerToken, callAsCaller }) {
  const { operationId } = actionReq;
  if (!operationId) {
    return jsonResponse({ code: 'invalid_parameters', message: 'operationId required' }, 422);
  }

  const opRes = await callAsCaller('get_discovery_publication_operation', {
    p_operation_id: operationId,
  }, callerToken);

  return jsonResponse({
    contract: 'travelgo.admin.publication.v1',
    action: 'operation',
    operation: {
      id: operationId,
      state: opRes.state,
      version: opRes.version,
      sourceRevision: opRes.sourceRevision,
    },
  }, 200);
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}
