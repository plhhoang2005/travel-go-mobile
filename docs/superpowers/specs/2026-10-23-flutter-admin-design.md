# TravelGO — Thiết kế khu quản trị Flutter và xuất bản danh mục

Ngày: 23/10/2026, Asia/Saigon. Trạng thái: **SPEC APPROVED FOR PLANNING — owner đã duyệt bản viết và chọn Codex lập kế hoạch/review, Antigravity code; phạm vi/budget implementation còn chờ review.**

## 1. Yêu cầu đã chốt và kết quả cần đạt

Owner yêu cầu quản lý người dùng, khóa/mở tài khoản, cấp quyền bằng UI, dashboard thống kê và thêm/sửa/ẩn điểm đến/địa điểm trong Flutter. Owner chọn **A: lưu nháp → xem trước → xuất bản → app khách nhận danh mục mới**, đồng thời yêu cầu dùng Superpowers để lập kế hoạch chi tiết.

Đầu ra sản phẩm: admin đăng nhập ứng dụng Android hiện có, vào mục Quản trị trong Cá nhân, thực hiện các nghiệp vụ trên với dữ liệu server thật. Customer/Guest khám phá danh mục đã xuất bản, nhận cập nhật trên cùng APK, vẫn mở được chuyến đi cũ. Tài khoản bị khóa mất quyền truy cập dữ liệu tài khoản trên server; thu hồi admin có hiệu lực tại các thao tác quản trị tiếp theo.

Giữ hai role `customer`/`admin`. Guest là trạng thái chưa đăng nhập. Giữ Flutter, Provider, Dio, Material/AppTheme, SQLite, Supabase; chưa đề xuất dependency hay native permission mới. Không thêm booking/payment, social, quota AI hoặc thuật toán quyết định.

Các quyết định dưới đây đã được owner duyệt làm cơ sở lập kế hoạch, không được coi đã triển khai hoặc đã được cấp quyền deploy. Không hỏi lại phương án A hay thứ tự nghiệp vụ đã thống nhất. Approval ngày 23/10/2026: “duyệt bản thiết kế này để mình viết kế hoạch triển khai cụ thể theo file, API và test”.

Checklist Superpowers cho lượt thiết kế:

- [x] Phân loại architectural; khôi phục context và kiểm tra source liên quan.
- [x] Ghi nhận ý định, scope A, ràng buộc và tiêu chí thành công.
- [x] So sánh hướng kỹ thuật, chọn đề xuất phù hợp code hiện tại.
- [x] Viết thiết kế toàn hệ thống và ranh giới các phần có thể lập kế hoạch riêng.
- [x] Tự review nội dung, nhất quán contract và các trường hợp lỗi.
- [x] Owner review và duyệt bản spec này.
- [x] Sau duyệt spec: dùng writing-plans viết ba implementation plan theo file, API, constraint và test.
- [x] Owner chọn phân công: Codex lập kế hoạch/review, Antigravity code và sửa findings.
- [ ] Owner review kế hoạch và duyệt budget/file exception hoặc giao task cụ thể trước code.

## 2. Baseline đã đọc và giới hạn bằng chứng

Checkout: `D:/Travel-Go-Android/travel-go`, branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`. Status hiện có nhiều file modified/untracked thuộc work trước; HEAD không đại diện toàn bộ source hiện tại. Không reset/stash/clean hoặc gộp work cũ vào thay đổi mới.

| Thành phần | Đọc được trong source/checkpoint | Ý nghĩa đối với thiết kế |
|---|---|---|
| Flutter role | `UserRole` chỉ customer/admin; AuthProvider lấy role từ profile được bảo vệ | Tái sử dụng; badge/demo không cấp quyền server |
| Flutter navigation | Shell có 5 tab khách; Profile chưa có đường vào quản trị | Thêm route quản trị lồng, không thêm tab khách thứ sáu |
| Admin dynamic | Prepared migration `20261020151440_admin_discovery_drafts.sql`, web editor, SQL/Node tests | Tái sử dụng IDs, parent FK, draft/revision/history/audit; xác minh live trước migration |
| Admin authorization | Prepared `private_discovery_admin.require_actor()` kiểm profile hiện tại, auth user/session, ban, anonymous | Dùng cùng nguyên tắc ở mọi endpoint mới; không suy backend A1 đã deploy |
| Discovery | `CatalogueRepository` đọc bundled V1; parser có regions/IDs/rights/source rules cố định | Cần protocol V2 và repository public thống nhất, không chỉ bỏ check số lượng |
| Visit details | Repository/cache ràng buộc expected IDs + catalogue hash, remote origin staging | Bảo toàn integrity; thay bằng snapshot đồng bộ của release V2 |
| Home | Destinations hiện đọc bảng riêng rồi fallback | Phải chuyển phần destination sang cùng public snapshot để không hiện mục đã ẩn |
| AI | `itinerary-proposal/gateway.mjs` có allowlist 12 destination IDs | Điểm mới hỗ trợ manual trước; không tự bỏ allowlist hoặc gọi engine/AI hỗ trợ mọi ID |
| Account data | Có direct-table RLS, V1/V2 trip RPC, favorites, preferences và AI gateway | Khóa tài khoản phải bảo vệ các đường cũ, không chỉ endpoint admin |
| Historical checks mới hơn | Admin Dynamic ledger ghi analyzer clean, Flutter 852 PASS/2 FAIL; isolated 18 PASS/2 FAIL, Node 115 PASS | Đây là báo cáo lịch sử; chưa chạy lại trong lượt thiết kế, chưa gọi toàn hệ thống PASS |

Hai failure lịch sử cần xác minh trước thay đổi sản phẩm: mất local acknowledgement khi Guest revision tăng; ảnh detail/chữ lớn bị `pumpAndSettle` timeout. Không sửa assertion, quy flaky hoặc mượn ngân sách Auth/G4 cũ. Checkpoint PHONE03 cũ và acceptance P3.2 còn mở không bị spec này thay thế.

Chưa inspect live database trong lượt này. Mọi số tài khoản, migration đã áp dụng hoặc trạng thái staging chỉ là thông tin checkpoint cho tới readback mới.

## 3. Các hướng đã cân nhắc

| Hướng | Ưu điểm | Hạn chế | Đề xuất |
|---|---|---|---|
| Flutter + guarded RPC + Edge Function cho thao tác đặc quyền + release bất biến | Dùng lại stack và draft hiện có; server kiểm quyền; client có snapshot offline nhất quán | Cần thiết kế đồng bộ Auth/API, publication và cache rõ ràng | **Chọn hướng này** |
| Flutter ghi trực tiếp bảng profile/destination và app đọc bảng đang sửa | Ít lớp ban đầu | Khó giữ nháp/xuất bản, khó khóa token cũ, dễ mở quyền quá rộng và đọc dữ liệu nửa chừng | Không chọn |
| Xây backend Java quản trị và storage mới | Có thể tách riêng hoàn toàn | Nhân đôi identity, quyền và vận hành với Supabase hiện tại | Không chọn cho scope này |

## 4. Trải nghiệm Flutter

### 4.1. Điều hướng và trạng thái

`Cá nhân → Quản trị → Tổng quan / Người dùng / Danh mục / Xuất bản & lịch sử`.

Chỉ hiện entry khi AuthProvider có tài khoản thật và trusted admin role; mở route còn phải qua kiểm tra admin hiện hành ở server. Chưa xác minh thì loading; bị từ chối thì đóng nội dung quản trị và xóa dữ liệu admin khỏi RAM. Customer/Guest/demo mở route trực tiếp vẫn bị từ chối.

Điện thoại dùng danh sách và trang detail/form; màn rộng dùng NavigationRail và vùng nội dung. Dùng theme/textTheme hiện có, touch target Android ít nhất 48 logical pixels, nhãn cho icon, hỗ trợ chữ lớn, SafeArea, Back/Cancel và form không mất dữ liệu khi lỗi. Không dùng bảng cuộn ngang làm cách duy nhất quản lý tài khoản trên điện thoại.

Các màn có loading/error/empty/retry riêng. Mỗi mutation chống bấm lặp; toast thành công chỉ sau acknowledgement server. Khi kết quả chưa rõ do mất mạng, giữ operation ID và hiển thị “Chưa xác nhận kết quả”, không tự gửi một thao tác mới.

### 4.2. Người dùng và quyền

- Danh sách phân trang 25 mục; tìm theo tên/email, lọc role và trạng thái. Chỉ tài khoản không anonymous, chưa xóa; sort `(createdAt DESC, id DESC)` với cursor ổn định.
- Detail chỉ có ID, tên, email, ngày tạo, lần đăng nhập gần nhất nếu có, role, trạng thái khóa và lịch sử quản trị liên quan. Không mở private trips, khoản chi, số điện thoại/địa chỉ của người khác.
- Không có xóa tài khoản, tạo user, đổi mật khẩu hay gửi email trong scope này.
- `Khóa`, `Mở khóa`, `Cấp admin`, `Thu hồi admin` đều có dialog nêu đúng target, trước/sau và lý do bắt buộc 1–500 ký tự.
- Admin được quản lý tài khoản khác. Không tự khóa hoặc tự đổi role; không khóa/hạ quyền admin hoạt động cuối cùng. Không thêm superadmin/role thứ ba.
- Trạng thái tài khoản và trạng thái đồng bộ Supabase Auth được trình bày riêng nếu thao tác đang xử lý dở; UI không báo “Đã mở khóa” khi Auth chưa đồng bộ xong.

### 4.3. Dashboard có định nghĩa số liệu

Server trả một snapshot số liệu kèm `asOf`, không để Flutter tải toàn bộ users rồi tự đếm:

| Chỉ số | Định nghĩa |
|---|---|
| Tổng tài khoản | User không anonymous, chưa xóa, có profile; có tính tài khoản bị khóa |
| Tài khoản bị khóa | Account access khác enabled hoặc Auth đang ban; pending-unlock vẫn bị khóa |
| Admin hoạt động | Role admin, access enabled, Auth không ban/xóa; không đồng nghĩa online |
| Đăng ký mới | Đếm theo `auth.users.created_at`, biểu đồ theo ngày trong 7/30 ngày lịch Việt Nam, gồm hôm nay |
| Danh mục nháp | Số destination/place active/hidden của revision nháp hiện tại |
| Danh mục đã xuất bản | Số destination/place của release đang active; ghi rõ nếu chưa có release |
| Trạng thái nội dung | Draft revision, published source revision, version đã xuất bản và thay đổi chưa xuất bản |

Không ghi “người dùng online”, doanh thu, lượt xem hoặc chuyến đi phổ biến khi chưa có nguồn đo tương ứng. Dữ liệu không tải được hiển thị lỗi/giá trị chưa có, không giả thành 0.

### 4.4. Điểm đến và địa điểm

- Destination: tên, slug, vùng, mô tả, URL ảnh tùy chọn, nguồn tham khảo, active/hidden.
- Place: tên, slug, destination cha, mô tả, URL ảnh tùy chọn, cặp latitude/longitude tùy chọn, nguồn và active/hidden.
- ID server tạo một lần và bất biến; sửa tên/slug không đổi ID. Destination slug duy nhất; place slug duy nhất trong destination; parent phải tồn tại. Tên gần giống chỉ cảnh báo.
- Form cho phép lưu nháp thiếu dữ liệu công bố nhưng giữ lỗi cấu trúc ngay tại trường. URL HTTPS, tọa độ hợp lệ/đủ cặp, giới hạn độ dài và quyền nội dung phải được kiểm tra ở server.
- Thêm mới không bị giới hạn 12/72; giới hạn kỹ thuật payload nháp hiện tại 2 MiB vẫn giữ và UI báo rõ khi chạm giới hạn.
- Không hard delete. Ẩn destination xác nhận số place active sẽ bị ẩn cùng trong một transaction; hiện lại parent không tự hiện tất cả con. Chuyển parent giữ ID và kiểm lại uniqueness.
- Giữ nguyên dữ liệu giá/giờ/nguồn/gói hiện có khi form sửa metadata. Không viết lại toàn bộ editor giá vé/lịch mùa nâng cao trong scope này; dữ liệu này vẫn được giữ và hiển thị trong preview/public theo mức xác minh.
- Lưu nháp tăng revision và ghi actor/reason/request ID; khôi phục lịch sử tạo nháp mới, không xóa ID được tạo sau revision cũ.

## 5. Phân quyền và quản lý trạng thái tài khoản

### 5.1. Nguồn quyết định quyền

Role tiếp tục ở `public.profiles.role`, chỉ thay đổi qua mutation server có kiểm quyền. Không cấp quyền bằng user_metadata, local badge, app flags hoặc mở quyền UPDATE(role) trực tiếp cho authenticated.

Đề xuất thêm schema private quản trị chứa `account_access`, `account_operations`, `audit_events` và một khóa điều phối singleton. Đây là tên contract đề xuất; implementation plan sẽ khóa tên SQL cụ thể, grants và đường migration sau khi spec được duyệt.

`account_access` chứa subject, trạng thái `enabled/locked/unlocking`, revision, lý do/actor/thời điểm và mốc `session_valid_after`. Migration backfill user hiện có; user tạo mới có access row trong cùng giao dịch tạo profile. Thiếu row là deny, không mặc định enabled. Ban đang tồn tại trong Auth được bảo toàn; không bulk-unban.

Mọi truy cập tài khoản được bảo vệ kiểm auth.uid, auth user chưa bị ban/xóa, access enabled và đúng phiên hiện hành. Session phải có `auth.sessions` phù hợp, chưa quá hạn và được tạo sau `session_valid_after`. So mốc theo session creation, không theo JWT iat, vì refresh JWT không tạo phiên đăng nhập mới.

Các endpoint admin kiểm thêm protected current role=admin trong transaction. Quyền đọc public release vẫn dành cho Guest và không bị biến thành dữ liệu private.

### 5.2. Khóa/mở khóa và thao tác dở

Supabase Auth Admin API chỉ được gọi từ Edge Function phía server. Không ghi trực tiếp `auth.users`/`auth.sessions` bằng SQL để thay thế Admin API; không đưa service key vào Flutter.

Luồng khóa:

1. Server xác minh actor, target, expected revision, operation ID và lý do. Khóa điều phối giúp kiểm last-active-admin không bị race giữa hai thao tác.
2. Transaction ghi access=locked, tăng revision và session_valid_after, operation pending, audit; từ commit này các request account mới bị deny dù JWT chưa hết hạn.
3. Edge Function gọi Admin API để ban đăng nhập/refresh, đọc lại trạng thái Auth, rồi ghi operation hoàn tất. Nếu API lỗi, access vẫn locked và UI báo đang chờ đồng bộ; retry cùng ID tiếp tục thao tác cũ.

Luồng mở khóa: access vẫn deny trong trạng thái unlocking, bỏ ban qua Admin API và xác minh, sau đó mới chuyển enabled với session_valid_after mới. Phiên cũ không tự có quyền trở lại; người dùng đăng nhập lại. Không dùng admin signOut với token của target vì admin không được thu thập token người dùng khác.

Khóa và kiểm access được tuyến tính hóa tại giao dịch server. Request đã được server cho phép trước commit khóa có thể hoàn tất; không tuyên bố hủy hồi tố thao tác đã commit. Mỗi operation gồm actor/target/base revision/payload hash, pending/completed/needs_retry; retry khác payload cùng ID bị chặn. Không dùng quyền lịch sử để cho phép replay: actor phải còn quyền hiện hành mới được đọc lại kết quả quản trị.

Các thao tác Auth cho một target được điều phối theo operation/revision; mutation đối nghịch không được chạy đồng thời với operation chưa rõ kết quả. Worker hoàn tất phải kiểm lại target revision; kết quả API cũ không được chuyển access của revision mới thành enabled. Nếu actor cũ mất quyền, admin hợp lệ khác có thể yêu cầu đối chiếu/tiếp tục đồng bộ bằng operation mới tham chiếu operation cũ; giữ actor gốc trong audit và không lặp thay đổi quyền đã commit. Khi cần đối chiếu, database access state vẫn là nguồn quyết định deny; trạng thái ban của Auth chưa khớp phải được trình bày và retry rõ ràng.

Đổi role chỉ cần transaction PostgreSQL + audit + expected revision, dùng cùng khóa last-active-admin. Việc demote admin không khóa quyền customer của họ; request admin tiếp theo bị deny ngay theo role hiện tại. Pending-unlock không được tính là active-admin để vượt guard.

### 5.3. Bảo vệ các đường truy cập cũ

Phải kiểm kê grants/RLS/RPC thực tế trước migration; helper private không được thành public definer không kiểm quyền. Bổ sung account/session predicate cho profile/preferences, favorites, trips/activities/user_vouchers và các bảng private/account exposed có liên quan; giữ ownership A/B hiện tại. RPC definer V1/V2/import và đầu ra idempotency phải kiểm access trước cả trả cached receipt.

AI gateway phải kiểm account access/session trước quota reservation, trước dispatch và trước trả kết quả/cached result; worker service role không được làm thay quyền tài khoản. Guest AI giữ consent/allowlist/quota hiện hữu; không mở scope hoặc tăng hạn mức.

Flutter kiểm lại quyền khi mở admin, resume foreground và nhận 401/403; xóa RAM admin và chặn late responses theo owner/session epoch. Khi server xác nhận account bị khóa thì dùng lifecycle hiện có để thu hồi quyền RAM và ngăn publish response cũ; không xóa Guest drafts.

Thiết bị hoàn toàn offline không nhận được lệnh khóa từ xa. Giữ quy tắc offline snapshot/account hiện tại, không hứa xóa dữ liệu đã cache tức thì hoặc đổi toàn cơ chế offline để làm demo. Online trở lại phải xác minh trước truy cập dữ liệu tài khoản. Đây là giới hạn nghiệm thu phải nêu rõ.

## 6. Danh mục công khai V2 và xuất bản

### 6.1. Một snapshot đồng bộ

Đề xuất protocol `travelgo.discovery.release.v2`: một bundle JSON chứa catalogue metadata và visit details tương ứng, stable IDs, source references, trạng thái xác minh, không chứa user/actor/email/audit/private draft. Public projection chỉ lấy destination/place đang active và các source/package được chúng tham chiếu; không phát tán nội dung nháp của mục hidden/chưa từng xuất bản. Trip cũ dùng snapshot đã lưu khi reference không còn trong release mới. Một manifest chọn toàn bộ bundle; client không trộn catalogue version mới với visit details version cũ.

Manifest chỉ có protocol/schema, version tăng dần, object key cố định trong origin/bucket allowlist, SHA256 trên raw bytes, byteLength và publishedAt. Bundle 2 MiB tối đa; mọi ID/parent/source/package refs, flags, tọa độ và typed values được kiểm. Preview draft dùng DTO private riêng, không được đưa vào public cache.

**Delta cần owner duyệt cùng spec:** V2 cho phép xuất bản tên/metadata có nguồn và thông tin vận hành còn unknown. Giá/giờ chưa xác minh được loại khỏi public values, hiển thị “Chưa có dữ liệu đã xác minh”; không coi unknown là 0/miễn phí/mở cả ngày. Mọi field reviewed vẫn phải có nguồn, ngày kiểm và điều kiện hợp lệ. Gói V1 FULL hiện yêu cầu 72/72 reviewed vẫn giữ nguyên; V2 metadata release không được báo là đã đạt FULL/FR-AI-005. Nếu không duyệt delta này, release mới còn bị chặn cho tới khi toàn bộ dữ liệu active đạt yêu cầu đầy đủ.

Không gia hạn checkedAt khi publish. Thiếu nguồn cho tên/ảnh, tham chiếu hỏng hoặc reviewed value mâu thuẫn phải chặn publish với đường dẫn field. Mô tả tự biên soạn cần đánh dấu nguồn gốc; URL ảnh chỉ được công bố khi có nguồn/quyền sử dụng được khai báo, không suy có license từ HTTPS.

### 6.2. Chuẩn bị và kích hoạt release

Chọn Storage cho immutable bundle và **một public manifest row trong PostgreSQL** làm con trỏ active. Row chỉ chứa dữ liệu manifest, public SELECT với RLS rõ ràng, không client write; private release/audit tables tách riêng. App GET manifest bằng client public riêng, không token tài khoản/cookie. Publish không ghi đè `latest.json` của protocol cũ.

Vì Storage và PostgreSQL không có transaction chung:

1. Admin đã lưu nháp → yêu cầu preview theo exact draft revision. Server trả tóm tắt thêm/sửa/ẩn, warning/blocker, source revision và digest.
2. Admin xác nhận xuất bản bằng request ID, exact preview digest, expected draft revision và expected active release version. Server giữ frozen draft snapshot; cấp số version duy nhất, số bị bỏ trống khi thất bại là hợp lệ.
3. Server serialize một lần, tính raw SHA/length, upload object `releases/v2/<version>.json` không upsert. Đọc lại URL public đúng origin, không redirect, kiểm bytes/hash/length; không download URL do client tùy ý gửi.
4. Sau readback, một DB transaction kiểm lại current actor/session/role, draft revision, preview digest và expected active version; cập nhật public manifest cùng audit/published source revision. Đây là điểm có hiệu lực của publication.
5. Nếu draft/active/role đổi giữa lúc upload, activation bị từ chối. Active cũ giữ nguyên; object ứng viên có thể tồn tại nhưng chưa được app chọn. Không tự đổi preview sang nội dung mới.
6. Retry cùng operation ID lấy lại trạng thái đã chuẩn bị/kích hoạt; không tạo hai active versions. Khi response mất sau activation, UI tra operation thay vì publish lại.

UI: “Đã lưu nháp” và “Đã xuất bản phiên bản N” là hai trạng thái riêng. Nếu đã publish thành công nhưng client cũ chưa refresh, không báo mọi điện thoại đã cập nhật.

Sửa sai: tạo version cao hơn từ nội dung đúng hoặc từ snapshot cũ; giữ IDs mới hơn ở hidden khi restore nháp. Không giảm version, thay bytes object cũ hoặc xóa release mà cache client còn dùng. Dọn orphan Storage không nằm trong scope thao tác tự động đầu tiên.

### 6.3. App khách nhận dữ liệu

Một repository/public snapshot provider dùng chung cấp dữ liệu destination cho Home, Khám phá, detail, destination picker của planner và các lookup map/favorites liên quan. Services/tours/vouchers không được chuyển vào danh mục này chỉ vì Home cũng hiển thị chúng.

Luồng tải: validated SQLite last-known-good → seed tương thích nếu chưa có cache → GET manifest → kiểm version/protocol/origin/length/hash/schema/refs → transaction ghi nguyên bundle + manifest vào SQLite → thay snapshot RAM một lần. Cùng version khác hash bị chặn; thấp version bị bỏ qua; version schema cao hơn hỗ trợ giữ cache cũ và hiện cần cập nhật ứng dụng.

Lần đầu mở khi online và nút “Cập nhật danh mục” yêu cầu refresh; foreground resume chỉ tự refresh nếu lần thành công gần nhất quá 5 phút. Debounce/single-flight, không timer nền hoặc yêu cầu mạng từ build(). UI ghi version, thời điểm tải và nguồn seed/cache/server; lỗi mạng giữ snapshot hợp lệ và cảnh báo. Không cam kết push/realtime hoặc thời gian mọi thiết bị phải cập nhật.

All-hidden hoặc destination chưa có place là trạng thái hợp lệ: hiện empty state; không dùng fallback hardcoded để làm mục đã ẩn xuất hiện trở lại. Count động, IDs không phụ thuộc prefix, zero/một/nhiều items được hỗ trợ trong V2. Không nới parser V1 để chấp nhận nội dung khác contract cũ.

Trip đang mở giữ immutable snapshot và user input của nó; background refresh không đổi tên/giá/ngày/actualExpenses trong document. Hidden entries biến mất khỏi lựa chọn mới nhưng trip/favorite cũ vẫn đọc snapshot, ghi nhãn không còn trong danh mục; không xóa chuyến đi hoặc tự đổi stable reference. Khi bắt đầu chuyến mới phải chọn active destination; form đã mở không mất dữ liệu nếu destination vừa bị ẩn.

### 6.4. Tương thích planner/AI/engine

Destination mới xuất bản phải dùng được cho manual planner → Guest local và Account save/list/reopen. Kiểm validator server/client để không giữ hardcoded 12-ID gate ở đường lưu manual.

Giữ allowlist engine/AI hiện tại cho các mode cũ. Destination chưa hỗ trợ có nhãn và nút manual hoạt động; nút AI/automatic disabled kèm lý do. Không phát sinh request quota bị từ chối chỉ để UI biết là chưa hỗ trợ. Các destination cũ tiếp tục AI như cũ; không giảm kiểm nguồn, consent, quota hoặc đánh dấu routingReady=true tự động. Old APK tiếp tục seed/protocol V1; không được nhận bundle V2 rồi crash.

## 7. Contract và trách nhiệm các lớp

| Ranh giới | Đầu vào/đầu ra nghiệp vụ | Trách nhiệm |
|---|---|---|
| Admin access | Phiên hiện tại → allowed/denied và khả năng quản trị | Server current role/status/session; Flutter chỉ điều hướng |
| User list/detail | query/filter/cursor → UserSummary page; target ID → detail | Server chỉ trả trường tối thiểu, không tokens/raw metadata |
| Account mutation | requestId, target, expectedRevision, action, reason → operation status + target revision | Guard actor/target/last-admin, audit, Auth sync retry |
| Dashboard | window 7/30 → metrics, daily registrations, asOf | Aggregate trên server, ngày Việt Nam |
| Discovery draft | read/save/version theo contract hiện có | Atomic revision/ID/parent/history; server tạo ID trong mutation có kiểm quyền |
| Publication | exact preview + expected draft/active versions → operation/release | Frozen candidate, Storage readback, CAS activation |
| Public catalogue | manifest + immutable bundle → validated PublicSnapshot | Một cache atomically đồng bộ metadata/visit details |

Các lỗi phân biệt: unauthorized/account_locked/admin_required, conflict, invalid_field, last_admin, self_change_denied, outcome_pending, upstream_unavailable, release_integrity_failed, unsupported_protocol. Không trả stack trace/tokens/raw Auth response cho client. UI giữ input khi validation/conflict; conflict hiển thị bản server để tải/so lại, không auto-overwrite.

Dart models immutable; service phụ thuộc Dio/Supabase client hiện có; Provider giữ trạng thái và owner/epoch; widget không tự gọi API. PII admin chỉ ở RAM, không ghi log/analytics hoặc public cache. Payload chỉ có ID/status/counts cần thiết khi ghi diagnostic.

## 8. Các vùng file và cách tách công việc sau duyệt spec

Đây là bản đồ trách nhiệm để viết implementation plans, chưa phải danh sách file được phép sửa ngay:

| Vùng | Files/components dự kiến |
|---|---|
| Account backend | New CLI-generated migrations; `supabase/functions/admin-control/`; account SQL và Node contract tests; migration bổ sung guards cho account data hiện hữu |
| Discovery backend | Prepared `supabase/migrations/20261020151440_admin_discovery_drafts.sql` chỉ được thay nếu live preflight xác nhận chưa applied; publication migration/function/tests mới; giữ web editor tương thích |
| Flutter admin | `lib/features/admin/{models,services,providers,presentation/screens,presentation/widgets}/`; screen/forms theo trách nhiệm, không gom thành một file admin khổng lồ |
| Entry/lifecycle | `lib/features/profile/presentation/screens/profile_screen.dart`, `lib/main.dart`, AuthProvider và lifecycle chỉ tại hook kiểm quyền cần thiết |
| Public catalogue | V2 model/parser/repository/cache/provider dưới `features/explore`; adapters của CatalogueRepository/VisitDetailsProvider; discovery/detail/home/planner lookups |
| Regression | Existing Auth/trips/favorites/AI/catalogue tests; admin permission/provider/widget tests; native fixture/probe khi được duyệt |
| Operations | Runbook publication V2, migration-history mapping và acceptance report; không sửa permanent rules để bỏ gate |

Ba implementation plan phụ thuộc nhau sẽ được viết sau owner duyệt spec:

1. **Account control và quyền quản trị:** guards, account operations, Auth sync, audit và API dashboard. Có thể kiểm bằng synthetic SQL/API tests trước UI.
2. **Khu quản trị Flutter:** entry/guard, user list/detail/actions, dashboard và editor nháp/history. Dùng hợp đồng của phần 1 và draft API; không gọi UI-only là backend live.
3. **Publication V2 và consumer:** validator/bundle/activation, Flutter preview/publish, public cache/repository và tích hợp Home/Khám phá/manual planner; rồi nghiệm thu xuyên suốt.

Các phần dùng chung contract nhưng review được độc lập; không lập ba lịch triển khai đồng thời khi chưa ổn định interfaces. Phân công đã chốt: Codex lập kế hoạch/review, Antigravity code; không tự spawn subagents hoặc tự chuyển người sửa code vì owner yêu cầu Superpowers.

Scope toàn feature chắc chắn vượt 5 files. Trước implementation cần owner duyệt exception tổng số file và tổng tool budget dựa trên file map cụ thể trong kế hoạch; không tự chia gói để reset guard. Mỗi gói có allowlist, used/max tool calls và repair rounds; không mượn hoặc reset G2/G3/G4 của công việc cũ. Lượt này chỉ thêm tài liệu spec, nằm trong giới hạn hiện tại.

## 9. Nghiệm thu bắt buộc

| ID | Tình huống | Kết quả cần chứng minh |
|---|---|---|
| ADM01 | Guest/customer/demo mở route hoặc gọi thẳng API | Không đọc/sửa admin data, không lộ user list |
| ADM02 | Admin role bị thu hồi trong lúc screen/request pending | Mutation bị deny tại server, RAM admin/late response không xuất hiện lại |
| USR01 | Pagination/search/filter và user chưa đăng nhập lần nào | Không trùng/bỏ cursor; nullable lastSignIn hiển thị đúng; không load hết Auth users ở client |
| USR02 | Khóa user còn JWT trên V1/V2/direct tables/AI | Các đường account bị deny; auth sync failure không cho user hoạt động tiếp |
| USR03 | Mở khóa, retry, response mất, request cùng ID khác payload | Fresh login mới dùng account; retry không lặp mutation; payload mismatch bị chặn |
| USR04 | Hai admin đồng thời khóa/hạ quyền nhau hoặc admin cuối | Transaction serialization giữ ít nhất một active-admin; self-change bị chặn |
| USR05 | Lock/unlock API thất bại hoặc process dừng giữa chừng | Operation còn truy vấn/retry được; trạng thái deny/acknowledgement trung thực |
| USR06 | Logout A → B; response user list của A đến muộn | Không hiện dữ liệu admin A ở customer B; không chạm Guest draft |
| DASH01 | Khoảng ngày qua nửa đêm UTC/Vietnam, user banned/anonymous/deleted | Số liệu đúng định nghĩa, asOf và 7/30 ngày; thiếu dữ liệu không thành 0 |
| CAT01 | Thêm destination/place vượt 12/72, slug trùng, parent sai, tọa độ thiếu một nửa | Hợp lệ lưu được; lỗi chặn ở server và UI giữ input |
| CAT02 | Ẩn parent có con, hiện lại, chuyển parent và restore snapshot cũ | Không orphan/hard delete; ID giữ; restore không làm mất ID thêm sau |
| CAT03 | Hai admin sửa cùng revision, mất response save | Conflict rõ ràng; retry cùng operation không tăng thêm revision |
| PUB01 | Chỉ lưu nháp rồi mở app Guest | App vẫn thấy release cũ; không rò draft, audit/email vào public |
| PUB02 | Preview R → draft đổi hoặc actor demoted → activate | Không xuất bản nội dung khác preview; active release cũ giữ |
| PUB03 | Upload/readback/CAS thất bại, response mất sau activation | Không trỏ vào gói hỏng, không ghi đè immutable object; retry xác định đúng kết quả |
| PUB04 | Hai publication cùng expected active; restore bản cũ | Một CAS thành công; sửa sai bằng version cao hơn, không downgrade |
| PUB05 | Operational unknown, reviewed sai nguồn/ngày, ảnh chưa có quyền | Unknown hiển thị đúng; dữ kiện khẳng định thiếu bằng chứng không publish |
| APP01 | Cùng APK nhận bundle mới, thêm/sửa/ẩn rồi refresh | Home/Khám phá/picker dùng cùng version, không hồi sinh hidden từ fallback |
| APP02 | Hash sai, version cũ, schema mới, timeout, lỗi cache write | Giữ snapshot hợp lệ, không trộn metadata/visit, có cảnh báo |
| APP03 | All-hidden, place list rỗng, IDs UUID không prefix | Empty state đúng; parser V2 không ép seed shape, parser V1 không bị nới |
| APP04 | Restart offline sau cache; trip cũ tham chiếu hidden place | Cache sống qua restart; trip/actual expenses không bị sửa/xóa |
| APP05 | Destination mới manual → Guest/account save/reopen | Luồng hoạt động; AI/engine chưa hỗ trợ được giải thích và không gọi quota |
| UI01 | Chữ lớn, màn hẹp, TalkBack, keyboard/back/cancel, loading/error | Không overflow; controls có nhãn; dirty form và confirmation đúng |

Chạy targeted regression theo thay đổi; `./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot 'D:/flutter/flutter'` là gate gồm `flutter analyze`, `flutter test` và ba Node contracts hiện có. Admin Node suites mới phải có lệnh riêng hoặc được thêm rõ ràng vào helper: Full hiện không tự chạy `admin_discovery_web_test.mjs`. SQL rollback/concurrency suite phải dùng database local biệt lập hoặc staging được duyệt, không giả live bằng mock.

Native acceptance phải ghi APK/entrypoint/environment/hash, device, release version và thao tác thực đã quan sát; unit/widget PASS không thay native evidence. Sau Dart changes thử hot reload qua Dart MCP khi có active app; nếu không kết nối thì ghi NOT RUN, không cài/clear emulator có draft chưa lưu.

Thiết kế/tài liệu không cần chạy toàn Flutter suite để giả chứng minh feature chưa viết. Trong lượt này chỉ kiểm file, links nội bộ/đường dẫn và sự nhất quán của spec; mọi test sản phẩm ghi NOT RUN.

## 10. Rollout, ranh giới phê duyệt và rủi ro

- Target dự kiến chỉ staging `bkocylxbuyvdgxccpixx`. Trước mutation đọc lại migration history/ACL/functions và kiểm role/session guard; map filename local với version remote hiện có. Không replay R1 hoặc prepared A1 khi server đã applied khác nội dung.
- Migrations mới tạo bằng `supabase migration new <name>` ở implementation; không đặt trước timestamp hoặc sửa applied history. Additive rollout: guards/schema → endpoints → compatible Flutter → native acceptance → cho dùng publication.
- Mỗi live deployment/migration/bucket/policy/publish đầu tiên phải có packet exact target/hash/preconditions/readback/rollback được owner review. Duyệt spec không tự cấp quyền khóa/cấp quyền tài khoản thật để thử hoặc xuất bản dữ liệu chưa review.
- Khi chức năng đã được triển khai và nghiệm thu, admin dùng UI là người xác nhận từng thao tác; không đòi quay lại chat xin phép cho mỗi lần lưu/xuất bản thường lệ.
- Rollback bằng tắt entry/endpoint mới và giữ active manifest hợp lệ; không bulk-unlock, reset roles, xóa audit, hạ release version hoặc xóa draft dữ liệu owner.
- Không stage/commit file owner khác, không merge/push main, không thay dependencies/native settings/permanent rules trong scope thiết kế. Source feature mới phải trên branch phù hợp hoặc worktree có baseline đầy đủ khi bắt đầu execution, không tạo worktree từ HEAD cũ rồi bỏ mất dirty dependencies.
- Không cam kết ngày hoàn tất hoặc đủ điều kiện production từ số tests. Đây là nhiều phần liên quan Auth/security/public data; implementation plan phải nêu critical path, file/tool budget và gate review trước khi ước lượng effort.

Rủi ro chính đã có phương án: stale JWT → server access/session guard; Admin API không transaction với DB → trạng thái deny và operation retry; Storage không transaction với DB → readback + CAS manifest; fixed catalogue → protocol V2/adapter; nội dung chưa xác minh → unknown public projection và delta nêu rõ; old trips → immutable snapshots/soft-hide; shared dirty checkout và tests cũ → baseline evidence riêng, selective edits.

## 11. Review và bước tiếp theo

Owner đã duyệt spec này, bao gồm các quyết định: admin được quản lý tài khoản khác nhưng không tự thay quyền; unlock cần fresh login; dashboard không đo online; V2 metadata có thể publish với operational unknown; điểm mới manual được nhưng AI/engine không tự mở rộng. Không hỏi lại approval thiết kế; kế hoạch cụ thể/cách thực thi là gate kế tiếp.

Đã dùng **superpowers:writing-plans** lập ba kế hoạch: [Account control](../plans/2026-10-23-admin-account-control.md), [Flutter admin UI](../plans/2026-10-23-flutter-admin-ui.md), [Publication V2 và app khách](../plans/2026-10-23-discovery-publication-v2.md). Các file chứa contracts, constraint matrices, TDD, verification, dependency order, file/tool budgets và rollout gates. Owner đã chọn Codex review/plan và Antigravity code; xem [handoff](../plans/2026-10-23-admin-antigravity-handoff.md). Không hỏi lại người thực thi hoặc tự mở scope/budget từ lựa chọn này.

Nguồn nội bộ đã đối chiếu: `AGENTS.md`; `.agent/rules.md`; `.agent/workflow.md`; `docs/phase-3/ADMIN_DISCOVERY_IMPLEMENTATION_PLAN_20261020.md`; `docs/phase-3/DISCOVERY_PUBLISH_RUNBOOK.md`; source Auth/Profile/Discovery/Home/Trips/AI và helper verification nêu trong mục 2/8.

Tài liệu Supabase đã đọc khi thiết kế: [Admin updateUserById](https://supabase.com/docs/reference/javascript/auth-admin-updateuserbyid), [Admin listUsers](https://supabase.com/docs/reference/javascript/auth-admin-listusers), [Admin signOut](https://supabase.com/docs/reference/javascript/auth-admin-signout), [sessions](https://supabase.com/docs/guides/auth/sessions), [Storage standard uploads](https://supabase.com/docs/guides/storage/uploads/standard-uploads), [changelog](https://supabase.com/changelog). Changelog markdown bị công cụ từ chối content-type ở lượt trước; HTML fallback đã đọc, không coi fetch markdown lỗi là đã scan markdown thành công.

### Handover của lượt thiết kế (lịch sử trước approval)

- **Changed:** thêm một spec; chưa sửa code/config/schema/live data.
- **Why:** chuyển scope A thành thiết kế có server authority và public snapshot nhất quán; tránh UI có nút nhưng không có hiệu lực backend/app khách.
- **Testing:** source/status inspection và self-review tài liệu; Flutter/Node/SQL/native của feature chưa chạy vì chưa implementation.
- **Problems:** chờ owner review written spec; legacy Flutter failures, live preflight và ngân sách triển khai còn phải xử lý theo gate riêng.
- **Lesson Candidate:** đổi dữ liệu admin chỉ hoàn tất khi consumer nhận snapshot hợp lệ; khóa tài khoản chỉ hoàn tất khi các đường server cũ cũng kiểm trạng thái, không chỉ khi UI đổi badge.

Self-review: đã làm rõ publish active-only, nguồn dữ liệu unknown, retry khi actor mất quyền, stale completion của Auth API, hardcoded AI IDs và sự khác nhau giữa lịch sử tests với checks hiện tại. Các checkbox còn mở là gate review/thực thi có chủ ý, không phải yêu cầu nghiệp vụ chưa quyết định trong tài liệu.
