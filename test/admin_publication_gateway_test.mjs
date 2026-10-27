// Unit and fault injection tests for admin-publication gateway and storage worker.

import test from 'node:test';
import assert from 'node:assert/strict';
import { createPublicationGateway } from '../supabase/functions/admin-publication/gateway.mjs';

function makeRequest(body, auth = 'Bearer test-admin-token') {
  return new Request('https://example.com/functions/v1/admin-publication', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': auth,
    },
    body: JSON.stringify(body),
  });
}

test('admin-publication gateway rejects invalid contract or missing auth', async () => {
  const gateway = createPublicationGateway();

  // Missing auth
  const resNoAuth = await gateway(new Request('https://example.com', { method: 'POST' }));
  assert.equal(resNoAuth.status, 401);

  // Invalid contract
  const resBadContract = await gateway(makeRequest({
    contract: 'wrong.contract',
    action: 'preview',
    request: {},
  }));
  assert.equal(resBadContract.status, 422);
});

test('preview action freezes draft and stages candidate', async () => {
  let staged = false;
  const gateway = createPublicationGateway({
    verifyCaller: async () => ({ id: 'admin-1', role: 'admin' }),
    callAsCaller: async (name, params) => {
      assert.equal(name, 'prepare_discovery_preview');
      return {
        previewId: 'prev-1234',
        sourceRevision: 1,
        expectedActiveVersion: 0,
        candidateVersion: 1,
        previewDigest: 'digest-1234',
        expiresAt: new Date(Date.now() + 900000).toISOString(),
        frozenDraft: {
          inventory: {
            destinations: [{ id: 'da-nang', name: 'Đà Nẵng', slug: 'da-nang', region: 'Miền Trung', isActive: true }],
            places: [],
          },
        },
      };
    },
    callAsWorker: async (name, params) => {
      assert.equal(name, 'stage_discovery_candidate');
      assert.equal(params.p_preview_id, 'prev-1234');
      staged = true;
      return {};
    },
  });

  const res = await gateway(makeRequest({
    contract: 'travelgo.admin.publication.v1',
    action: 'preview',
    request: {
      requestId: 'req-001',
      draftRevision: 1,
    },
  }));

  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(staged, true);
  assert.equal(data.preview.previewId, 'prev-1234');
  assert.equal(data.preview.expectedActiveVersion, 0);
  assert.equal(data.preview.summary.added, 1);
  assert.equal(data.preview.blockers.length, 0);
});

test('readback_failure_never_switches_manifest: readback mismatch aborts activation', async () => {
  var activateCalls = 0;
  const mockSha = 'a'.repeat(64);
  const badSha = 'b'.repeat(64);

  const gateway = createPublicationGateway({
    verifyCaller: async () => ({ id: 'admin-1', role: 'admin' }),
    callAsCaller: async (name) => {
      assert.equal(name, 'begin_discovery_publication');
      return {
        operationId: 'op-001',
        workerToken: 'tok-001',
        candidateVersion: 1,
        objectKey: 'releases/v2/1.json',
        payloadText: '{"test":1}',
        sha256: mockSha,
        byteLength: 10,
      };
    },
    storage: {
      uploadOnce: async () => true,
      readback: async () => ({
        bytes: Buffer.from('corrupted'),
        sha256: badSha, // MISMATCH!
        byteLength: 10,
      }),
    },
    callAsWorker: async (name) => {
      if (name === 'activate_discovery_release') {
        activateCalls++;
      }
      return {};
    },
  });

  const res = await gateway(makeRequest({
    contract: 'travelgo.admin.publication.v1',
    action: 'publish',
    request: {
      requestId: 'req-002',
      previewId: 'prev-1234',
      previewDigest: 'digest-1234',
      expectedDraftRevision: 1,
      expectedActiveVersion: 0,
    },
  }));

  assert.equal(res.status, 200);
  const data = await res.json();

  // Pin assertion: activateCalls MUST be 0!
  assert.equal(activateCalls, 0);
  assert.equal(data.operation.state, 'needs_retry');
});

test('successful publish completes storage upload, verified readback and activation', async () => {
  var activateCalls = 0;
  const mockSha = 'c'.repeat(64);

  const gateway = createPublicationGateway({
    verifyCaller: async () => ({ id: 'admin-1', role: 'admin' }),
    callAsCaller: async (name) => {
      assert.equal(name, 'begin_discovery_publication');
      return {
        operationId: 'op-002',
        workerToken: 'tok-002',
        candidateVersion: 2,
        objectKey: 'releases/v2/2.json',
        payloadText: '{"valid":true}',
        sha256: mockSha,
        byteLength: 14,
      };
    },
    storage: {
      uploadOnce: async () => true,
      readback: async () => ({
        bytes: Buffer.from('{"valid":true}'),
        sha256: mockSha, // EXACT MATCH
        byteLength: 14,
      }),
    },
    callAsWorker: async (name) => {
      assert.equal(name, 'activate_discovery_release');
      activateCalls++;
      return {
        operationId: 'op-002',
        state: 'completed',
        version: 2,
      };
    },
  });

  const res = await gateway(makeRequest({
    contract: 'travelgo.admin.publication.v1',
    action: 'publish',
    request: {
      requestId: 'req-003',
      previewId: 'prev-5678',
      previewDigest: 'digest-5678',
      expectedDraftRevision: 2,
      expectedActiveVersion: 1,
    },
  }));

  assert.equal(res.status, 200);
  const data = await res.json();

  assert.equal(activateCalls, 1);
  assert.equal(data.operation.state, 'completed');
  assert.equal(data.operation.version, 2);
});

test('completed publication replay performs neither upload nor activation',async()=>{
  const gateway=createPublicationGateway({
    verifyCaller:async()=>({id:'admin',role:'admin'}),
    callAsCaller:async()=>({operationId:'op-replay',state:'completed',candidateVersion:2,sourceRevision:3}),
    callAsWorker:async()=>{assert.fail('completed replay activated again');},
    storage:{uploadOnce:async()=>assert.fail('completed replay uploaded again')},
  });
  const res=await gateway(makeRequest({contract:'travelgo.admin.publication.v1',action:'publish',request:{
    requestId:'same',previewId:'prev',previewDigest:'digest',expectedDraftRevision:3,expectedActiveVersion:1,
  }}));
  assert.equal(res.status,200); assert.equal((await res.json()).operation.id,'op-replay');
});
test('preview replay projects identical bytes from server frozen time',async()=>{
  const payloads=[];
  let time=0;
  const gateway=createPublicationGateway({
    now:()=>new Date(1000*(++time)),verifyCaller:async()=>({id:'admin',role:'admin'}),
    callAsCaller:async()=>({previewId:'same',sourceRevision:1,expectedActiveVersion:0,candidateVersion:1,
      previewDigest:'digest',expiresAt:'2026-10-27T10:00:00Z',preparedAt:'2026-10-27T09:00:00Z',
      frozenDraft:{inventory:{destinations:[],places:[]}}}),
    callAsWorker:async(_,args)=>{payloads.push(args.p_payload_text);return {};},
  });
  const req=()=>makeRequest({contract:'travelgo.admin.publication.v1',action:'preview',request:{requestId:'same',draftRevision:1}});
  assert.equal((await gateway(req())).status,200); assert.equal((await gateway(req())).status,200);
  assert.equal(payloads.length,2); assert.equal(payloads[0],payloads[1]);
});

test('blocked preview is not staged for a direct publish bypass',async()=>{
  let staged=0;
  const gateway=createPublicationGateway({
    verifyCaller:async()=>({id:'admin',role:'admin'}),
    callAsCaller:async()=>({previewId:'blocked',sourceRevision:1,candidateVersion:1,expectedActiveVersion:0,
      preparedAt:'2026-10-27T09:00:00Z',previewDigest:'d',expiresAt:'2026-10-27T10:00:00Z',
      frozenDraft:{inventory:{destinations:[{id:'d',name:'D',slug:'d',region:'Miền Trung',isActive:true}],
        places:[{id:'d/p',destinationId:'d',name:'P',latitude:16,longitude:null,isActive:true}]}}}),
    callAsWorker:async()=>{staged++;},
  });
  const res=await gateway(makeRequest({contract:'travelgo.admin.publication.v1',action:'preview',request:{requestId:'r',draftRevision:1}}));
  assert.equal(res.status,200); assert.ok((await res.json()).preview.blockers.length>0);
  assert.equal(staged,0);
});
test('expired candidate is a definite rejection rather than uncertain upstream failure',async()=>{
  const gateway=createPublicationGateway({verifyCaller:async()=>({id:'a',role:'admin'}),
    callAsCaller:async()=>{throw new Error('RPC failed: candidate_expired');}});
  const res=await gateway(makeRequest({contract:'travelgo.admin.publication.v1',action:'publish',request:{
    requestId:'r',previewId:'p',previewDigest:'d',expectedDraftRevision:1,expectedActiveVersion:0}}));
  assert.equal(res.status,422); assert.equal((await res.json()).code,'candidate_expired');
});
