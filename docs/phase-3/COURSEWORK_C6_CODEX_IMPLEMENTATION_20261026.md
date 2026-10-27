# C6 — Bàn giao Codex, 26/10/2026

**C6 source/automated và SQL contract local PASS; Codex self-review đạt trong phạm vi đã kiểm.** Owner trả lời “duyệt” cho [plan C6](COURSEWORK_C6_IMPLEMENTATION_PLAN_20261026.md) trong session này. Codex triển khai và tự review, không dùng Superpowers/subagent. Chưa nghiệm thu cloud/native hoặc review độc lập.

Checkout `D:/Travel-Go-Android/travel-go`, branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1–C6/owner work. Không commit/push/merge/deploy, không apply cloud hoặc khóa user thật. Trước sửa: snapshot C5 383 files không drift, 14 migration lịch sử giữ hash.

## 1. Changed

So bản sao trước C6: **22 file hiện có và 7 file mới** trong code/test/SQL/tool. Evidence `.dart_tool/c6-codex-implementation/scope.json`, `before/source-snapshot.json`, `reviewed-change.patch` (chỉ diff C6, không dùng diff HEAD để quy toàn dirty tree cho C6).

| Nhóm | Files và vai trò |
| --- | --- |
| Account state/transport | `lib/features/admin/providers/admin_account_provider.dart`: context/epoch guards, query/filter/cursor, frozen attempts, readback/reconcile/resume. `services/admin_account_service.dart`: caller trước lazy loader, strict ACK và lỗi không chắc kết quả. `models/admin_account_models.dart`: pending operation trong detail, lỗi tiếng Việt |
| Admin UI | `lib/features/admin/presentation/screens/admin_shell_screen.dart`: vào Người dùng, bỏ entry Tổng quan và call dashboard chỉ dành entry đó. `admin_users_screen.dart`: loading/error/pagination, clear query, status wrap, truyền Provider qua route. `admin_user_detail_screen.dart`: retry đúng attempt, reason giữ, resume pending, bỏ nút promote/demote. `lib/features/profile/presentation/screens/profile_screen.dart`: copy đúng scope |
| Khám phá | `lib/features/explore/providers/discovery_provider.dart`: tìm cả place, chuẩn hóa vùng, giữ catalogue khi lỗi refresh. `presentation/screens/explore_screen.dart`: nhãn lỗi dữ liệu cũ, clear query/filter, chỉ dẫn place khớp. `destination_detail_screen.dart`: catalogue/facts/source cùng snapshot, chặn CTA khi bị ẩn. `presentation/widgets/destination_reference_list_tile.dart`: nhãn place khớp |
| Server | `supabase/functions/admin-control/gateway.mjs`: receipt không dispatch lại; SQL cấp quyền dispatch trước Auth, kiểm completion identity. Mới `supabase/migrations/20261026025306_coursework_admin_account_consistency.sql`: authSynced thật, token/revision/actor/session fences, dispatch một lần, reconcile theo request identity; detail có pending operation không chứa worker token |
| SQL tests/tools | Mới `supabase/tests/coursework_admin_account_contract.sql`, `tool/check-coursework-admin-vectors.mjs`. Sửa `supabase/tests/admin_account_control.sql` positive fixture dùng token/revision thực. `tool/verify-flutter-admin.ps1` chạy đủ account Dart/Node, so SQL vectors và xác minh stop. `tool/verify-coursework-trips.ps1` kiểm thêm control/concurrency/guards/C6 trên schema cuối |
| Tests | Sửa `test/admin_account_{provider,service,ui}_test.dart`, `admin_navigation_test.dart`, `admin_control_gateway_test.mjs`, `discovery_provider_test.dart`, `coursework_navigation_test.dart`. Mới `coursework_admin_account_flow_test.dart`, `coursework_discovery_flow_test.dart`, `coursework_admin_contract_test.mjs`, `fixtures/coursework_admin_account_vectors.json` |

Giữ backend promote/demote, last-admin/self-change guards, model và standalone dashboard tests; chỉ thu đường UI được duyệt. Không sửa auth C3/C4, calculator, dependency/native config, 14 migration lịch sử hoặc C5 forward migration. Tài liệu C6/master/core cập nhật checkpoint riêng.

## 2. Why — luồng trước/sau và trách nhiệm

**Khóa/mở khóa:** admin → danh sách/chi tiết → dialog giữ lý do → Provider giữ caller/epoch và frozen request → gateway → SQL kiểm quyền/revision, ghi pending rồi cấp dispatch → Auth ban/unban (unlock có readback) → SQL complete → app đọc lại user → hiển thị trạng thái thật. UI không suy enabled/locked từ nút vừa bấm. Hủy không gửi request, double-confirm một attempt.

Trước C6, enter/mutation có thể nhận response muộn, filter dùng null vừa là không truyền vừa là xóa, query mới bị bỏ khi đang tải, unlock luôn bị suy thành unlocking. Sau sửa, đổi phiên/owner/role xóa PII và chặn cả success/error/finally cũ; query mới có generation riêng và giữ filter; duplicate cursor không gửi hai lần. Server 401/403/revoked đóng quyền hiển thị.

Mất ACK giữ requestId/target/revision/reason; retry transport không tạo thao tác mới. Operation needs_retry dùng operation/reconcile; reconcile có request identity riêng và giữ khi mất ACK. ACK completed nhưng đọc lại lỗi thì chỉ tải lại kết quả. Khi mở lại detail, pending operation từ SQL giúp khôi phục đường reconcile, không đoán từ chữ “Đã khóa”. Thao tác mới sau completion không dùng receipt cũ. UI chi tiết nhận cùng Provider do shell sở hữu khi đổi route.

**Khám phá:** tìm `dam o loan` → một điểm đến cha `coursework-phu-yen`/Phú Yên → detail cùng release/source → Chuẩn bị chuyến đi → editor giữ đúng ID/tên; engine/AI/save gọi 0 trong fixture. Tìm có dấu/không dấu/combining marks và filter `Trung`/`Miền Trung` cùng nghĩa. Catalogue rỗng giữ rỗng; lỗi refresh giữ bản đã tải và có nhãn. Detail resolve theo ID trong snapshot hiện tại; destination bị ẩn thì báo đã đổi và chặn CTA.

## 3. Testing — bằng chứng thực tế

Artifact ignored dưới `.dart_tool/c6-codex-implementation/`:

| Kiểm tra | Kết quả |
| --- | --- |
| Baseline | Account targeted 118/118; Discovery targeted 47/47; Account runner cũ PASS. Lần đầu sandbox chặn SDK lockfile; retry được cấp quyền cache mới chạy tests |
| RED | `c61-c62-red-valid.log`: 10 ca FAIL đúng guard/filter/page/mutation. Có một fixture compile thiếu phone trước đó, không tính lỗi app. `gateway-red.log`: replay completed vẫn gọi Auth, dispatch denied bị bỏ qua. `sql-red-valid.log`: locked pending bị báo authSynced=true |
| RED bổ sung | `lazy-context-red.log`: đổi epoch khi loader chờ vẫn dispatch 1. `second-attempt-red.log`: receipt cũ làm retry thao tác mới thất bại. `detail-route-red.log`: ProviderNotFound ở route chi tiết. `reopen-pending-red.log`: mở lại không có retry operation. `discovery-ui-red.log`/`detail-red.log`: place search, refresh label, snapshot cũ |
| Targeted | `targeted-expanded.log` 55/55; `final-corrections.log` 45/45; `flows-final.log` 26/26; `final-round-targeted.log` 39/39. Các log này thuộc candidate trước/thời điểm ghi, không thay Full cuối |
| Full cuối | `full-final-source.log`: analyzer sạch; **Flutter1123/1123, Node91/91**, exit0. Chi tiết `.dart_tool/travelgo-verification/20261026T032903488Z-23072/` |
| Account cuối | `account-final.log`: Flutter 201/201, Node 19/19, focused SQL PASS; sáu SQL operation/user vectors khớp JSON dùng chung cho Dart/Node; exit 0 |
| SQL schema cuối | `sql-final.log`, DB local `.dart_tool/coursework-trip-sql/9a37dd88a9d0460598a936578ba1a564/`: C5 roundtrip, admin control, concurrency qua dblink, surface guards và C6 contract PASS; 21 C6 assertions; exit 0; `stop.log` server stopped |
| Harness | `account-selftest-final.log` exit 0: SQL/Node failure nonzero, false-positive/timeout controls; owned PostgreSQL được dừng |
| Diff/hash | Snapshot434 files, SHA256 `1424baabec8a1a6e33b496436e21230c0193ab5baef24e9888ae1a45b720e8d4`, trước/sau Full0 drift. `c6-scoped-hashes.json` gồm29 file; `final-integrity.json`:14 migration lịch sử không đổi, C5 forward hash giữ `708b4728d55dae40eb1427014ea7071bd3e4ee6ef28d33ecaa9c760e66970f3e`. `git diff --check` exit0; kiểm riêng file mới ghi nhận whitespace trong khối SQL kế thừa, không phải lỗi contract |

Commands: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath ...`; `-Mode Full`; `./tool/verify-flutter-admin.ps1 -Mode Account -FlutterRoot D:/flutter/flutter`; cùng lệnh `-SelfTest`; `./tool/verify-coursework-trips.ps1`; `git diff --check`.

Các lần chưa đạt được giữ: Full đầu dừng ở 5 curly-brace lint infos, sửa cơ học. Full tiếp theo analyzer sạch, Flutter 1118 PASS/1 FAIL do fixture C1 dùng Huế từ seed nhưng public snapshot chỉ chứa Quy Nhơn; đồng bộ fixture Huế, giữ assertions destination/no-engine/no-map. Full sau đó 1120/1120 + Node91 đạt, trước bổ sung các ca cuối. Một positive SQL fixture cũ dùng token worker ngẫu nhiên bị guard mới từ chối; đổi sang token/revision được SQL cấp, giữ negative control sai token phải deny. Không nới timeout/helper/assertions legacy import; không kết luận đã sửa flake C5. Phép thử `git -c core.autocrlf=false diff --check` báo CRLF của dirty files cũ là whitespace; không đổi chúng, dùng cấu hình Git hiện hành và kiểm7 file mới riêng.

## 4. Problems / giới hạn

- Đây là **Codex self-review**, chưa có reviewer độc lập hoặc live acceptance. Dart dùng fake HTTP/local SQLite; Node mô phỏng Auth/RPC; SQL gọi RPC thật trên PostgreSQL local. Cùng vectors giảm lệch contract nhưng không phải full gateway→Supabase/Auth integration thật.
- SQL schema cuối vẫn dùng adapters C5 cho PostgreSQL18 fingerprint/digest/p32_utc và auth substrate synthetic. PASS không chứng minh historical migration chain nguyên trạng fresh deploy được. 14 lịch sử và C5 forward migration giữ nguyên.
- Migration C6 chưa apply cloud; gateway/app đang deploy chưa chứng nhận có hành vi mới. Rollout cần migration/SQL dispatch contract đi trước gateway sử dụng nó; lượt này không rollout. Catalogue producer/publish thuộc C7.
- Không build/install/start app/device, gửi email/AI thật hoặc thao tác tài khoản thật. DTD discovery không có process/app; yêu cầu hot reload của plugin trả “No active app connection”, không hot reload app nào. Chưa kiểm TalkBack, keyboard/device/native acceptance.
- Giữ tối đa3 vòng correction hành vi: receipt/caller guard, route Provider, resume pending. Lint/fixture corrections ghi riêng; không tự reset guard để sửa tiếp. Nếu có finding hành vi mới cần checkpoint và owner quyết định theo guard hiện hành.
- Bộ duyệt tự động ban đầu từ chối bỏ entry Tổng quan vì chưa nhận diện approval; Codex đọc lại đúng plan mục1/C6.5 và approval “duyệt”, cùng patch được chấp nhận sau bằng chứng. Không còn hành động bị auto-review chặn.

## 5. Lesson Candidate / tiếp theo

Problem: tests từng lớp xanh nhưng operation/account state và UI retry khác nhau → Root Cause: fixture không lấy từ SQL thật, route tests cấp Provider rộng hơn app → Actionable Rule: dùng shared response vectors kiểm lại với SQL và test đường route với đúng scope Provider sản phẩm.

Problem: ACK completed không đồng nghĩa đã đọc được trạng thái mới; mở lại có thể mất đường retry → Root Cause: mutation receipt, readback và attempt chỉ sống trong một dialog → Actionable Rule: giữ identity riêng cho mutation/reconcile, lấy state từ readback, server trả đủ định danh pending để nối lại thao tác có chủ đích.

C7 chưa bắt đầu. Không mở lại findings C3/C4 đã đóng nếu không có bằng chứng mới; email/native và migration-chain limitations vẫn riêng. Bước tiếp theo trong repo là review độc lập C6 hoặc chuẩn bị C7 theo chỉ thị owner, không tự code/deploy từ báo cáo này.
