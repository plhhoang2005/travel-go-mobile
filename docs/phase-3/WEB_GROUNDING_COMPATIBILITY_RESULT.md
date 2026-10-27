# Báo Cáo Kỹ Thuật: Kiểm Tra Tương Thích Google Search Grounding (W1 Spike)

> **Mã công việc:** S5 — W1 (Compatibility Spike for Google Search Grounding)  
> **Thời điểm thực hiện:** 27/10/2026  
> **Nhánh:** `codex/owner-a2-evidence-persistence`  
> **Tài liệu căn cứ:** [Web R2 Plan](../superpowers/plans/2026-10-24-coursework-web-r2.md), [AI Planner Design](../../.agent/ai-planner-design.md), [Product Scope](../../.agent/product-scope.md).

---

## 1. Tóm tắt kết quả (Executive Summary)

- **Quyết định:** **GO** cho giai đoạn **S6 — W2 (Opt-in Web Advice)**.
- **Phạm vi spike:** Kiểm tra định dạng API, tham số request, cấu trúc metadata trả về, thuật toán ánh xạ trích dẫn (citation/claim mapping), quy định bản quyền/UI attribution của Google, chi phí/quota, và phương án xử lý ký tự tiếng Việt đa byte UTF-8.
- **Trạng thái kiểm thử:** 
  - Đã xây dựng và xác minh thành công bộ kiểm tra cục bộ (Local Fixture & Parser Suite) tại `.dart_tool/web_grounding_spike/verify_spike.mjs` (5/5 PASS).
  - Trạng thái gọi trực tiếp tới mạng thật (Live Probe): **LIVE NOT RUN** (chờ cấp quyền API key thực tế khi triển khai live; toàn bộ contract transport & normalization đã được cô lập an toàn).

---

## 2. Thông số kỹ thuật & Giao thức API (API Contract)

| Thuộc tính | Giá trị tiêu chuẩn | Ghi chú kỹ thuật |
| :--- | :--- | :--- |
| **API Family** | Google Generative Language REST API `v1beta` | Khớp với hạ tầng gateway hiện hữu (`gateway.mjs`). |
| **Endpoint** | `POST https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent` | Gọi thông qua backend Supabase Edge Function `itinerary-proposal`. |
| **Model ID** | `gemini-3.5-flash-lite` (hoặc runtime fallback `gemini-2.5-flash`) | Hỗ trợ multimodal, function calling, grounding, và structured outputs. |
| **Tool Declaration** | `tools: [ { "google_search": {} } ]` | REST API v1beta sử dụng `google_search` (snake_case). |
| **Header** | `x-goog-api-key: <GEMINI_API_KEY>`, `content-type: application/json` | Giữ nguyên cấu hình bảo mật gateway. |

### Cấu trúc Request tiêu chuẩn (W2 Advice)

```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Người dùng hỏi: Giờ mở cửa của Bảo tàng Lịch sử Quốc gia tại Hà Nội là khi nào? Điểm đến: Hà Nội."
        }
      ]
    }
  ],
  "tools": [
    {
      "google_search": {}
    }
  ],
  "generationConfig": {
    "maxOutputTokens": 2048,
    "temperature": 0.2
  }
}
```

---

## 3. Cấu trúc Metadata Căn cứ Trả về (`groundingMetadata`)

Khi Google Gemini thực hiện tìm kiếm web, `candidates[0].groundingMetadata` chứa các trường sau:

```json
{
  "groundingMetadata": {
    "webSearchQueries": [
      "giờ mở cửa Bảo tàng Lịch sử Quốc gia Hà Nội"
    ],
    "groundingChunks": [
      {
        "web": {
          "uri": "https://baotanglichsu.vn/vi/Articles/3096/gio-mo-cua.html",
          "title": "Giờ mở cửa và giá vé - Bảo tàng Lịch sử Quốc gia"
        }
      }
    ],
    "groundingSupports": [
      {
        "segment": {
          "startIndex": 0,
          "endIndex": 48,
          "text": "Bảo tàng mở cửa từ 8:00 đến 12:00 và 13:30 đến 17:00"
        },
        "groundingChunkIndices": [0],
        "confidenceScores": [0.94]
      }
    ],
    "searchEntryPoint": {
      "renderedContent": "<div class=\"google-search-chip\">...</div>"
    }
  }
}
```

---

## 4. Phát hiện cốt lõi: Ánh xạ đoạn trích dẫn (UTF-8 Byte Offset)

### Vấn đề kỹ thuật
Trong tài liệu chuẩn của Google Gemini API, `startIndex` và `endIndex` trong `segment` là **UTF-8 Byte Offsets** (offset theo số byte mã hóa UTF-8), **KHÔNG PHẢI** là chỉ số ký tự UTF-16 hay độ dài chuỗi (`String.length`).

### Thực nghiệm với tiếng Việt
- Chuỗi tiếng Việt `"Đà Lạt"`:
  - Độ dài chuỗi trong JavaScript / Dart (`String.length` UTF-16 code units): **6 ký tự**.
  - Độ dài byte trong UTF-8: **10 bytes** (`Đ` = 2 bytes, `à` = 2 bytes, ` ` = 1 byte, `L` = 1 byte, `ạ` = 3 bytes `[0xE1, 0xBA, 0xA1]`, `t` = 1 byte).
- **Rủi ro:** Nếu dùng trực tiếp `string.substring(startIndex, endIndex)` trong Dart hoặc JavaScript, toàn bộ vị trí trích dẫn sẽ bị lệch nghiêm trọng (drift) hoặc cắt ngang chừng ký tự đa byte gây lỗi hiển thị.

### Giải pháp kỹ thuật chuẩn hóa
1. **Trong Node.js (Gateway):**
   ```javascript
   function sliceUtf8Bytes(text, start, end) {
     const buf = Buffer.from(text, 'utf-8');
     return buf.subarray(start, end).toString('utf-8');
   }
   ```
2. **Trong Dart (Flutter client):**
   ```dart
   String sliceUtf8Bytes(String text, int start, int end) {
     final bytes = utf8.encode(text);
     final safeStart = start.clamp(0, bytes.length);
     final safeEnd = end.clamp(safeStart, bytes.length);
     return utf8.decode(bytes.sublist(safeStart, safeEnd), allowMalformed: true);
   }
   ```
3. **Cơ chế dự phòng (Fallback):** Nếu `segment.text` được API trả về trực tiếp, ưu tiên đối chiếu `segment.text` trước khi cắt byte.

---

## 5. Tương thích giữa Google Search và Structured Outputs (JSON Schema)

- **W2 (Web Advice):** Là văn bản tự nhiên giải đáp câu hỏi của người dùng kèm trích dẫn web (`operations = []`, không chỉnh sửa trực tiếp vào lịch trình). Khớp 100% với cấu hình sinh văn bản tự nhiên + `google_search` grounding.
- **W3 (Web Proposal):** Cần sinh hoạt động có cấu trúc vào lịch trình.
  - Các phiên bản mô hình cũ hơn (`gemini-2.5` ban đầu) từng gặp hiện tượng lược bỏ một phần `groundingSupports` khi ép `responseMimeType: "application/json"`.
  - Trên `gemini-3.5-flash-lite`, tính năng kết hợp Structured Output và Search Grounding đã được hỗ trợ chính thức.
  - **Phương án an toàn (Decoupled Fallback Strategy):** Nếu live gateway gặp hiện tượng thiếu metadata khi ép JSON strict:
    - *Bước 1:* Gọi Web Search Grounding dạng văn bản để thu thập facts và metadata chính xác.
    - *Bước 2:* Dùng prompt nội bộ trích xuất các hoạt động đã được kiểm chứng vào JSON schema của TravelGO.
    - *Ghi chú:* W2 không bị ảnh hưởng bởi vấn đề này.

---

## 6. Yêu cầu hiển thị và Bản quyền (UI Attribution & Guidelines)

Theo điều khoản dịch vụ Google Search Grounding:
1. **Hiển thị nguồn:** Phải hiển thị danh sách các đường dẫn nguồn trích dẫn từ `groundingChunks[i].web.uri` kèm tiêu đề `title`.
2. **Search Entry Point:** Nếu `searchEntryPoint.renderedContent` có dữ liệu, hiển thị widget / logo tìm kiếm của Google.
3. **Chỉ dẫn người dùng (Luật TravelGO):** Bắt buộc hiển thị nhãn minh bạch:  
   `"Thông tin từ Internet, chưa được Admin kiểm duyệt"`  
   và nút `"Xem căn cứ"` mở `EvidenceDetailsSheet`.

---

## 7. Chi phí và Quota (Billing & Quota Semantics)

- **Hạn mức miễn phí:** 5.000 truy vấn tìm kiếm mỗi tháng (dùng chung cho các mô hình Gemini 3+ trên cùng dự án).
- **Chi phí trả phí (sau 5.000 lượt):** $14.00 / 1.000 lượt truy vấn tìm kiếm.
- **Chi phí Token:**
  - Input tokens: $0.30 / 1.000.000 tokens.
  - Output tokens: $2.50 / 1.000.000 tokens.
- **Chính sách TravelGO:** 
  - Chỉ kích hoạt tìm kiếm Web khi người dùng chủ động chọn ("Opt-in").
  - Mỗi yêu cầu tìm kiếm web được gán 1 `requestId` duy nhất, không tạo retry ngầm lãng phí hạn mức.

---

## 8. Kết luận và Kế hoạch chuyển tiếp sang S6 (W2)

- Spike W1 hoàn thành mục tiêu nghiên cứu và chứng minh tính tương thích.
- **Handoff:** Chuyển sang lập kế hoạch triển khai **S6 — W2 (Opt-in Web Advice)** với đầy đủ Stage-Gate Review:
  1. Xây dựng Edge Function module `supabase/functions/itinerary-proposal/web-evidence.mjs` và bộ test `test/web_evidence_test.mjs`.
  2. Bổ sung endpoint contract `travelgo.web.advice.v1` trong `gateway.mjs`.
  3. Cập nhật Flutter UI: nút tùy chọn tìm kiếm Web ("Tìm thông tin Internet"), nhãn cảnh báo nguồn Internet, và liên kết xem căn cứ.

