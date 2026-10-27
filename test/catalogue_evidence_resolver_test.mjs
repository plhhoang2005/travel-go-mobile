import test from 'node:test';
import assert from 'node:assert/strict';
import {bundleFixture,catalogueFixture} from './fixtures/catalogue_evidence_fixture.mjs';
import {resolveCatalogueEvidence} from '../supabase/functions/itinerary-proposal/catalogue-evidence.mjs';

const resolve=(f,extra={})=>resolveCatalogueEvidence({projectOrigin:'https://fixture.supabase.co',destinationId:'new-city',dates:['2026-11-24'],expectedVersion:'7',clock:()=>new Date('2026-10-27T02:00:00Z'),fetchImpl:f.fetchImpl,...extra});
test('exact dynamic public release yields sourced facts with winter hours',async()=>{
  const f=catalogueFixture();const r=await resolve(f);
  assert.equal(r.status,'ready');assert.equal(r.version,'7');assert.equal(r.digest,f.digest);
  assert.equal(r.places[0].price.options[0].amountVnd,100000);
  assert.deepEqual(r.places[0].hoursByDate[0].openingWindows.map(w=>[w.startMinute,w.endMinute,w.admissionCutoffMinute]),[[540,1020,960]]);
  assert.ok(r.evidence.length>0);assert.equal(f.calls.length,2);
  assert.ok(f.calls.every(c=>c.init.redirect==='manual'));
});
test('summer and unknown date do not reuse winter windows',async()=>{
  let r=await resolve(catalogueFixture(),{dates:['2026-06-01']});
  assert.equal(r.places[0].hoursByDate[0].openingWindows[0].startMinute,480);
  r=await resolve(catalogueFixture(),{dates:[]});
  assert.equal(r.places[0].hoursByDate[0].status,'unknown');
});
test('version mismatch, integrity errors, missing destination, and network stay distinct',async()=>{
  assert.equal((await resolve(catalogueFixture(),{expectedVersion:'6'})).status,'catalogue_changed');
  assert.equal((await resolve(catalogueFixture(undefined,{text:'corrupt'}))).status,'unavailable');
  assert.equal((await resolve(catalogueFixture(),{destinationId:'absent'})).status,'insufficient');
  assert.equal((await resolve(catalogueFixture(undefined,{offline:true}))).status,'unavailable');
});
test('invalid origin, key, manifest schema and redirects fail closed',async()=>{
  const f=catalogueFixture();assert.equal((await resolve(f,{projectOrigin:'http://fixture.supabase.co'})).status,'unavailable');assert.equal(f.calls.length,0);
  for(const manifest of [{object_key:'../bad.json'},{schema_version:3},{byte_length:2097153},{sha256:'bad'}]){
    assert.equal((await resolve(catalogueFixture(undefined,{manifest}))).status,'unavailable');
  }
  assert.equal((await resolve(catalogueFixture(undefined,{status:302}))).status,'unavailable');
});
test('unverified price/unknown check date never become free or recently checked',async()=>{
  const b=bundleFixture();b.catalogue.sources[0].checkedAt=null;
  b.visitDetails.places[0].price={status:'unverified',options:[],evidence:{reviewState:'unverified',checkedAt:null,sourceIds:[],conditions:[],unresolvedIssues:[]}};
  const r=await resolve(catalogueFixture(b));assert.equal(r.status,'ready');
  assert.deepEqual(r.places[0].price.options,[]);
  assert.equal(r.evidence.find(e=>e.factKey.endsWith(':name')).checkedAt,null);
});
test('malformed source URL or cross-release source conflict is rejected',async()=>{
  const b=bundleFixture();b.catalogue.sources[0].url='javascript:alert(1)';
  assert.equal((await resolve(catalogueFixture(b))).status,'unavailable');
});

test('calendar source check dates keep precision and never fabricate a timestamp',async()=>{
 const r=await resolve(catalogueFixture());assert.equal(r.status,'ready');
 assert.equal(r.evidence.find(e=>e.factKey.endsWith(':name')).checkedAt,null);
 assert.ok(r.evidence.some(e=>e.factKey.endsWith(':checkedOn')&&e.factValue==='2026-10-20'));
});

test('source effective dates outside the trip do not become verified price or opening',async()=>{
 const b=bundleFixture();b.visitDetails.sources[0].effectiveFrom='2027-01-01';
 const r=await resolve(catalogueFixture(b));assert.equal(r.status,'ready');
 assert.equal(r.places[0].price.status,'unknown');assert.equal(r.places[0].hoursByDate[0].status,'unknown');
});
