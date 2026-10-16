# T6–T7 staging — apply thành công, nghiệm thu còn chờ native connection

Ngày 2026-10-16. Owner đã duyệt apply và chạy kiểm tra đúng gói staging trong chat.
**BASE APPLIED; R1 REPAIR ROLLED BACK; R2 TEMP-UNIT PASS, NOT APPLIED.**
Không coi P3.2 hoặc Account acceptance là hoàn tất.

## Cập nhật apply repair R1 và chuẩn bị R2

Owner duyệt exact `7fdd0fe`. Hash R1 và original manifest 8/8 khớp, preflight live
12:16:20 ICT khớp hai function definitions. Supabase apply_migration R1 chạy đến
regression account validation rồi ERROR 42702 `e is ambiguous`, tự rollback.
12:17:53 ICT xác nhận repair history absent và hai private definitions vẫn là
`51256cfeb2a57bf023e90da33503bd08` / `713fa2d3b6c0f836e19dec6b2cdf485a`.
Không align history hoặc thử apply R2 khi chưa được duyệt hash mới.

R2 sửa thêm query alias tại exception validation/deleteActual/filtering, chỉ trong
cùng hai private functions; thêm deleteActual positive/negative regression.
Đã kiểm body R2 qua pg_temp clones + regression và 12-command block: **PASS**,
transaction rollback; không thay permanent functions hoặc ghi app fixture rows.
R2 source hash và gói review cập nhật ở repair packet. Full suites/races chưa chạy.

## Cập nhật sau khi Owner cấu hình native connection

- Native TLS connect thành công `postgres|postgres|t`; không cần Owner nhập lại mật khẩu.
- ExecuteStaging FAIL tại positive suite, lỗi `boolean -> unknown` trong reorderDay.
  Negative/B3 suites và 12 races chưa chạy. Không báo SQL nghiệm thu PASS.
- Transaction fixture rollback; read-only 2026-10-16 11:56:25 ICT xác nhận cả hai
  namespace synthetic users còn 0. Không đổi migration đã apply hoặc data sản phẩm.
- Đã chuẩn bị [gói forward fix](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_STAGING_JSON_PRECEDENCE_REPAIR.md)
  cho 5 vị trí toán hạng JSON trong hai private functions, có preflight/regression
  transaction. Fix chưa apply, chờ duyệt hash mới theo plan §4.
- SelfTest/dry-run PASS; corrected expression SELECT true/true. New DDL/full
  SQL suites sau sửa NOT RUN. Các kiểm post-apply/ACL bên dưới là evidence lịch sử.

## Changed

- Target duy nhất `bkocylxbuyvdgxccpixx`. Source repo HEAD khi apply
  `27181978472cc5b8e1460ca5d25c9d3e3d91c149`, source SQL HEAD `0a499cf`.
- Apply qua Supabase MCP `apply_migration`, name `editable_trip_v2`, nhận
  `success:true`; SQL là nguyên bytes file đã duyệt
  `supabase/migrations/20261016034905_editable_trip_v2.sql`, SHA-256
  `9f4d30c8d7bd7b8b1c19c4a1e70858c7ce45676d289cfcb11e637d807768f6cd`.
- MCP đăng ký version `20261016044628`; kiểm registry lưu **đúng một SQL string
  có cùng SHA-256 đã duyệt**, rồi đồng bộ duy nhất version registry thành
  `20261016034905` để khớp tên file CLI. UPDATE có điều kiện name/old version/hash
  và version đích chưa tồn tại. Không đổi SQL đã apply hoặc dữ liệu ứng dụng.
- Tạo helper/hướng dẫn cấu hình native connection trong artifact ngoài repo;
  không chứa mật khẩu. Không push, deploy, sửa app/native config hoặc primary.

## Why / luồng

Native runner cần nhiều phiên PostgreSQL độc lập để quan sát khóa giữa thao tác
lưu/xóa/đọc và xóa tài khoản. Kết nối Supabase MCP đã đăng nhập giúp apply gói và
kiểm quyền ngay, nhưng chưa thay thế bằng chứng 12 schedules của runner native.

Sau khi Owner nhập mật khẩu database cục bộ và chọn CA certificate, Codex nạp
metadata đường dẫn, đặt PGUSER/PGDATABASE/PGPASSFILE/PGSSLROOTCERT cho process
runner. Runner tự pin staging host, verify-full TLS, tạo synthetic fixtures và
cleanup đúng UUID/email/run. Approval hiện tại còn hiệu lực; không apply lại file.

## Testing thực tế

- Source manifest **8/8 hashes MATCH** trước apply. PostgreSQL 17.11, role postgres;
  V2 objects chưa tồn tại ở precheck 04:39:25 UTC. Preflight transaction trong
  migration đã đối chiếu schema/ACL/B3 baseline trước DDL; apply trả success.
- 04:47:34 UTC: **3 private tables, RLS=true cho cả ba, 6 public RPC**,
  **0 app execute grants trên private helpers**.
- Ba B3 definitions/ACL giữ nguyên:
  `guest_b3_trip_guard`: `86dbec45babd7eb72937b9f8a455c65a`;
  `import_guest_draft_v1`: `8f96ede11466e66055b04b35c970d64e`;
  `get_import_trip_snapshot_v1`: `37296be3a0bfe0495195ebac85f3bea1`.
- 04:50:12 UTC: smoke trong transaction rollback dưới role anon/authenticated
  **PASS**: anon gọi get RPC bị permission denied; authenticated thiếu auth UID
  bị `unauthorized`. Không tạo fixture/account/trip hoặc ghi application rows.
- Metadata ACL: **0 direct private-table privileges** cho anon/authenticated/
  service_role trên 3 bảng (SELECT/INSERT/UPDATE/DELETE/TRUNCATE);
  **0 anon grants** trên 6 RPC; **6/6** authenticated RPC có postgres owner,
  SECURITY DEFINER và `search_path=''` đúng contract.
- Native psql **18.6** có sẵn; direct TCP staging port5432 **reachable=true**.
- Thiếu PGUSER/PGDATABASE/PGPASSFILE/PGSSLROOTCERT và không có standard pgpass/CA;
  **chưa chạy ExecuteStaging**, SQL positive/negative/B3 suites và 12 independent
  schedules **NOT RUN**, không có synthetic fixture từ runner cần cleanup.
- Setup helper SelfTest **PASS**, không tạo credential hoặc kết nối DB.
- Analyzer/655 Flutter/Pester14/SelfTest/dry-run PASS là evidence source gói trước
  apply, không chạy lại ở task database này và không dùng để chứng minh SQL PASS.

## Problems / security review

Security advisor đã chạy 04:49 UTC. Không báo toàn bộ project security CLEAN:

- Ba private V2 tables có RLS nhưng không policy: [INFO 0008](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
  Đây là deny trực tiếp có chủ đích; app còn bị revoke table grants, chỉ qua RPC.
- Sáu V2 RPC được authenticated gọi SECURITY DEFINER: [WARN 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
  Đúng interface đã duyệt; có auth/owner checks, search_path rỗng và anon bị revoke.
  Full ownership/ledger/race behavior vẫn chờ suite thực tế.
- Advisor còn báo hai hàm ngoài T6 `set_profile_updated_at` và
  `verify_profiles_policy_drift` cho anon execute SECURITY DEFINER:
  [WARN 0028](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable).
  Ghi nhận để review riêng, không sửa ACL ngoài gói đã duyệt. Các anonymous-policy/
  Auth password-protection notices ngoài T6 cũng giữ nguyên, chưa xử lý.

Primary `oavbymauorhmrjcustzw` không được apply/query trong task; B3 primary
vẫn NOT APPLIED theo handoff. Không install/launch APK, chưa có phone acceptance mới.

## Lesson Candidate / checkpoint

MCP sinh registry timestamp khác CLI file → xác nhận exact stored SQL hash rồi
đồng bộ duy nhất registry entry → không để lần migration sau coi cùng source là
hai migration. Apply thành công không đồng nghĩa native concurrency PASS.

Tiếp theo: Owner duyệt gói JSON precedence/query alias repair **R2**; cấu hình native đã dùng được,
không yêu cầu nhập lại. Sau approval apply đúng forward migration rồi chạy lại
runner và kiểm cleanup. Giữ state hiện tại; không reset/drop/reapply file gốc.
Giữ Codex-only, superpowers OFF, no subagents/Docker/main push; giữ nguyên sáu
Owner paths, macOS dirty file và unrelated untracked docs.
