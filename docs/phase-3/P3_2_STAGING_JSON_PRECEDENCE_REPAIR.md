# T6–T7 — Gói sửa lỗi JSON precedence sau native SQL FAIL

2026-10-16, Asia/Saigon. **SOURCE PREPARED; NOT APPLIED.**
Staging gốc đã apply; native TLS connection thành công, SQL positive suite FAIL.
Primary ngoài scope. Không reset/drop/sửa dữ liệu chuyến đi hoặc apply lại file gốc.

## Changed

CLI 2.81.3 tạo file đúng path trả về:
`D:/Travel-Go-Android/travel-go/supabase/migrations/20261016045559_editable_trip_v2_json_precedence_fix.sql`.

**SHA-256:** `eeb9123e80961887193fdd0c528696615f252ac97c9957730c8dff03736da1a6`.

Migration mới chỉ CREATE OR REPLACE **hai hàm private** `p32_validate(text,boolean)`
và `p32_replay(jsonb,jsonb)`: thêm ngoặc tại **5 vị trí toán hạng containment**.
Đối chiếu tự động xác nhận ngoài 5 chỗ và CREATE OR REPLACE, hai body giống nguyên
source đã apply. Không đổi RPC signatures, grants, tables, schema model hoặc B3.
File gốc và cả 8 file trong manifest đã duyệt giữ nguyên bytes/hash.

Preflight yêu cầu postgres, migration gốc có trong history, đúng definition MD5,
owner/ACL/search_path của hai hàm. Transaction giới hạn lock 5s / statement 60s.
Postcondition dùng JSON synthetic trong bộ nhớ: đảo thứ tự → tạo overlap/time_order
→ xác nhận cả hai issues → account validate → kiểm actual ledger và private ACL
không đổi, rồi mới COMMIT. Không tạo auth users/trips/expense rows trong migration.

| Function trước sửa | Definition MD5 live lúc 11:56:25 ICT |
| --- | --- |
| private.p32_validate(text,boolean) | 51256cfeb2a57bf023e90da33503bd08 |
| private.p32_replay(jsonb,jsonb) | 713fa2d3b6c0f836e19dec6b2cdf485a |

## Why — lỗi và tác động

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
- New migration DDL/postcondition và toàn bộ SQL/races sau fix **NOT RUN**.
  Không chạy lại Flutter/Pester vì không đổi client/runner; evidence 655/14 trước
  đó giữ nguyên timestamp và không được gọi là SQL PASS.

Logs tại artifact folder `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/`:
`P3_2_STAGING_CONNECTION.log`, `P3_2_STAGING_EXECUTION.log`,
`P3_2_SQL_FAILURE_PRIVATE.log`. Không chứa mật khẩu; stderr không đưa vào Git.

## Gói apply/test cần Owner duyệt

Gói trước chỉ cho apply đúng migration/hash đã duyệt. [Plan §4](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_IMPLEMENTATION_PLAN.md:653)
yêu cầu khi SQL source failure: giữ database state và review lại package.
Vì vậy bản sửa hash mới **chưa được apply**.

Đề nghị duyệt: apply duy nhất file fix/hash trên vào **staging
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
Gói sửa có postcondition thực thi cả ba nhánh bị ảnh hưởng trước khi commit DDL.
