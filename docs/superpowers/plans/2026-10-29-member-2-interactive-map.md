# Thành Viên 2 — Bản Đồ Khám Phá Danh Mục & Hiệu Ứng Rating (Catalogue Map & Rating Effects) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng Bản đồ Khám phá Du lịch tương tác sử dụng OpenStreetMap (`flutter_map`): Hiển thị tất cả các Điểm đến (Destinations) do Admin thêm vào; khi người dùng chạm vào Điểm đến sẽ tự động hiển thị các Địa điểm tham quan (Places) bên trong. Bản đồ tự động đồng bộ (ẩn/hiện/cập nhật) khi Admin chỉnh sửa, đồng thời áp dụng hiệu ứng thị giác (UI/UX) theo điểm Rating: địa điểm đánh giá cao sẽ hiển thị to và nổi bật hơn; khẳng định chủ quyền Hoàng Sa & Trường Sa. *(Không cần tính toán lộ trình polyline hay marker số 1, 2, 3)*.

**Architecture:** Mở rộng `lib/features/map/` kết nối trực tiếp với nguồn dữ liệu Danh mục Admin (`PublicCatalogueSnapshot` / `DestinationCatalogService`) và hệ thống đánh giá của Thành viên 3 (`ReviewProvider`). Cung cấp widget `CatalogueDiscoveryMapScreen` với 2 cấp độ thu phóng (Zoom Level): Cấp 1 hiển thị Điểm đến tỉnh/thành phố; Cấp 2 hiển thị các địa danh tham quan chi tiết kèm hiệu ứng Rating Visual Weight. Tích hợp lớp chủ quyền biển đảo `VietnameseSovereigntyLayer`.

**Tech Stack:** Flutter 3.x, Dart 3.x, `flutter_map: ^7.0.2`, `latlong2: ^0.9.1`, OpenStreetMap Standard Tiles, Provider.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Không vẽ lộ trình phức tạp:** Tuyệt đối không cần gọi API tính toán đường đi OSRM/Routing hay vẽ polyline nối các mốc 1, 2, 3; tập trung trọn vẹn vào trải nghiệm khám phá địa điểm trên bản đồ.
- **Đồng bộ sống với Admin:** Bản đồ đọc dữ liệu trực tiếp từ `PublicCatalogueSnapshot` đã công bố của Admin; khi Admin thêm/xóa/ẩn địa điểm, bản đồ tự động phản ánh ngay lập tức.
- **Trọng số thị giác theo Rating:** Kích thước, màu sắc và hiệu ứng viền của Marker phải tương ứng với điểm đánh giá sao (1–5 sao) lấy từ hệ thống của Thành viên 3.
- **Chủ quyền quốc gia:** Bắt buộc duy trì nhãn khẳng định chủ quyền Hoàng Sa (Đà Nẵng) và Trường Sa (Khánh Hòa) trên Biển Đông.

## Review Focus
1. **Chạm vào Điểm đến (Drill-down):** Khi người dùng chạm vào Marker "Đà Lạt", bản đồ phải mượt mà phóng to (animate zoom) vào tọa độ Đà Lạt và bung ra các Marker địa điểm tham quan bên trong.
2. **Hiệu ứng phân cấp Rating:** Địa điểm có rating $\ge$ 4.5 sao phải có đường kính marker to hơn 25%, màu vàng cam rực rỡ và có icon ngôi sao ⭐; địa điểm chưa có đánh giá thì màu xám nhạt nhỏ gọn.
3. **Admin ẩn địa điểm:** Khi Admin chuyển trạng thái địa điểm sang ẩn (`isHidden: true`), Marker của địa điểm đó phải biến mất khỏi bản đồ ở lần tải/làm mới tiếp theo.
4. **Không crash khi mất mạng:** Khi không có internet, bản đồ vẫn vẽ được các Marker và nhãn tên dựa trên tọa độ đã lưu trong cache/snapshot.
5. **Chạm vào Marker xem tóm tắt:** Bấm vào một Marker bất kỳ phải hiển thị BottomSheet hoặc thẻ xem nhanh: Tên, Ảnh thu nhỏ, Số sao rating và nút "Xem chi tiết".

---

### Task 1: Khai báo Thư viện Bản đồ trong `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml`
- Test: `flutter pub get`

**Interfaces:**
- Produces: `package:flutter_map/flutter_map.dart`, `package:latlong2/latlong.dart`

- [ ] **Step 1: Cập nhật `pubspec.yaml`**
Thêm hai gói thư viện vào mục `dependencies:`:
```yaml
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
```

- [ ] **Step 2: Chạy lệnh tải gói**
Run: `flutter pub get`  
Expected: Exit code 0.

- [ ] **Step 3: Commit**
```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(map): add flutter_map and latlong2 dependencies for catalogue map"
```

---

### Task 2: Xây dựng Model Marker Phân Cấp và Widget Lớp Chủ Quyền

**Files:**
- Create: `lib/features/map/models/catalogue_map_marker.dart`
- Create: `lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart`
- Create: `test/catalogue_map_marker_test.dart`

**Interfaces:**
- Produces: `CatalogueMapMarker`, enum `MarkerType { destination, place }`, `VietnameseSovereigntyLayer`

- [ ] **Step 1: Viết failing test cho `CatalogueMapMarker` phân cấp hiệu ứng Rating**
```dart
// test/catalogue_map_marker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/catalogue_map_marker.dart';

void main() {
  test('CatalogueMapMarker calculates visual weight based on rating', () {
    final highRated = CatalogueMapMarker(
      id: 'p1',
      title: 'Bà Nà Hills',
      point: const LatLng(15.9988, 107.9961),
      type: MarkerType.place,
      averageRating: 4.8,
      reviewCount: 50,
    );
    expect(highRated.isTopRated, isTrue);
    expect(highRated.markerColor, equals(Colors.amber));
    expect(highRated.markerSize, greaterThan(35.0));

    final lowRated = CatalogueMapMarker(
      id: 'p2',
      title: 'Điểm mới',
      point: const LatLng(16.0, 108.0),
      type: MarkerType.place,
      averageRating: 3.0,
      reviewCount: 2,
    );
    expect(lowRated.isTopRated, isFalse);
    expect(lowRated.markerSize, lessThan(highRated.markerSize));
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/catalogue_map_marker_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model Marker và Widget Chủ Quyền**
1. `catalogue_map_marker.dart`: Tính toán kích thước (`markerSize`), màu sắc (`markerColor`), và cờ `isTopRated` dựa trên `averageRating >= 4.5`.
2. `vietnamese_sovereignty_layer.dart`: Định vị 2 ghim chủ quyền biển đảo Hoàng Sa và Trường Sa.

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/catalogue_map_marker_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/map/models/catalogue_map_marker.dart lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart test/catalogue_map_marker_test.dart
git commit -m "feat(map): implement CatalogueMapMarker with rating visual weight and sovereignty layer"
```

---

### Task 3: Xây dựng Màn hình `CatalogueDiscoveryMapScreen` Đồng Bộ Admin

**Files:**
- Create: `lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart`
- Create: `lib/features/map/presentation/widgets/place_map_preview_card.dart`
- Create: `test/catalogue_discovery_map_screen_test.dart`

**Interfaces:**
- Produces: `CatalogueDiscoveryMapScreen()`, `PlaceMapPreviewCard(marker: CatalogueMapMarker)`

- [ ] **Step 1: Viết widget test cho `CatalogueDiscoveryMapScreen`**
```dart
// test/catalogue_discovery_map_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/catalogue_discovery_map_screen.dart';

void main() {
  testWidgets('CatalogueDiscoveryMapScreen renders map and markers correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CatalogueDiscoveryMapScreen(),
    ));
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
Run: `flutter test test/catalogue_discovery_map_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Màn hình Bản đồ**
1. Đọc danh sách điểm đến và địa danh từ `PublicCatalogueSnapshot` (dữ liệu Admin C7).
2. Khi ở mức zoom xa: Hiển thị các Marker Điểm đến (Đà Lạt, Đà Nẵng, Phú Quốc...).
3. Khi người dùng bấm vào một Điểm đến: Gọi `mapController.move(destinationLatLng, 13.5)` $\rightarrow$ Chuyển sang hiển thị các Marker Địa điểm tham quan bên trong.
4. Marker áp dụng hiệu ứng rating:
   - ⭐ **Top Rated ($\ge$ 4.5 sao):** Vòng tròn vàng cam to, viền phát sáng, icon ngôi sao.
   - 📍 **Bình thường (3.5 – 4.4 sao):** Vòng tròn xanh tím kích thước vừa.
   - ⚪ **Thấp / Chưa đánh giá (< 3.5 sao):** Vòng tròn xám nhỏ.
5. Khi bấm vào Marker: Hiện thẻ `PlaceMapPreviewCard` ở đáy màn hình với tên, số sao và nút "Xem chi tiết".

- [ ] **Step 4: Chạy test xác nhận PASS**
Run: `flutter test test/catalogue_discovery_map_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/map/presentation/ test/catalogue_discovery_map_screen_test.dart
git commit -m "feat(map): implement CatalogueDiscoveryMapScreen with drill-down and rating glow effects"
```

---

### Task 4: Gắn Nút Bản Đồ Khám Phá vào Tab "Khám Phá" (Explore)

**Files:**
- Modify: `lib/features/explore/presentation/screens/explore_screen.dart` (hoặc màn hình danh mục)
- Test: `test/map_explore_entry_test.dart`

**Interfaces:**
- Gắn nút IconButton hình bản đồ (`Icons.map_outlined`) ở thanh AppBar của mục Khám phá để mở `CatalogueDiscoveryMapScreen`.

- [ ] **Step 1: Viết test kiểm tra nút bản đồ xuất hiện trên thanh AppBar**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Thêm nút chuyển hướng sang `CatalogueDiscoveryMapScreen`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/explore/ test/map_explore_entry_test.dart
git commit -m "feat(map): integrate Catalogue Map entry button into Explore screen AppBar"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Xem Điểm đến & Bấm vào để bung Địa điểm (Drill-down):**
   - **Thao tác:** Mở app $\rightarrow$ Vào tab "Khám phá" $\rightarrow$ Bấm icon **Bản đồ** ở góc trên màn hình.
   - **Kỳ vọng:** Bản đồ hiện ra toàn cảnh Việt Nam với các biểu tượng Điểm đến: Hà Nội, Đà Nẵng, Đà Lạt, Phú Quốc...
   - **Thao tác:** Chạm vào biểu tượng **"Đà Lạt"**.
   - **Kỳ vọng:** Bản đồ tự động lướt và phóng to vào trung tâm Đà Lạt. Các biểu tượng địa điểm con hiện ra: Hồ Xuân Hương, Chùa Linh Phước, Thung lũng Tình Yêu...
2. **Test Hiệu ứng Phân cấp Rating (Visual Weight):**
   - **Kỳ vọng thị giác:** 
     - Những địa điểm được nhiều người chấm 5 sao (như Bà Nà Hills, Hồ Xuân Hương) có biểu tượng **màu vàng rực rỡ, to nổi bật và có hình ngôi sao ⭐**.
     - Những địa điểm mới thêm chưa có đánh giá có biểu tượng màu xám nhỏ hơn.
3. **Test Đồng bộ khi Admin Thêm/Xóa/Sửa:**
   - **Thao tác:** Đăng nhập tài khoản Admin $\rightarrow$ Thêm 1 địa điểm mới hoặc Ẩn 1 địa điểm cũ $\rightarrow$ Xuất bản (Publish). Quay lại màn hình Bản đồ của User và vuốt làm mới.
   - **Kỳ vọng:** Địa điểm mới thêm xuất hiện ngay trên Bản đồ; địa điểm bị ẩn sẽ biến mất.
4. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
