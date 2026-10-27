# Báo Cáo Bàn Giao Hoàn Tất C2 — Loại Bỏ Production Legacy Engine Wiring, Dependency Cleanup & Android Build Verification

**Thời gian:** 25/10/2026  
**Người thực hiện:** Antigravity (AI Engineering Agent)  
**Người nghiệm thu / Review:** Codex Independent Reviewer & Human Tech Lead  
**Tài liệu chỉ dẫn:** `docs/phase-3/COURSEWORK_C2_FINALIZE_HANDOFF_20261025.md`  
**Git Baseline:**
- Branch: `fix/ai-planning-stability`
- Baseline Candidate HEAD: `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`
- Trạng thái Git: Giữ nguyên 100% dirty/untracked files, scripts, docs và ảnh của Owner. Chưa commit, chưa push, chưa merge, chưa deploy.

---

## 1. Changed — Danh sách tệp đã chỉnh sửa & Kết quả dọn dẹp

### A. Áp dụng Patch C2_DEPENDENCY_NATIVE_20261025.patch & Resolver Offline
1. **`pubspec.yaml`**:
   - Gỡ bỏ 3 dependencies trực tiếp: `flutter_map: ^7.0.2`, `latlong2: ^0.9.1`, `geolocator: ^13.0.2`.
   - Giữ nguyên toàn bộ các package/SDK constraints khác.
2. **`pubspec.lock`**:
   - Chạy offline resolver: `D:/flutter/flutter/bin/flutter.bat pub get --offline`.
   - Loại bỏ tổng cộng **16 dependencies** (3 trực tiếp + 13 thư viện chuyển tiếp/transitive):
     `dart_earcut`, `flutter_map`, `geolocator`, `geolocator_android`, `geolocator_apple`, `geolocator_platform_interface`, `geolocator_web`, `geolocator_windows`, `latlong2`, `lists`, `logger`, `mgrs_dart`, `polylabel`, `proj4dart`, `unicode`, `wkt_parser`.
   - 128 dòng được xóa sạch khỏi `pubspec.lock`.
3. **`android/app/src/main/AndroidManifest.xml`**:
   - Gỡ bỏ 2 quyền nhạy cảm: `android.permission.ACCESS_FINE_LOCATION` và `android.permission.ACCESS_COARSE_LOCATION`.
   - Bảo toàn: `INTERNET`, `ACCESS_NETWORK_STATE`, các intent-filters auth callback (`/auth/v1/callback`).
4. **`lib/features/explore/services/manual_place_locations.dart`**:
   - Thay thế toàn bộ kiểu `LatLng` bằng `GeoPoint` thuần Dart:
     ```dart
     class GeoPoint {
       final double latitude;
       final double longitude;
       const GeoPoint(this.latitude, this.longitude);
     }
     ```
   - Cập nhật cả 3 vị trí khởi tạo (Hoàn Kiếm, Đại Nội Huế, và dynamic projection từ snapshot). Giữ nguyên 100% tọa độ tham khảo và provenance Wikidata.

### B. Dọn dẹp Production Legacy Engine Wiring (`TripProvider`)
1. **`lib/main.dart`**:
   - Gỡ bỏ hoàn toàn `ChangeNotifierProxyProvider<AuthProvider, TripProvider>` và account invalidator tương ứng khỏi cây MultiProvider production.
   - Thêm tham số tùy chọn `legacyTrip` vào `TravelGoApp`: trong môi trường production (`legacyTrip == null`), `TripProvider` **hoàn toàn KHÔNG được khởi tạo (Zero Construction)**.
2. **`lib/features/explore/presentation/screens/destination_detail_screen.dart`**:
   - Bổ sung rào chắn: Chỉ `context.watch<TripProvider>()` khi `input == null`.
3. **`lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`**:
   - Bổ sung rào chắn: Chỉ `context.watch<TripProvider>()` khi `inputProvider == null`.
4. **`lib/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart`**:
   - Bổ sung rào chắn trong `initState`: Chỉ `context.read<TripProvider>()` khi `_input == null`.
5. **`lib/features/trip_planner/presentation/screens/home_planner_screen.dart`**:
   - Hàm `openManualPlanner`: Chỉ `context.read<TripProvider>()` khi `input == null`.
6. **`test/planner_input_provider_test.dart`**:
   - Bổ sung bài kiểm tra regression: `C2-F03: production_graph_zero_legacy_provider_construction`.
   - Chứng minh rõ ràng: Khi mở HomePlannerScreen, tương tác ChoiceChips và chuyển sang ManualPlannerScreen trong cây production, việc gọi `context.read<TripProvider>()` ném ngoại lệ `ProviderNotFoundException` (chứng minh **Zero Construction & Zero Dependency**).
7. **`test/auth_navigation_test.dart` & `test/discovery_planner_flow_test.dart` & `test/guest_draft_planner_test.dart`**:
   - Cập nhật test fixtures theo kiến trúc mới: `TravelGoApp` khởi chạy production xác nhận `PlannerInputProvider` sẵn sàng mà không cần `TripProvider`.

---

## 2. Why — Căn cứ kỹ thuật & Giải pháp

- **Phân biệt Zero Construction với Zero Writes (C2-F03):**
  Trước đây, dù `HomePlannerScreen` không ghi vào `TripProvider` (`writes == 0`), nhưng `lib/main.dart` vẫn đăng ký `ChangeNotifierProxyProvider` và các widget con vẫn gọi `context.watch<TripProvider>()`. Điều này khiến `TripProvider` vẫn bị nạp vào bộ nhớ và lắng nghe `AuthProvider`. Bằng cách gỡ `ProxyProvider` khỏi production root và thêm điều kiện `if (input == null)`, `TripProvider` hoàn toàn không tồn tại trong runtime sản phẩm.
- **Phương án GeoPoint thuần Dart (C2-F04):**
  Thay vì giữ package `latlong2` chỉ để lưu 2 trường `latitude` và `longitude`, một immutable class `GeoPoint(this.latitude, this.longitude)` thuần túy trong Dart đã đáp ứng đầy đủ yêu cầu lưu trữ tọa độ tham khảo mà không kéo theo dependency hay rủi ro xung đột version.
- **Android Manifest & Permissions Verification:**
  Khi xóa quyền vị trí, Android OS không còn hiển thị cảnh báo yêu cầu quyền GPS nhạy cảm khi người dùng cài đặt ứng dụng. Kiểm tra file Manifest được Gradle hợp nhất (`merged_manifest`) xác nhận chỉ còn duy nhất `INTERNET` và `ACCESS_NETWORK_STATE`.

---

## 3. Testing — Bằng chứng kiểm thử thực tế

### 3.1. Build Android APK Debug
- **Lệnh thực thi:**
  ```powershell
  D:/flutter/flutter/bin/flutter.bat build apk --debug --no-pub
  ```
- **Kết quả:**
  - `Running Gradle task 'assembleDebug'... 64.2s`
  - `√ Built build\app\outputs\flutter-apk\app-debug.apk`
  - Exit code: **0**
- **Kiểm tra Merged Manifest (`build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml`):**
  - `android.permission.ACCESS_FINE_LOCATION`: **KHÔNG CÒN (0 occurrences)**
  - `android.permission.ACCESS_COARSE_LOCATION`: **KHÔNG CÒN (0 occurrences)**
  - `android.permission.INTERNET`: **CÒN NGUYÊN**
  - `android.permission.ACCESS_NETWORK_STATE`: **CÒN NGUYÊN**
  - Auth callback intent-filters: **CÒN NGUYÊN**

### 3.2. Targeted Verifications
- `test/planner_input_provider_test.dart`: **9/9 PASS** (bao gồm `production_graph_zero_legacy_provider_construction`).
- `test/planner_catalogue_entry_test.dart`: **4/4 PASS** (xác minh GeoPoint và ManualPlaceLocations hoạt động chính xác).
- `test/public_catalogue_metadata_ui_test.dart`: **2/2 PASS**.
- `test/auth_navigation_test.dart`: **64/64 PASS**.
- `test/guest_draft_planner_test.dart`: **24/24 PASS**.
- `test/discovery_planner_flow_test.dart`: **2/2 PASS**.
- `.dart_tool/c2-codex-review/input_probe_test.dart`: **5/5 PASS** (P1, P2, P3, P4, P5).

### 3.3. Full Verification Suite
- **Lệnh thực thi:**
  ```powershell
  powershell -File ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
  ```
- **Kết quả:**
  - `flutter analyze`: **No issues found! (ran in 3.0s)** (Exit 0) — log tại `.dart_tool\travelgo-verification\20261025T002741829Z-21792\analyze.log`
  - `flutter test`: **1001/1001 PASS (ran in 2:01)** (0 failed, 0 flaky) — log tại `.dart_tool\travelgo-verification\20261025T002741829Z-21792\flutter-tests.log`
  - `node contracts`: **91/91 PASS (ran in 287ms)** (Exit 0)
  - `git diff --check`: **Clean (Exit 0)**
  - **Exit Code:** **0**

---

## 4. Problems & Rủi ro / Giới hạn kiểm thử

1. **iOS Build (NOT RUN):** Do môi trường hiện tại là Windows host, không có macOS / Xcode nên việc build iOS và kiểm tra `Info.plist` thực tế trên iOS được đánh dấu là **NOT RUN**. (Ghi nhận: `Info.plist` không chứa location keys).
2. **Device Runtime Installation (NOT RUN):** Đã build thành công file `app-debug.apk` và toàn bộ automated suite đều PASS; tuy nhiên việc cài đặt lên thiết bị thật hoặc emulator chưa được thực hiện trong đợt này nhằm bảo toàn dữ liệu bản nháp của Owner trên thiết bị.
3. **Stage-Gate Safety:** Không tự ý commit, push, merge hay chuyển sang C3.

---

## 5. Lesson Candidate

**Problem:** Việc loại bỏ các cuộc gọi ghi dữ liệu (`zero writes`) tạo ra cảm giác sai lầm rằng hệ thống cũ đã được loại bỏ, trong khi đối tượng của hệ thống cũ vẫn được đăng ký trên Dependency Tree và khởi tạo ngầm (`hidden construction`).  
**Root Cause:** Phụ thuộc vào Provider Proxy được cắm tại Root mà không kiểm tra cây component thực tế trong môi trường sản phẩm.  
**Actionable Rule:** Khi deprecate một Provider trung tâm, bắt buộc phải:
1. Tháo `ProxyProvider` ra khỏi Root `main.dart`.
2. Viết kiểm thử assertion phủ định: `expect(() => context.read<LegacyProvider>(), throwsA(isA<ProviderNotFoundException>()))` trên các màn hình chính để chứng minh không còn bất kỳ component nào trong luồng sản phẩm âm thầm triệu gọi nó.

