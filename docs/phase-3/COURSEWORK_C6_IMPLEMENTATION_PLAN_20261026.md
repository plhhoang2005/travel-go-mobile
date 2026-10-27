# C6 — Quản trị người dùng/tài khoản và Khám phá

**OWNER ĐÃ DUYỆT C6 ngày26/10/2026.** Owner trả lời “duyệt” sau khi Codex khôi phục checkpoint và dẫn đúng plan này. Codex triển khai native, không dùng Superpowers hoặc subagent. Approval chỉ code/test/PostgreSQL local cô lập; không mở quyền cloud/device/commit/push/merge hoặc C7. Nội dung dưới giữ kế hoạch được duyệt; lượt lập plan ban đầu chỉ đọc source và Account DryRun.

Nguồn: [phạm vi sản phẩm](../../.agent/product-scope.md), [thiết kế AI để giữ ranh giới](../../.agent/ai-planner-design.md), [Core R2 C6](../superpowers/plans/2026-10-24-coursework-core-r2.md#c6--admin-useraccount-và-khám-phá), [bàn giao C5](COURSEWORK_C5_CODEX_IMPLEMENTATION_20261026.md), [tự review C5](C5_CODEX_REVIEW_20261026.md).

Codex không dùng Superpowers vì owner chưa yêu cầu cho task hiện tại. Người code theo phân công owner khi duyệt; nếu giao Antigravity, handoff bắt buộc yêu cầu Superpowers phù hợp và evidence thực tế theo chỉ thị thường trực. Không thêm kiến trúc/dependency/native config để thực hiện C6.

## 1. Mục tiêu và ranh giới

Hai luồng cần hoàn thiện:

- Admin hợp lệ → tìm/lọc/phân trang người dùng → xem chi tiết → xác nhận khóa/mở khóa → server kiểm quyền và phiên bản → hiển thị đúng kết quả, pending hoặc lỗi/thử lại. Đổi tài khoản hoặc mất quyền phải xóa dữ liệu quản trị cũ và chặn phản hồi đến muộn.
- Người dùng → Khám phá → tìm điểm đến hoặc địa điểm tham quan trong catalogue → xem thông tin/nguồn/giá/giờ → chuẩn bị chuyến đi → editor hiện có. Không tìm thấy thì hiển thị trống và cho xóa query/lọc; không tự sinh địa điểm hoặc gọi Internet.

| Giữ/hoàn thiện | Gỡ khỏi đường sản phẩm trong C6 | Chưa làm trong C6 |
| --- | --- | --- |
| Tìm/xem user, trạng thái customer/admin, khóa/mở khóa có xác nhận, retry có kiểm soát; server guards/audit hiện có | Nút cấp/hạ quyền admin không thuộc danh sách chức năng đã chốt; entry Tổng quan và copy quản trị hệ thống vượt nhu cầu đồ án | Quản trị vai trò mới, dashboard thống kê mới, xóa user/hàng loạt, export dữ liệu người dùng |
| Khám phá/tìm kiếm/chi tiết; nguồn và nhãn chưa xác minh; chuyển đúng điểm đến vào editor | Tham chiếu map/favorites nếu còn trên đúng các màn C6 chạm tới | Crawler/tìm Internet, phủ hết Việt Nam, bản đồ, chatbot, thay đổi AI |
| Catalogue, quyền dữ liệu, cache hợp lệ và last-known-good | Chỉ gỡ UI/call riêng không còn dùng; không xóa RPC/guard/model/test bảo vệ quyền chỉ vì bỏ nút | Admin thêm/sửa/ẩn và publish→User refresh thuộc **C7**; giữ đường Danh mục/lịch sử đang phục vụ C7 |

Đề xuất shell quản trị mở mặc định ở **Người dùng**. Gỡ entry Tổng quan không đồng nghĩa xóa mọi biểu đồ/SQL thống kê hoặc thay quy trình xuất bản. Hiển thị role vẫn cần; không có nút promote/demote không đồng nghĩa bỏ last-admin/self-change protection ở backend.

## 2. Mốc rà soát và khoảng trống source

Checkout `D:/Travel-Go-Android/travel-go`; branch `fix/ai-planning-stability`; HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty C1–C5/owner work (166 entries lúc bắt đầu). Snapshot C5 `.dart_tool/c5-codex-implementation/final-source-snapshot.json`:383 files, đối chiếu hiện tại **0 drift**. Snapshot này không chứa migration lịch sử; kiểm hash SQL riêng khi triển khai.

C5 đã báo analyzer sạch, Flutter1100/1100, Node91/91 và SQL contract local có bootstrap adapters. Đây là **evidence C5**, không phải tests C6 vừa chạy, không chứng minh cloud/native hoặc toàn historical migration chain. Một ca legacy import từng vượt thời gian chờ ở Full đầu C5, chưa kết luận nguyên nhân; giữ nguyên assertions khi kiểm regression C6.

Các dòng dưới là nhận định qua đọc source, chưa phải lỗi runtime tái hiện trong lượt này. Trước sửa hành vi phải có regression/control xác nhận; phần đã đúng chỉ bổ sung evidence.

| Thành phần đã có | Việc cần kiểm/sửa nếu RED |
| --- | --- |
| `AdminAccountProvider.enter`, invalidate và generation cho list/detail | `enter()` chưa giữ generation/context trước await; mutation success/error/finally chưa có guard tương đương. Test owner/role/session đổi khi access/mutation đang chờ, kể cả error đến muộn làm bẩn state mới |
| List/search/filter/pagination | `setFilter` dùng null vừa làm mặc định vừa xóa filter; sửa query có thể xóa role/state. `loadUsers` bỏ request mới khi đang tải trang đầu, còn đường nextPage chưa chặn mọi lần gọi trùng. Test tên hiện có “query_and_detail_race” thực tế kiểm detail, chưa chứng minh query race |
| `confirmMutation`, `retryOperation` giữ args/requestId | Dialog gọi confirmMutation cho lần xác nhận tiếp, trong khi chưa có UI gọi retryOperation. Cần phân biệt thao tác mới với retry attempt chưa biết kết quả; không mint request mới sau mất ACK |
| Gateway/SQL có lock→Auth ban/unban→complete và service có operation/reconcile | Provider suy tài khoản từ action, unlock luôn gán unlocking; chưa readback user theo ACK. SQL list/detail suy authSynced từ `state <> unlocking`, có thể không phản ánh ban-sync còn lỗi. Cần test pending/completed/needs_retry và readback xuyên lớp |
| Wire enums có sẵn | `AccountOperation.state` chỉ nhận pending/completed/needs_retry; `UserSummary.state` nhận enabled/locked/unlocking. Fixture `admin_control_gateway_test.mjs` đang mô phỏng state tài khoản trong operation response, khác SQL thật và Dart DTO: cần contract chung |
| Profile admin entry, shell server access gate | Guard UI/server phải giữ. Shell đang vào Tổng quan, detail có promote/demote; đề xuất thu đường UI đúng scope như mục1 |
| Discovery có fold tiếng Việt, region, empty/error/retry, snapshot động | visibleDestinations hiện chỉ so tên điểm đến. Cần tìm cả tên place trong catalogue, kiểm query/lọc kết hợp và dữ liệu ngoài seed12/72 |
| Detail hiện render place/facts/source, CTA manual | Detail giữ catalogue/destination từ lúc mở còn visit facts có thể đổi snapshot. Cần kiểm không trộn phiên bản khi refresh/hide; đây là consumer regression C6, chưa nghiệm thu producer C7 |

## 3. Tiền kiểm trước code

1. Giữ nguyên dirty work, ghi source snapshot mới gồm admin/explore/auth liên quan, gateway, runner và SQL phụ thuộc. Đối chiếu383 C5 và14 migration cũ; không chỉ dùng HEAD vì các thay đổi chưa commit.
2. Chạy baseline targeted C6 và Account runner trước sửa; giữ log/exit/count, phân biệt assertion failure với fixture/setup failure. Không sửa source đã đạt chỉ để có diff.
3. Audit runner `tool/verify-flutter-admin.ps1 -Mode Account`: hiện chạy4 file auth/lifecycle/access Dart và2 Node suites, **không tự chạy3 file admin_account Dart/UI**. SQL là focused baseline/two-role/control/guards, không phải toàn migration chain hiện hành. Vì vậy cần targeted riêng và control trên schema cuối khi thay server guard.
4. PostgreSQL18/Flutter/Node có runtime được dùng ở C5; kiểm lại binary và dblink khi chạy, không tự cài/nâng. SelfTest phải chứng minh lỗi SQL/Node nonzero và server local được dừng. Không thay bằng staging/cloud nếu local thiếu.
5. Giữ giới hạn tối đa3 vòng sửa lỗi hiện hành; checkpoint nếu chạm giới hạn, không tự reset bằng tên gói. Không xóa test quyền/tính toàn vẹn để đạt PASS.

## 4. C6.1 — Quyền quản trị và dữ liệu khi đổi phiên

**Files:** `lib/features/admin/providers/admin_account_provider.dart`, `services/admin_account_service.dart`, `presentation/screens/admin_shell_screen.dart`, `lib/features/profile/presentation/screens/profile_screen.dart`; auth/lifecycle chỉ sửa khi regression chứng minh cần, giữ giải pháp C3–C5.

- Giữ server access() là gate; subject trả về phải khớp account đang thực hiện. Guest/customer/demo không vào admin bằng menu hoặc route trực tiếp. Role từ client/user metadata không được cấp quyền server.
- Capture owner/role/session context và generation cho enter/list/detail/mutation; invalidate xóa PII và pending UI ngay. Mọi success/error/finally muộn đều không được bật admin, hiện dữ liệu/lỗi hoặc tắt loading của operation mới.
- Test A đang load/mutate → logout/B/customer/role revoked; B đang tải hoặc lỗi vẫn không thấy A. Test cùng user nhưng authority phiên đã thay đổi; không coi cùng ID là chứng minh request còn hợp lệ.
- Lỗi 401/403/account_locked từ server phải đóng quyền hiển thị phù hợp, không để dữ liệu quản trị trước đó còn như đang được phép. Không tự xóa lịch chưa lưu của editor trong quá trình này.

**Đạt khi:** access A trả muộn không mở shell B; dữ liệu riêng bị xóa ngay và không quay lại; direct API customer bị deny, không privileged mutation/Auth Admin call. Happy admin vẫn vào và thao tác được.

**Tests:** `admin_account_provider_test.dart`, `admin_account_service_test.dart`, `admin_navigation_test.dart`, `auth_role_security_test.dart`, `local_account_lifecycle_test.dart`, Node/SQL deny controls ở C6.3.

## 5. C6.2 — Danh sách, tìm/lọc và chi tiết user

**Files:** account provider; `presentation/screens/admin_users_screen.dart`, `admin_user_detail_screen.dart`; service/model giữ listUsers/getUser/cursor đang có.

- Tách “không truyền filter” khỏi “xóa filter”; gõ query giữ role/state đã chọn, xóa query không âm thầm xóa bộ lọc còn lại. Dùng debounce hiện có nhưng đổi query phải vô hiệu kết quả cũ ngay.
- Query A đang tải → nhập B → B phải có request riêng và là kết quả cuối, bất kể A success/error về trước/sau. Cursor ràng buộc query/filters; đổi chúng reset trang. Không append trang cũ hoặc request cùng cursor nhiều lần.
- Có loading đầu, load thêm, empty thật, retry lỗi đầu và lỗi trang sau; giữ kết quả hợp lệ cùng query khi lỗi tải thêm. Không hiện empty như kết quả thành công khi request còn lỗi/chưa hoàn tất.
- Detail A→B giữ kiểm target/generation; quay lại/list refresh không mất query và không lấy detail A làm B. Lý do khóa do người dùng nhập phải giữ khi lỗi còn có thể sửa/thử lại.

**Đạt khi:** lọc role + state + tên/email hoạt động kết hợp; xóa từng filter rõ; phân trang không trùng/lẫn query; lỗi và empty có đường phục hồi. Test chiều rộng320dp/chữ2x, nút xóa query có nhãn truy cập.

**Tests:** ba file `admin_account_{provider,service,ui}_test.dart`; bổ sung Completer và widget tests đúng các race trên, không chỉ đổi tên test cũ.

## 6. C6.3 — Khóa/mở khóa, contract server và retry

Thực hiện **3a contract/SQL/gateway trước → 3b provider/UI sau**, để không chữa UI bằng trạng thái giả.

**Files:** account models/service/provider và detail UI; `supabase/functions/admin-control/gateway.mjs`; `supabase/tests/admin_account_control.sql`, `admin_account_surface_guards.sql`, `admin_account_concurrency.sql`; runner Account. Nếu có gap SQL thật, tạo forward migration bằng Supabase CLI migration new; không đặt timestamp giả hoặc sửa14 migration lịch sử.

### 3a. Contract và quyền server

- Giữ `travelgo.admin.v1`, các endpoint access/users/user/mutate/operation/reconcile và complete hiện có. Phân biệt operation state với account state; không nới Dart enum để nhận nhầm state tài khoản.
- Thêm fixture contract dùng chung, dự kiến `test/fixtures/coursework_admin_account_vectors.json`: completed/needs_retry/pending cho lock/unlock, readback enabled/locked/unlocking, revision/target/action đúng. Đối chiếu với output SQL local thật rồi dùng cùng vectors cho Node gateway và Dart parser/service. Fixture synthetic, không chứa user/token thật.
- Lock chặn quyền nghiệp vụ trước khi ban Auth; ban lỗi vẫn locked, nhưng nhãn đồng bộ phải trung thực. Unlock chỉ enabled sau readback/complete hợp lệ; Auth/complete lỗi giữ trạng thái hạn chế, có retry. List/detail phải giữ cùng sự thật sau refresh, không biến authSynced=false thành true chỉ vì state=locked.
- Giữ caller/session/role checks, expectedRevision, request identity, worker token và last-admin/self-change guards. Complete chỉ service_role; không đưa secret/worker token ra client. Customer/anon/locked/revoked gọi API trực tiếp bị deny và Auth Admin call0.
- Ca mất quyền giữa operation, completion cũ sau target revision mới, sai worker token, cùng request replay và wrong-target ACK phải có negative controls. Retry operation đã completed hoặc attempt của revision cũ không được ban/unban lại làm đổi Auth state của revision mới; kiểm cả số lần gọi Auth Admin, không chỉ việc SQL từ chối completion. Không làm yếu test promote/demote bảo vệ backend chỉ vì bỏ nút UI.

### 3b. Luồng app

- Dialog ghi rõ target/hành động, bắt lý do; Hủy0 request, bấm xác nhận nhanh chỉ1 attempt. Pending phải được ghi nhận trước await.
- Phân biệt **chưa biết kết quả** (mất phản hồi/mạng sau dispatch) với lỗi chắc chắn và **cần đồng bộ lại** (needs_retry có operationId). Chưa biết thì giữ frozen requestId/target/revision/reason và tra operation/replay đúng attempt; không dùng nút Xác nhận tạo requestId mới.
- Dùng operation()/reconcile() hiện có theo contract thực: retry transport giữ identity của attempt cũ; reconcile là attempt được theo dõi riêng, gắn operation/revision đúng. Không auto-retry vô hạn hoặc chạy poller nền mới.
- Sau ACK đọc lại target đúng phiên để lấy state/revision/audit; không suy enabled/locked chỉ từ nút đã bấm. Nếu ACK đã thành công nhưng đọc lại lỗi, nói thao tác đã được ghi nhận/cần tải lại, không gửi mutation mới để tải lại UI.
- Trạng thái pending/needs_retry có nút thử lại đúng việc; completed không để nút “Đang đồng bộ” vô thời hạn. Revision conflict giữ nội dung lý do, tải phiên bản mới và yêu cầu xác nhận lại rõ ràng, không tự ghi đè.

**Đạt khi:** lock→locked; unlock→enabled sau đồng bộ thật; Auth lỗi→pending/needs_retry trung thực và thử lại được; lost ACK không tăng số operation/revision trái contract; sai quyền/revision/target bị chặn; dữ liệu không lẫn account.

**Tests:** mở rộng account provider/service/UI, `admin_control_gateway_test.mjs`, `admin_account_gateway_test.mjs` và3 SQL suites. Có thể thêm `test/coursework_admin_account_flow_test.dart` đi qua provider→service/Dio→stateful fake transport với vectors SQL; ghi rõ mock khác SQL thật và khác Supabase live. Không gọi đây là full server integration chỉ vì fake trả200.

## 7. C6.4 — Khám phá, tìm địa điểm và dữ liệu động

**Files:** `lib/features/explore/providers/discovery_provider.dart`; `presentation/screens/explore_screen.dart`, `destination_detail_screen.dart`; `presentation/widgets/place_visit_details_widget.dart`, `destination_reference_list_tile.dart` khi cần; public catalogue/visit providers và sync coordinator chỉ sửa gap consumer được tái hiện.

- Reuse foldSearch: không dấu/có dấu/combining marks/hoa/thường/trim. Query khớp tên destination **hoặc place của destination đó**; region vẫn áp dụng. Hiển thị điểm đến cha một lần, có chỉ dẫn place khớp khi cần; dùng chi tiết place sẵn có trong màn detail, không bắt tạo màn/search service mới.
- Fixture có ID điểm đến/place ngoài seed, tên độc nhất như “Đầm Ô Loan” thuộc “Phú Yên thử nghiệm”; tìm `dam o loan` phải thấy đúng điểm đến, mở được facts/source đúng place. Không encode12 destinations/72 places vào logic hoặc tự tạo slug cho kết quả.
- Chuẩn hóa giá trị vùng giữa dữ liệu/choice chips hoặc lấy lựa chọn từ catalogue, giữ các vùng có sẵn hợp lý; test cả nhãn hiện dùng và dữ liệu V2, không chỉ self-consistent fixture dùng một kiểu nhãn khác UI.
- Không kết quả → empty + xóa query/lọc; catalogue rỗng/all-hidden không fallback về seed như dữ liệu mới. Lỗi refresh giữ last-known-good có nhãn lỗi/nguồn phù hợp, thử lại có chủ đích; cold load lỗi có retry, không kết quả giả.
- Detail/facts/source phải cùng release/digest hoặc giữ snapshot cũ nhất quán có nhãn rõ. Khi refresh đổi/hide destination đang xem, resolve theo ID từ snapshot nhất quán hoặc báo dữ liệu đã đổi; không trộn tên cũ với giá/nguồn mới hay tự chọn điểm đến khác.
- CTA chuẩn bị chuyến đi truyền đúng ID/tên, giữ dirty/pending-save guard C5, không gọi Decision Engine/AI chỉ để mở editor. Catalogue thiếu vẫn có đường tự lập theo scope; không đưa Internet vào C6. Giá/giờ unknown giữ chưa xác minh, không0/free/open.

**Đạt khi:** tìm tên destination/place động → detail đúng nguồn → manual editor đúng input; filters/clear/error/empty/refresh hoạt động; catalogue public không yêu cầu quyền admin để đọc; trip đang sửa và actuals C5 không mất.

**Tests:** `discovery_provider_test.dart`, `discovery_screen_test.dart`, `destination_detail_test.dart`, `public_catalogue_consumers_test.dart`, `public_catalogue_provider_test.dart`, `public_catalogue_metadata_ui_test.dart`, `discovery_planner_flow_test.dart`, `manual_discovery_flow_test.dart`, `coursework_trip_roundtrip_test.dart`. Producer admin save/publish thật vẫn nghiệm thu ở C7.

## 8. C6.5 — Thu đường UI và kiểm trải nghiệm

- Shell dùng Người dùng làm điểm vào; bỏ Tổng quan khỏi rail/bottom navigation và bỏ promote/demote khỏi detail theo mục1. Giữ danh mục/lịch sử để C7 tiếp tục, index/back/navigation đúng sau thay đổi. Bỏ call dashboard chỉ phục vụ entry đã gỡ nếu không còn caller; giữ callback public refresh của publication.
- Profile ghi “Quản lý người dùng và địa điểm”, không giới thiệu bộ quản trị hệ thống rộng. Không lộ các nhãn kỹ thuật như Revision/worker token hoặc raw exception cho người dùng; hiển thị lỗi tiếng Việt và hành động thử lại phù hợp.
- Giữ Material/AppTheme/Provider hiện có. Kiểm320dp/chữ2x, SafeArea, scroll bàn phím trong dialog, focus/nút Hủy, nhãn icon xóa/làm mới, loading/error/empty. Không thay font/palette/design system.
- Test navigation sửa expectation từ4 mục cũ sang mục còn trong scope; giữ guest/customer/demo denied, direct route server deny, verified admin/back. Standalone tests backend/model bảo vệ quyền giữ nguyên, không xóa toàn bộ test có chữ dashboard/role.

**Tests:** `admin_navigation_test.dart`, `admin_account_ui_test.dart`, `secondary_screens_visual_test.dart`, `discovery_screen_test.dart` và những tests thực sự phụ thuộc shell. Chỉ tạo test mới cho hành vi cần chứng minh, không mirror implementation.

UX guidance tham khảo từ `ui-ux-pro-max`: `destructive action confirmation --domain ux` khớp Confirmation Dialogs/Confirmation Messages; `search loading empty --stack flutter` khớp async loading/error. Đây là gợi ý để viết tiêu chí, không phải chứng nhận đã quan sát app/TalkBack hoặc yêu cầu đổi sang FutureBuilder/SDK mới.

## 9. C6.6 — Kiểm tổng hợp, tự review và bàn giao

**Thứ tự:** tiền kiểm → C6.1 → C6.2 → C6.3a → C6.3b → C6.4 → C6.5 → C6.6. Từng gap: RED/control → sửa tối thiểu → targeted GREEN; cuối cùng Full và Account SQL/Node. Không bắt mỗi gói phải có app diff nếu code đã đúng.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/admin_account_provider_test.dart,test/admin_account_service_test.dart,test/admin_account_ui_test.dart,test/admin_navigation_test.dart,test/auth_role_security_test.dart,test/account_access_service_test.dart,test/local_account_lifecycle_test.dart
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/discovery_provider_test.dart,test/discovery_screen_test.dart,test/destination_detail_test.dart,test/public_catalogue_consumers_test.dart,test/public_catalogue_provider_test.dart,test/public_catalogue_metadata_ui_test.dart,test/discovery_planner_flow_test.dart,test/manual_discovery_flow_test.dart,test/coursework_trip_roundtrip_test.dart
./tool/verify-flutter-admin.ps1 -Mode Account -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -Mode Account -FlutterRoot D:/flutter/flutter -SelfTest
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Thêm file flow/vectors tests mới vào targeted sau khi tạo. Full hiện chỉ chạy3 Node AI/catalogue suites nên **không thay Account Node tests**. Nếu sửa SQL/server surface, chạy thêm `./tool/verify-coursework-trips.ps1` để giữ C5 editable/account guards trên final-schema fixture; nếu cần suite final-schema C6 riêng, mở rộng local runner có mode/fixture rõ trong phạm vi verification, không trỏ cloud. Tách focused Account SQL, final-contract SQL có adapters và fresh-deploy chain; không đánh đồng các kết quả.

**Đạt để chốt source:** tất cả allow/deny/happy/error/race cases của các gói có evidence; analyzer sạch, Full và Account exit0, SQL đúng role trên DB local cô lập; snapshot/hash không drift; không có ngoài scope hoặc nới guards. Báo thiếu prerequisite là BLOCKED cho đúng lớp, không coi skip là PASS hoặc dùng mock thay SQL.

Bàn giao5 mục Changed/Why/Testing/Problems/Lesson Candidate, exact branch/HEAD cộng dirty snapshot, commands/exits/counts/logs. Trace một lần khóa/mở khóa UI→provider→gateway→SQL/Auth→readback→UI và một lần tìm place→detail→editor. Nêu test nào đổi theo scope, finding nào đóng/còn mở, và self-review khác independent review.

**Giới hạn:** approval plan triển khai nếu được duyệt chỉ cho code/test/local DB cô lập. Chưa cấp quyền deploy/apply cloud/live lock user/SMTP/AI thật, build/install/hot reload/device, commit/push/merge hoặc C7. Nghiệm thu live dùng admin và target test được owner cho phép riêng, không khóa owner/admin chính. C3/C4 email/native acceptance và migration-chain limitation C5 vẫn riêng.

## 10. Bàn giao lượt lập kế hoạch

**Changed:** thêm plan C6 và cập nhật checkpoint tài liệu, không sửa app/tests/SQL/tool. **Why:** dựa trên code đang có để ưu tiên session/filters/operation contract rồi consumer discovery, giữ scope đồ án. **Testing:** đọc source/test/SQL; đối chiếu snapshot C5 có0 drift; Account DryRun exit0, không chạy Dart/Node/SQL C6. **Problems:** các gap bảng mục2 chưa được tái hiện bằng fresh tests; chưa có C6/live acceptance. **Lesson Candidate:** operation state và account state cần contract khác nhau; mock ở từng lớp có thể đều xanh nhưng chưa chứng minh toàn luồng khớp nhau. Chờ owner duyệt plan trước triển khai.

## 11. Checkpoint thực thi sau approval — 26/10/2026

Owner đã trả lời “duyệt” cho plan này. Codex triển khai native và tự review: **source/automated + SQL contract local PASS**, Full1123 Flutter/91 Node/analyzer sạch, Account201 Flutter/19 Node,6 SQL vectors và final-schema control/concurrency/guards/C5 roundtrip PASS. [Bàn giao](COURSEWORK_C6_CODEX_IMPLEMENTATION_20261026.md), [review](C6_CODEX_REVIEW_20261026.md). Snapshot434 files0 drift;14 migration lịch sử và C5 forward giữ nguyên. Chưa independent/cloud/native acceptance; bootstrap adapters C5 vẫn riêng.3 vòng correction hành vi đã dùng, không reset guard. C7 chưa bắt đầu; không commit/push/deploy/apply cloud hoặc thao tác user thật.
