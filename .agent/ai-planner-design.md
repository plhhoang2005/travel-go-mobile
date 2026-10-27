# Trợ lý lập lịch trình AI — thiết kế owner chốt 24/10/2026

## Quyết định và phạm vi

Đọc cùng [product-scope.md](product-scope.md). TravelGO dùng Gemini qua backend hiện có, kết hợp RAG đơn giản từ catalogue, Google Search Grounding cho nhánh tìm web do người dùng chọn và validation bằng code. Tên chức năng: **Trợ lý lập lịch trình AI**. Chat/ô nhập yêu cầu là cách giao tiếp trong chuyến đi, không phải chatbot du lịch tổng quát.

Đây là thiết kế đích đã được owner đồng ý ghi vào project; không phải báo cáo implementation hoàn tất, không tự cấp quyền deploy, sửa database hoặc thêm dependency. Ưu tiên kiểm tra và hoàn thiện generation/assistant/grounding/preview có sẵn, không viết lại framework.

## 1. RAG đơn giản và trách nhiệm các lớp

Luồng: yêu cầu người dùng → UI/Provider thu thập ngữ cảnh → backend kiểm tài khoản, giới hạn gọi và lấy catalogue liên quan → Gemini → kiểm dữ liệu có cấu trúc → preview hoặc câu trả lời → người dùng xác nhận → bản chỉnh sửa → người dùng lưu theo tài khoản.

- Retrieval là lọc catalogue theo điểm đến, ID địa điểm và trường dữ liệu có sẵn. Chưa cần semantic search, pgvector, LangChain hoặc vector database.
- Backend là nơi điều phối truy xuất dữ liệu đáng tin và gọi model. Có thể tái sử dụng facts builder/snapshot/cache hiện có; khi client gửi facts, server phải kiểm schema, nguồn/phiên bản phù hợp và coi nội dung client là dữ liệu không đáng tin, không là lệnh hệ thống.
- Dữ liệu catalogue gồm mã/tên địa điểm, mô tả, giá, đơn vị tính giá, giờ mở cửa, nguồn và trạng thái xác minh nếu có. Thiếu dữ liệu phải giữ trạng thái unknown/unverified, không tự đổi thành giá 0 hay giờ chắc chắn.
- Tài liệu/mô tả địa điểm và lời nhập người dùng là dữ liệu, không được phép ghi đè instruction hoặc kiểm quyền.
- RAG cung cấp căn cứ, không bảo đảm kết quả đúng. Server/client kiểm ràng buộc trước khi thay đổi bản chỉnh sửa; quyền dữ liệu lưu do server quyết định.
- Catalogue không khả dụng hoặc thiếu: báo rõ và giữ bản chỉnh sửa, cho người dùng chọn tìm web hoặc tự lập lịch; không tự gọi web hay âm thầm sinh dữ liệu địa điểm giả. Cache sẵn có phải có nguồn/trạng thái dữ liệu cũ rõ ràng.

## 2. Ba nhiệm vụ trong hai luồng UI

### Tạo lịch

Nút **AI tạo lịch** dùng form: điểm đến, ngày đi/số ngày, số người, ngân sách và sở thích. Backend lấy catalogue liên quan, Gemini trả lịch có cấu trúc theo ngày, mã địa điểm, giờ dự kiến và chi phí tham khảo. Kiểm kết quả rồi hiển thị preview → hủy/xác nhận. Xác nhận chỉ áp dụng vào bản chỉnh sửa; lưu là thao tác riêng.

Thiết kế đồ án: chỉ tạo toàn bộ lịch khi bản chỉnh sửa chưa có hoạt động. Khi đã có lịch, chuyển sang trợ giúp/đề xuất sửa; không append toàn lịch hoặc ghi đè âm thầm khi bấm tạo lại. Đây là hành vi đích cần đối chiếu implementation hiện tại, không khẳng định đã có gate.

### Tư vấn

Mục **Trợ giúp AI** trong chuyến đi có chế độ tư vấn. Ví dụ: “Ngày 1 có quá nhiều hoạt động không?”, “Ngân sách còn lại có đủ không?”. Cung cấp lịch hiện tại, ngày/hoạt động được chọn, thông tin chuyến đi, tổng dự toán và ngân sách còn lại. Phân biệt ngân sách trừ dự kiến với ngân sách trừ đã chi, gắn nhãn đúng; không gửi một số dư mơ hồ.

Trả lời bằng nội dung dễ hiểu, chỉ dựa trên ngữ cảnh được cung cấp; nói rõ giới hạn khi thiếu dữ liệu. Tư vấn không tạo command mutation hoặc tự lưu lịch.

### Đề xuất sửa hoạt động

Trong cùng mục Trợ giúp AI, người dùng chọn ngày/hoạt động và yêu cầu thêm/sửa/xóa. Model trả danh sách operation có cấu trúc, target ID và thay đổi cụ thể. Không phân tích đoạn văn tự do để đoán mutation.

Preview thể hiện trước/sau, hoạt động thêm/sửa/xóa và dự toán cần xem lại. Hủy giữ nguyên; xác nhận mới cập nhật bản chỉnh sửa. Không âm thầm xóa ghi chú, sửa khoản đã chi hoặc đổi tiền theo suy đoán của AI. Nếu thao tác tác động dữ liệu liên kết mà chưa có chính sách bảo toàn rõ, chặn và giải thích thay vì bỏ dữ liệu.

## 3. Ngữ cảnh, validation và tính nhất quán

- Tạo lịch nhận đúng các lựa chọn có ý nghĩa trong UI: điểm đến, ngày/số ngày, số người, ngân sách và sở thích. Không hiển thị tùy chọn cá nhân hóa mà không dùng hoặc không nói rõ giới hạn.
- Tư vấn/sửa nhận lịch hiện tại và số tổng hợp ngân sách cần thiết. Không gửi email, mật khẩu, token hoặc toàn bộ ledger chi tiết không cần thiết cho model. Auth token dùng riêng cho kết nối app–backend, không vào prompt.
- Output tạo/sửa phải qua schema allowlist và validation: đúng điểm đến, mã địa điểm nội bộ thuộc tập cung cấp hoặc tham chiếu ngoài catalogue có nguồn theo nhánh web, target tồn tại, ngày trong chuyến đi, giờ/thứ tự hợp lệ, không trùng giờ, tiền không âm và đúng đơn vị.
- Kiểm giờ mở cửa đã xác minh theo ngày cụ thể. Giờ chưa biết giữ nhãn cảnh báo, không coi thiếu dữ liệu là đã kiểm hợp lệ.
- Code tính tổng dự toán/đã chi và cảnh báo vượt ngân sách; không tin tổng tiền model tự khai. Không hứa ngân sách bảo đảm gồm mọi chi phí nếu thiếu dữ liệu.
- Kiểm toàn document sau khi chuyển operation thành thay đổi: dời giờ phải cập nhật thứ tự timeline phù hợp, không chỉ kiểm từng operation riêng.
- Gắn đề xuất với version/digest bản chỉnh sửa và tài khoản/ngữ cảnh đang mở. Nếu người dùng sửa lịch, đổi chuyến đi hoặc đổi tài khoản khi AI đang chạy, kết quả cũ không được áp dụng; hướng dẫn gửi lại theo ngữ cảnh mới.
- Không hứa tối ưu quãng đường, định tuyến hoặc thời gian di chuyển chính xác; bản đồ/định tuyến ngoài scope.

## 4. Lỗi và trải nghiệm

Loading không chặn chỉnh sửa thủ công. Có thông báo khi mạng/provider lỗi, timeout, quota hết hoặc output không hợp lệ; giữ nguyên lịch và cho thử lại có chủ đích. Không tự gọi provider lặp nhiều lần, không giả thành công hoặc tự fallback sang lịch giả. Backend giữ khóa API, kiểm quyền và giới hạn gọi hiện có.

UI gồm nút tạo lịch, mục Trợ giúp AI với lựa chọn tư vấn/đề xuất sửa và gợi ý câu hỏi ngắn; mọi mutation có preview/hủy/xác nhận. Không mở rộng lịch sử hội thoại bền vững, agent tự hành hoặc công cụ ngoài phạm vi nếu chưa được giao.

## 5. Thứ tự hoàn thiện và bằng chứng nghiệm thu

1. Audit generation/assistant/grounding/preview hiện có và payload thực sự gửi đi; phân biệt source, deployed backend và APK.
2. Tạo lịch → validate → preview/hủy/áp dụng trên bản trống; chặn tạo toàn lịch trên bản có hoạt động.
3. Tư vấn dùng đúng lịch và tổng hợp ngân sách, không đổi document.
4. Đề xuất sửa → preview trước/sau → hủy/áp dụng; bảo toàn dữ liệu liên kết.
5. Lưu, mở lại và kiểm nội dung đã áp dụng; chạy checks phù hợp, sau đó thử UI thật với dịch vụ thật.

Các ca trọng yếu: hủy không đổi document; đổi giờ qua hoạt động khác; trùng giờ; địa điểm lạ; ngoài giờ mở cửa đã biết; chi phí thiếu/âm; đổi lịch khi chờ AI; đổi tài khoản; lỗi mạng/quota; lưu/mở lại không mất ghi chú và khoản đã chi. Dùng fixture cho test, tài khoản thử có quyền cho runtime. Ghi HEAD, bản backend/APK, kết quả và NOT RUN/BLOCKED; test xanh không tự chứng nhận demo.

Không triển khai vector search hoặc roadmap enterprise để đáp ứng các tiêu chí trên. Không coi tài liệu này là bằng chứng tính năng đã được sửa hay nghiệm thu.

## 6. Quyết định bổ sung — tìm Internet và dẫn chứng (owner chốt 24/10/2026)

Quyết định này bổ sung catalogue-only trước đó. Ưu tiên catalogue; khi chưa có điểm đến hoặc thiếu dữ kiện cần thiết, hiển thị giới hạn và lựa chọn **Tìm thông tin trên Internet**. Chỉ gọi tìm web sau khi người dùng chọn; không tự chuyển âm thầm. Lỗi tìm kiếm không làm mất bản chỉnh sửa.

- Hướng tích hợp: Gemini qua backend + Google Search Grounding; không tự xây crawler/vector database. Phải kiểm tương thích model/API hiện dùng, JSON output, metadata dẫn nguồn, điều kiện hiển thị và chi phí trước triển khai. Không tự đổi model, quota, billing hoặc deploy từ quyết định tài liệu này.
- Grounding có thể không thực hiện tìm kiếm hoặc không trả bằng chứng cho một nhận định; bật tool không đồng nghĩa mọi câu đều có nguồn. Không có evidence phù hợp thì không gắn nhãn có dẫn chứng.
- Mỗi nhận định thực tế quan trọng cần liên kết tới evidence: mã nguồn, URL do hệ thống nhận/truy xuất, tiêu đề/đơn vị nếu xác định được, dữ kiện hỗ trợ, thời điểm truy xuất, ngày kiểm tra/cập nhật khi biết và khoảng ngày hiệu lực nếu có. Không lấy thời điểm truy xuất làm ngày xuất bản hay ngày xác minh.
- UI có **Xem căn cứ**: dữ kiện được dùng, link nguồn, thời điểm và giới hạn. Tách điều nguồn nói với suy luận/đề xuất AI; nguồn không được tự sinh từ văn bản model. Catalogue cần trạng thái xác minh và độ mới, web cần nhãn **Thông tin từ Internet, chưa được Admin kiểm duyệt**. Có nguồn không tự nghĩa đã xác minh; không ưu tiên dữ kiện catalogue cũ để bỏ qua mâu thuẫn mới.
- Ưu tiên nguồn chính thức phù hợp với loại dữ kiện; khi mâu thuẫn/thiếu nguồn, nêu giới hạn, không chọn giá thấp nhất hoặc đổi dữ liệu thiếu thành miễn phí. Kiểm địa điểm, ngày, đơn vị tính và phạm vi hỗ trợ của bằng chứng.
- Không suy mưa một ngày cụ thể từ xu hướng tháng/mùa. Chỉ tư vấn dựa trên dự báo bao phủ đúng địa điểm/ngày, có thời điểm cập nhật; chưa có dự báo thì nói chưa đủ căn cứ. Quyết định này không tự đưa lại widget thời tiết, bản đồ hoặc API dự báo chuyên biệt vào scope.
- Thông tin/địa điểm từ web chỉ vào chuyến đi sau preview/xác nhận, lưu nguồn và nhãn cùng dữ liệu để mở lại vẫn xem được. Không tự thêm vào catalogue chung. Cần định danh tham chiếu ngoài catalogue riêng, không giả placeId nội bộ và không nới allowlist/validation toàn hệ thống để nhận chuỗi tùy ý.
- Người dùng vẫn có thể tự lập lịch khi thiếu dữ liệu; dữ liệu tự nhập được gắn nguồn người dùng, không coi đã xác minh.
- Tìm web chỉ gửi thông tin chuyến đi cần thiết; không đưa ghi chú riêng tư, email, token hoặc ledger cá nhân vào truy vấn tìm kiếm.

Thứ tự chốt: (1) AI catalogue có bằng chứng + kiểm ràng buộc + preview; (2) tư vấn tìm web có trích dẫn; (3) chuẩn hóa đề xuất web thành hoạt động xem trước/lưu/mở lại. Chưa bật giai đoạn 3 chỉ vì tư vấn web đã trả lời được.

Nghiệm thu bổ sung: catalogue thiếu → không gọi web trước lựa chọn; nguồn sai/không có/không hỗ trợ nhận định; thông tin cũ/mâu thuẫn; dự báo ngoài khoảng ngày; metadata tìm kiếm rỗng; web timeout/quota; lưu/mở lại hoạt động ngoài catalogue giữ nguồn; hủy không đổi lịch; dữ liệu web không thành catalogue Admin. Các bước thực tế trên backend/APK phải có evidence riêng.
