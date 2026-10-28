import test from 'node:test';
import assert from 'node:assert/strict';
import { createItineraryGateway, sanitizeContext, validateProposal, sanitizeAssistantRequest, validateAssistantResult, MODEL } from '../supabase/functions/itinerary-proposal/gateway.mjs';

const owner='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', requestId='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', worker='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const context=()=>({destinationId:'hue',originRegion:'unknown',numDays:2,numPeople:2,budgetVnd:500000,interests:['văn hóa']});
const payload=()=>({contract:'travelgo.itinerary.v1',intent:'generate',requestId,consent:true,context:context()});
const activity=(day=1)=>({day,title:'Tham quan văn hóa',startMinute:540,endMinute:600,costVnd:100000,category:'attractions'});
const generated=()=>({summary:'Lịch tham khảo',activities:[activity(1),activity(2)],warnings:[]});
const json=(value,status=200)=>new Response(JSON.stringify(value),{status});
const request=(value=payload())=>new Request('https://fixture.supabase.co/functions/v1/itinerary-proposal',{method:'POST',headers:{authorization:'Bearer fixture-access'},body:JSON.stringify(value)});

test('generation provider HTTP failures emit only safe boundary diagnostics',async()=>{
 for(const status of [400,401,403,429,503]){
  const events=[];const f=fixture({providerStatus:status,config:{diagnostic:event=>events.push(event)}});
  assert.equal((await f.handler(request())).status,502);
  assert.deepEqual(events,[{event:'itinerary_generation_failed',requestId,stage:'provider_http',httpStatus:status,finishReason:null}]);
  assert.equal(f.calls.find(c=>c.url.endsWith('/finalize_ai_request_v1')).body.p_success,false);
  assert.equal(/fixture-access|fixture-gemini|PRIVATE|văn hóa/.test(JSON.stringify(events)),false);
 }
});
test('generation diagnostics distinguish transport, envelope and proposal validation failures',async()=>{
 for(const [options,stage,httpStatus,finishReason] of [
  [{providerThrows:true},'provider_transport',null,null],
  [{finishReason:'MAX_TOKENS'},'provider_envelope',200,'MAX_TOKENS'],
  [{output:{summary:'not itinerary'}},'proposal_validation',200,'STOP'],
 ]){
  const events=[];const f=fixture({...options,config:{diagnostic:event=>events.push(event)}});
  assert.equal((await f.handler(request())).status,502);
  assert.deepEqual(events,[{event:'itinerary_generation_failed',requestId,stage,httpStatus,finishReason}]);
  assert.equal(JSON.stringify(events).includes('private provider details'),false);
 }
});
test('unknown finish reasons cannot put provider-controlled text into diagnostics',async()=>{
 const events=[];const f=fixture({finishReason:'PRIVATE fixture-gemini',config:{diagnostic:event=>events.push(event)}});
 assert.equal((await f.handler(request())).status,502);
 assert.equal(events.length,1);assert.equal(events[0].finishReason,'OTHER');
 assert.equal(/PRIVATE|fixture-gemini/.test(JSON.stringify(events)),false);
});
test('diagnostic sink failure cannot skip failure finalization or leak details to client',async()=>{
 const f=fixture({providerStatus:429,config:{diagnostic:()=>{throw Error('PRIVATE');}}});
 const response=await f.handler(request());assert.equal(response.status,502);
 assert.equal((await response.text()).includes('PRIVATE'),false);
 assert.equal(f.calls.filter(c=>c.url.endsWith('/finalize_ai_request_v1')).length,1);
});
test('provider diagnostics retain standard error codes but never raw provider messages',async()=>{
 for(const [error,expected] of [
  [{status:'INVALID_ARGUMENT',message:'API key not valid. PRIVATE fixture-gemini',details:[{'@type':'type.googleapis.com/google.rpc.ErrorInfo',reason:'API_KEY_INVALID'}]}, {status:'INVALID_ARGUMENT',reason:'API_KEY_INVALID'}],
  [{status:'INVALID_ARGUMENT',message:'PRIVATE',details:[{'@type':'type.googleapis.com/google.rpc.BadRequest',fieldViolations:[{field:'generation_config.response_json_schema',description:'PRIVATE'}]}]}, {status:'INVALID_ARGUMENT',field:'generation_config.response_json_schema'}],
  [{status:'PRIVATE',message:'PRIVATE',details:[{reason:'PRIVATE'}]},undefined],
 ]){
  const events=[];const f=fixture({providerStatus:400,providerError:error,config:{diagnostic:event=>events.push(event)}});
  assert.equal((await f.handler(request())).status,502);
  assert.deepEqual(events[0].providerError,expected);
  assert.equal(/PRIVATE|fixture-gemini/.test(JSON.stringify(events)),false);
 }
});
test('unstructured Google errors become finite safe reason codes without raw text',async()=>{
 for(const [message,reason,field] of [
  ['Invalid JSON payload received. Unknown name "responseJsonSchema" at generation_config. PRIVATE','UNKNOWN_REQUEST_FIELD','responseJsonSchema'],
  ['Invalid JSON payload received. Unknown name "additionalProperties". PRIVATE','UNKNOWN_REQUEST_FIELD','additionalProperties'],
  ['API key not valid. PRIVATE fixture-gemini','API_KEY_INVALID',undefined],
  ['Gemini API free tier is not available in your country. Enable billing. PRIVATE','FREE_TIER_UNAVAILABLE',undefined],
  ['PRIVATE arbitrary provider message','OTHER_INVALID_ARGUMENT',undefined],
 ]){
  const events=[];const f=fixture({providerStatus:400,providerError:{status:'INVALID_ARGUMENT',message},config:{diagnostic:event=>events.push(event)}});
  assert.equal((await f.handler(request())).status,502);
  assert.equal(events[0].providerError.reason,reason);assert.equal(events[0].providerError.field,field);
  assert.equal(/PRIVATE|fixture-gemini|arbitrary provider/.test(JSON.stringify(events)),false);
 }
});
function fixture(options={}) {
 const calls=[]; let state='new',stored=null;
 const envelope=(dispatch=false)=>({status:state,requestId,acceptedDay:'2026-10-19',workerToken:state==='reserved'?worker:null,expiresAt:'2026-10-19T12:00:00Z',remaining:state==='failed'?3:2,result:stored,...(dispatch?{dispatch:true}:{})});
 const handler=createItineraryGateway({projectUrl:'https://fixture.supabase.co',publicKey:'fixture-public',serviceKey:'fixture-service',geminiKey:'fixture-gemini',enabled:true,realContextAllowed:true,allowedSubjects:[owner],...options.config},async(url,init)=>{
  const body=init.body?JSON.parse(init.body):null; calls.push({url,body,headers:init.headers});
  if(url.endsWith('/auth/v1/user')) return json({id:owner,aud:'authenticated',is_anonymous:options.anonymous!==false,email:'PRIVATE',user_metadata:{PRIVATE:true}},options.authStatus??200);
  if(url.endsWith('/reserve_ai_request_v1')) {if(options.reserve)return json(options.reserve); if(state==='new'){state='reserved';return json(envelope(true));} return json(envelope());}
  if(url.includes('generativelanguage.googleapis.com')) {if(options.providerWait)await options.providerWait;if(options.providerThrows)throw Error('private provider details');if(options.providerStatus)return json(options.providerError?{error:options.providerError}:{},options.providerStatus);return json({candidates:[{finishReason:options.finishReason??'STOP',content:{parts:options.parts??[{text:JSON.stringify(options.output??generated())}]}}]});}
  if(url.endsWith('/finalize_ai_request_v1')) {if(options.expireFinalize){state='expired';stored=null;return json(envelope());}stored=body.p_result;state=body.p_success?'succeeded':'failed';if(options.dropFinalize)throw Error('lost acknowledgement');return json(envelope());}
  throw Error('unexpected fixture path');
 });
 return {handler,calls};
}
test('new endpoint defaults deny; old readiness policy is not used as permission',async()=>{
 for(const config of [{enabled:false},{realContextAllowed:false},{allowedSubjects:[]},{model:'alternate'},{projectUrl:'http://fixture.supabase.co'}]){const f=fixture({config});assert.equal((await f.handler(request())).status,503);assert.equal(f.calls.length,0);}
});
test('consent and exact minimal context required before quota/provider',async()=>{
 for(const value of [{...payload(),consent:false},{...payload(),title:'PRIVATE'},{...payload(),context:{...context(),notes:'PRIVATE'}},{...payload(),context:{...context(),interests:['private@example.com']}}]){const f=fixture();assert.equal((await f.handler(request(value))).status,400);assert.equal(f.calls.some(c=>c.url.includes('/reserve_')),false);}
 assert.equal(sanitizeContext(payload()).context.numDays,2);
});
test('strict proposal validates destination, day, time, money and unknown fields',()=>{
 const p=validateProposal(generated(),context());assert.equal(p.verification,'unverified');assert.equal(p.model,MODEL);assert.equal(p.contract,'travelgo.itinerary.v1');
 for(const a of [{...activity(),day:3},{...activity(),endMinute:500},{...activity(),costVnd:-1},{...activity(),actualExpenses:[]},{...activity(),startMinute:null}])assert.throws(()=>validateProposal({...generated(),activities:[a]},context()));
 assert.throws(()=>validateProposal({...generated(),activities:[activity(),activity()]},context()));
});
test('real structured result uses trusted subject/shared quota and never forwards private auth data',async()=>{
 const f=fixture();const reply=await f.handler(request());assert.equal(reply.status,200);const body=await reply.json();assert.equal(body.result.activities.length,2);assert.equal(body.result.destinationId,'hue');
 const provider=f.calls.find(c=>c.url.includes('generativelanguage'));assert.equal(JSON.stringify(provider.body).includes('PRIVATE'),false);assert.equal(JSON.stringify(provider.body).includes('fixture-access'),false);
 const reserve=f.calls.find(c=>c.url.endsWith('/reserve_ai_request_v1'));assert.equal(reserve.body.p_subject,owner);assert.equal(reserve.body.p_is_guest,true);assert.match(reserve.body.p_payload_digest,/^[a-f0-9]{64}$/);
 assert.equal(f.calls.some(c=>c.url.includes('trip')),false);
});
test('same request replay and lost success acknowledgement never regenerate or refund',async()=>{
 const f=fixture({dropFinalize:true});assert.equal((await f.handler(request())).status,503);assert.equal((await f.handler(request())).status,200);
 assert.equal(f.calls.filter(c=>c.url.includes('generativelanguage')).length,1);assert.equal(f.calls.filter(c=>c.url.endsWith('/finalize_ai_request_v1')).length,1);
});
test('unusable provider output finalizes failure without a usable result',async()=>{
 const f=fixture({output:{summary:'not itinerary'}});assert.equal((await f.handler(request())).status,502);const finish=f.calls.find(c=>c.url.endsWith('/finalize_ai_request_v1'));assert.equal(finish.body.p_success,false);assert.equal(finish.body.p_result,null);
});

test('JSON mode still rejects schema and semantic violations before publishing any result',async()=>{
 for(const output of [
  {...generated(),activities:[{...activity(),day:3}]},
  {...generated(),activities:[{...activity(),endMinute:500}]},
  {...generated(),activities:[{...activity(),costVnd:-1}]},
  {...generated(),activities:[{...activity(),owner:'invented'}]},
 ]){
  const f=fixture({output});assert.equal((await f.handler(request())).status,502);
  const finish=f.calls.find(c=>c.url.endsWith('/finalize_ai_request_v1')).body;
  assert.equal(finish.p_success,false);assert.equal(finish.p_result,null);
  assert.equal(f.calls.filter(c=>c.url.includes('generativelanguage.googleapis.com')).length,1);
 }
});
test('expired/revoked bearer and quota exhaustion never call provider',async()=>{
 for(const options of [{authStatus:401},{reserve:{status:'quota_exhausted',acceptedDay:'2026-10-19',remaining:0}}]){const f=fixture(options);assert.ok([401,429].includes((await f.handler(request())).status));assert.equal(f.calls.some(c=>c.url.includes('generativelanguage')),false);}
});
test('anonymous rollout is a separate default-off gate; it never opens unlisted Accounts',async()=>{
 const config={allowedSubjects:['dddddddd-dddd-4ddd-8ddd-dddddddddddd']};
 assert.equal((await fixture({config}).handler(request())).status,403);
 assert.equal((await fixture({config:{...config,allowAnonymousGuests:true}}).handler(request())).status,200);
 assert.equal((await fixture({config:{...config,allowAnonymousGuests:true},anonymous:false}).handler(request())).status,403);
});
test('functional entry is disabled with no deployment flags',async()=>{
 const previous=globalThis.Deno;let installed;
 globalThis.Deno={env:{get:()=>undefined},serve:handle=>{installed=handle;}};
 try{await import('../supabase/functions/itinerary-proposal/index.ts');assert.equal((await installed(request())).status,503);}finally{globalThis.Deno=previous;}
});

test('in-flight duplicate is pending and never dispatches another provider call',async()=>{
 let release;const wait=new Promise(resolve=>{release=resolve;});const f=fixture({providerWait:wait});
 const first=f.handler(request());
 for(let i=0;i<100&&!f.calls.some(c=>c.url.includes('generativelanguage'));i++)await new Promise(resolve=>setImmediate(resolve));
 try{assert.equal((await f.handler(request())).status,202);assert.equal(f.calls.filter(c=>c.url.includes('generativelanguage')).length,1);}finally{release();}
 assert.equal((await first).status,200);
});
test('provider errors, truncation and tool calls release only the failed reservation',async()=>{
 for(const options of [{providerStatus:429},{providerThrows:true},{finishReason:'MAX_TOKENS'},{parts:[{functionCall:{name:'deleteTrip'}}]}]){
  const f=fixture(options);assert.equal((await f.handler(request())).status,502);
  const finish=f.calls.find(c=>c.url.endsWith('/finalize_ai_request_v1'));assert.equal(finish.body.p_success,false);assert.equal(finish.body.p_result,null);
 }
});
test('oversized input, wrong receipt binding and expired worker fail closed',async()=>{
 const huge=fixture();assert.equal((await huge.handler(request({...payload(),extra:'x'.repeat(9000)}))).status,400);assert.equal(huge.calls.some(c=>c.url.includes('/reserve_')),false);
 const wrong=fixture({reserve:{status:'reserved',requestId:owner,acceptedDay:'2026-10-19',workerToken:worker,expiresAt:'2026-10-19T12:00:00Z',remaining:2,result:null,dispatch:true}});
 assert.equal((await wrong.handler(request())).status,503);assert.equal(wrong.calls.some(c=>c.url.includes('generativelanguage')),false);
 const expired=fixture({expireFinalize:true});const r=await expired.handler(request());assert.equal(r.status,410);assert.equal((await r.json()).result,null);
});
test('partial long-trip proposal and overbudget estimates are explicit warnings, never verified',()=>{
 const p=validateProposal(generated(),{...context(),numDays:366,budgetVnd:0});
 assert.equal(p.numDays,366);assert.ok(p.warnings.some(w=>w.includes('364')));assert.ok(p.warnings.some(w=>w.includes('vượt ngân sách')));assert.equal(p.verification,'unverified');
});
function assistantPayload(intent='advice'){
 return {contract:'travelgo.assistant.v1',intent,requestId,consent:true,prompt:'Gợi ý giúp tôi cho ngày đang chọn',history:[],context:{...context(),selectedDay:1,date:'2026-10-20',priority:'balanced',activities:[{id:'dddddddd-dddd-4ddd-8ddd-dddddddddddd',title:'Tham quan',placeId:'hue/citadel',startMinute:540,endMinute:600}],places:[{id:'hue/citadel',name:'Kinh thành Huế',sourceId:'hue-official'}],constraints:{openingWindows:[],routes:[]},weather:'unknown'}};
}
test('generation and assistant use JSON mode with the complete schema in instructions',async()=>{
 for(const value of [payload(),...['advice','recommendations','modify'].map(assistantPayload)]){
  const output=value.intent==='generate'?generated():{
   ...assistantOutput(),
   recommendations:value.intent==='recommendations'?[{title:'Tham quan Kinh thành',reason:'Phù hợp sở thích văn hóa',placeId:'hue/citadel'}]:[],
   operations:value.intent==='modify'?[{kind:'remove',itemId:value.context.activities[0].id}]:[],
  };
  const f=fixture({output});
  assert.equal((await f.handler(request(value))).status,200);
  const provider=f.calls.find(c=>c.url.includes('generativelanguage'));
  assert.equal(provider.url,`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`);
  const config=provider.body.generationConfig;
  assert.equal(config.responseMimeType,'application/json');
  const schema=JSON.parse(provider.body.systemInstruction.parts.find(p=>p.text.startsWith('OUTPUT_SCHEMA:')).text.slice('OUTPUT_SCHEMA:'.length));
  assert.equal(schema.type,'object');
  assert.equal(schema.additionalProperties,false);
  for(const removed of ['responseFormat','responseSchema','responseJsonSchema','temperature','topP','topK','candidateCount'])assert.equal(Object.hasOwn(config,removed),false);
  assert.equal(config.maxOutputTokens,8192);
  assert.equal(provider.body.contents.at(-1).role,'user');
  if(value.intent==='generate'){
   assert.deepEqual(schema.required,['summary','activities','warnings']);
   assert.equal(schema.properties.activities.items.properties.day.maximum,value.context.numDays);
   assert.deepEqual(schema.properties.activities.items.properties.costVnd.type,['integer','null']);
  }else{
   assert.deepEqual(schema.required,['summary','recommendations','operations','warnings']);
   assert.equal(schema.properties.operations.items.anyOf.length,3);
  }
 }
});
const assistantOutput=()=>({summary:'Tư vấn tham khảo theo lịch ngày đang chọn',recommendations:[],operations:[],warnings:[]});
test('assistant accepts only minimal scoped consent context; private fields/contacts rejected',()=>{
 assert.equal(sanitizeAssistantRequest(assistantPayload()).context.selectedDay,1);
 for(const bad of [{...assistantPayload(),consent:false},{...assistantPayload(),prompt:'gọi tôi 0901234567'},{...assistantPayload(),context:{...assistantPayload().context,actualExpenses:[]}}])assert.throws(()=>sanitizeAssistantRequest(bad));
});
test('assistant priorities match all manual codec values and reject invented priorities',()=>{
 for(const priority of ['cheapest','fastest','balanced','comfortable'])assert.equal(sanitizeAssistantRequest({...assistantPayload(),context:{...assistantPayload().context,priority}}).context.priority,priority);
 for(const priority of ['economy','budget'])assert.throws(()=>sanitizeAssistantRequest({...assistantPayload(),context:{...assistantPayload().context,priority}}));
});
test('recommendations carry a valid catalogue reference and reason but never operations',async()=>{
 const output={...assistantOutput(),recommendations:[{title:'Tham quan Kinh thành',reason:'Phù hợp sở thích văn hóa; cần kiểm tra giờ mở cửa.',placeId:'hue/citadel'}]};
 const f=fixture({output});const r=await f.handler(request(assistantPayload('recommendations')));assert.equal(r.status,200);const body=await r.json();assert.equal(body.result.recommendations[0].placeId,'hue/citadel');assert.deepEqual(body.result.operations,[]);assert.equal(body.result.verification,'unverified');
});
test('assistant allows normal multiline chat/history/answers while rejecting other controls',()=>{
 const p={...assistantPayload(),prompt:'Ngày này\nnên chuẩn bị gì?',history:[{role:'user',text:'Câu hỏi\ntrước đó'},{role:'model',text:'Phần một\nPhần hai'}]};
 const clean=sanitizeAssistantRequest(p);assert.equal(clean.prompt,p.prompt);
 assert.equal(validateAssistantResult({...assistantOutput(),summary:'Mục một\nMục hai'},clean).summary,'Mục một\nMục hai');
 assert.throws(()=>sanitizeAssistantRequest({...p,prompt:'Nội dung\u0001không hợp lệ'}));
});
test('advice/recommendations cannot smuggle mutations or unsupported source places',()=>{
 const clean=sanitizeAssistantRequest(assistantPayload());
 assert.equal(validateAssistantResult(assistantOutput(),clean).verification,'unverified');
 assert.throws(()=>validateAssistantResult({...assistantOutput(),operations:[{kind:'remove',itemId:clean.context.activities[0].id}]},clean));
 const recommendations=sanitizeAssistantRequest(assistantPayload('recommendations'));
 assert.throws(()=>validateAssistantResult({...assistantOutput(),recommendations:[{title:'Gợi ý',reason:'Lý do',placeId:'arbitrary/place'}]},recommendations));
});
test('modify only addresses submitted day items; known closed hours and travel gaps block usable output',()=>{
 const p=assistantPayload('modify');p.context.constraints.openingWindows=[{placeId:'hue/citadel',startMinute:480,endMinute:660,sourceRef:'fixture-hours'}];
 const clean=sanitizeAssistantRequest(p),id=clean.context.activities[0].id;
 const op={kind:'edit',itemId:id,title:'Tham quan',placeId:'hue/citadel',startMinute:550,endMinute:620};
 assert.equal(validateAssistantResult({...assistantOutput(),operations:[op]},clean).operations.length,1);
 assert.throws(()=>validateAssistantResult({...assistantOutput(),operations:[{...op,endMinute:700}]},clean));
 assert.throws(()=>validateAssistantResult({...assistantOutput(),operations:[{kind:'remove',itemId:owner}]},clean));
 const travel=assistantPayload('modify');travel.context.places.push({id:'hue/other',name:'Điểm khác',sourceId:'hue-official'});travel.context.constraints.routes=[{fromPlaceId:'hue/citadel',toPlaceId:'hue/other',minMinutes:30,sourceRef:'fixture-route'}];
 const add={kind:'add',title:'Điểm khác',placeId:'hue/other',startMinute:610,endMinute:650,costVnd:null,category:'other'};
 assert.throws(()=>validateAssistantResult({...assistantOutput(),operations:[add]},sanitizeAssistantRequest(travel)));
});
test('assistant endpoint shares trusted quota, keeps prompt in provider only and binds changed question digest',async()=>{
 const f=fixture({output:assistantOutput()});const first=await f.handler(request(assistantPayload()));assert.equal(first.status,200);assert.equal((await first.json()).result.intent,'advice');
 const reserve=f.calls.find(c=>c.url.endsWith('/reserve_ai_request_v1'));assert.equal(JSON.stringify(reserve.body).includes('Gợi ý'),false);
 const other=fixture({output:assistantOutput()}),changed={...assistantPayload(),prompt:'Tôi nên chọn hoạt động nào?'};assert.equal((await other.handler(request(changed))).status,200);
 assert.notEqual(other.calls.find(c=>c.url.endsWith('/reserve_ai_request_v1')).body.p_payload_digest,reserve.body.p_payload_digest);
});
test('assistant rejects aggregate money overflow and receipts exceeding the shared quota contract',async()=>{
 const clean=sanitizeAssistantRequest(assistantPayload('modify'));
 const add={kind:'add',title:'Hoạt động',placeId:null,startMinute:null,endMinute:null,costVnd:9007199254740991,category:'other'};
 assert.throws(()=>validateAssistantResult({...assistantOutput(),operations:[add,add]},clean));
 const f=fixture({reserve:{status:'reserved',requestId,acceptedDay:'2026-10-19',workerToken:worker,expiresAt:'2026-10-19T12:00:00Z',remaining:501,result:null,dispatch:true}});
 assert.equal((await f.handler(request())).status,503);assert.equal(f.calls.some(c=>c.url.includes('generativelanguage')),false);
});
test('sanitizeContext accepts dynamic slug destination IDs beyond the initial 12 seed',async()=>{
 const dynamicPayload={...payload(),context:{...context(),destinationId:'quy-nhon'}};
 const clean=sanitizeContext(dynamicPayload);
 assert.equal(clean.context.destinationId,'quy-nhon');
 const invalidPayload={...payload(),context:{...context(),destinationId:'INVALID UPPERCASE'}};
 assert.throws(()=>sanitizeContext(invalidPayload));
});
test('gateway sanitizes public destinationName and passes it to provider as data',async()=>{
 const dynamicWithPublicName={...payload(),context:{...context(),destinationId:'dest-quy-nhon-123',destinationName:'Quy Nhơn'}};
 const clean=sanitizeContext(dynamicWithPublicName);
 assert.equal(clean.context.destinationId,'dest-quy-nhon-123');
 assert.equal(clean.context.destinationName,'Quy Nhơn');

 // Rejects phone, email, URL in destinationName
 assert.throws(()=>sanitizeContext({...payload(),context:{...context(),destinationName:'0901234567'}}));
 assert.throws(()=>sanitizeContext({...payload(),context:{...context(),destinationName:'test@example.com'}}));
 assert.throws(()=>sanitizeContext({...payload(),context:{...context(),destinationName:'https://evil.com'}}));
 assert.throws(()=>sanitizeContext({...payload(),context:{...context(),destinationName:'   '}}));

 // Rejects unknown keys
 assert.throws(()=>sanitizeContext({...payload(),context:{...context(),unknownKey:'value'}}));

 // Verified provider body includes destinationName in context as data
 const f=fixture({output:generated()});
 const reply=await f.handler(request(dynamicWithPublicName));
 assert.equal(reply.status,200);
 const providerCall=f.calls.find(c=>c.url.includes('generativelanguage'));
 assert.ok(providerCall);
 const userContent=JSON.parse(providerCall.body.contents[0].parts[0].text);
 assert.equal(userContent.context.destinationName,'Quy Nhơn');
 assert.equal(userContent.context.destinationId,'dest-quy-nhon-123');
});
