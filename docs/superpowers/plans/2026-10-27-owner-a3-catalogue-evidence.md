# A3 — Backend truy xuất catalogue và ngữ cảnh AI có căn cứ

**Trạng thái:** phiếu triển khai sau khi owner duyệt C7 ngày27/10/2026. Chưa code A3, chờ duyệt phiếu cụ thể. Owner tự vibe coding cả resolver/context/gateway/receipt; không chờ coder2. Codex không tự dùng Superpowers/delegation; Antigravity khi được giao code phải dùng Superpowers phù hợp theo AGENTS.md.

**Goal:** Backend tự lấy đúng catalogue đã xuất bản, kiểm version/hash, chọn dữ liệu liên quan cho AI và lưu registry căn cứ vào receipt mà A2 có thể xác thực. Không coi dữ liệu giá/giờ/reviewed client gửi là nguồn đáng tin.

**Architecture:** Tái dùng public pipeline C7, gateway Gemini, account/quota reserve/finalize và persistence A2. Structured retrieval theo destination/place/date; không vector DB/framework/dependency mới. A3 làm nền backend/context/receipt; A4/A5 mới hoàn thiện output/UI tạo lịch/tư vấn/sửa có dẫn chứng.

**Nguồn chuẩn:** [scope](../../../.agent/product-scope.md), [AI design](../../../.agent/ai-planner-design.md), [AI R2 A3–A5](2026-10-24-coursework-ai-catalogue-r2.md#a3--backend-catalogue-resolver-và-context-dùng-chung), [owner plan](2026-10-27-team-owner.md), [A2](../../phase-3/A2_CODEX_IMPLEMENTATION_20261027.md), [C7 owner duyệt](../../phase-3/C7_CODEX_IMPLEMENTATION_20261027.md).

## 1. Prerequisite đã kiểm và hiện trạng source

- Owner đã duyệt A1, A2 và C7. C7 report: analyzer sạch/Flutter1234/Node91, Publication/Draft/SQL/local checks đạt; owner approval không phải independent review hoặc live acceptance.
- Checkout `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`, base HEAD `0d7b95afaf183ede2053dd02ad6566bd4528b3ec` +dirty/untracked A1/A2/C7/docs. HEAD không chứa toàn candidate; phải đối chiếu manifests trước code, không reset/clean/stage tất cả.
- C7 public snapshot có version, SHA-256, manifest, catalogue/visits cùng bản, fetchedAt và optional raw payloadText. Manifest/bundle là `travelgo.discovery.manifest.v2`/`travelgo.discovery.release.v2`; bundle tối đa2MiB, Storage key `releases/v2/<version>.json`.
- Gateway hiện dùng `travelgo.itinerary.v1` / `travelgo.assistant.v1`. Generate gửi destination/numDays/people/budget/interests, chưa gửi ngày cụ thể/version/digest. Assistant gửi places/openingWindows/routes từ context client. Grounding Dart hiện có không thay cho backend retrieval đáng tin.
- `safeEnvelope`, `validateProposal`, `validateAssistantResult` đang strict keys. Không được thêm evidence vào result v1 rồi giả định reader cũ sẽ đọc được.
- A2 chỉ nhận proof từ finalized account-owned receipt có result.contract thuộc evidence contracts đã chốt, `evidence`/`claims` khớp canonical, `catalogueVersion` là String và `catalogueDigest` là64hex. Receipt v1 không có registry không đủ proof.
- SQL quota hiện nhận object result tối đa16KiB theo JSONB text, retention24h. Không tự nâng cap/quota/retention hoặc tạo loại AI request độc lập chỉ để cấp proof.
- `BudgetTotals` hiện có knownEstimate/unknownEstimateCount/actualTotal/estimateRemaining/actualRemaining; sử dụng lại. Source `checkedAt` thiếu đã được C7 giữ unknown.

**Giữ guard:** C7 4/4, A2 4/4, A1 một vòng và C6 ba vòng lịch sử. A3 task mới dùng0/3 vòng; không mở lại correction task cũ hoặc reset bằng đổi tên. Không commit/push/PR/merge/cloud apply/deploy/AI/email/build/install/device từ phiếu local này.

## 2. Quyết định triển khai

### 2.1. Truy xuất phía server, giữ hợp đồng legacy

Resolver phải chạy với origin từ cấu hình trusted của gateway. Client chỉ chọn destination/place IDs, dates và expected catalogue identity; không nhận origin/URL catalogue, source URL, reviewed flag hoặc giá/giờ do client tự khai làm authority.

Giữ đường v1 và stored receipts v1 cho caller cũ. Đường catalogue evidence dùng **hai contract đã có trong R2/A2 allowlist**: `travelgo.itinerary.evidence.v1` và `travelgo.assistant.evidence.v1`. Request/result được dispatch bằng contract rõ ràng, không tùy tiện mở rộng strict JSON v1. Không fallback write v1 làm mất nguồn.

A3 cung cấp parser/builder/resolver/receipt và wiring nội bộ có tests. Không bật CTA evidence mặc định trong app hoặc feature trên môi trường thật từ A3. A4/A5 sẽ gắn UI/typed proposal/operations và claim refs tương ứng rồi mới nghiệm thu luồng người dùng. Không tuyên bố A4/A5 hoàn thành chỉ vì wrapper receipt đã có.

### 2.2. Interface resolver

Giữ interface R2:

```text
resolveCatalogueEvidence({projectOrigin,destinationId,dates,expectedVersion,fetchImpl,clock})
  -> {status,version,digest,places,evidence}
status = ready | catalogue_changed | insufficient | unavailable
```

Boundary gateway đối chiếu thêm `expectedDigest` của client sau khi resolver trả digest đã tự tính; không tin digest client như proof. Version wire String canonical số nguyên dương, map lossless từ public version. Version/hash thay đổi đều trả `catalogue_changed`; không ghép facts hai release.

- Fetch manifest tại fixed origin, rồi object key allowlist trong bucket hiện có. Chặn redirect, origin khác, credentials, malformed key, sai schema, vượt byte cap, sai raw UTF-8 SHA/length, bundle/manifest version không khớp. Kiểm origin trước dùng service credentials; không gửi service token tới URL client.
- Inject fetch/clock cho fixtures; giới hạn timeout và đọc body có bound. Không thêm vòng tự gọi provider/search.
- Chọn destination còn active và places trong snapshot đó. Hidden/không tồn tại không biến thành known place bằng dữ liệu client. Không giới hạn12destination/72seed; giữ giới hạn request hiện hành và báo rõ nếu lựa chọn vượt khả năng xử lý, không bỏ tùy tiện place đang được dùng.
- `ready` nghĩa là có dữ liệu tham chiếu tối thiểu hợp lệ để dựng context, không có nghĩa mọi giá/giờ đều verified. Destination/place không có thì `insufficient`; lỗi mạng/hash/schema thì `unavailable`. Khi chỉ thiếu giá/giờ, giữ unknown nếu context còn dùng được; tests phải chốt positive control cùng các trường hợp không đủ dữ liệu.
- Ngày chưa được người dùng nhập giữ unknown, có thể dates rỗng; không thay bằng hôm nay. Effective dates, thứ/ngày/giờ đóng/mở và pricing basis áp dụng đúng ngày/số người bằng logic xác định; tham khảo R1–R5 grounding đã có, không tự dùng preparedAt làm ngày kiểm nguồn.
- Registry IDs ổn định trong request và exact release, tham chiếu tới dữ kiện/source thật. Tách fact được catalogue hỗ trợ khỏi inference/unknown; không gắn câu AI tự viết thành fact nếu không có mapping tương ứng.

### 2.3. Ngữ cảnh dùng chung trên Dart

Tạo `AiEvidenceContext` theo R2: destinationId/catalogueVersion/dates/numPeople/budgetVnd/interests/BudgetTotals/baseDigest; bổ sung catalogueDigest để kiểm exact snapshot, scope `day|trip` và selectedDay khi cần. `toJson()` allowlist, immutable collections, số tiền an toàn, ngày và hash hợp lệ.

Factory nhận document +đúng `PublicCatalogueSnapshot`, tái dùng BudgetCalculator. Chỉ gửi IDs/ngữ cảnh cần thiết; activities cho scope đã chọn lấy từ document, không gửi email/token/ghi chú riêng hoặc toàn ledger. Budget là ngữ cảnh người dùng, server không dùng nó làm authority của giá catalogue.

Không thay các trường v1 hiện có khi caller không opt-in evidence. Generation/assistant builders có đường mới rõ contract; legacy tests phải giữ wire shape. Shared snapshot loader dùng cùng provider/repository đang cấp discovery; không tải thêm một catalogue seed độc lập khi đã có bản public. Nếu cần callsite wiring `main.dart`, chỉ nối loader/factory, chưa bật generation/assistant evidence UI.

### 2.4. Gateway, receipt và ranh giới A4/A5

- Auth/subject/account guards hiện có chạy trước external retrieval/provider; statuses không-ready phải chặn Gemini và không tự web. Quota/request reservation chỉ dùng cho request thực sự đủ điều kiện dispatch; không tạo AI receipt giả cho lookup thuần catalogue.
- Digest request phải bind intent/contract, context allowlist, catalogue version+digest, dates/scope và baseDigest. Retry cùng request ID không đổi snapshot thành release mới hoặc gọi Gemini hai lần. Receipt đã succeeded phải replay registry cũ; không re-fetch catalogue hiện tại rồi gắn lại vào kết quả cũ.
- Context gửi provider có facts từ resolver server; bỏ/không sử dụng client openingWindows/price/reviewed như facts authoritative. Route/time di chuyển không có căn cứ thì unknown; không đưa map/route engine trở lại scope.
- Receipt evidence contract mới chứa proposal/result có validator tương ứng, catalogueVersion/catalogueDigest/baseDigest và registry `evidence`/`claims` đúng A1/A2. Registry do server gắn; model chỉ được tham chiếu ID đã cấp, không sinh URL/source/review flag. Không chỉ gắn metadata vào prompt rồi bỏ nó khi finalize.
- A3 định nghĩa/kiểm registry và receipt core; A4/A5 hoàn thiện domain output/operation mappings và typed UI. Câu trả lời AI chưa có mapping không được nâng thành claim fact. Đường UI legacy vẫn mang giới hạn cũ, không được quảng bá là evidence mode đã bật.
- Chỉ finalize succeeded sau output/schema/registry validation và account recheck. Rejected/oversize/provider lỗi phải finalize failed hoặc báo outcome_pending đúng existing protocol, không success giả. Không tăng16KiB để chứa cả catalogue; chọn bounded subset trước provider, kiểm receipt trong SQL thật, vượt cap trả lỗi rõ.
- Status/safe-envelope reader phân biệt evidence contracts với legacy receipts. Giữ request namespace/idempotency/quota worker hiện có; không thêm queue/RPC finalize song song hoặc sửa migration A2. Catalogue proof mới phải qua validator A2 hiện có nguyên trạng.

## 3. Exact file map dự kiến

| File | Thay đổi |
| --- | --- |
| Tạo `supabase/functions/itinerary-proposal/catalogue-evidence.mjs` | Fixed-origin retrieval, integrity/schema checks, selection/date facts và registry |
| Tạo `supabase/functions/itinerary-proposal/catalogue-receipt.mjs` | Canonical evidence/claim/result wrapper, bounds và proof packaging theo A1/A2 |
| `supabase/functions/itinerary-proposal/{gateway.mjs,index.ts}` | Trusted origin/resolver injection, evidence contract dispatch/context/receipt; giữ v1 và existing guards |
| Tạo `lib/features/trip_planner/models/ai_evidence_context.dart` | Immutable shared context factory/allowlist từ document +public snapshot |
| `lib/features/trip_planner/services/{ai_generation_service,ai_assistant_service}.dart` | Builders/request codecs evidence path riêng; không bật UI A4/A5 |
| `lib/main.dart` | Nếu cần, inject shared snapshot loader/context factory; không đổi auth/navigation |
| Tạo `test/{catalogue_evidence_resolver,catalogue_receipt}_test.mjs`, `test/ai_evidence_context_test.dart`, `test/fixtures/catalogue_evidence_vectors.json` | Positive/deny/error/dates/unknown/injection/version/digest và parity |
| `test/{itinerary_gateway_test.mjs,ai_generation_test.dart,ai_assistant_test.dart,ai_assistant_grounding_test.dart}` | Contract/guard/legacy regressions đúng phần thay đổi |
| Tạo `supabase/tests/catalogue_evidence_receipt.sql` | Finalized gateway receipt → A2 save/read và negative controls trên DB cô lập |
| `tool/verify-travelgo.ps1`, `tool/verify-coursework-trips.ps1` | Thêm suites/fixture bridge cần thiết; không giả ModeAi/Full đã chứa tests mới khi chưa wire |

Read-only: A1/A2 code và migration, C7 producer/parser/cache và migration lịch sử, BudgetCalculator/grounding rules nếu đã đúng. Nếu thật sự cần đổi schema vì contract receipt mới không thể dùng quota pipeline hiện có, dừng ở diff/RED cụ thể trước mở phạm vi; không tự nâng cap hoặc sửa A2 validator để test xanh.

## 4. Các bước triển khai và kiểm chứng

### A3-0 — Freeze baseline / contracts

- [ ] Đối chiếu A1/A2/C7 manifests, owner approvals và guard; ghi A3 source-before manifest riêng, không reset/stash/stage dirty tree.
- [ ] Chốt request/result examples synthetic cho hai evidence contracts và legacy stored receipts; A2 validator không đổi. Kiểm các schema source/price/hours/claims thực tế trước code, không thiết kế theo tên field đoán.
- [ ] Kiểm primary docs/CLI hiện hành khi cần trong implementation; giữ runtime/config/model/key/quota hiện có. Không dùng approval plan để gọi live.

### A3-1 — Resolver RED → GREEN

- [ ] Fixtures chuẩn +dynamic IDs +all-hidden/empty +unknown/unchecked dates; manifest/bundle mismatch, invalid URL/origin/redirect/oversize và bad hash phải fail đúng nguyên nhân.
- [ ] Chứng minh changed/insufficient/unavailable có0Gemini calls và0auto web; field client giả reviewed/giá/giờ không tới provider như authoritative facts.
- [ ] Chạy Node RED trước implementation rồi GREEN; include fixture khác mùa/ngày, units/pricing basis, unknown price không thành0 và timestamp thiếu không thành hôm nay.

### A3-2 — Context / gateway / receipt

- [ ] Dart tests kiểm full vsselected-day scope, baseDigest/current snapshot, people/budget, remaining theo dự kiến khác đã chi, unknownEstimateCount và không gửi dữ liệu riêng.
- [ ] Node integration fake fetch ghi body thực tới Gemini; kiểm source text là data, ID refs allowlist, facts/date/version/digest đúng, model output không tự tạo proof.
- [ ] Pending/succeeded replay giữ request/registry cũ dù catalogue mới xuất bản; changed request/digest cùng request ID bị deny. Account bị khóa/đổi phiên trước finalize không succeeded. Legacy v1 tests giữ nguyên assertions/wire shape.
- [ ] Receipt assembler/schema và size tests; invalid source/claim/ref/URL, missing version/digest, cap16KiB và auth/quota negative có positive controls.

### A3-3 — Bridge SQL thật và bàn giao

- [ ] Runner tạo reserved AI fixture bằng SQL và xuất binding/worker synthetic cho Node fixture gateway. Node dùng catalogue/provider fake, ghi exact finalize args/result; SQL nhận lại các args đó, finalize bằng existing RPC rồi dùng A2 save/read envelope. Không chèn result bằng quyền fixture để gọi đó là proof gateway→receipt.
- [ ] SQL controls: wrong owner, not finalized/expired/missing registry, altered record/claim/ref, missing hoặc malformed catalogueVersion/catalogueDigest, over-cap; unchanged base evidence vẫn đọc được sau expiry. Gateway kiểm request version/digest đối chiếu trusted release; không giả định A2 tự xác minh lại toàn catalogue từ metadata receipt. Không dùng fixture privileged thay cho test authenticated A2 save.
- [ ] Targeted Dart +Node resolver/receipt/gateway → Full analyzer/Flutter/Node cuối → disposable SQL/runner SelfTest nếu đổi runner. Thu actual exits/logs/hashes; owned DB dừng xong.
- [ ] Runtime hot reload chỉ app đúng project đã kết nối; không app ghi NOT RUN. Source/local PASS không chứng minh live retrieval→Gemini→saved trip, backend apply hay APK.
- [ ] Handover5mục +owner summary dễ hiểu, exact hashes/diff scope, closure/review prompt và giới hạn. Self-review ghi đúng, giữ guard. Sau owner review A3 mới lập phiếu A4/A5; không tự triển khai web.

## 5. Tiêu chí hoàn thành A3 local

Resolver/context/gateway/receipt evidence path có tests và consumer contract rõ; sai identity hoặc thiếu catalogue không dispatch; không tin facts client; registry finalized theo đúng account và qua A2 nguyên trạng; legacy tiếp tục đọc; checks bắt buộc đạt và artifacts review được. Đường feature chưa rollout/consumer UI A4/A5 chưa bật phải ghi rõ, không gọi là RAG end-to-end đã nghiệm thu.

## Bàn giao lượt lập phiếu

**Changed:** ghi nhận owner duyệt C7; tạo phiếu A3 và cập nhật đường dẫn/trạng thái owner plan. Không sửa ứng dụng, backend, SQL hoặc quota/config.

**Why:** C7 cung cấp trusted publication; A2 đòi receipt có exact registry. A3 phải nối cả retrieval và finalized proof, không chỉ đưa catalogue vào prompt.

**Testing:** đọc actual source/context/quota/A2 validation, đối chiếu manifests/link tài liệu và diff-check. Không chạy lại Flutter/Node/SQL khi chỉ lập phiếu; số1234/91 là evidence C7 đã được owner review, không phải test A3.

**Problems:** live catalogue/backend version chưa xác minh; evidence contracts cần parser/receipt wiring riêng vì v1 strict keys. A3 chưa code; không có quyền live/Git/deploy mới.

**Lesson Candidate:** Source có trong prompt nhưng không nằm trong finalized receipt → không đủ proof khi lưu lịch → test phải đi từ bytes retrieval qua provider context/finalize đến validator A2, đồng thời giữ backward reader.
