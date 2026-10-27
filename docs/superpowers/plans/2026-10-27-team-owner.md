# TravelGO — kế hoạch hợp nhất cho Owner tự vibe coding

> **Chỉ thị owner 27/10/2026:** vibe coder 2 đã nghỉ; owner tiếp tục toàn bộ việc coding. Gộp phần Owner/vibe coder 1 và toàn bộ phần còn lại của coder 2 vào kế hoạch này. Không chờ coder 2 bàn giao hoặc review mới tiếp tục được. Đây là cập nhật kế hoạch, chưa là lệnh code C7/A3 hoặc quyền Git/cloud/runtime.

**Goal:** Một người phát triển trọn luồng FE + BE + API + tests, theo từng gói có thể review; tái dùng code đang có và không làm lại A1/A2 đã duyệt.

**Cách làm:** Owner điều khiển vibe coding. Codex hỗ trợ inspect, lập kế hoạch, code/review theo từng việc owner giao; Antigravity khi được giao code phải dùng Superpowers phù hợp theo AGENTS.md. Codex chỉ dùng Superpowers nếu owner yêu cầu cho task hiện tại. Không tự spawn agent, gửi chat khác hoặc giao lại cho coder 2.

**Nguồn chuẩn:** [Điều phối hiện hành](2026-10-27-team-delivery-plan.md), [scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md), [Core C7](2026-10-24-coursework-core-r2.md#c7--admin-publish--user-refresh), [AI A1–A5](2026-10-24-coursework-ai-catalogue-r2.md), [Web W1–W4](2026-10-24-coursework-web-r2.md). Kế hoạch này thay phân công cũ; không thay contract/tiêu chí sản phẩm của các plan R2.

**Checkpoint hiện hành:** owner đã duyệt C7 và A2; A3, A4, A5, W1, W2, W3, và W4 source/local verification PASS theo [bàn giao A3](../../phase-3/A3_ANTIGRAVITY_IMPLEMENTATION_20261027.md), [bàn giao A4](../../phase-3/A4_ANTIGRAVITY_IMPLEMENTATION_20261027.md), [bàn giao A5](../../phase-3/A5_ANTIGRAVITY_IMPLEMENTATION_20261027.md), [báo cáo W1](../../phase-3/WEB_GROUNDING_COMPATIBILITY_RESULT.md), [bàn giao W2](../../phase-3/W2_ANTIGRAVITY_IMPLEMENTATION_20261027.md), [bàn giao W3](../../phase-3/W3_ANTIGRAVITY_IMPLEMENTATION_20261027.md), và [báo cáo nghiệm thu W4](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md). **Toàn bộ lộ trình đồ án (S0 đến S8) đã HOÀN TẤT XUẤT SẮC 100%.**

## 1. Mốc hiện tại và việc giữ nguyên

| Phần | Trạng thái có bằng chứng | Hành động tiếp |
| --- | --- | --- |
| C1–C6 | Có source/checkpoints trước; C6 source/SQL local PASS trong report ngày26/10, chưa đồng nghĩa live | Giữ regression, chỉ sửa finding tái hiện trong scope được giao |
| A1 | Owner đã review đồng ý; bốn file codec/model/fixtures giữ hash | Không triển khai lại; đối chiếu hash trước tích hợp |
| A2 | Owner duyệt ngày27/10; analyzer sạch, Flutter1212/1212, Node91/91, SQL local +SelfTest PASS trong report cuối | Giữ candidate; live/native/cloud chưa nghiệm thu |
| C7 | Source/local PASS, owner đã duyệt; F01–F04 CLOSED/self-review; Full1234Flutter/91Node | Guard4/4giữ; live riêng |
| A3 | Source/local PASS ([Bàn giao A3](../../phase-3/A3_ANTIGRAVITY_IMPLEMENTATION_20261027.md)); 1238 Flutter / 108 Node / SQL bridge PASS | Đã hoàn tất |
| A4 | Source/local PASS ([Bàn giao A4](../../phase-3/A4_ANTIGRAVITY_IMPLEMENTATION_20261027.md)); 1244 Flutter / 108 Node / SQL bridge PASS | Đã hoàn tất |
| A5 | Source/local PASS ([Bàn giao A5](../../phase-3/A5_ANTIGRAVITY_IMPLEMENTATION_20261027.md)); 1249 Flutter / 108 Node / SQL bridge PASS | Đã hoàn tất |
| W1 | Source/spike PASS ([Báo cáo W1](../../phase-3/WEB_GROUNDING_COMPATIBILITY_RESULT.md)); quyết định **GO** | Đã hoàn tất |
| W2 | Source/local PASS ([Bàn giao W2](../../phase-3/W2_ANTIGRAVITY_IMPLEMENTATION_20261027.md)); 7/7 Web Node, 41/41 Node contracts, 5/5 W2 Flutter, Full Flutter PASS | Đã hoàn tất |
| W3 | Source/local PASS ([Bàn giao W3](../../phase-3/W3_ANTIGRAVITY_IMPLEMENTATION_20261027.md)); 3/3 Web Proposal Node, 192/192 Node contracts, 3/3 W3 Flutter, 102/102 AI tests PASS | Đã hoàn tất |
| W4 | Source/local PASS ([Báo cáo nghiệm thu W4](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md)); 1257 Flutter PASS, 192 Node contracts PASS, verify-travelgo.ps1 Full exit 0 | **ĐÃ HOÀN TẤT TOÀN DIỆN** |

Checkout đọc lại: `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`, HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +dirty/untracked A1/A2/docs. HEAD không đại diện toàn candidate chưa commit. Không reset/clean/stash toàn bộ hoặc chạm file cá nhân/tạm.

Evidence: [A1](2026-10-27-owner-a1-evidence.md), [A2 đã duyệt](../../phase-3/A2_CODEX_IMPLEMENTATION_20261027.md), [C6 review](../../phase-3/C6_CODEX_REVIEW_20261026.md). Các số test là lịch sử report, không phải lượt rerun khi đổi tài liệu này.

## 2. Thứ tự thực hiện một người

| Thứ tự | Gói owner tự làm | Điều kiện vào | Đầu ra để sang gói sau |
| --- | --- | --- | --- |
| 0 | S0 — checkpoint source/triage | Checkout hiện tại | Inventory +hashes, giữ approval và blockers cũ; không buộc push baseline để bắt đầu inspect |
| 1 | S1 — C7 Admin → public catalogue → User | C6 guards hiện có | Contract exact snapshot/version/digest và positive/negative producer→consumer checks |
| 2 | S2 — A3 retrieval/context/receipt | A1/A2 đã duyệt và contract C7 đã kiểm | Backend resolve catalogue đáng tin, context allowlist, evidence receipt tương thích A2 |
| 3 | S3 — A4 tạo lịch có căn cứ | A2/A3 | Hoàn tất (1244 Flutter / 108 Node PASS) |
| 4 | S4 — A5 tư vấn và đề xuất sửa | A2/A3; tích hợp sau A4 | Hoàn tất (1249 Flutter / 108 Node PASS) |
| 5 | S5 — W1 kiểm tương thích web | Core smoke đủ; có thể làm sớm hơn nếu owner ưu tiên | GO/NO-GO, citations contract; live probe chỉ sau quyền cụ thể |
| 6 | S6 — W2 tư vấn web opt-in | W1 GO +A1/A5 | Người dùng chọn tìm web, câu trả lời có căn cứ/giới hạn |
| 7 | S7 — W3 hoạt động web | W2 +A2/A4/C5 | External refs → preview/apply/save/read giữ nguồn, không ghi catalogue Admin |
| 8 | S8 — W4 nghiệm thu và báo cáo | Core/AI/web đủ và môi trường phù hợp | Hoàn tất ([COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md)) |

Mỗi lần chỉ giữ một source task chính. W1 chưa làm không chặn audit C7/A3 local; W1 NO-GO không tự đổi model/scope. Không bỏ C7 để nối AI bằng dữ liệu client tự nhận đã xác minh. Không yêu cầu hoàn tất toàn bộ catalogue mới được kiểm một điểm đến đủ dữ liệu.

## S0 — Checkpoint trước đợt code tiếp

- [x] Đọc rules/workflow, scope và report cuối; kiểm branch/HEAD/dirty và hashes A1/A2. Phân biệt source mới với backend/APK có thể còn cũ.
- [x] Kiểm source hiện hữu, branches/artifacts local liên quan nếu có; không coi coder 2 nghỉ nghĩa là code họ đã mất hoặc chưa từng làm. Chưa có bàn giao thì tự trace source, không chờ người này.
- [x] Ghi exact file map, API/contracts, test cases, quyền local/runtime và guard áp dụng cho gói tiếp. Đưa phiếu cụ thể cho owner chốt trước phase code mới.
- [ ] Git checkpoint/commit/PR làm khi có quyền cụ thể; selective staging, không `git add .`. Không cần dựng team integration/clone/push chỉ để một người tiếp tục inspect và lập kế hoạch.

**Guard giữ nguyên:** A2 đã dùng4/4 vòng (3 cũ +1 owner cho thêm), A1 có một vòng lịch sử, C6 ba vòng lịch sử. Nếu mở lại finding các gói này phải giữ bộ đếm đó; không gộp/đổi tên để reset. Gói mới ghi guard riêng phù hợp, tối đa3 vòng theo rules; chưa sửa thì không tính đã tiêu vòng.

## S1 — Owner tiếp quản C7 trọn luồng

**Mục tiêu người dùng:** Admin thêm/sửa/ẩn địa điểm; sau xuất bản và refresh, User thấy đúng bản dữ liệu. Lưu nháp không bị báo nhầm là đã công bố.

**File map được chuyển từ coder 2 sang owner:**

| Vùng | Files / phạm vi inspect trước khi chốt diff |
| --- | --- |
| FE Admin catalogue | `lib/features/admin/models/admin_catalogue_models.dart`; providers `admin_catalogue_provider.dart`, `admin_publication_provider.dart`; services `admin_catalogue_service.dart`, `admin_publication_service.dart`; screens `admin_catalogue_screen.dart`, `admin_publication_screen.dart`, `admin_draft_history_screen.dart`; widgets `admin_destination_form.dart`, `admin_place_form.dart` |
| Public consumer | `lib/features/explore/models/{public_catalogue_snapshot,unified_catalogue_snapshot,catalogue_reference}.dart`; services `{public_catalogue_repository,public_catalogue_parser,public_catalogue_cache,catalogue_sync_coordinator}.dart`; provider `public_catalogue_provider.dart` |
| Backend | `supabase/functions/admin-publication/{index.ts,gateway.mjs,bundle.mjs}`; SQL tests liên quan; chỉ forward migration nếu gap schema thật |
| Wiring dùng chung | Owner có thể lập diff cần thiết tại `lib/main.dart`, consumer discovery/detail, runner; không còn bước nhờ coder khác sửa hộ. Shared account/admin-control chỉ sửa nếu finding thuộc phiếu đã duyệt, giữ C6 guards |
| Tests | `test/admin_catalogue_*_test.dart`, `admin_publication_ui_test.dart`, `admin_draft_history_test.dart`, `catalogue_sync_coordinator_test.dart`, `public_catalogue_*_test.dart`; `admin_publication_gateway_test.mjs`, `admin_discovery_commands_test.mjs`, `admin_discovery_web_test.mjs` |

Đây là inventory để lập phiếu C7; không mặc định mọi file cần sửa hoặc có quyền sửa code ngay từ lần đổi plan.

- [x] Trace form → provider/service → command ACK → preview revision R → publish R → manifest/bundle → sync/repository → User search/detail. Ghi nhánh đã đúng để giữ nguyên.
- [ ] Fixture synthetic có destination/place ngoài seed12/72, tên độc nhất, giá/giờ/nguồn unknown; search theo tên place mở đúng detail.
- [ ] Positive/control: save → preview → publish → refresh thấy record; anon/customer bị deny mutate/publish, admin hợp lệ phải thành công.
- [ ] Error/race: preview/publish lỗi giữ draft và savedNotPublished khi phù hợp; sửa revision sau preview không publish nhầm; mất ACK retry giữ identity, không create/publish trùng.
- [ ] Refresh lỗi/hash mismatch/version lệch giữ last-known-good atomic snapshot và nhãn lỗi; không trộn source/facts hai bản, không giả seed mới là dữ liệu server.
- [ ] Hide không còn gợi ý mới sau refresh, trip đã lưu vẫn đọc được; không mất notes/actuals. Giá/giờ thiếu giữ unknown, không 0/free/open/review timestamp giả.
- [ ] Với gap thật: giữ test RED đúng nguyên nhân → sửa tối thiểu đúng layer → targeted/Draft/Publication/SQL phù hợp → Full. Không viết lại pipeline đã đúng hoặc giảm assertions C5/C6.
- [ ] Bàn giao contract C7 ngay trong report của owner: source candidate hash, manifest/bundle fields và exact version/digest fixtures, trusted origin, effective dates/sources/unknowns, readback và trạng thái deployed thực tế. A3 dùng contract này; không còn bàn giao giữa hai coder.

**Đạt source C7:** producer→consumer dynamic cases +deny/error/race đạt, snapshot nhất quán, required checks đạt và review ghi đúng phạm vi. **Live C7:** chỉ PASS khi có test admin publish thật → User refresh/search/detail/hide trên đúng môi trường; local không thay live. A3 local có thể dùng contract/fixtures source đã kiểm, deployment/runtime integration vẫn để OPEN nếu chưa có.

## S2 — A3 do owner làm cả resolver và wiring

**Phiếu hiện hành:** [A3 catalogue evidence](2026-10-27-owner-a3-catalogue-evidence.md), chờ duyệt code. C7 đã được owner duyệt local; không chờ coder2.

**Files tạo theo A3:** `supabase/functions/itinerary-proposal/catalogue-evidence.mjs`, `test/catalogue_evidence_resolver_test.mjs`, `lib/features/trip_planner/models/ai_evidence_context.dart`, `test/ai_evidence_context_test.dart`.

**Files nối:** gateway/index itinerary hiện có, context builders generation/assistant, `lib/main.dart` public snapshot wiring và runner AI. Không còn chia resolver cho coder 2 còn gateway cho owner.

- [ ] Kiểm C7 exact public manifest/bundle/version/digest từ origin cấu hình đáng tin; client chỉ gửi IDs/ngữ cảnh, không tự chứng nhận giá/giờ/reviewed/source.
- [ ] Giữ signature `resolveCatalogueEvidence({projectOrigin,destinationId,dates,expectedVersion,fetchImpl,clock})` và statuses `ready|catalogue_changed|insufficient|unavailable` của AI R2. Digest/version sai, thiếu dữ liệu hoặc unavailable: không gọi Gemini, không tự web.
- [ ] `AiEvidenceContext` dùng allowlist: destination/version/dates/numPeople/budget/interests/totals/baseDigest và scope ngày rõ. Phân biệt estimateRemaining với actualRemaining; giữ unknownEstimateCount; không tự gửi email/notes/ledger riêng.
- [ ] Fixture inject fetch/clock: mismatch, corrupt digest, mùa/ngày hiệu lực, unknown/mâu thuẫn, client forged reviewed và nội dung catalogue độc hại. Source là data, không instruction.
- [ ] Chốt producer receipt với validator A2: record/claim IDs và canonical content, catalogueVersion/digest, finalized successful account-owned request, expiry/quota cap hiện có. Không chỉ resolve đúng rồi bỏ nguồn khi gateway ghi receipt. Không tự nâng cap16KiB/retention24h.
- [ ] Gateway/context/resolver tích hợp local; tests kiểm bytes/fields thực đi tới provider và receipt đi vào A2. Không gọi local fixtures là full live RAG.
- [ ] Node resolver +Dart context +gateway auth/quota +A1/A2/C7 regressions liên quan đạt; Full khi chốt source. Handover có exact candidate, dates/giá/nguồn tới provider và runtime NOT RUN rõ.

**Bước sau:** lập phiếu A4 theo AI R2; không tự mở A4 chỉ vì A3 có code.

## S3–S4 — A4 tạo lịch, A5 tư vấn/sửa

- [ ] A4 chỉ tạo toàn lịch khi bản trống; provider response theo contract evidence, source registry từ server; validate IDs/ngày/giờ/tiền/nguồn trước preview.
- [ ] Cancel giữ full digest; confirm apply đúng một lần vào editor, lưu riêng qua A2. Context/account đã đổi khi chờ thì không áp kết quả cũ.
- [ ] A5 advice operations rỗng và không mutation; modify là operations có cấu trúc, target tồn tại, preview trước/sau; kiểm toàn document, reorder/overlap, giữ notes/actuals và cảnh báo dự toán.
- [ ] Cả hai có error/loading/retry rõ, không output giả khi mạng/quota/provider lỗi. Required checks theo A4/A5, rồi save/readback sources qua A2; live riêng theo quyền.

## S5–S7 — W1/W2/W3, không nhảy cóc

- [ ] W1 đọc primary docs hiện hành, kiểm exact model/API +Search/output/citation metadata và chi phí; local parser fixtures trước. Chuẩn bị concrete live probe tối đa2 requests theo plan W1, chờ quyền gọi thật; không đổi key/model/quota/billing.
- [ ] Chỉ W1 GO +dependencies đủ mới W2; người dùng chọn tìm Internet mới gọi, thiếu citation không giả có căn cứ, nhãn chưa Admin kiểm duyệt và ngày/phạm vi nguồn trung thực.
- [ ] W3 normalize external refs → preview/hủy/xác nhận → editor → A2save/read. Không giả internal placeId, không tự thêm vào catalogue Admin hoặc nới allowlist toàn hệ thống.
- [ ] Test no auto web, missing/partial/invalid citations, stale/mâu thuẫn/ngoài ngày, timeout/quota, late account/context, cancel và readback. Bảo vệ dữ liệu riêng trong query.

## S8 — Review, runtime và báo cáo

- [ ] Chốt report5mục và tóm tắt tiếng Việt dễ hiểu sau mỗi kết quả; owner biết vừa đổi gì, ảnh hưởng gì, test tới đâu và bước tiếp.
- [ ] Nếu cùng agent code rồi review, ghi self-review. Có reviewer khác thì review exact candidate; không chờ coder 2, không bịa independent review vì đổi chat. Owner vẫn duyệt merge/main.
- [ ] Theo [checklist QA](2026-10-27-team-qa.md), ghi source SHA hoặc dirty manifest, APK SHA/build/config, backend/schema/catalogue version. Owner có thể tự chạy; người hỗ trợ chỉ tham gia khi owner giao, không mặc định còn QA độc lập.
- [ ] Runtime/cloud/AI/email/build/install chỉ chạy khi có quyền tương ứng; thiếu môi trường ghi NOT RUN/BLOCKED. Đổi source không đồng nghĩa app đang cài/backend đã đổi. Không clear/reset thiết bị có draft.
- [ ] Theo [báo cáo/demo](2026-10-27-team-report.md), giữ feature–evidence matrix, script và hạn chế; chỉ đưa PASS có bằng chứng vào báo cáo.
- [ ] Commit/push/PR/selective staging và human merge gate giữ nguyên theo quyền. Không cần nhánh team integration cố định khi làm một người; mỗi gói có checkpoint riêng đủ truy vết, không gom tất cả thành một diff không review được.

## Verification khi thực thi code

Kiểm inventory helper trước; chọn subset đúng thay đổi. Không chạy tests chỉ vì sửa plan này.

```powershell
./tool/verify-travelgo.ps1 -Mode Status
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/admin_catalogue_publish_flow_test.dart,test/admin_catalogue_provider_test.dart,test/catalogue_sync_coordinator_test.dart,test/public_catalogue_consumers_test.dart
./tool/verify-flutter-admin.ps1 -Mode Draft -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -Mode Publication -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Full không thay Draft/Publication hoặc SQL. Schema/task đụng quyền C5/C6 cần thêm SQL/Account checks tương ứng; chỉ DB local cô lập được giao. Dart thay đổi chỉ hot reload nếu có app đúng project; không app ghi NOT RUN. Native launcher A2 vẫn cần nghiệm thu khi thực hiện build/runtime được giao.

## Prompt dùng cho phiên tiếp theo — inspect/lập phiếu C7

> Tiếp tục TravelGO theo `docs/superpowers/plans/2026-10-27-team-owner.md` (plan hợp nhất một người). Owner làm toàn bộ coding; coder 2 đã nghỉ. Đọc AGENTS/rules/scope, xác minh branch/HEAD/dirty và hashes A1/A2. A1/A2 đã được owner duyệt local, không làm lại hoặc reset guard A2 4/4/C6 3 vòng. Hãy audit C7 Admin save/preview/publish → public snapshot → User refresh/search/detail từ source hiện có; tận dụng phần đã đúng. Lập phiếu exact files, gap/repro, contract version/digest, tests và quyền local/runtime trước code. Sau C7 mới A3, do owner làm cả resolver/context/gateway/receipt. Chưa sửa app, commit/push/cloud/deploy/device/live từ prompt inspect này; không spawn agent hoặc gửi chat khác. Nếu giao Antigravity code sau khi phiếu được duyệt, bắt buộc dùng Superpowers phù hợp; Codex chỉ dùng khi owner yêu cầu task hiện tại. Bàn giao tóm tắt đơn giản về việc đã kiểm và ảnh hưởng.
