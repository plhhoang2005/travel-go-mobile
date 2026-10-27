# C1 — Codex independent review, 24/10/2026

**Verdict: REQUEST CHANGES. Chưa chấp nhận C1 hoàn thành; chưa chuyển C2.**

## 1. Changed — phạm vi review và findings

Review branch `fix/ai-planning-stability`, base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1 source/tests. Đọc diff thực, test mới, callers giữ lại và handoff Antigravity do owner dán. Không dùng Superpowers: owner yêu cầu skill cho task lập plan trước, không tự cấp quyền cho task review này. Áp dụng project context và ui-ux-pro-max cho kiểm điều hướng/scope; không tạo thiết kế mới.

Codex không sửa app/backend/permanent tests, không tạo branch, stage/commit/push/merge/deploy, không DB mutation hoặc gọi AI/email thật. Chỉ tạo report này; commands ghi verification logs trong .dart_tool ignored. Docs/ảnh/scripts dirty của owner giữ nguyên.

### F01 [P2] Vẫn mở được bản đồ từ tab Khám phá

**Source:** `lib/features/explore/presentation/screens/explore_screen.dart:61–68`. IconButton tooltip `Bản đồ` vẫn Navigator.push tới `TripMapScreen`; import ở line 10 vẫn còn. Tab Khám phá vẫn là tab chính trong MainNavigationShell nên route này còn reachable, không phải code chết đang chờ C2.

**Ảnh hưởng:** người dùng vẫn thấy và mở một chức năng owner đã loại; việc bỏ nút bản đồ khỏi ManualPlannerScreen chưa hoàn thành yêu cầu C1 “bỏ UI entry map”. C2 mới là xóa module/dependency; ẩn entry Khám phá thuộc chính C1. Đây là gap theo scope đã duyệt, không khẳng định map runtime crash.

**Kiểm test:** coursework_navigation_test.dart chỉ kiểm `find.text('Bản đồ ngày này')` không có ở manual editor. Không có map network spy; câu “0 map calls” trong tên/comment không được assertion đo. Vì không kiểm Explore, ba test PASS vẫn lọt entry này.

**Đóng khi:** gỡ UI/route entry map ở Explore (giữ module tới C2), thêm test đi qua main shell→Explore không có CTA Bản đồ và không dispatch map/network route. Kiểm đồng thời Home/Explore→planner đúng destination. Nếu báo “mapCalls=0” phải đo bằng injected spy/transport có thực, hoặc giới hạn đúng claim chỉ là không có entry map; không coi label absence là network proof.

### F02 [P2] Full regression chưa đồng bộ với UI C1, vẫn exit 1

**Fresh result:** `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter` kết thúc **1113 PASS / 11 FAIL, exit 1**. Analyzer PASS. Full runner dừng ở Flutter fail nên Node stage của chính lần Full không chạy; Codex chạy Node riêng được 91/91 PASS.

| File | Failure count | Điểm còn kỳ vọng UI đã loại |
| --- | ---: | --- |
| `test/discovery_planner_flow_test.dart` | 1 | Lưu bản nháp Guest từ planner |
| `test/editable_saved_trip_ui_test.dart` | 1 | Mounted Guest list |
| `test/editable_guest_import_ui_test.dart` | 1 | Guest list mở V2 draft |
| `test/guest_draft_planner_test.dart` | 5 | Guest save/list/dialog controls |
| `test/manual_day_map_test.dart` | 2 | Nút Bản đồ ngày này trong editor |
| `test/manual_planner_end_to_end_test.dart` | 1 | Guest list/import trước offline/A→B fencing |

Các lỗi log phù hợp UI đã bị gỡ, không tự chứng minh 11 lỗi nghiệp vụ trong chức năng giữ lại. Nhưng cũng không thể gọi toàn C1 PASS khi Full required còn fail và bài end-to-end giữ dữ liệu/account fencing không còn chạy tới assertions phía sau.

Plan có điểm giao thoa: C2 cho dọn tests của module bị xóa, trong khi C1 yêu cầu Full khi chốt và đã cho sửa navigation tests bị đổi UI. Cách xử lý tối thiểu: **C1 cập nhật regression bị đổi UI; C2 mới xóa module/dependency**. Không chuyển nguyên các failures sang C2 rồi tick C1 hoàn thành.

**Đóng khi:** audit từng ca; test chỉ phục vụ entry bị loại chuyển thành assertion không có entry hoặc test module standalone nếu còn cần tới C2. Test hỗn hợp phải giữ/di chuyển assertions legacy read, budget, save/read và A→B/account isolation sang account flow còn hỗ trợ. Không xóa cả file/chỉ skip assertions để lấy PASS. Targeted C1 và Full đều exit 0; báo counts/logs trên đúng final source.

## 2. Why — những phần làm đúng và luồng đã kiểm

- Main shell thực đã còn bốn tab; không thấy caller initialIndex khác còn hardcode profile 4 trong lib. Clamp chỉ là guard, không thay đổi ý nghĩa một route được kiểm.
- HomePlannerScreen primary CTA gọi openManualPlanner, không submitPlan. Manual entry vẫn giữ input snapshot và popup thay bản chỉnh sửa, mở ManualPlannerScreen enableBudget=true.
- Nút map ở manual editor và guest-import ở MyTrips đã gỡ; module/adapter/SQL/native/dependency chưa bị xóa. Đúng ranh giới tách UI C1 trước module C2.
- Test mới đã chứng minh Huế đi vào editor với đúng destination và engineCalls=0, hủy thay editor giữ dirty/digest. Đây là widget/source evidence, chưa kiểm APK thật, actual map HTTP calls hoặc toàn thông số ngày/số người/budget xuyên Home/Explore.
- Profile vẫn có phần cấu hình Backend API; khi cleanup tiếp cần đối chiếu scope và callers còn lại, không tự sửa thêm trong review. Không nâng thành finding độc lập khi dependency legacy chưa dọn.

## 3. Testing — commands, exits và giới hạn

1. Lần Full đầu chạy trong quyền mặc định bị chặn bởi SDK lockfile `D:/flutter/flutter/bin/cache/lockfile`; analyzer exit -1073741816. Đây là lỗi quyền môi trường, không lỗi app. Log `.dart_tool/travelgo-verification/20261024T140434285Z-27328/analyze.log`.
2. Sau khi được phép chạy SDK ngoài workspace, Full chạy trên source C1: analyzer **No issues found**, exit 0, 4.0s; Flutter **1113 PASS / 11 FAIL**, exit 1, 2:12. Logs `.dart_tool/travelgo-verification/20261024T140450874Z-20556/{analyze,flutter-tests}.log`. Không chạy vòng sửa nào vì review chỉ đọc.
3. Targeted độc lập: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/coursework_navigation_test.dart -FlutterRoot D:/flutter/flutter`: **3/3 PASS**, exit 0. Log `.dart_tool/travelgo-verification/20261024T140732266Z-19412/flutter-tests.log`, wrapper `.dart_tool/c1-codex-targeted-review.log`.
4. `node --test test/ai_gateway_test.mjs test/itinerary_gateway_test.mjs test/catalogue_readiness_test.mjs`: **91/91 PASS**, zero failures/skips. Log `.dart_tool/c1-codex-node-review.log`.
5. `git diff --check`: exit 0. LF/CRLF conversion warnings không phải whitespace failure.

Author báo 14 lỗi ở lần chạy của họ; reviewer có **11 lỗi tại source hiện đọc**, không thay số liệu lịch sử bằng số hiện tại. Report không chứng nhận chu kỳ RED cũ: reviewer chỉ kiểm final candidate. Ảnh fixture HTTP400 trong widget tests không chứng minh ảnh thiết bị lỗi hoặc mạng thật đã test. Không build/install/hot reload vì không sửa Dart; không native UI/SQL/live service acceptance.

## 4. Problems — next repair packet cho Antigravity

Thực hiện đúng hai findings, không bắt đầu C2:
1. Gỡ entry map Explore và bổ sung coverage main-shell/Explore; giữ map module/dependency/native config.
2. Cập nhật từng regression UI bị tác động, giữ assertions chức năng còn trong scope (nhất là save/read và A→B). Chạy targeted rồi Full trên final diff, không skip cả file hoặc coi tất cả failures tự hết ở C2.
3. Bàn giao exact base/final HEAD hoặc dirty-file hashes, diff files, commands/exits/counts/logs, test nào được đổi/xóa và vì sao, runtime NOT RUN. Không commit/push/deploy hoặc sửa recovery/AI/native/dependency ngoài task.

Scope C1 đã duyệt, không cần xin lại quyết định xóa UI map hay cập nhật test đúng scope. Cần review sửa xong trước chuyển C2; chưa nghiệm thu chỉ từ 3 test mới PASS.

## 5. Lesson Candidate

- Problem: manual editor không còn map nhưng app vẫn mở map → Root cause: kiểm một màn thay vì toàn entry graph → Rule: review route từ mọi tab chính; “module còn tồn tại” khác với “UI vẫn reachable”.
- Problem: test cũ fail trước account/legacy assertions → Root cause: feature removal thay entry nhưng regression vẫn nối qua entry cũ → Rule: migrate tests cùng UI change, giữ invariant dữ liệu ở entry mới thay vì skip cả bài.

## Reviewed file fingerprints

Source/test candidate không commit; dùng hashes dưới đây để phát hiện revision đổi trước review lại. Đây là fingerprint file, không là commit hash.

| File | SHA-256 |
| --- | --- |
| `lib/features/navigation/presentation/screens/main_navigation_shell.dart` | `5903c8bc372b4cae02504c384e5d553ecfb596c90c010d6ae0cc98373bab1548` |
| `lib/features/trip_planner/presentation/screens/home_planner_screen.dart` | `918b1915ffc95aefa723976de8bc1e9a2283a384b7c87560119605f0fc0bad17` |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | `487bf7b32b083a1aa80681d26ec92e96eb9140fa2fbd63be4c39bbe00989390e` |
| `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart` | `f960d36b8ce59a87ecf501f4f38c85f9359d719221efde29a2ae680bc642630f` |
| `lib/features/trips/presentation/screens/my_trips_screen.dart` | `3a1da7bc8bd07c9d15506aa8eab232125efd1c2eb74582a45fc7269f8bc2b96a` |
| `test/coursework_navigation_test.dart` | `b1cc618cf59a5e0590d4a7f2076ec92391951af1be46d75f317deb24fcde0a73` |
| `test/auth_navigation_test.dart` | `4dd26ba30880894fe6414adfc710deaa4d44268f80e22126508dfd2094a35fa0` |
| `test/home_planner_screen_adaptive_ui_test.dart` | `16ea197166b1b06e52f275ea2a33d5ca524b5d79bebf290a1ff570abdf4992f6` |
| `test/trip_input_visual_test.dart` | `dee13c0e167e9b664780aad05473e1457317dd6b7b442f3bb2fa2759a3b914a2` |
| `lib/features/explore/presentation/screens/explore_screen.dart` | `b8ccaf8f95df93dee151ca111d20eefb7ac6208ff9117f69d3896e22cb6350b7` |
