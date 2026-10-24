# Core Review R1 — Map/API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Antigravity implements; Codex reviews. Do not dispatch subagents or switch implementer. Steps use checkbox syntax. Read the master handoff before execution.

**Goal:** Đóng CR3/CR4/CR7: tuyến đúng thứ tự điểm tham quan; phản hồi ngày/host cũ không đổi geometry, loading, error hoặc camera của ngữ cảnh hiện tại.

**Architecture:** Giữ map standalone dùng GPS như hiện có; thêm entry route lịch trình chỉ nhận stops có tọa độ. Mỗi lần rebuild itinerary có context mới do screen sở hữu. MapApiService fence toàn operation, gồm backend retries và OSRM; MapProvider xử lý config-change như invalidation, không biến thành offline route.

**Tech Stack:** Flutter/Dart, Provider, Dio, latlong2, flutter_map; không thêm dependency/native permission.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`, S3 và API config trong S5; ID findings/quyền hạn trong `docs/superpowers/plans/2026-10-24-core-review-r1-antigravity-handoff.md`.

## Global Constraints

- Baseline `147bd2050ae3a59e942b29945fbe54c9c9eae60c` + dirty owner; giữ hunks ngoài task và catalogue snapshot hiện có.
- Không tính lại Decision Engine, không geocode/fuzzy match/LLM tọa độ, không thêm trung tâm thành phố hoặc GPS vào chuỗi tham quan.
- Tọa độ là tham khảo; hoạt động thiếu vị trí vẫn có hàng, nhãn K/N và cảnh báo tuyến chưa đầy đủ. <2 điểm có vị trí không gọi routing.
- Không thay Radar, tự kết nối phòng/phát vị trí, tiles/GPS/network thật trong test hoặc gửi token Supabase tới backend/OSRM.
- Giữ config URL/revision và retries của từng request; đổi URL trong I/O thì operation cũ bị hủy cả khi OSRM trả lỗi.
- Mỗi task <=5 file; RED đúng hành vi trước fix, GREEN sau fix. Tuân budget/checkpoint hiện hành.

## Review Focus

1. Hai điểm tham quan ở Huế, GPS ở TP.HCM hoặc GPS throw: route vẫn là Huế A→B — B1.
2. Ngày1 slow-success sau ngày2 success/fail/<2 stops: không stale polyline/loading/error/camera — B2.
3. Chọn binding liên tiếp hoặc A→B→A trong cùng màn: mỗi lượt có token riêng, dữ liệu capture riêng — B2.
4. Backend fail rồi OSRM pending, URL đổi và OSRM success/error: reject operation cũ, không offline-line cũ — B3.
5. Screen A dispose sau screen B sở hữu provider: A không clear B; standalone/GPS/Radar vẫn đúng — B2/B3.

## B1 — Itinerary route có origin thực (CR3)

**Files:** Modify `lib/features/map/providers/map_provider.dart`, `lib/features/map/presentation/screens/trip_map_screen.dart`, `test/dashboard_itinerary_map_test.dart` (3 files).

**Interfaces:** Giữ `MapProvider.init({...})` cho standalone. Thêm:

```dart
Future<void> initItineraryRoute({
  required List<RouteWaypoint> stops,
  required int contextGeneration,
});
```

Screen truyền toàn bộ located stops theo thứ tự ngày, giữ key/title/dayNumber. Provider lấy first làm origin, last làm destination, middle làm waypoints; 0/1 stops clear route, không gọi GPS hoặc getRoute. Dữ liệu stops phải copy/freeze trước await.

- [ ] **1. RED tests:** mở thật TripMapScreen, fake API ghi request; fake LocationService đếm calls và có chế độ throw.
  - `itinerary_route_uses_first_located_stop_not_gps`: fixture A=LatLng(16.4698,107.5775), B=LatLng(16.4530,107.5440), C=LatLng(16.4645,107.5904), GPS=LatLng(10.7769,106.7009); assert `lastOrigin == A`, `lastDestination == C`, `lastWaypoints.map((w)=>w.position) == [B]`, GPS calls 0.
  - `itinerary_route_does_not_require_location_permission`: fake GPS throw, route A→C vẫn thành công và không gọi fake GPS.
  - `one_or_zero_located_stops_never_route`: API calls 0, không giữ route ngày trước, các hàng/marker còn đúng.
  - `both_dashboard_map_actions_use_same_itinerary_coordinates`: test cả nút appbar và nút nội dung dashboard; không chỉ assert tên màn/panel.
- [ ] **2. Run RED:** `& ./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath @('test/dashboard_itinerary_map_test.dart','test/itinerary_map_builder_test.dart')`. Bắt đầu repro qua API cũ để RED không do undefined method.
- [ ] **3. Implement:** Screen chỉ xây danh sách stops đã resolve; provider entry mới gán origin/name/isUsingCurrentLocation=false và fetch đúng chuỗi. Không dùng `init(GPS)` rồi `setOrigin` sau fetch; không route hai lần. Giữ cách hiển thị unknown/gap hiện có, không sửa plan source.
- [ ] **4. GREEN:** Lặp command B1 + `test/map_feature_test.dart`, `test/manual_day_map_test.dart`; standalone init vẫn lấy current location và nhãn mock khi phù hợp.
- [ ] **5. Review/commit:** `fix(map): route itinerary from its first located stop` (selective hunks khi owner cho phép).

## B2 — Context mới cho đổi ngày/binding và camera (CR4)

**Depends on:** B1.

**Files:** Modify `lib/features/map/presentation/screens/trip_map_screen.dart`, `lib/features/map/providers/map_provider.dart`, `test/dashboard_itinerary_map_test.dart` (3 files).

**Interfaces:** Giữ `beginRouteContext() -> int`, `endRouteContext(int)`, `isContextActive(int)`, B1 `initItineraryRoute`. Screen `_routeContextToken` luôn là token mới nhất mà screen sở hữu. Cache reference MapProvider khi context còn active; dispose không lookup inherited provider qua context đã deactivated.

- [ ] **1. RED races qua screen:** fake routing dùng một Completer RIÊNG cho mỗi request và lưu immutable copies của coordinates; không dùng một pendingCompleter chung cho cả ngày.
  - `day_one_late_success_cannot_replace_day_two`: ngày1 pending -> tap Ngày2 -> complete2 -> complete1; geometry/labels/token vẫn ngày2.
  - `old_success_after_new_day_failure_never_restores_old_route`: B fail thì không polyline A, kể cả A trả về sau.
  - `day_with_one_stop_stays_routeless_after_old_response`: chuyển sang ngày chỉ một stop rồi release route cũ; hasRoute false/loading false, một marker đúng ngày.
  - `rapid_day_a_b_a_and_binding_change_uses_latest_token`: mỗi lượt token tăng; last request thắng, không dùng destination/waypoints đã bị request khác sửa.
  - `stale_location_finally_and_camera_do_not_apply`: route/location completion cũ không tắt spinner/ghi error/fit camera của lượt mới. Quan sát MapController/camera thực từ widget tree hoặc test seam hẹp, không network tiles.
  - `dispose_releases_owned_context_without_clearing_new_owner`: pop A đang pending -> A token inactive; mở B/new token rồi dispose A không clear B; late A không notify/publish.
- [ ] **2. Run RED:** Targeted `test/dashboard_itinerary_map_test.dart`, `test/map_feature_test.dart`.
- [ ] **3. Implement:** Mỗi open/day change/place binding gọi begin một lần trước I/O và assign token mới. Reset route/selection/loading nhất quán, capture token + stops + camera target trong callback. Provider guard token/disposed ở success/error/finally; screen camera `.then` cũng guard mounted + token active. Dispose end đúng latest owned token bằng cached provider reference. Không chỉ tăng token trong unit test mà quên screen handler.
- [ ] **4. GREEN:** Lặp B2 command + B1 integration; kiểm route generation trong UI và thứ tự tọa độ, không chỉ stops labels.
- [ ] **5. Review/commit:** `fix(map): isolate itinerary day requests and camera updates` (selective hunks khi được phép).

## B3 — Revision bao cả OSRM và caller (CR7)

**Depends on:** B2 cho integration; service tests độc lập.

**Files:** Modify `lib/features/map/services/map_api_service.dart`, `lib/features/map/providers/map_provider.dart`, `test/backend_url_clients_test.dart`, `test/dashboard_itinerary_map_test.dart` (4 files).

**Interfaces:** Giữ public `MapApiService.getRoute({required LatLng origin, required LatLng destination, List<RouteWaypoint> waypoints = const []})`. Bổ sung named param `required int configRevision` cho private `_fetchDirectOsrmRoute(LatLng, LatLng, List<RouteWaypoint>, {required int configRevision})`; mọi call site truyền opRevision. Dùng `BackendConfigChangedException` đang có; MapProvider catch riêng exception này trước generic fallback.

- [ ] **1. RED transport tests:** Dio fake adapter/interceptor phân biệt backend và absolute OSRM URL; không gọi internet.
  - `url_change_during_osrm_success_rejects_old_operation`: backend 503/connectionError -> chặn OSRM -> config.setBaseUrl('http://192.168.1.99:9000') -> release GeoJSON hợp lệ; `expect(oldFuture, throwsA(isA<BackendConfigChangedException>()))`.
  - `url_change_during_osrm_error_preserves_invalidation`: cùng setup nhưng OSRM timeout/error; vẫn BackendConfigChangedException, không RoutingException/offline route.
  - `same_revision_osrm_still_succeeds`: revision không đổi, fallback OSRM thật giả lập trả geometry đúng, giữ semantics isFallback hiện có.
  - `new_operation_uses_new_host_without_retargeting_old_retry`: capture RequestOptions, old retries vẫn host cũ; request mới có uri.host '192.168.1.99'.
  - `config_change_does_not_create_local_line_in_provider`: qua MapProvider đang active -> config invalidation -> `expect(hasRoute, false)`; không `_generateLocalOfflineLine` cho exception này. Nếu đã chuyển ngày, error/loading của ngày mới không bị ảnh hưởng.
- [ ] **2. Run RED:** Targeted `test/backend_url_clients_test.dart`, `test/dashboard_itinerary_map_test.dart`.
- [ ] **3. Implement service:** Kiểm revision sau OSRM await và trước convert mỗi error/timeout; kiểm trong nhánh backend lỗi trả fallback lẫn nhánh response 503 không throw. Mọi completion của operation phải đi qua revision check; giữ absolute OSRM URL/retry timeout. Không mutate RequestOptions đang pending để đổi host.
- [ ] **4. Implement provider:** ConfigChanged là invalidate operation, clear/no geometry và thông báo cần tải lại nếu context vẫn hiện hành; không catch thành local-line fallback. Guard token trước mọi cập nhật để lỗi operation cũ không ghi vào context mới.
- [ ] **5. GREEN:** Lặp B3 command + `test/map_feature_test.dart`, `test/backend_api_config_test.dart`, `test/trip_api_adaptive_fallback_test.dart`. Kiểm headers fake transport không có Authorization Supabase.
- [ ] **6. Runtime check:** Dùng hot reload/restart Dart MCP khi có app QA an toàn; không reset/install/build live để tạo evidence. Không có runtime phù hợp ghi NOT RUN.
- [ ] **7. Review/commit:** `fix(map): fence OSRM fallback by backend config revision` (selective hunks khi được phép).

## Exit criteria / owner explanation

- CR3: request wire có đúng `[first, ...middle, last]`, GPS không tham gia itinerary; CR4: screen races/camera/dispose green; CR7: service và provider đều reject old revision.
- Giải thích owner: chọn ngày -> chụp stops + token -> service backend/OSRM -> chỉ context mới nhất được vẽ. Kiểm geometry và camera quan trọng như kiểm danh sách ngày.
- Full verification và handover chung theo master; không tự gọi source pass là native map acceptance.
