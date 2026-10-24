# Thiết kế sửa nghiệp vụ planner, kết quả, bản đồ và tài khoản

## Phạm vi đã được giao

Owner xác nhận “ok hãy tiến hành” sau báo cáo `docs/phase-3/CORE_PLANNER_ACCOUNT_AUDIT_20261023.md`: lập plan cho L1–L8, A1–A3, N1–N6; Antigravity code, Codex review. Tài liệu này chốt thiết kế để viết kế hoạch trong cùng lượt theo yêu cầu đó, không phải bằng chứng đã triển khai. Dùng superpowers cho task này; không tự cấp quyền cho task khác.

Baseline: `89659f5a7c48eca4053b3f1c5e519d42a7a4efa8` + dirty/untracked hiện có, branch `codex/phase-3-discovery-design`. Không xóa/stash/reset hoặc commit chung phần việc owner.

## Các lựa chọn thiết kế

1. **Chọn sửa các điểm nối hiện có**, giữ Provider/Dio/canonical V1/V2, so với viết lại planner: ít rủi ro mất draft và giữ được test/account lifecycle đã có.
2. **Chọn ma trận từ DTO thật**, thay vì scale ba package giả hoặc xây mới engine/package API. Hiện backend trong repo chỉ có health/map; không có implementation `/plan-trip` để tự giả định có thể sửa Decision Engine ở đây.
3. **Chọn map giữ cả các hoạt động chưa định vị**, thay vì đoán tọa độ từ tên. Danh mục thật cung cấp tọa độ; điểm chưa xác định được hiện rõ và có thao tác chọn liên kết địa điểm. Không đổi canonical activity V1 chỉ để thêm field vị trí.
4. **Chọn phân loại chuyến từ dữ liệu đã tải**, không thêm RPC/list schema: provider hiện đã tải snapshot legacy và head V2. Cần bổ sung summary trong RAM và cách nhóm, không phát sinh quy trình booking/hủy đơn.
5. **Chọn recovery PKCE riêng trong auth hiện có**, giữ `detectSessionInUri:false`, cùng hàng đợi credential/lifecycle. Không bật cơ chế SDK tự xử lý callback song song với handler hiện tại.

## Bất biến chung

- Backend quyết định MCDA/Pareto/scheduler. Flutter không tự gán danh hiệu tối ưu hay sinh giá/package/chính sách hủy.
- Fallback, dữ liệu thiếu, offline, cache và pending save luôn được thông báo; không đổi thành live/đã lưu khi chưa có xác nhận thật.
- Không cố định 72 địa điểm hoặc 12 điểm đến cho danh mục động. AI chỉ hoạt động với ID hợp lệ còn trong snapshot công khai và qua auth/consent/quota hiện có.
- Ngày là calendar `YYYY-MM-DD`, timezone `Asia/Ho_Chi_Minh`; không dùng giờ máy để làm lệch ngày. Ngày kết thúc bao gồm trong số ngày.
- Form gợi ý tự động hỗ trợ 1–30 ngày thống nhất picker/slider/validation. Editor thủ công vẫn giữ giới hạn hiện hữu 1–366 ngày; không làm mất chuyến cũ dài hơn 30 ngày.
- SharedPreferences trực tiếp pin `2.5.5` đúng phiên bản đã khóa; không nâng SDK/package khác. URL backend không thay Supabase project URL hay nơi gửi token tài khoản.
- Không sửa native config: dùng lại callback scheme/host đã đăng ký. Chỉ tạo source migration tương thích request; không apply/deploy/đổi SMTP/quota/allowlist live trong task code này.
- Không thêm giới hạn giả về số calls, files hay chia approval theo task. Thứ tự trong plan phục vụ phụ thuộc và kiểm thử; Antigravity hoàn thành toàn phạm vi được giao.

## S1 — Đầu vào, ngày và lưu kết quả

Ngày đi/ngày về/số ngày là một trạng thái thống nhất. Chọn khoảng ngày cập nhật số ngày; đổi số ngày khi có ngày đi cập nhật ngày về. Hai ngày thiếu một, ngày không tồn tại, end < start hoặc khoảng >30 ngày trên form tự động phải bị từ chối với lỗi cụ thể, không clamp một trường rồi giữ trường còn lại.

`TripProvider` đồng bộ ngày vào metadata khi owner đổi input. Factory lấy ngày request nếu metadata chưa có; nếu cả hai có mà mâu thuẫn thì báo lỗi, không chọn ngầm. Bản cũ inconsistent giữ nguyên payload/digest, hiện yêu cầu sửa ở bản sao trước submit/save mới.

Dashboard chụp immutable result context gồm request, metadata, response và workspace generation. Save dialog dùng đúng context đó, kiểm auth epoch/owner/context trước và sau I/O. Bản lưu mới dùng envelope `CanonicalTripPayloadV1`, giữ đủ request, metadata, plan và FALLBACK; headers dùng ngày thật và **ngân sách đầu vào**, không dùng totalAllocated hay mặc định 4 triệu.

Metadata điểm đến cho result lấy winnerId có card tương ứng; không lấy first card nếu khác winner. Nếu không đủ ID/tên xác thực thì để thiếu và hiện rõ, không tự bịa. Plan-only cũ vẫn đọc được; legacy dates ở headers được dùng cho view/copy như dữ liệu tham khảo, không ghi lại receipt immutable.

SQL `private.validate_guest_payload_v1` hiện chỉ chấp nhận request sáu trường. Thêm migration sau các migration hiện có để chấp nhận các trường optional đã có ở Dart: destinationId, destinationName, startDate, endDate, companionType; giữ chặn unknown key, duplicate key, size, Unicode, money, owner/digest/idempotency và toàn bộ hoạt động B3. Không sửa migration lịch sử hoặc rehash dữ liệu đã lưu.

## S2 — Ma trận và biểu đồ

Ma trận hiển thị hai phần: điểm đến được backend trả về theo đúng thứ tự/score, và phương tiện của chuyến thắng với cost/duration/comfort/Pareto/tradeoff/reason. Không ghép thành ba package hoàn chỉnh. Ngân sách so sánh là `request.budgetVnd`, ghi rõ giá dành cho nhóm khi contract là `priceTotalVnd`. Không suy chi phí khách sạn/chính sách hủy từ transport.

Nếu chỉ có một phương án thì hiện một; nếu không có thì empty state. Không có ngân sách đầu vào ở bản cũ thì hiện “Chưa có ngân sách đầu vào”, không mặc định.

Pareto giữ cờ server, chỉ lọc tọa độ vẽ không hữu hạn/âm và báo số phương án không vẽ được. Trục X/Y từ giá trị hợp lệ, min 0; max = max(1, maximum*1.1), nếu tất cả bằng 0 vẫn có khoảng trục dương. Mọi điểm hợp lệ phải nằm trong trục; giữ danh sách số liệu gốc.

Pie chỉ dùng các hạng chi không âm và dự phòng dương. Nếu dự phòng âm, biểu đồ tỷ trọng theo tổng chi hợp lệ, khoản vượt hiển thị riêng màu lỗi; giữ nguyên tổng chi gốc và hạn mức. Bất kỳ hạng chi âm thì hiện lỗi dữ liệu cho chart, không abs()/clamp để làm đẹp; trường hợp tất cả zero hiện empty state. Không tính phần trăm với mẫu số <=0.

Timeline dashboard nhận startDate tùy chọn và ordinal: ngày n = startDate + n-1 theo UTC calendar; không có ngày thì “Ngày n · Chưa chọn ngày”. Không tự dùng DateTime.now.

## S3 — Danh mục, bản đồ và tuyến

Mọi đường tạo, mở draft, mở saved và copy vào manual editor lấy `PublicCatalogueProvider.snapshot` hiện hành/cache hợp lệ. Nếu chưa có snapshot thì load provider một lần; không tải asset trực tiếp ở từng entry point. Thay snapshot không được ghi đè draft đang sửa hoặc chọn lại ID đầu tiên; địa điểm bị ẩn giữ tên trong draft kèm cảnh báo và không dùng để tạo liên kết mới.

Bản đồ ngày dùng cùng snapshot mà editor đang hiển thị; tọa độ chỉ đến từ record có ID tương ứng, hữu hạn và trong biên độ. Có cache công khai thì offline vẫn xem danh sách/marker; không có tọa độ không có marker giả.

Dashboard chuyển `ItineraryMapContext` chứa **mọi** hoạt động theo ngày/thứ tự, kể cả chưa có tọa độ, cùng metadata điểm đến và snapshot. Adapter chỉ tự ghép khi tên hoạt động trim/casefold trùng **duy nhất** tên địa điểm trong đúng destinationId; không bỏ tiền tố, bỏ dấu, fuzzy hay dùng trung tâm thành phố. Ghi nhãn “Ghép theo tên danh mục”; tọa độ là vị trí tham khảo, chưa xác minh lối vào.

Hoạt động chưa ghép có hàng “Chưa xác định vị trí” và “Chọn địa điểm” từ danh mục hiện hành; lựa chọn người dùng chỉ thuộc phiên xem bản đồ này và ghi rõ chưa lưu vào lịch. Muốn lưu liên kết bền vững dùng editor V2 hiện có (`TripItem.placeId`); không sửa receipt V1. Không gọi geocoder ngoài hoặc dùng LLM để phát minh tọa độ.

Chọn ngày chỉ vẽ các điểm của ngày đó, giữ số thứ tự ban đầu và báo K/N điểm đã định vị. Tuyến tham quan là chuỗi >=2 điểm có vị trí theo thứ tự; không thêm điểm đến trung tâm sau điểm cuối. Có điểm ở giữa chưa biết vị trí thì tuyến ghi rõ “Tuyến qua các điểm có vị trí, chưa đầy đủ”. Không vẽ đường nếu <2 điểm; marker/danh sách vẫn xem được. Tuyến từ GPS hiện tại tới điểm đến là thao tác riêng, không tự coi GPS là nơi xuất phát đã chọn trên form.

Mỗi lần mở/init map phải xóa route/destination/selection cũ, tăng generation; response cũ đến sau bị bỏ. Khi route mới lỗi thì không giữ polyline cũ với tên mới. Map dispose làm mất hiệu lực request của màn đó; không đổi cơ chế Radar ngoài điều cần để không giữ ngữ cảnh chuyến trước.

## S4 — Chuyến đi và trợ giúp AI

Bỏ `_buildUpcomingDemoCard`, không tự có chuyến/đơn xác nhận khi danh sách rỗng. Loading/error/offline/empty là trạng thái riêng; danh sách Guest vẫn là draft thật trên máy.

Enrich `OwnedTripSummary` trong RAM từ snapshot/head đã tải: startDate/endDate/rawStatus/statusKnown. Không thêm fields vào RPC v2 đang có strict decoder. V2 có ngày trong document và không có nghiệp vụ hủy; legacy online có status từ headers. Cache legacy không có trạng thái đáng tin thì hiện “Chưa đủ thông tin”, không mặc định planning để giấu một lần hủy.

Nhóm: `Đã qua ngày` khi có range hợp lệ, trạng thái đã biết và endDate < hôm nay VN; `Sắp/đang đi` khi tương tự và endDate >= hôm nay; còn lại `Chưa đủ thông tin`. Legacy chỉ nhận status planning/booked/completed theo CHECK hiện có; completed với ngày kết thúc trong tương lai là mâu thuẫn và thuộc nhóm chưa đủ thông tin. V2 không có nghiệp vụ hủy nên phân loại từ document. “Đã qua ngày” không khẳng định người dùng đã thực hiện chuyến. Bỏ tab `Đã hủy` vì schema hiện không chấp nhận cancelled; không thêm thao tác hủy đơn/hoàn tất giao dịch để làm tab có dữ liệu. Counts phản ánh những chuyến đã tải, ghi “đã tải” khi còn cursor; Xem thêm hoạt động ở mọi tab kể cả tab đang rỗng. Giữ thứ tự/cursor/owner fencing.

Trợ giúp AI ở chi tiết điểm đến đi qua cùng hành động thay workspace có xác nhận đang có, tới form/editor với destinationId đã chọn và mở composer trợ lý. Không gọi AI ngay lúc navigation. Guest được giải thích cần đăng nhập; đăng nhập không được làm mất nháp. Consent và Apply vào draft tách khỏi Save.

AI dynamic: UI/service/gateway dùng ID regex chung và destination đang có trong snapshot; truyền thêm destinationName công khai từ snapshot, tối đa 200 ký tự, qua sanitizer gateway, để ID opaque vẫn có ngữ cảnh tên thật. Không lấy tên tự do từ profile/notes để gửi. Xóa whitelist 12 ở kiểm tra khả dụng, giữ legacy mapping ở copy adapter nếu cần. Server guard/auth/quota/known-fact validators không được nới.

## S5 — API URL, OTP và recovery

API config: luôn truy cập trong Cá nhân trên debug/profile/release, kể cả Guest. Lưu `backend_api_base_url.v1` bằng SharedPreferences, normalize trailing slash và suffix `/api/v1`; chấp nhận root hoặc URL đã có đúng suffix, từ chối path tùy ý, query/fragment/userInfo, scheme ngoài http(s), host rỗng. HTTP LAN/localhost được dùng cho demo. Chỉ báo lưu thành công sau write true; write false giữ config cũ. Startup await load trước runApp/khởi tạo Dio; đọc lỗi dùng mặc định kèm cảnh báo có thể thử lại. Reset xóa key và có kiểm kết quả.

TripApiService và MapApiService lấy effective URL cho từng operation; mỗi operation giữ một URL nhất quán qua retries. Đổi URL trong lúc I/O làm kết quả cũ không được áp vào UI hiện tại. Không gắn token Supabase vào các URL người dùng nhập.

OTP: client/email/session thiếu thì báo lỗi; token phải đúng 6 chữ số trước gọi SDK. Chỉ nhận thành công khi SDK trả session + user hợp lệ, identity khớp SDK session và qua lifecycle nếu đang dùng lifecycle. Không còn đường production tạo user để phục vụ test.

Recovery dùng `io.supabase.travelgo://login-callback?flow=recovery` (host đã có trong Manifest), PKCE đã bật, auto URI detection vẫn false. User nhập email thật, SDK `resetPasswordForEmail`; UI thông báo chung “Nếu email phù hợp, bạn sẽ nhận được hướng dẫn”, không khẳng định đã giao mail tới hộp thư.

Lưu pending recovery marker theo project, TTL cục bộ 60 phút, gồm generation/requestedAt/phase; không lưu email, token, code hay mật khẩu trong marker. PKCE verifier do SDK quản lý. Marker được đọc trước auth initialization để SDK recovery session sau process death không thành account bình thường.

Callback cần marker hợp lệ + URI đúng scheme/host/path, query flow=recovery và duy nhất code, không token/fragment/duplicate query. Exchange chỉ trong credential queue; `AuthSessionUrlResponse.redirectType` phải là `passwordRecovery`, session/user khớp. Marker chuyển phase ready chỉ sau exchange; đọc marker không cấp quyền đặt mật khẩu nếu SDK/session không còn. Invalid/expired/replayed link không mở quyền account và phải xin link mới; link tạo từ máy khác không có PKCE verifier được báo rõ, không bypass.

Trong recovery mode, account consumers bị invalidate/ẩn; recovery session chỉ để update password, không establish account handle/fetch trips/role. SDK observer không được revoke một exchange recovery do chính app đang xử lý hoặc publish nó thành login. Password mới: tối thiểu max(8, quy định đang có trên form đăng ký), trùng confirmation, server policy vẫn quyết định; không log raw value. Success updateUser rồi signOut local, clear marker, về login; người dùng đăng nhập lại bình thường. Nếu update thành công nhưng cleanup lỗi, báo “Đã đổi mật khẩu, cần hoàn tất đăng xuất”, khóa retry update và cho retry cleanup. Cancel/logout/đổi auth flow hủy intent/generation; callback cũ không sống lại. Không hứa revoke tất cả thiết bị khác.

## Nghiệm thu và giới hạn

- Hồi quy 8 probe lỗi gốc phải thành test permanent GREEN; ca đối chứng gửi ngày backend vẫn GREEN.
- Một flow tạo mới → kết quả → cloud save → load → copy/editor → map dùng cùng ngày/ngân sách/số người và danh mục mới; Guest → account import cùng payload cũng được kiểm local SQL.
- Kiểm nghiệm synthetic không thay email thật/AI thật/APK profile. Các bước live cần đúng staging, tài khoản QA và quyền môi trường được owner cấp; thiếu điều kiện ghi NOT RUN/BLOCKED và tiếp tục phần local độc lập.
- Không gọi toàn bộ việc xong nếu chỉ source pass mà email/AI endpoint chưa rollout tương ứng. Tách source-ready, deployment-ready, native acceptance.

## Tài liệu đối chiếu

- Báo cáo lỗi: `docs/phase-3/CORE_PLANNER_ACCOUNT_AUDIT_20261023.md`.
- SDK đã đọc từ package_config: supabase_flutter 2.17.2, gotrue 2.27.2, shared_preferences 2.5.5; giữ lockfile hiện có.
- [Supabase resetPasswordForEmail](https://supabase.com/docs/reference/dart/auth-resetpasswordforemail), [Mobile deep links](https://supabase.com/docs/guides/auth/native-mobile-deep-linking). SDK local xác nhận exchangeCodeForSession trả redirectType và event passwordRecovery từ verifier.
