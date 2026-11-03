# Kế hoạch & Screen Inventory: TravelGO Mobile Product UX Redesign V2

**Ngày lập:** 2026-11-03  
**Nhánh công việc:** `feat/ui-ux-polishing` (Base: `feat/team-integration-v1`)  
**Người thực hiện:** Thành viên 2 (UI/UX Polishing)  
**Tài liệu tham chiếu hình ảnh:** `img/fb5a5ca9-9c12-4c3d-b0bc-267ab4174bc1.png` và `img/anhdemo.png`  
**Nguyên tắc tối thượng:** *Beautiful UI + Real Data + Working Features + No Business Logic Regression*

---

## I. Screen Inventory & UX Audit Toàn Bộ Ứng Dụng (Phase 0)

| STT | Màn hình / Route | File Flutter | Mục đích | Thao tác chính | Nguồn dữ liệu | Vấn đề UI/UX hiện tại | Mức độ ưu tiên | Phạm vi |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| 1 | **Home** | `lib/features/home/presentation/screens/main_home_screen.dart` | Trang chủ đón người dùng, truy cập nhanh tính năng | Tìm kiếm, chọn tag sở thích, tạo chuyến đi nhanh, mở GoAI | `DiscoveryProvider`, `AuthProvider` | Đã hoàn thiện Phase 1 trước đó; cần giữ vững tính nhất quán và nhãn chính xác. | Cao | TV2 |
| 2 | **Explore** | `lib/features/explore/presentation/screens/explore_screen.dart` | Danh sách khám phá điểm đến | Tìm kiếm điểm đến, lọc vùng miền (Bắc/Trung/Nam), chọn điểm đến | `DiscoveryProvider` | Cần đồng bộ search bar và filter chips dạng pill giống màn 2 trong ảnh V2. | Trung bình | TV2 |
| 3 | **Destination Detail** | `lib/features/explore/presentation/screens/destination_detail_screen.dart` | Xem thông tin chi tiết một địa danh | Xem tổng quan, danh sách điểm tham quan, đánh giá, "+ Lập chuyến đi" | `PublicCatalogueProvider`, `PlaceVisitDetailsProvider` | Quá nhiều văn bản metadata dài ở đầu trang; toàn bộ danh sách điểm tham quan và form đánh giá bị dồn chung một trang gây rối mắt. | **Rất cao (P1)** | TV2 |
| 4 | **Place Visit Details** | `lib/features/explore/presentation/widgets/place_visit_details_widget.dart` | Chi tiết điểm tham quan bên trong địa danh | Xem giá vé, giờ mở cửa, điều kiện tham quan, nguồn thông tin | `PlaceVisitDetailsProvider` | Bị chôn dưới dạng card phẳng trên màn cha, cần luồng xem chi tiết hoặc BottomSheet/Screen con trực quan. | **Rất cao (P1)** | TV2 |
| 5 | **Place Reviews** | `lib/features/reviews/presentation/widgets/place_review_tile.dart` & `place_reviews_section.dart` | Đánh giá & nhận xét điểm tham quan | Đọc đánh giá, gửi review, xem sao | `PlaceReviewsProvider` / Supabase | Chưa có cơ chế "Xem thêm / Thu gọn" cho review dài (bị tràn hoặc quá dài); cần tóm tắt thanh phân bố rating (5-4-3-2-1). | **Rất cao (P1)** | TV2 |
| 6 | **Home Planner (Lập chuyến đi)** | `lib/features/trip_planner/presentation/screens/home_planner_screen.dart` | Tạo kế hoạch chuyến đi (điểm đến, ngày, người, ngân sách, sở thích) | Chọn điểm đến, ngày đi, số người, ngân sách, tạo lịch với GoAI | `PlannerInputProvider`, `TripProvider` | Giao diện còn dạng form kéo thả dài; cần tổ chức theo các khối/bước trực quan (Destination -> Time -> People -> Budget) bám sát màn 6 V2. | **Rất cao (P2)** | TV2 |
| 7 | **Trip Editing & Save Preview** | `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart` & `lib/features/trip_planner/presentation/widgets/manual_save_preview.dart` | Chỉnh sửa chuyến đi đã lưu & xem trước diff thay đổi | Sửa thông tin, xem diff, xác nhận lưu thay đổi | `ManualPlannerProvider`, `EditableTripService` | Diff trước đây hiển thị so sánh thừa khi không đổi; cần cấu trúc "Tóm tắt -> Chọn mục sửa -> Xác nhận thay đổi thực tế" bám sát màn 7 V2. | **Rất cao (P2)** | TV2 |
| 8 | **Community Feed** | `lib/features/community/presentation/screens/community_feed_screen.dart` | Dòng thời gian chia sẻ chuyến đi cộng đồng | Tìm kiếm bài viết, lọc tab (Bài viết / Chuyến đi / Theo dõi), mở chi tiết | `CommunityService` | Đã nâng cấp card; cần đồng bộ header search & filter chips dạng pill. | Trung bình | TV2 |
| 9 | **Shared Trip Detail** | `lib/features/community/presentation/screens/shared_trip_detail_screen.dart` | Chi tiết chuyến đi cộng đồng | Xem tổng quan, lịch trình các ngày, đánh giá chuyến đi, Sao chép chuyến đi | `CommunityService` | Lịch trình các ngày không hiển thị dù clone vẫn có dữ liệu; cần sửa trích xuất và hiển thị timeline ngày 1, ngày 2 bám sát màn 9 V2. | **Rất cao (P3)** | TV2 |
| 10 | **Profile Screen** | `lib/features/profile/presentation/screens/profile_screen.dart` | Trang cá nhân, cài đặt & thông tin tài khoản | Xem thông tin, chỉnh sửa hồ sơ, avatar, chuyển ngôn ngữ, đăng xuất | `AuthProvider` | Avatar hiện tại chưa có nút bấm chỉnh sửa rõ ràng; cần bổ sung modal/sheet đổi avatar bằng URL hoặc bộ avatar du lịch có sẵn. | **Cao (P4)** | TV2 |
| 11 | **My Trips** | `lib/features/trips/presentation/screens/my_trips_screen.dart` | Quản lý danh sách chuyến đi của tôi | Xem danh sách tab (Sắp/đang đi, Đã qua ngày, Chưa đủ thông tin), mở xem chi tiết | `SavedTripsProvider` | Đã sạch đẹp; cần kiểm tra responsive padding và giữ nguyên card status badge. | Trung bình | TV2 |
| 12 | **AI Chatbot** | `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart` | Trò chuyện cùng trợ lý GoAI toàn cục | Gửi tin nhắn, chọn chip câu hỏi nhanh, xem phản hồi AI | `AiChatProvider` | Đã có GoAI hero; cần đảm bảo tương tác floating button toàn cục mượt mà. | Hoàn thành | TV2 |

---

## II. Kế Hoạch 7 Phase Triển Khai (Thực thi độc lập & có kiểm thử)

### Phase 0: Audit & Screen Inventory (Hoàn thành trong văn bản này)
- Lập bảng danh mục màn hình, đánh giá hiện trạng và xác định file can thiệp.

### Phase 1: Destination Experience Redesign (Ưu tiên 1)
- Tái cấu trúc `destination_detail_screen.dart` theo 3 tab rõ ràng (Tổng quan | Điểm tham quan | Đánh giá) bám sát ảnh V2 màn 3, 4, 5.
- Đưa thông tin nguồn & metadata kỹ thuật vào expandable section "Thông tin & nguồn".
- Danh sách điểm tham quan hiển thị dạng Card trực quan có ảnh, tên, mô tả ngắn, trạng thái và chevron `>`.
- Khi bấm vào card điểm tham quan, mở chi tiết điểm tham quan đó (sheet hoặc dialog chi tiết) với đầy đủ thông tin vé, giờ mở cửa.
- Triển khai tính năng **"Xem thêm / Thu gọn"** cho các nhận xét dài tại `place_review_tile.dart` (mặc định tối đa 3 dòng).
- Bổ sung thanh phân bố sao (Rating summary 5-4-3-2-1) trực quan.

### Phase 2: Trip Planner & Trip Editing Redesign (Ưu tiên 2)
- Tối ưu `home_planner_screen.dart` thành các khối tham số trực quan (Điểm đến, Thời gian, Số người, Ngân sách ước tính) bám sát ảnh V2 màn 6.
- Tối ưu `editable_trip_detail_screen.dart` và `manual_save_preview.dart`:
  - Loại bỏ các dòng so sánh vô nghĩa (`3 ngày -> 3 ngày`).
  - Chỉ hiển thị thay đổi khi giá trị thực sự khác nhau.
  - Nếu không có thay đổi, thông báo: "Bạn chưa thay đổi thông tin nào."
  - Giữ nguyên 100% các ràng buộc cảnh báo chi phí, logic ngày và validation.

### Phase 3: Community Experience & Itinerary Fix (Ưu tiên 3)
- Điều tra và sửa lỗi trích xuất `itineraryDays` trong `shared_trip_detail_screen.dart` (hỗ trợ đọc cả `itineraryDays`, `itinerary_days`, `days`, `plan.itineraryDays`, json string).
- Thiết kế giao diện hiển thị lịch trình theo ngày dạng Timeline / Day Card (Ngày 1: Hà Nội -> Sa Pa, Ngày 2: ...) bám sát ảnh V2 màn 9.
- Đảm bảo dữ liệu thật 100%, không sinh lịch trình giả.

### Phase 4: Personal Profile Redesign (Ưu tiên 4)
- Tối ưu giao diện `profile_screen.dart`: Avatar tròn lớn có icon camera/edit ở góc dưới bên phải bám sát ảnh V2 màn 10.
- Xây dựng BottomSheet đổi ảnh đại diện (Đổi bằng URL / Chọn avatar mẫu TravelGO / Thông báo trạng thái thiết bị trung thực).
- Kiểm tra chặt chẽ: chỉ tài khoản có role Admin mới hiển thị badge `ADMIN` và mục Quản trị.

### Phase 5: Global Consistency & GoAI
- Kiểm tra tính hiện diện của nút nổi GoAI toàn cục trên tất cả các màn hình sau đăng nhập.
- Đảm bảo GoAI không che lấp các nút dính (sticky CTA) ở đáy màn hình.

### Phase 6: QA, Responsive & Real Device Verification
- Chạy `flutter analyze` đảm bảo 0 cảnh báo.
- Chạy toàn bộ các test suite liên quan (`flutter test`).
- Báo cáo bàn giao theo Quy tắc 7 và tiêu chuẩn bắt buộc.
