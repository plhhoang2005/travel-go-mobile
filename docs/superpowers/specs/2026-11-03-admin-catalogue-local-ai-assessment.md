# Đánh giá quản trị, bản đồ và AI local trong lập chuyến đi

Ngày: 03/11/2026. Trạng thái: **đề xuất để owner duyệt, chưa phải phạm vi triển khai đã duyệt**.

## Mục tiêu và căn cứ

Làm cho quản trị thay đổi được dữ liệu thật, người dùng nhận đúng danh mục đã xuất bản, sau đó dùng Qwen3 local hỗ trợ lập chuyến đi dựa trên dữ liệu đó. Không mở rộng thành hệ thống tài chính hoặc nền tảng huấn luyện AI.

Căn cứ: bảy ảnh owner cung cấp; code tại HEAD `7bf77cb97641bfaf461d5a0c1e3141b539b65dd2` cùng working tree hiện tại; `.agent/product-scope.md`, `.agent/ai-planner-design.md`, `docs/phase-3/LOCAL_AI_QWEN3_HANDOVER_20261103.md`. Phiên này chỉ đọc code và lập tài liệu; chưa gọi backend đang deploy bằng tài khoản admin, chưa chạy lại kiểm thử Flutter/SQL.

Lựa chọn Qwen3 local mới nhất của owner được giữ. Tài liệu scope cũ ghi Gemini và loại bản đồ khỏi phạm vi; đề xuất mới là giữ bản đồ hiện có để sửa tính đúng đắn, không thêm GPS/chỉ đường, và dùng local cho chức năng AI đang bàn. Sau khi được duyệt phải cập nhật tài liệu thiết kế liên quan; không tự sửa permanent rules trong phiên lập plan này.

## 1. Hiện trạng và mức chắc chắn

| Nội dung | Bằng chứng | Kết luận |
|---|---|---|
| Danh sách khách hàng/tất cả người dùng lỗi | Ảnh 1–2; `admin_account_service.dart` gọi `admin-control` → RPC `admin_accounts`; nhiều mã lỗi cùng ánh xạ thông báo chung | Lỗi có thật trên máy owner. Chưa xác định là function deploy, schema, quyền hay hợp đồng phản hồi; không kết luận do mạng hoặc do `digest` |
| Lưu danh mục khác xuất bản | Ảnh 3–6 báo lưu nháp thành công; preview trả SQLSTATE `42883`, không tìm thấy `public.digest(text, unknown)` | Đã xác nhận bước chuẩn bị xuất bản đang lỗi ở database. Không được báo toàn bộ CRUD chưa lưu, cũng không được coi đã công khai |
| Các bản sửa SQL cục bộ | Có `fix_admin_accounts.sql`, `fix_prepare_discovery_preview.sql`, migration `20261103140000_fix_pgcrypto_digest.sql` chưa được Git theo dõi | Không phải bằng chứng đã áp dụng lên server; cần kiểm tra từng bản, không chạy tất cả để thử |
| Retry sau lưu nháp | Provider còn có thể nhận một lệnh create mới khi bản nháp đã được xác nhận lưu nhưng xuất bản thất bại | Rủi ro tạo trùng cần test tái hiện; chưa khẳng định dữ liệu trên server đã bị trùng |
| Trạng thái hoạt động | Draft có `active`, nhưng create/update command không truyền giá trị này; archive là command riêng | Công tắc trong form có thể không phản ánh thao tác lưu. Không coi “bật lại” là đã được hỗ trợ |
| Tọa độ | Form có tọa độ mặc định; bản đồ có fallback đặt điểm lệch quanh tâm điểm đến | Vị trí tạm có thể bị hiểu thành vị trí thật; cần phân biệt thiếu tọa độ với đã xác minh |
| Ẩn từ bản đồ | `_togglePlaceHide` chỉ đổi `_hiddenPlaceIds` trong state của màn hình | Không phải lệnh ẩn toàn hệ thống; mở lại màn hình có thể mất trạng thái |
| Nguồn bản đồ | Bản đồ ưu tiên public snapshot; publication bundle loại phần tử `isActive == false` | Luồng đúng là lưu nháp → xuất bản thành công → khách refresh snapshot → danh sách/bản đồ cập nhật. Hiện chưa bảo đảm đầu-cuối |
| AI local | Qwen3 4B Instruct Q4_K_M đã được kiểm tra trên điện thoại qua USB ở phiên trước; cài đặt host/model là preferences trên thiết bị | Không phải chính sách AI dùng chung của admin; kết quả kiểm thử trước không chứng minh các lỗi admin hiện tại đã hết |
| AI trong planner | `ManualPlannerScreen` đã có “Trợ giúp AI”, `AiAssistantContext`, validation và preview; đường gọi mặc định còn dùng gateway cũ | Tái sử dụng luồng bảo vệ và preview, thay adapter AI có chủ đích; không nối chatbot văn bản trực tiếp vào lệnh sửa lịch |
| Chat riêng tư | Chat local hiện chưa cung cấp ngữ cảnh chuyến đi/RAG; lịch sử lưu theo thiết bị | Phải phân vùng theo tài khoản/chuyến đi trước khi đưa dữ liệu lịch trình riêng vào chat |

Hàm `digest` có overload `text,text` và `bytea,text` theo [PostgreSQL pgcrypto](https://www.postgresql.org/docs/current/pgcrypto.html). Ảnh chỉ chứng minh tên hàm/schema hiện tại không resolve; cần kiểm tra extension nằm ở đâu và search_path trước khi chọn cách sửa.

## 2. Đánh giá năm đề xuất của owner

### A. Sửa quản trị người dùng và CRUD danh mục: bắt buộc, ưu tiên cao nhất

Quản trị phải dùng tài khoản thật, phân quyền server, danh sách thật và lỗi có thể chẩn đoán. Demo Sandbox chỉ là môi trường thử riêng, không phải giải pháp cho lỗi server. Phạm vi người dùng hợp lý: xem/tìm/lọc/phân trang, xem chi tiết cần thiết, khóa/mở khóa có lý do và nhật ký. Không mặc định thêm tạo/xóa tài khoản Auth tùy ý.

Danh mục phải phân biệt bốn kết quả: chưa lưu; đã lưu nháp/chưa xuất bản; đã xuất bản; chưa rõ kết quả thao tác. Thử lại xuất bản không gửi lại lệnh tạo. Ưu tiên ẩn/lưu trữ thay vì xóa cứng để không phá lịch trình đã lưu; nếu cần hiện lại từng mục phải có command/kiểm quyền riêng, không dùng khôi phục toàn phiên bản để bật một mục.

### B. Thay nội dung “Quản trị AI”: hợp lý, cần phân biệt hai loại cài đặt

Màn chính nên quản lý hành vi sản phẩm: bật/tắt trợ lý, hiển thị lối vào chatbot, cho phép tư vấn trong chuyến đi, và trạng thái dữ liệu catalogue dùng cho gợi ý. Host/model nằm trong phần “Kết nối AI trên thiết bị này” thu gọn; prompt và nhiệt độ chỉ ở cấu hình nâng cao cho demo, không đặt làm nhiệm vụ quản trị chính.

Đề xuất mặc định là chính sách dùng chung do admin có quyền ghi trên backend, client đọc các trường công khai an toàn. Phải phân biệt “ẩn nút chatbot” với “tạm ngừng chức năng”: trường hợp sau chặn mọi lối vào và xử lý request đang chạy. Preferences cục bộ không thể tắt AI cho mọi khách hàng. Đây là điều khiển hành vi app; không thể thu hồi quyền gọi một Ollama độc lập ngoài app.

Không thêm huấn luyện model, tải tài liệu tùy ý, vector database hoặc dashboard kỹ thuật lớn. Khi server policy lỗi, giữ dữ liệu người dùng, báo chưa xác định khả dụng; không dùng một cờ local để giả chính sách server.

### C. Thêm/ẩn trên danh mục có hiện trên bản đồ không?

**Theo thiết kế có, sau xuất bản và refresh. Với hiện trạng ảnh/code, chưa bảo đảm.** Lưu nháp không đổi dữ liệu khách hàng. Ẩn điểm đến đã xuất bản phải loại điểm đến và các điểm con khỏi khám phá/bản đồ, nhưng không tự xóa các hoạt động đã lưu trong lịch của khách.

Sửa cả lỗi xuất bản, thao tác ẩn cục bộ trên bản đồ và lựa chọn điểm đến cũ khi snapshot đổi. Điểm thiếu tọa độ vẫn có thể xuất hiện trong danh sách với trạng thái “Chưa có vị trí”, không tạo marker giả. Không mở rộng GPS, dẫn đường hay bản đồ mới trong gói sửa này.

### D. Quản trị thêm ngân sách: hợp lý nếu đổi thành quản trị dữ liệu chi phí

Đề xuất thêm giá vé/dịch vụ tham khảo, đơn vị tiền, cách tính theo người/nhóm, điều kiện áp dụng, nguồn và ngày xác minh ngay trong chi tiết địa điểm; bổ sung giờ mở cửa và nguồn nếu cần. Tái sử dụng `VisitCatalogue`, `VisitPrice` và `VisitHours` đang có. Chưa rõ giá phải là “chưa xác minh”, không phải 0 đồng. AI và bộ tính ngân sách dùng dữ liệu này nhưng ghi rõ ước tính.

Không cho admin sửa ngân sách hoặc khoản chi riêng của chuyến đi khách hàng. “Mẫu ngân sách theo điểm đến/người/ngày” có thể làm sau nếu owner cần demo, là dữ liệu tham khảo riêng có schema/nguồn rõ, không phải yêu cầu để sửa lỗi hiện tại. Giữ bốn tab admin hiện có; chưa cần thêm tab ngân sách chỉ để tăng số chức năng.

### E. AI local trong lập chuyến đi: phù hợp với trải nghiệm chính

Điểm vào chính là nút “Trợ giúp AI” trong planner. Giai đoạn đầu chỉ tư vấn: nhận câu hỏi cùng ngày đang chọn, ngân sách còn lại, hoạt động liên quan và vài bản ghi catalogue đã xuất bản. Truy xuất có cấu trúc bằng code là RAG đơn giản; không cần vector database. Hiển thị các địa điểm/giá/nguồn thực sự được dùng; thiếu dữ liệu thì nói thiếu.

Giai đoạn sau mới tạo/đề xuất sửa hoạt động: Qwen trả dữ liệu có cấu trúc → parser/validator hiện có → preview thay đổi → hủy hoặc xác nhận. Code kiểm ID địa điểm, ngày/giờ, lịch trùng, tổng tiền và revision. Tư vấn không tự ghi; không tự chuyển sang Gemini khi local lỗi. Giữ ghi chú và khoản đã chi của người dùng.

Trước khi cấp ngữ cảnh phải ràng buộc owner/account session, trip ID và workspace revision; bỏ kết quả cũ khi đổi tài khoản/chuyến đi. Lịch sử tách theo tài khoản và chuyến đi; lịch sử thiết bị cũ không tự gán cho tài khoản đầu tiên đăng nhập và không tự xóa. Chọn cách chuyển đổi rõ ràng khi triển khai.

Hiện local dùng context 2048 và output 256 cho câu trả lời ngắn. Không tái sử dụng giới hạn đó một cách mù quáng cho lịch nhiều ngày: chọn ít ứng viên, đo token/độ trễ/RAM trên máy demo, thử JSON bị cắt và lỗi parse; không tăng context vô hạn. Giữ model `qwen3:4b-instruct-2507-q4_K_M`.

## 3. Các phương án

| Phương án | Ưu điểm | Hạn chế | Đề xuất |
|---|---|---|---|
| Chỉ sửa thông báo và kết nối | Ít thay đổi | Không giải quyết xuất bản, retry trùng và bản đồ sai trạng thái | Không đủ để nghiệm thu |
| Sửa dữ liệu đầu-cuối, rồi tích hợp AI local từng bước | Có nền dữ liệu tin cậy; tái sử dụng kiến trúc; từng gói demo được | Cần kiểm thử admin và khách trên cùng phiên bản dữ liệu | Chọn phương án này |
| Mở rộng quản trị tài chính và nền tảng AI/RAG lớn | Nhiều chức năng | Vượt đồ án, tăng dependency và rủi ro quyền riêng tư | Không chọn |

## 4. Thứ tự triển khai và tiêu chí nghiệm thu

1. **Gói 1 — phục hồi quản trị và dữ liệu công khai.** Chẩn đoán users; sửa đúng lớp; sửa digest; chống tạo trùng khi retry; trạng thái ẩn rõ ràng; tọa độ đúng; bản đồ nhận phiên bản mới. Kế hoạch chi tiết ở `../plans/2026-11-03-admin-data-repair-and-map-sync.md`.
2. **Gói 2 — chính sách AI và ngữ cảnh riêng tư.** Thiết kế policy dùng chung + cấu hình thiết bị riêng; tách lịch sử theo account/trip; ràng buộc request cũ. Nghiệm thu: khóa chức năng áp dụng các lối vào sau khi nhận policy, đăng xuất/đổi tài khoản không lộ chat của tài khoản trước. Phải viết plan riêng sau khi duyệt hướng này.
3. **Gói 3 — tư vấn local trong planner.** RAG catalogue có giới hạn, nguồn rõ, hỏi theo ngày/ngân sách; không tự sửa lịch. Nghiệm thu câu hỏi có/thiếu dữ liệu, Ollama tắt, hủy request, mạng lỗi, chuyến đi đổi revision, đo máy demo thật.
4. **Gói 4 — đề xuất sửa/tạo lịch có preview.** Adapter output cấu trúc, validators, hủy/xác nhận. Nghiệm thu JSON sai/cắt, ID lạ, lịch trùng, giá chưa xác minh, vượt ngân sách, xác nhận lặp và output trễ. Không ghi dữ liệu trước xác nhận.
5. **Gói 5 — dữ liệu giá/giờ cho admin.** Biên tập dữ liệu giá/giờ có nguồn rồi xuất bản qua pipeline đã sửa. Có thể thực hiện trước gói 3 nếu dữ liệu hiện tại không đủ trả lời câu hỏi ngân sách. Mẫu ngân sách là tùy chọn sau cùng.

Gói 1 là ưu tiên trước mọi mở rộng. Các gói sau là roadmap, không phải toàn bộ đã được duyệt code. Không thêm dependency/framework hoặc thay kiến trúc chỉ để làm các mục này.

## 5. Điều cần owner duyệt

- Duyệt gói 1 để xử lý lỗi thật trước; không triển khai đồng loạt năm gói.
- Đồng ý hướng AI local trong planner: tư vấn có ngữ cảnh trước, đề xuất thay đổi có preview sau; chính sách AI dùng chung khác cấu hình Ollama trên máy.
- Đồng ý “quản trị chi phí” là quản lý giá/nguồn tham khảo của địa điểm; chưa thêm quyền sửa ngân sách cá nhân hoặc tab tài chính.

## Bàn giao phiên phân tích

- **Changed:** tạo assessment này và plan gói 1; không sửa code ứng dụng/SQL.
- **Why:** giải quyết dữ liệu không tới khách hàng trước khi đưa dữ liệu đó cho AI.
- **Testing:** đối chiếu ảnh, code và hợp đồng hiện có; chưa kiểm thử backend deploy. Không chạy `flutter analyze`/`flutter test` vì phiên này chỉ viết tài liệu.
- **Problems:** chưa xác định nguyên nhân users; chưa chứng minh SQL local đã được áp dụng; working tree có bốn file admin đang sửa sẵn cần giữ nguyên.
- **Lesson Candidate:** Lưu nháp thành công nhưng khách không thấy → nhầm lưu với xuất bản → kiểm tra riêng command, publication và phiên bản public snapshot trước khi báo CRUD hoàn tất.
