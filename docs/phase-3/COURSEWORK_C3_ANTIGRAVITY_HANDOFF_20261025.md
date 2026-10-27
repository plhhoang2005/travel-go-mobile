# Prompt giao Antigravity — C3: recovery ownership, cancel và cleanup

Triển khai **chỉ task C3** của plan Core R2 đã duyệt. Owner vừa trả lời “duyệt” sau review cuối C2 và bước tiếp theo C3. Không cần xin lại cùng scope; không tự mở C4 hoặc phần AI. Codex đã chuẩn bị handoff này, chưa sửa app C3.

**Bắt buộc sử dụng Superpowers khi code, theo chỉ thị owner 25/10/2026.** Đọc và áp dụng các skill phù hợp: `using-superpowers`, `executing-plans`, `systematic-debugging`, `test-driven-development`, `verification-before-completion` theo yêu cầu của chúng. Nêu skill đang dùng và mục đích. Thực thi plan C3 đã duyệt; dùng skill không yêu cầu làm lại lựa chọn thiết kế/phê duyệt đã có hoặc mở scope mới. Không tự commit/push/merge/deploy, thao tác live/device hay thêm dependency từ workflow skill. Nếu skill không có trên môi trường Antigravity, báo rõ tên thiếu và ảnh hưởng; không giả đã dùng.

## 1. Đọc và xác minh trước khi sửa

Repo `D:/Travel-Go-Android/travel-go`; branch tại bàn giao `fix/ai-planning-stability`; actual HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`. Working tree có nhiều thay đổi C1/C2 và tài liệu/ảnh/script của owner chưa commit. Chạy status/HEAD và kiểm diff trước, không reset/stash/clean hoặc ghi đè baseline.

Đọc:

- `AGENTS.md`, `.agent/rules.md`, `.agent/workflow.md`, đặc biệt session-context/owner-learning và explicit-superpowers.
- [.agent/product-scope.md](../../.agent/product-scope.md), [.agent/ai-planner-design.md](../../.agent/ai-planner-design.md).
- [Master R2](../superpowers/plans/2026-10-24-coursework-r2.md), [Core R2 mục C3/C4](../superpowers/plans/2026-10-24-coursework-core-r2.md).
- [C2 final review](C2_CODEX_REVIEW_FINAL_20261025.md): C2 ACCEPT SOURCE/AUTOMATED/ANDROID DEBUG BUILD, chưa device/iOS/live. Giữ các sửa C1/C2, không đưa map/engine provider trở lại.
- [Core review R1](CORE_REVIEW_R1_CODEX_REVIEW_20261024.md): tập trung **F01, F02, F04** và **R1/R3/R4/R5/R8/R9/R10**. Đây là evidence lịch sử, phải tái hiện trên candidate hiện tại.

Baseline ba file chính tại lúc viết handoff (SHA256, không thay actual diff/HEAD check):

| File | SHA256 |
| --- | --- |
| `lib/features/auth/providers/password_recovery_provider.dart` | `4a73090cc07ca0f11889f00921a19019d0510ca10f30bed3c809b75565f59ca2` |
| `lib/features/auth/providers/auth_provider.dart` | `ca48ad34180005fe6968cd848e0210c3680f2f9674be2f1dc0c4db997e86083d` |
| `lib/features/auth/services/recovery_intent_store.dart` | `296361c70f2c5194c770eb63636075a326fc8ea4d1dda06e942a4718f8e28082` |

## 2. Mục tiêu và giới hạn sửa

Tình huống đích: khôi phục A đang chờ đọc/ghi marker hoặc SDK exchange → người dùng Hủy/Guest → đăng nhập B. Continuation của A không được làm recovery sống lại, không dispatch email mới sau hủy, không ghi/xóa marker của B và không đăng xuất B. Khi chưa có B, exchange A hoàn tất muộn cũng phải được dọn session A trước khi coi hủy hoàn tất.

Nếu clear marker hoặc signOut thất bại, giữ lỗi và trạng thái có thể thử dọn lại; không báo cleanup thành công hay cấp account mới. Guest vẫn dùng được, nhưng Guest không làm mất trách nhiệm cleanup và không cho phép account grant vượt qua lỗi.

Sửa chính:

- `lib/features/auth/providers/password_recovery_provider.dart`
- `lib/features/auth/providers/auth_provider.dart`
- `lib/features/auth/services/recovery_intent_store.dart`
- `lib/features/trips/services/local_account_lifecycle_service.dart` chỉ khi trace chứng minh cần thay đổi cho cùng invariant.
- Model/service/gate recovery hiện có chỉ khi cần để thể hiện ownership hoặc lỗi/retry của C3; ghi rõ lý do. Không refactor rộng hoặc thiết kế lại UI.

Giữ API recovery hiện có khi có thể; dùng Provider/Dio/backend/SDK đã cài. Không thêm dependency, đổi native URL/permission, schema, auth project/config hoặc SDK version. Nếu cần gọi API SDK chưa dùng, xác minh phiên bản đang khóa và tài liệu/changelog Supabase chính thức trước khi dựa vào hành vi đó. Không dùng quyền client hoặc dữ liệu user-editable thay server authority.

**C4 vẫn OPEN:** F03/R2 double-submit, F05/R6 expiry-before-dispatch, F06/R7 cold server-revalidation, OTP/profile và nghiệm thu email thật. Không làm yếu guards hiện có hoặc sửa các expected của C4 để suite xanh. Nếu code dùng chung khiến một ca C4 đã PASS thì ghi evidence, không mở rộng thành tuyên bố hoàn tất C4.

## 3. Thứ tự triển khai

### Bước 1 — Tái hiện trước khi sửa

Chuyển các ca C3 sang permanent regression tests phù hợp trong:

- `test/password_recovery_authority_test.dart`
- `test/password_recovery_callback_race_test.dart`
- `test/password_recovery_cleanup_test.dart`
- `test/password_recovery_gate_test.dart`, `test/auth_navigation_test.dart` khi cần kiểm UI retry/account grant.

Probe tham khảo hiện có: `.dart_tool/codex-core-r1-review/recovery_review_probe_test.dart` (ignored, không bảo đảm có trên máy khác). Giữ original assertions nếu dùng; tự dựng fixture tương đương khi thiếu, không coi thiếu artifact ignored là blocker implementation.

| Ca | Interleaving phải giữ bằng Completer/barrier | Expected |
| --- | --- | --- |
| R1 / F01 | ready-marker write A pending → cancel → release | Không ready A; không tái tạo marker A sau cleanup hoàn tất |
| R4 / F01 | bootstrap read pending → Guest/cancel → trả marker A cũ | Không begin/restore recovery A |
| R8 / F01 | requesting-marker write pending → Guest/cancel → release | Không dispatch email sau hủy; recoverCalls=0 |
| R3 / F02 | SDK exchange A pending → cancel → exchange hoàn tất | Không ready A; cuối cùng không còn SDK session A khi chưa có B |
| F02 bổ sung | cancel A pending exchange → login B chồng lấn | Kết quả cuối đúng B sau cleanup hợp lệ; không cleanup muộn signOut B |
| F01/F02 bổ sung | write/clear/retryCleanup A pending → intent/callback B | Marker B không bị A ghi đè/xóa; slot B không bị finally A giải phóng |
| R5 / F04 | cleanup A fail → login B | Không báo login success hoặc publish account B; retry còn khả dụng |
| R9 / F04 | cancel với clear/signOut fail | Không idle giả; state/UI cleanupRequired hoặc trạng thái lỗi tương đương có retry |
| R10 / F04 | Như R5 với lifecycle + SQLite fixture thật | Không cấp account handle B trước cleanup success; control success cấp đúng B |

Bao phủ storage `remove=false`, exception và signOut failure. Assert state, marker, SDK session/user, lifecycle handle, UI và trace cleanup-before-login; không chỉ assert boolean login. Dùng SDK thật đã cài qua fake HTTP, UUID/JWT synthetic có exp hợp lệ, SQLite temp. Không dùng delay để hy vọng đúng thứ tự; có positive controls chứng minh fixture cấp phiên thành công khi hợp lệ.

Ghi RED actual assertion/command/exit. Nếu ca đã PASS ở source hiện tại, ghi already-pass cùng evidence, không cố tạo RED giả. Bộ probe R1 có cả R2/R6/R7 thuộc C4; **không yêu cầu toàn bộ 13 probe GREEN để đóng riêng C3**, phải tách kết quả theo scope và giữ nguyên assertions.

### Bước 2 — Sửa cùng một quy tắc ownership

- Claim/invalidate ownership đồng bộ trước await đầu tiên, bao initialization/bootstrap, requestEmail trước dispatch, callback, marker read/write/clear và SDK mutation.
- Kiểm lại owner/generation sau await và trước publish; serialize marker mutation để write/clear A không phá marker B. Chỉ thao tác hủy/giải phóng slot nếu slot đó vẫn thuộc operation A.
- Cancel thu hồi quyền ngay; SDK exchange đã dispatch vẫn có side effect, nên phải chờ/drain đúng queue rồi dọn session thuộc owner cũ. Không chỉ chặn UI result.
- Cancel, retryCleanup và success cleanup dùng ordering tương thích với credential queue/account transitions; tránh invalidator gọi ngược enqueue rồi tự chờ gây deadlock. Không signOut session mới vì cleanup cũ.
- Normal login/account grant phải await cleanup có kết quả; fail thì không tiếp tục dispatch/publish account mới. Lỗi giữ retry thật và Guest vẫn hoạt động, không dùng catch rỗng để mở quyền.
- Giữ local account lifecycle/data isolation, auth invalidation, saved trips, draft và input reset của C1/C2. Không xóa dữ liệu để xử lý race.

### Bước 3 — Kiểm thử và bàn giao

Chạy các file chứa regression trước, rồi toàn bộ auth/recovery bị ảnh hưởng và Full:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_authority_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_callback_race_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_cleanup_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/password_recovery_gate_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/auth_navigation_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Full gồm analyzer, Flutter suite và Node contracts; baseline C2 trước C3 là 1001 Flutter/91 Node PASS, không dùng lại số này như kết quả source C3. Chạy thêm các file auth/recovery khác nếu diff ảnh hưởng, ghi chính xác command/count/exit/log. Nếu có app runtime kết nối thì reload/restart phù hợp bằng tooling đang có và ghi kết quả; không tự install/clear/restart thiết bị của owner để tạo evidence. Không có runtime phù hợp thì ghi NOT RUN, không thay bằng widget test.

Giữ guard tối đa ba vòng sửa lỗi đang hiệu lực, ghi các vòng đã dùng; không tự reset budget khi lỗi lặp. Không giới hạn số file/tool calls cũ. Không stage/commit/push/merge, không deploy/SQL/email/live AI, không đọc/log token hoặc mật khẩu thật. Không đổi thiết bị/bản nháp owner.

Tạo `docs/phase-3/COURSEWORK_C3_ANTIGRAVITY_REPORT_20261025.md` theo **Changed / Why / Testing / Problems / Lesson Candidate**, có:

- Actual branch/base HEAD và diff/source hashes cuối; file sửa và lý do.
- Bảng F01/F02/F04 ↔ R1/R3/R4/R5/R8/R9/R10 ↔ test/barrier ↔ RED/GREEN/exit/log; các ca A→B bổ sung và controls.
- Luồng trước/sau bằng ví dụ hủy A → login B, giải thích vì sao chặn result không đủ dọn SDK session và vì sao cleanup lỗi phải chặn account grant.
- C4 findings vẫn OPEN/deferred; device/live NOT RUN đúng thực tế. Không claim toàn recovery hoặc toàn app đã hoàn thiện.

**Dừng sau báo cáo C3 candidate để Codex independent review. Không tự chuyển C4.**
