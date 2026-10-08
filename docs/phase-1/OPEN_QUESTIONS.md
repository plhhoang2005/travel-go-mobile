# 10 — Open questions, assumptions và decision gates

> Phiên bản thiết kế: 1.0 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED**.
> Baseline: S-MP (Master Prompt v1.0); đây là kế hoạch kiểm tra/thiết kế, không phải evidence triển khai đã pass.

## Quyền quyết định và trạng thái

**Mọi OQ bên dưới: [OPEN], chưa có quyết định cuối, chưa có evidence approval.** Các đề xuất giải pháp không đổi trạng thái OPEN. OQ-001–010 giữ ID từ S-MP §13; OQ-011–015 là khoảng trống bổ sung từ audit. Mốc quyết định bên dưới **[PROPOSED]**, timezone Asia/Saigon; deadline sản phẩm **2026-10-28 [CONFIRMED]**.

Bộ thiết kế có thể công bố với conditional status. Final architecture approval/Phase 2 implementation không được tự tiếp tục khi blocker chưa quyết định hoặc chưa có authorization riêng.

### OQ-001

- **Trạng thái:** [OPEN]. **Vấn đề:** Rubric API của giảng viên.
- **Nguồn:** S-MP §8.3/10/13.
- **Vì sao quan trọng / tác động:** Supabase APIs có thể chưa đáp ứng yêu cầu tự phát triển REST; chọn sai ảnh hưởng đánh giá và backend.
- **Options:** External API; tự phát triển REST; cả hai; Supabase đủ.
- **Khuyến nghị [PROPOSED]:** Hỏi giảng viên bằng rubric/phản hồi có lưu evidence; không giả định Supabase đủ.
- **Decision owner [PROPOSED]:** Chủ dự án hỏi giảng viên.
- **Decision deadline [PROPOSED]:** 2026-10-09.
- **Blocker:** Final architecture approval và API implementation.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-002

- **Trạng thái:** [OPEN]. **Vấn đề:** Provider/model AI.
- **Nguồn:** S-MP §5.4/13.
- **Vì sao quan trọng / tác động:** Chi phí, quota, Vietnamese/structured output, privacy và key availability quyết định luồng MUST.
- **Options:** Gemini candidate; provider khác qua adapter nếu duyệt.
- **Khuyến nghị [PROPOSED]:** So tài liệu chính thức + PoC sau authorization; không chốt model từ tên ứng viên.
- **Decision owner [PROPOSED]:** Chủ dự án / developer.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** AI implementation và final integration approval.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-003

- **Trạng thái:** [OPEN]. **Vấn đề:** Policy missing map/weather/opening hours.
- **Nguồn:** S-MP §5.4/13.
- **Vì sao quan trọng / tác động:** Ảnh hưởng tính thực tế và cách validator diễn giải unknown.
- **Options:** Chỉ curated known; allow estimate có nguồn; giữ unknown với warnings.
- **Khuyến nghị [PROPOSED]:** Theo BR-P003 và quality contract; known closure/error có severity; không fabricate.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Validator/detail-policy approval, không chặn soạn thiết kế.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-004

- **Trạng thái:** [OPEN]. **Vấn đề:** Thu thập/duy trì/verify dữ liệu Việt Nam.
- **Nguồn:** S-MP §5.2/13.
- **Vì sao quan trọng / tác động:** Coverage, quyền sử dụng, freshness, sample quality.
- **Options:** Curated có nguồn chính thức; external provider; hybrid.
- **Khuyến nghị [PROPOSED]:** Hybrid curated nhỏ và external theo nhu cầu; provenance từng trường, trách nhiệm curator.
- **Decision owner [PROPOSED]:** Chủ dự án / developer.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Discovery data implementation và final data approval.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-005

- **Trạng thái:** [OPEN]. **Vấn đề:** Quota Guest AI chính xác.
- **Nguồn:** S-MP §5.1/13.
- **Vì sao quan trọng / tác động:** Abuse/cost và trải nghiệm Guest; quota số không có trong baseline.
- **Options:** Per-session/per-device/per-day token; auth quotas riêng; total app cap.
- **Khuyến nghị [PROPOSED]:** Server enforcement và manual khi hết; chốt Q/window/reset/privacy, không dùng IP đơn lẻ như identity.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Guest AI implementation; không thay yêu cầu Guest AI giới hạn.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-006

- **Trạng thái:** [OPEN]. **Vấn đề:** Số destination/sample demo.
- **Nguồn:** S-MP §5.2/13.
- **Vì sao quan trọng / tác động:** Một developer cần dataset đủ kiểm chứng nhưng không quá rộng.
- **Options:** Một luồng điểm đến có nhiều places; vài khu vực tương phản; catalogue rộng.
- **Khuyến nghị [PROPOSED]:** Chọn số cụ thể cùng giảng viên và coverage AC; không invent quy mô confirmed.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Dataset/demo planning; không chặn logical architecture.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-007

- **Trạng thái:** [OPEN]. **Vấn đề:** State management và local persistence.
- **Nguồn:** S-MP §8.2/8.4/13.
- **Vì sao quan trọng / tác động:** Framework migration và atomic restart recovery.
- **Options:** Provider hiện có/Riverpod/BLoC; SQLite wrapper/key-value.
- **Khuyến nghị [PROPOSED]:** Ưu tiên Provider tương thích, đánh giá SQLite cho relational/atomic store; quyết định cuối vẫn OPEN.
- **Decision owner [PROPOSED]:** Chủ dự án / developer.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Mobile application/state/local-store implementation.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-008

- **Trạng thái:** [OPEN]. **Vấn đề:** Map provider sau PoC.
- **Nguồn:** S-MP §6.1/13.
- **Vì sao quan trọng / tác động:** Billing/attribution/Việt Nam routing accuracy; map không là core blocker.
- **Options:** Google Maps/Routes; OSM-compatible tile host + routing provider.
- **Khuyến nghị [PROPOSED]:** PoC Android/Vietnam/failure/cost restrictions sau gate; không dùng standard tiles cho offline bulk.
- **Decision owner [PROPOSED]:** Chủ dự án / developer.
- **Decision deadline [PROPOSED]:** 2026-10-20.
- **Blocker:** Map SHOULD implementation và provider approval; không chặn core manual.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-009

- **Trạng thái:** [OPEN]. **Vấn đề:** Draft migration duplicate và interrupted sync.
- **Nguồn:** S-MP §5.1/13.
- **Vì sao quan trọng / tác động:** Mất draft hoặc duplicate trip; privacy trên shared device.
- **Options:** Always copy; content dedupe; identity/revision idempotency và receipt.
- **Khuyến nghị [PROPOSED]:** BR-P001: owner+draft+revision; chọn khi revision mới update/copy, thời điểm purge và lựa chọn drafts.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Auth/import implementation và final persistence approval.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-010

- **Trạng thái:** [OPEN]. **Vấn đề:** UML/ERD/reports/demo submission rubric.
- **Nguồn:** S-MP §13.
- **Vì sao quan trọng / tác động:** Có thể thiếu artifact môn học nếu chỉ Markdown.
- **Options:** Mermaid đủ; export UML/ERD; report/deck/demo theo mẫu.
- **Khuyến nghị [PROPOSED]:** Lấy checklist chính thức của giảng viên; bộ 10 docs không tự thay rubric.
- **Decision owner [PROPOSED]:** Chủ dự án hỏi giảng viên.
- **Decision deadline [PROPOSED]:** 2026-10-09.
- **Blocker:** Submission readiness; không chặn conceptual design.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-011

- **Trạng thái:** [OPEN]. **Vấn đề:** Đối chiếu codebase và vai trò backend/LLM.
- **Nguồn:** S-USER; S-REPO; CF-001/003/004/005.
- **Vì sao quan trọng / tác động:** Engine cũ chỉ explainer khác Hybrid AI baseline, knowledge có thể cũ.
- **Options:** Giữ engine + external AI candidate/validator adapter; phê duyệt đổi hướng; revise baseline riêng.
- **Khuyến nghị [PROPOSED]:** Read-only compatibility audit rồi xin quyết định; không rewrite engine/Provider/Auth từ docs.
- **Decision owner [PROPOSED]:** Chủ dự án / developer.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Final architecture approval và mọi implementation ảnh hưởng code hiện tại.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-012

- **Trạng thái:** [OPEN]. **Vấn đề:** Weather provider và alert/freshness policy.
- **Nguồn:** S-MP §6.2; §10.
- **Vì sao quan trọng / tác động:** Real API horizon/units, stale warnings và noncommercial eligibility.
- **Options:** Open-Meteo candidate đang có service; provider khác phù hợp.
- **Khuyến nghị [PROPOSED]:** Kiểm docs/terms + PoC; in-app alerts, không push; missing không block core.
- **Decision owner [PROPOSED]:** Chủ dự án / developer.
- **Decision deadline [PROPOSED]:** 2026-10-20.
- **Blocker:** Weather SHOULD implementation; core xử lý unknown không phụ thuộc.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-013

- **Trạng thái:** [OPEN]. **Vấn đề:** Community moderation/ratings/ownership detail.
- **Nguồn:** S-MP §6.3.
- **Vì sao quan trọng / tác động:** Role escalation, publication privacy, report process và scope chi phí.
- **Options:** Author ownership; moderator hide/restore; rating range và uniqueness cần chọn.
- **Khuyến nghị [PROPOSED]:** BR-P012, public opt-in; moderation không cấp private-trip quyền.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-20.
- **Blocker:** Community SHOULD implementation.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-014

- **Trạng thái:** [OPEN]. **Vấn đề:** Chi tiết quyền Editor/invitation và version policy.
- **Nguồn:** S-MP §6.4; §9.
- **Vì sao quan trọng / tác động:** Editor budget rights/invitation expiry/removed-member behavior chưa chốt.
- **Options:** Editor itinerary-only; itinerary+expense; invite token scoped subject với expiry.
- **Khuyến nghị [PROPOSED]:** Duyệt ma trận BR; Owner administration bắt buộc, version atomic, không transfer owner MVP.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-20.
- **Blocker:** Group SHOULD implementation; core version approach vẫn PROPOSED.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.

### OQ-015

- **Trạng thái:** [OPEN]. **Vấn đề:** Retention/consent/cache TTL/proposal expiry/account deletion.
- **Nguồn:** S-MP §9/11; BR-019/021.
- **Vì sao quan trọng / tác động:** Private context gửi API, stale data, offline cache và destructive delete policies.
- **Options:** Minimal logs; owner-protected snapshots; expiry/revalidation; purge/anonymize policy.
- **Khuyến nghị [PROPOSED]:** Duyệt policy trước lưu sensitive telemetry/production deletion; không invent TTL hoặc legal guarantee.
- **Decision owner [PROPOSED]:** Chủ dự án.
- **Decision deadline [PROPOSED]:** 2026-10-10.
- **Blocker:** Final privacy/data approval và sensitive persistence/integration implementation.
- **Decision / approver / date / evidence:** Chưa có; giữ OPEN.


## Assumption register

Mọi mục ở bảng này là **[ASSUMPTION]**, không phải yêu cầu đã duyệt. Nếu sai, cập nhật thiết kế/impact trước triển khai.

| ID | Working assumption | Validation / impact | Owner và due [PROPOSED] |
| --- | --- | --- | --- |
| AS-001 | Có thể tái sử dụng một phần code đang có mà không rewrite | Audit OQ-011 và test compatibility; timeline có thể phải đổi | Developer; 2026-10-10 |
| AS-002 | Demo ban đầu dùng VND và múi giờ Việt Nam | Duyệt BR-P002/008; không tự thêm multi-currency | Chủ dự án; 2026-10-10 |
| AS-003 | Chủ dự án có thể tạo/cấu hình Auth/AI accounts sau gate | Xác minh account/Google config/quota, không lấy README làm bằng chứng live | Chủ dự án; 2026-10-10 |
| AS-004 | Curated sample dataset có thể thu thập hợp lệ kịp hạn | OQ-004/006, kiểm source/license; thiếu data không sinh fake facts | Developer; 2026-10-10 |
| AS-005 | Một Android demo environment có thể chốt để đo | Ghi device/network/dataset trước AC-048; target chưa benchmark | Developer; 2026-10-15 |
| AS-006 | Người dùng cho phép gửi context tối thiểu đến provider theo consent | OQ-015/privacy policy; không gửi PII dư | Chủ dự án; 2026-10-10 |
| AS-007 | Giờ làm/năng lực đủ cho lịch vertical-slice đề xuất | Chưa có estimate effort giờ; điều chỉnh schedule, không giảm MUST tự động | Chủ dự án; 2026-10-10 |

## Deferred register

| ID | Trạng thái | Nội dung và điều kiện mở lại |
| --- | --- | --- |
| DF-001 | [DEFERRED]; S-MP §6.5/BR-015 | Booking/reservation/payment; cần approval scope riêng |
| DF-002 | [DEFERRED]; S-MP §6.6 | Push notifications/advanced reminders; không thêm hạ tầng sẵn |
| DF-003 | [DEFERRED]; S-MP §8.4 | Saved itinerary offline editing và advanced sync; Guest local draft không bị hoãn |
| DF-P001 | [PROPOSED] hoãn implementation SHOULD | Map/Weather/Community/Group nếu ảnh hưởng core; không đổi mức SHOULD baseline và không báo đã triển khai |

## Cách ghi quyết định và thay đổi baseline [PROPOSED]

Ghi ID OQ/ADR/FR liên quan, option được chọn, người duyệt, ngày, evidence và impact trên các docs/AC. Chỉ chuyển CONFIRMED sau owner approval; nội dung thay đổi đối chiếu S-MP/S-USER. Nếu trễ mốc proposed, báo ảnh hưởng critical path và phương án, không âm thầm chọn provider hoặc giảm MUST. Không đóng Phase 1 bằng việc push commit.

## Yêu cầu review cuối Phase 1

Chủ dự án vui lòng review [mục lục và Phase 1 approval checklist](README.md), chấp thuận hoặc yêu cầu sửa các PROPOSED/ASSUMPTION, giải quyết blocker và ghi evidence. Trạng thái vẫn **APPROVED WITH CONDITIONS**, chưa final approval; authorization triển khai Phase 2/3 cần riêng.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
