import {createHash} from 'node:crypto';

const MAX=2097152, MONEY=9007199254740991;
const check=(ok)=>{if(!ok) throw Error('invalid_catalogue');};
const obj=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
const list=(x,max=5000)=>{check(Array.isArray(x)&&x.length<=max);return x;};
const text=(x,max=4000)=>{check(typeof x==='string'&&x.length>0&&x.length<=max&&!/[\x00-\x1f\x7f]/.test(x));return x;};
const hash=x=>createHash('sha256').update(x).digest('hex');
const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x))&&new Date(x).toISOString().slice(0,10)===x;
const instant=x=>x==null?null:(check(typeof x==='string'&&date(x.slice(0,10))&&Number.isFinite(Date.parse(x))&&/Z$|[+-]\d\d:\d\d$/.test(x)),new Date(x).toISOString());
const sourceStamp=x=>x==null?null:date(x)?null:instant(x);
const effective=x=>x==null?null:date(x)?x:instant(x);
function sourceUrl(x){if(x==null)return null;text(x,4096);const u=new URL(x);check(u.protocol==='https:'&&u.hostname&&!u.username&&!u.password&&!/[\s\\]/.test(x));return x;}
async function read(res,limit){
  check(res.status===200&&!res.redirected&&res.body);const reader=res.body.getReader();let timer;
  try{return await Promise.race([(async()=>{let n=0;const chunks=[];while(true){const part=await reader.read();if(part.done)break;n+=part.value.byteLength;check(n<=limit);chunks.push(part.value);}return Buffer.concat(chunks,n);})(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('catalogue_timeout')),5000);})]);}
  finally{clearTimeout(timer);await reader.cancel().catch(()=>{});}
}
function applies(rule,day){
  check(obj(rule));check(list(rule.weekdays,7).every(n=>Number.isInteger(n)&&n>=1&&n<=7));
  check(Number.isInteger(rule.startMinutes)&&rule.startMinutes>=0&&rule.startMinutes<1440&&Number.isInteger(rule.endMinutes)&&rule.endMinutes>=0&&rule.endMinutes<1440&&[0,1].includes(rule.endDayOffset));
  check(rule.endMinutes+rule.endDayOffset*1440>rule.startMinutes&&rule.endMinutes+rule.endDayOffset*1440-rule.startMinutes<=1440);
  for(const key of ['admissionCutoffMinutes','lastReturnMinutes'])check(rule[key]==null||(Number.isInteger(rule[key])&&rule[key]>=0&&rule[key]<1440));
  for(const key of ['effectiveFrom','effectiveTo'])check(rule[key]==null||date(rule[key]));
  check((rule.seasonStart==null)===(rule.seasonEnd==null));
  if(rule.seasonStart!=null){check(/^\d\d-\d\d$/.test(rule.seasonStart)&&date(`2000-${rule.seasonStart}`)&&date(`2000-${rule.seasonEnd}`));}
  if(!rule.weekdays.includes(new Date(day).getUTCDay()||7)||(rule.effectiveFrom&&day<rule.effectiveFrom)||(rule.effectiveTo&&day>rule.effectiveTo))return false;
  const mmdd=day.slice(5),a=rule.seasonStart,b=rule.seasonEnd;
  return a==null||(a<=b?mmdd>=a&&mmdd<=b:mmdd>=a||mmdd<=b);
}
function usableEvidence(e,sources,clock,days){
  if(!obj(e))return false;
  const ids=list(e.sourceIds,32);check(ids.every(id=>sources.has(id)));
  const stamp=sourceStamp(e.checkedAt);
  const checkedDay=date(e.checkedAt)?e.checkedAt:stamp?new Date(Date.parse(stamp)+7*3600000).toISOString().slice(0,10):null;
  const today=new Date(+clock+7*3600000).toISOString().slice(0,10);
  if(days!==undefined&&ids.some(id=>{const source=sources.get(id);const from=effective(source.effectiveFrom),to=effective(source.effectiveTo);return (from||to)&&(!days.length||days.some(day=>(from&&day<from.slice(0,10))||(to&&day>to.slice(0,10))));}))return false;
  return e.reviewState==='reviewed'&&checkedDay!==null&&checkedDay<=today&&Date.parse(today)-Date.parse(checkedDay)<=30*86400000&&ids.length>0;
}
export async function resolveCatalogueEvidence({projectOrigin,destinationId,dates,expectedVersion,fetchImpl=fetch,clock=()=>new Date()}){
  let version=null,digest=null;
  const result=(status,extra={})=>({status,version,digest,places:[],evidence:[],...extra});
  try{
    const origin=new URL(projectOrigin);check(origin.protocol==='https:'&&origin.hostname.endsWith('.supabase.co')&&origin.pathname==='/'&&!origin.search&&!origin.hash&&!origin.port&&!origin.username&&!origin.password);
    check(typeof destinationId==='string'&&/^[a-z0-9][a-z0-9/-]{0,119}$/.test(destinationId));
    check(typeof expectedVersion==='string'&&/^[1-9]\d*$/.test(expectedVersion)&&Number.isSafeInteger(Number(expectedVersion)));
    list(dates,366);check(dates.every(date)&&new Set(dates).size===dates.length);
    const now=clock();check(now instanceof Date&&Number.isFinite(+now));
    const get=url=>fetchImpl(url,{method:'GET',redirect:'manual',signal:AbortSignal.timeout(5000),headers:{Accept:'application/json'}});
    const rows=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(await read(await get(`${origin.origin}/rest/v1/discovery_release_manifest?id=eq.current&select=contract,schema_version,version,object_key,sha256,byte_length,published_at`),32768)));
    if(Array.isArray(rows)&&rows.length===0)return result('insufficient');
    check(Array.isArray(rows)&&rows.length===1&&obj(rows[0]));const m=rows[0];
    check(m.contract==='travelgo.discovery.manifest.v2'&&m.schema_version===2&&Number.isSafeInteger(m.version)&&m.version>0);
    version=String(m.version);digest=m.sha256;
    check(typeof digest==='string'&&/^[0-9a-f]{64}$/.test(digest)&&m.object_key===`releases/v2/${version}.json`&&Number.isInteger(m.byte_length)&&m.byte_length>0&&m.byte_length<=MAX);
    instant(m.published_at);
    if(version!==expectedVersion)return result('catalogue_changed');
    const bytes=await read(await get(`${origin.origin}/storage/v1/object/public/discovery-catalogue/${m.object_key}`),MAX);
    check(bytes.length===m.byte_length&&hash(bytes)===digest);
    const b=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
    check(b.contract==='travelgo.discovery.release.v2'&&b.schemaVersion===2&&b.version===m.version&&obj(b.catalogue)&&obj(b.visitDetails));
    const sources=new Map();
    for(const s of list(b.catalogue.sources)){
      check(obj(s)&&!sources.has(text(s.id,128)));sourceUrl(s.url);sourceStamp(s.checkedAt);for(const k of ['title','publisher'])check(s[k]==null||typeof s[k]==='string');
      sources.set(s.id,s);
    }
    for(const s of list(b.visitDetails.sources)){
      check(obj(s));const previous=sources.get(s.id);
      if(previous){for(const k of ['url','title','publisher','publishedAt','effectiveFrom','effectiveTo'])if(previous[k]!=null&&s[k]!=null)check(previous[k]===s[k]);}
      else{sourceUrl(s.url);sources.set(text(s.id,128),s);}
      sourceStamp(s.publishedAt);for(const key of ['effectiveFrom','effectiveTo'])effective(s[key]);
      if(s.effectiveFrom!=null&&s.effectiveTo!=null)check((s.effectiveFrom.length===10)===(s.effectiveTo.length===10)&&Date.parse(s.effectiveFrom)<=Date.parse(s.effectiveTo));
      if(previous)sources.set(s.id,{...s,...previous});
    }
    const destinations=list(b.catalogue.destinations);check(new Set(destinations.map(d=>d.id)).size===destinations.length);
    const d=destinations.find(v=>v.id===destinationId&&v.isActive!==false);
    if(!d)return result('insufficient');text(d.name,200);
    const selected=list(d.places).filter(p=>p.isActive!==false);
    if(selected.length===0||selected.length>12)return result('insufficient');
    const details=new Map();for(const v of list(b.visitDetails.places)){check(obj(v)&&!details.has(v.placeId));details.set(v.placeId,v);}
    if(selected.some(p=>!Array.isArray(p.sourceRefs)||p.sourceRefs.length===0||p.sourceRefs.some(id=>!sources.get(id)?.url)))return result('insufficient');
    const evidence=[],places=[];const unique=new Set();
    function record(p,key,value,metadata={}){
      const ids=metadata.sourceIds??p.sourceRefs??[];list(ids,32);check(ids.every(id=>sources.has(id)));
      const s=sources.get(ids[0]);const checkedAt=sourceStamp(metadata.checkedAt??s?.checkedAt);
      const factValue=typeof value==='string'?value:JSON.stringify({...value,...(date(metadata.checkedAt)?{checkedOn:metadata.checkedAt}:{})});
      text(factValue,4000);
      const id='cat_'+hash(JSON.stringify([digest,p.id,key,ids])).slice(0,32);
      const r={id,origin:'catalogue',url:sourceUrl(s?.url),title:s?.title||null,publisher:s?.publisher||null,
        factKey:key,factValue,retrievedAt:now.toISOString(),checkedAt,publishedAt:sourceStamp(s?.publishedAt),
        effectiveFrom:effective(s?.effectiveFrom),effectiveTo:effective(s?.effectiveTo),reviewed:metadata.reviewed===true,evidenceRequestId:null};
      evidence.push(r);return id;
    }
    for(const p of selected){
      check(obj(p)&&typeof p.id==='string'&&p.id.startsWith(destinationId+'/')&&p.destinationId===destinationId&&!unique.has(p.id));unique.add(p.id);text(p.name,200);
      const nameId=record(p,`${p.id}:name`,p.name);
      for(const sourceId of p.sourceRefs){
        const source=sources.get(sourceId);
        for(const [field,label] of [['checkedAt','checkedOn'],['publishedAt','publishedOn']]){
          if(date(source[field]))record(p,`${p.id}:source:${sourceId}:${label}`,source[field],{sourceIds:[sourceId]});
        }
      }
      const v=details.get(p.id),price=v?.price,hours=v?.hours;
      const priceReviewed=usableEvidence(price?.evidence??{sourceIds:[]},sources,now,dates);
      let options=[];
      if(priceReviewed&&['free','priced','bundled'].includes(price.status)){
        options=list(price.options??[],32).map(o=>{
          check(obj(o)&&o.currency==='VND'&&(o.amountVnd===null||Number.isSafeInteger(o.amountVnd)&&o.amountVnd>=0&&o.amountVnd<=MONEY));
          return {id:text(o.id,128),amountVnd:o.amountVnd,currency:'VND',unit:text(o.unit,100),packageId:o.packageId??null,conditions:list(o.conditions??[],32)};
        });
        if(price.status==='free')check(options.length===0||options.every(o=>o.amountVnd===0));
      }
      const resolvedPrice={status:priceReviewed&&['free','priced','bundled'].includes(price.status)?price.status:'unknown',options};
      const evidenceIds=[nameId];
      if(resolvedPrice.status!=='unknown')evidenceIds.push(record(p,`${p.id}:price`,resolvedPrice,{...price.evidence,reviewed:priceReviewed}));
      const hoursReviewed=usableEvidence(hours?.evidence??{sourceIds:[]},sources,now);
      const hoursByDate=[];
      for(const day of dates.length?dates:[null]){
        let status='unknown',openingWindows=[];
        if(hoursReviewed&&day!==null&&usableEvidence(hours.evidence,sources,now,[day])){
          if(hours.status==='temporarily_closed')status='closed';
          else if(['scheduled','seasonal'].includes(hours.status)){
            const rules=list(hours.rules,64);
            for(const r of rules){
              if(applies(r,day))openingWindows.push({startMinute:r.startMinutes,endMinute:r.endDayOffset===1?1440:r.endMinutes,admissionCutoffMinute:r.admissionCutoffMinutes??null});
              const yesterday=new Date(Date.parse(day)-86400000).toISOString().slice(0,10);
              if(r.endDayOffset===1&&r.endMinutes>0&&applies(r,yesterday))openingWindows.push({startMinute:0,endMinute:r.endMinutes,admissionCutoffMinute:null});
            }
            status=openingWindows.length?'open':'closed';
          }
        }
        const h={date:day,status,openingWindows};hoursByDate.push(h);
        if(status!=='unknown')evidenceIds.push(record(p,`${p.id}:hours:${day}`,h,{...hours.evidence,reviewed:hoursReviewed}));
      }
      places.push({id:p.id,name:p.name,evidenceIds,price:resolvedPrice,hoursByDate});
    }
    // Leave room for proposal and claims inside the existing 16 KiB receipt cap.
    if(Buffer.byteLength(JSON.stringify({places,evidence}),'utf8')>8000)return result('insufficient');
    return result('ready',{places,evidence});
  }catch{return result('unavailable');}
}
