# 03 — Yêu cầu chức năng và traceability

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**.
> Bộ thiết kế v1.1 đã được chủ dự án phê duyệt có điều kiện ngày **2026-10-08**; hồ sơ Phase 1 đóng. Xem [approval](APPROVAL.md) và [bàn giao](HANDOFF.md); Phase 2/3 chưa được phép triển khai.
> Baseline: S-MP (Master Prompt v1.0); đây là đặc tả thiết kế, không phải bằng chứng tính năng đã triển khai hoặc Phase 1 đã được đóng.

## Quy ước requirement và nguồn

Mỗi FR dưới đây có một trạng thái, mức ưu tiên riêng và nguồn cụ thể. [CONFIRMED] là nội dung S-MP đã chọn; chưa có nghĩa code hiện tại đã đáp ứng. Các chi tiết policy/contract/model đề xuất nằm ở BR-P*, ADR-P1-* và DB-*.

Nguồn § là section của S-MP; BR là [05](BUSINESS_RULES.md); UF là [04](USER_FLOWS.md); data là [07](DATABASE_DESIGN.md); AC là [09](ACCEPTANCE_CRITERIA.md). S-USER xác nhận phạm vi publication; S-DEC tại [index](README.md) xác nhận các lựa chọn v1.1.

## Danh mục và traceability

| ID | Trạng thái | Ưu tiên | Nội dung yêu cầu | Nguồn | Flow | Data/component | Acceptance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <a id="fr-acc-001"></a>FR-ACC-001 | [CONFIRMED] | MUST | Khám phá ở chế độ Guest không cần đăng nhập. | S-MP §5.1; BR-001 | UF-001 | destinations | [AC-001](ACCEPTANCE_CRITERIA.md#ac-001) |
| <a id="fr-acc-002"></a>FR-ACC-002 | [CONFIRMED] | MUST | Đăng ký, đăng nhập email/password và duy trì phiên tài khoản. | S-MP §5.1; BR-002 | UF-004 | Auth; profiles | [AC-002](ACCEPTANCE_CRITERIA.md#ac-002) |
| <a id="fr-acc-003"></a>FR-ACC-003 | [CONFIRMED] | MUST | Google Sign-In; hủy đăng nhập không làm mất bản nháp. | S-MP §5.1; BR-002 | UF-004 | Auth; profiles | [AC-003](ACCEPTANCE_CRITERIA.md#ac-003) |
| <a id="fr-acc-004"></a>FR-ACC-004 | [CONFIRMED] | MUST | Xem/sửa hồ sơ riêng tư: sở thích, ngân sách điển hình, phong cách. | S-MP §5.1; BR-003 | UF-005 | profiles | [AC-004](ACCEPTANCE_CRITERIA.md#ac-004) |
| <a id="fr-acc-005"></a>FR-ACC-005 | [CONFIRMED] | MUST | Guest lưu draft cục bộ và phục hồi sau khởi động lại. | S-MP §5.1; BR-016 | UF-002 | LocalDraft | [AC-005](ACCEPTANCE_CRITERIA.md#ac-005) |
| <a id="fr-acc-006"></a>FR-ACC-006 | [CONFIRMED] | MUST | Lưu/đồng bộ vào tài khoản cần xác thực; thiết kế chuyển Guest draft và quản lý phiên. | S-MP §5.1; BR-016; §13 OQ-009 | UF-004 | trips; LocalDraft | [AC-006](ACCEPTANCE_CRITERIA.md#ac-006) |
| <a id="fr-dis-001"></a>FR-DIS-001 | [CONFIRMED] | MUST | Danh sách và tìm kiếm điểm đến Việt Nam. | S-MP §5.2 | UF-001 | destinations | [AC-007](ACCEPTANCE_CRITERIA.md#ac-007) |
| <a id="fr-dis-002"></a>FR-DIS-002 | [CONFIRMED] | MUST | Chi tiết điểm đến, thông tin du lịch và nguồn/chất lượng/độ mới dữ liệu hybrid. | S-MP §5.2; BR-019 | UF-001 | destinations; places | [AC-008](ACCEPTANCE_CRITERIA.md#ac-008) |
| <a id="fr-dis-003"></a>FR-DIS-003 | [CONFIRMED] | MUST | Khám phá theo sở thích và chọn điểm đến để tạo trip. | S-MP §5.2 | UF-001 | destinations; trips | [AC-009](ACCEPTANCE_CRITERIA.md#ac-009) |
| <a id="fr-dis-004"></a>FR-DIS-004 | [CONFIRMED] | MUST | Người mới có thể khám phá lịch trình mẫu. | S-MP §5.2; BR-014 | UF-001 | SampleItinerary | [AC-010](ACCEPTANCE_CRITERIA.md#ac-010) |
| <a id="fr-trp-001"></a>FR-TRP-001 | [CONFIRMED] | MUST | Nhập điểm đến, ngày bắt đầu/kết thúc, ngân sách, số người, sở thích và nơi xuất phát. | S-MP §5.3 | UF-002; UF-003 | trips | [AC-011](ACCEPTANCE_CRITERIA.md#ac-011) |
| <a id="fr-trp-002"></a>FR-TRP-002 | [CONFIRMED] | MUST | Tạo lịch trình thủ công dùng cùng mô hình itinerary với AI. | S-MP §5.3; BR-004 | UF-002 | trip_days; itinerary_items | [AC-012](ACCEPTANCE_CRITERIA.md#ac-012) |
| <a id="fr-trp-003"></a>FR-TRP-003 | [CONFIRMED] | MUST | Xếp theo ngày/giờ; thêm, xóa, đổi thứ tự và sửa hoạt động. | S-MP §5.3 | UF-002; UF-006 | trip_days; itinerary_items | [AC-013](ACCEPTANCE_CRITERIA.md#ac-013) |
| <a id="fr-trp-004"></a>FR-TRP-004 | [CONFIRMED] | MUST | Preview, xác nhận và lưu trip. | S-MP §5.3; §12 | UF-004; UF-006 | trips; itinerary_items | [AC-014](ACCEPTANCE_CRITERIA.md#ac-014) |
| <a id="fr-trp-005"></a>FR-TRP-005 | [CONFIRMED] | MUST | Xem danh sách trip đã lưu và mở lại chi tiết. | S-MP §5.3 | UF-007 | trips | [AC-015](ACCEPTANCE_CRITERIA.md#ac-015) |
| <a id="fr-trp-006"></a>FR-TRP-006 | [CONFIRMED] | MUST | Xem itinerary đã lưu offline ở chế độ chỉ đọc. | S-MP §5.3; §8.4 | UF-007 | OfflineSnapshot | [AC-016](ACCEPTANCE_CRITERIA.md#ac-016) |
| <a id="fr-ai-001"></a>FR-AI-001 | [CONFIRMED] | MUST | Đề xuất điểm đến/hoạt động cá nhân hóa theo sở thích. | S-MP §5.4 | UF-003 | destinations; ai_plan_requests | [AC-017](ACCEPTANCE_CRITERIA.md#ac-017) |
| <a id="fr-ai-002"></a>FR-AI-002 | [CONFIRMED] | MUST | Sinh itinerary cá nhân hóa qua external AI kết hợp dữ liệu có cấu trúc và validation. | S-MP §5.4; BR-004; BR-006 | UF-003 | ai_plan_requests; trip_days; itinerary_items | [AC-018](ACCEPTANCE_CRITERIA.md#ac-018) |
| <a id="fr-ai-003"></a>FR-AI-003 | [CONFIRMED] | MUST | Chat hỗ trợ du lịch theo ngữ cảnh; tư vấn không tự ghi thay đổi trip. | S-MP §5.4 | UF-003 | ai_plan_requests | [AC-019](ACCEPTANCE_CRITERIA.md#ac-019) |
| <a id="fr-ai-004"></a>FR-AI-004 | [CONFIRMED] | MUST | AI đề xuất sửa itinerary: preview khác biệt và chỉ áp dụng sau xác nhận rõ ràng. | S-MP §5.4; BR-005 | UF-006 | ai_plan_requests; trips | [AC-020](ACCEPTANCE_CRITERIA.md#ac-020) |
| <a id="fr-ai-005"></a>FR-AI-005 | [CONFIRMED] | MUST | Xét ngân sách, giờ mở cửa, thời gian di chuyển, vị trí, thời tiết, sở thích; phân biệt verified/estimated/unknown. | S-MP §5.4; BR-006; BR-019 | UF-003 | places; itinerary_items; ai_plan_requests | [AC-021](ACCEPTANCE_CRITERIA.md#ac-021) |
| <a id="fr-ai-006"></a>FR-AI-006 | [CONFIRMED] | MUST | API AI lỗi vẫn có thể dùng planner thủ công. | S-MP §5.4; BR-020 | UF-003; UF-002 | LocalDraft | [AC-022](ACCEPTANCE_CRITERIA.md#ac-022) |
| <a id="fr-ai-007"></a>FR-AI-007 | [CONFIRMED] | MUST | Guest được 3 yêu cầu AI/ngày, reset 00:00 giờ Việt Nam; lỗi hệ thống không trả kết quả dùng được không trừ lượt (DEC-003). | S-MP §5.1; BR-017; S-DEC DEC-003 | UF-003 | GuestAIRequest; ai_plan_requests | [AC-023](ACCEPTANCE_CRITERIA.md#ac-023) |
| <a id="fr-bud-001"></a>FR-BUD-001 | [CONFIRMED] | MUST | Quản lý tổng ngân sách và chi phí dự kiến. | S-MP §5.5; BR-007 | UF-008 | trips; trip_expenses | [AC-024](ACCEPTANCE_CRITERIA.md#ac-024) |
| <a id="fr-bud-002"></a>FR-BUD-002 | [CONFIRMED] | MUST | Ghi/sửa chi phí thực tế và phân loại khoản chi, tách khỏi dự kiến. | S-MP §5.5; BR-007 | UF-008 | trip_expenses | [AC-025](ACCEPTANCE_CRITERIA.md#ac-025) |
| <a id="fr-bud-003"></a>FR-BUD-003 | [CONFIRMED] | MUST | So sánh ngân sách, số còn lại và cảnh báo vượt; không chặn tạo/sửa. | S-MP §5.5; BR-008 | UF-008 | trips; trip_expenses | [AC-026](ACCEPTANCE_CRITERIA.md#ac-026) |
| <a id="fr-bud-004"></a>FR-BUD-004 | [CONFIRMED] | MUST | Thay itinerary cập nhật estimate liên quan và giữ actual expenses. | S-MP §5.5 | UF-006; UF-008 | itinerary_items; trip_expenses | [AC-027](ACCEPTANCE_CRITERIA.md#ac-027) |
| <a id="fr-map-001"></a>FR-MAP-001 | [CONFIRMED] | SHOULD | Khi triển khai: pins, routes, distances; provider OPEN và cần PoC. | S-MP §6.1; BR-012 | UF-009 | places | [AC-028](ACCEPTANCE_CRITERIA.md#ac-028) |
| <a id="fr-wea-001"></a>FR-WEA-001 | [CONFIRMED] | SHOULD | Khi triển khai: API thời tiết thật, forecast, gợi ý và cảnh báo; xử lý stale/unavailable. | S-MP §6.2; BR-013 | UF-009 | WeatherSnapshot | [AC-029](ACCEPTANCE_CRITERIA.md#ac-029) |
| <a id="fr-com-001"></a>FR-COM-001 | [CONFIRMED] | SHOULD | Khi triển khai: blog, review/rating, comment, like do người dùng xuất bản. | S-MP §6.3 | UF-010 | posts; reviews; comments; likes | [AC-030](ACCEPTANCE_CRITERIA.md#ac-030) |
| <a id="fr-com-002"></a>FR-COM-002 | [CONFIRMED] | SHOULD | Khi triển khai: quyền sở hữu, riêng tư và quản trị nội dung không phù hợp. | S-MP §6.3; BR-011 | UF-010 | posts; reviews; comments | [AC-031](ACCEPTANCE_CRITERIA.md#ac-031) |
| <a id="fr-grp-001"></a>FR-GRP-001 | [CONFIRMED] | SHOULD | Khi triển khai: Owner/Editor, mời và sửa chung; Owner quản lý thành viên/xóa trip, private mặc định. | S-MP §6.4; BR-009; BR-010 | UF-011 | trip_members; TripInvitation | [AC-032](ACCEPTANCE_CRITERIA.md#ac-032) |
| <a id="fr-grp-002"></a>FR-GRP-002 | [CONFIRMED] | SHOULD | Khi triển khai: version checking phát hiện stale; cảnh báo/từ chối conflict. | S-MP §6.4; BR-018 | UF-011 | trips | [AC-033](ACCEPTANCE_CRITERIA.md#ac-033) |
| <a id="fr-sec-001"></a>FR-SEC-001 | [CONFIRMED] | MUST | Backend authorization bảo vệ trip riêng tư và hồ sơ cá nhân. | S-MP §7 BR-009; BR-021; §11 | UF-004; UF-007 | trips; profiles; trip_expenses | [AC-034](ACCEPTANCE_CRITERIA.md#ac-034) |
| <a id="fr-sec-002"></a>FR-SEC-002 | [CONFIRMED] | MUST | Không nhúng sensitive API credentials vào mobile; tích hợp nhạy cảm qua backend. | S-MP §7 BR-022; §8.3 | UF-003 | ServerSecret | [AC-035](ACCEPTANCE_CRITERIA.md#ac-035) |
| <a id="fr-def-001"></a>FR-DEF-001 | [DEFERRED] | DEFERRED | Không triển khai booking, reservation transaction hoặc thanh toán. | S-MP §6.5; BR-015 | Ngoài luồng MVP | Không tạo bảng MVP | [AC-036](ACCEPTANCE_CRITERIA.md#ac-036) |
| <a id="fr-def-002"></a>FR-DEF-002 | [DEFERRED] | DEFERRED | Không triển khai push notifications/advanced reminders. | S-MP §6.6 | Ngoài luồng MVP | Không tạo bảng MVP | [AC-037](ACCEPTANCE_CRITERIA.md#ac-037) |
| <a id="fr-def-003"></a>FR-DEF-003 | [DEFERRED] | DEFERRED | Offline editing của trip đã lưu và advanced sync ngoài MVP; Guest drafts vẫn sửa local. | S-MP §8.4 | UF-007 | OfflineSnapshot | [AC-038](ACCEPTANCE_CRITERIA.md#ac-038) |

## Phụ thuộc và hợp đồng dùng chung

| Nhóm FR | Phụ thuộc bắt buộc | API/operation [PROPOSED] | Chính sách/chưa chốt |
| --- | --- | --- | --- |
| FR-ACC-001; FR-DIS-001–004 | Catalogue được phép công bố | API-A-02; LOCAL-01 | OQ-004/006 |
| FR-ACC-002–004/006 | Supabase Auth; profile owner | API-A-01/03/04 | OQ-009; BR-P001 |
| FR-ACC-005 | SQLite drafts và ownership thiết bị [CONFIRMED DEC-005] | LOCAL-02 | Package còn OPEN; migration DEC-006 |
| FR-TRP-001–003 | Common itinerary model | LOCAL-01/03 | BR-P002/003 |
| FR-TRP-004–006 | Auth + RLS + transaction snapshot | API-A-04/05; LOCAL-02 | BR-P004/005 |
| FR-AI-001–007 | Gemini server-side và 3 Guest lượt/ngày [CONFIRMED DEC-002/003/008] | API-A-06; API-B-01 | Model/reservation detail vẫn OPEN/PROPOSED; BR-P006/007 |
| FR-BUD-001–004 | Expense kind và itinerary identity | API-A-05; LOCAL-03 | BR-P008/009 |
| FR-MAP-001; FR-WEA-001 | Provider + timestamp/rights | API-B-02/03/04 | OQ-008/012 |
| FR-COM-001/002 | Auth, content ownership, moderation | API-A-08 | OQ-013 |
| FR-GRP-001/002 | Owner/member authorization, version | API-A-07 | OQ-014; BR-P005 |
| FR-SEC-001/002 | RLS; server JWT/Guest policy; secrets | Tất cả API remote | NFR-SEC-001–005 |

[PROPOSED] Auth không là tiền điều kiện khám phá, manual draft hoặc quota-limited Guest AI. Remote private-trip read/write cần authenticated subject; Guest AI dùng policy gateway riêng, không cấp quyền ghi private tables.

## Requirement audit: khoảng trống chưa tự giải quyết

[CONFIRMED] S-DEC đóng lựa chọn external API, Gemini provider, Guest 3/ngày, Provider/SQLite và quy trình migration. [OPEN] Model Gemini, package SQLite, dataset depth/source verification, quota implementation details và privacy retention vẫn cần validation/duyệt; xem [10](OPEN_QUESTIONS.md).

[CONFIRMED] MUST chat, recommendation và modification không được lược khỏi baseline chỉ vì generation được demo. [CONFIRMED] Private by default và backend authorization phải có ở MVP dù collaboration hoãn. [DEFERRED] Booking/notifications không sinh API/table MVP.

## Ma trận kiểm tra liên tài liệu

[PROPOSED] Khi review, đối chiếu từng dòng catalogue: nguồn phải có; BR phù hợp; UF có happy/negative path; model giữ dữ liệu; operation có failure/fallback; AC có precondition và expected result. ID tồn tại không đồng nghĩa yêu cầu đã đạt; trạng thái acceptance ban đầu là NOT RUN.

## Traceability quyết định bổ sung

[CONFIRMED] DEC-001 → external AI integration; DEC-002/008 → FR-AI-* và FR-SEC-002; DEC-003 → FR-AI-007; DEC-004 → FR-DIS-*; DEC-005 → FR-ACC-005/FR-TRP-006; DEC-006 → FR-ACC-006; DEC-007/009/010 → FR-SEC-001/002. Acceptance bổ sung AC-051–055 kiểm quota/date, catalogue breadth, migration consent và privacy/cache. Không thêm module MUST ngoài baseline.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
