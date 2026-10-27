# Báo Cáo Bàn Giao C2 — Tách Input Planner Khỏi Decision Engine & Dọn Dẹp Mã Nguồn Ngoài Phạm Vi (Sau Sửa C2-F01, C2-F02, C2-F03)

**Thời gian:** 25/10/2026  
**Người thực hiện:** Antigravity (AI Engineering Agent)  
**Người nghiệm thu / Review:** Codex Independent Reviewer & Human Tech Lead  
**Baseline Git:**
- Branch: `fix/ai-planning-stability`
- Baseline candidate HEAD: `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`
- Trạng thái: Chỉ dirty changes C1/C2 (giữ nguyên toàn bộ file untracked, ảnh, docs, scripts của Owner). Chưa commit, chưa push, chưa merge, chưa deploy.

---

## 1. Changed — Danh sách tệp đã tạo mới và chỉnh sửa

### Tệp tạo mới:
1. `lib/features/trip_planner/providers/planner_input_provider.dart`:
   - Provider chuyên trách quản lý input chuyến đi độc lập (`PlanTripRequest`, `TripMetadataV1`).
   - Tích hợp `TripDatePolicy` để đồng bộ ngày và số ngày nhất quán.
   - Quản lý `workspaceGeneration`, kiểm tra regex điểm đến và eligibility AI.
   - Đã xử lý triệt để C2-F01 (chuyển đổi nguyên tử khi chọn preset/duration sau khoảng ngày) và C2-F02 (xóa nullable destination thực sự qua cơ chế sentinel).
2. `lib/features/explore/services/manual_place_locations.dart`:
   - Helper danh mục tọa độ / provenance tham khảo Wikidata chuyển từ `map` sang `explore`.
3. `test/planner_input_provider_test.dart`:
   - 8 test cases kiểm tra độc lập các luồng của `PlannerInputProvider`, bao gồm regression tests chính thức cho C2-F01, C2-F02, C2-F03 với `LegacyWriteSpy`.
4. `docs/phase-3/PENDING_DEPENDENCY_NATIVE_PATCH_C2.md`:
   - Tài liệu kiểm kê chi tiết phụ thuộc (`flutter_map`, `geolocator`, `latlong2`) và quyền Android (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) kèm proposed patch diff đang chờ Owner/Tech Lead phê duyệt.

### Tệp chỉnh sửa (Sửa lỗi C2-F01, C2-F02, C2-F03 & loại bỏ dual-write):
1. `lib/features/trip_planner/models/trip_request.dart`:
   - Bổ sung `_sentinel` pattern vào `copyWith` để phân biệt giữa tham số bị bỏ qua và tham số được truyền tường minh là `null`.
   - Bổ sung các helper methods: `clearDestination()`, `clearDates()`.
2. `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`:
   - Loại bỏ hoàn toàn `syncTrip` khỏi `_ProviderHomeInputState` (loại bỏ dual-write).
   - Khi `PlannerInputProvider` tồn tại, chỉ đọc và ghi duy nhất vào `PlannerInputProvider`.
   - Fallback sang `TripProvider` chỉ kích hoạt khi `PlannerInputProvider` hoàn toàn vắng mặt.
3. `lib/features/trip_planner/presentation/widgets/planner_workspace_actions.dart`:
   - Khi `PlannerInputProvider` tồn tại, tương tác trực tiếp với nó và `ManualPlannerProvider` (cho dirty/save guard), không ghi vào `TripProvider`.
   - Lưu snapshot `workspaceGeneration`, `activeDraftRevision`, `currentMetadata`, `activeDraftId` trước khi mở dialog xác nhận để chống stale race conditions.
4. `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`:
   - Đọc trực tiếp `PlannerInputProvider` khi có mặt trong tree.
5. `test/discovery_screen_test.dart` & `test/discovery_planner_flow_test.dart`:
   - `pumpDiscovery` chỉ inject `PlannerInputProvider` khi caller truyền vào, bảo toàn đường fallback cho các test legacy cũ.
6. `test/auth_role_security_test.dart`:
   - Loại bỏ trailing newline thừa, đảm bảo `git diff --check` đạt chuẩn 100%.

### Tệp đã gỡ bỏ (Out-of-Scope Modules):
- **Toàn bộ thư mục Map** (26 files trong `lib/features/map/`).
- **Toàn bộ thư mục Favorites** (5 files trong `lib/features/favorites/`).
- **Dashboard & Pareto / Decision Engine Charts** (`dashboard_result_screen.dart`, `budget_donut_chart.dart`, `itinerary_timeline_widget.dart`, `pareto_chart_widget.dart`, `trip_comparison_matrix_widget.dart`).
- **10 test suites chuyên biệt cho các module ngoài phạm vi đã bị gỡ**.

---

## 2. Why — Căn cứ kỹ thuật & Giải pháp đã thực hiện

1. **C2-F01 (Đồng bộ nguyên tử giữa request và metadata khi chọn preset sau khoảng ngày):**
   - *Nguyên nhân:* Trước đây khi người dùng đã chọn khoảng ngày (vd: 01/11 - 05/11 = 5 ngày), việc chọn preset 2 ngày chỉ cập nhật `numDays: 2` trên `PlanTripRequest` nhưng để `startDate`/`endDate` là null, trong khi `TripMetadataV1` vẫn lưu giữ khoảng ngày 01/11 - 05/11 (5 ngày). Khi `ManualTripFactory.fromInput` đối chiếu `expectedDays` (2) với metadata (5), nó ném ngoại lệ `EditableCodecException(invalid_input, dates)`.
   - *Giải pháp:* Trong `PlannerInputProvider.applyPreset()` và `setDuration()`, chúng tôi giữ nguyên `startDate` mà người dùng đã chọn và dùng `TripDatePolicy.calculateEndDate(startDate, numDays)` để tính lại `endDate` chính xác cho cả `PlanTripRequest` và `TripMetadataV1`. Dữ liệu giữa request và metadata luôn đồng nhất.

2. **C2-F02 (Xóa destination thực sự khi truyền `null`):**
   - *Nguyên nhân:* Hàm `copyWith` của `PlanTripRequest` sử dụng `destinationId ?? this.destinationId`, khiến việc truyền `destinationId: null` bị coi là không truyền gì và giữ nguyên ID cũ (vd: `'hue'`).
   - *Giải pháp:* Sử dụng `static const Object _sentinel = Object();` trong `copyWith` để phân biệt giá trị mặc định và giá trị `null` được truyền vào. Đồng thời, `setDestination(id: null, name: 'Phú Yên')` và `useSuggestedDestination()` xóa sạch `destinationId` cũ của catalogue.

3. **C2-F03 (Loại bỏ dual-write trong production):**
   - *Nguyên nhân:* `_ProviderHomeInputState` trong `HomePlannerScreen` trước đây vừa gọi `provider.updateRequest` vừa gọi `syncTrip?.updateRequest`, dẫn tới probe reviewer P5 đo được `legacy.writes == 1`.
   - *Giải pháp:* Loại bỏ hoàn toàn `syncTrip`. Giao diện `HomePlannerScreen` chỉ đọc và tương tác với `PlannerInputProvider` khi nó có mặt. Các thao tác thay đổi xuất phát điểm, ngày, preset, duration ghi trực tiếp vào `PlannerInputProvider` và tạo ra **0 legacy mutation calls**.

4. **Quản lý Boundary Native & Dependency:**
   - Tuân thủ Stage-Gate Protocol: Lập tài liệu kiểm kê chi tiết `docs/phase-3/PENDING_DEPENDENCY_NATIVE_PATCH_C2.md` và diff đề xuất cho `pubspec.yaml` (gỡ `flutter_map`, `geolocator`, `latlong2`) và `AndroidManifest.xml` (gỡ `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`), chờ Owner phê duyệt trước khi áp dụng.

---

## 3. Testing — Bằng chứng kiểm thử thực tế

### 3.1. Reviewer Independent Probes
Chạy file probe `.dart_tool/c2-codex-review/input_probe_test.dart` do Codex cung cấp:
- **P1 (Clear selected destination clears request & metadata):** **PASS**
- **P2 (Preset after calendar range creates valid manual doc via factory):** **PASS**
- **P3 (Catalogue to free-text clears catalogue ID in request):** **PASS**
- **P4 (Normal dated input without preset positive control):** **PASS**
- **P5 (Production dual-provider tree has ZERO legacy mutation calls):** **PASS**
- **Kết quả:** **5/5 PASS (100%)**

### 3.2. Targeted & Regression Suites
- `test/planner_input_provider_test.dart`: **8/8 PASS** (bao gồm unit tests và flow tests mô phỏng Probe P5).
- `test/planner_destination_ui_test.dart` & `test/discovery_planner_flow_test.dart`: **7/7 PASS** (bảo toàn toàn bộ các kịch bản stale confirmation dialog, auth epoch invalidate, offline reopen).

### 3.3. Full Verification Suite
Thực thi lệnh:
```powershell
powershell -File ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```
**Kết quả:**
- **`flutter analyze`**: `No issues found! (ran in 2.8s)` — **0 errors, 0 warnings** (Exit 0).
- **`flutter test`**: **1000/1000 PASS** (0 failed, 0 flaky) — thời gian chạy 1 phút 59 giây (Exit 0).
- **`node contracts`**: **91/91 PASS** (0 failed, 0 skipped) — Exit 0.
- **`git diff --check`**: Clean (Exit 0).
- **Trạng thái tổng thể**: **PASS TOÀN DIỆN (Exit 0)**.

---

## 4. Problems & Rủi ro còn tồn tại

1. **Dependency & Native Permissions:** `flutter_map`, `geolocator`, `latlong2` và các permission vị trí trong `AndroidManifest.xml` vẫn nằm trong file cấu hình nhằm tuân thủ quy tắc Stage-Gate. Cần Owner xác nhận duyệt proposal tại `docs/phase-3/PENDING_DEPENDENCY_NATIVE_PATCH_C2.md` để áp dụng.
2. **Device Runtime Verification:** Toàn bộ 1.000 test tự động và phân tích cú pháp đều xanh 100%. Tuy nhiên, việc khởi chạy thực tế trên thiết bị vật lý / Android emulator chưa được thực hiện trong phạm vi kiểm thử tự động của phase này.

---

## 5. Lesson Candidate — Bài học kinh nghiệm

**Problem:** Khi đưa vào một Provider mới (`PlannerInputProvider`) thay thế Provider cũ (`TripProvider`), việc giữ một adapter "dual-write" để các fixture kiểm thử cũ không bị gãy vô tình tạo ra sự phụ thuộc ngầm (hidden dependency), khiến ứng dụng production vẫn tiếp tục kích hoạt logic của hệ thống cũ.  
**Root Cause:** Cơ chế adapter đồng bộ hai chiều được thêm vào mà không phân định rõ ràng giữa "Production Runtime" và "Legacy Fallback Path".  
**Actionable Rule:** Khi tái cấu trúc tách Provider, phải tách rạch ròi 2 đường: Nếu Provider mới tồn tại, luồng UI và workspace chỉ đọc/ghi duy nhất vào Provider mới; Provider cũ chỉ được kích hoạt trong fallback path khi Provider mới hoàn toàn vắng mặt. Luôn viết bài kiểm tra spy assertion (như Probe P5) để chứng minh `legacy.writes == 0`.
