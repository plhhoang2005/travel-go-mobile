# Planner, Results & Map Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Owner đã chọn Antigravity implement và Codex review; không spawn subagents hoặc đổi executor. Checkboxes là tiến độ kỹ thuật, không phải approval gate từng task.

**Goal:** Giữ đúng cấu hình chuyến đi qua kết quả/lưu/mở lại, bỏ số liệu giả và truyền lịch trình thật sang bản đồ.

**Architecture:** Dùng policy ngày chung, immutable result snapshot và envelope canonical V1 hiện có. Adapter trình bày ma trận/chart/map không quyết định lại MCDA/Pareto. Catalogue snapshot được nối qua entry point; map dùng generation để tách ngữ cảnh.

**Tech Stack:** Flutter/Dart, Provider, Dio, fl_chart, flutter_map, Supabase/PostgreSQL; giữ phiên bản hiện có.

**Spec:** `docs/superpowers/specs/2026-10-24-core-planner-account-repair-design.md`, phần S1–S3 và bất biến chung.

## Global Constraints

- Form tự động 1–30 ngày; editor thủ công 1–366 ngày; calendar YYYY-MM-DD, Asia/Ho_Chi_Minh.
- Không tạo package/giá/chính sách hủy/Pareto giả; không tự dùng 4 triệu hoặc ngày hiện tại cho dữ liệu thiếu.
- Giữ canonical V1 activity bốn trường; không sửa/hủy receipt cũ, migration lịch sử hay apply SQL live.
- Snapshot theo version+sha256, không fixed 72/12; không dùng title để đoán ID hoặc fuzzy tọa độ.
- Giữ dirty work, selective diff/hunks; không push main, không commit toàn bộ file dirty có công việc khác.

## Review Focus

1. Chọn lịch rồi kéo số ngày, tháng nhuận và date range >30 không được lệch range/count — P1.
2. Save dialog đang mở trong lúc đổi input/account không được lưu nhầm context — P2.
3. Bản cũ chỉ có plan hoặc headers ngày vẫn mở được, không fabricate request — P2.
4. Bản đồ có hoạt động trùng tên/thiếu vị trí và danh mục đổi release không được định vị sai — P4/P5.
5. Route A đến muộn sau B/clear/config change không được vẽ lại — P6, kết hợp R1.

## File structure / ownership

| Task | Create | Modify |
|---|---|---|
| P1 | `lib/features/trip_planner/services/trip_date_policy.dart`, `test/planner_date_policy_test.dart` | `lib/features/trip_planner/providers/trip_provider.dart`, `lib/features/trip_planner/services/manual_trip_factory.dart`, `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`, `test/trip_provider_adaptive_test.dart`, `test/manual_trip_factory_test.dart` |
| P2 | `lib/features/trip_planner/models/planner_result_snapshot.dart`, `test/planner_result_persistence_test.dart`, `supabase/tests/planner_request_context.sql`, `tool/verify-planner-core.ps1`; migration generated với suffix `_planner_request_context.sql` | `lib/features/trip_planner/providers/trip_provider.dart`, `lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart`, `lib/features/trips/models/trip_payload_codec.dart`, `lib/features/trips/providers/saved_trips_provider.dart`, `lib/features/trips/services/legacy_trip_copy_adapter.dart`, `test/trip_payload_codec_test.dart`, `test/saved_trip_snapshot_test.dart` |
| P3 | `test/planner_result_charts_test.dart`, `test/trip_comparison_matrix_test.dart` | `lib/features/trip_planner/presentation/widgets/trip_comparison_matrix_widget.dart`, `lib/features/trip_planner/presentation/widgets/pareto_chart_widget.dart`, `lib/features/trip_planner/presentation/widgets/budget_donut_chart.dart`, `lib/features/trip_planner/presentation/widgets/itinerary_timeline_widget.dart`, `lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart` |
| P4 | `lib/features/trip_planner/presentation/screens/manual_planner_entry_screen.dart`, `test/planner_catalogue_entry_test.dart` | `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`, `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`, `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart`, `lib/features/trips/presentation/widgets/editable_draft_import_selection.dart`, `lib/features/map/services/manual_place_locations.dart`, `test/manual_day_map_test.dart` |
| P5 | `lib/features/map/models/itinerary_map_context.dart`, `lib/features/map/services/itinerary_map_builder.dart`, `lib/features/map/presentation/widgets/itinerary_map_panel.dart`, `test/itinerary_map_builder_test.dart`, `test/dashboard_itinerary_map_test.dart` | `lib/features/trip_planner/presentation/screens/dashboard_result_screen.dart`, `lib/features/map/presentation/screens/trip_map_screen.dart` |
| P6 | none | `lib/features/map/providers/map_provider.dart`, `lib/features/map/presentation/screens/trip_map_screen.dart`, `test/map_feature_test.dart`, `test/dashboard_itinerary_map_test.dart` |

Line anchors trong audit chỉ giúp tìm source; đọc lại signatures trước sửa, không áp diff mù theo số dòng.

## Task P1 — Policy ngày và form đồng bộ (L1 manual, N1)

**Interfaces:** Create `TripDateRange(startDate,endDate,numDays)` immutable. `TripDatePolicy.validate(String? startDate,String? endDate,{int? expectedDays,int maxDays=366}) -> TripDateRange?` trả null khi cả hai null, còn invalid throw FormatException. Thêm `TripProvider.setCalendarRange(String startDate,String endDate) -> void`, `setDuration(int numDays) -> void`; lỗi không thay state, được UI bắt và hiện. Factory signature hiện có giữ nguyên.

- [ ] Viết tests: `01–03/11/2026 => 3`, `setDuration(5) => end 05/11`; `28/02–01/03/2028 => 3`; một ngày =>1; range31 trên auto form bị từ chối và state cũ giữ nguyên; manual366 còn hợp lệ. `updateRequest` hợp lệ phải đồng bộ metadata; metadata/request cùng có ngày nhưng khác nhau thì factory báo lỗi.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/planner_date_policy_test.dart,test/trip_provider_adaptive_test.dart,test/manual_trip_factory_test.dart`. Assertion mất ngày phải FAIL trên baseline, không coi compile/finder error là bằng chứng bug.
- [ ] Implement policy, hai setter và metadata sync. UI picker/slider cùng giới hạn30, bắt lỗi và không clamp khoảng ngày một nửa. Manual factory dùng policy và rule ngày trong spec; restore lịch sử không tự rewrite payload. Test adaptive cũ có 4 ngày cho khoảng 20–24/11 phải sửa fixture thành5 hoặc kiểm báo mâu thuẫn, không bỏ assertion ngày.
- [ ] GREEN chạy lại đúng lệnh; thêm widget assertion cho slider không làm ngày label lệch range.
- [ ] Review diff và selective commit `fix(planner): keep date range and duration consistent`.

## Task P2 — Chụp context và roundtrip lưu đầy đủ (L1 cloud, N2)

**Interfaces:** `PlannerResultSnapshot` có `PlanTripRequest request`, `TripMetadataV1 metadata`, `PlanTripResponse plan`, `int workspaceGeneration`, getter `DestinationCard? winner` tìm đúng winnerId; tạo qua `TripProvider.captureResult() -> PlannerResultSnapshot?`, dùng deep freeze. `snapshot.toPayload({required String title}) -> CanonicalTripPayloadV1`. Dùng `TripPayloadCodec.encode` để tạo Map lưu vào `saveTrip` đang có, không đổi signature RPC. `TripProvider.isCurrentResult(PlannerResultSnapshot snapshot) -> bool` kiểm generation/identity.

- [ ] Viết tests bấm save với input `Hà Nội, Huế,01–03/11/2026,3ngày,4người,6triệu,family`: headers dates không null, budgetTotal=6000000 dù totalAllocated=5000000; decode ai_plan_data lấy đủ input/metadata/plan và isFallback. Save dialog đổi workspace/account trước confirm phải không gửi; phản hồi muộn không báo thành công cho account mới. Read/copy plan-only cũ vẫn đòi input thiếu, không lấy preset.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/planner_result_persistence_test.dart,test/trip_payload_codec_test.dart,test/saved_trip_snapshot_test.dart`.
- [ ] Implement snapshot và save dialog: capture trước mở dialog, auth epoch/owner + generation fence, double-tap lock; tên chỉnh trong dialog chỉ thay title. Header/defaulttitle/map đều dùng winner đúng ID thay vì first card; metadata công khai đã chọn chỉ dùng khi ID khớp. Nếu backend trả winner khác điểm đến user đã chọn thì hiện lỗi không khớp, không ngầm đổi điểm đến rồi lưu. Headers dùng request; dates serialize dạng calendar, không để DateTime local/UTC dịch ngày. Cập nhật `_fromRemote/_fromCached` giữ envelope và ngày từ metadata nếu headers thiếu; adapter copy nhận ngày headers qua view-local override, không sửa receipt/digest. Bỏ mọi default4000000 ở đường save/result input.
- [ ] Tạo source migration bằng `supabase migration new planner_request_context` (hoặc local `npx --yes supabase migration new planner_request_context` sau kiểm --help nếu CLI thiếu; không cài global). Chỉ một file suffix này; ghi chính xác tên sinh ra vào handover. `CREATE OR REPLACE private.validate_guest_payload_v1(text)` giữ body cũ, thêm optional request keys năm trường ở spec. Validate ID regex, name không blank khi có, calendar/range/count, companion enum solo/couple/family/group; absent vẫn chấp nhận payload cũ. Không thêm grants/public functions. SQL tests: legacy payload cũ PASS; mới dates/dynamicID/family PASS; unknown key/date sai/duplicate/null sai type FAIL; import cùng request id/digest giữ semantics cũ; A không đọc/import dữ liệu riêng B.
- [ ] Implement `tool/verify-planner-core.ps1 -Mode Sql -FlutterRoot D:/flutter/flutter` và `-DryRun/-SelfTest`: dùng mẫu isolated PostgreSQL/auth substrate của `verify-flutter-admin.ps1`, chỉ tạo server do task sở hữu dưới `.dart_tool/planner-core-verification`; không nhận DSN live. Apply baseline→privacy→guest_import→editable_v2→json_precedence_fix→migration mới đúng thứ tự, giữ test prerequisites. Runner trước hết chạy `test/planner_result_persistence_test.dart` với `--dart-define=PLANNER_EXPORT_SQL_FIXTURES=true` và `--dart-define=PLANNER_SQL_FIXTURE_DIR=<absolute-runRoot>` để xuất rawUTF8 payloadText+digest. Sau đó chạy `supabase/tests/guest_import.sql` và `planner_request_context.sql`: dùng base64/parameters chuyển payloadText, không reserialize trước hash; SQL ghi kết quả validation/import/projection vào resultJSON trong cùng runRoot. Cuối cùng runner chạy lại Dart test với `--dart-define=PLANNER_SQL_FIXTURES=true` + cùng directory để so kết quả/digest SQL. Flag consume thiếu fixture/result phải FAIL; Full thường có thể skip riêng bridgeSQL test nhưng không claim SQL PASS. SelfTest chứng minh SQL lỗi lan truyền exit khác0, cleanup finally đúng PID/dataDir; log không chứa credential/email thật.
- [ ] GREEN: chạy targeted trên + `./tool/verify-planner-core.ps1 -Mode Sql -FlutterRoot D:/flutter/flutter`, rồi targeted với `--dart-define=PLANNER_SQL_FIXTURES=true` từ runner. SQL contract roundtrip payload bytes/digest phải khớp Dart. Kiểm lại migration không đổi lịch sử/ACL.
- [ ] Selective commit `fix(trips): persist complete planner result context`.

## Task P3 — Ma trận thật, trục thích ứng, ngân sách và ngày timeline (L2,L3,L4,L7)

**Interfaces:** `TripComparisonMatrixWidget({required PlanTripResponse response, int? requestedBudgetVnd})`; `ItineraryTimelineWidget({required List<ItineraryDay> itineraryDays,String? startDate})`. Chart widgets giữ constructor public hiện có; không sửa data DTO để chữa chart.

- [ ] Tests: Huế6triệu/PhúQuốc9triệu hiển thị đúng DTO, không chứa Furama/BàNà/miễnphíhủy nếu DTO không có. Số phương án0/1/5 thật, ordinal/ranking không đổi. Pareto20h nằm trong trục, toàn0/singlepoint không chia0, invalid point có thông báo. Pie chi1,4triệu/dựphòng-400k không có section âm, vẫn báo vượt400k; zero empty; hạng chi âm báo lỗi. Timeline01/11 ngày3=03/11, không ngày hiện chưa chọn.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/planner_result_charts_test.dart,test/trip_comparison_matrix_test.dart,test/decision_engine_contract_test.dart`.
- [ ] Implement theo S2. Dashboard truyền snapshot.request.budgetVnd/startDate; dùng tab labels phù hợp dữ liệu, không “3 kịch bản” cố định. Ma trận là view, không chọn transport rồi ngầm viết lại itinerary/budget. Nếu DTO không chỉ ra transport được chọn thì không gắn “đã chọn”. Các chart nội dung dài phải scroll được trong tab, không chỉ dựa chiều cao490 để cắt mất dữ liệu.
- [ ] GREEN cùng lệnh; widget viewport360px và text scale1.5 không overflow ở header/số tiền, không mở thêm redesign ngoài phạm vi.
- [ ] Selective commit `fix(results): render supplied alternatives and truthful charts`.

## Task P4 — Nối catalogue qua mọi entry point (N3)

**Interfaces:** Extract entry widget private đang ở Home thành `ManualPlannerEntryScreen({ManualPlannerEntryIntent intent=ManualPlannerEntryIntent.edit})`, enum `.edit,.aiAssistant`. Giữ runtime/provider hiện có. `ManualPlannerScreen` nhận snapshot thực, không truyền null khi đã có public catalogue. Entry lấy provider qua DI hiện có; unit test phải inject fake provider.

- [ ] Tests từ UI entry thật: danh mụcrelease2 có place dynamic `dest-quy-nhon-123/eo-gio` tọa độ13.78/109.22; tạo→save/open→edit→map dùng đúng nơi này. Cached offline cùng snapshot còn marker; thiếu coords không marker; releaseẩnplace không đổi input/dirtydraft, hiện cảnh báo. Kiểm cả Home, saved V2, Guest draft và legacy copy.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/planner_catalogue_entry_test.dart,test/manual_day_map_test.dart,test/editable_saved_trip_ui_test.dart,test/editable_guest_import_ui_test.dart`.
- [ ] Move entry logic giữ auth/workspace generation guards; thay asset load bằng public snapshot loader hiện có. Không dùng `CatalogueRepository().load()` trực tiếp trong bốn entry trên. Consumer lấy latest snapshot khi provider đổi nhưng không sửa document; view ghi version/hash dùng cho vị trí. Validate lat/lng hữu hạn, biên[-90,90]/[-180,180], source tồn tại; reference cũ chỉ dùng khi không bị danh mục xác nhận ẩn, không làm place mới có tọa độ fallback.
- [ ] GREEN; grep tất cả `ManualPlannerScreen(` trong lib để chứng minh mỗi call site truyền snapshot/thông báo thiếu rõ ràng. Existing dynamic component tests không thay ca entry end-to-end.
- [ ] Selective commit `fix(planner): carry published catalogue through saved trip entry`.

## Task P5 — Lịch trình đầy đủ sang bản đồ (L5)

**Interfaces:** `ItineraryMapActivity` immutable: `String key`, `int dayNumber,position`, `String title,time`, `String? placeId`, `LatLng? positionOnMap`, `String resolution` (catalogueName/user/unresolved). Key stable `day:<ordinal>/activity:<index>` trong result context. `ItineraryMapContext` giữ `PlannerResultSnapshot result`, `PublicCatalogueSnapshot snapshot`, destinationId/name, optional center, list activities; snapshotVersion/hash là getters từ snapshot để panel có dữ liệu chọn địa điểm và rebuild khi release đổi. `ItineraryMapBuilder.build({required PlannerResultSnapshot result,required PublicCatalogueSnapshot snapshot,Map<String,String> userPlaceBindings=const{}}) -> ItineraryMapContext`. `TripMapScreen` thêm optional `ItineraryMapContext? itinerary`; giữ các tham số cũ cho tab standalone.

- [ ] Tests: 3ngày/5hoạtđộng đi qua cả hai nút map dashboard; các hàng/thời gian/thứ tự giữ đủ. Tên trùng ở hai nơi/khác destination không tự match. Tên unique exact trong đúng destination được map. User chọn binding có source thật được marker, binding sangIDẩn/saiđích bị từ chối. Ngày2 không lẫn điểm ngày1, <2 tọa độ không gọi route; điểm giữa thiếu thì còn hàng và tuyến nhãn chưa đầy đủ. Không thêmcenterđích cuối tuyến.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/itinerary_map_builder_test.dart,test/dashboard_itinerary_map_test.dart`.
- [ ] Implement builder thuần theo S3; panel cho chọn ngày, xem K/N, chọn liên kết tạm và đường dẫn tới editor để lưu placeId nếu cần. Truyền cùng immutable context từ cả hai map actions. Khi public release đổi, rebuild với result cũ và snapshot mới, loại binding ID không còn active, invalidate route cũ; không sửa source plan. `initialWaypoints` vẫn hỗ trợ caller cũ; itinerary mode dùng điểm đầu/cuối đã định vị và phần giữa theo ngày, không tự chèn GPS vào chuỗi tham quan. RouteWaypoint cho điểm trung gian dùng type `stop` và đúng dayNumber, tương thích reorder/filter hiện có. Thao tác GPS→destination tách riêng có nhãn; incomplete/unknown hiển thị trước khi build tuyến.
- [ ] GREEN; test không network tiles/GPS thật và adapter API phải assert chính xác thứ tự coordinates gửi đi, không chỉ assert tên màn map.
- [ ] Selective commit `fix(map): display itinerary stops with explicit location gaps`.

## Task P6 — Xóa ngữ cảnh cũ và chặn route muộn (N5)

**Interfaces:** `MapProvider.init({...existing,int? contextGeneration}) -> Future<void>`, thay semantics thành replace context. Thêm `int beginRouteContext()` (reset+increment) và `void endRouteContext(int generation)` để screen release chỉ context mình sở hữu. Screen gọi begin trước init, truyền token và giữ nó cho dispose; caller cũ không truyền token thì init tự begin một lần. Mọi async location/route callback kiểm token. `clearRoute()` làm tăng generation và xóa geometry/selection; không begin thêm lần nữa khi đã truyền token hợp lệ.

- [ ] Tests: initA→init(null) trả destination null/hasRoutefalse; Ađangchạy→B→Ahoànthành không đổi B; clear/dispose trong GPS/route pending không notify sau dispose; Bfailed không polylineA. Chuyển ngày tương tự; screenA dispose không clear contextB mới.
- [ ] RED: `./tool/verify-travelgo.ps1 -Mode Targeted -FlutterRoot D:/flutter/flutter -TestPath test/map_feature_test.dart,test/dashboard_itinerary_map_test.dart`.
- [ ] Implement clear trước await GPS, token guards cả finally/error. Giữ existing locate-only/Radar tests; không tự kết nối phòng demo hoặc phát vị trí để kiểm route.
- [ ] GREEN cùng lệnh. Kết hợp test R1 đổi host khi route A đang chạy trước review cuối.
- [ ] Selective commit `fix(map): fence route state to its active trip context`.

## Exit criteria

P1–P6 GREEN và evidence đầy đủ không tự đóng live rollout. Tiếp tục kế hoạch UI/AI và tài khoản; dùng master handoff cho kiểm tra cuối toàn phạm vi.
