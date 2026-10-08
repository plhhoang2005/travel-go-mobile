# Travel-Go Mobile — Bàn giao sau Phase 1

> Ngày bàn giao: **2026-10-08** • Deadline sản phẩm: **2026-10-28**.
> **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED.**
> Baseline: **design v1.1 tại 2f330e9**, approval **S-APP-001** tại [APPROVAL.md](APPROVAL.md).
> Tác vụ bàn giao chỉ có tài liệu; chưa tạo session mới, sửa agent rules/skills hoặc triển khai ứng dụng.

## Điểm bắt đầu cho người/agent tiếp nhận

1. Đọc [APPROVAL.md](APPROVAL.md), [index/decision log](README.md) và [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md).
2. Dùng checkout thật của repository plhhoang2005/travel-go-mobile; kiểm tra main/head và trạng thái local trước thay đổi. Thư mục ChatGPT project mirror/sources là reference read-only, không phải workspace để sửa source app.
3. Giữ baseline/confimed decisions; không lặp lại câu hỏi provider/state/quota/destination đã chốt. Đọc rules repo hiện có và chỉ đề xuất cập nhật chỗ không phù hợp; không tự sửa permanent rules hoặc cài skill.
4. Không sử dụng superpowers theo preference trực tiếp hiện tại. Session mới cần mang preference này trong handoff/prompt để không suy đoán từ chat cũ.
5. Việc kế tiếp là readiness/compatibility audit và kế hoạch Phase 2 khi được giao; approval Phase 1 không tự là permission viết code Phase 2.

## Các commit và trạng thái bàn giao

| Commit | Vai trò |
| --- | --- |
| [8451fdb](https://github.com/plhhoang2005/travel-go-mobile/commit/8451fdb86943d8e72530fe4f06609529a88512f5) | Main trước tác vụ thiết kế; code hiện có được bảo toàn |
| [758804c](https://github.com/plhhoang2005/travel-go-mobile/commit/758804ce9bb636e45d3c8d11dcab4b33fed4cc68) | 10 docs v1.0 + index/root README; 50 AC |
| [2f330e9](https://github.com/plhhoang2005/travel-go-mobile/commit/2f330e94423d67c89ed34bb2f4d0657b652cb30b) | Bản v1.1 đã duyệt; 55 AC, decision log và design detail |
| Closure commit | Commit chứa bản handoff này; xem [history](https://github.com/plhhoang2005/travel-go-mobile/commits/main/docs/phase-1/HANDOFF.md) để lấy SHA chính xác khi bàn giao session mới |

[CONFIRMED] Trong hai commit thiết kế trước, verification đối chiếu tree đã xác nhận 231 file ngoài scope docs giữ nguyên. Closure sẽ tiếp tục đối chiếu blob/type/mode; không tuyên bố runtime từ việc code không đổi. Agent tiếp nhận nên pin closure SHA lấy từ Git thay vì dùng link main như immutable baseline.

## Quyết định đã chốt

| Decision | Nội dung CONFIRMED | Trace |
| --- | --- | --- |
| DEC-001 | Tiêu chí giảng viên: external API; không bắt buộc tự xây REST | OQ-001 |
| DEC-002/008 | Gemini chính, server-only key, proposal/preview/apply sau user confirm | OQ-002; FR-AI-*; BR-005/022 |
| DEC-003 | Guest 3 request/ngày; reset 00:00 Asia/Ho_Chi_Minh; request AI dùng chung quota; lỗi không có usable result không trừ | OQ-005; BR-Q001/002; AC-023/051 |
| DEC-004 | 12 destination: Hà Nội, Hạ Long, Sa Pa, Ninh Bình, Huế, Đà Nẵng, Hội An, Nha Trang, Đà Lạt, TP.HCM, Phú Quốc, Cần Thơ | OQ-006; AC-052 |
| DEC-005 | Giữ Provider; SQLite Guest writable drafts + saved read-only snapshots | OQ-007; AC-005/016/045 |
| DEC-006 | Login/chọn/confirm draft, ack trước saved/transferred, lỗi giữ draft, retry không duplicate; remote là bản chính | OQ-009; AC-006/039/053 |
| DEC-007 | Tái sử dụng code/backend phù hợp; Supabase Auth/profile/private data; không tự rewrite engine | OQ-011 |
| DEC-009 | AI context tối thiểu; no email/password/auth token/default precise GPS; origin coarse | OQ-015; AC-054 |
| DEC-010 | Logout purge account cache local; Supabase trip còn; không lẫn data account | AC-040/045/055 |
| DEC-011 | Hoàn thiện design; không sử dụng superpowers | Scope/preference |
| S-APP-001 | Baseline v1.1 phê duyệt có điều kiện và hồ sơ Phase 1 đóng | APPROVAL.md |

[CONFIRMED] Five MUST: Account/Profile, Discovery, Trip Planner, AI Assistant, Budget. Map/Weather/Community/Group là SHOULD, không hy sinh MUST. Booking/payment, push/advanced reminders và saved-trip offline editing/advanced sync DEFERRED.

[PROPOSED] 6–10 places/activities mỗi destination và 1 sample ~3 ngày, tổng 72–120 places + 12 samples; chưa được chọn cuối. Closure không phê duyệt số lượng này ngầm. Estimated/actual expense tách riêng; AI/manual chung itinerary; missing external values labeled estimated/unknown, không fake verified.

## Hiện trạng đã quan sát, chưa suy diễn runtime

Snapshot source đã kiểm read-only: recursive tree ở 2f330e9 và các file được nêu trong ARCHITECTURE.md/S-REPO-2.

| Evidence source | Quan sát | Giới hạn |
| --- | --- | --- |
| [backend/pom.xml](https://github.com/plhhoang2005/travel-go-mobile/blob/2f330e94423d67c89ed34bb2f4d0657b652cb30b/backend/pom.xml) | Backend Spring Boot/Java, web/cache/validation dependencies | Chưa build/run hoặc kiểm hosting |
| [MapController](https://github.com/plhhoang2005/travel-go-mobile/blob/2f330e94423d67c89ed34bb2f4d0657b652cb30b/backend/src/main/java/com/travelgo/backend/map/controller/MapController.java) và MapService | Source route operation /api/v1/maps/routes, provider/fallback handling | Không chứng minh endpoint đang deploy/live hoặc security coverage |
| [TripApiService](https://github.com/plhhoang2005/travel-go-mobile/blob/2f330e94423d67c89ed34bb2f4d0657b652cb30b/lib/features/trip_planner/services/trip_api_service.dart) | Client planning request + hardcoded fallback demo, debug body logging | Fallback không là Gemini thật hoặc dữ liệu giá/thời tiết đã verify; logging cần privacy review trước private context |
| [TripsService](https://github.com/plhhoang2005/travel-go-mobile/blob/2f330e94423d67c89ed34bb2f4d0657b652cb30b/lib/features/trips/services/trips_service.dart) | Supabase saved_trips read/insert/delete | Deployed schema/RLS/version/import receipt chưa xác minh |
| Tree và pubspec trong repo | Feature folders, Provider/Dio/fl_chart/Supabase/map packages, weather service | Dependency có mặt không đồng nghĩa provider/flow đã acceptance-pass |
| Design 10 docs | 38 FR/22 BR/11 UF/55 AC/OQ register | Tất cả 55 AC NOT RUN; runtime/keys/provider PoC chưa thực hiện |

[OPEN] Chưa thấy planning controller/Gemini service trong tree backend đã kiểm. Không kết luận engine ở môi trường khác không tồn tại; không rewrite MCDA/Pareto/Greedy theo giả định. Logical trips/day/items/expenses phải map legacy saved_trips sau schema audit, không xóa/rename dữ liệu từ đặc tả.

## Remaining readiness

Due/owner dưới đây là **[PROPOSED]**, dùng để điều phối sau closure; không là deadlines mới đã được duyệt. Global deadline 2026-10-28 giữ CONFIRMED.

| ID / OQ | Điều cần làm rõ | Owner [PROPOSED] | Due [PROPOSED] | Evidence / gate |
| --- | --- | --- | --- | --- |
| RC-001 / OQ-002 | Gemini model/version, account eligibility/key/quota, structured output tiếng Việt | Developer + chủ dự án | 2026-10-10 | Chọn model có căn cứ, live PoC sau authorization; chặn live AI integration cho đến readiness |
| RC-002 / OQ-007 | SQLite driver/package, atomic recovery/schema migrations, secure token storage | Developer | 2026-10-10 | Compatibility proposal, dependency approval trong Phase 2 plan; chặn local-store implementation chưa chọn |
| RC-003 / OQ-011 | Spring hosting/HTTPS, actual saved_trips schema/RLS, DTO mapping/version/receipts | Developer + chủ dự án | 2026-10-10 | Read-only audit + compatibility matrix + scoped plan; chặn remote mutation/integration chưa bảo đảm ownership |
| RC-004 / OQ-004/006 | Places/sample depth, sources/licenses/quality, dataset curation coverage | Chủ dự án + developer | Depth/source 2026-10-10; coverage review 2026-10-15 | Depth quyết định rõ, provenance/license evidence, không fabricate fields; chặn claim catalogue complete |
| RC-005 / OQ-003/005/009/015 | Validator exceptions, Guest identity/lease/global/account caps, migration revision handling, consent/retention/encryption/delete | Chủ dự án + developer | 2026-10-10 | Policy decisions và test cases; không lưu raw private prompts/logs/destructive cleanup khi còn thiếu approval |
| RC-006 / OQ-010 | UML/report/deck/demo checklist môn học | Chủ dự án hỏi giảng viên | 2026-10-09 | Rubric/phản hồi thực; API type external đã chốt, không hỏi lại |

[OPEN] OQ-008/012/013/014: map provider/PoC, weather provider, community moderation và collaboration permissions chi tiết. Due PROPOSED 2026-10-20 khi chọn SHOULD; không chặn core nếu chưa đưa vào implementation scope. Không “đóng” các OQ này chỉ để báo Phase 1 hoàn thành.

[PROPOSED] Quota used+reserved≤3, accepted-day bucket, idempotency/state lookup và lease reconciliation là mechanics chưa xác minh; app quota không bằng Gemini quota. Guest random token không bảo đảm quota theo mỗi người thật qua reinstall/multiple devices; chống abuse/global cost cap phải được chọn rõ.

## Công việc tiếp theo, theo thứ tự

| Bước | Đầu ra cần có | Phạm vi / authorization |
| --- | --- | --- |
| 1. Chuẩn bị session/checkout thật | Pin closure commit, clean status, handoff/reference docs sẵn | Có thể tạo session mới khi user yêu cầu; chưa tạo trong tác vụ này |
| 2. Audit readiness/compatibility | Report phần có/thiếu, tests/runtime baseline, schema/RLS/DTO/backend/keys status (không lộ secret) | Read-only audit được giao riêng; không tự cài package/provision/migrate từ handoff |
| 3. Rà soát agent guidance hiện có | Đề xuất thay đổi AGENTS/rules/workflow/skills còn mâu thuẫn baseline | Không xây bộ agent mới mặc định; permanent rules chỉ sửa khi được user cho phép |
| 4. Chốt readiness và Phase 2 plan | Backlog nhỏ, file list, dependencies, risk/rollback, acceptance IDs, lịch tới 2026-10-28 | Cần user authorization Phase 2; quyết định mới trace vào OQ/ADR |
| 5. Core vertical slice | Guest discovery → input/manual edit/budget → SQLite draft → auth/import → reopen/offline | Implementation sau authorization; chạy meaningful tests, không báo màn hình/mock là MVP |
| 6. Gemini + catalogue breadth | Request/proposal/validator/quota/approval; 12-destination coverage | PoC/model/accounts/policy readiness; actual expenses giữ nguyên khi AI sửa |

[PROPOSED] Thực hiện từng phần nhỏ trên feature branch/PR theo repo workflow khi được triển khai; direct push main trong tác vụ docs không là quyền lâu dài cho code. Không tự mở broad rewrite hoặc nhiều agent/skills trước audit.

## Acceptance và tiêu chí bàn giao sang implementation

- 55 acceptance cases vẫn **NOT RUN**; documentation verification không đổi chúng thành PASS.
- Dùng FR→BR→UF→model/API→AC khi chia backlog; AC-051 quota, AC-052 12 destinations, AC-053 import, AC-054 privacy, AC-055 logout là các negative/boundary case quan trọng.
- Gemini thật cần evidence riêng với controlled fixture; không dùng fallback sample để claim AI integration đạt.
- Chỉ đánh dấu requirement complete sau observed test/evidence trong môi trường authorized; failures/pre-existing debt ghi rõ, không sửa ngoài scope.

## Checklist người tiếp nhận

- [ ] Đọc baseline/approval/handoff và lấy closure SHA từ Git.
- [ ] Kiểm checkout thật/branch/local changes; nguồn synced chỉ read-only.
- [ ] Giữ DEC đã CONFIRMED, due/assumptions/details OPEN không coi là approved implementation.
- [ ] Nhận task/authorization readiness hoặc Phase 2 riêng; không tự bắt đầu code.
- [ ] Không sử dụng superpowers; không tự thay permanent agent guidance.
- [ ] Giữ secrets ngoài app/log và không in giá trị credential trong report.
- [ ] Chia scoped plan, acceptance evidence và deadline 2026-10-28.

[Xem approval](APPROVAL.md) · [Index](README.md) · [Remaining OQ](OPEN_QUESTIONS.md).
