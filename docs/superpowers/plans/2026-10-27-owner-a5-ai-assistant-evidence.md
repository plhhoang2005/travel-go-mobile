# A5 — Trợ lý AI tư vấn và sửa hoạt động có căn cứ (Implementation Plan) [HOÀN TẤT]

> **Trạng thái:** HOÀN TẤT & ĐÃ XÁC MINH (27/10/2026 bởi Antigravity). Bàn giao chi tiết tại [A5 Handover Report](../../phase-3/A5_ANTIGRAVITY_IMPLEMENTATION_20261027.md). Toàn bộ 5/5 test A5, 1.249 tests Flutter, 108 tests Node, SQL suite đều PASS 100%.

**Mục tiêu:** Nâng cấp Trợ lý AI (AI Assistant) để hỗ trợ hai chế độ chính có căn cứ dữ liệu từ Catalogue đã xuất bản (thông qua A3):
1. **Tư vấn (Advice / Recommendations):** Cung cấp lời khuyên lịch trình, gợi ý địa điểm theo ngữ cảnh (ngày cụ thể hoặc toàn chuyến). Tuyệt đối **không sinh lệnh thay đổi (operations rỗng)**, không tự động sửa dữ liệu lịch trình của người dùng.
2. **Sửa hoạt động (Modify):** Đề xuất thêm (`add`), sửa (`edit`), hoặc xóa (`remove`) hoạt động trên một ngày cụ thể (`scope: 'day'`). Hiển thị màn hình so sánh (Diff Preview) kèm bằng chứng đối chiếu Catalogue, nút "Xem căn cứ". Khi người dùng bấm **Áp dụng**, hệ thống cập nhật lịch trình và tích hợp phong bì bằng chứng (`TripEvidenceEnvelope`), bảo toàn tuyệt đối 100% các ghi chú cá nhân (`notes`) và các khoản đã chi (`actualExpenses`).

---

## 1. Các nguyên tắc kiến trúc & Bất biến nghiệp vụ (Law 1, 2, 3, 4)

1. **Law 1 — Trải nghiệm người dùng:** AI chỉ đề xuất, người dùng toàn quyền quyết định. Mọi thay đổi đều phải qua màn hình xem trước (Preview) $\rightarrow$ Hủy (Cancel giữ nguyên) $\rightarrow$ Xác nhận áp dụng (Apply).
2. **Law 2 & Law 3 — Tính minh bạch & Bảo toàn dữ liệu:**
   - Hoạt động tư vấn (`advice`): `operations` bắt buộc rỗng. Không có bất kỳ lệnh sửa đổi nào được phép xuất hiện.
   - Hoạt động sửa đổi (`modify`): Giữ nguyên vẹn 100% các trường `notes` (ghi chú cá nhân) và danh sách `actualExpenses` (sổ chi tiêu thực tế). AI không được phép xóa hoặc sửa đổi các khoản chi thực tế.
   - Nếu hoạt động bị thay đổi bản chất hoặc vị trí, cờ `estimateReviewRequired` được bật để người dùng rà soát lại dự toán ngân sách.
3. **Law 4 — Nguyên tử & Bất đồng bộ (Atomicity & Stale Protection):**
   - Áp dụng nguyên tử: Lệnh sửa đổi lịch và phong bì bằng chứng được cập nhật đồng thời vào Provider.
   - Chặn kết quả cũ: Nếu người dùng chuyển ngày, đổi tài khoản hoặc chỉnh sửa tài liệu trong khi request AI đang chạy, kết quả về muộn (`stale`) lập tức bị hủy bỏ và không bao giờ được áp dụng vào bản nháp.

---

## 2. File Map dự kiến

| File | Hành động | Mục đích |
| :--- | :--- | :--- |
| `lib/features/trip_planner/models/ai_grounded_assistant.dart` | Tạo mới | Mô hình dữ liệu kết nối `AiAssistantResult`, `AiModificationPreview` và `TripEvidenceEnvelope` trích xuất từ biên nhận A3 |
| `lib/features/trip_planner/services/ai_assistant_service.dart` | Sửa | Bổ sung hàm `askAiWithEvidence(...)` dispatch hợp đồng `travelgo.assistant.evidence.v1` với tham số `credential` an toàn |
| `lib/features/trip_planner/presentation/widgets/ai_assistant_preview.dart` | Sửa | Hiển thị nhãn đối chiếu Catalogue, nút "Xem căn cứ" (liên kết `EvidenceDetailsSheet`), xem trước khác biệt (Diff Preview) và nút Hủy/Áp dụng |
| `test/ai_assistant_evidence_test.dart` | Tạo mới | Bộ kiểm thử tự động toàn diện: advice rỗng operations, modify bảo toàn notes & actuals, hủy giữ nguyên digest, xem căn cứ, chặn kết quả muộn |

---

## 3. Các bước triển khai (TDD Cycle)

### Bước 1: RED (Viết Test trước) [x]
- Tạo `test/ai_assistant_evidence_test.dart` bao gồm:
  1. `advice_with_evidence_returns_empty_operations_and_preserves_document`: Tư vấn có căn cứ trả về giải thích + căn cứ nhưng không có lệnh sửa đổi, tài liệu giữ nguyên vẹn.
  2. `modify_with_evidence_preserves_notes_and_actual_expenses`: Sửa đổi hoạt động (thêm/sửa/xóa) giữ nguyên 100% `notes` và `actualExpenses`, hợp nhất bằng chứng vào `TripEvidenceEnvelope`.
  3. `cancel_preview_keeps_document_and_evidence_untouched`: Hủy xem trước giữ nguyên vẹn bản nháp và hash bằng chứng.
  4. `stale_or_changed_workspace_discards_late_assistant_result`: Đổi workspace hoặc tài khoản trong khi request AI đang xử lý sẽ ném lỗi `stale` và không áp dụng.
  5. `ai_assistant_preview_shows_evidence_sheet_button`: Widget test kiểm tra hiển thị nút "Xem căn cứ" và mở thành công sheet bằng chứng.

### Bước 2: GREEN (Thực thi mã nguồn) [x]
- Tạo `lib/features/trip_planner/models/ai_grounded_assistant.dart`.
- Bổ sung `askAiWithEvidence` trong `ai_assistant_service.dart`.
- Tích hợp hiển thị bằng chứng và áp dụng đồng bộ trong `ai_assistant_preview.dart`.
- Nối luồng gọi `askAiWithEvidence` vào `manual_planner_screen.dart`.

### Bước 3: VERIFY (Kiểm thử & Nghiệm thu) [x]
- Chạy `flutter test test/ai_assistant_evidence_test.dart` đạt 100% (5/5 PASS).
- Chạy toàn bộ regression suite `test/ai_assistant_test.dart` và `test/ai_assistant_grounding_test.dart` (42/42 PASS).
- Chạy `flutter analyze` bảo đảm 0 lỗi cảnh báo (0 issues found).
- Chạy `powershell -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter` (1249 Flutter PASS, 108 Node PASS).
- Chạy `powershell -ExecutionPolicy Bypass -File ./tool/verify-coursework-trips.ps1 -FlutterRoot D:/flutter/flutter` (Toàn bộ SQL PASS).

