# T6–T7 staging — R2 applied, SQL và concurrency PASS

Ngày 2026-10-16. **STAGING DATABASE ACCEPTANCE PASS; ANDROID / WHOLE P3.2 PENDING.**
Owner duyệt exact R2 `1cdf6b09ad48ed6df9399445f3a95515265b8cb5` trong chat.
Target duy nhất `bkocylxbuyvdgxccpixx`; primary ngoài scope.

## Changed

- Apply thành công qua Supabase MCP `apply_migration`, name
  `editable_trip_v2_json_precedence_fix`, lúc 13:26 UTC / 20:26 ICT.
- File `supabase/migrations/20261016045559_editable_trip_v2_json_precedence_fix.sql`,
  SHA-256 `0e60c7dfcb93e41f78c20d3294b3f7a1d67f1d2da4247683e474ade1fdc735ae`.
  Original manifest 8/8 hashes MATCH trước apply; không apply lại migration gốc.
- MCP sinh version `20261016132610`. Đối chiếu registry lưu đúng một SQL string,
  đúng SHA-256 đã duyệt rồi conditional UPDATE duy nhất version thành
  `20261016045559`, khớp CLI filename. Không đổi application rows khi align.
- Chỉ hai hàm private thay body; owner postgres, ACL postgres-only, search_path rỗng.
  Definition MD5 sau apply: validate `89c8fdbb4c4b83e981d1dd8a49b7910c`;
  replay `b022f376545426724cb48633945b9dac`.
- Cập nhật bốn hồ sơ nghiệm thu; không sửa client, runner, native config hoặc grants.

## Why / luồng và sửa lỗi

Owner đổi thứ tự hoạt động tại Huế → app gửi commands và phiên bản → database
kiểm owner, replay và validate → lưu document/receipt → app nhận kết quả.
Thiếu ngoặc JSON containment từng chặn reorder/ack; alias trùng biến từng chặn
account validation/deleteActual. R2 xác định rõ toán hạng và tên cột, giữ validation.
Regression trong migration đã chạy trước COMMIT, gồm reorder/overlap/ack/account
validate/actual ledger/deleteActual thành công và lần xóa lặp bị từ chối.

Hai thiết bị sửa cùng phiên bản: chỉ một lần commit, lần còn lại version_conflict.
Retry cùng request ID trả receipt cũ, không tăng phiên bản hoặc tạo bản ghi trùng.
Xóa hoạt động giữ tiền đã chi; xóa chuyến/tài khoản không cho request muộn hồi sinh.

## Testing thực tế

- Preflight 13:26:00 UTC: đúng old private definition MD5/ACL/owner/search_path;
  repair history chưa tồn tại; B3 definitions/ACL khớp baseline.
- Apply `success:true`; 13:26:17 UTC registry stored SQL hash MATCH.
- Native PowerShell 7, psql 18.6, TLS verify-full; dùng PGPASSFILE/CA Owner đã tạo.
  Không đọc/in mật khẩu hoặc tạo lại credentials.
- Chạy `run-editable-trip-concurrency.ps1 -ProjectRef bkocylxbuyvdgxccpixx
  -ConnectionHost db.bkocylxbuyvdgxccpixx.supabase.co -ExecuteStaging`: **exit 0**.
- **4 suites PASS:** editable_trip_v2.sql, editable_trip_v2_negative_controls.sql,
  guest_import.sql và guest_import_negative_controls.sql. V2 positive kiểm đủ
  12 typed commands; negative kiểm ownership/ACL/bypass/guards và các lỗi kỳ vọng.
- **12 observed-lock schedules PASS:** same create key, same base update, same
  update key, update/read hai chiều, read/delete hai chiều, update/delete hai chiều,
  same delete key, update/account cascade và account cascade/update.
  Quan sát blocker qua PostgreSQL; các phiên psql độc lập, không suy từ thời gian chờ.
- Lost reply/recover fresh session và old receipt/newer head assertions PASS.
- Runner báo `P32 staging SQL, observed-lock races and exact synthetic cleanup PASS.`
  Chỉ cleanup UUID/email/run synthetic của runner, không bulk delete theo domain.
- Read-only postcheck 13:27:46 UTC / 20:27:46 ICT: **0 fixture users** ở hai namespace
  p32-sql/p32-concurrency; **0 temp probe functions**; **0 forbidden table grants**,
  **0 app EXECUTE trên private helpers**; **3/3 private tables RLS enabled**.
- **6/6 RPC** postgres owner, SECURITY DEFINER, search_path rỗng, authenticated
  được gọi / anon không được gọi. Hai registry versions/hashes đúng source.
- B3 postcheck 13:27:04 UTC giữ nguyên definitions, ACL, owner và search_path:
  guard `86dbec45babd7eb72937b9f8a455c65a`;
  import `8f96ede11466e66055b04b35c970d64e`;
  get snapshot `37296be3a0bfe0495195ebac85f3bea1`.
- Log: `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/P3_2_R2_STAGING_EXECUTION.log`.
- Flutter không chạy lại vì chỉ apply database/cập nhật docs. Evidence source trước
  đó: `flutter analyze --no-pub` sạch, `flutter test --no-pub --reporter expanded`
  **655 PASS**, catalogue 40 PASS, Pester14/SelfTest/dry-run PASS. Giữ timestamp cũ;
  SQL PASS ở task này đến từ PostgreSQL thực, không từ Flutter hoặc pg_temp probe.

## Problems / security review / giới hạn

Security advisor chạy 13:27:05 UTC. Không báo toàn project security CLEAN:

- Ba private V2 tables RLS/no policy: [INFO 0008](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
  deny trực tiếp có chủ đích, table grants bị revoke.
- Sáu V2 authenticated SECURITY DEFINER RPC: [WARN 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
  đúng interface đã duyệt, quyền và owner checks đã được suite thực kiểm.
- Hai hàm ngoài scope `set_profile_updated_at` / `verify_profiles_policy_drift`
  còn [WARN 0028](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable).
  Các anonymous-policy và [leaked password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
  notices cũ cũng chưa xử lý; không đổi ACL/Auth settings ngoài gói.

Chưa install/launch APK, chạy native persistence probe, TalkBack, airplane mode
hoặc Owner phone acceptance. P3.1 Owner acceptance còn PENDING; toàn P3.2 chưa xong.
Primary `oavbymauorhmrjcustzw` không query/apply; B3 primary vẫn NOT APPLIED.
Không push/PR/deploy/AI. Owner macOS dirty change và unrelated/private paths giữ nguyên.

## Lịch sử và Lesson Candidate

Original migration applied `20261016034905`; native positive từng fail JSON
precedence. R1 `7fdd0fe` apply regression fail alias ambiguity và rollback hoàn toàn.
R2 pg_temp regression/12 commands PASS trước approval, sau approval mới permanent
apply và full suites/races PASS như trên. Evidence lỗi cũ giữ trong repair packet/logs.

Lỗi SQL chỉ xuất hiện khi nhánh chạy → kiểm trên PostgreSQL thực, thêm regression
trước COMMIT, dùng ngoặc và qualified aliases → không coi analyzer/static/client
PASS là database acceptance. Apply thành công vẫn phải kiểm races và cleanup.

Tiếp theo: Owner test P3.2 trên điện thoại staging theo acceptance report, gồm Guest
và Account; SQL prerequisite đã PASS, không còn chờ duyệt/apply R2.
