import { createHash } from 'node:crypto';

// Immutable upload adapter, shared by the Edge entrypoint and fetch-only tests.
export function createPublicationStorage({projectUrl,serviceKey,fetchImpl=fetch}) {
  const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
  const url=(bucket,key)=>`${projectUrl}/storage/v1/object/${bucket}/${key}`;
  const headers={apikey:serviceKey,Authorization:`Bearer ${serviceKey}`};
  const storage={
    async uploadOnce(bucket,key,bytes,{contentType}) {
      const res=await fetchImpl(url(bucket,key),{
        method:'POST',redirect:'manual',headers:{...headers,'Content-Type':contentType},body:bytes,
      });
      if(res.ok) return true;
      const body=await res.text();
      let error;
      try { error=JSON.parse(body); } catch { /* Unknown errors remain failures. */ }
      const duplicate=[400,409].includes(res.status) && (
        ['Duplicate','ResourceAlreadyExists'].includes(error?.error) ||
        ['Duplicate','ResourceAlreadyExists'].includes(error?.code) ||
        ['Asset Already Exists','The resource already exists'].includes(error?.message)
      );
      if(!duplicate) throw new Error(`Storage upload failed (${res.status})`);
      const existing=await storage.readback(bucket,key);
      if(existing.byteLength!==bytes.byteLength || existing.sha256!==digest(bytes)) {
        throw new Error('Storage integrity failure: existing object has different bytes');
      }
      return true;
    },
    async readback(bucket,key) {
      const res=await fetchImpl(url(bucket,key),{method:'GET',redirect:'manual',headers});
      if(!res.ok) throw new Error(`Storage readback failed (${res.status})`);
      const bytes=new Uint8Array(await res.arrayBuffer());
      return {bytes,sha256:digest(bytes),byteLength:bytes.byteLength};
    },
  };
  return storage;
}
