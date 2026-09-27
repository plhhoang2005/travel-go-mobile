# KNOWLEDGE BASE & MEMORY — TRAVELGO MOBILE (FLUTTER)

Cơ sở tri thức toàn diện, các quyết định kiến trúc bất biến (ADRs), nợ kỹ thuật được chấp nhận và bộ nhớ bài học kinh nghiệm (Episodic Memory) dành riêng cho ứng dụng di động TravelGO Flutter.

---

## 1. Project Context & Target Persona

### 1.1. Tầm Nhìn Sản Phẩm
TravelGO Mobile là ứng dụng di động **Trí tuệ Nhân tạo Hỗ trợ Ra Quyết định (Decision Intelligence)** trong du lịch và di chuyển thông minh cho người Việt.
- **Bài toán cốt lõi**: "Với ngân sách X triệu đồng, xuất phát từ Y trong Z ngày, đi cùng gia đình/bạn bè thì nên đi đâu, đi bằng phương tiện gì để tối ưu chi phí vs thời gian, và lịch trình sắp xếp ra sao?"
- **Triết lý cốt lõi**: Tránh bẫy Chatbot văn bản. Thay vào đó là **Interactive Mobile Dashboard** với thanh trượt tương tác thời gian thực, biểu đồ trực quan (`fl_chart`) và thẻ điểm số minh bạch có thể kiểm chứng toán học.

### 1.2. Chân Dung Khách Hàng Mục Tiêu (Target Persona)
- **Tên**: Minh (25 tuổi, kỹ sư CNTT tại TP. Hồ Chí Minh).
- **Ngân sách**: 3.000.000 – 5.000.000 VNĐ / người.
- **Thời lượng**: Chuyến đi 2 – 4 ngày (cuối tuần hoặc nghỉ lễ ngắn).
- **Quy mô nhóm**: Nhóm bạn thân 3-4 người hoặc gia đình nhỏ.
- **Mối quan tâm hàng đầu**: Cân nhắc phương tiện tối ưu (xe khách/tàu hỏa tiết kiệm vs máy bay nhanh), điểm đến có thời tiết thuận lợi và lịch trình cân đối (tối đa 3-4 điểm tham quan/ngày, không bị quá tải).

---

## 2. Architecture Decisions Records (ADRs)

### ADR-001: Feature-First Architecture trên Flutter
- **Trạng thái**: Accepted
- **Bối cảnh**: Ứng dụng di động cần phân chia rõ ràng giữa các tính năng độc lập, dễ mở rộng mà không làm rối cấu trúc widget.
- **Quyết định**: Áp dụng Feature-First layout:
  - `core/`: Chứa hằng số toàn cục ([`ApiConstants`](file:///d:/Travel-Go-Android/travel-go/lib/core/constants/api_constants.dart)) và giao diện dùng chung ([`AppTheme`](file:///d:/Travel-Go-Android/travel-go/lib/core/theme/app_theme.dart)).
  - `features/trip_planner/`: Chứa toàn bộ 4 lớp: `models/`, `services/`, `providers/`, `presentation/`.
- **Hệ quả**: Dễ dàng module hóa, tìm kiếm nhanh mã nguồn và cô lập phạm vi kiểm thử.

### ADR-002: Quản Lý Trạng Thái với Provider & ChangeNotifier
- **Trạng thái**: Accepted
- **Bối cảnh**: Cần một giải pháp quản lý trạng thái chính thức, nhẹ, dễ bảo trì, ít boilerplate cho giai đoạn hiện tại của ứng dụng.
- **Quyết định**: Sử dụng package `provider: ^6.1.5+1` kết hợp `ChangeNotifier` ([`TripProvider`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/providers/trip_provider.dart)).
- **Hệ quả**: Phù hợp hoàn hảo với quy mô app, dễ kiểm thử bằng Mock Service, và mở đường chuyển đổi sang Riverpod/BLoC trong tương lai nếu cần.

### ADR-003: Tầng Mạng Dio Kết Hợp Cơ Chế Fallback Minh Bạch (Law 3)
- **Trạng thái**: Accepted
- **Bối cảnh**: Ứng dụng di động cần hoạt động mượt mà ngay cả khi môi trường mạng chập chờn, Backend offline hoặc đang thử nghiệm offline.
- **Quyết định**: Sử dụng `dio: ^5.11.1` với Interceptor ghi log debug, cấu hình timeout chặt chẽ (15s connect, 30s receive), và khi có lỗi kết nối sẽ gọi `_generateOfflineFallbackResponse` có cờ `isFallback: true`.
- **Hệ quả**: Đảm bảo ứng dụng không bao giờ bị crash trắng màn hình khi mất mạng, đồng thời UI hiển thị nhãn `[FALLBACK]` minh bạch cho người dùng.

### ADR-004: Trực Quan Hóa Đồ Thị với fl_chart
- **Trạng thái**: Accepted
- **Bối cảnh**: Cần hiển thị biểu đồ phân bổ ngân sách (Donut Chart) và biểu đồ phân tán tối ưu Pareto (Scatter/Bar Chart) trực tiếp trên màn hình mobile.
- **Quyết định**: Sử dụng `fl_chart: ^1.2.0` cho cả [`ParetoChartWidget`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/pareto_chart_widget.dart) và [`BudgetDonutChart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/presentation/widgets/budget_donut_chart.dart).
- **Hệ quả**: Hiệu năng vẽ Canvas native cao, hỗ trợ responsive tốt trên nhiều kích thước màn hình Android/iOS.

---

## 3. Accepted Technical Debt (Nợ Kỹ Thuật Đã Chấp Nhận)

> **Cảnh báo cho AI Agent**: Tuyệt đối **KHÔNG ĐƯỢC** tự ý refactor hoặc "sửa" các vấn đề dưới đây trừ khi task có yêu cầu chỉ định rõ ràng:

### ISSUE-001: Bộ Dữ Liệu Demo Fallback Cứng Trong Service
- **Hiện trạng**: Dữ liệu fallback ngoại tuyến đang được hardcode trực tiếp trong phương thức `_generateOfflineFallbackResponse` tại [`trip_api_service.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/services/trip_api_service.dart).
- **Lý do chấp nhận**: Giúp ứng dụng chạy demo ngay lập tức mà không cần cài đặt thêm SQLite/Hive hay file asset JSON phụ trong giai đoạn này.

### ISSUE-002: Các Cấu Hình Preset Hardcode Trong Model
- **Hiện trạng**: Các preset (Minh, Phú Quốc, Vũng Tàu) được định nghĩa tĩnh trong [`trip_request.dart`](file:///d:/Travel-Go-Android/travel-go/lib/features/trip_planner/models/trip_request.dart).
- **Lý do chấp nhận**: Phục vụ việc demo tức thì chỉ bằng 1 nút bấm trên `HomePlannerScreen`.

### ISSUE-003: Chưa Có Xác Thực Người Dùng (Authentication)
- **Hiện trạng**: Ứng dụng hoạt động dạng guest/anonymous, chưa có đăng nhập tài khoản, token JWT hay quản lý profile cá nhân.
- **Lý do chấp nhận**: Ưu tiên tối đa hoàn thiện trải nghiệm Decision Intelligence cốt lõi.

---

## 4. Episodic Memory & Lessons Learned (Bài Học Kinh Nghiệm Đã Duyệt)

### [ACTIVE] LESSON-001: Xử Lý BaseUrl Cho Android Emulator vs Thiết Bị Thật
- **Lĩnh vực**: Mobile Networking
- **Vấn đề**: Máy ảo Android (Android Emulator) chạy trong mạng ảo riêng, không thể gọi trực tiếp `http://localhost:8080` (trỏ vào chính máy ảo thay vì máy tính host phát triển).
- **Giải pháp**: Trong [`ApiConstants.baseUrl`](file:///d:/Travel-Go-Android/travel-go/lib/core/constants/api_constants.dart), tự động phát hiện `Platform.isAndroid` để dùng IP `10.0.2.2:8080`, còn Web/iOS/Desktop dùng `localhost:8080`.
- **Quy tắc cho Agent**: Tuyệt đối không hard-code `localhost` cố định trong code mạng của Flutter.

### [ACTIVE] LESSON-002: Phòng Ngừa Crash Khi Parse DTO Có Danh Sách Rỗng Hoặc Null
- **Lĩnh vực**: DTO & Type Safety
- **Vấn đề**: Khi Backend trả về danh sách phụ (`pois`, `assumptions`, `activities`) rỗng hoặc null, app bị ném ngoại lệ `TypeError: Null is not a subtype of type List`.
- **Giải pháp**: Luôn ép kiểu an toàn với default value rỗng: `(json['activities'] as List<dynamic>?)?.map(...).toList() ?? []`.
- **Quy tắc cho Agent**: Mọi hàm `fromJson` trong thư mục `models/` bắt buộc phải có giá trị mặc định cho danh sách và kiểu nullable.

### [ACTIVE] LESSON-003: Tối Ưu Tần Suất Rebuild Với Provider
- **Lĩnh vực**: Flutter Performance
- **Vấn đề**: Sử dụng `context.watch<TripProvider>()` ở cấp độ widget cha (Scaffold) khiến toàn bộ màn hình bị rebuild mỗi khi 1 slider thay đổi giá trị.
- **Giải pháp**: Tách các phần hiển thị giá trị thanh trượt thành widget con và chỉ lắng nghe giá trị đó bằng `context.select<TripProvider, int>(...)` hoặc bọc cục bộ bằng `Consumer<TripProvider>`.
- **Quy tắc cho Agent**: Luôn thu hẹp phạm vi lắng nghe Provider xuống widget con thấp nhất có thể.

### [ACTIVE] LESSON-004: Ngăn Chặn Tool Bypassing Trực Tiếp Trong Anti-Vague Gatekeeper
- **Lĩnh vực**: Autonomous Agent Behavior & Safety Governance
- **Vấn đề**: Khi người dùng nhập prompt ngắn hoặc mơ hồ ("làm chức năng đăng nhập", "thêm màn hình lịch sử"), Agent bị thiên vị công cụ IDE mặc định (`ask_question` modal popup hoặc tự ý nhảy vào Planning Mode), làm ẩn nội dung phân tích kiến trúc.
- **Giải pháp**: Đưa ra ràng buộc cấm tuyệt đối: Khi Requirement Confidence == LOW, cấm gọi `ask_question`, cấm tạo file plan, chỉ dùng read tools để inspect và bắt buộc xuất văn bản Markdown thẩm định kiến trúc kèm Ready-to-Use Prompts ra khung chat và dừng turn.
- **Quy tắc cho Agent**: Tuyệt đối không dùng modal hỏi đáp ẩn thay cho báo cáo minh bạch khi gặp yêu cầu mơ hồ hoặc chạm Vùng Đỏ.
