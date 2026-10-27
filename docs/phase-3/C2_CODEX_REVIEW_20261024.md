# C2 — Codex independent review, 24/10/2026

**Verdict: REQUEST CHANGES. C2 chưa được chấp nhận hoàn thành; chưa chuyển C3.**

## 1. Changed — phạm vi, nguồn và findings

Repo `D:/Travel-Go-Android/travel-go`; branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2 changes. Owner gửi handover Antigravity để Codex re-review. Đọc source thật, diff, plan C2, logs author và chạy checks/probe độc lập; không chỉ tin “100% trơn tru/tương thích hoàn hảo”. Không dùng Superpowers vì quyền trước đó dành cho lập kế hoạch, không tự áp sang review.

Codex không sửa product/permanent tests/backend/native/deps, không stage/commit/push/merge/deploy hoặc DB mutation. Reviewer tạo report này, probe synthetic Git-ignored `.dart_tool/c2-codex-review/input_probe_test.dart`, logs và hash snapshot. 315 source/test/backend/tool/native/dependency files không đổi trong review. Các dirty docs/ảnh/scripts của owner giữ nguyên.

### C2-F01 [P2] Chọn preset sau khoảng ngày làm input/metadata mâu thuẫn, không mở được editor

**Source:** `lib/features/trip_planner/providers/planner_input_provider.dart:97–110`, `applyPreset:180–187`; consumer `ManualTripFactory.fromInput`.

**Repro P2:** input mới→setCalendarRange('2026-11-01','2026-11-05')→applyPreset(3). Request mới là 2 ngày, start/end=null; metadata vẫn giữ 01–05/11 (5 ngày). Factory dùng metadata cũ để validate expectedDays=2 và ném `EditableCodecException(invalid_input, dates)`. Probe expected returnsNormally thực sự FAIL, không lỗi harness. P4 cùng date range không apply preset tạo doc 5 ngày PASS.

**Ảnh hưởng người dùng:** ở form chưa chọn điểm đến, sau chọn ngày rồi bấm preset “2 ngày”, bấm lập lịch không mở được editor dù UI vẫn nhận preset. Đây là gap consistency trong provider mới C2; không khẳng định mọi thao tác chọn ngày đều lỗi. Logic cũ có thể có cùng giới hạn, nhưng không phải lý do bỏ qua yêu cầu C2 tạo input nhất quán.

**Hướng sửa/đóng:** cập nhật request và metadata nguyên tử theo một chính sách preset được giải thích rõ. Có thể giữ ngày bắt đầu và tính lại kết thúc theo duration hoặc bỏ cả khoảng ngày; không giữ range cũ một bên. Bổ sung regression calendar→cả ba presets→factory, đối chứng calendar→setDuration, kiểm preview và editor cùng số ngày. Không nới validator cho phép dữ liệu mâu thuẫn.

### C2-F02 [P2] Truyền null qua copyWith không xóa destination cũ trong request

**Source:** `planner_input_provider.dart:80–85` và `171–175`; `PlanTripRequest.copyWith` dùng `destinationId ?? this.destinationId` và tương tự name.

**Repro P1:** setDestination(hue,Huế)→useSuggestedDestination(). Metadata ID=null nhưng request ID vẫn hue/name Huế.
**Repro P3:** setDestination(hue,Huế)→setDestination(id:null,name:'Phú Yên'). Metadata ID=null/name Phú Yên, request vẫn ID hue/name Phú Yên. Hai assertions expected null đều FAIL; không phải AI thực trả sai địa điểm.

**Ảnh hưởng:** cùng một input có hai danh tính điểm đến; UI dùng metadata, consumer khác có thể dùng request cũ. Hiện factory ưu tiên metadata nên report không suy rằng đã lưu nhầm Huế; điều đã chứng minh là clear contract không thực hiện và request/name có thể không cùng điểm đến. Free-text end-to-end còn phải hoàn thiện ở C5, nhưng setter/null semantics là trách nhiệm provider mới C2.

**Hướng sửa/đóng:** có API clear/set nullable thật hoặc rebuild immutable request tường minh, cập nhật request/metadata cùng lúc; giữ các tham số còn lại đúng chủ đích. Không gắn slug catalogue giả cho free-text. P1/P3 GREEN, clear sau khi có ngày phải giữ date policy nhất quán, ordinary selection/update không regression.

### C2-F03 [P2] Production vẫn ghi vào TripProvider cũ, chưa tách đường input theo C2

**Source:** `_ProviderHomeInputState` trong `home_planner_screen.dart:119–160`, wiring `main.dart:641–675`, `planner_workspace_actions.dart` còn mutate legacy rồi input.

Production đăng ký cả hai provider; Home watch cả hai và tạo adapter mới có syncTrip. Mỗi updateRequest/setCalendarRange/applyPreset/setDuration vừa ghi provider mới vừa gọi provider cũ. replacePlannerWorkspace vẫn dựa legacy dirty/permission/generation và gọi prepare/useSuggested cũ trước provider mới. Đây không chỉ fallback test khi provider mới vắng mặt, cũng không phải read-only adapter đọc trip cũ.

**Probe P5:** mount HomePlannerScreen với cả PlannerInputProvider và subclass TripProvider spy như production; bấm ChoiceChip Hà Nội. Input mới đúng Hà Nội nhưng legacy.updateRequest được gọi **1 lần**, expected 0 FAIL. Probe dùng source UI thật, không gọi backend thật. Không suy updateRequest tự dispatch Decision Engine: điều đã chứng minh là active dual writes/dependency, chưa phải network call.

**Ảnh hưởng:** còn hai nguồn state cho cùng form, legacy dirty/guard vẫn có thể chi phối luồng mới; chưa đạt mục tiêu chuyển callers rồi bỏ engine/runtime binding của C2. Bảo toàn fixture cũ không yêu cầu production sync provider cũ.

**Hướng sửa/đóng:** khi PlannerInputProvider tồn tại, đường input/entry/workspace chỉ dùng nó và ManualPlannerProvider cho dirty/save guard. Loại dual writes; chuyển fixture mới theo contract mới. Giữ v1/v2 readers/adapter dữ liệu thật sự cần, không giữ provider engine đang hoạt động chỉ để tests inject được. Nếu fallback phục vụ legacy tests còn cần, tách rõ đường vắng provider mới và không đưa legacy engine/guest wiring vào production input. P5 GREEN, actual dual-provider fixture không gọi legacy mutation; account invalidation/reset/dirty editor và v1/v2 read đều PASS.

## 2. Why — điểm đã làm đúng và phần còn thiếu của C2

- Map/favorites UI modules và dashboard/Pareto đã được gỡ; không thấy runtime import tới thư mục map/favorites đã xóa. C1 entry map vẫn được bỏ.
- Helper manual_place_locations được chuyển sang explore trước delete; dữ liệu tọa độ/provenance giữ. Tuy nhiên helper hiện chỉ được test tham chiếu, không thấy caller runtime trong lib; không dùng điều này làm bằng chứng mọi package map/location vẫn cần.
- Provider mới tự nó không tạo service/network; factory/readers, account lifecycle và backend SQL không bị rewrite.
- Nhiều test chuyên map/dashboard được gỡ đúng feature; một số control/account/manual suites còn chạy. Nhưng 5 tests input mới chưa thử clearing nullable hoặc preset sau ngày, và “không transport” chỉ test provider một mình, chưa kiểm production có cả hai providers.
- **Phần chưa hoàn tất cần báo trung thực:** `pubspec.yaml` vẫn có flutter_map, geolocator, latlong2; AndroidManifest vẫn ACCESS_FINE_LOCATION/ACCESS_COARSE_LOCATION; guest-import/legacy engine wiring vẫn trong main. Không có dependency/native diff/patch bàn giao riêng. Prompt đã yêu cầu tôn trọng review diff trước apply, nên reviewer không yêu cầu tự sửa native ngoài quyền; cần chuẩn bị diff cụ thể và ghi pending, không báo toàn C2 đã dọn sạch. Nếu giữ latlong2 vì helper, giải thích caller thật hoặc dùng cấu trúc tọa độ đơn giản sau khi được duyệt, không dựng dependency giả từ test.

## 3. Testing — fresh verification và probe

### Full suite hiện có

`./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`

- Analyzer **No issues found**, 58.2s, exit 0.
- Flutter **997/997 PASS**, 1:53, exit 0.
- Node **91/91 PASS**, fail 0, skipped 0, exit 0.
- Full wrapper exit 0.
- Reviewer logs `.dart_tool/travelgo-verification/20261024T164328581Z-25048/{analyze,flutter-tests,node-contracts}.log`; wrapper `.dart_tool/c2-codex-full.log`.

997 so với 1125 ở C1 phản ánh tests feature bị loại/cập nhật; không dùng chênh count một mình để kết luận coverage đủ hoặc yếu. Review đi vào assertions và independent probes.

### Independent probes, không sửa sản phẩm

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded .dart_tool/c2-codex-review/input_probe_test.dart
```

**1 PASS control / 4 FAIL assertions, exit 1**, gom thành 3 findings ở trên:

| Probe | Actual |
| --- | --- |
| P1 clear destination | FAIL: request vẫn hue |
| P2 calendar→preset→factory | FAIL: invalid_input,dates |
| P3 catalogue→free-text | FAIL: request vẫn hue |
| P5 production both providers | FAIL: legacy writes 1 thay 0 |
| P4 date without preset | PASS: factory tạo 5 ngày và đúng Huế |

Log `.dart_tool/c2-codex-review/input-probe.log`; probe synthetic trong ignored directory, không thêm vào permanent suite. 997 tests hiện có vẫn PASS vì chưa có các ca này. Không gọi Gemini/Supabase thật, không dùng dữ liệu tài khoản thật hoặc credential trong probes. SDK cần ghi lockfile ngoài workspace nên commands dùng quyền đã được công cụ duyệt; không có auto-review rejection.

`git diff --check` exit 0, LF/CRLF warnings không là whitespace errors. Một lệnh xuất source có UnicodeEncodeError do console cp932, đã sửa encoding ở harness đọc, không sửa sản phẩm. Không build/install/hot reload/device UI, runtime NOT RUN; không chứng nhận Android/iOS acceptance.

## 4. Problems / gói sửa tiếp cho Antigravity

1. Sửa C2-F01/F02 ở request/metadata transition, regression có cả positive controls và factory/entry.
2. Sửa C2-F03 để production input chỉ có một nguồn state; không duy trì dual writes để giữ fixtures. Giữ legacy read và kiểm account reset/saving/dirty guards.
3. Bàn giao cleanup inventory: cái gì thực đã gỡ, cái gì giữ vì có caller; chuẩn bị dependency/native diff riêng theo approval hiện có. Không tự drop data/migration hoặc nâng scope sang C3.
4. Tích hợp regressions đã xác nhận vào tests chính thức, chạy targeted rồi Full trên final candidate, giữ statements về network đúng mức spy đã đo. Không sửa test kỳ vọng theo lỗi hiện tại.
5. Báo base/HEAD/diff hoặc hashes, commands/exits/counts/log, pending review/NOT RUN. Không commit/push/deploy/DB live. Guard sửa lỗi hiện hành giữ, không tự reset budget từ một review mới.

R2 đã duyệt scope C2 nên không cần hỏi lại có sửa ba gap này không. Native/dependency hoặc live action chưa được cấp quyền vẫn phải chuẩn bị diff trước bước quyết định cuối. C2 hiện REQUEST CHANGES, C3 chưa bắt đầu.

## 5. Lesson Candidate — giải thích cho owner

Input có hai bản: request dùng tạo/gửi dữ liệu và metadata dùng hiển thị/đặt tên/ngày. Bấm preset chỉ đổi request nhưng giữ ngày cũ ở metadata khiến factory từ chối mở editor. Truyền null vào copyWith có nghĩa giữ giá trị cũ, nên nút bỏ điểm đến chỉ bỏ một bản. Tạo provider mới nhưng tiếp tục ghi cả provider cũ chưa cắt sự phụ thuộc.

Problem→Root Cause→Rule: “form nhìn hợp lệ nhưng không mở editor”→“request và metadata đổi không nguyên tử”→“test chuỗi thao tác thật như chọn ngày→preset→mở editor, không chỉ test từng setter”. “Có provider mới nhưng vẫn phụ thuộc engine state”→“adapter dual-write để fixtures cũ xanh”→“test production provider graph và giữ reader compatibility riêng với active input mutation”.

## Reviewed fingerprints

| File | SHA-256 |
| --- | --- |
| `lib/features/trip_planner/providers/planner_input_provider.dart` | `9a2df5285fcac6239bdd405b76c942cc00c469ac39407f1e61df2a2c412a618e` |
| `lib/features/trip_planner/presentation/screens/home_planner_screen.dart` | `d99fd247857b44cd91c8472b2d921b1fdd6fa9fe169b8e27cde8a15a20088841` |
| `lib/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart` | `2d347bd7e6a0ede46fbe892be4cce9c934b4b1d4de6aba3152277dd7308e1339` |
| `lib/features/trip_planner/presentation/widgets/planner_workspace_actions.dart` | `aa132a54501c7986f16b233924cdce2964d1eb9026875acafd36fca20c798feb` |
| `lib/main.dart` | `26aa097a256e1e3636577a9dcf4787939b72cdf97c22dca144ca9188303ccc1e` |
| `test/planner_input_provider_test.dart` | `97fdd7d9e3c5eb322a9c425f0e99c8232f37fbf406eb6142da6d0d859a121205` |
