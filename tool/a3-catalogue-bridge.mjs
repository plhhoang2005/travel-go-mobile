// Disposable local SQL integration only. No real auth or provider network calls.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createItineraryGateway} from '../supabase/functions/itinerary-proposal/gateway.mjs';
import {catalogueFixture,owner,requestId} from '../test/fixtures/catalogue_evidence_fixture.mjs';
const [dir,psql,port]=process.argv.slice(2);
assert.ok(path.isAbsolute(dir)&&path.isAbsolute(psql)&&/^\d+$/.test(port));
const args=['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-q','-A','-t'];
function sql(query){return execFileSync(psql,[...args,'-c',query],{encoding:'utf8',timeout:15000,windowsHide:true,maxBuffer:1024*1024}).trim();}
function literal(v){
  if(v===null)return 'NULL';if(typeof v==='boolean')return v?'true':'false';
  const text=typeof v==='object'?JSON.stringify(v):String(v),tag='$a3_'+randomBytes(8).toString('hex')+'$';
  assert.ok(!text.includes(tag));return tag+text+tag+(typeof v==='object'?'::jsonb':'');
}
const rpcNames={lookup_ai_request_v1:['p_subject','p_is_guest','p_request_id','p_payload_digest'],
 reserve_ai_request_v1:['p_subject','p_is_guest','p_request_id','p_payload_digest'],
 finalize_ai_request_v1:['p_subject','p_request_id','p_worker_token','p_payload_digest','p_success','p_result'],
 check_gateway_account:['p_subject','p_session_id','p_is_guest']};
const session='a3000000-0000-4000-8000-000000000004';
sql(`INSERT INTO auth.users(id,aud,role,email,email_confirmed_at,is_anonymous) VALUES('${owner}','authenticated','authenticated','a3-fixture@example.invalid',now(),false) ON CONFLICT(id) DO NOTHING;
 INSERT INTO auth.sessions(id,user_id) VALUES('${session}','${owner}') ON CONFLICT(id) DO NOTHING;`);
const payload=JSON.parse(fs.readFileSync(path.join(dir,'a3-request.json'),'utf8'));
const document=JSON.parse(fs.readFileSync(path.join(dir,'a3-document.json'),'utf8'));
assert.equal(payload.requestId,requestId);
const raw=fs.readFileSync('test/fixtures/catalogue_evidence_vectors.json','utf8');
const cat=catalogueFixture();
// The Dart fixture used exact file bytes, including whitespace.
const {createHash}=await import('node:crypto');
const digest=createHash('sha256').update(raw).digest('hex');
assert.equal(payload.context.catalogueDigest,digest);
const manifest={...cat.manifest,sha256:digest,byte_length:Buffer.byteLength(raw)};
// Published catalogue is a privileged synthetic server fixture, not an AI receipt.
// It mirrors the exact Storage bytes and makes the dynamic destination valid for A2.
const candidate='a3000000-0000-4000-8000-000000000007';
sql(`INSERT INTO private_discovery_admin.release_candidates(preview_id,actor_id,session_id,request_id,source_revision,expected_active_version,candidate_version,preview_digest,expires_at,payload_text,sha256,byte_length)
 VALUES('${candidate}','${owner}','00000000-0000-0000-0000-000000000000','a3000000-0000-4000-8000-000000000008',1,0,7,repeat('f',64),now()+interval '1 hour',${literal(raw)},${literal(digest)},${Buffer.byteLength(raw)});
 INSERT INTO private_discovery_admin.releases(version,candidate_id,object_key,sha256,byte_length,source_revision)
 VALUES(7,'${candidate}','releases/v2/7.json',${literal(digest)},${Buffer.byteLength(raw)},1);
 INSERT INTO public.discovery_release_manifest(id,version,object_key,sha256,byte_length)
 VALUES('current',7,'releases/v2/7.json',${literal(digest)},${Buffer.byteLength(raw)})
 ON CONFLICT(id) DO UPDATE SET version=EXCLUDED.version,object_key=EXCLUDED.object_key,sha256=EXCLUDED.sha256,byte_length=EXCLUDED.byte_length;`);
const trace=[];let providerCalls=0,catalogueCalls=0;
const token='fixture.'+Buffer.from(JSON.stringify({session_id:session})).toString('base64url')+'.fixture';
const gateway=createItineraryGateway({projectUrl:'https://fixture.supabase.co',publicKey:'fixture-public',serviceKey:'fixture-worker',geminiKey:'fixture-gemini',
 enabled:true,realContextAllowed:true,catalogueEvidenceEnabled:true,allowedSubjects:[owner],clock:()=>new Date('2026-10-27T02:00:00Z')},async(url,init={})=>{
  if(url.endsWith('/auth/v1/user'))return Response.json({id:owner,aud:'authenticated',is_anonymous:false});
  if(url.includes('/rest/v1/rpc/')){
    const name=url.split('/').at(-1),params=JSON.parse(init.body);assert.ok(Object.hasOwn(rpcNames,name));
    assert.deepEqual(Object.keys(params).sort(),[...rpcNames[name]].sort());
    trace.push({name,args:params});
    const result=sql(`SET ROLE service_role; SELECT public.${name}(${rpcNames[name].map(k=>`${k}=>${literal(params[k])}`).join(',')})::text;`);
    return Response.json(JSON.parse(result));
  }
  if(url.includes('/discovery_release_manifest')){catalogueCalls++;return Response.json([manifest]);}
  if(url.includes('/storage/v1/object/public/')){catalogueCalls++;return new Response(raw);}
  if(url.includes('generativelanguage.googleapis.com')){
    providerCalls++;const body=JSON.parse(init.body);assert.ok(JSON.stringify(body).includes('catalogueFacts'));
    return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify({summary:'Synthetic visit',activities:[{
      day:1,title:'Museum',startMinute:null,endMinute:null,costVnd:null,category:'attractions'}],warnings:[]})}]}}]});
  }
  throw Error('Unexpected integration fixture URL');
});
const request=()=>new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal',{method:'POST',headers:{authorization:`Bearer ${token}`},body:JSON.stringify(payload)});
const response=await gateway(request());const body=await response.json();
assert.equal(response.status,200,JSON.stringify(body));assert.equal(body.status,'succeeded');
const receipt=body.result;
assert.ok(receipt.evidence.length>0);
const again=await gateway(request());assert.equal(again.status,200);assert.deepEqual((await again.json()).result,receipt);
assert.equal(providerCalls,1);assert.equal(catalogueCalls,2);
assert.equal(trace.filter(t=>t.name==='reserve_ai_request_v1').length,1);
assert.equal(trace.filter(t=>t.name==='finalize_ai_request_v1').length,1);
const envelope={contract:'travelgo.trip.evidence.v1',document,evidence:receipt.evidence,claims:receipt.claims,externalPlaces:[],externalBindings:[]};
for(const [name,value] of Object.entries({'a3-receipt.json':receipt,'a3-envelope.json':envelope,'a3-rpc-trace.json':trace})){
 fs.writeFileSync(path.join(dir,name),JSON.stringify(value));
}
console.log('A3 real SQL lookup/reserve/finalize + gateway fake provider bridge PASS');
