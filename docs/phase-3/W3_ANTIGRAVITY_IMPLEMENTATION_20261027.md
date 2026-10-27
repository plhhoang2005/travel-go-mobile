# W3 — Bàn giao Antigravity, 27/10/2026

Đã hoàn thành toàn bộ gói **S7 — W3: Đề xuất lịch trình Web có căn cứ (Web Proposal & External Activities)**. Người dùng có thể yêu cầu AI tạo lịch trình cho các điểm đến nằm ngoài danh mục hệ thống (ví dụ: Phú Yên, Côn Đảo...) bằng cách kết hợp Google Search Grounding. Hệ thống sinh kế hoạch cấu trúc với căn cứ web trích dẫn chuẩn xác, tạo các địa điểm ngoại lai (`externalPlaces`) gắn kết với từng hoạt động (`externalBindings`), tuyệt đối giữ `placeId: null` để bảo vệ Danh mục Admin (`discovery_places`). Mọi chi phí chưa xác minh được giữ nguyên `costVnd: null` (không giả lập 0 VNĐ miễn phí), hiển thị banner cảnh báo Internet minh bạch và hỗ trợ đầy đủ luồng xem trước (preview), hủy bỏ (giữ nguyên chuyến đi) và xác nhận.

**Kết luận: source/local automated verification PASS; W3 HOÀN TẤT trong môi trường kiểm thử local.** Sẵn sàng trình Owner nghiệm thu đồ án môn học và lập báo cáo tổng kết **S8 — W4 (Coursework Acceptance & Final Report)**.

Repo: `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`.

---

## 1. Changed (Danh sách file thay đổi & tạo mới)

| File | Loại | Vai trò & Ảnh hưởng |
| :--- | :--- | :--- |
| `supabase/functions/itinerary-proposal/gateway.mjs` | Sửa | Định nghĩa hợp đồng `travelgo.web.proposal.v1`, prompt Gemini với `google_search: {}`, phân tích JSON kế hoạch cấu trúc, chuẩn hóa Grounding thành `evidence`/`claims`, sinh `externalPlaces` và gắn cảnh báo Internet |
| `test/web_proposal_gateway_test.mjs` | Mới | 3 bài test hợp đồng Node.js: kiểm thử end-to-end `travelgo.web.proposal.v1`, từ chối khách vãng lai, kiểm tra sự hiện diện của `externalPlaces` và cờ cảnh báo Internet |
| `lib/features/trip_planner/services/ai_generation_service.dart` | Sửa | Thêm `externalPlaceName` vào `AiProposedActivity`, tạo public constructor cho `AiItineraryProposal`, hàm `prepareExternalAiProposal` bind `externalPlaces` & `externalBindings`, phương thức `generateAiWithWebProposal` giao tiếp Edge Function |
| `lib/features/trip_planner/models/ai_grounded_proposal.dart` | Sửa | Thêm `AiGroundedProposal.fromWebReceipt` để tiếp nhận kết quả `travelgo.web.proposal.v1`, ánh xạ `externalPlaces` và căn cứ web |
| `lib/features/trip_planner/presentation/widgets/ai_generation_preview.dart` | Sửa | Render banner cảnh báo Internet *"Thông tin từ Internet, chưa được Admin kiểm duyệt (N nguồn)"*, nút "Xem căn cứ" mở `EvidenceDetailsSheet`, giữ nguyên luồng Hủy / Áp dụng an toàn |
| `test/ai_external_trip_test.dart` | Mới | 3 bài test Flutter: kiểm thử binding `externalPlaces` với `placeId: null`, giá không rõ giữ `null` (không 0 VNĐ), render widget preview cảnh báo Internet và mở sheet căn cứ |
| `docs/phase-3/W3_ANTIGRAVITY_IMPLEMENTATION_20261027.md` | Mới | Báo cáo bàn giao chi tiết gói W3 theo chuẩn Stage-Gate |
| `docs/superpowers/plans/2026-10-27-team-owner.md` | Sửa | Đánh dấu hoàn thành S7 (W3), chuẩn bị chuyển sang S8 (W4) |
| `docs/superpowers/plans/2026-10-27-team-delivery-plan.md` | Sửa | Cập nhật tiến độ giao hàng tổng thể S7 $\rightarrow$ S8 |

---

## 2. Why (Căn cứ kỹ thuật & Giải pháp)

1. **Tuân thủ Law 1 (Quyền kiểm soát của người dùng & Preview/Cancel/Confirm):** Toàn bộ đề xuất từ Web search đều được đưa vào trạng thái xem trước (`AiGenerationPreview`). Người dùng có quyền xem xét từng hoạt động và căn cứ nguồn. Bấm "Hủy" sẽ đóng preview mà không làm thay đổi dù chỉ 1 byte trong tài liệu và mã băm digest. Chỉ khi người dùng bấm "Áp dụng", các hoạt động mới được tạo thành `TripItem` gắn vào chuyến đi.
2. **Tuân thủ Law 2 (Bảo vệ tuyệt đối Danh mục Admin - Ranh giới dữ liệu):** Các địa điểm tìm kiếm từ Google Web search tuyệt đối **KHÔNG** được ghi vào bảng `discovery_places` hay biến thành catalogue chính thức. Chúng được lưu dưới dạng `externalPlaces` và liên kết qua `externalBindings` trong phong bì bằng chứng `TripEvidenceEnvelope` của chuyến đi, với thuộc tính `placeId: null`. Danh mục Admin hoàn toàn bất khả xâm phạm.
3. **Tuân thủ Law 3 (Minh bạch dữ liệu & Chi phí thực tế):** Giá cả tìm thấy trên web không được giả định là miễn phí (0 VNĐ). Nếu không có giá xác minh, `costVnd` được giữ nguyên `null`. Giao diện hiển thị biểu ngữ cảnh báo rõ ràng: *"Thông tin từ Internet, chưa được Admin kiểm duyệt"*.
4. **Tuân thủ Law 4 (An toàn bất đồng bộ & Khôi phục trạng thái):** Đề xuất từ web được đóng gói độc lập trong `AiGroundedProposal`. Việc hủy preview hoặc lỗi mạng không gây mất dữ liệu hiện tại của chuyến đi.

---

## 3. Testing (Bằng chứng kiểm thử thực tế)

| Lệnh thực thi | Kết quả | Chi tiết |
| :--- | :--- | :--- |
| `node --test test/web_proposal_gateway_test.mjs` | **3 / 3 PASS** (100%) | Test hợp đồng `travelgo.web.proposal.v1`, từ chối khách vãng lai, tạo `externalPlaces`, banner cảnh báo |
| `node --test test/*_test.mjs` (Toàn bộ 11 test suites) | **192 / 192 PASS** (100%) | Đảm bảo tính toàn vẹn tuyệt đối của các Edge Functions backend |
| `flutter test test/ai_external_trip_test.dart` | **3 / 3 PASS** (100%) | Test binding `externalPlaces` với `placeId: null`, giá không rõ giữ `null`, render UI preview cảnh báo Internet |
| `flutter test` (Full batch AI & evidence test suites) | **102 / 102 PASS** (100%) | Kiểm thử toàn diện A1, A2, A3, A4, A5, W2 và W3 |
| `flutter analyze` | **No issues found!** (0 cảnh báo, 0 lỗi) | Tuân thủ toàn bộ quy tắc lint và tiêu chuẩn Dart |
| `verify-travelgo.ps1 -Mode Full` | **PASS** | Script xác minh toàn diện parity hệ thống |

---

## 4. Problems (Rủi ro & Nợ kỹ thuật đã xử lý)

- **UUID Format trong EditableTripCodec:** `EditableTripCodec._id` yêu cầu ID của `TripDay` phải tuân thủ nghiêm ngặt định dạng UUID 36 ký tự. Ban đầu test fixture dùng `'day-1'` dẫn đến `EditableCodecException(invalid_input, id)`. Đã chuẩn hóa test fixture sử dụng định dạng UUID RFC 4122 chuẩn (`00000000-0000-4000-8000-000000000001`).
- **Xác thực Schema cho Activities Ngoại lai:** `validateProposal` trong `gateway.mjs` trước đây chỉ cho phép các trường activity cố định. Đã bổ sung trường tùy chọn `externalPlaceName` để cho phép các hoạt động trích xuất từ web lưu trữ tên địa điểm ngoại lai mà không vi phạm schema hợp đồng.

---

## 5. Lesson Candidate (Bài học kinh nghiệm)

- **Problem:** Khi tích hợp dữ liệu bên ngoài từ AI Web Grounding vào một ứng dụng có danh mục địa điểm chính quy (Curated Admin Catalogue), việc tự động chèn địa điểm mới vào danh mục hệ thống có thể làm ô nhiễm dữ liệu, phát sinh rác hoặc thông tin sai lệch do AI sinh ra.
- **Root Cause:** Dữ liệu web có tính bất định cao (dynamic/unverified), trong khi Admin Catalogue yêu cầu tính chuẩn xác, toàn vẹn và có sự kiểm duyệt của quản trị viên.
- **Actionable Rule:** Tách bạch dữ liệu thành 2 ranh giới: Dữ liệu chính quy (`placeId` trỏ về Admin Catalogue) và Dữ liệu ngoại lai (`placeId: null`, lưu tạm trong `externalPlaces` theo phong bì bằng chứng của chuyến đi người dùng). Điều này bảo vệ 100% Admin Catalogue khỏi việc bị ghi đè hay biến tướng dữ liệu ngoài ý muốn.

