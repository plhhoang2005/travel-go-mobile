# C4-F01 — Codex sửa và kiểm tra lại, 25/10/2026

Owner duyệt “tiến hành sửa c4 sau đó review”. Scope: đúng [C4-F01 trong review R1](C4_CODEX_REVIEW_20261025.md), giữ C3/C4 đã đạt; không mở C5, không thay permanent workflow, không dùng Superpowers hoặc subagent cho Codex.

**Kết quả: C4-F01 CLOSED — source/automated và self-review PASS.** Full cuối analyzer sạch, Flutter1088/1088, Node91/91, exit0; focused8/8 và nguyên probes review gốc5/5 PASS trên bytes cuối. Snapshot379 files không drift. Targeted C3/C4 trước hai braces cuối ở fixture đạt228/228. [Review hậu sửa R2](C4_CODEX_REVIEW_R2_20261025.md) không phát hiện finding mới trong phạm vi sửa; chưa independent/native/live acceptance.

## 1. Changed

Branch `fix/ai-planning-stability`, base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty owner work. Trước sửa, candidate review378 files khớp snapshot C4,0 drift. Chỉ **1 source file hiện có và1 test file mới** thay đổi so candidate đó:

| File | Thay đổi |
| --- | --- |
| `lib/features/auth/providers/password_recovery_provider.dart` | Đưa việc giữ phase ready trong RAM ra sau try/catch ghi restore; kiểm ownership/generation/auth authority trước gán, áp dụng cả nhánh ghi thành công lẫn thất bại |
| `test/password_recovery_retry_persistence_test.dart` (mới) | Tám tests bằng RecoveryIntentStore production + SharedPreferences platform fixture: false/throw, lỗi write-ahead tiếp diễn, TTL, cancel, successor, cold reload và UI giữ input |

Không đổi store, service/SDK API, AuthProvider, UI production, TTL/schema, dependency/native/backend/DB. Task-start backup và status tại `.dart_tool/c4-f01-codex-fix/before/`, `status-before.txt`; patch source riêng tại `provider-fix.patch`. Không reset/stash/clean/stage/commit/push/merge.

## 2. Why — trước/sau và trách nhiệm của các lớp

Trước sửa: ghi updating thành công → GET lỗi mạng → ghi restore-ready thất bại → provider hiển thị ready nhưng intent RAM vẫn updating → lần thử sau bị từ chối vì phase sai. PUT chưa được gửi nhưng người dùng không thể thử tiếp đúng luồng.

Sau sửa: vì đã biết GET thất bại **trước khi có PUT**, provider giữ ý định ready trong RAM kể cả khi ghi khôi phục marker lỗi. Chỉ phục hồi cho đúng intent/generation còn authority; Hủy hoặc successor đã thay thế thì continuation cũ không được gán lại intent. Người dùng bấm lại vẫn phải ghi updating thành công → GET server mới → kiểm TTL/session/owner → PUT. Không bỏ write-ahead hoặc cấp quyền gửi khi lưu local còn lỗi.

RAM và lưu bền có trách nhiệm khác nhau. Nếu app bị đóng trước khi ghi tiếp thành công, marker thực sự trên storage vẫn có thể là updating. Khi mở lại app, cơ chế uncertain hiện có vẫn chặn tự gửi lại; sửa này không diễn giải một marker updating từ lần chạy trước thành “chắc chắn chưa PUT”. Tests kiểm dữ liệu platform lưu thực tế và reload cache SharedPreferences để phân biệt điều này với RAM provider.

UI production không cần thay: state và phase đã nhất quán nên form tiếp tục được giữ; widget test xác nhận password input còn nguyên qua lỗi kết hợp và lần bấm tiếp có thể hoàn tất khi lỗi hết.

## 3. Testing — evidence và phân biệt candidate

**RED trước source fix:** `.dart_tool/c4-f01-codex-fix/red.log`,2 PASS/6 FAIL. Năm failures đo lỗi C4-F01: false/throw, retry khi lưu còn lỗi, TTL cleanup sau lỗi và phase/input trong UI. Failure thứ sáu ở successor do fixture mới thiếu PKCE async storage, không phải finding sản phẩm; đã cấp MockAsyncStorage như các fixture auth hiện có, không sửa production auth để chữa fixture.

**GREEN8/8**, `green-final.log`, exit0. Tám ca:

1. GET lỗi mạng + ready-restore trảfalse → RAM ready → khi lỗi hết có GET mới/PUT1.
2. Như trên nhưng platform write ném lỗi → cùng kết quả.
3. Nếu write-ahead lần thử tiếp vẫn lỗi → GET/PUT không được dispatch; lỗi hết mới thử lại thành công.
4. Hết TTL trước retry → PUT0, dọn SDK session, không ready.
5. Hủy trong lúc restore-write chờ → không hồi sinh ready, SDK được dọn.
6. Successor được tạo trong lúc restore chờ → giữ intent/marker successor, PUT0.
7. Reload dữ liệu updating thực sự từ platform → uncertain, không tự PUT.
8. UI lỗi GET+storage → form/input được giữ; sau phục hồi chỉ PUT1 và quay lại luồng đăng nhập.

**Targeted228/228 PASS**, exit0,23s, `targeted-owner-final.log`,14 suites C3/C4/OTP/profile/navigation. Sau lượt này chỉ thêm braces ở hai if trong fixture test; không đổi logic. Full cuối và focused kiểm tra sau lint là evidence cho bytes cuối, không dùng một targeted cũ thay cho source mới.

**Focused sau lint8/8 PASS**, exit0, `focused-verified.log`; **review probes cũ5/5 PASS**, `review-verified.log`, exit0, đều chạy trên bytes cuối sau Full. File `.dart_tool/c4-codex-review/review_probe_test.dart` giữ SHA256 `260f28e76184d12740a2c4b4250b6f0c3fb1853c0c704878687e8c5c48aafef0`, không chỉnh assertions hoặc sequencing để lấy PASS. Gồm cả hai cách tái hiện C4-F01 và ba positive/negative controls đã chạy ở review R1. Các lượt review-owner-final/original-review-probes trước đó cũng đạt5/5 nhưng không thay kết quả cuối.

**Full cuối exit0**, đã thu completion process: `.dart_tool/c4-f01-codex-fix/full-verified.log`; suite logs `.dart_tool/travelgo-verification/20261025T160726060Z-18796/`. Analyzer **No issues found,3.8s**; Flutter **1088/1088 PASS,2:01**; Node **91/91 PASS,fail0/skipped0**,259ms. Snapshot379 files trước Full và sau focused/review không đổi, diffcheck exit0.

Các lượt `full-final.log` và `full-owner-final.log` dừng ở analyzer vì4 rồi2 lint cơ học: braces trong provider/fixture và super parameter. Đã xử lý, không tắt lint/analyzer hoặc thay assertion. Không gọi các lượt đó là Full PASS; Flutter/Node chưa chạy ở các lượt bị chặn.

```powershell
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --reporter=expanded --timeout=20s test/password_recovery_retry_persistence_test.dart
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --reporter=expanded --timeout=15s .dart_tool/c4-codex-review/review_probe_test.dart --plain-name REVIEW
git diff --check
```

Snapshot cuối379 files `.dart_tool/c4-f01-codex-fix/final-source-snapshot.json`. Hashes:

| File | SHA256 |
| --- | --- |
| password_recovery_provider.dart | `6a160b28b0ecfb45fdcc18ef65db1392c84111e3444d8ee7306e44b32bb56b28` |
| password_recovery_retry_persistence_test.dart | `3d0e9dff2296006e36b6f1e788053823b531aad2c7802cfe56d6f024f7f88234` |

## 4. Problems / review và giới hạn

Đây là sửa và self-review của Codex theo yêu cầu owner, không gọi independent cross-agent review. Không phát triển lại C3/C4 hoặc reset repair guard bằng tên báo cáo mới; một correction hành vi C4-F01, fixture PKCE và lint được ghi riêng.

Chưa nghiệm thu email/OTP/link khôi phục trên thiết bị hoặc đổi mật khẩu tài khoản thật. Không gửi email/live request, SQL/deploy, build/install/hot reload hoặc thao tác draft/thiết bị. Quyền code không được dùng để bypass việc hot reload từng bị automatic approval review từ chối ở C3 vì thiếu app/DTD và quyền runtime cụ thể.

C4-F01 đã đóng bằng Full và review trên bytes cuối; không còn finding mở trong scope correction này. Chưa bắt đầu C5, chưa commit/push/merge; giữ dirty work của owner. Review độc lập và nghiệm thu email/thiết bị vẫn chưa thực hiện.

## 5. Lesson Candidate

Problem → Root Cause → Rule: “UI cho thử lại nhưng RAM phase vẫn cấm retry” → “gắn việc cập nhật ý định RAM với thành công persistence, dù đã biết chưa có server mutation” → “phân biệt RAM phục vụ retry hiện tại và marker phục vụ crash recovery; trước mỗi dispatch vẫn phải giữ write-ahead, authority và validation”.
