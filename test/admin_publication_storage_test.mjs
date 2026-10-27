import test from 'node:test';
import assert from 'node:assert/strict';
import { createPublicationStorage } from '../supabase/functions/admin-publication/storage.mjs';

for (const status of [400,409]) {
  test(`existing object (${status}) is accepted only after exact readback`, async () => {
    const requests=[];
    const storage=createPublicationStorage({projectUrl:'https://example.test',serviceKey:'fixture',fetchImpl:async (url,opts)=>{
      requests.push(opts);
      if(opts.method==='POST') return new Response(JSON.stringify({error:'Duplicate'}),{status});
      return new Response('frozen bytes');
    }});
    await storage.uploadOnce('discovery-catalogue','releases/v2/1.json',Buffer.from('frozen bytes'),{contentType:'application/json'});
    assert.equal(requests.length,2);
    assert.equal(requests[0].headers['x-upsert'],undefined);
  });
}
test('different existing bytes are rejected without overwrite',async()=>{
  const storage=createPublicationStorage({projectUrl:'https://example.test',serviceKey:'fixture',fetchImpl:async (_,opts)=>
    opts.method==='POST'?new Response(JSON.stringify({error:'Duplicate'}),{status:409}):new Response('different')});
  await assert.rejects(storage.uploadOnce('b','k',Buffer.from('expected'),{contentType:'application/json'}),/integrity/);
});
for(const status of [400,401,403,404,500]){
  test(`unrelated upload failure ${status} is not success`,async()=>{
    let calls=0;
    const storage=createPublicationStorage({projectUrl:'https://example.test',serviceKey:'fixture',fetchImpl:async()=>{
      calls++; return new Response(JSON.stringify({error:'OtherError'}),{status});
    }});
    await assert.rejects(storage.uploadOnce('b','k',Buffer.from('x'),{contentType:'application/json'}),/upload failed/);
    assert.equal(calls,1);
  });
}
test('failed readback after duplicate is not success',async()=>{
  const storage=createPublicationStorage({projectUrl:'https://example.test',serviceKey:'fixture',fetchImpl:async(_,opts)=>
    opts.method==='POST'?new Response(JSON.stringify({error:'Duplicate'}),{status:409}):new Response('',{status:404})});
  await assert.rejects(storage.uploadOnce('b','k',Buffer.from('x'),{contentType:'application/json'}),/readback failed/);
});
