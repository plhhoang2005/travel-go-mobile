# Schema thực — kết quả đối chiếu và kế hoạch xử lý

Ngày 2026-10-08. **Phase 1 CLOSED — APPROVED WITH CONDITIONS** giữ nguyên; deadline **2026-10-28 [CONFIRMED]**. Đây là phân tích và kế hoạch **PROPOSED**, chưa phải authorization sửa code/database hoặc nghiệm thu Phase 3. Không sử dụng superpowers.

## Bằng chứng và giới hạn

**SRC-DB-001 [CONFIRMED — metadata owner cung cấp]:** JSON trong Pasted text.txt, attachment 061b7101-3193-4452-9bf2-807153dd5cbe, SHA-256 `8858f68479a86f58be701591e1cac2d5a82bd2b869aa63902aab916991a8391d`. Owner đã xác nhận quản lý project `oavbymauorhmrjcustzw` tại DEC-P2-004. Nội dung khớp cấu trúc [metadata coverage](EVIDENCE.md): 12 tên bảng được kiểm tra, 40 cột, 8 policies, 84 grants và 4 indexes. Đây là evidence do owner xuất; Codex chưa có authenticated Dashboard/session để xác minh trực tiếp project và thời điểm chạy.

Đối chiếu source tại main local 8451fdb, code tương đương remote 4140712. Không đọc application rows; không biết số hồ sơ/trip/destination thực tế. Không suy diễn inventory này là toàn bộ database. SRC-DB-001 chưa bao gồm functions/triggers/constraints/column/schema privileges; SRC-DB-002 bổ sung phần này trong phạm vi query. Function bodies/config, default privileges, schemas khác và REST exposure vẫn chưa kiểm. OpenAPI 401 trước đó vẫn cần xác định nguyên nhân.

**SRC-DB-002 [CONFIRMED — metadata owner cung cấp]:** attachment 804fadbb-9f2c-4458-aaa1-bc42c0488ad8, SHA-256 `63103559ed3b2887a8621f7254ed87d86763cd29ab20e59a1853de6fc0616d48`. captured_at `2026-10-08T07:46:32.683482+00:00` (14:46:32 giờ Việt Nam); PostgreSQL 17.6. JSON hợp lệ: 11 constraints đều validated, 1 non-internal trigger trong phạm vi, 480 column-privilege rows, 12 effective-role rows, 6 execute rows cho 2 functions, 4 table owners postgres. Owner nói chạy đúng project; JSON không chứa project ref để tool độc lập xác minh. Không thay direct cloud-access evidence.

## Inventory được xác nhận trong phạm vi truy vấn

| Bảng public | Metadata | Hệ quả |
| --- | --- | --- |
| destinations | Có; RLS enabled; 8 cột; policy SELECT true | Có thể reuse catalogue; chưa chứng minh đủ 12 điểm đến hoặc 72 places/12 samples |
| profiles | Có; RLS enabled; 9 cột; SELECT true cho PUBLIC; UPDATE own row | Có email/phone/address/role; cần sửa privacy và kiểm quyền sửa cột |
| trips | Có; RLS enabled; 11 cột; own-row SELECT/INSERT/UPDATE/DELETE | Candidate nguồn lưu trip chính; JSON tại ai_plan_data |
| trip_activities | Có; RLS enabled; 12 cột; ALL theo owner của trips | Candidate activities; cần chốt quan hệ với canonical JSON và transaction |
| saved_trips | Không có | Client hiện tại gọi sai bảng so với snapshot này |
| places, trip_days, itinerary_items, trip_expenses | Không có các tên này | Chưa chọn tạo bảng mới hay dùng payload; không kết luận mọi feature tương đương đều vắng mặt |
| ai_plan_requests, guest_ai_requests, import_receipts | Không có các tên này | Chưa có evidence cho quota/import ledger theo phương án Phase 2 |

Các bảng có đều rls_forced=false, indexes được xuất chỉ gồm primary key id. Không có cột version trong trips hoặc index trips.user_id/trip_activities.trip_id trong snapshot. SRC-DB-002 xác nhận FK/constraints và trigger Auth bên dưới.

## Metadata bổ sung đã giải quyết

| Evidence SRC-DB-002 | Kết luận / tác động tích hợp |
| --- | --- |
| profiles.id → auth.users.id; trips.user_id → auth.users.id, đều ON DELETE CASCADE | Owner ID gắn Auth; xóa account có thể xóa profile/trips và activities theo cascade. Logout không phải xóa account. Không chạy thử xóa dữ liệu thật |
| trip_activities.trip_id → trips.id ON DELETE CASCADE | Parent-child integrity đã có; không cần dựng lại relation. Save trip + activities vẫn cần transaction |
| trip_activities.service_id → services.id ON DELETE SET NULL | service_id tùy chọn phải dùng ID tồn tại; không gán place/demo ID tùy ý. services là bảng liên quan ngoài inventory 12 tên ban đầu |
| trips.status CHECK planning/booked/completed | Canonical adapter phải tương thích enum. Local draft/pending/transferred/import status giữ riêng; booked không cấp phép implement booking |
| destinations.region CHECK Bắc/Trung/Nam/Tây Nguyên | Seed 12 điểm đến cần dùng đúng vocabulary |
| profiles.role CHECK customer/partner/admin; authenticated can_update_profile_role=true | Check chỉ giới hạn giá trị, không cấm owner đổi role sang admin. Không có non-internal trigger profiles trong phạm vi query; cần chặn client UPDATE role |
| auth.users on_auth_user_created enabled O → handle_new_user() | Trigger đăng ký hiện diện/enabled ở chế độ origin; chưa chứng minh signup runtime hoặc logic function đúng |
| anon/authenticated: schema USAGE=true, CREATE=false, BYPASSRLS=false; TRUNCATE=true cả 4 bảng | Quyền schema USAGE đã xác nhận; table grant/RLS profiles public vẫn là privacy blocker. TRUNCATE là effective privilege, nhưng chưa chứng minh đường gọi từ REST |
| service_role BYPASSRLS=true; table owners postgres | Server dùng service_role phải kiểm owner riêng; test bằng service/admin không chứng minh app-user isolation |

480 rows không có nghĩa 480 explicit column grants độc lập: [PostgreSQL column_privileges](https://www.postgresql.org/docs/17/infoschema-column-privileges.html) cũng biểu diễn table-level grants ở mỗi cột. Migration phải kiểm ACL table/column/inherited privileges thật; chỉ thu UPDATE(role) trong khi còn table UPDATE sẽ không đạt mục tiêu. anon can_update_profile_role=true là privilege layer, không tự vượt own-row RLS với auth.uid() null.

## Findings và ưu tiên

| ID / mức | Bằng chứng và ảnh hưởng | Đề xuất / traceability |
| --- | --- | --- |
| DB-001 / HIGH integration | TripsService gọi saved_trips (lines 20/41/62); SavedTrip model đọc/ghi trip_plan_data (lines 40/56). Database có trips.ai_plan_data, không có saved_trips. Mapping hiện tại không phù hợp | Reuse trips qua adapter, kiểm required fields/legacy payload; INT-001, RC-003, FR-TRP-004–006 |
| DB-002 / HIGH privacy | Profiles SELECT policy “Profiles are viewable by everyone”, roles PUBLIC, USING true; anon có SELECT. Cấu hình này cho phép đọc mọi profile ở tầng table/RLS, gồm cột liên hệ nếu đường truy cập được cấp | Thay policy đọc công khai bằng own-profile; không chỉ thêm một permissive policy owner. RC-003/005, FR-SEC-001/002, AC-034/054 |
| DB-003 / HIGH privilege hardening | anon/authenticated/service_role đều có SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER trên cả 4 bảng | Thu quyền không cần thiết theo access matrix dưới; kiểm inherited/PUBLIC grants và default privileges. Không kết luận anonymous REST gọi được TRUNCATE; RPC/DB access path chưa kiểm. RC-003/005 |
| DB-004 / HIGH role integrity | SRC-DB-002 xác nhận authenticated effective UPDATE role=true; CHECK cho phép admin; không có non-internal profiles trigger trong query. Kết hợp own-row UPDATE của SRC-DB-001 cho thấy cấu hình không ngăn owner đổi role | Cấm client sửa role; role do trusted server quản lý. Chưa chạy exploit/khẳng định privileged backend action; mức ảnh hưởng phụ thuộc nơi dùng role để authorization. RC-005 |
| DB-005 / OPEN durability/performance | Snapshot chưa thể hiện import receipt, optimistic version hoặc owner/parent lookup indexes | Thiết kế atomic import + durable uniqueness/version trước triển khai; index theo queries và đo khi cần. Không phải evidence import hiện có đạt AC-053. RC-003/005 |
| DB-006 / HIGH source trust; cloud logic OPEN | AuthProvider lines 62/72 lấy role từ user.userMetadata. Repo SQL handle_new_user lines 36–52 lấy role từ new.raw_user_meta_data; cloud metadata chỉ xác nhận function cùng tên SECURITY DEFINER owner postgres, chưa có body | Không dùng user-editable metadata làm quyền admin/partner. Signup server ép customer, privileged roles từ nguồn trusted/server-only; đối chiếu deployed body trước migration. RC-003/005 |

DB-002 xác nhận lỗi cấu hình; **không khẳng định đã xảy ra rò rỉ dữ liệu hoặc đã đọc được dữ liệu qua API**. DB-003 cần xử lý trước mở luồng dữ liệu thật; mức ảnh hưởng thực tế phụ thuộc các quyền và đường truy cập chưa kiểm.

Nguồn [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) phân biệt user metadata do người dùng sửa được với metadata do server quản lý; DB-006 là source finding, không kết luận cloud function body giống file repo. UI role không phải authorization server. Quick demo roles không được dùng làm trusted identity ở live path.

Hai public functions được xuất: handle_new_user() SECURITY DEFINER=true và check_review_eligibility() SECURITY DEFINER=false, đều có effective EXECUTE cho anon/authenticated/service_role. Cần inspect return type/body/search_path/ACL; SECURITY DEFINER tự nó không là lỗi. Repo handle_new_user returns trigger nên không được mặc định coi là RPC thường gọi để nâng quyền. Kiểm nội dung function trước thu quyền để giữ Auth signup hoạt động. [Supabase function security](https://supabase.com/docs/guides/database/functions) hướng dẫn giới hạn execute và search_path khi dùng SECURITY DEFINER.

Theo [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html), permissive policies kết hợp OR; TRUNCATE/REFERENCES không chịu RLS. WITH CHECK bỏ trống ở UPDATE/ALL dùng USING làm mặc định; vì vậy không tự coi null là thiếu bảo vệ. FORCE=false không tự là lỗi; owner/BYPASSRLS cần được phân biệt với app roles khi test. [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) là nguồn đối chiếu cho auth.uid() và app-role access.

Policies trips và trip_activities có predicate owner hợp lý trên giấy; **OPEN** kiểm A/B/anon, đổi user_id, đổi trip_id và stale session. Không dùng kết quả SQL Editor admin hoặc service_role để tuyên bố RLS PASS.

## Persistence contract đề xuất

| Model/app | Database hiện có | Quy tắc cần thiết |
| --- | --- | --- |
| Remote trip ID / owner | trips.id / user_id | ID server trả; owner từ authenticated context, không tin owner tùy ý trong request |
| Title / destination | title / destination_name | NOT NULL; input mới phải có destination thực, không suy từ itinerary fallback |
| Days / budget / dates | num_days / budget_total / start_date / end_date | Validate số/ngày/VND; ngày du lịch là local-date, chốt cách chuyển timestamptz tránh đổi ngày |
| Trip payload | ai_plan_data jsonb | Chốt canonical payload version và legacy reader; tên cột không bắt buộc nội dung chỉ do AI tạo |
| Activities | trip_activities | Chọn một nguồn sự thật; nếu là projection thì ghi cùng transaction, không dual-write độc lập từ client |
| Version / import receipt | Chưa có evidence trong inventory | Migration additive có review; một transaction lưu trip + receipt, retry trả cùng trip, conflict không ghi đè âm thầm |

[PROPOSED] Giữ trips và adapter cho model hiện tại thay vì tạo saved_trips chỉ để che mismatch. Bảo toàn IDs/records hiện có; không chạy lại enterprise schema wholesale. Không chọn schema mới trước kiểm FK, defaults, triggers và đường tạo profile của Auth.

## Access matrix mục tiêu [PROPOSED]

| Đối tượng | anon | authenticated | Trusted server |
| --- | --- | --- | --- |
| destinations curated | SELECT | SELECT | Curate bằng quyền cần thiết; không cấp client write |
| profiles riêng tư | Không truy cập | SELECT own; UPDATE own các cột được phép | Tạo profile theo Auth lifecycle; role chỉ sửa qua quản trị được kiểm soát |
| trips / trip_activities | Không truy cập | CRUD own theo RLS và contract | Import transaction xác minh JWT/owner; tránh bỏ qua owner khi dùng service role |
| quota / receipts tương lai | Không ghi trực tiếp | Không ghi ledger trực tiếp | Cập nhật atomic; quyền/function grants và search_path phải review |

Giữ email Auth là nguồn nhận dạng; không cho profile editor đổi role/email/id/created_at. Chốt cột editable sau kiểm UI hiện có. Client không cần TRUNCATE/REFERENCES/TRIGGER. Quyền server/admin không thu đồng loạt: phải kiểm Auth trigger và jobs trước để tránh làm hỏng đăng ký. Anonymous Guest draft vẫn local; quyền đọc catalogue không đồng nghĩa quyền đọc profiles/trips.

## Kế hoạch xử lý theo thứ tự [PROPOSED]

| Gói | Công việc Codex chuẩn bị → Antigravity thực hiện sau approval | Evidence để hoàn tất |
| --- | --- | --- |
| S0 — Metadata bổ sung | FK/check/triggers/effective privileges đã nhận SRC-DB-002; còn deployed function body/search_path/defaults/ACL và REST 401; không lấy user rows | Metadata inventory chính DONE trong scope; function logic/live access OPEN; không gọi toàn S0 PASS |
| S1 — Privacy và role | Diff thay profiles public policy, own-row read/update-column allowlist, least-privilege grants; signup trusted customer; AuthProvider lấy role từ trusted source; staging và recovery plan | A đọc/sửa own; B/anon không đọc profile A; UPDATE role và signup metadata role=admin không cấp admin; OAuth signup hoạt động; catalogue vẫn public |
| S2 — Persistence adapter | Scoped client model/service/provider plan: trips/ai_plan_data, required fields, legacy decoder; chỉ báo save success sau server ack; lỗi giữ draft | Save/reload/delete đúng trip; failed save không fake success; logout/account switch loại stale results |
| S3 — Durable import/version | Additive receipt/version contract; server transaction cùng owner; draft retained đến ack; test lost response/retry/edit/conflict | Không duplicate sau retry/crash; không overwrite revision khác; A/B access isolation |
| S4 — AI/environment | Xác minh Gemini account/tier/model/caps và HTTPS/JWT; quota 3 logical Guest requests/day theo Vietnam; synthetic PoC trước dữ liệu thật | Model/request evidence, concurrent quota/error/retry tests, minimal context/redacted logs |

S0 là xác minh chỉ đọc, S1–S4 là execution sau scoped approval. S1 cần ưu tiên trước real-user persistence/AI; các task domain/manual độc lập vẫn có thể được lập kế hoạch. Mỗi gói split theo file/scope guard hiện có, ghi exact files/migration delta/tests/rollback trước handoff. Không tự giao task bằng tool hoặc tạo agent/session mới.

Owner đã chạy [supplementary metadata coverage](EVIDENCE.md) và gửi SRC-DB-002; không cần chạy lại query này. Kết quả không thay inspect deployed function bodies/search_path/default privileges hoặc functional tests. Không cần gửi credentials.

### S1 task contract để hoàn thiện trước handoff

Phạm vi dự kiến: một migration mới trong supabase/migrations (PROPOSED path; chưa tạo), lib/features/auth/providers/auth_provider.dart, auth tests phù hợp và database authorization test script; split nhỏ nếu vượt file guard. Không overwrite supabase_enterprise_schema.sql wholesale. Exact test paths/source role service phải xác định khi plan freeze; đây chưa phải execution packet đã approved.

1. Capture policy/grant/function baseline; thử migration ở local/staging với synthetic accounts A/B. Preserve trigger name và Auth profile creation; verified deployed body là input bắt buộc cho function amendment.
2. Thay permissive public SELECT profiles bằng authenticated own-profile SELECT. Giữ update own-row, explicit owner WITH CHECK cho dễ review. Chọn editable columns fullname/phone/avatar/address theo UI, cấm role/email/id/created_at; thu table-level UPDATE và mọi residual effective grant cho cột protected, rồi cấp allowlist.
3. Thu quyền client không dùng ở 4 bảng, đặc biệt TRUNCATE/REFERENCES/TRIGGER; anon chỉ đọc destinations. Kiểm effective privileges sau migration thay vì chỉ nhìn câu REVOKE. Profile insert do trusted Auth trigger; không thêm client INSERT policy để chữa signup lỗi.
4. Function signup mới luôn gán customer; không tin raw_user_meta_data.role. Pin safe search_path và qualify object names sau inspect body; grant/default privilege changes theo dependency Auth thực tế. Không tự chuyển existing admin/partner records sang customer hoặc công nhận chúng hợp lệ; kiểm nguồn cấp quyền bằng quy trình quản trị riêng.
5. AuthProvider lấy privileged role từ server-controlled source; profile role chỉ có thể tin sau DB-004 remediation. Không dùng user metadata hoặc local demo role để mở privileged live operations; server/RLS vẫn enforce authorization.
6. Tests: A/B/anon profile và trip isolation; A UPDATE role=admin denied, allowed profile edit works; signup role=admin yields customer; email/OAuth signup tạo profile; metadata role spoof không cấp privileged operations; public destinations still read-only. TRUNCATE chỉ assert has_table_privilege=false, không thử xóa bảng thật. Negative tests NOT RUN hiện tại.

Recovery: review backup/schema capture trước rollout, migration transaction nếu phù hợp; khi regression ưu tiên forward fix hoặc hạn chế feature. Không dùng rollback mở profiles công khai lại làm cách khôi phục mặc định; cần owner-reviewed recovery plan giữ privacy.

## Readiness sau evidence này

- **CONFIRMED:** inventory chính SRC-DB-001/002 đã nhận; mismatch, FK/cascade/enum, Auth trigger presence và effective role/TRUNCATE privileges đã xác định. Không cần hỏi lại tồn tại bảng/trigger hoặc chạy lại hai query.
- **PROPOSED:** reuse trips, privacy/grant remediation và các gói S0–S4; chưa chuyển thành quyết định đã duyệt.
- **OPEN:** trực tiếp cloud auth/API, deployed function body/config/default privileges, role trust remediation và RLS negative tests; receipt/version, Gemini/host/quota, dataset coverage và rubric giảng viên. RC-003/005 chưa đóng.
- **DEFERRED:** booking/payments/push và sửa account trip offline giữ theo Phase 1.
- **ASSUMPTION:** metadata được xuất từ project owner đã chỉ định; SRC-DB-002 có timestamp nhưng không project-ref field. Không coi assumption là independent tool verification.

Không thay status conditional approval thành unconditional approval. Bước tiếp theo là hoàn thiện S0 và contract/migration plan S1–S3, rồi roadmap + AI guidance phục vụ đúng các task này. Phase 2 chưa COMPLETE; chưa authorize Phase 3. Report được publish cùng REPAIR-v1 qua documentation PR; source/DB/agent configuration không sửa. Xem [REPAIR_PLAN.md](REPAIR_PLAN.md).
