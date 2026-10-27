import fs from 'node:fs';
import {createHash} from 'node:crypto';
export const bundleFixture=()=>JSON.parse(fs.readFileSync(new URL('catalogue_evidence_vectors.json',import.meta.url),'utf8'));
export function catalogueFixture(bundle=bundleFixture(),options={}) {
  const text=JSON.stringify(bundle),bytes=Buffer.from(text);
  const digest=createHash('sha256').update(bytes).digest('hex');
  const manifest={contract:'travelgo.discovery.manifest.v2',schema_version:2,version:bundle.version,object_key:`releases/v2/${bundle.version}.json`,sha256:digest,byte_length:bytes.length,published_at:'2026-10-27T01:00:00Z',...options.manifest};
  const calls=[];
  return {digest,manifest,text,calls,fetchImpl:async(url,init)=>{
    calls.push({url,init});
    if(options.offline) throw Error('offline');
    if(url.includes('/rest/v1/discovery_release_manifest')) return new Response(JSON.stringify([manifest]),{status:options.status??200});
    if(url.includes('/storage/v1/object/public/discovery-catalogue/')) return new Response(options.text??text);
    throw Error('unexpected URL');
  }};
}
export const owner='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
export const requestId='a3000000-0000-4000-8000-000000000003';
export function contextFixture(digest) {return {
  destinationId:'new-city',catalogueVersion:'7',catalogueDigest:digest,
  dates:['2026-11-24'],dayDates:[{day:1,date:'2026-11-24'}],numDays:1,numPeople:2,budgetVnd:500000,
  interests:[],budget:{knownEstimate:0,unknownEstimateCount:0,actualTotal:0,estimateRemaining:500000,actualRemaining:500000},
  baseDigest:'a'.repeat(64),scope:'trip',selectedDay:null,priority:'balanced',activities:[],
};}
export function requestFixture(digest,assistant=false){return {contract:assistant?'travelgo.assistant.evidence.v1':'travelgo.itinerary.evidence.v1',
  requestId,intent:assistant?'advice':'generate',consent:true,context:contextFixture(digest),...(assistant?{prompt:'Suggest a safe visit',history:[]}:{})};}
