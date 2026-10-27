# S6 — W2: Tư vấn Web Opt-in Có Nguồn Trích Dẫn (Implementation Plan)

> **Mã công việc:** S6 — W2 (Opt-in Sourced Web Advice)  
> **Trạng thái:** SẴN SÀNG CHỜ DUYỆT (Stage-Gate Approval Gate)  
> **Kế hoạch gốc:** [Web R2 Plan](2026-10-24-coursework-web-r2.md), [AI Design](../../.agent/ai-planner-design.md), [Product Scope](../../.agent/product-scope.md).  
> **Tiền đề đã hoàn tất:** S5 — W1 (Compatibility Spike) đạt kết quả **GO** ([báo cáo W1](../../phase-3/WEB_GROUNDING_COMPATIBILITY_RESULT.md)).

---

## 1. Mục tiêu & Phạm vi nghiệp vụ (Scope)

Cung cấp tính năng **Tư vấn thông tin Internet có nguồn trích dẫn (Opt-in Web Advice)** khi:
1. Người dùng chủ động bật tùy chọn tìm kiếm Web ("Tìm thông tin Internet") khi hỏi Trợ lý AI.
2. Thông tin trong Catalogue Admin chưa có hoặc người dùng muốn tra cứu thông tin thực tế mới nhất (giờ mở cửa, giá vé, sự kiện theo mùa).

### Các bất biến kiến trúc bắt buộc (5 Luật Bất Biến)
- **Law 1 (Chỉ tư vấn, không tự sửa):** Hoạt động tư vấn web tuyệt đối **không sinh lệnh thay đổi lịch trình (`operations` rỗng)**. Người dùng đọc thông tin tham khảo, không tự động ghi đè dữ liệu.
- **Law 2 (Quyền riêng tư & Bảo vệ dữ liệu):** Không bao giờ đưa email, số tiền chi tiêu thực tế (`actualExpenses`), ghi chú riêng tư (`notes`), hoặc tên thành viên vào prompt gửi sang Google Search. Chỉ gửi ngữ cảnh tối thiểu (tên điểm đến, số ngày, khoảng ngân sách tổng, sở thích).
- **Law 3 (Minh bạch nguồn gốc & Không làm giả căn cứ):**
  - Mọi thông tin từ web phải được gắn nhãn rõ ràng: `"Thông tin từ Internet, chưa được Admin kiểm duyệt"`.
  - Mọi căn cứ web phải có `origin: "web"` và `reviewed: false`. Không bao giờ tự ý gắn nhãn `origin: "catalogue"` hoặc tự động ghi vào Catalogue của Admin.
  - Các đường link trích dẫn phải là URL hợp lệ (HTTPS/HTTP), không tự bịa link hoặc giả mạo trang web.
- **Law 4 (Bất đồng bộ & Chặn kết quả cũ):** Nếu người dùng đóng giao diện, đổi chuyến đi hoặc chuyển tài khoản khi đang đợi kết quả web, kết quả muộn (`stale`) lập tức bị loại bỏ.
- **Law 5 (Stage-Gate Approval Protocol):** Kế hoạch này được trình bày chi tiết và dừng chờ lệnh xác nhận từ Owner ("duyệt") trước khi viết bất kỳ dòng mã nguồn nào của W2.

---

## 2. Danh mục tệp dự kiến (File Map)

| STT | Đường dẫn tệp | Hành động | Mục đích |
| :---: | :--- | :---: | :--- |
| 1 | `supabase/functions/itinerary-proposal/web-evidence.mjs` | **Tạo mới** | Module chuẩn hóa `groundingMetadata` từ Gemini: xử lý UTF-8 byte offset, lọc URL hợp lệ, ánh xạ thành `EvidenceRecord` và `EvidenceClaim` |
| 2 | `test/web_evidence_test.mjs` | **Tạo mới** | Bộ kiểm thử tự động Node.js cho `normalizeGoogleGrounding` (UTF-8 byte offset tiếng Việt, URL độc hại, metadata rỗng, chỉ số ngoài phạm vi) |
| 3 | `supabase/functions/itinerary-proposal/gateway.mjs` | **Cập nhật** | Bổ sung xử lý hợp đồng `travelgo.web.advice.v1`, kiểm tra quyền người dùng (chỉ người dùng đã đăng nhập, cấm khách ẩn danh), kiểm tra hạn ngạch và gọi Gemini với `tools: [{ "google_search": {} }]` |
| 4 | `lib/features/trip_planner/models/ai_web_advice.dart` | **Tạo mới** | Mô hình dữ liệu client: `AiWebAdviceRequest`, `AiWebAdviceReply`, `WebEvidenceContext`, parser an toàn |
| 5 | `lib/features/trip_planner/services/ai_assistant_service.dart` | **Cập nhật** | Thêm hàm `requestWebAdvice(...)` gọi Edge Function qua Supabase Functions / HTTP gateway |
| 6 | `lib/features/trip_planner/presentation/widgets/ai_assistant_preview.dart` | **Cập nhật** | Thêm tùy chọn checkbox/switch "Tìm thông tin Internet", hiển thị nhãn cảnh báo nguồn Internet và nút "Xem căn cứ" |
| 7 | `test/ai_web_advice_test.dart` | **Tạo mới** | Kiểm thử tích hợp Flutter: parse phản hồi web, hiển thị nhãn cảnh báo Internet, mở sheet căn cứ, bảo vệ không mutation |

---

## 3. Chi tiết Hợp đồng Kỹ thuật (Technical Contract)

### 3.1. Hợp đồng Request: `travelgo.web.advice.v1`

```json
{
  "contract": "travelgo.web.advice.v1",
  "requestId": "e1f2a3b4-5678-90ab-cdef-1234567890ab",
  "consent": true,
  "webConsent": true,
  "prompt": "Bảo tàng Lịch sử Quốc gia có mở cửa vào thứ Hai không và giá vé bao nhiêu?",
  "context": {
    "destinationName": "Hà Nội",
    "dates": ["2026-11-20", "2026-11-21"],
    "numPeople": 2,
    "budgetVnd": 5000000,
    "interests": ["lịch sử", "văn hóa"],
    "scope": "whole_trip",
    "baseDigest": "a1b2c3d4e5f6..."
  }
}
```

### 3.2. Hợp đồng Phản hồi: `travelgo.web.advice.v1`

```json
{
  "status": "succeeded",
  "requestId": "e1f2a3b4-5678-90ab-cdef-1234567890ab",
  "summary": "Bảo tàng Lịch sử Quốc gia đóng cửa vào thứ Hai hàng tuần (trừ các ngày lễ lớn). Giá vé tham quan đối với người lớn là 40.000 VNĐ.",
  "evidence": [
    {
      "id": "web:baotanglichsu-vn-3096",
      "origin": "web",
      "sourceUri": "https://baotanglichsu.vn/vi/Articles/3096/gio-mo-cua.html",
      "sourceTitle": "Giờ mở cửa và giá vé - Bảo tàng Lịch sử Quốc gia",
      "retrievedAt": "2026-10-27T16:00:00.000Z",
      "reviewed": false
    }
  ],
  "claims": [
    {
      "id": "claim:web:0",
      "kind": "fact",
      "field": "advice",
      "context": "Bảo tàng Lịch sử Quốc gia đóng cửa vào thứ Hai hàng tuần",
      "sourceIds": ["web:baotanglichsu-vn-3096"]
    }
  ],
  "searchQueries": ["giờ mở cửa giá vé Bảo tàng Lịch sử Quốc gia"],
  "searchEntryPoint": null,
  "warnings": [
    "Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra lại trước khi thực hiện."
  ],
  "baseDigest": "a1b2c3d4e5f6..."
}
```

---

## 4. Chu trình Triển khai TDD (Test-Driven Development)

### Giai đoạn 1: Backend RED & GREEN
1. **Viết test trước:** `test/web_evidence_test.mjs` kiểm tra các trường hợp:
   - Trích xuất trọn vẹn `groundingChunks` và `groundingSupports` với ký tự tiếng Việt đa byte UTF-8.
   - Khi metadata rỗng: trả về danh sách `evidence` rỗng và cảnh báo phù hợp.
   - Lọc bỏ URL scheme không an toàn (`javascript:`, `ftp:`, `data:`).
   - Bỏ qua các `groundingChunkIndices` vượt ngoài độ dài danh sách nguồn.
2. **Thực thi mã nguồn:** `supabase/functions/itinerary-proposal/web-evidence.mjs` với thuật toán `sliceUtf8Bytes` đã được kiểm chứng ở Spike W1.
3. **Cập nhật Gateway:** Bổ sung `travelgo.web.advice.v1` vào `gateway.mjs`, tích hợp kiểm tra `webConsent === true`.
4. **Chạy test:** `node --test test/web_evidence_test.mjs` $\rightarrow$ Đạt 100% PASS.

### Giai đoạn 2: Frontend Flutter RED & GREEN
1. **Viết test trước:** `test/ai_web_advice_test.dart` kiểm tra:
   - Mô hình hóa và parse chuẩn JSON của `AiWebAdviceReply`.
   - UI hiển thị nhãn `"Thông tin từ Internet, chưa được Admin kiểm duyệt"`.
   - Bấm nút `"Xem căn cứ"` hiển thị đầy đủ tiêu đề và liên kết trích dẫn web thông qua `EvidenceDetailsSheet`.
   - Xác nhận phản hồi không chứa bất kỳ thao tác sửa đổi lịch trình nào (`no operations`).
2. **Thực thi mã nguồn:** 
   - `lib/features/trip_planner/models/ai_web_advice.dart`.
   - `lib/features/trip_planner/services/ai_assistant_service.dart`.
   - `lib/features/trip_planner/presentation/widgets/ai_assistant_preview.dart`.
3. **Chạy test:** `flutter test test/ai_web_advice_test.dart` $\rightarrow$ Đạt 100% PASS.

### Giai đoạn 3: Kiểm định Hệ thống Toàn diện (Full System Verification)
- Chạy `flutter analyze` bảo đảm 0 lỗi, 0 cảnh báo.
- Chạy `powershell -ExecutionPolicy Bypass -File ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter` (đảm bảo không hồi quy 1.249+ bài kiểm thử).

---

## 5. Tiêu chí Nghiệm thu (Acceptance Criteria)

1. [ ] Hợp đồng `travelgo.web.advice.v1` chỉ được gọi khi người dùng chủ động chọn tìm kiếm web (`webConsent: true`).
2. [ ] Khách ẩn danh (`is_anonymous: true`) bị từ chối gọi tìm kiếm web (trả về mã 403 `subject_denied`) để bảo vệ quota hệ thống.
3. [ ] Không có thông tin cá nhân (email, sổ chi tiêu, ghi chú riêng tư) bị rò rỉ trong câu truy vấn sang Google.
4. [ ] Đoạn trích dẫn tiếng Việt có dấu được cắt chính xác theo UTF-8 byte offset, không lỗi font hoặc vỡ ký tự.
5. [ ] Mọi phản hồi đều hiển thị rõ ràng nhãn cảnh báo nguồn Internet và nút "Xem căn cứ" mở `EvidenceDetailsSheet`.
6. [ ] Tuyệt đối không sinh bất kỳ lệnh sửa đổi lịch trình nào (`operations` rỗng).

