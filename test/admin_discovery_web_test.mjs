import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
const html=readFileSync(new URL('../admin/index.html',import.meta.url),'utf8');
const rawSeed=JSON.parse(readFileSync(new URL('../assets/catalogue/place_visit_details_v1.json',import.meta.url),'utf8'));
const base=JSON.parse(readFileSync(new URL('../assets/catalogue/catalogue_readiness_v1.json',import.meta.url),'utf8'));
const context={URL,TextEncoder,Date,AbortController,setTimeout,clearTimeout,crypto:webcrypto,atob,
 fetch:()=>{throw Error('Unexpected real network');}};
vm.createContext(context);vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1],context);
const C=context.TravelGOAdminCore,copy=x=>JSON.parse(JSON.stringify(x));
const seed=copy(C.withInventory(rawSeed,base));
const doc=()=>({revision:1,payload:copy(seed),history:[]});
const token=()=>({access_token:'synthetic-access',refresh_token:'synthetic-refresh',expires_at:9999999999,
 user:{id:'synthetic-admin',user_metadata:{role:'customer'}}});
const response=(value,status=200)=>({ok:status>=200&&status<300,status,json:async()=>copy(value)});
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
const key='sb_publishable_synthetic_public_key';
function client(fetchImpl,extra={}){return C.createClient({key,fetchImpl,...extra});}

test('seed coverage remains 20 price / 17 hours / 16 both with all 72 IDs',()=>{
 assert.deepEqual(copy(C.coverage(seed,'2026-10-20')),{price:20,hours:17,both:16});
 assert.equal(new Set(seed.places.map(p=>p.placeId)).size,72);
});
test('blank money remains unknown, zero remains free, time does not silently become midnight',()=>{
 assert.equal(C.money(''),null);assert.equal(C.money('0'),0);assert.equal(C.minute(''),null);
 assert.equal(C.minute('24:00'),null);assert.equal(C.minute('17:30'),1050);assert.equal(C.time(0),'00:00');
});
test('source links reject credentials and executable protocols',()=>{
 assert.equal(C.safeURL('javascript:alert(1)'),null);assert.equal(C.safeURL('https://a:b@example.invalid'),null);
 assert.equal(C.safeURL('https://example.invalid/source'),'https://example.invalid/source');
});
test('preview displays human prices, conditions and hours; unverified values stay hidden',()=>{
 const p=seed.places.find(p=>p.placeId==='ha-noi/van-mieu');
 assert.match(C.previewLines(p.price,'price',seed,'2026-10-20').join('\n'),/70.000 VNĐ/);
 assert.match(C.previewLines(p.hours,'hours',seed,'2026-10-20').join('\n'),/08:00–17:00/);
 const unknown=copy(p.price);unknown.evidence.reviewState='unverified';
 assert.doesNotMatch(C.previewLines(unknown,'price',seed,'2026-10-20').join('\n'),/70.000/);
});
test('future checks, missing references and unresolved issues never count as reviewed',()=>{
 const data=copy(seed),p=data.places[0];assert.equal(C.evidenceOK(p.price,data.sources,'2026-10-20'),true);
 p.price.evidence.checkedAt='2026-10-21';assert.equal(C.evidenceOK(p.price,data.sources,'2026-10-20'),false);
 p.price.evidence.checkedAt='2026-10-20';p.price.evidence.unresolvedIssues=['conflicting source'];
 assert.equal(C.evidenceOK(p.price,data.sources,'2026-10-20'),false);
 p.price.evidence.unresolvedIssues=[];p.price.evidence.sourceIds=['missing'];
 assert.equal(C.evidenceOK(p.price,data.sources,'2026-10-20'),false);
});
test('editing one place preserves shared packages, dates and other places; inventory changes rejected',()=>{
 const edit=copy(seed);edit.places[0].notes=['Admin edit'];assert.equal(C.inventory(edit,seed),true);
 assert.deepEqual(edit.packages,seed.packages);assert.deepEqual(edit.places[1],seed.places[1]);
 edit.places[0].placeId='forged/place';assert.throws(()=>C.inventory(edit,seed));
 const partial=copy(seed);partial.places.pop();assert.throws(()=>C.inventory(partial,seed));
 const fakeRelease=copy(seed);fakeRelease.version++;assert.throws(()=>C.inventory(fakeRelease,seed));
});
test('secret and service role keys refused; public anon key accepted without trusting it for roles',()=>{
 assert.throws(()=>client(()=>{}, {key:'sb_secret_synthetic'}));
 const jwt=role=>'x.'+Buffer.from(JSON.stringify({role})).toString('base64url')+'.x';
 assert.equal(C.publicKey(jwt('service_role')),false);assert.equal(C.publicKey(jwt('anon')),true);
});
test('login requires successful server admin read, not metadata.role',async()=>{
 const calls=[];const c=client(async(url,options)=>{calls.push([url,JSON.parse(options.body),options.headers]);
 return response(url.includes('/auth/')?token():doc());});
 const result=await c.login('admin@example.invalid','synthetic-password');assert.equal(result.revision,1);
 assert.equal(calls.length,2);assert.match(calls[1][0],/^https:\/\/bkocylxbuyvdgxccpixx\.supabase\.co\/rest\/v1\/rpc\/admin_discovery$/);
 assert.equal(calls[1][1].p_action,'read');assert.equal(calls[1][2].Authorization,'Bearer synthetic-access');
});
test('customer with spoofed admin metadata gets no document when server denies',async()=>{
 const c=client(async url=>url.includes('/auth/')?response({...token(),user:{user_metadata:{role:'admin'}}}):response({code:'42501'},403));
 await assert.rejects(c.login('customer@example.invalid','synthetic-password'));
 assert.equal(c.state.authenticated,false);assert.equal(c.state.document,null);
});
test('late login cannot resurrect auth after logout',async()=>{
 const held=deferred();let reads=0;const c=client(async url=>{if(url.includes('/auth/'))return held.promise;reads++;return response(doc());});
 const login=c.login('admin@example.invalid','synthetic-password');await c.logout();held.resolve(response(token()));
 await assert.rejects(login);assert.equal(c.state.authenticated,false);assert.equal(reads,0);
});
test('late read cannot restore document after logout',async()=>{
 const held=deferred();let reads=0;const c=client(async url=>{if(url.includes('/auth/'))return response(token());return ++reads===1?response(doc()):held.promise;});
 await c.login('admin@example.invalid','synthetic-password');const read=c.read();await new Promise(r=>setImmediate(r));
 await c.logout();held.resolve(response(doc()));await assert.rejects(read);assert.equal(c.state.document,null);
});
test('lost ack retry retains exact request ID/revision/payload and does not mint a second request',async()=>{
 const writes=[];let ids=0;const c=client(async(url,options)=>{if(url.includes('/auth/'))return response(token());
 const body=JSON.parse(options.body);if(body.p_action==='read')return response(doc());writes.push(body);
 if(writes.length===1)throw Error('synthetic lost ack');return response({...doc(),revision:2,payload:body.p_payload});
 },{randomUUID:()=>`synthetic-request-${++ids}`});await c.login('admin@example.invalid','synthetic-password');
 const edit=copy(seed);edit.places[0].notes=['Edit'];await assert.rejects(c.save(edit,'Reason'));
 assert.equal(c.state.pending,true);const saved=await c.save(edit,'Reason');assert.equal(saved.revision,2);
 assert.deepEqual(writes[0],writes[1]);assert.equal(ids,1);assert.equal(c.state.pending,false);
});
test('editing after unknown save result blocks sending changed content with the same request',async()=>{
 let writes=0;const c=client(async(url,options)=>{if(url.includes('/auth/'))return response(token());
 if(JSON.parse(options.body).p_action==='read')return response(doc());writes++;throw Error('lost ack');});
 await c.login('admin@example.invalid','synthetic-password');const edit=copy(seed);await assert.rejects(c.save(edit,'Reason'));
 edit.places[0].notes=['new edit'];await assert.rejects(c.save(edit,'Reason'),/trước chưa rõ kết quả/);assert.equal(writes,1);
});
test('conflict keeps the base revision and does not pretend the save succeeded',async()=>{
 const c=client(async(url,options)=>url.includes('/auth/')?response(token()):JSON.parse(options.body).p_action==='read'?response(doc()):response({code:'40001'},409));
 await c.login('admin@example.invalid','synthetic-password');await assert.rejects(c.save(copy(seed),'Reason'),/phiên bản mới hơn/);
 assert.equal(c.state.document.revision,1);assert.equal(c.state.pending,false);
});
test('revoked admin fails closed and clears document on the next server request',async()=>{
 const c=client(async(url,options)=>url.includes('/auth/')?response(token()):JSON.parse(options.body).p_action==='read'?response(doc()):response({code:'42501'},403));
 await c.login('admin@example.invalid','synthetic-password');await assert.rejects(c.save(copy(seed),'Reason'));
 assert.equal(c.state.authenticated,false);assert.equal(c.state.document,null);
});
test('validation stops missing reason before sending a write',async()=>{
 let writes=0;const c=client(async(url,options)=>{if(url.includes('/auth/'))return response(token());
 const body=JSON.parse(options.body);if(body.p_action!=='read')writes++;return response(doc());});
 await c.login('admin@example.invalid','synthetic-password');await assert.rejects(c.save(copy(seed),'   '));assert.equal(writes,0);
});
test('UI uses text nodes, fixed network origin, memory-only auth and explicit unpublished wording',()=>{
 assert.doesNotMatch(html,/\.innerHTML\s*=|localStorage|sessionStorage|document\.write/);
 assert.match(html,/chưa xuất bản|không xuất bản/);assert.match(html,/rel:'noopener noreferrer'/);
 assert.match(html,/connect-src 'self' https:\/\/bkocylxbuyvdgxccpixx\.supabase\.co/);
 assert.match(html,/lang="vi"/);assert.match(html,/aria-live="polite"/);
});

const newDestination=()=>({id:'dest-quy-nhon',name:'Quy Nhơn',slug:'quy-nhon',description:'',imageUrl:null,region:'',isActive:true});
const newPlace=()=>({id:'place-eo-gio',destinationId:'dest-quy-nhon',name:'Eo Gió',slug:'eo-gio',description:'',imageUrl:null,latitude:null,longitude:null,isActive:true});
const withDestination=()=>C.editEntity(seed,'destination',newDestination(),{create:true});
test('admin can create destination 13 and place 73; visit facts start unverified',()=>{
 const expanded=C.editEntity(withDestination(),'place',newPlace(),{create:true});
 assert.equal(expanded.inventory.destinations.length,13);assert.equal(expanded.inventory.places.length,73);
 assert.equal(expanded.places.length,73);assert.equal(expanded.places.at(-1).price.status,'unverified');
 assert.equal(expanded.places.at(-1).price.evidence.checkedAt,null);assert.equal(C.inventory(expanded,seed),true);
 assert.equal(seed.places.length,72);
});
test('Vietnamese names generate readable slugs while identity stays immutable',()=>{
 assert.equal(C.slugify('  Đà Nẵng / Sơn Trà  '),'da-nang-son-tra');
 const expanded=withDestination(),edited=C.editEntity(expanded,'destination',{...newDestination(),name:'Quy Nhơn mới',slug:'quy-nhon-moi'});
 assert.equal(edited.inventory.destinations.at(-1).id,'dest-quy-nhon');
});
test('orphan place and active child of hidden destination are rejected',()=>{
 assert.throws(()=>C.editEntity(seed,'place',newPlace(),{create:true}),/thuộc một điểm đến/);
 const hidden=C.editEntity(withDestination(),'destination',{...newDestination(),isActive:false});
 assert.throws(()=>C.editEntity(hidden,'place',newPlace(),{create:true}),/điểm đến đã ẩn/);
});
test('unique slug per destination; a different parent may use same place slug',()=>{
 assert.throws(()=>C.editEntity(seed,'destination',{...newDestination(),slug:'ha-noi'},{create:true}),/đường dẫn điểm đến/);
 const expanded=C.editEntity(withDestination(),'place',newPlace(),{create:true});
 assert.throws(()=>C.editEntity(expanded,'place',{...newPlace(),id:'another-eo-gio'},{create:true}),/đường dẫn địa điểm/);
 assert.doesNotThrow(()=>C.editEntity(expanded,'place',{...newPlace(),id:'hanoi-eo-gio',destinationId:'ha-noi'},{create:true}));
});
test('coordinates require a valid pair and HTTPS images; name cannot be empty',()=>{
 for(const invalid of [{latitude:91,longitude:109},{latitude:13,longitude:null},{latitude:NaN,longitude:109},
 {latitude:13,longitude:181},{imageUrl:'javascript:alert(1)'},{name:'  '}])
 assert.throws(()=>C.editEntity(withDestination(),'place',{...newPlace(),...invalid},{create:true}));
});
test('removing or renaming existing IDs fails; hide preserves records and history references',()=>{
 const removed=copy(seed);removed.inventory.places.shift();removed.places.shift();
 assert.throws(()=>C.inventory(removed,seed),/Giữ nguyên mã/);
 const moved=C.editEntity(seed,'place',{...seed.inventory.places[0],destinationId:'ha-long'});
 assert.equal(moved.inventory.places[0].id,seed.inventory.places[0].id);
 const archived=C.editEntity(seed,'destination',{...seed.inventory.destinations[0],isActive:false},{archiveChildren:true});
 assert.equal(archived.inventory.places.length,72);assert.equal(archived.places.length,72);
 assert.equal(archived.inventory.places.filter(p=>p.destinationId==='ha-noi'&&p.isActive).length,0);
});
test('restoring old version keeps newly added IDs hidden instead of deleting them',()=>{
 const current=C.editEntity(withDestination(),'place',newPlace(),{create:true});
 const restored=C.restoreSnapshot(current,seed);
 assert.equal(restored.inventory.places.length,73);assert.equal(restored.places.length,73);
 assert.equal(restored.inventory.destinations.find(d=>d.id==='dest-quy-nhon').isActive,false);
 assert.equal(restored.inventory.places.find(p=>p.id==='place-eo-gio').isActive,false);
});
test('draft integrity rejects negative money, broken source/package links and reversed hours',()=>{
 const badMoney=copy(seed);badMoney.places[1].price.options[0].amountVnd=-1;
 assert.throws(()=>C.inventory(badMoney,seed),/không âm/);
 const badSource=copy(seed);badSource.places[0].price.evidence.sourceIds=['missing'];
 assert.throws(()=>C.inventory(badSource,seed),/Nguồn tham khảo/);
 const badPackage=copy(seed);badPackage.places[1].price.options[0].packageId='missing';
 assert.throws(()=>C.inventory(badPackage,seed),/Gói vé/);
 const badTime=copy(seed);badTime.places[1].hours.rules[0].startMinutes=1200;badTime.places[1].hours.rules[0].endMinutes=480;
 assert.throws(()=>C.inventory(badTime,seed),/Khung giờ/);
 badTime.places[1].hours.rules[0].endDayOffset=1;assert.doesNotThrow(()=>C.inventory(badTime,seed));
});
test('invalid dates and reviewed evidence without references are rejected before write',()=>{
 const badDate=copy(seed);badDate.places[0].price.evidence.checkedAt='2025-02-30';
 assert.throws(()=>C.inventory(badDate,seed),/Ngày kiểm tra/);
 const fakeReviewed=copy(seed);fakeReviewed.places[0].price.evidence.sourceIds=[];
 assert.throws(()=>C.inventory(fakeReviewed,seed),/Chỉ đánh dấu/);
});
