# Kế hoạch triển khai TravelGO theo phạm vi đồ án

> **R2 thay thế cách thực hiện:** Owner yêu cầu dùng Superpowers để làm chặt kế hoạch ngày 24/10/2026. Đọc [master R2](../superpowers/plans/2026-10-24-coursework-r2.md) và ba plan con; bản dưới đây giữ làm roadmap tham khảo, không chạy song song như kế hoạch thứ hai. R2 vẫn CHỜ DUYỆT, chưa sửa app. Câu “Không dùng Superpowers” phía dưới mô tả lượt lập bản đầu, không mô tả lượt R2.

Ngày: 24/10/2026. Trạng thái: **CHỜ OWNER DUYỆT — CHƯA TRIỂN KHAI**.

## 1. Căn cứ, quyền hạn và mục tiêu

- Phạm vi: [.agent/product-scope.md](../../.agent/product-scope.md).
- Thiết kế AI: [.agent/ai-planner-design.md](../../.agent/ai-planner-design.md).
- Gap audit: [SCOPE_READONLY_AUDIT_20261024.md](SCOPE_READONLY_AUDIT_20261024.md).
- Baseline được xác minh: branch `fix/ai-planning-stability`, HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59`; working tree có tài liệu đã sửa và file owner chưa track. Không reset/stash/xóa chúng. Kiểm actual HEAD/diff trước mỗi gói; nếu thay đổi liên quan, đối chiếu lại thay vì dùng audit cũ như sự thật hiện tại.
- Lượt này chỉ tạo kế hoạch. Không sửa app, backend, tests, SQL, dependencies, native config, không build/install, gọi AI/email thật, deploy, DB mutation, stage/commit/push/merge. Không dùng Superpowers, không tạo subagent.
- Mục tiêu: ứng dụng di động có tài khoản/OTP/recovery, khám phá, tự lập lịch, ngân sách, chuyến đi theo tài khoản, admin tối thiểu và trợ lý AI có dẫn chứng. AI gồm tạo/tư vấn/đề xuất sửa; catalogue trước, tìm web có lựa chọn khi thiếu sau.
- Không đưa bản đồ, dashboard Decision Intelligence, yêu thích, guest-import, widget thời tiết, chatbot tổng quát hoặc framework RAG mới vào lại scope.

Danh sách file dưới đây là phạm vi dự kiến từ source, không phải lệnh xóa toàn bộ thư mục. Chỉ thêm file hỗ trợ khi cần cho gói; không mở rộng feature. Duyệt kế hoạch không thay quyền triển khai live, sửa billing/quota/model, schema hoặc native/dependency ngoài phần được chỉ rõ; chuẩn bị diff và kiểm local trước bước phê duyệt triển khai cuối. Nếu owner duyệt nhiều gói cùng lúc, không hỏi lại cùng một quyết định đã được duyệt.

## 2. Thứ tự và cách chia gói

Mỗi hàng là một đầu ra có thể review; làm và xác minh xong mới chuyển gói phụ thuộc. Không tạo thêm roadmap nhiều tầng. Không đặt hạn mức file/tool calls; giữ tối đa ba vòng sửa lỗi theo quy tắc hiện hành, báo checkpoint khi chạm guard.

| Thứ tự | Gói | Kết quả người dùng thấy |
| --- | --- | --- |
| G1a | Thu gọn điều hướng | App chỉ giới thiệu chức năng trong scope; lập chuyến đi dẫn vào editor, không qua Decision Engine |
| G1b | Dọn module riêng | Gỡ code/dependency/quyền chỉ dành cho tính năng đã bỏ; dữ liệu cũ vẫn đọc được |
| G2 | Tài khoản và recovery | Đăng ký/OTP/login/logout/quên mật khẩu hoạt động thật và không lẫn phiên |
| G3 | Lịch thủ công, ngân sách, lưu chuyến | Tạo/sửa/lưu/mở lại/xóa hoàn chỉnh, không cần AI hoặc bản đồ |
| G4 | Admin và catalogue | Admin quản lý user/địa điểm; User tải lại thấy dữ liệu được xuất bản |
| G5 | Nguồn và bằng chứng dùng chung | Dữ kiện có nguồn/ngày/trạng thái, lưu và mở lại vẫn xem căn cứ |
| G6 | AI tạo lịch từ catalogue | Bản trống → đề xuất có căn cứ → preview/hủy/áp dụng → lưu |
| G7 | AI tư vấn/sửa từ catalogue | Hiểu đúng lịch/ngân sách; tư vấn không mutation; sửa có xác nhận |
| G8 | Tìm web để tư vấn | Người dùng chọn tìm web, xem câu trả lời có dẫn nguồn và nhãn rõ |
| G9 | Đưa hoạt động web vào lịch | Preview → xác nhận → lưu/mở lại có nguồn, không tự nhập catalogue Admin |
| G10 | Nghiệm thu đồ án | Có một kịch bản end-to-end đã chạy trên APK/backend/thiết bị xác định |

Đường chính: G1a → G1b → G2 → G3 → G4 → G5 → G6 → G7 → G8 → G9 → G10. G8 có bước kiểm tương thích trước implement tìm web; nếu bị chặn, dừng nhánh web và báo owner, vẫn có thể nghiệm thu phần catalogue độc lập. Không tự bỏ G8/G9 khỏi scope đã chốt hoặc báo toàn đồ án hoàn thành khi nhánh web còn NOT RUN/BLOCKED.

## 3. Chi tiết từng gói

### G1a — Thu gọn UI và điểm vào

**Sửa/gỡ:**
- `lib/features/navigation/presentation/screens/main_navigation_shell.dart`: bỏ tab Yêu thích, đồng bộ index và các nơi điều hướng tới tab; đề xuất bốn tab Trang chủ/Khám phá/Chuyến đi/Cá nhân.
- `lib/features/home/presentation/screens/main_home_screen.dart`, `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`, `manual_planner_entry_screen.dart`, `manual_planner_screen.dart`: Lập chuyến đi đi trực tiếp vào form/editor thủ công; giữ nút AI ở editor. Tái dùng trường ngày, số người, ngân sách; bỏ entry dashboard/Pareto/so sánh phương tiện và nút bản đồ.
- `lib/features/profile/presentation/screens/profile_screen.dart`, các màn onboarding/detail/trips có liên quan: bỏ entry tiện ích ngoài scope, guest save/import và cấu hình Decision Engine khi không còn dùng. Giữ auth/recovery, hồ sơ cơ bản và admin gate.
- Không xóa local account lifecycle hoặc cache phục vụ dữ liệu giữ lại. Chưa xóa model snapshot cũ trong gói này.

**Kiểm thử/đạt:** tab đúng, link từ Home/Explore/My trips không mở sai tab; tạo lịch mở đúng điểm đến; không còn CTA map/favorites/guest-import/dashboard. Widget tests cho luồng điều hướng mới và tests hiện có liên quan, không viết test cho từng label. Không có request `/plan-trip` hoặc request map khi chạy luồng tạo chuyến mới. Chỉ dừng phục vụ feature cũ, không mất nội dung đang sửa.

### G1b — Dọn code, dependency và bảo toàn dữ liệu cũ

**Phụ thuộc:** G1a. Lập bảng imports/callers trước mỗi delete.

**Sửa/gỡ:**
- `lib/main.dart`: dọn Provider/wiring chỉ dành map, favorites, guest-import, old decision planner.
- `lib/features/map/`, `lib/features/favorites/` và widgets/services Decision Engine chỉ dùng riêng: gỡ sau khi không còn caller. Chuyển catalogue/reference dùng chung sang explore trước nếu có phụ thuộc; không xóa địa điểm vì đang nằm trong thư mục map.
- `lib/features/trips/`: tách service/codec legacy cần đọc chuyến đã lưu khỏi feature tạo snapshot/import đã bỏ. Giữ adapter read-only khi cần; UI giải thích dữ liệu cũ, không biến mất bản ghi không đọc được. Không tự chuyển đổi rồi ghi đè dữ liệu server.
- `pubspec.yaml`/lockfile, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`: chỉ bỏ flutter_map/latlong2/geolocator và quyền location nếu toàn bộ callers đã hết và gói sửa các file này được duyệt. Giữ INTERNET và auth deep links/app_links. Không nâng phiên bản package không liên quan.
- Dọn tests chỉ đòi feature đã bỏ; sửa fixtures/imports của tests core. Không xóa SQL/migration/bảng/server data chỉ vì app không dùng nữa.

**Kiểm thử/đạt:** analyzer không unresolved imports; account trip manual vẫn đọc; fixture snapshot legacy mở được hoặc có trạng thái giới hạn rõ, không crash/mất dữ liệu; guest data cũ không bị tự xóa. Full suite còn phù hợp PASS. Build Android khi thực thi gói config được duyệt; iOS build nếu thiếu máy phải NOT RUN, không tự tuyên bố iOS đạt. Chỉ gỡ quyền vị trí, không làm hỏng link recovery.

### G2 — Tài khoản, OTP và quên mật khẩu

**Phụ thuộc:** G1. Tái hiện findings cũ trên actual source trước khi sửa; sửa đúng finding còn tồn tại, không viết lại auth.

**Files:** `lib/features/auth/providers/auth_provider.dart`, `password_recovery_provider.dart`; `services/password_recovery_service.dart`, `recovery_intent_store.dart`, `account_access_service.dart`; `models/password_recovery_state.dart`; màn register/OTP/login/forgot/reset, `widgets/password_recovery_gate.dart`; `lib/features/trips/services/local_account_lifecycle_service.dart` chỉ khi trace chứng minh liên quan. Hồ sơ cơ bản trong profile giữ/tinh gọn.

**Hành vi:** signUp→OTP email→verify→login; logout; recovery email link→đặt mật khẩu→cleanup→login bằng mật khẩu mới. Không OTP giả, session giả hoặc bypass để demo. Giữ một luồng recovery hiện có, không thêm OTP reset riêng. Với sáu findings R1: ownership sau await, cancel/SDK queue, submit đôi, cleanup fail, TTL và cold server revalidation đều phải có kết quả mới và trạng thái đóng/mở cụ thể.

**Kiểm thử/đạt:** `password_recovery_*_test.dart`, `auth_role_security_test.dart`, `auth_navigation_test.dart` và account lifecycle tests liên quan; thử callback cũ sau cancel, cancel→loginB, double submit, cleanup lỗi, expired/revoked, callback cold/warm. Không publish phiên cũ hay đổi mật khẩu hai lần; giữ retry rõ và đúng tài khoản. Đăng ký/OTP/recovery email thật là acceptance riêng trên tài khoản thử được cho phép, gồm OTP sai/hết hạn và không log token/mật khẩu. Cấu hình SMTP/redirect live chưa có thì báo BLOCKED, chuẩn bị yêu cầu cụ thể sau khi local diff review được.

### G3 — Lịch thủ công, ngân sách và chuyến đi theo tài khoản

**Phụ thuộc:** G2. Giữ bộ tính tiền/mutator/repository, chỉ sửa gap tái hiện.

**Files:** manual planner screen/entry, `manual_activity_form.dart`, `manual_expense_form.dart`, `manual_budget_panel.dart`, `manual_save_preview.dart`; `manual_planner_provider.dart`; `trip_date_policy.dart`, `editable_trip_validator.dart`, `editable_trip_mutator.dart`, `budget_calculator.dart`; `lib/features/trips/{providers,services,models,presentation}` cần cho save/list/read/update/delete.

**Hành vi:** ngày/số ngày/số người thống nhất; tự nhập địa điểm khi chưa có catalogue; dự kiến và đã chi tách rõ, quy tắc tiền theo người/lượt/toàn chuyến không cộng trùng; thay đổi ngân sách không tự sửa khoản đã chi. Giữ người dùng tự lập lịch khi AI/backend AI không khả dụng. Nơi chưa có catalogue dùng tên + provenance user-provided, không giả ID Admin; implement hợp đồng này cùng codec/validator.

**Kiểm thử/đạt:** tạo→thêm/sửa/xóa hoạt động→chi phí→preview save→list→read→update→read→delete bản thử. Ngày biên, 0/thiếu tiền, vượt budget, xóa hoạt động có khoản chi liên kết, timeout save chưa rõ kết quả, retry không duplicate, phản hồi A tới sau loginB. Dữ liệu đã chi và ghi chú giữ đúng; account khác không đọc/sửa trip. Dùng `manual_planner_end_to_end_test.dart`, `manual_budget_ui_test.dart`, `budget_calculator_test.dart`, `editable_trip_*_test.dart`, `editable_saved_trip_ui_test.dart`, `my_trips_truthful_state_test.dart`. Manual ở điểm đến chưa có vẫn lưu/mở lại được.

### G4 — Admin và dữ liệu đến User

**Phụ thuộc:** G3. Bản hiện tại đã có save→preview→publish; kiểm trước khi sửa, không lặp finding D4 cũ như chưa triển khai.

**Files:** `lib/features/admin/` providers/services/models/screens/forms; public catalogue repository/provider/parser, `catalogue_sync_coordinator.dart`, discovery/detail/home; `supabase/functions/admin-control/` và `admin-publication/` chỉ khi xác minh gap; SQL/contract tests liên quan nếu đổi backend.

**Hành vi:** tìm/xem user, khóa/mở khóa; CRUD điểm đến/địa điểm (ẩn thay xóa phá trip). Giữ server admin guards và cơ chế roles đang cần, không thêm quản trị doanh nghiệp. Catalogue từ Admin được User refresh nhận đúng snapshot; chưa publish không báo khách đã thấy. Source form hỗ trợ trường nguồn hiện có hoặc gói G5 bổ sung nếu chưa có. Không hardcode số 12/72 làm trần.

**Kiểm thử/đạt:** customer bị từ chối cả API, không chỉ ẩn nút; admin khóa/mở test account đúng authority; tạo một điểm đến/place thử mới→publish→User refresh/search/detail thấy→ẩn→refresh không còn đề xuất mới, trip cũ vẫn đọc. Save ack nhưng publish lỗi hiển thị trạng thái đúng, retry không create trùng. Account/Draft/Publication contract suites và integration fixture động, không chỉ seed. Kiểm account isolation/RLS khi có thay schema. Thay đổi DB live cần phê duyệt riêng và chuẩn bị diff/migration trước.

### G5 — Dữ kiện, nguồn và lưu bằng chứng dùng chung

**Phụ thuộc:** G4. Đây là nền cho mọi AI có dẫn chứng, không phải framework retrieval mới.

**Files:** `lib/features/explore/models/place_visit_details.dart`, repositories/cache/parser; `lib/features/trip_planner/models/ai_context_grounding.dart`, `editable_trip_document.dart`; `lib/features/trips/models/editable_trip_codec.dart` và local/remote repository/schema liên quan; catalogue source forms/publication projection; widget Xem căn cứ mới dùng chung nếu chưa có.

**Hợp đồng đề xuất:** evidence record có ID, origin catalogue/web/user, URL/tiêu đề/publisher khi có, dữ kiện hỗ trợ, retrievedAt, checkedAt/publishedAt khi biết, effectiveFrom/To và review status. Claim trả evidenceIds và loại fact/inference; không coi mọi URL là evidence. Tận dụng `FieldProvenance.sourceRefs` nhưng sourceRefs hiện chỉ là chuỗi, cần record có thể resolve sau mở lại. Không tự sinh checkedAt hoặc coi fetchedAt là reviewed.

**Tương thích:** codec v2 strict keys nên phải chốt version bump/backward reader trước khi thêm evidence fields; output contract và local/server validator thay đồng bộ, old documents có thiếu evidence phải vẫn đọc thành unknown. Chuẩn bị migration mới có backward compatibility nếu thực sự cần; không rewrite migration lịch sử. Không tự migrate cloud data. Nếu evidence phải đọc từ server, kiểm quyền cả source record không chỉ trip. Kiểm giới hạn kích thước để snapshot không phình không kiểm soát.

**Kiểm thử/đạt:** roundtrip bằng chứng và legacy v2; source sai ID/URL scheme, trích dẫn không hỗ trợ claim, cũ/khác ngày, thiếu nguồn và nguồn mâu thuẫn; lưu/mở lại offline khi có cached trip vẫn xem source snapshot hoặc báo chưa tải, không nhầm đã xác minh. Không auto fetch URL bất kỳ từ user/backend; link chỉ mở theo thao tác, chuẩn hóa https và xử lý mở thất bại; không thêm plugin không cần thiết. Hoàn thiện nguồn tốt cho 2–3 điểm đến pilot dựa trên coverage hiện có, không yêu cầu đủ toàn quốc/72 places để đạt.

### G6 — AI tạo lịch catalogue có dẫn chứng

**Phụ thuộc:** G5.

**Files:** `ai_generation_service.dart`, `ai_generation_preview.dart`, manual planner screen; `supabase/functions/itinerary-proposal/gateway.mjs`, index nếu cần config; reuse facts/evidence builder từ G5; `test/ai_generation_test.dart`, `test/itinerary_gateway_test.mjs` và codec tests.

**Sửa:** generation nhận ngày cụ thể/số người/sở thích/budget và catalogue facts hợp lệ; server lấy/kiểm snapshot nguồn tin cậy, không tin client gắn cờ reviewed. Output có reference địa điểm/evidence IDs; model không tạo URL. Chỉ tạo toàn lịch khi bản trống; trên bản có hoạt động dẫn sang trợ giúp sửa. Giữ schema validation/quota/stamp, không bỏ allowlist chỉ để kết quả qua.

**Kiểm thử/đạt:** đổi ngày/số người/sở thích làm context đúng; đúng destination và place allowlist; giờ/giá/đơn vị/hiệu lực đúng; thiếu giá không thành free; ngoài giờ đã biết bị chặn; hết nguồn báo giới hạn/offer web chứ không tự gọi web. Hủy không đổi digest; apply tạo đúng một lần; edit/đổi account lúc pending không áp dụng cũ; save/read giữ căn cứ. Mọi claim quan trọng resolve được nguồn hoặc gắn rõ chưa đủ căn cứ/suy luận. Gemini thật là test riêng sau local PASS và có quyền gọi.

### G7 — AI tư vấn và đề xuất sửa hoạt động catalogue

**Phụ thuộc:** G6, dùng chung evidence G5.

**Files:** `ai_assistant_service.dart`, `ai_assistant_preview.dart`, gateway assistant sanitizer/schema/provider prompt, manual editor/mutator/validator; `test/ai_assistant_test.dart`, `ai_assistant_grounding_test.dart`, gateway contracts.

**Sửa:** bổ sung tổng dự toán/đã chi, hai số dư được gắn nhãn khác nhau; context có scope day/trip rõ. Nếu hỏi cả chuyến thì cung cấp lịch cần thiết có giới hạn; không có thì nói chỉ biết ngày được chọn. Không gửi ledger cá nhân/raw notes không cần thiết. Facts giá/giờ/evidence thực sự đi vào request, không chỉ giữ local. Tư vấn trả claim+căn cứ, không mutation; modify trả operation có target ID và evidence, UI trước/sau.

**Kiểm thử/đạt:** yêu cầu mơ hồ như lịch nhẹ thì hỏi rõ hoặc nêu giả định, không tự suy đi cùng mẹ=người già; sáng ngày bận là ràng buộc người dùng có thể kiểm. Dời A qua B sắp xếp đúng; trùng giờ bị chặn; không mất ghi chú/khoản đã chi; đổi hoạt động ảnh hưởng dự toán có cảnh báo/ack phù hợp. Tư vấn không đổi document. Hủy/late response/đổi account giữ nguyên dữ liệu. Commit repair cũ phải được giữ assertions đúng, không làm lại sửa đã đóng nếu regression không tái hiện.

### G8 — Kiểm tương thích và tư vấn web có dẫn nguồn

**Phụ thuộc:** G7. Tách G8a kiểm tương thích khỏi G8b tích hợp để không xây dựa trên giả định.

**G8a:** kiểm tài liệu chính thức ở thời điểm thực hiện và exact `gemini-3.5-flash-lite` + REST generateContent + JSON mode đang dùng. Local fixture trước; probe thật có quyền và số lượt cụ thể, không thay model/key/quota/billing hoặc dùng identity khác để né giới hạn. Ghi metadata nhận được, source/claim mapping, giới hạn search không dispatch và chi phí/quota được xác nhận; không dump secret/prompt riêng. Kiểm điều kiện UI/attribution/Search entry point theo API dùng. Nếu JSON+tools không tương thích, so sánh một request với hai bước evidence→JSON về latency, quota, output validation; chuẩn bị đề xuất cụ thể cho owner, không tự nhân đôi số call hoặc đổi model/API.

**G8b files:** gateway/index, AI context/service/preview, evidence registry/UI và tests mới cho search. Bổ sung ý định web-advice hoặc contract version rõ, không nới contract strict một cách ngầm. Không cần thêm dependency nếu REST/Dio hiện có đủ.

**Hành vi:** catalogue thiếu → thông báo → người dùng chọn Tìm thông tin trên Internet → gửi dữ liệu tối thiểu → trả lời có nguồn, nhãn chưa Admin kiểm duyệt. Grounding chunks/supports là đầu vào evidence registry, URL không lấy từ model tự viết. Chỉ tư vấn, chưa ghi activity. Không có support cho claim thì không gắn nhãn sourced. Search không luôn có ngày xuất bản: giữ unknown. Không hứa search sẽ tìm được dự báo đúng ngày hoặc nguồn chính thức cho mọi nơi.

**Kiểm thử/đạt:** không gọi web trước lựa chọn; nguồn/citation ngoài registry bị từ chối; metadata rỗng/search không thực hiện/mâu thuẫn/sai địa điểm/sai ngày/nguồn cũ có trạng thái rõ; không suy mưa ngày cụ thể từ khí hậu tháng. Timeout/quota/provider error giữ draft. User/catalogue text có instruction độc hại không vượt system/validation. Test hợp đồng và UI bằng fixtures; một ca live có nguồn thật và mở link đúng phải được ghi riêng.

### G9 — Áp dụng và lưu địa điểm/hoạt động từ web

**Phụ thuộc:** G8b và persistence G5. Không bật apply chỉ vì web-advice đã chạy.

**Files:** reference model riêng cho web hoặc extension có discriminator; trip input/codec/document/mutator/validator/repository, manual entry/form, AI proposal/assistant contracts, preview/evidence UI; server trip validation và migrations mới nếu cần.

**Hành vi:** cho điểm đến chưa có trong catalogue; phân biệt catalogueRef/externalRef/userProvided, không nhét external vào namespace placeId Admin. Nguồn web và reviewed=false lưu cùng activity/trip. Preview thêm/sửa/xóa trước apply, không tự import/publish catalogue. Những ngày/giá/giờ thiếu vẫn là unknown, không tự coi hợp lệ đã xác minh. Xem source của chuyến đã lưu dùng snapshot/provenance, không phải gọi Gemini lại.

**Kiểm thử/đạt:** điểm đến chưa Admin tạo→chọn web→xem căn cứ→preview→hủy giữ nguyên→lần khác confirm→save→reopen→edit vẫn giữ nguồn/nhãn. Cross-account bị từ chối, external refs không giả catalogue refs, source snapshot sai bị reject. Cache/lỗi refresh không đổi nhãn thành reviewed. Catalogue Admin trước/sau không tự thêm record. Legacy trips vẫn đọc. Thiếu source đủ dùng phải dừng apply hoặc chỉ cho user tự nhập với nhãn đúng, không biến nội dung thiếu evidence thành có dẫn chứng.

### G10 — Nghiệm thu và chuẩn bị báo cáo

**Phụ thuộc:** các gói trên đạt hoặc báo rõ blocker; không hạ tiêu chí để gọi hoàn thành.

**Artifacts:** báo cáo cuối và kịch bản demo mới thay tham chiếu D04 Decision Engine/D05 map trong demo cũ; không xóa báo cáo lịch sử. Ghi APK hash/build/source HEAD, backend version/source, thiết bị, ngày/giờ, tài khoản thử dưới dạng mã, checks và kết quả từng ca.

**Kịch bản bắt buộc:**
1. Đăng ký→OTP→login→sửa hồ sơ; logout/login và recovery thật; sai/hết hạn có trạng thái rõ.
2. Customer tìm/đọc điểm đến→manual lịch→dự kiến/đã chi→save/read/update/delete bản thử.
3. AI catalogue: generate→cancel/apply; advice có căn cứ không sửa lịch; modify→preview→confirm→save/read nguồn còn đúng.
4. Catalogue thiếu: chủ động chọn web→tư vấn có nguồn; proposal web→apply→save/read, không thêm catalogue chung.
5. Admin user lock/unlock có kiểm quyền, sửa/ẩn place→publish→User refresh thấy dữ liệu đúng. Khóa trên test identity, không dùng tài khoản owner.
6. Lỗi mạng/AI, save chưa rõ kết quả, đóng/mở app và đổi account không mất dữ liệu đã lưu/lẫn tài khoản. Không clear data/uninstall/reset thiết bị có bản nháp.

**Đạt:** mỗi nhóm đều có test phù hợp + acceptance runtime; đủ các luồng cốt lõi theo scope và nguồn hiển thị trung thực. Test suite PASS không thay live email, Google Search, quyền server hoặc thao tác UI. iOS chưa có môi trường ghi NOT RUN; trọng tâm nghiệm thu Android môn học, không khẳng định toàn nền tảng.

## 4. Verification SOP dùng lại công cụ hiện có

Chưa chạy các lệnh dưới đây trong lượt lập kế hoạch. Khi implement: targeted checks trong lúc phát triển; mỗi gói có source change chạy analyzer + toàn Flutter suite khi chốt gói (Full có sẵn), contract/SQL tương ứng. Không lặp Full sau khi đã PASS nếu không có thay đổi mới. Cập nhật wrapper nếu nó còn liệt kê test của tính năng đã được duyệt bỏ; không tắt check quyền/dữ liệu để lấy xanh.

```powershell
./tool/verify-travelgo.ps1 -Mode Status
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/ai_generation_test.dart -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Ai -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
./tool/verify-flutter-admin.ps1 -Mode All -FlutterRoot D:/flutter/flutter
```

Full hiện gọi analyze, toàn Flutter tests và ba Node suites (`ai_gateway_test.mjs`, `itinerary_gateway_test.mjs`, `catalogue_readiness_test.mjs`), không đại diện mọi admin/SQL suite. Admin wrapper cần database disposable/docker và flags/fixture phù hợp theo runbook; thiếu môi trường ghi BLOCKED, không chạy vào DB thật thay thế. New evidence/web tests phải được thêm vào runner phù hợp. Với schema change: SQL disposable + client/server codec/contract + allow/deny account tests; chỉ apply migration lên môi trường được duyệt sau diff review.

Khi sửa Flutter thực tế: hot reload/restart hoặc rebuild phù hợp với thay đổi và công cụ có sẵn; ghi NOT RUN nếu không có runtime. Khi nghiệm thu đổi dependency/native config phải rebuild thay vì coi hot reload là đủ.

## 5. Quản lý rủi ro và giới hạn

- Các file/doc legacy được giữ để truy nguyên, không còn chỉ đạo scope. R1 recovery và AI repair chỉ đóng bằng evidence tại source được review.
- Không phá schema cũ: version/read compatibility xác định ở G5 trước AI, external refs ở G9 không giả catalogue IDs.
- Không có provenance pipeline hoàn chỉnh thì chưa quảng bá mọi đề xuất có dẫn chứng. Một phần thông tin thiếu vẫn được phép tư vấn có điều kiện nhưng nhãn rõ.
- Chưa chọn exact transport web: G8a là điểm quyết định, không nâng scope sang crawling hoặc vector search.
- Một plan được duyệt là phạm vi công việc; live email/API calls/build install/DB publish cần theo quyền owner và giữ data. Nếu thiếu quyền/credential, chuẩn bị phần local và câu hỏi cụ thể, không hỏi lại các quyết định sản phẩm đã chốt.
- Branch hiện tại là fix/ai-planning-stability; không đổi branch trong lượt này. Khi triển khai giữ branch được owner chọn hoặc tạo branch fix/feat phù hợp quy tắc repo; selective staging, không commit build/secrets và không push main. Human merge gate giữ nguyên.
- Không hứa lịch trình hoàn hảo, thời tiết chắc chắn, nguồn web luôn đúng hoặc dữ liệu toàn Việt Nam.

## 6. Handover của lượt lập kế hoạch và trạng thái duyệt

**Changed:** tạo duy nhất kế hoạch này. **Why:** biến scope/gap audit thành các đầu ra nhỏ có thể kiểm chứng, tận dụng phần đang có. **Testing:** kiểm UTF-8, links local và diff/whitespace; không chạy analyzer/tests/build/runtime vì không sửa sản phẩm. **Problems:** compatibility web, runtime email, dữ liệu nguồn và nguồn cũ/codec cần kiểm khi triển khai; các gói đang NOT STARTED. **Lesson Candidate:** có module không đồng nghĩa nối đủ luồng; phải chứng minh input→AI→evidence→preview→save/read, và tách release nguồn khỏi runtime acceptance.

**Chờ owner duyệt:** có thể duyệt toàn kế hoạch hoặc chọn bắt đầu G1a. Không có bước code tự động sau khi ghi tài liệu; dừng tại đây để owner xem. Không dùng trạng thái “đã duyệt” cho tới khi owner trả lời.
