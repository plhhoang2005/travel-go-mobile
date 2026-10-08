# 07 — Database design và ERD specification

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED**.
> Tiến độ bộ thiết kế v1.1: **DESIGN COMPLETE — FINAL OWNER REVIEW PENDING**. Các lựa chọn đã chốt theo S-DEC; chưa chuyển Phase 2/3.
> Baseline: S-MP (Master Prompt v1.0); đặc tả chưa chứng minh tính năng đã triển khai hoặc Phase 1 đã đóng.

## Phạm vi và quyết định mô hình

[CONFIRMED] PostgreSQL qua Supabase; cần ownership, referential integrity, version, expense separation và backend authorization (S-MP §8–9; BR-007/009/018/021). **Toàn bộ tên entity, field, kiểu, constraint, index và transaction dưới đây là [PROPOSED]** logical schema; không SQL, không migration, không giả định deployed schema giống thiết kế.

DB-001 [PROPOSED]: Core chỉ profiles, destinations, places, trips, trip_days, itinerary_items, trip_expenses, ai_plan_requests và catalogue sample trong dữ liệu curated. Group/Community chỉ mô hình conceptual mở rộng. GuestAIRequest và quota ledger server theo 3/ngày DEC-003; không tạo Guest user profile giả để vượt ownership.

## Conceptual ERD [PROPOSED]

```mermaid
erDiagram
  AUTH_USER ||--o| PROFILE : owns
  PROFILE ||--o{ TRIP : owns
  DESTINATION ||--o{ PLACE : contains
  DESTINATION ||--o{ TRIP : primary_destination
  TRIP ||--|{ TRIP_DAY : schedules
  TRIP_DAY ||--o{ ITINERARY_ITEM : orders
  PLACE o|--o{ ITINERARY_ITEM : references_optional
  TRIP ||--o{ TRIP_EXPENSE : ledger
  ITINERARY_ITEM o|--o{ TRIP_EXPENSE : links_optional
  TRIP o|--o{ AI_PLAN_REQUEST : targets_optional
  PROFILE o|--o{ AI_PLAN_REQUEST : requests_optional
```

DB-002 [PROPOSED]: persisted trip aggregate có ít nhất một day đúng date range khi confirm/save; bản draft local có thể chưa đủ ngày. AI request cho recommendation/Guest có thể chưa có trip/profile. Public sample catalogue không là private trip của một tài khoản giả.

## Logical entities và field dictionary [PROPOSED]

Ký hiệu ! = required; ? = optional/null. UUID là định danh đề xuất, không gắn vào provider ID. Amount numeric fixed precision; datetime lưu UTC với trip timezone riêng; ngày đi là calendar date không tự đổi khi UTC conversion.

| Entity / PK | Fields chính và required/optional | FK / cardinality | Ownership / constraints |
| --- | --- | --- | --- |
| profiles / user_id! | display_name?, interests! (có thể rỗng), typical_budget?, travel_style?, created_at!, updated_at! | user_id → Auth subject, 1:0..1 | Own user; budget nonnegative nếu có; email/password không sao chép sang profile |
| destinations / id! | name!, region!, country_code!, description?, interests!, publication_status!, source_reference?, retrieved_at?, verified_at?, quality!, sample_itineraries? | Destination 1:0..N place, 1:0..N trip | Public read chỉ published; curate/admin write; source/status theo từng field khi khác nhau |
| places / id! | destination_id!, name!, description?, latitude?, longitude?, opening_hours?, cost_reference?, provider_name?, external_id?, provenance!, updated_at! | destination_id → destinations; 1:0..N item | Tọa độ theo cặp và range; opening_hours unknown nullable; provider+external_id unique khi cả hai có |
| trips / id! | owner_id!, destination_id!, start_date!, end_date!, total_budget!, traveler_count!, interests!, start_location!, travel_style?, timezone!, currency!, status!, visibility!, itinerary_version!, source_draft_id?, source_revision?, created_at!, updated_at! | owner_id → profiles; destination_id → destinations; 1:1..N day | Owner bất biến ở MVP; private mặc định; date/count/budget constraint BR-P002; version integer ≥1 |
| trip_days / id! | trip_id!, date!, ordinal!, notes? | trip_id → trips; 1:0..N item | Unique trip_id+date và trip_id+ordinal; date thuộc range trip |
| itinerary_items / id! | trip_id!, trip_day_id!, place_id?, title!, start_time?, end_time?, position!, travel_mode?, travel_duration?, duration_quality!, location_snapshot?, opening_hours_snapshot?, provenance!, user_exception_reason? | trip_day_id → day cùng trip; place_id → places optional | Unique day+position; custom item không cần place_id; không cho day thuộc trip khác |
| trip_expenses / id! | trip_id!, item_id?, kind!, amount?, category!, basis!, quantity!, description?, paid_at?, origin!, active!, source_item_snapshot?, provenance!, created_by!, request_key!, created_at!, updated_at! | trip_id → trips; item_id → item cùng trip optional; created_by → Auth subject | kind estimated/actual; actual amount required ≥0; unknown estimated amount null; quantity dương; unique trip+request_key |
| ai_plan_requests / id! | requester_id?, trip_id?, guest_subject_hash?, intent!, request_key!, base_version?, input_digest!, proposal_digest?, proposal_payload?, quality_warnings!, state!, provider_reference?, created_at!, expires_at?, applied_at?, result_receipt? | requester_id → profiles optional; trip_id → trips optional | Exactly one requester hoặc Guest subject; proposal private; unique subject+request_key; applied receipt giữ idempotency |

DB-003 [PROPOSED]: provenance trong logical model có thể là cấu trúc embedded, chưa ép thêm bảng; không lưu raw prompt chứa PII hoặc raw provider payload vô thời hạn. Với mỗi field cần value, unit, quality, source reference và thời gian; cross-reference API contract [06](ARCHITECTURE.md). Opening hours cần timezone và ngoại lệ nếu nguồn cung cấp; không đánh đồng chuỗi LLM sinh với giờ verified.

DB-004 [PROPOSED]: SourceDraft identity unique owner_id+source_draft_id+source_revision để retry không tạo thêm trip cùng revision. Policy revision mới update/copy vẫn OQ-009; không tự coi mọi draft giống nội dung là duplicate. Transaction receipt gắn key với output trip/version; xác nhận save không phụ thuộc client timestamp.

## Local và curated models [PROPOSED]

| Model | Dữ liệu cần giữ | Hành vi |
| --- | --- | --- |
| LocalDraft | draft UUID, device scope, revision, trip input/day/items/estimates/local actual entries, quality, saved_at, migration state/receipt | Writable local cho Guest; restart recovery; migration có chọn chủ đích; version khác remote itinerary_version |
| OfflineSnapshot | authenticated owner ID, trip ID, itinerary version, schema version, fetched_at, trip/day/items và budget display snapshot | Immutable read-only; atomic replace; partition owner; không cache secret/session plaintext |
| SampleItinerary | stable sample ID/version, destination ID, day/activity template, known estimates, source/license/status | Curated structured catalogue, copy thành LocalDraft; sample không là live AI |
| GuestAIRequest | scoped Guest subject hash, intent, quota counters/window, request key/state và proposal tạm | Server-owned ephemeral design; anonymous không đọc private trip; retention/quota OQ-005/015 |
| WeatherSnapshot | destination coords, provider/reference, forecast/valid times, retrieved_at, units/status | Snapshot context có freshness; chưa đề xuất core weather table |

DB-005 [PROPOSED]: Local migrated drafts chứa dữ liệu đã nhận bởi account cần chuyển owner scope; không để ở Guest vùng public thiết bị. [CONFIRMED DEC-010] Logout xóa account cache, không xóa remote trip và không xóa draft chưa chuyển của Guest. Giới hạn thiết bị dùng chung cần consent/policy ở OQ-015.

## Referential integrity, transaction và indexes [PROPOSED]

- Save/import: trip, days, items, expenses và receipt commit cùng nhau. Không có half-saved itinerary. Request key retry cùng payload trả receipt; key cùng khác payload bị reject.
- Day/date liên kết trip bằng constraint/transaction validation; item có trip_id redundant để RLS/lookup nhưng bắt buộc khớp day.trip_id. Expense item link cũng khớp trip. Không chỉ tin UUID từ client.
- Reorder dùng aggregate transaction đảm bảo position unique cuối transaction. Date range resize yêu cầu preview các days/items ảnh hưởng, không silently delete actual.
- Itinerary mutation so sánh expected_version nguyên tử rồi tăng +1; AI apply và manual update dùng cùng quy tắc. Đồng thời validate quyền hiện tại, trạng thái proposal/digest.
- Delete itinerary item: inactive/remove derived estimated entries theo BR-P009; actual item link → null và giữ item snapshot. Không cascade actual theo item deletion.
- Delete trip do Owner: cascade aggregate days/items/expenses/request data thuộc trip; catalog nguồn không xóa. Profile deletion/anonymization, account/trip retention cần OQ-015 trước destructive implementation.
- Catalogue place bị unpublish không làm saved itinerary mất title/location snapshot. Không xóa destination còn trip tham chiếu tùy tiện; archive catalogue trước, policy hard-delete cần duyệt.
- Index candidates: trips(owner_id, updated_at), days(trip_id,date), items(trip_id,trip_day_id,position), expenses(trip_id,kind,active), AI(subject,request_key), provider reference unique. Chưa thêm partitioning/sharding.

## Access/RLS specification [PROPOSED]

DB-006: bật grants tối thiểu và RLS trên mọi bảng expose; deny mặc định. Auth UID từ verified session; không trust owner_id/requester_id client. Policies cho SELECT/INSERT/UPDATE/DELETE tách rõ, write kiểm tra trạng thái row sau update để ngăn đổi owner/trip.

| Dữ liệu | Read | Write |
| --- | --- | --- |
| profiles | Chỉ own; không public private preferences | Chỉ own permitted columns |
| destinations/places/sample | Guest/user chỉ published | Server curator; không cho user update source/status |
| trips | Owner; active member nếu Group triển khai | Owner/edit membership theo operation; owner/visibility/version không để generic client tự thay |
| days/items/expenses | Có quyền đọc trip parent | Có quyền edit trip và parent consistency; atomic remote writes qua trusted operation |
| ai_plan_requests | Own request và còn quyền trip nếu target trip; không expose raw sensitive input | Gateway/server state machine; client không đổi state thành applied |
| Guest AI transient | Không direct database read cho anon | Gateway scoped token; quota 3/ngày CONFIRMED, identity/lease details OPEN |

DB-007: trusted operation dùng token scope thấp nhất có thể. Nếu dùng elevated server key, phải tự kiểm tra subject + trip membership + allowed operation trước query; service role bypass RLS không thay thế authorization. Database and server negative tests là AC-034/041/046.

## SHOULD conceptual extensions — chưa deploy [PROPOSED]

| Entity | Keys/fields/relationships | Constraints/access |
| --- | --- | --- |
| trip_members | trip_id + user_id PK; role Editor, state, joined_at | Unique member; trip 1:N members; Owner lấy từ trips.owner_id, không tạo Owner thứ hai; active member read/edit |
| TripInvitation | id PK; trip_id/issuer_id/target subject; token hash; state; expires_at | Owner issuer; single-use, expiry, revoke; token không public; OQ-014 |
| posts | id PK; author_id FK; title/body; publication/moderation_state; reason/time | Public published only; author write, moderator hide; không link private trip data tự động |
| reviews | id PK; author_id/place_id FK; rating/body/status | Rating scale [OPEN OQ-013]; một review per user/place [PROPOSED] |
| comments | id PK; author_id, content, post_id? hoặc review_id? | Exactly one parent; parent visible; author own; moderator quyền giới hạn |
| likes | user_id + target ID composite identity | Exactly one post/review target; unique để retry không double-like |

[DEFERRED] Không reservation/payment/notification entities. Storage community media chỉ đánh giá khi Community chọn; private buckets và ownership nếu dùng, không provision sẵn.

## Retention, deletion và scale

[PROPOSED] AI logs tối thiểu redacted; proposal có expiry; snapshot thể hiện fetched_at; catalog provenance giữ lịch sử đủ kiểm chứng. [OPEN] OQ-015 xác định TTL cache/AI logs/proposal, account deletion và audit retention; không invent thời hạn pháp lý.

[PROPOSED] Pagination catalogue/trips, indexes theo access path, limit request/output đã duyệt và lean dataset phù hợp học thuật. Nếu dữ liệu tăng, đo trước thêm full-text search/geo indexing; không dựng hạ tầng vượt MVP.

## Logical schema bổ sung v1.1 [PROPOSED]

DB-008: SQLite là công nghệ [CONFIRMED DEC-005]; tên bảng/fields/index/encryption/driver bên dưới còn PROPOSED.

| Local entity | Identity và dữ liệu | Invariant |
| --- | --- | --- |
| local_drafts | draft_id PK, revision, device_guest_scope, input/day/items/expense payload, payload_digest, state, updated_at | Chỉ writable local Guest drafts chưa transferred; atomic save/recovery |
| account_trip_snapshots | owner_id + trip_id PK, remote_version, schema_version, fetched_at, snapshot_payload | Read-only, namespace riêng; không lưu server/API secret |
| draft_import_receipts | owner_id + draft_id + source_revision unique, request_key, payload_digest, remote_trip_id/version, acknowledged_at | Receipt chỉ sau ack; key khác payload reject; logout purge local account copies |
| local_import_journal | draft/revision/request key, target_owner, pending/acknowledged/error, attempt state | Journal phục hồi sau restart; session subject phải khớp trước retry |

DB-009: quota server là logical extension cần cho Guest MUST, không là bảng SHOULD. GuestSubject token random server-issued, lưu secret token trong secure credential storage theo proposal; không dùng SQLite plain token như authority. Server giữ hash/reference, không cần email/GPS/advertising identifier.

| Server entity | Identity/data | Constraints |
| --- | --- | --- |
| guest_ai_daily_usage | subject_id + calendar_date PK; timezone Vietnam, limit=3, used, reserved, updated_at | used/reserved nguyên ≥0; used+reserved≤3; counters atomic, không từ client |
| ai_usage_reservations | request_id PK, subject/day FK, payload_digest, reserved/finalized/released, accepted_at, lease/reconciliation state | Unique request; terminal mutation một lần; no provider call trước reservation |
| ai_request_receipts | request_id PK/FK, terminal status, normalized result reference/digest, charged state, safe error, completed_at | Retry/query không charge lại; result publication/charge nhất quán |

[PROPOSED] Có thể cùng physical storage với ai_plan_requests thay vì dựng ba services; bảng tách mô tả responsibility, không buộc triển khai ceremony. Guest quota records phải deny direct anon access; server thao tác dưới policy có validation. Quota và provider quota khác nhau.

DB-010: giữ trip private ownership và current saved_trips compatibility. Target canonical trips/day/items/expenses là logical aggregate; không mặc định tạo schema song song rồi bỏ dữ liệu cũ. Cần map saved_trips deployed columns/JSON blobs, legacy ID/owner, current DTO, missing version/provenance. Owner field legacy nếu là user_id phải map sang canonical owner_id với RLS kiểm subject. Không chạy migration hoặc rename table trong Phase 1.

DB-011: migration transaction tạo trip aggregate + import receipt unique owner/draft/revision/digest. Remote receipt phải tồn tại đủ để timeout/retry không duplicate; TTL/deletion của receipt cần duyệt OQ-015 trước cleanup. Một token dùng lại không được bind draft A sang account B giữa request.

DB-012: logout xóa account snapshots/transferred local copies/import account receipt cache trong SQLite; Supabase trip/days/expenses không delete. Guest local draft chưa nhận vào account không tự đổi owner. Journal đang pending thuộc account cần purge/redact hoặc khóa không truy cập sau logout theo policy mechanics PROPOSED; server receipt vẫn cho reconnect recovery khi đúng account.

DB-013: catalogue 12 destination CONFIRMED; source records cần stable tourism_destination_id (không phụ thuộc tên tỉnh sau thay đổi hành chính), curated status, license/attribution, last reviewed, place source/reference and field-level quality. 6–10 places/destination + one sample còn PROPOSED; không seed placeholder data hoặc fake verified values chỉ để đủ count.

## Giới hạn retention và privacy

[CONFIRMED DEC-009] Không dùng email/password/auth token/GPS chính xác mặc định làm input Gemini. [OPEN] Raw chat retention, consent record lifetime, proposal expiry, receipt retention/account deletion và encryption key management chưa chốt. Chính sách tối thiểu [PROPOSED]: chỉ durable metadata cần retry/quota, redacted logs; nếu cần raw prompts để debug thì phải approval retention/consent trước. Không công bố số ngày lưu hoặc protection-at-rest như đã triển khai.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
