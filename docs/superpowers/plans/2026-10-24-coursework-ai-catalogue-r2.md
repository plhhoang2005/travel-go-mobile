# TravelGO Catalogue AI R2 Implementation Plan

> **Điều phối mới 27/10/2026:** owner tự làm toàn bộ A3 resolver/context/gateway/receipt, không giao resolver cho coder 2. A1/A2 đã được owner duyệt local; dùng [plan hợp nhất](2026-10-27-team-owner.md) và [report A2](../../phase-3/A2_CODEX_IMPLEMENTATION_20261027.md) cho trạng thái mới nhất. Checkboxes/mốc lập plan bên dưới không thay bằng chứng hoàn thành sau này; không làm lại A1/A2. Dependencies/contract A3–A5 giữ nguyên.

> **For agentic workers:** ĐÃ ĐƯỢC OWNER DUYỆT. Thực thi từng task bằng checkbox theo phương thức owner chọn. Chỉ dùng Superpowers cho execution khi owner yêu cầu task đó; không mặc định spawn/commit/deploy.

**Goal:** Trợ lý tạo/tư vấn/sửa lịch dựa trên catalogue, có căn cứ xem được và giữ qua save/read.

**Architecture:** Thêm evidence registry bao document v2, không nới v2 strict schema. Backend resolve exact public catalogue version để AI không tin facts/review flag client. UI hiện có tiếp tục preview/apply và stamp protection.

**Tech Stack:** Flutter/Provider/Dio, Gemini gateway hiện có, PostgreSQL/Supabase storage/RPC hiện có.

**Spec:** [AI design](../../../.agent/ai-planner-design.md), [Product scope](../../../.agent/product-scope.md), [master R2](2026-10-24-coursework-r2.md). Baseline, quyền hạn, limits và Review Focus của master áp dụng.

NEW interfaces dưới đây là thiết kế đã duyệt, chưa triển khai; chưa có source/test được tạo. Không tự migration live hoặc lấy dữ liệu Admin test thật trong lúc thực hiện unit tests.

## A1 — Evidence model/codec backward-compatible

**Depends:** C5 xác nhận các document/roundtrip hiện tại. Task A1 là pure model/codec, chưa remote writes.
**Create:** `lib/features/trips/models/trip_evidence_envelope.dart`, `trip_evidence_codec.dart`, `test/trip_evidence_codec_test.dart`, `test/fixtures/trip_evidence_vectors.json`.
**Reuse:** `EditableTripDocumentV2`, `EditableTripCodec` và `FieldProvenance.sourceRefs`; không sửa meaning v2. Đây là test fixture file, không dữ liệu người dùng.

**Interfaces NEW:**
- `enum EvidenceOrigin { catalogue, web, user }`; `enum ClaimKind { fact, inference, unknown }`.
- `EvidenceRecord`: `String id`, `EvidenceOrigin origin`, `Uri? url`, `String? title,publisher`, `String factKey,factValue`, `String? retrievedAt,checkedAt,publishedAt,effectiveFrom,effectiveTo`, `bool reviewed`, `String? evidenceRequestId` (UUID do backend gắn cho evidence phát sinh từ AI/web, không do model tạo). Timestamps UTC ISO hoặc date-only cho effective dates, không trộn; unknown=null. Catalogue/web record cần https URL, user-origin không giả URL/verified. ID ≤128; title/publisher/factValue dùng cùng tổng maxBytes, không truncate âm thầm.
- `EvidenceClaim`: `String id,text`, `ClaimKind kind`, `List<String> evidenceIds`; fact phải resolve ít nhất một ID trong registry; inference không được giả thành fact/verified.
- `ExternalPlaceRecord`: `String id,name,destinationName`, `List<String> evidenceIds`; `ExternalItemBinding`: `String itemId,externalPlaceId`. Hai loại này chuẩn bị schema, không bật UI web tới W3. Catalogue placeId và external binding không được cùng tồn tại cho một item.
- `TripEvidenceEnvelope`: `EditableTripDocumentV2 document`, `List<EvidenceRecord> evidence`, `List<EvidenceClaim> claims`, `List<ExternalPlaceRecord> externalPlaces`, `List<ExternalItemBinding> externalBindings`; contract=`travelgo.trip.evidence.v1`.
- `TripEvidenceCodec.decode(String text) -> TripEvidenceEnvelope`, `encode(TripEvidenceEnvelope)->String`, `digest(TripEvidenceEnvelope)->String`; decode old v2 wrap registries rỗng, encode luôn canonical envelope; old reader V2 không tự nhận envelope.

- [ ] RED: create vectors old_v2/new_envelope/dangling_source/duplicate_id/bad_url/too_big. Test names `reads_legacy_v2_without_rewriting`, `roundtrip_keeps_claim_sources`, `digest_covers_evidence_change`, `rejects_dangling_evidence`.

```dart
// Assertions trong test, dùng vector fixture có đủ document hợp lệ.
final legacy = TripEvidenceCodec.decode(legacyV2Text);
expect(legacy.evidence, isEmpty);
expect(EditableTripCodec.encode(legacy.document), legacyV2Text);
final restored = TripEvidenceCodec.decode(TripEvidenceCodec.encode(envelope));
expect(restored.evidence.single.url.toString(), 'https://example.org/place-a');
expect(restored.claims.single.evidenceIds, ['source-a']);
expect(() => TripEvidenceCodec.decode(danglingText), throwsA(isA<EditableCodecException>()));
```

`legacyV2Text/envelope/danglingText` là values từ vectors trong fixture, không undefined product API. Fixture canonical v2 text do existing codec encode, không tự so JSON whitespace.
- [ ] Run: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/trip_evidence_codec_test.dart -FlutterRoot D:/flutter/flutter`; RED chưa có codec, sau đó RED behavioral cases đúng nguyên nhân.
- [ ] GREEN: implement types/codec/validation, giữ v2 validator intact; envelope canonical deterministic, immutable deep copies và 1 MiB cho toàn envelope. `reviewed` web/user phải false, provenance dangling ở old v2 giữ legacy unknown, new envelope phải resolve đầy đủ.
- [ ] Verify: targeted PASS, v2 existing codec fixtures PASS, checksum đổi khi nguồn đổi nhưng document giữ. Old legacy plan v1 đi adapter hiện có trước wrap, không bắt envelope decoder nhận mọi JSON v1.
- [ ] Review/checkpoint: proposed `feat(evidence): add versioned source envelope`; không auto modify remote payload.

## A2 — Lưu/read evidence atomically, UI xem căn cứ

**Depends:** A1, C5.
**Modify:** editable remote/local records, repository/service/store/schema codecs; ManualPlannerProvider, save preview/detail; server validation mới trong additive migration. Existing head/view records giữ document getter cũ và thêm optional `TripEvidenceEnvelope? evidenceEnvelope`; payloadText/contentDigest/version phủ toàn envelope. Khi mở legacy v2 thì optional này null; không parse toàn envelope bằng v2 codec.
**Create:** `lib/features/trip_planner/presentation/widgets/evidence_details_sheet.dart`, `test/trip_evidence_repository_test.dart`, `test/trip_evidence_ui_test.dart`, `supabase/tests/trip_evidence_contract.sql`. Migration tên mới dưới `supabase/migrations/` theo timestamp thực tế lúc implement, không ghi đè migration cũ.

**Interfaces NEW:** repository `Future<EditableMutationReply> saveEvidenceAccount({required TripEvidenceEnvelope envelope, required List<EditableCommand> commands, EditableHead? base, String? requestId})`; service/RPC version mới create/update/read/mutation status `create_evidence_trip_v1`, `update_evidence_trip_v1`, `get_evidence_trip_v1`, `get_evidence_mutation_v1`. SQL argument requestId/version/requestText/requestDigest giữ pattern v2. Shared trip list phải nhận `evidence_v1` discriminator ở endpoint list version mới `list_owned_trips_v3`, vẫn gồm v1/v2 old kinds. Delete evidence trip qua `delete_evidence_trip_v1` cùng owner/version guard. Client chuyển sang list v3 chỉ khi capability supported; server unavailable báo deploymentBlocked, không fallback write bỏ evidence.

Server tái sử dụng transaction engine hiện có, giữ transaction request-id receipt/idempotency và expected version; validate nested v2 bằng rule cũ, toàn envelope bằng rule mới. Commands replay vẫn áp trên nested document; validate envelope.source bindings/claim refs riêng. Update request dùng cả envelope digest và document commands, evidence thay đổi cũng đổi version; không hai writes riêng document rồi evidence. Local pending attempt chứa full envelope, retry exact frozen request.

**UI:** `EvidenceDetailsSheet({required List<EvidenceRecord> records, required EvidenceClaim claim})`; URL mở theo thao tác bằng capability có sẵn; nếu cần dependency mới phải đưa vào diff duyệt, không thêm tùy tiện. UI trả nguồn/time/status/limitations, không thực thi arbitrary HTML nguồn.

- [ ] RED: create→read→update→read→delete evidence giữ nguồn; save timeout→retry một record; thiếu capability không remote fallback v2; sửa một source làm digest/version đổi; legacy v2 được list/read cùng envelope; cross-account read/status/update/delete denied. New UI sheet nguồn thật từ fixture, unknown checkedAt không render “đã kiểm hôm nay”.
- [ ] Run new targeted repository/UI tests, disposable SQL test theo admin/planner harness sau khi bổ sung runner. Kiểm v2 codec, owner/RLS allow+deny và existing list classifications.
- [ ] GREEN: additive endpoints/reader/local wrapper, giữ old endpoints và data. Snapshot source lấy từ backend registry A3 cho generated results, không tin client `reviewed=true`; user-origin editable metadata không được phép nâng trust. Server có cùng rule với codec. Nguồn mới origin catalogue phải resolve từ exact public version; nguồn AI/web mới đối chiếu finalized request receipt thuộc chính account (evidenceRequestId), không tin reviewed flag/URL client. Nguồn đã nằm trong base version được giữ snapshot immutable; user edit dữ kiện phải gỡ/đánh dấu lại citation, không sửa fact rồi giữ trust. Receipt mới hết hạn trước lần save đầu trả `evidence_expired`, không hạ xuống v2 write hoặc nâng trust. Khi A3/W2 chưa có, dùng fixture/evidence do server integration test dựng; từng nhánh chỉ bật sau resolver/provider sở hữu evidence đó sẵn sàng.
- [ ] Verify: targeted + Full + SQL disposable PASS. Rollout order: backend additive approved→capability readback→new app→feature on; không rollback app bằng cách drop schema/new trips. Runtime chưa deploy ghi LIVE NOT RUN, không báo remote evidence đã xong.
- [ ] Review/checkpoint: proposed `feat(trips): persist evidence with versioned mutations`; reviewed diff/RPC contracts trước xin apply staging, không tự deploy SQL.

## A3 — Backend catalogue resolver và context dùng chung

**Depends:** A1/A2 và C7 public pipeline. Model tests có thể chạy trước deployment.
**Create:** `supabase/functions/itinerary-proposal/catalogue-evidence.mjs`, `test/catalogue_evidence_resolver_test.mjs`; `lib/features/trip_planner/models/ai_evidence_context.dart`, `test/ai_evidence_context_test.dart`.
**Modify:** itinerary gateway/index, context builder generation/assistant, main public snapshot wiring, runner AI.

**Interfaces NEW:** JS `resolveCatalogueEvidence({projectOrigin,destinationId,dates,expectedVersion,fetchImpl,clock}) -> Promise<{status,version,digest,places,evidence}>`; statuses `ready|catalogue_changed|insufficient|unavailable`. Input origin do config trusted cấp, không lấy từ user. Dates là list YYYY-MM-DD theo timezone trip; match exact public manifest/bundle version và digest bằng existing projection rules. Không nhận giá/giờ/review flag do request tự chứng nhận.

Dart `AiEvidenceContext` chứa `destinationId`, `catalogueVersion`, `List<String> dates`, `int numPeople,budgetVnd`, `List<String> interests`, `BudgetTotals budget`, `String baseDigest`; `toJson()->Map<String,Object?>` dùng fields allowlist. `BudgetTotals.estimateRemaining` khác `actualRemaining`; `unknownEstimateCount>0` phải truyền để AI không hứa đủ tiền. App gửi IDs/context; server bổ sung trusted sources. Giữ selectedDay scope rõ, không auto gửi notes/email/ledger.

- [ ] RED: resolver trả version mismatch → catalogue_changed/zero Gemini calls; public bundle digest sai → unavailable; catalogue thiếu → insufficient/zero auto web; dates khác mùa trả openingWindows đúng; client forged reviewed flag bị rejected/ignored, không tới prompt như fact đáng tin. Test request chỉ chọn ID, không còn payload tự chứng nhận trust.
- [ ] Run `node --test test/catalogue_evidence_resolver_test.mjs`; targeted `test/ai_evidence_context_test.dart`; trước resolver code mới expected RED, existing static tests không gọi network thật.
- [ ] GREEN: reuse fixed-origin storage pipeline, map source IDs→EvidenceRecord, chỉ lấy data liên quan; unknown giữ unknown. Xử lý stale source và effective dates không bằng fetchedAt. Inject fetch/clock cho fixtures, không cache source thiếu metadata.
- [ ] Verify: Node tests PASS, fields gửi model đúng ngân sách/ngày/traveler, unknown/conflicting source không thành verified; gateway auth/quota tests vẫn PASS. Source độc hại trong catalogue là data không instruction; chỉ trusted prompt code quyết schema.
- [ ] Review/checkpoint: proposed `feat(ai): resolve catalogue evidence on backend`; ghi ngày/giá/nguồn nào đi tới provider, không gọi local-only grounding là full pipeline.

## A4 — AI tạo lịch trên bản trống, có căn cứ

**Depends:** A1–A3.
**Modify:** ai_generation_service.dart, ai_generation_preview.dart, manual_planner_screen.dart, gateway.mjs generation branches; source claims UI shared và provider envelope dispatch.
**Tests:** `test/ai_generation_test.dart`, `test/itinerary_gateway_test.mjs`; NEW `test/ai_generation_evidence_test.dart`.
**Interfaces NEW:** `bool canGenerateWholeTrip(EditableTripDocumentV2 document) => document.items.isEmpty` trong generation service; `AiGroundedProposal` gồm existing `AiItineraryProposal proposal`, `List<EvidenceRecord> evidence`, `List<EvidenceClaim> claims`, `String baseDigest`. Provider contract mới `travelgo.itinerary.evidence.v1`, mọi activity catalogue có placeId+evidenceIds; giữ v1 gateway reader cho stored receipts cũ. Shared parse output kiểm claim IDs registry A3, không model-generated URL.

- [ ] RED: `whole_trip_generation_rejects_nonempty_document`, `cancel_keeps_document_digest`, `applied_proposal_keeps_sources_after_readback`, `late_owner_result_never_applies`. Mã địa điểm lạ/claim ref ngoài registry/out-of-hours known phải fail; thiếu giá stays null/warning; đổi ngày thực sự đổi provider context.

```dart
expect(canGenerateWholeTrip(emptyDocument), isTrue);
expect(canGenerateWholeTrip(documentWithOneActivity), isFalse);
// Trong widget fixture inject gateway spy: nonempty → calls=0.
// Hủy preview: envelope digest trước/sau bằng nhau; confirm: exactly 1 apply.
```

- [ ] Run new generation evidence test + existing ai_generation; Node itinerary contracts, RED đúng gate/source mất.
- [ ] GREEN: enforce gate cả UI lẫn service; request source version/dates; backend resolver trước Gemini; validate output schema/allowlist/time/money; preview Xem căn cứ. Giữ stamps owner/editor; apply cập nhật envelope registry+document atomically, save riêng.
- [ ] Verify: lookup unknown destination offer self-plan/web choice (web chưa enabled nếu W2 chưa xong), no hidden call; repeated confirm idempotent UI; no stale source/account; roundtrip A2 giữ URLs. Full/gateway PASS; live Gemini sample ghi riêng theo quyền gọi.
- [ ] Review/checkpoint: proposed `feat(ai): create sourced catalogue itineraries`; nếu provider ra output sai giữ nguyên draft, không lịch giả.

## A5 — Tư vấn và sửa hoạt động dùng cùng evidence

**Depends:** A1–A4. Giữ assistant recommendations hiện có nếu phục vụ tư vấn/sửa, không phát triển chatbot tổng quát.
**Modify:** ai_assistant_service.dart, ai_assistant_preview.dart, gateway assistant schema/prompts, manual editor/mutator/validator khi cần; tests assistant/grounding.
**Create:** `test/ai_assistant_evidence_test.dart`.
**Interfaces:** `AiEvidenceContext` A3 dùng lại; assistant context thêm `scope=day|trip` và chỉ activities relevant. Mọi response `travelgo.assistant.evidence.v1` gồm intent, summary, claims/evidence refs và operations (rỗng với advice); modify target existing item IDs. Source registry do server attach, provider chỉ chọn IDs. Existing `prepareAiModification` là nơi kiểm toàn document sau operations; không tạo engine thứ hai.

- [ ] RED: tư vấn budget fixture C5 nhận knownEstimate=250000/actualTotal=70000 và 2 remaining khác nhau; advice preserves digest; reorder A 09–10 qua B 11–12 thành A 13–14 → B trước A, no overlap. Modify giữ notes/actual, đổi bản chất activity báo estimateReviewRequired. Late response/draft changed/account changed không apply. “đi cùng mẹ” không tự thêm thuộc tính elderly vào structured context.
- [ ] Run new evidence test + `ai_assistant_test.dart`, `ai_assistant_grounding_test.dart`, Node itinerary contracts. Năm input/failure Review Focus trong master có case tương ứng, không chỉ happy path.
- [ ] GREEN: scope/ràng buộc từ user gửi đúng, questions thiếu dữ kiện có clarification/unknown, không mutation; modify preview change diff + refs + ack dự toán; ghi chú không gửi AI vẫn phải giữ khi apply. Giữ protection sửa actual expenses ngoài scope AI.
- [ ] Verify `advice.operations=[]`, hủy giữ digest, confirm 1 atomic editor update, save/readback evidence A2. Không quảng bá cả-trip nếu chỉ selectedDay context; test whole-trip request bounded list không truncation âm thầm. Full/gateway PASS, live advice/modify riêng NOT RUN cho tới thử.
- [ ] Review/checkpoint: proposed `feat(ai): ground itinerary advice and edits`; source cũ sửa reorder/duplicate không làm lại nếu regression đã GREEN.

## Self-review / handover

A1 định nghĩa type/schema, A2 lưu và read/UI, A3 trusted retrieval/context, A4 generate, A5 advice/modify. Không dangling future type hoặc tác vụ web tự chạy. Nếu A2 additive RPC chưa rollout, A4/A5 local có thể test fixtures nhưng remote writes không bật. Chưa có task được tick; mọi assertion là mục tiêu test, không kết quả thực.


## Nhật ký duyệt — 24/10/2026

Owner đã trả lời **“duyệt”** cho R2 trong chat. Phê duyệt bao gồm master và ba plan con, không phải nghiệm thu code hoặc cấp quyền thao tác live ngoài phạm vi. Các checkbox vẫn chưa tick. Handoff đầu tiên là C1 theo workflow Antigravity implement/Codex review.
