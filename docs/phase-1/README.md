# Travel-Go Mobile — Phase 1 design index

> Version **1.1** • Ngày cập nhật: **2026-10-08** • Approval date S-MP baseline: **2026-10-08** • Deadline: **2026-10-28**.
> **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED.**
> Bộ thiết kế v1.1: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED** ngày **2026-10-08**.
> Approval của chủ dự án được ghi tại [APPROVAL.md](APPROVAL.md); điều kiện còn mở bàn giao tại [HANDOFF.md](HANDOFF.md). Phase 2/3 chưa được cấp phép triển khai.

## Mục lục: 10 deliverables theo S-MP §15

| Thứ tự | Tài liệu | Nội dung |
| --- | --- | --- |
| 01 | [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | Vision/stakeholder, audit conflicts, feasibility/risk, codebase observations |
| 02 | [PRD.md](PRD.md) | Five MUST, four SHOULD, 12 destinations, depth proposal và deadline strategy |
| 03 | [FUNCTIONAL_REQUIREMENTS.md](FUNCTIONAL_REQUIREMENTS.md) | 38 FR và nguồn, flow/data/API/acceptance traceability |
| 04 | [USER_FLOWS.md](USER_FLOWS.md) | UF-001–011, alternative/error/state và quota sequence |
| 05 | [BUSINESS_RULES.md](BUSINESS_RULES.md) | BR-001–022, policy details, quota/migration/privacy invariants và permission matrix |
| 06 | [ARCHITECTURE.md](ARCHITECTURE.md) | Provider/SQLite/Supabase/Gemini, server adapter, compatibility, A/B/C API matrix và ADR |
| 07 | [DATABASE_DESIGN.md](DATABASE_DESIGN.md) | ERD, logical schema, saved_trips mapping, SQLite/import/quota ledger và RLS |
| 08 | [NON_FUNCTIONAL_REQUIREMENTS.md](NON_FUNCTIONAL_REQUIREMENTS.md) | Security/reliability/performance/offline/maintainability/privacy |
| 09 | [ACCEPTANCE_CRITERIA.md](ACCEPTANCE_CRITERIA.md) | 55 acceptance cases, tất cả **NOT RUN** |
| 10 | [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | OQ-001–015 cập nhật trạng thái, assumptions, RC-001–006 và gate |

## Nguồn và thứ tự ưu tiên

- **S-USER [CONFIRMED]:** yêu cầu trực tiếp ngày 2026-10-08: dùng repo hiện có plhhoang2005/travel-go-mobile, bổ sung 10 design docs trong docs/phase-1 và README/index, không sửa code, verify documentation-only diff rồi commit/push main. Chỉ áp dụng ngoại lệ publication này cho tác vụ tài liệu, không sửa AGENTS/rules lâu dài.
- **S-MP:** file đính kèm **Pasted text.txt**, “MASTER PROMPT — TRAVEL-GO MOBILE”, version 1.0, sections §1–18, status Conditionally Approved, approval 08/10/2026 và deadline 28/10/2026. SHA-256 bytes: **42ae69d1f67b1b5e969ba1c9d89e23f5524b1dd12979f6d2daaaa4200e18b773**. Mọi source §n ở docs tham chiếu section này; không dùng preview conversation thay nội dung file.
- **S-REPO:** snapshot main trước xuất bản [8451fdb](https://github.com/plhhoang2005/travel-go-mobile/tree/8451fdb86943d8e72530fe4f06609529a88512f5), root tree **ef4a16c92986dcad5994704dafaf46665f9fa9a1**. Đã đọc tree (không truncated), README, pubspec, AGENTS và .agent rules/workflow/knowledge để nhận diện khác biệt. Đây là evidence repository có code/dependencies/tài liệu, không chứng minh chức năng live hoặc secrets an toàn.
- **EXT-01–08:** official provider documentation tham khảo 2026-10-08, links và giới hạn evidence ở [06](ARCHITECTURE.md). Chưa kiểm chứng tài khoản, khóa, plan entitlement, deployed endpoints hoặc PoC.

[CONFIRMED] Khi prompt “chưa có codebase” khác repo hiện có, S-USER xác nhận dùng code hiện có; ghi CF-001–007 tại [01](PROJECT_OVERVIEW.md), không rewrite. Các thuật toán/provider/state trong repo không tự đóng các OQ của baseline mới.


**S-REPO-2:** snapshot tiếp nối [758804c](https://github.com/plhhoang2005/travel-go-mobile/tree/758804ce9bb636e45d3c8d11dcab4b33fed4cc68), tree effa88d091b51bb790cf1fcc2be2f5a4f7a68883. Read-only inspected backend/pom.xml, MapController, MapService, TripApiService, TripsService và recursive tree. Backend chứa routing/health; client trip planning có fallback, persistence dùng saved_trips. Chưa chứng minh Gemini/engine live hoặc deployed RLS/schema. Không đọc/copy secret values.


## Hồ sơ đóng Phase 1

- [APPROVAL.md](APPROVAL.md): approval evidence, baseline được duyệt, phạm vi đóng và các điều kiện không được tự coi là đã giải quyết.
- [HANDOFF.md](HANDOFF.md): quyết định, commit, hiện trạng, RC owners/deadlines và thứ tự công việc tiếp theo.
- Đây là hai hồ sơ bổ trợ, không thay danh sách 10 design deliverables.

## Baseline bổ sung v1.1 — quyết định trực tiếp của chủ dự án

Nguồn **S-DEC** là các trả lời trực tiếp trong chat tiếp nối ngày 2026-10-08, không phải suy luận từ preview. Mọi CONFIRMED dưới đây chỉ xác nhận thiết kế/phạm vi, không xác nhận sản phẩm đã chạy. S-MP v1.0 giữ nguyên làm nguồn lịch sử; S-DEC sửa các lựa chọn vốn OPEN, không sửa bản đính kèm.

| ID | Trạng thái | Quyết định | Evidence trực tiếp | Traceability |
| --- | --- | --- | --- | --- |
| DEC-001 | [CONFIRMED] | Giảng viên yêu cầu tích hợp external API; không bắt buộc tự xây REST API | User chọn “A” cho câu hỏi tiêu chí API | OQ-001; API-B-01; ADR-P1-010 |
| DEC-002 | [CONFIRMED] | Gemini là provider chính; model cụ thể vẫn OPEN | “Gemini đi” | OQ-002; FR-AI-001–005; ADR-P1-008 |
| DEC-003 | [CONFIRMED] | Guest 3 yêu cầu AI/ngày; reset 00:00 Asia/Ho_Chi_Minh; generation/tư vấn/sửa tính lượt; lỗi hệ thống không có kết quả dùng được không trừ | User chọn 3/ngày rồi “ok tôi chốt” toàn bảng backend/privacy/quota | OQ-005; BR-P007; AC-023; AC-051 |
| DEC-004 | [CONFIRMED] | 12 điểm đến: Hà Nội, Hạ Long, Sa Pa, Ninh Bình, Huế, Đà Nẵng, Hội An, Nha Trang, Đà Lạt, TP.HCM, Phú Quốc, Cần Thơ | “chốt danh sách vậy” sau bảng 12 điểm đến | OQ-006; FR-DIS-001–004; AC-052 |
| DEC-005 | [CONFIRMED] | Giữ Provider hiện có; SQLite cho Guest drafts sửa local và saved snapshots chỉ đọc offline | “ok tôi chốt phần này”; phạm vi câu hỏi đã được ghi nhận là Provider/SQLite | OQ-007; ADR-P1-005/006; AC-005/016/045 |
| DEC-006 | [CONFIRMED] | Sau login, user chọn draft để lưu; chỉ báo saved khi server ack; lỗi giữ draft; retry không tạo trùng; ack xong đánh dấu đã chuyển, remote trip là bản chính | “ok tiến hành” trả lời quy trình migration | OQ-009; BR-P001/004; AC-006/039/053 |
| DEC-007 | [CONFIRMED] | Tái sử dụng code/backend phù hợp, audit trước bổ sung, không tự rewrite engine; Supabase quản lý auth/profile/private trips; server kiểm tra quyền | “ok tôi chốt” bảng backend/privacy | OQ-011; FR-SEC-001; ADR-P1-003/004 |
| DEC-008 | [CONFIRMED] | Gemini qua server, secret không ở app; AI trả proposal, chỉ apply itinerary sau user confirmation | Cùng approval DEC-007; đồng thời giữ BR-005/022 baseline | FR-AI-004; FR-SEC-002; AC-020/035/041 |
| DEC-009 | [CONFIRMED] | Chỉ gửi destination/dates/budget/count/interests/activities liên quan; không email/password/token; origin theo thành phố/khu vực, không mặc định gửi GPS chính xác | Cùng approval bảng backend/privacy | OQ-015; NFR-SEC-003/005; AC-047/054 |
| DEC-010 | [CONFIRMED] | Logout xóa cache trip của account trên máy; dữ liệu Supabase còn; không làm lộ snapshot account A cho B | Cùng approval bảng backend/privacy | BR-P010; NFR-OFF-002; AC-040/045/055 |
| DEC-011 | [CONFIRMED] | Hoàn thiện thiết kế Phase 1; không sử dụng superpowers trong tác vụ này | Yêu cầu mới nhất “ok tôi chốt (không sử dụng superpowers) hãy thiết kế để hoàn tất phase 1” | Phạm vi publication tài liệu, không cấp phép code Phase 2 |

[PROPOSED] Mỗi điểm đến 6–10 địa điểm/hoạt động, 1 sample itinerary khoảng 3 ngày: tổng 72–120 places và 12 samples. Chủ dự án chỉ chốt danh sách destination; độ sâu này chưa được duyệt. Thu thập dataset thực không thuộc tác vụ tài liệu.

[OPEN] Model Gemini/quota tài khoản/keys, package SQLite, hosting server và schema deployed cần validation trước implementation. Các chi tiết quota reservation, schema và contract ở dưới là thiết kế PROPOSED; không dùng approval chính sách tổng quát để gắn CONFIRMED cho mọi chi tiết chưa trình.

## Phân loại bắt buộc

| Nhãn | Ý nghĩa |
| --- | --- |
| [CONFIRMED] | Nội dung được chọn trong S-MP hoặc yêu cầu xuất bản trực tiếp S-USER; không có nghĩa đã implement/test pass |
| [PROPOSED] | Thiết kế/policy/target/plan khuyến nghị, chưa được owner duyệt |
| [OPEN] | Quyết định hoặc validation còn thiếu; recommendation không làm OPEN thành CONFIRMED |
| [DEFERRED] | Chủ động ngoài MVP đầu: booking, notifications, saved-trip offline editing/advanced sync |
| [ASSUMPTION] | Giả định làm việc có người kiểm chứng và impact; không là baseline |

Priority MUST/SHOULD là trục khác với trạng thái. Map/Weather/Community/Group là capability SHOULD [CONFIRMED], provider/policies OPEN hoặc PROPOSED; đề nghị hoãn triển khai SHOULD là PROPOSED. Deadline 2026-10-28 là CONFIRMED, decision/sprint dates là PROPOSED. Unknown dữ liệu không bằng estimated hoặc verified.


## Executive final design review v1.1

1. **Vision:** Android học thuật tích hợp discovery/manual/AI planning/budget, phục vụ người đi Việt Nam cá nhân/nhóm.
2. **Baseline:** 38 FR/22 BR; năm MUST giữ nguyên, bốn SHOULD không vượt core; booking/notifications/saved offline editing DEFERRED.
3. **Scope:** 12 destination CONFIRMED, 72–120 places/12 samples PROPOSED; coverage thực cần curation/evidence, không seed fake data.
4. **Architecture:** Provider/SQLite đã chốt; Supabase Auth/profile/private data; Gemini via trusted server; Spring adapter là proposal tương thích, không dựng backend thay thế tự động.
5. **Data:** Canonical itinerary cho manual/AI; owner/version/receipts/provenance; actual độc lập estimate; logical schema phải map saved_trips trước migration.
6. **API:** Rubric chỉ external API đã confirmed; Gemini live là core integration. 3 Guest requests/calendar day Vietnam; application quota tách provider quota; reservation/idempotency cơ chế PROPOSED.
7. **Privacy:** Minimal context, coarse origin, no email/password/token/default precise GPS; backend auth/RLS; logout purge local account cache, remote trip còn.
8. **Reliability:** Explicit proposal preview/apply; stale reject; migration ack/retry no duplicates; offline local draft writable, saved snapshot read-only; manual fallback khi AI lỗi.
9. **Remaining conditions:** Model/account readiness, SQLite driver, hosting/schema/RLS compatibility, data-depth/source/license, Guest identity/account cap, consent/retention và submission checklist; maps/weather/community/group còn OPEN nếu chọn SHOULD.
10. **Acceptance/gate:** 55 cases NOT RUN. Chủ dự án đã phê duyệt có điều kiện baseline v1.1 và yêu cầu ghi approval/đóng hồ sơ; Phase 1 đóng. RC còn mở và authorization Phase 2/3 vẫn riêng.

## Phase 1 approval checklist

### Các lựa chọn đã được chủ dự án xác nhận

- [x] External API criterion — DEC-001.
- [x] Gemini provider chính — DEC-002.
- [x] Guest 3/ngày, reset 00:00 Vietnam, no usable system result không trừ — DEC-003.
- [x] Danh sách 12 destination — DEC-004.
- [x] Provider + SQLite, Guest writable và saved snapshot read-only — DEC-005.
- [x] Migration có lựa chọn/confirmation/ack/retry no duplicate — DEC-006.
- [x] Reuse code/backend phù hợp, Supabase và Gemini server-side/explicit apply — DEC-007/008.
- [x] Minimal AI context/coarse origin và logout purge local account cache — DEC-009/010.
- [x] Hoàn thiện Phase 1 design, không sử dụng superpowers trong lần cập nhật — DEC-011.

### Approval cuối và đóng hồ sơ

- [x] Chủ dự án phê duyệt bộ thiết kế v1.1 tại commit 2f330e9; evidence S-APP-001 trong APPROVAL.md.
- [x] Ghi approval có điều kiện ngày 2026-10-08; Phase 1 CLOSED, không còn chờ approval artifact v1.1.
- [x] Giữ nguyên các quyết định CONFIRMED DEC-001–011 và 10 design deliverables.
- [x] Bàn giao details PROPOSED/OPEN và RC-001–006, không đánh dấu đã hoàn thành validation.
- [ ] Chốt data depth, driver/model/hosting và policies chi tiết còn mở trước operation implementation tương ứng.
- [ ] Cấp authorization Phase 2 và duyệt implementation plan riêng; chưa có tại thời điểm đóng hồ sơ.

**Closure record:** [APPROVAL.md](APPROVAL.md) là nguồn approval; [HANDOFF.md](HANDOFF.md) là điểm bắt đầu cho session tiếp theo. Phê duyệt thiết kế có điều kiện không là nghiệm thu ứng dụng hoặc cấp quyền tự triển khai.

## Verification lần xuất bản v1.1

Scope đúng 12 Markdown files: 10 docs + index + README root. Giữ phần hướng dẫn cài đặt gốc ở README root; chỉ cập nhật section Phase 1. Đối chiếu mọi blob/mode ngoài allowlist để bảo vệ lib/backend/test/platform/dependencies/AGENTS và tài liệu khác. Synced sources/ chỉ đọc.

Kiểm count/unique IDs, cross-links/anchors, 55 cases đầy đủ fields, quota/provider/state/privacy decisions đồng nhất và trạng thái closed/open phân biệt. Verification tài liệu không là Flutter analyze/test, live provider/PoC hoặc evidence 55 acceptance đã đạt.

## Verification lần đóng hồ sơ

Scope lần closure: 14 Markdown files — 10 tài liệu thiết kế, index Phase 1, README root và hai hồ sơ APPROVAL/HANDOFF. So sánh với commit v1.1; mọi file ngoài phạm vi này phải giữ nguyên nội dung và mode. Không chạy hoặc tuyên bố nghiệm thu ứng dụng; 55 acceptance cases vẫn NOT RUN.

## Lịch sử phiên bản

| Version | Date | Nội dung |
| --- | --- | --- |
| 1.0 | 2026-10-08 | Conditional design baseline theo S-MP, 38 FR/22 BR/50 AC; commit 758804c |
| 1.1 | 2026-10-08 | Ghi DEC-001–011; Gemini/3 Guest requests/12 destinations/Provider+SQLite/migration/privacy; bổ sung AC-051–055 và integration/readiness design; tại thời điểm xuất bản v1.1 còn chờ final artifact review; đã được duyệt ở closure record bên dưới |
| Closure record | 2026-10-08 | S-APP-001 ghi approval baseline v1.1, đóng Phase 1 có điều kiện; chuyển remaining readiness items sang HANDOFF.md, không thay scope hoặc triển khai |
