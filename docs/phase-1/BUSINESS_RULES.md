# 05 — Business rules và quyền dữ liệu

> Phiên bản thiết kế: 1.0 • Ngày lập: 2026-10-08 • Deadline: **2026-10-28**.
> Trạng thái: **APPROVED WITH CONDITIONS — DESIGN WORK AUTHORIZED, IMPLEMENTATION NOT AUTHORIZED**.
> Baseline: S-MP (Master Prompt v1.0); đây là đặc tả thiết kế, không phải bằng chứng tính năng đã triển khai hoặc Phase 1 đã được đóng.

## Business rules baseline

Các quy tắc BR-001–BR-022 giữ nguyên ID và nghĩa của S-MP §7. Chúng là [CONFIRMED]; BR-015 xác nhận quyết định defer booking, không xác nhận chức năng booking. SHOULD chỉ có hiệu lực triển khai khi module được chọn.

| ID | Trạng thái | Quy tắc | Requirements | Điểm thực thi [PROPOSED] | Acceptance |
| --- | --- | --- | --- | --- | --- |
| <a id="br-001"></a>BR-001 | [CONFIRMED] | Guest được khám phá ứng dụng. | FR-ACC-001 | Public catalogue boundary | AC-001 |
| <a id="br-002"></a>BR-002 | [CONFIRMED] | Hỗ trợ email và Google authentication. | FR-ACC-002/003 | Supabase Auth identity | AC-002/003 |
| <a id="br-003"></a>BR-003 | [CONFIRMED] | Profile chứa travel preferences. | FR-ACC-004 | Profile owner | AC-004 |
| <a id="br-004"></a>BR-004 | [CONFIRMED] | Hỗ trợ itinerary thủ công và AI-assisted. | FR-TRP-002; FR-AI-002 | Common domain itinerary | AC-012/018 |
| <a id="br-005"></a>BR-005 | [CONFIRMED] | AI-proposed changes phải có user confirmation. | FR-AI-004 | Preview + server apply gate | AC-020/041 |
| <a id="br-006"></a>BR-006 | [CONFIRMED] | AI xét travel constraints có dữ liệu. | FR-AI-005 | Deterministic validator | AC-021 |
| <a id="br-007"></a>BR-007 | [CONFIRMED] | Estimated và actual expenses tách biệt. | FR-BUD-001/002 | Expense kind + totals | AC-024/025 |
| <a id="br-008"></a>BR-008 | [CONFIRMED] | Vượt budget cảnh báo, không chặn. | FR-BUD-003 | Warning path | AC-026 |
| <a id="br-009"></a>BR-009 | [CONFIRMED] | Trip private mặc định. | FR-SEC-001; FR-GRP-001 | RLS default deny | AC-034 |
| <a id="br-010"></a>BR-010 | [CONFIRMED] | Owner quản trị membership và xóa trip. | FR-GRP-001 | Owner server check | AC-032/046 |
| <a id="br-011"></a>BR-011 | [CONFIRMED] | Community có moderation. | FR-COM-002 | Content policy | AC-031 |
| <a id="br-012"></a>BR-012 | [CONFIRMED] | Map có pins/routes/distances khi triển khai. | FR-MAP-001 | Provider adapter | AC-028 |
| <a id="br-013"></a>BR-013 | [CONFIRMED] | Weather có forecast/recommendations/alerts khi triển khai. | FR-WEA-001 | Weather adapter | AC-029 |
| <a id="br-014"></a>BR-014 | [CONFIRMED] | Người mới khám phá sample itineraries. | FR-DIS-004 | Sample catalogue | AC-010 |
| <a id="br-015"></a>BR-015 | [CONFIRMED] | Booking implementation deferred. | FR-DEF-001 | Scope gate | AC-036 |
| <a id="br-016"></a>BR-016 | [CONFIRMED] | Guest draft lưu local. | FR-ACC-005 | Local persistence | AC-005 |
| <a id="br-017"></a>BR-017 | [CONFIRMED] | Guest AI bị giới hạn; số quota OPEN. | FR-AI-007 | Gateway quota | AC-023 |
| <a id="br-018"></a>BR-018 | [CONFIRMED] | Collaboration edits có version conflict detection. | FR-GRP-002 | Atomic version compare | AC-033 |
| <a id="br-019"></a>BR-019 | [CONFIRMED] | Thiếu external data phải disclosed hoặc labeled estimated. | FR-DIS-002; FR-AI-005 | Provenance per field | AC-008/021 |
| <a id="br-020"></a>BR-020 | [CONFIRMED] | AI lỗi vẫn có manual planning. | FR-AI-006 | Manual independent path | AC-022 |
| <a id="br-021"></a>BR-021 | [CONFIRMED] | Backend authorization bảo vệ private trip. | FR-SEC-001 | Database policies + server checks | AC-034 |
| <a id="br-022"></a>BR-022 | [CONFIRMED] | Không nhúng sensitive API credentials vào mobile. | FR-SEC-002 | Server secret boundary | AC-035 |

## Chi tiết policy — chưa được duyệt

| ID | Trạng thái/Nguồn | Chính sách đề xuất | Enforcement và negative case |
| --- | --- | --- | --- |
| BR-P001 | [PROPOSED]; BR-016; OQ-009 | Migration key là owner + source_draft_id + source_revision; retry cùng revision trả cùng trip; revision mới cần lựa chọn update/copy rõ | Backend transaction/receipt; không xóa draft trước acknowledgment; AC-039 |
| BR-P002 | [PROPOSED]; FR-TRP-001; §5.3 | end_date ≥ start_date; traveler_count nguyên ≥1; budget ≥0; VND toàn chuyến | Local validation và backend revalidation; date error khác budget warning; AC-011 |
| BR-P003 | [PROPOSED]; BR-006/019 | Giờ ngoài khoảng ngày hoặc known closed/time overlap phải sửa hoặc được người dùng chấp nhận exception có lý do; unknown chỉ warning | Validator trả severity/field/reason/source; unknown không gắn verified; AC-021/042 |
| BR-P004 | [PROPOSED]; BR-005/021 | Confirmed nội dung và saved persistence là hai trạng thái; save chỉ thành công sau backend receipt | UI/transaction; mạng lỗi không báo saved; AC-014/040 |
| BR-P005 | [PROPOSED]; BR-018; FR-AI-004 | Mọi update saved itinerary dùng base_version; so sánh và tăng version nguyên tử; reject stale | Không check rồi write tách rời; AC-033/041 |
| BR-P006 | [PROPOSED]; BR-005 | Apply AI yêu cầu subject hiện tại + proposal_id + digest đã preview + base_version; proposal scoped trip và có thời hạn theo OQ-015 | Reject cancel/expired/tampered/cross-trip; không gọi provider để regenerate trong apply; AC-020/041 |
| BR-P007 | [PROPOSED]; BR-017/022; OQ-005 | Guest token server-minted, quota theo subject thiết bị/phiên có chống abuse; auth quota riêng; check trước provider | Client counter chỉ để hiển thị, không tin cho enforcement; không chốt số; AC-023 |
| BR-P008 | [PROPOSED]; BR-007/008 | actual_remaining = budget − tổng actual; estimate_remaining = budget − tổng estimates active; hiển thị hai chỉ số, không cộng estimate + actual thành “đã chi” | Money fixed precision; unknown count riêng; AC-024–026/043 |
| BR-P009 | [PROPOSED]; FR-BUD-004 | Estimate do itinerary sinh mang item_id và provenance; delete item inactive estimate đó; actual giữ nguyên, unlink item với snapshot mô tả | Transaction update/version; AC-027/044 |
| BR-P010 | [PROPOSED]; BR-021; §8.4 | Cache partition owner; sign-out/account switch xóa hoặc khóa cache riêng; local Guest draft riêng | Không thấy dữ liệu A khi B vào; AC-040/045 |
| BR-P011 | [PROPOSED]; §9 | Trip Owner delete cascade day/items/expenses/members/AI metadata thuộc trip; retention audit tối thiểu cần duyệt | Không coi xóa trip là xóa tài khoản hoặc data nguồn; OQ-015 |
| BR-P012 | [PROPOSED]; §6.3 | Public community opt-in; author quản lý nội dung mình; moderator được hide/restore; không có private-trip admin quyền | Backend/RLS và moderation audit; AC-031 |

## Authorization matrix

Quy tắc private/Owner là [CONFIRMED]; ma trận thao tác chi tiết là [PROPOSED], OQ-014. Quyền deny mặc định, UI không phải điểm bảo vệ cuối.

| Thao tác | Guest | User không thành viên | Owner | Editor (SHOULD) | Moderator |
| --- | --- | --- | --- | --- | --- |
| Đọc catalogue public | Có | Có | Có | Có | Có |
| Sửa profile của chính mình | Không | Có, chỉ own | Chỉ own | Chỉ own | Chỉ own |
| Local Guest draft | Thiết bị local | Chỉ vùng local tách biệt | Như user | Như user | Như user |
| Đọc private trip | Không | Không | Có | Có nếu member active | Không theo moderation role |
| Sửa itinerary/apply AI | Local draft, không remote trip | Không | Có + version/approval | Có + version/approval | Không theo moderation role |
| Sửa actual expense | Local draft của mình [PROPOSED] | Không | Có | Có [PROPOSED; OQ-014] | Không theo moderation role |
| Invite/remove/delete trip | Không | Không | Có | Không | Không |
| Publish community | Không [PROPOSED] | Có nếu authenticated | Có | Có | Có |
| Moderate community | Không | Không | Không theo trip role | Không | Có khi cấp role server |

[CONFIRMED] Owner có quyền membership/deletion; Editor không được tăng quyền Owner. [PROPOSED] Không có transfer Owner trong MVP. Bảng quyền collaboration/community không phải lệnh tạo bảng hoặc triển khai SHOULD.

---
[Xem mục lục và quy ước nguồn/trạng thái](README.md).
