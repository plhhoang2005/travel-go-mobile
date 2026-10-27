# TravelGO AI demo stability — design để owner duyệt

Status: PROPOSED / WAITING_OWNER_APPROVAL. Đây là tài liệu, chưa cấp quyền code.
Base: `f8085a57305fc96a641db56f7f9a0b8b2318832c`.

## Intent và phạm vi đã chọn

Owner chọn: “Ổn định demo: sửa áp dụng lịch, trùng hoạt động và dự toán cũ;
ghi backlog phần nâng cấp dữ liệu.” Codex lập plan, Antigravity triển khai qua
`agy`, Codex review độc lập. Một triển khai đầu tiên, tối đa hai vòng sửa sau review.
Không tự merge hoặc deploy. User sẽ duyệt plan trước khi bắt đầu code.

Luồng sản phẩm: bản nháp → đề xuất AI → kiểm tra và tạo commands → preview →
xác nhận → sửa bản nháp → người dùng lưu bằng luồng hiện có.

## Global constraints

- Giữ API, contracts, JSON document, database và cấu hình rollout hiện tại.
- Không thêm dependency, đổi model, native config, Auth/recovery hoặc Decision Engine.
- Không đổi số tiền, category, provenance hoặc chứng từ đã chi để làm đề xuất hợp lệ.
- Không nới overlap/time_order validation hoặc giảm assertions hiện có.
- Giữ preview/Cancel/Apply, owner/epoch/digest guards, request replay và quota.
- Giữ dữ liệu owner; không reset/clean/uninstall hoặc bỏ bản nháp chưa lưu.
- Không tự merge, push, deploy, chạy migration hoặc gọi AI live trong gói source này.

## S1 — Áp dụng chỉnh giờ đúng timeline

`prepareAiModification` phải trả commands có thể tái áp dụng lên input để tạo đúng
`preview.document`. Sau edit/add/remove, chuẩn hóa thứ tự trong ngày được chọn:
hoạt động biết giờ tăng theo startMinute, rồi endMinute; hòa thì giữ thứ tự candidate.
Hoạt động chưa rõ giờ đặt sau nhóm biết giờ, giữ thứ tự tương đối của chúng.
Chỉ reorder ngày được chọn, bằng `ReorderDayCommand` hiện có.

Ca bắt buộc: A 09:00–10:00, B 11:00–12:00; dời A 13:00–14:00 → B,A và canApply=true.
Thêm hoạt động 08:00–09:00 cũng phải vào vị trí đúng. Trùng giờ thật vẫn bị từ chối.
Input, các ngày khác, input chuyến đi, estimates và actual ledger không bị đổi
ngoài các thay đổi add/remove vốn được phép bởi contract.

## S2 — Chặn cộng trùng trong đề xuất tạo lịch

Khóa so sánh là bộ `(dayOrdinal, normalizedTitle, startMinute, endMinute)`.
normalizedTitle = trim, gộp mọi chuỗi whitespace thành một dấu cách, lowercase;
giữ dấu tiếng Việt. So sánh với hoạt động cũ cùng ngày và trong chính đề xuất.
Giờ null vẫn tham gia khóa. Cùng tên khác ngày hoặc khác giờ không tự coi là trùng.

Nếu có khóa trùng: toàn preview không được Apply, có issue chặn
`ai_duplicate_activity`; không áp dụng một phần hay âm thầm bỏ hoạt động.
Input và tổng tiền input giữ nguyên; không tạo thêm dự toán qua UI xác nhận.
UI hiện có hiển thị issues/canApply, dùng thông báo rõ hoạt động/ngày bị trùng.
Đây là chống trùng nội dung giữa các lần tạo/xác nhận riêng; giữ nguyên cơ chế
idempotency/retry cùng requestId đang có.

## S3 — Người dùng xác nhận việc giữ dự toán cũ

Chính sách chọn cho demo: giữ số tiền cũ, tăng rõ ràng bước người dùng rà soát.
Không tự đoán “giá mới”, không xóa tiền, không thêm marker vào mô tả/JSON để đổi schema.

Edit đổi normalizedTitle hoặc placeId của một activity đang có ít nhất một
estimate active liên kết → preview đánh dấu item đó cần rà soát dự toán.
Chỉ đổi giờ, notes hoặc thứ tự không kích hoạt yêu cầu này. Remove/add tiếp tục
theo chính sách tài chính hiện có. Không suy nghĩa từ văn bản bằng một lần gọi AI khác.

`AiModificationPreview` thêm immutable `estimateReviewItemIds` (optional named
constructor argument mặc định rỗng) và getter `requiresEstimateReview`.
UI hiển thị các hoạt động liên quan, dự toán cũ được giữ và checkbox:
“Tôi đã rà soát dự toán cũ của các hoạt động thay đổi.”
Khi cần rà soát, Apply chỉ bật sau tick và canApply=true. Nút Hủy luôn khả dụng.
Checkbox gắn với đúng kết quả preview, reset khi đổi kết quả/intent; không dùng
ACK của preview A để xác nhận preview B. Đây là xác nhận của người dùng, không
chứng nhận giá thực tế hoặc bổ sung trạng thái bền vững sau lưu.

## S4 — Evidence và giới hạn nghiệm thu

Source verified khi tests S1–S3, regression guards, analyze và full tests đều đạt
trên đúng candidate. Các probe cũ dùng để tái hiện; chuyển thành assertions mong
đợi đúng trong test chính thức, không giữ expected-bug rồi gọi là đã sửa.

Native/live chưa chạy phải ghi NOT RUN/BLOCKED. Không dùng green suite để tuyên bố
APK/mạng/đầu ra Gemini thực tế đã nghiệm thu. Demo 15 phút vẫn có gate duyệt riêng.

## Backlog đã đồng ý hoãn

Ngữ cảnh dự toán/số dư đầy đủ; ngày đi/nơi xuất phát/ưu tiên cho generate; ràng buộc
địa điểm và nối bản đồ; nguồn giá/giờ mở cửa/route facts; tính khả thi ngoài thực tế.
Sáu findings recovery cũ giữ nguyên. Không tuyên bố gói này xử lý các vấn đề đó.

## Workflow và stop conditions

Approval plan cho phép đúng S1–S3, các tests và local checkpoints trên nhánh riêng;
không cần xin lại từng task hoặc repair cùng scope. Phạm vi mới phải trình owner.
I0 → review R0 → repair I1/R1 nếu cần → repair I2/R2 nếu cần → dừng.
Lỗi cốt lõi/demo cần bằng chứng tái hiện; lỗi nhẹ ghi backlog. Đếm vòng sửa toàn
gói, không reset theo task, session hoặc model. Kết thúc ACCEPTED_SOURCE hoặc
BLOCKED/STOPPED_WITH_BLOCKERS; không cam kết luôn sửa đúng trong hai vòng.
