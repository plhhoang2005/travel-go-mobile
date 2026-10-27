# C5 — Bàn giao Codex, 26/10/2026

**C5 source/automated và SQL contract local PASS; tự review đạt trong phạm vi đã kiểm.** Chưa nghiệm thu cloud hoặc app trên thiết bị. Owner đã duyệt [plan C5](COURSEWORK_C5_IMPLEMENTATION_PLAN_20261025.md) và yêu cầu tiếp tục. Không dùng Superpowers cho Codex; không giao code cho Antigravity trong gói này.

Checkout `D:/Travel-Go-Android/travel-go`, branch `fix/ai-planning-stability`, base HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` cộng dirty C1–C5. Chưa commit/push/merge/deploy, không có PR mới. Giữ các file riêng của owner và thay đổi C1–C4.

## 1. Changed

| File | Thay đổi C5 |
| --- | --- |
| `lib/features/trip_planner/services/manual_trip_factory.dart` | Giữ tên tự nhập khi ID null; ID sai cú pháp bị từ chối thay vì âm thầm biến thành null |
| `lib/features/trip_planner/services/editable_trip_validator.dart` | Account save cần tên hợp lệ; không bắt tên tự nhập phải có ID catalogue |
| `lib/features/trip_planner/presentation/widgets/manual_trip_input_form.dart` | Nhập/sửa tên tự nhập, giữ tên khi chỉ sửa ngân sách, giữ ID/tên lịch sử chưa có trong catalogue tải về |
| `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart` | Thêm chính sách `accountSaveOnly`; khách bấm lưu nhận thông báo, document không đổi |
| `lib/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart` | Bật chính sách lưu tài khoản cho đường Home/Khám phá vào editor |
| `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart` | Bật cùng chính sách ở hai đường mở editor/copy chuyến đi |
| `test/coursework_trip_roundtrip_test.dart` | 12 regressions/controls mới; factory/form, tiền, account roundtrip và lost ACK qua provider/repository/service thật với fake transport/local SQLite |
| `test/manual_discovery_flow_test.dart` | Đổi yêu cầu lưu khách từ đường sản phẩm thành kiểm yêu cầu tài khoản; giữ assertion engine/AI0, document nguyên và không có bản lưu giả |
| `supabase/migrations/20261025163015_coursework_manual_destination.sql` | Forward migration: tên tự nhập, crypto schema, owner/account guard, head ownerId, version/locks/write permits; giữ catalogue membership |
| `supabase/tests/coursework_trip_roundtrip.sql` | RPC thật với role authenticated/anon trên PostgreSQL local, positive/negative controls |
| `tool/verify-coursework-trips.ps1` | DB local riêng trên loopback/cổng ngẫu nhiên, xuất fixture từ codec Dart, SQL fail nonzero, dừng đúng server do runner tạo |

Tổng cộng **7 file hiện có đổi so checkpoint C4 và4 file mới** trong code/test/SQL/tool. Không đổi công thức ngân sách, dependency, native config, AI gateway hay schema lịch sử. 14 migration cũ khớp byte với bản sao trước C5.

Helper guest/import và khả năng đọc dữ liệu cũ vẫn giữ cho tương thích; các đường editor đang dùng trong app bật accountSaveOnly. Các test standalone của thư viện không phải entry point sản phẩm. Chặn ở UI không thay thế quyền server: anon/wrong owner/locked account vẫn phải bị từ chối ở RPC.

## 2. Why — luồng và nguyên nhân

Ví dụ user tự nhập “Phú Yên”: form → factory → document có destinationId=null/name Phú Yên → preview → xác nhận → repository đóng băng payload/requestId → RPC kiểm quyền/validation → lưu → list/read → mở editor sửa → update đúng trip/version → xóa khi xác nhận. Hủy preview không gửi request. Lưu và sửa vẫn là hai thao tác có ACK; UI không tự coi request đã gửi là đã lưu.

Trước C5, factory bỏ tên nếu không có ID, form chỉ đọc tên từ catalogue và account validator/server còn buộc ID. Codec riêng lẻ đã hỗ trợ null-ID nên test codec PASS chưa đủ. Bản sửa giữ tên xuyên các lớp, không tạo slug giả hoặc bỏ kiểm catalogue cho ID thật. Chỉ sửa ngân sách hoặc mở chuyến có ID lịch sử cũng phải giữ tên và ID đang có.

SQL local còn tái hiện update bị `versioned_write_required`: migration dynamic-ID cũ thay RPC nhưng bỏ write permit, khóa hàng và một số kiểm quyền/head fields. Migration mới khôi phục RPC nền có guards, thêm membership động vào đúng chỗ, dùng p32_owner từ bản admin guard có kiểm enabled account và giữ ownerId trong head để client xác thực ACK. Không gỡ trigger để làm update qua được.

Tiền giữ hai sổ:2 người ×100.000 +50.000 =250.000 dự kiến; đã chi70.000; ngân sách1.000.000 cho hai số dư750.000 theo dự kiến và930.000 theo đã chi. Đổi3 người chỉ đổi dự kiến thành350.000; actual70.000 giữ nguyên. Unknown vẫn là unknown. Xóa hoạt động giữ actual và snapshot nguồn; không tự xóa khoản đã thanh toán.

## 3. Testing — evidence thực tế

Mọi đường dẫn `.dart_tool/` bên dưới tương đối với repo, là artifact ignored giữ trên máy này.

| Kiểm tra | Kết quả / evidence |
| --- | --- |
| RED đầu tiên | `client-red.log`:1 PASS/6 FAIL;3 gap thật ở factory/validator/form. Ba failure còn lại do fixture tạo hai active estimates cùng item, codec từ chối đúng; đã sửa fixture, không tính là3 lỗi app |
| RED lưu khách | `guest-gate-red.log`: thông báo yêu cầu đăng nhập chưa xuất hiện trước guard; sau sửa PASS |
| SQL null-ID RED | `.dart_tool/coursework-trip-sql/a3c766826fbd4c20846a80025ab9d7b1/coursework-roundtrip.log`: `invalid_input` tại validator |
| SQL update RED | `.dart_tool/coursework-trip-sql/5b100d8ea8044c66a8bb9bacd1af211c/coursework-roundtrip.log`: update thiếu permit bị trigger từ chối |
| Targeted rộng |162/162, exit0; `.dart_tool/c5-codex-implementation/targeted.log` |
| Targeted sau correction/test bổ sung |27/27, exit0, gồm12 C5 +8 discovery +7 legacy import; `targeted-correction.log` |
| Full cuối | Analyzer0 issues; **Flutter1100/1100; Node91/91**, exit0; `full-final.log`, log chi tiết `.dart_tool/travelgo-verification/20261026T021852648Z-4840/` |
| SQL cuối | PASS, exit0; `sql-final-expanded.log`; DB riêng `.dart_tool/coursework-trip-sql/97a01c01bd94478c8b9f64928ac13f28/`, `coursework-roundtrip.log` và `stop.log` |
| Runner negative self-test | PASS, exit0 cho self-test, SQL cố ý lỗi trả nonzero; `.dart_tool/coursework-trip-sql/2cb6f091b06d44368fdd14a238ac8ecd/expected-error.log`; stop.log xác nhận server stopped |
| Diff/snapshot | `git diff --check` exit0; snapshot383 files0 drift sau Full;14 migration cũ không đổi |

Lượt Full đầu có1096 PASS/2 FAIL (`full.log`): test Discovery vẫn yêu cầu guest save trái scope; đã sửa expectation và giữ assertions bảo vệ dữ liệu. Test import cũ vượt helper chờ2 giây: nguyên file đạt7/7 khi chạy riêng (`import-isolated.log`), đạt lại trong targeted27 và Full cuối. **Không đổi helper chờ/timeout hay assertion import**, chưa kết luận nguyên nhân gốc của failure gián đoạn đó. Node chưa chạy ở Full đầu vì runner dừng tại Flutter failure;91/91 là kết quả Full cuối.

SQL cuối kiểm: self-entered/name UTF8; blank/whitespace/oversize/malformed ID reject; exact canonical bytes và ownerId trong ACK; create/read/list/update/delete; replay cùng request không tạo trùng; sai digest/request identity reject; stale version conflict; direct table write reject; B không read/list/update/delete A; locked account reject; anon denied; legacy Hue; dynamic ID active tạo được, inactive không tạo mới được, trip đang dùng historical ID vẫn sửa được. Release rows là fixture synthetic để kiểm helper membership, không phải nghiệm thu admin publication pipeline.

Lệnh chính đã chạy:

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/coursework_trip_roundtrip_test.dart,test/manual_discovery_flow_test.dart,test/editable_guest_import_ui_test.dart
./tool/verify-coursework-trips.ps1
./tool/verify-coursework-trips.ps1 -SelfTest
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Snapshot `.dart_tool/c5-codex-implementation/final-source-snapshot.json` gồm379 files kế thừa C4 +4 file C5 mới, SHA256 `38bf4d2df67e408f2e01f805409446217face4552aa08143b873d073b1fcde38`; **không có migration lịch sử trong379 file C4**. Chúng được kiểm riêng bằng `historical-migration-hashes.json` (14/14). Danh sách hash11 file C5 ở `c5-scoped-hashes.json`; diff so bản sao trước C5 ở `reviewed-change.patch`. Snapshot không có nghĩa source đã commit.

## 4. Problems / giới hạn còn lại

**Chuỗi migration lịch sử nguyên trạng chưa được chứng minh cài mới thành công.** Runner nạp baseline/migrations thật vào DB mới nhưng cần3 adapters chỉ trên bản sao local: bỏ constraint contype=n khỏi fingerprint PG17 khi chạy PG18 (attnotnull vẫn được kiểm); schema-qualify digest của migration dynamic-ID; giữ tên tham số p32_utc(v) thay vì đổi thành t trong CREATE OR REPLACE. Runner cũng dựng auth schema tối thiểu và migration history synthetic.14 file lịch sử trong repo không bị sửa. Forward migration sửa các định nghĩa cuối liên quan C5; không thể tự giải quyết việc một migration cũ lỗi trước khi chạy tới nó. Vì vậy SQL PASS chứng minh contract cuối trên fixture tương thích, **không phải PASS deploy/reset toàn chain hoặc staging Supabase**.

Chưa apply migration mới lên cloud; backend/app đang deploy chưa được chứng nhận có hành vi mới. Chưa build/install/hot reload, mở app/thiết bị, gửi email/AI thật hoặc nghiệm thu mạng thật. C3/C4 email/native acceptance vẫn riêng. Không nâng runtime/SDK, không tự thay key/model/quota. Fixture local không mô phỏng mọi chi tiết Supabase Auth/PostgREST, và không chạy concurrency stress/staging runner.

Review là **self-review của Codex**, không có reviewer độc lập. Chưa phát hiện finding mới cần sửa trong diff C5 đã kiểm; limitation bootstrap và test import gián đoạn vẫn được ghi, không dùng PASS cuối để xóa lịch sử failure. Thêm behavior repair hoặc live rollout ngoài C5 phải theo scope/guard/approval tương ứng, không reset repair budget bằng tên task mới.

## 5. Lesson Candidate / tiếp theo

Problem: codec hỗ trợ tên tự nhập nhưng lưu xuyên app/server vẫn lỗi → Root Cause: contract chỉ được kiểm ở một lớp và RPC sau ghi đè guards cũ → Actionable Rule: kiểm vòng UI/factory/validation/RPC/read với positive và negative controls; khi CREATE OR REPLACE phải đối chiếu quyền, locks, permits và reply schema của các định nghĩa trước.

Problem: local SQL xanh có adapters → Root Cause: version catalogue hệ thống và lỗi bootstrap lịch sử khác contract sản phẩm → Actionable Rule: ghi rõ adapter/prerequisites, giữ hash lịch sử và tách kết luận final-contract PASS khỏi fresh-deploy PASS.

Bước kế tiếp theo master plan là **rà soát/lập plan C6 (admin user/account và khám phá)**; chưa bắt đầu code C6. Việc deploy C5 hoặc nghiệm thu thiết bị cần task và môi trường được owner cho phép riêng.
