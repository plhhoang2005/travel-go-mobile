# C2 — Codex re-review R2, 25/10/2026

**Verdict: REQUEST CHANGES cho hoàn tất C2.** Hai lỗi input đã đóng; phần dual-write đã đóng. C2-F03 còn phần wiring legacy; đề xuất dependency/native chưa đạt điều kiện áp dụng. Không phát hiện lại failure của năm probes cũ, không yêu cầu làm lại những phần đã đạt. Chưa chuyển C3.

## 1. Changed — source review và trạng thái findings

Actual branch `fix/ai-planning-stability`, actual HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2 source/tests/docs. Đối chiếu handover owner gửi với source thật, report trước và assertions probe cũ. Không kiểm hay xác nhận những nhận định ngoài scope trong handover về số commit ahead/remote main vì không liên quan C2 và chưa có evidence mới.

Codex chỉ đọc product/permanent tests, chạy kiểm thử và tạo report/probe artifacts ignored; không sửa app/backend/native/dependency, không commit/push/merge/deploy/DB mutation hoặc gửi AI/email thật. 315 source/test/backend/tool/config files giữ nguyên trong review theo snapshot `.dart_tool/c2-codex-review/r2-source-snapshot.json`. Không kích hoạt Superpowers cho review này.

| Finding trước | Trạng thái R2 | Evidence |
| --- | --- | --- |
| C2-F01 calendar→preset lệch ngày | **CLOSED** | Request/metadata giữ start và tính end theo preset; P2 GREEN; permanent test cả ba presets |
| C2-F02 null không xóa destination | **CLOSED** | Sentinel/clearDestination phân biệt omitted với null; P1/P3 GREEN |
| C2-F03 dual-write và runtime legacy | **PARTIALLY CLOSED** | Home syncTrip đã gỡ, workspace action nhánh new không mutate legacy; P5 GREEN. Root và một số new callers vẫn read/watch legacy, xem bên dưới |

### C2-F03 [P2] — phần còn mở: legacy engine provider vẫn được wiring/đọc ở production

**Source:** `lib/main.dart:652–675`, `manual_planner_entry_screen.dart:initState`, `home_planner_screen.dart:openManualPlanner`, `selected_destination_controls.dart:build`, `destination_detail_screen.dart:build`.

Main vẫn đăng ký `ChangeNotifierProxyProvider<AuthProvider, TripProvider>` tạo TripProvider(localStoreLoader), update auth context và account invalidator cho nó. Một số màn vẫn đọc/watch legacy ngay cả khi input mới tồn tại: ManualPlannerEntry init đọc cả hai, openManualPlanner đọc cả hai; selected/detail watch legacy không điều kiện. Vì vậy root lazy factory vẫn có thể bị khởi tạo trong luồng mới. Không phải fallback chỉ khi provider mới hoàn toàn vắng mặt.

**Phần đã sửa đúng:** `_ProviderHomeInputState` không còn syncTrip; Home build chỉ watch legacy khi input mới không có; workspace actions không gọi mutation legacy khi input mới có. P5 measured legacy.updateRequest=0 PASS. Không dùng việc còn wiring để nói probe dual-write vẫn fail, không quy source này đã dispatch mạng hoặc lộ dữ liệu.

**Vì sao chưa đóng cả finding:** C2-F03 trước đã yêu cầu giữ v1/v2 readers riêng với runtime input, và không đưa engine/guest wiring cũ vào production input chỉ để hỗ trợ fixtures. Loại dual-write đạt một nửa yêu cầu; source handover nói “tách hẳn/cắt đứt hoàn toàn” đang rộng hơn evidence.

**Đóng khi:** bỏ binding TripProvider engine khỏi production root nếu không có caller cần thiết của feature giữ lại; new input/entry/detail/selected controls không đọc/watch legacy khi input mới có. Giữ fallback fixture hoặc legacy reader thực sự cần tách khỏi root runtime, không xóa codec/data cũ. Thêm production-graph regression chứng minh mở Home/Explore/editor không cần khởi tạo legacy engine provider; giữ P5 zero mutations, account invalidation/reset/dirty/save guard và legacy read tests. Nếu có caller production cần giữ, chỉ ra cụ thể và tách narrow read-only adapter, không giữ cả engine provider vì test cũ.

### C2-F04 [P2] — mới, chỉ ở proposal: native/dependency patch chưa áp dụng được

**Source:** `docs/phase-3/PENDING_DEPENDENCY_NATIVE_PATCH_C2.md:43–98`.

Reviewer trích ba diff blocks vào `.dart_tool/c2-codex-review/native-proposal.patch`, không apply vào sản phẩm.

- `git apply --check .dart_tool/c2-codex-review/native-proposal.patch` → **exit 1, corrupt patch at line 48** (hunk counts không đúng).
- Khi thử parser tự đếm lại bằng `git apply --check --recount ...`, vẫn báo **pubspec.yaml patch does not apply**. Context dùng provider6.1.2/dio5.7.0/shared_preferences2.3.3, không khớp file hiện tại provider6.1.5+1/dio5.11.1/shared_preferences2.5.5. Manifest patch cũng không thể hiện ACCESS_NETWORK_STATE nằm giữa INTERNET/location trong file thật.
- Patch GeoPoint mới đổi import/type declaration nhưng bỏ sót **ba** chỗ `LatLng(...)` trong helper (hai static references và một dynamic return). Nếu bỏ dependency/import theo proposal mà không sửa các constructor này, helper sẽ không compile. Đây là lỗi của proposal, chưa phải compilation failure của app hiện tại.
- Chưa có bước cụ thể cập nhật pubspec.lock qua resolver khi triển khai, hoặc kiểm bản build sau thay dependency/native.

**Đóng khi:** chuẩn bị patch sinh từ candidate hiện tại, đủ ba constructor GeoPoint, giữ nguyên các package versions không liên quan, INTERNET/ACCESS_NETWORK_STATE và auth deep links. `git apply --check` trên patch exact file đạt. Ghi rõ pubspec.lock sẽ được regenerate bằng cached/offline resolver khi bước apply được duyệt, không sửa lock thủ công/nâng package khác; có targeted helper tests, Full và Android build ở bước apply. Chỉ chuẩn bị/review patch, không tự apply trước quyền native/dependency đã yêu cầu.

Không coi chuẩn bị proposal là đã gỡ packages/quyền. Không cần mở lại lựa chọn sản phẩm: maps đã ngoài scope. Đề xuất A dùng immutable GeoPoint phù hợp; vấn đề là artifact hiện tại chưa đầy đủ/chưa khớp source.

## 2. Why — before/after và phần đã kiểm

Trước khi sửa, request preset hai ngày vẫn đi cùng metadata năm ngày, nên factory từ chối tạo editor. Bản mới giữ start và tính lại end theo số ngày của preset; test calendar→preset→factory chạy đúng. Trước đây null có nghĩa giữ ID cũ; sentinel giúp request và metadata cùng xóa ID, hoặc chuyển sang tên tự nhập mà không giả catalogue ID.

Form mới hiện không còn mutate provider cũ khi sửa nơi xuất phát. Giữ độc lập giữa request input và editor/save là đúng hướng. Phần còn lại là dọn root/reads, không viết lại provider và không làm lại hai fixes đã đóng. Sau source cleanup, legacy v1/v2 vẫn cần đọc qua reader/codec hiện có, không qua active engine input state.

Tôi chưa thêm probe race mới hay khẳng định có lỗi account/data mới ngoài evidence. Getter/guard khác giữ trong scope C2; recovery findings không được review này đóng.

## 3. Testing — fresh commands và limits

Full command độc lập:

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

**Exit 0.** Reviewer logs `.dart_tool/travelgo-verification/20261025T000021274Z-33936/`, wrapper `.dart_tool/c2-codex-r2-full.log`.

| Check | Kết quả thực |
| --- | --- |
| analyze | No issues found, 4.3s, exit 0 |
| Flutter Full | **1000/1000 PASS**, 1:51, exit 0 |
| Node contracts | **91/91 PASS**, fail0/skipped0, exit0 |
| Original reviewer probes | **5/5 PASS**, exit0 |
| git diff --check | exit0, chỉ line-ending warnings |
| Native proposal check | FAIL, exit1; read-only, không apply |
| Source consistency | 315 product/test/config files không đổi trong review |

Probe command:

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=1 --reporter=expanded .dart_tool/c2-codex-review/input_probe_test.dart
```

Logs `.dart_tool/c2-codex-review/input-probe-r2.log`; assertions của P1/P2/P3/P4/P5 giữ expected behavior, không hạ kỳ vọng để xanh. Permanent suite có thêm ba tests và cả calendar presets test. P5 chỉ đo input mutation, không phải test không khởi tạo legacy provider — hai việc khác nhau.

Không build/install/hot reload/device acceptance, không live AI/email/SQL. Runtime **NOT RUN**. Handover nói “0 flaky” không được một lần Full PASS tự chứng minh; reviewer chỉ ghi kết quả lần chạy. SDK cần quyền ghi lockfile ngoài project, commands được công cụ cho phép; không auto-review rejection.

## 4. Problems / next correction

- Không sửa lại C2-F01/F02 hoặc đưa dual-write trở lại. Giữ regressions đã GREEN.
- Hoàn tất root/caller cleanup của phần còn mở C2-F03; tiếp tục chỉ task C2, không C3.
- Sửa proposal C2-F04 thành patch apply-check PASS, chưa áp dụng dependency/native trước quyền tương ứng. Bàn giao patch + kế hoạch lockfile/build cụ thể để bước owner duyệt là bước cuối.
- Các package/flutter_map/geolocator/latlong2 và location permissions hiện vẫn còn theo pending. Vì vậy chưa báo “toàn C2 hoàn thành 100%”. C2 có source fixes tốt nhưng cleanup/proposal còn việc.
- Không tự cấp lại repair budget; giữ guard tối đa ba vòng đang hiệu lực. Nếu hết guard, report checkpoint cùng diff cụ thể, không reset counts hoặc mở scope.
- Không commit/push/deploy/DB live. Mọi approval C1/C2 trước chỉ áp source đã kiểm; source thay tiếp cần checks phù hợp.

## 5. Lesson Candidate

Problem→Root cause→Rule: “spy zero writes nhưng legacy provider vẫn sống”→“đo mutation không đo production dependency graph”→“kiểm riêng cái gì còn được khởi tạo và cái gì còn được gọi”. “Proposal nhìn giống diff nhưng không apply được”→“hunk/context giả và bỏ sót constructor”→“sinh patch từ đúng candidate, check read-only trước khi xin duyệt, ghi lockfile/build như một phần rollout”.
