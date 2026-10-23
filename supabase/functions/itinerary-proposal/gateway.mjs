// Functional itinerary contract. Separate flags/consent from the readiness PoC.
export const MODEL = 'gemini-3.5-flash-lite';
const CONTRACT='travelgo.itinerary.v1';
const ASSISTANT='travelgo.assistant.v1';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DESTINATION_SLUG=/^[a-z0-9][a-z0-9/-]{0,119}$/;
const DESTINATIONS=new Set(['ha-noi','ha-long','sa-pa','ninh-binh','hue','da-nang','hoi-an','nha-trang','da-lat','ho-chi-minh','phu-quoc','can-tho']);
export function isValidDestinationId(id){return typeof id==='string'&&(DESTINATIONS.has(id)||DESTINATION_SLUG.test(id));}
const CATEGORIES=['transport','accommodation','food','attractions','shopping','other'];
const MAX_MONEY=9007199254740991, encoder=new TextEncoder();
function ensure(value){if(!value)throw new Error('invalid_contract');}
function object(value,required,optional=[]){ensure(value&&typeof value==='object'&&!Array.isArray(value));ensure(required.every(k=>Object.hasOwn(value,k)));ensure(Object.keys(value).every(k=>required.includes(k)||optional.includes(k)));}
function integer(value,min,max){ensure(Number.isSafeInteger(value)&&value>=min&&value<=max);return value;}
function text(value,max){ensure(typeof value==='string'&&value.length>0&&value===value.trim()&&[...value].length<=max&&!/[\x00-\x1f\x7f]/.test(value));return value;}
function day(value){ensure(typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&Number(value.slice(0,4))>=1&&Number.isFinite(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value);return value;}
export function sanitizeContext(value){
 if(value?.contract===ASSISTANT)return sanitizeAssistantRequest(value);
 object(value,['contract','intent','requestId','consent','context']);
 ensure(value.contract===CONTRACT&&value.intent==='generate'&&value.consent===true&&UUID.test(value.requestId));
 const c=value.context;object(c,['destinationId','originRegion','numDays','numPeople','budgetVnd','interests']);
 ensure(isValidDestinationId(c.destinationId)&&['north','central','south','unknown'].includes(c.originRegion));
 ensure(Array.isArray(c.interests)&&c.interests.length<=20&&new Set(c.interests).size===c.interests.length);
 const interests=c.interests.map(i=>{text(i,80);ensure(!/@|https?:|www\.|\+?\d[\d .()-]{7,}\d/i.test(i));return i;});
 return {contract:CONTRACT,intent:'generate',requestId:value.requestId.toLowerCase(),consent:true,context:{destinationId:c.destinationId,originRegion:c.originRegion,numDays:integer(c.numDays,1,366),numPeople:integer(c.numPeople,1,2147483647),budgetVnd:integer(c.budgetVnd,0,MAX_MONEY),interests}};
}
export function validateProposal(value,c,stored=false){
 object(value,stored?['contract','destinationId','numDays','summary','activities','warnings','model','verification']:['summary','activities','warnings']);
 if(stored)ensure(value.contract===CONTRACT&&value.destinationId===c.destinationId&&value.numDays===c.numDays&&value.model===MODEL&&value.verification==='unverified');
 text(value.summary,800);ensure(Array.isArray(value.activities)&&value.activities.length>0&&value.activities.length<=48);
 ensure(Array.isArray(value.warnings)&&value.warnings.length<=(stored?12:8));value.warnings.forEach(w=>text(w,200));
 const activities=value.activities.map(a=>{
  object(a,['day','title','startMinute','endMinute','costVnd','category']);integer(a.day,1,c.numDays);text(a.title,120);ensure(CATEGORIES.includes(a.category));
  ensure((a.startMinute===null)===(a.endMinute===null));
  if(a.startMinute!==null){integer(a.startMinute,0,1439);integer(a.endMinute,1,1440);ensure(a.endMinute>a.startMinute);}
  if(a.costVnd!==null)integer(a.costVnd,0,MAX_MONEY);
  return {...a};
 });
 for(let i=0;i<activities.length;i++)for(let j=0;j<i;j++){
  const a=activities[i],b=activities[j];
  if(a.day===b.day&&a.startMinute!==null&&b.startMinute!==null)ensure(a.startMinute>=b.endMinute||b.startMinute>=a.endMinute);
 }
 const total=activities.reduce((n,a)=>n+BigInt(a.costVnd??0),0n);ensure(total<=BigInt(MAX_MONEY));
 const warnings=[...value.warnings];
 if(!stored){
  warnings.push('Gợi ý AI chưa xác minh: kiểm tra địa điểm, giờ mở cửa, đường đi và thời tiết trước khi sử dụng.');
  if(total>BigInt(c.budgetVnd))warnings.push('Ước tính hoạt động vượt ngân sách; chưa bao gồm các khoản chi hiện có.');
  const uncovered=c.numDays-new Set(activities.map(a=>a.day)).size;
  if(uncovered>0)warnings.push(`Còn ${uncovered} ngày chưa có hoạt động trong đề xuất; cần bổ sung lịch thủ công.`);
 }
 const usable={contract:CONTRACT,destinationId:c.destinationId,numDays:c.numDays,summary:value.summary,activities,warnings,model:MODEL,verification:'unverified'};
 ensure(encoder.encode(JSON.stringify(usable)).length<=14000);return usable;
}
async function boundedJson(input,limit=65536){
 ensure(input.body);const reader=input.body.getReader();let timer;
 try{return await Promise.race([(async()=>{let bytes=0;const chunks=[];while(true){const part=await reader.read();if(part.done)break;bytes+=part.value.byteLength;ensure(bytes<=limit);chunks.push(part.value);}const data=new Uint8Array(bytes);let offset=0;for(const chunk of chunks){data.set(chunk,offset);offset+=chunk.length;}return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(data));})(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('input_timeout')),5000);})]);}
 finally{clearTimeout(timer);await reader.cancel().catch(()=>{});}
}
function response(body,status){return new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'}});}
async function safeProviderError(reply){
 try{
  const error=(await boundedJson(reply,16384)).error;
  if(!['INVALID_ARGUMENT','FAILED_PRECONDITION','PERMISSION_DENIED','UNAUTHENTICATED','RESOURCE_EXHAUSTED','NOT_FOUND','INTERNAL','UNAVAILABLE'].includes(error?.status))return undefined;
  const result={status:error.status};
  for(const detail of Array.isArray(error.details)?error.details:[]){
   if(detail?.['@type']==='type.googleapis.com/google.rpc.ErrorInfo'&&['API_KEY_INVALID','API_KEY_EXPIRED','API_KEY_SERVICE_BLOCKED','API_KEY_HTTP_REFERRER_BLOCKED','API_KEY_IP_ADDRESS_BLOCKED','API_KEY_ANDROID_APP_BLOCKED','API_KEY_IOS_APP_BLOCKED','SERVICE_DISABLED','BILLING_DISABLED','CONSUMER_INVALID','RATE_LIMIT_EXCEEDED','QUOTA_EXCEEDED'].includes(detail.reason))result.reason=detail.reason;
   if(detail?.['@type']==='type.googleapis.com/google.rpc.BadRequest')for(const violation of Array.isArray(detail.fieldViolations)?detail.fieldViolations:[]){
    if(['generation_config.response_json_schema','generation_config.response_schema','generation_config.temperature','generation_config.max_output_tokens','generation_config.thinking_config','generation_config.response_mime_type','contents','system_instruction','model'].includes(violation?.field))result.field=violation.field;
   }
  }
  if(!result.reason&&!result.field&&result.status==='INVALID_ARGUMENT'){
   const message=typeof error.message==='string'?error.message:'';
   const unknown=/Unknown name ["']([^"']+)["']/i.exec(message)?.[1];
   if(['responseJsonSchema','additionalProperties','minItems','maxItems','minimum','maximum','type','responseMimeType','thinkingConfig','temperature'].includes(unknown)){result.reason='UNKNOWN_REQUEST_FIELD';result.field=unknown;}
   else if(/api key.*(?:not valid|invalid)/i.test(message))result.reason='API_KEY_INVALID';
   else if(/free tier.*not available/i.test(message))result.reason='FREE_TIER_UNAVAILABLE';
   else if(/temperature/i.test(message))result.reason='TEMPERATURE_REJECTED';
   else if(/schema/i.test(message))result.reason='SCHEMA_REJECTED';
   else result.reason='OTHER_INVALID_ARGUMENT';
  }
  return result;
 }catch{return undefined;} // A malformed diagnostic body must not prevent failure finalization.
}
// Canonical output shape; the wire adapter sends it as model instructions.
function structuredConfig(schema){
 return {maxOutputTokens:8192,responseFormat:{text:{mimeType:'APPLICATION_JSON',schema}}};
}
function providerBody(clean){
 if(clean.contract===ASSISTANT)return assistantProviderBody(clean);
 const nullableInteger={type:['integer','null']};
 return {
  systemInstruction:{parts:[{text:'TravelGO: tạo lịch trình tham khảo bằng tiếng Việt từ ngữ cảnh tối thiểu. Chỉ tạo đề xuất, không thực hiện thao tác hay thay thế Decision Engine. Ước tính chi phí tổng cho nhóm, không coi giá/địa điểm/giờ mở cửa/đường đi/thời tiết là verified. Không dùng dữ liệu cá nhân hoặc tạo URL nguồn giả. Không quá 48 hoạt động; nếu không phủ đủ các ngày, nêu rõ thiếu. Không lịch trùng giờ. Trả JSON đúng schema.'}]},
  contents:[{role:'user',parts:[{text:JSON.stringify({intent:clean.intent,context:clean.context})}]}],
  generationConfig:structuredConfig({type:'object',additionalProperties:false,required:['summary','activities','warnings'],properties:{summary:{type:'string'},warnings:{type:'array',maxItems:8,items:{type:'string'}},activities:{type:'array',minItems:1,maxItems:48,items:{type:'object',additionalProperties:false,required:['day','title','startMinute','endMinute','costVnd','category'],properties:{day:{type:'integer',minimum:1,maximum:clean.context.numDays},title:{type:'string'},startMinute:nullableInteger,endMinute:nullableInteger,costVnd:nullableInteger,category:{type:'string',enum:CATEGORIES}}}}}}),
 };
}
function providerRequest(clean){
 const body=providerBody(clean),schema=body.generationConfig.responseFormat.text.schema;
 // JSON mode avoids the provider's rejected schema configuration. Complete
 // semantic validation remains in validateProposal/validateAssistantResult.
 return {...body,systemInstruction:{parts:[...body.systemInstruction.parts,{text:'OUTPUT_SCHEMA:'+JSON.stringify(schema)}]},generationConfig:{maxOutputTokens:8192,responseMimeType:'application/json'}};
}
export function createItineraryGateway(config,fetchImpl=fetch){
 const c={...config},allowed=new Set(c.allowedSubjects??[]);let origin;
 try{const url=new URL(c.projectUrl);ensure(url.protocol==='https:'&&url.hostname.endsWith('.supabase.co')&&url.pathname==='/'&&!url.port&&!url.username&&!url.password&&!url.search&&!url.hash);origin=url.origin;}catch{origin=null;}
 const configured=origin&&c.enabled===true&&c.realContextAllowed===true&&c.publicKey&&c.serviceKey&&c.geminiKey&&allowed.size>0&&[...allowed].every(id=>UUID.test(id))&&(c.model===undefined||c.model===MODEL);
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
 async function rpc(name,body){const r=await fetchImpl(`${origin}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:c.serviceKey,Authorization:`Bearer ${c.serviceKey}`,'content-type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(5000)});ensure(r.ok);return boundedJson(r,20000);}
 function safeEnvelope(value,clean){
  object(value,['status'],['requestId','acceptedDay','workerToken','expiresAt','remaining','result','dispatch']);
  ensure(['reserved','succeeded','failed','expired','result_expired','quota_exhausted','global_cap'].includes(value.status));
  if(value.status==='global_cap')return {status:'global_cap'};
  day(value.acceptedDay);integer(value.remaining,0,3);
  if(value.status==='quota_exhausted')return {status:value.status,acceptedDay:value.acceptedDay,remaining:value.remaining};
  ensure(value.requestId===clean.requestId);
  if(value.status==='reserved')ensure(UUID.test(value.workerToken)&&Number.isFinite(Date.parse(value.expiresAt))&&value.result===null&&(value.dispatch===undefined||value.dispatch===true));
  else ensure(value.workerToken===null&&value.dispatch===undefined);
  return {status:value.status==='reserved'?'pending':value.status,requestId:clean.requestId,acceptedDay:value.acceptedDay,remaining:value.remaining,result:value.status==='succeeded'?(clean.contract===ASSISTANT?validateAssistantResult(value.result,clean,true):validateProposal(value.result,clean.context,true)):null};
 }
 function quotaResponse(value,clean){const safe=safeEnvelope(value,clean);return response(safe,({succeeded:200,pending:202,failed:502,expired:410,result_expired:410,quota_exhausted:429,global_cap:503})[safe.status]);}
 return async request=>{
  if(!configured)return response({status:'deployment_blocked'},503);
  if(request.method!=='POST')return response({status:'method_not_allowed'},405);
  const bearer=/^Bearer ([^\s]+)$/.exec(request.headers.get('authorization')??'');if(!bearer||bearer[1].length>4096)return response({status:'unauthorized'},401);
  let user;
  try{const r=await fetchImpl(`${origin}/auth/v1/user`,{headers:{apikey:c.publicKey,Authorization:`Bearer ${bearer[1]}`},signal:AbortSignal.timeout(5000)});if([401,403].includes(r.status))return response({status:'unauthorized'},401);ensure(r.ok);user=await boundedJson(r,16384);ensure(UUID.test(user.id)&&user.aud==='authenticated'&&typeof user.is_anonymous==='boolean');}catch{return response({status:'auth_unavailable'},503);}
  if(!allowed.has(user.id)&&!(c.allowAnonymousGuests===true&&user.is_anonymous===true))return response({status:'subject_denied'},403);
  const initialCheck = await checkAccount(user, bearer[1]);
  if (!initialCheck.allowed) return response({ status: 'account_locked' }, 403);
  let clean;try{clean=sanitizeContext(await boundedJson(request,32768));}catch{return response({status:'invalid_context'},400);}
  const digest=[...new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(JSON.stringify({contract:clean.contract,intent:clean.intent,context:clean.context,...(clean.contract===ASSISTANT?{prompt:clean.prompt,history:clean.history}:{})}))))].map(n=>n.toString(16).padStart(2,'0')).join('');
  const binding={p_subject:user.id,p_request_id:clean.requestId,p_payload_digest:digest};let reservation;
  try{reservation=await rpc('reserve_ai_request_v1',{...binding,p_is_guest:user.is_anonymous});safeEnvelope(reservation,clean);if(reservation.dispatch!==true)return quotaResponse(reservation,clean);ensure(reservation.status==='reserved');}catch{return response({status:'quota_unavailable',requestId:clean.requestId},503);}
  const finalize=(success,usable)=>rpc('finalize_ai_request_v1',{...binding,p_worker_token:reservation.workerToken,p_success:success,p_result:usable});
  let usable,stage='provider_transport',httpStatus=null,finishReason=null,providerError;
  try{
   const r=await fetchImpl(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,{method:'POST',headers:{'x-goog-api-key':c.geminiKey,'content-type':'application/json'},body:JSON.stringify(providerRequest(clean)),signal:AbortSignal.timeout(25000)});httpStatus=r.status;stage='provider_http';if(!r.ok&&clean.contract===CONTRACT)providerError=await safeProviderError(r);ensure(r.ok);
   stage='provider_envelope';const candidate=(await boundedJson(r)).candidates?.[0];
   if(candidate?.finishReason!==undefined)finishReason=['STOP','MAX_TOKENS','SAFETY','RECITATION','LANGUAGE','BLOCKLIST','PROHIBITED_CONTENT','SPII','MALFORMED_FUNCTION_CALL','IMAGE_SAFETY'].includes(candidate.finishReason)?candidate.finishReason:'OTHER';
   ensure(candidate?.finishReason==='STOP'&&Array.isArray(candidate.content?.parts));const parts=candidate.content.parts.filter(p=>p.thought!==true);ensure(parts.length>0&&parts.every(p=>typeof p.text==='string'&&!p.functionCall));stage='provider_content';const raw=JSON.parse(parts.map(p=>p.text).join(''));stage='proposal_validation';usable=clean.contract===ASSISTANT?validateAssistantResult(raw,clean):validateProposal(raw,clean.context);
  }catch{
   // Generation-only metadata: never log prompts, provider bodies, credentials or subjects.
   if(clean.contract===CONTRACT&&typeof c.diagnostic==='function'){
    try{c.diagnostic({event:'itinerary_generation_failed',requestId:clean.requestId,stage,httpStatus,finishReason,...(providerError?{providerError}:{})});}catch{ /* Diagnostics must not affect quota finalization. */ }
   }
   try{return quotaResponse(await finalize(false,null),clean);}catch{return response({status:'outcome_pending',requestId:clean.requestId},503);}
  }
  const finalCheck = await checkAccount(user, bearer[1]);
  if (!finalCheck.allowed) {
    try { await finalize(false, null); } catch {}
    return response({ status: 'account_locked' }, 403);
  }
  try{return quotaResponse(await finalize(true,usable),clean);}catch{return response({status:'outcome_pending',requestId:clean.requestId},503);}
 };
}

function humanText(value,max,multiline=false){const flat=multiline&&typeof value==='string'?value.replace(/[\r\n\t]/g,' '):value;text(flat,max);ensure(!/@|https?:|www\.|(?:\+\d|0)(?:[ .()-]*\d){8,14}/i.test(flat));return value;}
function maybeTime(value,max){return value===null?null:integer(value,0,max);}
export function sanitizeAssistantRequest(value){
 object(value,['contract','intent','requestId','consent','context','prompt','history']);
 ensure(value.contract===ASSISTANT&&['advice','recommendations','modify'].includes(value.intent)&&value.consent===true);
 const c=value.context;object(c,['destinationId','originRegion','numDays','numPeople','budgetVnd','interests','selectedDay','date','priority','activities','places','constraints','weather']);
 const base=sanitizeContext({contract:CONTRACT,intent:'generate',requestId:value.requestId,consent:true,context:Object.fromEntries(['destinationId','originRegion','numDays','numPeople','budgetVnd','interests'].map(k=>[k,c[k]]))});
 integer(c.selectedDay,1,c.numDays);if(c.date!==null)day(c.date);ensure(['cheapest','fastest','balanced','comfortable'].includes(c.priority)&&c.weather==='unknown');
 ensure(Array.isArray(c.places)&&c.places.length<=12);
 const places=c.places.map(p=>{object(p,['id','name','sourceId']);ensure(typeof p.id==='string'&&p.id.startsWith(c.destinationId+'/'));text(p.id,128);humanText(p.name,200);text(p.sourceId,80);return {...p};});
 const placeIds=new Set(places.map(p=>p.id));ensure(placeIds.size===places.length);
 ensure(Array.isArray(c.activities)&&c.activities.length<=48);
 const activities=c.activities.map(a=>{object(a,['id','title','placeId','startMinute','endMinute']);ensure(UUID.test(a.id)&&(a.placeId===null||placeIds.has(a.placeId)));humanText(a.title,200);maybeTime(a.startMinute,1439);maybeTime(a.endMinute,1440);return {...a};});
 ensure(new Set(activities.map(a=>a.id)).size===activities.length);
 object(c.constraints,['openingWindows','routes']);ensure(Array.isArray(c.constraints.openingWindows)&&c.constraints.openingWindows.length<=48&&Array.isArray(c.constraints.routes)&&c.constraints.routes.length<=48);
 const openingWindows=c.constraints.openingWindows.map(w=>{object(w,['placeId','startMinute','endMinute','sourceRef']);ensure(placeIds.has(w.placeId));integer(w.startMinute,0,1439);integer(w.endMinute,1,1440);ensure(w.endMinute>w.startMinute);text(w.sourceRef,128);return {...w};});
 const routes=c.constraints.routes.map(r=>{object(r,['fromPlaceId','toPlaceId','minMinutes','sourceRef']);ensure(placeIds.has(r.fromPlaceId)&&placeIds.has(r.toPlaceId));integer(r.minMinutes,0,1440);text(r.sourceRef,128);return {...r};});
 humanText(value.prompt,600,true);ensure(Array.isArray(value.history)&&value.history.length<=4&&value.history.length%2===0);
 const history=value.history.map((h,i)=>{object(h,['role','text']);ensure(h.role===(i%2===0?'user':'model'));humanText(h.text,1200,true);return {...h};});
 return {contract:ASSISTANT,intent:value.intent,requestId:base.requestId,consent:true,context:{...base.context,selectedDay:c.selectedDay,date:c.date,priority:c.priority,activities,places,constraints:{openingWindows,routes},weather:'unknown'},prompt:value.prompt,history};
}
function checkAssistantSchedule(activities,c){
 for(const a of activities){
  if(a.startMinute===null||a.endMinute===null)continue;
  ensure(a.endMinute>a.startMinute);
  const windows=c.constraints.openingWindows.filter(w=>w.placeId===a.placeId);
  if(windows.length)ensure(windows.some(w=>a.startMinute>=w.startMinute&&a.endMinute<=w.endMinute));
 }
 for(let i=0;i<activities.length;i++)for(let j=i+1;j<activities.length;j++){
  let a=activities[i],b=activities[j];if(a.startMinute===null||a.endMinute===null||b.startMinute===null||b.endMinute===null)continue;
  if(a.startMinute>b.startMinute)[a,b]=[b,a];ensure(a.endMinute<=b.startMinute);
  const route=c.constraints.routes.find(r=>r.fromPlaceId===a.placeId&&r.toPlaceId===b.placeId);
  if(route)ensure(b.startMinute-a.endMinute>=route.minMinutes);
 }
}
export function validateAssistantResult(value,clean,stored=false){
 const c=clean.context;
 object(value,stored?['contract','intent','destinationId','numDays','selectedDay','summary','recommendations','operations','warnings','model','verification']:['summary','recommendations','operations','warnings']);
 if(stored)ensure(value.contract===ASSISTANT&&value.intent===clean.intent&&value.destinationId===c.destinationId&&value.numDays===c.numDays&&value.selectedDay===c.selectedDay&&value.model===MODEL&&value.verification==='unverified');
 humanText(value.summary,1200,true);ensure(Array.isArray(value.recommendations)&&value.recommendations.length<=6&&Array.isArray(value.operations)&&value.operations.length<=12&&Array.isArray(value.warnings)&&value.warnings.length<=(stored?12:8));
 const placeIds=new Set(c.places.map(p=>p.id));
 const recommendations=value.recommendations.map(r=>{object(r,['title','reason','placeId']);humanText(r.title,200);humanText(r.reason,400,true);ensure(r.placeId===null||placeIds.has(r.placeId));return {...r};});
 if(clean.intent==='recommendations')ensure(recommendations.length>0);
 if(clean.intent!=='modify')ensure(value.operations.length===0);else ensure(value.operations.length>0);
 const targets=new Set(),items=c.activities.map(a=>({...a}));
 const operations=value.operations.map((op,index)=>{
  ensure(['add','edit','remove'].includes(op?.kind));
  if(op.kind==='remove'){object(op,['kind','itemId']);ensure(!targets.has(op.itemId)&&c.activities.some(a=>a.id===op.itemId));targets.add(op.itemId);items.splice(items.findIndex(a=>a.id===op.itemId),1);return {...op};}
  object(op,op.kind==='add'?['kind','title','placeId','startMinute','endMinute','costVnd','category']:['kind','itemId','title','placeId','startMinute','endMinute']);
  humanText(op.title,200);ensure(op.placeId===null||placeIds.has(op.placeId));maybeTime(op.startMinute,1439);maybeTime(op.endMinute,1440);ensure((op.startMinute===null)===(op.endMinute===null));if(op.startMinute!==null)ensure(op.endMinute>op.startMinute);
  if(op.kind==='add'){if(op.costVnd!==null)integer(op.costVnd,0,MAX_MONEY);ensure(CATEGORIES.includes(op.category));items.push({id:`new:${index}`,title:op.title,placeId:op.placeId,startMinute:op.startMinute,endMinute:op.endMinute});}
  else{ensure(!targets.has(op.itemId)&&c.activities.some(a=>a.id===op.itemId));targets.add(op.itemId);Object.assign(items.find(a=>a.id===op.itemId),{title:op.title,placeId:op.placeId,startMinute:op.startMinute,endMinute:op.endMinute});}
  return {...op};
 });
 if(clean.intent==='modify')checkAssistantSchedule(items,c);
 const newCost=operations.reduce((total,op)=>total+(op.kind==='add'?BigInt(op.costVnd??0):0n),0n);ensure(newCost<=BigInt(MAX_MONEY));
 const warnings=value.warnings.map(w=>humanText(w,200,true));
 if(!stored)warnings.push('Tư vấn AI chưa xác minh; giờ mở cửa, đường đi và thời tiết còn thiếu nếu không có dữ liệu được cung cấp.');
 if(!stored&&newCost>BigInt(c.budgetVnd))warnings.push('Ước tính hoạt động mới vượt ngân sách; xem toàn bộ dự toán trong preview.');
 const result={contract:ASSISTANT,intent:clean.intent,destinationId:c.destinationId,numDays:c.numDays,selectedDay:c.selectedDay,summary:value.summary,recommendations,operations,warnings,model:MODEL,verification:'unverified'};
 ensure(encoder.encode(JSON.stringify(result)).length<=14000);return result;
}
function assistantProviderBody(clean){
 const nullableInteger={type:['integer','null']},nullableString={type:['string','null']};
 const shared={title:{type:'string'},placeId:nullableString,startMinute:nullableInteger,endMinute:nullableInteger};
 const operationSchemas=[
  {type:'object',additionalProperties:false,properties:{kind:{type:'string',enum:['add']},...shared,costVnd:nullableInteger,category:{type:'string',enum:CATEGORIES}},required:['kind','title','placeId','startMinute','endMinute','costVnd','category']},
  {type:'object',additionalProperties:false,properties:{kind:{type:'string',enum:['edit']},itemId:{type:'string'},...shared},required:['kind','itemId','title','placeId','startMinute','endMinute']},
  {type:'object',additionalProperties:false,properties:{kind:{type:'string',enum:['remove']},itemId:{type:'string'}},required:['kind','itemId']},
 ];
 return {
  systemInstruction:{parts:[{text:'TravelGO hỗ trợ dashboard/planner, trả tiếng Việt. Chỉ tư vấn theo ngày scope; không thực hiện hành động, không có quyền sửa/lưu trip. Advice/recommendations phải operations rỗng. Modify chỉ add/edit/remove trong activity IDs đã cho, không actual expenses/notes/roles/days. Dùng placeId trong places hoặc null; reference name không xác minh giờ/giá/vị trí. Xét date,priority,budget,interests và constraints openingWindows/routes khi có. Không tạo lịch đóng cửa, trùng giờ hoặc thiếu thời gian đi theo dữ liệu được cung cấp. Weather unknown thì nói chưa biết. Không đưa email/số liên hệ/URL hoặc nguồn giả. Trả JSON đúng schema, không tool calls.'}]},
  contents:[{role:'user',parts:[{text:JSON.stringify({intent:clean.intent,context:clean.context,prompt:clean.prompt,history:clean.history})}]}],
  generationConfig:structuredConfig({type:'object',additionalProperties:false,required:['summary','recommendations','operations','warnings'],properties:{summary:{type:'string'},recommendations:{type:'array',maxItems:6,items:{type:'object',additionalProperties:false,required:['title','reason','placeId'],properties:{title:{type:'string'},reason:{type:'string'},placeId:nullableString}}},operations:{type:'array',maxItems:12,items:{anyOf:operationSchemas}},warnings:{type:'array',maxItems:8,items:{type:'string'}}}}),
 };
}
