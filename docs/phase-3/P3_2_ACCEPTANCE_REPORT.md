# P3.2 — Manual planner and budget acceptance

Ngày kiểm: 2026-10-16. Branch: `codex/phase-3-discovery-design`.
Trạng thái: **CLIENT SOURCE VERIFIED; WHOLE P3.2 ACCEPTANCE PENDING**.
App source: `7c103ac` (T16), trước đó T14 `b9074eb`, T15 `8ee26c0`, UI3 `4981bee`.
Các file T17 chỉ thêm tests/probe/report, không đổi runtime app.

## Changed / Why

Guest có thể mở lịch tự lập, sửa hoạt động/ngày, dự kiến/chi thực tế, xem lại và
lưu bản nháp; mở lại từ SQLite giữ đúng nội dung. Account chọn đúng revision để
chuyển, retry giữ identity của yêu cầu đã xác nhận. V2 saved dùng versioned read/
edit/delete; V1 giữ nguyên và chỉ tạo bản sao sau preview. UI và state kiểm owner,
phiên, revision/digest trước và sau I/O; cache ngoại tuyến chỉ đọc, không ngầm
đổi điểm đến hoặc gọi Decision Engine/AI. Codex implement và tự kiểm source/tests.

T17 thêm `manual_planner_end_to_end_test.dart` và Android target
`test/native/editable_trip_probe.dart`. Native probe chỉ dùng thư mục con
`p32_owned_native_v2` với marker riêng, session synthetic, không gọi server hoặc
đọc dữ liệu của app chính. Launch hai lần để kiểm sealed restart/A→B. Chưa có
thiết bị thì source/analyzer không được báo thành native persistence PASS.

## Testing

- T14: analyzer sạch; focused 82 PASS; full 638 PASS.
- T15: analyzer sạch; focused 10 PASS; full 645 PASS.
- T16: analyzer sạch; focused 19 PASS; full 652 PASS.
- T17 focused: `flutter test --no-pub test/manual_planner_end_to_end_test.dart
  --reporter expanded`: **3 PASS**, exit 0, 4s.
- T17 chứng minh Guest edit/save → đóng/mở SQLite → đọc đúng digest → explicit
  import bằng service synthetic → offline read-only → A/B purge giữ Guest còn lại.
  Case riêng sealed registry + disk reopen giữ actual, sau đó B không thấy A.
- T16 kiểm no selection/cancel không gửi; thiếu ngày chặn; đổi account trong
  consent; revision mới khi dialog mở; revision 2 tồn tại khi ack revision 1;
  mất local ack rồi retry revision 1 không xóa revision 2 hoặc tạo trùng.
- Các bài service/repository dùng server synthetic; **không là SQL/RLS live PASS**.
- Final `flutter analyze --no-pub`: **No issues found**, exit 0, 4.2s.
- Final `flutter test --no-pub --reporter expanded`: **655 PASS**, exit 0, 43s.
- `node --test test/catalogue_readiness_test.mjs`: **40 PASS**, exit 0.
- Touched Dart format check: 0 changes; `git diff --check` PASS.
- Logs ignored: `build/p32-t17-analyze-final.log`, `p32-t17-full-final.log`,
  `p32-t17-catalogue.log`, `p32-t17-apk-build.log`.
- Owner macOS file SHA-256 vẫn
  `A3E74B87727BB64B1A151FD73324E80246B712C8663792DBB01E82EACEA5AD74`.

| ID | Client evidence | SQL / Android evidence |
| --- | --- | --- |
| M01 | validator, trip input form, Guest/account validation tests | Android PENDING |
| M02 | command/mutator + button CRUD/reorder widget tests | Android PENDING |
| M03 | resize preview/unknown/ack invalidation tests | Android PENDING |
| M04 | integer budget vectors + basis/overflow + budget UI tests | SQL NOT RUN; Android PENDING |
| M05 | activity removal unlinks actual without changing ledger amounts | SQL NOT RUN; Android PENDING |
| M06 | SQLite FFI faults/reopen + T17 Guest integrated restart | Native device NOT RUN |
| M07 | V1 regression vectors + T15 copy/cancel/source binding | Android PENDING |
| M08 | populated V1→V2 atomic upgrade/fault regression | Native device NOT RUN |
| M09 | T16 selected revision + lost ack/recovery/preserve newer Guest | Native PostgreSQL NOT RUN |
| M10 | service/repository/provider receipt + account save tests | Live staging NOT RUN |
| M11 | frozen request/old receipt/new head/conflict client tests | Independent SQL sessions NOT RUN |
| M12 | typed commands and atomic local document tests | SQL adversarial NOT RUN |
| M13 | lifecycle/proof/late responses/purge/real disk sealed restart | SQL roles/device NOT RUN |
| M14 | T15 complete offline view and unavailable; monotonic cache tests | Airplane-mode device PENDING |
| M15 | client rejects identity/protocol/deployment errors | Real ACL/RLS/bypass controls NOT RUN |
| M16 | T15 warning/cancel/version conflict/delete/cache removal | SQL tombstone/races NOT RUN |
| M17 | widget sizes/text scaling/button reorder/forms/focus | TalkBack/landscape/device PENDING |
| M18 | Discovery→Huế→manual Guest integrated regression, no engine/AI | Android PENDING |

## Problems / limits

- T6 migration, positive/negative SQL suites và T7 native runner đã viết/commit.
  Gói nguồn và hash được chốt tại [hồ sơ migration staging](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_STAGING_MIGRATION_PACKET.md).
  Metadata baseline staging đối chiếu đầy đủ ngày 2026-10-16 04:23:04 UTC: khớp;
  3 bảng/6 RPC V2 chưa tồn tại. B3 definition/ACL/owner/search_path không đổi.
  Local SelfTest và dry-run **PASS**, Pester **14/14 PASS**; native child-process
  timeout/nonzero/drain đã kiểm. Đây không phải SQL database runtime PASS.
  Owner đã duyệt apply/test; migration **APPLIED** trên staging `bkocylxbuyvdgxccpixx`,
  post-apply metadata và anon/missing-auth smoke PASS. Native PG connection đã thành
  công; positive SQL suite **FAIL** do JSON operator precedence ở reorderDay/ack.
  Negative/B3 suites và 12 races **NOT RUN**. [Forward fix](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_STAGING_JSON_PRECEDENCE_REPAIR.md)
  đã chuẩn bị, chưa apply, chờ Owner review hash mới theo plan §4.
  Chi tiết ở [runtime report](D:/Travel-Go-Android/travel-go/docs/phase-3/P3_2_STAGING_RUNTIME_REPORT.md).
- No deployment performed. Primary B3 stays **NOT APPLIED** per handoff;
  primary is outside scope. Không apply lại migration staging đã thành công.
- APK, when built, is a **Guest/UI staging test build**. Account V2 list/save/edit/
  import depend on missing staging RPC/schema and will report server not ready.
  Legacy list also requires the mixed discriminator RPC; do not silently fall
  back to broad V1 decoding. This APK is not account runtime acceptance.
- Owner P3.1 acceptance remains PENDING. Whole P3.2 cannot be COMPLETE from
  synthetic tests. No push/PR/hosted CI/merge in this scope.
- Device inventory at 2026-10-16: `adb devices -l` empty. No install/clear/uninstall.
- Previous diagnostic PNGs are NOT ACCEPTED visual evidence. No visual or
  accessibility PASS is inferred from widget tests or UI skill suggestions.
- Preserve Owner generated macOS change and all unrelated/private files.

## Owner test on the staging Guest/UI build

1. Guest → Khám phá → Huế → Chuẩn bị chuyến đi → Tự lập lịch trình.
2. Nhập ngày/người/ngân sách; thêm/sửa/chuyển/thứ tự hoạt động bằng các nút.
3. Thêm dự kiến, giá chưa biết và chi thực tế; kiểm tổng riêng và phần còn lại.
4. Xóa một hoạt động: khoản đã chi vẫn còn, chỉ bỏ liên kết hoạt động.
5. Xem lại → lưu trên máy → đóng/mở app → Chuyến đi của tôi → mở đúng bản nháp.
6. Giảm số ngày: xem preview và giải quyết hoạt động bị ảnh hưởng; Hủy giữ nguyên.
7. Kiểm chữ lớn, bàn phím, landscape, back/cancel, TalkBack. Báo step PASS/FAIL.
8. Account tests chạy sau migration staging được duyệt/apply; không dùng lỗi RPC
   chưa triển khai làm bằng chứng test account thành công.

## Lesson Candidate

T6/T7 bổ sung: hash fixture thuộc exact rawText, không phải canonicalText →
đọc đúng hợp đồng trước khi so digest; giữ nguyên chuỗi gửi lên khi retry.
Pester 3.4 tại máy này trả false với Throw không có expected message → dùng
detector try/catch tường minh và negative control để kiểm chính bộ kiểm thử.

T6/T7 verification local ngày 2026-10-16: `flutter analyze --no-pub` sạch (4.6s),
`flutter test --no-pub --reporter expanded` **655 PASS** (46s); không đổi Dart,
không rebuild APK, không có SQL parser/runtime PASS hoặc nghiệm thu điện thoại mới.

Account từ chối Guest write → race test phải mô phỏng một workspace Guest khác
trên disk synthetic, không nới quyền của account để test PASS. Retry đọc revision
mới → sai yêu cầu đã xác nhận → giữ immutable source/digest/request identity và
chỉ retire đúng revision có ack. Bản mới hơn tiếp tục tồn tại trên máy.

## APK STAGING — Guest/UI test artifact

- Build `flutter build apk --release --target-platform android-arm64 --no-pub`
  với `TRAVELGO_ENV=staging` và active publishable key của staging qua file build
  tạm. File tạm đã xóa; không thêm key vào source/report/log. Exit 0; Gradle 70.3s.
- Package `com.travelgo.travelgo_mobile`, versionCode 1, versionName 1.0.0 theo
  cấu hình hiện có; không đổi native config/signing. Release dùng debug signing
  hiện có để test, không phải artifact phát hành store.
- Artifact: `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/TravelGO-P3.2-GUEST-STAGING-20261016-70C9947B.apk`.
- Kích thước: 22,365,863 bytes. SHA-256:
  `70C9947B0883C6BD7207E3F795225A83E544FE6818FBD61374462DCB03B3FA78`.
- `libapp.so` chỉ có ARM64; ELF64/AArch64 đã kiểm. Archive còn hai binary
  `libdatastore_shared_counter.so` armeabi-v7a/x86_64 từ dependency hiện có, nên
  aapt liệt kê thêm hai ABI; không coi chúng là app Dart cho ABI khác.
- Catalogue trong APK trùng bytes cả source và asset, SHA-256
  `C14CECC97149A3ACF64F439D44662333BBB8756BD580E18F368AC053BDD1542A`.
- Staging URL + nhãn STAGING có trong app binary. Hash bản xuất trùng bản build.
- ADB không có thiết bị: install/launch/native two-stage probe/phone UI NOT RUN.
- **Chỉ test Guest/UI hiện tại. Account runtime chờ T6/T7 + exact staging apply
  approval + kiểm SQL thật. Không tự apply hoặc đổi sang primary.**
