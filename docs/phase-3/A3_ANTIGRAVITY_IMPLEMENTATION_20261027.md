# A3 — Bàn giao Antigravity, 27/10/2026

Đã hoàn thành toàn bộ gói **A3: Backend truy xuất Catalogue và đóng gói ngữ cảnh, biên nhận bằng chứng AI**. Hệ thống Gateway nay tự động kiểm tra tính toàn vẹn của Catalogue đã xuất bản (C7), lọc dữ liệu ngày/giờ/giá chính xác, và đóng gói căn cứ bằng chứng theo đúng chuẩn A1/A2. Đã khắc phục việc kẹt Quota khi kiểm tra lại yêu cầu cũ thông qua hàm SQL chỉ đọc `lookup_ai_request_v1`. Toàn bộ 1.238 bài test Flutter, 108 bài test Node.js và suite SQL cô lập đều đạt 100%.

**Kết luận: source/local automated verification PASS; A3 HOÀN TẤT trong môi trường kiểm thử local.** Sẵn sàng chuyển tiếp sang gói **S3 — A4 (AI tạo lịch trình có căn cứ trên bản trống)**.

Repo: `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`.

---

## 1. Changed (Danh sách file thay đổi & tạo mới)

| File | Loại | Vai trò & Ảnh hưởng |
| :--- | :--- | :--- |
| `supabase/functions/itinerary-proposal/catalogue-evidence.mjs` | Mới | Trình truy xuất Catalogue phía server: kiểm tra release, SHA-256 digest, ngày hiệu lực, giờ mở cửa theo mùa, giữ nguyên giá trị `unknown` |
| `supabase/functions/itinerary-proposal/catalogue-receipt.mjs` | Mới | Đóng gói biên nhận (Receipt), Claims và Registry căn cứ tương thích chuẩn A1/A2 |
| `supabase/functions/itinerary-proposal/gateway.mjs` | Sửa | Tích hợp dispatch hợp đồng evidence, gọi `lookup_ai_request_v1` chống trừ quota sai, chuyển `catalogueFacts` sang Gemini |
| `supabase/functions/itinerary-proposal/index.ts` | Sửa | Bổ sung cờ cấu hình `TRAVELGO_CATALOGUE_EVIDENCE_ENABLED` |
| `supabase/migrations/20261027071802_ai_request_read_lookup.sql` | Mới | Forward migration: hàm SQL chỉ đọc `lookup_ai_request_v1` để tra cứu yêu cầu mà không trừ quota |
| `supabase/tests/ai_request_lookup.sql` | Mới | Test SQL: bảo vệ hàm lookup chống giả mạo binding, phân quyền `service_role` |
| `supabase/tests/catalogue_evidence_receipt.sql` | Mới | Test SQL: kiểm tra receipt được ghi nhận và tương thích với trình xác thực A2 |
| `lib/features/trip_planner/models/ai_evidence_context.dart` | Mới | Dart Context: chắt lọc dữ liệu tối thiểu từ bản nháp + snapshot catalogue, loại bỏ thông tin riêng tư/nhạy cảm |
| `lib/features/trip_planner/services/ai_generation_service.dart` | Sửa | Request builder cho luồng tạo lịch trình bằng chứng |
| `lib/features/trip_planner/services/ai_assistant_service.dart` | Sửa | Request builder cho luồng tư vấn và đề xuất sửa hoạt động bằng chứng |
| `test/catalogue_evidence_resolver_test.mjs` | Mới | 8 test Node: kiểm tra phân tích giờ mùa đông/hè, lỗi hash, url giả mạo, ngày chưa kiểm chứng |
| `test/catalogue_receipt_test.mjs` | Mới | 5 test Node: kiểm tra cấu trúc receipt, claims dữ kiện, từ chối kết quả vượt kích thước |
| `test/catalogue_gateway_test.mjs` | Mới | 4 test Node: tích hợp gateway, replay không gọi Gemini, bảo vệ tài khoản |
| `test/ai_evidence_context_test.dart` | Mới | 4 test Dart: bảo vệ ngữ cảnh client, chặn sai lệch điểm đến, xuất fixture cho SQL test |
| `tool/a3-catalogue-bridge.mjs` | Mới | Cầu nối kiểm thử: kết nối Gateway giả lập với cơ sở dữ liệu PostgreSQL thực tế |
| `tool/verify-coursework-trips.ps1` | Sửa | Tích hợp suite kiểm tra A3 context, SQL bridge, và sửa cơ chế khởi động PostgreSQL trên Windows |
| `tool/verify-travelgo.ps1` | Sửa | Tích hợp 3 file test Node của A3 vào suite chạy tự động chế độ Full |

---

## 2. Why (Căn cứ kỹ thuật & Giải pháp)

1. **Tin cậy nguồn dữ liệu:** Thay vì tin tưởng dữ liệu giá tiền, giờ mở cửa do máy trạm (client) tự khai báo, Edge Function phía backend tự truy xuất bản Catalogue đã xuất bản (qua Storage/Manifest của C7), tự tính toán SHA-256 digest và chỉ gửi các dữ kiện đã kiểm chứng sang mô hình AI.
2. **Khắc phục kẹt Quota khi Replay:** Trước đây, hàm `reserve_ai_request_v1` vừa làm nhiệm vụ kiểm tra vừa ghi nhận lượt dùng. Khi người dùng bấm thử lại hoặc gửi lại một yêu cầu đã có, việc gọi `reserve` khiến hệ thống coi đó là một yêu cầu mới và trừ quota dù việc tải catalogue phía sau có thể thất bại. Hàm `lookup_ai_request_v1` chỉ đọc dữ liệu, giúp trả về ngay kết quả cũ nếu đã có mà không phát sinh thêm bản ghi chờ nào.
3. **Bảo mật dữ liệu cá nhân:** Lớp `AiEvidenceContext` phía Flutter đảm bảo chỉ xuất các thuộc tính thiết yếu (destinationId, số ngày, ngân sách) và loại bỏ hoàn toàn các trường ghi chú nội bộ, thông tin liên lạc hay token xác thực trước khi dữ liệu rời khỏi máy khách.

---

## 3. Testing (Bằng chứng kiểm thử thực tế)

| Lệnh thực thi | Kết quả | Bằng chứng chi tiết |
| :--- | :--- | :--- |
| `flutter analyze` | **No issues found!** (0 cảnh báo, 0 lỗi) | `.dart_tool/travelgo-verification/20261027T080111051Z-21768/analyze.log` |
| `flutter test` (Full suite) | **1238 / 1238 PASS** (100%) | `.dart_tool/travelgo-verification/20261027T080111051Z-21768/flutter-tests.log` |
| `node --test` (Contract suite) | **108 / 108 PASS** (100%) | `.dart_tool/travelgo-verification/20261027T080111051Z-21768/node-contracts.log` |
| `verify-coursework-trips.ps1 -SelfTest` | **PASS** (Bắt lỗi cố ý thành công) | `.dart_tool/coursework-trip-sql/ed76c693a77d4cddba2f8957e10e69d7` |
| `verify-coursework-trips.ps1` (Full SQL) | **PASS** (Tất cả migration + A3 SQL bridge) | `.dart_tool/coursework-trip-sql/64364f15323145ffb22f55b5a08e95a0` |

---

## 4. Problems (Rủi ro & Nợ kỹ thuật đã xử lý)

- **PowerShell 5.1 NativeCommandError trên Windows:** Việc `pg_ctl` và `psql` xuất các thông báo (NOTICES) sang luồng Standard Error bị Windows PowerShell 5.1 hiểu nhầm là lỗi dừng chương trình khi `$ErrorActionPreference = 'Stop'`. Đã xử lý triệt để trong `verify-coursework-trips.ps1` bằng cơ chế tạm chuyển `$ErrorActionPreference = 'Continue'` và kiểm tra mã thoát `$code = $LASTEXITCODE` như tiêu chuẩn của `verify-planner-core.ps1`.
- **Ranh giới chưa kết nối UI:** Gói A3 tập trung hoàn toàn vào tầng Backend/RPC/Context. Giao diện người dùng cho việc hiển thị nhãn bằng chứng và nút xác nhận áp dụng lịch trình sẽ thuộc phạm vi của gói tiếp theo (**A4**).

---

## 5. Lesson Candidate (Bài học kinh nghiệm)

- **Problem:** Sử dụng một RPC mang tính thay đổi trạng thái (như `reserve`) để kiểm tra dữ liệu dẫn tới tác dụng phụ ngoài ý muốn (trừ nhầm quota khi lỗi mạng).
- **Root Cause:** Thiếu một hàm truy vấn thuần túy (idempotent read-only query) trong tầng hợp đồng cơ sở dữ liệu.
- **Actionable Rule:** Khi thiết kế các cổng giao tiếp có giới hạn định mức (rate/quota limits), luôn tách biệt rõ ràng hàm kiểm tra đọc trạng thái (`lookup`/`query`) khỏi hàm ghi nhận trừ tài nguyên (`reserve`/`charge`).

