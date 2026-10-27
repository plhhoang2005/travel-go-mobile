# P3.2 completion plan — checkpoint 20/10/2026

**Kết luận: NOT COMPLETE / NOT ACCEPTED. Plan-only, chờ Owner duyệt thực thi.**

Codex lập/review plan trên checkout hiện có; chưa sửa product, harness hay test. Không dùng superpowers/subagent. Chỉ tạo tài liệu này; không stage/commit/push/merge, build/install, điều khiển thiết bị, deploy/DB/config/SDK/dependency. Chỉ thị mới cho phép phân tích và targeted tests, không tự hủy STOP của phần triển khai ngày 20/10.

## 1. Mục tiêu, phạm vi và chuẩn nghiệm thu

Hoàn tất đúng E01–E12 và PHONE01–PHONE04 của `P3_2_UX_REFRESH_IMPLEMENTATION_PLAN.md:222–239`, bảo toàn Guest draft, actual ledger và ranh giới Account. Chỉ kết luận PASS sau source verification hoàn chỉnh, emulator đủ matrix, DNY đủ cột trọng yếu, bằng chứng APK và Owner đối chiếu Home A/Planner B. Critical FAIL/BLOCKED bắt buộc => NOT ACCEPTED.

Non-goals: mở tính năng AI mới, hoàn tất mọi MUST, AI005 operational feed, thay decision logic, sửa Auth bằng bỏ owner/epoch/subject/server-verification guard, nâng SDK/dependency, thêm native permissions/config, production rollout. Không tăng timeout, bỏ/skip assertion hoặc sửa dữ liệu kỳ vọng chỉ để GREEN.

Phân biệt phạm vi:

- E11 có yêu cầu ảnh/map đúng ngày, failure/offline và AI unavailable trung thực. Đây là P3.2.
- Generation/assistant backend, primary rollout và AI005 feed giờ mở cửa/route/weather không phải tiêu chí ngầm P3.2 theo câu “Hoàn tất gói khi”. Nếu Owner muốn đưa vào acceptance phải bổ sung scope/budget riêng; không đổi nghĩa PASS của E01–E12.
- Shared Auth, consent/owner isolation và bảo toàn draft là dependency nếu flow P3.2 đi qua chúng. Google subset/Profile emulator đã có evidence trong MUST ledger, không tự đóng toàn E02/E03 hay DNY.
- Ledger 20/10 ghi backend v12 có 6 HTTP200 + 1 quota HTTP429, native preview/cancel/apply A/B đạt happy path; AI005 vẫn OPEN. Đây là evidence lịch sử, không kiểm lại staging trong lượt plan và không dùng để thay acceptance mobile.

## 2. Baseline đã xác minh và nguồn bằng chứng

### 2.1. Checkout hiện tại

| Thuộc tính | Kết quả đọc trong lượt plan |
| --- | --- |
| Repo | `D:\Travel-Go-Android\travel-go` |
| Branch | `codex/phase-3-discovery-design` |
| HEAD | `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa` |
| Dirty | 112 mục theo `git status --short`: 42 tracked modified, 70 untracked entries; một entry thư mục có thể chứa nhiều file |
| Staging | `git diff --cached --stat` rỗng |
| Plan đích | Chưa tồn tại trước lượt này |

Đã đọc `git status`, `git diff --stat` và scoped diff AuthProvider/lifecycle/repository/detail UI/saved UI test/main; guest import test không có diff so với HEAD. Phân loại phục vụ scope, **không suy mọi dirty file do cùng tác giả**:

| Nhóm | Ví dụ đang dirty | Cách xử lý |
| --- | --- | --- |
| P3.2 presentation/phone | theme, Auth screens, manual form/timeline/budget, detail/list, navigation, UI tests | Giữ nguyên, chỉ chạm file được gói sau duyệt và có evidence |
| Shared Auth/PHONE03 | AuthProvider, lifecycle service, auth_navigation_test, main | Hash bên dưới; source correction chưa native retest |
| Conflict recovery đã có | manual_planner_provider, editable_trip_repository/local_store, provider tests | Không mở lại finding đã native PASS nếu không có regression mới |
| MUST/AI/Profile/Google ngoài task sửa P3.2 | user/profile, AI services/previews, Supabase function/migration/tests, Manifest | Không deploy/DB/config; không xem whole MUST là P3.2 |
| Owner/historical/generated ngoài scope | macOS registrant, .docx, create_*.py, presentation.html, phase-2 docs, docs/superpowers, supabase/.temp | Không sửa/reset/clean hoặc nhận là task diff |

SHA256 hiện tại đã đối chiếu đúng ledger STOP:

| File | SHA256 |
| --- | --- |
| `lib/features/auth/providers/auth_provider.dart` | `1195C7D3D26CE2F9B16A7A8FE3E5FBD7FB69B01BDAF7855199F36EBAEBC0FA6D` |
| `lib/features/trips/services/local_account_lifecycle_service.dart` | `55E6544C526E64B7F10F591A4D39D9A14F10BB052F71A0046F7C3D99DA30326C` |
| `test/auth_navigation_test.dart` | `43A0714489987D0A3B2CD87E3D03C696F19074C71DDB31E206B73A3A085B5C56` |
| `test/editable_guest_import_ui_test.dart` | `3C2E4A7A8C1BEC4C5B028144B9845AD39D6629BF13A2E59F1EE80760043FBF3D` |
| `test/editable_saved_trip_ui_test.dart` | `5BC6A789AAF71F296E80F8B55ABF64025DA0E8CD54A819A0D7FCF45377848D24` |

HEAD không định danh dirty source đã test; các gói sau phải ghi hash/diff manifest của packet thực tế, không chỉ commit.

### 2.2. Evidence lịch sử đã đọc lại

- `MUST_DELIVERY_PLAN_20261024.md:627–780`, đặc biệt checkpoint STOP: G4 **433/435 calls, 8/8 files, 7/7 rounds**; G2 **246/265, 8/8, 10/11**; G3 **141/170, 8/8, 7/7**. Đề nghị +40/+2 trước đó bị từ chối; maxima chưa tăng.
- `.dart_tool/p32-phone03-final-full-v2.log` và `.dart_tool/travelgo-verification/20261020T041808145Z-27828/`: analyzer **No issues found, 21.9s**; Flutter dừng ở **479 PASS / 4 FAIL**, không final summary/count; Node chưa chạy trong pipeline này. Exit do chủ động dừng không phải compile failure. Không dùng lịch sử 757 Flutter/89 Node trước Auth correction làm checks cuối.
- Failure log có expected false/actual true ở guest import (693–724), timeout photos (769–800), close message (833), timeout delete-cancel (860–892), expected 1/actual 0 ở confirmed delete (901–931).
- `P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md`: Guest/import/actual subsets (164–189), conflict/receipt probe (191–232), **conflict recovery đã CLOSED native** (234–275), Auth pending→Guest và offline/recovery (278–end). Các OPEN trước đó được supersede trong đúng subset, không bỏ lịch sử FAIL.
- `P3_2_PHONE03_REPAIR_PLAN.md` mô tả sửa active-vs-sealed ngày 18/10; emulator D5B365 valid-session cold/resume PASS. Không bao phủ interrupted-startup mới ngày 20/10.
- `test/auth_navigation_test.dart:1330–1465`: 9 variants `PHONE03 interrupted cold startup <outcome> preserves authority boundaries`: loader/store/verify phải khôi phục; guest/guest-loader/changed-owner/expired/verifier-denied/invalid-registry phải deny, Guest draft giữ. Ledger ghi 9/9 target PASS trên correction cuối; 123 Auth+lifecycle PASS thuộc packet trước loader correction. Không chạy lại các case này trong lượt plan.

### 2.3. Targeted verification thực chạy trong lượt plan

Dùng SDK hiện có `D:\flutter\flutter`; gọi cached dart + flutter_tools.snapshot, tương đương `flutter test` dưới đây. Không sửa source/test, không tăng timeout, không full suite/build/device command.

```powershell
flutter test --no-pub --reporter expanded test/editable_guest_import_ui_test.dart --plain-name 'lost local ack retries original request even after Guest revision advances'
flutter test --no-pub --reporter expanded test/editable_saved_trip_ui_test.dart --name 'saved detail photos use stable ids and large text preserves read-only ledgers|delete cancel sends nothing; version conflict keeps detail and list|confirmed V2 delete removes cached head and refreshes list'
```

- Lần launcher đầu bị sandbox chặn ghi SDK `bin/cache/lockfile`, exit1 **trước khi chạy case**. Rerun được auto-review cho phép với cùng cache, không SDK upgrade.
- Guest isolated: exit0, **1/1 PASS**, khoảng1s test time.
- Ba saved cases chạy tuần tự trong cùng invocation: exit0, **3/3 PASS**, khoảng2s test time. Image HTTP400 fixture warnings vẫn có, không cản PASS; không là native image evidence.
- Tổng 3 invocation attempts (2 thực chạy test), dưới trần4. Không có full-source PASS mới. Output nằm trong transcript tool, không tạo log/report file thứ hai.
- Kết luận: không tái hiện bốn lỗi ở hai lần targeted hiện tại. **Chưa kết luận flaky, contention, môi trường hay Auth patch là nguyên nhân.** Một targeted PASS không giải thích full-run FAIL; việc phân loại dứt điểm vẫn thuộc A.

### 2.4. Trạng thái thiết bị — lấy từ checkpoint, chưa điều khiển/xác minh live lượt plan

- DNY-NX9 Android16 ARM64 đang bản **profile cũ** `35ef8d78287fdfc4cf336aa25bbe372cfb2217db3ec99a1d294e3ca563d5cac2`; **Guest sau repro interrupted cold của B**, chưa login lại. Cloud `P32_DNY_20261020_A_R2/version2` giữ. Không có APK mới exit0/hash sau correction; build dở không được cài.
- Emulator5554 giữ **QA draft B chưa remote-save**, có Hồ Hoàn Kiếm và dirty label; installed main trước correction `6f80a29d…eca10`. VM JSON `.dart_tool/p32-aiqa-B.vm.json` là QA value backup, không phải bằng chứng product import/persistence/recovery.
- **5556 không đụng**; trạng thái phiên hiện tại không được suy từ report18/10. Không dùng nó như session độc lập sẵn sàng nếu chưa có quyền và preflight mới.
- DNY chỉ có ADB Wi-Fi theo checkpoint; không tắt kênh đó để thử offline. Giữ font/network/a11y baseline; cần USB độc lập cho phép thử network.

## 3. Bốn failure: luồng, phân loại có giới hạn và phép chứng minh

Quy ước: “nghiêng về harness” là giả thuyết có dấu hiệu source, không là root cause đã chứng minh. Tất cả bốn là blocker của **gate source verification** hiện tại; tác động trực tiếp E05/E09/E10/E12 ghi riêng. Không defer chỉ vì targeted đã PASS.

### F1 — lost local ack, guest revision đã tăng (`editable_guest_import_ui_test.dart:280–319`)

**Kỳ vọng:** create lần đầu đã commit server nhưng local ack thất bại thì giữ uncertain và Guest source. Retry phải dùng request của revision1, đọc receipt cũ, không create lần2; sau ack thành công uncertain=false và revision2 trên disk còn nguyên.

**Luồng:** chọn draft → `EditableDraftImportSelection._review` → `EditableDraftsProvider.importSelected` → repository.importGuest → frozen UUIDv5(owner/scope/draft/revision) → stage → lookup receipt/create → `commitEditableAck` transaction. Lỗi hook `ack_snapshot_written` khiến provider giữ uncertain=true. Retry UI **đi trực tiếp repository.importGuest(frozen source)**; sau thành công gọi drafts.invalidate/load (`editable_draft_import_selection.dart:140–157`). Retry không dùng `drafts.isImporting` như lượt đầu. Lifecycle chỉ cấp proof/handle và kiểm epoch/subject xuyên các await.

**Evidence:** Fullv2 assert uncertain=false nhưng true; test đợi200ms rồi pumpAndSettle. `waitImport` có predicate isImporting nhưng chỉ dùng trước retry. Future SQL/registry/I/O bên trong `tester.runAsync` không được hoàn tất bằng việc bơm animation clock. Current targeted PASS giữ creates=1/revision2. 200ms không phải product deadline; uncertain là **fence thật của sản phẩm** cho đến ack, không được clear sớm để làm test xanh.

**Phân loại:** nghiêng về thiếu synchronization của harness, **chưa kết luận**; nếu local ack lỗi thật hoặc proof invalidated thì true là đúng bảo vệ và phải điều tra product. Chưa có evidence Auth PHONE03 gây lỗi: fixture login freshAuthentication=true, AuthProvider riêng không lifecycleLoader, không pause/resume; không đi qua startupContinuation. Shared lifecycle còn là dependency nên chưa loại mọi tương tác.

**Chứng minh tối thiểu ở A:** giữ ack pending bằng hook/completer test hiện có, xác nhận uncertain vẫn true trước release; chờ **retry UI/receipt/local commit hoàn tất**, không chờ isImporting của initial import. RED của helper cũ phải xuất hiện khi completion bị giữ; sau release GREEN với requestId/bytes cũ, creates=1, uncertain=false, revision2 còn. Nếu completion đã xong mà uncertain còn true hoặc receipt mismatch => gói product A2-import. Ưu tiên sửa harness chỉ sau bằng chứng này, không defer data-loss/duplicate-write risk. Native main-UI retry còn thiếu ở E10; native probe cũ không thay nút Retry.

### F2 — stable photos + large text ledger (`editable_saved_trip_ui_test.dart:300–345`)

**Kỳ vọng:** destinationId `ha-noi` quyết định ảnh dù destinationName tự nhập khác; chữ2x/360dp vẫn xem actual/estimate, không mutate digest/ledger.

**Luồng:** detail post-frame `_load` → ManualPlannerRuntime → repository.readTrip → service.read giả + **SQLite putEditableSnapshot thật** → owner/epoch/generation checks → set `_view`, `_busy=false` → render ảnh/ledger. Khi chưa có head và busy, UI vẽ loading animation (`editable_trip_detail_screen.dart:107–144,295–303`).

**Evidence:** Fullv2 timeout tại **pumpUi:189 từ321, trước assertion ảnh/ledger**, không phải ledger mismatch hay overflow. Helper chỉ real-delay100ms rồi pumpAndSettle bên trong runAsync. Targeted current PASS, vẫn có image fixture HTTP400. Chưa có stack chờ SQL hoặc pending frame trace trong full-run để chứng minh bước nào giữ busy.

**Phân loại:** nghi harness đợi I/O bằng settle/100ms; product load không kết thúc vẫn là khả năng mở. Chưa chứng minh do ảnh, môi trường hay Auth correction; test dùng Auth simulation tách khỏi lifecycle loader. Không đi qua native interrupted startup.

**Chứng minh tối thiểu:** UiRepository test override readTrip gate, hoặc adapter/completer kiểm head-cache completion; khi giữ gate xác nhận loading và chưa có ledger, release rồi chờ observable **detail-ready** có real async yield trong giới hạn hiện có; sau đó mới settle animation và giữ nguyên tất cả assertion stable-id/large text/digest. Nếu readTrip xong/proof còn current mà busy/view không kết thúc => A2-detail product. Chưa defer E12; image-source/failure coverage vẫn cần native E11 riêng.

### F3 — delete cancel/version conflict (`editable_saved_trip_ui_test.dart:545–562`)

**Kỳ vọng:** cancel không gọi delete; confirm với known version_conflict giữ detail/list và hiển thị warning.

**Luồng:** cùng load/read/cache như F2 → dialog context trả false/true → `_delete` kiểm owner/proof/generation → `UiRepository.deleteTrip` chụp deletedBase và ném typed conflict **trước real repository submit** → UI giữ document/list. Lifecycle không được tự invalidate từ một known conflict.

**Evidence:** timeout ở550/pumpUi, **chưa mở dialog/chưa delete/chưa conflict branch**. Fullv2 log833 close message xen giữa output nhiều test files; line823–824 đang có `guest_draft_planner_test` production runtime test. Targeted case PASS. Không đủ cơ sở gán close log cho fixture này hoặc suy conflict code hỏng.

**Close log đã xác minh source:** `lib/main.dart:436–474`: widget.dispose gọi `unawaited(_closeResources().catchError(...))`; `_closeResources` await manualRuntime.close, auth.close, rồi `await (await _loadingLifecycle).close()` trong try/catch. Catch **in ra** “Account lifecycle close did not complete.” rồi tiếp tục runtime.close. Vì vậy thông báo chứng minh exception của loader/close đã được catch, **không tự chứng minh future đang treo**. `LocalAccountLifecycleService.close:947` dispose rồi trả `_tail`; dispose hủy deadline và invalidate. Background close có thể là lỗi cleanup riêng; bản thân debugPrint không schedule frame liên tục. Chưa chứng minh quan hệ nhân quả với pumpAndSettle.

**Phân loại:** chặn ở setup/detail load, nghi cùng harness F2; close error là finding cleanup cần attribution, **chưa kết luận** product/Auth/môi trường. Minimum probe: test-name/instance-id an toàn, entered/completed/error cho loader/close, explicit drain của resource fixture tạo ra; không raw errors chứa token/private data. RED nếu cleanup future reject/hang hoặc case sau chạy trước cleanup xong; GREEN khi close/drain đúng hợp đồng và không còn async exception rò sang case sau. Không sửa production close chỉ để im log.

**Quyết định:** xử lý load-ready harness ở A; attribution cleanup độc lập trước khi gán root cause. Giữ regression cancel/conflict nguyên vẹn và xem native E08/E09, không lặp lại toàn conflict recovery đã PASS ngày18/10.

### F4 — confirmed V2 delete/cache/list (`editable_saved_trip_ui_test.dart:564–584`)

**Kỳ vọng:** confirm gửi đúng1 delete, refresh list đúng1 lần, cached head biến mất và UI không còn title.

**Luồng:** dialog accepted + `_current`/busy/generation → UiRepository.deletedBase → repository `_account` serialize + beginAccountOperation → stageEditableAttempt SQL → receipt lookup → fake server.delete (tăng counter **tại dispatch**) → commitEditableAck xóa snapshot → UI `_deleted` → SavedTripsProvider.loadTrips. Owner/epoch thay đổi ở bất kỳ await phải từ chối response cũ.

**Evidence:** Fullv2 deletes=0 tại573 sau150ms/pumpAndSettle; chưa chạy asserts list.loads/cache/title. Không thể suy “list refresh hỏng” từ counter0. Counter0 có thể do chưa dispatch qua stage/lookup, dialog chưa được chấp nhận, hoặc proof/generation/busy đã chặn; cần xác định boundary. Current targeted PASS đầy đủ1delete/1refresh/cache null. `_account:65–80` đăng ký operation trước queue và finish trong whenComplete; queue/I/O là dependency cụ thể. Diff detail hiện tại thêm ảnh/ledger layout, không sửa load/delete handler.

**Phân loại:** async dispatch/ack harness là giả thuyết ưu tiên; chưa kết luận product, cache, owner/epoch hay Auth patch. Minimum probe/gates: dialog accepted → deletedBase set → stage done → lookup done → delete entered/completed → local ack → list refresh. Gate trước dispatch: deletes vẫn0 hợp lệ; sau release và ack phải1, list1, cache null. Negative owner switch phải0 và không refresh cho owner mới. RED nếu đủ các prerequisite mà không dispatch, hoặc ack deleted mà cache/list sai; GREEN giữ toàn bộ assertions hiện có. Product fix chỉ tại boundary đã chứng minh (A2-delete), không thêm sleep hay bỏ guard.

### Liên hệ PHONE03 và điều kiện defer

PHONE03 mới đã có native root cause riêng: B valid/active → cold launch → HOME ngay trước startup restore xong → resume thành Guest. Ledger20/10: startup bị cancel rồi resume bị first-attempt fence chặn. Source correction giữ private exact-subject continuation, server verify trước publish, Guest/owner/expiry vẫn deny; 9 target PASS. Bốn UI fixtures trên dùng fresh lifecycle login, Auth simulation và không phát app lifecycle states; **chưa có causal evidence nối bốn lỗi với PHONE03**. Không rollback Auth correction dựa vào chronology.

Đề xuất mặc định bốn lỗi vẫn chặn source gate cho đến A+B. Chỉ defer nếu Owner chấp thuận rõ, có deterministic evidence phân loại, chứng minh không mất dữ liệu/duplicate-write/privacy issue, issue+owner+deadline cụ thể. Nếu bốn lỗi còn tái hiện trong required source suite, không được gọi source PASS hoặc P3.2 PASS dù native subset đạt. Nếu Owner đổi gate, ghi acceptance có ngoại lệ/scope khác; không âm thầm gọi đủ tiêu chí P3.2 cũ.

## 4. Gap matrix — giữ các PASS đã có, không đánh đồng phiên bản/thiết bị

Trạng thái tổng hợp chỉ dùng PASS/PARTIAL/FAIL/BLOCKED/NOT RUN. PASS lịch sử trong cột evidence vẫn có giá trị đúng flow/build; không bắt chạy lại toàn bộ chỉ vì APK mới. Trên bản mới ưu tiên regression bị ảnh hưởng bởi Auth/corrected harness và các ô chưa có evidence. Cột DNY trọng yếu phải có dữ liệu thật; emulator/source không thay DNY.

| Hạng mục | Trạng thái hiện tại | Evidence đã có | Còn thiếu | Blocker/dependency | Gói đề xuất |
| --- | --- | --- | --- | --- | --- |
| E01 login/latency | PARTIAL | A emulator SDK2384ms + authorize326ms; DNY A/B vào Home, B cận trên9288ms | submit→SDK→authorized Home; A/B first-after-update/repeat, >=3 mẫu mỗi trạng thái; median/max, progress/errors/duplicate-submit | APK mới, account thật; profile timing không dựa debug-only assert logs | C, D5 |
| E02 restore/background/Guest | FAIL | APK D5B365 normal cold/resume PASS; DNY old35ef normal A/B subsets PASS; source9 interrupted variants PASS lịch sử | đúng interrupted cold native sau correction; expired/revoked live, Guest explicit | DNY Guest cũ, chưa có APK mới; fixture expiry/revoke | C, D5 |
| E03 A/B isolation/late callbacks | PARTIAL | 18/10 A→B list không A;20/10 DNY B không fixtureA, AI A→B có authority đúng | stale detail/deep-link, late live response/changed owner, Guest separation trên flow còn thiếu | hai session thật được phép, draft5554 phải bảo toàn | D2, D3, D5 |
| E04 offline/timeout/Auth error | BLOCKED | CEDE offline→error→Guest→form sạch→online HomeA PASS; cached detail read-only subsets PASS | timeout có reason riêng; offline resume/cold và quyền Account; DNY offline thật | DNY Wi-Fi-only; timeout fixture/method chưa duyệt | D2, D5 |
| E05 Guest/import | PARTIAL | Guest save/reopen; main no-autoimport/preview cancel/confirm1 lần, actual123456 retained/version1 PASS18/10 | DNY full Guest→import→reopen/cancel; retry lost ack UI boundary | F1/source gate; synthetic Guest mới, không dùng lại consumed source | A, D2 |
| E06 HomeA/PlannerB/form | PARTIAL | Guest exact5123456; native preview/apply; DNY Huế3days/2people/4000000/date-required guard | search/filter, min/max/invalid, date bounds/affected resize/cancel/interests/keyboard, Owner visual signoff | synthetic fixtures và matrix trace | D1, E |
| E07 timeline/activity | PARTIAL | add/rename/move day2/delete linked activity giữ actual123456 ở emulator | reorder, time/notes/daynotes, resize affected items/cancel, selected day/back/dirty; DNY edit/move/reorder/save/reopen | không làm mất actual/draft | D1 |
| E08 dialogs/actual | PARTIAL | Guest cancel/Back/confirm; DNY Account cancel/confirm Alpha PASS; emulator linked actual sau delete/save/reopen PASS | barrier/nested Navigator/owner đổi lúc modal; DNY Guest + actual-preservation, remaining estimate variants | F3/source readiness; synthetic actual | A, D1, D2 |
| E09 Account CRUD/list | PARTIAL | main emulator create/update auto list/readback; DNY createv1/updatev2 premounted list/readback PASS | native empty/premounted create, pullrefresh/paging/delete cancel/confirm; latest affected smoke | F4 + auth correction; được phép synthetic delete | A, D2 |
| E10 offline/receipt/conflict/V1 | PARTIAL | cached readonly Edit/Delete disabled; real two-session conflict + replacement recovery CLOSED; receipt probe same-key/version1/1row PASS | main UI lost-reply/retry; uncached fixture; approved V1 read/copy; DNY critical conflict/lostreply | two sessions, controlled response-loss method, synthetic V1 exactID | D2, D3 |
| E11 image/map/unavailable | PARTIAL | Home/Ngọ Môn source photo; unknown0positions/Back PASS; report có Hanoi reference marker subset | known/day-switch/unknown/tileoffline/back đầy đủ; source/coordinate coverage; image failure; AI unavailable trung thực | map synthetic refs đúng source; không default city hay gọi feedunknown là verified | D4 |
| E12 accessibility/performance | PARTIAL | budget411dp portrait/font2 subset PASS; photos/ledger360dp scale2 targeted current PASS | mọi màn đã đổi360/412, portrait/landscape,scale1/1.3/2, TalkBack/focus/48dp/reducedmotion/IME/Vietnamese dài; DNY frame timings | profile ARM64 mới; settings restore, assets/network phù hợp | D4 |
| PHONE01 login chậm | PARTIAL | Auth timing/Guest exit và recovery subsets PASS | end-to-end3 mẫu mỗi trạng thái A/B; không coi spinner đẹp là latency fix; giải thích stage chậm | E01/E04; target latency chưa chốt số | D5 |
| PHONE02 dialog đóng sai route | PARTIAL | Guest và DNY Account cancel/confirm đóng đúng dialog/editor ở subset đã chạy | nested/barrier/Back/Account switch + actual trên DNY; latest source gate | E08/F3; dùng regression giữ exactroute | A, D1, D2 |
| PHONE03 cold thành Guest | FAIL | active-vs-sealed defect cũ closed18/10; interrupted20/10 RED→9/9 source GREEN | emulator+DNY exact repro sau APK correction, negative authority boundaries | source B xong, budget/native approval, signedOut không bypass | C, D5 |
| PHONE04 save không hiện list | PARTIAL | original create/update/list/readback flow PASS emulator; DNY update premounted list/version2 PASS | empty/premounted-create variants và latest affected auth smoke; không nhầm F4 delete với save | E09/source B | D2 |

Không có hàng tổng hợp PASS vì mỗi hàng còn ít nhất một tiêu chí bắt buộc chưa được chứng minh. Điều này không thu hồi các subset PASS đã liệt kê. Các expired/revoked/timeout đang BLOCKED không thể đóng chỉ bằng fake session trong unit test.

## 5. Work packages và dependency

**Thứ tự:** Owner quyết định → A → A2 đúng boundary nếu cần → B → C1/C2 → D1…D5 → E → F. Các gói thực thi tuần tự, không subagent. Emulator đầy đủ trước cột DNY; C là critical PHONE03 retest sớm theo yêu cầu này. Bug mới trong QA phải chuyển thành repair packet cụ thể, không sửa nhiều luồng lẫn trong QA.

Paths dưới đây relative repo, chỉ là dự kiến. Mỗi gói tối đa5 file sửa/tạo,3 repair rounds,25 outer calls, tính cả waits/questions/rejected tools/checkpoint. Generated caches không phải authored source; probe/helper/ảnh được chủ động tạo phải tính vào file cap. Nếu cần nhiều ảnh, chia evidence thành các gói nhỏ có roster rõ, hoặc dùng screenshot output sẵn trong tool; không gom thư mục thành1 file để né cap.

Native case labels bên dưới là tên dự kiến để ghi acceptance evidence, chưa tạo source test. Với QA thuần túy, NOT RUN không phải RED: chỉ ghi RED khi đã quan sát hành vi trái kỳ vọng; sau đó mới GREEN nếu cùng case đạt. Tên bốn source regressions giữ đúng mục3.

### A — phân loại/stabilize bốn failure (24 calls, tối đa3 rounds)

- **Mục tiêu:** chứng minh boundary F1–F4; sửa harness khi đã có RED của synchronization lỗi; phân biệt cleanup exception. Bốn targeted PASS một lần chưa đủ phân loại.
- **Files (3):** test/editable_guest_import_ui_test.dart, test/editable_saved_trip_ui_test.dart, docs/phase-3/P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md. Dùng test-local override/completer/store hook hiện có; không sửa common tapText làm lan scope.
- **RED/GREEN:** bốn case đầy đủ tên ở mục3; thêm controlled delayed-I/O variants trong cùng2 tests. Trước release phải loading/uncertain; sau completion phải request/counter/ledger/cache đúng. F3 phải attribute cleanup theo instance, drain resource thật, không suppress error.
- **Native evidence:** chưa build/install; ghi mapping F1→E05/E10, F2→E12, F3→E08, F4→E09 để chọn native retest ở D. Không tạo native PASS từ target GREEN.
- **DoD:** mỗi failure có causal evidence hoặc ghi unresolved. Chỉ đóng harness sau controlled RED→GREEN, không tăng timeout. Nếu chưa reproduce được thì B kiểm source gate, không gắn “flaky”. Nếu B lại FAIL quay đúng boundary, không rerun full suite tự động.
- **Stop:**24 calls/3 rounds/3 files hoặc cần product/native/deploy mutation; checkpoint unresolved, không auto-defer.

### A2 — conditional product repair, chưa nằm trong ngân sách chính

Chỉ mở một packet có finding cụ thể, Owner duyệt boundary/file roster. Mỗi packet tối đa24 calls/3 rounds; không dùng remaining G2 round cho bug P3.2.

Định vị roster: repository=`lib/features/trips/services/editable_trip_repository.dart`; provider=`lib/features/trips/providers/editable_drafts_provider.dart`; import UI=`lib/features/trips/presentation/widgets/editable_draft_import_selection.dart`; detail=`lib/features/trips/presentation/screens/editable_trip_detail_screen.dart`; repository test=`test/editable_trip_repository_test.dart`. Auth paths và hai UI test paths theo bảng hash mục2; lifecycle test=`test/local_account_lifecycle_test.dart`; report luôn là `docs/phase-3/P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md`.

| Packet | File tối đa5, gồm report | RED trước / GREEN sau | Native / DoD / Stop |
| --- | --- | --- | --- |
| A2-import | repository; editable_drafts_provider **hoặc** import_selection UI theo evidence; guest import UI test; repository test; acceptance report | F1 completion xong nhưng fence/receipt/revision sai; paired unknown-outcome vẫn giữ fence | D2 main Retry dùng exact request; ack và revision2/1create đúng. Stop nếu phải đổi request contract/schema |
| A2-detail/delete | detail screen; repository; saved UI test; repository test; acceptance report | F2/F3 load xong nhưng view kẹt, hoặc F4 dispatch/ack/cache sai; owner-switch negative vẫn0 | D2 exact synthetic deletion + cache/list. Stop nếu thêm boundary ngoài5 files |
| A2-auth/cleanup | auth_provider; lifecycle service; auth_navigation_test; local_account_lifecycle_test; acceptance report | Attributed close/startup failure bằng controlled gates, giữ9 PHONE03 positives/negatives | C lặp exact interrupted cold trên2 thiết bị, không bypass authority. Stop nếu cần SDK/native config hoặc hết3 rounds |

Không thực thi cả ba theo một grant chung. Mỗi packet phát sinh thêm tối đa24 calls,3 rounds và file slots mới đã audit. Sau sửa mới chạy B trên source ổn định. Nếu không có product regression, bỏ A2 và ghi lý do.

### B — full-source verification một lần (8 calls,0 repair rounds)

- **File (1):** acceptance report. Chốt hash manifest trước/sau; không sửa source khi pipeline đang chạy; không build/boot AVD cùng full suite.
- **Command:** ./tool/verify-travelgo.ps1 -Mode Full. Wrapper hiện có chạy analyzer --no-pub; Flutter tests --no-pub --concurrency=2 --reporter=expanded; Node ai_gateway/itinerary_gateway/catalogue_readiness. Dùng cache/SDK hiện có, không pub upgrade.
- **RED/GREEN:** Fullv2 hiện incomplete/4FAIL; GREEN cần mọi command exit0 và final summary/count thật, ghi log paths. Không đặt trước count766. Suite phải bao gồm9 PHONE03 và4 UI cases.
- **Native:** NOT RUN; source PASS chỉ mở C. Thu đúng process đang chạy, polling để cập nhật người dùng trong60s, không tăng test timeout hay mở pipeline thứ hai.
- **DoD/Stop:** source stable và checks đầy đủ. Fail/hash đổi → dừng về A/A2. Chỉ sau source fix mới chạy một full verification mới cho packet ổn định mới, không lặp đến may mắn xanh.

### C1 — build/install đúng APK, giữ data (24 calls,0 repair rounds)

- **Case artifact:** `MAIN_STAGING_HASH_ABI_INSTALL_R_PRESERVES_DATA`.
- **File (1):** acceptance report; không sửa source/config/defines. Ghi SDK/build inputs/hash packet. Xác minh đường dẫn staging defines hiện có ngoài Git, không ghi secrets.
- Build explicit -t lib/main.dart --no-pub: emulator debug android-x64; DNY **profile android-arm64**. Kiểm exit0/SHA256/ABI/entrypoint/STAGING/probeAbsent. Không dùng APK từng là probe hoặc build dở.
- Theo preservation protocol mục6: chỉ khi QA B có recovery đã kiểm chứng mới install-r5554. DNY preflight Guest/không unsaved draft, giữ cloudA_R2. Dùng adb -s <verified-DNY-serial> install -r <new-profile.apk>, không clear/uninstall; verify installed base.apk hash.
- **RED/GREEN:** DNY old35ef chưa chứa correction → installed hash đúng packetB. Đây là artifact gate, chưa là feature PASS.
- **DoD/Stop:**2 ABI đúng, data baseline không mất. Stop nếu preservation thiếu, signature/package/ABI mismatch, build fail hoặc quyền thiếu; không sửa config/signature để ép install.

### C2 — native PHONE03 interrupted cold (20 calls,0 repair rounds)

- **Case native:** `PHONE03_COLD_HOME_WHILE_RESTORE_PENDING_RESUMES_ACCOUNT`; negative `PHONE03_EXPLICIT_GUEST_NEVER_REPUBLISHES_ACCOUNT`.
- **File (1):** acceptance report. DNY signedOut cũ cần **fresh login B hợp lệ**, không sửa registry để giả restore. Emulator dùng account thật sau preservation.
- **RED:** trên35ef, validB active → force-stop → launch không-W → HOME ngay → chờ1500ms → resume → Guest.
- **GREEN:** trên APK mới, cùng sequence phải trở về ProfileB/Account sau startup hoàn tất, không login lại/không lộA, Guest draft giữ. Kiểm thêm normal cold/background-resume liền kề; không dùng normal-cold PASS thay interrupted case.
- **Evidence native:** emulator trước rồi DNY profile; safe stage/owner booleans, thời điểm HOME/launch/authorized Profile, screenshot che private data, registry state enum nếu access sẵn có và được phép. Native explicit Guest không tự Account; source9 cases giữ authority negatives.
- **DoD/Stop:** exact repro GREEN trên2 devices, không mất draft. Nếu20 calls không đủ lặp ổn định ghi PARTIAL, xin gói bổ sung. Fail mới → A2-auth riêng; G4 hiện hết rounds, không tự sửa.

### D1 — form/timeline/budget/dialogs (24 calls,0 repair rounds)

- **Cases native:** `E06_RESIZE_CANCEL_PRESERVES_DAYS_ITEMS`, `E07_REORDER_MOVE_SAVE_REOPEN`, `E08_DELETE_LINKED_ACTIVITY_PRESERVES_ACTUAL`.
- **File (1):** acceptance report. Fixtures mới P32_COMPLETE_<date>_<A|B|G> toàn fake; reuse synthetic cũ khi đúng case, không mutate trip Owner.
- E06/E07/E08: exact money, unknown-vs-zero, date bounds/min/max/invalid/interests, affected resize/Cancel; add/edit/reorder/move/time/notes/day notes; selected-day/Back/dirty; linked estimated/actual trước/sau delete/resize/save/reopen. HomeA/Khám phá → PlannerB với bàn phím tiếng Việt thật.
- **RED/GREEN:** baseline các ô thiếu observation; GREEN từng bước expected/actual/digest/totals. Không thêm source test nếu không có bug. Carry-forward linked actual123456 đã PASS; ưu tiên variants chưa chạy và DNY trọng yếu.
- **Native/DoD:** emulator matrix rồi DNY edit/move/reorder/save/reopen và Guest/Account dialogs/actual; mỗi ô ghi build/device/evidence, Cancel không mutate.
- **Stop:** loss/privacy/fail hoặc budget; sửa bug phải packet tối đa5 files riêng.

### D2 — Guest import/Account CRUD/isolation/offline (24 calls,0 repair rounds)

- **Cases native:** `E05_IMPORT_CANCEL_THEN_CONFIRM_EXACTLY_ONCE`, `E09_PREMOUNTED_EMPTY_CREATE_AND_DELETE_REFRESH`, `E03_OWNER_SWITCH_REVOKES_OPEN_DETAIL`, `E10_UNCACHED_OFFLINE_SHOWS_NO_PRIVATE_DOCUMENT`.
- **File (1):** acceptance report. Reuse cloudA_R2/v2 chỉ cho thao tác rõ; fixture mới cho delete/import/empty-list. Không xóa fixture chứng cứ trước readback; không xóa toàn Account để tạo empty state. Thiếu account/fixture được phép thì BLOCKED.
- **RED/GREEN:** F1/F3/F4 source GREEN từ A/B; native no-autoimport→preview Cancel giữ source→confirm1 lần→readback; premounted empty create, pull-refresh/paging/delete/cache/list; A→B trong detail/modal/response pending không lộA hay request sai owner.
- Offline cached label/disabled writes và uncached là hai case riêng; không gọi cached prefetch là uncached.
- **Native/DoD:** emulator đầy đủ rồi DNY critical import/create/update/delete/isolation. DNY offline cần USB; thiếu thì BLOCKED, tiếp tục phần online. Local/source/remote/cache khớp exact owner/version/request.
- **Stop:** cần seedDB/credentials/quyền chưa có, data không synthetic hoặc hết budget.

### D3 — hai session conflict/receipt/V1 (24 calls,0 repair rounds)

- **Cases native:** `E10_TWO_REAL_SESSIONS_STALE_SAVE_CANNOT_OVERWRITE`, `E10_MAIN_UI_LOST_REPLY_RETRIES_SAME_RECEIPT`, `E10_V1_COPY_LEAVES_ORIGINAL_AND_ACTUAL_UNCHANGED`.
- **File (1):** acceptance report. Hai session dùng emulator+DNY sauC; **không dùng5556**. Cùng base version của exact tripA synthetic, winner/stale có preview rõ.
- Reuse conflict recovery CLOSED18/10; chỉ thêm DNY critical/late-response còn thiếu, không lặp toàn repair.
- **RED/GREEN:** main UI lost reply phải sau commit1 request → uncertain → explicit Retry giữ request/bytes →1row/version không tăng, local ack/fence đúng. Native probe18/10 chỉ là dependency evidence.
- V1 fixture cần exactID/source được Owner chỉ định; read/copy không mutate original, actual không tự copy.
- **Native method:** chỉ dùng existing controlled response-loss adapter nếu đã audit và được duyệt cho main UI. Network OFF trước save không chứng minh post-commit loss. Cần sửa probe/source/middleware → dừng, lập packet tối đa5 files riêng; không deploy bằng grant QA.
- **DoD/Stop:** independent session evidence + main UI receipt + approved V1. Thiếu fixture/method/quyền hoặc hết budget thì BLOCKED.

### D4 — map/media/accessibility/profile (24 calls,0 repair rounds)

- **Cases native:** `E11_SELECTED_DAY_MAP_BACK_PRESERVES_DOCUMENT`, `E11_TILE_IMAGE_FAILURE_KEEPS_ACTIONS_USABLE`, `E12_ALL_CHANGED_SCREENS_LARGE_TEXT_FOCUS_KEYBOARD`, `E12_PROFILE_SCROLL_FRAME_CAPTURE`.
- **File (1):** acceptance report. Kiểm stableID/provenance/coverage các ảnh/tọa độ được dùng; unknown coords/hours phải trung thực.
- Map known/day switch/unknown/tile offline/Back không đổi itinerary; image failure/scroll/AI unavailable hiển thị đúng.
- **RED/GREEN:** F2 source từ A/B; native mọi màn đã đổi ở360/412dp, portrait/landscape, text1/1.3/2, TalkBack/focus/targets>=48dp/reduced motion/IME/long Vietnamese. Không lấy một budget screen làm E12 PASS.
- **Native evidence:** emulator matrix; DNY profile critical flows và image/chart scroll frame timings. Báo frame count/p50/p95/jank theo công cụ thực có; thiếu trace ghi NOT RUN. Ghi settings baseline và restore trong finally.
- **DoD/Stop:** source/coordinate coverage, screen checklist và Owner HomeA/PlannerB. Thiếu asset provenance, cần config permission mới hoặc hết budget thì dừng. Document/ảnh mới phải có file slot trong gói.

### D5 — Auth negative và latency (24 calls,0 repair rounds)

- **Cases native:** `E01_A_B_FIRST_REPEAT_THREE_SAMPLES`, `E02_EXPIRED_REVOKED_SESSION_DENIES_ACCOUNT_CACHE`, `E04_TIMEOUT_GUEST_EXIT_ONLINE_RECOVERY`.
- **File (1):** acceptance report. A/B first-after-install-r và repeat, **>=3 mẫu mỗi trạng thái trên mỗi thiết bị bắt buộc**; ghi từng duration/median/max từ submit→SDK→server/local grant→authorized Home. Activity launch/cận trên9288ms cũ không thay mẫu.
- Tách network/local, progress/duplicate/error; không tự đặt SLA để gọi “nhanh”.
- **RED/GREEN:** live timeout/expiry/exact-session revoke cần precondition/reason/time thật; deny Account cache trước authorization, Guest choice không tự Account muộn. Online recovery phải explicit fresh login thành công.
- Không đổi clock/TTL/config/bỏ guard hoặc global revoke để tạo fixture.
- **Native evidence:** emulator; DNY valid cold/resume/offline qua USB và critical Auth. Current debug timing dùng assert nên profile có thể không có SDK stage log: trước QA chọn safe existing trace/monotonic harness/Owner timestamps; thiếu stage instrumentation ghi BLOCKED, không giả duration.
- **DoD/Stop:** E01–E04/PHONE01/03 có evidence thật. Thiếu USB/safe revoke method/credentials/latency instrumentation hoặc hết24 calls thì checkpoint; không coi generic error hay chờ45s là timeout proof.

### E — acceptance/release evidence (16 calls,0 repair rounds)

- **Case evidence:** `RELEASE_SOURCE_APK_DEVICE_EVIDENCE_MATCHES_OWNER_VISUAL_REVIEW`.
- **Files tối đa3:** acceptance report, MUST delivery ledger, completion plan này. Không thêm changelog/helper tiện tay.
- **RED/GREEN:** baseline NOT ACCEPTED → đủ source/emulator/DNY/evidence, không đổi kết quả để khớp24/10.
- Thu APK hash/build-input manifest/installed hash/install-r/data retention, ảnh before/after đúng synthetic fixture, sources/coordinates coverage, latency/frame observations, Owner HomeA/PlannerB signoff. Che private data.
- **Native:** dùng evidence C/D, không build/install lại khi source không đổi. Source đổi sauB/artifact không khớp → quay B/C theo dependency, xin budget nếu hết.
- **DoD/Stop:** report tách source/backend/emulator/DNY, old/new builds, expected/actual/version/ref. Còn critical BLOCKED/FAIL thì NOT ACCEPTED; không tag/release/push/merge.

### F — quyết định đóng P3.2 (4 calls,0 repair rounds)

- **Case acceptance:** `P32_ALL_REQUIRED_ROWS_PASS_WITH_NO_CRITICAL_BLOCKER`.
- **File (1):** completion plan. Chỉ sauE; reconcile E01–E12/PHONE01–04 và Owner decisions, không mutation runtime.
- **RED/GREEN:** còn ô bắt buộc PARTIAL/FAIL/BLOCKED/NOT RUN → NOT ACCEPTED. Chỉ toàn bộ required PASS + Owner đối chiếu mới P3.2 PASS; không suy whole MUST/AI005 PASS.
- **DoD/Stop:** checklist ký nhận. Thiếu evidence/decision thì dừng; deadline/budget không là approval.

## 6. Bảo toàn draft và cập nhật DNY

1. Trước install/force-stop/logout: xác minh exact serial/package/build/owner bằng safe checks; ghi QA draft title/day/activity/actual/dirty, cloud fixtureID/version, network/font/a11y baseline. Không dump Account list/auth EditText/session storage.
2. **5554:** QA_B unsaved cần đường recovery đã kiểm chứng trướcC. Existing VM JSON chỉ là backup graph. Ưu tiên Owner cho save đúng tripB synthetic qua UI rồi server readback, hoặc supported local copy/export+reopen đúng digest nếu product hỗ trợ. Thiếu đường recovery được kiểm chứng thì giữ editor/process, BLOCKED install/force-stop5554. Install-r giữ disk không bảo đảm giữ RAM draft.
3. **DNY:** preflight Guest/không unsaved draft; giữ cloudA_R2/version2. Build profile ARM64 main mới, verify exit/hash/ABI/STAGING, install-r trực tiếp lên35ef8d78…5cac2 bằng cùng signature/package. Verify installed hash và local list/draft baseline. Install fail thì dừng, không uninstall/clear.
4. DNY signedOut do old repro cần freshB login hợp lệ sau update; đây là precondition, không sửa Auth state để giả restore. Sau đó mới cold/HOME/resume. Dùng quyền test credentials Owner xác nhận đúng scope, không ghi vào repo/log/chat.
5. 5556 không đụng. DNY Wi-Fi giữ nguyên; offline chỉ khi USB độc lập đã verify. Restore settings trong finally; không sửa Manifest/native/dependency để lấy trace.

## 7. Budget đề nghị — chưa phải grant

Lượt plan là task độc lập tối đa25 outer calls,1 authored file,0 repair rounds; không tự tiêu counter triển khai G2/G3/G4. Targeted tests được prompt này cho phép, không mở code round. Giữ used counters lịch sử, cộng execution thực tế sau grant; read/wait/question/rejection/checkpoint đều tính, không reset khi đổi session.

### 7.1. Chặng xin duyệt trước: A+B

| Gói | Đã dùng / max hiện tại | Còn | Đề nghị thêm | Max sau duyệt | Phạm vi |
| --- | --- | --- | --- | --- | --- |
| G4 |433/435 calls;7/7 rounds;8/8 files|2 calls;0 round;0 file slot|**+30 calls,+3 rounds,+5 file slots**|**465 calls/10 rounds/13 files**|A24+B8=32 calls;2 remaining+30; reserve tối đa5 prospective paths cho cả main path:2 UI tests+acceptance+MUST ledger+completion plan|
| G2 |246/265 calls;10/11 rounds;8/8 files|19 calls;1 round;0 slot|**+0 calls,+0 rounds**|giữ265/11/8|B shared verification tính bảo thủ tối đa8 calls → còn11; không AI repair|
| G3 |141/170 calls;7/7 rounds;8/8 files|29 calls;0 round;0 slot|**+0 calls,+0 rounds**|giữ170/7/8|B shared verification tối đa8 calls → còn21; không assistant repair|

File slots là cumulative G4 reservation; từng WP vẫn tối đa5 files. Audit roster8 file cũ trước touch; file đã tính không tính lặp. Không tự coi2 UI tests/docs đã nằm trong8 file cũ. Nếu cần source/probe/helper/coverage paths khác thì xin slot trong packet cụ thể, không né cap bằng đổi tên gói.

Chặng A+B không bảo đảm phân loại xong nếu method thiếu; phải stop đúng guard.

### 7.2. Sau A+B đạt mới xét C…F

| WP | Calls trần | Repair rounds |
| --- | ---: | ---: |
| C1 |24|0|
| C2 |20|0|
| D1 |24|0|
| D2 |24|0|
| D3 |24|0|
| D4 |24|0|
| D5 |24|0|
| E |16|0|
| F |4|0|
| Tổng chặng2 |**184**|**0**|

Main path A24+B8+184 = **216 calls**, chưa A2. G4 hiện còn2 nên cần **+214 calls** cho cả main path (max649 = used433+216), **+3 rounds** (max10), reservation **+5 file slots** (max13). Có thể duyệt chặng1+30 trước, rồi chặng2+184 riêng. Đây là cap đề nghị, không là cam kết216 calls đủ toàn matrix.

Nếu A2 cần: **+24 calls/+3 rounds cho đúng một packet** so với max lúc đó và file slots mới đã liệt kê. Không grant âm thầm cả3 packet. D1…D5 đạt24 calls mà còn ô thiếu thì checkpoint, dự toán phần dư và xin bổ sung; không vượt bằng gom lệnh hay đổ sang G2. G3 hết rounds nên AI assistant bug mới cần scope/grant riêng; G2 còn1 round không chuyển thành G4 repair.

## 8. Quyền, blockers và lịch đến24/10

Main path dùng source/staging hiện có, **không cần deploy/DB schema/native config/SDK/dependency/billing/quota/key/model change**. Routine synthetic UI create/update/import/delete là QA write cần Owner duyệt phạm vi; không phải quyền SQL/deploy.

Các quyết định phải tách rõ:

- Install-r APK lên DNY+5554 sau preservation; login A/B và save QA_B để bảo toàn.
- USB độc lập; safe exact-session revoke/expiry fixture và main-UI response-loss method. Chỉ đúng account/session test, không global revoke/đọc token.
- Synthetic V1 exactID cho read/copy. Nếu phải seedDB/deploy instrumentation/đổi native config mới làm được: BLOCKED và packet review riêng, không suy quyền từ historical v12 deployment/Profile migration.
- Quyền Owner đã cấp20/10 cho testA/B giữ đúng scope; prompt hiện tại plan-only nên không login bây giờ. Không mở credential file/ghi password vào report.

Lịch gợi ý có điều kiện, giờ Việt Nam:20/10 A+B nếu grant;21/10 C và D1;22/10 D2/D3;23/10 D4/D5;24/10 E/F. Còn blocked fixtures/USB/expiry/revoke/latency instrumentation và all-screen coverage nên **chưa có cơ sở cam kết đủ P3.2 ngày24/10**. Repair mới hoặc B FAIL có thể đẩy lùi.

Scope tối thiểu trung thực nếu không kịp: source packet verified+B, APK main/hash/install-r giữ data, PHONE03 exact interruption trên emulator+DNY, save/update/dialog/actual critical smoke và gap report. Gọi phần này **P3.2 partial evidence packet / NOT ACCEPTED**, không cắt E01–E12 rồi gọi P3.2 PASS. NếuC không đạt chỉ giao source/evidence, không tuyên bố phone đã sửa.

## 9. Owner decisions trước thực thi

1. **Acceptance scope:** A — chỉ E01–E12/PHONE matrix theo plan đã chốt (đề nghị); B — thêm AI generation/assistant, cần acceptance/budget G2/G3 riêng. AI005 mở scope hay vẫn là MUST riêng?
2. **Bốn failure:** A — bắt buộc phân loại A và sourceB full PASS (đề nghị); B — cho đề xuất defer sau causal evidence+issue/owner/deadline. Không defer loss/privacy/duplicate write hoặc đánh suite FAIL thành PASS.
3. **Budget:** duyệt A+B **G4+30 calls/+3 rounds/+5 slots** trước, giữ G2/G3 maxima; sau đó duyệt riêng C…F **+184 G4 calls**, hay cả main path **+214 calls/+3 rounds/+5 slots**? A2 vẫn cần finding/packet riêng.
4. **Device/data/login:** có cho install-r APK main mới trên DNY/5554 sau verified preservation, fresh A/B login và save chính QA_B synthetic để recovery không?5556 giữ không đụng.
5. **Staging/fixtures:** giữ backend/DB/config v12 hiện trạng (đề nghị), chỉ routine UI writes đúng synthetic fixtures; nếu negative QA đòi DB/deploy/instrumentation/revoke thì có duyệt packet riêng không? Cung cấp method USB, V1 exactID, safe expiry/revoke/response-loss nếu có.
6. **Latency:** chốt ngưỡng submit→authorized Home để đóng PHONE01. Chưa có ngưỡng thì báo samples/median/max và Owner đánh giá, không tự đặt số; tối thiểu3 mẫu mỗi trạng thái vẫn bắt buộc.

## 10. Acceptance checklist và stop conditions

- [ ] Grant rõ calls/rounds/files/scope; counters không reset; STOP cũ chỉ gỡ trong phạm vi mới.
- [ ] F1–F4 có boundary evidence; phân biệt harness/product/environment/unresolved, không gán flaky/Auth thiếu bằng chứng.
- [ ] B exit0/analyzer sạch/full Flutter final summary/Node contracts; hash packet ổn định, không skip/relax assertion.
- [ ] APK2 ABI main/STAGING/probeAbsent, SHA+installed hash khớp; DNY profile mới thay35ef bằng install-r; data retention đã kiểm.
- [ ] QA_B5554 recoverable trước kill/install;5556 không đụng; Guest/actual không mất, Account không lộ chéo.
- [ ] PHONE03 exact cold→HOME pending→resume trên emulator/DNY GREEN; Guest/owner/expiry negatives giữ deny.
- [ ] E01–E12 emulator đủ, DNY critical đủ; two real independent sessions; main-UI receipt/V1/uncached không mạo nhận probe/cache evidence.
- [ ] >=3 latency samples mỗi A/B state đúng device/build; source/coordinate coverage; a11y/keyboard/frame evidence đủ.
- [ ] Owner HomeA/PlannerB đối chiếu; report tách old/new/source/native/backend, giữ lịch sử FAIL.
- [ ] Không critical PARTIAL/FAIL/BLOCKED/NOT RUN bắt buộc; nếu còn → NOT ACCEPTED. Không gộp whole MUST/AI005 vào P3.2 PASS.

Stop khi call/file/round đạt cap, source hash đổi trong verification, draft chưa recoverable, login/private-data ambiguity, request không đúng synthetic, signature/ABI/install mismatch, thiếu quyền hoặc critical loss/privacy. Checkpoint ghi command/result/remaining/budget/next action; không rollback dirty Owner files/clear app để có baseline sạch.

## 11. Handover của lượt plan

- **Changed:** chỉ tạo completion plan này; không product/test/config/source edit, Git publication, native/deploy/DB.
- **Why:** targeted GREEN chỉ chứng minh lần chạy hiện tại; SQL/I/O và animation clock cần boundary evidence. Chờ ack/ready/dispatch để phân loại, giữ uncertain fence thật và Auth authority guards.
- **Testing:**2 targeted invocations thực chạy=4/4 PASS;1 launcher bị SDK lockfile chặn trước test. Không analyzer/full suite/build/native trong task plan. Fullv2 lịch sử479/4 incomplete, analyzer21.9s clean; không full PASS mới.
- **Problems:** causal root cause bốn failures chưa chốt dứt điểm; PHONE03 correction chưa native; DNY old/Guest, QA_B unsaved, fixtures/USB/latency/a11y/map coverage còn thiếu; execution budget chưa cấp.
- **Lesson Candidate:** fixed sleep/pumpAndSettle không chứng minh I/O commit → real SQL/network có completion clock khác animation → chờ observable boundary và giữ negative controls. Normal cold PASS không loại interrupted startup FAIL → khóa đúng pending load/verify và đo native cùng sequence.

Chờ Owner duyệt plan trước khi thực thi.
