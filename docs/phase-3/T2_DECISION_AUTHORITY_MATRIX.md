# T2 Decision Authority Matrix — TravelGO Decision Intelligence

- **Dự án**: TravelGO Mobile
- **Tài liệu**: `docs/phase-3/T2_DECISION_AUTHORITY_MATRIX.md`
- **Giai đoạn**: Phase 3 — RAG T2 Architecture & Decision Boundary Freeze
- **Ngày lập**: 24/10/2026
- **Cơ sở kiến trúc**: 5 Luật Bất Biến (Đặc biệt Luật 1, Luật 2, Luật 5)

---

## 1. Nguyên Tắc Phân Định Thẩm Quyền (Core Principles)

Trong hệ thống TravelGO Decision Intelligence, **mỗi thành phần có một thẩm quyền duy nhất và bất khả xâm phạm**. Tuyệt đối không để AI (LLM) hoặc Mobile Client tự ý lấn sân vào các quyết định toán học và tài chính cốt lõi:

```
[Admin Web / CMS] ──(Publish)──> [Supabase Edge Function: Publication]
                                                  │
                                                  ▼ (Manifest + Release)
[Gemini LLM] ◄──(Sanitized Context)── [Supabase Gateway] ◄── [Mobile Client] ◄── [Decision Engine]
(Advisor/Explainer)                   (Quota & Contract)     (Presentation)      (Math & Pareto)
```

---

## 2. Ma Trận Thẩm Quyền Quyết Định Chi Tiết (Authority Matrix)

| Nghiệp Vụ / Quyết Định | Thành Phần Chịu Trách Nhiệm Duy Nhất | Thẩm Quyền Của Mobile Client | Vai Trò Của Gemini LLM | Rủi Ro & Ranh Giới Nghiêm Cấm |
| :--- | :---: | :---: | :---: | :--- |
| **1. Lựa chọn Điểm đến Thắng cuộc (MCDA)** | **Backend Decision Engine** (`/plan-trip`) | Nhận DTO và hiển thị lên Dashboard. Nếu mất mạng, kích hoạt fallback có cờ `isFallback: true` (Luật 3). | KHÔNG CÓ THẨM QUYỀN. Chỉ giải thích lý do tại sao điểm đến thắng cuộc. | **CẤM**: Client tự thay đổi điểm số hoặc tráo đổi kết quả MCDA của server. |
| **2. Tối ưu Đa mục tiêu (Pareto Frontier)** | **Backend Decision Engine** (`/plan-trip`) | Vẽ biểu đồ phân tán Pareto bằng `fl_chart`. | KHÔNG CÓ THẨM QUYỀN. | **CẤM**: LLM tự xưng là phương án tối ưu Pareto mà không có căn cứ từ Decision Engine. |
| **3. Mô phỏng Độ nhạy Ngân sách (Sensitivity)** | **Backend Decision Engine** (`/simulate-sensitivity`) | Cung cấp thanh trượt ngân sách tương tác trên UI và gửi request mô phỏng. | KHÔNG CÓ THẨM QUYỀN. | **CẤM**: Client tự ngoại suy đường cong độ nhạy bằng công thức cục bộ. |
| **4. Tính Toán Gói Vé Combo (Package Discount)** | **Backend Decision Engine** (Đợt Backend riêng) | **Đánh dấu `NOT_IMPLEMENTED`** trong T1/T2. Chỉ lưu trữ metadata gói để hiển thị. | KHÔNG CÓ THẨM QUYỀN. | **CẤM**: Client tự cộng dồn đơn giá rồi trừ tiền combo gây sai lệch ngân sách (tránh bug AI-G03). |
| **5. Ngân Sách Bản Nháp Người Dùng (Provisional Budget)** | **Mobile Client** (`BudgetCalculator`) | Tính toán tạm thời các khoản dự toán (`costVnd`, `EstimatedExpense`) của người dùng để vẽ biểu đồ chi phí (Luật 1). | Đề xuất giá tham khảo khi thêm hoạt động mới (luôn ở trạng thái `unverified`). | **CẤM**: Coi dự toán tạm thời của Client là quyết toán tài chính chính thức. |
| **6. Sổ Cái Chi Tiêu Thực Tế (Actual Expenses Ledger)** | **Người Dùng (Chủ sở hữu chuyến đi)** | Lưu trữ nguyên tử trong SQLite riêng tư (`EditableTripDocumentV2.actualExpenses`). | **TUYỆT ĐỐI CẤM TRUY CẬP HOẶC SỬA ĐỔI**. | **CẤM**: AI xóa, sửa hoặc làm xáo trộn các khoản tiền người dùng đã chi thực tế. |
| **7. Phê Duyệt Sửa Lịch Trình (Apply Modification)** | **Người Dùng (Human-in-the-Loop)** | Hiển thị màn hình So sánh Trước/Sau (`AiModificationPreview`). Chỉ ghi khi bấm "Apply". | Đề xuất các thao tác `add`, `edit`, `remove`, `reorder`. | **CẤM**: AI tự động lưu đè lịch trình vào chuyến đi mà không thông qua người dùng duyệt. |
| **8. Xác Minh Facts Địa Điểm (Grounding Facts)** | **Catalog Data & Evidence Pipeline** | Đọc từ `PlaceVisitDetails` (đã có nguồn kiểm duyệt), lọc ra `openingWindows`, `availability` (`open`/`closed`/`unknown`). | Bắt buộc phải tuân thủ các facts được cung cấp. | **CẤM**: AI bịa giờ mở cửa, bịa giá vé hoặc xếp lịch vào địa điểm đã đóng cửa. |
| **9. Xuất Bản Danh Mục (Publication)** | **Admin Web + Edge Function** (`admin-publication`) | Tải bản phát hành bất biến (Immutable Bundle), kiểm tra hash SHA-256 và lưu cache. | KHÔNG CÓ THẨM QUYỀN. | **CẤM**: Client tự ý sửa đổi dữ liệu danh mục công cộng của hệ thống. |
| **10. Điều Hướng Câu Hỏi Lạc Đề (Smart Pivot)** | **Mobile Client Guardrail** (`isOutOfDomainQuery`) | Tự động phát hiện câu hỏi ngoài phạm vi và trả lời điều hướng lịch sự tại máy, không tốn quota. | Trả lời câu hỏi du lịch hợp lệ đã được Client thông qua. | **CẤM**: Chặn nhầm các câu hỏi du lịch có chứa từ khóa nhạy cảm (như "Bảo tàng Chứng tích Chiến tranh"). |

---

## 3. Ranh Giới Kiểm Soát Mạng & Bảo Mật (Trust Boundary)

1. **Client là Untrusted Environment**:
   - Dữ liệu từ Mobile gửi lên Supabase Gateway (`itinerary-proposal`) chỉ được coi là **đề xuất / ngữ cảnh tiêu thụ**.
   - Gateway bắt buộc phải kiểm tra schema, chặn request vượt quota (Rate Limiting / Quota Guard), và chỉ cho phép các trường dữ liệu hợp lệ.
2. **LLM là Non-Authoritative Generator**:
   - Mọi chuỗi văn bản do Gemini tạo ra đều mặc định mang nhãn `verification: unverified`.
   - Kết quả trả về từ Gemini bắt buộc phải đi qua hàm kiểm tra cấu trúc cục bộ `AiAssistantResult.fromJson` và `_validateCandidate` trước khi hiển thị cho người dùng.
3. **Sự Độc Lập Giữa Dữ Liệu Công Cộng & Riêng Tư**:
   - Dữ liệu danh mục công cộng (`PublicCatalogueSnapshot`, `VisitCatalogue`) nằm trong cache đọc công khai.
   - Dữ liệu chuyến đi của người dùng (`EditableTripDocumentV2`, ghi chú, chi tiêu) được cách ly hoàn toàn theo `userId` và không bao giờ bị rò rỉ vào cache công cộng.

