# C5 — Lịch trình thủ công, ngân sách và chuyến đi theo tài khoản

**OWNER ĐÃ DUYỆT — CODEX ĐÃ TRIỂN KHAI C5; SOURCE/AUTOMATED VÀ SQL CONTRACT LOCAL PASS ngày26/10/2026.** Owner duyệt plan trong chat và yêu cầu tiếp tục. [Bàn giao](COURSEWORK_C5_CODEX_IMPLEMENTATION_20261026.md), [tự review](C5_CODEX_REVIEW_20261026.md). Chưa deploy/apply cloud hoặc nghiệm thu thiết bị; SQL local có bootstrap adapters được nêu rõ trong báo cáo. Nội dung phía dưới giữ mốc rà soát/kế hoạch ngày25/10, không dùng các câu “chưa chạy” lịch sử thay kết quả mới. Approval C5 không thay permanent workflow cho task sau.

Nguồn yêu cầu: [scope đồ án](../../.agent/product-scope.md), [thiết kế AI để giữ ranh giới C5](../../.agent/ai-planner-design.md), [Core R2, mục C5](../superpowers/plans/2026-10-24-coursework-core-r2.md#c5--manual-ngân-sách-và-savereadupdatedelete). C5 hoàn thiện luồng đang có, không viết lại kiến trúc Provider/Dio/repository và không bổ sung tính năng ngoài scope.

Codex không dùng Superpowers vì owner chưa yêu cầu cho task này. Nếu giao Antigravity code C5, prompt/handoff **bắt buộc yêu cầu dùng Superpowers phù hợp và ghi evidence thực tế**, theo chỉ thị thường trực owner; không hỏi lại quyền dùng skill.

## 1. Mốc source và kết quả rà soát chỉ đọc

Checkout `D:/Travel-Go-Android/travel-go`; branch `fix/ai-planning-stability`; HEAD `c4c1af51c6f9785d4a47be3c45f54b8af9bdee59` + dirty owner work C1–C4 và tài liệu. Snapshot C4 cuối `.dart_tool/c4-f01-codex-fix/final-source-snapshot.json` có379 files; đối chiếu lượt lập plan **0 drift**. HEAD chưa gồm các thay đổi chưa commit nên khi triển khai phải giữ thêm snapshot/hash, không chỉ ghi HEAD.

Tiền đề C4: [review R2](C4_CODEX_REVIEW_R2_20261025.md) đóng C4-F01, Full1088 Flutter/91 Node và analyzer sạch trên source được ghi. Đây là evidence từ lượt C4 trước, **không phải kiểm thử C5 vừa chạy**. C4 còn thiếu email/native acceptance; việc đó không thay thế hoặc buộc chặn việc lập plan C5.

| Thành phần | Có sẵn trong source | Khoảng trống / việc C5 cần kiểm |
| --- | --- | --- |
| Tạo lịch thủ công | `ManualTripFactory`, input/metadata, date policy, ngày rỗng, không gọi engine/AI | Factory chỉ giữ destinationName khi có ID hợp lệ; nhập tên không có ID bị mất tên |
| Sửa thông tin chuyến đi | `ManualTripInputForm`, preview resize, giữ/chuyển/xóa hoạt động có xác nhận | `_readInput` lấy tên từ catalogue selection; phải giữ tên tự nhập và tên lịch sử khi chưa chọn lại catalogue |
| Validation client | Codec đã cho destinationId=null cùng destinationName dạng text | `EditableTripValidator` accountSave vẫn bắt có ID; chưa lưu được chuyến tự nhập đúng chủ trương C5 |
| Validation server | Migration dynamic IDs ngày23/10 đã bỏ enum12 ID, có membership checks | Nhánh destinationId=null vẫn reject account_save trong validator mới nhất; cần sửa contract tương ứng, không dùng migration enum cũ làm nguồn sự thật |
| Hoạt động | Form, timeline, add/edit/delete/move, ngày/giờ/ghi chú; mutator bảo toàn actual snapshot khi xóa item | Kiểm xuyên luồng sửa ngày/số người, trùng giờ, hủy preview, mất liên kết; không mặc định các phần này đều chưa làm |
| Ngân sách | BigInt guards; dự kiến/đã chi, hai số dư, unknown khác0; UI đã có nhãn/cảnh báo | Bổ sung vector C5 và roundtrip, không đổi công thức đang đúng chỉ để có diff |
| Lưu theo tài khoản | SavePreview, confirm/retry, pending request, repository/service và RPC create/read/update/delete/list | Kiểm đủ vòng qua provider→repository→service, đặc biệt tự nhập, timeout/lost ACK, conflict và A→B |
| Test sẵn có | Factory, dynamic ID, budget, provider, codec/mutator/validator, repository/service, saved UI/end-to-end | Dynamic ID test không chứng minh tên tự nhập null-ID; một số end-to-end dùng fixture guest/import lịch sử, không dùng chúng thay nghiệm thu product theo tài khoản |

Các gap trên là kết luận đọc source, **chưa có fresh RED/GREEN C5**. Trước sửa phải tái hiện bằng test/control. Lượt chỉ lập plan không chạy Flutter/SQL tests.

## 2. Hành vi đích và giới hạn

Luồng chính: đăng nhập → nhập thông tin → tạo lịch thủ công → thêm/sửa hoạt động và ngân sách → xem trước lưu → hủy hoặc xác nhận → danh sách chuyến đi → mở lại → sửa/lưu phiên bản tiếp → xác nhận xóa.

- Điểm đến catalogue: giữ đúng ID/tên được chọn; giữ kiểm membership/historic ID hiện có.
- Điểm đến tự nhập: `destinationId=null`, `destinationName='Phú Yên'`; tên nonblank tối đa180 ký tự theo contract hiện hành. Không tạo slug giả hoặc tự nhập địa điểm này vào catalogue Admin.
- Sửa tên chuyến đi/ngân sách không được vô tình xóa destinationName đang có. Chuyển catalogue↔tự nhập phải rõ ràng, không âm thầm coi tên tự nhập là thông tin Admin đã xác minh.
- Lưu tài khoản cần đúng tài khoản/authority, tên/nơi xuất phát/ngày và các input hợp lệ hiện hành. Codec/read vẫn giữ tương thích bản lịch sử; không dùng việc nới destinationId để nới quyền owner hoặc bỏ ngày bắt buộc.
- Ngân sách tổng, dự kiến và đã chi là ba dữ liệu khác nhau. Hai số dư = budget−estimateKnown và budget−actual; không cộng hai sổ rồi trừ chung, không biến unknown thành0.
- C5 không mở guest-save/import thành product flow, không bản đồ/Decision Engine, không làm thêm AI/web/catalogue/admin. Tên tự nhập phục vụ lịch thủ công không tự bảo đảm có catalogue để AI tạo lịch.

## 3. Gói C5.1 — Giữ và sửa điểm đến tự nhập trong app

**Files có thể sửa:** `lib/features/trip_planner/services/manual_trip_factory.dart`, `services/editable_trip_validator.dart`, `presentation/widgets/manual_trip_input_form.dart`; `models/trip_request.dart`/`providers/planner_input_provider.dart`/entry screen chỉ khi data flow thật cần. `lib/features/trips/models/editable_trip_codec.dart` chỉ thay khi test chỉ ra contract thiếu; hiện codec đã hỗ trợ null-ID+name.

**Trình tự:**

1. Test factory với null-ID/tên Phú Yên, explicit title, ngày/số người; roundtrip encode/decode giữ nguyên.
2. Test mở input form từ chuyến null-ID có tên, chỉ sửa ngân sách hoặc số người rồi xác nhận: tên vẫn còn. Test hủy giữ nguyên toàn bộ document.
3. Tái dùng form hiện có để nhập/chuyển kiểu điểm đến; giữ tên lịch sử khi catalogue không còn mục đó. Không tự lấy một mục catalogue khác hoặc reset về tên mặc định.
4. Cho accountSave chấp nhận tên tự nhập hợp lệ; từ chối rỗng/toàn khoảng trắng/quá dài, ID sai định dạng; không nới validation khác.

**Tests:** `manual_trip_factory_test.dart`, `manual_dynamic_destination_test.dart`, `editable_trip_codec_test.dart`, `editable_trip_validator_test.dart`, `manual_planner_screen_test.dart` hoặc `manual_discovery_flow_test.dart` theo component thực sự đổi.

**Đạt khi:** tên và null-ID giữ qua tạo→form→codec; catalogue/dynamic/historical ID controls vẫn đạt; account preview không bị chặn chỉ vì điểm đến tự nhập. App-only PASS chưa chứng minh server chấp nhận.

## 4. Gói C5.2 — Đồng bộ contract lưu trên server

**Nguồn hiện hành phải đọc:** `supabase/migrations/20261023170000_manual_dynamic_destination_ids.sql`, các RPC guards trong migrations mới hơn nếu có; client `editable_trip_service.dart`/repository. Không sửa migration lịch sử đã áp dụng để giả vờ server đã cập nhật.

**Thay đổi dự kiến:** migration additive mới cho validator/producer thật cần thiết. Khi implement, tạo bằng Supabase CLI `migration new` theo help/skill, không tự bịa timestamp trong plan. Cho null-ID + tên hợp lệ khi account_save; kiểm catalogue membership vẫn áp dụng khi có catalogue ID, không cho fake ID bỏ qua kiểm tra. Giữ đúng owner, role/account guards, grants/RLS, canonical payload/digest, requestId và version.

**SQL tests:** mở rộng `supabase/tests/editable_trip_v2.sql`/negative controls hoặc thêm `supabase/tests/coursework_trip_roundtrip.sql` cho self-entered destination, published/historic controls, malformed/blank/oversize, wrong owner/Guest, create→read→update→delete và replay.

**Lưu ý verification đã phát hiện khi lập plan:** `tool/verify-planner-core.ps1` hiện dựng PostgreSQL tách riêng nhưng đang chạy contract V1 guest/request-context, **chưa nạp đầy đủ editable V2/dynamic destination**. Không dùng PASS của nó để chứng nhận thay đổi V2. Tái dùng cách dựng DB local tách riêng, bổ sung mode/suite V2 rõ ràng hoặc runner local riêng, có migration order chính xác và negative control chứng minh runner trả nonzero khi SQL fail. Không chạy `run-editable-trip-concurrency.ps1 -ExecuteStaging`: runner đó nhắm staging thật, không phải DB local dùng một lần.

**Đạt khi:** client và SQL cùng chấp nhận/reject contract; null-ID+name lưu/mở/sửa không mất tên; owner B không đọc/đổi/xóa trip A; idempotency/version/digest controls còn đạt. SQL chưa chạy thì ghi chưa kiểm chứng server; không chỉ dùng fake HTTP để gọi end-to-end server PASS. Không deploy/apply cloud trong gói này.

## 5. Gói C5.3 — Hoạt động, ngày và ngân sách

**Files kiểm trước:** `editable_trip_mutator.dart`, `editable_trip_validator.dart`, `budget_calculator.dart`, `trip_date_policy.dart`; `manual_activity_form.dart`, `manual_expense_form.dart`, `manual_itinerary_timeline.dart`, `manual_budget_panel.dart`, input resize preview. Chỉ sửa nơi có regression/gap được chứng minh.

**Bộ ca bắt buộc:**

- Thêm/sửa/xóa/chuyển hoạt động giữa ngày, thứ tự và giờ; ngày calendar khớp range; lỗi/trùng giờ theo validation hiện hành; input lỗi không làm mất nội dung đang nhập.
- Rút ngắn lịch có hoạt động bị ảnh hưởng: preview đúng, hủy giữ nguyên, xác nhận mới áp dụng lựa chọn. Giữ ghi chú và stable IDs khi không bị thay đổi có chủ ý.
- Xóa hoạt động: dự kiến liên kết được xử lý đúng chính sách hiện có; khoản đã chi được giữ và có sourceItemSnapshot. Không âm thầm xóa hoặc tính lại actual theo số người/ngày.
- Vector C5:2 người, budget1.000.000; estimate per_person100.000 + trip_total50.000; actual70.000 → knownEstimate250.000, actualTotal70.000, estimateRemaining750.000, actualRemaining930.000.
- Thêm một estimate chưa biết giá: unknownCount tăng, knownEstimate không bị bịa thêm;0 được nhập rõ là0. Kiểm inactive, per_day/per_person_day/custom quantity, vượt ngân sách và overflow bằng tests sẵn có.
- Đổi số người/ngày chỉ đổi multiplier phù hợp của dự kiến; actual giữ nguyên. Lưu/mở lại vẫn có đủ hai sổ và hai số dư.

**Tests:** `budget_calculator_test.dart`, `manual_budget_ui_test.dart`, `editable_trip_mutator_test.dart`, `editable_trip_validator_test.dart`, `manual_planner_provider_test.dart`. Nếu arithmetic đã đúng và tests đạt, giữ implementation; không refactor calculator hoặc biểu đồ để mở scope.

**Đạt khi:** các giá trị trên được assert cả logic lẫn UI cần thiết; unknown/0/actual không lẫn; hoạt động và ledger không mất qua sửa/ngày/xóa/liên kết.

## 6. Gói C5.4 — Lưu, mở lại, sửa và xóa theo tài khoản

**Files kiểm:** `manual_planner_provider.dart`; `manual_save_preview.dart`; `editable_trip_repository.dart`, `editable_trip_service.dart`, `editable_trip_codec.dart`; `my_trips_screen.dart`, `editable_trip_detail_screen.dart`, SavedTripsProvider và binding auth liên quan.

1. Trước lưu: preview từ đúng document/generation; Hủy không gửi request. Sửa document sau preview khiến preview cũ không áp dụng được.
2. Confirm create: có server ACK/digest/owner đúng mới báo đã lưu. Mở từ danh sách theo tài khoản, kiểm title/destination/ngày/số người/activity IDs/ghi chú/estimates/actuals.
3. Sửa rồi lưu: đúng tripId và expected version, không tạo bản mới. Conflict giữ bản đang sửa, nêu có phiên bản mới; không tự ghi đè.
4. Timeout hoặc mất ACK: giữ pending request, frozen bytes và requestId; thử lại đúng attempt cũ. Test bấm hai lần, đổi nội dung khi request đang bay, retry lookup rồi head mới hơn: không tạo trip thứ hai hoặc báo version sai.
5. Xóa có xác nhận: Hủy không gửi; ACK đúng mới bỏ cache/list. Timeout/conflict không báo xóa xong giả.
6. Đổi A→B/Guest khi load/save/delete còn chờ: xóa state riêng A và chặn cả success/error muộn; B lỗi hoặc đang tải cũng không hiện dữ liệu A. Không chỉ kiểm response mới mà bỏ cache A đang có.
7. Trace đường vào editor/save từ Home/Khám phá/My Trips; account required khi lưu. Nếu còn entry point guest-save/import ngoài scope thì xử lý đúng đường product, không bật lại helper lịch sử chỉ vì test cũ dùng trực tiếp chúng. Không xóa local cache/legacy readers/guards dưới tên cleanup.

**Tests:** `manual_planner_provider_test.dart`, `editable_trip_repository_test.dart`, `editable_trip_service_test.dart`, `editable_saved_trip_ui_test.dart`, `saved_trips_provider_test.dart`, `my_trips_truthful_state_test.dart`; giữ relevant assertions của `auth_navigation_test.dart`.

**Đạt khi:** vòng create/read/update/delete rõ ràng cho catalogue và tự nhập; đúng account; hủy/mất mạng/conflict giữ dữ liệu và không thành công giả. Các cơ chế đã có không bị viết lại nếu đạt.

## 7. Gói C5.5 — Roundtrip tổng hợp, review và bàn giao

**Test mới:** `test/coursework_trip_roundtrip_test.dart`. Dùng fixtures local có state, fake Dio transport đi qua service/repository/provider thật và local store khi cần; không chỉ stub save trảtrue. Test này chứng minh client phối hợp đúng contract; SQL suite riêng mới chứng minh các RPC thực sự lưu/đọc đúng.

Kịch bản chính: account A tạo chuyến2 ngày/2 người, destinationId=null/name Phú Yên → thêm hoạt động, notes, hai estimates và actual theo vector → preview/cancel giữ nguyên → preview/confirm → list/read lại → sửa hoạt động/ngân sách → update → read lại giữ đúng data/IDs → delete cancel → delete confirm. Có controls catalogue ID, lost ACK/retry one record, A→B và wrong-owner reject. Không gọi Decision Engine, AI hoặc bản đồ để hoàn thành.

**Thứ tự:** snapshot mới → C5.1 → C5.2 → C5.3 → C5.4 → C5.5. Viết regression/control trước từng gap; chạy targeted theo phần sửa; cuối cùng Full. C5.3 có thể chỉ bổ sung evidence nếu source đã đúng; không bắt tất cả gói đều phải có app diff.

```powershell
./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/manual_trip_factory_test.dart,test/manual_dynamic_destination_test.dart,test/editable_trip_codec_test.dart,test/editable_trip_validator_test.dart,test/editable_trip_mutator_test.dart,test/budget_calculator_test.dart,test/manual_planner_provider_test.dart,test/manual_budget_ui_test.dart,test/editable_trip_repository_test.dart,test/editable_trip_service_test.dart,test/editable_saved_trip_ui_test.dart,test/saved_trips_provider_test.dart,test/my_trips_truthful_state_test.dart,test/manual_planner_end_to_end_test.dart
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
git diff --check
```

Thêm test mới vào targeted sau khi tạo. Lệnh SQL local cụ thể chốt sau khi hoàn thiện runner V2 đúng migration prerequisites; không đưa một command chưa hỗ trợ V2 vào plan như bằng chứng. Kiểm runtime PostgreSQL có sẵn; không cài/nâng runtime hoặc kết nối cloud thay thế ngầm nếu local thiếu.

## 8. Tiêu chí chốt và ranh giới quyền

- Client roundtrip giữ dữ liệu, SQL contract tương ứng đạt; analyzer sạch, Full Flutter/Node exit0 trên cùng source snapshot. Ghi commands/log/count/hash thật, không kế thừa1088/91 của C4 như kết quả C5.
- Review tập trung vào dữ liệu mất qua các lớp, khoản đã chi, hai số dư, timeout/retry và account isolation; không chỉ review giao diện. Phân biệt self-review và review độc lập.
- Báo cáo5 mục Changed/Why/Testing/Problems/Lesson Candidate; trace một chuyến UI→provider→repository→RPC→read→UI, trước/sau một lỗi đại diện và evidence. Cập nhật master/core checkpoint sau kết quả thực tế, không đánh dấu C5 xong khi plan được duyệt.
- Demo email/auth/native vẫn riêng. Nghiệm thu create/read/update/delete trên app/backend thật chỉ khi có môi trường/tài khoản thử và quyền tương ứng; mocks/local PostgreSQL không chứng minh deployment đang chạy.
- Không live SQL/deploy/merge/commit/push, build/install/hot reload hoặc thao tác device từ approval plan. Giữ dirty owner work, Git safety và guard tối đa3 vòng sửa lỗi hiện hành; không reset bằng tên gói mới. Không đổi dependencies/native architecture để hoàn thành C5.

## 9. Bàn giao lượt chỉ lập plan

**Changed:** chỉ thêm tài liệu plan C5. **Why:** chia scope đã chốt thành gói nhỏ dựa trên gap source, tái dùng phần hoạt động/ngân sách/lưu đã có. **Testing:** đọc app/test/SQL/runner và đối chiếu snapshot C4,0 drift; chưa chạy tests/SQL C5. **Problems:** gap tự nhập xuyên app/server chưa sửa; runner local hiện có chưa chứng minh V2; chưa có evidence C5/live mới. **Lesson Candidate:** một tên điểm đến phải được giữ xuyên UI/factory/validator/server/read; test codec đơn lẻ và kiểm migration lịch sử không đủ chứng minh toàn luồng.
