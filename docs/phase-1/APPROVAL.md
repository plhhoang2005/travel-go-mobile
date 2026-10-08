# Phase 1 — Approval và closure record

> Baseline được duyệt: **design v1.1**.
> Ngày phê duyệt/đóng hồ sơ: **2026-10-08**, timezone Asia/Saigon.
> Người phê duyệt: **Chủ dự án — người dùng trong chat hiện tại**; không suy diễn chữ ký hoặc danh tính pháp lý.
> **APPROVED WITH CONDITIONS — PHASE 1 CLOSED — IMPLEMENTATION NOT AUTHORIZED.**
> Deadline sản phẩm: **2026-10-28 [CONFIRMED]**.

## S-APP-001 — Evidence phê duyệt trực tiếp

[CONFIRMED] Sau khi bản v1.1 đã được công bố và assistant hỏi phê duyệt để đóng Phase 1, chủ dự án trả lời trong chat:

> “ok tôi chốt trước khi qua phase 2 cho tôi hỏi có nên tạo session mới …”

Chủ dự án sau đó yêu cầu rõ:

> “Đóng hồ sơ Phase 1: ghi approval, giữ rõ những điều kiện còn mở và tạo bản bàn giao gồm quyết định, commit, hiện trạng và việc tiếp theo.”

Hai thông điệp trực tiếp ngày 2026-10-08 là căn cứ ghi approval và closure; không dựa vào preview conversation hoặc lời assistant tự xác nhận. Approval này là acceptance baseline thiết kế **có điều kiện**, đồng thời yêu cầu giữ remaining OPEN/PROPOSED. Không có lời cấp phép viết code, cài packages, migrate database, provision services hoặc triển khai Phase 2/3.

## Baseline và commit được phê duyệt

| Artifact | Commit / evidence |
| --- | --- |
| Master Prompt nguồn | Pasted text.txt v1.0; SHA-256 và source register ở [index](README.md); nguồn lịch sử không bị sửa |
| Design baseline đầu tiên | [758804c](https://github.com/plhhoang2005/travel-go-mobile/commit/758804ce9bb636e45d3c8d11dcab4b33fed4cc68) |
| Bản thiết kế v1.1 được duyệt | [2f330e9](https://github.com/plhhoang2005/travel-go-mobile/commit/2f330e94423d67c89ed34bb2f4d0657b652cb30b) |
| Snapshot v1.1 trước closure | [docs tại 2f330e9](https://github.com/plhhoang2005/travel-go-mobile/tree/2f330e94423d67c89ed34bb2f4d0657b652cb30b/docs/phase-1) |
| Closure publication | Commit chứa APPROVAL.md/HANDOFF.md và thay đổi metadata closure; xác định immutable SHA qua [lịch sử approval](https://github.com/plhhoang2005/travel-go-mobile/commits/main/docs/phase-1/APPROVAL.md), không ghi SHA của commit trước như closure SHA |

[CONFIRMED] Design v1.1 gồm đúng 10 deliverables, 38 functional requirements, BR-001–022, UF-001–011, 55 acceptance cases và OQ-001–015. Closure bổ sung hai hồ sơ APPROVAL/HANDOFF và cập nhật metadata/links; không thay 10 deliverables thành 12 yêu cầu thiết kế.

## Phạm vi approval

- [CONFIRMED] Baseline v1.1 và DEC-001–011 tại [decision log](README.md) được giữ làm đầu vào cho bước chuẩn bị tiếp theo.
- [CONFIRMED] Đóng review/hồ sơ Phase 1; không còn cần hỏi lại approval cho bản v1.1.
- [CONFIRMED] Giữ rõ các điều kiện còn mở; closure không tự nâng mọi chi tiết PROPOSED thành CONFIRMED.
- [CONFIRMED] Gemini, Guest policy 3/ngày/reset Vietnam, 12 destination, Provider/SQLite, migration và privacy boundaries đã chốt; không mở lại khi đổi session.
- [PROPOSED/OPEN] Model, package, dataset depth, implementation contracts/schema, identity/retention/hosting và submission details tiếp tục quyết định/validation theo handoff.
- [DEFERRED] Booking/payment, push notifications/advanced reminders và saved-trip offline editing/advanced sync giữ ngoài MVP đầu.

## Điều kiện giữ mở khi đóng Phase 1

| Readiness ID | Tình trạng chuyển tiếp |
| --- | --- |
| RC-001 | Gemini model/account/key/quota/structured-output/tiếng Việt chưa được xác minh |
| RC-002 | SQLite package/version, schema migration/recovery và secure token storage chưa chốt |
| RC-003 | Spring hosting/HTTPS, deployed saved_trips schema/RLS và transaction compatibility chưa được kiểm chứng |
| RC-004 | 12 destination đã chốt; 6–10 places/destination + 1 sample còn PROPOSED; source/license/coverage thực chưa thu thập/verify |
| RC-005 | Guest subject/lease/account quota/global cap, consent/retention/encryption/deletion chi tiết còn OPEN |
| RC-006 | Submission artifact checklist giảng viên còn OPEN; external API type đã CONFIRMED |

Owners, due dates đề xuất, evidence và gate theo từng operation nằm ở [HANDOFF.md](HANDOFF.md#remaining-readiness). Không yêu cầu kết luận OPEN đã xong để báo closure; không triển khai operation còn phụ thuộc điều kiện chưa xử lý.

## Tách các mốc approval và nghiệm thu

| Mốc | Trạng thái |
| --- | --- |
| Chốt các lựa chọn DEC-001–011 | CONFIRMED |
| Phê duyệt baseline thiết kế v1.1 | APPROVED WITH CONDITIONS, S-APP-001 |
| Đóng hồ sơ Phase 1 | CLOSED, ngày 2026-10-08 |
| Product acceptance 55 cases | **NOT RUN** |
| Flutter/backend runtime, deployed RLS, live Gemini PoC | **UNVERIFIED** trong tác vụ tài liệu |
| Cho phép viết/triển khai Phase 2/3 | **NOT AUTHORIZED** |
| Tạo session mới / thay rules/workflow/skills | Chưa thực hiện trong tác vụ đóng hồ sơ |

## Kiểm tra publication

Phạm vi closure: README root, index, metadata 10 design docs và hai hồ sơ approval/handoff; tất cả Markdown. Phần hướng dẫn cài đặt gốc ở README root giữ nguyên. Code, dependencies, tests, platform config, AGENTS/rules/skills và synced sources không thuộc scope thay đổi.

Verification của closure là documentation-only diff, counts/IDs/links/anchors, preserved README prefix và Git blob/mode ngoài allowlist. Không dùng publication verification để đổi AC thành PASS.

[Xem index](README.md) · [Bàn giao tiếp theo](HANDOFF.md).
