# W2 — Bàn giao Antigravity, 27/10/2026

Đã hoàn thành toàn bộ gói **S6 — W2: Tư vấn Web Opt-in Có Nguồn Trích Dẫn (Opt-in Sourced Web Advice)**. Người dùng có thể bật tùy chọn tìm kiếm Web khi hỏi Trợ lý AI; hệ thống trích xuất thông tin Google Grounding kèm theo liên kết nguồn và đánh dấu đoạn trích bằng chỉ số UTF-8 byte offset chính xác (không bị lỗi tiếng Việt có dấu). Tất cả căn cứ web được gắn nhãn minh bạch *"Thông tin từ Internet, chưa được Admin kiểm duyệt"* với `origin: 'web'` và `reviewed: false`, chỉ tư vấn và không tự động thay đổi lịch trình. Toàn bộ các bài test Node.js và Flutter liên quan đều đạt 100%.

**Kết luận: source/local automated verification PASS; W2 HOÀN TẤT trong môi trường kiểm thử local.** Sẵn sàng trình Owner Stage-Gate chuyển tiếp sang gói **S7 — W3 (Đề xuất hoạt động web, preview/xác nhận và lưu căn cứ)**.

Repo: `D:/Travel-Go-Android/travel-go`, branch `codex/owner-a2-evidence-persistence`.

---

## 1. Changed (Danh sách file thay đổi & tạo mới)

| File | Loại | Vai trò & Ảnh hưởng |
| :--- | :--- | :--- |
| `supabase/functions/itinerary-proposal/web-evidence.mjs` | Mới | Chuẩn hóa `groundingMetadata` từ Gemini: xử lý UTF-8 byte offsets chống lệch ký tự tiếng Việt, kiểm tra URI HTTPS/HTTP an toàn, map thành `EvidenceRecord` (`origin: 'web'`) và `EvidenceClaim` |
| `test/web_evidence_test.mjs` | Mới | 7 bài test Node.js kiểm thử bộ chuẩn hóa Grounding, byte offsets, schema URL an toàn và từ chối khách ẩn danh |
| `supabase/functions/itinerary-proposal/gateway.mjs` | Sửa | Tích hợp hợp đồng `travelgo.web.advice.v1`, gọi Gemini với `tools: [{google_search: {}}]`, gắn căn cứ web vào kết quả |
| `lib/features/trip_planner/models/ai_web_advice.dart` | Mới | Models client `AiWebAdviceContext` (loại bỏ thông tin riêng tư/nhạy cảm) và `AiWebAdviceReply` (xác thực `evidence`, `claims`, `warnings`) |
| `lib/features/trip_planner/presentation/widgets/web_advice_sheet.dart` | Mới | Giao diện hiển thị phản hồi tư vấn Web kèm banner cảnh báo Internet nổi bật và nút "Xem căn cứ" mở `EvidenceDetailsSheet` |
| `lib/features/trip_planner/presentation/widgets/ai_assistant_preview.dart` | Sửa | Xuất khẩu `web_advice_sheet.dart` để tích hợp trong luồng Trợ lý AI |
| `lib/features/trip_planner/services/ai_assistant_service.dart` | Sửa | Phương thức `requestWebAdvice(...)` giao tiếp với Edge Function qua hợp đồng `travelgo.web.advice.v1` với cơ chế chống phản hồi muộn (`stale`) |
| `test/ai_web_advice_test.dart` | Mới | 5 bài test Dart: kiểm tra bảo mật dữ liệu riêng tư, parser claims/evidence, render banner cảnh báo Internet, mở sheet căn cứ, chống phản hồi muộn |
| `docs/phase-3/W2_ANTIGRAVITY_IMPLEMENTATION_20261027.md` | Mới | Báo cáo bàn giao chi tiết gói W2 theo đúng chuẩn Stage-Gate |
| `docs/superpowers/plans/2026-10-27-team-owner.md` | Sửa | Đánh dấu hoàn thành S6 (W2), chuẩn bị cho S7 (W3) |
| `docs/superpowers/plans/2026-10-27-team-delivery-plan.md` | Sửa | Cập nhật tiến độ giao hàng tổng thể |

---

## 2. Why (Căn cứ kỹ thuật & Giải pháp)

1. **Tuân thủ Law 1 (Chỉ tư vấn, không tự ý sửa đổi lịch trình):** Theo quyết định owner ngày 24/10/2026 và thiết kế AI đã chốt, gói W2 chỉ phục vụ giải đáp thắc mắc người dùng (`operations` luôn rỗng). Lịch trình và ngân sách của người dùng không bao giờ bị can thiệp tự động bởi các câu trả lời tư vấn.
2. **Tuân thủ Law 2 (Bảo vệ dữ liệu cá nhân & Tách bạch trách nhiệm):** `AiWebAdviceContext` chỉ trích xuất các thông tin chung của chuyến đi (tên điểm đến, số ngày, khoảng ngân sách tổng, sở thích). Tuyệt đối không gửi email, số điện thoại, ghi chú riêng tư (`notes`), chi tiêu thực tế (`actualExpenses`) hay tên các thành viên ra dịch vụ Google Search.
3. **Tuân thủ Law 3 (Minh bạch nguồn gốc & Xử lý UTF-8 byte offset tiếng Việt):** Dữ liệu trả về từ Gemini Search Grounding sử dụng vị trí chỉ mục byte UTF-8 trong chuỗi nhị phân Protobuf, không phải độ dài ký tự UTF-16 của JavaScript/Dart. Việc triển khai `sliceUtf8Bytes` giúp trích xuất chính xác đoạn văn bản có dấu (ví dụ: chữ 'ạ' chiếm 3 bytes) mà không làm rách ký tự hoặc lệch vị trí trích dẫn. Mọi nguồn tin đều được gắn cờ `origin: 'web'` và `reviewed: false` kèm cảnh báo trực quan cho người dùng.
4. **Tuân thủ Law 4 (Chống rò rỉ dữ liệu khi chuyển đổi ngữ cảnh):** Khi người dùng gửi câu hỏi tư vấn web, nếu người dùng đóng màn hình, chuyển sang chuyến đi khác hoặc đăng xuất trước khi nhận phản hồi, kiểm tra `workspaceCurrent()` sẽ ngay lập tức hủy bỏ kết quả muộn và ném lỗi `stale`, đảm bảo không hiển thị thông tin sai ngữ cảnh.

---

## 3. Testing (Bằng chứng kiểm thử thực tế)

| Lệnh thực thi | Kết quả | Chi tiết |
| :--- | :--- | :--- |
| `node --test test/web_evidence_test.mjs` | **7 / 7 PASS** (100%) | Kiểm tra trích xuất Google Grounding, UTF-8 byte offset tiếng Việt, URL an toàn, lọc chunk index, từ chối khách ẩn danh |
| `node --test` (Toàn bộ 6 file Node contracts) | **41 / 41 PASS** (100%) | Đảm bảo tính toàn vẹn của cả hệ thống Edge Functions (Admin publication, Catalogue evidence, Web advice) |
| `flutter analyze` | **No issues found!** (0 cảnh báo, 0 lỗi) | Đạt chuẩn linting và quy tắc Dart |
| `flutter test test/ai_web_advice_test.dart` | **5 / 5 PASS** (100%) | Test context builder bảo mật, parser reply, render widget cảnh báo Internet, nút xem căn cứ, guard stale response |
| `flutter test` (Full batch evidence & advice) | **99 / 99 PASS** (100%) | Test tích hợp A1, A2, A3, A4, A5 và W2 |
| `verify-travelgo.ps1 -Mode Full` | **PASS** | Kiểm tra toàn bộ codebase |

---

## 4. Problems (Rủi ro & Nợ kỹ thuật đã xử lý)

- **Lệch ký tự tiếng Việt do UTF-8 Byte Offset:** Trong Protobuf API của Google Gemini, `groundingSupports.segment` trả về `startIndex` và `endIndex` tính bằng số byte UTF-8. Nếu dùng trực tiếp `String.substring` trong Dart hoặc JS, các từ tiếng Việt như *"Đà Lạt"*, *"Hồ Chí Minh"* sẽ bị cắt đứt giữa chừng hoặc lệch vị trí đánh dấu trích dẫn. Đã xử lý triệt để bằng hàm `sliceUtf8Bytes` cắt mảng `Uint8Array`/`Buffer` trước khi `TextDecoder('utf-8')`.
- **Ranh giới sang gói W3:** W2 hoàn thành trọn vẹn phần **Tư vấn (Advice)**. Việc chuyển đổi từ thông tin web thành đề xuất thêm hoạt động vào chuyến đi (`AiGroundedProposal`), kèm preview/hủy/xác nhận và lưu trữ căn cứ ngoài (`externalPlaces`, `externalBindings`) sẽ được thực hiện ở gói **W3**.

---

## 5. Lesson Candidate (Bài học kinh nghiệm)

- **Problem:** Sử dụng API Grounding của Google Gemini với văn bản tiếng Việt có nguy cơ gây lỗi ký tự (Malformed UTF-8 sequence) hoặc lệch vị trí bôi đen trích dẫn khi dùng hàm cắt chuỗi mặc định của ngôn ngữ lập trình.
- **Root Cause:** Gemini API quy định chỉ mục phân đoạn trích dẫn (`segment.startIndex`, `segment.endIndex`) theo UTF-8 byte offsets (chuỗi nhị phân), trong khi Dart và JavaScript xử lý chuỗi theo mã UTF-16 code units (mỗi ký tự tiếng Việt có dấu chiếm 2 đến 3 bytes UTF-8 nhưng chỉ là 1 code unit UTF-16).
- **Actionable Rule:** Khi làm việc với `groundingMetadata` từ Gemini API, luôn luôn chuyển văn bản sang mảng byte UTF-8 (`Buffer.from(text, 'utf-8')` trong Node.js hoặc `utf8.encode(text)` trong Dart), thực hiện cắt mảng byte (sublist / subarray), sau đó mới giải mã ngược lại thành chuỗi UTF-8.

