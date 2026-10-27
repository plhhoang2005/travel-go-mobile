# C3 — Codex implementation theo yêu cầu owner, 25/10/2026

Owner yêu cầu trực tiếp **“hay bạn sửa c3 đi”** sau [review R4](C3_CODEX_REVIEW_R4_20261025.md). Đây là chỉ thị cho Codex implement trong task này, thay phân công Antigravity implement thông thường; không sửa permanent workflow. Chỉ xử lý C3, chưa mở C4. Không dùng Superpowers cho Codex vì chính sách hiện hành chỉ cấp thường trực cho Antigravity coding.

**Kết quả: SOURCE/AUTOMATED PASS.** F02/F03 được sửa bằng marker FIFO và retained cleanup ownership; bổ sung fence callback và SDK owner tại exchange. Targeted126/126, Full analyzer sạch/Flutter1039/1039/Node91/91, exit0. Self-review hoàn tất; không gắn nhãn independent acceptance hoặc native/live acceptance.

## 1. Changed

Branch `fix/ai-planning-stability`, base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2/C3 owner work. Codex sửa **5 files hiện có và thêm 1 test file**, đối chiếu với snapshot R4 và backup trước task trong `.dart_tool/c3-codex-implementation/before/`; không reset/stash/clean, stage/commit/push/merge.

| File | Thay đổi trong lượt Codex |
| --- | --- |
| `lib/features/auth/providers/password_recovery_provider.dart` | FIFO cho marker write/clear/cancel; kiểm generation+owner trước dispatch, bỏ toàn bộ write bù/restore; tách `_cleanupIntent` khỏi active authority; giữ retry owner sau lỗi; chặn callback cũ khi đang drain; mọi SDK cleanup đi qua AuthProvider |
| `lib/features/auth/providers/auth_provider.dart` | Recovery signOut chạy trong credential queue; revoke ngay trước cleanup account transition; ghi nhận intent thực sự sở hữu SDK session từ exchange success và khi phục hồi marker đã verified, độc lập với thời điểm ready-marker commit |
| `test/password_recovery_authority_test.dart` | Giữ assertions bảo vệ SDK/user/state; đổi sequencing để release gate trước await cancel/login vốn nay phải chờ drain; thêm assertions login không vượt pending marker cleanup |
| `test/password_recovery_callback_race_test.dart` | Thay các cut point dựa vào write bù đã bị loại bằng pending-write/cancel/successor cùng FIFO; vẫn kiểm marker successor và không hồi sinh intent đã cancel |
| `test/password_recovery_gate_test.dart` | Flush real/fake async tới đúng state boundary, giữ server rejection/form/child assertions; thêm UI retry sau cancel đã xóa marker nhưng logout lỗi |
| `test/password_recovery_marker_ordering_test.dart` (mới) | Sáu regressions/control: drain ordering, retry khi mất marker, retry clear fail, successful cancel, callback cũ trong drain, SDK exchange đã xong nhưng ready-marker còn pending |

RecoveryIntentStore, auth model/TTL, SDK/dependencies/native config/backend/schema giữ nguyên. Auth file giữ định dạng các vùng ngoài phần sửa để giảm diff. Các sửa/tài liệu/ảnh/script khác của owner được bảo toàn.

## 2. Why — luồng trước/sau và ownership

**F02:** trước đây write A muộn → ghi bù B → ghi bù C; mỗi write bù lại có một cửa sổ stale mới. Bản này chỉ có một hàng đợi marker tại provider, bao cả entry vào pausable/overridable store. Cancel thu hồi authority đồng bộ, rồi clear đứng sau write đang bay. Write successor xếp sau clear; nếu successor bị hủy trước khi tới lượt thì không dispatch write. Khi các futures hoàn tất, không còn operation cũ có thể ghi lại marker. Không cần biết chuỗi có hai hay nhiều intent, không có tầng compensation mới.

**F03:** thu hồi quyền mutation không đồng nghĩa xóa owner cần để retry. Cancel tách active intent khỏi `_cleanupIntent`; marker có thể đã xóa nhưng owner cleanup còn trong RAM đến khi dọn xong hoặc được supersede an toàn. SDK logout500 → cleanupRequired giữ owner → người dùng retry → hoàn tất dọn, không gửi lại password PUT.

**SDK ownership:** SDK exchange có thể tạo session trước khi ready-marker ghi xong. AuthProvider ghi nhận owner session ngay bên trong credential queue khi exchange thành công. Khôi phục marker verified cũng gắn owner phù hợp. Vì vậy cancel trong cửa sổ marker pending vẫn dọn SDK session A; việc mới gửi email B chưa được coi là đã có SDK session B. Khi B đã có session thật hoặc normal login mới, cleanup A không sở hữu nó. Các SDK signOut kiểm owner trong cùng queue với credential operations.

**Callback cũ:** trong lúc cancel đang drain, callback không được bootstrap lại marker A rồi lấy quyền ready mới. Negative regression đã tái hiện accepted=true trước guard, và đạt false sau sửa.

Ví dụ: A đang ghi marker → Hủy A → nhập B. UI thu hồi quyền A ngay; marker cleanup chờ I/O A, B không commit vượt lên. Nếu người dùng hủy B trước lượt, B không ghi. Nếu logout A lỗi, retry vẫn có owner dù marker đã mất. Không xóa dữ liệu chuyến đi hoặc SQLite để chữa auth.

## 3. Testing — evidence thực tế

**Targeted cuối: 126/126 PASS**, exit0, log `.dart_tool/c3-codex-implementation/targeted-final.log`, 20s. Sáu suites gồm ordering mới, authority, callback-race, cleanup, gate và auth-navigation. Trước đó regression/unit/UI nhỏ `regressions-final.log` đạt12/12; bản cuối thêm SDK-owner negative/control và được kiểm lại trong targeted126.

Full cuối **exit0** trên đúng bytes được hash: analyzer **No issues found, 4.6s**; Flutter **1039/1039 PASS, 1:53**; Node **91/91 PASS, fail0/skipped0**. Wrapper `.dart_tool/c3-codex-implementation/full-owner-final.log`; suite logs `.dart_tool/travelgo-verification/20261025T071106772Z-27796/`. Final source snapshot377/377 files không đổi qua run và sau khi thu completion; git diff --check exit0. Không dùng các lượt Full trước làm kết quả cho bytes cuối.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --concurrency=2 --reporter=expanded --timeout=15s test/password_recovery_marker_ordering_test.dart test/password_recovery_authority_test.dart test/password_recovery_callback_race_test.dart test/password_recovery_cleanup_test.dart test/password_recovery_gate_test.dart test/auth_navigation_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

RED và chẩn đoán giữ trong `.dart_tool/c3-codex-implementation/`:

- `red.log`: trước product edits, 3 behavior FAIL / 1 control PASS, gồm ordering vượt write và hai nhánh cleanup retry.
- `callback-red.log`: negative callback cũ được chấp nhận khi cancel pending, trước guard bổ sung.
- `sdk-owner-red.log`: tự rà soát sau bản queue ban đầu, SDK còn session khi cancel sau exchange nhưng trước marker ready; trước bổ sung SDK session ownership.
- `targeted-1.log`, `targeted-2.log`: các lượt chuẩn bị, có một guard thiếu trước marker queue và widget timing chưa flush đủ; **không dùng như kết quả cuối**.
- `gate-probe.log`: xác nhận widget chuyển ready→updating sau khi flush real async, không phải bỏ assert. `gate-final-2.log`:7/7 PASS sau helper flush đúng boundaries.
- Full đầu dừng vì5 lints cơ học; đã sửa. Full kế tiếp PASS trên revision queue trước bổ sung SDK owner; **không thay Full cuối**. Không nâng SDK/package để xử lý lỗi.

Các old reviewer probe files ignored giữ nguyên. Một số harness cũ await cancel trước khi release chính write/SDK gate mà cancel nay phải drain, hoặc chờ write bù không còn tồn tại. Không chạy chúng rồi gọi timeout là failure/không sửa chúng để báo “30 raw probes PASS”. Hành vi negative/successor/session được giữ trong permanent suites với sequencing phù hợp FIFO và các assertions bổ sung về không overtaking. Đây là thay đổi cut point theo implementation đã cho phép trong handoff; không giảm schema/authority checks.

Ba nhóm chỉnh nguồn chính được kiểm chứng gồm marker/cleanup owner, authority trước dispatch/callback và SDK ownership trước persistence; các lần chỉnh harness/lint được ghi riêng trong logs. Không dùng việc đổi tên task để reset guard sửa lỗi.

Đã đối chiếu [Supabase signOut documentation](https://supabase.com/docs/reference/dart/auth-signout) và [changelog](https://supabase.com/changelog), cùng SDK đã khóa trong cache; không đổi API provider/cloud hoặc package version. Tests dùng fake HTTP/SharedPreferences/SQLite fixtures; không auth/email live, đọc/log credentials thật.

### Candidate cuối

Snapshot `.dart_tool/c3-codex-implementation/final-source-snapshot.json`:377 files, lập trước Full cuối. Hashes source/tests:

| File | SHA256 |
| --- | --- |
| auth_provider.dart | `305a7bad641d435b08739ed7efe2c71e80dbd4f4037bc0474e06ff2b6b85c67c` |
| password_recovery_provider.dart | `bf05197d51aa78affbf475457a1bf1bf978f58d9e080b57d41012d5a41af30b4` |
| password_recovery_authority_test.dart | `26d427a51a3f01c0b5e5082d11031328e47b1a64f0d7ee2e391408e3fd078fb0` |
| password_recovery_callback_race_test.dart | `8bfc648d2b11031cf05d1fcefb1ef2781501c1165c7313ecd771318a01ae1715` |
| password_recovery_gate_test.dart | `ad5c04203a1f34168ab4cb3478ef8f4fe1c3abd8bee1657161df6575031fe5db` |
| password_recovery_marker_ordering_test.dart | `9b1a957ede5c5e1474450975659dd2571f45c62e538b98ddd30ca190e823fe2f` |

## 4. Problems / giới hạn

Đây là implementation và self-review của Codex theo chỉ thị owner, **không phải independent review R5**. Chưa nghiệm thu toàn recovery/app. C4 double-submit trước write-ahead, TTL/server revalidation, OTP/profile/live vẫn deferred. Không commit/push/merge/deploy/SQL hoặc đổi native/dependency.

Không có DTD/debug app được kết nối. `dtd.listDtdUris` trả không có process; lần gọi hot_reload bị **automatic approval review từ chối** vì có thể đổi trạng thái runtime chưa được chỉ định/ủy quyền. Không bypass hoặc thử runtime qua CLI/thiết bị khác. Hot reload/native/device/live **NOT RUN**; không có install/clear/uninstall làm mất draft. Source/tests tiếp tục được verify bằng automated suites.

Một widget-test harness bị kẹt fake async đã được dừng đúng process tree do task tạo; không dừng IDE/thiết bị owner. Lỗi literal của scratch probe và lints được sửa ở artifacts/source phù hợp, không được tính thành product exploit hoặc evidence success.

## 5. Lesson Candidate

Problem → Root cause → Rule: “write bù chữa ca cũ nhưng tạo cùng race ở write mới” → “không có ordering bao operation I/O” → “serialize mutation từ entry, revoke ngay rồi drain; không sửa bù dữ liệu từ continuation stale”.

Problem → Root cause → Rule: “retry UI hiện nhưng không còn owner” → “xóa quyền và quên trách nhiệm cleanup cùng lúc” → “tách active authority, persisted marker và retained cleanup owner; gắn SDK owner ngay khi SDK side effect xảy ra”.
