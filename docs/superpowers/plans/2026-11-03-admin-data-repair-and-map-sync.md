# Admin Data Repair and Map Sync Implementation Plan

> **For agentic workers:** Khi owner giao triển khai và yêu cầu Superpowers, dùng superpowers:executing-plans để thực hiện từng task. Không tự spawn subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khôi phục danh sách người dùng và làm cho thay đổi danh mục được lưu/xuất bản/thể hiện trên bản đồ đúng, không tạo trùng khi thử lại.

**Architecture:** Giữ Flutter/Provider/service hiện có, admin-control và pipeline publication hiện có. Chẩn đoán hợp đồng đang deploy trước khi chọn sửa client hay SQL; public snapshot đã xuất bản là nguồn dữ liệu chung cho khám phá và bản đồ.

**Tech Stack:** Flutter/Dart, Provider, Dio, Supabase Edge Functions, PostgreSQL/pgcrypto, Node contract tests.

**Spec:** `../specs/2026-11-03-admin-catalogue-local-ai-assessment.md` (bản đề xuất, chờ owner duyệt triển khai gói 1).

## Global Constraints

- Gói 1 là ưu tiên trước mọi mở rộng. Các gói sau là roadmap, không phải toàn bộ đã được duyệt code.
- Không thêm dependency/framework hoặc thay kiến trúc chỉ để làm các mục này.
- Lưu nháp không đổi dữ liệu khách hàng.
- Thử lại xuất bản không gửi lại lệnh tạo.
- Không cho admin sửa ngân sách hoặc khoản chi riêng của chuyến đi khách hàng.
- Không mở rộng GPS, dẫn đường hay bản đồ mới trong gói sửa này.
- Không dùng Demo Sandbox hoặc dữ liệu giả để báo server đã hoạt động.
- Giữ bốn file admin đang dirty và các SQL chưa được theo dõi; ghi baseline, review diff trước khi sửa; không reset/commit gộp thay đổi ngoài task.
- Chỉ áp dụng SQL lên môi trường đang dùng sau khi có migration cụ thể được review và phạm vi triển khai được owner cho phép. Không cần hỏi lại cho từng thao tác local thuộc gói đã duyệt.
- Khi thực thi tạo nhánh `codex/admin-data-repair-map-sync` hoặc checkout cô lập phù hợp; không push main. Handoff Antigravity phải ghi rõ chỉ thị owner: coding luôn dùng Superpowers phù hợp.

## Review Focus

1. Phiên admin bị thu hồi hoặc đổi account trong lúc tải: hủy/bỏ kết quả cũ, không giữ quyền hay dữ liệu tài khoản trước (Task 1).
2. Draft đã lưu nhưng publication timeout/thất bại: không tạo bản ghi thứ hai, không báo đã công khai (Task 3).
3. Retry/concurrent publication với cùng request: giữ idempotency/hash/revision, không phát hành nhầm draft (Task 2–3).
4. Snapshot đổi khi đang chọn một điểm đến/marker: rebind theo ID hoặc bỏ chọn, không giữ địa điểm đã ẩn (Task 4).
5. Tọa độ rỗng/sai và điểm đến có con bị ẩn từ trước: không tạo pin giả, không bật lại mọi điểm con khi chỉ muốn hiện điểm đến (Task 3–4).

## Task 0: Khoanh vùng lỗi server bằng bằng chứng đọc

**Files:** Read `lib/features/admin/services/admin_account_service.dart`, `models/admin_account_models.dart`, `providers/admin_account_provider.dart`, `supabase/functions/admin-control/gateway.mjs`; các migration/account SQL hiện có. Create `docs/phase-3/ADMIN_DATA_DIAGNOSTIC_20261103.md` khi thực hiện.

**Interfaces:** giữ `admin-control` contract `travelgo.admin.v1`, action `users`, request gồm `query`, `limit` và role/state/cursor khi có. Output là kết luận lớp lỗi cùng HTTP status, mã đã khử thông tin riêng, request ID và SQLSTATE nếu có.

- [ ] Ghi HEAD, hash/diff bốn file dirty; xem lại SQL/script chưa theo dõi trước khi cân nhắc dùng. Không chạy script chứa credential hoặc ghi DB để chẩn đoán.
- [ ] Dùng phiên admin thật được owner cấp trong luồng hiện có; tái hiện all/admin/customer, query rỗng/có nội dung, trang đầu/trang tiếp theo. Không in token, email hay toàn bộ danh sách vào log bàn giao.
- [ ] Đọc phiên bản Edge Function, RPC signature/return type, schema cột và policy liên quan. Kiểm tra joins `auth.users`, `public.profiles`, `private_admin.account_access`, giá trị role/state và kiểu cursor đúng với deployment thực tế.
- [ ] Ghi test fixture đã bỏ PII cho lỗi thật. Phân biệt 401/403, RPC missing/schema error, server 5xx, DTO decode và offline; không quy mọi lỗi về mạng hay digest.
- [ ] Kiểm tra read-only extension namespace, overload digest, định nghĩa prepare/stage/begin đang deploy và migration ledger. Kết quả là cách sửa tối thiểu có căn cứ cho Task 1–2; nếu không truy cập được môi trường ghi rõ giới hạn, vẫn viết regression fixtures ở local.

**Gate:** Task này không sửa function server. Lỗi users chưa xác định lớp thì chưa chọn chạy `fix_admin_accounts.sql`.

## Task 1: Phục hồi danh sách người dùng và giữ quyền đúng

**Files:** Modify theo chẩn đoán: `lib/features/admin/services/admin_account_service.dart`, `lib/features/admin/providers/admin_account_provider.dart`, `lib/features/admin/models/admin_account_models.dart`, `supabase/functions/admin-control/gateway.mjs`. Nếu cần SQL, tạo `supabase/migrations/20261103190000_repair_admin_accounts_read_contract.sql` sau khi kiểm tra tên chưa tồn tại. Tests: `test/admin_account_service_test.dart`, `test/admin_account_provider_test.dart`, `test/admin_account_ui_test.dart`, `test/admin_control_gateway_test.mjs`, `supabase/tests/coursework_admin_account_contract.sql`.

**Interfaces:** bảo toàn `loadUsers({bool nextPage = false}) → Future<void>` và users envelope hiện có. Sửa tối thiểu đúng lớp gây lỗi; không thêm quyền client/service role. Lỗi kỹ thuật chi tiết ở log có request ID, thông báo UI theo nhóm lỗi và có thử lại.

- [ ] Viết regression test từ Task 0: danh sách all/customer trả đúng DTO, nullable fields, trang tiếp theo không trùng/mất dòng; test lỗi đã xác nhận phải fail trên baseline vì đúng nguyên nhân.
- [ ] Bổ sung test forbidden/admin revoked/account switch trong pending load: không giữ dữ liệu admin cũ; xem kỹ diff dirty hiện tại chỉ gọi `_fail` với `account_locked` có bỏ sót cleanup không.
- [ ] Chạy `flutter test test/admin_account_service_test.dart test/admin_account_provider_test.dart test/admin_account_ui_test.dart` và `node --test test/admin_control_gateway_test.mjs`; ghi assertion lỗi trước sửa.
- [ ] Sửa lớp đã xác nhận; nếu SQL lỗi, tạo migration nhỏ thay vì chép toàn bộ function untracked. Giữ lọc/phân trang server-side và quyền caller. Nếu chỉ mapping client sai thì không thêm migration.
- [ ] Chạy lại nhóm test trên; chạy account SQL qua harness ở Task 5. Nghiệm thu backend thật tách riêng, không dùng test mock để kết luận deployment đã sửa.
- [ ] Review diff và commit chọn lọc phần task, không stage cả file dirty nếu còn thay đổi ngoài phạm vi.

## Task 2: Sửa resolve digest trong toàn pipeline publication

**Files:** Read `supabase/migrations/20261027063524_coursework_catalogue_publication_retry.sql`, `20261023160000_discovery_publication_v2.sql`; review migration local `20261103140000_fix_pgcrypto_digest.sql` và `supabase/fix_prepare_discovery_preview.sql`. Create migration chuẩn `supabase/migrations/20261103190100_repair_discovery_digest_schema.sql` nếu chưa có bản tương đương được quản lý. Modify `supabase/tests/coursework_catalogue_publication_retry.sql`, `supabase/tests/discovery_publication.sql`, và `tool/verify-flutter-admin.ps1` để harness áp dụng migration sửa trước các assertion liên quan.

**Interfaces:** giữ prepare preview, stage payload và begin publication RPC hiện có, bao gồm requestId, expectedRevision, preview hash/expiry và idempotency. Không thay thuật toán hash/freeze để né lỗi resolve function.

- [ ] Tạo regression với pgcrypto trong namespace deployment thực tế (ví dụ `extensions` khi Task 0 xác nhận), search_path tương đương production; đi qua preview → stage → publish. Assert không có SQLSTATE 42883; giữ test hash/revision/permission hiện có.
- [ ] Chạy `./tool/verify-flutter-admin.ps1 -Mode Publication`, xác nhận regression fail đúng do digest resolve (không coi thiếu PostgreSQL/tool là regression fail hợp lệ).
- [ ] Chọn schema-qualified digest đúng extension trong các function bị ảnh hưởng hoặc wrapper tối thiểu nếu hợp đồng thực sự cần. Sửa cả hash preview, stage và request; giữ SECURITY DEFINER/search_path/ACL đang được bảo vệ. Không grant anon rộng chỉ vì bản fix tạm có grant đó; kiểm thử theo các role thực tế.
- [ ] Xử lý môi trường extension đã có ở namespace khác bằng kiểm tra rõ ràng; không di chuyển extension hoặc tạo wrapper gọi sai schema một cách mù quáng. Đối chiếu bản migration untracked để không áp dụng hai phương án chồng nhau.
- [ ] Chạy lại harness Publication; assert request lặp không tạo publication mới, stale revision bị từ chối, customer/anon không được ghi và public bundle không chứa mục ẩn.
- [ ] Review migration + rollback/khôi phục function definition trước khi deploy; không rollback bằng xóa dữ liệu publication. Commit chọn lọc; đưa SQL cụ thể cho owner khi cần quyền triển khai.

## Task 3: CRUD trung thực, retry không trùng và dữ liệu vị trí rõ ràng

**Files:** `lib/features/admin/providers/admin_catalogue_provider.dart`, `models/admin_catalogue_models.dart`, `presentation/screens/admin_shell_screen.dart`, `presentation/widgets/admin_place_form.dart`, `presentation/widgets/admin_destination_form.dart`. Tests: `test/admin_catalogue_provider_test.dart`, `test/admin_catalogue_forms_test.dart`, `test/admin_catalogue_publish_flow_test.dart`, `test/admin_publication_provider_test.dart`.

**Interfaces:** giữ `submitDestination(AdminDestinationDraft,String)`, `submitPlace(AdminPlaceDraft,String)`, `archiveDestination(String,String)`, `archivePlace(String,String)` trả `Future<bool>`; dùng state savePhase/savedRevision/operation hiện có để phân biệt kết quả, không suy từ bool duy nhất. `retrySave()` phải tiếp tục thao tác cũ đúng trạng thái, không mint create request mới sau acknowledged save.

- [ ] Viết test create được lưu nhưng preview báo digest error; nhấn thử lại chỉ gọi publication từ saved revision, create count vẫn bằng 1. Thêm pending/unknown outcome và double tap: không mint request mới để né idempotency.
- [ ] Test lưu nháp thành công rồi public refresh lỗi: UI báo đúng đã xuất bản nhưng tải dữ liệu mới lỗi, không báo lưu thất bại và không tạo lại dữ liệu.
- [ ] Test trường active: không cho công tắc giả thao tác hỗ trợ. Trong gói sửa dùng lệnh archive rõ ràng và trạng thái chỉ đọc khi chưa có command restore từng mục; không dùng `restoreVersion` để bật lại một mục. Nếu muốn restore từng mục, phải tách thiết kế command/server/tests riêng trước khi thêm nút.
- [ ] Test tên/mô tả trống, slug trùng, tọa độ không đủ cặp/ngoài khoảng; tọa độ mẫu không âm thầm thành tọa độ xác minh. Thiếu tọa độ phải được lưu là chưa có vị trí khi schema cho phép; nếu schema không cho phép thì yêu cầu nhập tọa độ thật, không dùng mặc định Hà Nội.
- [ ] Chạy `flutter test test/admin_catalogue_provider_test.dart test/admin_catalogue_forms_test.dart test/admin_catalogue_publish_flow_test.dart test/admin_publication_provider_test.dart`; xác nhận các case mới fail đúng trước sửa.
- [ ] Sửa bằng state machine hiện có: khi server đã xác nhận draft save, kết thúc phần create/edit của form, giữ thông báo “Đã lưu nháp, chưa xuất bản” và thao tác tiếp tục publication cho revision đó. Không tạo banner lặp và snackbar lỗi đỏ cho cùng một sự kiện đã được ghi nhận. Giữ nội dung form khi chưa lưu hoặc chưa rõ kết quả.
- [ ] Chạy lại nhóm test; review archive cascade không làm mất lịch trình cũ. Không tự xóa các bản ghi thử nghiệm tên “2/3” của owner.
- [ ] Commit chọn lọc sau khi kiểm tra baseline dirty.

## Task 4: Bản đồ phản ánh snapshot đã xuất bản

**Files:** `lib/features/map/presentation/screens/catalogue_discovery_map_screen.dart`; kiểm tra binding trong `lib/main.dart`, `lib/features/admin/presentation/screens/admin_shell_screen.dart` và PublicCatalogueProvider bằng `rg` trước khi sửa, chỉ sửa binding nếu regression chứng minh thiếu. Tests: `test/catalogue_discovery_map_screen_test.dart`, `test/map_feature_test_suite.dart`, `supabase/tests/admin_catalogue_visibility.sql`, `test/admin_publication_gateway_test.mjs`.

**Interfaces:** bản đồ lấy catalogue từ public snapshot, không đọc draft. `_selectedDestination`/selected marker được rebind bằng ID mỗi khi version/hash public snapshot đổi; ID bị ẩn thì bỏ chọn. Lệnh ẩn có tác động toàn hệ thống phải qua provider/server/publication, không qua Set trong màn hình.

- [ ] Viết test snapshot A có marker X; snapshot B ẩn X trong lúc đang drilldown → X biến mất và panel không giữ dữ liệu cũ. Ẩn destination loại các con ở public view; không sửa dữ liệu chuyến đi đã lưu.
- [ ] Test draft thêm/hide không ảnh hưởng bản đồ trước publication; sau publish+refresh dùng version/hash mới; refresh lỗi giữ cache có trạng thái cũ rõ ràng.
- [ ] Test tọa độ thiếu không tạo marker ở tâm hoặc offset giả; danh sách vẫn ghi “Chưa có vị trí”. Tọa độ hợp lệ nằm đúng lat/lng đã xuất bản.
- [ ] Chạy `flutter test test/catalogue_discovery_map_screen_test.dart test/map_feature_test_suite.dart`; xác nhận regression cần sửa.
- [ ] Bỏ hành vi snackbar khẳng định “Admin đã ẩn” cho state cục bộ. Gói này ưu tiên điều hướng admin tới biên tập danh mục để ẩn rồi xuất bản; không dựng luồng ghi khác riêng cho map. Rebind selected IDs khi snapshot đổi và bỏ fallback marker giả.
- [ ] Chạy lại nhóm test và tests bundle/publication. Kiểm tra chức năng khám phá không lấy nhầm draft.
- [ ] Commit chọn lọc.

## Task 5: Kiểm chứng gói sửa và bàn giao

**Files:** update `docs/phase-3/ADMIN_DATA_DIAGNOSTIC_20261103.md`; create `docs/phase-3/ADMIN_DATA_REPAIR_HANDOVER_20261103.md` sau khi thực hiện. Không ghi PASS trước khi có output.

- [ ] Chạy `./tool/verify-flutter-admin.ps1 -Mode All` để bao gồm account/draft/publication và PostgreSQL test harness. Nếu thiếu dependency/môi trường ghi BLOCKED cụ thể; không tính là pass. Đảm bảo migration Task 2 được harness áp dụng.
- [ ] Chạy `node --test test/admin_account_gateway_test.mjs test/admin_control_gateway_test.mjs test/admin_discovery_commands_test.mjs test/admin_discovery_web_test.mjs test/admin_publication_gateway_test.mjs test/admin_publication_storage_test.mjs`.
- [ ] Chạy `./tool/verify-travelgo.ps1 -Mode Full`; phải ghi exit code và log thực tế cho `flutter analyze`, `flutter test` và các contract suite. Full không thay thế Admin SQL harness hay kiểm thử môi trường thật.
- [ ] Sau khi có quyền deploy cần thiết, áp dụng đúng migration/Edge Function thay đổi và ghi version triển khai. Không chỉ cài APK rồi coi database đã sửa.
- [ ] Trên điện thoại thật: admin A xem all/customer/search/page; lưu destination/place; publication thất bại có kiểm soát → retry không trùng; sửa/ẩn/xuất bản. Khách B refresh thấy đúng version/hash, danh sách và map nhất quán. Kiểm tra mở lại app, cache offline, permission revoked và draft chưa xuất bản. Dùng tài khoản test phù hợp, không sửa dữ liệu riêng khách thật.
- [ ] Ghi trường hợp chưa chạy riêng. Bàn giao tiếng Việt: vừa sửa gì/ảnh hưởng người dùng, Changed, Why, Testing, Problems, Lesson Candidate; kèm HEAD/backend version/APK hash khi có.

## Ngoài gói này

Không tích hợp chatbot mới, không thay UI quản trị AI hoặc thêm quyền dữ liệu ngân sách trong gói sửa. Các mục đó có hướng trong assessment và cần plan riêng sau khi owner duyệt. Việc lập plan hiện tại không thay đổi hành vi app hay trạng thái backend.
