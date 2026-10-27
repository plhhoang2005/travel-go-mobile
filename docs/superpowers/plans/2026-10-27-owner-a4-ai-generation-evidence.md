# A4 — AI tạo lịch trình có căn cứ trên bản trống (Implementation Plan) [HOÀN TẤT]

> **Trạng thái:** HOÀN TẤT & ĐÃ XÁC MINH (27/10/2026 bởi Antigravity). Bàn giao chi tiết tại [A4 Handover Report](../../phase-3/A4_ANTIGRAVITY_IMPLEMENTATION_20261027.md). Toàn bộ 6/6 test A4, 1.244 tests Flutter, 108 tests Node, SQL suite đều PASS 100%.

**Mục tiêu:** Cho phép người dùng tạo lịch trình trọn gói tự động bằng Trợ lý AI khi chuyến đi chưa có hoạt động nào (bản trống). Đề xuất trả về từ AI được gắn kèm bằng chứng căn cứ (Evidence & Claims) từ Catalogue đã xuất bản (thông qua A3). Người dùng xem trước (Preview) $\rightarrow$ Hủy (giữ nguyên bản nháp) $\rightarrow$ Xác nhận áp dụng (đưa vào trình chỉnh sửa để sửa thủ công và lưu lại qua A2).

**Ranh giới & Quy tắc:**
1. **Chỉ áp dụng trên bản trống:** `canGenerateWholeTrip(document) => document.items.isEmpty`. Nếu đã có hoạt động, không cho phép tạo đè toàn bộ chuyến đi.
2. **Không tự ghi đè chuyến đi đã lưu:** Đề xuất được áp dụng vào bản nháp trong bộ nhớ (Editor); việc lưu lên máy chủ/cơ sở dữ liệu cục bộ là thao tác riêng biệt do người dùng thực hiện (A2).
3. **Bảo toàn dữ liệu khi hủy:** Bấm Hủy (Cancel) trong màn hình xem trước phải giữ nguyên vẹn bản nháp hiện tại.
4. **Xác thực bằng chứng phía client:** Các địa điểm, claims phải khớp với Registry do backend A3 trả về; không nhận URL hay nhãn kiểm duyệt do AI tự sinh.

---

## 1. File Map dự kiến

| File | Hành động | Mục đích |
| :--- | :--- | :--- |
| `lib/features/trip_planner/models/ai_grounded_proposal.dart` | Tạo mới | Mô hình dữ liệu kết hợp giữa đề xuất lịch trình `AiItineraryProposal` và căn cứ bằng chứng `TripEvidenceEnvelope` |
| `lib/features/trip_planner/services/ai_generation_service.dart` | Sửa | Thêm hàm `canGenerateWholeTrip(document)` và hàm gọi API Edge Function với contract `travelgo.itinerary.evidence.v1` |
| `lib/features/trip_planner/presentation/widgets/ai_generation_preview.dart` | Sửa / Mới | Màn hình/sheet xem trước đề xuất: hiển thị lịch trình, nút "Xem căn cứ" (tái dùng `EvidenceDetailsSheet`), nút Hủy và Áp dụng |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | Sửa | Nối luồng kích hoạt tạo lịch AI từ thanh công cụ khi chuyến đi chưa có hoạt động |
| `test/ai_generation_evidence_test.dart` | Tạo mới | Kiểm thử toàn diện: từ chối khi bản không trống, hủy giữ nguyên digest, áp dụng 1 lần nguyên tử, kiểm tra claims |

---

## 2. Các bước triển khai (TDD Cycle)

### Bước 1: RED (Viết Test trước) [x]
- Tạo `test/ai_generation_evidence_test.dart` bao gồm:
  1. `whole_trip_generation_rejects_nonempty_document`: Khi `document.items` có ít nhất 1 hoạt động, `canGenerateWholeTrip` trả về `false` và service từ chối gửi request.
  2. `cancel_keeps_document_digest`: Mở preview và bấm Hủy $\rightarrow$ document digest và nội dung không đổi.
  3. `apply_updates_document_and_evidence_atomically`: Bấm Xác nhận $\rightarrow$ các hoạt động được đưa vào editor kèm danh sách evidence/claims chuẩn xác từ receipt.
  4. `late_response_ignored_if_context_changed`: Phản hồi về muộn khi người dùng đã chuyển ngày/điểm đến sẽ bị từ chối áp dụng.

### Bước 2: GREEN (Thực thi mã nguồn) [x]
- Tạo `lib/features/trip_planner/models/ai_grounded_proposal.dart`.
- Bổ sung `canGenerateWholeTrip` và phương thức gọi `generateAiWithEvidence` trong `ai_generation_service.dart`.
- Xây dựng giao diện xem trước `AiGenerationPreview` kèm nút xem căn cứ, xử lý hủy/xác nhận.
- Kết nối vào `manual_planner_screen.dart`.

### Bước 3: VERIFY (Kiểm thử & Nghiệm thu) [x]
- Chạy `flutter test test/ai_generation_evidence_test.dart` đạt 100% (6/6 PASS).
- Chạy `flutter analyze` bảo đảm 0 lỗi cảnh báo (0 issues found).
- Chạy toàn bộ regression suite `verify-travelgo.ps1 -Mode Full` (1244 Flutter PASS, 108 Node PASS, SQL PASS).

