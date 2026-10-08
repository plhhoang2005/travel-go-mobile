# 01 — Tổng quan dự án

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**.
> Bộ thiết kế v1.1 đã được chủ dự án phê duyệt có điều kiện ngày **2026-10-08**; hồ sơ Phase 1 đóng. Xem [approval](APPROVAL.md) và [bàn giao](HANDOFF.md); Phase 2/3 chưa được phép triển khai.
> Baseline: S-MP (Master Prompt v1.0); đây là đặc tả thiết kế, không phải bằng chứng tính năng đã triển khai hoặc Phase 1 đã được đóng.

## Tóm tắt điều hành

[CONFIRMED] Travel-Go Mobile là ứng dụng học thuật Android bằng Flutter/Dart dành cho người đi du lịch cá nhân và nhóm tại Việt Nam. Giá trị cốt lõi là khám phá điểm đến, lập lịch trình cá nhân hóa bằng Hybrid AI, chỉnh sửa thủ công và quản lý ngân sách trong cùng một trải nghiệm (S-MP §2, §4, §8).

[CONFIRMED] Năm module MUST: Account & Profile, Travel Discovery, Trip Planner, AI Travel Assistant, Budget Management. Map, Weather, Community, Group Collaboration là SHOULD: thiết kế điểm mở rộng nhưng triển khai không được làm ảnh hưởng MUST. Booking và push notifications được DEFERRED. Một lập trình viên chính với hỗ trợ AI, Windows, ưu tiên free tier, deadline 2026-10-28 là ràng buộc kế hoạch cứng.

[PROPOSED] Tổ chức feature-based, repository boundary, Supabase Auth/PostgreSQL/RLS và server-side orchestration cho AI; local store phục vụ Guest draft và snapshot itinerary đã lưu. Supabase và PostgreSQL đã CONFIRMED, Provider/SQLite và nguyên tắc server-side đã CONFIRMED theo DEC-005/008; tổ chức lớp, deployment/driver và contract chi tiết còn PROPOSED/OPEN.

## Vấn đề và mục tiêu

[CONFIRMED] Người dùng phải chuyển giữa nhiều website/app để chọn điểm đến, tìm hoạt động, tính chi phí, ghép ngày/giờ và chia sẻ thông tin. Mục tiêu là giảm công sức chuẩn bị, đưa quyết định về cùng một itinerary chỉnh sửa được, minh bạch dữ liệu thiếu và chi phí ước tính (S-MP §2).

[PROPOSED] G-001: kiểm chứng trọn luồng Guest khám phá → điền trip → AI → preview → sửa → estimate → xác nhận → đăng nhập/lưu → mở lại → đọc offline. G-002: kiểm chứng quyền riêng tư và không mất draft khi API/auth lỗi. G-003: chứng minh AI tạo đề xuất có kiểm tra, không tự sửa itinerary đã xác nhận. Không dùng số màn hình làm thước đo hoàn thành.

[OPEN] Chưa có nghiên cứu đo thời gian chuẩn bị chuyến đi trước/sau; không công bố phần trăm giảm thời gian hoặc tỷ lệ hài lòng chưa đo.

## Stakeholder và nhu cầu

| Vai trò | Nhu cầu/Trách nhiệm | Cơ sở |
| --- | --- | --- |
| Người đi cá nhân/nhóm [CONFIRMED] | Khám phá, chỉnh itinerary, theo dõi ngân sách riêng tư | S-MP §2.3 |
| Chủ dự án [CONFIRMED] | Phê duyệt thiết kế và thay đổi baseline | S-MP §16–18 |
| Lập trình viên chính [CONFIRMED] | Thực hiện trong thời gian hữu hạn sau gate | S-MP §2.4 |
| Giảng viên [CONFIRMED] | Đánh giá external API theo DEC-001; submission artifact details OPEN | S-MP §10; OQ-001, OQ-010 |
| Quản trị Community [CONFIRMED khi module triển khai] | Moderation; không mặc nhiên đọc private trip | S-MP §6.3 |
| Nhà cung cấp API [OPEN] | Hạn mức, điều kiện sử dụng, độ mới dữ liệu cần kiểm chứng | S-MP §10 |

[ASSUMPTION] Persona demo: người Việt chuẩn bị chuyến đi ngắn, muốn linh hoạt ngân sách và không muốn nhập lại dữ liệu khi đăng nhập. Persona Minh trong tài liệu repository là ngữ cảnh hiện có, không phải bằng chứng nghiên cứu người dùng mới.

## Requirement Audit trước khi thiết kế

| ID xung đột | Nguồn và vấn đề | Tác động | Xử lý trong bộ tài liệu |
| --- | --- | --- | --- |
| CF-001 [OPEN] | S-MP §2.4 “No existing codebase”; S-REPO có lib/, backend/, test/ | Không được scaffold hoặc viết như greenfield | S-USER yêu cầu dùng repo hiện có và giữ code: tài liệu bổ sung; chưa đánh giá tương thích từng tính năng |
| CF-002 [OPEN] | S-MP “No API accounts or keys configured”; README cũ nói có Supabase key trong code | Không thể suy luận tài khoản live hay loại key | Ghi nhận lời README, chưa audit key; phân biệt publishable/anon key và secret; không sao chép giá trị |
| CF-003 [CONFIRMED boundary; OPEN runtime] | S-REPO mô tả Decision Engine backend, AI chỉ explainer; S-MP §5.4 yêu cầu external AI sinh itinerary, chat, sửa | Thiết kế tương lai có thể khác vai trò LLM và API hiện tại | DEC-007/008 duyệt giữ/tái sử dụng phần phù hợp và Gemini proposal server-side; target adapter PROPOSED, runtime engine chưa chứng minh |
| CF-004 [CONFIRMED state; OPEN providers] | Repository dùng Provider, Dio, flutter_map/Open-Meteo; S-MP OQ-007/008 và Weather provider còn mở | Dependency hiện có không đủ chứng minh provider được duyệt cho baseline mới | DEC-005 xác nhận giữ Provider và dùng SQLite; maps/weather provider vẫn OPEN; dependency không thay PoC |
| CF-005 [OPEN] | Knowledge ghi “chưa Auth”; tree có màn hình auth và supabase_flutter | Tài liệu hiện trạng có thể cũ | Không tuyên bố Auth đã đủ/thiếu; kiểm thử đối chiếu sau gate (OQ-011) |
| CF-006 [CONFIRMED: chỉ trong tác vụ xuất bản] | AGENTS repo giới hạn 5 file, feature branch/PR; S-USER chỉ định 10 docs + README/index và push main | Quy trình xuất bản khác mặc định | Chỉ dẫn trực tiếp S-USER áp dụng cho tác vụ tài liệu này; không sửa AGENTS hoặc quy tắc lâu dài |
| CF-007 [OPEN] | S-MP §16 muốn yêu cầu approval cuối cùng; S-USER muốn xuất bản tài liệu ngay | Xuất bản dễ bị hiểu là duyệt thiết kế | Commit/push chỉ công bố bộ thiết kế; trạng thái conditional, approval checklist vẫn pending |

[CONFIRMED] Không trùng nghĩa “nhóm khách đi” với “nhóm có quyền cộng tác”: traveler_count phục vụ kế hoạch MUST, shared editing là SHOULD. “Confirm itinerary” của người dùng và “approve Phase 1” của chủ dự án là hai gate khác nhau. Weather alerts SHOULD là cảnh báo trong app; không mở lại push notifications DEFERRED.

## Khả thi và rủi ro

[PROPOSED] Có cửa sổ khoảng 20 ngày từ 2026-10-08 đến 2026-10-28, khả thi có điều kiện nếu ưu tiên luồng tích hợp, chốt provider/rubric sớm và tận dụng phần hiện có sau audit. Chưa biết năng lực code và giờ làm mỗi ngày nên không bảo đảm hoàn thành triển khai. Không có triển khai nào được phép bởi lần xuất bản này.

| Rủi ro | Mức [PROPOSED] | Kiểm soát đề xuất | Liên kết |
| --- | --- | --- | --- |
| Submission rubric còn thiếu; API type đã chốt | Trung bình | DEC-001 xác nhận external API; lấy checklist artifact ở OQ-010 | OQ-010 |
| Model/account quota/keys chưa xác minh; provider và Guest policy đã chốt | Cao | Gemini DEC-002, 3 Guest/ngày DEC-003; validate model/credentials sau gate; manual không thay live AI evidence | OQ-002, OQ-005 |
| Dữ liệu Việt Nam thiếu/không được phép dùng | Cao | Dataset curated có nguồn, kiểm tra từng trường; unknown không bằng 0 | OQ-004, OQ-006 |
| Tương thích codebase/engine | Cao | Audit read-only; duyệt adapter thay vì mặc nhiên rewrite | OQ-011 |
| Scope SHOULD làm chậm MUST | Cao | Chỉ kích hoạt SHOULD khi core acceptance đã có bằng chứng | PRD.md |
| Mất draft, stale edits, private-data leakage | Cao | Idempotency, version guard, RLS, cache ownership | AC-039–AC-045 |

## Tiêu chí thành công và gate

[CONFIRMED] Tính năng chỉ đạt khi có bằng chứng cho acceptance ở [09](ACCEPTANCE_CRITERIA.md), không dựa trên mock screenshot. [PROPOSED] Mọi AC MUST phải đạt; SHOULD đánh dấu không áp dụng nếu module chưa được phê duyệt triển khai; DEFERRED kiểm tra không phát sinh triển khai ngoài scope.

[CONFIRMED S-APP-001] Chủ dự án đã phê duyệt baseline v1.1 và đóng Phase 1 có điều kiện. Logical schema/policy details chưa chốt và runtime validation tiếp tục được bàn giao, không được đổi OPEN thành CONFIRMED tự động; xem [approval](APPROVAL.md) và [handoff](HANDOFF.md).

## Kết quả Requirement Audit v1.1

[CONFIRMED] DEC-001 loại bỏ blocker “có bắt buộc tự xây REST API”; vẫn dùng external Gemini thật trong demo, không dùng fixture thay. DEC-002/003/005/006/007–010 chốt provider AI, Guest policy, state/local, migration và privacy boundary. Danh sách DEC/evidence nằm ở [index](README.md).

[OPEN] Audit read-only S-REPO-2 ở commit 758804ce9bb636e45d3c8d11dcab4b33fed4cc68: backend/pom.xml khai báo Spring Boot/Java; tree có MapController, MapService và routing adapters. MapController định nghĩa POST /api/v1/maps/routes. TripApiService gọi endpoint planning qua constants và có fallback mẫu; tree backend chưa thấy planning controller hoặc Gemini service. TripsService sử dụng saved_trips của Supabase. Chỉ chứng minh structure/source, không chứng minh service live, schema deployed hay RLS an toàn.

[PROPOSED] Final design là feature-based Provider client, SQLite drafts/snapshots, Supabase auth/profile/private-trip storage, trusted Gemini orchestration có validator/quota/explicit apply. Ưu tiên bổ sung vào Spring backend đang có bằng adapter sau compatibility review; không yêu cầu dựng backend thứ hai. Logical schema mới được map với saved_trips, không tự đổi tên/xóa dữ liệu.

[PROPOSED] 12 destination đã chốt tăng curated-data workload; 72–120 places/12 samples vẫn là độ sâu đề xuất. Đây là kế hoạch thu thập, chưa có dataset hoặc chứng minh coverage. Thời gian 2026-10-28 không đổi; core acceptance và dữ liệu cần được triển khai kiểm chứng sau gate.

## Trạng thái bàn giao

**APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED.** Chủ dự án đã phê duyệt bộ thiết kế v1.1 và yêu cầu ghi approval/đóng hồ sơ ngày 2026-10-08. [APPROVAL.md](APPROVAL.md) giữ evidence; [HANDOFF.md](HANDOFF.md) giữ quyết định, commit, hiện trạng và điều kiện mở.

Scope/capabilities/proposed policies giữ classification hiện tại. Việc đóng Phase 1 chỉ đóng review thiết kế; không chứng minh runtime/AC đã đạt hoặc quyền provisioning/Phase 2. Metadata closure không sửa nguồn Master Prompt lịch sử.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
