# TravelGO P3.2 — UI/UX refresh and phone fixes implementation plan

> Execution: Codex tự triển khai trong session hiện tại, không subagents. Owner yêu cầu Superpowers cho thiết kế/lập plan; **tắt Superpowers khi code**, kể cả các sub-skill mà template upstream mặc định yêu cầu. Không dùng đường dẫn `docs/superpowers/` của Owner.

**Ngày:** 2026-10-16, Asia/Saigon. **Trạng thái:** thiết kế tổng thể được Owner chốt bằng “ok hãy tiến hành”; Owner đã duyệt plan bằng “hãy tiến hành”. Đang thực thi; tiến độ tại P3_2_UX_REFRESH_PROGRESS.md. Chưa sửa xong bốn lỗi, chưa nghiệm thu bản mới.

**Goal:** Giao một bản staging đồng bộ UI/UX theo Home A + Planner B, sửa PHONE-01…04, test đầy đủ trên máy ảo trước rồi kiểm tra trọng yếu trên DNY-NX9.

**Architecture:** Giữ Flutter/Provider và luồng dữ liệu hiện tại: Guest local, Account qua lifecycle/proof/repository, mutation có receipt/version. Widget chỉ trình bày và phát command hiện có; không đổi wire V2, RPC, Decision Engine hay thuật toán tối ưu. Metadata ảnh/tọa độ tham chiếu nằm ngoài document chuyến đi, có nguồn và trạng thái thiếu dữ liệu.

**Tech stack:** Flutter/Dart trong repo, Material, Provider, Dio, fl_chart, flutter_animate, flutter_map/latlong2; không thêm dependency/font/SDK. Test bằng flutter_test hiện có, Android native probe và thao tác emulator/phone; chưa có integration_test dependency, không tự thêm.

**Spec:** 7 mục dưới đây là snapshot thiết kế đã chốt; chi tiết interview và mockup tại `C:/Users/ASUS/.codex/visualizations/2026/10/15/01a13e60-f404-7293-9fdb-748ab9a31e91/TRAVELGO_UX_REDESIGN/DESIGN_BRIEF.md` và companion `content/travelgo-directions-v2.html`. Evidence lỗi: [phone report](P3_2_DNY_NX9_PHONE_TEST_REPORT.md). Plan này không thay lịch sử acceptance cũ.

## Thiết kế đã chốt

1. Trang chủ A: ảnh điểm đến nổi bật, khám phá theo sở thích, lối vào lập chuyến rõ ràng.
2. Lập chuyến B: preview ảnh/ngày/người/ngân sách luôn nổi bật; nhập theo nhóm ngắn bằng lịch, nút tăng giảm, mức ngân sách gợi ý và lựa chọn sở thích. Có nhập số tiền chính xác.
3. Chỉnh lịch trình: timeline theo ngày; ảnh đúng hoạt động khi có nguồn; sửa/chuyển/đổi thứ tự thuận tiện. Bản đồ hỗ trợ lịch trình theo ngày, AI hỗ trợ trong ngữ cảnh.
4. Ngân sách: tổng quan trực quan, dự kiến và đã chi tách biệt, khoản chưa có giá luôn được nhận biết.
5. Toàn app: teal/cam san hô hiện có, ảnh thật, chữ rõ, chuyển động nhẹ; đồng bộ auth, Khám phá, Chuyến đi, Yêu thích, Cá nhân.
6. Giao UI/UX và bốn lỗi chung một bản để Owner test: login chậm, phục hồi phiên, dialog xóa, danh sách chuyến không cập nhật.
7. Full acceptance trên máy ảo trước; các điểm quan trọng trên DNY-NX9 sau. Hai môi trường có kết quả riêng.

## Global constraints

- Codex-only; không subagents, Docker, reset/clean, push main, tự merge/deploy.
- Mỗi task thực thi tối đa 25 tool calls, 5 file sửa/tạo (tính cả test/docs), 3 vòng sửa. Các task dưới đây là ranh giới kỹ thuật để kiểm soát thay đổi, **không phải các đợt duyệt lại thiết kế**. Tiếp tục hết gói khi đã được duyệt, trừ gate thật hoặc Budget Guard bắt buộc checkpoint/chờ Owner.
- Task hiện tại chỉ viết plan và cập nhật design brief. Trước task code mới kiểm actual Git state; giữ branch `codex/phase-3-discovery-design` nếu còn phù hợp, không giả định main đã cập nhật.
- Không đọc/sửa/stage/delete: `Huong_dan_su_dung_Map.docx`, `create_doc.py`, `create_ppt.py`, `docs/superpowers/`, `embed.py`, `presentation.html`.
- Giữ nguyên thay đổi Owner `macos/Flutter/GeneratedPluginRegistrant.swift` và untracked không thuộc task; selective staging. Không commit artifact build/credentials.
- Chỉ build STAGING `bkocylxbuyvdgxccpixx`. Không truy cập primary `oavbymauorhmrjcustzw`, apply migration/đổi schema/RLS/SDK/native config trong gói này. Nếu chẩn đoán cần đổi ngoài phạm vi, ghi bằng chứng và trình gói cụ thể.
- Không nới lifecycle/proof/epoch/subject verification, không cho session chưa xác minh xem cache Account để làm login nhanh. Không log password, token, email đầy đủ hoặc payload riêng tư.
- Bảo toàn Guest draft, import có xác nhận, lost-reply/idempotency, conflict, V1 read/copy, actual ledger và provenance. Không thêm blog/booking hoặc kích hoạt backend AI.
- Teal `#086C61`, coral `#FF7657` qua AppTheme/colorScheme; spacing bội4, radius tối đa16 trừ pill; targets >=48dp; typeTheme tiếng Việt; kiểm tương phản thực. Chuyển động định hướng 200–300ms, tắt/giảm theo accessibility.
- Không dùng ảnh địa điểm khác như ảnh thật của địa điểm hiện tại; lỗi tải ảnh có placeholder trung tính. Nguồn ảnh/giấy phép ghi rõ. Không bịa giá, rating, thời gian mở cửa, tọa độ, tuyến hoặc kết quả AI.
- Phải chạy `flutter analyze`, `flutter test` sau thay đổi source trước bàn giao. PASS cũ655 tests và SQL PASS không chứng minh UI mới PASS.

## Review focus và evidence hiện tại

| Rủi ro | Đã biết / chưa biết | Test sở hữu |
| --- | --- | --- |
| Login đợi rất lâu / cold start tự Guest | Quan sát phone ít nhất80s đợi và37s Guest; chưa đo submit→home, chưa biết root cause | T1; E01–E04 |
| Cancel/confirm đóng nhầm route | `_delete` gọi `Navigator.pop(context)` từ editor trong dialog `_route`; code là dấu hiệu, cần regression nested Navigator | T2; E08 |
| Save đã commit nhưng list0; response đến sau đổi Account | Server B có version1, UI list0; chưa biết invalidation/bind/refresh root cause | T3; E05/E09/E10 |
| Form đẹp nhưng làm mất dữ liệu/giới hạn khi sửa | Date/day resize, exact money, existing interests phải round-trip; preview không tự mutate | T6/T7; E06/E07 |
| Ảnh/bản đồ đẹp nhưng sai, UI không dùng được khi chữ lớn/offline | PlaceReference.coordinates hiện null, TripItem không có coord; form không được phụ thuộc ảnh/tile | T4/T8/T9; E11/E12 |

## Thứ tự thực thi và quy ước kiểm thử

T1–T3 xử lý lỗi; T4 tạo thành phần chung; T5–T11 áp dụng UI; T12 nghiệm thu. Đây là **một gói bàn giao**, không chuyển Phase3.3 khi P3.2 còn fail. Đọc file liên quan bằng cửa sổ <=150 dòng; re-check signatures trước khi sửa. Nếu cần file thứ6 cho một task, không lén mở rộng: ghi checkpoint/phân ranh giới có ý nghĩa, giữ task hiện tại review được.

Mỗi task source: thêm regression có ý nghĩa cho hành vi bị lỗi trước sửa; chạy test đích xác nhận tái hiện → sửa tối thiểu → chạy test đích → analyze/full tests. Thay đổi style thuần không cần test phản chiếu padding/màu. Chỉ commit file task khi verification thực PASS; không tự push/PR. Các tên test bên dưới là case mới cần bổ sung, không phải test đã tồn tại/PASS.

### T1 — Đo và sửa login/khôi phục phiên (PHONE-01,03)

**Files (5):** `lib/features/auth/providers/auth_provider.dart`, `lib/features/trips/services/local_account_lifecycle_service.dart`, `lib/main.dart`, `test/auth_navigation_test.dart`, `test/local_account_lifecycle_test.dart`.

**Interfaces:** giữ `Future<bool> AuthProvider.login(String email, String password)`, `Future<void> initialization`, `resumeAccount()`, `establishAccount({required bool freshAuthentication})` và proof/epoch hiện có. Không thay kiểu kết quả công khai nếu không có bằng chứng bắt buộc.

- [ ] Đo các chặng bằng Stopwatch/trace debug được che dữ liệu: SDK initialize, credential queue, prepare mutation, sign-in request, subject verification, SQLite/registry, consumer binding, publish, navigation. Correlation ID ngẫu nhiên không mang identity. So sánh A/B lần đầu sau cài đè code và lần tiếp theo; không uninstall/clear dữ liệu Owner.
- [ ] Đọc SDK version thực trong lockfile, source callback/binding và docs/changelog Supabase chính thức trước đổi API. Kiểm vòng chờ giữa auth.initialization và lazy binding; kiểm registry active/sealed sau force-stop so với background bình thường. Đo được chặng chậm rồi mới chọn sửa; không gán tất cả cho server.
- [ ] Thêm `login_does_not_await_noncritical_catalog_or_trip_fetch`, `cold_start_matching_account_restores_after_authorization`, `late_auth_completion_cannot_publish_after_guest_or_owner_change`, `resume_denied_session_never_exposes_account_cache`. Fake chậm giữ queue/proof kiểm được; test fail phải tái hiện đúng nguyên nhân đã tìm.
- [ ] Sửa chặng đã chứng minh: chỉ tách I/O không quyết định authorization khỏi critical path, sửa startup ordering/lifecycle transition trong mô hình hiện có nếu đó là nguyên nhân. Không bỏ subject check/cleanup để đạt tốc độ. Nếu nguyên nhân network, giữ trace phân biệt SDK với client và báo giới hạn thay vì tuyên bố đã sửa.
- [ ] Xác nhận loading phát ở frame kế tiếp, không submit trùng; navigation chỉ khi authorized. T10 bổ sung progress/error UX; không thêm timeout Promise giả rồi để request cũ âm thầm publish/retry đồng thời.
- [ ] Run `flutter test test/auth_navigation_test.dart test/local_account_lifecycle_test.dart test/auth_role_security_test.dart`; giữ các case stale callback, logout/revocation, refresh, foreground và Guest cũ.

### T2 — Dialog xóa đóng đúng route (PHONE-02)

**Execution status 2026-10-16:** source fix and seven new nested-routing regressions complete. Targeted38/full663 tests PASS; analyzer clean. Native emulator/DNY acceptance remains pending; details in P3_2_UX_REFRESH_PROGRESS.md.

**Files (3):** `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`, `test/manual_planner_screen_test.dart`, `test/manual_budget_ui_test.dart`.

**Interfaces:** giữ `_route<T>(Widget child, {bool dialog = false})` và `RemoveItemCommand(item.id)`; nếu cần builder nội bộ để nhận dialog context, đổi private helper cùng callsites trong file, giữ `_ManualStamp`/ManualFormScope.

- [ ] Thêm `nested_navigator_cancel_delete_keeps_editor_and_dirty_values` và `nested_navigator_confirm_delete_closes_only_dialog_preserves_actual`. Dựng root MaterialApp + Navigator lồng như bootstrap; kiểm dialog biến mất, editor còn mounted, unsaved notes/expense còn nguyên.
- [ ] Gắn action đóng vào context sở hữu dialog, không editor context; xử lý Back/barrier/cancel không dispatch. Confirm dispatch đúng một lần nếu stamp/proof còn hiệu lực.
- [ ] Thêm case Account đổi/revocation lúc modal mở: không mutate workspace mới, actual amount/title snapshot còn giữ sau remove đúng.
- [ ] Run `flutter test test/manual_planner_screen_test.dart test/manual_budget_ui_test.dart`.

### T3 — Save và danh sách chuyến nhất quán (PHONE-04)

**Execution status 2026-10-16:** save-to-list refresh and pull-to-refresh implemented, four regressions added. Targeted66/full667 tests PASS; analyzer clean. Original phone symptom still needs emulator/DNY retest; provider-binding causes not ruled out.

**Files (5):** `lib/features/trip_planner/presentation/widgets/manual_save_preview.dart`, `lib/features/trips/providers/saved_trips_provider.dart`, `lib/features/trips/presentation/screens/my_trips_screen.dart`, `test/editable_saved_trip_ui_test.dart`, `test/saved_trips_provider_test.dart`.

**Interfaces:** dùng kết quả `ManualPlannerProvider.confirmSave(SavePreview)` và `SavedTripsProvider.loadTrips(String? userId)`, `visibleTrips`, `currentUserId`, `sessionEpoch`; không coi refresh thất bại là mutation thất bại.

- [ ] Trace create receipt→head/cache→provider bind→list request/response→filter/render, gồm list rỗng. Thêm `acknowledged_create_appears_when_returning_to_empty_trip_list`, `empty_list_pull_refresh_dispatches_load`, `refresh_failure_does_not_repeat_committed_create`, `old_owner_refresh_cannot_replace_new_owner_list`.
- [ ] Sau save Account được xác nhận, refresh đúng owner với epoch còn hiện hành; screen vẫn đóng/thông báo lưu đúng nếu list fetch riêng bị lỗi. Đảm bảo screen chỉ có empty state cũng kéo refresh/thử lại được. Không append bản giả hoặc che mất server errors.
- [ ] Giữ nguồn mixed V1/V2, cursor/loadMore, cached/offline labels; không hardcode đổi status để chuyến xuất hiện. Nếu root cause nằm ngoài5 file đã dự kiến, checkpoint lại ranh giới trước sửa thêm.
- [ ] Run `flutter test test/editable_saved_trip_ui_test.dart test/saved_trips_provider_test.dart test/manual_planner_provider_test.dart`.

### T4 — Theme, ảnh thật và thành phần preview dùng chung

**Execution status 2026-10-16:** five-file source batch complete,12 attributed covers/2 known place subjects and shared image/preview components. Targeted5/full672 tests PASS; analyzer clean. UI integration and native visual acceptance pending.

**Files (5):** `lib/core/theme/app_theme.dart`; tạo `lib/core/presentation/travel_media.dart`, `lib/core/presentation/travel_image.dart`, `lib/features/trip_planner/presentation/widgets/trip_live_preview.dart`, `test/travel_visual_components_test.dart`.

**Interfaces mới:** `TravelMediaReference` có `imageUrl`, `sourceUrl`, `author`, `license`, `licenseUrl`; `TravelMediaCatalog.forDestination(String id)`/`forPlace(String id)` trả nullable reference; `TravelImage({required TravelMediaReference? media, required String semanticLabel, required double height})`; `TripLivePreview({required TripInput input, required int dayCount})`. Presentation metadata không đi vào wire/digest.

- [ ] Xác minh nguồn/giấy phép từng ảnh trước dùng; ưu tiên ảnh đúng12 điểm đến, activity chỉ khi matching placeId đáng tin. Có attribution nhìn được từ ảnh/chi tiết. Không coi ảnh service generic hiện có là ảnh đúng catalogue. Dùng URL đã xác minh, không thêm asset/dependency/pubspec trong gói.
- [ ] Giữ teal/coral, chuẩn hóa text/input/button/surface/navigation tokens hiện có; reuse palette, không sinh design system cạnh tranh. Preview ảnh + ngày/người/tổng và per-person, dùng số tiền input thật; không tạo lịch hoạt động tự động.
- [ ] Test ảnh pending/error/missing vẫn có semantic label và controls dùng được, attribution truy cập được; preview đổi người/ngày/ngân sách đúng, input0/unknown không chia0; font scale2 không overflow.
- [ ] Run `flutter test test/travel_visual_components_test.dart` và kiểm hình thực sau áp dụng T5/T6.

### T5 — Home A và Khám phá

**Execution 2026-10-17:** source/analyzer674 tests/build PASS; installed T5 staging x86_64 emulator APK. Native photo loading FAIL/open; screenshot and exact evidence in P3_2_UX_REFRESH_PROGRESS.md. No full emulator acceptance.

**Files (5):** `lib/features/home/presentation/screens/main_home_screen.dart`, `lib/features/explore/presentation/screens/explore_screen.dart`, `lib/features/explore/presentation/screens/destination_detail_screen.dart`, `lib/features/explore/presentation/widgets/destination_reference_list_tile.dart`, `test/discovery_screen_test.dart`.

**Interfaces:** giữ DiscoveryProvider/catalogue IDs/routes; dùng TravelImage/TravelMediaCatalog T4. CTA vào flow hiện có, không đổi destination ngầm khi engine chưa hỗ trợ.

- [ ] Đưa ảnh điểm đến và CTA lập chuyến lên ưu tiên; nhóm sở thích/filter rõ, nội dung catalogue có nguồn. Giữ search12 destinations và selected places khi đi/về detail; tránh hero khổng lồ đẩy CTA khỏi màn hình.
- [ ] Detail có ảnh và nguồn/operational unknown đúng sự thật; mẫu chưa review không thành lịch sẵn dùng. Không đưa giá/quảng cáo/voucher giả vào trang chủ.
- [ ] Thêm `photo_home_plan_entry_keeps_selected_destination`, `discovery_filter_survives_detail_back`, `failed_image_keeps_destination_actions_accessible`; chạy `flutter test test/discovery_screen_test.dart test/discovery_planner_flow_test.dart test/manual_discovery_flow_test.dart`.

### T6 — Form lập chuyến B

**Execution 2026-10-17:** source verified, targeted36/full678 PASS, analyzer clean. Bounded5-file map adjusted to manual_trip_input_form.dart, manual_activity_form.dart (optional header), selected_destination_controls.dart, trip_live_preview.dart (narrow max-count fix), new test/trip_input_visual_test.dart. home_planner_screen.dart and existing planner test assertions unchanged. Native T6 build/acceptance pending; progress doc is the continuation checkpoint.

**Files (4):** `lib/features/trip_planner/presentation/widgets/manual_trip_input_form.dart`, `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`, `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`, `test/manual_planner_screen_test.dart`.

**Interfaces:** giữ `ManualTripInputResult`, `baseDigest`, `commands`, destination IDs và resize preview hiện có. TripLivePreview T4 nhận tentative TripInput, không dispatch khi chỉ nhập/chuyển nhóm.

- [ ] Nhóm Đi đâu/Khi nào & ai/Ngân sách & sở thích ngắn, có progress và quay lại giữ giá trị. Preview nổi bật; khi bàn phím/chữ lớn thì co thành summary vẫn thấy dữ liệu, không che trường/CTA. Lịch chọn ngày, stepper người/ngày khi chưa chọn dates, presets ngân sách là gợi ý có thể sửa exact VND, chips sở thích vẫn giữ giá trị tự nhập trước đây.
- [ ] Giữ limits codec/form hiện hành: ngày1…366, người/ngân sách/string theo validator hiện có; không thu hẹp bằng slider/preset. Khoảng ngày tính inclusive; ngày chưa biết vẫn hợp lệ theo contract. Resize/đổi destination phải preview và xử lý items ảnh hưởng trước áp dụng.
- [ ] Test `group_navigation_preserves_unsaved_values`, `calendar_updates_inclusive_days_and_live_preview`, `budget_preset_and_exact_entry_round_trip`, `custom_existing_interests_survive_chip_edit`, `resize_cancel_preserves_days_and_items`; thêm case min/max theo codec thực trước viết code.
- [ ] Run `flutter test test/manual_planner_screen_test.dart test/manual_discovery_flow_test.dart test/planner_destination_ui_test.dart`.

### T7 — Timeline và chỉnh hoạt động

**Execution 2026-10-17:** timeline/activity form source verified; targeted28/full681 PASS, analyzer clean. No manual_planner_screen.dart change required in T7. Exact-place photo coverage2/72; native T7 acceptance pending. See rolling progress evidence.

**Files (4):** `lib/features/trip_planner/presentation/widgets/manual_itinerary_timeline.dart`, `lib/features/trip_planner/presentation/widgets/manual_activity_form.dart`, `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`, `test/manual_planner_screen_test.dart`.

**Interfaces:** giữ dayId/itemId/position, các callback `onSelectDay/onEdit/onMove/onDelete`, command mutator hiện có; dùng ảnh theo placeId T4.

- [ ] Timeline rõ ngày/giờ/notes và ảnh đúng nguồn khi có; day selector dễ chuyển, empty day có CTA thêm. Action sửa/chuyển/xóa dễ thấy, reorder giữ nút Lên/Xuống có semantics; không bắt dùng drag. Không thêm auto-optimize/client scheduling.
- [ ] Form activity gọn bằng nhóm thời gian/nội dung, giữ provenance/unknown/source. Điều hướng Back, dirty state và stamp guard giữ nguyên.
- [ ] Test `reorder_and_move_update_only_selected_items`, `day_notes_and_photo_missing_keep_timeline_usable`, `editor_keeps_changes_after_cancel_and_return`; chạy `flutter test test/manual_planner_screen_test.dart test/editable_trip_mutator_test.dart` và lặp T2 regression sau đổi UI.

### T8 — Bản đồ hỗ trợ ngày và vị trí trợ giúp AI

**Execution 2026-10-17:** source verified targeted100/full688 PASS, analyzer clean; installed staging x86_64. Position coverage2/72, unknowns explicit. Native Android system Back exits activity instead of returning to editor: FAIL/open in bootstrap Navigator, handled as bounded main.dart + auth_navigation_test.dart follow-up before device acceptance. See progress report.

**Files (5):** tạo `lib/features/map/presentation/screens/manual_day_map_screen.dart`, `lib/features/map/services/manual_place_locations.dart`; sửa `lib/features/trip_planner/presentation/screens/manual_planner_screen.dart`, `lib/features/explore/presentation/screens/destination_detail_screen.dart`; tạo `test/manual_day_map_test.dart`.

**Interfaces mới:** `ManualPlaceLocation` gồm `placeId`, `LatLng position`, `sourceUrl`, `checkedAt`; `ManualPlaceLocations.forPlace(String)` nullable. `ManualDayMapScreen({required EditableTripDocumentV2 document, required String dayId, bool enableNetworkTiles = true})` chỉ đọc; không dùng MapProvider singleton để tự thay itinerary hoặc chọn route mẫu. Reuse flutter_map và lớp sovereignty hiện có.

- [ ] CTA “Bản đồ ngày này” lấy đúng items của selected dayId và thứ tự position, tra theo stable placeId; quay lại giữ editor/selected day. Xác minh tọa độ từ nguồn phù hợp trước thêm registry; không dùng tọa độ trung tâm thành phố thay cho hoạt động.
- [ ] Marker chỉ cho nơi đã có tọa độ xác minh. Hiện danh sách nơi chưa có tọa độ và lý do; 0 marker hiện trạng thái thiếu dữ liệu, không nhảy sang thành phố/default route khác. Bản đồ chưa hỗ trợ đủ mọi hoạt động phải ghi coverage trong report, không báo đầy đủ chỉ vì mở được map.
- [ ] Không gọi OSRM/optimizer để giả lịch khả thi. Nếu chỉ có markers/thứ tự thì mô tả đúng; không hiện đường đi/ETA/khoảng cách chưa có dữ liệu. Tile/network lỗi có banner và timeline vẫn dùng được; không xin quyền vị trí chỉ để xem lịch.
- [ ] Destination/editor có entry trợ giúp ngắn trong ngữ cảnh. Gói này chỉ trình bày trạng thái “AI chưa khả dụng” trung thực/giải thích dữ liệu hiện có, không gọi backend AI mới hoặc tạo kết quả giả; budget dùng cùng quy tắc ở T9. Backend AI P3.3 vẫn riêng.
- [ ] Test `day_map_never_shows_other_day_or_default_stops`, `unknown_coordinates_do_not_become_city_center`, `tile_failure_keeps_day_list_and_back`, `map_does_not_mutate_document`, `unavailable_ai_never_generates_fake_advice`; run `flutter test test/manual_day_map_test.dart test/map_feature_test.dart`.

### T9 — Ngân sách trực quan và exact input

**Execution 2026-10-17:** source verified targeted25/full690 PASS, analyzer clean; newest staging x86_64 APK6618D... built but not installed. Calculator unchanged; native budget acceptance pending.

**Files (4):** `lib/features/trip_planner/presentation/widgets/manual_budget_panel.dart`, `lib/features/trip_planner/presentation/widgets/manual_expense_form.dart`, `test/manual_budget_ui_test.dart`, `test/budget_calculator_test.dart`.

**Interfaces:** giữ `ManualBudgetPanel(planner: ..., onEditExpense: ...)`, calculator hiện có, int VND, estimate/actual kinds và snapshot association. Dùng fl_chart hiện có, không tính lại decision score.

- [ ] Tổng ngân sách, dự kiến, đã chi và phần còn lại có nhãn phân biệt; biểu đồ có giá trị chữ tương đương, không chỉ màu. Unknown prices có count/callout, không coi tổng known là chi phí đầy đủ. Nếu over budget hiển thị vượt, không clamp số thành0 rồi giấu.
- [ ] Form ít gõ hơn bằng category/date/link selectors nhưng giữ exact amount; tránh preset tự ghi số vào unknown. Activity removed: estimate ngừng tính theo contract, actual vẫn đúng amount/snapshot, unlink được giải thích. Entry AI cùng trạng thái trung thực T8.
- [ ] Test `unknown_price_is_not_zero_or_complete_total`, `estimated_and_actual_totals_are_separate`, `exact_vnd_survives_save_reopen`, `removed_activity_preserves_actual_snapshot`, `over_budget_has_explicit_amount`; run `flutter test test/manual_budget_ui_test.dart test/budget_calculator_test.dart`.

### T10 — Auth UI và phản hồi đăng nhập

**Source status2026-10-17:** auth redesign and confirmation spinner follow-up verified: full695PASS/analyzer clean3.7s. Native/real login latency/restoration and retry after Guest cancellation remain pending; see progress report. No new dependency or recovery backend.

**Preliminary bounded bootstrap follow-up:** main.dart + extended auth_navigation_test.dart fixed Material waiting style and nested system Back; targeted72/full688 PASS, analyzer clean. Native Guest map Back and dirty-editor confirmation PASS on bootstrap APK194FB... . Auth screen redesign and measured login/session issues remain pending. Details in progress report.

**Files (5):** `lib/features/auth/presentation/screens/login_screen.dart`, `lib/features/auth/presentation/screens/register_screen.dart`, `lib/features/auth/presentation/screens/forgot_password_screen.dart`, `lib/features/auth/presentation/screens/otp_verification_screen.dart`, `test/auth_navigation_test.dart`.

**Interfaces:** giữ login/register/verifyOtp hiện có, Supabase confirmation semantics và OAuth callbacks. Không đổi recovery backend chỉ vì làm đẹp form; không coi mock OTP/demo thành Account thật.

- [ ] Hình ảnh vừa đủ và form rõ, keyboard/autofill/visible labels/focus tốt, CTA không bị bàn phím che. Dùng shared theme/image; ảnh không làm auth phụ thuộc network.
- [ ] Submit có progress và status ngay frame tiếp theo; giữ tên hành động khi đang chờ, disable duplicate; chờ lâu có giải thích và Guest exit an toàn theo generation guard. Error có cách thử lại khi request trước đã kết thúc; không auto-resubmit credentials. Không đặt timeout UI giả để request cũ còn quyền publish.
- [ ] Test `login_loading_keeps_action_label_and_blocks_duplicate_submit`, `late_login_after_guest_exit_cannot_navigate_to_account`, `auth_keyboard_large_text_keeps_submit_visible`, `signup_confirmation_does_not_claim_signed_in`; run `flutter test test/auth_navigation_test.dart test/auth_role_security_test.dart`.

### T11a — Chuyến đi và điều hướng toàn app

**Source status2026-10-17:** full696PASS/analyzer clean3.9s. Stable-ID photos only; V2 list summaries without IDs retain no guessed image. Native matrix pending; see progress.

**Files (5):** `lib/features/navigation/presentation/screens/main_navigation_shell.dart`, `lib/features/trips/presentation/screens/my_trips_screen.dart`, `lib/features/trips/presentation/screens/editable_trip_detail_screen.dart`, `lib/features/trips/presentation/screens/saved_trip_snapshot_screen.dart`, `test/editable_saved_trip_ui_test.dart`.

**Interfaces:** giữ5 tab và SavedTripsProvider/EditableTripRepository. Dùng TravelImage theo destinationId, đọc metadata V1 qua adapter hiện có; không suy destination từ tiêu đề tự do.

- [ ] List/detail photo-led, metadata ngày/người/budget có thứ bậc, empty/error/loading/cached phân biệt; đúng Guest/Account. Đồng bộ theme tab/CTA, không đổi navigation architecture.
- [ ] Giữ V1 read-only/copy và V2 edit, version/conflict/cache warnings; không trang trí thành booking đã xác nhận. Lặp T3 save→list và T2 delete/cancel sau UI.
- [ ] Run `flutter test test/editable_saved_trip_ui_test.dart test/auth_navigation_test.dart test/saved_trip_snapshot_test.dart`.

### T11b — Yêu thích, Cá nhân và entry states

**Source status2026-10-17:** four new visual/identity/init cases; full700PASS/analyzer clean3.5s. Existing flutter_animate/TravelImage/theme reused, no dependency added. Native matrix pending; see progress.

**Files (5):** `lib/features/favorites/presentation/screens/favorites_screen.dart`, `lib/features/profile/presentation/screens/profile_screen.dart`, `lib/features/auth/presentation/screens/onboarding_screen.dart`, `lib/features/auth/presentation/screens/splash_screen.dart`; tạo `test/secondary_screens_visual_test.dart`.

**Interfaces:** giữ FavoritesProvider, AuthProvider, profile update allowlist và bootstrap result; không sửa providers chỉ để style.

- [ ] Đồng bộ ảnh thật/typography/layout/action states; favorites ảnh theo data có thực, profile không đổi identity bằng local label; Guest có CTA đúng luồng. Splash/onboarding không tự chọn Guest trước initialization, motion tôn trọng giảm chuyển động.
- [ ] Test `guest_and_account_secondary_actions_keep_identity_boundary`, `favorites_image_failure_preserves_actions`, `profile_large_text_and_splash_pending_are_accessible`; run `flutter test test/secondary_screens_visual_test.dart test/auth_role_security_test.dart test/auth_navigation_test.dart`.

### T12 — Nghiệm thu trọn gói, emulator trước / DNY-NX9 sau

**Partial native2026-10-17:** latest source full701PASS/analyzer clean3.6s. Staging APK EA84325D... installed emulator; Guest UI and exact actual123456/date save-reopen observed. NEW FAIL: existing Guest trip list requires manual reload after save; next fix before full acceptance. AccountA/B, full matrix and DNY NOT RUN; see progress for exact hash/evidence.

**Files (tối đa5):** tạo `docs/phase-3/P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md`; cập nhật `docs/phase-3/P3_2_ACCEPTANCE_REPORT.md`, `docs/phase-3/P3_2_DNY_NX9_PHONE_TEST_REPORT.md`, plan này. Chỉ sửa thêm `test/native/editable_trip_probe.dart` nếu cần sửa probe có bằng chứng; nếu gặp bug app mới chuyển về task sở hữu, không sửa lẫn trong task QA.

- [ ] Ghi HEAD, clean task diff, SDK, thiết bị/API/ABI, build mode và APK SHA256. Source verification: `flutter analyze`, `flutter test`, `node --test test/catalogue_readiness_test.mjs`; chỉ ghi PASS theo output mới.
- [ ] Emulator hiện có: `Pixel_8`, Android34/Android14, x86_64, RAM2048MB từ config local. Boot bằng SDK emulator, xác nhận `adb devices -l`, `getprop ro.product.cpu.abi`. Không dùng lại APK ARM64.
- [ ] Chuẩn bị file define local ngoài Git gồm `TRAVELGO_ENV=staging`, `TRAVELGO_STAGING_PUBLISHABLE_KEY` lấy từ cấu hình staging đã đăng nhập; không đọc/in password/token. Truyền đường dẫn thật cho `--dart-define-from-file`; kiểm binary/banner/host STAGING trước thao tác tài khoản.
- [ ] Build emulator: `flutter build apk --debug --target-platform android-x64 --dart-define-from-file=<local-staging-defines.json>`; cài đúng emulator serial, ghi digest. Build phone: `flutter build apk --profile --target-platform android-arm64 --dart-define-from-file=<local-staging-defines.json>`, cài đè `-r` đúng DNY để giữ app data. Placeholder phải thay đường dẫn thật trước chạy, không chạy production default.
- [ ] Full matrix E01–E12 trên emulator; dùng A/B test accounts và synthetic trips có prefix, Owner nhập credentials trực tiếp, không gửi chat/không dump EditText trên login. Hai real sessions cần emulator+phone hoặc session thứ2 độc lập; nếu chưa có thì ghi BLOCKED, không coi giả lập unit test là bằng chứng đó.
- [ ] Chạy native SQLite/sealed probe bằng target `test/native/editable_trip_probe.dart` hai lần, dùng thư mục synthetic của probe. Probe là target riêng: ghi build/hash và phục hồi đúng staging app sau probe; không clear/uninstall dữ liệu Owner.
- [ ] Chỉ sau full emulator matrix không còn critical fail mới nghiệm thu cột DNY dưới đây. Phép đo mượt/khởi động dùng profile trên phone, không suy hiệu năng từ debug emulator. Full suite emulator không loại nhu cầu second-session phone nếu case yêu cầu hai session.
- [ ] Report riêng source/emulator/phone/SQL; lưu ảnh before/after, trace đã che dữ liệu, actual expected, PASS/FAIL/BLOCKED, issue còn mở. Không sửa lịch sử phone failure thành PASS khi chưa retest cùng case. Không tự cleanup dữ liệu Owner; synthetic cleanup chỉ đúng ID tạo trong task.

## Ma trận nghiệm thu và tiêu chí xong

| ID | Máy ảo — đầy đủ | DNY-NX9 — trọng yếu |
| --- | --- | --- |
| E01 | A và B login lần đầu sau cài đè, lần2; đo submit→SDK→authorized home; progress, lỗi, không submit trùng | Cả A/B login, ít nhất3 mẫu mỗi trạng thái; báo từng duration/median/max, tách network/local. Chưa kết luận nhanh nếu chỉ đẹp loading |
| E02 | Restart/force-stop/background-resume; valid/expired/revoked session; user chọn Guest; no accidental logout | Valid session force-stop mở lại và background-resume, không chạm clear/uninstall; quan sát đến auth kết thúc |
| E03 | A→logout→B, late callbacks, cached detail/list không lộ A; Guest drafts giữ riêng | A→B và vào lại Chuyến đi/chi tiết; kiểm không còn A |
| E04 | Offline auth/resume/timeout/error hiển thị đúng, không cache Account khi chưa được phép | Mất/kết nối mạng và resume với kênh ADB độc lập; nếu Wi-Fi TLS không tắt kênh điều khiển mù |
| E05 | Guest create/save/reopen→login không autoimport→preview/cancel/confirmimport đúng1 lần | Một Guest trip đầy đủ→import Account→mở lại; giữ bản nháp khi cancel |
| E06 | HomeA/PlannerB search/filter/destination/steps/date/people/interests/exactbudget, min/max, invalid và resize/cancel | Lập chuyến Huế từ Home/Khám phá, preview đúng và nhập không khó với bàn phím thật |
| E07 | Activity add/edit/reorder/move/daynotes/resize, selected day/back/dirty giữ đúng | Sửa/chuyển/đổi thứ tự hoạt động rồi save/reopen |
| E08 | Nested dialog cancel/confirm/Back/barrier, Account đổi lúc modal mở; estimate/actual preservation | Guest và Account cancel+confirm xóa; editor còn đúng, actual đã lưu vẫn đúng sau reopen |
| E09 | Account create/update/readback/list từ rỗng/pullrefresh/loadMore/deletecancel/delete; version đúng | Save→list thấy ngay→mở đúng bản→update→reopen→xóa đúng synthetictrip |
| E10 | Offline cached/uncached, lostreply/retry receipt, 2session conflict, V1read/copy bằng fixture được phép | Conflict bằng2session và lostreply quan trọng, V1 copy chỉ data test đã chỉ rõ; không sửa V1 Owner có sẵn |
| E11 | Ảnh đúng/source/failure, map đúng ngày/unknown/tileoffline/back, AI unavailable trung thực | Image load/scroll/mapback đúng ngày; không đổi itinerary/ngầm dùng default city |
| E12 | Tất cả màn đã đổi: width360/412dp, portrait/landscape, text scale1/1.3/2, TalkBack/focus, targets>=48dp, reducedmotion, keyboard, long Vietnamese text | Touch/focus/keyboard/largefont/TalkBack trên các flow trọng yếu, image scrolling và charts profile; ghi quan sát/frame timings |

**Hoàn tất gói khi:** source checks thực PASS; bốn PHONE issues có root cause/evidence sửa và regression PASS; E01–E12 emulator PASS (case2session có bằng chứng độc lập), cột DNY trọng yếu PASS; không mất draft/actual hay lộ Account; ảnh/tọa độ có source và coverage report; UI Owner thấy đúng HomeA/PlannerB. Bất kỳ critical fail/BLOCKED bắt buộc vẫn ghi NOT ACCEPTED, không gọi P3.2 xong. AI backend/primary rollout không phải tiêu chí ngầm của gói này.

## Self-review và handover của task lập plan

- Changed: tạo plan này; cập nhật design brief ghi Owner chốt7 mục và liên kết plan. Không đổi app/SQL/native/dependency.
- Why: một gói giao chung theo Owner; chia ranh giới kỹ thuật để giữ5 file/task, tránh đổi UI làm mất guard/dữ liệu. Đưa map/AI thiếu dữ liệu ra thành trạng thái thật thay vì mock thành công.
- Testing: kiểm file paths và API từ source, Git actual `cdf91ef`; AVD config x86_64/API34. Chưa chạy Flutter tests/analyzer hoặc boot emulator trong task tài liệu; không có PASS source/device mới.
- Problems: root cause PHONE01/03/04 chưa xác minh; PHONE02 có dấu hiệu context route nhưng cần test thật. PlaceReference chưa có coords; ảnh/tọa độ mới cần source-check trong task sở hữu. Không chấp nhận chỉ cải thiện spinner là sửa latency.
- Lesson candidate: UI preview dễ che mất thiếu dữ liệu → tách metadata ảnh/map khỏi canonical trip và giữ unknown rõ ràng; test hành vi route/receipt/owner cùng visual acceptance.
- Coverage: yêu cầu1→T4/T5,2→T6,3→T2/T7/T8,4→T9,5→T4/T10/T11a/T11b,6→T1/T2/T3,7→T12. Review focus5 dòng đều có regression và acceptance case. Chưa tạo execution branch/commit hoặc tự triển khai từ approval thiết kế.

