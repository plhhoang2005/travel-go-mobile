import test from 'node:test';
import assert from 'node:assert/strict';
import {createItineraryGateway} from '../supabase/functions/itinerary-proposal/gateway.mjs';
import {catalogueFixture,requestFixture,owner,requestId} from './fixtures/catalogue_evidence_fixture.mjs';
function fixture({assistant=false,enabled=true,offline=false,lookup,finalFailure=false,denyFinal=false}={}){
  const cat=catalogueFixture(undefined,{offline});const payload=requestFixture(cat.digest,assistant),calls=[];
  let result,accountChecks=0;
  const envelope=(status,extra={})=>({status,requestId,acceptedDay:'2026-10-27',remaining:2,expiresAt:'2026-10-27T03:00:00Z',workerToken:null,result:null,...extra});
  const handler=createItineraryGateway({projectUrl:'https://fixture.supabase.co',publicKey:'public-fixture',serviceKey:'service-fixture',geminiKey:'gemini-fixture',enabled:true,realContextAllowed:true,
    catalogueEvidenceEnabled:enabled,allowedSubjects:[owner],clock:()=>new Date('2026-10-27T02:00:00Z'),
    checkAccount:async()=>({allowed:!(denyFinal&&++accountChecks>1)})},async(url,init={})=>{
      const body=init.body?JSON.parse(init.body):null;calls.push({url,init,body});
      if(url.endsWith('/auth/v1/user'))return Response.json({id:owner,aud:'authenticated',is_anonymous:false});
      if(url.endsWith('/lookup_ai_request_v1'))return Response.json(lookup??(result?envelope('succeeded',{result}):{status:'not_found'}));
      if(url.includes('/discovery_release_manifest')||url.includes('/storage/v1/object/public/'))return cat.fetchImpl(url,init);
      if(url.endsWith('/reserve_ai_request_v1'))return Response.json(envelope('reserved',{workerToken:'11111111-1111-4111-8111-111111111111',dispatch:true}));
      if(url.includes('generativelanguage.googleapis.com'))return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(assistant?{summary:'Advice',recommendations:[],operations:[],warnings:[]}:{summary:'Visit',activities:[{day:1,title:'Museum',startMinute:null,endMinute:null,costVnd:null,category:'attractions'}],warnings:[]})}]}}]});
      if(url.endsWith('/finalize_ai_request_v1')){
        if(finalFailure)return Response.json({}, {status:503});
        result=body.p_result;return Response.json(envelope(body.p_success?'succeeded':'failed',{result}));
      }
      throw Error('unexpected fixture path');
    });
  const request=()=>new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal',{method:'POST',headers:{authorization:'Bearer fixture'},body:JSON.stringify(payload)});
  return {handler,request,payload,calls,cat};
}
for(const assistant of [false,true])test(`evidence ${assistant?'advice':'generate'} stores server registry and replays without retrieval/provider`,async()=>{
  const f=fixture({assistant});let res=await f.handler(f.request());assert.equal(res.status,200);
  const first=await res.json();assert.ok(first.result.evidence.length);assert.equal(first.result.catalogueDigest,f.cat.digest);
  const provider=f.calls.find(c=>c.url.includes('generativelanguage'));assert.ok(JSON.stringify(provider.body).includes('catalogueFacts'));
  assert.ok(JSON.stringify(provider.body).includes('estimateRemaining'));assert.ok(JSON.stringify(provider.body).includes('actualRemaining'));
  assert.equal(first.result.proposal.verification,'unverified');
  const before=f.calls.length;res=await f.handler(f.request());assert.equal(res.status,200);
  assert.deepEqual((await res.json()).result,first.result);
  assert.equal(f.calls.slice(before).filter(c=>c.url.includes('discovery_release_manifest')||c.url.includes('generativelanguage')||c.url.includes('reserve_ai_request')).length,0);
});
test('disabled evidence mode and invalid client authority never reserve/provider',async()=>{
  const off=fixture({enabled:false});assert.equal((await off.handler(off.request())).status,503);
  const forged=fixture();forged.payload.context.reviewed=true;assert.equal((await forged.handler(forged.request())).status,400);
  for(const f of [off,forged])assert.equal(f.calls.filter(c=>c.url.includes('reserve_ai_request')||c.url.includes('generativelanguage')).length,0);
});
test('unavailable or changed catalogue does not reserve and does not call provider/search',async()=>{
  const offline=fixture({offline:true});const changed=fixture();changed.payload.context.catalogueVersion='6';
  for(const f of [offline,changed]){
    const res=await f.handler(f.request());assert.ok([409,503].includes(res.status));
    assert.equal(f.calls.filter(c=>c.url.includes('reserve_ai_request')||c.url.includes('generativelanguage')).length,0);
  }
});
test('revoked account before finalize never creates successful receipt; lost finalize ACK remains pending',async()=>{
  const locked=fixture({denyFinal:true});assert.equal((await locked.handler(locked.request())).status,403);
  assert.equal(locked.calls.find(c=>c.url.includes('finalize_ai_request')).body.p_success,false);
  const lost=fixture({finalFailure:true});const res=await lost.handler(lost.request());
  assert.equal(res.status,503);assert.equal((await res.json()).status,'outcome_pending');
});
