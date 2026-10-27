# C4 — Codex review bổ sung, 25/10/2026

> **Cập nhật sau owner duyệt sửa:** [Review R2](C4_CODEX_REVIEW_R2_20261025.md) đóng C4-F01 ở mức source/automated và self-review; Full1088/91, probes gốc5/5, permanent regression8/8 PASS. Phần dưới giữ nguyên evidence R1 trước sửa, không phải trạng thái mở hiện tại.

**Kết luận: REQUEST CHANGES — một finding P2 đã tái hiện và xác nhận bằng production store.** Fresh Full vẫn PASS: analyzer sạch, Flutter1080/1080, Node91/91. Bộ tests hiện có thiếu tổ hợp GET lỗi mạng rồi ghi ready marker thất bại. C4 chưa đạt review acceptance cho đến khi xử lý finding này; không phủ nhận bằng chứng source/automated đã chạy trước đó.

Owner yêu cầu “tôi muốn bạn review luôn”. Codex review lại source mình đã implement, không gọi đây là review độc lập của agent khác. Không dùng Superpowers hoặc subagent. Lượt này không sửa app, native, dependency hoặc database; chỉ thêm probes vào thư mục ignored và ghi tài liệu.

## 1. Changed — phạm vi review và định danh source

Repo `D:/Travel-Go-Android/travel-go`, branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1/C2/C3/C4. Candidate review khớp **378/378 files** của `.dart_tool/c4-codex-implementation/final-source-snapshot.json`, trước/sau review0 drift. Không thay permanent source/test files.

Đọc diff C4 theo task-start backups, provider/service/store/model/gate/reset UI và các fixtures OTP/profile/C3. Điểm kiểm chính: quyền submit trước await, TTL/session/owner sau chờ I/O, server preflight trong credential queue, lỗi trước dispatch khác PUT uncertain, persistence/cleanup và retry.

Source chính `lib/features/auth/providers/password_recovery_provider.dart` SHA256 `4acb41d598231a1c4575b543ef165f779e38c0ad174e01d3e16a36db71bd95a8`; các hashes khác giữ nguyên trong snapshot và [bàn giao C4](COURSEWORK_C4_CODEX_IMPLEMENTATION_20261025.md).

### C4-F01 [P2] Retry bị khóa khi GET thất bại rồi ghi khôi phục ready cũng thất bại

**Vị trí:** `lib/features/auth/providers/password_recovery_provider.dart:251–264`, đặc biệt catch tại256–259 và state assignment tại262. Lần submit sau bị chặn tại663–667.

**Trigger / luồng thực tế:**

1. Yêu cầu recovery hợp lệ, form ready; người dùng bấm cập nhật mật khẩu.
2. Ghi marker updating thành công và `_currentIntent` chuyển sang updating.
3. GET xác minh server lỗi mạng; **chưa có PUT đổi mật khẩu**.
4. `_rejectPreflight` thử ghi lại marker ready để cho retry; thao tác ghi local thất bại.
5. Catch chỉ kiểm ownership rồi bỏ qua lỗi. `_currentIntent` trong RAM vẫn updating, nhưng `_state` được đặt ready và UI cho bấm lại.
6. Mạng và lưu local đã phục hồi; bấm lại vẫn trả false ngay vì intent.phase!=ready. Không có GET/PUT mới. UI chuyển sang lỗi phiên thay vì thử lại xác minh, có thể làm form đang nhập bị tháo.

**Expected:** khi biết chắc PUT chưa dispatch, trạng thái retry trong RAM và UI phải nhất quán. Sau khi lỗi lưu/mạng hết, lần thử lại phải ghi write-ahead và xác minh server rồi mới PUT1. Nếu chưa thể retry, UI phải nêu đúng lỗi lưu/đường phục hồi, không tự thông báo ready rồi từ chối ở lần bấm kế tiếp.

**Actual đã đo:** submit đầu=false, PUT0, state=ready nhưng RAM phase=updating; submit sau=false dù cả hai lỗi đã tắt. Probe expectedtrue actualfalse. Đây là lỗi phục hồi luồng, không phải bằng chứng password đã bị đổi hoặc quyền server bị vượt.

**Xác nhận:** lần đầu dùng `ReviewStore` gây lỗi ghi ready có kiểm soát. Lần thứ hai dùng nguyên **RecoveryIntentStore production**, SharedPreferences thật của package trên platform fixture trảfalse riêng lần ghi ready. Cả hai đều tái hiện. Production `write` biến setString=false thành StateError; không phụ thuộc subclass store tự bịa hành vi. SharedPreferences có cache riêng nhưng provider ưu tiên `_currentIntent` updating nên cache không cứu được retry.

**Đề xuất, chưa sửa:** bảo đảm phase trong RAM/đường retry nhất quán kể cả khi ghi ready thất bại; vẫn buộc ghi updating thành công và kiểm TTL/authority/server trước PUT tiếp theo. Không đổi trường hợp đã gửi PUT/mất ACK thành retryable, không bỏ write-ahead hoặc gán completed. Thêm regression permanent cho tổ hợp hai lỗi và giữ controls lỗi riêng.

## 2. Why — vì sao Full PASS vẫn có finding

Các tests hiện có chứng minh lỗi ghi write-ahead **trước dispatch** có thể thử lại; GET lỗi mạng **khi ghi restore thành công** cũng có thể thử lại. Hai nhánh đều PASS riêng. Chúng chưa ghép GET lỗi với ready-restore write lỗi, nên không phát hiện mâu thuẫn giữa state hiển thị và phase của intent.

Đường đúng cần thống nhất ba thứ: quyền mutation, ý định đang giữ trong RAM và marker lưu local. “Chưa PUT” cho phép chuẩn bị lại để thử, nhưng không cho bỏ qua bước lưu/xác minh kế tiếp. “PUT đã đi nhưng chưa rõ kết quả” vẫn phải giữ uncertain như trước.

Các bảo vệ duplicate, TTL/queue, cold validation, cancel/Guest/login B, OTP lifecycle và profile vẫn đạt các ca permanent đã chạy; không mở lại findings cũ chỉ vì đổi nhãn giai đoạn. Finding mới chỉ nằm ở nhánh restore failure được thêm trong C4.

## 3. Testing — reviewer-run

**Fresh Full exit0**, log `.dart_tool/c4-codex-review/full.log`; suite logs `.dart_tool/travelgo-verification/20261025T154132749Z-31740/`:

- Analyzer: **No issues found,3.9s**.
- Flutter: **1080/1080 PASS,1:56**.
- Node: **91/91 PASS,fail0/skipped0**,249ms.

**Adversarial probes cuối:** `.dart_tool/c4-codex-review/probes-all-final.log`: **3 PASS /2 FAIL**, exit1, cả5 ca chạy trong một invocation trên probe source cuối. Hai FAIL là hai cách tái hiện cùng C4-F01, gồm subclass store và production-store confirmation. Ba controls gồm GET outage riêng retry PUT1, lỗi write-ahead riêng retry PUT1, callback expired sau GET outage không mở form/không PUT. Lượt trước chưa bổ sung confirmation, `probes-final.log`, đạt3 PASS/1 FAIL cùng finding.

**Production-store confirmation:** `.dart_tool/c4-codex-review/production-store-confirmation.log`: **1 FAIL**, exit1, cùng C4-F01. Không tính thành finding thứ hai. `.dart_tool/c4-codex-review/probes-1.log` là tái hiện đầu tiên cùng lỗi.

Probe source cuối `.dart_tool/c4-codex-review/review_probe_test.dart` SHA256 `260f28e76184d12740a2c4b4250b6f0c3fb1853c0c704878687e8c5c48aafef0`; dùng fixtures synthetic của suite C4 cộng failure injection, không có credentials/dữ liệu thật. Chạy filter REVIEW để tách controls mới khỏi33 tests gốc.

```powershell
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --reporter=expanded --timeout=15s .dart_tool/c4-codex-review/review_probe_test.dart --plain-name REVIEW
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' test --no-pub --reporter=expanded --timeout=15s .dart_tool/c4-codex-review/review_probe_test.dart --plain-name 'REVIEW production store'
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Lượt probes-final được chạy trước khi bổ sung production confirmation; sau đó probes-all-final đã kiểm cả5 ca trên cùng file cuối có hash nêu trên. Candidate app không đổi trong mọi invocation. Diffcheck exit0.

## 4. Problems / bước tiếp theo

- **C4-F01 OPEN**; sửa trong phạm vi retry/error handling của C4, bổ sung test permanent rồi targeted/Full trên candidate mới. Không tự sửa app trong lượt review này hoặc reset repair guard từ tên báo cáo mới.
- C4 đạt bộ kiểm thử sẵn có nhưng **chưa đạt review acceptance**. Chưa bắt đầu C5. Sáu findings CORE_REVIEW_R1 trước đó vẫn có evidence riêng; không dùng finding này để nói các ca đã đóng đều hỏng.
- Runtime/email/native/device **NOT RUN**; không build/install/hot reload, gửi email, đổi mật khẩu thật, SQL/deploy/commit/push/merge. Không có PR mới, không thay trạng thái GitHub.
- Đây vẫn là review bổ sung của Codex trên code Codex đã viết; không gắn nhãn cross-agent independent review. Giữ dirty work của owner và source378 files nguyên trạng.

## 5. Lesson Candidate

Problem → Root Cause → Actionable Rule: “UI nói có thể thử lại nhưng lần sau bị chặn” → “xử lý lỗi persistence chỉ đổi state hiển thị, không đồng bộ phase intent trong RAM” → “kiểm invariant state/phase/authority sau lỗi; test cả tổ hợp hai lỗi liên tiếp, không chỉ mỗi lỗi độc lập”.
