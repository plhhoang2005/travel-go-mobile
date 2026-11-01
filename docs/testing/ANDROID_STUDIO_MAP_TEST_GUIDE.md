# 🗺️ HƯỚNG DẪN TEST TÍNH NĂNG BẢN ĐỒ KHÁM PHÁ (THÀNH VIÊN 2) TRÊN ANDROID STUDIO

Tài liệu này cung cấp hướng dẫn chi tiết và các cấu hình chạy trực tiếp để kiểm thử, đánh giá tính năng **Bản đồ Khám phá (Interactive Map)** của **Thành viên 2** đồ án TravelGO trên Android Studio.

---

## 📋 I. BẢNG KIỂM TRA ĐỐI CHIẾU YÊU CẦU THÀNH VIÊN 2

| Yêu cầu từ Nhóm trưởng | Hiện trạng triển khai | File mã nguồn đảm nhiệm | Đánh giá |
| :--- | :--- | :--- | :---: |
| **Dùng `flutter_map` (OpenStreetMap miễn phí)** | Đã tích hợp `flutter_map: ^7.0.2` & `latlong2: ^0.9.1`, kết nối OpenStreetMap tiles tiêu chuẩn không cần API key. | [pubspec.yaml](file:///c:/flutter/travel-go-mobile/pubspec.yaml#L50-L51)<br>[catalogue_discovery_map_screen.dart](file:///c:/flutter/travel-go-mobile/lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart#L421-L428) | ✅ ĐẠT 100% |
| **Hiện các Điểm đến $\rightarrow$ bấm vào tự zoom và bung các Địa điểm con** | Ở chế độ toàn cảnh (Zoom 6.0) hiện các Điểm đến (Đà Lạt, Đà Nẵng, Hà Nội...). Bấm vào một Điểm đến sẽ tự động animate zoom (mức 13.0) và bung toàn bộ địa điểm con bên trong. | [catalogue_discovery_map_screen.dart](file:///c:/flutter/travel-go-mobile/lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart#L146-L161) | ✅ ĐẠT 100% |
| **Hiệu ứng Rating** ($\ge 4.5$ sao to & vàng rực rỡ ⭐; ít sao thì nhỏ/xám) | Địa điểm $\ge 4.5$ sao: Marker to 38px, màu vàng hổ phách rực rỡ, viền phát sáng (Glow), icon ngôi sao ⭐.<br>Địa điểm $3.5 - 4.4$ sao: Marker 32px màu xanh ngọc.<br>Địa điểm $< 3.5$ sao / mới: Marker 26px màu xám gọn gàng. | [catalogue_map_marker.dart](file:///c:/flutter/travel-go-mobile/lib/features/map/models/catalogue_map_marker.dart#L33-L79)<br>[catalogue_discovery_map_screen.dart](file:///c:/flutter/travel-go-mobile/lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart#L327-L378) | ✅ ĐẠT 100% |
| **Giữ nguyên nhãn chủ quyền Hoàng Sa & Trường Sa** | Lớp `VietnameseSovereigntyLayer` ghim cố định 2 quần đảo **Hoàng Sa (Đà Nẵng)** và **Trường Sa (Khánh Hòa)** với cờ đỏ sao vàng khẳng định chủ quyền biển đảo Việt Nam. | [vietnamese_sovereignty_layer.dart](file:///c:/flutter/travel-go-mobile/lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart#L8-L65) | ✅ ĐẠT 100% |
| **Không cần làm đường kẻ lộ trình** | Tuân thủ tuyệt đối: Không vẽ polyline OSRM phức tạp gây rối bản đồ, tập trung hoàn toàn vào trải nghiệm khám phá danh mục. | — | ✅ TUÂN THỦ |
| **Tự đồng bộ khi Admin sửa/ẩn địa điểm** | Đọc dữ liệu trực tiếp từ `PublicCatalogueSnapshot` / `DiscoveryProvider`. Khi Admin ẩn hoặc sửa dữ liệu, bản đồ cập nhật ngay lập tức. | [catalogue_discovery_map_screen.dart](file:///c:/flutter/travel-go-mobile/lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart#L67-L92) | ✅ ĐẠT 100% |

---

## 🚀 II. CÁC FILE ĐÃ TẠO ĐỂ TEST TRÊN ANDROID STUDIO

1. **File chạy trực tiếp độc lập (Standalone Preview):**
   * Đường dẫn: [`lib/main_map_preview.dart`](file:///c:/flutter/travel-go-mobile/lib/main_map_preview.dart)
   * **Công dụng:** Mở trực tiếp màn hình Bản đồ Khám phá với đầy đủ dữ liệu mẫu (Đà Lạt, Đà Nẵng, Hà Nội, Phú Quốc) kèm nút giả lập Admin Ẩn/Hiện địa điểm theo thời gian thực mà **không cần đăng nhập hay khởi động server backend**.

2. **Cấu hình chạy 1-Click trên Android Studio:**
   * File cấu hình:
     * [`.idea/runConfigurations/TravelGO_Map_Interactive_Preview.xml`](file:///c:/flutter/travel-go-mobile/.idea/runConfigurations/TravelGO_Map_Interactive_Preview.xml)
     * [`.idea/runConfigurations/All_Map_Feature_Tests.xml`](file:///c:/flutter/travel-go-mobile/.idea/runConfigurations/All_Map_Feature_Tests.xml)
     * [`.run/TravelGO_Map_Interactive_Preview.run.xml`](file:///c:/flutter/travel-go-mobile/.run/TravelGO_Map_Interactive_Preview.run.xml)
     * [`.run/All_Map_Feature_Tests.run.xml`](file:///c:/flutter/travel-go-mobile/.run/All_Map_Feature_Tests.run.xml)

3. **Bộ Suite kiểm thử tự động toàn diện:**
   * Đường dẫn: [`test/map_feature_test_suite.dart`](file:///c:/flutter/travel-go-mobile/test/map_feature_test_suite.dart)
   * **Công dụng:** Chạy toàn bộ các bài test Marker, hiệu ứng Rating sao, lớp chủ quyền Hoàng Sa - Trường Sa, thao tác drill-down phóng to và phản hồi khi Admin sửa danh mục.

---

## 💻 III. CÁCH TEST TRÊN ANDROID STUDIO (TỪNG BƯỚC)

### Cách 1: Chạy 1-Click từ thanh công cụ Android Studio (Khuyên dùng)
1. Mở dự án trong **Android Studio**.
2. Trên thanh công cụ trên cùng (Toolbar), bấm vào danh sách chọn cấu hình (Run Configuration dropdown).
3. Chọn: **`🗺️ TravelGO Map Preview (Thành Viên 2)`**.
4. Chọn máy ảo (Android Emulator) hoặc điện thoại thật đã cắm cáp.
5. Bấm nút **Run ▶️** (hoặc nhấn tổ hợp phím `Shift + F10`).
6. Ứng dụng sẽ khởi động ngay lập tức vào Bản Đồ Khám Phá!

---

### Cách 2: Chạy trực tiếp từ Project Explorer trong Android Studio
1. Mở cây thư mục bên trái (`Project` tab).
2. Tìm đến file: `lib/main_map_preview.dart`.
3. Bấm **chuột phải** vào `main_map_preview.dart` $\rightarrow$ chọn **Run 'main_map_preview.dart'**.

---

### Cách 3: Chạy Test Suite để xem thanh kết quả màu xanh lá (Green Bar)
1. Mở cây thư mục bên trái: `test/map_feature_test_suite.dart`.
2. Bấm **chuột phải** vào file $\rightarrow$ chọn **Run 'tests in map_feature_test_suite.dart'**.
3. Khung Test Runner của Android Studio sẽ chạy và hiển thị cây kiểm thử **100% Passed**.

---

### Cách 4: Chạy từ Terminal / Command Line
Nếu muốn chạy bằng lệnh terminal:
* **Chạy giao diện xem trước:**
  ```powershell
  flutter run -t lib/main_map_preview.dart
  ```
* **Chạy kiểm thử tự động:**
  ```powershell
  flutter test test/map_feature_test_suite.dart
  ```

---

## 🎯 IV. KỊCH BẢN THAO TÁC ĐỂ CHẤM ĐIỂM BẢO VỆ

Khi mở màn hình bản đồ trên thiết bị hoặc máy ảo, bạn hãy thực hiện lần lượt các thao tác sau để kiểm tra:

1. **Khẳng định Chủ quyền Biển Đảo Việt Nam:**
   * Quan sát vùng Biển Đông trên bản đồ:
   * Thấy ngay 2 huy hiệu cờ đỏ sao vàng nổi bật: **"Hoàng Sa (VN)"** và **"Trường Sa (VN)"**.
   * Chạm vào huy hiệu $\rightarrow$ Xem thông tin chủ quyền lãnh thổ Việt Nam hiển thị ở thẻ đáy màn hình.

2. **Chạm vào Điểm Đến để bung Địa Điểm con (Drill-Down Zoom):**
   * Đang ở toàn cảnh Việt Nam $\rightarrow$ Chạm vào biểu tượng **"Đà Lạt"** (màu tím).
   * **Kết quả:** Bản đồ tự động lướt và phóng to mượt mà (Zoom 13.0) vào trung tâm Đà Lạt.
   * Trên cùng xuất hiện thanh thông báo: `Đang xem: Đà Lạt (5 địa điểm)` kèm nút đóng (X).

3. **Kiểm tra Hiệu Ứng Rating (Trọng số thị giác Visual Weight):**
   * Quan sát các marker địa điểm con vừa bung ra tại Đà Lạt:
     * **Hồ Xuân Hương** & **Chùa Linh Phước** (Rating $\ge 4.5$ sao): Marker hình tròn **to, màu vàng hổ phách rực rỡ, viền phát sáng và có icon ⭐**.
     * **Thung Lũng Tình Yêu** (Rating $4.3$ sao): Marker kích thước vừa, màu xanh ngọc.
     * **Điểm Check-in Mới** (Chưa có sao / $< 3.5$ sao): Marker nhỏ gọn, màu xám thanh lịch.

4. **Thẻ Xem Trước (PlaceMapPreviewCard):**
   * Chạm vào marker **"Hồ Xuân Hương"**:
   * Thẻ ở đáy màn hình hiện lên viền vàng sang trọng, huy hiệu **"⭐ Nổi Bật"**, điểm `4.9`, số lượt đánh giá, mô tả tóm tắt và nút **"Xem chi tiết"**.
   * Bấm nút đóng (X) trên card để ẩn thẻ.

5. **Thử nghiệm Tính Năng Đồng Bộ Admin (Admin Realtime Sync):**
   * Bấm nút tròn nổi ở góc phải bên dưới: **`Admin: Ẩn Chợ Đà Lạt`**.
   * **Kết quả:** Marker `Chợ Đà Lạt & Chợ Đêm` biến mất ngay lập tức khỏi bản đồ (mô phỏng đúng hành vi khi Admin chuyển trạng thái ẩn địa điểm).
   * Bấm lại nút **`Admin: Hiện lại Chợ Đà Lạt`** $\rightarrow$ Địa điểm lập tức xuất hiện trở lại!

6. **Trở lại chế độ toàn cảnh quốc gia:**
   * Bấm nút **"Toàn cảnh"** trên thanh AppBar hoặc bấm dấu **(X)** trên thanh thông báo đang xem.
   * Bản đồ tự động thu nhỏ về mức toàn cảnh Việt Nam.

