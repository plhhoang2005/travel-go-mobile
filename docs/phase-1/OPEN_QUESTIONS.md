# 10 — Open questions, assumptions và decision gates

> Phiên bản thiết kế: 1.1 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**.
> Bộ thiết kế v1.1 đã được chủ dự án phê duyệt có điều kiện ngày **2026-10-08**; hồ sơ Phase 1 đóng. Xem [approval](APPROVAL.md) và [bàn giao](HANDOFF.md); Phase 2/3 chưa được phép triển khai.
> Baseline: S-MP (Master Prompt v1.0); đây là kế hoạch kiểm tra/thiết kế, không phải evidence triển khai đã pass.

## Quyền quyết định và cách đọc trạng thái

S-DEC tại [index](README.md) ghi approval trực tiếp của chủ dự án ngày 2026-10-08. OQ-001–015 giữ ID lịch sử; trạng thái v1.1 đã cập nhật, không coi toàn bộ còn OPEN. Một lựa chọn CONFIRMED vẫn có validation/detail OPEN; không mở lại quyết định đã chốt chỉ vì chưa có runtime evidence.

Deadline sản phẩm **2026-10-28 [CONFIRMED]**. Mọi decision/validation due bên dưới **[PROPOSED]**. Phase 1 CLOSED nghĩa review thiết kế đã được phê duyệt có điều kiện theo S-APP-001; không nghĩa OPEN đã giải quyết hoặc implementation được phép.

### OQ-001

- **Trạng thái:** [CONFIRMED]. **Vấn đề:** Rubric API.
- **Nguồn:** S-MP §8.3/10/13; DEC-001.
- **Quyết định/evidence:** Owner xác nhận loại A: external API; không bắt buộc tự phát triển REST. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Gemini live qua server đáp ứng loại integration đã chọn; report/artifact rubric ở OQ-010 vẫn OPEN.
- **Impact/blocker:** Không còn blocker lựa chọn API type; credentials/live evidence là implementation readiness.
- **Decision/validation owner [PROPOSED]:** Chủ dự án / developer.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-002

- **Trạng thái:** [CONFIRMED] provider; [OPEN] model/readiness. **Vấn đề:** AI provider/model.
- **Nguồn:** S-MP §5.4/13; DEC-002/008.
- **Quyết định/evidence:** Gemini provider chính đã duyệt. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Model name/version, account eligibility/quota/keys, structured-output Vietnamese PoC chưa xác minh. Không auto chọn model mới/latest từ tên Gemini.
- **Impact/blocker:** Chặn live AI implementation readiness; không chặn việc hoàn tất tài liệu provider design.
- **Decision/validation owner [PROPOSED]:** Chủ dự án / developer.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-003

- **Trạng thái:** [OPEN]. **Vấn đề:** Missing external data và validator severity.
- **Nguồn:** S-MP §5.4/13; BR-019.
- **Quyết định/evidence:** Disclosure estimated/unknown là baseline CONFIRMED; chi tiết validator policy PROPOSED. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Options: warn unknown; reject known infeasible; owner exception có lý do. Đề xuất BR-P003, provenance contract, không fabricate dữ liệu.
- **Impact/blocker:** Policy chi tiết vẫn cần quyết định trước implementation validation; closure không tự phê duyệt mọi exception/severity.
- **Decision/validation owner [PROPOSED]:** Chủ dự án.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-004

- **Trạng thái:** [OPEN]. **Vấn đề:** Nguồn/quality/freshness catalogue.
- **Nguồn:** S-MP §5.2/13; DEC-004.
- **Quyết định/evidence:** 12 destination CONFIRMED; chưa thu thập dataset. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Options: curated official/operator source và external theo nhu cầu. Đề xuất source/license/attribution/timestamp/field-quality checks; 6–10 places/destination vẫn proposal.
- **Impact/blocker:** Data curation readiness; không giả dữ liệu để báo đủ coverage.
- **Decision/validation owner [PROPOSED]:** Developer / chủ dự án.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-005

- **Trạng thái:** [CONFIRMED] quota policy; [OPEN] enforcement details. **Vấn đề:** Guest AI quota.
- **Nguồn:** S-MP §5.1/13; DEC-003.
- **Quyết định/evidence:** 3 requests/day, reset 00:00 Asia/Ho_Chi_Minh; generation/tư vấn/sửa, no usable system result không trừ. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Đề xuất signed/random Guest subject, used+reserved≤3, durable request idempotency, accepted-day bucket; token expiry/lease/global cap/account quota chưa chốt.
- **Impact/blocker:** Không hỏi lại 3/ngày; technical limits/anti-abuse cần validation trước live integration.
- **Decision/validation owner [PROPOSED]:** Developer / chủ dự án.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-006

- **Trạng thái:** [CONFIRMED] 12 destinations; [PROPOSED] depth. **Vấn đề:** Demo scope.
- **Nguồn:** S-MP §5.2/13; DEC-004.
- **Quyết định/evidence:** Hà Nội, Hạ Long, Sa Pa, Ninh Bình, Huế, Đà Nẵng, Hội An, Nha Trang, Đà Lạt, TP.HCM, Phú Quốc, Cần Thơ. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** 6–10 places/activities mỗi destination và 1 sample ~3 ngày là PROPOSED; options giảm/tăng depth có approval, không âm thầm giảm 12 destination.
- **Impact/blocker:** Chốt depth trước curation; dataset collection/live coverage ở Phase 2 sau authorization.
- **Decision/validation owner [PROPOSED]:** Chủ dự án / developer.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-007

- **Trạng thái:** [CONFIRMED] Provider/SQLite; [OPEN] driver. **Vấn đề:** State/local storage.
- **Nguồn:** S-MP §8.2/8.4/13; DEC-005.
- **Quyết định/evidence:** Giữ Provider; SQLite writable Guest drafts và read-only account snapshots. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Package/driver compatible Android/Windows dev, transaction/recovery/schema migration và credential secure-store implementation cần validation. Không chuyển framework tự động.
- **Impact/blocker:** Không hỏi lại framework/storage; package selection là implementation readiness.
- **Decision/validation owner [PROPOSED]:** Developer.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-008

- **Trạng thái:** [OPEN]. **Vấn đề:** Map provider sau PoC.
- **Nguồn:** S-MP §6.1/13.
- **Quyết định/evidence:** Capability SHOULD baseline giữ; dependency existing không provider approval. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Google Maps/Routes hoặc OSM tiles+router phù hợp; so billing/attribution/coverage/terms bằng PoC sau authorization.
- **Impact/blocker:** Chỉ chặn Map SHOULD, không chặn core manual/AI unknown fallback.
- **Decision/validation owner [PROPOSED]:** Chủ dự án / developer.
- **Due [PROPOSED]:** 2026-10-20.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-009

- **Trạng thái:** [CONFIRMED] migration policy; [PROPOSED] key/state details. **Vấn đề:** Draft migration.
- **Nguồn:** S-MP §5.1/13; DEC-006.
- **Quyết định/evidence:** Login → chọn/confirm draft → server save → ack mới transferred; retry không duplicate; lỗi giữ draft; remote là bản chính. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Owner+draft+revision/digest receipt, pending journal và state chuyển namespace là PROPOSED; edits sau submit cần preview update/copy, không silently overwrite.
- **Impact/blocker:** Chi tiết transaction/state cần decision trước implementation; không hỏi lại quy trình đã chốt.
- **Decision/validation owner [PROPOSED]:** Developer / chủ dự án.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-010

- **Trạng thái:** [OPEN]. **Vấn đề:** Submission artifacts.
- **Nguồn:** S-MP §13; DEC-001 chỉ giải quyết API type.
- **Quyết định/evidence:** Chưa có checklist UML/report/deck/demo chính thức. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Hỏi rubric artifact; Mermaid/10 docs không tự thay mọi yêu cầu nộp.
- **Impact/blocker:** Submission readiness; không ngăn hoàn tất design docs.
- **Decision/validation owner [PROPOSED]:** Chủ dự án hỏi giảng viên.
- **Due [PROPOSED]:** 2026-10-09.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-011

- **Trạng thái:** [CONFIRMED] reuse boundary; [PROPOSED] adapter/deployment; [OPEN] runtime. **Vấn đề:** Code/backend compatibility.
- **Nguồn:** S-REPO-2; DEC-007/008.
- **Quyết định/evidence:** Tái sử dụng phù hợp, không tự rewrite engine; server Gemini + Supabase auth/private persistence. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Tree/code evidence: Spring routing, client fallback, saved_trips. Đề xuất bổ sung Spring Gemini adapter và map legacy schema; hosting HTTPS/auth/version transaction cần validation, Edge alternative cần approval.
- **Impact/blocker:** Implementation plan/compatibility readiness; không đổi platform hoặc bỏ dữ liệu legacy từ docs.
- **Decision/validation owner [PROPOSED]:** Developer / chủ dự án.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-012

- **Trạng thái:** [OPEN]. **Vấn đề:** Weather provider.
- **Nguồn:** S-MP §6.2/10.
- **Quyết định/evidence:** Real API forecast/gợi ý/alerts SHOULD; missing/stale phải rõ. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Open-Meteo candidate đang có service hoặc provider khác qua PoC; eligibility/attribution/freshness/horizon chưa duyệt. Alerts in-app, push vẫn deferred.
- **Impact/blocker:** Weather SHOULD only; AI xử lý unknown không phụ thuộc API này.
- **Decision/validation owner [PROPOSED]:** Developer / chủ dự án.
- **Due [PROPOSED]:** 2026-10-20.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-013

- **Trạng thái:** [OPEN]. **Vấn đề:** Community policies.
- **Nguồn:** S-MP §6.3.
- **Quyết định/evidence:** Community SHOULD, moderation capability confirmed. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Đề xuất author ownership, moderator hide/restore/audit, public opt-in; rating scale/report process/uniqueness cần duyệt.
- **Impact/blocker:** Community SHOULD only, không tự tạo full social subsystem.
- **Decision/validation owner [PROPOSED]:** Chủ dự án.
- **Due [PROPOSED]:** 2026-10-20.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-014

- **Trạng thái:** [OPEN]. **Vấn đề:** Group details.
- **Nguồn:** S-MP §6.4/9.
- **Quyết định/evidence:** Owner/admin, Editor limits, private/version checks baseline confirmed. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Đề xuất Editor itinerary+expense, scoped expiring invitation và atomic version; Editor expense rights/expiry/version merge policy cần review.
- **Impact/blocker:** Group SHOULD only; không tự approve Editor admin quyền.
- **Decision/validation owner [PROPOSED]:** Chủ dự án.
- **Due [PROPOSED]:** 2026-10-20.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.

### OQ-015

- **Trạng thái:** [CONFIRMED] minimal-context/logout; [OPEN] retention/consent details. **Vấn đề:** Privacy/lifecycle.
- **Nguồn:** S-MP §9/11; DEC-009/010.
- **Quyết định/evidence:** Không email/password/token/GPS chính xác mặc định cho Gemini; coarse origin; logout purge local account cache, remote còn. Evidence cho phần đã chốt: các trả lời S-DEC trong chat ngày 2026-10-08; approver: chủ dự án.
- **Options/khuyến nghị/điểm chưa chốt:** Consent UI/provider data terms, raw chat/log retention, proposal/receipt expiry, encryption-at-rest và account deletion chưa chốt. Đề xuất minimal metadata/no durable raw logs trước retention approval.
- **Impact/blocker:** Privacy details cần quyết định trước lưu raw prompt/log hoặc destructive cleanup; approval baseline không tự cấp phép việc này.
- **Decision/validation owner [PROPOSED]:** Chủ dự án / developer.
- **Due [PROPOSED]:** 2026-10-10.
- **Evidence remaining:** Chưa có PoC/runtime/approval cho phần OPEN/PROPOSED; không trình bày là PASS.


## Assumptions và điều kiện bàn giao

| ID | Trạng thái | Nội dung / validation | Owner/due [PROPOSED] |
| --- | --- | --- | --- |
| AS-001 | [ASSUMPTION] | Code hiện có tái sử dụng được một phần; policy reuse confirmed nhưng compatibility chưa runtime-tested | Developer; 2026-10-10 |
| AS-002 | [ASSUMPTION] | Travel money VND và trip timezone Việt Nam; quota reset timezone đã confirmed riêng, không thay approval currency policy | Chủ dự án; 2026-10-10 |
| AS-003 | [ASSUMPTION] | Có thể cấu hình Auth/Google/Gemini accounts sau authorization; chưa xác minh credentials/quota | Chủ dự án; 2026-10-10 |
| AS-004 | [ASSUMPTION] | Thu thập đủ source hợp lệ cho 12 destination theo depth được duyệt kịp hạn | Developer; 2026-10-10 |
| AS-005 | [ASSUMPTION] | Chốt Android demo device/network để benchmark | Developer; 2026-10-15 |
| AS-006 | [CONFIRMED boundary; OPEN mechanics] | Minimal AI context được duyệt DEC-009; runtime user consent/provider retention không tự được duyệt | Chủ dự án; 2026-10-10 |
| AS-007 | [ASSUMPTION] | Một developer có đủ giờ làm cho roadmap; chưa có effort estimate chứng minh | Chủ dự án; 2026-10-10 |

## Deferred register

| ID | Trạng thái | Nội dung |
| --- | --- | --- |
| DF-001 | [DEFERRED]; S-MP §6.5/BR-015 | Booking/reservation/payment; approval scope riêng để mở lại |
| DF-002 | [DEFERRED]; S-MP §6.6 | Push notifications/advanced reminders; không thêm infrastructure |
| DF-003 | [DEFERRED]; S-MP §8.4 | Saved-trip offline editing và advanced sync; Guest drafts local vẫn MUST |
| DF-P001 | [PROPOSED] hoãn SHOULD | Map/Weather/Community/Group nếu ảnh hưởng core; không đổi priority baseline |

## Readiness conditions để review và triển khai riêng

[PROPOSED] RC-001: Chọn model Gemini stable phù hợp, xác minh key/quota/structured-output/tiếng Việt sau authorized PoC; không cần chọn lại provider.
RC-002: SQLite driver/version và secure Guest/session-token storage phù hợp existing packages; không sửa dependencies trong Phase 1.
RC-003: Validate deployed saved_trips/schema/RLS và Spring hosting HTTPS, map adapter, transaction/version/import receipt/quota ledger.
RC-004: Duyệt data depth, source/license và coverage catalogue 12 destination.
RC-005: Duyệt Guest identity/lease/account quota/global cap và privacy consent/retention/cache cleanup mechanics.
RC-006: Submission artifact checklist giảng viên còn OPEN. SHOULD provider/moderation/group decisions không chặn core nếu chưa chọn implementation.

## Closure và điều kiện chuyển tiếp

[CONFIRMED S-APP-001] Chủ dự án đã phê duyệt baseline v1.1 tại commit 2f330e9 và yêu cầu ghi approval/đóng hồ sơ ngày 2026-10-08. **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED**. Evidence/scope ở [APPROVAL.md](APPROVAL.md).

OQ trạng thái CONFIRMED/OPEN/PROPOSED giữ nguyên; RC-001–006 được bàn giao với owner/due tại [HANDOFF.md](HANDOFF.md), không phải hoàn thành ngầm. Phase 2 cần authorization và implementation plan tương thích repo riêng. Không hỏi lại provider, danh sách destination, framework/quota policy đã chốt.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
