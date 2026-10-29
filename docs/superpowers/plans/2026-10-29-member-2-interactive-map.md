# Thành Viên 2 — Bản Đồ Tương Tác & Lộ Trình Du Lịch (Interactive Map & Sovereignty) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp bản đồ du lịch tương tác sử dụng OpenStreetMap (`flutter_map`), hiển thị danh sách các điểm tham quan theo từng ngày với Marker đánh số thứ tự, vẽ lộ trình Polyline nối các điểm dừng và khẳng định chủ quyền biển đảo Việt Nam (Hoàng Sa & Trường Sa).

**Architecture:** Tái sử dụng và chuẩn hóa module `lib/features/map/` từ nhánh lịch sử `origin/feat/map-resilience-and-sovereignty`. Bản đồ hoạt động độc lập, nhận dữ liệu chuyến đi (`TripPlanResponse` hoặc danh sách địa điểm có tọa độ lat/long) từ `TripProvider` và `ExploreProvider`. Lớp hiển thị tích hợp widget chủ quyền `VietnameseSovereigntyLayer` trực tiếp trên tầng bản đồ.

**Tech Stack:** Flutter 3.x, Dart 3.x, `flutter_map: ^7.0.2`, `latlong2: ^0.9.1`, OpenStreetMap Standard Tile Layer.

**Spec:** [docs/phase-3/COURSEWORK_ACCEPTANCE_REPORT.md](../../phase-3/COURSEWORK_ACCEPTANCE_REPORT.md) & [TRAVELGO_UPGRADE_MASTER_PLAN.md](TRAVELGO_UPGRADE_MASTER_PLAN.md).

## Global Constraints
- **Hoàn toàn miễn phí (Zero API Cost):** Sử dụng OpenStreetMap Tile Server, tuyệt đối không dùng Google Maps SDK đòi hỏi thẻ tín dụng hoặc API Key có phí.
- **Chủ quyền quốc gia:** Bắt buộc phải có nhãn hiển thị Quần đảo Hoàng Sa (TP. Đà Nẵng) và Quần đảo Trường Sa (Tỉnh Khánh Hòa) trên vùng biển Việt Nam.
- **Cách ly mạng trong kiểm thử:** Toàn bộ Widget test của Bản đồ không được gửi request tải ảnh tile thật ra ngoài Internet (tránh timeout hoặc lỗi CI).
- **Fallback an toàn:** Nếu một địa điểm chưa có tọa độ GPS chính xác, tự động fallback về tọa độ trung tâm của tỉnh/thành phố đó (ví dụ Đà Lạt: `11.9404, 108.4583`), không để app crash.

## Review Focus
1. **Mất kết nối mạng khi tải bản đồ:** App vẫn phải hiển thị giao diện khung bản đồ và các Marker vị trí, không được văng app (crash) khi không tải được ảnh vệ tinh/đường phố.
2. **Bộ lọc theo ngày:** Khi người dùng chọn "Ngày 1", bản đồ chỉ vẽ các điểm và đường nối của Ngày 1; khi chọn "Ngày 2" chuyển sang các điểm của Ngày 2.
3. **Tính liên tục của đường Polyline:** Đường nối các điểm phải tuân theo thứ tự thời gian của hoạt động trong ngày, không nối chéo zíc-zắc bất hợp lý.
4. **Hiệu năng Canvas:** Khi có từ 10–20 điểm dừng, việc kéo vuốt (pan) và phóng to/thu nhỏ (pinch-to-zoom) phải đạt tối thiểu 60 FPS.
5. **Định tuyến màn hình:** Nút bấm "Xem trên bản đồ" từ màn hình Chi tiết Chuyến đi và Chi tiết Địa danh phải mở đúng tọa độ tương ứng.

---

### Task 1: Khai báo Thư viện Bản đồ trong `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml`
- Test: Chạy `flutter pub get`

**Interfaces:**
- Produces: `package:flutter_map/flutter_map.dart`, `package:latlong2/latlong.dart`

- [ ] **Step 1: Cập nhật dependencies trong `pubspec.yaml`**
Thêm hai gói thư viện vào mục `dependencies:`:
```yaml
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
```

- [ ] **Step 2: Chạy lệnh tải gói**
Run: `flutter pub get`  
Expected: Exit code 0, không có xung đột phiên bản.

- [ ] **Step 3: Commit**
```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(map): add flutter_map and latlong2 dependencies"
```

---

### Task 2: Xây dựng Model Marker và Lớp Chủ Quyền Biển Đảo Việt Nam

**Files:**
- Create: `lib/features/map/models/map_marker_item.dart`
- Create: `lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart`
- Create: `test/map_marker_item_test.dart`

**Interfaces:**
- Produces: `MapMarkerItem`, `VietnameseSovereigntyLayer`

- [ ] **Step 1: Viết failing test cho `MapMarkerItem`**
```dart
// test/map_marker_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/map_marker_item.dart';

void main() {
  test('MapMarkerItem initializes coordinates and labels correctly', () {
    final item = MapMarkerItem(
      id: 'p1',
      title: 'Hồ Xuân Hương',
      point: const LatLng(11.9404, 108.4583),
      order: 1,
      dayNumber: 1,
    );
    expect(item.title, equals('Hồ Xuân Hương'));
    expect(item.point.latitude, closeTo(11.9404, 0.001));
    expect(item.order, equals(1));
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/map_marker_item_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai Model và Widget Chủ quyền**
1. Tạo `lib/features/map/models/map_marker_item.dart`: Chứa tọa độ, tên địa điểm, thứ tự ngày, giờ tham quan.
2. Tạo `lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart`: Vẽ hai nhãn Marker cố định tại tọa độ Biển Đông:
   - Hoàng Sa: `LatLng(16.5372, 111.6094)` — Nhãn: *"Quần đảo Hoàng Sa (TP. Đà Nẵng, Việt Nam)"*.
   - Trường Sa: `LatLng(8.6444, 111.9194)` — Nhãn: *"Quần đảo Trường Sa (Tỉnh Khánh Hòa, Việt Nam)"*.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/map_marker_item_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/map/models/map_marker_item.dart lib/features/map/presentation/widgets/vietnamese_sovereignty_layer.dart test/map_marker_item_test.dart
git commit -m "feat(map): create MapMarkerItem model and VietnameseSovereigntyLayer widget"
```

---

### Task 3: Xây dựng Màn hình Bản đồ `TripMapScreen`

**Files:**
- Create: `lib/features/map/presentation/screens/trip_map_screen.dart`
- Create: `lib/features/map/presentation/widgets/map_day_selector.dart`
- Create: `test/trip_map_screen_test.dart`

**Interfaces:**
- Produces: `TripMapScreen(markers: List<MapMarkerItem>, initialCenter: LatLng)`

- [ ] **Step 1: Viết widget test cho `TripMapScreen`**
```dart
// test/trip_map_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelgo_mobile/features/map/models/map_marker_item.dart';
import 'package:travelgo_mobile/features/map/presentation/screens/trip_map_screen.dart';

void main() {
  testWidgets('TripMapScreen renders FlutterMap with markers and day selector', (tester) async {
    final markers = [
      MapMarkerItem(id: '1', title: 'Điểm A', point: const LatLng(16.0, 108.0), order: 1, dayNumber: 1),
      MapMarkerItem(id: '2', title: 'Điểm B', point: const LatLng(16.1, 108.1), order: 2, dayNumber: 1),
    ];
    await tester.pumpWidget(MaterialApp(
      home: TripMapScreen(markers: markers, initialCenter: const LatLng(16.0, 108.0)),
    ));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Điểm A'), findsWidgets);
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Run: `flutter test test/trip_map_screen_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Triển khai `TripMapScreen`**
1. Nhúng `FlutterMap` với `MapOptions(initialCenter: initialCenter, initialZoom: 13.0)`.
2. Thêm `TileLayer` trỏ tới OpenStreetMap URL `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.
3. Thêm `PolylineLayer` vẽ đường nối giữa các Marker có cùng `dayNumber`.
4. Thêm `MarkerLayer` vẽ vòng tròn số thứ tự `order` màu sắc theo theme (`colorScheme.primary`).
5. Thêm thanh chọn ngày (`MapDaySelector`) ở góc trên để lọc hiển thị các điểm theo từng ngày.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Run: `flutter test test/trip_map_screen_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/map/presentation/screens/trip_map_screen.dart lib/features/map/presentation/widgets/map_day_selector.dart test/trip_map_screen_test.dart
git commit -m "feat(map): implement TripMapScreen with polylines, markers and day selector"
```

---

### Task 4: Gắn Nút Mở Bản Đồ vào Màn hình Chi tiết Chuyến đi

**Files:**
- Modify: `lib/features/trips/presentation/screens/saved_trips_screen.dart` (hoặc màn hình hiển thị lịch trình)
- Test: `test/trip_map_navigation_test.dart`

**Interfaces:**
- Consumes: `TripMapScreen`

- [ ] **Step 1: Viết test kiểm tra nút bản đồ xuất hiện trên giao diện chuyến đi**
- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Thêm nút `FloatingActionButton.extended` (icon `Icons.map_outlined`, nhãn "Xem Bản đồ") chuyển hướng sang `TripMapScreen`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit**
```bash
git add lib/features/trips/ test/trip_map_navigation_test.dart
git commit -m "feat(map): integrate map entry button into trip itinerary view"
```

---

## 🎯 TIÊU CHÍ NGHIỆM THU DỄ HIỂU (ACCEPTANCE & TEST GUIDE)

Dành cho người kiểm thử hoặc AI Agent kiểm tra chất lượng:

1. **Test Mở Bản đồ từ Chuyến đi:**
   - **Thao tác:** Vào một chuyến đi có sẵn hoạt động (ví dụ: Chuyến đi Đà Nẵng 3 ngày). Bấm nút **"Xem Bản đồ"**.
   - **Kỳ vọng:** Màn hình Bản đồ hiện ra trơn tru. Xuất hiện các điểm đánh số 1, 2, 3 trên nền bản đồ. Có đường vẽ nối từ điểm 1 sang điểm 2 rồi sang điểm 3.
2. **Test Chuyển ngày trên Bản đồ:**
   - **Thao tác:** Bấm chuyển sang tab "Ngày 2" trên thanh chọn ngày ở phía trên bản đồ.
   - **Kỳ vọng:** Các marker và đường kẻ của Ngày 1 ẩn đi, hiển thị các địa điểm tham quan của Ngày 2.
3. **Test Khẳng định Chủ quyền:**
   - **Thao tác:** Dùng 2 ngón tay thu nhỏ bản đồ (zoom out) ra toàn cảnh Biển Đông Việt Nam.
   - **Kỳ vọng:** Nhìn thấy rõ ràng hai nhãn ghim đỏ: **Quần đảo Hoàng Sa (TP. Đà Nẵng, Việt Nam)** và **Quần đảo Trường Sa (Tỉnh Khánh Hòa, Việt Nam)**.
4. **Kiểm định mã nguồn bắt buộc:**
   - Chạy lệnh `flutter analyze` $\rightarrow$ Kết quả: **No issues found!**
   - Chạy lệnh `flutter test` $\rightarrow$ Kết quả: **Tất cả bài test đều PASS 100%**.
