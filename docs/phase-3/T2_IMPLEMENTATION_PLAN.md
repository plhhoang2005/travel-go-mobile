# T2 Implementation Plan — Scalable Retrieval & Production Readiness

- **Dự án**: TravelGO Mobile (Flutter Client)
- **Tài liệu**: `docs/phase-3/T2_IMPLEMENTATION_PLAN.md`
- **Giai đoạn**: Phase 3 (RAG T2 & T3)
- **Ngày lập**: 24/10/2026
- **Chiến lược thực hiện**: Chia nhỏ thành các **Implementation Packets (P0 → P8)** độc lập, có ranh giới file chặt chẽ, kiểm thử tự động riêng biệt, không triển khai một khối thay đổi khổng lồ.

---

## 1. Bản Đồ Phân Chia Implementation Packets (P0 → P8)

```
[P0: Architecture & Authority Audit]  <── (Hoàn thành)
               │
               ▼
[P1: Catalogue Snapshot Consistency]  <── (Trọng tâm triển khai đầu tiên)
               │
               ▼
[P2: Sync, Cache & Publication Hardening]
               │
               ▼
[P3: Safety Overrides (Layer B)]
               │
               ▼
[P4: Lexical Retrieval (T2.1a)]
               │
               ▼
[P5: Hybrid Semantic Retrieval (T2.1b)]
               │
               ▼
[P6: Destination Expansion (T2.3)]
               │
               ▼
[P7: Monitoring, Security & Quota (T3)]
               │
               ▼
[P8: Native Acceptance & Release Readiness (T3)]
```

---

## 2. Chi Tiết Từng Implementation Packet

### 🔹 Packet P0: T2.0 Architecture & Authority Audit
- **Mục tiêu**: Kiểm toán mã nguồn thực tế, làm rõ ranh giới thẩm quyền quyết định, rà soát 10 câu hỏi cốt lõi và lập kế hoạch chi tiết.
- **Phạm vi Files**:
  - `docs/phase-3/T2_ARCHITECTURE_AUDIT.md`
  - `docs/phase-3/T2_DECISION_AUTHORITY_MATRIX.md`
  - `docs/phase-3/T2_IMPLEMENTATION_PLAN.md`
  - `docs/phase-3/T2_RISK_AND_GAP_REGISTER.md`
- **Tiêu chuẩn hoàn thành**: Tài liệu hoàn chỉnh, không sửa đổi code logic hiện có, không phá vỡ T1 baseline.

---

### 🔹 Packet P1: T2.2 Catalogue Snapshot Consistency
- **Mục tiêu**: Hợp nhất hai luồng đọc danh mục độc lập (`PublicCatalogueRepository` và `VisitDetailsRepository`) thành một điểm điều phối duy nhất `CatalogueSyncCoordinator`, bảo đảm tính chuyển đổi nguyên tử (Atomic Snapshot Switch) — metadata địa điểm và facts giờ/giá luôn cùng phiên bản `version`.
- **Phạm vi Files**:
  - `lib/features/explore/services/catalogue_sync_coordinator.dart` (New File).
  - `lib/features/explore/models/unified_catalogue_snapshot.dart` (New File).
  - `lib/main.dart` (Tích hợp coordinator an toàn, tương thích ngược).
  - `test/catalogue_sync_coordinator_test.dart` (New Test Suite).
- **Tiêu chuẩn hoàn thành**:
  - 100% test cases mới PASS (tối thiểu 8 test cases kiểm tra atomic switch, version sync, rollback, interrupted fetch).
  - Bảo toàn 1.112 Flutter tests cũ PASS.
  - `flutter analyze` 0 issues.

---

### 🔹 Packet P2: T2.2 Sync, Cache & Publication Hardening
- **Mục tiêu**: Nâng cấp cơ chế đồng bộ danh mục: bổ sung ETag / Conditional GET, bảo vệ chống downgrade attack khi có rollback hợp lệ từ Admin, cơ chế chống xung đột concurrent refresh (Single-Flight Token).
- **Phạm vi Files**:
  - `lib/features/explore/services/public_catalogue_repository.dart`
  - `lib/features/explore/services/place_visit_details_repository.dart`
  - `test/catalogue_cache_hardening_test.dart`
- **Tiêu chuẩn hoàn thành**:
  - Interrupted download không phá hỏng Last-Known-Good cache.
  - Corrupted SHA-256 bị từ chối nguyên tử.
  - Rollback manifest từ Admin được tiếp nhận an toàn qua `monotonic activation sequence`.

---

### 🔹 Packet P3: T2.2 Safety Overrides (Layer B)
- **Mục tiêu**: Triển khai tầng dữ liệu ghi đè ngắn hạn (Operational Overrides) cho các trường hợp khẩn cấp: bão lũ, sự kiện đóng cửa đột xuất, sửa chữa công trình. Layer B có quyền ưu tiên cao hơn Layer A (Lịch định kỳ) và tự động hết hạn khi tới `expiresAt`.
- **Phạm vi Files**:
  - `lib/features/explore/models/operational_override.dart` (New File).
  - `lib/features/trip_planner/models/ai_context_grounding.dart` (Tích hợp override resolver).
  - `test/safety_override_grounding_test.dart` (New Test Suite).
- **Tiêu chuẩn hoàn thành**:
  - Một địa điểm có lịch mở cửa bình thường nhưng có `OperationalOverride(status: 'emergency_closed')` thì RAG lập tức coi là `closed` và chặn đề xuất.
  - Khi override hết hạn (`now > expiresAt`), hệ thống không tự ý coi là `open` nếu thiếu bằng chứng mới.

---

### 🔹 Packet P4: T2.1a Lexical Retrieval Engine
- **Mục tiêu**: Xây dựng bộ tìm kiếm từ vựng (Lexical Search) tốc độ cao ngay trên Mobile Client dựa trên snapshot đã xác thực, hỗ trợ: tìm kiếm có dấu/không dấu, bí danh (aliases), lọc theo điểm đến và danh mục, hoạt động 100% ngoại tuyến (Offline-First).
- **Phạm vi Files**:
  - `lib/features/explore/services/lexical_retrieval_engine.dart` (New File).
  - `test/lexical_retrieval_test.dart` (New Test Suite).
- **Tiêu chuẩn hoàn thành**:
  - Đạt Recall@5 $\ge 95\%$ trên bộ kiểm thử tên địa danh tiếng Việt (viết hoa/thường, có dấu/không dấu, gõ tắt).
  - Không bao giờ trả về ID địa điểm không tồn tại trong snapshot đã publish.

---

### 🔹 Packet P5: T2.1b Hybrid Semantic Retrieval
- **Mục tiêu**: Đánh giá và tích hợp Semantic Search sử dụng `pgvector` trên Supabase (khi có kết nối mạng), kết hợp xếp hạng lai (Reciprocal Rank Fusion - RRF) giữa Lexical Score và Semantic Similarity.
- **Ranh giới**: Embeddings chỉ dùng để tìm địa điểm liên quan; **tuyệt đối không dùng embeddings để suy đoán giá vé hay giờ mở cửa** (vẫn dùng Fact-Check tất định từ T1/P3).
- **Phạm vi Files**:
  - `supabase/functions/itinerary-proposal/retrieval.mjs`
  - `lib/features/trip_planner/services/hybrid_retrieval_service.dart`
  - `test/hybrid_retrieval_test.dart`

---

### 🔹 Packet P6: T2.3 Multi-Destination Expansion
- **Mục tiêu**: Mở rộng độ phủ RAG từ Pilot Huế sang 11 điểm đến còn lại (Đà Nẵng, Hà Nội, Hội An, Phú Quốc...). Áp dụng thang đo sẵn sàng 5 cấp độ (L0: Named $\rightarrow$ L4: Operational Ready).
- **Phạm vi Files**:
  - `assets/catalogue/place_visit_details_v1.json`
  - `assets/catalogue/catalogue_readiness_v1.json`
  - `test/multi_destination_grounding_test.dart`

---

### 🔹 Packet P7: T3 Monitoring, Security & Quota Guard
- **Mục tiêu**: Giám sát độ trễ p50/p95/p99 của AI, cơ chế bảo vệ Quota, chống Prompt Injection qua retrieved facts, và bảo đảm an toàn dữ liệu cá nhân.
- **Phạm vi Files**:
  - `lib/core/telemetry/ai_telemetry_service.dart`
  - `supabase/functions/itinerary-proposal/gateway.mjs`
  - `test/ai_security_and_quota_test.dart`

---

### 🔹 Packet P8: T3 Native Acceptance & Release Readiness
- **Mục tiêu**: Ma trận kiểm thử Native End-to-End trên thiết bị thật (Android APK / iOS IPA): Admin publish $\rightarrow$ App cập nhật; App offline $\rightarrow$ online; Process death khôi phục; Bản nháp bảo toàn chi phí thực tế. Chuẩn bị Checklist phát hành chính thức.
- **Phạm vi Files**:
  - `docs/phase-3/T3_PRODUCTION_READINESS_CHECKLIST.md`
  - `docs/phase-3/T3_NATIVE_ACCEPTANCE_MATRIX.md`

---

## 3. Kế Hoạch Bắt Đầu Ngay (Immediate Execution)

Theo chỉ đạo của Master Prompt, sau khi hoàn thành Packet **P0**, chúng ta sẽ tiến hành triển khai ngay Packet **P1 (Catalogue Snapshot Consistency)** trong phạm vi tối thiểu, tương thích ngược, không phá vỡ T1 baseline và viết test kiểm chứng đầy đủ.

