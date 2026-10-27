# Core Review R1 — Codex independent review, 24/10/2026

**Verdict: REQUEST CHANGES. Chưa chấp nhận tuyên bố hoàn thành 100%.**

Review chỉ đọc code sản phẩm. Suite hiện có PASS, nhưng 10 assertion về recovery FAIL trong probe độc lập, có 3 positive controls PASS. Các failure được gom thành 6 findings dưới đây, không phải 10 gói sửa riêng. Không merge/commit/deploy trong lượt này.

## 1. Changed — phạm vi và trạng thái nguồn

- Repo: D:/Travel-Go-Android/travel-go.
- Branch: codex/phase-3-discovery-design.
- Actual HEAD: 147bd2050ae3a59e942b29945fbe54c9c9eae60c. Gói Antigravity chưa commit; reviewed candidate = HEAD + dirty working tree.
- Đối chiếu ba plan Core Review R1, spec S3/S5, report Antigravity, diff source và tests. Không bật Superpowers: owner yêu cầu Superpowers cho lượt lập plan trước, không cấp tự động cho lượt review này.
- Mười source files trọng tâm được hash trước/sau và không đổi trong review. Không khẳng định lịch sử toàn bộ dirty work owner được giữ nguyên bởi Antigravity vì không có snapshot nội dung đầy đủ trước implementation.
- Artifacts reviewer tạo: report này và ignored probe `.dart_tool/codex-core-r1-review/recovery_review_probe_test.dart`, log cùng thư mục. Không thay source, permanent tests, dependency, native config, SQL, staging hoặc thiết bị.

### Findings cần sửa (đã tái hiện)

#### F01 [P1] Async marker/bootstrap continuation có thể khôi phục recovery đã hủy

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:82–98,154–168,280–293`.

Authority chỉ được kiểm trước `store.write(readyIntent)`; sau await code vẫn gán currentIntent/ready. Bootstrap đọc marker xong cũng gọi beginRecovery mà không kiểm generation đã đổi bởi Guest. requestEmail ghi marker trước beginRecovery nên Guest trong cửa sổ đó không vô hiệu hóa request đang chuẩn bị.

**Repro và actual:**
- R1: exchange xong, chặn ready-marker write → provider.cancel() → release write. Auth đã hết recovering nhưng provider.isReady lại true.
- R4: chặn bootstrap read → Guest → trả marker cũ. Auth.isRecovering lại true.
- R8: chặn requesting-marker write → Guest → release. Email vẫn được dispatch (actual recoverCalls=1; expected0).

**Hướng sửa:** Một generation/intent owner xuyên toàn operation, bao cả pre-auth dispatch và marker I/O. Kiểm lại sau mọi await, serialize store writes/clear, hủy đồng bộ trước cleanup. Reset in-flight exchange chỉ nếu chính slot/intent đó còn thuộc operation; finally hiện tại gán null vô điều kiện cũng cần được khóa cùng invariant. Không chỉ thêm một if sau riêng ready write.

**Đóng khi:** R1/R4/R8 GREEN và có test old write/clear A không ghi đè hoặc xóa marker B; initialization/callback/cancel cùng dùng một ownership rule.

#### F02 [P1] Nút Hủy không dùng cancellation authority/credential queue, để SDK session xuất hiện lại

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:458–475`; so với API `AuthProvider.cancelRecovery:124–141`.

Provider.cancel xóa state, gọi signOut trực tiếp ngoài queue, rồi finishRecovery; nó không gọi cancelRecovery để tăng generation và drain SDK operation. signOut có thể chạy TRƯỚC exchange đang pending hoàn tất. SDK exchange sau đó vẫn lưu session; chỉ chặn publish result không hoàn tác side effect SDK.

**R3 actual:** provider không ready, marker null, nhưng client.auth.currentSession khác null sau khi exchange trả về. Expected SDK session null. Đây là session synthetic thực do SDK tạo qua fake HTTP, không phải provider mock trả true.

**Ảnh hưởng:** UI tưởng đã hủy nhưng SDK vẫn giữ phiên recovery. Không khẳng định server auth bị bypass hoặc đã đọc được dữ liệu riêng; lỗi đã chứng minh là cleanup/cancellation không hoàn tất và state SDK/UI lệch nhau.

**Hướng sửa:** Hủy authority ngay, chờ exchange đang dispatch kết thúc trong queue rồi cleanup session thuộc intent cũ; không signout nhầm B. Áp dụng cùng queue cho success cleanup, retryCleanup và cancel, không chỉ SDK exchange/update.

**Đóng khi:** R3 GREEN; bổ sung cancel→loginB và retryCleanupA→loginB/callbackB thực sự chồng lấn, assert SDK user cuối là B và marker B còn nguyên.

#### F03 [P1] Hai submit trong lúc write-ahead đang chờ có thể gửi hai PUT mật khẩu

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:345–360`.

State updating chỉ được đặt SAU await store.write. Hai submit cùng thấy phase ready/state ready trước khi ghi xong; cả hai đi qua write-ahead và vào credential queue. Queue chỉ tuần tự hóa, không gộp hoặc cấm mutation thứ hai.

**R2 actual:** chặn updating marker của hai submit, release rồi giữ cleanup pending → PUT calls=2, expected1. Ca đối chứng submit bình thường vẫn PUT1 và cleanup thành công.

**Hướng sửa:** Claim update slot đồng bộ trước await đầu tiên; disable UI ngay; giữ token operation riêng và validate lại trước dispatch. Pre-dispatch storage failure có thể release slot theo state hợp lệ; ACK/uncertain tuyệt đối không mở lại quyền PUT.

**Đóng khi:** R2 GREEN cả double tap cùng password và hai password khác nhau; chặn riêng write-ahead/SDK/cleanup để không cho thứ tự microtask tình cờ làm test xanh.

#### F04 [P1] Cleanup failure bị nuốt, vừa mất màn retry vừa cho account mới đăng nhập

**Source:** `lib/features/auth/providers/auth_provider.dart:104–119`, `password_recovery_provider.dart:37–47,458–477`.

_handleRecoveryCancellation bỏ cờ recovering trước khi cleanup hoàn tất; invalidators chạy unawaited; lỗi marker clear và SDK signout bị nuốt. Provider.cancel chuyển idle trước cleanup và cũng nuốt lỗi. Lỗi I/O không còn là điều kiện chặn account grant như plan yêu cầu.

**Repro:**
- R5: ready A → store.clear throw → login B. Actual login=true.
- R9: cancel với clear throw. Actual provider cleanupRequired=false (idle) trong khi auth.isRecovering vẫn true, không có recovery retry UI.
- R10: lặp R5 với AuthProvider có LocalAccountLifecycleService và SQLite fixture thật. Actual login=true, trái expectedfalse.
- Positive control cùng lifecycle/SQLite khi clear thành công PASS và cấp đúng owner B. Fixture dùng UUID và JWT synthetic có exp hợp lệ; không suy lỗi này từ fixture bị từ chối.

**Ảnh hưởng:** Một lần login có thể được báo thành công dù marker recovery A chưa dọn; cold boot đọc marker cũ có thể ép lại flow sai/chấm dứt phiên mới. Không chỉ là khác biệt về thông báo lỗi.

**Hướng sửa:** Cleanup là operation có kết quả và có owner, normal auth phải await kết quả trước dispatch/publish. Fail thì giữ một trạng thái retry/blocked account rõ ràng; Guest vẫn khả dụng. Không dùng catch rỗng để mở quyền. Không giữ callback invalidator tự enqueue ngược gây deadlock.

**Đóng khi:** R5/R9/R10 GREEN; fake prefs remove=false, exception và signOut failure đều được kiểm; assert marker, SDK session, lifecycle handle, UI và trace cleanupA trước loginB, không chỉ return value.

#### F05 [P2] Ready intent hết hạn trong RAM vẫn dispatch update

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:326–338`.

submit ưu tiên _currentIntent mà không gọi intent.isExpired(_clock()). TTL chỉ áp khi đọc store/callback; form đã mở có thể sống quá 60 phút, SDK session còn hạn do refresh hoặc còn thời gian chênh lệch.

**R6 actual:** mở form ready → advance provider clock61 phút, giữ JWT synthetic còn hạn theo clock SDK → PUT1, expected0.

**Hướng sửa:** Validate TTL của intent và identity/session trong queue ngay trước side effect, không chỉ lúc mở form. Quá hạn không cập nhật; giữ cleanup/nhãn phù hợp, cho xin flow mới sau cleanup.

**Đóng khi:** R6 GREEN; có ca sát ranh giới60 phút và hết hạn trong lúc write-ahead/queue đang pending.

#### F06 [P2] Cold ready không server-revalidate như plan, chỉ tin session local

**Source:** `lib/features/auth/providers/password_recovery_provider.dart:111–119`; update preflight tại334–338 cũng chỉ kiểm local.

Không có SDK getUser/revalidation trước cold ready. Test cold đã gọi initialize thật, nhưng chỉ seed UID khớp rồi assert ready; chưa có server-denial case.

**R7 actual:** fake transport GET user sẽ401 revoked, nhưng provider vẫn ready và không gửi GET. Expected không mở form khi server từ chối. Đây không phải bằng chứng vượt qua kiểm soát password update của server; server vẫn quyết định PUT. Finding là thiếu bước xác minh/luồng lỗi đã được yêu cầu ở A2/A3.

**Hướng sửa:** Revalidate qua SDK trong recovery queue, kiểm verifiedUserId/expiry/current authority sau await; denial/expired không mở form, offline không tự xem là verified online. Không cấp normal account handle để thực hiện bước này.

**Đóng khi:** R7 GREEN, GET UID sai/401/offline/late-owner/late-cancel đều có test, PUT không được dispatch nếu preflight không đạt.

## 2. Why — luồng, nguyên nhân chung và trạng thái CR

Recovery gồm ba lớp state: UI/provider, marker bền vững và session do SDK nắm. Chặn một Future trả về không xóa side effect SDK đã xảy ra; clear UI trước I/O không có nghĩa marker đã dọn. Hiện queue chỉ bao exchange/update nhưng cancel/cleanup/store continuation nằm ngoài cùng ownership rule, nên lỗi còn lặp tại các cửa sổ await khác.

Map đã tách đúng itinerary origin khỏi GPS; đổi ngày/binding cấp token mới; completion camera kiểm active token và dispose dùng cached provider. OSRM có revision check ở success/error/timeout; provider bắt ConfigChanged riêng và không vẽ offline line cho exception đó. Không tìm thấy blocker code mới trong diff Map/API được kiểm tra.

| CR | Kết luận trên candidate này | Bằng chứng / giới hạn |
|---|---|---|
| CR1 | Đã sửa trigger ready→updating làm tháo form | Widget/provider paths thông thường PASS; A4 đầy đủ còn coverage gap và bị F01/F04 tác động |
| CR2 | CHƯA ĐÓNG | F01/F02/F04; 7 probes fail trong các nhóm này |
| CR3 | Đã sửa ở source | first/middle/last route + GPS-denied/0–1 stops tests PASS |
| CR4 | Đã sửa race ngày chính ở source | Token thay ở day/binding, guards completion/camera, delayed-response tests PASS; camera test chuyên biệt chưa thực sự đo camera |
| CR5 | Duplicate thông thường đã sửa; chưa đủ đóng toàn race contract | Duplicate positive control PASS; scope của bootstrap/marker/slot qua cancel còn F01 |
| CR6 | ACK→cleanup-marker failure và uncertain paths cơ bản đã sửa | Existing tests PASS; single-update/preflight/cleanup invariants còn F03/F04/F05/F06 |
| CR7 | Đã sửa backend/OSRM invalidation chính | Service/provider success/error paths PASS; old-retry-host test chưa thực sự có retry pending |

Không yêu cầu mở lại planner/catalogue/AI hay sửa lại phần Map đã đạt chỉ để tăng scope. Tập trung correction vào sáu findings và test còn thiếu dưới đây.

## 3. Testing — reviewer-run và tính thực chất của coverage

### Fresh Full

Command: `& ./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter`.

- Process exit0.
- analyze: No issues found, 4.4s.
- Flutter: 1097 All tests passed, 2:05.
- Node: 91 pass /0 fail.
- Logs: `.dart_tool/travelgo-verification/20261024T053648760Z-26120/`.
- Không chạy lại Full sau mỗi probe: code sản phẩm không thay đổi, probe nằm trong ignored .dart_tool, không nằm trong permanent test suite.

### Independent probes

Command:

```powershell
& D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe D:/flutter/flutter/bin/cache/flutter_tools.snapshot --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded --timeout=30s .dart_tool/codex-core-r1-review/recovery_review_probe_test.dart
```

Final process exit1, **13 cases: 3 PASS controls, 10 FAIL behavioral assertions**. Log `.dart_tool/codex-core-r1-review/recovery-probes.log`. Chỉ final run được tính; các lượt chuẩn bị fixture có type/UUID/JWT-exp chưa đúng đã được sửa trong probe, không được báo thành lỗi sản phẩm. Fixture cuối có positive lifecycle control PASS.

| Probe | Expected | Actual | Finding |
|---|---|---|---|
| R1 cancel lúc ready write pending | ready false | true | F01 |
| R2 double submit lúc write-ahead pending | PUT1 | PUT2 | F03 |
| R3 cancel lúc exchange SDK pending | SDK session null | session A còn | F02 |
| R4 Guest lúc bootstrap read pending | recovering false | true | F01 |
| R5 clear fail rồi login B | deny login | success | F04 |
| R6 RAM intent >TTL60 | PUT0 | PUT1 | F05 |
| R7 server deny cold ready | không ready + GET verify | ready, không GET | F06 |
| R8 Guest lúc requesting write pending | mail0 | mail1 | F01 |
| R9 cancel cleanup fail | cleanup retry UI state | idle | F04 |
| R10 clear fail/login B với lifecycle + SQLite | không account grant | login success | F04 |

Controls PASS: ordinary ready update đúng1 PUT + cleanup; callback duplicate không cancellation chỉ1 exchange; lifecycle + SQLite login B sau cleanup thành công.

Probes dùng HTTP mock và controlled storage seam để tạo interleaving xác định, SDK thật đã cài, một fixture SQLite thật cho account grant; không gọi Supabase server/email/OSRM thật. Không tuyên bố native acceptance hoặc khai thác auth server từ các probe này.

### Coverage có tên nhưng chưa kiểm đúng điều được hứa

| Test hiện tại | Điều thực sự chạy | Thiếu cần bổ sung |
|---|---|---|
| authority: cancelled_intent_never_dispatches_queued_mutation | cancel xong mới gọi mutation | Một mutation đã xếp queue bị cancel trước dispatch |
| authority: old_marker_write_cannot_overwrite_new_intent | await toàn bộ A rồi mới B | Không có write A pending; probe R1 chứng minh cửa sổ chưa đóng |
| authority: new_login_waits_for_old_recovery_cleanup | chỉ assert exchangeA trước loginB | Không assert cleanup tồn tại/thứ tự hoặc marker clear hoàn tất |
| authority: recovery_session_never_publishes_on_resume | AuthProvider không lifecycleLoader | handleAppLifecycleState return ngay, không thực thi guarded resume |
| cleanup: wrong_or_expired_session_cannot_update | chỉ UID mismatch | Không expired/TTL/server denial; R6/R7 còn fail |
| gate: warm_and_cold_callbacks_override_nested_bootstrap | chỉ phát warm stream callback | Không initialAuthLinkLoader callback cold |
| gate: bootstrap_resume_timer_cannot_replace_recovery_form | child là BACKGROUND_CHILD_SCREEN, auth không lifecycle | Không Splash timer/nested bootstrap/lifecycle thật |
| gate: cleanup_success_returns_to_login_flow | assert BACKGROUND_CHILD_SCREEN | Không chứng minh đến LoginScreen/SDK session null trong TravelGoApp |
| map: stale_location_finally_and_camera_do_not_apply | gọi provider bằng stale token đã hết hiệu lực | Không TripMapScreen/MapController hoặc pending location để đo camera |
| URL: new_operation_uses_new_host_without_retargeting_old_retry | hai request tuần tự với injected Dio | Không old request/retry chồng lấn; injected Dio không tự có default retry interceptor |

Ngoài ra main vẫn nuốt recovery marker read exception và không truyền bootstrapBlocked từ kết quả lỗi; A4 failure path này chưa được implement/test đầy đủ. Ghi là requirement/coverage gap, chưa coi là exploit hoặc failure native đã tái hiện.

## 4. Problems — điều kiện chốt một gói sửa thay vì vòng vá từng triệu chứng

1. Sửa ownership/cancellation + serialized cleanup/store theo F01/F02/F04 như một invariant xuyên các bước, không vá riêng từng probe.
2. Claim update slot trước await đầu tiên (F03), giữ write-ahead/uncertain contract đã làm; centralize TTL/server/session preflight (F05/F06).
3. Chuyển 13 probe cases thành regression permanent có kiểm fixture controls; mở rộng guarded lifecycle cho cancellation/Guest/resume. Các controls phải vẫn PASS.
4. Bổ sung các test thiếu trong bảng coverage. Không đổi tên test/giảm assertions thành return-value-only để báo green.
5. Chạy targets rồi Full một lần trên final source, ghi hash/diff/HEAD; review lại cùng checklist. Native/email thật vẫn NOT RUN đến khi có đúng QA environment/quyền.
6. Report Antigravity cần sửa phần model: source chỉ thêm RecoveryPhase.updating; không có updatedAtUtc/failedRecoverable/dropUpdateAck trong PendingRecovery. dropUpdateAck hiện là flag của test, không phải model sản phẩm. Cần map CR→test/assertion/log, không chỉ tổng số suite pass.
7. Không commit/push/merge/deploy và không sửa ngoài scope từ báo cáo này. Owner chuyển correction cho Antigravity; Codex không tự implement.

Đây là phạm vi kết luận ở candidate hash dưới đây, không lời hứa phần mềm hết mọi lỗi. Không thêm approval gate vào công việc đã giao; việc review này kết thúc với REQUEST CHANGES có repro cụ thể.

### Candidate identity — SHA256, trước/sau review giống nhau

| File | SHA256 |
|---|---|
| `lib/features/auth/models/password_recovery_state.dart` | `a53034082e1a698e55adeb488243927a3dbb95581a9dce97c71f611c43a65585` |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` | `49744faa3f3b8960c6b454c607a602d701a1f346355665cb881dad298e49c9fe` |
| `lib/features/auth/presentation/widgets/password_recovery_gate.dart` | `ee68cac73246332672d0107a32e32c0621003613e1aa2d8f36b602ea6b3e7890` |
| `lib/features/auth/providers/auth_provider.dart` | `ca48ad34180005fe6968cd848e0210c3680f2f9674be2f1dc0c4db997e86083d` |
| `lib/features/auth/providers/password_recovery_provider.dart` | `4a73090cc07ca0f11889f00921a19019d0510ca10f30bed3c809b75565f59ca2` |
| `lib/features/auth/services/recovery_intent_store.dart` | `296361c70f2c5194c770eb63636075a326fc8ea4d1dda06e942a4718f8e28082` |
| `lib/main.dart` | `af0d5fe0212152262cbdb589c2a391d96b801f6930416bbb351da0b80cda972b` |
| `lib/features/map/presentation/screens/trip_map_screen.dart` | `a8bbeb3a246e53408697cfdcd3289d77d661fed58643b297c8f599090a36480c` |
| `lib/features/map/providers/map_provider.dart` | `0ae871e6d98e842a400b4098d6e97f17796a3e3af494941ec5143f488b70accd` |
| `lib/features/map/services/map_api_service.dart` | `daa5fdc2de8582aaac129359e77ed62e4afc71ccb6e2c69be75a0456d1d8adc8` |

## 5. Lesson Candidate

- Problem: tests xanh nhưng race còn → Root cause: tên test mô tả concurrency nhưng setup chạy tuần tự hoặc bỏ qua lifecycle → Actionable rule: mỗi race test phải chứng minh đã dừng đúng boundary và có operation đối nghịch xảy ra trước khi release.
- Problem: đã cancel mà SDK session/ready quay lại → Root cause: chặn kết quả provider không hoàn tác SDK/storage side effects → Actionable rule: ownership phải bao dispatch, completion, persistent write và cleanup, với positive controls cho flow mới.

