# Travel-Go Mobile — Phase 1 design index

> Version 1.0 • Ngày lập: **2026-10-08** • Approval date baseline: **2026-10-08** • Deadline: **2026-10-28**.
> **APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED.**
> Công bố tài liệu không đóng Phase 1 và không cho phép tự chuyển Phase 2/3.

## Mục lục: đúng 10 deliverables theo S-MP §15

| Thứ tự | Tài liệu | Nội dung |
| --- | --- | --- |
| 01 | [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | Vision, stakeholder, audit/xung đột, feasibility/risk |
| 02 | [PRD.md](PRD.md) | Scope MUST/SHOULD/DEFERRED, MVP và deadline strategy |
| 03 | [FUNCTIONAL_REQUIREMENTS.md](FUNCTIONAL_REQUIREMENTS.md) | 38 FR có source, priority, flow/data/AC traceability |
| 04 | [USER_FLOWS.md](USER_FLOWS.md) | 11 journeys/use cases, alternatives/errors và state |
| 05 | [BUSINESS_RULES.md](BUSINESS_RULES.md) | BR-001–022 baseline, proposed policies, authorization matrix |
| 06 | [ARCHITECTURE.md](ARCHITECTURE.md) | Context/components/ADR, Hybrid AI và A/B/C API Integration Matrix |
| 07 | [DATABASE_DESIGN.md](DATABASE_DESIGN.md) | Conceptual ERD/logical schema/RLS/integrity/ownership |
| 08 | [NON_FUNCTIONAL_REQUIREMENTS.md](NON_FUNCTIONAL_REQUIREMENTS.md) | Security/reliability/performance/usability/offline/maintainability |
| 09 | [ACCEPTANCE_CRITERIA.md](ACCEPTANCE_CRITERIA.md) | 50 acceptance scenarios; tất cả **NOT RUN** |
| 10 | [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | OQ-001–010 baseline + OQ-011–015 audit, assumptions/blockers/owners/due |

## Nguồn và thứ tự ưu tiên

- **S-USER [CONFIRMED]:** yêu cầu trực tiếp ngày 2026-10-08: dùng repo hiện có plhhoang2005/travel-go-mobile, bổ sung 10 design docs trong docs/phase-1 và README/index, không sửa code, verify documentation-only diff rồi commit/push main. Chỉ áp dụng ngoại lệ publication này cho tác vụ tài liệu, không sửa AGENTS/rules lâu dài.
- **S-MP:** file đính kèm **Pasted text.txt**, “MASTER PROMPT — TRAVEL-GO MOBILE”, version 1.0, sections §1–18, status Conditionally Approved, approval 08/10/2026 và deadline 28/10/2026. SHA-256 bytes: **42ae69d1f67b1b5e969ba1c9d89e23f5524b1dd12979f6d2daaaa4200e18b773**. Mọi source §n ở docs tham chiếu section này; không dùng preview conversation thay nội dung file.
- **S-REPO:** snapshot main trước xuất bản [8451fdb](https://github.com/plhhoang2005/travel-go-mobile/tree/8451fdb86943d8e72530fe4f06609529a88512f5), root tree **ef4a16c92986dcad5994704dafaf46665f9fa9a1**. Đã đọc tree (không truncated), README, pubspec, AGENTS và .agent rules/workflow/knowledge để nhận diện khác biệt. Đây là evidence repository có code/dependencies/tài liệu, không chứng minh chức năng live hoặc secrets an toàn.
- **EXT-01–08:** official provider documentation tham khảo 2026-10-08, links và giới hạn evidence ở [06](ARCHITECTURE.md). Chưa kiểm chứng tài khoản, khóa, plan entitlement, deployed endpoints hoặc PoC.

[CONFIRMED] Khi prompt “chưa có codebase” khác repo hiện có, S-USER xác nhận dùng code hiện có; ghi CF-001–007 tại [01](PROJECT_OVERVIEW.md), không rewrite. Các thuật toán/provider/state trong repo không tự đóng các OQ của baseline mới.

## Phân loại bắt buộc

| Nhãn | Ý nghĩa |
| --- | --- |
| [CONFIRMED] | Nội dung được chọn trong S-MP hoặc yêu cầu xuất bản trực tiếp S-USER; không có nghĩa đã implement/test pass |
| [PROPOSED] | Thiết kế/policy/target/plan khuyến nghị, chưa được owner duyệt |
| [OPEN] | Quyết định hoặc validation còn thiếu; recommendation không làm OPEN thành CONFIRMED |
| [DEFERRED] | Chủ động ngoài MVP đầu: booking, notifications, saved-trip offline editing/advanced sync |
| [ASSUMPTION] | Giả định làm việc có người kiểm chứng và impact; không là baseline |

Priority MUST/SHOULD là trục khác với trạng thái. Map/Weather/Community/Group là capability SHOULD [CONFIRMED], provider/policies OPEN hoặc PROPOSED; đề nghị hoãn triển khai SHOULD là PROPOSED. Deadline 2026-10-28 là CONFIRMED, decision/sprint dates là PROPOSED. Unknown dữ liệu không bằng estimated hoặc verified.

## Final design review — 10 mục

1. **Executive summary:** ứng dụng Android học thuật tích hợp discovery, itinerary/manual/AI và budget; publication chỉ tài liệu.
2. **Requirements baseline:** năm MUST, bốn SHOULD; 38 FR và 22 BR có source; giữ năm nhãn.
3. **MVP scope:** core vertical slice 11 bước S-MP §12, Google/email/profile/chat/recommendations/modification vẫn ở baseline, không rút MUST.
4. **Proposed architecture:** feature boundaries + Supabase, trusted AI gateway/validator và local persistence; codebase compatibility OQ-011 chưa duyệt.
5. **Database summary:** private owner aggregate trip/day/item/expense; actual độc lập estimate; provenance/version/receipt; SHOULD model conceptual.
6. **API strategy:** A backend, B external, C local; provider choice/quota/rubric chưa chốt; official references không thay PoC/account verification.
7. **Main risks:** API assessment, accounts/quota, curated data, 20-day window, scope SHOULD, migration/privacy/stale updates.
8. **Open questions:** OQ-001–015 còn OPEN, decision owners/due/blocking impact và assumptions đã ghi.
9. **Acceptance summary:** 50 Given/When/Then, preconditions/expected/priority/method; **NOT RUN**, không claim MVP đạt.
10. **Approval:** checklist dưới đây phân biệt “tài liệu có mặt” với “owner duyệt thiết kế” và “cho phép implementation”.

## Phase 1 approval checklist — pending owner review

- [ ] Chủ dự án review 10 docs và traceability FR→BR→UF→data/API→AC.
- [ ] Xác nhận cách xử lý CF-001–007; nhất là engine/LLM/codebase compatibility.
- [ ] Chốt OQ-001/010 với giảng viên và giữ rubric evidence.
- [ ] Duyệt provider/model AI, data strategy, Guest quota, state/local persistence và migration policies (OQ-002–007/009).
- [ ] Duyệt ADR/model/RLS/permission/quality policies và retention/privacy (OQ-011/015).
- [ ] Duyệt mốc kế hoạch, demo dataset và minimal implementation depth; không cắt MUST ngầm.
- [ ] Quyết định thời điểm triển khai SHOULD; PoC map trước provider approval (OQ-008/012–014).
- [ ] Ghi người duyệt, ngày duyệt, decision evidence và thay đổi từng status có căn cứ.
- [ ] Explicitly approve final Phase 1 design/close Phase 1.
- [ ] Cấp authorization và review kế hoạch Phase 2 riêng; không tự chuyển Phase 2/3.

**Yêu cầu review:** Chủ dự án vui lòng phê duyệt hoặc yêu cầu sửa bộ thiết kế và các quyết định còn mở. Đến khi có evidence explicit approval, trạng thái giữ **APPROVED WITH CONDITIONS**.

## Phạm vi kiểm tra lần xuất bản

Chỉ thay đổi Markdown: 10 design docs + index này + append documentation section vào README gốc. README trước đó giữ nguyên prefix; không sửa lib/, backend/, test/, platform config, dependencies, AGENTS hoặc synced sources/.

Kiểm tra xuất bản gồm count 10 deliverables, links/anchors, IDs và requirement/acceptance coverage; byte-preservation README prefix; Git tree đối chiếu mọi path/blob/mode ngoài allowlist. Các kiểm tra này không là flutter analyze/flutter test hoặc product/security acceptance. Runtime ứng dụng và 50 AC chưa được chạy trong tác vụ tài liệu.
