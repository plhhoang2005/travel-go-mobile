# C1 — Codex re-review R2, 24/10/2026

**Verdict: ACCEPT C1 — SOURCE / AUTOMATED CHECKS. F01 và F02 CLOSED.**

Không phát hiện finding mới có thể hành động trong phạm vi C1 được review. Chưa nghiệm thu APK/thiết bị, chưa chấp nhận toàn project hoặc C2. Có thể chuyển sang task C2 theo R2 đã duyệt và phân công Antigravity implement/Codex review; không tự mở quyền deploy/merge/native/DB live.

## 1. Changed — ai sửa gì, Codex kiểm gì

- Actual branch `fix/ai-planning-stability`; actual HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty source/tests. Chưa có commit C1.
- Antigravity gỡ import/nút map ở Explore, thêm test navigation toàn luồng và cập nhật sáu file regression theo scope mới. Các thay đổi C1 ban đầu giữ nguyên.
- So với fingerprints review R1, trong bộ source/test từng fingerprint chỉ Explore và coursework_navigation_test đổi; sáu regression còn lại được đối chiếu bằng git diff với baseline. Không chỉ tin báo cáo author.
- Codex đọc diff/source/tests và chạy Full độc lập; không sửa app/backend/permanent tests, không deploy/DB mutation, stage/commit/push/merge, không gọi Gemini/email thật hoặc thao tác thiết bị. Tạo report R2 và cập nhật tiến độ docs. Các artifacts/ảnh/scripts của owner giữ nguyên.
- Fingerprint snapshot trước chạy trong `.dart_tool/c1-r2-review-source-snapshot.json`: **344 source/test/backend/tool files không thay đổi** trong lúc kiểm chứng. Snapshot ignored, không phải artifact sản phẩm.

## 2. Why — findings đóng bằng evidence

### F01 — CLOSED: tab Khám phá không còn entry map

`lib/features/explore/presentation/screens/explore_screen.dart` đã bỏ import TripMapScreen và IconButton tooltip Bản đồ. Search constructors/route usages trong lib: các map/legacy dashboard module còn theo C2, nhưng không còn route vào từ Explore/luồng manual đang phục vụ. Không yêu cầu xóa map module trong C1.

Test mới `explore_and_home_planner_navigation_without_map` mount MainNavigationShell ở Explore, kiểm không có tooltip/icon map, tìm Huế→detail→Chuẩn bị chuyến đi→HomePlanner→ManualPlannerScreen, kiểm destination hue và spy engineCalls=0, editor không có nút map.

**Giới hạn chính xác:** test này chứng minh route/UI entry không có và planTrip không được gọi; không có dedicated map HTTP spy nên không dùng test để khẳng định đã đo zero map network calls. Tên/comment “0 map calls” của test cũ không bổ sung một phép đo network. Không còn blocker F01 về reachable map entry.

### F02 — CLOSED: regression được chuyển đúng boundary, Full exit 0

| File cập nhật | Đánh giá reviewer |
| --- | --- |
| `discovery_planner_flow_test.dart` | Kiểm nút guest không có, CTA mới còn; gọi service draft trực tiếp để giữ test legacy disk reopen/destination, không tái thêm entry UI |
| `editable_saved_trip_ui_test.dart` | Guest list entry đổi sang empty/login state; vẫn giữ assertions actual expense/date, disk revision và zero account writes |
| `editable_guest_import_ui_test.dart` | MyTrips không có entry; component EditableGuestDraftList được mount độc lập để kiểm V2 đúng và không ghi account ngoài ý muốn |
| `guest_draft_planner_test.dart` | Kiểm CTA mới/nút guest absent; dirty-cancel dùng replacePlannerWorkspace; dialog disk-error/disposal được mount độc lập, không skip nghiệp vụ |
| `manual_day_map_test.dart` | Editor không có map; giữ selected day/dirty/AI limitation. Account invalidation được kiểm trên form trip subroute còn phục vụ thay route map đã bỏ |
| `manual_planner_end_to_end_test.dart` | Giữ persistence/reopen, source digest/title, explicit legacy import qua component độc lập, offline read-only và A→B hiding/cache isolation assertions |

Không thấy thêm skip trong bảy file test của gói sửa. Test mixed không bị xóa nguyên; standalone fixtures là đúng chỗ để giữ module legacy tới C2. Không coi legacy guest tests là sản phẩm còn hỗ trợ guest-import. Khi C2 thật sự xóa module phải chuyển invariant còn trong scope sang account flow và chỉ bỏ phần riêng guest/map; không xóa assertions lưu/đọc/account isolation.

Chuỗi giữ lại vẫn là Home/Explore→input→manual editor, không submit Decision Engine; bốn tab giữ profile đúng index; hủy thay editor giữ digest/dirty. Đây là các behavior có widget/service evidence, không phải runtime phone acceptance.

## 3. Testing — chạy độc lập trên final candidate

Command thực tế:

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Wrapper ghi `.dart_tool/c1-codex-r2-full.log`; runner directory `.dart_tool/travelgo-verification/20261024T145734813Z-22700/`.

| Check | Fresh result | Evidence |
| --- | --- | --- |
| analyze | PASS, exit 0; No issues found, 4.8s | `analyze.log` |
| Flutter full suite | **1125/1125 PASS**, exit 0; 2:14, không có [E]/Some tests failed | `flutter-tests.log` |
| Node contracts | **91/91 PASS**, fail 0, skipped 0, exit 0 | `node-contracts.log` |
| Full wrapper | exit 0 | `.dart_tool/c1-codex-r2-full.log` |
| whitespace | `git diff --check`, exit 0; line-ending warnings không phải errors | command reviewer |
| consistency | 344 source/test/backend/tool hashes không đổi trong review | ignored snapshot |

Toàn Flutter suite bao gồm bốn tests C1 mới và sáu file từng có 11 failures; không cần lặp lại targeted sau Full đã PASS trên cùng source. Author ghi “1124+”; reviewer ghi exact fresh count 1125. Không dùng logs 144754 của author thay run reviewer 145734.

Flutter SDK yêu cầu quyền ghi lockfile ngoài workspace nên reviewer dùng escalation cho command kiểm thử; không có automatic-approval rejection. Việc đó không sửa SDK/dependencies hay cấp quyền deploy. Không gọi live AI/email/SQL, không build/install/hot reload vì reviewer không đổi Dart; runtime **NOT RUN**.

## 4. Problems / giới hạn / bước tiếp

- Không có finding C1 mới cần sửa từ diff đã review. F01/F02 không còn OPEN.
- “C1 đạt” nghĩa code review và local automated checks, không phải toàn app ổn định trên phone. Recovery issues, catalogue evidence pipeline, web grounding và source persistence nằm ở task sau, chưa được review này đóng.
- Candidate chưa commit; sửa source tiếp sẽ cần đối chiếu lại hashes/tests liên quan. Không đưa approval source cũ áp vào code mới một cách tự động.
- C2 đã nằm trong kế hoạch owner duyệt: tách input provider, chuyển callers rồi mới dọn modules/deps/quyền. Không xóa helpers catalogue/shared storage hay dữ liệu cũ. Native/dependency diff và live/build actions theo quyền đã ghi trong plan; review này không cấp quyền mới.
- Khi chuẩn bị C2, tránh gọi những test legacy standalone còn PASS là tính năng UI vẫn cần giữ; chúng chỉ bảo vệ dữ liệu/module cho tới khi C2 chuyển callers/test invariants.

## 5. Lesson Candidate — giải thích cho owner

**Trước:** mở Khám phá vẫn có thể vào bản đồ; tests cũ đi qua các nút guest/map đã xóa nên dừng trước khi kiểm dữ liệu.

**Sau:** entry map đã gỡ; luồng Khám phá→Huế→editor được kiểm trực tiếp. Những test cho lưu đĩa và cô lập A/B không còn phụ thuộc việc user nhìn thấy guest/map button, nên chúng tiếp tục kiểm đúng invariant trong phạm vi C1.

Problem→Root Cause→Actionable Rule: “gỡ tính năng nhưng test mất đường tới invariant”→“test gắn chặt một entry đã bỏ”→“tách assertions về UI scope khỏi assertions dữ liệu, giữ test dữ liệu ở component/service còn tồn tại”. Khi C2 xóa module, chuyển invariant account còn cần sang production account flow trước.
