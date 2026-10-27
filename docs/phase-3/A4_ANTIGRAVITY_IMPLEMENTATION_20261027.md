# A4 — Bàn giao Antigravity, 27/10/2026

Đã hoàn thành toàn bộ gói **A4: AI tạo lịch trình có căn cứ trên tài liệu trống (Whole-Trip Generation on Empty Document)**. Người dùng nay có thể sử dụng AI để tạo lịch trình khởi tạo ban đầu kèm đầy đủ bằng chứng đã đối chiếu từ Catalogue. Giao diện xem trước bổ sung nút "Xem căn cứ" mở Bottom Sheet minh bạch nguồn gốc dữ liệu. Quy tắc bảo vệ tài liệu được siết chặt: tính năng tạo toàn bộ chuyến đi chỉ kích hoạt khi tài liệu hoàn toàn trống, ngăn ngừa hoàn toàn rủi ro ghi đè lịch trình đang có. Khi người dùng bấm Áp dụng, các hoạt động và phong bì căn cứ dữ liệu (TripEvidenceEnvelope) được lưu trữ nguyên vẹn đồng bộ. Toàn bộ 1.244 bài test Flutter, 108 bài test Node.js và suite SQL cô lập đều đạt 100%.

**Kết luận: source/local automated verification PASS; A4 HOÀN TẤT trong môi trường kiểm thử local.** Sẵn sàng chuyển tiếp sang gói **S4 — A5 (AI Assistant tư vấn & đề xuất sửa đổi hoạt động có căn cứ)**.

Repo: `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`.

---

## 1. Changed (Danh sách file thay đổi & tạo mới)

| File | Loại | Vai trò & Ảnh hưởng |
| :--- | :--- | :--- |
| `lib/features/trip_planner/models/ai_grounded_proposal.dart` | Mới | Lớp Model kết nối proposal lịch trình và phong bì bằng chứng (`TripEvidenceEnvelope`), xử lý phân giải claims, evidence records và receipt A3 |
| `lib/features/trip_planner/services/ai_generation_service.dart` | Sửa | Bổ sung hàm cổng `canGenerateWholeTrip(doc) => doc.items.isEmpty`, hàm `generateAiWithEvidence`, hỗ trợ truyền `credential` linh hoạt và bắt lỗi xác thực Supabase an toàn |
| `lib/features/trip_planner/presentation/widgets/ai_generation_preview.dart` | Sửa | Tích hợp hiển thị nhãn đối chiếu Catalogue, nút bấm "Xem căn cứ" liên kết với Bottom Sheet chi tiết bằng chứng |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | Sửa | Ràng buộc điều kiện tài liệu trống trước khi mở AI generator, áp dụng đồng bộ `commands` cùng `replaceEvidence(envelope)` khi người dùng xác nhận |
| `test/ai_generation_evidence_test.dart` | Mới | Bộ 6 kiểm thử tự động toàn diện: chặn tài liệu có sẵn hoạt động, phân giải hợp đồng `travelgo.itinerary.evidence.v1`, duy trì nguồn sau khi đọc lại từ bộ lưu trữ, widget test xem trước & hủy, và bảo vệ workspace khỏi kết quả đến muộn |

---

## 2. Why (Căn cứ kỹ thuật & Giải pháp)

1. **Bảo vệ toàn vẹn lịch trình của người dùng (Law 1 & Law 4):** Lập kế hoạch cả chuyến đi bằng AI là thao tác sinh mới hoàn toàn. Để ngăn chặn việc người dùng vô tình làm mất các hoạt động thủ công đã nhập từ trước, hàm kiểm tra `canGenerateWholeTrip(document)` bắt buộc `document.items.isEmpty`. Nếu tài liệu đã có hoạt động, người dùng được định hướng sử dụng Trợ lý AI (A5) để thêm/sửa từng hoạt động thay vì sinh lại cả chuyến.
2. **Minh bạch căn cứ dữ liệu (Law 3):** Giao diện `AiGenerationPreview` không chỉ hiển thị các hoạt động được đề xuất mà còn phân biệt rõ ràng các đề xuất đã được đối chiếu với Catalogue xuất bản (hiển thị số nguồn bằng chứng và nút "Xem căn cứ"). Người dùng có thể nhấn để mở `showTripEvidence` kiểm tra chi tiết ngày kiểm chứng, nhà xuất bản, URL nguồn trước khi quyết định áp dụng.
3. **Áp dụng nguyên tử (Atomic Application):** Khi người dùng nhấn nút Áp dụng, hệ thống vừa gửi lệnh đưa các hoạt động và dự toán vào bản nháp (`dispatchAll`), vừa áp dụng phong bì căn cứ tương ứng vào tài liệu (`replaceEvidence`). Cả hai thành phần này được lưu trữ đồng bộ trong `ManualPlannerProvider` và duy trì qua các chu kỳ lưu trữ cục bộ/từ xa.

---

## 3. Testing (Bằng chứng kiểm thử thực tế)

| Lệnh thực thi | Kết quả | Bằng chứng chi tiết |
| :--- | :--- | :--- |
| `flutter analyze` | **No issues found!** (0 cảnh báo, 0 lỗi) | Chạy trong 3.7s |
| `flutter test test/ai_generation_evidence_test.dart` | **6 / 6 PASS** (100%) | Chạy trong 1.2s |
| `flutter test` (Full suite qua `verify-travelgo.ps1`) | **1244 / 1244 PASS** (100%) | Đạt toàn bộ test suites của Flutter |
| `node --test` (Contract suite) | **108 / 108 PASS** (100%) | Đạt toàn bộ kiểm thử hợp đồng Gateway & Resolver |
| `verify-coursework-trips.ps1` (Full SQL suite) | **PASS** (100%) | Tất cả migrations, SQL suites và evidence contracts trên PostgreSQL cô lập |

---

## 4. Problems (Rủi ro & Nợ kỹ thuật đã xử lý)

- **Uninitialized Supabase Client trong Unit Tests:** Hàm lấy thông tin xác thực mặc định `requestAiForDraft` trước đây truy cập trực tiếp `Supabase.instance.client.auth.currentSession` mà không có khối `try/catch`. Trong môi trường unit test (chưa gọi `Supabase.initialize`), thao tác này sinh ra ngoại lệ `AssertionError` và bị lớp ngoài bắt nhầm thành `outcome_pending`. Đã khắc phục bằng cách bao bọc `try/catch` an toàn ném `unauthorized` có kiểm soát, đồng thời bổ sung tham số tùy chọn `Future<String> Function()? credential` cho phép các bài test truyền token giả lập trực tiếp.
- **Hit-testing trong AlertDialog:** Kích thước mặc định của màn hình widget test (800x600) khiến nút bấm "Tạo đề xuất" bị đẩy xuống gần sát mép dưới khi có thêm các điều khoản chấp thuận. Đã bổ sung `ensureVisible` và tăng kích thước viewport trong widget test để đảm bảo mô phỏng thao tác người dùng chính xác.

---

## 5. Lesson Candidate (Bài học kinh nghiệm)

- **Problem:** Truy cập trực tiếp singleton toàn cục (như `Supabase.instance`) trong các hàm logic lõi gây vỡ luồng xử lý ngoại lệ trong môi trường kiểm thử cô lập.
- **Root Cause:** Phụ thuộc cứng vào trạng thái runtime của SDK thay vì tiêm phụ thuộc (Dependency Injection) hoặc cơ chế fallback an toàn.
- **Actionable Rule:** Mọi thao tác đọc session từ singleton hệ thống phải được bao bọc an toàn trong khối kiểm tra lỗi có kiểm soát, đồng thời hàm service phải luôn cung cấp cổng nạp thông tin xác thực (`credential` callback) để các bài test hoặc caller tùy biến có thể kiểm thử độc lập mà không cần khởi tạo toàn bộ SDK bên ngoài.

