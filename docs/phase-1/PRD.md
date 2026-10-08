# 02 — Product Requirements Document

> Phiên bản thiết kế: 1.0 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED**.
> Baseline: S-MP (Master Prompt v1.0); đây là đặc tả thiết kế, không phải bằng chứng tính năng đã triển khai hoặc Phase 1 đã được đóng.

## Baseline và scope

[CONFIRMED] Scope và mức ưu tiên lấy từ S-MP §4–6; danh mục yêu cầu và traceability ở [03](FUNCTIONAL_REQUIREMENTS.md). Các mức MUST/SHOULD không thể bị thay đổi chỉ vì thiếu thời gian. Đề nghị cắt giảm yêu cầu MUST phải được chủ dự án phê duyệt riêng.

| Module | Ưu tiên baseline | Độ sâu MVP tối thiểu [PROPOSED] | Phụ thuộc |
| --- | --- | --- | --- |
| Account & Profile | MUST [CONFIRMED] | Guest; email/password và Google; hồ sơ sở thích/ngân sách/phong cách; chuyển draft sang account | Auth config, OQ-009 |
| Travel Discovery | MUST [CONFIRMED] | Dataset Việt Nam có nguồn; search/filter; detail; chọn destination; sample itinerary | OQ-004/006 |
| Trip Planner | MUST [CONFIRMED] | Ngày/giờ, thêm/xóa/reorder, preview/confirm, save/list/reopen, snapshot offline | Mô hình chung và persistence |
| AI Travel Assistant | MUST [CONFIRMED] | Recommendations, generation, chat theo trip, đề nghị sửa, preferences và deterministic validation | OQ-002/003/005, server secrets |
| Budget Management | MUST [CONFIRMED] | Total budget, estimates, actuals/categories, remaining và warning; reconcile estimate khi sửa | Itinerary và expense identity |
| Travel Map | SHOULD [CONFIRMED] | Pins/routes/distances, provider sau PoC; có thể hoãn triển khai [PROPOSED] | OQ-008; billing/attribution |
| Weather | SHOULD [CONFIRMED] | Forecast thật, gợi ý và cảnh báo trong app; có thể hoãn triển khai [PROPOSED] | OQ-012; freshness |
| Community | SHOULD [CONFIRMED] | Đăng nội dung/review/rating/comment/like, quyền sở hữu/moderation; hoãn triển khai [PROPOSED] | OQ-013 |
| Group Collaboration | SHOULD [CONFIRMED] | Owner/Editor, invitation, private, optimistic version; hoãn triển khai [PROPOSED] | Membership/transaction |
| Booking; notifications | DEFERRED | Không flow thanh toán/booking; không push infrastructure | FR-DEF-001/002 |

[CONFIRMED] Offline chỉ bao gồm Guest drafts local và đọc saved itinerary. [DEFERRED] Offline editing của trip đã lưu, background multi-device sync, payment/reservations, advanced reminders. [PROPOSED] Không bổ sung realtime radar/tracking, recommendation ML riêng, microservices, vector database hoặc social feed nâng cao vào baseline Phase 1; các khả năng cũ trong repo được giữ nguyên code, không tự đưa thành yêu cầu mới.

## Nhu cầu người dùng và trải nghiệm

| ID | Trạng thái | Nhu cầu | Yêu cầu/flow |
| --- | --- | --- | --- |
| UN-001 | [CONFIRMED] | Thử khám phá trước khi đăng nhập | FR-ACC-001; UF-001 |
| UN-002 | [CONFIRMED] | Không mất kế hoạch khi chuyển Guest → account | FR-ACC-005/006; UF-004 |
| UN-003 | [CONFIRMED] | AI tiết kiệm công soạn lịch nhưng vẫn chủ động chỉnh sửa | FR-AI-001–005; UF-003/006 |
| UN-004 | [CONFIRMED] | Biết dự kiến, đã chi và vượt ngân sách | FR-BUD-001–004; UF-008 |
| UN-005 | [CONFIRMED] | Xem lịch đã lưu khi mất mạng | FR-TRP-006; UF-007 |
| UN-006 | [CONFIRMED nếu SHOULD triển khai] | Sửa chung nhưng kiểm soát quyền Owner | FR-GRP-001/002; UF-011 |

[PROPOSED] Navigation dùng điểm khám phá, tạo/lịch trip, trip đã lưu, hồ sơ; AI là hỗ trợ nằm trong ngữ cảnh itinerary và có vùng chat riêng, không thay toàn bộ dashboard bằng chat. Không chốt widget hoặc sửa navigation hiện có.

## MVP end-to-end và phạm vi dữ liệu

[CONFIRMED] Luồng §12 gồm 11 bước: mở app; Guest explore; nhập trip; generate AI; preview; sửa activities; xem estimate; confirm; authenticate/save; reopen; offline view. Xem [UF-003](USER_FLOWS.md#uf-003), [UF-004](USER_FLOWS.md#uf-004), [UF-007](USER_FLOWS.md#uf-007).

[PROPOSED] Chuyến đi demo dùng VND và múi giờ Asia/Ho_Chi_Minh; cho phép tổng ngân sách 0, không cho số người 0 hoặc ngày kết thúc trước ngày bắt đầu. Không bịa giới hạn số ngày, số hoạt động hoặc lượng destination. Quy mô demo phải chốt OQ-006.

[PROPOSED] Itinerary vừa tạo là draft; confirmed là nội dung người dùng đã duyệt; saved là đã persistence thành công. Xác nhận local không được hiển thị “đã đồng bộ”. Saved có version để bảo vệ update; AI proposal là đối tượng riêng chưa có hiệu lực.

## Kế hoạch theo deadline — chỉ là đề xuất, sau approval

| Giai đoạn | Khoảng ngày [PROPOSED] | Kết quả cần có trước bước sau |
| --- | --- | --- |
| Thiết kế/audit và chốt blocker | 2026-10-08–2026-10-10 | Review 10 docs; OQ-001/002/004/005/007/009/011; authorization Phase 2 riêng |
| Core vertical slice | 2026-10-11–2026-10-15 | Guest discovery, input/manual, Auth, save/reopen, budget |
| Hybrid AI integration | 2026-10-16–2026-10-20 | Generation/recommendations/chat/modification; validation; explicit approval; fallback |
| Reliability, privacy, offline | 2026-10-21–2026-10-24 | Restart recovery, migration retries, RLS negatives, snapshots, actual preservation |
| Demo và evidence | 2026-10-25–2026-10-27 | AC MUST, API evidence theo rubric, rehearsal; ghi lỗi/rủi ro thực |
| Hạn cuối [CONFIRMED] | 2026-10-28 | Nộp theo rubric đã xác nhận |

[PROPOSED] Nếu đến 2026-10-20 chưa đạt core slice, không bắt đầu SHOULD. Đơn giản hóa UI và bề rộng dataset theo OQ-006 trước khi đề xuất giảm MUST. Thiếu AI/provider hoặc Google Sign-In không được báo MVP đủ bằng mock/manual; ghi blocker và xin quyết định scope riêng.

## Definition of Ready và Done

[PROPOSED] Ready triển khai: blocker có quyết định ghi ngày/người duyệt; mappings FR→BR→UF→data→API→AC được review; provider được thử sau authorization; kế hoạch triển khai tương thích repo được duyệt.

[PROPOSED] Done sản phẩm: tất cả AC MUST đạt trên Android; API thật có evidence; không có unauthorized read/write; không mất actual/draft; verified chỉ khi có nguồn; offline snapshot được thử sau restart. [CONFIRMED] Phase 1 được đóng chỉ sau explicit approval của chủ dự án; công bố docs không phải Done triển khai.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
