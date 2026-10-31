# TravelGO — phạm vi đồ án hiện hành

Owner chốt ngày 24/10/2026. Đây là nguồn quy định phạm vi sản phẩm cho Codex và Antigravity. Mục tiêu: ứng dụng di động có luồng hoàn chỉnh, đọc/ghi dữ liệu, xử lý lỗi, giao diện dùng được và AI tạo lịch, tư vấn, đề xuất sửa hoạt động. Owner đã cho phép cập nhật tài liệu; việc sửa này không tự triển khai hoặc xóa tính năng trong app, không cho phép deploy/DB mutation/merge.

**Thiết kế AI bắt buộc tham chiếu:** [ai-planner-design.md](ai-planner-design.md). Thống nhất tên Trợ lý lập lịch trình AI, Gemini qua backend + RAG catalogue đơn giản; catalogue thiếu thì người dùng chọn tìm Internet qua Google Search Grounding, có dẫn nguồn/nhãn chưa được Admin kiểm duyệt; kiểm tra bằng code; tạo lịch trên bản chưa có hoạt động, tư vấn và đề xuất sửa trên lịch hiện tại. Đây là thiết kế đích, chưa phải trạng thái implementation.

## 1. Chức năng phải giữ và hoàn thiện

| Nhóm | Phạm vi |
| --- | --- |
| Xác thực | Đăng nhập, đăng ký, OTP xác minh đăng ký, quên/đặt lại mật khẩu, đăng xuất. Dùng dịch vụ xác thực thật; không OTP/tài khoản giả. Không tạo thêm một luồng OTP độc lập nếu không cần. |
| Tài khoản | Xem/sửa thông tin cá nhân cơ bản; phân biệt customer và admin. |
| Khám phá | Danh sách, tìm kiếm, chi tiết điểm đến và địa điểm tham quan; đánh giá công khai theo từng địa điểm. Guest được đọc; tài khoản thật được gửi tối đa một đánh giá bất biến 1–5 sao cho mỗi địa điểm. Chưa có sửa/xóa đánh giá. |
| Tự lập lịch | Tạo chuyến đi, tên/điểm đến/ngày/số người; thêm/sửa/xóa hoạt động theo ngày, giờ và ghi chú. |
| Chuyến đi theo tài khoản | Lưu, danh sách, mở lại, sửa, xóa; giữ đúng hoạt động, ngày, số người và dữ liệu ngân sách sau khi mở lại. |
| Ngân sách | Nhập ngân sách; thêm/sửa/xóa khoản dự kiến và đã chi; tổng hợp, cảnh báo vượt. Biểu đồ đơn giản phục vụ ngân sách được giữ; không cần tối ưu toán học. |
| AI tạo lịch | Nhập yêu cầu → AI đề xuất → preview → hủy/xác nhận. Hủy không đổi lịch; xác nhận áp dụng vào trình chỉnh sửa thông thường; người dùng sửa thủ công rồi lưu. Không tự ghi đè chuyến đi đã lưu. |
| AI tư vấn và đề xuất sửa hoạt động | Tư vấn dựa trên ngữ cảnh chuyến đi/ngày hiện tại; đề xuất thêm/sửa/xóa hoạt động theo yêu cầu. Tư vấn không thay đổi lịch. Đề xuất sửa có preview thể hiện thay đổi → hủy giữ nguyên → xác nhận mới áp dụng vào bản chỉnh sửa. Kiểm giờ/thứ tự/trùng hoạt động, giữ ghi chú và khoản đã chi; cảnh báo dự toán cần xem lại, không âm thầm đổi tiền hoặc lưu lên server. |
| Admin người dùng/tài khoản | Xem/tìm người dùng, xem chi tiết, khóa/mở khóa. Quyền kiểm ở server. Không mở rộng thành bộ quản trị doanh nghiệp. |
| Admin địa điểm | Thêm/sửa/ẩn điểm đến và địa điểm, thông tin mô tả/giá/giờ/nguồn phù hợp. Dữ liệu cập nhật phải tới User ở lần tải/làm mới tiếp theo. Tái dùng cơ chế xuất bản hiện có nếu cần, tránh bắt người dùng thao tác quy trình kỹ thuật phức tạp. |

Các hoạt động từ web được xem trước/xác nhận rồi lưu vào chuyến đi cùng nguồn; không tự thêm vào catalogue Admin. Triển khai catalogue có dẫn chứng trước, tư vấn web sau, rồi mới áp dụng/lưu hoạt động web. Không có bằng chứng thì phải nói rõ giới hạn.

## 2. Loại khỏi phạm vi sản phẩm

- Toàn bộ bản đồ, GPS/định vị, chỉ đường, tối ưu tuyến, radar/chia sẻ vị trí nhóm; bỏ entry point và yêu cầu quyền chỉ phục vụ chúng khi triển khai cleanup.
- Chatbot tổng quát và AI tự động thực hiện thay đổi không qua xác nhận vẫn ngoài scope. AI tư vấn chuyến đi và đề xuất sửa hoạt động được giữ theo quyết định bổ sung của owner.
- Dashboard hỗ trợ quyết định, MCDA/Pareto, so sánh phương tiện, sensitivity/knapsack/greedy tối ưu; không còn bắt buộc endpoint Decision Engine để hoàn thành luồng chính.
- Yêu thích, voucher, thời tiết và tiện ích ngoài danh sách giữ lại.
- Guest lưu nháp rồi import vào tài khoản; offline sync nâng cao. State bản nháp trong trình chỉnh sửa và xử lý lỗi mạng để bảo vệ dữ liệu vẫn cần.
- Semantic search/pgvector, realtime phức tạp, A/B testing, monitoring p95/p99, roadmap mở rộng RAG/enterprise không phải mục tiêu đồ án.
- Không xóa auth guards, kiểm quyền, chống lẫn tài khoản, validation, cache cần thiết hoặc test bảo vệ chức năng giữ lại dưới danh nghĩa giảm scope.

## 3. Hiện trạng đã biết — không phải chứng nhận hoàn thành

Mốc đọc source: branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` trước thay đổi tài liệu này. Luôn kiểm lại HEAD khi tiếp tục.

- Đã có các module auth, profile, explore, trips, manual planner, budget, AI generation, AI assistant, admin; đồng thời còn map, favorites và dashboard cũ cần cleanup theo scope. AI assistant được giữ cho tư vấn/đề xuất sửa hoạt động, không xóa module này chỉ vì quyết định scope trước đó.
- Có bằng chứng lịch sử chạy một số ca manual/create/save/reopen/update trên điện thoại và AI preview/cancel/apply trên emulator. Không coi đó là nghiệm thu APK hiện tại.
- Checkpoint `docs/phase-3/DEMO_CHECKPOINT_20261024.md` ghi analyzer và suite PASS tại source cũ; demo đầy đủ trên thiết bị/dịch vụ thật chưa được chứng nhận.
- `docs/phase-3/CORE_REVIEW_R1_CODEX_REVIEW_20261024.md` còn sáu findings recovery chưa có evidence đóng trong lượt chốt scope. Quên mật khẩu nay thuộc scope bắt buộc: quyết định cũ loại recovery khỏi demo không thay thế việc sửa/nghiệm thu.
- Commit `93b0abf` có sửa AI reorder/duplicate/estimate, `c789c7a` và `3b9930e` có grounding, `c4c1af5` có catalogue sync. Không lặp lỗi cũ như finding hiện tại nếu chưa đối chiếu bản sửa; cũng không coi commit message là chứng nhận runtime.
- Giá/giờ chưa xác minh ở một số địa điểm phải hiển thị trung thực. Không bắt xác minh toàn bộ catalogue mới được demo một điểm đến có dữ liệu đủ.
- Admin → publication → User refresh, đăng ký/OTP/email, recovery và phiên đăng nhập cần kiểm xuyên lớp ở môi trường demo. Không gắn nhãn “chưa làm” cho phần đã có code nhưng thiếu runtime evidence.

Các báo cáo/roadmap lịch sử chỉ để truy nguyên. Tách bốn trạng thái: đã có code; test tự động đã chạy tại HEAD nào; runtime đã thử tại bản nào; còn thiếu/chưa triển khai.

## 4. Cách thực hiện việc thu gọn

1. Inspect dependencies, route, UI entry points, Provider/service, tests và cấu hình trước khi sửa; phân biệt code dùng chung với tính năng bị loại.
2. Lập gói triển khai/review theo phạm vi được giao và approval hiện có. Chốt scope không đồng nghĩa mọi thay đổi code đã được duyệt.
3. Gỡ chức năng ngoài scope theo từng gói: UI/navigation → code chỉ dùng riêng → dependency/quyền chỉ dùng riêng nếu được duyệt. Không xóa dữ liệu server/migration lịch sử hoặc tài liệu bằng chứng một cách tự động.
4. Giữ bảo vệ dữ liệu người dùng và các test còn đúng. Sửa/remove test đòi chức năng đã bị loại; không làm yếu test auth/data integrity để lấy PASS.
5. Không tự mở lại roadmap P0–P8/T2+ hoặc phát triển feature ngoài danh sách. Tài liệu/skill cũ yêu cầu dashboard/map/AI explainer-only bị thay thế ở phần sản phẩm mâu thuẫn.

## 5. Tiêu chí hoàn thành đồ án

- Đăng ký → nhận/xác minh OTP → đăng nhập; đăng xuất và quên/đặt lại mật khẩu thật; lỗi/OTP sai/hết hạn có phản hồi rõ, không cấp phiên giả.
- User khám phá/tìm điểm đến → tự lập lịch hoặc AI tạo → preview hủy giữ nguyên/xác nhận áp dụng → chỉnh hoạt động và ngân sách → lưu → mở lại → sửa → lưu lại → xóa bản thử.
- AI tư vấn không làm thay đổi bản nháp; preview sửa hoạt động hiển thị đúng thay đổi, hủy giữ nguyên và xác nhận mới áp dụng. Kiểm ca đổi giờ qua hoạt động khác, trùng giờ, phản hồi đến muộn khi bản nháp đã đổi và bảo toàn ghi chú/khoản đã chi.
- Đóng/mở app hoặc mất mạng không được báo lưu giả, làm lẫn tài khoản hoặc âm thầm mất dữ liệu đã lưu.
- Customer không dùng được API admin. Admin quản lý user/tài khoản và sửa địa điểm; User tải/làm mới thấy dữ liệu mới.
- App/navigation không còn giới thiệu chức năng bị loại; ngân sách/timeline không phụ thuộc bản đồ hay Decision Engine.
- Chạy `flutter analyze`, `flutter test` và contract checks phù hợp theo thay đổi, ghi exit/head/log. Không cần chạy Flutter tests chỉ vì sửa tài liệu.
- Diễn tập trên đúng APK, thiết bị, tài khoản thử và mạng sẽ báo cáo. Phân biệt PASS/FAIL/BLOCKED/NOT RUN; không thay runtime bằng test mock.

## 6. Quyền hạn và bàn giao

Giữ nguyên superpowers OFF trừ khi owner yêu cầu cho task hiện tại; Git safety, human merge gate, approval trước phase triển khai lớn và quy tắc giải thích cho owner vẫn hiệu lực. Không áp giới hạn file/tool calls cũ; giữ guard sửa lỗi hiện hành. Handover gồm Changed, Why, Testing, Problems, Lesson Candidate; nêu đã gỡ gì, còn gì trong scope, bằng chứng và việc chưa chạy.
