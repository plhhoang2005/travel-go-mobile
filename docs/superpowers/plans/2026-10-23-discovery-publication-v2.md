# Discovery Publication V2 and Flutter Consumer Implementation Plan

> **Owner-selected execution, 23/10/2026:** Codex lập kế hoạch và review; Antigravity viết code, chạy kiểm thử và sửa findings. Đây là phân công do owner chọn, thay thế đề xuất Codex-native/subagent trước đó. Steps use checkbox (`- [ ]`) syntax for tracking. Không tự dispatch agents hoặc coi lựa chọn người code là duyệt toàn bộ scope/budget/deployment. Xem [handoff](2026-10-23-admin-antigravity-handoff.md).

**Goal:** Admin xuất bản đúng bản nháp đã xem trước; cùng APK tải/cache danh mục mới, sử dụng điểm đến mới trong manual planner và giữ nguyên chuyến đi cũ.

**Architecture:** Guarded publication service freezes a draft, projects public V2 bytes and uploads an immutable Storage object; verified readback precedes atomic PostgreSQL manifest activation. Flutter reads that manifest with a dedicated public client and swaps one validated catalogue+visit snapshot after SQLite commit. Legacy V1/AI contracts remain separate.

**Tech Stack:** Supabase PostgreSQL/Storage/Edge Functions, Node built-in test runner, Flutter/Provider/Dio/sqflite/crypto hiện có; không thêm dependency.

**Spec:** [Thiết kế đã duyệt](../specs/2026-10-23-flutter-admin-design.md). **Dependencies:** [Account plan](2026-10-23-admin-account-control.md) A1–A5, [Flutter UI plan](2026-10-23-flutter-admin-ui.md) F1–F6. Toàn bộ acceptance ID của spec được map ở cuối tài liệu.

## Global Constraints

- Giữ stable IDs, nháp/private audit tách public; public projection chỉ active destination/place và referenced sources/packages. Unknown không được biến thành 0/miễn phí/mở cả ngày.
- Một bundle đồng bộ metadata+visit details; protocol `travelgo.discovery.release.v2`, schemaVersion 2, max raw bytes 2097152, SHA256 trên raw UTF-8 không BOM. Manifest không được chọn host/path do người dùng nhập.
- New version tăng dần; cùng version không đổi bytes/hash. Correct/restore bằng version cao hơn, không hạ active version hoặc overwrite object cũ.
- Nháp revision và active version phải khớp preview; Storage readback phải PASS trước CAS activation; quyền actor/session phải còn hợp lệ tại activation.
- Account/Guest/manual dữ liệu cũ không bị refresh danh mục sửa/xóa. Không thêm dependency/native permission, không tăng quota/billing hoặc tự mở allowlist AI/engine.
- Source data chưa reviewed giữ unknown; FULL V1 72/72 gate không bị relabel thành PASS bởi metadata release V2.
- Target staging `bkocylxbuyvdgxccpixx`; bucket dự kiến `discovery-catalogue`; files `releases/v2/<version>.json`. Không tự tạo bucket/policy/deploy/publish từ plan approval.
- Mỗi task <=5 authored files, 20 tool calls, 3 repair rounds; approval tổng file/call exception phải rõ trước execution. Migration aliases tạo/bind bằng CLI như plan 1.

## Review Focus

1. DB/Storage/HTTP mất response ở từng ranh giới không chọn release chưa kiểm — P1/P2 fault injection và CAS tests.
2. Tất cả destination bị ẩn hoặc một destination chưa có places vẫn là dữ liệu hợp lệ — P1/P4/P6/P7 tests, không fallback hồi sinh mục cũ.
3. Node→Dart dữ liệu lớn/Unicode/nonfinite/duplicate-ID không được parse khác nhau — P1/P4 shared fixture contract và raw byte/hash tests.
4. Dirty manual editor và saved trip có reference biến mất vẫn giữ chi phí thực tế và snapshot — P8/P9 tests.
5. Protocol mới hơn client hoặc cùng version khác hash không phá last-known-good qua restart — P5 cache tests.

## Locked public and publication contracts

`DiscoveryManifest{contract:"travelgo.discovery.manifest.v2",schemaVersion:2,version,objectKey,sha256,byteLength,publishedAt}`; publishedAt do activation transaction cấp. GET public row `public.discovery_release_manifest`, singleton `id='current'`; publishable apikey only, **không** Authorization/cookie/session interceptor. Object public GET không credentials. URI origin fixed HTTPS project; objectKey regex `^releases/v2/[1-9][0-9]*\.json$`, no redirect, <=15s total download and actual raw size <=2097152.

Bundle `{contract:"travelgo.discovery.release.v2",schemaVersion:2,version,preparedAt,catalogue:{sources,destinations},visitDetails:{sources,packages,places}}`. preparedAt là freeze time, không thay checkedAt, không bị quảng bá là giờ publish. Destination contains `{id,name,slug,region,description,imageUrl:null|string,imageRights:null|{sourceUrl,permission,credit,licenseUrl:null|string},sourceRefs:string[],places:Place[],sample:null|LegacySample}`. Place includes `{id,destinationId,name,slug,description,imageUrl,imageRights,latitude:null|number,longitude:null|number,sourceRefs:string[]}`. V2 có 0..N destinations và 0..N places; IDs text <=120 đúng pattern A1, không ép prefix. Sources chỉ giữ `{id,title,publisher,url,checkedAt}` cần thiết; checkedAt null chỉ hợp lệ nếu reference chưa dùng để khẳng định reviewed/name/ảnh.

Visit details sử dụng cấu trúc existing fields của `place_visit_details.dart`; unknown public values null/unverified với issues rõ, không có số/giờ chưa xác minh. Node projection và Dart parser cùng kiểm ID/source/package relations, dates thật/không tương lai, reviewed evidence, price nguyên 0..9007199254740991, latitude [-90,90], longitude [-180,180] finite/paired. Payload/schema strict; loại field private trước bytes serialization. Thứ tự array theo stable ID để cùng frozen input cho cùng candidate bytes; dùng một UTF-8 payloadText được lưu private làm nguồn upload/retry, không serialize lại.

`LegacySample` means exactly the existing `assets/catalogue/catalogue_readiness_v1.json` authored-example sample shape and its editorial review conditions; it is not a new sample generator. Null means unavailable. Public manifest row has explicit `contract` CHECK travelgo.discovery.manifest.v2 and `schema_version` CHECK 2; public GET selects camel-case aliases for object_key/byte_length/published_at/schema_version so DiscoveryManifest.fromJson sees the contract above, never unfiltered table columns.

HTTP `POST /functions/v1/admin-publication` envelope `{contract:"travelgo.admin.publication.v1",action,request}`, caller proof như AdminAccountService. Requests:

- `preview`: `{requestId,draftRevision}` → `PublicationPreview{previewId,sourceRevision,expectedActiveVersion,previewDigest,summary:{added,changed,hidden},warnings:FieldIssue[],blockers:FieldIssue[],expiresAt}`. `FieldIssue{code,path,message}`. Preview valid 15 phút, actor+session-bound; revision change invalidates. No active release uses expectedActiveVersion=0.
- `publish`: `{requestId,previewId,previewDigest,expectedDraftRevision,expectedActiveVersion}` → `PublicationOperation{id,state:pending|completed|needs_retry|conflict,version?,sourceRevision}`. Same requestId different content rejected. Blockers nonempty cannot publish.
- `operation`: `{operationId}` → same operation; current admin required, worker token/raw private payload never returned.

SQL: guarded `public.prepare_discovery_preview(p_request_id uuid,p_expected_draft_revision bigint) RETURNS jsonb` freezes current draft plus verified actor/session/expectedActiveVersion; Edge `buildPublicBundle(frozen,version,preparedAt)` returns typed projection or field issues. Service-only `public.stage_discovery_candidate(p_preview_id uuid,p_worker_token uuid,p_payload_text text) RETURNS jsonb` recomputes SHA/byteLength and stores immutable bytes associated with freeze; empty/malformed/private field payload rejected by server validator before staging, worker can stage only its bound candidate. `public.begin_discovery_publication(p_request jsonb) RETURNS jsonb` validates caller/preview/digest/expiry/base versions, returns internal worker-bound operation to Edge. Service-only `public.activate_discovery_release(p_operation_id uuid,p_worker_token uuid,p_readback_sha256 text,p_readback_length bigint) RETURNS jsonb` takes actor/session from persisted operation, checks current account/role/session and draft/active versions again, never trusts a new actor parameter.

Schema `M_PUBLICATION = supabase migration new discovery_publication_v2`; `M_TRIP_IDS = ... manual_dynamic_destination_ids`. Prepared versions remain immutable and CLI timestamp is recorded when created, not invented in planning.

| Table/invariant | Concrete constraint | Concurrency/negative check |
|---|---|---|
| `private_discovery_admin.release_candidates` | preview UUID PK, UNIQUE(actor_id,request_id); source_revision FK versions RESTRICT; frozen payload/digest; expected active >=0; candidate version positive unique; expires_at > created_at | Staging once only; same preview different bytes denied; actor/session binding immutable |
| `private_discovery_admin.release_operations` | UUID id PK; candidate FK RESTRICT; request hash `[0-9a-f]{64}`; state CHECK pending/completed/needs_retry/conflict; worker token private; reason/source revision audit retained | Same ID/content idempotent; stale worker or mismatched binding denied |
| `private_discovery_admin.releases` | version bigint PK CHECK 1..9007199254740991; candidate FK UNIQUE; object_key UNIQUE; sha256 regex; byte_length CHECK 1..2097152; source_revision FK versions RESTRICT; append-only | No update/delete exposed; UNIQUE(version,object_key,sha256,byte_length) supports composite manifest FK |
| `public.discovery_release_manifest` | id text PK CHECK id='current'; version/object_key/hash/length NOT NULL with composite FK→releases RESTRICT; version unique | Activation locks singleton/control and CAS expected active; creates row only for first verified release |
| Publication audit | Append event referencing operation; unique operation+event kind | Manifest+completed state+audit in one transaction; failure rolls all back |
| Public visibility | RLS SELECT true for anon/authenticated only on manifest table; no table write grants; private candidates/releases no client table grants | Guest can get manifest, cannot get frozen draft/actor/email/worker token or choose active version |

No raw service_role secret or private payload is included in client/public tables. Storage object writes are service-only, bucket policy blocks mobile insert/update/delete; publication function cannot fetch arbitrary URLs. Data API grants explicit, not dependent on historical auto-exposure defaults.

## Task P1: Publication schema và public projection

**Files (5):** `M_PUBLICATION` (Create via CLI), `supabase/functions/admin-publication/bundle.mjs` (Create), `test/discovery_public_bundle_test.mjs` (Create), `supabase/tests/discovery_publication.sql` (Create), `test/fixtures/discovery_release_v2_vectors.json` (Create).

**Interfaces:** `validateAndProjectPublicBundle({frozenDraft,version,preparedAt}) -> {bundle,blockers,warnings}`; `encodePublicBundle(bundle)->{payloadText,bytes,sha256,byteLength}`; fixture contains named valid/invalid inputs and expected SHA/IDs/projection/issue codes, synthetic URLs only. All publication SQL interfaces above are owned here.

- [ ] RED Node/SQL: projection excludes hidden/unpublished private content/audit and unverified numeric/time fields; unknown labels preserved; all-hidden and zero-place destination valid; orphan/duplicate/invalid dates/finite coordinates/missing source rights blocked. Shared raw-byte fixture includes Vietnamese combining characters, not just ASCII.
- [ ] Pin `all_hidden_publishes_an_empty_public_projection`: `assert.equal(bundle.catalogue.destinations.length,0)` and `assert.equal(bundle.visitDetails.places.length,0)`; private candidate remains unchanged and nonpublic.
- [ ] Bind M_PUBLICATION, implement PK/FK/UNIQUE/CHECK/RLS/grants and candidate/operation/activation functions. Public projection uses existing draft sources; never extends checkedAt. Persist frozen preview digest and exact once-encoded payloadText for every retry.
- [ ] Tests: mutation of draft/role/session/active after preview denies; a 15-minute expired preview requires new preview. Two connections activation same expectedActiveVersion => exactly one active successor. Candidate actor role lost denies even though service worker remains valid.
- [ ] Run `node --test test/discovery_public_bundle_test.mjs` and `./tool/verify-flutter-admin.ps1 -Mode Publication`; assert all Node/SQL negative cases PASS. Commit `feat(discovery): define immutable V2 publication contracts`.

## Task P2: Storage publication worker

**Files (4):** `supabase/functions/admin-publication/index.ts` (Create), `supabase/functions/admin-publication/gateway.mjs` (Create), `test/admin_publication_gateway_test.mjs` (Create), `tool/verify-flutter-admin.ps1` (Modify).

**Interfaces:** `createPublicationGateway({verifyCaller,callAsCaller,callAsWorker,storage,now}) => (Request)=>Promise<Response>`; storage interface uploadOnce/readback on fixed keys, no client URL. Readback compares raw bytes, digest and length before calling activate.

- [ ] RED assertions: `assert.equal(activateCalls,0)` after upload failure/readback hash mismatch/redirect/length overflow; lost upload ack retries same key/content; lost activation ack returns same completed operation. Existing object with different bytes is integrity failure, never upsert.
- [ ] Pin `readback_failure_never_switches_manifest`; assert active version equals previousVersion and activateCalls=0 for every injected readback failure.
- [ ] Implement preview/publish/operation wire; current caller RPC begins, service worker stages/readbacks/activates only bound operation. Reverify actor at activation, retain active old manifest on every pre-activation error; include status pending/needs_retry rather than fake success.
- [ ] Fault tests after prepare/stage/upload/readback/commit and duplicate publish requests; unauthorized/customer/locked/demoted cannot retrieve operation or publish. Never return worker tokens, actor email or private draft in errors/logs; never publish from client-provided raw payload.
- [ ] Run publication Node + SQL suites and existing `test/admin_discovery_web_test.mjs`; commit `feat(discovery): publish verified immutable release objects`.

## Task P3: Flutter preview/confirmation/operation tracking

**Files (5):** `lib/features/admin/services/admin_publication_service.dart` (Create), `lib/features/admin/providers/admin_publication_provider.dart` (Create), `lib/features/admin/presentation/screens/admin_publication_screen.dart` (Create), `lib/features/admin/presentation/screens/admin_shell_screen.dart` (Modify), `test/admin_publication_ui_test.dart` (Create).

**Interfaces:** immutable `PublicationPreview`, `PublicationOperation`, `FieldIssue` live in service file (small transport DTOs). `AdminPublicationService.preview({requestId,draftRevision})`, `.publish({requestId,preview})`, `.operation(String id)` return typed futures with same proof guards as F1. Provider `loadPreview(int revision)`, `confirmPublish()`, `checkOutcome()`, `invalidate()`; service+provider initialized below admin route, no global credential cache.

- [ ] RED widgets assert blockers show exact paths and disable Publish; Cancel sends no publish request; double confirm keeps requestId; server conflict retains user draft, requires new preview. Unknown operational warning visible before confirmation.
- [ ] Pin `publication_cancel_never_calls_publish`: `expect(publishRequests,isEmpty)`; lost acknowledgement then checkOutcome asserts only one publication requestId exists.
- [ ] Implement summary add/change/hide, expected/current revision/version and explicit confirm. Draft save status remains separate; publication completed updates only published status, not claims that every customer refreshed. Expiry/countdown uses server expiresAt, no implicit re-preview on confirmation.
- [ ] Test 401/403 owner/role loss clears previews and late responses; uncertain result offers check same operation ID; retry never silently publishes changed revision. Run new widgets + `test/admin_navigation_test.dart`; commit `feat(admin): add confirmed catalogue publication flow`.

## Task P4a: Typed visit-details bridge without weakening V1

**Files (2):** `lib/features/explore/models/place_visit_details.dart` (Modify), `test/public_visit_projection_test.dart` (Create).

**Interfaces:** add `VisitCatalogue.fromPublicProjection({required int version,required DateTime publishedAt,required String releaseSha256,required Map<String,Object?> data,required Set<String> expectedPlaceIds,required DateTime now})`; factory lives in the existing library so it can construct private `VisitCatalogue._`/`PlaceVisitDetails._` types. Add `bindingKind` with default `catalogue_v1`, value `release_v2` for this factory. Existing `catalogueSha256` field stores releaseSha256 for release_v2 only; it is explicitly a whole-bundle integrity binding there, not a V1 base catalogue digest. No V2 object is written to the V1 visit cache or parsed as a V1 remote manifest.

- [ ] RED `test('public_projection_preserves_unknown_and_rejects_orphans')`: assert unknown amount stays null, expected IDs match exactly, reviewed fields lacking evidence throw, and `expect(result.bindingKind,'release_v2')`. V1 manifest/asset tests must keep their original exact-hash/ID assertions.
- [ ] Implement the exported factory with existing private typed parsers/constructors, finite/date/source validation and no network. It receives only the already hash-validated public projection from P4, not arbitrary private drafts.
- [ ] Run new bridge + all existing visit model/asset/cache suites; commit `feat(discovery): adapt validated public visit projections`.

## Task P4: Dart V2 model/parser and legacy adapter

**Files (5):** `lib/features/explore/models/public_catalogue_snapshot.dart` (Create), `lib/features/explore/services/public_catalogue_parser.dart` (Create), `lib/features/explore/models/catalogue_reference.dart` (Modify), `test/public_catalogue_parser_test.dart` (Create), `test/fixtures/discovery_release_v2_vectors.json` (Modify).

**Interfaces:** `PublicCatalogueSnapshot{version,sha256,origin,manifest,catalogue:CatalogueReference,visits:VisitCatalogue,fetchedAt?}`; `PublicCatalogueParser.parse({required String payloadText,required DiscoveryManifest manifest,required DateTime now})->PublicCatalogueSnapshot`; `DiscoveryManifest.fromJson` in model file. `CatalogueReference` adds optional metadata/rights/sourceRefs and optional sample support through `SampleReference.unavailable()` with canPreview=false; old constructors retain defaults and V1 parser unchanged. Destination/place IDs no prefix inference in V2. Construct visits through P4a factory with release binding; never call another library's private constructors or loosen the V1 parser.

- [ ] RED Dart consumes same P1 vectors: expected hash/projection/IDs/issues equal Node; duplicate refs/type confusion/nonfinite numbers/oversize/unknown protocol fail. Empty bundle valid, missing optional sample renders unavailable, not fake reviewed sample.
- [ ] Pin `same_raw_fixture_has_same_cross_runtime_digest`: `expect(snapshot.sha256,vector.expectedSha256)` and `expect(snapshot.catalogue.destinations.map((d)=>d.id),vector.expectedDestinationIds)`.
- [ ] Implement strict V2 parsing and adapter to existing reference/visit models; price/hour unknown cannot parse as 0/24h. Keep old V1 parser and its rights/publisher gates unchanged. Validation hashes actual bytes, not re-encoded JSON.
- [ ] Run `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/public_catalogue_parser_test.dart','test/catalogue_parser_test.dart','test/place_visit_details_model_test.dart') -FlutterRoot 'D:/flutter/flutter'` and P1 Node vectors. Commit `feat(discovery): parse versioned public catalogue snapshots`.

## Task P5: Atomic public cache, repository and provider

**Files (5):** `lib/features/explore/services/public_catalogue_repository.dart` (Create), `lib/features/explore/services/public_catalogue_cache.dart` (Create), `lib/features/explore/providers/public_catalogue_provider.dart` (Create), `test/public_catalogue_repository_test.dart` (Create), `test/public_catalogue_cache_test.dart` (Create).

**Interfaces:** `PublicCatalogueCache.read()->Future<PublicCatalogueSnapshot?>`, `.write(PublicCatalogueSnapshot)->Future<void>`, `.close()`; constructor binds parser for read validation. SQLite dedicated public DB schema singleton manifest+raw payload+hash, atomic transaction; separate from account partitions. `PublicCatalogueRepository.load()->Future<PublicCatalogueSnapshot>`, `.refresh()->Future<PublicRefreshResult{snapshot,updated,errorCode?}>`, `.close()`; constructor injects seedLoader/cache/Dio/projectOrigin/now. Provider `.load()`, `.refresh({bool force=false})`, `.onResume()` exposes immutable snapshot/state/error and generation guards.

- [ ] RED tests actual temporary SQLite: interrupted write rollback, corruption revalidated, restart keeps last-known-good. Seed source can include incomplete visit facts labelled as seed; never requires pretending FULL V1 release complete to bootstrap V2.
- [ ] Pin `cache_write_failure_keeps_ram_and_disk_version`: both reloaded and currently shown version equal oldVersion after a failed transaction; future-schema/same-version-different-hash vectors assert the same.
- [ ] Implement dedicated public GET clients and allowlisted manifest/object paths, time/size bounds, single-flight refresh; forced button refresh, resume only after 5 minutes since last success. Compare both version/hash before SQLite write; commit then replace RAM snapshot once.
- [ ] Test malicious manifest URL/redirect, lower version, same-version-different-hash, future schema, timeout, cache write failure all preserve prior version in RAM and disk. Out-of-order requests/disposed provider cannot replace a newer snapshot. Public requests assert no bearer/cookie, only manifest publishable apikey where needed.
- [ ] Run repository/cache tests via Targeted and Node bundle vectors; commit `feat(discovery): cache and refresh public releases atomically`.

## Task P6: Shared Discovery and visit consumer wiring

**Files (5):** `lib/main.dart` (Modify), `lib/features/explore/providers/discovery_provider.dart` (Modify), `lib/features/explore/providers/place_visit_details_provider.dart` (Modify), `lib/features/explore/services/catalogue_repository.dart` (Modify), `test/public_catalogue_consumers_test.dart` (Create).

**Interfaces:** main creates one public provider/repository; CatalogueRepository gains injectable `Future<CatalogueReference> Function()? snapshotLoader`, preserving default V1 asset load for old tests. DiscoveryProvider subscribes to current snapshot with `bindPublicSnapshot(PublicCatalogueSnapshot)`; PlaceVisitDetailsProvider adds same method for full matching visits, and disables independent remote refresh while bound to a V2 snapshot. No `_boundIds` error for a legitimate V2 version switch.

- [ ] RED: same UI tree receives new destination and matching visit metadata together; independent legacy visit request arriving late cannot mix versions. All-hidden yields empty state, not bundled fallback; V1-only fixtures keep working.
- [ ] Pin `catalogue_and_visits_change_as_one_snapshot`: `expect(discoveryVersion,visitVersion)` after each listener notification, not just after the final frame.
- [ ] Wire ownership/dispose/provider subscriptions, force-refresh entry and resume hook; avoid notifyListeners during build and preserve search/filter inputs across snapshot changes. Repository/default seed adaptation must not create recursive main/provider dependencies.
- [ ] Run new consumer suite, existing discovery/provider/detail/visit tests. Expected snapshot version equality for every bound consumer; commit `feat(discovery): share release snapshots across discovery consumers`.

## Task P7: Home destination consistency

**Files (5):** `lib/features/home/models/destination_model.dart` (Modify), `lib/features/home/providers/home_catalog_provider.dart` (Modify), `lib/features/home/services/home_catalog_service.dart` (Modify), `lib/features/home/presentation/screens/main_home_screen.dart` (Modify), `test/home_public_catalogue_test.dart` (Create).

**Interfaces:** HomeCatalogProvider adds `bindPublicSnapshot(PublicCatalogueSnapshot)`; Home destinations derive from the shared snapshot, while hotels/tours/vouchers keep current services. DestinationModel accepts optional unknown weather for dynamic entries; missing weather cannot display preset 26°C as a measured forecast. Existing seeded weather behavior remains clearly sourced.

- [ ] RED: hidden destination disappears from Home and does not return when service request fails/returns empty or all destinations hidden; new name/image/description displays from V2. Metadata refresh does not reset hotels/vouchers or issue duplicate claims.
- [ ] Pin `home_failure_does_not_resurrect_hidden_destination`: `expect(home.destinations.where((d)=>d.id==hiddenId),isEmpty)` before/after held legacy response and refresh failure.
- [ ] Replace destination table/fallback path only when bound public snapshot is authoritative. Inject provider binding via existing main proxy hookup from P6; Home listens to that public provider at screen boundary, so no second snapshot/network source. Async old destination/weather results cannot overwrite newer catalogue.
- [ ] Run Home tests + discovery screen tests; missing dynamic weather renders unavailable, not fabricated default. Commit `fix(home): render destinations from the published catalogue`.

## Task P8a: Published image rights in the media component

**Files (3):** `lib/core/presentation/travel_media.dart` (Modify), `lib/core/presentation/travel_image.dart` (Modify), `test/public_media_reference_test.dart` (Create).

**Interfaces:** `TravelMediaCatalog.fromPublished({required String? imageUrl,required Map<String,Object?>? rights,required String caption})->TravelMediaReference?`; add optional `declaredPermission` and permit nullable licenseUrl for owned-image references while old constructors remain compatible. Licensed requires a valid declared license URL; UI renders source, credit and rights as admin declarations, never invents Commons/public-domain attribution or a license link.

- [ ] RED `test('owned_media_does_not_invent_a_license_url')`: `expect(reference.licenseUrl,isNull)`; licensed without licenseUrl yields null; credit/source appear in accessible attribution, not false verified legal status. Missing rights/image returns placeholder.
- [ ] Implement factory and attribution branch, preserving static references and existing image tests. Run new test plus `test/travel_visual_components_test.dart`; commit `feat(media): render declared publication image rights`.

## Task P8: Metadata images, detail and map lookups

**Files (5):** `lib/features/explore/presentation/widgets/destination_reference_list_tile.dart` (Modify), `lib/features/explore/presentation/screens/destination_detail_screen.dart` (Modify), `lib/features/favorites/presentation/screens/favorites_screen.dart` (Modify), `lib/features/map/services/manual_place_locations.dart` (Modify), `test/public_catalogue_metadata_ui_test.dart` (Create).

**Interfaces:** consume P8a media factory; runtime media takes precedence for V2, absent image uses existing semantic placeholder, not another destination's photo. `ManualPlaceLocations.find(String? id,{PublicCatalogueSnapshot? snapshot})` returns runtime coordinates/source when available; old static fixture references remain presentation-only fallback for existing IDs. Favorites retains saved name/image but labels unavailable current catalogue reference without deleting the item or rewriting its stored snapshot.

- [ ] RED UI: new ID with approved image metadata renders with credit; missing rights/image shows placeholder; optional sample unavailable handled; place name/source/unknown facts use matching snapshot. No strict prefix lookup or hardcoded count.
- [ ] Pin `unavailable_favorite_keeps_saved_label`: saved name remains visible with unavailable-reference label; `expect(deleteFavoriteCalls,0)`.
- [ ] Use runtime coordinates without claiming verified entrance/routing; map/favorites missing reference keeps saved label/snapshot and indicates no longer in catalogue. Apply that label only to catalogue-backed destination/place favorite types, not hotel/tour/service favorites. Favorite records already retain name/image; no migration or deletion is needed, resolve display against current snapshot only where reference exists.
- [ ] Tests metadata changes affect new browsing but not saved trip images/names or actual expense ledgers; textScale2.0 and image failure safe. Commit `feat(discovery): display published metadata and reference locations`.

## Task P9: Dynamic manual destination identity

**Files (5):** `M_TRIP_IDS` (Create via CLI), `lib/features/trips/models/editable_trip_codec.dart` (Modify), `lib/features/trip_planner/services/manual_trip_factory.dart` (Modify), `test/manual_dynamic_destination_test.dart` (Create), `supabase/tests/manual_dynamic_destination.sql` (Create).

**Interfaces:** Extend V2 document `input.destinationId` validation from 12-value enum to nullable stable text pattern `[a-z0-9][a-z0-9/-]{0,119}` paired with nonblank name <=180; retain legacy IDs and canonical V2 keys. `ManualTripFactory.fromInput` preserves valid published destination metadata rather than nulling unknown IDs. New manual create accepts active published ID; updates/reads permit historical released ID through server release history, not client-supplied arbitrary proof. Existing destination IDs remain supported before first V2 publication.

- [ ] RED: new published UUID destination survives factory→codec→Guest save/restart→Account create/read/update; arbitrary/malformed/not-yet-published destination blocked at new account create. Existing input destination may be preserved when later hidden; changing a trip to another destination requires that new destination currently active. Tests actualExpenses/source/place snapshots byte-identical across refresh/hide.
- [ ] Pin `dynamic_destination_survives_manual_roundtrip`: `expect(reopened.input.destinationId,publishedId)` and `expect(reopened.actualExpenses,original.actualExpenses)`; corresponding SQL create for unpublishedId must raise invalid_document without a trip/receipt insert.
- [ ] Bind M_TRIP_IDS; additive SQL replaces only relevant `private.p32_validate` input-ID predicate and create/update publication membership checks, retaining sourceBinding/import/V1_copy/digest/receipt validation and account guards from A2. Do not invent new canonical document fields or claim old APK can parse dynamic IDs.
- [ ] Default pure codec read accepts typed historic IDs so offline saved trips reopen, without requiring current network catalogue. Membership is server policy on creation/change, not a global read/codec allowlist. Guest selection comes from active local public snapshot.
- [ ] Run new Dart+SQL tests and existing editable codec/manual factory/end-to-end/Guest draft suites. Assert old V1/copy tests unchanged; commit `feat(planner): preserve published dynamic destination identities`.

## Task P10: Manual picker, AI capability and map route integration

**Files (5):** `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` (Modify), `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart` (Modify), `lib/features/map/presentation/screens/manual_day_map_screen.dart` (Modify), `lib/features/trip_planner/providers/trip_provider.dart` (Modify), `test/dynamic_destination_planner_ui_test.dart` (Create).

**Interfaces:** TripProvider `bool get supportsSelectedDestinationAi` uses the existing 12-ID supported set (no server policy widening); manual selected ID/name comes from current public snapshot. Manual planner freezes selected workspace snapshot while its chooser can refresh for a new selection; map screen receives optional current public snapshot and passes it to P8 lookup.

- [ ] RED widgets: new dynamic destination can start manual, add place, save/reopen; AI and automatic actions disabled with explanation and zero quota/API calls. Existing supported destination retains generate/modify preview/cancel/apply behavior.
- [ ] Pin `unsupported_destination_never_consumes_ai_quota`: `expect(aiRequestCalls,0)` while manual actions remain enabled; selected UUID matches publishedId through the picker.
- [ ] Handle active destination disappearing during dirty editor: preserve input/actuals, warn unavailable for a new trip and offer choose-active without auto clearing; saved historic trip still edits non-destination fields. New-place chooser excludes hidden places; existing timeline item retains snapshot label.
- [ ] Run new UI tests plus manual/discovery/map/AI widget suites; attempt hot reload when connected. Commit `feat(planner): integrate dynamic catalogue with manual planning`.

## Task P11: Whole-feature verification, deployment packet and native acceptance

**Files (3):** `tool/verify-flutter-admin.ps1` (Modify), `docs/phase-3/DISCOVERY_PUBLISH_V2_RUNBOOK_20261023.md` (Create), `docs/phase-3/FLUTTER_ADMIN_ACCEPTANCE_20261023.md` (Modify).

- [ ] Complete harness inventories for every SQL/Node/Dart suite above; `./tool/verify-flutter-admin.ps1 -Mode All -FlutterRoot 'D:/flutter/flutter'` runs SQL isolated suites + all explicitly named new Node suites + existing Full, checking exits and summaries. No count is predetermined. Do not run concurrent Full/build to save time; collect one final process result.
- [ ] Pin evidence case `native_same_apk_draft_publish_refresh_offline`: record actual release versions before draft, after publication and after offline restart; expected draft-only unchanged, refreshed newVersion, offline same newVersion. NOT RUN cannot be relabeled PASS.
- [ ] Reconcile fresh baseline failures: fixed within authorized scope with regression proof or list unresolved; whole acceptance stays NOT ACCEPTED if required suites fail. Preserve tests/assertions and Auth negative cases.
- [ ] Prepare exact staging packet: CLI-generated migrations/history map/hashes/order, functions/source hashes, required existing env names (no values), Storage bucket/policies, least grants/advisors baseline+delta, test fixture identities chosen by owner, rollback/disable procedure and evidence. Stop for concrete rollout approval; plan approval is not permission for live user mutations/publication.
- [ ] After approved deploy/readback, native admin/customer/Guest accounts: create destination+place → save draft (customer unchanged) → preview/cancel → preview/publish → same APK refresh sees new item → edit/hide/publish → Home/Explore/manual agree → Guest offline restart retains last-known-good → old trip/actuals remain. Test lock/unlock and promote/demote only on approved QA accounts; record old JWT denies, fresh login after unlock and last-admin guard.
- [ ] Native airplane/offline tests require USB or independent control channel; do not disable Wi-Fi-only ADB or clear/reinstall over unsaved drafts. Record APK/ABI/entrypoint/staging hash/device/release version/observed UI; failing or NOT RUN cases keep their gate open. Commit only reports/harness: `docs(admin): record verified publication and native acceptance`.

## Spec coverage, total budget and execution handoff

| Spec acceptance | Owning tasks |
|---|---|
| ADM01/ADM02, USR01–USR06 | A1–A4, F1–F3; P11 native |
| DASH01 | A1 SQL aggregate, F2 display/date tests |
| CAT01/CAT02/CAT03 | A5, F4–F6 |
| PUB01–PUB05 | P1–P3, P11 |
| APP01 | P6–P8 |
| APP02/APP03/APP04 | P4–P6, P9/P11 |
| APP05 | P9/P10/P11 |
| UI01 | F2/F3/F5/F6, P3/P8/P10/P11 |

Critical path: A0→A1→A2→A3→A4, A1→A5→F4; F1→F2→F3 and F4→F5→F6; A5→P1→P2, F6/P2→P3; P1→P4a→P4→P5→P6→P7, P4→P8a→P8, P6/P8→P9→P10; all tracks→P11. P1 schema/projection can be verified locally before production UI; any independent parallel work still requires selected execution method and stable interfaces. No agents are spawned during planning.

**Scope approval requested for execution:** **25 tasks, 98 unique execution files**, counted from all Files entries; includes existing/new code, SQL migrations, tests, fixtures, harness and runbooks/reports. A0–A5:6 tasks/23 unique files; F1–F6:6 tasks/25 files; P1–P11 plus P4a/P8a:13 tasks/55 files; shared files are deduplicated in 98 total. Each task touches <=5 files. Five migration aliases each count as one CLI-generated file; the count does not include these three planning documents or the spec status update. This is a requested exception for the whole feature, not permission already granted or a claim that 98 new product files will be created.

Budget proposal: **20 calls/task, 3 repair rounds/task, 500 calls aggregate ceiling**. This is a ceiling for review, not expected consumption or a time estimate. Task usage is deducted from the same aggregate, no reset between tracks; stop at either task or aggregate threshold. Shared reports/harness count as touched files in their owning tasks. Live rollout/readback/native calls also consume the remaining aggregate and still require their exact approved packet. Old G2/G3/G4 used counters remain unchanged. Any repair outside the task's five-file allowlist requires a scoped revision before editing, not an automatic sixth file.

Execution method đã được owner chọn ngày 23/10/2026: **Codex lập kế hoạch/review, Antigravity code và sửa findings**. Không hỏi lại Native/Subagent-driven. Tuân theo [hướng dẫn bàn giao và prompt Antigravity](2026-10-23-admin-antigravity-handoff.md); không tự tạo chat hoặc gửi message sang Antigravity.

Antigravity bàn giao từng task với exact diff/commit, lệnh kiểm thử và kết quả thật; Codex review đúng baseline/source hiện tại, phân biệt author-reported với kết quả mình xác minh. Findings trả về cho Antigravity, Codex không tự sửa implementation. Chỉ một agent ghi code tại một thời điểm; thay contract/phạm vi phải cập nhật kế hoạch trước.

Phân công mới không thay deployment gates hoặc cấp quyền dùng user thật làm fixture. Tổng 98 file/500 calls vẫn là đề xuất; chọn người code không phê duyệt exception tổng. Review calls của Codex và implementation calls của Antigravity cùng phải được ghi trong ledger tổng của feature, không tạo hai budget độc lập hoặc reset used. Có thể giao riêng A0 trong giới hạn hiện hữu; không tự suy A0 cho phép triển khai toàn bộ 25 task.

## Planning self-review and handover

- Spec coverage: all acceptance IDs mapped above; account schema, API, Dart types, source editing, image rights, private visit-model constructors, zero-item catalogue, dynamic manual IDs and same-APK acceptance each have owning tasks and pinned regressions.
- Interface review: names shared across plans are locked; caller authority versus service worker completion is separate; last-admin is transactional, array/JSON references validated server-side rather than mislabeled SQL FKs; publication combines immutable bytes/readback with DB CAS.
- File review: every task lists Create/Modify operations, <=5 files; repeated new files are Create only in their first owning task and Modify downstream. Five migration filenames are bound by CLI at execution, not invented.
- **Changed:** three implementation plans and spec approval/status links only. Planning baseline HEAD `6385e3d`; preserve all pre-existing modified/untracked source. No product code, schema, environment, device or live account changed.
- **Why:** executable task boundaries, explicit invariants and test evidence prevent UI-only administration, stale-token bypasses and partially updated public data.
- **Testing:** documentation validation checks plan/spec links, task/file counts, placeholders and whitespace; Flutter/Node/SQL/native feature suites are NOT RUN in this documentation task. Their commands and expected behaviors are specified, not claimed as observed results.
- **Problems:** execution method đã chốt Codex review/plan + Antigravity code; scope/budget exception còn chờ duyệt, cached Supabase CLI discovery required, historical Flutter failures still require fresh classification in A0, staging/native permissions remain packet-specific.
- **Lesson Candidate:** an integrity requirement needs a named enforcement point and a rejection/race test; UI validation alone does not establish server integrity.
