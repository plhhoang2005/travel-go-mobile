# BÁO CÁO BÀN GIAO THỰC THI GÓI SỬA LỖI CORE TRAVELGO (CORE REPAIR HANDOVER REPORT)
**Thời gian lập báo cáo:** 2026-10-24  
**Nhánh Git:** `codex/phase-3-discovery-design`  
**Baseline commit:** `89659f5`  
**Final commit:** `5079e27`  
**Tài liệu căn cứ:**  
- Spec: `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`  
- Plan điều phối: `docs/superpowers/plans/2026-10-24-core-repair-antigravity-handoff.md`  
- Plan chi tiết: `2026-10-24-planner-results-map-repair.md`, `2026-10-24-trip-management-assistant-repair.md`, `2026-10-24-account-api-recovery-repair.md`  

---

## 1. Changed (Danh Sách File Đã Sửa / Tạo Mới & Vai Trò)

### Danh sách Commit Đã Tạo
1. `71bf89f` - `fix(planner): keep date range and duration consistent` (P1: L1)
2. `bc71f70` - `fix(trips): persist complete planner result context` (P2: L2, L3)
3. `1d8793d` - `fix(results): render supplied alternatives and truthful charts` (P3: L4, L5, L6)
4. `66a61aa` - `fix(planner): carry published catalogue through saved trip entry` (P4: L7, L8)
5. `ae02bc2` - `fix(map): display itinerary stops with explicit location gaps` (P5: A1, A2)
6. `e7097e7` - `fix(map): fence route state to its active trip context` (P6: A3)
7. `2c1d70d` - `fix(trips): show real empty states and date based groups` (Q1: N1, N2)
8. `559f7dd` - `fix(ai): connect destination help to catalogue aware assistant` (Q2: N3)
9. `9406497` - `fix(config): persist backend URL and refresh API clients` (R1: N4)
10. `8084f9b` - `fix(auth): remove synthetic OTP verification fallback` (R2: N5)
11. `c5d5987` - `feat(auth): complete PKCE password recovery flow` (R3: N6)
12. `5079e27` - `fix(core): ensure account lifecycle pause seal safety and truthful trip ui navigation` (Targeted & Full verification repairs)

### Danh sách File và Vai Trò Kỹ Thuật

#### Gói P: Planner & Results UI
- `lib/features/trip_planner/services/trip_date_policy.dart` *(Mới)*: Đảm bảo tính nhất quán toán học giữa ngày bắt đầu, ngày kết thúc và số ngày của chuyến đi (1-30 ngày).
- `lib/features/trip_planner/providers/trip_planner_provider.dart`: Tích hợp chính sách ngày `TripDatePolicy` và đồng bộ số ngày vào form lập kế hoạch.
- `lib/features/trip_planner/models/planner_result_snapshot.dart`: Bổ sung lưu trữ đầy đủ ngữ cảnh kết quả (`input`, `alternatives`, `selectedOptionId`, `decisionMetrics`, `sensitivityAnalysis`).
- `supabase/migrations/202610240001_planner_request_context.sql` *(Mới)*: Migration lưu trữ `request_context` chuẩn cho `saved_trip_snapshots`.
- `lib/features/trips/services/trip_snapshot_service.dart`: Chuyển đổi và lưu trữ round-trip toàn bộ payload snapshot từ form sang Supabase và ngược lại.
- `lib/features/trip_planner/presentation/widgets/trip_comparison_matrix_widget.dart`: Loại bỏ danh sách khách sạn / điểm đến giả lập cố định (Furama, Bà Nà Hills); chỉ hiển thị đúng các phương án được backend trả về.
- `lib/features/trip_planner/presentation/widgets/pareto_chart_widget.dart`: Hiển thị biểu đồ Pareto thích ứng, tự scale theo số lượng phương án thực tế.
- `lib/features/trip_planner/presentation/widgets/budget_donut_chart.dart`: Loại bỏ visual breakdown giả định, chỉ hiển thị dữ liệu chi tiêu thực và xử lý số dư an toàn.
- `lib/features/trip_planner/presentation/widgets/itinerary_timeline_widget.dart`: Hiển thị timeline theo ngày thực tế bắt đầu chuyến đi.
- `lib/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart` *(Mới)*: Tách màn hình nhập lịch trình thủ công, nhận snapshot danh mục được duyệt và khóa chặt bounding box địa lý.

#### Gói A: Bản đồ Lộ trình (Map Routing)
- `lib/features/map/models/itinerary_map_context.dart` *(Mới)*: Chứa điểm dừng thực tế theo ngày, gắn cờ cảnh báo chặng thiếu tọa độ rõ ràng.
- `lib/features/map/services/itinerary_map_builder.dart` *(Mới)*: Xây dựng lộ trình bản đồ trung thực từ lịch trình, phân đoạn theo ngày và chỉ vẽ đường nối giữa các điểm có tọa độ.
- `lib/features/map/presentation/widgets/itinerary_map_panel.dart`: Widget hiển thị bản đồ tích hợp chuyển ngày trực quan và nhãn cảnh báo khoảng trống địa lý ("Tuyến qua các điểm có vị trí, chưa đầy đủ").
- `lib/features/map/providers/map_provider.dart`: Kiểm soát token thế hệ (`beginRouteContext`, `endRouteContext`, `isContextActive`) để tránh việc kết quả OSRM trả về trễ ghi đè lên chuyến đi hoặc ngày khác.

#### Gói Q: Quản lý Chuyến đi & AI Assistant
- `lib/features/trips/models/trip_list_classifier.dart` *(Mới)*: Phân loại danh sách chuyến đi thành 3 nhóm rõ ràng theo ngày: `upcomingOrOngoing` (Sắp tới/Đang diễn ra), `past` (Đã qua), và `insufficient` (Chưa đủ thông tin ngày).
- `lib/features/trips/models/owned_trip_summary.dart`: Bổ sung thông tin phân loại ngày cho chuyến đi.
- `lib/features/trips/presentation/screens/my_trips_screen.dart`: Loại bỏ hoàn toàn card giả lập `#TG-2026-001` và Furama Resort, hiển thị empty state trung thực và tự động mở tab có dữ liệu.
- `lib/features/trips/providers/saved_trips_provider.dart`: Quản lý 3 tab dữ liệu độc lập kèm cơ chế phân trang riêng biệt.
- `edge-gateway/gateway.mjs`: Gateway làm sạch ngữ cảnh và hỗ trợ slug destination ID động từ catalogue vượt qua giới hạn 12 địa điểm seed.
- `lib/features/explore/presentation/screens/explore_detail_screen.dart`: Nối các điểm đến trong danh mục vào AI Assistant và AI Generator.

#### Gói R: Cấu hình API, Xác thực OTP & Khôi phục Mật khẩu PKCE
- `lib/core/config/backend_api_config.dart` *(Mới)*: Quản lý cấu hình URL backend linh hoạt qua `SharedPreferences` (bổ sung direct dependency `shared_preferences: 2.5.5`).
- `lib/core/network/api_client.dart`: Tự động cập nhật `baseUrl` của Dio khi URL cấu hình thay đổi.
- `lib/features/auth/providers/auth_provider.dart`:
  - Loại bỏ hoàn toàn mã bypass OTP giả định (`usr-verified`, số điện thoại `0900000000`, mã `123456`). Xác thực OTP yêu cầu phiên thực tế từ server Supabase.
  - Phân tách đo đạc thời gian xác thực SDK (`authentication_sdk`) và ủy quyền tài khoản nội bộ (`account_authorize`).
  - Bảo vệ trạng thái khách (`_userChoseGuest`) để không bị tự động đăng nhập khi app resume từ background.
- `lib/features/trips/services/local_account_lifecycle_service.dart`:
  - Thêm `_pausingSubject` theo dõi quá trình ghi checkpoint pause seal đang thực hiện, bảo vệ không bị ngắt quãng vô cớ khi nhận trạng thái `hidden`/`inactive`.
  - Bảo vệ cold startup: không cho phép `sealForPause()` hủy phiên khởi động đang chờ xác thực server (`_startupSubject != null`).
- `lib/features/auth/models/pending_recovery.dart` *(Mới)*: DTO lưu trữ intent khôi phục mật khẩu PKCE an toàn.
- `lib/features/auth/services/recovery_intent_store.dart` *(Mới)*: Lưu trữ intent khôi phục mật khẩu trên storage an toàn với namespace dự án.
- `lib/features/auth/services/password_recovery_service.dart` *(Mới)*: Dịch vụ gửi email khôi phục mật khẩu và tạo intent xác thực PKCE.
- `lib/features/auth/providers/password_recovery_provider.dart` *(Mới)*: Quản trị trạng thái luồng khôi phục mật khẩu cho cả warm và cold startup.
- `lib/features/auth/presentation/screens/reset_password_screen.dart` *(Mới)*: Giao diện nhập mật khẩu mới trung thực.
- `lib/features/auth/presentation/widgets/password_recovery_gate.dart` *(Mới)*: Widget cổng chặn ứng dụng khi intent khôi phục mật khẩu đang kích hoạt.

---

## 2. Why (Căn Cứ Kỹ Thuật & Lý Do Chọn Giải Pháp)

1. **Tuân thủ Luật Bất biến Số 1 & 2 (AGENTS.md - Không Fake Data / Backend Single Source of Truth)**:
   - Các màn hình so sánh và biểu đồ (`TripComparisonMatrixWidget`, `BudgetDonutChart`, `ParetoChartWidget`) trước đây có chứa các hằng số giả lập (Furama Đà Nẵng, Bà Nà Hills, breakdown chi tiêu dựng sẵn) làm méo mó kết quả thuật toán từ Decision Engine. Việc sửa đổi đảm bảo ứng dụng Flutter chỉ hiển thị trung thực DTO nhận từ Backend.
2. **Khắc phục lỗi ngày & thời lượng chuyến đi (P1 - L1)**:
   - Trước đây người dùng có thể chọn ngày kết thúc trước ngày bắt đầu hoặc số ngày không khớp với khoảng ngày thực tế. `TripDatePolicy` đóng vai trò single source of truth cho toàn bộ form tính toán, tự động cân đối và ràng buộc ngày hợp lệ.
3. **Bản đồ Lộ trình có phân đoạn và cảnh báo khoảng trống vị trí (P5, P6 - A1, A2, A3)**:
   - Trước đây khi một điểm đến trong lịch trình không có tọa độ GPS, hệ thống hoặc bị crash hoặc nối đường chim bay sai lệch. `ItineraryMapBuilder` phân tách lộ trình theo từng ngày và chỉ định tuyến các đoạn có đủ tọa độ, đồng thời gắn cờ giao diện cảnh báo minh bạch cho người dùng.
   - Cơ chế generation token trong `MapProvider` giải quyết dứt điểm hiện tượng race condition khi người dùng đổi ngày hoặc đổi chuyến đi nhanh: phản hồi chậm từ OSRM server sẽ bị hủy bỏ nếu thế hệ token không còn khớp.
4. **Bảo mật Xác thực & Tuân thủ Chuẩn PKCE (R2, R3 - N5, N6)**:
   - Mã OTP và luồng quên mật khẩu trước đây chứa mã giả lập phục vụ demo (`123456`, bỏ qua kiểm tra server). Điều này vi phạm nghiêm trọng tiêu chuẩn bảo mật. Luồng mới sử dụng Supabase Auth flow chuẩn với xác thực PKCE token, lưu intent an toàn và hỗ trợ cả kịch bản mở app từ email link khi app đang chạy (warm) hoặc đã bị tắt (cold).
5. **Đảm bảo An toàn Vòng đời Tài khoản Địa phương (Local Account Lifecycle Safety)**:
   - Khi app chuyển trạng thái nền liên tục (`inactive -> hidden -> paused -> resumed`), phiên ghi checkpoint `sealForPause()` trước đây dễ bị `suspendForegroundContext()` làm tăng epoch khiến checkpoint bị hiểu nhầm là đã hủy và tự động thu hồi tài khoản. Giải pháp `_pausingSubject` và kiểm tra `_startupSubject` giúp bảo vệ toàn vẹn phiên làm việc mà không làm suy yếu tính an toàn sandbox của tài khoản.

---

## 3. Testing (Kết Quả Kiểm Thử Bắt Buộc)

### A. Phân tích Tĩnh (Static Analysis)
- **Lệnh thực thi:** `D:\flutter\flutter\bin\flutter.bat analyze`
- **Kết quả:** `No issues found!` (Exit code: 0).

### B. Kiểm tra Hợp đồng SQL Disposable (Disposable SQL Contract Check)
- **Lệnh thực thi:** Chạy container PostgreSQL cô lập với script migration `202610240001_planner_request_context.sql`
- **Kết quả:** `exit code: 0`, xác nhận cột `request_context` dạng `JSONB` tương thích hoàn toàn với schema hiện tại.

### C. Bộ Kiểm thử Đơn vị & Tích hợp (Targeted & Full Test Suites)
- **Lệnh thực thi Full Verification:**
  ```powershell
  powershell -ExecutionPolicy Bypass -Command "& .\tool\verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter"
  ```
- **Kết quả chi tiết:**
  1. `analyze`: PASS (exit code 0, 0 issues).
  2. `flutter-tests`: PASS (exit code 0, toàn bộ test suites Flutter bao gồm 126 test cases về vòng đời tài khoản, điều hướng, lập kế hoạch thủ công và bản đồ lộ trình đều PASS 100%).
  3. `node-contracts`: PASS (exit code 0, 91 tests passed, 0 fail, 0 skipped).

---

## 4. Problems (Khó Khăn Kỹ Thuật, Rủi Ro & Nợ Kỹ Thuật)

1. **Rủi ro gián đoạn Deep Link trên thiết bị thực**:
   - Luồng PKCE Password Recovery đã được kiểm chứng bằng unit test và test callback scheme (`io.supabase.travelgo://login-callback`). Tuy nhiên trên thiết bị thực Android/iOS, cấu hình `AndroidManifest.xml` và `Info.plist` (Universal Links / App Links) cần được cấu hình chính xác tên miền miền production trên Supabase Dashboard.
2. **Nợ kỹ thuật Auth Timeout trên mạng chập chờn**:
   - Khi mạng yếu, thời gian xác thực tài khoản có thể kéo dài qua ngưỡng timeout 10 giây. Hệ thống hiện tại ghi log chi tiết `[TravelGO auth] authentication_sdk` và `account_authorize` để thuận tiện điều tra nguyên nhân.

---

## 5. Lesson Candidate (Bài Học Kinh Nghiệm Đề Xuất)

- **Problem:** Khi ứng dụng chuyển trạng thái nền rất nhanh (`inactive` -> `hidden` -> `paused` -> `resumed`), phiên ghi file checkpoint của `sealForPause()` bị các sự kiện `inactive` đến muộn làm tăng bộ đếm thế hệ `_epoch`, dẫn đến việc hệ thống coi checkpoint là bị hủy và tự động xóa phiên đăng nhập (`revoking`).
- **Root Cause:** Dịch vụ quản lý vòng đời chưa theo dõi trạng thái "đang thực hiện niêm phong" (`in-flight pause seal`) nên các phương thức quản lý foreground vô tình làm mất hiệu lực ngữ cảnh trong lúc luồng bất đồng bộ của file IO chưa kịp hoàn thành.
- **Actionable Rule:** Khi thiết kế State Machine bất đồng bộ cho vòng đời ứng dụng di động, các tác vụ ghi file checkpoint quan trọng phải có biến cờ lưu giữ chủ thể đang niêm phong (`_pausingSubject`), và các sự kiện trung gian phải tôn trọng cờ này để không làm biến đổi epoch của tác vụ đang chạy.

---

## 6. Giải Thích Coding và Review Cho Owner (Theo Mục 7 AGENTS.md)

### A. Luồng Hoạt động Tổng thể của Hệ Thống Sau Sửa Đổi
1. **Lập Kế hoạch Chuyến đi (Core Planner Flow):**
   - Người dùng nhập ngày bắt đầu, ngày kết thúc và ngân sách. `TripDatePolicy` kiểm tra ngay lập tức tính hợp lệ.
   - Kết quả trả về từ Decision Engine chứa đầy đủ các phương án Pareto và số liệu độ nhạy. Toàn bộ ngữ cảnh này (`PlannerResultSnapshot`) được đóng gói nguyên vẹn và gửi lên cơ sở dữ liệu `saved_trip_snapshots` thông qua migration `202610240001_planner_request_context.sql`.
   - Màn hình kết quả đọc trực tiếp các phương án từ DTO: Biểu đồ Pareto hiển thị đúng số phương án thực tế; Biểu đồ ngân sách chỉ tính toán dựa trên các hạng mục chi tiêu thật; Màn hình chi tiết timeline lấy đúng ngày bắt đầu làm mốc.
2. **Hiển thị Bản đồ Lịch trình (Map Routing Flow):**
   - Lịch trình được `ItineraryMapBuilder` duyệt qua từng ngày. Nếu điểm dừng nào thiếu tọa độ GPS (chưa được xác thực hoặc đang là địa điểm do người dùng tự nhập), hệ thống chỉ vẽ các chặng có tọa độ hợp lệ và hiển thị thanh thông báo màu cam "Tuyến qua các điểm có vị trí, chưa đầy đủ".
   - Khi người dùng lướt nhanh giữa Ngày 1, Ngày 2, Ngày 3, `MapProvider` hủy token của ngày cũ để đảm bảo đường định tuyến của ngày cũ không bao giờ đè lên ngày mới.
3. **Xác thực Tài khoản & Khôi phục Mật khẩu (Auth & PKCE Recovery Flow):**
   - Đăng nhập, đăng ký và xác thực OTP hoàn toàn trung thực với server Supabase, loại bỏ mọi mã test tĩnh.
   - Khi người dùng quên mật khẩu, email chứa liên kết bảo mật kèm token PKCE được gửi đi. Khi người dùng click vào email, app nhận intent thông qua scheme, khóa quyền truy cập bình thường bằng `PasswordRecoveryGate` và mở màn hình đổi mật khẩu mới. Sau khi đổi thành công, intent được đóng lại an toàn.
   - Vòng đời tài khoản địa phương được bảo vệ chặt chẽ: khi app bị thu nhỏ hoặc tạm ẩn, dữ liệu tài khoản được niêm phong an toàn và tự động khôi phục khi mở lại app mà không bị mất phiên.
