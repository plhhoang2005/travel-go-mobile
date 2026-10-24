# Báo Cáo Inventory & POI Coverage Kiểm Chứng (RAG T0) — TravelGO Mobile

- **Dự án**: TravelGO Mobile (Flutter Client)
- **Tài liệu**: `docs/phase-3/RAG_INVENTORY_AND_DATA_COVERAGE_20261024.md`
- **Phiên bản**: T1 Implementation & Review Alignment
- **Ngày thực hiện**: 24/10/2026
- **Implementer**: Antigravity (AGY Mobile Team)
- **Baseline Git HEAD**: `93b0abf00459007fec9049221f9d8746ad2a3cdb`
- **Reviewed HEAD**: `c789c7a522719fc2f535cd18a30050bef7c3982c`
- **Nhánh làm việc**: `fix/ai-planning-stability`
- **Trạng thái**: ĐÃ HOÀN THÀNH TRIỂN KHAI VÀ REPAIR THEO BÁO CÁO REVIEW CODEX

---

## 1. Mục Tiêu Đợt T0 (RAG Inventory & Data Readiness)

Mục tiêu của đợt T0 là kiểm kê toàn diện tài sản dữ liệu hiện có trong codebase TravelGO Mobile, đối chiếu các mô hình vé/lịch tham quan (`VisitPrice`, `VisitScheduleRule`, `PlaceVisitDetails`), đo lường độ phủ thực tế (data coverage) trên 72 địa điểm (12 điểm đến), và chỉ định điểm đến thí điểm (Pilot Destination) dựa trên chứng cứ dữ liệu thực tế nhằm phục vụ việc tích hợp Retrieval-Augmented Generation (RAG) cho AI Assistant & AI Planner mà **không phải đập đi xây lại hoặc phát minh cấu trúc dữ liệu mới**.

---

## 2. Kiểm Kê Tài Sản Mô Hình Hiện Có (Codebase Inventory)

### 2.1. Mô hình dữ liệu lõi trong Mobile (`lib/features/explore/models/place_visit_details.dart`)

Codebase TravelGO Mobile đã sở hữu sẵn hệ thống model phân cấp cực kỳ chặt chẽ cho dữ liệu tham quan, bao gồm đầy đủ các khía cạnh tài chính, lịch trình và bằng chứng kiểm duyệt:

1. **`PlaceVisitDetails`**:
   - `placeId` (String): ID định danh địa điểm (dạng `<destination>/<slug>`, ví dụ `hue/citadel`).
   - `visitScopeLabel` (String): Phạm vi tham quan (ví dụ: *"Đại Nội có vé, không bao gồm toàn bộ Kinh thành"*).
   - `price` (`VisitPrice`): Cấu trúc giá vé chi tiết.
   - `hours` (`VisitHours`): Cấu trúc giờ mở cửa và quy tắc vận hành.
   - `notes` (`List<String>`): Ghi chú cảnh báo, lưu ý di chuyển.
   - `isComplete` (bool getter): Xác nhận cả giá vé lẫn giờ mở cửa đều ở trạng thái `reviewed` và không còn `unresolvedIssues`.

2. **Mô hình Giá vé (`VisitPrice` & `VisitPriceOption`)**:
   - `VisitPrice.status`: Thuộc tập enum xác định: `priced` | `free` | `bundled` | `variable` | `unverified`.
   - `VisitPriceOption`:
     - `id`: Định danh tùy chọn vé (ví dụ: `hue-citadel-standard-adult`).
     - `label`: Tên loại vé (*Vé tiêu chuẩn người lớn*).
     - `audience`: Đối tượng áp dụng (*Khách Việt Nam/Quốc tế*, *Trẻ em 7–12 tuổi*).
     - `amountVnd` (int?): Giá vé tính bằng VNĐ (bắt buộc = 0 nếu `free`, > 0 nếu `priced`, null nếu `unverified`).
     - `unit`: Đơn vị tính (*người/lượt*, *nhóm*, *xe*).
     - `packageId`: ID gói combo nếu thuộc vé tuyến/gói chung.
     - `conditions`, `included`, `excluded`: Các quyền lợi và điều kiện loại trừ.

3. **Mô hình Lịch trình & Giờ mở cửa (`VisitHours` & `VisitScheduleRule`)**:
   - `VisitHours.status`: `scheduled` | `seasonal` | `event_based` | `no_fixed_hours` | `temporarily_closed` | `unverified`.
   - `VisitScheduleRule`:
     - `label`: Nhãn quy tắc (*Mùa hè*, *Mùa đông*, *Thứ Hai – Chủ nhật*).
     - `weekdays` (`List<int>`): Danh sách các ngày trong tuần (1 = Thứ Hai, ..., 7 = Chủ nhật).
     - `seasonStart`, `seasonEnd`: Chuỗi định dạng `MM-DD` xác định khoảng thời gian theo mùa (ví dụ: `03-16` đến `10-15` cho mùa hè).
     - `startMinutes`, `endMinutes`: Phút bắt đầu và kết thúc trong ngày (0 đến 1439/1440).
     - `admissionCutoffMinutes`: Hạn chót nhận khách/bán vé trước khi đóng cửa (ví dụ: trước 60 phút).
     - `appliesOn(DateTime localDate)`: Hàm logic thuần túy xác định quy tắc có hiệu lực vào một ngày lịch Việt Nam cụ thể hay không.

4. **Mô hình Bằng chứng & Nguồn xác minh (`VisitEvidence` & `VisitSource`)**:
   - `sourceIds`: Danh sách ID nguồn thông tin chính thống được đối chiếu.
   - `checkedAt`: Ngày kiểm tra thực tế (DateTime).
   - `reviewState`: Trạng thái rà soát (`unverified` hoặc `reviewed`).
   - `needsReview(DateTime now)`: Hàm tính toán độ tươi dữ liệu — cảnh báo nếu nguồn đã kiểm tra quá 30 ngày so với hiện tại.
   - `conditions`, `unresolvedIssues`: Các vấn đề còn tồn đọng cần tra cứu thêm.

5. **Mô hình Gói tham quan combo (`VisitPackage`)**:
   - Phục vụ giải quyết các gói vé tham quan liên tuyến (ví dụ: combo 3 điểm Đại Nội – Minh Mạng – Khải Định, hoặc vé tuyến 1/tuyến 2 Vịnh Hạ Long), tránh lỗi cộng dồn chi phí sai thực tế.

### 2.2. Kho lưu trữ và Pipeline xuất bản (Storage & Publication Pipeline)

1. **Local Bundled Seed**:
   - `assets/catalogue/place_visit_details_v1.json`: File JSON đóng gói sẵn trong ứng dụng, định dạng `schemaVersion: 1`, gồm **72 places**, **24 sources**, **25 packages**, có SHA-256 catalogue hash kiểm tra toàn vẹn.
   - `assets/catalogue/catalogue_readiness_v1.json`: Danh mục 72 địa điểm và kịch bản mẫu của 12 điểm đến.
2. **Hạ tầng Quản lý & Cập nhật từ xa (Remote Staging/Publication)**:
   - Supabase Edge Function `admin-publication` (`supabase/functions/admin-publication/`): Quản lý đóng gói bundle `travelgo.discovery.release.v2` với CAS (Compare-And-Swap), tính toán SHA-256, và upload immutable vào Supabase Storage bucket `discovery-catalogue`.
   - Mobile Repository `VisitDetailsRepository` (`lib/features/explore/services/place_visit_details_repository.dart`):
     - Cơ chế 2 tầng: Tự động nạp local seed làm cơ sở hoạt động ngoại tuyến an toàn (Law 3).
     - Khi có mạng (`remoteEnabled: true`), kiểm tra manifest version qua HTTP và tải bản phát hành mới vào bộ nhớ đệm `VisitReleaseCache` (`place_visit_cache.dart`).

---

## 3. Báo Cáo Đo Lường Độ Phủ Dữ Liệu (Coverage Audit 72 POIs)

Dữ liệu thực tế được trích xuất trực tiếp bằng công cụ phân tích từ `assets/catalogue/place_visit_details_v1.json` và đối chiếu với tài liệu `docs/phase-3/DISCOVERY_VISIT_DETAILS_72_COVERAGE_20261020.md`:

### 3.1. Bảng tổng hợp độ phủ theo 12 Điểm đến

| STT | Điểm đến (`destinationId`) | Tổng POI | Cả Giá & Giờ ĐÃ REVIEWED | Chỉ có Giá Reviewed | Chỉ có Giờ Reviewed | Chưa xác minh / Trống | Tỷ lệ Hoàn tất (%) |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| 1 | **Hạ Long** (`ha-long`) | 6 | **6** | 0 | 0 | 0 | **100.0%** |
| 2 | **Huế** (`hue`) | 6 | **4** | 0 | 0 | 2 | **66.7%** |
| 3 | **Đà Nẵng** (`da-nang`) | 6 | **2** | 2 | 1 | 1 | **33.3%** |
| 4 | **Hội An** (`hoi-an`) | 6 | **2** | 2 | 0 | 2 | **33.3%** |
| 5 | **Hà Nội** (`ha-noi`) | 6 | **2** | 0 | 0 | 4 | **33.3%** |
| 6 | **Cần Thơ** (`can-tho`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| 7 | **Đà Lạt** (`da-lat`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| 8 | **TP. Hồ Chí Minh** (`ho-chi-minh`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| 9 | **Nha Trang** (`nha-trang`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| 10 | **Ninh Bình** (`ninh-binh`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| 11 | **Phú Quốc** (`phu-quoc`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| 12 | **Sa Pa** (`sa-pa`) | 6 | 0 | 0 | 0 | 6 | 0.0% |
| **TỔNG** | **12 Điểm đến** | **72** | **16** | **4** | **1** | **51** | **22.2%** |

### 3.2. Đánh giá chất lượng dữ liệu toàn hệ thống

- **Số lượng đã hoàn tất kiểm duyệt cả hai tiêu chí**: **16 / 72 hồ sơ (22.2%)**.
- **Số lượng đã kiểm duyệt giá**: **20 / 72 hồ sơ (27.8%)**.
- **Số lượng đã kiểm duyệt giờ tham quan**: **17 / 72 hồ sơ (23.6%)**.
- **Số lượng hồ sơ chưa có căn cứ hoặc thiếu nguồn chính thống**: **56 / 72 hồ sơ (77.8%)**.
- **Nhận xét kiến trúc**:
  - Codebase TravelGO **không có dữ liệu giả định (zero mock facts)**. Dữ liệu chưa xác minh được giữ nguyên trạng thái `status: 'unverified'` và `reviewState: 'unverified'`.
  - Điều này tuân thủ nghiêm ngặt **Luật 3 (Zero Silent Fallbacks)**: RAG tuyệt đối không được tự bịa ra giờ mở cửa hoặc giá vé cho 56 địa điểm chưa xác minh, mà phải hiển thị rõ nhãn `[Chưa xác minh]` và trả availability là `unknown`.

---

## 4. Chỉ Định Điểm Đến Thí Điểm Có Chứng Cứ (Evidence-Based Pilot Selection)

### 4.1. Điểm đến được chọn làm Thí điểm Chính: **Huế (`hue`)**

Qua đối chiếu kỹ thuật, **Huế (`hue`)** được chỉ định là Điểm đến Thí điểm (Primary Pilot Destination) cho việc tích hợp RAG với các chứng cứ kỹ thuật sau:

1. **Đầy đủ dữ liệu phức tạp cho mô hình toán & RAG**:
   - 4 di tích trọng điểm của Trung tâm Bảo tồn Di tích Cố đô Huế có dữ liệu vé và giờ mở cửa đã kiểm duyệt 100%:
     - `hue/citadel` (Kinh thành / Đại Nội): Vé lẻ người lớn 200.000đ, trẻ em 40.000đ. Giờ mùa hè (16/03–15/10) mở 06:30–18:30 (cắt vé 17:30); giờ mùa đông (16/10–15/03) mở 07:00–18:00 (cắt vé 17:00).
     - `hue/tu-duc` (Lăng Tự Đức): Vé người lớn 150.000đ, trẻ em 30.000đ. Cắt vé trước 60 phút.
     - `hue/minh-mang` (Lăng Minh Mạng): Vé người lớn 150.000đ, trẻ em 30.000đ.
     - `hue/khai-dinh` (Lăng Khải Định): Vé người lớn 150.000đ, trẻ em 30.000đ.
2. **Kịch bản Combo Packages (Vé tuyến) điển hình**:
   - Hệ thống vé Huế có các gói combo:
     - Gói 3 điểm (Đại Nội – Minh Mạng – Khải Định): 420.000đ (tiết kiệm 80.000đ so với mua lẻ 500.000đ).
     - Gói 4 điểm (Đại Nội – Minh Mạng – Tự Đức – Khải Định): 530.000đ (tiết kiệm 120.000đ so với mua lẻ 650.000đ).
   - *Giá trị cho RAG*: Đây là ca kiểm thử kinh điển để chứng minh RAG giải quyết được bài toán tránh cộng dồn chi phí sai (tránh nhân đôi/nhân ba ngân sách khi đi nhiều điểm trong cùng gói).
3. **Kịch bản Lịch trình theo mùa & Giờ cắt vé**:
   - Có phân biệt rõ ràng giữa mùa hè và mùa đông, cùng thời gian đóng cổng vé trước 60 phút.
   - *Giá trị cho RAG*: RAG Assistant có thể đối chiếu ngày đi cụ thể của người dùng (`date`) để inject đúng `openingWindows` vào prompt, ngăn AI đề xuất đi tham quan sau 17:00 (mùa đông) hoặc sau 17:30 (mùa hè).
4. **Kiểm thử tính minh bạch dữ liệu chưa xác minh (Negative Control)**:
   - 2 địa điểm còn lại của Huế phản ánh đúng thực tế du lịch:
     - `hue/dong-ba` (Chợ Đông Ba): Không thu vé vào cổng (`status: 'unverified'` vé tham quan, giờ mở cửa 06:30–19:00 mang tính tham khảo).
     - `hue/thien-mu` (Chùa Thiên Mụ): Chưa có quy định giờ mở cửa chính thức bằng văn bản (`status: 'unverified'`).
   - *Giá trị cho RAG*: Giúp kiểm thử khả năng xử lý biên của RAG — AI Assistant phải thông báo rõ `availability: 'unknown'` và không được tự bịa giá vé cho Chùa Thiên Mụ hay Chợ Đông Ba.
5. **Phù hợp Persona Mục tiêu (Minh)**:
   - Chuyến đi 2–3 ngày, ngân sách 3–5 triệu VNĐ, du lịch văn hóa kết hợp ẩm thực.

### 4.2. Điểm đến Đối chứng Dương (Positive Control): **Hạ Long (`ha-long`)**

- 6/6 địa điểm (100%) đã được kiểm duyệt hoàn chỉnh cả vé và giờ tham quan.
- Dùng làm bộ kiểm thử đối chứng dương để khẳng định: Khi dữ liệu đạt 100% độ phủ, hệ thống RAG không phát sinh bất kỳ cảnh báo `unknown` hay `unverified` nào.

---

## 5. Kết Luận Kiểm Kê & Khuyến Nghị Cho RAG Phase

1. **Tận dụng tối đa mô hình hiện có**: Không cần tạo thêm schema JSON mới. RAG Retrieval layer chỉ cần truy xuất và chuyển đổi các trường của `PlaceVisitDetails` (đặc biệt là `rules` của `VisitHours` và `options` của `VisitPrice`) thành các facts có cấu trúc chuẩn cho AI Prompt.
2. **Cơ chế Fallback rõ ràng**: Với 56/72 POIs chưa kiểm duyệt, hệ thống RAG bắt buộc phải trả trạng thái minh bạch `availability: 'unknown'` và `price: 'unverified'`, tuân thủ Luật 3 của dự án.

