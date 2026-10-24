# Rà soát nghiệp vụ lập kế hoạch, tài khoản và bản đồ — chờ owner xác nhận phạm vi

## Trạng thái và cách đọc

- Codex chỉ phân tích/review. **Chưa lập implementation plan, chưa sửa sản phẩm, chưa giao thực thi cho Antigravity.** Owner yêu cầu nêu lỗi rồi chờ xác nhận trước khi tạo plan.
- Repo `D:/Travel-Go-Android/travel-go`, branch `codex/phase-3-discovery-design`, HEAD `89659f5a7c48eca4053b3f1c5e519d42a7a4efa8`, cộng working tree có sẵn nhiều thay đổi dirty/untracked. Findings áp dụng cho mã trong working tree được đọc trong lượt này, không chỉ riêng commit HEAD.
- Owner cho dùng superpowers trong task hiện tại. Áp dụng using-superpowers, systematic-debugging, brainstorming và verification-before-completion; kết hợp travelgo-session và hướng dẫn Supabase. Chưa invoke writing-plans vì còn chờ xác nhận phạm vi theo yêu cầu owner.
- `P1`: ảnh hưởng trực tiếp tính đúng đắn dữ liệu/luồng chính. `P2`: tính năng chưa nối hoặc hiển thị gây hiểu sai. Mức này phục vụ ưu tiên sản phẩm, không thay một cuộc audit bảo mật đầy đủ.
- `REPRO`: probe cục bộ trên code thật với API/GPS/account giả lập. `SOURCE`: truy vết mã nguồn; chưa nghiệm thu hành vi trên APK/máy thật.

## Luồng dữ liệu đã kiểm tra

Form lập kế hoạch cập nhật `PlanTripRequest` trong `TripProvider`. Điểm đến được chọn từ Discovery còn nằm trong `TripMetadataV1`. Gửi backend dùng request được ghép với metadata; mở lịch thủ công dùng `ManualTripFactory(request, metadata)`. Hai đường này hiện đọc ngày từ hai chỗ khác nhau.

Kết quả backend qua `PlanTripResponse` tới dashboard. Lưu cloud qua `SavedTripsProvider.saveTrip` nhưng dashboard chỉ chuyển response; mở lại/copy sử dụng codec và legacy adapter. Bản đồ lộ trình dùng `MapProvider` chung; bản đồ ngày trong trình soạn thủ công là một màn riêng, có thể nhận snapshot danh mục nhưng các entry point chưa truyền snapshot.

## Tám lỗi owner đã nêu

### L1 — P1 — Không giữ xuyên suốt ngày tháng đã chọn [REPRO]

- Dashboard gọi `saveTrip` nhưng không truyền `startDate/endDate`: `lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart:538`. Provider hỗ trợ hai tham số này tại `lib/features/trips/providers/saved_trips_provider.dart:709`.
- Probe chọn 01–03/11/2026, bấm lưu trên dashboard với service giả: giá trị ngày đến provider là `null`.
- Một điểm đứt khác cùng nhóm: `_pickDateRange` ghi ngày vào request tại `home_planner_screen.dart:179`, `TripProvider.updateRequest` không đồng bộ metadata tại `trip_provider.dart:223`; factory đọc ngày từ metadata tại `manual_trip_factory.dart:22`. Mở lịch thủ công từ cùng đầu vào trả `input.startDate == null` và ngày trong lịch chưa có ngày thực.
- Ca đối chứng: `submitPlan` vẫn gửi được `startDate=2026-11-01` và destination `hue` tới fake backend. Không kết luận mọi đường truyền ngày đều hỏng.
- Hành vi cần đạt: ngày trên form, lịch thủ công, payload lưu, bản mở lại và timeline thống nhất; không tự gán ngày hiện tại để che dữ liệu thiếu.

### L2 — P1 — Ma trận trình bày gói du lịch giả như phương án được tính [SOURCE]

- `_buildOptions()` trong `trip_comparison_matrix_widget.dart:44` luôn trả ba gói 4.200.000 / 3.450.000 / 4.850.000 đồng, khách sạn/resort, vé bay, Bà Nà, Mỹ Khê, Sơn Trà và điều kiện hủy cố định.
- Ngân sách truyền vào chỉ đổi dòng mô tả. Dashboard còn lấy `totalAllocated` hoặc mặc định 4 triệu thay cho ngân sách đầu vào (`dashboard_result_screen.dart:397`).
- Người chọn Huế/ngân sách khác vẫn thấy các chi tiết Đà Nẵng và nhãn “MCDA đề xuất”.
- Contract response hiện có điểm đến/phương tiện/ngân sách/lịch trình, không có bộ ba package hoàn chỉnh hay chính sách đặt phòng/hủy. Không được đổi ba số bằng công thức ở Flutter rồi gọi đó là đề xuất thật. Cần chốt dùng các phương án có trong DTO hoặc mở rộng contract backend ở bước thiết kế sau xác nhận.

### L3 — P2 — Pareto không co giãn theo thời gian thực [REPRO]

- `pareto_chart_widget.dart:66` cố định `maxX: 12`.
- Probe đưa phương tiện 20 giờ: maxX vẫn 12. Điểm nằm ngoài phạm vi trục; chưa thấy logic lọc giá trị không hữu hạn hoặc dự phòng cho khoảng trục suy biến.
- Sửa phần trình bày trục không đồng nghĩa tính lại tập Pareto ở Flutter; cờ tối ưu vẫn phải lấy từ backend.

### L4 — P1 — Biểu đồ ngân sách nhận phần âm khi vượt ngân sách [REPRO]

- `budget_donut_chart.dart:23` chuyển thẳng `remainingSafetyMargin` vào `PieChartSectionData`. Tổng dùng để tính tỷ lệ là tổng chi cộng phần còn lại.
- Probe chi 1,4 triệu/ngân sách 1 triệu: section dự phòng nhận -400.000. Các tỷ lệ cũng có thể âm hoặc vượt 100%; nếu tổng không dương widget biến mất.
- Đã chứng minh dữ liệu âm đi vào biểu đồ, **chưa chứng minh app crash**. Không được sửa bằng cách xóa khoản vượt ngân sách khỏi số tổng; cần thể hiện khoản vượt riêng và giữ số liệu gốc.

### L5 — P1 — Bản đồ từ kết quả không nhận các hoạt động của lịch trình [SOURCE]

- Hai chỗ mở `TripMapScreen` tại `dashboard_result_screen.dart:86` và `:259` chỉ truyền tọa độ/tên điểm đến; không truyền `initialWaypoints`.
- Quan trọng hơn, `Activity` tại `trip_response.dart:220` chỉ có time/title/cost/duration, chưa có placeId hay tọa độ. Chỉ sửa tham số Navigator chưa đủ để định vị đáng tin cậy các điểm tham quan.
- Cần phân biệt tuyến GPS hiện tại → điểm đến với tuyến các điểm trong lịch. Không suy tọa độ từ tên gần giống hoặc thay điểm không rõ bằng tọa độ trung tâm thành phố.

### L6 — P2 — Còn thẻ chuyến đi demo có vẻ như đơn thật, phạm vi hẹp [SOURCE]

- `my_trips_screen.dart:49–60,134` chỉ bật thẻ giả cho `isDemoSession` và email chứa `minh`.
- `_buildUpcomingDemoCard` tại `:338` hiển thị trạng thái đã xác nhận, mã đơn và Furama/ngày khởi hành cố định.
- **Không xác nhận lỗi này xảy ra với tài khoản Supabase thật đang rỗng.** Các tài khoản đó hiện có empty state. Nhu cầu là bỏ thẻ giả còn lại hoặc cô lập demo rõ ràng, không viết lại toàn màn danh sách.

### L7 — P2 — Timeline kết quả chưa hiển thị ngày thực [SOURCE]

- `itinerary_timeline_widget.dart:5` chỉ nhận `List<ItineraryDay>` và hiển thị “NGÀY n”; `ItineraryDay` không có calendar date. Dashboard không truyền ngày khởi hành.
- Phải áp dụng ngày đã chọn cùng ordinal, không bịa ngày nếu đầu vào không có.
- Timeline của lịch thủ công đã có `manualDayLabel` hiển thị ngày thực khi document chứa ngày (`manual_itinerary_timeline.dart:9`). Không kết luận cả hai timeline đều chưa có hỗ trợ ngày.

### L8 — P2 — Nút Trợ giúp AI tại chi tiết điểm đến chưa nối chức năng [SOURCE]

- `destination_detail_screen.dart:134` chỉ hiện SnackBar “AI chưa khả dụng”.
- Trình soạn thủ công đã có luồng AI generation/assistant/preview/apply và yêu cầu session/consent; không nên tạo thêm một chatbot độc lập hay gọi AI ngầm khi mở trang.
- UI dùng `TripProvider.supportedAiDestinationIds` và `AiGenerationContext.fromDocument` vẫn kiểm danh sách 12 điểm đến cũ; trong khi gateway mới đã kiểm ID theo `isValidDestinationId`. Nới codec/gateway chưa đủ để kích hoạt AI cho điểm đến động qua UI. Cần chốt phạm vi AI trước khi lập plan; không bypass session, consent hoặc quota để làm nút có vẻ hoạt động.

## Ba yêu cầu bổ sung về Cá nhân / Tài khoản

### A1 — P1 cho demo trên máy thật — API URL chỉ nằm trong RAM, mục cấu hình bị giới hạn build [SOURCE]

- `api_constants.dart:6` chỉ có static override, không có load/save local. Lưu/mặc định trong `profile_screen.dart:225,235` chỉ gán biến nhưng thông báo đã lưu.
- Mục cấu hình đặt dưới `if (kDebugMode)` tại `profile_screen.dart:139`: máy thật chạy debug vẫn truy cập được; **profile/release mới bị ẩn**, không phải mọi máy thật đều bị chặn.
- Cần lưu bền vững, restore trước khi các client dùng URL, validate/chuẩn hóa http(s), thể hiện lỗi ghi và reset thật. SharedPreferences có sẵn trong lockfile theo dependency gián tiếp, chưa phải dependency trực tiếp khai báo trong pubspec.

### A2 — P1 về tính đúng xác thực — Còn nhánh cấp user giả từ OTP [REPRO, có điều kiện]

- `auth_provider.dart:643–658`: thiếu client/email hoặc không nhận user ở nhánh cũ thì chấp nhận bất kỳ chuỗi có độ dài 6 và gán `usr-verified`, `0900000000`.
- Probe `AuthProvider().verifyOtp('abcdef')` trả true. Test cũ còn khẳng định mã tùy ý 123456 phải đăng nhập thành công (`auth_navigation_test.dart:98`).
- Luồng main có client thật inject lifecycle loader (`main.dart:268`); khi có loader, `verifyOtp` dùng guarded Supabase mutation tại `auth_provider.dart:598`. **Không có bằng chứng mã OTP sai bị Supabase chấp nhận trong đường chính này.**
- Cần xóa fallback xác thực khỏi code dùng chung và sửa fixture test; các test phải dùng SDK giả để mô phỏng kết quả server, không bắt sản phẩm tạo user giả.

### A3 — P1 khi người dùng quên mật khẩu — Chưa có luồng khôi phục hoàn chỉnh [SOURCE]

- `forgot_password_screen.dart:26` chỉ có nội dung tĩnh; không có form hay lời gọi gửi email.
- Không thấy đường nhập mật khẩu mới / xử lý passwordRecovery. Callback hiện yêu cầu một OAuth intent đang tồn tại (`auth_provider.dart:1280`), nên không thể tái sử dụng nguyên trạng để nhận liên kết recovery tự mở app.
- Hành vi hoàn chỉnh: nhập email → Supabase tiếp nhận yêu cầu → mở liên kết → xác thực recovery hợp lệ → nhập mật khẩu mới → cập nhật → đăng nhập bằng mật khẩu mới.
- Tài liệu chính thức Flutter: https://supabase.com/docs/reference/dart/auth-resetpasswordforemail . Redirect phải được cấu hình phù hợp; chưa đọc cấu hình SMTP/allowlist của môi trường live, chưa gửi email thật và chưa đổi tài khoản thật.

## Các lỗi nghiệp vụ phát hiện thêm

### N1 — P1 — Khoảng ngày và số ngày có thể mâu thuẫn [REPRO]

- Chọn 01–03/11 rồi kéo số ngày lên 5: callback slider chỉ `copyWith(numDays:5)` (`home_planner_screen.dart:539`). Request giữ 01–03/11 nhưng báo 5 ngày.
- Date picker còn clamp số ngày tối đa 30 trong khi vẫn giữ nguyên khoảng ngày dài hơn (`:181`); slider giới hạn 14. Ba giới hạn chưa thống nhất.
- Cần quy tắc duy nhất cho quan hệ start/end/count; không để server, lịch thủ công và nhãn UI hiểu ba phiên bản khác nhau.

### N2 — P1 — Lưu kết quả cloud làm mất đầu vào và có thể sai nghĩa ngân sách [REPRO + SOURCE]

- Serializer dashboard chỉ lưu `res.toJson()` (`dashboard_result_screen.dart:448`), không request/metadata. Probe bắt payload tại save không có request.
- `decodeBareLegacyPlan` trả request null (`trip_payload_codec.dart:481`). `LegacyTripCopyAdapter` phải yêu cầu nhập lại đầu vào khi mở bản sao (`legacy_trip_copy_adapter.dart:51`): không phục hồi được origin/số người/sở thích/priority/companion từ bản cloud này.
- `budgetTotal` được gán bằng phần đã phân bổ, hoặc 4 triệu nếu thiếu (`dashboard_result_screen.dart:546`), không phải ngân sách người dùng chọn. Điều này làm mất ý nghĩa hạn mức gốc.
- Đây là dữ liệu mới tạo ra vẫn ở dạng cũ mất thông tin, không chỉ vấn đề tương thích với lịch sử. Cần lưu đủ contract đã có, giữ đọc được bản cũ và hiển thị trung thực dữ liệu thiếu.

### N3 — P1 — Mở lại lịch thủ công chưa dùng snapshot danh mục công khai [SOURCE]

- `home_planner_screen.dart:1063`, `editable_trip_detail_screen.dart:192,734`, `editable_draft_import_selection.dart:523`: mở `ManualPlannerScreen` không truyền snapshot.
- Các đường mở saved/draft/copy còn trực tiếp `CatalogueRepository().load()` thay cho snapshot đang phát hành. Có thể mất lựa chọn địa điểm admin mới thêm khi sửa/mở lại.
- `manual_planner_screen.dart:150` chuyển snapshot optional tới bản đồ ngày. Nếu null, `ManualPlaceLocations.find` chỉ còn hai tọa độ tham khảo gán sẵn Hoàn Kiếm/Đại Nội (`manual_place_locations.dart:21`), dù danh mục phát hành có tọa độ cho nơi khác.
- Một component test tự truyền snapshot không chứng minh các entry point của app đã nối đúng. Cần kiểm chuỗi tạo mới → lưu → mở lại → bản đồ, không chỉ widget độc lập.

### N4 — P1 — Đổi URL backend có thể chỉ tác dụng với planner, bản đồ vẫn gọi URL cũ [SOURCE]

- TripApiService cập nhật `_dio.options.baseUrl` trước request tại `trip_api_service.dart:37,60`.
- MapApiService chỉ đọc URL khi constructor tạo Dio (`map_api_service.dart:32`), `getRoute` không cập nhật lại.
- Khi map client đã khởi tạo rồi mới sửa URL ở Cá nhân, lập kế hoạch và route có thể dùng hai host khác nhau. Persist URL riêng lẻ chưa đủ để giải quyết.

### N5 — P1 — Bản đồ dùng lại điểm đến/tuyến chuyến trước khi ngữ cảnh mới không có tọa độ [REPRO]

- `MapProvider.init` chỉ thay `_destination` nếu tham số khác null, không xóa destination/route cũ (`map_provider.dart:498`). Provider được dùng chung.
- Probe mở điểm đến `(16.46,107.58)`, sau đó gọi init không destination: destination vẫn là điểm cũ và route cũ được dùng lại.
- Điều này xảy ra cả khi mở tab map không chọn đích, hoặc dashboard chuyến mới có winner thiếu tọa độ. Không được hiển thị tuyến chuyến trước như tuyến hiện tại.

### N6 — P2 — Các tab quản lý chuyến đi chưa phân loại trạng thái thực [SOURCE, thiếu chức năng]

- `my_trips_screen.dart:58,85–88,142` đếm toàn bộ visible trips vào “Sắp đi”, hai tab còn lại cố định 0/empty.
- `SavedTrip` có status/startDate, nhưng `OwnedTripSummary` không mang đủ thông tin để phân nhóm lịch thực. Chuyến trong quá khứ cũng có thể nằm ở Sắp đi.
- Không suy rằng hệ thống đã có quy trình đặt dịch vụ, hủy đơn hoặc hoàn thành chuyến. Sau xác nhận cần chốt cách phân nhóm theo ngày và trạng thái nào thực sự được hỗ trợ; không tạo chức năng booking/hủy giao dịch mới ngoài phạm vi.

## Bằng chứng kiểm tra trong lượt này

1. Test sẵn có: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/trip_request_adaptive_test.dart,test/trip_provider_adaptive_test.dart,test/manual_trip_factory_test.dart,test/manual_day_map_test.dart,test/ai_generation_test.dart,test/ai_assistant_test.dart,test/auth_navigation_test.dart,test/profile_preferences_test.dart`.
   - **114 PASS, exit 0**. Log `.dart_tool/travelgo-verification/20261023T165337229Z-31960/flutter-tests.log`; bản wrapper `.dart_tool/codex-core-review/existing-targeted.log`.
2. Probe mới `.dart_tool/codex-core-review/core_probe_test.dart`, chạy bằng cached Flutter snapshot `test --no-pub --concurrency=2 --reporter=expanded`.
   - **1 PASS đối chứng + 8 FAIL tái hiện, exit 1**, log `.dart_tool/codex-core-review/probes.log`.
   - FAIL: map giữ đích cũ; manual mất ngày; slider ngày mâu thuẫn; OTP thiếu backend vẫn cấp user; Pareto maxX 12 cho điểm 20h; pie nhận số âm; cloud không truyền ngày; cloud không giữ request.
   - Đây là kết quả chứng minh lỗi chưa sửa, không phải bộ regression đã GREEN. Probe nằm trong thư mục ignored, không thêm vào sản phẩm.
   - Lượt đầu có lỗi finder của reviewer ở hai probe bấm lưu; đã sửa finder trong probe và chạy lại để có failures do giá trị thực null. Không tính lỗi finder là bug ứng dụng.
3. Không chạy Full/analyzer/build/APK/device trong lượt chỉ audit này; không tuyên bố hệ thống sạch mọi lỗi. Chưa gọi AI/Supabase/email/SQL thật, không deploy, không thay native/dependencies.
4. Browser đọc được reference resetPasswordForEmail; fetch changelog.md bị công cụ từ chối content-type. Không có triển khai Supabase dựa vào suy đoán phiên bản trong lượt này.

## Điểm đúng đã được phân biệt

- Model/codec đã giữ trường date/companion trong request; ca gửi backend có ngày PASS. Vấn đề nằm ở các điểm nối tiếp theo, không cần viết lại toàn bộ DTO.
- Timeline thủ công đã hỗ trợ ngày thực khi document có ngày.
- AI preview/consent/apply trong manual editor đã có source và targeted tests pass; nút AI ở destination detail chưa nối không đồng nghĩa toàn bộ AI đang hỏng.
- Auth lifecycle và các test chuyển tài khoản/giữ dữ liệu riêng vẫn pass trong bộ targeted. Không mở rộng kết luận OTP fallback thành bypass Supabase live.
- Tài khoản thật rỗng không đi vào demo card theo điều kiện hiện có.

## Phạm vi đề nghị owner xác nhận, chưa phải kế hoạch triển khai

Giữ hai gói owner đã chọn, bổ sung ba mục Cá nhân/Tài khoản. Gộp N1–N5 vào nhóm nghiệp vụ liên quan vì chúng trực tiếp làm sai lịch, mất đầu vào hoặc hiển thị sai bản đồ. N6 là phần quản lý chuyến đi chưa hoàn thiện cần owner xác nhận thêm trước khi đưa vào phạm vi code.

Sau owner xác nhận, Codex mới viết thiết kế/plan theo file, contract và test. Đặc biệt cần chốt dữ liệu thực cho ma trận và định danh điểm tham quan trước khi Antigravity code. Antigravity thực thi; Codex review diff và kiểm chứng lại các ca lỗi gốc. Chưa tự gửi message sang ứng dụng khác.

## Changed / Why / Problems / Lesson Candidate

- Changed: chỉ báo cáo review này và probe/log ignored; không sửa sản phẩm.
- Why: tách “dữ liệu có trong model” khỏi “dữ liệu thực sự đi xuyên qua các màn hình”; kiểm từng ranh giới form/provider/service/save/reopen/map.
- Problems: các findings còn mở; nghiệm thu máy thật, recovery email thật và AI thật chưa chạy trong lượt này. Không gắn PASS live từ test giả lập.
- Lesson Candidate: Input đúng ở form nhưng sai khi lưu → nhiều nguồn ngày/serialization mất ngữ cảnh → kiểm roundtrip nguyên chuỗi, không chỉ test constructor và request. Widget có hỗ trợ snapshot nhưng entry point không truyền → test component che khuất thiếu wiring → cần một ca tạo/lưu/mở lại/bản đồ dùng cùng snapshot.
