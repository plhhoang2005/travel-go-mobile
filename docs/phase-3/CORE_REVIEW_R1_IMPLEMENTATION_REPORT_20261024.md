# BÁO CÁO BÀN GIAO THỰC THI GÓI CORE REVIEW R1 (CR1–CR7)

> **Mã công việc:** Core Review R1 Implementation & Verification  
> **Tài liệu bàn giao:** `docs/superpowers/plans/2026-10-24-core-review-r1-antigravity-handoff.md`  
> **Thực thi bởi:** Antigravity (Implementation & Test Runner)  
> **Reviewer đối tác:** Codex (Stage-Gate Review)  
> **Thời điểm hoàn tất:** 2026-10-24 12:31:00 +07:00  

---

## 1. Changed (Danh Sách File Đã Sửa / Tạo Mới)

| File | Trạng thái | Vai trò kỹ thuật |
| :--- | :--- | :--- |
| `lib/features/auth/models/password_recovery_state.dart` | Modified | Thêm các pha phục hồi tài khoản (`exchanging`, `updating`, `cleanupRequired`, `uncertain`, `failedRecoverable`), model `PendingRecovery` mở rộng với `updatedAtUtc`, cờ `dropUpdateAck` và authority fences. |
| `lib/features/auth/services/recovery_intent_store.dart` | Modified | Store bền vững SharedPreferences lưu trữ và đối soát intent recovery, kiểm tra snapshot atomic và huỷ bỏ stale marker nếu đổi intent. |
| `lib/features/auth/providers/password_recovery_provider.dart` | Modified | Provider trung tâm quản lý luồng khôi phục mật khẩu, hàng đợi huỷ bỏ (cancellation fencing), giải phóng session, bootstrap idempotent qua app_links, và cleanup-only retry. |
| `lib/features/auth/presentation/widgets/password_recovery_gate.dart` | Modified | Widget cổng điều hướng auth: giữ `ResetPasswordScreen` ổn định khi đang cập nhật/lỗi hồi phục được, hiển thị màn hình lỗi nghiêm trọng và xử lý chuyển tiếp về Login khi hoàn tất. |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` | Modified | Giao diện đặt lại mật khẩu: hiển thị banner cảnh báo trạng thái `uncertain`, ẩn nút submit khi đang dọn dẹp hoặc trạng thái không chắc chắn. |
| `lib/features/map/providers/map_provider.dart` | Modified | Phân lập lộ trình lịch trình: entry `initItineraryRoute` chỉ nhận các điểm tham quan đã định vị (`first` là origin, `last` là destination); fence `_routeContextGeneration` trên từng context; bắt `BackendConfigChangedException` để invalidate route thay vì vẽ đường thẳng offline giả mạo. |
| `lib/features/map/presentation/screens/trip_map_screen.dart` | Modified | Quản lý vòng đời màn hình bản đồ: cấp token `beginRouteContext()` mới mỗi khi chuyển ngày (`onDaySelected`) hoặc đổi liên kết địa điểm (`onPlaceBound`); cache reference `MapProvider` để `dispose()` dọn đúng token sở hữu; chặn camera di chuyển từ context cũ. |
| `lib/features/map/services/map_api_service.dart` | Modified | Kiểm soát cấu hình backend và OSRM: truyền `configRevision` vào `_fetchDirectOsrmRoute`, ném `BackendConfigChangedException` nếu revision thay đổi trước/sau khi gọi OSRM hoặc khi OSRM timeout/lỗi. |
| `lib/main.dart` | Modified | Cho phép inject `authProvider` vào `TravelGoApp` phục vụ test harness widget. |
| `test/password_recovery_authority_test.dart` | Created | Test suite cho Task A1 (CR2): kiểm chứng authority, huỷ bỏ intent cũ khi intent mới được kích hoạt, đăng nhập mới đợi dọn dẹp intent cũ. |
| `test/password_recovery_callback_race_test.dart` | Created | Test suite cho Task A2 (CR5): kiểm chứng callback idempotency giữa warm (stream) và cold (initial link), bootstrap ordering. |
| `test/password_recovery_cleanup_test.dart` | Created | Test suite cho Task A3 (CR6): kiểm chứng write-ahead logging cập nhật mật khẩu, xử lý `uncertain`, và cơ chế cleanup-only retry. |
| `test/password_recovery_gate_test.dart` | Created | Test suite cho Task A4 (CR1): kiểm chứng `PasswordRecoveryGate` giữ form qua các pha cập nhật và lỗi, xử lý bootstrap timer. |
| `test/dashboard_itinerary_map_test.dart` | Modified | Test suites cho Task B1 (CR3), Task B2 (CR4), Task B3 (CR7): kiểm chứng route lịch trình không phụ thuộc GPS, phân lập ngữ cảnh đổi ngày/chuyển tab, loại bỏ stale polyline/camera. |
| `test/backend_url_clients_test.dart` | Modified | Test suites cho Task B3 (CR7): kiểm chứng Dio adapter bắt `BackendConfigChangedException` xuyên suốt cả nhánh backend lỗi và OSRM fallback. |

---

## 2. Why (Căn Cứ Kỹ Thuật & Kiến Trúc)

1. **Phân quyền và bảo mật Recovery PKCE (CR2, CR5, CR6, CR1):**
   - Tránh tình trạng người dùng yêu cầu recovery nhiều lần hoặc race condition giữa deep link khởi động lạnh (initial link) và stream chạy ngầm (warm callback). Mỗi intent recovery được gắn định danh và snapshot thời gian trong persistent store.
   - Khi có intent mới hoặc người dùng đăng nhập tài khoản khác, intent cũ phải được giải phóng hoàn toàn và huỷ bỏ toàn bộ mutation đang chờ.
   - Thao tác cập nhật mật khẩu tuân thủ nguyên lý *Write-Ahead Logging*: ghi nhận pha `updating` trước khi gửi lệnh lên server. Nếu server phản hồi không chắc chắn (timeout/drop ACK), hệ thống chuyển sang trạng thái `uncertain` và chỉ cho phép dọn dẹp (cleanup-only retry), không được thực thi đè mật khẩu mới.
   - Form đặt lại mật khẩu (`ResetPasswordScreen`) được giữ nguyên vẹn trên cây widget trong suốt quá trình cập nhật để không làm mất trải nghiệm người dùng, chỉ điều hướng về đăng nhập khi dọn dẹp hoàn tất.

2. **Trung thực về tuyến đường bản đồ lịch trình & Phân lập ngữ cảnh (CR3, CR4, CR7):**
   - Lộ trình tham quan trong ngày phải xuất phát từ điểm tham quan đầu tiên (`first located stop`), đi qua các điểm giữa (`waypoints`), và kết thúc tại điểm cuối (`last located stop`). Tuyệt đối không chèn GPS vật lý của người dùng (ví dụ: đang ở TP.HCM nhưng xem lịch trình ở Huế) vào chuỗi tham quan.
   - Mỗi lần đổi ngày hoặc thay đổi địa điểm trong lịch trình phải sinh một `routeContextGeneration` mới. Toàn bộ kết quả mạng trả về muộn (late responses), lỗi OSRM cũ hoặc animation camera của ngày cũ đều bị chặn không cho cập nhật lên UI ngày mới.
   - Khi cấu hình backend URL/revision thay đổi, toàn bộ tác vụ định tuyến OSRM đang chờ phải bị vô hiệu hóa thông qua `BackendConfigChangedException` và xoá sạch route cũ, không được biến tướng thành đường thẳng offline giả mạo.

---

## 3. Testing (Kết Quả Kiểm Thử Thực Tế)

### A. Static Analysis
- **Lệnh thực hiện:** `flutter analyze`
- **Kết quả:** `No issues found! (ran in 3.0s)` (Exit Code 0).

### B. Targeted Suites (Core Review R1 Focus)
- **Lệnh thực hiện:**  
  `powershell -ExecutionPolicy Bypass -Command "D:/flutter/flutter/bin/flutter.bat test test/password_recovery_authority_test.dart test/password_recovery_callback_race_test.dart test/password_recovery_cleanup_test.dart test/password_recovery_gate_test.dart test/password_recovery_cold_start_test.dart test/auth_navigation_test.dart test/dashboard_itinerary_map_test.dart test/backend_url_clients_test.dart test/backend_api_config_test.dart"`
- **Kết quả:** **120 tests passed, 0 failed** (Exit Code 0).

### C. Full Verification Suite
- **Lệnh thực hiện:**  
  `powershell -ExecutionPolicy Bypass -Command "& ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter"`
- **Kết quả:**
  - `analyze`: **PASS (exit 0)**
  - `flutter-tests`: **PASS (exit 0)**
  - `node-contracts`: **91/91 PASS (exit 0)**
  - Log lưu trữ tại: `.dart_tool/travelgo-verification/20261024T052756630Z-27920/`

### D. Runtime QA Check
- **Trạng thái:** **NOT RUN** (Do môi trường local hiện tại không kết nối thiết bị emulator/thiết bị thật có phiên chạy thử QA an toàn; đã tuân thủ nghiêm ngặt quy định không tự ý deploy/build live giả mạo kết quả).

---

## 4. Problems (Khó Khăn Kỹ Thuật, Rủi Ro & Biện Pháp Đã Xử Lý)

1. **Deadlock Completer trong FakeAsync Zone của Flutter Test:**
   - *Vấn đề:* Khi chạy widget test với `TravelGoApp`, các animation timers và microtask loops nếu dùng Completer chờ lẫn nhau qua zone có thể gây treo vô thời hạn (như từng gặp ở lượt chạy 7+ phút trước).
   - *Giải pháp:* Thiết kế `ControllableRecoveryService` và `ControllableMapApiService` với khả năng kích hoạt trực tiếp `rejectWith` hoặc hoàn tất đồng bộ theo danh sách cuộc gọi độc lập (`RecordedRouteCall`), unmount cây widget bằng `SizedBox.shrink()` và xả hết timer rác trước khi kết thúc test.
2. **Leak RouteContext khi chuyển ngày liên tục:**
   - *Vấn đề:* Widget `TripMapScreen` trước đây chỉ gọi `beginRouteContext()` một lần tại `initState()`, dẫn đến khi người dùng chuyển từ Ngày 1 sang Ngày 2 rồi Ngày 3, các yêu cầu OSRM trả về trễ của Ngày 1 vẫn có token hợp lệ và ghi đè polyline lên Ngày 2.
   - *Giải pháp:* Cấp token mới tại `onDaySelected` và `onPlaceBound`, đồng thời cache reference `MapProvider` để `dispose()` giải phóng đúng token sở hữu mà không tra cứu vào BuildContext đã ngắt kết nối.
3. **Lỗi biến ngoại lệ thành đường thẳng giả mạo:**
   - *Vấn đề:* Khi `BackendConfigChangedException` xảy ra trong `MapProvider._fetchRoute`, catch block mặc định coi đó là lỗi mạng không xác định và tự động vẽ đường thẳng nối các toạ độ (`_generateLocalOfflineLine()`).
   - *Giải pháp:* Bắt tường minh `on BackendConfigChangedException`, huỷ bỏ lộ trình (`_currentRoute = null`) và yêu cầu người dùng tải lại lộ trình.

---

## 5. Lesson Candidate (Bài Học Kinh Nghiệm Kỹ Thuật)

- **Problem:** Khi chuyển đổi màn hình hoặc chọn các tab/ngày liên tiếp trong Flutter, các phản hồi API hoặc animation camera chạy ngầm của lượt tương tác trước có thể làm sai lệch dữ liệu và giật camera của lượt tương tác mới.
- **Root Cause:** Quản lý vòng đời bất đồng bộ phụ thuộc vào cờ mounted đơn thuần mà không có **Context Generation Token Fencing** để gắn định danh độc nhất cho từng phiên tương tác I/O.
- **Actionable Rule:** Bắt buộc áp dụng cơ chế cấp số thế hệ tăng dần (`routeContextGeneration`) cho mọi luồng tải dữ liệu có nhiều pha (I/O, fallback, animation). Mọi điểm hoàn tất dữ liệu (`success`, `error`, `finally`, `camera animation`) đều phải đối soát token phiên trước khi ghi nhận trạng thái lên State/Provider.

---

## 6. Bảng Đối Chiếu Phát Hiện Core Review (CR1–CR7)

| Mã | Nội dung phát hiện & Mục tiêu sửa | File liên quan | Test chứng minh | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| **CR1** | `PasswordRecoveryGate` không được unmount form reset khi đang cập nhật; giữ form trên các pha lỗi hồi phục được. | `password_recovery_gate.dart`, `reset_password_screen.dart` | `test/password_recovery_gate_test.dart` (6 tests) | **PASSED (exit 0)** |
| **CR2** | Phân quyền Recovery Authority: Intent mới huỷ bỏ mutation cũ; đăng nhập mới chờ dọn dẹp intent cũ; không tự động phát tán session khi resume. | `recovery_intent_store.dart`, `password_recovery_provider.dart` | `test/password_recovery_authority_test.dart` (5 tests) | **PASSED (exit 0)** |
| **CR3** | Tuyến đường bản đồ lịch trình có origin thực: Điểm xuất phát là điểm tham quan đầu tiên có toạ độ, không lấy GPS hiện tại của người dùng. | `map_provider.dart`, `trip_map_screen.dart` | `test/dashboard_itinerary_map_test.dart` (Task B1: 4 tests) | **PASSED (exit 0)** |
| **CR4** | Phân lập ngữ cảnh đổi ngày/đổi địa điểm: Token mới cho mỗi lần đổi ngày; phản hồi muộn của Ngày 1 không đè Ngày 2; camera không giật. | `map_provider.dart`, `trip_map_screen.dart` | `test/dashboard_itinerary_map_test.dart` (Task B2: 6 tests) | **PASSED (exit 0)** |
| **CR5** | Xử lý race condition giữa warm (stream) và cold (initial link) deep link; đảm bảo bootstrap idempotent và không chạy song song. | `password_recovery_provider.dart` | `test/password_recovery_callback_race_test.dart` (4 tests) | **PASSED (exit 0)** |
| **CR6** | Cập nhật mật khẩu bền vững: Write-ahead logging cho phase `updating`, xử lý `uncertain` và cơ chế chỉ cho phép retry cleanup. | `password_recovery_state.dart`, `password_recovery_provider.dart` | `test/password_recovery_cleanup_test.dart` (5 tests) | **PASSED (exit 0)** |
| **CR7** | Rào chắn cấu hình URL/Revision bao quát toàn bộ OSRM fallback và MapProvider: Loại bỏ stale retry khi đổi host, không vẽ đường thẳng giả mạo. | `map_api_service.dart`, `map_provider.dart` | `test/backend_url_clients_test.dart` (7 tests), `dashboard_itinerary_map_test.dart` (Task B3: 1 test) | **PASSED (exit 0)** |

---

## 7. Giải Thích Dành Cho Owner (Bắt Buộc Theo Quy Tắc Owner Learning)

Kính gửi Owner, dưới đây là tóm tắt bản chất kỹ thuật của các vấn đề đã được giải quyết trong gói Core Review R1:

1. **Luồng Khôi Phục Mật Khẩu (Recovery Flow - CR1, CR2, CR5, CR6):**
   - **Vấn đề trước đây:** Khi người dùng bấm link khôi phục mật khẩu từ email, nếu ứng dụng mở lạnh (cold start) kết hợp với luồng app links ngầm, hệ thống có thể bị gọi 2 lần (race condition), hoặc nếu người dùng đổi ý bấm "Quên mật khẩu" lần nữa thì token cũ và token mới tranh chấp nhau trong bộ nhớ. Đặc biệt, khi bấm "Cập nhật mật khẩu", nếu mạng chập chờn, giao diện bị văng về màn hình đăng nhập hoặc hiển thị lỗi không rõ ràng.
   - **Cách giải quyết:** Chúng tôi áp dụng cơ chế **Thẻ Định Danh Intent (Intent Fencing)** và **Ghi Nhật Ký Trước (Write-Ahead Logging)**:
     - Mỗi phiên khôi phục có mã ID riêng. Bất kỳ intent mới nào xuất hiện sẽ lập tức huỷ bỏ quyền hạn của intent cũ.
     - Form nhập mật khẩu mới được giữ cố định trên màn hình, không bị giật hay unmount đột ngột.
     - Khi gửi mật khẩu mới lên server, trạng thái được lưu tạm là "đang cập nhật". Nếu server phản hồi mơ hồ, ứng dụng chuyển sang trạng thái an toàn ("chờ dọn dẹp") thay vì để người dùng gửi liên tiếp gây lỗi mật khẩu.

2. **Luồng Bản Đồ Lịch Trình (Itinerary Map - CR3, CR4, CR7):**
   - **Vấn đề trước đây:** 
     - Khi xem bản đồ lịch trình cho chuyến đi Huế, bản đồ lại lấy toạ độ GPS của điện thoại (ví dụ đang ở TP.HCM) làm điểm bắt đầu, dẫn đến lộ trình vẽ một đường dài hàng trăm km từ TP.HCM ra Huế.
     - Khi bấm chuyển từ Ngày 1 sang Ngày 2, nếu mạng của Ngày 1 phản hồi chậm hơn Ngày 2, kết quả Ngày 1 về sau sẽ đè lên Ngày 2 và giật camera về lại địa điểm Ngày 1.
     - Khi địa chỉ máy chủ backend thay đổi, hệ thống fallback lại tự động vẽ một đường thẳng offline vô nghĩa.
   - **Cách giải quyết:**
     - Tách riêng hàm `initItineraryRoute`: Điểm đầu tiên của tuyến đường luôn là điểm tham quan đầu tiên của ngày, không bao giờ hỏi quyền GPS hay chèn GPS người dùng vào lộ trình tham quan.
     - Mỗi lần đổi ngày hoặc gắn địa điểm mới, một mã số thế hệ (`token`) mới được sinh ra. Bất kỳ phản hồi mạng nào của ngày cũ trả về muộn đều bị huỷ bỏ, camera chỉ di chuyển theo ngày người dùng đang chọn.
     - Khi cấu hình IP/URL backend thay đổi, hệ thống huỷ ngay lộ trình cũ và yêu cầu tải lại, không vẽ đường thẳng giả mạo.

---

## 8. Prompt Gửi Lại Cho Codex Review

```markdown
Kính gửi Codex,

Antigravity đã hoàn thành 100% việc sửa code và kiểm thử gói Core Review R1 (CR1–CR7) theo đúng kế hoạch tại `docs/superpowers/plans/2026-10-24-core-review-r1-antigravity-handoff.md` cùng hai kế hoạch chi tiết `core-review-r1-recovery.md` và `core-review-r1-map-api.md`.

Các bằng chứng kiểm thử thực tế đã đạt:
1. `flutter analyze`: 0 issues found (exit 0).
2. 9 bộ test suites trọng tâm (CR1–CR7): 120/120 tests passed (exit 0).
3. `verify-travelgo.ps1 -Mode Full`: analyze PASS (exit 0), flutter-tests PASS (exit 0), node-contracts 91/91 PASS (exit 0).
4. Không có commit/push/merge tự ý; toàn bộ dirty files của owner được giữ nguyên vẹn.

Báo cáo bàn giao chi tiết đã được xuất tại:
`docs/phase-3/CORE_REVIEW_R1_IMPLEMENTATION_REPORT_20261024.md`

Xin mời Codex tiến hành thẩm định và review toàn bộ gói bàn giao Core Review R1.
```

