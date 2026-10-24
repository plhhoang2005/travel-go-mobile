# Discovery72 — checkpoint triển khai 20/10/2026

**PARTIAL — đã triển khai code, chưa hoàn tất dữ liệu72.** Owner đã duyệt “hãy bỏ qua thời gian tiến hành code theo plan”. Bỏ lịch giao, giữ yêu cầu nguồn/kiểm thử/quyền publish và Budget Guard. Repo `D:/Travel-Go-Android/travel-go`, branch `codex/phase-3-discovery-design`, HEAD nền `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`; toàn bộ thay đổi mới chưa commit. Working tree có nhiều thay đổi owner từ trước, không reset/stash/clean/stage/push.

## Changed

| Thành phần | Files và vai trò |
| --- | --- |
| Domain | `lib/features/explore/models/place_visit_details.dart`, `test/place_visit_details_model_test.dart`: immutable schema, exact IDs/hash, source riêng từng field, vé gói/đối tượng, mùa/qua đêm/cutoff, bounded safe errors. |
| Seed | `assets/catalogue/place_visit_details_v1.json`, asset registration trong `pubspec.yaml`, `test/place_visit_details_asset_test.dart`: đúng72 IDs/12 destinations;16 hồ sơ reviewed cả giá/giờ,4 chỉ có giá,1 chỉ có giờ,51 thiếu cả hai. Không thêm dependency/SDK/native permission. |
| Cache | `lib/features/explore/services/place_visit_cache.dart`, `test/place_visit_cache_test.dart`: SQLite public riêng, transaction/version guards, đọc lại raw UTF8/hash/schema, chờ IO khi close. |
| Download | `lib/features/explore/services/place_visit_details_repository.dart`, repository test: GET staging pinned,15s/bounded streaming, validate manifest→bytes→hash/schema/evidence→commit cache→publish snapshot; giữ bản tốt khi lỗi. |
| State | `lib/features/explore/providers/place_visit_details_provider.dart`, provider test: local-first, single flight,15 phút auto/manual refresh, dispose/late response, factory lazy. |
| UI | `lib/features/explore/presentation/widgets/place_visit_details_widget.dart`, widget test: giá/đơn vị/đối tượng, lịch/điều kiện, nguồn+ngày theo field, copy URL, stale warning;360dp/chữ2x/landscape. |
| Wiring | `lib/main.dart`, Explore/detail/Home và2 integration test files: cùng provider public ngoài Auth graph, đúng6 địa điểm theo destination, giữ tìm kiếm/lọc/Back/pending samples/planner. Constructor detail optional injection cho fixtures cũ. |
| Release | `tool/build_discovery_release.dart`, builder test, `docs/phase-3/DISCOVERY_PUBLISH_RUNBOOK.md`: local only, raw-byte hash, immutable reservation, từ chối chưa đủ nguồn, không upload. |
| Handover | Spec/implementation-plan ledger/coverage/acceptance report. Existing dirty patches không tự nhận là thay đổi của task này. |

## Why — người dùng sẽ trải nghiệm gì

Mở Khám phá → danh mục tên hiện có → đọc bản đi kèm hoặc bản đã lưu → tải update TravelGO ở nền khi staging cho phép → chỉ thay toàn bộ bản khi kiểm hợp lệ và đã lưu thành công. Mỗi trang lấy đúng6 place IDs. Mạng lỗi không mất bản cũ, đăng xuất không xóa public cache. App không scrape website, không tự đưa vé vào ngân sách hoặc thay thuật toán lập chuyến.

Ví dụ Hạ Long: Sửng Sốt và Mê Cung dùng chung phí tuyến250k, không cộng thành500k cho hai hang. Mùa của cảng bắt đầu01/4 còn mùa tại hang16/4; hồ sơ giữ hai phạm vi riêng. Ví dụ Huế: mùa đông ngừng bán vé17:00, đóng cửa18:00, không ghi17:00 là hết giờ tham quan. Kinh thành hiển thị rõ phần có vé là Đại Nội. Tất cả claims có scope/đối tượng/ngày kiểm và nguồn; không gọi dữ liệu tải hôm nay là nguồn vừa cập nhật hôm nay.

Lớp visit-data riêng giữ nguyên catalogue legacy vốn chủ đích để giá/giờ null. SHA catalogue vẫn `C14CECC97149A3ACF64F439D44662333BBB8756BD580E18F368AC053BDD1542A`; AuthProvider và account lifecycle hashes bằng preflight. Không sửa private schema/lifecycle, decision engine, trip DTO hoặc nguồn cũ.

## Testing — evidence thực tế

- Mỗi gói code có RED trước implementation và GREEN sau; chi tiết log paths trong execution ledger của plan.12 domain,6 cache,26 repository,7 provider,8 widget,6 builder tests; integration giữ các assertion cũ. Một sửa lint ngoặc WP1, một sửa cleanup semantics của test WP6, một sửa import URI đồng nhất trong builder WP8; không nới assertions.
- Full R1: analyzer sạch24.1s;836PASS/2FAIL trong838 Flutter tests. Hai lỗi: `editable_guest_import_ui_test.dart:311` lost-local-ack assertion và `editable_saved_trip_ui_test.dart` pumpAndSettle timeout. Node chưa chạy vì helper dừng. Không sửa hai file này. Chạy riêng cả hai:20PASS, `.dart_tool/travelgo-verification/20261020T105041292Z-11056/`.
- Full R2: analyzer sạch3.8s; **839 Flutter PASS,89 Node PASS/fail0**, exit0. `.dart_tool/travelgo-verification/20261020T105443941Z-28768/`, wrapper `.dart_tool/discovery-full-r2-20261020.log`. Snapshot lúc này8 reviewed. Nondeterminism của R1 vẫn là giới hạn cần nhớ, không tuyên bố đã sửa một lỗi cũ.
- Huế update tiếp theo: **18 asset+domain PASS**, `.dart_tool/travelgo-verification/20261020T110217269Z-14348/`, reviewed12. Full suite chưa rerun sau thay đổi dữ liệu/test Huế; code app không đổi sau Full R2.
- Real builder dry-run: `Release refused: incomplete`, exit1 mong đợi; không có packet thật được tạo/upload. Source test fixtures chỉ ở temp và không dùng làm travel facts.
- DTD kết nối được nhưng0 active apps; hot reload trả không có app. ADB inventory0 devices, không install/restart/uninstall/clear. APK main staging/debug/x64 snapshot8 build thành công, không bật QA fault flags. Build này khác acceptance trên thiết bị.
- Continuation checkpoint: **35 targeted PASS**, `20261020T134628583Z-17800`, wrapper `.dart_tool/discovery-checkpoint-tests-20261020.log`; scoped test analyzer clean. Hội An update: **36 targeted PASS**, `20261020T135500596Z-22580`, wrapper `.dart_tool/discovery-hoian-green-20261020.log`; scoped analyzer clean. Full sau Hội An: analyzer sạch, **841 Flutter PASS,89 Node PASS/fail0**, toàn helper exit0, log folder `20261020T135542693Z-7776`; wrapper `.dart_tool/discovery-hoian-full-20261020.log`.

Hội An: vé chung80k/120k giữ package IDs dùng lại, không cộng tại từng di tích. Bảo tàng dùng gói120k rõ quyền lợi. Tấn Ký hai buổi có nghỉ trưa theo bài được cổng Hội An đăng lại; dataset công khai nguồn Traveloka và không có ngày hiệu lực. Phố cổ/Chùa Cầu còn thiếu giờ, hai biển còn thiếu cả hai.

- APK Hội An snapshot14 reviewed cả hai trường/16 giá: main staging/debug/android-x64 build PASS, SHA `5332D97D8D911ABD296073F966B511852AEFECC6E9CE9F6323BBFC5729604B51`, log `.dart_tool/discovery-build-hoian-main-x64-20261020.log`. Asset SHA `21F3F23EDA726C9F2258EC222DEFA241C1D4ADB4AA3EDC904BC4064E9DC9E0EC`. Không install, không đổi server. Đây là build mới thay artifact snapshot8; lịch sử hash cũ vẫn giữ ở ledger. Native acceptance vẫn NOT RUN.

## Problems — phần chưa hoàn tất và guard

- Đà Nẵng current: hai hồ sơ đầy đủ thêm, hai chỉ thêm giá, một chỉ thêm giờ, một còn cả hai gap. Mỹ Khê không bypass lỗi chứng chỉ nguồn quản lý; Linh Ứng không chọn bừa giữa hai giờ khác nhau. Giá miễn của Sơn Trà/Linh Ứng có nguồn2023 và ghi rõ niên đại, không giả thông báo mới2026. Chợ Hàn giữ nhãn giờ tham khảo và thiếu bằng chứng phí.
- Đà Nẵng verification:38 targeted PASS `20261020T141214318Z-29452`, analyzer scoped clean; Full current snapshot: analyzer sạch, **843 Flutter PASS,89 Node PASS/fail0**, toàn helper exit0, log folder `20261020T141251289Z-16568`, wrapper `.dart_tool/discovery-danang-full-20261020.log`. APK snapshot14 ở phần trước là artifact cũ. Gói này chỉ sửa dataset/test/coverage/plan/report, không đổi code app, Auth, quyết định chuyến, native config hoặc ghi server.

- **Source coverage giá20/72,giờ17/72,both16/72** theo scope đã ghi;56 chưa đủ cả hai:4 Hà Nội,2 Huế,4 Hội An,4 Đà Nẵng,42 thuộc7 destination khác. [Coverage đầy đủ](DISCOVERY_VISIT_DETAILS_72_COVERAGE_20261020.md) giữ từng stable ID và gap. Không gọi72 ô có dữ liệu “chưa xác minh” là hoàn tất chức năng.
- Huế: cổng web trích xuất rỗng và PDF timeout đã được khắc phục cho bốn di tích qua browser; Chợ Đông Ba/Thiên Mụ vẫn thiếu bằng chứng đủ cho mọi field. Không lấy lịch sử/giá hàng hóa thành phí vào cửa, không suy miễn phí/24h.
- Gói nghiên cứu Huế đã lưu checkpoint tại guard25 outer calls/5 authored files. Owner sau đó chỉ thị “tiếp tục công việc sau khi hết token”: tiếp tục từ checkpoint, không lập plan lại; giữ các gói tiếp theo nhỏ và không reset repair budget cũ. Chỉ thị tiếp tục không cấp quyền publish live một payload chưa duyệt.
- Packet Hội An dừng tại Budget Guard:25 outer tool calls/5 authored files (dataset,assettest,coverage,plan,acceptance),0 repair rounds. Giữ checkpoint chờ owner tiếp tục theo `.agent/workflow.md` mục3.2; không mở packet mới để vượt guard.
- Server: chưa tạo bucket, upload, replace latest hoặc kiểm ACL/quota/headers live. Release chưa complete nên chưa có exact packet để xin publish. Staging public-read/admin-write; production chưa bật remote.
- Native: không có thiết bị; chưa nghiệm thu cùngAPK V1→V2, offline process restart hoặc12 destination trên emulator/phone. Không tuyên bố whole P3.2/production accepted.
- Code review độc lập chưa chạy, không tự spawn subagent theo scope đã duyệt. Review prompt: đối chiếu domain/source rules, version/close race, hash/size limits, persist-before-visible, source tuổi và ngày tải, cùng hai call sites, tuyệt đối không thay nguồn thiếu bằng facts giả.

- APK current Đà Nẵng: main staging/debug/android-x64 build PASS, SHA `875D5DFE2CE48BEF169F4E0DDB820818816DD2F67CE806FE7F570CD9D43DF1D1`, log `.dart_tool/discovery-build-danang-main-x64-20261020.log`; source asset SHA `26BB382E435DEB1AE84B23C4642C2758E263B118D75F90420B1430EEFF7D189A`. Dataset20giá/17giờ/16both,72IDs. Không install/live publish. Native acceptance NOT RUN; danh sách thiết bị không kiểm lại trong gói data này.
- Packet Đà Nẵng kết thúc20 outer tool calls/5 authored files/0 repair rounds; chạm mốc5files trong workflow guard. Lưu checkpoint và dừng chờ owner. Next: Ninh Bình6IDs; không reset G4 hoặc mở scope crawler/admin. Không có auto-review rejection; lỗi chứng chỉ là nguồn browser, không vượt qua.

## Lesson Candidate

Nguồn tổng quan cũ hoặc giá khác gói → sai phạm vi dù có URL → ưu tiên đúng đơn vị quản lý/sản phẩm, ghi audience/unit/included và dates trước khi review. Giờ quán trong chợ/giờ tuyến trên bán đảo khác giờ toàn điểm → cùng địa danh nhưng scope khác → đối chiếu phạm vi từng field, giữ gap khi mâu thuẫn. Lần tải mới nhưng nguồn cũ → dễ tạo cảm giác “giá vừa cập nhật” → giữ `checkedAt` và `lastFetchedAt` độc lập, giữ version/hash bất biến.

Khi tiếp tục: mở plan ledger+coverage này, giữ dirty work và counters, tiếp tục nghiên cứu56 IDs chưa đủ cả hai trường; hoàn chỉnh nguồn trước release packet/publish gate. Không mở rộng crawler/admin/AI/booking, không reset budget G4 cũ hoặc tự liên hệ các bên ngoài.
