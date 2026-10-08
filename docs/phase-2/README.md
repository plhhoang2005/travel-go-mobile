# Phase 2 — kế hoạch sửa và bàn giao Antigravity

Ngày 2026-10-08; deadline **2026-10-28 [CONFIRMED]**. Plan **REPAIR-v1**.
Baseline [4140712](https://github.com/plhhoang2005/travel-go-mobile/commit/41407120c7aac598b402e7e6aaef84e920ff7e2d). Phase 1 giữ **CLOSED — APPROVED WITH CONDITIONS**.

| Đọc theo thứ tự | Nội dung |
| --- | --- |
| [EVIDENCE.md](EVIDENCE.md) | Checkout/tests, hai snapshots metadata và RC status |
| [SCHEMA_REVIEW.md](SCHEMA_REVIEW.md) | DB-001–006, cấu trúc thực và rủi ro |
| [REPAIR_PLAN.md](REPAIR_PLAN.md) | Task dependencies, exact allowlists, contracts/tests/rollout |
| [ANTIGRAVITY_HANDOFF.md](ANTIGRAVITY_HANDOFF.md) | Prompt triển khai và format trả kết quả Codex review |

**CONFIRMED:** Codex phân tích/plan/review; Antigravity triển khai; Gemini, Provider/SQLite, Guest 3 AI logical requests/ngày reset theo Việt Nam; 12 điểm đến, minimum 6 places + 1 sample/điểm đến. Không sử dụng superpowers.

**Authorization evidence:** owner yêu cầu “hoàn thiện và đưa kế hoạch sửa lên GitHub, rồi bàn giao Antigravity triển khai”. Codex publish docs và handoff; owner chuyển packet vào Antigravity làm execution instruction cho batch A. Không blanket approve mọi Phase 3 task, dependency/native/rule changes, provisioning/billing hoặc live DB rollout. Không hỏi lại quyết định đã chốt.

**PROPOSED:** REPAIR-v1 technical contracts và reuse trips/Supabase hiện tại; không tạo repo/project thay thế. **OPEN:** deployed function body/config, REST 401, live tests, Gemini/model/host/import version, submission checklist. **DEFERRED:** booking/payments/push/account trip offline editing. **ASSUMPTION:** metadata owner xuất đúng project, chưa independent authenticated tool verification.

Publication chỉ thêm 5 Markdown files docs/phase-2, không sửa Phase 1/code/permanent guidance. Repo AGENTS yêu cầu feature branch/PR/human merge; không push main trực tiếp. Antigravity đọc packet trên documentation branch ngay để inspect, ghi exact docs SHA. Code/migrations ở PR triển khai sau; Phase 2 chưa COMPLETE và các lỗi chưa RESOLVED từ việc viết docs.

