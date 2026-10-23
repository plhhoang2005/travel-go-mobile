// Edge Function Entry: admin-publication
// Contract: travelgo.admin.publication.v1
import { createPublicationGateway } from './gateway.mjs';

declare const Deno: {
  env: {
    get(name: string): string | undefined;
  };
  serve(handler: (request: Request) => Promise<Response>): void;
};

const projectUrl = Deno.env.get('SUPABASE_URL') || '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

async function verifyCaller(token: string) {
  const res = await fetch(`${projectUrl}/auth/v1/user`, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${token}`,
    },
  });
  if (!res.ok) throw new Error('unauthorized');
  const user = await res.json();
  const profileRes = await fetch(`${projectUrl}/rest/v1/profiles?id=eq.${user.id}&select=role`, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
  });
  const profiles = await profileRes.json();
  return { id: user.id, role: profiles[0]?.role };
}

async function callRpc(name: string, params: Record<string, unknown>, token: string) {
  const res = await fetch(`${projectUrl}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`RPC ${name} failed: ${err}`);
  }
  return await res.json();
}

const storage = {
  async uploadOnce(bucket: string, objectKey: string, bytes: Uint8Array, opts: { contentType: string }) {
    const res = await fetch(`${projectUrl}/storage/v1/object/${bucket}/${objectKey}`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': opts.contentType,
      },
      body: bytes,
    });
    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Storage upload failed: ${err}`);
    }
    return true;
  },
  async readback(bucket: string, objectKey: string) {
    const res = await fetch(`${projectUrl}/storage/v1/object/${bucket}/${objectKey}`, {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    });
    if (!res.ok) throw new Error('Storage readback failed');
    const buf = await res.arrayBuffer();
    const bytes = new Uint8Array(buf);
    const hashBuf = await crypto.subtle.digest('SHA-256', bytes);
    const hashHex = Array.from(new Uint8Array(hashBuf))
      .map((b) => b.toString(16).padLeft ? b.toString(16).padStart(2, '0') : b.toString(16))
      .join('');
    return { bytes, sha256: hashHex, byteLength: bytes.byteLength };
  },
};

const handle = createPublicationGateway({
  verifyCaller,
  callAsCaller: (name, params, token) => callRpc(name, params, token),
  callAsWorker: (name, params) => callRpc(name, params, serviceKey),
  storage,
});

Deno.serve(handle);
