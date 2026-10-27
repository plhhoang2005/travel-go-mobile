# Radar Realtime Room Disconnect, Reconnect & Lifecycle Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để lỗi không thể rời phòng radar, lỗi treo "Đang kết nối..." khi vào lại phòng, lỗi vị trí thành viên vẫn hiển thị sau khi rời nhóm, và lỗi mất đồng bộ vị trí giữa 2 thiết bị khi một thiết bị thoát app đột ngột.

**Architecture:** 
1. **Optimistic Local Teardown & Non-Blocking Departure:** Ngay khi nhấn "Rời phòng", `MapProvider` lập tức dọn dẹp state nội bộ (`_isGroupRadarEnabled = false`, `_groupMembers = []`, `_activeGroupId = null`), đóng modal ngay lập tức; tác vụ mạng gửi packet `member_left` và unsubscribe Supabase được bọc timeout ngắn (2s) và chạy an toàn ở background, không chặn UI thread (Law 4).
2. **Channel Serialization & Connection Timeout Guard:** Bổ sung timeout (6s) cho `joinGroup` và `connectGroupRadar`, ngăn chặn race condition giữa tác vụ unsubscribe cũ và channel subscribe mới, triệt tiêu lỗi treo button "Đang kết nối...".
3. **Heartbeat TTL & Stale Member Eviction Engine:** Triển khai cơ chế quét định kỳ (mỗi 5s) trong `GroupLocationService`. Nếu thành viên nào không gửi `location_ping` quá 15s sẽ chuyển sang trạng thái `idle/offline`; quá 30s sẽ tự động xóa khỏi danh sách radar, giải quyết triệt để vấn đề "ghost markers" khi một máy tắt app đột ngột.
4. **Stable User Identity & App Lifecycle Integration:** Giữ nguyên `_myUserId` ổn định theo phiên app thay vì sinh random mỗi lần click kết nối; tích hợp `WidgetsBindingObserver` để tự động dọn dẹp kết nối khi app bị kill/paused.

**Tech Stack:** Flutter 3.x, Dart 3.x, Provider, Supabase Realtime Broadcast, Geolocator, fl_chart / flutter_map.

**Spec:** Bug Report từ 5 ảnh đính kèm (Ảnh 1: nút Rời phòng không đóng modal; Ảnh 2: form kết nối hiện nhưng map vẫn còn banner; Ảnh 3: nút KẾT NỐI PHÒNG RADAR bị treo "Đang kết nối..."; Ảnh 4: thành viên đã rời nhưng marker vẫn còn; Ảnh 5: máy B thoát app đột ngột khiến máy A giữ marker cũ và máy B vào lại phải kết nối lại).

---

## Global Constraints
- Không vi phạm 5 Luật Bất Biến (AGENTS.md): Không chatbot, không silent fallback, không chặn UI thread, tôn trọng Stage-Gate Protocol.
- Không thêm dependency mới vào `pubspec.yaml` (tuân thủ Permission Boundary).
- Toàn bộ thay đổi phải vượt qua `flutter analyze` (0 warnings/errors) và `flutter test` (100% pass).

## Review Focus
1. **Mất mạng khi bấm "Rời phòng":** Nếu ngắt kết nối mạng hoặc server Supabase chậm, modal phải đóng ngay lập tức và map phải xóa hết marker thành viên, không được treo UI.
2. **Double-tap hoặc spam bấm "KẾT NỐI PHÒNG RADAR":** Nút phải disable khi đang kết nối, có timeout 6s nếu mạng lag, reset `_isConnecting = false` và hiện SnackBar báo lỗi rõ ràng nếu thất bại.
3. **Máy B bị kill hoặc vuốt tắt từ Recent Apps:** Sau 15-20s, máy A phải tự động gỡ marker của máy B trên bản đồ mà không cần máy B gửi gói `member_left`.
4. **Máy B kết nối lại sau khi mở lại app:** Không được tạo thành 2 marker trùng lặp trên máy A (nhờ `_myUserId` ổn định hoặc cơ chế upsert theo deviceId).
5. **Dữ liệu Demo Fallback:** Nếu kết nối thật thất bại do sai mã phòng hoặc timeout, phải thông báo rõ ràng cho người dùng, không được tự ý âm thầm bật 4 thành viên demo khi người dùng đang kết nối phòng thật.

---

### Task 1: Sửa cơ chế ngắt kết nối Optimistic & Dọn dẹp State trong `MapProvider` và `GroupRadarSheet`

**Files:**
- Modify: `lib/features/map/providers/map_provider.dart:320-355`
- Modify: `lib/features/map/presentation/widgets/group_radar_sheet.dart:305-325`
- Test: `test/map_feature_test.dart`

**Interfaces:**
- Consumes: `GroupLocationGateway.markOffline(groupId)`
- Produces: `MapProvider.disconnectGroupRadar()` hoàn thành ngay lập tức (optimistic), xóa sạch `_groupMembers = []`, không chặn UI.

- [ ] **Step 1: Viết failing test trong `test/map_feature_test.dart`**
  Kiểm tra `disconnectGroupRadar()`:
  - `isGroupRadarEnabled` lập tức chuyển thành `false`.
  - `activeGroupId` lập tức thành `null`.
  - `groupMembers` lập tức rỗng `isEmpty == true`.
  - Không ném exception và thông báo `notifyListeners()` ngay.

- [ ] **Step 2: Chạy test để xác nhận test fail hoặc pass**
  Run: `flutter test test/map_feature_test.dart`

- [ ] **Step 3: Cập nhật `disconnectGroupRadar()` trong `lib/features/map/providers/map_provider.dart`**
  - Đặt `_groupMembers = [];` ngay khi bắt đầu disconnect.
  - Gọi `notifyListeners();` ngay lập tức để UI cập nhật (tắt banner, xóa marker trên map).
  - Bọc lời gọi `_groupLocationService.markOffline(groupId)` trong `unawaited` với `.timeout(const Duration(seconds: 2))` để không chặn UI thread.

- [ ] **Step 4: Cập nhật nút "Rời phòng / Tắt Radar" trong `lib/features/map/presentation/widgets/group_radar_sheet.dart`**
  - Thêm state `bool _isDisconnecting = false;`.
  - Khi bấm nút: hiện `CircularProgressIndicator` nhỏ trên nút và gọi `Navigator.of(context).pop()` ngay khi `disconnectGroupRadar()` được kích hoạt.

- [ ] **Step 5: Chạy lại test để xác nhận pass**
  Run: `flutter test test/map_feature_test.dart`

---

### Task 2: Thêm Timeout Guard & Khắc phục lỗi Treo "Đang kết nối..." (Case 1 - Ảnh 3)

**Files:**
- Modify: `lib/features/map/services/group_location_service.dart:45-120`
- Modify: `lib/features/map/providers/map_provider.dart:270-322`
- Modify: `lib/features/map/presentation/widgets/group_radar_sheet.dart:38-68`
- Test: `test/map_feature_test.dart`

**Interfaces:**
- Consumes: `GroupLocationService.joinGroup(...)`
- Produces: `Future<String> joinGroup(...)` có timeout 6s, xử lý dọn dẹp channel an toàn, ném `TimeoutException` có kiểm soát.

- [ ] **Step 1: Viết test cho Timeout & Connection Error Handling**
  Viết test giả lập gateway treo quá 6s và xác nhận `connectGroupRadar` bắt lỗi, cập nhật message và không treo app.

- [ ] **Step 2: Chạy test để kiểm tra**
  Run: `flutter test test/map_feature_test.dart`

- [ ] **Step 3: Cập nhật `joinGroup` và `markOffline` trong `group_location_service.dart`**
  - Bổ sung `timeout(const Duration(seconds: 3))` cho `_activeChannel?.unsubscribe()`.
  - Nếu `_activeChannel` đã tồn tại, đảm bảo tháo channel an toàn trước khi gọi `_client.channel(...)`.
  - Sinh và lưu trữ `_myUserId` cố định theo instance thay vì sinh lại timestamp mỗi lần join để tránh clone ghost members.

- [ ] **Step 4: Cập nhật `_handleConnect` trong `group_radar_sheet.dart`**
  - Bọc `connectGroupRadar` với try-catch có SnackBar hiển thị lỗi cụ thể nếu timeout / mất mạng.
  - Đảm bảo `finally` luôn gán `_isConnecting = false` để nút không bao giờ bị treo vĩnh viễn ở trạng thái "Đang kết nối...".

- [ ] **Step 5: Chạy test xác nhận pass**
  Run: `flutter test test/map_feature_test.dart`

---

### Task 3: Triển khai Stale Member Eviction Engine (TTL Heartbeat) (Case 2 & Case 3 - Ảnh 4 & 5)

**Files:**
- Modify: `lib/features/map/services/group_location_service.dart`
- Modify: `lib/features/map/providers/map_provider.dart`
- Test: `test/map_feature_test.dart`

**Interfaces:**
- Produces: Periodic TTL pruner tự động phát hiện thành viên không còn gửi ping quá 15s để chuyển offline, quá 30s để xóa khỏi bản đồ.

- [ ] **Step 1: Viết unit test cho Heartbeat TTL Pruning**
  Tạo member có `updatedAt` cách đây 35s. Chạy phương thức prune và assert rằng member đó bị remove khỏi danh sách active.

- [ ] **Step 2: Chạy test để xác nhận fail**
  Run: `flutter test test/map_feature_test.dart`

- [ ] **Step 3: Triển khai Timer Pruning trong `GroupLocationService`**
  - Thêm `Timer? _staleMembersTimer;`.
  - Mỗi 5 giây kiểm tra `_activeMembers`:
    - Nếu `now.difference(m.updatedAt) > Duration(seconds: 30)`: remove khỏi `_activeMembers`.
    - Nếu `now.difference(m.updatedAt) > Duration(seconds: 15)`: cập nhật `status: GroupMemberStatus.idle`.
  - Đẩy danh sách đã cập nhật qua `_membersController`.
  - Dọn dẹp `_staleMembersTimer?.cancel()` trong `markOffline` và `dispose`.

- [ ] **Step 4: Chạy test để xác nhận pass**
  Run: `flutter test test/map_feature_test.dart`

---

### Task 4: Tích hợp App Lifecycle (`WidgetsBindingObserver`) & Đồng bộ Map Screen

**Files:**
- Modify: `lib/features/map/presentation/screens/trip_map_screen.dart`
- Modify: `lib/features/map/providers/map_provider.dart`
- Test: `test/map_feature_test.dart`

**Interfaces:**
- Tự động tạm dừng phát GPS khi app vào background (`AppLifecycleState.paused` / `inactive`), và thông báo `member_left` nếu app bị detach.
- Khôi phục stream vị trí khi app resume.

- [ ] **Step 1: Viết test cho AppLifecycle handling**
  Kiểm tra khi provider nhận signal pause / detach thì dừng timer ping vị trí để tránh hao pin và treo socket.

- [ ] **Step 2: Chạy test**
  Run: `flutter test test/map_feature_test.dart`

- [ ] **Step 3: Triển khai `WidgetsBindingObserver` trong `TripMapScreen`**
  - Trong `didChangeAppLifecycleState`:
    - Khi `AppLifecycleState.paused`: gọi `provider.onAppPaused()`.
    - Khi `AppLifecycleState.resumed`: gọi `provider.onAppResumed()`.
    - Khi `AppLifecycleState.detached`: gọi `provider.disconnectGroupRadar()`.

- [ ] **Step 4: Chạy toàn bộ test suite và analyze**
  Run: `flutter analyze`
  Run: `flutter test`

---

## Handover & Verification Checklist
1. `flutter analyze` trả về 0 errors, 0 warnings.
2. `flutter test` vượt qua toàn bộ 82+ tests.
3. Không thêm bất kỳ library ngoại lai nào vào `pubspec.yaml`.

