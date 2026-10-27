# TravelGO — hai role và quản trị dữ liệu Khám phá

## Quyết định và quyền thực thi

Owner chốt chỉ `admin`/`customer`, ưu tiên: nền role/quyền → admin nhập/kiểm/xuất bản → hoàn tất Khám phá72 → quản lý tài khoản đầy đủ. Chỉ thị “vậy hãy làm theo thứ tự đi” cho phép bắt đầu code trong phạm vi này; không hỏi lại lựa chọn hai role hoặc thứ tự. Không dùng Superpowers cho task mới vì owner chưa yêu cầu. Không spawn agent, thêm dependency hoặc chỉnh native config.

Repo `D:/Travel-Go-Android/travel-go`, branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`, working tree137 entries dirty trước packet. Giữ nguyên work của owner; không reset/stash/stage/commit/push/merge. B1/Auth/lifecycle và G4 cũ có guards riêng; không dùng task role này để sửa race/import/trip ngoài phạm vi.

Live writes (migration, cấp admin, deploy chức năng, Storage publish) phải có target và thay đổi cụ thể để review trước thao tác. Kế hoạch không tự cấp role cho bất kỳ tài khoản nào. Owner đã chỉ định tài khoản admin đầu tiên và đã đối chiếu đúng1subject ở staging; chưa đổi role khi chưa hoàn thiện packet database R1.

## Hiện trạng trước sửa và preflight server20/10/2026

- Flutter `UserRole` có customer/partner/admin; hai nhánh Auth đọc `profiles.role` và fixture demo còn partner. Chưa có giao diện admin hoặc route phân nhánh admin trong shell hiện tại.
- Read-only staging `travel-go-staging` / `bkocylxbuyvdgxccpixx`: profiles có3customer,0partner,0admin; role text DEFAULT customer, nullable; `profiles_role_check` cho customer/partner/admin. Anon/authenticated không có UPDATE(role), authenticated không INSERT profiles. Không đọc email/identity/private trip trong audit này.
- Có bảng legacy `partner_profiles` và `services`; không xóa hoặc làm mất dữ liệu chỉ để giảm enum. Production chưa kiểm tra/chưa đổi.
- App không tin `user_metadata.role`; trusted fetch có epoch/user guards. Signup server trigger ép customer. Giữ các nguyên tắc này.
- Khám phá đã có domain/parser/cache/repository/Provider/UI/release builder. Bộ ID/hash cố định72; seed giá20/giờ17/both16, còn56 chưa đủ cả hai; chưa có release live hoặc native acceptance. Baseline gần nhất analyzer clean,843Flutter/89Node PASS, không phải tests của thay đổi role mới.

## Mô hình quyền cần đạt

| Chủ thể | Đọc public release | Đọc/sửa draft | Kiểm và xuất bản | Tài khoản riêng | Cấp role |
| --- | --- | --- | --- | --- | --- |
| Guest | Có | Không | Không | Không | Không |
| Customer | Có | Không | Không | Chỉ của mình | Không |
| Admin xác thực thật | Có | Có | Có, sau validation | Hồ sơ của mình; chưa mở private trips người khác | Bootstrap do operator; UI quản lý tài khoản ở giai đoạn sau |
| Demo/local identity | Dữ liệu đọc công khai | Không ghi live | Không | Chỉ fixture/local | Không |

Guest là trạng thái chưa đăng nhập, không phải role thứ ba. Mọi giá trị role cũ/không biết từ backend được client xử lý thành customer; metadata do client gửi không cấp admin. Mỗi thao tác ghi admin phải được server xác minh session và role hiện tại, không dựa badge hoặc ẩn nút. Không chứa service_role key trong web/Flutter.

## R0 — thu gọn role phía app (packet hiện tại)

Allowlist5 files: tài liệu này; `lib/features/auth/models/user_model.dart`; `lib/features/auth/providers/auth_provider.dart`; `test/auth_role_security_test.dart`; `test/auth_navigation_test.dart`.

1. Viết assertions enum chỉ customer/admin; trusted partner/unknown/null không cấp role đặc quyền; giữ spoof/late user/logout tests.
2. Bỏ partner enum/display/badge/demo; cả hai nhánh trusted-role mapping chỉ nhận exact admin, còn lại customer. Không thay credential/lifecycle flow.
3. Đổi fixture navigation partner thành kiểm enum hai role; giữ customer/admin/Guest flow và mọi assertion bảo mật khác.
4. Chạy targeted Auth roles/navigation; scoped analyzer; Full (`flutter analyze`, `flutter test`, Node contracts). Thử hot reload nếu có app kết nối; phân biệt build/test với native acceptance.
5. Ghi logs/counts/hashes/result trong ledger cuối tài liệu. R0 xong không có nghĩa database đã bỏ partner hoặc admin UI đã hoàn tất.

## R1 — ràng buộc database hai role và nền kiểm quyền

Allowlist riêng: migration mới do `supabase migration new` tạo; SQL allow/deny test mới; tài liệu ledger này (<=5files/25calls).

- Kiểm lại role counts/nulls và constraint trên staging trước apply. Migration giao dịch: chỉ chuyển partner/null về customer nếu đúng preconditions đã review; chỉ giữ constraint hai role, DEFAULT customer/NOT NULL. Không promote customer và không xóa bảng partner/services.
- Giữ column grants bảo vệ role và trigger ép customer; kiểm signup giả admin/partner, customer tự đổi role bị từ chối, customer không đọc profile người khác, admin không mặc định được xem private trips.
- Bổ sung helper kiểm quyền phục vụ admin data sau khi chốt schema ở R2: đọc role từ nguồn server bảo vệ, session thật, deny cho Guest/customer/missing/null/deleted profile. Không dựa user_metadata. Nếu cần SECURITY DEFINER chỉ helper tối thiểu trong schema riêng, search_path rỗng/qualified names và EXECUTE grants đúng; không tạo public superuser function.
- Bootstrap admin đầu tiên bằng exact account ID từ email owner chỉ định; ghi audit và kiểm readback. Trình bày SQL/target/ảnh hưởng cụ thể trước live mutation. Không nâng toàn bộ3customer lên admin.
- Kiểm migration/allow-deny trên môi trường test phù hợp; không gọi SQL ghi live là “dry-run”. Khi chưa có runner, ghi NOT RUN thay vì PASS. Kiểm advisors sau apply đã được duyệt.

## A1 — lưu nháp và lịch sử dữ liệu Khám phá

Owner đã đổi scope sang **danh mục động**:12điểm đến/72địa điểm là seed ban đầu, không là giới hạn. Cho thêm/sửa/ẩn điểm đến và địa điểm; giữ mã đã tạo, quan hệ cha–con và ràng buộc database. Tách các packet schema/tests/service/app <=5files. Admin web riêng trong repo, không thêm dependency nếu toolchain hiện có đáp ứng. Các checkpoint A1-fixed72 phía dưới là lịch sử, đã được checkpoint Dynamic Admin thay thế.

- Draft: raw domain JSON/record, revision tăng, updatedAt/updatedBy; một write kèm expectedRevision, conflict không đè dữ liệu mới. Nhập thiếu vẫn lưu nháp; không giả reviewed khi chưa đủ URL/ngày/điều kiện.
- Trường form: scope, giá loại/đối tượng/đơn vị/gói/tuyến/included/excluded; lịch ngày/mùa/qua đêm/cutoff; nguồn từng field và checkedAt; trạng thái kiểm tra.
- Shared package và source IDs dùng chung, không copy thành phí riêng tại từng điểm. Không sửa catalogue cũ hoặc parser legacy để lách72ID.
- Server kiểm admin cho SELECT/INSERT/UPDATE draft và audit; customer/Guest không được đọc draft. Audit ghi người sửa/trước-sau/revision/thời gian phía server trong cùng transaction; client không sửa/xóa audit.
- Seed nhập draft giữ nguyên20/17 nguồn reviewed hiện có và exact gaps, không tự gia hạn checkedAt.

## A2 — giao diện nhập, xem trước, xuất bản

Ba màn chính: danh sách/lọc cần kiểm → editor nháp → preview/validation/publish và lịch sử cơ bản. Desktop web cho nhập liệu; không buộc Flutter mobile mang công cụ quản trị. Cần áp ui-ux skill khi triển khai UI, dùng trạng thái loading/error/conflict rõ ràng.

- Login dùng tài khoản thật; customer/demo mở URL admin vẫn bị server từ chối. Lỗi xác thực/role bị thu hồi phải ngừng ghi ngay cả khi giao diện còn mở.
- Preview dùng cùng contract/domain và hiển thị tương đương app. Có lỗi validation thì giữ draft, chỉ rõ từng field, không làm mất phần đang nhập.
- Publish cần release đồng bộ metadata danh mục động và visit-details cho bộ IDs đang được xuất bản, version tăng/hash raw bytes; validate contract và checkedAt/effectiveness. Consumer Flutter và release builder cũ còn pinned seed72 nên phải nâng contract riêng trước khi phát hành danh mục mở rộng; không bỏ integrity checks của consumer cũ để lách việc này.
- Upload immutable release trước; readback bytes/hash/schema/72IDs rồi mới đổi latest. Khóa/expectedVersion để tránh hai admin ghi đè. Lỗi giữa bước giữ bản tốt, retry/idempotency không tạo latest trỏ tới file hỏng. Mọi publish ghi actor/revision/hash/version/audit.
- Credentials quản trị chỉ phía server; mobile/customer chỉ public GET. Nếu quyền upload/deploy chưa được duyệt, code và packet local vẫn hoàn thiện trước khi trình đúng payload/target. Public bucket không có nghĩa authenticated được ghi.

## D — hoàn tất Khám phá72 bằng công cụ admin

- Tiếp tục nguồn56IDs còn thiếu, ưu tiên Ninh Bình6; giữ evidence nguồn theo field, không thay điểm khó tra hoặc dùng snippet/error thành reviewed.
- Nhập qua admin, đối chiếu bản preview với nguồn, build/publish full sau đủ nguồn và exact live approval.
- Kiểm cùng APK nhận version mới; lỗi mạng/hash/schema/cache giữ bản tốt; offline sau restart; search/detail/planner đúng72IDs. Native acceptance phải có thiết bị thật/app kết nối và giữ draft đang có. Không reinstall/clear để che lỗi.
- Các kiểm thử cũ đã pass là baseline; bộ current phải được chạy sau thay đổi. Không gọi code/test xong là full acceptance nếu server/native còn NOT RUN.

## U — quản lý người dùng sau luồng nhập→xuất bản hoàn chỉnh

Tìm kiếm/phân trang thông tin cơ bản, trạng thái, khóa/mở kèm lý do, cấp/thu hồi admin, lịch sử và khôi phục nội dung. Chốt policy khóa/session, bảo vệ admin cuối cùng và tự hạ quyền trước code; không đổi reset password/đọc private trips hoặc xóa tài khoản thành quyền mặc định. Role changes/audit ở server, customer không tự nâng quyền. Không xây custom roles/permission matrix động.

## Verification và giới hạn

Các packet giữ25outer calls/5authored files/3repair rounds; hết guard lưu checkpoint và chờ owner theo workflow. Không lấy packet mới để reset G4 cũ. No dependency/native settings/paid plan changes; không deploy production hoặc tạo project/branch có phí. Không gửi email/liên hệ bên ngoài.

Nguồn kỹ thuật đã đối chiếu: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [changelog](https://supabase.com/changelog). Data API grants và RLS đều phải được kiểm. user_metadata không đáng tin để cấp quyền; token claim có thể cũ nên sensitive writes kiểm role server hiện tại.

## Execution ledger

- Preflight read-only staging:3customer/0partner/0admin, nullable role và constraint3roles. Không DB writes. Owner đã chỉ định tài khoản admin đầu tiên; truy vấn đúng email trả duy nhất auth ID `6346607e-40e0-4182-b887-2cf9d33321f9`, profile role customer, email confirmed. Không lưu email/token vào artifact; không tự promote trong R0.
- R0 đã sửa app: enum/display/badge chỉ customer/admin, xóa demo partner; hai nhánh mapping trusted server chỉ nhận exact admin, role partner/unknown thành customer. Giữ nguyên epoch guards, credential queue, lifecycle và signup metadata protections. Không đưa admin UI hoặc khả năng ghi server vào R0.
- R0 allowlist thực tế5files đúng mụcR0. AuthProvider/model/navigation test đã owner-dirty trước sửa; `git diff` so HEAD còn chứa work cũ, không nhận toàn diff là thay đổi R0. AuthProvider pre-R0 SHA `1195C7D3D26CE2F9B16A7A8FE3E5FBD7FB69B01BDAF7855199F36EBAEBC0FA6D`, user_model pre-R0 SHA `95906AA332D5DCB2D53AF08D7E84007F3FDCB3BB51AFB209DD780EC4BECE3999`.
- RED đầu `20261020T143751168Z-21216`:85pass/8fail;5 REST failures do fixture thiếu `Response.request`, không phải lỗi Auth. Đối chiếu package Postgrest2.9.1 `postgrest_builder.dart:462` bằng Dart MCP, thêm request vào mock, giữ assertions. Fixture sửa1round. RED thực `20261020T143922131Z-2612`:89pass/4fail đúng enum/partner mapping/epoch legacy; không có implementation edit trước RED này. Warning Null-check từ fixture cũ khác vẫn có trong suite, không mở scope sửa.
- GREEN `20261020T144022124Z-27128`:93Auth/navigation PASS exit0, scoped analyzer4files clean.11cases mới gồm6legacy/unknown/null qua injected fetcher và5actual PostgREST client paths (admin/customer/partner/ADMIN/null); giữ spoof metadata, logout/late userA→B và demo provenance checks. Enum navigation test thay fixture partner đã xóa, số test đó không tăng.
- Runtime: DTD discovery không tìm thấy process/app đang chạy, hot_reload đã thử và báo no active connection. Không cài/restart/clear thiết bị; native acceptance NOT RUN. Full R0 đã trả exit0; số test/log được ghi trong final evidence bên dưới. Không lấy843tests lịch sử thành kết quả mới.

### Packet R1 kế tiếp — concrete target và preconditions

Staging duy nhất `bkocylxbuyvdgxccpixx`, admin bootstrap duy nhất ID ở trên do owner chỉ định. Chưa inspect/change production. Preflight phải đọc lại counts và profile/confirmed auth subject ngay trước mutation, không dùng snapshot0partner làm điều kiện vĩnh viễn.

Migration mới cần bổ sung, không sửa migration lịch sử `202610080001_profile_privacy.sql`: xác nhận role text/default/grants/profiles_role_check đúng preflight; trong transaction chuyển legacy partner/null về customer, giữ mọi profile/trip, đổi CHECK thành customer/admin và NOT NULL. Sau đó exact bootstrap chỉ cập nhật một row target còn customer thành admin với actor/audit server. Không xóa `partner_profiles` hoặc `services`. Không mở UPDATE(role) cho authenticated để triển khai nút admin.

Các tests trước apply: role partner/unknown/null bị constraint chặn; signup gửi role admin vẫn ra customer; customer PATCH role bị42501; customer chỉ đọc profile của mình; admin bootstrap đúng1row và không cấp admin cho hai người còn lại. Thay đổi role không sửa ownership của trips/activities. Với admin-data RLS sau đó phải có positive/negative server tests riêng, không suy từ enum app.

Live mutation cần packet migration/tests đã chuẩn bị/kiểm, target readback mới và quyền owner được đối chiếu trước thao tác; chưa có migration R1 trong packet R0. Thiếu runtime PostgreSQL test phải ghi NOT RUN, không fake runner bằng mock như live database. Khi owner tiếp tục, hoàn thiện R1 trước A1; không quay lại nghiên cứu Ninh Bình trước nền admin đã được yêu cầu.

- R1 read-only bổ sung: profiles chỉ có SELECT/UPDATE own-row policies (id=auth.uid); updated_at trigger duy nhất; partner_profiles/services đều0rows; không có public function tên admin. Chưa mở quyền đọc profile người khác, không tạo helper hoặc policy mới ở R0. Tài khoản đầu tiên vẫn customer tại lần audit này.

### R0 final evidence — CLIENT COMPLETE, SERVER/UI PENDING

**Changed:**5file allowlist R0 ở trên. Model chỉ customer/admin và bỏ demo partner; Auth mapping bỏ partner ở hai nhánh; navigation test xác nhận exact enum; role tests thêm11cases với mock HTTP thật qua PostgREST. Tài liệu này giữ roadmap/phân quyền/live preflight/next steps. Không sửa source catalogue, DB SQL, native config hoặc dependencies trong R0.

**Why:** enum là trải nghiệm client, không phải quyền ghi server. Giá trị legacy partner không còn tạo nhánh đặc quyền; customer/admin vẫn dùng luồng đăng nhập đang có, epoch vẫn chặn phản hồi role của người trước. Demo admin vẫn có provenance test-only, không tạo tài khoản admin thật.

**Testing:** `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/auth_role_security_test.dart','test/auth_navigation_test.dart') -FlutterRoot 'D:/flutter/flutter'`:93PASS, `20261020T144022124Z-27128`; scoped analyzer4files sạch. `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot 'D:/flutter/flutter'`: analyzer sạch3.8s,854FlutterPASS1:27,89NodePASS/fail0, helper exit0, `20261020T144101265Z-13164`; wrapper `.dart_tool/admin-r0-full-20261020.log`. `git diff --check` scoped4files exit0. Source baseline843test là lịch sử, không thay current854. Chỉ sửa1fixture round, không nới assertions hoặc dùng Superpowers.

**Problems:** staging vẫn3customer/0admin, role constraint3values và nullable; target bootstrap vẫn customer ở readback cuối. Chưa tạo/apply R1 migration, cấp admin, deploy admin API/web hoặc publish Storage. App model hai role không có nghĩa server đã đổi. DTD không có runtime; hot_reload attempted/no active app. APK build khác với native acceptance; không install/clear/restart. Admin UI và full Discovery72 vẫn pending; số nguồn giữ20giá/17giờ/16both. Đã chạm5authored-file guard, packet19outer calls/1fixture repair, dừng checkpoint chờ owner tiếp tục đúngR1. Không reset G4 cũ, không PR/stage/commit/push/merge hoặc tự đổi branch.

**Lesson Candidate:** test HTTP giả bỏ Response.request → SDK dừng trước assertion nghiệp vụ → mock phải bảo toàn cấu trúc response thật, giữ positive assertion server-name để biết nhánh được chạy. Bỏ role enum không đổi quyền server → tách evidence client/schema/runtime; deny admin mutation phía server trước khi mở UI.

**Next:** hoàn thiện packetR1 migration+SQL allow/deny tests trên staging đã xác định; bootstrap chỉ đúngsubject owner chỉ định, không hỏi lại email hoặc hai roles. Kiểm lại live preconditions ngay trước thay đổi. SauR1 mới A1draft/audit và A2editor/preview/publish. Tài liệu này là checkpoint source cho session kế tiếp, không thay live deployment evidence.

Current source SHA256:
- lib/features/auth/models/user_model.dart: `BD146EA5FDD26582A172B76067311C6D77CBE38D15EE3811BA6F9C1F2F57A7B8`
- lib/features/auth/providers/auth_provider.dart: `DDA2638475DE666DD532F0F1844CA3093A0BCF517E0A7FBFAEBCF9EDE6E765AC`
- test/auth_role_security_test.dart: `8FE8F8D6681F9E4296221AB67C21FB062F74FF2E79254C7879FA2A96B50A70FF`
- test/auth_navigation_test.dart: `FA2C64C528EF1A0E38AAA9A5B815EC4FABE90B3EB8EE626D2F06943533BC0D05`
- APK main/staging/debug/android-x64 (no QA flags), build PASS, SHA `C2B9896B04C5350DD69F206C4B2DE69A03080F58CA86BE4C10725999F1CF6C9E`, log `.dart_tool/admin-r0-build-main-x64-20261020.log`. Artifact `build/app/outputs/flutter-apk/app-debug.apk`; không install hoặc coi là device acceptance.

### R1 — LOCAL VERIFIED, STAGING APPLY AWAITING OWNER (20/10/2026)

Owner yêu cầu tiếp tục bước kế tiếp. Giữ hai role và exact bootstrap subject đã chọn; không hỏi lại email hoặc mở Superpowers. Branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`; giữ toàn bộ dirty work có trước. Không stage/commit/push/merge. Packet R1 chạm đúng5files, dự kiến24outer calls,3harness/fixture repair rounds; kết thúc tại checkpoint này, không reset guard để làm A1.

**Changed —5file allowlist:**

1. `supabase/migrations/20261020145005_two_role_foundation.sql`, được CLI2.81.3 tạo bằng `migration new two_role_foundation`: kiểm baseline nullable/default/constraint/grants/owner policies; transaction có lock/statement timeout, normalize partner/null→customer, giữ admin có trước, đổi CHECK hai role và NOT NULL. Tạo schema `private_admin` và bảng `role_bootstrap_audit` chỉ phục vụ bằng chứng bootstrap; RLS enabled, không cấp client/service_role quyền schema/table, không có public RPC/SECURITY DEFINER mới. Không promote account trong migration, không sửa migration lịch sử hoặc ownership policies, không xóa bảng partner/services.
2. `supabase/staging/bootstrap_first_admin.sql`: transaction riêng cho đúng subject `6346607e-40e0-4182-b887-2cf9d33321f9`; yêu cầu hai-role constraint, chưa có admin/audit, auth subject confirmed và profile còn customer; khóa auth row/profiles/audit, đổi đúng1row và ghi actor database/old/new role/reason/time cùng giao dịch. Không dùng email như khóa cập nhật, không có API gán role tổng quát. Actor database là tài khoản SQL thực thi; nguồn chấp thuận của owner được đối chiếu trong chat/rollout ledger, không giả thành user JWT.
3. `supabase/tests/profile_two_roles.sql`:21assertions PostgreSQL thực, fixture collision guard, toàn bộ rollback; signup spoof admin/partner vẫn customer; partner/unknown/null bị constraint chặn; owner sửa cột an toàn được; customer không nâng role/insert profile/đọc sửa profile người khác/đọc trip người khác/đọc giả audit; admin đọc được role của mình nhưng không bypass private profiles/trips hoặc tự PATCH role; missing-subject/anon bị deny.
4. `tool/verify-admin-roles.ps1`: dùng PostgreSQL có sẵn, tạo cluster riêng dưới `.dart_tool/admin-r1-postgres/<guid>`, chỉ listen127.0.0.1 cổng tạm, synthetic auth substrate, replay baseline+privacy+preferences cũ rồi R1; kiểm normalize/preserve/admin/ownership/policies, unsafe-grant denial, replay denial, preferences regression và bootstrap missing/unconfirmed/existing-admin/repeat/late-audit-failure rollback. Không dùng hosted DB URL/key hoặc cài dependency. Dừng cluster trong finally; giữ logs để review, không xóa dữ liệu project.
5. Tài liệu này: evidence, target rollout và checkpoint tiếp theo.

**Why / luồng:** role hiển thị trong app không tự cấp quyền database. Client đăng nhập→đọc profile của mình→server giới hạn cột/row bằng grants+RLS. Hai-role CHECK/NOT NULL giữ dữ liệu hợp lệ; UPDATE(role) vẫn bị chặn cho authenticated, kể cả admin. Bootstrap là thao tác SQL đặc quyền một lần, chưa thay thế admin API/helper/session checks của A1. Luồng quản lý địa điểm, nháp, editor và xuất bản chưa được tạo ở R1.

**Testing — kiểm mới, không dùng lại kết quả R0:**

- `./tool/verify-admin-roles.ps1`: exit0 trên PostgreSQL18.6 Windows local.21allow/deny assertions PASS, regression preferences PASS; migration giữ4legacy fixture rows với3customer/1admin, snapshot trips/policies giữ nguyên. Bootstrap kết thúc đúng1admin/2customer/1audit; cố tình ép audit INSERT lỗi chứng minh role update cũng rollback; chạy lại bị từ chối. Evidence `.dart_tool/admin-r1-postgres/afb3ed1a7b324f80bd36b383245a178f/verification.log`; `stop.log` xác nhận server stopped. Local auth.users/auth.uid là substrate tổng hợp cho SQL; không coi đây là hosted Auth/JWT/session/PostgREST test hoặc PG17 staging acceptance.
- Lần sandbox đầu không cho loopback; initdb/pg_ctl khởi động gây Windows native-console descendant wait. Sửa launch bằng Start-Process Hidden và chỉ đợi process handle. Hai fixture corrections tiếp theo: owner postgres theo migration cũ; title bắt buộc của trips. Giữ log các lần chưa đạt ở `700c34273e8e42079fb12fa19c2f78fa`, `d0f8e1dea22c4d488a5672285d809970`, `83d58f9b96c94a8391c13fcdcb7b97a3`, `3c67002e4ce340a693785d930541892e`. Không sửa migration lịch sử hoặc nới assertion để đạt.
- `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot 'D:/flutter/flutter'`: exit0, analyzer sạch10.8s,854Flutter PASS1:33,89Node PASS/0fail. Evidence `.dart_tool/travelgo-verification/20261020T145441117Z-22988/`; wrapper `.dart_tool/admin-r1-full-20261020.log`. Không sửa Dart nên không build APK/hot reload mới trong R1.
- `git diff --check` scoped source exit0; no tracked source diff trong packet vì4file SQL/harness mới đang untracked. Nội dung file mới đã được psql/PowerShell chạy thực. Không thêm SDK/dependencies/native permissions, không chạm source catalogue hoặc dữ liệu nguồn72.
- Đã đọc official Supabase changelog HTML (Markdown endpoint trả unsupported content-type), docs Column Level Security và MCP RLS docs; đối chiếu grants/RLS và metadata không đáng tin. Tài liệu: https://supabase.com/docs/guides/database/postgres/column-level-security ; https://supabase.com/docs/guides/database/postgres/row-level-security .

**Concrete live packet — CHƯA THỰC THI:**

- Target duy nhất `travel-go-staging` / `bkocylxbuyvdgxccpixx`, PostgreSQL17.11.0.003. Không chạm production `oavbymauorhmrjcustzw`.
- Read-only preflight và readback mới trong R1:3customer/0admin, role nullable/CHECK3values; authenticated không UPDATE(role); private_admin chưa tồn tại; owner-selected exact subject confirmed=true, role=customer. Chưa ghi migration/audit/admin lên staging.
- Owner cần duyệt gói cụ thể này theo live-write boundary ở đầu tài liệu: (a) apply duy nhất migration mới ở trên; (b) chạy SQL allow/deny synthetic suite với rollback trên staging; (c) nếu suite đạt và fresh subject/email/role/grants/confirmed readback vẫn đúng, chạy riêng bootstrap SQL; (d) readback đúng1admin/2customer và1audit, kiểm advisors. Không chạy `supabase db push` để replay lịch sử vì migration history staging không trùng hoàn toàn tên file local.
- Nếu migration/SQL tests không đạt: dừng trước bootstrap, giữ bằng chứng; không tự nới grants/policies hoặc đổi target. Không tự động rollback schema về3role sau khi đã có admin. Bootstrap lỗi rollback giao dịch của nó; nếu migration đã thành công thì ghi rõ schema deployed nhưng admin pending.
- Các SQL scripts chứa psql meta-command `\set` chỉ chạy qua psql, hoặc bỏ riêng dòng client directive trước khi gửi SQL qua MCP; không thay semantics transaction/fixtures/assertions. Không gọi hosted rollback tests là dry-run vì vẫn ghi fixture trong giao dịch.

**Problems / giới hạn:** Local PG18 khác PG17 staging; live migration/tests/advisors/bootstrap NOT RUN, account thật vẫn customer. Không có giao diện/API quản trị mới, role assignment UI, release publish, native acceptance hoặc nguồn bổ sung Discovery. Các helper kiểm admin từ session thật cho A1 vẫn pending. Bảng audit private cố ý không mở cho web/admin client trong R1; cần endpoint được kiểm quyền ở bước sau.

**Lesson Candidate:** fixture thiếu contract schema/role owner→harness dừng trước behavior cần kiểm→dùng schema thật và sửa fixture, giữ migration/history/assertions. Cấp role và ghi lịch sử riêng rẽ→có thể để lại quyền không có bằng chứng→cùng transaction, test ép audit lỗi để chứng minh promotion rollback. Role admin→không có nghĩa được đọc trips riêng của khách→test allow quản trị dữ liệu công khai và deny dữ liệu cá nhân độc lập.

**Review prompt:** Review đúng5files R1 ở trên: constraint/default/NOT NULL và normalize legacy không promote, grants+RLS deny, bootstrap exact confirmed subject/one-row/atomic audit/repeat guard, preservation của ownership và private trips, và giới hạn synthetic PG18 so với hosted PG17. Chưa apply staging/deploy/publish. Báo lỗi theo file và tình huống tái hiện; không sửa owner dirty work hoặc mở rộng Auth/lifecycle G4.

**Next:** chờ owner duyệt concrete staging packet; sau đó preflight lại→apply duy nhất R1→SQL suite staging→bootstrap exactsubject→readback/advisors. Chỉ sau nền này mới A1 draft/audit và A2 admin web theo roadmap; không nhảy sang thu thập nguồn Ninh Bình.

SHA256 R1 đã kiểm:
- migration: `86C71288F0133F94C67813FCB575AB32A08B630A1FE463FBD3E946963FCED5C8`
- bootstrap: `9CABF24FD679153ACBCFEE696605BA8163494A4FC69F1F503BBF6D79B1BE23BB`
- SQL tests: `FA6BADDE89213D92F8CF2FB860A790CF1776C83C796E8C2B5561C8E53257D8E7`
- local runner: `F2B579987E460B42D683F21E50C5FB0C58B9BC4BA057C351762333F097A8B940`

### R1 staging rollout — DEPLOYED / FIRST ADMIN VERIFIED (20/10/2026)

Owner đã xác nhận **“ok hãy tiến hành”** sau câu hỏi duyệt gói staging và exact account. Quyền này đã được dùng để apply duy nhất R1, chạy SQL suite rollback, bootstrap account đã chỉ định và kiểm readback/advisors. Không hỏi lại quyền/email, không dùng Superpowers, không mở rộng sang production/dependencies/native/deploy web/Storage.

**Changed:** staging `travel-go-staging` / `bkocylxbuyvdgxccpixx`, PostgreSQL17.11: `two_role_foundation` apply SUCCESS; role chỉ customer/admin, DEFAULT customer, NOT NULL, grants bảo vệ role và hai profile owner policies giữ nguyên. Đã bootstrap đúng subject `6346607e-40e0-4182-b887-2cf9d33321f9` từ customer→admin; hiện **1admin /2customer**, tổng3auth subjects/3profiles. Có đúng1audit record, old_role=customer/new_role=admin, actor_db_role=postgres, recorded_at=`2026-10-20T15:04:00.093576+00:00` (22:04:00 giờ Việt Nam). Actor postgres là SQL runner của thao tác đã được owner duyệt, không giả thành JWT user.

**Testing:**

- Trước mutation: kiểm hash3SQL đúng gói đã duyệt, branch/HEAD giữ nguyên; fresh target email đối chiếu exact UUID, confirmed=true, role=customer;3customer/0admin; constraint3role/nullable; role UPDATE denied; private_admin chưa tồn tại.
- Sau apply, chạy nguyên semantics `supabase/tests/profile_two_roles.sql` qua MCP execute_sql, chỉ bỏ dòng client `\set ON_ERROR_STOP on`.21assertions hoàn tất không SQL error, final assert returned; giao dịch ROLLBACK. Readback xác nhận0synthetic auth fixtures/0synthetic trip, vẫn3customer/0admin/0audit trước bootstrap. Đây là ghi fixture trong giao dịch rollback ở staging, không gọi là dry-run.
- Chỉ sau suite đạt và fresh subject/role/grants/confirmed vẫn đúng mới execute exact bootstrap script. Readback: exact owner-selected subject confirmed=true/admin,1admin/2customer/1audit. Không cấp admin cho hai customer còn lại.
- Fingerprint trước/sau không đổi: profile fields ngoài role/updated_at `570c815b71bd88bf98d6e322af4d31e9`; trips `33873fa8984f3ec92119ed337b777837`; activities `d751713988987e9331980363e24189ce`. Hai profile policies unchanged; authenticated UPDATE(role)=false; anon/authenticated/service_role SELECT audit=false; audit RLS enabled.
- Advisors security so baseline trước migration: **không có WARN mới**. INFO mới duy nhất `private_admin.role_bootstrap_audit` có RLS nhưng không có policy, đúng thiết kế private/no-client-access. Không thêm policy cho client để làm mất INFO. Tham khảo [RLS enabled/no policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
- Automated Flutter/Node gần nhất vẫn là full R1 source ở `20261020T145441117Z-22988`: analyzer clean/854Flutter/89Node PASS. Không chạy lại hoặc relabel thành check mới vì rollout không thay Dart/SQL source đã kiểm; không APK build/install/hot reload/native acceptance. PostgreSQL17 staging SQL verification ở trên là evidence mới của lượt này.

**Problems / giới hạn:**

- Advisors trước đó đã có WARN về anonymous/authenticated executable SECURITY DEFINER functions, anonymous-sign-in policy lint và leaked-password protection disabled; R1 không tạo WARN mới hoặc sửa Auth/functions ngoài gói. Existing public `set_profile_updated_at` và `verify_profiles_policy_drift` xuất hiện trong baseline; các RPC trip authenticated có từ trước, cần đánh giá theo ownership guards của từng function, không revoke hàng loạt làm hỏng app. Remediation: [anon SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [authenticated SECURITY DEFINER](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [anonymous policy lint](https://supabase.com/docs/guides/database/database-advisors?queryGroups=lint&lint=0012_auth_allow_anonymous_sign_ins), [leaked passwords](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
- MCP apply_migration ghi remote version **`20261020150315`**, name `two_role_foundation`; source local đã duyệt vẫn `20261020145005_two_role_foundation.sql`, hash không đổi. Ghi mapping này cùng lệch history cũ; chưa rename/rewrite history hoặc dùng db push. CLI migration-history reconciliation cần packet riêng trước khi chuyển sang CLI deploy; không replay R1 lên database đã đổi constraint.
- Chưa đăng nhập hộ user, chưa xác nhận UI/runtime nhận role mới, chưa tạo admin web/API/helper/session checks. Role admin trong DB không tự tạo menu quản trị. R1 không mở quyền đọc hồ sơ/trips của khách cho admin. Draft/version/audit nội dung/publish nằm ở A1/A2 kế tiếp; nguồn Discovery giữ20giá/17giờ/16both, full72 chưa hoàn tất.

**Why / bài học:** client đọc role từ profile được bảo vệ; mutation nhạy cảm vẫn phải được server kiểm quyền. Cấp đúng role không đồng nghĩa được xem mọi dữ liệu cá nhân. Kiểm fixtures rollback và fingerprint dữ liệu trước/sau giúp phân biệt schema đã deploy với feature UI đã hoàn tất.

**Evidence:** `docs/phase-3/ADMIN_R1_STAGING_ROLLOUT_EVIDENCE_20261020.json` lưu preflight, apply result, bootstrap result, final readback, migration history và advisor baseline/delta từ tools; ghi riêng SQL-suite summary vì connector chỉ trả final result, không xuất21NOTICE riêng. Không chứa token/service key hoặc nội dung private trips. Source SQL/harness hashes giữ nguyên gói R1; source Auth/Discovery không đổi. Source report và JSON evidence là2authored files của rollout, không sửa4file implementation đã kiểm; không stage/commit/push/merge.

**Lesson Candidate:** migration qua MCP có version server khác filename local→CLI có thể hiểu nhầm pending migration→ghi mapping và reconcile history trước db push. Cấp role là quyền dữ liệu server, UI là bước riêng→test/readback server trước, không báo admin UI hoàn tất chỉ vì role=admin.

**Next:** R1 foundation đã deploy; tiếp tục A1 (draft + revision/optimistic locking + audit + server authorization từ session thật), rồi A2 admin web list72/editor/preview/publish theo roadmap. Không cần hỏi lại owner chọn roles/email; live deploy/publish mới vẫn cần concrete review theo boundary đã chốt.

### A1 + admin editor — LOCAL VERIFIED / STAGING DEPLOY PENDING (20/10/2026)

Owner đã giao rõ: lưu nháp, phiên bản, lịch sử, rồi giao diện admin. Mức confidence HIGH dựa roadmap đã duyệt; không dùng Superpowers/agents, không hỏi lại roles/email. Giữ branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`,144dirty entries ở preflight. Đúng5authored files: migration mới, SQL suite, HTML admin, Node suite và ledger này. Guard25outer calls; không mở packet mới để reset trong lượt. Không sửa Flutter/Auth/lifecycle/native/dependency, không stage/commit/push/merge.

**Changed / Why:**

- `supabase/migrations/20261020151440_admin_discovery_drafts.sql`, CLI2.81.3 `migration new admin_discovery_drafts`: schema private chứa singleton draft và versions append-only. Seed từ raw asset72 hiện tại, giữ20giá/17giờ/16both, checkedAt/packages/source IDs/gaps, không renew ngày hay xuất bản. Revision1 là seed, mỗi save tăng revision và lưu snapshot/actor/request/base revision/reason/time/hash cùng transaction. Hash MD5 là fingerprint JSONB nội bộ, không thay SHA256 raw bytes của release builder.
- `public.admin_discovery` là SECURITY INVOKER wrapper; private SECURITY DEFINER endpoint với search_path rỗng/qualified names kiểm current protected profiles.role=admin, subject/session UUID khớp auth.sessions, not_after, banned/deleted/is_anonymous. Khóa chia sẻ role/auth/session rows trong giao dịch để không nâng quyền bằng metadata hoặc dùng token có session đã xóa. RLS bật trên2table private; không client direct SELECT/INSERT/UPDATE/DELETE; không RPC cấp role/public definer mới. Helper riêng không EXECUTE cho client; chỉ endpoint private được authenticated gọi qua wrapper và vẫn kiểm quyền.
- Draft shape giữ exact72IDs và release envelope/catalogue hash, source/package records là objects có id, price/hours/evidence/options/rules có cấu trúc cơ bản, payload<=2MiB. Cho phép nội dung nghiệp vụ chưa xác minh để lưu nháp, không coi draft là release hợp lệ. expectedRevision chặn stale write; requestUUID cùng actor/base/content/reason cho retry mất ack không thêm version; tái dùng UUID với nội dung khác bị chặn. Versions không sửa/xóa qua client. History50gần nhất + lookup revision cũ; khôi phục là đưa snapshot cũ vào editor rồi save thành revision mới.
- `admin/index.html`: web riêng, HTML/CSS/JS không thêm package. Login email/password dùng publishable staging key có sẵn trong cấu hình client; không yêu cầu admin nhập key và không copy secret/service role. Token chỉ trong memory tab, refresh single-flight, logout local scope, epoch chặn response cũ sau logout. Fixed staging origin/CSP; dynamic data dùng textContent; source link chỉ HTTPS không credentials. Chỉ đọc/live admin tách rõ; demo không có identity đặc quyền và không ghi server.
- UI danh sách72, tìm tên tiếng Việt/ID, lọc điểm đến/mức thiếu nguồn, form scope/notes/options giá/đối tượng/đơn vị/bao gồm/không gồm/điều kiện/gói/tuyến, lịch ngày/mùa/qua đêm/cutoff/giờ về, evidence riêng theo field, nguồn dùng chung và gói JSON nâng cao. Các sửa nguồn đang nhập được đưa vào save cùng place; checkedAt không auto-fill. Preview đọc được giá VNĐ/giờ thay vì chỉ raw JSON, giữ nhãn chưa xác minh. Lý do bắt buộc, loading/error/conflict, lost-ack retry phải đúng payload, beforeunload cảnh báo chưa lưu; lịch sử hiển thị actor/time/reason và so snapshot địa điểm. JSON export ghi rõ là NHÁP. Chưa có nút publish hoặc upload latest; không nới release contract để xuất bản16/72.
- `supabase/tests/admin_discovery.sql`:30assertions rollback với synthetic users/sessions. `test/admin_discovery_web_test.mjs`:17Node tests không network, chạy core thực trong VM (không dựng lại logic giả).

**Testing — current:**

- Local PostgreSQL18.6, database synthetic R1 có sẵn trong `.dart_tool/admin-r1-postgres/afb3ed1a7b324f80bd36b383245a178f/data`, chỉ bind loopback cổng tạm. Bổ sung minimal auth.sessions/auth.jwt/status columns theo live schema đã inspect, apply A1 và chạy30assertions PASS/exit0. Bao gồm anon/customer metadata spoof, thiếu/sai/mismatched session, admin positive, no direct table access/history mutation, save/version/actor, retry không duplicate, stale conflict, inventory/envelope/shape deny, immutable old version, forced audit failure giữ revision, revoked role/expired/banned/anonymous/logged-out session deny. Rollback về revision1/72places/1seed version. Server stopped xác nhận ở stop.log. Không coi minimal auth substrate là hosted Auth/JWT login/PostgREST acceptance.
- Logs `.dart_tool/admin-a1-verification/{migration.log,sql-tests.log,stop.log}`. Lượt đầu29PASS; thêm shape guard/preview/shared-input refinements, lượt cuối30PASS. Không yếu assertion hoặc sửa Auth/SDK để đạt. Có3vòng cải thiện UI/shape; không thêm repair vượtguard. Lần export seed qua stdout quá lớn bị truncation trước write; chuyển sang đọc asset tại filesystem để embed nguyên JSON trong migration. Một lệnh đọc nguồn dùng thuộc tính `.Line` của string gây lỗi chỉ-read; không product error hoặc test failure.
- `node --test test/admin_discovery_web_test.mjs`:17PASS/0fail; log `.dart_tool/admin-a1-web-tests.log`. Kiểm coverage20/17/16, unknown amount khác0, time parse, safeURLs, evidence future/issues/missing refs, stable inventory/shared packages, secret-key refusal, positive server read/customer denial, late login/read after logout, lost-ack exact retry/changed payload blocked, conflict/revoked role/required reason, human preview và no persistent token/dynamic HTML. Không dùng mock HTTP thay hosted authorization test.
- `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot 'D:/flutter/flutter'`: exit0, analyzer clean75.6s,854Flutter PASS1:30,89Node PASS/0fail. Logs `.dart_tool/travelgo-verification/20261020T152647063Z-28264/`; wrapper `.dart_tool/admin-a1-full-20261020.log`. Suite hiện có không tự include17web tests mới; chạy riêng như trên. Không Dart change nên không APK build/hot reload/native install.
- Browser localhost `http://127.0.0.1:8765/admin/`: login render, demo chỉ đọc đủ72/12 và20/17/16, tên tiếng Việt, search Văn Miếu→1kết quả, select/preview có nguồn/date và điều kiện. Save/form disabled ở demo. Không đăng nhập thật hoặc viết hosted draft. Screenshot cuối `.dart_tool/admin-a1-preview.png` là bản xem thử, không staging-live evidence. Local preview server chỉ whitelist HTML và2catalogue assets, bind127.0.0.1, không phục vụ toàn bộ repo/secrets.
- Skill UI/UX design-system2queries cho ra typography/landing không khớp admin; không persist/apply những phần không phù hợp. Dùng màu/tokens TravelGO hiện có, system font, flat/light form,44px controls, focus-visible, responsive stack theo UX table-handling guidance. Chưa làm kiểm thử viewport375px/keyboard/screen reader đầy đủ hoặc independent code review.

**Concrete staging deploy packet — CHƯA ÁP DỤNG:** target duy nhất `bkocylxbuyvdgxccpixx`, existing1admin/2customer giữ. Apply duy nhất migration A1 ở trên (không db push/history replay), tạo2private tables/seed snapshot + session-check endpoint + exposed INVOKER wrapper; không cấp role mới, không đọc private trips, không bucket/deploy production/public release. Sau apply chạy synthetic SQL rollback suite khi revision1, kiểm0fixtures/revision1/seed source checks unchanged/old user-role counts/grants/advisors; không mở policy chỉ để làm mất INFO RLS/no-policy private. Sau đó owner có thể login web bằng tài khoản admin thật để xác nhận lưu/đọc phiên bản trên staging; không xin mật khẩu trong chat hoặc đăng nhập hộ bằng cách nâng quyền demo.

**Problems:** Backend A1 chưa live; web hiện chỉ nối được demo cho tới apply được owner duyệt. Chưa deploy hosting web, chưa true-login browser/session-refresh/E2E two-admin tabs, chưa phát hành dữ liệu đầy đủ72, chưa publish immutable release/readback/latest. UI/API hiện quản lý giá/giờ/nguồn của72IDs; chưa cho tạo tỉnh/địa điểm mới hoặc sửa catalogue names/descriptions. History là snapshot toàn dataset nên hai admin sửa hai địa điểm vẫn có thể conflict; an toàn cho scope72, chấp nhận phải tải/so lại thay vì merge tự động. Tên actor dùng UUID (không mở quyền đọc private profiles khác); migration history remote có mapping khác filename local như R1, phải ghi sau apply.

**Lesson Candidate:** UI biết role không đủ bảo vệ phiên→check protected role và live matching Auth session ở mỗi thao tác server. Mất ack có thể là đã commit→retry cùng UUID/base/payload/reason, không tự mint request mới. Nguồn/gói dùng chung→save phải giữ toàn bộ metadata và không làm mới checkedAt chỉ vì mở form; incomplete draft vẫn khác release đủ điều kiện xuất bản.

**Next:** xin duyệt đúng concrete A1 staging deploy sau local review; apply→30SQL cases rollback→readback/advisors→owner login smoke. Tiếp tục publish backend/hosting/72-source completion theo packet riêng, không báo full Discovery hoặc full admin module complete từ local demo.

### Dynamic Admin — local implementation verified; Flutter regression gate OPEN (20/10/2026)

**Owner steering/authorization:** owner xác nhận12/72chỉ là dữ liệu đầu, muốn admin thêm điểm đến/địa điểm, yêu cầu toàn vẹn; sau phần giải thích owner nói **“ok vậy hãy tiến hành code”**. Đây là chấp thuận đổi scope và kiến trúc dữ liệu cần thiết, không phải yêu cầu invoke Superpowers. Không hỏi lại thiết kế/roles/email. Branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`; giữ dirty work trước đó. Preflight staging read-only xác nhận private_discovery_admin=NULL, admin_discovery RPC=NULL, không có migration history A1, vẫn1admin/2customer. Vì A1-fixed72 chưa deploy, sửa **prepared migration** hiện có thay vì rewrite migration đã áp dụng. Không ghi live database trong lượt này.

**Changed — đúng5files của packet:**

1. `supabase/migrations/20261020151440_admin_discovery_drafts.sql`: draft bổ sung `inventory.schemaVersion=1` cùng arrays destinations/places; seed metadata tên/mã từ catalogue readiness, description/ảnh/tọa độ/vùng chưa có thì để trống/null, không bịa dữ kiện. Bỏ exact72-set gate khỏi endpoint save. Thêm bảng projection private `destinations` và `places`, PRIMARY KEY immutable IDs; slug destination UNIQUE, place slug UNIQUE trong destination; FK destination_id NOT NULL, ON DELETE/UPDATE RESTRICT. CHECK tên/slug/description/imageHTTPS/coordinate range+pair; RLS enabled và không client direct grants. Đồng bộ projection+draft+version cùng giao dịch sau expectedRevision và idempotency checks. Không hard delete ID đã tồn tại qua endpoint; ẩn để giữ danh mục/lịch sử. Không sửa public.destinations/services/trips hiện có.
2. Cùng migration: kiểm inventory metadata/visit-details1:1, uniqueness IDs/slug, parent tồn tại, active child không thuộc hidden parent, source/package IDs không trùng, source/package tham chiếu tồn tại, giá nguyên không âm, thứ trong tuần không trùng/1–7, giờ/phạm vi qua đêm, ngày lịch thật/khoảng ngày/mùa. ReviewState/status hợp lệ; reviewed phải có refs/date hợp lệ không ở tương lai, không unresolved issues, source title/publisher/HTTPS. Nháp unverified vẫn để thiếu số tiền/tọa độ/giờ được. Không có giới hạn nghiệp vụ12/72; giới hạn payload2MiB/revision và history pagination50 vẫn là giới hạn kỹ thuật cần mở rộng bằng phân trang sau này.
3. `admin/index.html`: thêm form Thêm/Sửa điểm đến, Thêm/Sửa địa điểm; tên, slug, description, ảnhURL, parent, tọa độ, vùng tùy chọn, active/ẩn. ID tạo một lần, giữ nguyên; slugify tiếng Việt; cảnh báo tên gần giống và chặn trùng slug. Ẩn parent có con active phải xác nhận rõ số con rồi cùng ẩn. Lỗi form giữ nội dung và focus error summary. Metadata được áp dụng vào bản đang nhập, chỉ ghi server khi Lưu bản nháp. Header/counts/filter đọc inventory runtime, không suy parent từ prefix placeId; hỗ trợ UUID IDs mới và chuyển parent vẫn giữ ID. Khôi phục snapshot cũ giữ các ID thêm về sau ở trạng thái hidden, đồng thời giữ visit/source/package tham chiếu để không tạo orphan. Demo chỉ đọc, các nút ghi disabled; không coi demo là admin thật.
4. `supabase/tests/admin_discovery.sql`:50assertions, gồm30security/draft tests trước và20checks mới về parent/slug/name/coords/image/active flags/price/source/time/date/dynamic creation, immutable IDs, projection counts và FK thật. Thử save thành công13destinations/73places/revision3, rồi toàn transaction rollback về12/72/revision1/1version. RESTRICT test chỉ chấp nhận SQLSTATE23001(restrict_violation) hoặc23503(foreign_key_violation) và kiểm parent+child còn tồn tại sau failed delete; không chấp nhận lỗi bất kỳ như một PASS.
5. `test/admin_discovery_web_test.mjs`:26tests, giữ17case trước, thêm9case dynamic create13/73, slug/ID preservation, orphan/hidden parent, uniqueness scope, coordinates/URL/name, archive/move preserving IDs, restore merging hidden new IDs, price/source/package/time integrity và date/review evidence. Fixture VM được chuẩn hóa qua JSON copy để so sánh dữ liệu thay vì prototype khác realm. Tài liệu ledger này là file thứ5, không mở thêm file/source Dart ngoài allowlist.

**Why / luồng:** admin nhập metadata→validation form/core→lưu whole-draft với expectedRevision/requestUUID→server kiểm role và session thật→kiểm toàn vẹn→UPSERT các bảng có PK/UNIQUE/FK/CHECK→append version+update draft→readback. Lỗi bất kỳ rollback cả projection/draft/history.12/72chỉ là seed; đã chứng minh thêm13/73 không cần sửa hằng số. Đổi tên/slug/parent không đổi stable ID; khôi phục/ẩn không xóa dữ liệu đã được lưu, giúp giữ tham chiếu của lịch sử. Các bảng projection hiện phục vụ draft admin, chưa phải public catalogue được khách đọc.

**Testing — current evidence:**

- PostgreSQL18.6 local synthetic substrate đã có từ R1/A1, chỉ listen127.0.0.1 cổng tạm. Recreate đúng private admin schema trong local disposable cluster, apply prepared migration SUCCESS; final50SQL PASS/exit0. Logs `.dart_tool/admin-dynamic-verification/{migration.log,sql-tests.log,sql-tests-diagnostic.log,sql-tests-final.log,stop.log}`. Lượt đầu fail ở expectation mã FK (server đã chặn xóa), diagnostic actual23001, chỉnh phép kiểm theo hai loại lỗi FK/RESTRICT xác định và thêm row-survival assertion; final50PASS. Sau rollback:12destinations/72places/revision1/1version; stop.log xác nhận server stopped. Không nhận localhost PG18/Auth substrate là hosted PG17/JWT/browser login acceptance.
- Node26PASS, `.dart_tool/admin-dynamic-web-tests-final.log`; toàn bộ `test/*.mjs` chạy bằng danh sách file rõ ràng **115PASS/0fail**, `.dart_tool/admin-dynamic-all-node-tests.log`. Initial25pass/1fail do deepStrictEqual giữa Node và VM prototypes; chuẩn hóa fixture, giữ nguyên assertions nội dung, sau đó26PASS. Không nới security assertions hoặc fake hosted server.
- `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot 'D:/flutter/flutter'`: analyzer sạch14.5s, Flutter **852PASS/2FAIL** trong4:28, wrapper exit1. Logs `.dart_tool/travelgo-verification/20261020T155019091Z-5096/` và `.dart_tool/admin-dynamic-full-20261020.log`. Full dừng trước Node; Node115ở trên là kiểm riêng mới, không relabel thành full pipeline PASS.
- Chạy riêng hai file sau khi full kết thúc: `-Mode Targeted -TestPath @('test/editable_guest_import_ui_test.dart','test/editable_saved_trip_ui_test.dart')`: **18PASS/2FAIL**,35s,exit1; `.dart_tool/travelgo-verification/20261020T155528224Z-16132/`, `.dart_tool/admin-dynamic-flutter-isolated-20261020.log`. Hai case: `lost local ack retries original request even after Guest revision advances` (expected false/actual true) và `saved detail photos use stable ids and large text preserves read-only ledgers` (pumpAndSettle timeout). Hai tình huống đã xuất hiện ở checkpoint Discovery cũ; lần này vẫn tái hiện isolated, **chưa xác định nguyên nhân**, không quy chắc do concurrency hoặc do admin. Không sửa/nới Dart tests, Auth/lifecycle, source trip/photo hoặc gọi full suite lại vô hạn. Full854PASS của A1 trước đó chỉ là lịch sử, không thay kết quả hiện tại.
- Browser reload localhost→demo: thấy nút thêm/sửa điểm đến/địa điểm, count lấy seed metadata, parent labels tiếng Việt; demo disables write. Screenshot `.dart_tool/admin-dynamic-preview.png`, SHA`EC66B278B0CBE0A5EED3D3063B0E0DE1D693105BCFA0F5380A4791D51A2FDED7`, tab deliverable. Đây là UI xem thử; tạo13/73 được xác minh bằng core+SQL, chưa có logged-in browser create/save smoke. Không xem screenshot seed12/72 là chứng cứ vẫn khóa số lượng.
- AuthProvider SHA vẫn `DDA2638475DE666DD532F0F1844CA3093A0BCF517E0A7FBFAEBCF9EDE6E765AC`; visit seed vẫn `26BB382E435DEB1AE84B23C4642C2758E263B118D75F90420B1430EEFF7D189A`. Không đổi reviewed facts20/17/16 hoặc check dates, không Dart/APK/hot reload/native/dependencies/SDK/permissions change. Scoped whitespace/diff checks kiểm lại khi đóng packet. Owner tree không reset/stash/commit/push/merge.

**Problems / remaining:**

- Global Flutter gate đang FAIL2 như trên; local dynamic SQL/web checks PASS không xóa finding này. Chưa có independent review. Backend A1/dynamic chưa deploy, server R1 vẫn1admin/2customer; chưa có public dynamic release/hosting hoặc user login smoke.
- **Mobile integration chưa làm:** Flutter catalogue parser/release builder/visit repository còn dùng pinned seed contract. Cần packet tiếp theo về public catalogue+visit manifest đồng bộ hash/version/IDs động, cache/last-known-good, active filtering, giữ snapshot trips cũ và xử lý điểm mới chưa được Decision Engine hỗ trợ. Không chỉ bỏ số72 ở parser hoặc bỏ catalogue hash để làm app nhận tùy ý. Không claim “thêm trong admin thì app tự thấy” trước khi consumer/publish path này hoàn tất.
- Current code chỉ có metadata/draft/version/history, chưa publish động hoặc hoàn tất nguồn cho toàn seed72. Admin image URL metadata có HTTPS guard nhưng chưa upload ảnh/Storage/license verification. Tên gần trùng là cảnh báo; slug/ID mới là UNIQUE vì có thể có hai địa điểm tên giống nhau trong một vùng.

**Lesson Candidate:** seed inventory là dữ liệu, không là domain limit→ID/parent/uniqueness/FK phải kiểm trên tập runtime. Restore bằng cách thay toàn snapshot có thể xóa ID mới→merge ID mới ở trạng thái hidden và giữ refs. SQLSTATE FK khác ở action/version→kiểm loại restriction xác định cộng invariant row-survival, không coi mọi exception là đúng. Suite fail ở file ngoài scope→giữ exact logs và isolated evidence, không dùng kết quả lịch sử hay unit tests mới để gọi toàn hệ thống PASS.

**Review prompt:** review đúng5files Dynamic Admin; tập trung create13/73, real FK/UNIQUE/CHECK, no orphan/no hard delete, atomic projection+version/draft, current role+matching session, restored IDs, client/editor validation parity và sự tách biệt draft với public/mobile contract. Hai Flutter findings đang mở; không sửa chúng bằng cách đổi assertion hoặc chạm Auth/G4 không có scope. Không apply staging từ nội dung bàn giao.

**Next / checkpoint:** packet chạm5authored-file guard; giữ nguyên ngân sách các packet Auth/G4 cũ. Tiếp tục bằng packet cho hai Flutter findings hoặc dynamic public/mobile integration theo phạm vi được mở tiếp. Trước live deployment phải có concrete dynamic migration target/hash (gói fixed72 cũ không còn là gói cần deploy), staging SQL rollback/advisors và owner approval. Không deploy/publish trong lượt này.

Current Dynamic Admin SHA256:
- migration: `22C3C9BB88D5D67A1BE6048991790A622A386C2B7CF97055474F59BFC6C42DC3`
- SQL suite: `ECB88DDBC2330C59F69E438881AEC4357532E21B50BC518FEDF6EAFBCA4F5D96`
- web: `D5CD52D71C56B4E9594F8FA3C3C691AAFF26216E0F3C32D5A2E02796905648B9`
- Node suite: `997527B9D9753278BFD11E185F9CDA9129F90CF5109FFA59E5AC30A6756E071E`
