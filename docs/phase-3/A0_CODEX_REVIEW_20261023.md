# A0 — Codex review: NEEDS CHANGES

Ngày 23/10/2026, Asia/Saigon. Codex review, Antigravity implement/fix. Reviewed commit `02db19e7dd9005f441e541c45630abb20be0807a`, branch `codex/phase-3-discovery-design`; HEAD khớp commit này khi bắt đầu review. Commit chỉ thêm `tool/verify-flutter-admin.ps1` và `docs/phase-3/FLUTTER_ADMIN_ACCEPTANCE_20261023.md`. Các owner-dirty files ngoài scope được giữ nguyên; Codex không sửa implementation.

**Kết luận:** A0 chưa đủ điều kiện nghiệm thu vì harness có thể báo PASS khi không có kết quả kiểm tra hợp lệ. Các kết quả baseline tốt có bằng chứng, nhưng không thay thế kiểm tra negative paths của chính harness. Chưa chuyển A1.

## Findings cần Antigravity sửa

### F1 — [P1] Unknown SQL exit code bị đổi thành thành công

Location: `tool/verify-flutter-admin.ps1:84`.

`$code = if ($null -ne $p.ExitCode) { $p.ExitCode } else { 0 }` biến trạng thái chưa đọc được mã thoát thành exit 0. Kiểm tra chuỗi `ERROR:` không thay được việc xác định process thành công: process có thể chết mà không xuất đúng marker hoặc chưa hoàn tất.

Evidence reviewer-run:

- Chạy SelfTest thật ngoài sandbox loopback: exit tổng 0; SQL division-by-zero bị bắt với thông báo **`SQL failed ... (exit 0): ... ERROR: division by zero`**. Chính harness đang mô tả một lỗi SQL là exit 0.
- Fault control lấy nguyên function `Invoke-Sql` từ AST file được review, không sửa file: fake process có ExitCode=null và WaitForExit=false, không khởi chạy psql. Gọi `SELECT 1/0;` vẫn in **`PASS: review-timeout-with-no-completion`** và trả bình thường. Evidence root `.dart_tool/review-a0/6366d0e4c49f4679885656085325f81e/`.

Expected: thu exit code thật; null/unavailable/timed-out là lỗi, không suy 0. Regression phải chứng minh SQL child exit nonzero không marker vẫn fail, unavailable exit không thành PASS, normal success vẫn exit 0. Giữ `ON_ERROR_STOP=1`.

### F2 — [P1] SelfTest chấp nhận mọi exception thay cho deliberate failure

Locations: `tool/verify-flutter-admin.ps1:186-188` và nhánh SQL tương tự `203-205`.

Catch không kiểm tra nguồn lỗi, mã thoát hoặc sentinel nên executable không tồn tại, lỗi khởi chạy, lỗi log hay lỗi kết nối cũng được tính là deliberate assertion failure. SelfTest có thể “xác minh” fail propagation trong khi test body chưa chạy.

Reproduction: chạy nguyên script với runtime resolver được inject cho `node` trỏ tới file không tồn tại; PostgreSQL path không tồn tại để tránh phát sinh DB trong negative control. Output:

```text
PASS: Node deliberate failure propagated nonzero and was caught: The term '...review-a0-missing-node.exe' is not recognized ...
SKIP: Local PostgreSQL binary not found for SQL SelfTest; recorded as NOT RUN.
=== SelfTest Complete: All assertions verified ===
```

Process exit 0. Không thay node installation, PATH toàn máy hay source của Antigravity; wrapper function chỉ ở scope process review.

Expected: first prove executable launches and success control succeeds; deliberate Node failure phải có expected assertion marker và actual nonzero child exit. SQL failure phải đúng expected SQL error và actual nonzero exit. Launch/permission/logging/connection errors fail hoặc BLOCKED, không PASS. Positive fake exit0 và missing-binary controls phải làm SelfTest thất bại.

### F3 — [P1] Thiếu PostgreSQL làm skip required SQL nhưng mode vẫn xanh

Locations: `tool/verify-flutter-admin.ps1:278` và `347`, tổng kết `418`.

Account/Draft chỉ vào nhánh SQL khi có binaries, không có else ghi thiếu required runtime và trả nonzero. Vì vậy Draft có thể chạy Node rồi bỏ hoàn toàn database integrity tests mà vẫn thoát thành công.

Reproduction thật:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tool/verify-flutter-admin.ps1 -Mode Draft -PostgresBin D:/Travel-Go-Android/travel-go/.dart_tool/review-a0-missing-postgres -FlutterRoot D:/flutter/flutter
```

Observed: Node 26 PASS; không có synthetic auth/migration/SQL suite; **`All executed checks PASS`**, exit 0. Log `.dart_tool/travelgo-admin-verification/20261023T060443226Z-30128/draft-node-tests.log`.

Expected: missing required psql/pg_ctl/initdb phải báo BLOCKED/NOT RUN và nonzero trước khi chạy các bước mode còn lại, hoặc structured incomplete result mà caller không thể coi PASS. SelfTest thiếu SQL runtime cũng không được kết luận all assertions verified. Publication đang chưa có suites có thể ghi pending rõ ràng trong A0, nhưng không được dùng exit0 của một mode không chạy gì làm nghiệm thu publication; sau P1 cần đúng suite inventory trong plan.

### F4 — [P2] SQL timeout bị bỏ qua, sau đó chờ vô hạn

Location: `tool/verify-flutter-admin.ps1:82-83`.

Kết quả `WaitForExit(30000)` bị bỏ, sau đó gọi `WaitForExit()` không timeout. SQL bị lock/hang vượt 30s sẽ tiếp tục treo harness, không fail hoặc cleanup. Fault control F1 ghi nhận call sequence **`["30000","unbounded"]`** sau khi timed wait trả false; không dùng SQL dài để làm treo máy owner.

Expected: timed wait false phải throw timeout, dừng đúng child query đã tạo, và đưa cleanup PostgreSQL vào finally; không tiếp tục chờ vô hạn hoặc tạo PASS. Regression dùng synthetic stalled child/controlled process và outer deadline ngắn, không cần đợi thật 30 giây cho mỗi test. Bổ sung cleanup startup-failure coverage vì pgStarted hiện chỉ true sau readiness và các normal stop paths không kiểm exit trước khi gỡ flag.

## Verification đã thực hiện

| Kiểm tra | Ai/kết quả | Giới hạn |
|---|---|---|
| Commit scope và source hash | Codex xác nhận 2 files đúng scope, harness SHA `2054B2975E7386F65BAF84585F7708F9FC7265F4767200D960CA65FFF1A1F157` | Không coi toàn dirty tree là work A0 |
| Full baseline log | Codex đọc log author: analyzer clean, Flutter 854 PASS, Node 89 PASS | Không chạy lại full; là author-run evidence tại source/working tree của lượt đó |
| Targeted historical log | Codex đọc 20 PASS | Không chứng minh root cause của failure cũ |
| Draft, binaries có thật | Codex rerun ngoài sandbox: Node 26 PASS, migrations + admin_discovery.sql PASS, exit 0 | SQL synthetic local, không live Supabase |
| SelfTest, binaries có thật | Codex rerun: exit 0, deliberate SQL error hiện `(exit 0)` | Positive path không đóng F1/F2 |
| Missing Postgres | Codex rerun: exit 0 và không SQL, F3 reproduced | Không sửa/xóa binary thật |
| Missing Node + unavailable SQL | Codex isolated runtime injection: SelfTest vẫn all-verified/exit0, F2 reproduced | Không thay runtime/config toàn máy |
| Missing exit/timeout process | Codex AST function + process double: PASS không process, F1/F4 reproduced | Fault injection, không phải thật sự treo SQL |

Fresh successful Draft log `.dart_tool/travelgo-admin-verification/20261023T060857149Z-31192/draft-node-tests.log`; SQL run directory generated under `.dart_tool/admin-postgres-draft/`. Fresh successful SelfTest SQL evidence `.dart_tool/admin-postgres-selftest/17012cfacfdb4c8989862823b623e105/sql-verification.log`.

Một SelfTest ban đầu trong sandbox thất bại vì sandbox chặn psql loopback (10013), không coi đây là lỗi feature. Xác minh process PostgreSQL review PID34068 đã không còn sau đó; giữ diagnostic folder, không dọn owner files/processes. Rerun được duyệt ngoài sandbox dùng cluster riêng; pidfile của SelfTest thành công đã được dọn. Không có deployment/native/emulator/real-account action.

## Ghi chú sửa báo cáo bàn giao

- Pasted handover quy hai failure cũ cho máy bận/concurrency, nhưng ledger lịch sử ghi đã fail cả isolated và chưa biết nguyên nhân. Kết luận hợp lệ hiện tại là **“không tái hiện trong fresh Full/Targeted run”**; chưa kết luận root cause nếu chưa có phép thử kiểm soát.
- Handover ghi ledger SHA `22DB55...`, actual file review là **`A07E2C3870F1B94CDF5932419F2166CEFBBBAF96A6F26170797E8F1AF9EF418A`**, kể cả normalized LF. Khi sửa xong lấy lại hash cuối, phân biệt với hash trước lần edit báo cáo.
- Ledger câu “tuyệt đối không ... chuyển lỗi thành PASS” tại line29 chưa được evidence hỗ trợ; cập nhật sau khi negative controls của F1–F4 đạt.

## Prompt sửa A0 cho Antigravity

```text
Codex review Task A0 tại commit 02db19e7dd9005f441e541c45630abb20be0807a: NEEDS CHANGES. Đọc docs/phase-3/A0_CODEX_REVIEW_20261023.md.

Sửa F1–F4 trong đúng allowlist A0: tool/verify-flutter-admin.ps1 và docs/phase-3/FLUTTER_ADMIN_ACCEPTANCE_20261023.md. Không sửa source sản phẩm, SQL migrations/tests hiện có, không chuyển A1 hoặc deploy. Codex chỉ review; Antigravity sửa implementation.

Ghim negative controls cho missing runtime, unavailable/null exit code, child nonzero không ERROR marker, wrong failure marker và controlled timeout/cleanup. Có thể triển khai các self-check này trong harness để giữ allowlist; không tạo file test thứ ba nếu chưa được giao. Chứng minh controls fail trước sửa và PASS sau sửa, với positive success controls để không biến harness thành luôn-fail. Không bắt mọi exception rồi gọi đó là deliberate failure. Missing required SQL tools phải BLOCKED/nonzero và không all-verified.

Giữ fake-data disposable database và ON_ERROR_STOP=1. Cleanup chỉ đúng process/data directory của harness, kiểm ownership/path; timeout không chờ vô hạn. Không đổi process-global PATH/cài runtime hoặc đụng Supabase/thiết bị. Giữ mọi owner-dirty files.

Chạy lại SelfTest, Account/Draft/DryRun theo môi trường thực; ghi code/log cụ thể cho từng negative control. Full Flutter/Node baseline không cần chạy lặp vì chỉ sửa harness nếu không có thay đổi hoặc concern mới yêu cầu; dùng evidence cũ đúng nhãn author-run. Ghi actual repair rounds trong budget còn lại, không tự reset; trần calls đã được owner bỏ, không xin thêm calls.

Cập nhật ledger/handover trung thực: 2 historical failures hiện không tái hiện, chưa chứng minh concurrency; hash tính sau edit cuối. Dừng sau packet sửa và bàn giao exact commit/diff/hashes cùng Changed/Why/Testing/Problems/Lesson Candidate cho owner để Codex review lại, chưa chuyển task.
```

## Handover của reviewer

- **Changed:** Codex chỉ thêm review report này; chưa sửa harness hoặc ledger author.
- **Why:** A0 là nền chứng minh các task sau đúng; một runner báo xanh khi tool/test chưa chạy sẽ khiến các ràng buộc toàn vẹn không được kiểm chứng dù dashboard test PASS.
- **Testing:** positive Draft/SelfTest và negative controls trên source hiện tại như bảng; Full/Targeted counts là log author đã đối chiếu, không nhận là reviewer rerun.
- **Problems:** F1–F4 còn mở, A0 NEEDS CHANGES; CLI readiness cho A1 và acceptance các phần còn lại vẫn tách riêng.
- **Lesson Candidate:** bắt được exception không đồng nghĩa đã chạy đúng negative test; PASS đòi chứng minh executable chạy, test body đạt đúng failure và actual child exit được thu đầy đủ.
