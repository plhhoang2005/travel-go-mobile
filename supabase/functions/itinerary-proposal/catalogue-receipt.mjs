export const ITINERARY_EVIDENCE='travelgo.itinerary.evidence.v1';
export const ASSISTANT_EVIDENCE='travelgo.assistant.evidence.v1';
export const isEvidenceContract=c=>[ITINERARY_EVIDENCE,ASSISTANT_EVIDENCE].includes(c);
const MAX=9007199254740991,UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const check=ok=>{if(!ok)throw Error('invalid_catalogue_contract');};
const keys=(v,required,optional=[])=>{check(v&&typeof v==='object'&&!Array.isArray(v));check(required.every(k=>Object.hasOwn(v,k))&&Object.keys(v).every(k=>required.includes(k)||optional.includes(k)));};
const str=(v,n=4000)=>{check(typeof v==='string'&&v.length>0&&v.length<=n&&!/[\x00-\x1f\x7f]/.test(v));return v;};
const human=(v,n)=>{str(v,n);check(!/@|https?:|www\.|(?:\+\d|0)(?:[ .()-]*\d){8,14}/i.test(v));return v;};
const integer=(v,min=0,max=MAX)=>{check(Number.isSafeInteger(v)&&v>=min&&v<=max);return v;};
const day=v=>{check(typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)&&Number.isFinite(Date.parse(v))&&new Date(v).toISOString().slice(0,10)===v);return v;};
const list=(v,n)=>{check(Array.isArray(v)&&v.length<=n);return v;};
const digest=v=>{check(typeof v==='string'&&/^[0-9a-f]{64}$/.test(v));return v;};
export function sanitizeEvidenceRequest(v){
  check(isEvidenceContract(v?.contract));const assistant=v.contract===ASSISTANT_EVIDENCE;
  keys(v,['contract','intent','requestId','consent','context'],assistant?['prompt','history']:[]);
  check(v.consent===true&&UUID.test(v.requestId)&& (assistant?['advice','recommendations','modify'].includes(v.intent):v.intent==='generate'));
  const c=v.context;
  keys(c,['destinationId','catalogueVersion','catalogueDigest','dates','dayDates','numDays','numPeople','budgetVnd','interests','budget','baseDigest','scope','selectedDay','priority','activities']);
  check(typeof c.destinationId==='string'&&/^[a-z0-9][a-z0-9/-]{0,119}$/.test(c.destinationId));
  check(typeof c.catalogueVersion==='string'&&/^[1-9]\d*$/.test(c.catalogueVersion)&&Number.isSafeInteger(Number(c.catalogueVersion)));
  digest(c.catalogueDigest);digest(c.baseDigest);integer(c.numDays,1,366);integer(c.numPeople,1,2147483647);integer(c.budgetVnd);
  check(['day','trip'].includes(c.scope)&&['cheapest','fastest','balanced','comfortable'].includes(c.priority));
  if(c.scope==='day')integer(c.selectedDay,1,c.numDays);else check(c.selectedDay===null);
  if(v.intent==='modify')check(c.scope==='day');
  const dayDates=list(c.dayDates,366).map(d=>{keys(d,['day','date']);integer(d.day,1,c.numDays);if(d.date!==null)day(d.date);return {...d};});
  const selected=dayDates.map(d=>d.day);check(new Set(selected).size===selected.length);
  check(c.scope==='day'?selected.length===1&&selected[0]===c.selectedDay:selected.length===c.numDays&&selected.every((d,i)=>d===i+1));
  const dates=list(c.dates,366).map(day);check(JSON.stringify(dates)===JSON.stringify(dayDates.filter(d=>d.date!==null).map(d=>d.date))&&new Set(dates).size===dates.length);
  const interests=list(c.interests,20).map(i=>human(i,80));check(new Set(interests).size===interests.length);
  keys(c.budget,['knownEstimate','unknownEstimateCount','actualTotal','estimateRemaining','actualRemaining']);
  integer(c.budget.knownEstimate);integer(c.budget.actualTotal);integer(c.budget.unknownEstimateCount,0,2147483647);
  integer(c.budget.estimateRemaining,-MAX);integer(c.budget.actualRemaining,-MAX);
  check(c.budget.estimateRemaining===c.budgetVnd-c.budget.knownEstimate&&c.budget.actualRemaining===c.budgetVnd-c.budget.actualTotal);
  const activities=list(c.activities,48).map(a=>{
    keys(a,['id','day','title','placeId','startMinute','endMinute']);check(UUID.test(a.id)&&selected.includes(a.day));human(a.title,200);
    check(a.placeId===null||(typeof a.placeId==='string'&&a.placeId.startsWith(c.destinationId+'/')));
    check((a.startMinute===null)===(a.endMinute===null));if(a.startMinute!==null){integer(a.startMinute,0,1439);integer(a.endMinute,a.startMinute+1,1440);}
    return {...a};
  });check(new Set(activities.map(a=>a.id)).size===activities.length);
  const context={destinationId:c.destinationId,catalogueVersion:c.catalogueVersion,catalogueDigest:c.catalogueDigest,dates,dayDates,
    numDays:c.numDays,numPeople:c.numPeople,budgetVnd:c.budgetVnd,interests,budget:{...c.budget},baseDigest:c.baseDigest,
    scope:c.scope,selectedDay:c.selectedDay,priority:c.priority,activities};
  const clean={contract:v.contract,intent:v.intent,requestId:v.requestId,consent:true,context};
  if(assistant){human(v.prompt?.replace(/[\r\n\t]/g,' '),600);clean.prompt=v.prompt;clean.history=list(v.history,4).map((h,i)=>{
    keys(h,['role','text']);check(h.role===(i%2?'model':'user'));human(h.text.replace(/[\r\n\t]/g,' '),1200);return {...h};
  });check(clean.history.length%2===0);}
  return clean;
}
export function receiptFits(value){
  // PostgreSQL jsonb adds spaces to separators. A conservative upper bound,
  // verified against the actual finalize RPC in the SQL bridge.
  let separators=0;
  const count=v=>{if(v&&typeof v==='object'){separators+=Object.keys(v).length;Object.values(v).forEach(count);}};count(value);
  return Buffer.byteLength(JSON.stringify(value),'utf8')+2*separators+256<=16384;
}
export function assembleCatalogueReceipt(clean,proposal,resolved){
  check(resolved.status==='ready'&&resolved.version===clean.context.catalogueVersion&&resolved.digest===clean.context.catalogueDigest);
  const evidence=resolved.evidence.map(r=>({...r,evidenceRequestId:clean.requestId}));
  const claims=evidence.map(r=>({id:'fact_'+r.id,kind:'fact',text:`${r.factKey}: ${r.factValue}`,evidenceIds:[r.id]}));
  const result={contract:clean.contract,proposal,catalogueVersion:resolved.version,catalogueDigest:resolved.digest,baseDigest:clean.context.baseDigest,evidence,claims};
  check(receiptFits(result));return validateCatalogueReceipt(result,clean);
}
export function validateCatalogueReceipt(r,clean){
  keys(r,['contract','proposal','catalogueVersion','catalogueDigest','baseDigest','evidence','claims']);
  check(r.contract===clean.contract&&r.catalogueVersion===clean.context.catalogueVersion&&r.catalogueDigest===clean.context.catalogueDigest&&r.baseDigest===clean.context.baseDigest&&receiptFits(r));
  const ids=new Set();
  for(const e of list(r.evidence,64)){
    keys(e,['id','origin','url','title','publisher','factKey','factValue','retrievedAt','checkedAt','publishedAt','effectiveFrom','effectiveTo','reviewed','evidenceRequestId']);
    str(e.id,128);check(!ids.has(e.id));ids.add(e.id);check(e.origin==='catalogue'&&e.evidenceRequestId===clean.requestId&&typeof e.reviewed==='boolean');
    const url=new URL(e.url);check(url.protocol==='https:'&&!url.username&&!url.password&&!/[\s\\]/.test(e.url));
    str(e.factKey);str(e.factValue);for(const k of ['title','publisher'])if(e[k]!==null)str(e[k]);
    for(const k of ['retrievedAt','checkedAt','publishedAt','effectiveFrom','effectiveTo']){
      const value=e[k];if(value!==null){if(['effectiveFrom','effectiveTo'].includes(k)&&value.length===10)day(value);else check(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$/.test(value)&&Number.isFinite(Date.parse(value))&&new Date(value).toISOString().slice(0,19)===value.slice(0,19));}
    }
  }
  for(const e of r.evidence){if(e.effectiveFrom!==null&&e.effectiveTo!==null)check((e.effectiveFrom.length===10)===(e.effectiveTo.length===10)&&Date.parse(e.effectiveFrom)<=Date.parse(e.effectiveTo));}
  check(ids.size>0);const claims=new Set();
  for(const claim of list(r.claims,64)){
    keys(claim,['id','kind','text','evidenceIds']);str(claim.id,128);str(claim.text,6000);check(!claims.has(claim.id));claims.add(claim.id);
    check(claim.kind==='fact'&&claim.evidenceIds.length===1&&ids.has(claim.evidenceIds[0]));
    const record=r.evidence.find(e=>e.id===claim.evidenceIds[0]);
    check(claim.id==='fact_'+record.id&&claim.text===`${record.factKey}: ${record.factValue}`);
  }
  check(claims.size===ids.size);return r;
}
export function providerEvidenceContext(clean,resolved){
  const c=clean.context;
  const places=resolved.places.map(p=>({id:p.id,name:p.name,sourceId:p.evidenceIds[0]}));
  const ids=new Set(places.map(p=>p.id));check(c.activities.every(a=>a.placeId===null||ids.has(a.placeId)));
  const selectedDay=c.selectedDay??1,selectedDate=c.dayDates.find(d=>d.day===selectedDay)?.date??null;
  const openingWindows=resolved.places.flatMap(p=>p.hoursByDate.filter(h=>h.date===selectedDate).flatMap(h=>h.openingWindows.map(w=>({placeId:p.id,startMinute:w.startMinute,endMinute:w.endMinute,sourceRef:p.evidenceIds[0]}))));
  return {contract:clean.contract===ITINERARY_EVIDENCE?'travelgo.itinerary.v1':'travelgo.assistant.v1',intent:clean.intent,requestId:clean.requestId,consent:true,
    context:{destinationId:c.destinationId,originRegion:'unknown',numDays:c.numDays,numPeople:c.numPeople,budgetVnd:c.budgetVnd,interests:c.interests,
      selectedDay,date:selectedDate,priority:c.priority,activities:c.activities,places,constraints:{openingWindows,routes:[]},weather:'unknown',
      budgetTotals:c.budget,scope:c.scope,dayDates:c.dayDates},...(clean.prompt!==undefined?{prompt:clean.prompt,history:clean.history}:{})};
}
export function resolutionFromReceipt(receipt){
  const places=receipt.evidence.filter(e=>e.factKey.endsWith(':name')).map(e=>{
    const id=e.factKey.slice(0,-5);
    return {id,name:e.factValue,evidenceIds:[e.id],hoursByDate:receipt.evidence.filter(h=>h.factKey.startsWith(id+':hours:')).map(h=>JSON.parse(h.factValue))};
  });
  return {places};
}
