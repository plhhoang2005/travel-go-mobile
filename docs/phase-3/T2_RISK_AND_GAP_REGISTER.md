# T2 Risk & Gap Register — TravelGO Decision Intelligence

- **Dự án**: TravelGO Mobile
- **Tài liệu**: `docs/phase-3/T2_RISK_AND_GAP_REGISTER.md`
- **Giai đoạn**: Phase 3 (RAG T2 & T3)
- **Ngày lập**: 24/10/2026
- **Auditor**: Principal Software Engineer & Chief AI Architect (Antigravity)

---

## 1. Bảng Đăng Ký Rủi Ro & Khoảng Trống Kỹ Thuật (Risk & Gap Register)

| ID | Khoảng Trống / Rủi Ro Kỹ Thuật | Mức Độ | Tác Động Tiềm Ẩn | Nguyên Nhân Gốc Rễ | Phương Án Giảm Thiểu (Mitigation) | Packet Xử Lý | Trạng Thái |
| :--- | :--- | :---: | :--- | :--- | :--- | :---: | :---: |
| **GAP-01** | **Bất đồng bộ giữa hai Repository danh mục** | **P1 (Critical)** | Metadata địa điểm (Public Catalogue) ở version mới nhưng facts vé/giờ (Visit Catalogue) ở version cũ nếu mạng lỗi giữa chừng. | Hai repository `PublicCatalogueRepository` và `VisitDetailsRepository` chạy luồng fetch độc lập. | Xây dựng `CatalogueSyncCoordinator` thực thi chuyển đổi nguyên tử (Atomic Switch). Cả 2 cùng lên version mới hoặc cùng giữ version cũ. | **P1** | **IN_PROGRESS** |
| **GAP-02** | **Thiếu cơ chế ghi đè khẩn cấp (Layer B Overrides)** | **P1 (Critical)** | Khi bão lũ hoặc di tích đột ngột đóng cửa khẩn cấp, RAG vẫn dùng lịch định kỳ (Layer A) và cho phép xếp lịch. | Mô hình dữ liệu hiện tại chỉ có lịch mở cửa định kỳ theo tuần/mùa, chưa có bảng ghi đè sự kiện vận hành ngắn hạn. | Thiết kế cấu trúc `OperationalOverride` với `status: emergency_closed`, `effectiveFrom`, `expiresAt`. Layer B có quyền ưu tiên cao hơn Layer A. | **P3** | **OPEN** |
| **GAP-03** | **Độ phủ dữ liệu thực tế 11 điểm đến ngoài Huế còn trống** | **P2 (High)** | 60/72 địa điểm thuộc 11 điểm đến khác chỉ có tên tham khảo mà chưa có giờ mở cửa/giá vé đã xác minh. | Đợt T1 mới hoàn thành kiểm chứng chi tiết cho Pilot Huế (12/72 POIs). | Áp dụng triệt để Luật 3: gán trạng thái `AvailabilityState.unknown`, hiển thị nhãn `[Chưa xác minh]`, không bịa số liệu. Triển khai mở rộng theo từng đợt L0 $\rightarrow$ L4. | **P6** | **MITIGATED_BY_LAW_3** |
| **GAP-04** | **Ranh giới tin cậy Client-to-Gateway (Trust Boundary)** | **P2 (High)** | Phía Client là untrusted, Gateway hiện chỉ kiểm tra schema JSON chứ chưa tự đối chiếu lại database để phát hiện nếu client sửa sai `openingWindows`. | Thiết kế ban đầu để giảm độ trễ (0 extra database round-trip). | Bổ sung Server-side Fact Verification hoặc ký hash trên facts trước khi gửi lên Gateway. | **P7** | **OPEN** |
| **GAP-05** | **Thiếu ETag / Conditional GET khi thăm dò Manifest** | **P3 (Medium)** | App tải toàn bộ `latest.json` trong mỗi chu kỳ kiểm tra, lãng phí băng thông di động khi dữ liệu không thay đổi. | Triển khai ban đầu dùng HTTP GET tiêu chuẩn không kèm header `If-None-Match`. | Bổ sung lưu trữ ETag trong SQLite cache và gửi kèm header `If-None-Match` để nhận mã `304 Not Modified`. | **P2** | **OPEN** |
| **GAP-06** | **Chưa có bằng chứng kiểm thử thực tế trên thiết bị thật (Native Evidence)** | **P2 (High)** | Nguy cơ crash tiềm ẩn khi app bị Android tiêu diệt ngầm (Process Death) hoặc lỗi render font chữ trên các màn hình nhỏ. | Bộ test hiện tại chủ yếu là unit/widget tests chạy trên máy ảo headless. | Thiết kế Acceptance Matrix kiểm thử trực tiếp trên thiết bị Android/iOS thật ở Packet P8. | **P8** | **OPEN** |
| **GAP-07** | **Package Combo Budget ở Mobile vi phạm Luật 2 nếu tự tính tiền** | **P1 (Critical)** | Tự ý tính toán combo vé ở Client sẽ làm sai lệch ngân sách và xung đột với thuật toán Pareto của Backend. | Schema seed thực tế (`pkg.included`) chứa nhãn text tiếng Việt thay vì stable ID. | Đã đánh dấu `NOT_IMPLEMENTED` ở Mobile Client (đợt T1). Đóng băng ranh giới và chuyển giao sang đợt Backend riêng. | **Arch Matrix** | **FROZEN_NOT_IMPLEMENTED** |

---

## 2. Kế Hoạch Theo Dõi & Giải Tỏa Rủi Ro (Burndown Strategy)

- **Ưu tiên số 1 (Ngay lập tức)**: Giải quyết **GAP-01** trong Packet **P1** để bảo vệ tính nhất quán của dữ liệu danh mục.
- **Ưu tiên số 2**: Giải quyết **GAP-05** trong Packet **P2** để tối ưu hóa hiệu năng đồng bộ.
- **Ưu tiên số 3**: Giải quyết **GAP-02** trong Packet **P3** để bảo vệ an toàn cho người dùng khi có sự cố thời tiết/đóng cửa đột xuất.

