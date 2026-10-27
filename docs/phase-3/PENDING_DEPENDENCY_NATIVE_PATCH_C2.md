# ĐỀ XUẤT DIFF/PATCH PHỤ THUỘC & CẤU HÌNH NATIVE (PENDING HUMAN APPROVAL)

> **Trạng thái mới nhất 25/10/2026:** Cleanup đã được owner duyệt, Antigravity áp dụng và Codex review cuối **ACCEPT SOURCE/AUTOMATED/ANDROID DEBUG BUILD**. Xem [review C2 cuối](C2_CODEX_REVIEW_FINAL_20261025.md). Nội dung PENDING/proposal dưới đây là snapshot lịch sử, không phải việc đang chờ duyệt; không áp lại patch. Device/iOS runtime chưa nghiệm thu.

> **Cập nhật 25/10/2026:** Owner đã duyệt hướng hoàn tất C2 sau review R2. Các diff blocks dưới đây có lỗi và chỉ giữ làm lịch sử; **không áp dụng**. Dùng [patch đã kiểm trên source thực](C2_DEPENDENCY_NATIVE_20261025.patch) và [handoff hoàn tất C2](COURSEWORK_C2_FINALIZE_HANDOFF_20261025.md). Codex đã chạy apply-check exit0 cho patch mới, chưa apply/build app. Phê duyệt không phải evidence implementation đã xong.

> **Trạng thái:** PENDING REVIEW — KHÔNG TỰ Ý ÁP DỤNG.  
> **Tuân thủ:** Theo Stage-Gate Protocol và Anti-Vague Gatekeeper (`AGENTS.md`), việc sửa đổi `pubspec.yaml` (thêm/bớt dependency) và `AndroidManifest.xml` / `Info.plist` (quyền hệ thống native) thuộc **Permission Boundary (Vùng Đỏ)**, bắt buộc chuẩn bị proposal độc lập và chỉ áp dụng khi được Tech Lead/Owner phê duyệt rõ ràng.

---

## 1. Kiểm kê phụ thuộc & Native Permissions (Cleanup Inventory)

### A. Thư viện di động / Packages (`pubspec.yaml`)
1. **`flutter_map: ^7.0.2`**
   - **Hiện trạng:** Đã gỡ toàn bộ các màn hình, widgets và services sử dụng trong `lib/features/map/` (đã xóa 16 files liên quan bản đồ).
   - **Số caller trong codebase:** **0 callers** trong cả `lib/` và `test/`.
   - **Đánh giá:** Hoàn toàn an toàn để gỡ bỏ khỏi `dependencies`.

2. **`geolocator: ^13.0.2`**
   - **Hiện trạng:** Đã gỡ `LocationService`, `GroupLocationService`.
   - **Số caller trong codebase:** **0 callers** trong cả `lib/` và `test/`.
   - **Đánh giá:** Hoàn toàn an toàn để gỡ bỏ khỏi `dependencies`.

3. **`latlong2: ^0.9.1`**
   - **Hiện trạng:** Chỉ còn 1 nơi import là `lib/features/explore/services/manual_place_locations.dart` (định nghĩa class `LatLng position` cho 2 điểm tham khảo Hồ Hoàn Kiếm và Đại Nội Huế).
   - **Caller thực tế:** Không có caller nào trong ứng dụng production (`lib/` runtime không gọi `ManualPlaceLocations`). Chỉ có 2 test suite tham chiếu đọc metadata: `test/planner_catalogue_entry_test.dart` và `test/public_catalogue_metadata_ui_test.dart`.
   - **Khuyến nghị:**
     - *Phương án A (Khuyên nghị):* Thay `LatLng(lat, lng)` trong `manual_place_locations.dart` bằng một simple immutable value object thuần Dart (ví dụ: `class GeoPoint { final double latitude, longitude; const GeoPoint(this.latitude, this.longitude); }`), từ đó gỡ bỏ hoàn toàn `latlong2`.
     - *Phương án B:* Giữ `latlong2` nếu muốn giữ kiểu dữ liệu tọa độ chuẩn cho Phase sau.

### B. Quyền hệ thống Native (`AndroidManifest.xml` / `Info.plist`)
1. **`android/app/src/main/AndroidManifest.xml`**
   - `android.permission.ACCESS_FINE_LOCATION`
   - `android.permission.ACCESS_COARSE_LOCATION`
   - **Hiện trạng:** Không còn tính năng vị trí/bản đồ/radar nhóm trong scope đồ án di động môn học (theo `.agent/product-scope.md`).
   - **Đánh giá:** Gỡ bỏ để app không đòi hỏi quyền vị trí nhạy cảm khi cài đặt trên Android.

2. **`ios/Runner/Info.plist`**
   - Không chứa `NSLocationWhenInUseUsageDescription` hay `NSLocationAlwaysUsageDescription`. Không cần chỉnh sửa iOS.

---

## 2. Chi tiết bản vá đề xuất (Patch Diff Proposal)

### Patch 1: `pubspec.yaml`
```diff
--- a/pubspec.yaml
+++ b/pubspec.yaml
@@ -43,9 +43,6 @@ dependencies:
   provider: ^6.1.2
   dio: ^5.7.0
   shared_preferences: ^2.3.3
-  flutter_map: ^7.0.2
-  latlong2: ^0.9.1
-  geolocator: ^13.0.2
   fl_chart: ^1.2.0
   sqflite: ^2.4.1
   path: ^1.9.0
```

### Patch 2: `android/app/src/main/AndroidManifest.xml`
```diff
--- a/android/app/src/main/AndroidManifest.xml
+++ b/android/app/src/main/AndroidManifest.xml
@@ -1,7 +1,5 @@
 <manifest xmlns:android="http://schemas.android.com/apk/res/android">
     <uses-permission android:name="android.permission.INTERNET"/>
-    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
-    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
     <application
         android:label="TravelGO"
         android:name="${applicationName}"
```

### Patch 3: Thay thế `LatLng` trong `lib/features/explore/services/manual_place_locations.dart` (Nếu chọn Phương án A)
```diff
--- a/lib/features/explore/services/manual_place_locations.dart
+++ b/lib/features/explore/services/manual_place_locations.dart
@@ -1,4 +1,8 @@
-import 'package:latlong2/latlong.dart';
 import '../models/public_catalogue_snapshot.dart';
 
+class GeoPoint {
+  final double latitude;
+  final double longitude;
+  const GeoPoint(this.latitude, this.longitude);
+}
+
 /// Presentation-only reference positions; never serialized into a trip.
 class ManualPlaceLocation {
   final String placeId, sourceUrl, checkedAt, note;
-  final LatLng position;
+  final GeoPoint position;
   const ManualPlaceLocation({
     required this.placeId,
     required this.position,
     required this.sourceUrl,
     required this.checkedAt,
     required this.note,
   });
 }
```

---

## 3. Kết luận
Gói vá này đã được chuẩn bị đầy đủ và sẵn sàng áp dụng ngay khi Tech Lead / Owner phê duyệt bằng lệnh `"Proceed"` hoặc `"Đồng ý áp dụng native patch"`.

