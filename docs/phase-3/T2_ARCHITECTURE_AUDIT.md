# T2 Architecture & Authority Audit — TravelGO Mobile

- **Dự án**: TravelGO Mobile (Decision Intelligence System)
- **Tài liệu**: `docs/phase-3/T2_ARCHITECTURE_AUDIT.md`
- **Giai đoạn**: Phase 3 — RAG T2 Scalable Retrieval & T3 Production Readiness
- **Thời điểm thực hiện**: 24/10/2026
- **Auditor**: Principal Software Engineer & Chief AI Architect (Antigravity)
- **Git Context**: Branch `fix/ai-planning-stability`, Baseline Candidate HEAD `3b9930e86123c1204e74a77525e476d5777ad83a`

---

## 1. Mục Đích & Phạm Vi Audit (Executive Summary)

Đợt kiểm toán T2.0 được thực hiện trực tiếp trên **Local Workspace thực tế** (Source of Truth) nhằm trả lời chính xác 10 câu hỏi cốt lõi về kiến trúc dữ liệu, đồng bộ hóa catalogue, ranh giới thẩm quyền quyết định (Decision Authority), và hiện trạng các thành phần RAG trước khi triển khai các gói tính năng mở rộng (T2.1, T2.2, T2.3) và tôi luyện sản xuất (T3).

---

## 2. Kết Quả Kiểm Toán 10 Vấn Đề Cốt Lõi (Core Findings)

### 2.1. Có bao nhiêu nguồn catalogue đang hoạt động?
- **Hiện trạng thực tế**: Đang có **2 nguồn catalogue song song** nhưng phục vụ hai tầng dữ liệu khác nhau:
  1. `PublicCatalogueRepository` / `PublicCatalogueProvider`: Quản lý danh mục cơ bản Discovery V2 (`destinations`, `places` với `name`, `slug`, `description`, `imageUrl`, `latitude`, `longitude`, `sourceRefs`).
  2. `VisitDetailsRepository` / `PlaceVisitDetailsProvider`: Quản lý dữ liệu tham quan chuyên sâu (`VisitCatalogue`: `hours` theo mùa, `price` theo đối tượng, `packages` liên tuyến, `sources`, `visitScopeLabel`).
  3. Cả 2 repository đều hỗ trợ 3 tầng: **Bundled Seed** (`assets/catalogue/`), **SQLite Cache** (`public_catalogue_cache.dart`, `place_visit_cache.dart`), và **Remote Storage** (`/storage/v1/object/public/discovery-catalogue/`).
- **Đánh giá**: Kiến trúc phân tách Layer A (Public Discovery) và Layer B (Operational Visit Facts) là hợp lý, nhưng cần một cơ chế điều phối đồng bộ duy nhất để tránh lệch pha phiên bản giữa 2 nguồn.

### 2.2. Snapshot nào được Home, Explore, Planner và Assistant sử dụng?
- **Home**: Sử dụng `HomeCatalogProvider`, được nuôi từ `PublicCatalogueProvider`.
- **Explore**: Sử dụng `DiscoveryProvider`, liên kết với `PublicCatalogueProvider` và inject `PlaceVisitDetailsProvider` để hiển thị nhãn giá/giờ.
- **Planner (Manual Planner)**: 
  - Lấy danh sách địa điểm theo điểm đến `_places` từ `PublicCatalogueSnapshot.destinations[...].places`.
  - Đọc facts chi tiết (`visitDetails`, `packages`) từ `PlaceVisitDetailsProvider.snapshot.catalogue`.
- **Assistant**:
  - `AiAssistantContext.fromDocument` nhận `places` (danh sách `PlaceReference`) từ Planner và giải mã facts qua `resolveGrounding(...)` sử dụng `visitDetails` và `packages` từ `PlaceVisitDetailsProvider`.
- **Đánh giá**: Luồng dữ liệu nhất quán, không có hiện tượng Home/Planner tự đọc file JSON tùy tiện ngoài Provider pipeline.

### 2.3. Visit facts có gắn version với catalogue không?
- **Hiện trạng**: Có. `VisitCatalogue` chứa trường `version` (int), `publishedAt` (ISO DateTime) và `catalogueSha256` (String). Khi Admin xuất bản qua `admin-publication/bundle.mjs`, cả inventory và visit facts đều được gắn chung một manifest release.
- **Lỗ hổng (Gap)**: Trên Mobile, `PublicCatalogueRepository` và `VisitDetailsRepository` refresh độc lập. Nếu mạng gián đoạn khiến một bên cập nhật version $N+1$ còn bên kia vẫn ở version $N$, UI sẽ bị lệch pha giữa metadata địa điểm và thông tin giá/giờ.

### 2.4. Admin Publish hiện đã end-to-end đến Flutter chưa?
- **Backend Edge Functions**: `admin-publication/bundle.mjs` đã hoàn chỉnh: kiểm tra tính hợp lệ của draft, đóng gói bundle, tính SHA-256 nguyên tử, lưu vào Supabase Storage bucket `discovery-catalogue`, và cập nhật `latest.json`.
- **Mobile Client**: Repository đã có hàm `refresh(current)` kiểm tra version tăng đơn điệu (`manifest.version > current.version`), xác minh hash SHA-256 trước khi lưu SQLite và cập nhật `_active`.
- **Khoảng cách đến End-to-End hoàn chỉnh**:
  - Flutter hiện chỉ gọi refresh khi app khởi động (`main.dart`) hoặc khi người dùng quay lại ứng dụng (`onResume`).
  - Chưa có cơ chế nhận sự kiện thông báo xuất bản qua Supabase Realtime Broadcast để kích hoạt refresh tức thì.
  - Chưa có bài test live end-to-end trên thiết bị thật chứng minh "Admin bấm Publish trên Web $\rightarrow$ Cùng 1 file APK trên máy người dùng tự động cập nhật dữ liệu mới mà không cần cài lại app".

### 2.5. Cache có atomic persistence và last-known-good không?
- **Hiện trạng**: ĐÃ TRIỂN KHAI VỮNG CHẮC.
  - Cả hai repository đều tuân thủ quy trình: `Fetch Bytes → Validate Hash → Validate Schema → Persist SQLite Cache → Activate Snapshot → Notify Listeners`.
  - Nếu download lỗi, timeout hoặc hash không khớp, active snapshot (Last-Known-Good) được bảo tồn 100%. Không làm hỏng cache cũ và không rơi vào silent fallback.

### 2.6. ETag, SHA-256 và schema validation đã thực hiện ở mức nào?
- **SHA-256**: Đạt 100%. Mọi gói phát hành đều được so khớp hash SHA-256 cả ở manifest và body. Sai hash bị từ chối ngay lập tức (`VisitDataException('release_integrity')`).
- **Schema Validation**: Đạt 100%. Cả client và gateway đều có parser kiểm tra từng trường dữ liệu, khoảng giá trị kinh độ/vĩ độ, enum status.
- **ETag / Conditional GET**: CHƯA TRIỂN KHAI. Hiện client đang tải toàn bộ file `latest.json` (~1KB) để đọc version thay vì dùng HTTP `If-None-Match` / ETag. Cần bổ sung để tối ưu băng thông di động.

### 2.7. Backend quyết định thực sự là Python/FastAPI hay Java/Spring Boot?
- **Sự thật trong Codebase**: Thư mục `backend/` trong repository này là **Java 17 + Spring Boot 3.2.4** (quản lý bởi `backend/pom.xml`), bao gồm `HealthController` (`/api/v1/health`) và `MapController` (`/api/v1/maps/routes`).
- **Endpoint Planning**: Các hằng số `/plan-trip` và `/simulate-sensitivity` được khai báo trong `ApiConstants.dart`. Khi backend không phản hồi, `TripApiService` kích hoạt bộ sinh lịch trình ngoại tuyến thích ứng (`_generateOfflineFallbackResponse`) tuân thủ nghiêm ngặt Luật 3.
- **Đính chính tài liệu**: "Python/FastAPI" là kiến trúc của một hệ thống độc lập bên ngoài hoặc tài liệu thiết kế ban đầu. Runtime thực tế trong repo Mobile này chỉ tương tác với **Java/Spring Boot**, **Supabase Edge Functions**, và **Offline Fallback Engine**.

### 2.8. Flutter có logic ngân sách nào trùng quyền với Backend không?
- **Phân định ranh giới**:
  - `BudgetCalculator.calculate(doc)` trên Flutter chỉ tính toán dự toán cục bộ cho các hoạt động mà người dùng hoặc AI đã đưa vào bản nháp (`TripItem.costVnd`, `EstimatedExpense`, `actualExpenses`) nhằm hiển thị biểu đồ ngân sách. Đây là **Presentation / Provisional Ledger**, không vi phạm Luật 2.
  - Logic tính toán gói combo vé du lịch (`VisitPackage`) và bài toán tối ưu chi phí liên tuyến đã được **chủ động đánh dấu `NOT_IMPLEMENTED`** ở Mobile Client trong đợt T1 vừa qua để nhường quyền quyết định chính thức cho Backend Decision Engine.

### 2.9. AI Gateway có revalidate facts từ nguồn server trusted không?
- **Hiện trạng**: Gateway (`supabase/functions/itinerary-proposal/gateway.mjs`) kiểm tra schema JSON rất chặt chẽ (giới hạn 12 places, 48 windows, không cho phép thừa trường).
- **Hạn chế tin cậy (Trust Boundary Gap)**: Gateway hiện tin tưởng các ràng buộc `openingWindows` do Mobile Client gửi lên, chứ chưa tự truy vấn ngược lại database Supabase để xác minh xem Client có gửi sai giờ hay không. Ở môi trường production, cần xem xét Server-side Validation hoặc chữ ký điện tử trên facts.

### 2.10. Các tính năng nào chỉ có unit tests nhưng chưa có native/live evidence?
- 1.112 Flutter tests và 91 Node contract tests đã PASS tuyệt đối trong môi trường giả lập (Harness).
- **Các điểm CHƯA có Native/Live Evidence**:
  1. Gọi Gemini API trực tiếp với API Key thật trên môi trường Production (đang chạy qua mock/synthetic gateway an toàn).
  2. Đồng bộ tự động catalogue qua mạng thực tế trên thiết bị Android/iOS thật sau khi Admin nhấn Publish.
  3. Kiểm tra tính năng khi app bị hệ điều hành tiêu diệt (Process Death) rồi khôi phục lại khi đang mở trợ lý AI.
  4. Xác nhận vận hành trên thiết bị vật lý với mạng 3G/4G chập chờn.

---

## 3. Kết Luận & Khuyến Nghị Kiến Trúc Cho T2

| Thành phần | Hiện trạng | Hành động cho T2 |
| :--- | :---: | :--- |
| **Sync Coordinator** | `PARTIAL` | Xây dựng bộ điều phối duy nhất (`CatalogueSyncCoordinator`) hợp nhất `PublicCatalogueRepository` và `VisitDetailsRepository` thành một giao dịch chuyển đổi nguyên tử (Atomic Snapshot Switch). |
| **Operational Overrides** | `MISSING` | Bổ sung Layer B (`OperationalOverrides`: đóng cửa khẩn cấp, cảnh báo bão lũ) có độ ưu tiên cao hơn lịch trình định kỳ. |
| **Hybrid Search (T2.1)** | `MISSING` | Triển khai trước Lexical Search (tìm kiếm có dấu/không dấu, alias) cục bộ trên Snapshot hiện có; sau đó mới kết nối Semantic Search. |
| **Multi-Destination (T2.3)** | `PILOT_ONLY` | Hiện chỉ có Huế đạt mức L4 (Operational Ready); 11 điểm đến còn lại ở mức L1 (Discoverable) và cần tiếp tục bổ sung facts có nguồn kiểm duyệt. |

