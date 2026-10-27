# AI — review nghiệp vụ bổ sung ngày 24/10/2026

Source: `f8085a57305fc96a641db56f7f9a0b8b2318832c`, nhánh
`codex/phase-3-discovery-design`. Phạm vi: các vấn đề ngoài độ xác thực địa điểm,
giờ mở cửa, thời gian di chuyển và liên kết bản đồ đã giải thích trước đó.

## 1. Changed

Không sửa ứng dụng, test chính thức, server, cấu hình hoặc database.
Artifacts của reviewer: báo cáo này và probe tạm, Git-ignored tại
`.dart_tool/codex-ai-business-review/additional_business_probe_test.dart`.
Kịch bản demo vẫn chờ owner duyệt; chưa chạy demo UI hoặc gọi Gemini.

## 2. Why — luồng được kiểm tra

UI lấy thông tin bản nháp → tạo ngữ cảnh gửi AI → kiểm tra kết quả → chuyển thành
command thay đổi bản nháp → kiểm tra toàn bản nháp → xem trước → owner xác nhận.
Review tập trung vào dữ liệu bị bỏ khỏi ngữ cảnh và sự khác biệt giữa một đề xuất
hợp lệ về thời gian với việc áp dụng nó vào timeline/chi phí thực tế.

## 3. Testing

Chạy trên service/mutator/validator thật với fixture giả trong repo:

`dart.exe flutter_tools.snapshot test --no-pub --concurrency=1 --reporter=expanded .dart_tool/codex-ai-business-review/additional_business_probe_test.dart`

SDK dùng: `D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe` và
`D:/flutter/flutter/bin/cache/flutter_tools.snapshot`.

- Lần đầu: B1–B4, 4/4 assertions về hành vi hiện tại PASS, exit 0.
- Lần cuối: B1–B5, 5/5 PASS, exit 0. B5 bổ sung một tình huống mới, không sửa app.
- Đây là các probe xác nhận hành vi hiện tại, không phải năm bằng chứng AI đúng
  nghiệp vụ. Không gọi provider, không dùng dữ liệu/tài khoản thật.
- Không chạy lại toàn suite: source sản phẩm không đổi. Kết quả này không chứng
  minh phiên bản APK hay service đã deploy giống source được kiểm tra.

## 4. Problems

### AI-F01 [P2] Dời hoạt động hợp lệ bị chặn bởi thứ tự timeline cũ

Đã tái hiện B5: bản nháp có A lúc 09:00–10:00, B lúc 11:00–12:00. AI edit A thành
13:00–14:00. Parser chấp nhận vì không trùng giờ. `prepareAiModification` giữ
position A trước B, validator phát lỗi `time_order`, `canApply=false`.

Source: `ai_assistant_service.dart:472–506` và
`editable_trip_validator.dart:188–199`.
Ảnh hưởng: yêu cầu dời giờ bình thường không áp dụng được, dù có thứ tự B → A
hợp lệ. Không làm mất dữ liệu vì preview chặn. Cần xem lại thứ tự khi áp dụng
edit/add; không bỏ kiểm tra time_order. Đóng finding khi ca này áp dụng đúng B → A,
các kiểm tra trùng giờ và dữ liệu chi phí vẫn giữ.

### AI-G01 — Trợ lý không biết dự toán hiện có/ngân sách còn lại

Đã tái hiện B1: hai bản có cùng tổng ngân sách nhưng dự toán hiện có 100.000 và
900.000 tạo cùng nội dung gửi trợ lý. Đổi tổng ngân sách làm payload khác — ca đối
chứng xác nhận đúng nhánh. Digest local khác nhau nhưng không gửi số dư cho model.

Source: `ai_assistant_service.dart:85–135`.
Ảnh hưởng: lời khuyên cắt chi phí/đủ tiền không thể dựa vào số dư thật. Preview
phía app vẫn tính lại toàn dự toán và cảnh báo vượt; không khẳng định app không
kiểm ngân sách. Đây là giới hạn ngữ cảnh, cần đánh giá theo yêu cầu sản phẩm,
không tự kết luận phải gửi ledger riêng tư cho AI.

### AI-G02 — Đổi bản chất hoạt động nhưng dự toán cũ vẫn được giữ

Đã tái hiện B2: đổi tham quan thành bữa tối; amount, category, description và
provenance của dự toán tham quan giữ nguyên, vẫn được phép áp dụng. Preview có
câu “cần xem lại dự toán” — đây là chính sách có báo rõ, không phải sửa tiền âm thầm.

Source: `ai_assistant_service.dart:482–506`.
Ảnh hưởng: người dùng chỉ xác nhận sửa hoạt động có thể để chi phí/phân loại cũ
đi theo hoạt động mới. Đây là rủi ro cần xem lại dữ liệu, không nên tự cập nhật
giá theo AI chưa xác minh. Probe không giả lập thu tiền hoặc thay đổi ledger thật.

### AI-G03 — Tạo và xác nhận nhiều lần có thể cộng trùng lịch/chi phí

Đã tái hiện B3: đề xuất gồm hoạt động chưa có giờ, chi phí 200.000. Sau hai lần
tạo/xác nhận riêng, có hai hoạt động giống tên và tổng dự kiến tăng 400.000.
Cả hai preview cho phép áp dụng. Không phải kiểm tra double tap hay request retry.

Source: `ai_generation_service.dart:242–299`.
Ảnh hưởng: chức năng là append vào lịch hiện có, UI đã nói “thêm vào bản nháp”;
không thay thế hay khử trùng nội dung. Nếu kỳ vọng bấm tạo lại sẽ đổi phương án,
người dùng có thể cộng trùng. Hoạt động có giờ trùng có thể bị validator chặn;
không khái quát rằng mọi lần tạo lại đều bị trùng.

### AI-G04 — AI tạo lịch chưa sử dụng một số thông tin đã chọn

Đã tái hiện B4: đổi ưu tiên cheapest/fastest tạo cùng payload gửi AI tạo lịch.
Không có lịch hiện tại, ngày cụ thể; originRegion luôn unknown. Đây là luồng
generate; trợ lý theo ngày có gửi date/priority nên không gộp hai luồng.

Source: `ai_generation_service.dart:49–115`.
Ảnh hưởng: chưa có căn cứ để nói AI tạo lịch đã cá nhân hóa theo ưu tiên đó,
nơi xuất phát hoặc ngày đi cụ thể. Không khẳng định model luôn trả cùng kết quả:
probe chỉ xác nhận input tới model không đổi theo lựa chọn này.

Ưu tiên: AI-F01 là lỗi chức năng tái hiện rõ, có thể ảnh hưởng demo chỉnh giờ.
AI-G01–G04 là các giới hạn/chính sách và rủi ro nghiệp vụ; không nên biến cả bốn
thành gói bắt buộc sửa khi chưa thống nhất kỳ vọng. Không đóng hay sửa findings
recovery cũ trong review AI này.

## 5. Lesson Candidate

- Problem: lịch không trùng giờ vẫn không áp dụng được → Root cause: AI edit đổi
  giờ nhưng chưa đổi thứ tự item → Rule: kiểm tính đúng cả đề xuất lẫn document
  sau khi chuyển thành command, dùng ca dời hoạt động vượt qua vị trí hoạt động khác.
- Problem: lời khuyên ngân sách thiếu căn cứ → Root cause: model không nhận số
  dư/dự toán → Rule: kiểm thông tin thực sự gửi đi trước khi hứa cá nhân hóa;
  nhãn cảnh báo và preview không thay thế dữ liệu đầu vào còn thiếu.
