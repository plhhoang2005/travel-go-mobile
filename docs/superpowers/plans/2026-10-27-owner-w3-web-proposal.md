# S7 — W3: Đề xuất Hoạt động Web & Căn cứ Độc lập (Implementation Plan)

> **Mã công việc:** S7 — W3 (Web Proposal & External Activities)  
> **Trạng thái:** CHỜ DUYỆT (Stage-Gate Approval Gate — Chờ Owner xác nhận)  
> **Kế hoạch gốc:** [Web R2 Plan](2026-10-24-coursework-web-r2.md#w3--web-proposal--preview--applysave/read-không-catalogue-mutation), [AI Design](../../.agent/ai-planner-design.md), [Product Scope](../../.agent/product-scope.md).  
> **Tiền đề đã hoàn tất:** S6 — W2 (Opt-in Sourced Web Advice) đạt kết quả 100% PASS trên cả Flutter và Node.js ([Bàn giao W2](../../phase-3/W2_ANTIGRAVITY_IMPLEMENTATION_20261027.md)). Owner đã chọn **Lựa chọn A** (Hoạt động web gắn `placeId: null`, lưu `externalPlaces`/`externalBindings` vào `TripEvidenceEnvelope`, tuyệt đối không ghi vào Catalogue của Admin).

---

## 1. Mục tiêu & Phạm vi nghiệp vụ (Scope)

Mở rộng khả năng của Trợ lý AI và Luồng tạo lịch trình khi gặp **điểm đến chưa có trong Catalogue Admin** (ví dụ: Phú Yên, Côn Đảo) hoặc khi người dùng muốn AI gợi ý các địa điểm/hoạt động thực tế từ Internet:
1. Cho phép AI trả về đề xuất lịch trình gồm các hoạt động có căn cứ từ Google Search Grounding (`travelgo.web.proposal.v1`).
2. Tích hợp hoạt động ngoài (`ExternalPlaceRecord`, `ExternalItemBinding`) vào `TripEvidenceEnvelope` của chuyến đi:
   - Các hoạt động từ web có `placeId: null`.
   - Được ánh xạ qua `externalBindings` tới danh sách `externalPlaces` (tên địa điểm, điểm đến, `evidenceIds`).
   - Mọi căn cứ trích dẫn đều có `origin: "web"`, `reviewed: false` và đường dẫn nguồn thực tế.
3. Người dùng bắt buộc phải qua màn hình xem trước (**Preview**):
   - Có thể **Hủy (Cancel)**: Chuyến đi và digest giữ nguyên 100%, không áp dụng bất kỳ thay đổi nào.
   - Có thể **Xác nhận (Confirm)**: Áp dụng các lệnh `AddItemCommand` có gắn `externalBinding` vào lịch trình.
4. Lưu trữ và đọc lại trọn vẹn qua `TripEvidenceRepository` / `EditableLocalStore` mà **tuyệt đối không làm thay đổi số lượng bản ghi trong Catalogue của Admin (`discovery_places`)**.

---

## 2. Các bất biến kiến trúc bắt buộc (5 Luật Bất Biến)

- **Law 1 (Quyền kiểm soát thuộc về người dùng):** AI chỉ tạo đề xuất, không tự động ghi đè chuyến đi. Người dùng có quyền xem trước so sánh trước/sau, kiểm tra các cảnh báo nguồn Internet, và chọn xác nhận hoặc hủy.
- **Law 2 (Bảo vệ dữ liệu Catalogue Admin & Phân quyền):** Các địa điểm tìm kiếm từ web (`externalPlaces`) chỉ thuộc về chuyến đi của người dùng đó. Tuyệt đối không thêm dữ liệu chưa kiểm duyệt vào bảng `discovery_places` hay Storage Catalogue của Admin.
- **Law 3 (Minh bạch căn cứ & Giá tiền trung thực):**
  - Mọi hoạt động từ web mang nhãn `"Thông tin từ Internet, chưa được Admin kiểm duyệt"`.
  - Giá tiền không có trong nguồn trích dẫn thì giữ nguyên `costVnd: null` (hoặc `unknown`), tuyệt đối **không tự ý coi là 0 VNĐ hay miễn phí**.
- **Law 4 (Bất đồng bộ & An toàn giao dịch):** Khi đang gửi yêu cầu tạo đề xuất web, nếu người dùng đóng màn hình, đổi chuyến đi hoặc đăng xuất, phản hồi muộn lập tức bị hủy (`stale`). Kích thước tài liệu không vượt quá giới hạn 1 MiB.
- **Law 5 (Stage-Gate Protocol):** Trình Implementation Plan chi tiết này cho Owner duyệt trước khi bắt đầu code.

---

## 3. Danh mục tệp dự kiến (File Map)

| STT | Đường dẫn tệp | Hành động | Mục đích |
| :---: | :--- | :---: | :--- |
| 1 | `supabase/functions/itinerary-proposal/gateway.mjs` | **Cập nhật** | Hỗ trợ hợp đồng `travelgo.web.proposal.v1`: gọi Gemini với công cụ Search Grounding, chuẩn hóa kết quả thành đề xuất hoạt động kèm `externalPlaces` và `evidence` |
| 2 | `test/web_proposal_gateway_test.mjs` | **Tạo mới** | Bộ kiểm thử tự động Node.js cho hợp đồng `travelgo.web.proposal.v1` (từ chối guest, replay idempotency, trích xuất `externalPlaces`, kiểm tra `origin: 'web'`) |
| 3 | `lib/features/trip_planner/models/ai_grounded_proposal.dart` | **Cập nhật** | Bổ sung factory `fromWebReceipt(...)`: tạo `ExternalPlaceRecord`, `ExternalItemBinding` và gán `FieldProvenance(quality: 'unknown', sourceRefs: [...])` |
| 4 | `lib/features/trip_planner/services/ai_generation_service.dart` | **Cập nhật** | Thêm hàm `requestWebProposal(...)` giao tiếp với Edge Function qua hợp đồng `travelgo.web.proposal.v1` |
| 5 | `lib/features/trip_planner/presentation/widgets/ai_generation_preview.dart` | **Cập nhật** | Hiển thị nhãn cảnh báo Internet và hỗ trợ xem căn cứ ngoài (`externalPlaces`) trong màn hình xem trước |
| 6 | `test/ai_external_trip_test.dart` | **Tạo mới** | Bộ kiểm thử tích hợp Flutter: tạo đề xuất web, preview/cancel bảo toàn document, confirm gắn `externalBindings`, lưu và đọc lại qua `TripEvidenceRepository`, xác nhận 0 biến động trong Catalogue Admin |

---

## 4. Chi tiết Hợp đồng Kỹ thuật (Technical Contract)

### 4.1. Request Contract: `travelgo.web.proposal.v1`
```json
{
  "contract": "travelgo.web.proposal.v1",
  "requestId": "w3000000-0000-4000-8000-000000000001",
  "consent": true,
  "webConsent": true,
  "prompt": "Lập lịch trình 2 ngày tại Phú Yên khám phá Bãi Xép và Ghềnh Đá Đĩa",
  "context": {
    "destinationName": "Phú Yên",
    "dates": ["2026-11-20", "2026-11-21"],
    "numPeople": 2,
    "budgetVnd": 4000000,
    "interests": ["biển", "ngắm cảnh"],
    "scope": "whole_trip",
    "baseDigest": "c8d9e0f1..."
  }
}
```

### 4.2. Response Contract: `travelgo.web.proposal.v1`
```json
{
  "status": "succeeded",
  "requestId": "w3000000-0000-4000-8000-000000000001",
  "proposal": {
    "contract": "travelgo.itinerary.v1",
    "destinationId": "custom-phu-yen",
    "numDays": 2,
    "summary": "Lịch trình 2 ngày tại Phú Yên tham quan Ghềnh Đá Đĩa và Bãi Xép.",
    "activities": [
      {
        "day": 1,
        "title": "Tham quan Ghềnh Đá Đĩa",
        "startMinute": 480,
        "endMinute": 660,
        "costVnd": 40000,
        "category": "attractions",
        "externalPlaceName": "Ghềnh Đá Đĩa"
      }
    ],
    "warnings": [
      "Thông tin từ Internet, chưa được Admin kiểm duyệt: kiểm tra giờ mở cửa và giá vé thực tế."
    ],
    "model": "gemini-3.5-flash-lite",
    "verification": "unverified"
  },
  "evidence": [
    {
      "id": "web:ghenhdadia-phuyen",
      "origin": "web",
      "url": "https://phuyen.gov.vn/ghenh-da-dia",
      "title": "Thắng cảnh quốc gia Ghềnh Đá Đĩa",
      "factKey": "general",
      "factValue": "Địa điểm du lịch nổi tiếng tại Tuy An, Phú Yên",
      "retrievedAt": "2026-10-27T17:00:00Z",
      "reviewed": false
    }
  ],
  "claims": [
    {
      "id": "claim:web:0",
      "kind": "fact",
      "text": "Ghềnh Đá Đĩa là điểm tham quan tại Phú Yên",
      "evidenceIds": ["web:ghenhdadia-phuyen"]
    }
  ],
  "externalPlaces": [
    {
      "id": "ext-ghenh-da-dia",
      "name": "Ghềnh Đá Đĩa",
      "destinationName": "Phú Yên",
      "evidenceIds": ["web:ghenhdadia-phuyen"]
    }
  ],
  "baseDigest": "c8d9e0f1..."
}
```

---

## 5. Quy trình Kiểm thử & Nghiệm thu (Verification SOP)

1. **Kiểm thử Edge Function (Node.js):**
   - Chạy `node --test test/web_proposal_gateway_test.mjs`.
   - Chạy lại toàn bộ 10 file hợp đồng Edge Functions: đảm bảo 100% PASS.
2. **Kiểm thử Flutter Client (Dart):**
   - Chạy `flutter test test/ai_external_trip_test.dart`.
   - Kiểm tra:
     - Tạo đề xuất web với `externalPlaces` và `externalBindings`.
     - Hủy xem trước (Cancel) $\rightarrow$ giữ nguyên tài liệu cũ và digest cũ.
     - Xác nhận xem trước (Confirm) $\rightarrow$ tạo `TripItem` có `placeId: null`, liên kết đúng `ExternalItemBinding`, `provenance.sourceRefs` giữ nguyên id nguồn.
     - Lưu chuyến đi vào CSDL $\rightarrow$ đọc lại qua repository bảo toàn 100% căn cứ.
     - Đếm số lượng bản ghi trong Catalogue của Admin $\rightarrow$ không thay đổi.
3. **Kiểm thử Tích hợp Toàn diện (Full Suite):**
   - Chạy `flutter analyze` $\rightarrow$ 0 lỗi, 0 cảnh báo.
   - Chạy `tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter` $\rightarrow$ PASS exit code 0.

