# TravelGO Web Grounding R2 Implementation Plan

> **For agentic workers:** ĐÃ ĐƯỢC OWNER DUYỆT. Chỉ thực thi các task owner cấp quyền; quyền dùng Superpowers cho plan không cấp tự động cho task/session sau. Không tự gọi API có phí, đổi model/quota/billing/deploy từ tài liệu này.

**Goal:** Tư vấn tìm web có nguồn khi catalogue thiếu, sau đó đưa đề xuất vào trip qua preview/xác nhận và lưu được căn cứ.

**Architecture:** Kiểm exact provider compatibility trước; dùng Google Search grounding metadata, không parse URL từ văn bản model. Reuse evidence envelope và validator từ catalogue plan. Người dùng chọn tìm web; web results không ghi vào catalogue Admin.

**Tech Stack:** Gemini REST hiện có qua backend; Flutter/Provider/Dio và evidence RPC từ A2. Không crawler/vector search.

**Spec:** [AI design](../../../.agent/ai-planner-design.md), [Product scope](../../../.agent/product-scope.md), [master R2](2026-10-24-coursework-r2.md), [catalogue plan](2026-10-24-coursework-ai-catalogue-r2.md). Global Constraints và Review Focus master áp dụng.

## W1 — Spike có giới hạn: model/API hiện tại có trả evidence dùng được không?

**Depends:** đủ core smoke, không cần đợi toàn bộ AI; ưu tiên sau C7 theo master nhưng có thể sớm sau C1 nếu owner chọn. Đầu ra là GO/NO-GO và payload/metadata contract, không production code hoặc triển khai tool.
**Read:** gateway.mjs/index.ts hiện tại, official Google Search docs và pricing/terms tại thời điểm probe.
**Create (docs only):** `docs/phase-3/WEB_GROUNDING_COMPATIBILITY_RESULT.md` khi task chạy; probe throwaway/fixture trong ignored `.dart_tool/`, không chèn code thử vào gateway đang deploy.

**Question:** exact `gemini-3.5-flash-lite` + v1beta `generateContent` + output format hiện tại có dùng Search và trả nguồn/claim mapping phù hợp không? Nếu tool+JSON không hỗ trợ, đâu là phương án ít thay đổi nhất có thể review riêng?

- [ ] Chuẩn bị request fixture không thông tin cá nhân: yêu cầu giờ mở cửa của một địa điểm có trang chính thức. Kiểm tool/model docs, UI attribution/search entry point, cost/quota units. Không đồng nhất “tool được khai báo” với search đã chạy.
- [ ] Local parser fixtures: có groundingSupports/chunks, không metadata, partial citations, invalid indices, Unicode text offsets. Xác định segment indexing theo docs/API thực; không cắt chuỗi Dart/JS theo một quy ước tự đoán.
- [ ] Chuẩn bị concrete probe để owner duyệt bước live cuối: tối đa 2 provider requests có mục đích khác nhau (grounded text; grounded JSON nếu docs cho phép), không retry tự động; giữ nguyên key/model/identity/quota. Nếu provider/permission không khả dụng thì NOT RUN/BLOCKED. Không đọc/in key, ghi prompt chứa dữ liệu riêng hoặc gọi hai request không cần khi câu trả lời đã đủ.
- [ ] Khi đã được cấp quyền, chạy probe và thu transport status, finishReason, citation metadata presence, source links, search dispatch evidence. Output JSON parse/schema nếu thử phải kiểm thực; text có link không tính như grounding metadata. Mẫu live là subset không chứng nhận mọi prompt.
- [ ] Báo GO chỉ nếu exact supported path, citations parse được và điều kiện UI/attribution/chi phí đã xác định. Nếu thiếu metadata ở một prompt, ghi kết quả ấy thay vì suy luôn không hỗ trợ. NO-GO: trình một phương án có tradeoff (tách search evidence→structured generation hoặc đổi supported configuration) để owner review; không tự chọn model mới/hai calls hoặc trừ quota gấp đôi. Giữ code probe là throwaway, không deploy.

**Handoff interface:** kết quả phải ghi `apiFamily`, `model`, supported request fields, response evidence shape, source/claim mapping, attribution UI, measured subset latency và billing/quota semantics có nguồn hoặc UNKNOWN. Chỉ sau GO mới W2. Không để câu “sẽ bật google_search” thay chứng minh tương thích.

Official references để kiểm lại khi thực thi:
- https://ai.google.dev/gemini-api/docs/generate-content/google-search
- https://ai.google.dev/gemini-api/docs/google-search

## W2 — Nhánh tư vấn web opt-in, có căn cứ

**Depends:** W1 GO và A1/A2/A5. Không cần remote mutate activity ở task này.
**Create:** `supabase/functions/itinerary-proposal/web-evidence.mjs`, `test/web_evidence_test.mjs`, `test/ai_web_advice_test.dart`.
**Modify:** gateway/index, runner AI, AI service/context/preview và evidence sheet. Nếu W1 xác nhận API khác exact current config phải có quyết định owner trước diff tích hợp đó.

**Interfaces NEW:** JS `normalizeGoogleGrounding({candidate,retrievedAt,destinationName,travelDates}) -> {evidence,claims,warnings}` dùng EvidenceRecord/EvidenceClaim A1; chỉ cite indices trong metadata provider, validate source URI schema. Không tạo publisher/checkedAt/publishedAt khi provider không biết. Returned citations/source handles có thể là redirect theo provider: lưu đúng link thực và label đúng, không tự bịa URL cuối; mở theo policy trình duyệt, không server-follow arbitrary untrusted addresses.

Request contract `travelgo.web.advice.v1`: `requestId`, `consent=true`, `context={destinationName,dates,numPeople,budgetVnd,interests,scope,baseDigest}`, `prompt`, `webConsent=true`; account/bearer tách khỏi prompt. Không serialize email/notes/ledger/traveler names ra search. Response `status=succeeded|insufficient_evidence|unavailable`, `summary`, `evidence`, `claims`, `warnings`, `baseDigest`; chỉ attach actual account context trong app, không nhận owner ID từ model. Không có operations trong response advice. Provider evidence được backend stamp evidenceRequestId và lưu trong finalized request receipt phục vụ A2 kiểm nguồn lúc save; client không được tự gắn trust. Receipt retention/cap phải kiểm trong W1/W2, hết hạn trước lần save đầu trả evidence_expired rõ ràng, không tăng quota hoặc lưu nguồn giả.

App `Future<AiWebAdviceReply> requestWebAdvice(...)` nhận context trên và existing workspaceCurrent authority; `AiWebAdviceReply` có exact response fields + validation. Scope/dates phục vụ search question, không gửi toàn bộ chi tiết hoạt động nếu câu hỏi không cần. Quota vẫn một logical request ID; dispatch/retry/receipts theo phương án W1 được duyệt, không đổi identity để né cap.

- [ ] RED: `no_web_dispatch_until_user_choice`, `empty_metadata_is_not_sourced`, `invalid_citation_index_rejected`, `stale_account_reply_never_publishes`, `seasonal_climate_is_not_day_forecast` và Unicode citation mapping. Gateway fake checks request không chứa email/actual ledger; advice no operations.

```js
// Fixture đã được W1 xác định metadata shape; không network thật.
const reply = normalizeGoogleGrounding({
  candidate: {content: {parts: [{text: 'Lời khuyên chưa có nguồn.'}]}},
  retrievedAt: '2026-10-24T12:00:00Z',
  destinationName: 'Đà Lạt', travelDates: ['2026-11-24']
});
assert.equal(reply.evidence.length, 0);
assert.equal(reply.claims.some(c => c.kind === 'fact'), false);
```

Climate claim xử lý bằng evidence type/date scope có cấu trúc; không dùng regex vài từ để giả định kiểm được nghĩa mọi câu. Nếu nguồn không cho đủ ngày hoặc kết luận chỉ do model diễn giải, nhãn limitation và không khuyên đổi ngày như một fact đã xác minh.
- [ ] Run `node --test test/web_evidence_test.mjs`; targeted `test/ai_web_advice_test.dart`; RED đúng unauthorized dispatch/metadata handling.
- [ ] GREEN: server tool opt-in, trusted provider metadata registry, UI Tìm thông tin Internet + Xem căn cứ + nhãn “Thông tin từ Internet, chưa được Admin kiểm duyệt”. Không tự mở link/fetch nội dung HTML. Source/model instructions không được override schema và auth. Missing/conflicting/stale evidence hiển thị limit, không fake official source. Attribution theo W1 GO.
- [ ] Verify: injected error/quota/timeout giữ draft, no silent retry/no hidden Google call; valid source opens UI action, link failures rõ; edited document/account while awaiting response không áp dụng/không publish kết quả gắn nhầm chuyến. Full + all new/old gateway tests. Live một advice có metadata thật riêng nếu được cấp quyền; thiếu live → LIVE NOT RUN.
- [ ] Review/checkpoint: proposed `feat(ai): add opt-in sourced web advice`; response chưa bao gồm apply button hoạt động.

## W3 — Web proposal → preview → apply/save/read, không catalogue mutation

**Depends:** W2 + A2/A4 + C5 free-text destination path.
**Modify:** AiGroundedProposal thêm externalPlaces/externalBindings từ A1 (default empty cho catalogue), provider web structured contract, trip preview/editor và envelope validation; source UI.
**Create:** `test/ai_external_trip_test.dart`, `test/web_proposal_gateway_test.mjs`; fixture external source không có thật chỉ dùng tests, nhãn rõ synthetic.

**Interfaces NEW:** request `travelgo.web.proposal.v1` reuse W2 consent/context; output `AiGroundedProposal` với external records/evidence; `prepareExternalProposal({required TripEvidenceEnvelope before, required AiGroundedProposal proposal, required String Function() newId}) -> TripEvidenceEnvelope`. Return candidate không trực tiếp save; validation/preview/stamp vẫn phải pass trước provider apply. Whole-trip generation cùng gate A4; add/edit/remove qua assistant scope, không tự overwrite existing trip.

Source binds từ grounding metadata đã nhận, không từ URLs sinh trong JSON. Những IDs cho hoạt động mới được cấp khi prepare, map externalBindings tới exact ID mới. Metadata resolver attach nguồn trước prepare; opaque names không tự làm catalogue ID.

- [ ] RED: Phú Yên chưa trong catalogue → manual destinationName giữ; chọn web → proposal with evidence → cancel digest không đổi; confirm → một apply, placeId null, externalBinding đúng; save/read giữ `origin=web,reviewed=false` và link; catalogue record count không thay. Missing facts không đổi giá null thành 0; claim source không support làm no apply hoặc unknown rõ theo field, không chỉ kiểm URL tồn tại.
- [ ] Run external Dart test + Node web proposal suite + evidence codec/repository tests; RED ở missing external binding/source persistence, không fake ID để test qua.
- [ ] GREEN: parse structured proposal theo exact W1 transport được duyệt; server validators/new RPC envelope giữ quyền/idempotency, external ref chỉ thuộc trip owner, không gọi admin-publication. UI trước/sau và cảnh báo unknown, ghi notes/actual/estimates đúng existing policy; không lưu lại toàn bộ search conversation.
- [ ] Verify: save/update/delete/retry, source snapshot cũ vẫn xem nhưng nhãn không thành fresh; A→B denied; preview context changed fails; quá 1MiB bị reject rõ. V1/v2/catalogue trips vẫn đọc. Full/new Node/SQL contract checks. Runtime với actual sourced proposal và readback riêng theo quyền deploy/call.
- [ ] Review/checkpoint: proposed `feat(trips): apply and persist sourced external activities`; không tuyên bố hỗ trợ toàn Việt Nam từ một case thành công.

## W4 — Nghiệm thu tích hợp và báo cáo môn học

**Depends:** C1–C7/A1–A5/W1–W3; nếu còn blockers giữ checklist OPEN, không tự miễn.
**Create:** `docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md` khi thực hiện, kèm exact source/backend/APK/device và từng case PASS/FAIL/BLOCKED/NOT RUN.
**Modify:** kịch bản demo cũ thành phiên bản mới hoặc tạo version mới, bỏ yêu cầu map/Decision Engine. Không sửa/xóa historical reports để mất evidence.

**Interfaces:** consume outputs tasks, không thay đổi app behavior để buổi demo có vẻ xanh. Nếu phát hiện lỗi, mở correction ở đúng task, test RED và review lại, giữ tối đa ba RCA rounds theo rules.

- [ ] Setup preflight: thiết bị trình bày, APK/source hash, backend source/version/flags, catalogue version, test account IDs đã được owner cho phép; còn bản nháp thì bảo toàn trước thao tác. Không clear/uninstall/reset hoặc đổi quota để demo.
- [ ] Run core: đăng ký/OTP/login/profile/logout và recovery email cold/warm; manual không catalogue, ngày/số người/budget→activities/estimates/actual→save→read→update→delete. Mất mạng/late replies/đổi account không lẫn dữ liệu. Xóa test trip qua UI có xác nhận.
- [ ] Run Admin: customer API denied, admin lock/unlock test identity; thêm/sửa/ẩn dynamic place→publish→User refresh đúng. Trip đã lưu không bị mất khi hide catalogue place.
- [ ] Run AI catalogue: generate blank→cancel→generate/confirm→advice không mutation→modify preview/cancel/confirm→save/read căn cứ. Source/date/giá đúng, unknown có nhãn. Đếm provider call/retry thực tế không hidden loops.
- [ ] Run web: unsupported destination/data→explicit web choice→advice cites true source→proposal preview→apply/save/read; no Admin catalogue insertion. Empty citations và source ngoài date range có limit, không lời khuyên chắc chắn vô căn cứ. Source link UI mở đúng và Google attribution theo W1.
- [ ] Verify automated final source một lần: Full helper; admin All/disposable checks nếu source liên quan; new web/evidence suites trong runner. Thu actual exit/log, không tái dùng counts source cũ. Android rebuild nếu native/deps đổi; iOS không môi trường ghi NOT RUN.
- [ ] Report/handoff: mốc M1/M2/M3/M4 có evidence, lỗi mở và ảnh hưởng demo, phần chưa chạy, owner merge gate. Proposed docs commit `docs(demo): record coursework acceptance` chỉ theo quyền hiện hành. Không merge/publish tự động.

## Self-review / handover

W1 là spike chưa chạy; W2 chỉ advice; W3 mới mutation; W4 integration. Có metadata không đồng nghĩa mọi câu có support. Không ép thời tiết vào scope widget/API riêng. Khi W1 NO-GO, report đầy đủ để owner quyết định thay configuration hay scope, tiếp tục core/catalogue độc lập. Không coi sample probe là evidence cho mọi điểm đến hoặc nguồn.


## Nhật ký duyệt — 24/10/2026

Owner đã trả lời **“duyệt”** cho R2 trong chat. Phê duyệt bao gồm master và ba plan con, không phải nghiệm thu code hoặc cấp quyền thao tác live ngoài phạm vi. Các checkbox vẫn chưa tick. Handoff đầu tiên là C1 theo workflow Antigravity implement/Codex review.
