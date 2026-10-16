# P3.2 — Gói duyệt migration staging T6–T7

Ngày 2026-10-16. **STAGING APPLIED; NATIVE SQL POSITIVE FAIL; REPAIR REVIEW PENDING.**
Native connection đã dùng được. Xem [gói sửa JSON precedence](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_STAGING_JSON_PRECEDENCE_REPAIR.md);
forward fix chưa apply. Manifest gốc dưới đây vẫn giữ nguyên 8/8 hashes.
Owner đã duyệt apply/test trong chat. Kết quả runtime cập nhật ở
[staging runtime report](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_STAGING_RUNTIME_REPORT.md).
Các phần source/hash/SOP bên dưới giữ hồ sơ gói đã duyệt; không apply lại migration.
Repo `plhhoang2005/travel-go-mobile`, workspace `D:/Travel-Go-Android/travel-go`,
branch `codex/phase-3-discovery-design`. Không push/PR/deploy trong task này.
Source HEAD được ràng buộc: `0a499cf95d9645128e2349d39573ba817fda199f`.
Các commit SQL: `d9614fd`, `b5d1396`, `01f239a`, `0a499cf`; runner: `7a8fd41`.
Commit tài liệu về sau không đổi năm file nguồn T6/T7 được duyệt dưới đây.

## Changed

- Migration do Supabase CLI **2.81.3** tạo đúng path trả về, không tự đoán timestamp.
  Ba bảng private lưu document/version, receipt và permit theo PID/transaction/trip/op;
  sáu RPC authenticated tạo/sửa/đọc/tra receipt/list/xóa; guard cho trips/activities.
- SQL positive/negative suites dùng corpus T1 nguyên chuỗi, đủ 12 typed commands,
  retry, phiên bản, ownership, actual-ledger protection, V1 copy, ACL và cascade.
- Runner native psql: default dry-run, exact target allowlist, UTF-8, TLS verify-full,
  hidden processes, drain stdout/stderr, timeout, cleanup chỉ synthetic owner/email.
  Chạy cả hai SQL suites V2 và hai regression suites B3 trên kết nối riêng.
- Nguồn được Codex implement và tự review. Không dùng subagents/superpowers/Docker.

## Why và luồng hoạt động

Ví dụ Owner sửa ngày của chuyến Huế trên hai thiết bị: app gửi phiên bản gốc,
commands, exact payload/request text và hash. RPC lấy owner từ phiên đăng nhập,
khóa user → owner → trip, tự replay lệnh và kiểm nội dung. Chỉ một yêu cầu cùng
phiên bản được commit; yêu cầu còn lại báo xung đột. Cùng request ID thử lại trả
receipt cũ, không tạo chuyến hoặc tăng version lần nữa. Head có thể mới hơn receipt.

Sửa/xóa hoạt động giữ nguyên tiền đã chi; chỉ bỏ liên kết và giữ snapshot.
Thay đổi actual phải qua putActual/deleteActual. V1 chỉ được đọc để tạo bản sao,
không đổi bytes hoặc receipt gốc. Xóa chuyến giữ tombstone; retry không hồi sinh nó.

## Target và metadata đã kiểm

- **Chỉ staging:** `bkocylxbuyvdgxccpixx`.
- **Chỉ direct host:** `db.bkocylxbuyvdgxccpixx.supabase.co`, port 5432.
- Primary `oavbymauorhmrjcustzw` ngoài scope; B3 primary vẫn NOT APPLIED theo handoff.
- Metadata-only SELECT 2026-10-16 **04:23:04.036522 UTC**: toàn bộ baseline
  tables/columns/defaults/nullability/FKs/checks/triggers/policies/ACL nhúng trong
  migration khớp (`baseline_matches=true`); private schema owner/ACL khớp.
- Metadata-only SELECT **04:20:13.25589 UTC**: PostgreSQL 17.11,
  **0/3 bảng V2 và 0/6 RPC V2**, B3 definition MD5/ACL/owner/security-definer/
  search_path khớp. pgcrypto đã có trong `extensions` theo preflight T6.
- Migration tự đối chiếu lại baseline và object collision trước DDL trong cùng
  transaction; drift/migration đã tồn tại thì dừng. Không phải migration rerunnable.

| B3 function giữ nguyên | Definition MD5 |
| --- | --- |
| private.guest_b3_trip_guard() | 86dbec45babd7eb72937b9f8a455c65a |
| import_guest_draft_v1(text,text,bigint,text,text,text) | 8f96ede11466e66055b04b35c970d64e |
| get_import_trip_snapshot_v1(uuid) | 37296be3a0bfe0495195ebac85f3bea1 |

## Exact source manifest

Các path dưới tính từ workspace tuyệt đối đã nêu; SHA-256 của bytes hiện tại.
Đối chiếu **cả tám file** trước apply/test. Khác hash, kể cả line endings, phải
kiểm lại gói; không tự bỏ qua. Không ghi credential/public key vào hồ sơ hoặc log.

| Path | SHA-256 |
| --- | --- |
| supabase/migrations/20261016034905_editable_trip_v2.sql | 9f4d30c8d7bd7b8b1c19c4a1e70858c7ce45676d289cfcb11e637d807768f6cd |
| supabase/tests/editable_trip_v2.sql | a270ada2573752c68bdff8dea3a45b5d6cbec9b7505ef3b479067159b3acc464 |
| supabase/tests/editable_trip_v2_negative_controls.sql | 5e8b93532292cd927c7dbff38580397f84e0f96477414df557c6802ddc63d7cb |
| supabase/tests/run-editable-trip-concurrency.ps1 | 58d033d60f5a5511755612677e507a79dc706d2814f379873004ff471f9c3eb2 |
| supabase/tests/run-editable-trip-concurrency.Tests.ps1 | 729b4953a054f930f358265a34aa6fe3db88a81c988f026e4df6b7596733b380 |
| test/fixtures/editable_trip_v2_vectors.json | 8a9c07bbae1225d2e1b931ce48dda2ec33994bd66aae8de927d3be173020b9d9 |
| supabase/tests/guest_import.sql | db446de8cc64f4c19a2d78b7d16f5d765fc73635589d13a6f7857fb11668b1c1 |
| supabase/tests/guest_import_negative_controls.sql | 4e917d62458f84aa7c952e7b3965ded372f2afde7e5bcd1a6aeaf79105ce25fa |

## Testing đã chạy

PowerShell 7, Pester 3.4.0 có sẵn; không cài thêm dependency.

```powershell
./supabase/tests/run-editable-trip-concurrency.ps1 -SelfTest
./supabase/tests/run-editable-trip-concurrency.ps1 `
  -ProjectRef bkocylxbuyvdgxccpixx `
  -ConnectionHost db.bkocylxbuyvdgxccpixx.supabase.co
Invoke-Pester ./supabase/tests/run-editable-trip-concurrency.Tests.ps1
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

- SelfTest **PASS**, default dry-run **PASS**, không kết nối database.
- Pester **14/14 PASS**: target/missing-source/fixture identity, exact rawText,
  SQL NULL, digest-bound requests, detector controls; child pwsh thật kiểm
  success/stdout+stderr drain, nonzero exit và timeout/kill qua cùng finish path.
- Analyzer **No issues found**, exit 0, 4.6s; Flutter **655 PASS**, exit 0, 46s.
  Đây là kiểm client; không compile hoặc chạy PL/pgSQL.
- Static source/dollar delimiter checks, đủ 3 tables/6 RPC, selective diff check PASS.
- SQL parser độc lập không có sẵn (`pglast` absent). **SQL function bodies,
  fixtures, ACL/RLS và real races NOT RUN**. Không coi source review là runtime PASS.
- Logs: `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/`
  với prefix `P3_2_T7_`: SELFTEST, DRY_RUN, PESTER, ANALYZE, FLUTTER_TEST.

## Chỉ chạy sau Owner duyệt đúng gói

Quyền viết source trước đây chưa cho phép apply/test dữ liệu. Gate này đến từ
[implementation plan §4](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_IMPLEMENTATION_PLAN.md:641).
Đề nghị duyệt cụ thể: **apply duy nhất migration có hash trong manifest lên staging
bkocylxbuyvdgxccpixx, rồi chạy runner ExecuteStaging và cleanup synthetic fixtures;
không primary, không deploy/AI**. Chưa có approval này tại thời điểm chốt hồ sơ.

Sau approval: kiểm HEAD/dirty paths và tám hashes; metadata drift thì dừng.
Dùng native psql và PowerShell 7; cấu hình PGUSER/PGDATABASE=postgres,
PGPASSFILE có sẵn và trust certificate/PGSSLROOTCERT cho verify-full ngoài log.
Không đưa mật khẩu hoặc connection URI vào command, file source hay chat.

Đoạn dưới là SOP **chưa chạy**, không phải cấp quyền tự chạy:

```powershell
$p32Psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$p32Migration = 'D:\Travel-Go-Android\travel-go\supabase\migrations\20261016034905_editable_trip_v2.sql'
if ($env:PGUSER -cne 'postgres' -or $env:PGDATABASE -cne 'postgres' -or
    [string]::IsNullOrWhiteSpace($env:PGPASSFILE) -or
    -not (Test-Path -LiteralPath $env:PGPASSFILE -PathType Leaf)) { throw 'PG setup required' }
if ((Get-FileHash -LiteralPath $p32Migration -Algorithm SHA256).Hash.ToLowerInvariant() -cne
    '9f4d30c8d7bd7b8b1c19c4a1e70858c7ce45676d289cfcb11e637d807768f6cd') { throw 'Migration hash drift' }
$env:PGHOST = 'db.bkocylxbuyvdgxccpixx.supabase.co'
$env:PGPORT = '5432'
$env:PGSSLMODE = 'verify-full'
$env:PGCLIENTENCODING = 'UTF8'
$env:PGCONNECT_TIMEOUT = '10'
foreach ($p32Name in @('PGSERVICE','PGSERVICEFILE','PGOPTIONS','PGHOSTADDR','PGPASSWORD')) {
  [Environment]::SetEnvironmentVariable($p32Name,$null,'Process')
}
& $p32Psql -X -w -v ON_ERROR_STOP=1 -f $p32Migration
if ($LASTEXITCODE -ne 0) { throw 'Apply failed; stop and review' }
& 'D:\Travel-Go-Android\travel-go\supabase\tests\run-editable-trip-concurrency.ps1' `
  -ProjectRef bkocylxbuyvdgxccpixx `
  -ConnectionHost db.bkocylxbuyvdgxccpixx.supabase.co -ExecuteStaging
if (-not $?) { throw 'Staging validation failed; stop and review' }
```

Không dùng db push để kéo theo migration khác. Runner không apply migration; chỉ bắt đầu
suites sau khi file migration đã apply thành công. Lỗi trước COMMIT sẽ rollback
transaction khi psql thoát. Nếu COMMIT xong nhưng test lỗi: giữ state, dừng Account
acceptance, review bản sửa; không DROP/reset hoặc apply lại file đã tồn tại.

## Expected postconditions và phần chưa nghiệm thu

- 3 bảng private có RLS; app roles không được truy cập bảng/helper/permit.
  Authenticated chỉ có đúng sáu RPC mới; anon không được gọi.
- Hai suites V2 và hai suites B3 PASS; B3 hashes/ACL/receipt behavior giữ nguyên.
- **12 schedules** phải quan sát đúng blocker PID: cùng create key; cùng base update;
  cùng update key; update→read; read→update; read→delete; delete→read;
  update→delete; delete→update; cùng delete key; update→account cascade;
  account cascade→update. Lost reply/recovery và old receipt/newer head kiểm riêng.
- Chỉ một receipt/commit đúng identity/version; account cascade không deadlock,
  deleted retry không hồi sinh; cleanup đúng UUID+email+run và kiểm đã hết synthetic
  users/trips/documents/receipts. Native timeout/cooperative error xử lý best effort;
  forced host termination/power loss không được báo là đã kiểm cleanup.
- Chỉ sau SQL PASS mới bắt đầu Account nghiệm thu trên staging APK. Android native
  restart/phone UI/TalkBack vẫn PENDING; Phase 3/P3.2 toàn luồng chưa COMPLETE.
  APK Guest/UI hiện có giữ nguyên SHA-256
  `70C9947B0883C6BD7207E3F795225A83E544FE6818FBD61374462DCB03B3FA78`.

## Checkpoint / Problems / Lesson Candidate

Source T6/T7 đã commit; docs này là checkpoint thay cho checkpoint T6 cũ còn pending.
Việc tiếp theo duy nhất của gói là Owner review/approve exact staging apply/test,
sau đó chạy và cập nhật runtime evidence. Không còn runner/source task bị bỏ dở.

Owner macOS file giữ SHA-256
`A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74`;
sáu private paths/untracked docs không đọc/sửa/stage/delete. Không reset/clean/push.

Fixture hash nhầm canonical với raw → đọc lại contract và sửa test → luôn bind
receipt/retry với exact submitted bytes. Pester Throw không expected message trả
false ở bản 3.4 này → dùng detector tường minh + deliberately broken controls →
kiểm chính bộ kiểm thử trước khi dựa vào kết quả PASS.

Review fingerprint: inner JSON value che outer item → qualify scoped_item.value
để lấy đúng ngày → SQL suite so fingerprint với ngày thật cố định; runtime vẫn NOT RUN.
