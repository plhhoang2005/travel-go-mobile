# TravelGO Flutter Admin & Account Control Acceptance Ledger

**Ngày thiết lập:** 23/10/2026 (Asia/Saigon)  
**Phân công đã duyệt:** Codex lập kế hoạch & review; Antigravity viết mã, kiểm thử và sửa findings.  
**Branch hiện tại:** `codex/phase-3-discovery-design`  
**Actual HEAD:** `f27d86ac929865a55718481cfdb4f1afa9e1c723`  
**Planning baseline commit (từ handoff):** `c6138952fc98838728a89c825bbc9bfb2df89bf1`  
**Working tree dirty state:** 46 modified files, 90 untracked files (toàn bộ dirty work của owner được bảo toàn 100%, không stash, không clean, không reset).

---

## 1. Runtime Tools & Verification Environment Status

| Công cụ | Phiên bản / Vị trí | Trạng thái | Ghi chú kỹ thuật |
|---|---|---|---|
| **Flutter SDK** | Flutter 3.47.4 • Dart 3.13.3 (`D:\flutter\flutter`) | **READY (Pass)** | Chạy qua cached snapshot `flutter_tools.snapshot` và `dart.exe`, tránh bootstrap launcher hang trên Windows. |
| **Node.js** | v24.16.0 (`D:\nodejs\node.exe`) | **READY (Pass)** | Chạy trực tiếp test runner `node --test`. |
| **PostgreSQL** | v18.6 (`C:\Program Files\PostgreSQL\18\bin`) | **READY (Pass)** | Sử dụng `initdb.exe`, `pg_ctl.exe`, `psql.exe` khởi tạo cluster độc lập tạm thời (disposable loopback port `127.0.0.1`), `ON_ERROR_STOP=1`. |
| **Supabase CLI** | Không có trên PATH và không có trong npm global | **BLOCKED / NOT RUN** | Không tự cài đặt / nâng cấp theo nguyên tắc bảo vệ runtime. Các lệnh `supabase migration new` trong task sau sẽ yêu cầu CLI hoặc cơ chế tương thích. |
| **Android / Emulator** | Thiết bị vật lý / Emulator 5554 / 5556 | **NOT RUN** | Không chạm emulator hoặc phone đang mở theo chỉ thị Task A0. |

---

## 2. Verification Harness Self-Test (`harness_propagates_nonzero`)

Harness [`tool/verify-flutter-admin.ps1`](file:///d:/Travel-Go-Android/travel-go/tool/verify-flutter-admin.ps1) được trang bị cờ `-SelfTest` nhằm kiểm tra tính toàn vẹn lan truyền mã lỗi:
1. **Node deliberate failure:** Khởi chạy script tạm thời cố tình vi phạm `assert.strictEqual(1, 2)` $\rightarrow$ Node kết thúc với mã lỗi $\neq 0$, harness bắt được lỗi và ghi nhận PASS cho cơ chế chặn lỗi.
2. **SQL deliberate failure:** Khởi chạy truy vấn cố tình lỗi `SELECT 1/0;` trên psql với `ON_ERROR_STOP=1` $\rightarrow$ psql kết thúc với mã lỗi $\neq 0$ và thông báo `ERROR: division by zero`, harness bắt được lỗi và ghi nhận PASS cho cơ chế chặn lỗi.
3. **Kết luận:** Cơ chế chặn lỗi hoạt động chuẩn xác; tuyệt đối không có việc nuốt lỗi (swallow failure) hoặc chuyển lỗi thành PASS.

---

## 3. Fresh Baseline Evidence

### 3.1. Scoped Flutter Analyzer
- **Lệnh:** `& "D:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe" "D:\flutter\flutter\bin\cache\flutter_tools.snapshot" --suppress-analytics analyze --no-pub`
- **Kết quả:** `No issues found! (ran in 71.9s)`, exit 0.
- **Trạng thái:** Analyzer hoàn toàn sạch trên working tree hiện tại.

### 3.2. Existing Node Contract Suites (115 tests)
- **Lệnh:** `& "D:\nodejs\node.exe" --test test/ai_gateway_test.mjs test/itinerary_gateway_test.mjs test/catalogue_readiness_test.mjs test/admin_discovery_web_test.mjs`
- **Kết quả:** `115 pass / 0 fail` (thời lượng 315ms), exit 0.
- **Bao gồm:**
  - AI Gateway: 41 tests pass
  - Itinerary Proposal Gateway: 23 tests pass
  - Catalogue Readiness: 25 tests pass
  - Admin Discovery Web: 26 tests pass

### 3.3. Isolated Disposable PostgreSQL Test Suites
Chạy trong cluster PostgreSQL 18.6 loopback tạm thời với synthetic auth substrate:
- **Mode Account (`tool/verify-flutter-admin.ps1 -Mode Account`):**
  - Dart targeted tests: 155 / 155 pass (`test/auth_role_security_test.dart`, `test/auth_navigation_test.dart`, `test/local_account_lifecycle_test.dart`), exit 0.
  - SQL migrations & regressions: `baseline.sql`, `profile_privacy.sql`, `profile_preferences.sql`, `two_role_foundation.sql`, `profile_two_roles.sql` đều PASS, exit 0.
- **Mode Draft (`tool/verify-flutter-admin.ps1 -Mode Draft`):**
  - Node contracts: 26 / 26 pass (`test/admin_discovery_web_test.mjs`), exit 0.
  - SQL migrations & regressions: `baseline.sql`, `profile_privacy.sql`, `profile_preferences.sql`, `two_role_foundation.sql`, `admin_discovery_drafts.sql`, `admin_discovery.sql` (toàn bộ 50 assertions) đều PASS, exit 0.

### 3.4. Historical Failures & Fresh Retest
- **Ghi nhận lịch sử (từ `docs/phase-3/ADMIN_DISCOVERY_IMPLEMENTATION_PLAN_20261020.md`, dòng 250–251):**
  1. `test/editable_guest_import_ui_test.dart`: từng ghi nhận `lost local ack retries original request even after Guest revision advances` (expected `false`, actual `true`).
  2. `test/editable_saved_trip_ui_test.dart`: từng ghi nhận `saved detail photos use stable ids and large text preserves read-only ledgers` (`pumpAndSettle` timeout).
- **Kết quả kiểm tra tươi (Fresh Retest) ngày 23/10/2026:**
  - **Full Suite Run:** 854 / 854 tests PASS trong 01:33 (exit 0). Log: `.dart_tool\travelgo-verification\20261023T044609308Z-30212\flutter-tests.log`.
  - **Targeted Run (`tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/editable_guest_import_ui_test.dart','test/editable_saved_trip_ui_test.dart')`):**
    - Kết quả: `20 / 20 PASS` trong 7 giây (exit 0). Log: `.dart_tool\travelgo-verification\20261023T044815556Z-22628\flutter-tests.log`.
  - **Kết luận:** Cả hai ca kiểm thử lịch sử trên đều đạt kết quả PASS thực tế trên working tree hiện tại mà không cần sửa đổi bất kỳ dòng code sản phẩm hay assertion nào. Hồ sơ lịch sử được lưu giữ minh bạch, không xóa bỏ.

---

## 4. Task A0 Execution Summary & Budget Accounting

- **Chỉ thị Owner ngày 23/10/2026:** Owner đã phê duyệt bãi bỏ giới hạn cứng về số lượt calls (20/25 calls/task, trần 500 calls tổng).
- **Ngân sách thực tế Task A0:**
  - **Tool calls:** Đã hoàn thành nhiệm vụ theo quyền chủ động dùng công cụ để inspect, code, test và fix errors trong phạm vi được giao.
  - **Authored files (2/2):**
    1. `tool/verify-flutter-admin.ps1`
    2. `docs/phase-3/FLUTTER_ADMIN_ACCEPTANCE_20261023.md`
  - **Repair rounds:** 1 round điều chỉnh luồng PostgreSQL readiness & synthetic auth schema cho tương thích psql trên Windows.
- **Scope adherence:** Tuyệt đối không triển khai A1–A5/F/P, không chạm source sản phẩm `lib/`.
