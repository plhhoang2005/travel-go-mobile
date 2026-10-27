import test from 'node:test';
import assert from 'node:assert/strict';
import {resolveCatalogueEvidence} from '../supabase/functions/itinerary-proposal/catalogue-evidence.mjs';
import {sanitizeEvidenceRequest,assembleCatalogueReceipt,validateCatalogueReceipt,providerEvidenceContext} from '../supabase/functions/itinerary-proposal/catalogue-receipt.mjs';
import {catalogueFixture,requestFixture} from './fixtures/catalogue_evidence_fixture.mjs';
async function fixture(){const f=catalogueFixture(),clean=sanitizeEvidenceRequest(requestFixture(f.digest));
 const resolved=await resolveCatalogueEvidence({projectOrigin:'https://fixture.supabase.co',destinationId:'new-city',dates:clean.context.dates,expectedVersion:'7',fetchImpl:f.fetchImpl,clock:()=>new Date('2026-10-27T02:00:00Z')});
 return {clean,resolved};}
test('server records and canonical fact claims are bound to the finalized request',async()=>{
 const {clean,resolved}=await fixture();const r=assembleCatalogueReceipt(clean,{verification:'unverified'},resolved);
 assert.equal(validateCatalogueReceipt(r,clean),r);
 assert.ok(r.evidence.every(e=>e.evidenceRequestId===clean.requestId));
 assert.equal(r.claims.length,r.evidence.length);
 assert.equal(providerEvidenceContext(clean,resolved).context.budgetTotals.estimateRemaining,500000);
});
test('forged authoritative fields, private notes and inconsistent budgets are denied',async()=>{
 const f=catalogueFixture();
 for(const mutate of [r=>r.context.reviewed=true,r=>r.context.notes='private',r=>r.context.budget.actualRemaining=1,r=>r.context.catalogueVersion=7]){
   const r=requestFixture(f.digest);mutate(r);assert.throws(()=>sanitizeEvidenceRequest(r));
 }
});
test('altered claims, request binding, registry keys and oversized result cannot be trusted',async()=>{
 const {clean,resolved}=await fixture();const good=assembleCatalogueReceipt(clean,{verification:'unverified'},resolved);
 for(const mutate of [r=>r.claims[0].text='invented fact',r=>r.evidence[0].reviewed='yes',r=>r.evidence[0].evidenceRequestId='other',r=>r.evidence[0].url='http://untrusted',r=>r.catalogueDigest='b'.repeat(64)]){
   const r=structuredClone(good);mutate(r);assert.throws(()=>validateCatalogueReceipt(r,clean));
 }
 assert.throws(()=>assembleCatalogueReceipt(clean,{summary:'x'.repeat(17000)},resolved));
});

test('assembler rejects malformed registry before success finalization',async()=>{
 const {clean,resolved}=await fixture();resolved.evidence[0].title={bad:'schema'};
 assert.throws(()=>assembleCatalogueReceipt(clean,{verification:'unverified'},resolved));
});
