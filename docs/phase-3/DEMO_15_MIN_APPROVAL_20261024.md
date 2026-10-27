# Kịch bản demo TravelGO 15 phút — chờ owner duyệt

Trạng thái: DRAFT / CHƯA CHẠY THỬ THEO KỊCH BẢN.
Source tham chiếu: `f8085a57305fc96a641db56f7f9a0b8b2318832c`,
nhánh `codex/phase-3-discovery-design`.
Đã đối chiếu màn hình và luồng trong source; chưa xác minh trên APK hiện tại.
Không sử dụng Superpowers cho task này.

## 1. Mục tiêu và dữ liệu demo

Câu chuyện: một nhóm hai người muốn đi Đà Lạt ba ngày, cần chọn phương án,
hiểu chi phí, chỉnh lịch, xem bản đồ và lưu lại để dùng tiếp.

- Nơi xuất phát: TP. Hồ Chí Minh; điểm đến: Đà Lạt từ danh mục hiện hành.
- Thời lượng: 3 ngày; số người: 2; ngân sách toàn chuyến: 4.000.000 VND.
- Sở thích: ẩm thực, nghỉ dưỡng; dùng đúng lựa chọn có trong UI.
- Tên bản tự lập: `DEMO15_DALAT_<thời điểm chạy>` để phân biệt dữ liệu thử.
- Một khoản dự kiến riêng: 100.000 VND, tính một lần cho cả chuyến.
- Một khoản đã chi riêng: 50.000 VND, tính một lần cho cả chuyến.
- Khách hàng và quản trị viên: tài khoản thử được owner cho phép sử dụng;
  không đưa email/mật khẩu/token vào kịch bản hoặc báo cáo.

Đà Lạt hoặc AI không khả dụng trong môi trường đang chạy phải được ghi nhận;
không tự thay điểm đến, giả kết quả hoặc đánh dấu luồng đó PASS.

## 2. Chuẩn bị trước giờ trình bày

Các việc này không tính vào 15 phút:

1. Chọn thiết bị/emulator sẽ demo. Đối chiếu bản ứng dụng với source nêu trên;
   APK cũ hoặc không xác định được phiên bản phải ghi rõ giới hạn.
2. Chuẩn bị tài khoản thử khách hàng và quản trị viên, API đang phục vụ và mạng.
   Owner có thể tự đăng nhập nếu cần; thiếu quyền truy cập thì ghi BLOCKED.
3. Giữ nguyên dữ liệu hiện có, đặc biệt bản nháp chưa lưu. Chỉ tạo bản demo mới;
   không clear data, uninstall, reset thiết bị, sửa vai trò hoặc chỉnh server.
4. AI dùng cấu hình đang có, tối đa hai lần gửi: một tạo lịch, một tư vấn.
   Không deploy, đổi key/model/quota hoặc tự gửi lại nhiều lần để tìm kết quả đẹp.
5. Ghi trạng thái trước thử, thiết bị, phiên bản app, thời gian và API đang dùng;
   không lưu thông tin đăng nhập hay nội dung chuyến đi riêng của owner.

## 3. Kịch bản đúng 15 phút

| Mã / thời gian | Thao tác trình bày | Lời dẫn ngắn và điều kiện đạt |
| --- | --- | --- |
| D01 · 00:00–00:45 | Mở app và giới thiệu Trang chủ. | “TravelGO giúp chọn phương án và quản lý chuyến đi bằng lịch trình, chi phí và bản đồ.” Không crash hoặc mắc kẹt ở splash. |
| D02 · 00:45–01:45 | Đăng nhập tài khoản khách hàng thử. | “Tài khoản giúp lưu chuyến đi và sử dụng lại.” Vào được app, đúng tài khoản và không mang nhãn tài khoản minh họa. Không dùng quên mật khẩu. |
| D03 · 01:45–03:00 | Vào Khám phá, tìm Đà Lạt, mở chi tiết, xem một địa điểm và đưa điểm đến vào luồng lập chuyến đi. | “Danh mục cung cấp thông tin tham khảo; giá và giờ chưa xác minh được ghi rõ.” Đúng điểm đến, không tự hiện giá 0 khi thiếu giá; biết nguồn danh mục đang dùng. |
| D04 · 03:00–05:00 | Nhập thông tin nhóm ở mục 1; bấm Xem gợi ý. Trên báo cáo, chỉ phương án được chọn, biểu đồ phân bổ ngân sách và phần giải thích. | “Backend tính phương án; app trình bày kết quả để người dùng đánh giá.” Kết quả đúng điểm đến/số ngày/số người; biểu đồ và số tiền nhất quán. Nếu FALLBACK: nói rõ dữ liệu dự phòng và ghi luồng online chưa đạt. Không gọi đó là kết quả server thành công. |
| D05 · 05:00–06:00 | Từ kết quả mở bản đồ lịch trình; chọn một điểm và xem nội dung. | “Các địa điểm trong lịch được đặt lên bản đồ.” Vị trí thuộc đúng lịch trình, thao tác không crash. Thiếu đường đi/tiles phải có trạng thái trung thực; bản đồ rỗng không tính là đạt đầy đủ. Không demo radar nhóm. |
| D06 · 06:00–08:00 | Quay lại Lập chuyến đi → Tự lập lịch trình. Mở Trợ giúp AI, kiểm tra dữ liệu gửi và đồng ý. Tạo đề xuất, xem trước rồi xác nhận thêm vào bản nháp. Mở trợ lý theo ngày và hỏi “Ngày 1 nên ưu tiên hoạt động nào để hạn chế di chuyển?”. | “AI đề xuất; người dùng xem trước và quyết định áp dụng.” Trước xác nhận, lịch gốc chưa đổi; sau xác nhận, lịch có nội dung đúng điểm đến và số ngày. Tư vấn không tự sửa lịch. Nếu AI lỗi hoặc không có preview, ghi FAIL/BLOCKED tương ứng; vẫn thử phần tự lập bằng bản demo mới, không coi nhánh này là AI PASS. |
| D07 · 08:00–10:00 | Đặt tên bản demo. Sửa tên một hoạt động ngày 1; nếu chưa có thì thêm một hoạt động ở khung giờ trống. Vào Ngân sách, thêm khoản dự kiến 100.000 và khoản đã chi 50.000, mỗi khoản tính một lần cho toàn chuyến. | “Lịch có thể tự chỉnh; dự kiến và đã chi được quản lý riêng.” Sửa đúng hoạt động, không mất ngày khác; tổng dự kiến tăng đúng 100.000, tổng đã chi tăng đúng 50.000 so với trước thao tác. Không cộng khoản đã chi lần nữa vào dự kiến chỉ vì vừa nhập. |
| D08 · 10:00–11:30 | Xem trước lưu, xác nhận lưu lên cloud. Vào tab Chuyến đi, mở lại đúng bản vừa tạo. | “Chuyến đi được lưu để tiếp tục chỉnh sửa.” Có xác nhận thực, xuất hiện đúng một bản; tên, ba ngày, hai người, hoạt động đã sửa và hai khoản chi còn đúng. Chỉ lưu local không tính là cloud PASS. |
| D09 · 11:30–12:30 | Sau khi xác nhận đã lưu, đóng và mở lại app; vào Chuyến đi, mở bản demo. | “Đóng ứng dụng không làm mất chuyến đi đã lưu.” Khôi phục phiên hợp lệ hoặc yêu cầu đăng nhập rõ ràng; sau truy cập hợp lệ, dữ liệu còn đầy đủ. Nếu phải đăng nhập lại thì đánh giá lưu dữ liệu và khôi phục phiên riêng, không gộp thành PASS. |
| D10 · 12:30–14:00 | Trước khi rời khách hàng, kiểm tra không có mục Quản trị. Đăng xuất, đăng nhập tài khoản admin thử → Cá nhân → Quản trị; xem Tổng quan và Danh mục. | “Hệ thống tách quyền khách hàng và quản trị.” Khách hàng không thấy mục Quản trị; admin vào được màn quản trị với dữ liệu tải thực. Đây là kiểm tra UI và quyền truy cập thực tế, chưa thay thế audit bảo mật đầy đủ. Chỉ xem, không khóa user, chỉnh dữ liệu hay publish. |
| D11 · 14:00–15:00 | Tổng kết ba điểm: hỗ trợ chọn phương án, chỉnh lịch/chi phí, lưu và quản trị. Dùng thời gian còn lại làm phần dự phòng thao tác. | “Dữ liệu tham khảo và lỗi kết nối được hiển thị rõ; AI có bước người dùng xác nhận.” Nêu đúng những phần đã chạy thành công và phần chưa đạt. |

## 4. Cách Codex chạy thử sau khi owner duyệt

- Chạy theo D01–D11 trên UI thật của bản app xác định được. Test unit/widget đã
  PASS trước đây chỉ là bằng chứng bổ sung, không thay thế thao tác UI.
- Đồng hồ 15 phút đo phần trình bày; thời gian chuẩn bị, chờ owner đăng nhập và
  thu thập bằng chứng sau lỗi được ghi riêng. Ghi thời gian thực tế từng mục;
  vượt ngân sách thời gian là một vấn đề của kịch bản, dù chức năng chạy được.
- Mỗi yêu cầu mạng đợi tối đa 45 giây trong lịch demo. Đến hạn mà chưa có kết quả,
  ghi “không đáp ứng thời gian demo”; không suy ra server chắc chắn đã thất bại.
  Không gửi lại thao tác lưu đang chưa rõ kết quả; kiểm tra danh sách trước.
- Gặp lỗi: chụp bằng chứng phù hợp, ghi thao tác và trạng thái; chỉ tiếp tục bước
  độc lập có thể thực hiện an toàn. Bước phụ thuộc bị chặn phải ghi BLOCKED.
- Trạng thái gồm PASS, FAIL, BLOCKED (thiếu điều kiện hoặc bị bước trước chặn),
  NOT RUN (chưa chạy). Không dùng ảnh kết quả cũ để thay lần chạy hiện tại.
- Không tự sửa code, config hoặc dữ liệu khác để làm bài test xanh; không commit,
  push, deploy hoặc chạy migration trong đợt test này.

## 5. Báo cáo sau chạy thử

| Mã | Thao tác tái hiện | Mong đợi | Thực tế | Trạng thái | Ảnh/log | Thời gian | Ảnh hưởng demo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D01–D11 | Điền sau khi chạy | Theo mục 3 | Chưa kiểm chứng | NOT RUN | Chưa có | Chưa đo | Chưa kết luận |

Với mỗi lỗi, phân biệt: chặn demo / vẫn demo được nhưng cần nói rõ / ít ảnh hưởng.
Chỉ kết luận nguyên nhân khi có bằng chứng; tách lỗi app, điều kiện môi trường và
chậm thao tác. Kết luận cuối: demo được ngay / demo được nếu bỏ các mục nêu rõ /
chưa nên demo. Liệt kê các mục chưa chạy thay vì tuyên bố đã test toàn project.

## 6. Phạm vi và giới hạn

Không đưa đăng ký mới/OTP/email, recovery, radar nhóm, thanh toán hoặc thử tải vào
15 phút. Đăng ký mới phụ thuộc nhận email nên không dùng làm điều kiện đầu vào
của bài trình bày này; những phần này vẫn chưa được nghiệm thu bởi kịch bản.
Sáu findings recovery trong review R1 giữ nguyên trạng thái đang mở.

Trong lượt lập kịch bản: chỉ thêm tài liệu này, chưa chạy demo, chưa sửa ứng dụng.
Lý do chọn một chuyến đi xuyên suốt là để kiểm dữ liệu từ nhập → gợi ý → chỉnh →
lưu → mở lại; mở từng màn riêng lẻ không chứng minh được toàn luồng.
Chờ owner duyệt trước khi bắt đầu thử nghiệm trên thiết bị.
