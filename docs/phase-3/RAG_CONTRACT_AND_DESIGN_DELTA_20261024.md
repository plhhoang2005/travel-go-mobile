# RAG Contract & Design Delta (RAG T0) — TravelGO Mobile

- **Dự án**: TravelGO Mobile (Flutter Client)
- **Tài liệu**: `docs/phase-3/RAG_CONTRACT_AND_DESIGN_DELTA_20261024.md`
- **Phiên bản**: T1 Repair — Architecture Responsibility, Contract Implementation & Codex Review Alignment
- **Ngày thực hiện**: 24/10/2026
- **Implementer**: Antigravity (AGY Mobile Team)
- **Baseline Git HEAD**: `93b0abf00459007fec9049221f9d8746ad2a3cdb`
- **Reviewed HEAD**: `c789c7a522719fc2f535cd18a30050bef7c3982c`
- **Nhánh làm việc**: `fix/ai-planning-stability`
- **Trạng thái**: ĐÃ HOÀN THÀNH TRIỂN KHAI & REPAIR R1–R7 THEO REVIEW CỦA CODEX

---

## 1. Phân Định Trách Nhiệm Kiến Trúc (Architecture Responsibility & Trade-Offs)

Một trong những câu hỏi cốt lõi trước khi thiết kế RAG cho TravelGO là: **Backend nào chịu trách nhiệm lưu trữ, tính toán và bảo đảm tính đúng đắn của dữ liệu giá vé và lịch trình?**

### 1.1. Bản đồ trách nhiệm theo 5 Luật Bất Biến (Architecture Alignment)

Hệ thống TravelGO phân định ranh giới trách nhiệm rất rõ ràng:

```
[Flutter Mobile Client]  <--- Untrusted Presentation Client & Offline Seed Store
       │
       ▼ (HTTPS REST / RPC with JWT & Quota Guard)
[Supabase Edge Function: itinerary-proposal] <--- Security Gateway & Contract Validator
       │
       ▼ (LLM Orchestration with Grounded Context)
[Gemini 1.5/2.0 API] <--- Explanation & Suggestion Generator (Non-authoritative)
       │
[Decision Engine Backend (FastAPI)] <--- Single Source of Truth for MCDA & Pareto (Law 2)
```

1. **Decision Engine Backend (Python/FastAPI)**:
   - **Trách nhiệm duy nhất (Law 2)**: Xử lý các thuật toán toán học tất định (MCDA, Pareto Frontier, Greedy Tour Routing, Phân bổ ngân sách tối ưu).
   - **Ranh giới**: Decision Engine **không phải là CMS dữ liệu địa điểm**. Nó chỉ nhận ma trận chi phí/thời gian và trả về tập nghiệm tối ưu Pareto.
2. **Supabase Edge Function (`itinerary-proposal` & `admin-publication`)**:
   - **Trách nhiệm**: Đóng vai trò Security & Quota Gateway, kiểm tra quyền truy cập (Auth/RLS/Quota), validate JSON schema nghiêm ngặt, bọc LLM Gemini bằng Structured Output, và quản lý các bản phát hành danh mục (`discovery-catalogue`).
3. **Flutter Mobile Client (`travel-go`)**:
   - **Trách nhiệm (Law 1, Law 3, Law 4)**: Cung cấp Dashboard tương tác trực quan, lưu trữ bản seed ngoại tuyến an toàn (`assets/catalogue/place_visit_details_v1.json`), quản lý bộ nhớ đệm cập nhật (`VisitReleaseCache`), và hiển thị nhãn minh bạch `[FALLBACK]` hoặc `[Chưa xác minh]`.

---

### 1.2. Phân Tích Trade-Off Giữa 3 Phương Án Kiến Trúc Cho RAG

| Tiêu chí | Phương án A: Client-Side Deterministic Grounding (Khuyến nghị cho RAG v1) | Phương án B: Server-Side Edge Function Grounding (RAG v2) | Phương án C: Decision Engine Grounding (RAG v2 Hybrid) |
| :--- | :--- | :--- | :--- |
| **Cơ chế hoạt động** | Mobile Client trích xuất dữ liệu thực tế từ `VisitDetailsRepository` (đã có trong bộ nhớ/cache) và đưa vào `AiAssistantContext` (`openingWindows`, `routes`, `places`, `pricingSummary`) trước khi gửi lên Edge Function. | Client chỉ gửi `placeIds`; Edge Function tự truy vấn Postgres/pgvector trên Supabase để ghép context gửi sang Gemini. | Client gửi request về Decision Engine Backend; Decision Engine vừa tính Pareto vừa query vector database. |
| **Hỗ trợ Offline (Law 3)** | **Tối ưu tuyệt đối (100%)**: Bản nháp và gợi ý quy tắc giờ/giá có thể kiểm tra ngay cả khi mất mạng nhờ local catalogue seed. | **Kém**: Mất mạng hoặc Edge Function timeout đồng nghĩa không thể lấy được context. | **Kém**: Phụ thuộc hoàn toàn vào kết nối Backend Python. |
| **Tác động Hạ tầng & DB** | **0% rủi ro**: Không sửa database, không chạy migration, không tốn tài nguyên server. | Cần bổ sung bảng `pgvector`, migration schema, và deploy lại Edge Function. | Cần viết thêm microservice hoặc module CMS cho Decision Engine. |
| **Độ trễ (Latency)** | **Thấp nhất**: 0 network round-trip bổ sung để tra cứu facts. | Thêm 1 round-trip giữa Deno Edge Function và Postgres DB. | Thêm 2 network hops (Client $\rightarrow$ Python $\rightarrow$ DB). |
| **Giới hạn quy mô (Scale limit)** | Bị giới hạn bởi kích thước danh mục trên thiết bị (hiện tại 72 POIs là cực kỳ nhẹ: file JSON ~150KB). | Mở rộng không giới hạn (hàng chục nghìn POIs). | Mở rộng tốt cho dữ liệu lớn. |

### 1.3. Quyết định Kiến trúc: RAG v1 vs RAG v2

- **RAG v1 (Đợt hiện tại — Pilot & Demo Stability)**: Chọn **Phương án A (Client-Side Deterministic Grounding)**.
  - *Lý do*: Tận dụng 100% hạ tầng hiện có (`VisitDetailsRepository`, `place_visit_details_v1.json`, `AiAssistantContext`), không phá vỡ bất kỳ database schema nào, tuân thủ Luật 2 và Luật 3, sẵn sàng chạy ngay cho điểm đến thí điểm Huế (`hue`).
- **RAG v2 (Đợt tương lai — Toàn diện Enterprise)**: Chuyển sang **Phương án B** với bảng vector embeddings trên Supabase Postgres khi số lượng địa điểm vượt quá 1.000 POIs.

---

## 2. Đặc Tả & Đóng Băng Hợp Đồng (Contract Specifications & Freezes)

Nhằm bảo đảm tính ổn định và tương thích ngược với các Edge Functions đã deploy, các thông số hợp đồng được đóng băng chính thức như sau:

### 2.1. Hợp đồng truyền thông (Wire Contract)

- Giữ nguyên wire contract identifier: **`travelgo.assistant.v1`**.
- Giữ nguyên cấu trúc payload hiện tại của Edge Function `itinerary-proposal/gateway.mjs`:
  - `intent`: `'advice'` | `'recommendations'` | `'modify'`.
  - `context`: bao gồm `destinationId`, `selectedDay`, `date`, `priority`, `activities`, `places`, `constraints` (`openingWindows`, `routes`), `weather`.
- **RAG v1 Implementation**: Bổ sung dữ liệu thực tế vào các trường constraints hiện có (`openingWindows`, `routes`). Cấu trúc `places` trên wire contract được **giữ nguyên nghiêm ngặt** `{id, name, sourceId}` để tránh bị `gateway.mjs` object() từ chối schema. Các thông tin grounded facts, giá vé, và cảnh báo được lưu giữ trong `AiAssistantContext.grounding` và truyền tất định tới UI qua warnings/differences mà không làm đổi wire contract.

---

### 2.2. Trạng Thái Khả Dụng (Availability State Machine Freeze)

Trạng thái khả dụng của một địa điểm tham quan được **đóng băng cố định gồm đúng 3 trạng thái**:

$$\text{Availability} \in \{\mathbf{open},\ \mathbf{closed},\ \mathbf{unknown}\}$$

#### Quy tắc chuyển trạng thái tất định (Deterministic State Transitions):
1. **`unknown` (Chưa rõ / Chưa xác minh)**:
   - Kích hoạt khi: `PlaceVisitDetails.hours.status == 'unverified'` HOẶC `hours.evidence.reviewState != 'reviewed'`.
   - Hoặc khi: `hours.status` thuộc `{'no_fixed_hours', 'event_based'}` mà không có ghi chú cụ thể.
   - *Hành vi AI*: AI **tuyệt đối không được khẳng định địa điểm mở cửa hay đóng cửa**, phải thông báo rõ tình trạng chưa xác minh cho người dùng.
2. **`closed` (Đóng cửa)**:
   - Kích hoạt khi: `PlaceVisitDetails.hours.status == 'temporarily_closed'`.
   - Hoặc khi: `VisitScheduleRule.appliesOn(selectedDate)` trả về `false` (ví dụ: điểm chỉ mở thứ Hai–thứ Sáu nhưng người dùng đi vào Chủ nhật).
   - Hoặc khi hoạt động có khung giờ (`startMinute`, `endMinute`) nằm ngoài khoảng `[rule.startMinutes, rule.endMinutes]`.
   - *Hành vi AI*: AI từ chối xếp lịch hoặc cảnh báo xung đột giờ.
3. **`open` (Mở cửa xác nhận)**:
   - Kích hoạt khi: `reviewState == 'reviewed'` VÀ có ít nhất một `VisitScheduleRule` thỏa mãn `rule.appliesOn(selectedDate)`.
   - Khung giờ hợp lệ: `[rule.startMinutes, rule.endMinutes]`, có tính đến `admissionCutoffMinutes` (ngừng nhận khách trước giờ đóng).

---

### 2.3. Căn Cứ & Mô Hình Định Giá (Pricing Basis Freeze)

Đóng băng 3 căn cứ tính giá vé chuẩn:

$$\text{PricingBasis} \in \{\mathbf{per\_person},\ \mathbf{trip\_total},\ \mathbf{packages}\}$$

1. **`per_person` (Theo đầu người)**:
   - Áp dụng cho vé tham quan cá nhân tiêu chuẩn (`unit == 'người/lượt'`).
   - Tổng chi phí = $\text{amountVnd} \times \text{numPeople}$.
   - Có phân tách đối tượng theo `audience` (người lớn vs trẻ em) nếu có thông tin số lượng.
2. **`trip_total` (Tổng chuyến / Nhóm)**:
   - Áp dụng cho các chi phí cố định theo nhóm/phương tiện (ví dụ: vé thuê thuyền trọn gói trên Sông Hương, phí giữ xe).
   - Tổng chi phí = $\text{amountVnd}$ (không nhân với số người).
3. **`packages` (Gói combo liên tuyến)**:
   - Áp dụng khi người dùng lên lịch ghé thăm từ 2 địa điểm trở lên thuộc cùng một `VisitPackage` (ví dụ gói Huế 3 điểm: Đại Nội, Lăng Minh Mạng, Lăng Khải Định).
   - **Quy tắc giải quyết xung đột giá (Package Resolution Rule)**:
     - Hệ thống tính toán song song:
       $$\text{Cost}_{\text{individual}} = \sum \text{amountVnd}(\text{single tickets})$$
       $$\text{Cost}_{\text{package}} = \text{package.amountVnd}$$
     - Nếu chuyến đi bao gồm đủ các điểm thuộc gói và $\text{Cost}_{\text{package}} < \text{Cost}_{\text{individual}}$, hệ thống sẽ áp dụng mức giá combo và đính kèm `packageId`, **tuyệt đối không cộng dồn vé lẻ làm đội ngân sách (tránh bug AI-G03)**.

---

### 2.4. Chính Sách Độ Tươi & Tái Thẩm Định (Freshness & Revalidation Policy)

1. **Tính Toàn Vẹn & Bất Biến (Immutability)**:
   - Mọi bản phát hành danh mục (`VisitCatalogue`) được định danh bằng mã băm **SHA-256**.
   - Bộ nhớ đệm `VisitReleaseCache` có hiệu lực vô thời hạn cho tới khi có phiên bản `version` mới hơn trên remote manifest.
2. **Ngưỡng Độ Tươi Nguồn Dữ Liệu (Source Freshness Age)**:
   - Mỗi hồ sơ có trường `evidence.checkedAt`.
   - Nếu $\text{now} - \text{checkedAt} > 30\text{ ngày}$, hàm `VisitEvidence.needsReview(now)` trả về `true`.
   - *Hành vi UI*: Hiển thị nhãn cảnh báo vàng nhẹ: *"Thông tin đã kiểm tra hơn 30 ngày trước, cần kiểm tra lại thực tế"*, nhưng không làm hỏng app.
3. **Kích hoạt tái thẩm định (Revalidation Triggers)**:
   - Kéo-để-làm-mới (Pull-to-refresh) trên màn hình chi tiết địa điểm hoặc màn hình lập lịch.
   - Khi khởi động ứng dụng (background refresh check nếu `remoteEnabled == true`).
   - Khi phát hiện SHA-256 catalogue mismatch giữa client và server.

---

### 2.5. Giới Hạn Tài Nguyên & Ranh Giới Tin Cậy (Limits & Trust Boundaries)

1. **Ranh giới tin cậy (Trust Boundary)**:
   - Phía Client là untrusted, không được quyền tự ý gán nhãn `reviewed` cho dữ liệu giả mạo. Mọi fact đưa vào prompt phải có `sourceId` hợp lệ tương ứng trong danh mục nguồn chính thống.
2. **Giới hạn số lượng (Hard Limits khớp với gateway.mjs & Dart implementation)**:
   - Số địa điểm tối đa đưa vào ngữ cảnh trợ lý: **$\le 12$ places**.
   - Số khung giờ mở cửa tối đa (`openingWindows`): **$\le 48$ windows**.
   - Số tuyến đường di chuyển tối đa (`routes`): **$\le 48$ routes**.
   - Số hoạt động tối đa: **$\le 48$ activities**.
   - Kích thước payload tối đa: $\le 32\text{ KiB}$ cho request, $\le 14\text{ KiB}$ cho response.

---

## 3. Kế Hoạch Triển Khai Chi Tiết Cho Task Code Đầu Tiên (T1 Implementation Plan)

> [!IMPORTANT]
> Đây là bản kế hoạch chi tiết cho T1 để Owner xem xét và phê duyệt. Antigravity **chưa bắt đầu viết code T1** trong lượt này.

### 3.1. Danh Sách File Cần Can Thiệp Trong T1 (Tối đa 5 files)

1. **`lib/features/trip_planner/services/ai_assistant_service.dart`** (Modify):
   - Bổ sung hàm tiện ích trích xuất và chuyển đổi dữ liệu từ `PlaceVisitDetails` sang `openingWindows` và `places` facts có cấu trúc.
   - Thêm bộ phân giải giá combo (`resolvePackageBudget`).
2. **`lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`** (Modify):
   - Nạp `PlaceVisitDetailsProvider` / `VisitDetailsRepository` snapshot hiện có để inject đúng `openingWindows` và thông tin giá vào `AiAssistantContext.fromDocument` thay vì để `const []`.
3. **`lib/features/trip_planner/models/ai_context_grounding.dart`** (New File):
   - Model bổ trợ định nghĩa enum `AvailabilityState` (`open`, `closed`, `unknown`), `PricingBasis` (`per_person`, `trip_total`, `packages`), và hàm đánh giá `evaluatePlaceAvailability(PlaceVisitDetails details, DateTime date, int? startMinute, int? endMinute)`.
4. **`test/ai_assistant_test.dart`** (Modify):
   - Bảo toàn 100% tests hiện có, bổ sung test assertions kiểm chứng các ràng buộc `openingWindows` và `placeFacts` khi có dữ liệu thật.
5. **`test/ai_assistant_grounding_test.dart`** (New Test File):
   - Bộ kiểm thử độc lập cho logic trích xuất facts từ Pilot Huế (`hue/citadel`, `hue/tu-duc`, `hue/dong-ba`), kiểm thử tính combo vé, kiểm thử chuyển đổi trạng thái `open`/`closed`/`unknown`.

---

### 3.2. Bộ Test Cases Kế Hoạch Cho T1 (TDD Red/Green)

- **`TC-T1.1 (Seasonal Schedule Grounding)`**:
  - *Kịch bản*: Chuyến đi Huế ngày 15/07 (mùa hè) vs 15/12 (mùa đông).
  - *Kỳ vọng*: `hue/citadel` tạo `openingWindow` là `06:30–17:30` (mùa hè) và `07:00–17:00` (mùa đông). Đề xuất tham quan lúc 17:15 vào mùa đông bị chặn bởi `checkAssistantSchedule`.
- **`TC-T1.2 (Combo Package Pricing Resolution)`**:
  - *Kịch bản*: Lịch trình chứa 4 điểm di tích Huế (`citadel`, `minh-mang`, `tu-duc`, `khai-dinh`).
  - *Kỳ vọng*: RAG trích xuất thông tin combo `hue-combo-4`, dự toán hiển thị đúng mức giá gói 530.000đ thay vì tổng vé lẻ 650.000đ.
- **`TC-T1.3 (Transparent Unverified Fallback - Law 3)`**:
  - *Kịch bản*: Hoạt động tại Chợ Đông Ba (`hue/dong-ba`) hoặc Chùa Thiên Mụ (`hue/thien-mu`).
  - *Kỳ vọng*: `availability` trả về `unknown`, `price` trả về `unverified`, UI hiển thị nhãn cảnh báo `[Chưa xác minh giá vé/giờ]`, cấm AI tự bịa giá.
- **`TC-T1.4 (Out-of-Hours Activity Rejection)`**:
  - *Kịch bản*: Hoạt động chỉnh sửa dời giờ tham quan Lăng Tự Đức sang 18:30 (sau giờ đóng cửa).
  - *Kỳ vọng*: `AiAssistantResult.fromJson` phát hiện vi phạm `openingWindows` và ném `FormatException('invalid_assistant_contract')`.
- **`TC-T1.5 (Budget Guard & State Consistency)`**:
  - *Kịch bản*: Người dùng chuyển qua lại giữa các ngày, thay đổi số người.
  - *Kỳ vọng*: Facts được tính toán lại tương ứng với số người và ngày được chọn mà không rò rỉ trạng thái giữa các preview.

---

### 3.3. Ngân Sách Dự Kiến Cho Task T1

- **Số lượng files can thiệp**: $\le 5$ files (2 modified, 2 new, 1 test modified).
- **Số lượng Tool Calls**: $\le 20$ calls.
- **Vòng lặp sửa lỗi (RCA Loops)**: $\le 3$ vòng lặp tối đa.
- **Tiêu chuẩn nghiệm thu kỹ thuật**:
  - `flutter analyze` $\rightarrow$ 0 issues found.
  - `flutter test test/ai_assistant_grounding_test.dart` $\rightarrow$ 100% PASS.
  - `flutter test test/ai_assistant_test.dart` $\rightarrow$ 100% PASS.
  - Full suite verification đạt 100%.

