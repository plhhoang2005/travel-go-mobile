# Direct OSRM Routing Client Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để lỗi tính toán lộ trình rơi vào trạng thái Fallback (đường thẳng chim bay, nhãn [OSRM Offline]) trên thiết bị thật có kết nối Internet bằng cách bổ sung cơ chế Direct OSRM Client Fallback Gateway và xử lý mạng thích ứng cho thiết bị Android vật lý.

**Architecture:** 
1. **Multi-Tier Routing Gateway Architecture (Kiến trúc định tuyến 2 tầng kiên cường):**
   - **Tầng 1 (Primary):** Gọi Backend API nội bộ (`/api/v1/maps/routes`) theo đúng Luật 2 (Backend SSoT).
   - **Tầng 2 (Resilient Client Fallback):** Nếu Backend không phản hồi (`connectionError`, `10.0.2.2` trên máy thật, server chưa start), `MapApiService` tự động fallback sang gọi trực tiếp OSRM Public API (`https://router.project-osrm.org/route/v1/driving/...`) qua HTTP GET với GeoJSON geometry.
   - **Tầng 3 (Local Offline Beeline):** Chỉ khi thiết bị mất mạng hoàn toàn (cả Backend và OSRM Public đều không thể kết nối), `MapProvider` mới kích hoạt `_generateLocalOfflineLine()` và hiển thị cờ minh bạch `[FALLBACK] [OSRM Offline]` theo đúng Luật 3.
2. **Road-Network Geometry & TSP Synergy:** Dữ liệu trả về từ Direct OSRM được giải mã thành danh sách tọa độ thực tế bám theo mạng lưới giao thông OpenStreetMap (đường xá, cầu vượt, ngã rẽ), kết hợp thuật toán tối ưu hóa thứ tự điểm dừng TSP 2-Opt trong `RouteOptimizerService` để đảm bảo quãng đường và thời gian tối ưu nhất.

**Tech Stack:** Flutter 3.x, Dart 3.x, Dio, latlong2, flutter_map, OSRM (Open Source Routing Machine).

**Spec:** Bug report kèm ảnh chụp thực tế: Xuất phát từ Thủ Đức đến Trung tâm TP. Hồ Chí Minh, máy có Internet và GPS đầy đủ nhưng bản đồ hiển thị đường thẳng màu cam xuyên sông ngòi, banner `Dữ liệu lộ trình ngoại tuyến [OSRM Offline]` và badge `FALLBACK` do không kết nối được `10.0.2.2:8080`.

---

## Global Constraints
- Tuân thủ nghiêm ngặt 5 Luật Bất Biến trong `AGENTS.md` (đặc biệt Luật 2 SSoT, Luật 3 Minh bạch dữ liệu ngoại tuyến, Luật 4 Non-blocking UI).
- Không thêm dependency mới vào `pubspec.yaml`.
- Đảm bảo toàn bộ 82+ test hiện tại tiếp tục pass 100% và `flutter analyze` đạt 0 warnings/errors.

## Review Focus
1. **Định dạng tọa độ OSRM:** OSRM nhận query dạng `{longitude},{latitude}` (lng trước, lat sau), trong khi `LatLng` của mobile là `{latitude, longitude}`. Phải đảo đúng thứ tự để không bị lỗi HTTP 400.
2. **Timeout an toàn cho Direct OSRM:** Lệnh gọi OSRM trực tiếp phải có timeout hợp lý (5s) và bọc try-catch để nếu OSRM public nghẽn mạng thì lập tức chuyển sang Tầng 3 (Offline line), không làm treo UI.
3. **Giảm tải điểm ảnh (Point Simplification):** Các cung đường dài (> 300km) có thể chứa hàng nghìn tọa độ; cần lấy mẫu tối đa 400-500 điểm để bản đồ `flutter_map` render mượt mà 60 FPS, không gây giật lag (Luật 4).
4. **Nhãn nguồn dữ liệu minh bạch:** Khi định tuyến thành công qua Direct OSRM, `isFallback` là `false`, summary là `Tuyến đường OSRM` và badge trên thẻ hiển thị `OSRM` (xanh ngọc) thay vì `FALLBACK` (cam).

---

### Task 1: Bổ sung Direct OSRM Client Gateway trong `MapApiService`

**Files:**
- Modify: `lib/features/map/services/map_api_service.dart:60-130`
- Test: `test/map_feature_test.dart`

**Interfaces:**
- Consumes: `https://router.project-osrm.org/route/v1/driving/{coords}?overview=full&geometries=geojson`
- Produces: `Future<RouteData> getRoute(...)` trả về `RouteData` thật với `isFallback = false`, tọa độ thực bám đường phố khi Backend down.

- [ ] **Step 1: Viết failing test trong `test/map_feature_test.dart`**
  Viết test kiểm tra khi Backend ném `connectionError`, `MapApiService` tự động gọi client fallback và phân tích JSON từ OSRM thành `RouteData`.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Run: `flutter test test/map_feature_test.dart`

- [ ] **Step 3: Cập nhật `MapApiService` trong `lib/features/map/services/map_api_service.dart`**
  - Thêm phương thức `Future<RouteData> _fetchDirectOsrmRoute(...)`.
  - Xây dựng coords string theo format: `lng,lat;lng,lat...`.
  - Gọi Dio GET tới `https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson` với timeout 5 giây.
  - Parse `routes[0].geometry.coordinates` thành `List<LatLng>`.
  - Lấy `distance` (chia 1000 ra km) và `duration` (chia 60 ra phút).
  - Trả về `RouteData(points: points, distanceKm: dist, durationMinutes: dur, isFallback: false, summary: 'Tuyến đường OSRM')`.
  - Trong hàm `getRoute`: khi bắt `DioException` kết nối Backend thất bại, tự động chuyển hướng gọi `_fetchDirectOsrmRoute(...)`. Nếu OSRM public cũng thất bại mới ném `RoutingException(..., backendUnreachable: true)`.

- [ ] **Step 4: Chạy lại test để xác nhận pass**
  Run: `flutter test test/map_feature_test.dart`

---

### Task 2: Cập nhật `MapProvider` xử lý trạng thái hiển thị tuyến đường

**Files:**
- Modify: `lib/features/map/providers/map_provider.dart:665-687`
- Test: `test/map_feature_test.dart`

**Interfaces:**
- Produces: `_fetchRoute()` trong `MapProvider` ưu tiên tuyến đường OSRM thực tế, chỉ kích hoạt `_generateLocalOfflineLine()` khi mất kết nối Internet hoàn toàn.

- [ ] **Step 1: Viết test cho `MapProvider._fetchRoute()`**
  Kiểm tra khi `_apiService.getRoute()` trả về `isFallback == false`, `currentRoute.isFallback` phải là `false` và `errorMessage` là `null`.

- [ ] **Step 2: Cập nhật hàm `_fetchRoute()` trong `lib/features/map/providers/map_provider.dart`**
  - Đảm bảo xóa sạch `_errorMessage` khi có tuyến đường OSRM hợp lệ.
  - Giữ nguyên cơ chế bảo vệ `_generateLocalOfflineLine()` cho trường hợp ngoại tuyến hoàn toàn.

- [ ] **Step 3: Chạy test để xác nhận pass**
  Run: `flutter test test/map_feature_test.dart`

---

### Task 3: Xác thực tổng thể `flutter analyze` & `flutter test`

**Files:**
- Test: `test/map_feature_test.dart`
- Lint: toàn bộ project

- [ ] **Step 1: Chạy `flutter test`**
  Run: `flutter test`
  Expected: 82+ tests pass 100%.

- [ ] **Step 2: Chạy `flutter analyze`**
  Run: `flutter analyze`
  Expected: No issues found.

---

## Handover & Verification Checklist
1. Khi máy có Internet (4G/Wi-Fi) và Backend tắt: Bản đồ vẽ đường thực tế bám theo mạng lưới giao thông OSRM, không còn đường thẳng chim bay.
2. Thẻ lộ trình hiển thị `OSRM` màu xanh ngọc, không còn nhãn `FALLBACK` màu cam.
3. Banner màu hổ phách `[OSRM Offline]` biến mất, thay vào đó là lộ trình chuẩn xác.
4. Khi tắt hẳn Wi-Fi/4G (ngoại tuyến hoàn toàn): Cơ chế Fallback đường thẳng chim bay vẫn kích hoạt an toàn với nhãn `[FALLBACK] [OSRM Offline]` theo đúng Luật 3.

