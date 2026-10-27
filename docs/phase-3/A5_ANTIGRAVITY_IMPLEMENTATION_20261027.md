# A5 — Bàn giao Antigravity, 27/10/2026

Đã hoàn thành toàn bộ gói **A5: Trợ lý AI tư vấn và sửa hoạt động có căn cứ (AI Assistant Advice & Modify with Evidence)**. Trợ lý AI nay hỗ trợ hai chế độ chính:
1. **Tư vấn (Advice / Recommendations):** Phân tích và đưa ra giải thích/gợi ý theo ngày hoặc toàn bộ chuyến đi kèm căn cứ dữ liệu minh bạch từ Catalogue xuất bản. Tuyệt đối **không sinh lệnh thay đổi (operations rỗng)**, không tự động sửa lịch trình của người dùng.
2. **Sửa hoạt động (Modify):** Đề xuất chỉnh sửa lịch trên một ngày cụ thể (`scope: 'day'`). Giao diện Diff Preview hiển thị so sánh trước/sau, nhãn đối chiếu Catalogue và nút "Xem căn cứ" mở Bottom Sheet minh bạch nguồn gốc dữ liệu. Khi người dùng bấm **Áp dụng**, hệ thống cập nhật lịch trình và tích hợp phong bì bằng chứng (`TripEvidenceEnvelope`), bảo toàn tuyệt đối 100% các ghi chú cá nhân (`notes`) và sổ chi tiêu thực tế (`actualExpenses`). Toàn bộ 1.249 bài test Flutter, 108 bài test Node.js và suite SQL cô lập đều đạt 100%.

**Kết luận: source/local automated verification PASS; A5 HOÀN TẤT trong môi trường kiểm thử local.** Sẵn sàng chuyển tiếp sang gói **S5 — W1 (Kiểm tra tương thích tìm kiếm Web / Google Search Grounding Compatibility)**.

Repo: `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`.

---

## 1. Changed (Danh sách file thay đổi & tạo mới)

| File | Loại | Vai trò & Ảnh hưởng |
| :--- | :--- | :--- |
| `lib/features/trip_planner/models/ai_grounded_assistant.dart` | Mới | Lớp Model kết nối `AiAssistantResult`, `AiModificationPreview` và `TripEvidenceEnvelope` trích xuất từ biên nhận A3, hỗ trợ tự động bổ sung tham chiếu địa điểm từ bằng chứng |
| `lib/features/trip_planner/services/ai_assistant_service.dart` | Sửa | Bổ sung hàm `askAiWithEvidence`, hỗ trợ truyền `credential` an toàn, thêm getter `after` cho `AiModificationPreview`, và mở rộng `AiAssistantGenerator` |
| `lib/features/trip_planner/presentation/widgets/ai_assistant_preview.dart` | Sửa | Tích hợp nhãn đối chiếu Catalogue, nút "Xem căn cứ" liên kết với Bottom Sheet chi tiết bằng chứng, và trả về `AiGroundedAssistantReply` khi người dùng bấm Áp dụng |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | Sửa | Nối luồng gọi `askAiWithEvidence` khi có Catalogue snapshot, tự động áp dụng lệnh và thay thế `evidenceEnvelope` vào `ManualPlannerProvider` |
| `test/ai_assistant_evidence_test.dart` | Mới | Bộ 5 kiểm thử tự động toàn diện: advice rỗng operations và bảo toàn digest, modify bảo toàn ghi chú/khoản đã chi và cập nhật phong bì bằng chứng, provider lưu trữ và đọc lại phong bì, widget test xem trước & hủy, và bảo vệ workspace khỏi kết quả đến muộn |

---

## 2. Why (Căn cứ kỹ thuật & Giải pháp)

1. **Phân định rõ ràng giữa Tư vấn và Chỉnh sửa (Law 1 & Law 2):** Tư vấn (`advice`) chỉ đóng vai trò phân tích, cung cấp thông tin và giải thích. Hệ thống cưỡng chế `operations.isEmpty == true` để đảm bảo AI không bao giờ tự ý sửa đổi lịch trình của người dùng khi người dùng chỉ hỏi xin ý kiến.
2. **Bảo toàn tuyệt đối ghi chú và tài chính cá nhân (Law 3):** Khi thực hiện các thao tác sửa đổi (`modify`: thêm, sửa, xóa hoạt động), hàm mutator và preview giữ nguyên vẹn 100% trường `notes` nội bộ của người dùng và danh sách sổ chi tiêu thực tế (`actualExpenses`). AI không có quyền can thiệp vào các khoản chi đã diễn ra.
3. **Cập nhật bằng chứng nguyên tử (Atomic Evidence Integration):** Khi người dùng xác nhận đề xuất chỉnh sửa, các bản ghi bằng chứng (`evidence`) và dữ kiện kiểm chứng (`claims`) mới được hợp nhất (merge deduplicated) vào `TripEvidenceEnvelope` của chuyến đi, đảm bảo tính liên tục của nguồn gốc dữ liệu khi lưu trữ và tải lại qua A2.
4. **Bảo vệ Workspace Stale (Law 4):** Mọi kết quả AI trả về muộn khi người dùng đã chuyển ngày, chuyển tab hoặc đổi tài khoản đều bị hủy bỏ ngay lập tức, không cho phép áp dụng kết quả lỗi thời vào bản nháp hiện tại.

---

## 3. Testing (Bằng chứng kiểm thử thực tế)

| Lệnh thực thi | Kết quả | Bằng chứng chi tiết |
| :--- | :--- | :--- |
| `flutter analyze` | **No issues found!** (0 cảnh báo, 0 lỗi) | Chạy trong 3.6s |
| `flutter test test/ai_assistant_evidence_test.dart` | **5 / 5 PASS** (100%) | Chạy trong 1.5s |
| `flutter test test/ai_generation_evidence_test.dart` | **6 / 6 PASS** (100%) | Chạy trong 1.2s |
| `flutter test test/ai_assistant_test.dart test/ai_assistant_grounding_test.dart` | **42 / 42 PASS** (100%) | Đạt toàn bộ kiểm thử hồi quy trợ lý |
| `flutter test` (Full suite qua `verify-travelgo.ps1`) | **1249 / 1249 PASS** (100%) | Đạt 100% bài kiểm thử Flutter toàn hệ thống |
| `node --test` (Contract suite) | **108 / 108 PASS** (100%) | Đạt toàn bộ kiểm thử hợp đồng Gateway & Resolver |
| `verify-coursework-trips.ps1` (Full SQL suite) | **PASS** (100%) | Tất cả migrations, SQL suites và evidence contracts trên PostgreSQL cô lập |

---

## 4. Problems (Rủi ro & Nợ kỹ thuật đã xử lý)

- **Place Reference Bounds trong Assistant Context:** `AiAssistantResult.fromJson` kiểm tra nghiêm ngặt rằng mọi `placeId` trong đề xuất phải nằm trong danh sách `places` được định nghĩa trước của ngữ cảnh. Nếu một đề xuất AI trả về một địa điểm trong Catalogue mà ngữ cảnh client trước đó chưa nạp vào danh sách thu gọn 12 địa điểm, contract sẽ từ chối. Đã xử lý triệt để trong `AiGroundedAssistantReply.fromReceipt`: hệ thống tự động trích xuất các địa điểm có căn cứ từ mảng `evidence` của biên nhận để bổ sung vào ngữ cảnh xác thực, đảm bảo tính hợp lệ tuyệt đối.
- **Enumeration Constraints trong FieldProvenance:** Giá trị trường `quality` trong `FieldProvenance` của tài liệu được quy định chặt chẽ thuộc tập `{'user_provided', 'estimated', 'unknown'}`. Đã chuẩn hóa toàn bộ các test fixture tuân thủ đúng enum này.

---

## 5. Lesson Candidate (Bài học kinh nghiệm)

- **Problem:** Tách rời danh sách thực thể tham chiếu (places) giữa tầng giao diện máy trạm và tầng biên nhận máy chủ dẫn đến từ chối hợp lệ sai (false rejection).
- **Root Cause:** Phía client chỉ gửi danh sách địa điểm thu gọn (tối đa 12) để tiết kiệm token, nhưng đề xuất từ server có thể kích hoạt các địa điểm khác trong Catalogue đã được đối chiếu.
- **Actionable Rule:** Tầng phân giải biên nhận (`fromReceipt`) phía client phải có khả năng tự động đọc lại danh sách thực thể từ chính các bản ghi bằng chứng (`evidence`) đính kèm trong biên nhận để làm giàu ngữ cảnh trước khi xác thực đề xuất.

