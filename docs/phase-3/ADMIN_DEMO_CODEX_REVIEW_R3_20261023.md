# Review 363215b — đóng D1/D2, còn luồng địa điểm mới → app khách

> **Plan thực thi mới:** owner đã giao lập [plan Admin lưu → xuất bản → app khách thấy](ADMIN_SAVE_PUBLISH_VISIBILITY_PLAN_20261023.md). Antigravity dùng plan và prompt cuối tài liệu đó thay prompt tổng quát ở cuối review này. Plan chọn chuẩn hóa unverified DTO tại projection server để sửa cả drafts local đã thiếu fields, không cần sửa migration/live chỉ cho list defaults.

Ngày 23/10/2026. Reviewed/actual HEAD `363215b0079fc703022e9f0a39d6706c6dfc4e6c`, branch `codex/phase-3-discovery-design`. Diff từ `0b2320d`: 5 files, +104/-20 lines. Codex review, Antigravity code. Superpowers OFF. Không sửa implementation, deploy/live/thiết bị/AI thật hoặc merge trong lượt này.

**Kết luận:** hai blockers D1/D2 của [review trước](ADMIN_DEMO_CODEX_REVIEW_R2_20261023.md) **đã đóng bằng reviewer-run evidence**. Khi kiểm thêm yêu cầu owner “số địa điểm không cố định; admin lưu thì cả user/admin đều thấy”, phát hiện D3 làm app khách không đọc được địa điểm mới. D4 là kết nối UI còn thiếu: lưu hiện chỉ cập nhật nháp, không xuất bản; màn xuất bản chưa được route từ khu admin. Luồng lưu tự cập nhật app khách vừa trao đổi chưa được thực hiện trong commit sửa D1/D2 này.

Không mở lại hardening/race/retry/history/UI polish đã hoãn. Chỉ tập trung đường demo thêm/sửa/ẩn → lưu → app khách thấy đúng.

## Đóng hai findings trước

| Finding | Bằng chứng mới | Trạng thái |
|---|---|---|
| D1 — thiếu sources của facts/packages | Actual SQL seed → actual Node builder giữ 24 nguồn, 25 packages và 72 visit records; actual Dart parser đọc thành công. | CLOSED tại 363215b cho dữ liệu seed. Không suy mọi record tạo mới đã đúng schema. |
| D2 — DTO published dashboard không khớp | Fresh SQL response `{"version":"1","activePlaces":72,"sourceRevision":6,"activeDestinations":12}` parse qua actual DashboardSnapshot thành công. | CLOSED tại 363215b. |

Hai probes cũ không bị nới assertion: `expect(..., returnsNormally)` giữ nguyên. Trạng thái đóng dựa trên dữ liệu mới sinh từ SQL/Node hiện tại, không chỉ lời bàn giao author.

## D3 — [P1] Địa điểm admin tạo mới có visit facts thiếu fields bắt buộc, app khách từ chối bundle

**Location:** `supabase/migrations/20261023074312_admin_discovery_commands.sql:188`–`:214` (createPlace → new_detail).

CreatePlace sinh default facts unverified nhưng thiếu:

- `price.evidence.conditions` (array).
- `hours.evidence.conditions` (array).
- `hours.notes` (array).

Actual Dart consumer cần các list này: `_evidence` gọi `_strings(data['conditions'])`, `_hours` gọi `_strings(data['notes'])`; thiếu field làm `VisitDataException(list)`. Seed cũ đủ fields nên D1 và existing tests xanh không phát hiện lỗi của record mới.

**Reviewer-run reproduction:**

1. Database local biệt lập nạp actual migrations; tạo điểm đến `demo-new` và địa điểm con qua actual command RPC, sửa tên/ảnh và readback thành công.
2. Lấy actual version payload sau `update child`, khi điểm đến mới và địa điểm con vẫn active, trước khi archive parent.
3. Actual Node builder xuất **13 điểm đến / 73 visit records / 24 sources**, blockers rỗng.
4. Actual Dart PublicCatalogueParser parse bundle và manifest đúng hash/length: **FAIL `VisitDataException(list)`**, stack tại `_evidence` conditions.
5. Diagnostic control chỉ thêm ba list rỗng bị thiếu vào fixture, không sửa product source và không đổi parser: parse **PASS**, vẫn đủ 13 điểm đến và 73 địa điểm.

**Ảnh hưởng demo:** admin thấy thêm thành công, nhưng sau publication app khách giữ danh mục cũ vì bundle mới parse lỗi. Đây là record mới tạo bình thường, không phải giới hạn số lượng. SQL không khóa số lượng ở 72; actual probe đã lưu được địa điểm thứ 73.

**Sửa tối thiểu:** tạo unverified facts đầy đủ schema mà app khách đọc được; giữ unknown/unverified trung thực, không bịa giá/giờ hoặc đổi trạng thái reviewed. Xử lý cả draft records đã được tạo thiếu fields trong đợt local/demo để chúng không tiếp tục làm hỏng bundle; không tự apply migration hoặc sửa dữ liệu live.

**Nghiệm thu:** actual createPlace → readback draft → Node projection → Dart parser PASS. Thêm/hide một fixture mới làm số lượng thay đổi phù hợp; không yêu cầu tổng luôn bằng 72. Giữ validation và các facts seed cũ.

## D4 — [P1] Chưa có đường UI đưa dữ liệu lưu ra danh mục khách

**Locations:** `lib/features/admin/providers/admin_catalogue_provider.dart:160`–`:169`; `lib/features/admin/presentation/screens/admin_shell_screen.dart:220` (screens list); `lib/features/admin/presentation/screens/admin_publication_screen.dart` chỉ khai báo màn hình.

`submitDestination/submitPlace/archive*` đi tới `service.command`, gán `_snapshot=updatedSnap` rồi return true. Không gọi publication service/worker sau acknowledgement. Shell chỉ có Dashboard/Users/Catalogue/History. Search toàn `lib` thấy `AdminPublicationScreen` chỉ ở file khai báo, không có constructor use/import từ màn khác; loadPreview/confirmPublish chỉ được gọi bên trong màn chưa có đường mở đó.

**Ảnh hưởng demo:** thao tác lưu/ẩn chỉ thay draft. Kể cả D3 được sửa, người dùng không tự thấy thay đổi vì active manifest chưa được cập nhật. Hiện cũng không thể mở màn publication qua điều hướng admin thông thường để xuất bản thủ công.

**Phân biệt phạm vi:** D1/D2 fix không quảng bá là đã làm auto-publish. Việc “Lưu → tự cập nhật app khách” là thay đổi luồng theo yêu cầu owner vừa làm rõ; đây chưa phải tính năng đã hoàn thành chỉ vì các probes publication PASS.

**Kết quả cần bàn giao Antigravity:** nối thao tác thêm/sửa/ẩn thành luồng lưu draft → xuất bản revision vừa lưu → acknowledgement → app khách refresh nhận active release. Dùng backend publication đang có; không thêm thao tác “Xuất bản” riêng như điều kiện bắt buộc để thỏa yêu cầu lưu của owner. UI có thể hiển thị “đã lưu, đang đồng bộ”; chỉ báo đã hiển thị cho khách khi activation được xác nhận. Failure phải trung thực, không coi draft-save là customer visibility. Không thay quyền từ client hoặc bỏ bước hash/readback.

Đây là kết nối luồng chính đã có, không phải yêu cầu xây recovery nâng cao, đổi kiến trúc hoặc realtime từng mili giây. App khách hiển thị sau fetch/refresh/sync bình thường; không hứa cập nhật tức thời trên mọi thiết bị đang offline. Xóa theo nghiệp vụ hiện tại là archive/ẩn khỏi danh mục active, giữ lịch sử chuyến đi.

## Evidence và phạm vi checks

| Check | Kết quả | Nguồn |
|---|---|---|
| Hai consumer probes D1/D2 cũ | **2/2 PASS**, exit0 | Reviewer-run `.dart_tool/codex-admin-demo-review/r3-consumer.log` |
| Integrated SQL access/lock/unlock/CRUD/publication state | exit0, owned PG đã dừng | Reviewer-run `r3-sql.log`, `r3-dynamic-sql.log` trong cùng evidence folder |
| Node bundle + publication gateway | **10 PASS**, exit0 | Reviewer-run `r3-node.log`. Không dùng số 15 của handover cho command này. |
| Dynamic consumer: old dashboard, old seed, new place, normalized control | **3 PASS / 1 FAIL**, exit1; chỉ new-place raw payload FAIL | Reviewer-run `r3-dynamic-control.log`; dynamic bundle có 13 destinations/73 visit records. |
| Existing Full | Analyzer clean, 944 Flutter PASS, 89 Node PASS | **Author-run logs Codex đã đọc**, `.dart_tool/travelgo-verification/20261023T115504220Z-29120/`; không phải lượt Full Codex chạy mới. Source/head vẫn 363215b, không lặp Full chỉ vì đọc lại logs. |

Probes nằm trong ignored `.dart_tool/codex-admin-demo-review/`: `probe.ps1`, `probe.sql`, `build-probe.mjs`, `consumer_probe_test.dart`. Dynamic payload lấy historical version trước archive từ actual RPC fixture. Normalized control là bản sao fixture chỉ dùng chẩn đoán, **không phải bản sửa production và không được thay cho testcase đang fail**.

Commands tái hiện:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./.dart_tool/codex-admin-demo-review/probe.ps1
node ./.dart_tool/codex-admin-demo-review/build-probe.mjs dynamic-
node ./.dart_tool/codex-admin-demo-review/build-probe.mjs dynamic- normalized-
& 'D:/flutter/flutter/bin/cache/dart-sdk/bin/dart.exe' 'D:/flutter/flutter/bin/cache/flutter_tools.snapshot' --suppress-analytics test --no-pub --reporter expanded .dart_tool/codex-admin-demo-review/consumer_probe_test.dart
```

Không có thay đổi server/thiết bị thật. Auth acknowledgement trong SQL probe là synthetic; không suy thành Auth ban/unban staging đã nghiệm thu. UI routing finding là source trace, chưa thao tác app trên thiết bị.

## Corrections nhỏ cho handover, không tạo thêm blocker

Tên các mục DEFERRED trong bản bàn giao bị đổi nghĩa: R1 là worker ACL/null-token; R5 là locked-admin window; R9 là guard404 fail-open; R10 là publication recovery; R11 là request identity; R12 là history parameters. Chúng không phải toàn bộ là UI polish. Giữ đúng evidence/trạng thái hoãn của review gốc; không yêu cầu sửa chúng trong gói demo này.

## Giải thích và prompt sửa tiếp

Luồng dữ liệu có hai điều kiện khác nhau: **đọc được record mới** và **đưa record đó sang danh mục public**. D3 hỏng điều kiện đầu; D4 thiếu điều kiện sau. Chỉ kiểm số lượng records hoặc việc admin nhìn thấy draft không chứng minh user đã nhận dữ liệu.

**Changed:** Antigravity sửa 5 implementation/test files ở 363215b; Codex tạo report và mở rộng reviewer fixture cho trường hợp thêm mới. **Why/Testing:** đóng D1/D2 bằng probes cũ; thêm record mới qua actual RPC rồi consumer thật để kiểm yêu cầu không giới hạn seed. **Problems:** D3/D4 còn chặn luồng admin-save→customer-visible; local checks không thay runtime thật. **Lesson Candidate:** tạo thành công ở producer phải đi cùng schema hợp lệ ở consumer; lưu draft và publish là hai bước riêng, cần nối tường minh nếu UI hứa lưu là khách thấy.

```text
Codex review 363215b: D1/D2 đã đóng, không sửa lại chúng hoặc các findings DEFERRED. Đọc docs/phase-3/ADMIN_DEMO_CODEX_REVIEW_R3_20261023.md. Tập trung đúng hai phần còn thiếu trong luồng demo theo yêu cầu owner:

D3: createPlace sinh facts unverified thiếu price.evidence.conditions, hours.evidence.conditions và hours.notes; actual SQL tạo được địa điểm thứ73 nhưng Dart parser từ chối bundle. Sửa schema defaults và xử lý draft local đã thiếu fields; không bịa facts hoặc bỏ validation. Giữ testcase dynamic raw payload cho đến khi PASS, không lấy normalized diagnostic fixture làm input thật.

D4: lưu hiện chỉ ghi nháp, publication screen chưa được nối từ admin. Nối thêm/sửa/ẩn → lưu → tự xuất bản revision vừa lưu → xác nhận kết quả → app khách refresh thấy đúng; không bắt owner bấm xuất bản riêng để đạt yêu cầu mới. Giữ quyền server và hash/readback, báo trạng thái lưu/đồng bộ trung thực. Không mở recovery/race nâng cao hoặc UI polish.

Giữ Codex plan/review, Antigravity code/tests. Bảo toàn dirty owner work, không weaken assertions, auto-install/native/deploy/live mutation/thiết bị/merge, không tự bật Superpowers. Kiểm seed hiện có vẫn đọc được và thêm/ẩn record mới làm cả admin/customer đổi số lượng đúng; số72 chỉ là seed fixture. Chạy checks liên quan và Full một lần ở source cuối. Bàn giao exact commit/diff, commands/exits/logs và phân biệt local/mock/chưa runtime thật. Không cần xin giao từng hạng mục hoặc thêm calls.
```
