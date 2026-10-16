# T6–T7 — Gói sửa JSON precedence và query alias R2

2026-10-16, Asia/Saigon. **R2 PREPARED; TEMP-FUNCTION REGRESSION PASS; NOT APPLIED.**
Owner đã duyệt R1 tại commit `7fdd0fe`. Apply R1 bị regression guard từ chối và
rollback hoàn toàn; R2 bên dưới có hash mới, chưa được apply.
Staging gốc đã apply; native TLS connection thành công, SQL positive suite FAIL.
Primary ngoài scope. Không reset/drop/sửa dữ liệu chuyến đi hoặc apply lại file gốc.

## Changed

CLI 2.81.3 tạo file đúng path trả về:
`D:/Travel-Go-Android/travel-go/supabase/migrations/20261016045559_editable_trip_v2_json_precedence_fix.sql`.

**SHA-256 R2:** `0e60c7dfcb93e41f78c20d3294b3f7a1d67f1d2da4247683e474ade1fdc735ae`.

Migration mới chỉ CREATE OR REPLACE **hai hàm private** `p32_validate(text,boolean)`
và `p32_replay(jsonb,jsonb)`: thêm ngoặc tại **5 vị trí toán hạng containment**,
đổi **3 query aliases** sang tên riêng và qualified column references để không
trùng biến `e`. Không đổi thuật toán, RPC signatures, grants, tables, schema model
hoặc B3. R2 bổ sung regression deleteActual thành công/lặp lại báo invalid_command.
File gốc và cả 8 file trong manifest đã duyệt giữ nguyên bytes/hash.

Preflight yêu cầu postgres, migration gốc có trong history, đúng definition MD5,
owner/ACL/search_path của hai hàm. Transaction giới hạn lock 5s / statement 60s.
Postcondition dùng JSON synthetic trong bộ nhớ: đảo thứ tự → tạo overlap/time_order
→ xác nhận cả hai issues → account validate → kiểm actual ledger → explicit
deleteActual và kiểm lần xóa lặp lại → kiểm private ACL
không đổi, rồi mới COMMIT. Không tạo auth users/trips/expense rows trong migration.

| Function trước sửa | Definition MD5 live lúc 11:56:25 ICT |
| --- | --- |
| private.p32_validate(text,boolean) | 51256cfeb2a57bf023e90da33503bd08 |
| private.p32_replay(jsonb,jsonb) | 713fa2d3b6c0f836e19dec6b2cdf485a |

## Why — lỗi và tác động

R1 đã sửa phép nhóm toán tử nhưng apply tự kiểm thêm nhánh account acknowledgment
và dừng với `column reference "e" is ambiguous`: `e` vừa là biến PL/pgSQL vừa là
alias của array elements. Regression guard đã ngăn COMMIT. R2 dùng
`exception_row.value` / `actual_row.value`, giữ chính sách mặc định phát hiện tên
mơ hồ, không đổi variable_conflict để che lỗi. Audit cả hai body còn tìm cùng
kiểu alias ở deleteActual và qualified exception filtering; đã xử lý chung.
[PostgreSQL variable substitution](https://www.postgresql.org/docs/17/plpgsql-implementation.html#PLPGSQL-VAR-SUBST)
giải thích vì sao cần tên riêng hoặc column references qualified.

Native positive suite dừng tại `editable_trip_v2.sql:184`, context `p32_replay`
PERFORM reorderDay, lỗi `operator does not exist: boolean -> unknown`.

Biểu thức `ordered @> c->'orderedItemIds'` bị PostgreSQL hiểu thành
`(ordered @> c)->'orderedItemIds'`. Kết quả so sánh là boolean nên không thể lấy
JSON field tiếp. Cùng kiểu thiếu ngoặc còn ở xác nhận issue và kiểm account save.
Đổi thành `ordered @> (c->'orderedItemIds')` và parenthesize hai phía khi cần.
[PostgreSQL operator precedence](https://www.postgresql.org/docs/17/sql-syntax-lexical.html#SQL-PRECEDENCE)
quy định nhóm toán tử này kết hợp trái; ngoặc xác định đúng toán hạng JSON.

Với Owner sửa thứ tự hai hoạt động tại Huế, lỗi này có thể chặn lưu lịch/account;
cùng root cause có thể chặn xác nhận lịch trùng giờ. Không sửa số tiền actual để
né lỗi, không bỏ validation hoặc đổi test thành chấp nhận lỗi.

## Testing và cleanup

### R1 apply đã thử, R2 chỉ kiểm bằng hàm tạm

- R1 hash `eeb9123e80961887193fdd0c528696615f252ac97c9957730c8dff03736da1a6`
  được gửi đúng theo approval `7fdd0fe`. Preflight live 12:16:20 ICT khớp baseline.
  Apply trả ERROR 42702 ở p32_validate trong regression; **không commit**.
- 12:17:53 ICT: `repair_applied=false`, hai definition MD5 vẫn đúng bảng baseline
  phía trên. Không có version repair để align; không sửa registry trên lần lỗi.
- R2 cloned hai body vào **pg_temp** với cùng private execute ACL cho test;
  dùng JSON synthetic, regression của migration và đúng block 12 commands từ SQL
  suite. Kết quả **R2_TEMP_FUNCTION_REGRESSION_AND_12_COMMANDS_PASS** trên PostgreSQL.
  Transaction ROLLBACK, không thay hai hàm private hoặc ghi account/trip rows.
- Probe adapter ban đầu thiếu mô phỏng temp ACL và helper p32_hash của suite;
  đã nạp đúng helper và revoke temp grants để kiểm cùng điều kiện. Không đổi body
  R2 hoặc nới production ACL để làm PASS.
- R2 full positive/negative/B3 suites, ownership/RPC và 12 concurrent schedules
  sau apply vẫn **NOT RUN**. Không coi pg_temp unit regression là toàn bộ nghiệm thu.

### Native run trước R1 (evidence lịch sử)

- Cấu hình Owner đã nhận; native **psql 18.6 → postgres|postgres|t**, host staging
  pinned và `sslmode=verify-full`, CA từ file Owner. Không đọc/in mật khẩu.
- Lần probe đầu lỗi local `service file "" not found`; sửa môi trường process con
  bằng Environment.Remove. Runner vốn đã làm đúng bước này, không đổi source runner.
- `-ExecuteStaging`: **FAIL** tại positive suite, run
  `bc72e969fb5941698af4a8520a53fbf4`; chưa tới negative/B3 suites hoặc 12 races.
- Chạy lại đúng positive fixture trong transaction để lấy context lỗi: psql exit 3,
  cùng lỗi. Không thử apply bản sửa lên staging.
- Kiểm read-only staging 11:56:25 ICT: **0 @p32-sql.invalid users**, **0
  @p32-concurrency.invalid users**. Failed transaction rollback; runner chưa vào
  bước tạo concurrency fixtures. Không có bulk cleanup hoặc xóa account thật.
- Hai biểu thức sửa reorder/ack kiểm bằng SELECT read-only trên PostgreSQL 17.11:
  **true / true**. Đây là bằng chứng root cause, chưa là full function/suite PASS.
- SelfTest **PASS**, staging dry-run **PASS** sau khi chuẩn bị fix; không kết nối DB.
- Static scope/dollar tags PASS; 8/8 original hashes unchanged. New migration có
  hai function definitions và regression transaction, không có table DML.
- R1 DDL/postcondition đã chạy và rollback khi regression lỗi. R2 permanent DDL
  chưa chạy; R2 postcondition/12-command block đã PASS trên hàm tạm như nêu trên.
  Không chạy lại Flutter/Pester vì không đổi client/runner; evidence 655/14 trước
  đó giữ nguyên timestamp và không được gọi là SQL PASS.

Logs tại artifact folder `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/`:
`P3_2_STAGING_CONNECTION.log`, `P3_2_STAGING_EXECUTION.log`,
`P3_2_SQL_FAILURE_PRIVATE.log`. Không chứa mật khẩu; stderr không đưa vào Git.

## Gói apply/test cần Owner duyệt

Approval R1 không mở rộng sang R2 có hash mới. [Plan §4](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_IMPLEMENTATION_PLAN.md:653)
yêu cầu khi SQL source failure: giữ database state và review lại package.
Vì vậy R2 hash mới **chưa được apply**; database giữ nguyên sau rollback R1.

Đề nghị duyệt R2: apply duy nhất file fix/hash trên vào **staging
bkocylxbuyvdgxccpixx**, xác minh/đồng bộ migration history với version CLI
`20261016045559` nếu MCP tạo timestamp khác, rồi chạy lại runner đã duyệt
`run-editable-trip-concurrency.ps1 -ExecuteStaging` và kiểm cleanup.
Không apply primary, không sửa grants ngoài gói, không deploy/AI.

Sau approval:

1. Verify fix hash + original manifest 8/8; private function MD5/ACL còn khớp.
2. Apply đúng SQL bằng Supabase apply_migration, name
   `editable_trip_v2_json_precedence_fix`; regression phải PASS trước COMMIT.
   Nếu transaction lỗi, giữ state và báo lỗi, không sửa nóng liên tục.
3. Verify registry stored SQL hash trước khi align đúng CLI version nếu cần;
   verify private ACL/owner/search_path, B3 definition/ACL giữ nguyên.
4. Dùng metadata local `%LOCALAPPDATA%/TravelGO/staging-db/connection.json`, đặt
   PGUSER/PGDATABASE/PGPASSFILE/PGSSLROOTCERT cho runner process, target/host pinned.
   Không tạo lại mật khẩu, không apply lại migration gốc.
5. Chạy positive/negative/B3 suites + 12 observed-lock schedules, cleanup exact
   synthetic IDs/emails, cập nhật runtime report. Chỉ SQL PASS mới nghiệm thu Account.

## Problems / Lesson Candidate

Static checks và client tests không phát hiện cách PostgreSQL parse body ở
nhánh reorder/ack → native SQL suite bắt lỗi thật → luôn kiểm các nhánh JSON
containment trên PostgreSQL và thêm ngoặc rõ toán hạng, không dựa vào thứ tự nhìn.
Gói sửa có postcondition thực thi các nhánh bị ảnh hưởng trước khi commit DDL.
SQL lỗi sâu chỉ được phân tích khi nhánh chạy → thêm regression trước COMMIT và
dùng query aliases khác tên biến; giữ guard phát hiện ambiguity thay vì bỏ qua.
