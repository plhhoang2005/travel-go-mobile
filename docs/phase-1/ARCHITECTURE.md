# 06 — Kiến trúc hệ thống và tích hợp API

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**.
> Bộ thiết kế v1.1 đã được chủ dự án phê duyệt có điều kiện ngày **2026-10-08**; hồ sơ Phase 1 đóng. Xem [approval](APPROVAL.md) và [bàn giao](HANDOFF.md); Phase 2/3 chưa được phép triển khai.
> Baseline: S-MP (Master Prompt v1.0); đặc tả chưa chứng minh tính năng đã triển khai hoặc Phase 1 đã đóng.

## Baseline và hiện trạng

[CONFIRMED] Flutter/Dart, Android-first, Supabase, PostgreSQL, Hybrid AI, Windows, free-tier preference; offline Guest draft + read-only saved itinerary (S-MP §8.1). [PROPOSED] Thiết kế bên dưới là target logical architecture, không là migration hoặc thay thế code hiện hữu.

[OPEN] S-REPO có Flutter feature folders, backend/, Provider, Dio, fl_chart, supabase_flutter, flutter_map và weather service. Chưa xác minh runtime, schema deployed, permissions, keys hoặc coverage. ADR trong .agent/knowledge.md là quyết định ngữ cảnh cũ, không tự giải quyết OQ của baseline mới. DEC-007/008 xác nhận giữ/tái sử dụng phần phù hợp và Gemini proposal server-side; code/runtime compatibility tiếp tục cần audit.

## System context [PROPOSED]

```mermaid
flowchart LR
  G[Guest / Người dùng Android] --> F[Flutter presentation]
  F --> A[Application và domain rules]
  A --> R[Repository boundaries]
  R --> L[Local drafts / Owner-scoped snapshots]
  R --> S[Supabase Auth / CRUD có RLS]
  R --> E[Trusted server operations]
  E --> D[PostgreSQL transaction và authorization]
  E --> AI[Gemini - provider confirmed]
  E --> X[Places / routing / weather - OPEN]
  S --> D
  E --> V[Deterministic validation]
  V --> P[Proposal preview - chưa mutation]
```

[PROPOSED] Client không giữ secrets của AI/third-party server. Supabase publishable/anon key là định danh public project nếu được thiết kế cho client và bảo vệ bằng grants/RLS; khác với service_role/secret key. Nhận định README cũ “API Key có trong code” chưa đủ để kết luận an toàn hay lộ secret. [Tham khảo RLS chính thức](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Logical components và lý do tồn tại [PROPOSED]

| Thành phần | Trách nhiệm | Boundary và lý do |
| --- | --- | --- |
| Presentation per feature | Screens, timeline, budget, preview, loading/error/empty | Không đọc secret, không tự quyết quyền remote |
| Application use cases | Create draft, request AI, preview, confirm, migrate, save, load snapshot | Phối hợp domain và repository; tách saved khỏi draft |
| Domain rules | Dates/items, money/categories, proposal state, data quality | Cùng itinerary model manual/AI; unit-testable |
| Repository contracts | Auth, catalogue, trip, expense, AI, local | Phân biệt local/remote; không cần interface cho mọi widget |
| Supabase Auth + CRUD | Identity, profile own, catalogue public, private reads | Backend grants/RLS enforce mọi nested row |
| Trusted operations | Atomic itinerary write, AI request/apply, draft import, sensitive member actions | Không thể an toàn chỉ bằng client check nhiều requests |
| Provider adapters | Normalize AI/places/weather/routing output + metadata | Thay provider sau quyết định, không khóa core vào payload nhà cung cấp |
| Local persistence | Draft restart recovery, saved immutable snapshot | Không phát triển offline conflict sync engine |
| Extension boundary | Group/Community, Booking tương lai | Chỉ conceptual; không provision bảng/queue/service cho deferred |

[PROPOSED] Client validation giúp feedback; backend validation và database constraints là authority cho remote writes. Không sao chép MCDA/Pareto/Greedy engine hiện có vào UI; server giữ deterministic validation; existing engine nếu có phải được audit và adapter, không tự viết lại theo DEC-007. Local cost sums/timeline editing là thao tác nhẹ theo S-MP §10, không thay engine ranking.

## ADR register

| ID | Trạng thái; nguồn | Quyết định/ứng viên | Phương án khác và trade-off |
| --- | --- | --- | --- |
| ADR-P1-001 | [CONFIRMED]; S-MP §8.1 | Flutter/Dart, Android, Supabase/PostgreSQL | Không thay bằng backend/platform mới trong tác vụ này |
| ADR-P1-002 | [PROPOSED]; §8.2 | Feature-based presentation/application/data, repository pattern vừa đủ | Layer-first dễ khởi đầu nhưng khó tìm feature; deep Clean Architecture tăng ceremony không cần thiết |
| ADR-P1-003 | [PROPOSED]; §5.4; CF-003 | External model tạo candidate; structured data và deterministic server checks; engine hiện có qua adapter nếu được duyệt | LLM tự quyết toàn bộ thiếu tin cậy; chỉ LLM explainer không đủ generation/chat/modification baseline |
| ADR-P1-004 | [PROPOSED]; §8.3 | Ưu tiên tái sử dụng Spring backend cho sensitive orchestration [PROPOSED]; nguyên tắc server-only [CONFIRMED DEC-007/008]; atomic DB operation cho version/apply/import | Edge Functions là phương án dự phòng cần duyệt nếu hosting/tích hợp Spring không phù hợp; không tự thêm deployment thứ hai |
| ADR-P1-005 | [CONFIRMED]; DEC-005; OQ-007 | Giữ Provider hiện có | Không đổi Riverpod/BLoC trong baseline; organization use cases vẫn PROPOSED |
| ADR-P1-006 | [CONFIRMED] SQLite DEC-005; [OPEN] package | SQLite lưu Guest drafts và saved read-only snapshots | Package/driver/schema migration strategy cần validation; không cài đặt trong Phase 1 |
| ADR-P1-007 | [PROPOSED]; BR-005/018 | Separate immutable AI proposal, base_version, preview digest, atomic apply | In-place AI mutate có thể mất confirmed itinerary; auto-merge tăng độ phức tạp |
| ADR-P1-008 | [CONFIRMED] provider DEC-002; [OPEN] model | Gemini là provider chính cho generation/chat/recommendation/modification | Model/account quota/eligibility cần thử; không triển khai multi-provider MVP tự động |
| ADR-P1-009 | [OPEN]; OQ-008/012 | Map/weather provider chờ PoC và điều kiện | Dependency hiện có chỉ là evidence; không tự gọi đó là lựa chọn được duyệt |

## Hybrid AI pipeline và state [PROPOSED]

1. Gateway kiểm tra session hoặc Guest token, quota, input size và trip access khi có trip ID.
2. Server lấy structured catalogue; normalize provenance từng price/hours/coords/travel/weather field. Chỉ gửi phần preferences/trip tối thiểu, không gửi email, password, token hoặc toàn bộ private profile.
3. Provider tạo candidate qua contract logic: schema_version, request_id, days/items, references, estimates, rationale và warnings. Đây là contract ứng dụng đề xuất, không endpoint provider được bịa ra.
4. Validator kiểm tra schema/type/range, dates/day membership, item identity/reference, overlaps/travel feasibility khi có dữ liệu, known opening hours, budget/sở thích. Ngoài budget là warning theo BR-008.
5. Invalid hard constraints → rejected output và lỗi có thể hành động; missing fields → unknown + warnings. LLM không được nâng giá trị nó tự tạo thành verified. Estimate phải ghi nguồn hoặc giả định ước tính; trường không đủ căn cứ để ước tính giữ unknown/null.
6. Response là proposal riêng, không saved itinerary. UI preview changes và quality warnings; người dùng chỉnh/reject/confirm.
7. Apply qua authorized transaction: subject/trip/proposal/digest/base_version khớp, validate lại quyền/rules, itinerary+estimate/version+receipt cùng commit. Actual expense không bị mutation theo AI. Result timeout → tra receipt, không regenerate rồi auto-save.

State: received → processing → proposed hoặc failed → applied/rejected/expired. “proposed” không nghĩa user confirmed. Hủy request phía UI không bảo đảm provider đã dừng; response muộn không tự apply. Guest proposal giữ local theo policy, không ghi vào private-trip tables.

### Provenance contract [PROPOSED]

Mỗi trường external có value nullable, unit, quality (verified/estimated/unknown), source/provider/reference, retrieved_at, verified_at nếu thực sự có kiểm chứng, valid_for/forecast_time khi phù hợp. “Có nguồn API” không bằng mọi giá trị đã được xác minh thực địa. Giá/giờ stale được hạ mức sử dụng và cảnh báo theo OQ-003/015. Sample/fixture luôn labeled sample. Không dùng null thành zero hay “mở cửa”.

## A/B/C API classification và Integration Matrix

Mọi operation name/API-A/B dưới đây là **[PROPOSED] specification-level contract**, chưa là deployed endpoint. LOCAL-* là local operation, không là API remote. Gemini provider đã **[CONFIRMED]**; model và maps/weather provider còn **[OPEN]**. Không gán quota/giá cố định khi chưa đo tài khoản thật.

| ID / Loại / MVP | Purpose + FR | Inputs | Expected outputs | Auth / secret management | Free-tier / freshness | Failure + fallback |
| --- | --- | --- | --- | --- | --- | --- |
| API-A-01 / A / MUST | Auth email, Google, session; FR-ACC-002/003 | Credentials hoặc OAuth flow, refresh context | Subject, session hoặc auth error | Supabase Auth [CONFIRMED DEC-007]; token protected local, không log password | Xác minh cấu hình Google/email và quota tài khoản; session expiry server | Cancel/network/login error giữ draft, reauth rõ |
| API-A-02 / A / MUST | Catalogue search/detail/sample; FR-DIS-* | Query, interests, destination/page | Published destinations/places/sample + provenance | Public read theo grants/RLS, curated writes server/admin | Internal cached, source timestamps; quota theo Supabase plan | Cache labeled hoặc empty/error; không fake |
| API-A-03 / A / MUST | Profile; FR-ACC-004 | Own subject + fields | Validated profile/version | JWT subject; RLS own; publishable client key khác secret | Session/current profile; plan xác minh | Keep unsaved form, retry, không đổi trip ngầm |
| API-A-04 / A / MUST | Save/import/read trips; FR-ACC-006, FR-TRP-004/005 | Trip model, draft key/revision, expected_version | Private trip/version/receipt | JWT; RLS read; trusted atomic mutation; server secret only | Supabase plan; authoritative commit/version | Conflict/unauthorized/error; local giữ draft; retry idempotent |
| API-A-05 / A / MUST | Expense CRUD và itinerary update; FR-BUD-* | Amount/kind/category/item link, request key/version | Ledger + totals + warnings | JWT + trip authorization; transaction; RLS nested | Timestamp/version; hạn mức chưa xác minh | Không double-charge entry; preserve actual, retry có receipt |
| API-A-06 / A / MUST | AI request/status/apply; FR-AI-* | Intent, constraints, minimum prefs; proposal/digest/base version khi apply | Proposal/warnings/status; applied receipt sau confirm | JWT hoặc scoped Guest token [PROPOSED]; AI secret server; quota trước external call | Guest 3/ngày [CONFIRMED DEC-003] khác provider quota; proposal tuổi OQ-015 | Invalid/quota/429/timeout giữ current itinerary, manual |
| API-A-07 / A / SHOULD | Group invitation/member/edit; FR-GRP-* | Trip, invitation subject, version | Membership/invite receipt hoặc conflict | JWT; Owner cho admin; Editor limited; token scoped | Invitation expiry OQ-014; không mặc định realtime | Reject stale/expired/removed user; reload preview |
| API-A-08 / A / SHOULD | Community publish/moderate; FR-COM-* | Content/rating/action/reason | Content state và audit metadata | Auth author/moderator backend roles; không client role claim | Content status authoritative; rate/storage quota cần kiểm chứng | Reject ownership; hidden content không public; retry form |
| API-B-01 / B / MUST | External AI generation/chat/recommendations; FR-AI-* | Sanitized structured context + constraints | Candidate normalized, không mutation trip | Gemini [CONFIRMED DEC-002], model OPEN; secret server | Pricing/model/tier/privacy qua EXT-03/04; quota thực tài khoản chưa biết | Timeout/429/model/schema error → manual và explicit retry |
| API-B-02 / B / SHOULD, hỗ trợ catalogue khi cần | Places/location; FR-DIS-002, FR-MAP-001 | Destination/coordinates/provider reference | Place info/hours/coords + source/status | Google Places hoặc nguồn OSM thích hợp [OPEN]; secret gateway; public data rights | Billing/attribution/cache policy và coverage Việt Nam cần kiểm; không assume complete | Curated internal; hours/price unknown nếu không có nguồn |
| API-B-03 / B / SHOULD | Map tiles, routing, distance/time; FR-MAP-001, FR-AI-005 | Coordinates, travel mode, departure context | Map/pins, route geometry/distance/duration + timestamp | Google Maps/Routes hoặc OSM tile host + routing service [OPEN]; restricted public map key nếu cần, sensitive routing key server | EXT-05/06; route estimates không live verified; routing không do tiles cung cấp | Itinerary list; estimate labeled hoặc unknown; không route giả |
| API-B-04 / B / SHOULD | Weather forecast/gợi ý/cảnh báo; FR-WEA-001 | Destination coords, travel date/timezone | Forecast timestamp/horizon/units/source | Open-Meteo candidate [OPEN]; auth theo plan, secret server nếu có | EXT-07, noncommercial eligibility/attribution và forecast horizon cần kiểm | Stale/absent/outside horizon → unknown, không block planner |
| LOCAL-01 / C / MUST | Input/timeline editing/sample copy | Local draft/day/items | Editable model + validation | Device data boundary, không API key | Không external quota; local draft revision | Validation/storage lỗi giữ form |
| LOCAL-02 / C / MUST | Draft/snapshot persistence | Owner scope + model/schema/version | Restart-safe draft/read-only snapshot | Owner partition; session/cache policy | No external quota; fetched_at trên cache | Incomplete write không replace valid snapshot |
| LOCAL-03 / C / MUST | Cost totals/local rule checks | Budget + known active estimates + actual ledger | Hai balances + unknown count + warnings | Local, revalidate remote khi save | Không external API cho phép cộng; fixed precision | Unknown không zero verified; actual giữ độc lập |

### Contract và lỗi dùng chung [PROPOSED]

Request mutation có request_id/idempotency_key và expected_version nếu sửa aggregate. Response thành công trả identity, version, committed_at và receipt. Validation error có field/reason; unauthenticated/forbidden không tiết lộ nội dung trip; conflict trả version metadata chỉ cho người còn quyền; quota/temporarily_unavailable có hướng manual/retry; provider_error không lộ payload/secret.

[CONFIRMED DEC-001] External API là tiêu chí giảng viên; không bắt buộc tự viết REST. Operation/HTTP contract dưới đây là target design, không khẳng định URL đang chạy. CRUD profile/read catalogue/private read có thể qua Supabase client + grants/RLS. Apply AI/import/versioned multi-row writes/member admin cần trusted server/database transaction; không dùng nhiều CRUD client như một transaction giả.

## Provider evaluation dựa trên tài liệu chính thức

Ngày tham khảo: **2026-10-08**. Gemini provider và Guest app quota đã duyệt theo S-DEC; bảng vẫn là đánh giá điều kiện tài khoản/model/giá/provider khác, chưa provisioning.

| Nguồn | Điều đã kiểm tra | Điều chưa kiểm chứng / quyết định |
| --- | --- | --- |
| EXT-01 [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) | Quyền theo row cần policies và grants; service role có khả năng bypass RLS | Policies deployed của repo chưa audit; phải negative-test |
| EXT-02 [Supabase server secrets](https://supabase.com/docs/guides/functions/secrets) và [pricing](https://supabase.com/pricing) | Secrets server-side; plan có giới hạn | Entitlement/quota thực, hoạt động project và deployment chưa xác minh |
| EXT-03 [Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits) | Hạn mức phụ thuộc model/tier/project, không chỉ từng key | Chưa đăng nhập AI Studio để biết quota/account; app Guest quota là quyết định riêng |
| EXT-04 [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing) | Free/paid khác theo model và điều kiện xử lý dữ liệu | Không chốt model/giá; review privacy trước gửi private preferences |
| EXT-05 [Google Maps pricing](https://developers.google.com/maps/billing-and-pricing/overview) | Billing theo SKU/event; maps, routes, places khác nhau | Xác minh billing setup, key restriction, coverage, cost cap và SDK trên Android |
| EXT-06 [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) | Standard tile host cần attribution, caching và nhận diện app; không cho offline bulk download | OSM data không đồng nghĩa tile/routing host miễn phí không giới hạn; chọn host/routing riêng |
| EXT-07 [Open-Meteo terms](https://open-meteo.com/en/terms) | Free service theo noncommercial terms, usage limits và attribution | Chưa xác nhận project đủ điều kiện; forecast không cam kết availability toàn thời gian |
| EXT-08 [openrouteservice plans](https://account.heigit.org/info/plans) | Trang kế hoạch ứng viên đã được truy cập nhưng không trả nội dung đọc được | Không suy diễn quota hoặc eligibility; giữ OPEN để xác minh chính thức trong PoC |

[PROPOSED] PoC sau approval phải chứng minh: gọi thật từ Android/server, địa điểm Việt Nam, lỗi/quota handling, attribution/restrictions, latency thực, secrets không xuất hiện trong bundle/log, ghi rõ tài khoản/plan/date và chi phí phát sinh nếu có. Map provider chỉ duyệt sau PoC theo S-MP §6.1. Không tạo key/accounts hoặc chạy PoC implementation trong Phase 1.

## Extension và giới hạn

[DEFERRED] Booking qua provider adapter tương lai chỉ mô tả boundary itinerary-place reference; không tables reservation/payment, webhook, message broker. Notifications không có push token/queue hiện tại. [PROPOSED] Community/Group conceptual model giữ ngoài core deployment khi SHOULD chưa chọn. Không yêu cầu migrate hoặc sửa code nào từ tài liệu này.

## ADR và thiết kế tích hợp hoàn chỉnh v1.1

ADR-P1-010 [CONFIRMED DEC-001]: Dùng external Gemini API thật đáp ứng loại API chủ dự án xác nhận từ giảng viên; backend nội bộ vẫn cần vì security/quota/validation, không vì rubric ép tự xây REST. Báo cáo submission artifacts vẫn OQ-010.

ADR-P1-011 [CONFIRMED DEC-007/008/009]: Supabase phụ trách Auth/profile/private persistence; sensitive AI qua server, minimal context và explicit user approval. [PROPOSED] Bổ sung Gemini adapter/orchestration vào Spring backend hiện có; Supabase Edge Functions chỉ alternative nếu deployability không phù hợp và phải duyệt riêng.

ADR-P1-012 [CONFIRMED DEC-010]: SQLite account cache purge on logout; remote trip retained. [PROPOSED] Provider reset UI state, local-store transaction delete owner namespace và clear token; cleanup failure deny access/queue cleanup thay vì UI báo sạch giả.

### Compatibility audit và bounded extension [PROPOSED]

S-REPO-2: tree backend có routing controller/service/providers và health; chưa thấy controller planning hoặc Gemini. TripsService dùng saved_trips. TripApiService có fallback demo và debug interceptor ghi request/response body. Đây là gap thiết kế, chưa phải task sửa code và chưa audit toàn bộ runtime.

| Phần hiện có | Định hướng v1.1 | Điều phải chứng minh trước thay đổi Phase 2 |
| --- | --- | --- |
| Provider/screens/DTO | Giữ flows hiển thị; adapter DTO → canonical itinerary khi có khác shape | Field mapping/request dates/items/quality đầy đủ, không parse mù |
| Spring map service | Giữ routing và health behavior; module Gemini dùng adapter riêng | Hosting HTTPS/runtime/authorization; không sửa endpoint map ngoài scope |
| Supabase saved_trips | Giữ dữ liệu cũ; target trip aggregate qua compatibility repository | Deployed schema/RLS/JSON columns thật; mapping legacy fields, version/idempotency support |
| Client plan-trip fallback | Giữ code trong tác vụ docs; Phase 2 phân biệt sample fallback/manual với Gemini live | Fallback không được dùng như evidence AI thành công hoặc verified prices/weather |
| Debug network logging | Trong Phase 2 cần redact/minimize payload trước dùng private context | Không email/token/private itinerary raw payload trong logs; hiện tại chưa sửa |
| Map/weather dependencies | Không coi có package/service là provider approved | PoC và terms; không ảnh hưởng core khi unavailable |

### Trusted Gemini operations [PROPOSED]

Giữ IDs API-A-06/B-01. Backend operation specification gồm: request AI, query request status/result, apply approved proposal. Không chọn endpoint Gemini/model ID chưa xác minh.

Request AI: request_id/idempotency key, intent generation/recommendation/chat/modification, scoped Guest token hoặc Supabase JWT, trip_id/base_version khi target trip, input constraints/context. Server xác thực và load dữ liệu có quyền, không trust client owner_id hoặc arbitrary place provenance. Guest không được lấy private trip thông qua request context.

Response AI: request_id/state, normalized payload/schema_version, proposal_id/digest/base_version khi có mutation suggestion, warnings/provenance và quota metadata (limit=3 cho Guest, used, reserved, remaining, reset_at). Failure có user-safe reason và charged=false nếu terminal no usable result; processing timeout khác terminal failure.

Apply: chỉ authenticated authorized actor cho remote saved trip; Guest có thể chấp nhận proposal vào local draft trước auth. Submit proposal_id + digest + expected_version + explicit action; server không nhận confirmation qua câu chữ LLM. Apply không gọi lại Gemini, không tính lượt AI mới; receipt/idempotency/version transaction giữ actual ledger.

### Quota state và concurrency [PROPOSED]

Server có durable ledger subject/day/request. Ngày theo server Asia/Ho_Chi_Minh; reserve nguyên tử used+reserved<3 trước provider, result valid → finalize một lượt; error → release. Persist result và charge state/receipt nhất quán để request status lookup không double-charge. Request key khác payload reject, client clock/counter không authority.

Bốn requests đồng thời ở bucket trống: tối đa ba reservation; request thứ tư không gọi provider. Nếu một request thất bại, một slot trở lại. Retry cùng key nhận cùng state/result. Qua midnight, request vẫn thuộc accepted-day bucket; bucket ngày mới độc lập. Crash/lease reconcile phải kiểm persisted result/terminal status trước release. Guest token expiry/reinstall abuse/global cap còn OPEN, không coi policy này là account quota Gemini.

### Local-store và migration contracts [PROPOSED]

SQLite adapters: LocalDraftRepository writable Guest, AccountSnapshotRepository immutable owner-partition, ImportReceiptStore lưu kết quả migration. Provider giữ loading/unsaved/error/current selection, không là durable storage. Package cụ thể mở; không thêm dependency.

Migration snapshot có source_draft_id/revision/digest và selected consent; backend identity từ JWT. Response receipt trả trip_id/version/source key/commit time. Ack → account-owned transferred record và snapshot; original Guest writable record không còn ở Guest namespace. Lỗi giữ source copy; mid-import edits tạo revision mới và đòi preview quyết định update/copy. Không cloud write nhiều rows bằng client coi như atomic.

### Privacy data flow [CONFIRMED boundaries; PROPOSED mechanics]

Client → server: inputs tối thiểu + auth/Guest token trong authorization context; server không đưa token vào provider prompt. Server → Gemini: destination/dates/budget/count/interests/relevant activities, origin coarse khi cần; không account identity/GPS mặc định. Không gửi full profile history. Server → database: own request metadata, normalized proposal/receipt/quota; raw prompts/log retention còn OQ-015.

[PROPOSED] Curated dataset descriptions và chat là untrusted text; không cho chúng instruct backend tools/actions. Consent UI giải thích provider nhận context và provider terms, bao gồm free-tier data processing; lưu consent version nếu được duyệt. Không giữ raw AI conversation history dài hạn trước retention decision.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
