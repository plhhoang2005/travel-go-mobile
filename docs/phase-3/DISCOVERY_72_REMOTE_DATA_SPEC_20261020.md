# TravelGO Discovery — Thiết kế dữ liệu tham quan72 địa điểm và cập nhật từ server

Ngày20/10/2026. **DESIGN PROPOSAL — chờ owner xác nhận cùng implementation plan.** Owner yêu cầu lập plan chi tiết bằng Superpowers rồi dừng trước code. Không tạo bucket, publish, thay schema/config, cài APK hoặc gọi crawler trong lượt này.

## 1. Ý định đã thống nhất

- Hoàn thiện Khám phá cho **12 điểm đến/72 địa điểm đang có**, không chọn lại chỉ 4 hoặc 12 nơi.
- Người dùng xem giá vé, giờ tham quan, điều kiện, nguồn và ngày kiểm tra theo từng địa điểm.
- Người quản lý kiểm chứng và cập nhật dữ liệu **thủ công**. App tự tải bản dữ liệu TravelGO đã duyệt, không tự scrape72 website.
- Giữ bản gần nhất để đọc offline. Phân biệt thời điểm kiểm nguồn với thời điểm app tải dữ liệu.
- Giữ tìm kiếm/lọc/ảnh/detail/chọn điểm đến→planner hiện có; không mở booking, crawler, admin dashboard, AI operational integration hoặc tự cộng phí vào budget.

Đây là mở rộng của scope demo v2. Tài liệu [phương án trước](DISCOVERY_VISIT_DETAILS_72_PLAN_20261020.md) chỉ có bundled asset; thiết kế này bổ sung server, versioning, publish và persistent cache. [Coverage ledger72 IDs](DISCOVERY_VISIT_DETAILS_72_COVERAGE_20261020.md) vẫn là inventory chuẩn.

## 2. Hiện trạng và evidence

Repo `D:/Travel-Go-Android/travel-go`, branch `codex/phase-3-discovery-design`, HEAD `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`;42 tracked modified và76 untracked entries trước lượt tạo spec/plan. Nhiều dirty files là owner work, không reset/clean hoặc nhận là diff task.

Asset tên/nguồn có SHA256 `C14CECC97149A3ACF64F439D44662333BBB8756BD580E18F368AC053BDD1542A`,12 destinations/72 unique places. `PlaceReference` hardcode operational fields null; parser cũ từ chối giá/giờ khác null. Vì vậy giữ nguyên contract catalogue cũ, tạo lớp visit data riêng keyed by stable placeId.

Coverage hiện tại mới4 hồ sơ SOURCED_SNAPSHOT đủ hai trường theo ledger; reviewed0/72, tích hợp app0/72. Không nâng trạng thái trong lượt lập kế hoạch. Historical full suite766 Flutter/89 Node PASS và native C2/D3 là bằng chứng nền; không phải tests của tính năng mới.

## 3. Lựa chọn kiến trúc

| Hướng | Ưu/nhược | Quyết định đề nghị |
| --- | --- | --- |
| Chỉ bundled JSON | Dễ offline nhưng đổi dữ liệu cần APK mới | Chỉ dùng làm seed/fallback |
| **Supabase Storage: JSON có version + manifest** | Reuse hệ thống hiện có, public read cho dữ liệu du lịch; không cần bảng nghiệp vụ hoặc endpoint mới | **Chọn cho bản này** |
| Table/RPC/admin app hoặc crawler | Linh hoạt nhưng thêm schema, quyền sửa và vận hành | Hoãn |

Storage chỉ chứa dữ liệu tham quan công khai, không chứa itinerary riêng tư, userID, token hoặc context AI. App chỉ GET HTTPS từ đúng project; publish do owner/operator có quyền quản trị thực hiện. Public bucket không có nghĩa client được upload: theo [Storage access model](https://supabase.com/docs/guides/storage/buckets/fundamentals), đọc file public và quyền ghi là hai phạm vi khác nhau.

Không nâng plan/billing. Không dựa vào Smart CDN hoặc purge trả phí; [Smart CDN](https://supabase.com/docs/guides/storage/cdn/smart-cdn) là tính năng Pro trở lên. Dùng release path bất biến, TTL manifest ngắn và xác minh readback, không hứa đồng bộ tức thời.

## 4. Luồng dữ liệu

```text
Website nguồn → người quản lý đọc/đối chiếu → dataset được review
  → validate/build release → owner upload release mới → readback kiểm SHA/schema
  → cập nhật latest.json cuối cùng

App mở Khám phá → đọc cache đã kiểm hoặc bundled seed
  → refresh manifest ở nền → nếu version mới: download + validate + lưu atomic
  → Provider thông báo UI → người dùng thấy bản mới và ngày kiểm nguồn
```

Mở app không tự gọi website nguồn. Dữ liệu đổi trên website chỉ đến app **sau khi operator cập nhật/publish**. Refresh app không được đổi `checkedAt` của nguồn.

## 5. Data contract

### 5.1. Dataset JSON

Root: `schemaVersion=1`, `version` integer tăng dần trong 1..9007199254740991, `publishedAt` UTC ISO8601, `catalogueSha256`, `timezone=Asia/Ho_Chi_Minh`, `sources`, `packages`, `places`.

`places` phải khớp **đúng72 stable IDs**; unknown/duplicate/missing ID bị reject. `catalogueSha256` phải khớp asset được hỗ trợ. Không âm thầm thay/add địa điểm dễ tra; đổi catalogue là migration scope riêng.

| Thành phần | Nội dung |
| --- | --- |
| Source | id, title, publisher, HTTPS URL trực tiếp, publishedAt/effective dates nếu có; không tự suy ngày hiệu lực từ ngày truy cập |
| Place | placeId, visitScopeLabel, price, hours, notes; không thay trip DTO cũ |
| Price | status `priced/free/bundled/variable/unverified`, options và evidence riêng |
| Option | id/label/audience, amountVnd nullable theo status, currencyVND, unit, packageId/routeId khi có, included/excluded/conditions |
| Hours | status `scheduled/seasonal/event_based/no_fixed_hours/temporarily_closed/unverified`, rules, notes và evidence riêng |
| Schedule rule | weekdays1..7, seasonStart/End tháng-ngày khi có, effective dates, local start/end phút0..1439, endDayOffset0/1; admissionCutoff/lastReturn chỉ khi nguồn nêu |
| Evidence mỗi price/hours | sourceIds, checkedAt theo ngày Việt Nam, reviewState `unverified/reviewed`, conditions/unresolvedIssues |
| Package | stable ID, scope/benefits/conditions/source refs, dùng chung giữa các places; hiển thị phí tuyến/gói đúng phạm vi |

Giờ qua đêm phải có endDayOffset1; không suy `end<start` thành dữ liệu hợp lệ nếu không có cờ. Mùa có thể băng qua năm, ví dụ01/11–15/4; tests phải pin biên. Không tự quy giờ phố đi bộ/giờ lễ/giờ cảng thành giờ mở cửa từng điểm.

`free` phải có amount0 và nguồn xác nhận; amountnull giữ là chưa có con số, không thành0. Miễn phí có điều kiện phải ghi đúng audience. `no_fixed_hours` cũng cần nguồn; ngoài trời không mặc định24/7. `variable` phải có giải thích/source, không thay bằng một giá đoán.

Release đầy đủ đòi hỏi72/72 price và72/72 hours ở trạng thái reviewed, nguồn trực tiếp hỗ trợ claim hoặc xác nhận không áp dụng/không có lịch cố định. Missing/unverified hiển thị trung thực khi development nhưng **không đạt FULL**. Mục tiêu xử lý72 hồ sơ không cho phép giả144 nhóm evidence.

### 5.2. Manifest và host

Bucket đề nghị: `discovery-catalogue`, trên staging **bkocylxbuyvdgxccpixx**. Chưa kiểm bucket có tồn tại; chưa tạo trong task này. Production ngoài scope.

Manifest `latest.json`: `schemaVersion`, `version`, `objectPath=releases/<version>.json`, `sha256`, `byteLength`, `publishedAt`, `catalogueSha256`. Không nhận arbitrary URL hoặc path traversal.

Remote URL được derive từ `SupabaseConstants.projectUrl`, đúng HTTPS project origin và cố định bucket/prefix. Chỉ bật remote trong target staging; production dùng seed/cache cho tới rollout được duyệt. Public GET không cần gửi JWT, cookies hay service secret.

Giới hạn đề nghị: manifest<=32 KiB, dataset<=2 MiB, timeout 15s, redirect bị từ chối; checksum/hash/schema/version/body length phải khớp trước lưu. SHA256 chống nhầm/corruption, **không phải chữ ký chống người có quyền publish**; tin cậy nằm ở HTTPS và ACL quản trị.

Client không downgrade version. Cùngversion nhưnghash khác bị reject. Muốn rollback nội dung thì publish một **version mới cao hơn**, không hạ manifest để đè cache.

## 6. Cache và refresh

- SQLite database riêng `travelgo_discovery_public_v1.db`, không dùng/chỉnh schema của Guest drafts hoặc Account lifecycle. Chỉ public catalogue data, không clear theo logout.
- Bảng singleton `active_release`: version, `payload_utf8 BLOB` giữ nguyên bytes UTF-8 của release, hash, catalogueSha256, publishedAt, lastFetchedAt. Dataset phải UTF-8 hợp lệ không BOM; SHA tính trên toàn bộ bytes, gồm newline nếu có. Transaction thay row sau validate; ngay trong transaction từ chối version thấp hơn hoặc cùng version khác hash. Lỗi ghi giữ last-known-good cũ, không publish UI trạng thái “đã lưu offline”.
- Startup: chọn version cao hơn giữa seed/cache hợp lệ cùng catalogue. Cache hỏng thì seed và thông báo, không crash catalogue cũ. Remote/cache phải reviewed hoàn chỉnh; seed unverified chỉ dành development với nhãn rõ, không đạt FULL. Không tự xóa private data khi sửa public cache.
- Provider có snapshot, origin `bundled/cache/remote`, isRefreshing, error, lastFetchedAt. Snapshot cũ giữ được trong lúc refresh/error; chỉ thay toàn bộ release hợp lệ, không trộn trường của hai version.
- Chỉ một request refresh cùng lúc; response cũ/dispose không publish. Auto refresh khi mở Khám phá, tối thiểu 15 phút giữa các lần auto; explicit refresh bypass khoảng chờ nhưng không bypass validation. Không timer liên tục hoặc automation theo dõi nguồn.
- Source age hiển thị theo `checkedAt`; nếu quá30 ngày, thêm “Thông tin cần kiểm tra lại”. Đây là policy cảnh báo đề nghị, không làm dữ liệu cũ thành giá hiện hành. `lastFetchedAt` hiển thị riêng là ngày app tải.
- Offline cached/seed luôn có nhãn nguồn dữ liệu; chưa có cache/seed reviewed thì không giả đã có dữ liệu hoàn chỉnh.

## 7. Giao diện và điều hướng

Giữ12 destination cards, search có/không dấu, filter vùng, ảnh và attribution, pending sample policy, dirty-workspace confirmation và nút Chuẩn bị chuyến đi. Không đụng decision engine/manual save/auth.

Mỗi place: tên → price summary theo loại → hours summary → điều kiện có thể mở rộng → source theo trường/ngày kiểm. Thêm copy URL bằng Clipboard có sẵn; không cần package/native permission mới. Chữ2x,360dp, landscape, screen reader và source dài vẫn dùng được; lỗi ảnh không cản giá/giờ.

Trang detail hiển thị version/origin và refresh; không còn cảnh báo chung “mọi giá/giờ chưa xác minh” khi dữ liệu từng trường đã reviewed. Tọa độ/thời lượng chưa có vẫn giữ đúng trạng thái riêng. Không có nút AI giả hứa hỗ trợ; entry ngoài scope giữ nguyên nếu hoạt động trung thực, không thêm mode.

## 8. Publish thủ công và quyền

1. Sửa dataset local dựa trên nguồn, cập nhật coverage; ghi rõ source checkedAt, không tự gia hạn khi chỉ rebuild.
2. Validator requireComplete=true; build release và manifest dưới `.dart_tool/discovery-release/<version>/`, không upload tự động.
3. Sau owner duyệt đúng target/payload, operator upload immutable release vào bucket, quyền ghi chỉ quản trị. Không thêm policy cho mobile roles INSERT/UPDATE/DELETE.
4. Public readback: raw bytes/hash/schema/72 IDs đúng thì mới thay `latest.json`. Manifest TTL đề nghị 60s, release immutable TTL 31536000s; phải kiểm actual hosting/cache headers và propagation, không bảo đảm refresh trong 60s trên mọi hạ tầng.
5. Nếu upload/readback lỗi: giữ manifest cũ. Nếu release có lỗi sau publish: publish version cao hơn với nội dung đúng; ghi lịch sử, không xóa cached data của user.

Không gửi secret vào Flutter hoặc transcript; chưa định sẵn CLI credential file. Có thể publish qua Dashboard có quyền sẵn; nếu connector không hỗ trợ upload hoặc quyền thiếu thì ghi BLOCKED, không dựng endpoint giả hay tự đổi host.

## 9. Done và giới hạn

FULL gồm:72 hồ sơ reviewed; không nhầm vé/giờ; search/detail→planner giữ đúng; remoteV1→V2 cùng APK, lỗi remote giữ bản tốt; offline sau process restart đọc đúng version; app không ghi Storage; full checks và native evidence; runbook cập nhật có thể làm lại.

Không đủ nguồn ở bất kỳ ID nào phải báo exact gap. Không gọi việc hiển thị72 ô “chưa rõ” là hoàn tất. Không tuyên bố tự động cập nhật từ website, production rollout hoặc AI005 đã đạt.

Ước lượng sơ bộ cho phần mới: research/review 12–24h; model/cache/remote/provider/UI/tests 10–16h; publish/native/docs 3–5h = **25–45 giờ**. Đây là dự toán, chưa cộng các gói demo khác; đo lại sau batch đầu. Không giữ lời cam kết scope gọn kịp 25/10 khi scope đã mở rộng.

## 10. Quyền hiện tại và lựa chọn còn cần owner xác nhận

Lượt này chỉ được viết spec/implementation plan. Chờ owner xác nhận trước code đúng yêu cầu. Đề nghị Native tuần tự; không subagents mặc định. Phê duyệt code không tự bao gồm publish live: lúc publisher có payload/hash/target cụ thể mới chốt quyền tạo bucket/upload/manifest staging. Không deploy DB/EdgeFunction hoặc đổi billing.

Đề nghị owner duyệt chung: phạm vi72, Storage staging public-read/admin-write, seed+cache, freshness policy 30 ngày, kế hoạch theo packet và lịch được đánh giá lại. Không hỏi lại4/12/72 hoặc bắt owner chọn lại Provider/SQLite.

**Docs evidence:** đã đọc Storage access/SmartCDN qua Supabase docs connector. Fetch `.md` trả unsupported content-type; đã dùng [changelog lọc Storage](https://supabase.com/changelog?tags=storage) và [breaking changes](https://supabase.com/changelog?types=breaking-change) để rà index. Trước implementation kiểm lại thay đổi liên quan và HTTPS trên runtime; không suy live bucket hoặc SDK compatibility chỉ từ docs.
