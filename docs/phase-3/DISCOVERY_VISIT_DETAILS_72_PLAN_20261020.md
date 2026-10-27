# Discovery — Giá vé và giờ tham quan có nguồn cho toàn bộ 72 địa điểm

> **Đã có thiết kế/kế hoạch mới bổ sung server update và persistent cache:** đọc [spec](DISCOVERY_72_REMOTE_DATA_SPEC_20261020.md) và [implementation plan mới](../superpowers/plans/2026-10-20-discovery-72-remote-catalogue.md). Tài liệu dưới đây giữ phương án bundled-data ban đầu để đối chiếu; không dùng nó thay kế hoạch mới.

Ngày20/10/2026. **Scope owner đã chọn: toàn bộ 72 địa điểm của 12 điểm đến đang có**, không giới hạn Huế hoặc1 địa điểm/tỉnh. Trạng thái: **PLAN FOR REVIEW — chưa sửa sản phẩm**. File này bổ sung cho Scope Baseline v2, không thay cam kết Generate/Modify, Guest/Email cloud hoặc bảo toàn dữ liệu.

## 1. Kết quả người dùng sẽ thấy

Ở trang chi tiết từng điểm đến, mỗi địa điểm tham quan có:

1. **Vé tham quan:** giá theo loại khách/loại vé, đơn vị tính và phần được bao gồm. Vé tuyến/gói phải ghi rõ phạm vi; phí gửi xe, thuyền, cáp treo hoặc dịch vụ tùy chọn tách riêng.
2. **Giờ tham quan:** lịch theo ngày/mùa, giờ bán vé/nhận khách cuối nếu có; không dùng giờ cấm xe, giờ lễ hoặc giờ biểu diễn làm giờ mở cửa toàn địa điểm.
3. **Nguồn cho từng nhóm thông tin:** đơn vị xuất bản, URL có thể chọn/sao chép, ngày kiểm; ngày công bố/ngày hiệu lực nếu nguồn có nêu.
4. **Lưu ý áp dụng:** khu vực tham quan, mùa, thời tiết, dịch vụ đi kèm, thay đổi/tạm đóng khi có nguồn thông báo.

“Miễn phí” chỉ khi có nguồn hỗ trợ việc không thu vé vào khu vực đó; không có thông tin giá không đồng nghĩa 0đ. Nơi ngoài trời/chợ/bãi biển không tự gán 00:00–24:00; chỉ ghi “không có giờ cố định” nếu được nguồn hỗ trợ. AI không được tự sinh những thông tin này.

Mục tiêu là **72 hồ sơ được xử lý đầy đủ và đúng ngữ nghĩa**, không phải ép mọi nơi thành một giá tiền và một cặp giờ. Nếu chưa tìm được nguồn đủ tin cậy, ghi BLOCKED/UNVERIFIED; **không tính hồ sơ đó hoàn thành để đạt72/72**.

## 2. Hiện trạng và nguyên nhân phải đổi cách lưu

- Asset hiện có 12 destinations/72 places; thông tin giá/giờ đều null.
- `PlaceReference` đang hardcode các trường operational là null/unknown.
- `CatalogueParser` yêu cầu priceVnd/openingHours/coordinates/durationMinutes phải null; điền giá trực tiếp sẽ khiến catalogue bị từ chối.
- UI hiện hiển thị cảnh báo chung tất cả chưa xác minh. Khi có dữ liệu mới, phải thay bằng trạng thái theo từng trường/địa điểm, không còn dùng cảnh báo chung gây hiểu nhầm.
- Dữ liệu tên/nguồn hiện tại còn được so sánh với source catalogue readiness và dùng bởi planner/AI. Không thay đổi contract đó hoặc sửa assertions cũ để chèn giá vào.

**Giải pháp đề nghị:** thêm một dataset thông tin tham quan riêng, ánh xạ bằng stable `placeId` hiện có. Giữ catalogue tên/nguồn và DTO trip cũ; không nối giá/giờ mới vào thuật toán AI trong gói này. Việc AI dùng dữ liệu đó để kiểm ràng buộc là scope riêng, chưa được coi FR-AI-005 hoàn thành.

## 3. Quy tắc nguồn và độ phủ

Ưu tiên nguồn đơn vị quản lý/website bán vé chính thức/cổng nhà nước; nguồn du lịch địa phương có thể bổ sung. Nguồn báo chí hoặc travel operator chỉ dùng với attribution và trạng thái tham khảo phù hợp, không giả là niêm yết của đơn vị quản lý.

Mỗi trường giá/giờ cần nguồn trực tiếp hỗ trợ nó. Bài nguồn chỉ chứng minh tên địa điểm không chứng minh giá/giờ. Search snippets là đầu mối, không đủ để ký duyệt; phải mở nội dung và kiểm phạm vi, ngày, chính sách mới hơn khi có.

- `SOURCE_FOUND`: tìm được URL liên quan, chưa kết luận giá/giờ.
- `SOURCED_SNAPSHOT`: đã đọc nội dung trực tiếp hỗ trợ trường, ghi ngày kiểm và điều kiện; chưa tích hợp app/chưa nghiệm thu.
- `REVIEWED`: đối chiếu mapping, loại vé/lịch và xung đột nguồn đã xử lý.
- `IN_APP_VERIFIED`: dữ liệu đã tích hợp, parser/tests/UI binding đã kiểm.
- `BLOCKED`: thiếu/không đọc được nguồn hoặc có xung đột; không nâng thành VERIFIED bằng phỏng đoán.

Theo dõi **hai cột riêng giá và giờ**, tối thiểu144 nhóm bằng chứng; hồ sơ có nhiều loại vé cần nhiều entries hơn. Độ phủ source/review/app/native là4 tầng khác nhau. Không gọi tạo đủ 72 rows là đã nghiên cứu72 nơi.

## 4. Nghiên cứu ban đầu thực hiện ngày 20/10

Các nguồn dưới đây đã được mở; mới là subset, không chứng minh72 nơi đã đủ:

- [F1 — Văn Miếu, thông tin cho du khách](https://vanmieu.gov.vn/vi/visitor-information): niêm yết vé phổ thông70.000đ, ưu tiên35.000đ và các nhóm miễn; giờ ban ngày 08:00–17:00. Tour đêm có lịch riêng, không tự dùng giá vé ban ngày cho tour đêm.
- [F2 — Ban quản lý vịnh Hạ Long, mức phí](https://halongbay.com.vn/p/58-muc-phi-tham-quan-vinh-ha-long): VHL1/VHL2 là phí theo tuyến250.000đ/người/lần; không phải vé lẻ cho từng hang. Bài ghi cập nhật31/03/2025; phải giữ ngày của nguồn, không đổi thành niêm yết ban hành2026.
- [F3 — Hạ Long, thời gian đón khách](https://halongbay.com.vn/p/71-thoi-gian-don-tra-khach-ve-cang-ben): lịch nhận khách theo mùa cho Sửng Sốt, Mê Cung, Thiên Cung; giờ ở từng điểm và giờ cảng là hai phạm vi khác nhau. Bài ghi06/11/2024, ngày truy cập20/10/2026.
- [F4 — Hội An, cập nhật vé16/03/2026](https://hoianworldheritage.org.vn/vi/news/Du-lich-Hoi-An/cap-nhat-ve-tham-quan-khu-pho-co-hoi-an-hanh-trinh-cham-ve-nguyen-ban-giua-long-di-san-3033.hwh): hai mức80.000đ/120.000đ theo quyền tham quan khác nhau. Không tự gán hai mức đó thành “khách Việt/khách nước ngoài”; không tự cộng lại ở mỗi di tích. Giờ khu phố đi bộ trong bài không tự thành giờ mở cửa từng nhà cổ/bảo tàng.

Không thêm Dinh Độc Lập vào danh mục: dù tìm được website có giá/giờ, nơi này không thuộc 72 IDs đã chọn. Không âm thầm thay các địa điểm khó tra bằng nơi dễ tra.

## 5. Data contract đề nghị

Dataset mới: `assets/catalogue/place_visit_details_v1.json`, version1, timezone `Asia/Ho_Chi_Minh`, keyed by72 stable IDs hiện có. Không thêm location/GPS hay đổi dataset nguồn gốc.

| Nhóm | Nội dung bắt buộc |
| --- | --- |
| Identity | `placeId`, `visitScopeLabel` để phân biệt toàn khu/phần bán vé |
| Price | `status` = `priced/free/bundled/variable/unverified`; danh sách ticket options, không chỉ1 số |
| Ticket option | label/audience, amountVnd nullable theo status, unit, included/excluded, packageOrRouteId nếu có, conditions, sourceIds |
| Hours | `status` = `scheduled/seasonal/event_based/no_fixed_hours/unverified/temporarily_closed`; các lịch và điều kiện, không mặc định24/7 |
| Evidence từng price/hours | sourceIds, checkedAt, publication/effective dates khi nguồn có; unknown date giữ null thay vì tự đặt |
| Source | id, publisher/title, HTTPS URL trực tiếp, access date; text diễn giải ngắn của dự án, không copy toàn bài/ảnh |
| Review | reviewStatus, unresolvedIssues; dữ liệu chưareview không hiển thị như chắc chắn |

Validation tối thiểu: ID phải thuộc catalogue, không duplicate; source ref phải tồn tại; tiền integer>=0 nhưng0 chỉ hợp lệ trong case miễn phí có nguồn; giờ/cửa sổ mùa có cấu trúc hợp lệ; null không thành 0; status vàvalue nhất quán; effectiveTo không trước effectiveFrom; thiếu nguồn không vào VERIFIED. Tiền/giờ không tự nạp vào estimated/actual của trip.

Giá theo gói dùng chung package ID; UI chỉ giải thích quyền bao gồm, không tự cộng thành tổng tiền chuyến đi. Mọi tính toán estimate/actual hiện tại giữ nguyên.

## 6. UI đề nghị và verification

Giữ bố cục trang detail, ảnh và nút Chuẩn bị chuyến đi. Mỗi place có một khối thông tin gọn: tên → tóm tắt vé → giờ → nguồn/ngày kiểm → điều kiện. Các loại vé/phụ phí có thể mở rộng, không card lồng card; giá/giờ chính đọc được ngay.

- Theo AppTheme/colorScheme/textTheme; spacing4/8/16/24, Android touch targets>=48dp.
- Không dùng màu làm dấu phân biệt verified duy nhất; có nhãn chữ và semantics. Tiền VND đọc rõ theo locale, đơn vị/vé/lượt/người luôn hiện.
- 360dp, chữ2x vẫn wrap nội dung, nguồn dài chọn/sao chép được; ảnh lỗi không cản đọc giá/giờ/nút chuẩn bị.
- Loader mới lỗi: Discovery tên/nguồn cũ vẫn dùng được, khối thông tin tham quan báo unavailable/retry; không giả dữ liệu hay làm trắng cả catalogue.
- Giữ source/date của tên riêng với source/date của giá/giờ. Không thay toàn bộ nhãn thành “đã xác minh” khi chỉ một trường có nguồn.

Skill UI/UX search: Flutter Semantics/large-font guidelines phù hợp. Query UX cho disclosure không trả match phù hợp sau 1 retry; bố cục mở rộng nêu trên là đề xuất dựa trên UI hiện có, không gán là kết quả database đã xác minh. Chưa quan sát native UI mới.

## 7. Các work packet để triển khai sau duyệt

Không coi tất cả là1 task<=5 files. Mỗi packet độc lập tối đa25 calls/5 authored files/3 repair rounds; ghi actual counters, không tăng hay reset G4 cũ. Không commit/deploy tự động.

### P1 — Contract/loader, chưa thay UI

**Files tối đa5:**
1. Create `lib/features/explore/models/place_visit_details.dart`: immutable typed records + strict parser.
2. Create `lib/features/explore/services/place_visit_details_repository.dart`: load asset/in-memory future caching, retry; injected loader cho tests, không thêm package.
3. Create `assets/catalogue/place_visit_details_v1.json`:72 identities trạng thái unverified trước khi có data review; rows rỗng không tính dataDONE.
4. Modify `pubspec.yaml`: chỉ đăng ký asset mới; không đổi dependency/SDK/lockfile.
5. Create `test/place_visit_details_test.dart`: schema/evidence/status/loader fixtures.

- [ ] Viết regression reject missing source/negative money/unknown IDs/duplicate IDs/bad dates/inconsistent free-vs-price; giữ rõ test unknown không thành 0.
- [ ] Test mùa/timezone và route/package không bị parse thành vé độc lập.
- [ ] Test loader fail/retry, cached concurrent loads, immutable output; RED trước implementation, GREEN sau.
- [ ] Implement đúng files; target suite, analyzer và full regression theo helper khi source ổn định.

### P2 — Thu thập và review12 batch dữ liệu

Mỗi batch 6 places, theo thứ tự ưu tiên: Hà Nội/Huế/Hạ Long/Hội An → Đà Nẵng/Ninh Bình/Sa Pa → Nha Trang/Đà Lạt/TP.HCM → Phú Quốc/Cần Thơ. Thứ tự không giảm cam kết72.

**Files/batch<=3:** dataset mới, [coverage ledger](DISCOVERY_VISIT_DETAILS_72_COVERAGE_20261020.md), test data coverage nếu cần assertion đặc thù. Không sửa code parser để chấp nhận dữ liệu không đủ nguồn.

- [ ] Tìm nguồn cho price vàhours từng ID; mở trực tiếp, phân loại actual visit scope, loại vé, ngày/mùa, operator.
- [ ] Xử lý nguồn xung đột/cũ/tạm đóng; ghi missing/blocked, không đoán nội dung.
- [ ] Nhập dữ liệu có evidence theo contract P1; không copy descriptions/images dài.
- [ ] Review độc lập từng trường trong cùng lượt: source hỗ trợ đúng claim, không nhầm vé gói/giờ phố đi bộ/giờ lễ. Không yêu cầu dùng subagents.
- [ ] Run target parser+assetcoverage; cập nhật hai bộ đếm `reviewedPrice`/`reviewedHours`, lưu URL/date/limitations.

### P3 — UI binding và tests

**Files tối đa4:** create `lib/features/explore/presentation/widgets/place_visit_details_widget.dart`; modify `destination_detail_screen.dart`; create `test/place_visit_details_widget_test.dart`; modify `test/destination_detail_test.dart` để khẳng định cảnh báo theo trường khi có data.

- [ ] Widget nhận một place ID và visit record/loadstate; không thay state, save, AI hoặc trip payload.
- [ ] Tests: priced/free/bundled/unknown/closed/seasonal, source/date đúng từng field; 360dp/chữ2x/nooverflow; loadererror vẫn xem được tên/nguồn cũ.
- [ ] Giữ các assertions cũ về pending sample/hide days; không hạ test source hoặc unknown để cho GREEN.
- [ ] Native Huế/1 paidplace,1 route/package,1 public/market,1 unavailable; mapping tất cả72 được assettests kiểm.

### P4 — Chốt toàn bộ và bàn giao

- [ ]72 stable IDs có record; **72/72 price +72/72 hours có nguồn phù hợp hoặc trạng thái không áp dụng được nguồn xác nhận**, không missing/unverified để gắn FULL.
- [ ] Không falsely free/24h, không doublecount packages; chưa đủ điều kiện thì báo partial/blocker với exact IDs.
- [ ] `./tool/verify-travelgo.ps1 -Mode Full` exit0, formatter/diff check cho scoped files; build main đúng ABI, runtime reload/rebuild sau Dart change, UI/native checks.
- [ ] Báo scope/source/data/native riêng, source hash/APK hash, known limitations và cách cập nhật dataset khi giá/giờ thay đổi.

## 8. Ảnh hưởng lịch Chủ nhật25/10

Đây là **mở rộng scope đáng kể** từ “1 fixture + giá/giờunknown” thành “72 hồ sơ có sourcedata”. Ước lượng cũ cho demo gọn không còn đủ để cam kết phạm vi mới.

Ước lượng sơ bộ cần hiệu chỉnh sau 1 batch 6 nơi: nghiên cứu/review trung bình10–20phút/nơi =12–24h; contract/UI/tests5–8h; regression/native/packaging3–5h → **20–37h tăng thêm**, có thể giảm nhờ nguồn dùngchung hoặc tăng khi phải xác minh bên ngoài. Chưa cộng các việc còn lại của Generate/Modify/save demo; không phải số giờ đã đo.

**Không hứa toàn bộ 72 hoàn tất trước Chủ nhật từ lượt này.** Giữ yêu cầu72, lấy batch đầu đo độ phủ và thời gian thật rồi cập nhật lịch. Nếu nguồn một nơi không thể xác minh, đưa exact blocker choowner quyết định; không tự bỏ nơi đó, đổi địa điểm, giả số liệu hoặc hạ định nghĩa FULL.

## 9. Quyền và bàn giao lượt lập phương án

Owner đã chọn phạm vi72. Plan/coverage là kết quả reviewable trước code; theo Stage-Gate củaAGENTS, cầnowner duyệt phươngán triển khai này trước sửa sản phẩm. Không yêu cầu chọn lại4/12/72; quyết định kế tiếp chỉ là thực thi plan và xửlý thay đổi lịch.

- **Changed:** tạo plan này và coverage ledger72 IDs; product/assets/tests/deps/native/DB chưa đổi.
- **Why:** hỗ trợ giá/giờ đúngnghĩa với nguồn riêng, giữ legacy catalogue và không tự nối vàoAI/budget.
- **Testing:** readsource/asset, directopen nguồnofficial, hashes trước/sau và kiểm 72 IDs khi ghi ledger. Không chạyFlutter analyze/test hoặc native ở lượt chỉ lập plan; sourcefindings không đồng nghĩa feature DONE.
- **Problems:** mới có subset nghiêncứu, chưa đủ 72; chưa có UI mới; source khó/giá mùa/tuyến và deadline cần reestimate.
- **Lesson Candidate:** source xác nhận tên không xác nhận giá/giờ → cần evidence từng field vàscope vé → theo dõi144 nhóm bằngchứng thay vì đếm72 hàng dữ liệu.
