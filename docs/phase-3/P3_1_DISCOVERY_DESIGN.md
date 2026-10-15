# P3.1 — Khám phá điểm đến và chuẩn bị chuyến đi

Ngày: 2026-10-15. Revision: R2. **DESIGN PROPOSED — CHỜ OWNER DUYỆT.**
Owner đã đồng ý hướng Discovery → manual planner/budget → AI trong chat.
Đó là approval hướng ưu tiên, chưa là approval bản thiết kế này hoặc code.
Codex-only; superpowers dùng cho phân tích/thiết kế, tắt khi sửa product code.

## 1. Mục tiêu và baseline

Guest hoặc người đã đăng nhập có thể tìm một trong 12 điểm đến đã chốt, xem
địa điểm/nguồn, xem ví dụ đã qua review biên tập nếu có, rồi đưa đúng lựa chọn
vào workspace planner. Không coi ví dụ là tour ba ngày hai đêm đã khả thi.
Guest lưu được bản nháp chỉ có đầu vào bằng SQLite hiện có. Không tự gọi engine,
Gemini hoặc lưu cloud khi chọn điểm đến. Không dùng số màn hình để báo Done.

Baseline main sau PR #38: `ebccb6d39d6db4cbfd568daf4edda97dd7643ea6`.
Khi inspect, checkout `c200ca8` có cùng tree với baseline, nhưng chưa ở main.
File generated macOS dirty từ trước và tài liệu riêng Owner nằm ngoài phạm vi.
Phase 2 có CI PASS và Owner manual staging 7/7 PASS; không suy ra AC mới đã đạt.

Nguồn yêu cầu: `docs/phase-1/PRD.md`, `FUNCTIONAL_REQUIREMENTS.md`, `USER_FLOWS.md`,
`ACCEPTANCE_CRITERIA.md`; giới hạn từ `docs/phase-2/catalogue/README.md`, canonical
V1 và `R06_IMPORT_CONTRACT.md`. Metadata Phase 1 là lịch sử, không xóa approval
Phase 2 đã có. Không đọc/sửa `docs/superpowers/` hoặc năm file riêng khác.

## 2. Lựa chọn kiến trúc

Chọn catalogue JSON đóng gói cùng app, đọc bằng Flutter asset loader sẵn có.
Giữ Provider và feature separation; dùng repository có loader inject được khi
test. Không thêm package, native permission, Supabase table hoặc deployment.
Các lựa chọn đã cân nhắc: publish lên Supabase cần schema/ACL/target approval;
viết cứng dữ liệu Dart làm khó truy nguồn. Asset phù hợp dữ liệu tham khảo tĩnh.

Nguồn biên tập là `docs/phase-2/catalogue/catalogue_readiness_v1.json`; bản hiện
tại vẫn là readiness chưa chỉnh dữ liệu sau Owner review. Phải có bước review
dữ liệu trước khi publish runtime, theo `P3_1_CATALOGUE_REVIEW.md`; không lấy
approval thiết kế để tự đánh dấu các lịch cũ đã khả thi.
Runtime copy dự kiến `assets/catalogue/catalogue_readiness_v1.json`; test so sánh
byte với nguồn, không chỉnh riêng hai bản. `pubspec.yaml` chỉ khai báo asset;
không thay dependencies hoặc lockfile. Asset declaration cần Owner duyệt cùng
plan sau; không được hiểu approval thiết kế là quyền cài thêm thư viện.

Discovery dùng model/repository/state riêng để không phụ thuộc việc tải hotel,
tour, voucher hoặc thời tiết. Lỗi các dịch vụ đó không làm mất catalogue.
Không refactor toàn bộ HomeCatalogProvider hoặc navigation shell trong P3.1.
Các đường Home đang mở Explore sẽ đến cùng màn Discovery mới. Nội dung quảng
bá/hotel/voucher và các card Home cũ chưa chuyển sang catalogue này giữ phạm vi
legacy; không báo tất cả các đường Home đã được chuẩn hóa.

## 3. Hợp đồng dữ liệu

Parser tạo model bất biến: Catalogue, SourceReference, DestinationReference,
PlaceReference, SampleReference và SampleDay. Giữ schemaVersion=1 của catalogue;
đây là version khác với canonical trip payload V1, không trộn hai schema.

- Chính xác 12 destination IDs: ha-noi, ha-long, sa-pa, ninh-binh, hue, da-nang,
  hoi-an, nha-trang, da-lat, ho-chi-minh, phu-quoc, can-tho.
- Bản nguồn hiện có sáu địa điểm mỗi nơi, tổng 72, một sample ba ngày mỗi nơi.
  Đây là số liệu kiểm kê, không phải yêu cầu ép mọi lịch dùng đủ sáu điểm hoặc
  hai điểm mỗi ngày. Source ID/place ID duy nhất; sample chỉ tham chiếu địa điểm
  thuộc đúng destination. Giữ stable IDs khi sửa tên hoặc thay lịch mẫu.
- Kiểm kiểu, trường bắt buộc, string không rỗng và tham chiếu. Từ chối schema
  không hỗ trợ, source thiếu, duplicate ID, sample chéo destination và marker
  xác minh sai. Không trả list rỗng thành công để che asset hỏng.
- Source URL phải HTTPS, không username/password, thuộc allowlist nguồn đã đọc
  và duyệt trong data packet. Baseline hiện chỉ vietnam.travel; không mở wildcard
  mọi domain. Nguồn operator/ban quản lý bổ sung cần source record thật, phạm vi
  claim và ngày kiểm riêng; checkedAt phải là ngày hợp lệ. URL chỉ hiển thị để tham khảo;
  P3.1 không thêm launcher/WebView hoặc mở site tự động.
- coordinates, openingHours, priceVnd, durationMinutes giữ null; operationalStatus
  unknown, routingReady=false. Không đổi null thành 0, miễn phí hoặc tọa độ giả.
- Giữ checkedAt/status/rights và cảnh báo sample. Ngày kiểm nguồn không phải ngày
  xác minh giá, giờ mở cửa hoặc khả năng đi thực tế.
- Review danh tính, hoạt động đón khách và review lịch trình là ba trạng thái
  riêng. Có thật trong vùng không đồng nghĩa đang mở cửa hoặc thuận tuyến.
  Sample chỉ có status not_feasibility_verified như bản cũ được coi là cần review
  biên tập, chưa đủ điều kiện publish lịch theo ngày. Data packet được review
  trước sẽ chọn và freeze marker cho các ví dụ biên tập có điều kiện; không
  đổi marker chỉ để bật UI hoặc coi user-report là xác minh độc lập.

Vùng là bảng ánh xạ biên tập theo ID, không phải ranh giới hành chính: Bắc gồm
Hà Nội/Hạ Long/Sa Pa/Ninh Bình; Trung gồm Huế/Đà Nẵng/Hội An/Nha Trang; Tây Nguyên
gồm Đà Lạt; Nam gồm TP.HCM/Phú Quốc/Cần Thơ. Không tự gán interest tags khi dữ
liệu chưa curated; lọc sở thích đầy đủ thuộc bước Discovery tiếp theo.

Không sao chép ảnh/đoạn mô tả của publisher. Dùng tên, liên kết nguồn và icon có
sẵn. Rights/distributionLicence giữ not_assigned; không tự tuyên bố open licence.
Thiết kế này không xác nhận quyền phát hành công khai toàn bộ dataset.

## 4. Trải nghiệm Discovery

Giữ tab Khám phá hiện tại. Danh sách hiển thị 12 tên, vùng và nhãn “Danh mục tham
khảo trong ứng dụng”, với ngày kiểm nguồn 13/10/2026. Có search tên và filter vùng
kết hợp; nút xóa tìm kiếm đưa lại kết quả đầy đủ theo filter hiện tại.
Search trim, không phân biệt hoa/thường/dấu, hỗ trợ đ/Đ và Unicode tổ hợp; tìm
substring theo tên destination. Không tự mở rộng alias không có trong dữ liệu.

Chọn card mở detail: tên/vùng, sáu địa điểm, source title/URL/ngày kiểm, các
trường thiếu ghi “Chưa xác minh”. Không hiện badge nhiệt độ mặc định hoặc price
0. Chỉ bật “Xem ví dụ tham khảo” khi sample đã qua review biên tập có ghi nguồn,
điều kiện và giới hạn; nhãn “Chưa xác minh tính khả thi”. Lịch còn cần sửa chỉ
hiện “Ví dụ đang được rà soát”, không render ngày/route sai dù có disclaimer.
Không tự chia đều ngày hoặc coi ví dụ là AI vừa tạo. P3.1 chỉ xem sample đủ điều
kiện, chưa copy thành itinerary chỉnh sửa được; không claim đủ 12 mẫu khả thi.

State rõ loading/ready/error; ready có search-empty riêng. Catalogue bundled
dùng offline bình thường, không gắn [FALLBACK] chỉ vì không có mạng. Asset hỏng
hiện lỗi với nút “Thử lại”; không âm thầm thay bằng sáu preset cũ. Loader lỗi
không phát thêm API calls, dispose không notify và load muộn không ghi đè state.

UI dùng Theme, text scale 1.5, màn rộng 360/390, nội dung cuộn, URL có thể wrap;
không dùng màu làm tín hiệu duy nhất. Không thêm tab hoặc đổi bố cục app gốc.

## 5. Chọn điểm đến và bảo toàn workspace

CTA detail: “Chuẩn bị chuyến đi”. Nó tạo workspace mới từ thông tin đầu vào hiện
tại, giữ origin/numDays/numPeople/budget/preferences/priority nếu có request;
không có request thì dùng preset hiện có như giá trị nhập ban đầu, được hiển thị
rõ để người dùng sửa. Không xem preset đó là kết quả dành cho destination.

Metadata mới dùng trường V1 sẵn có: destinationId/name lấy từ catalogue đã kiểm,
title mặc định “Chuyến đi <tên>”; startDate/endDate/timezone để null, không mang
ngày/tiêu đề tùy chỉnh của chuyến cũ sang chuyến mới. Response=null; draftId,
revision và savedDigest tách khỏi workspace cũ. Chưa sinh UUID draft hoặc ghi
SQLite cho đến khi Guest bấm lưu. Không sửa/xóa revision đã lưu trước đó.

Nếu đang có nội dung chưa lưu, hỏi “Tạo chuyến đi mới?” với “Hủy” và “Tạo mới”;
giải thích sẽ thay nội dung đang sửa và bản nháp đã lưu vẫn còn. Hủy/back không
đổi request/metadata/response/ID/digest và không navigate sang planner mới.
Workspace sạch không cần hỏi. Không tạo dialog xác nhận cloud/import ở đây.

Capture workspaceGeneration và Auth context trước khi hỏi; provider chỉ chấp
nhận hành động nếu generation còn đúng, context chưa đổi, chưa disposed và
không save/load draft đang chạy. Busy thì disable CTA, state thay đổi trong lúc
dialog mở thì báo “Nội dung hoặc phiên đã thay đổi; vui lòng chọn lại”, không
áp dụng lựa chọn cũ. API plan đang chờ bị invalidate khi tạo workspace, response
đến muộn không quay lại. Chỉ navigate sau khi provider chấp nhận thành công.

Planner hiển thị destination đã chọn. Guest dùng save/list/open/import V1 hiện
có; lưu rồi restart phải giữ ID/name và input, không tự chạy engine. Lưu lại
draft mới cập nhật revision của chính draft đó theo contract Phase 2.
Người đăng nhập xem catalogue và chuẩn bị input trong RAM được; hiển thị rõ
“Thông tin này chưa được lưu”. Không gọi SQLite Guest write hoặc cloud save ở
luồng account này; không đụng Guest checkpoint. Account persistence cho input
và saved-edit contract thuộc phần kế tiếp, không claim hoàn tất trong P3.1.

## 6. Không lập lịch sai điểm đến

PlanTripRequest Flutter/Java hiện không có destinationId; server tự chọn winner.
Do đó workspace có metadata.destinationId không được gọi submitPlan hiện tại.
Guard nằm cả provider lẫn UI, kể cả draft được mở lại; giữ các kết quả đã lưu
có thể xem, không xóa response chỉ vì đọc metadata. Guard chỉ chặn yêu cầu mới.

UI giải thích “Bạn có thể lưu thông tin chuyến đi. Chưa hỗ trợ tự lập lịch cho
điểm đến đã chọn.” Không nhắc tên packet/Phase trong sản phẩm. Không đánh tráo
destination metadata để khớp winner do API chọn.

Có hành động rõ “Để app gợi ý điểm đến”: xác nhận trước khi thay workspace dirty,
tạo workspace mới với request hiện tại và metadata destination rỗng, không sửa
draft cũ. Luồng này dùng API hiện có như trước. Account và Guest đều có đường
quay lại chế độ này; không buộc logout hoặc xóa draft để bật lại tối ưu tự động.

P3.1 không sửa backend repo, ranking, canonical V1, SQLite schema, B3 validator,
trigger import hoặc receipts. Fixed-destination generation cần contract server
và model planner được duyệt ở bước sau, không chuyển thuật toán sang Flutter.

## 7. Acceptance và bằng chứng cần có

| ID | Hành vi phải chứng minh | Cách kiểm tra sau approval implementation |
| --- | --- | --- |
| D01 | Đủ 12 ID; kiểm kê nguồn 72 place/12 candidate; runtime copy đúng bản đã review | Parser + byte comparison |
| D02 | Lỗi kiểu/schema/source/ID/sample chéo bị từ chối | Negative parser fixtures |
| D03 | Search có/không dấu, đ/Đ, tổ hợp, trim; filter kết hợp; empty/reset | State + widget |
| D04 | Detail đúng source/date; unknown không thành free/live/verified | Widget + malformed fixtures |
| D05 | Candidate chưa review không hiện lịch theo ngày; mẫu có điều kiện giữ cảnh báo; không ép 2 điểm/ngày | Publication policy + widget |
| D06 | Offline đọc bundled; asset lỗi có retry; không sáu preset che lỗi | Loader/state + widget |
| D07 | Chọn destination đúng, tạo input workspace mới, giữ request hợp lệ | Provider + widget |
| D08 | Hủy thay thế giữ nguyên cả payload/digest/ID; draft cũ còn nguyên | Provider/widget + SQLite FFI |
| D09 | Save/load pending, generation/Auth đổi, dispose và response muộn | Controlled completers + UI |
| D10 | Guest save/reopen sau restart giữ destination/input, V1/hash hợp lệ | SQLite FFI + Android acceptance |
| D11 | Account RAM không Guest write/cloud write; logout giữ Guest checkpoint | Context + storage/API spies |
| D12 | Selected destination chặn engine kể cả restore; auto mode gọi đúng | API call-count + widget |
| D13 | 360/390, text scale 1.5, URL dài/error/sample không overflow | Widget + Android |
| D14 | Phase 2 V1/import/retry/A-B/snapshot regressions vẫn PASS | Existing suites + scoped regression |

Traceability: AC-007 search, AC-008 source/unknown (phần catalogue này), AC-009
destination handoff (interest filter còn ngoài scope), AC-010 sample preview
chỉ là một phần (editable copy còn thiếu), AC-011 selected input và AC-052
breadth browsing. Không claim full AC-010/052, manual editor hoặc AI generation
chỉ từ browsing/handoff. D10 còn cần Android; FFI không thay manual acceptance.

## 8. Ranh giới kế hoạch và rollout

Sau khi Owner duyệt spec R1, lập implementation plan riêng: packet tối đa năm
file, allowlist cụ thể, thứ tự dependency, behavior tests và lệnh verify. Mục
tiêu là nhóm catalogue asset/parser, Discovery UI/state, rồi planner handoff;
đây chỉ là decomposition thiết kế, chưa freeze số packet hoặc cấp quyền code.
Không tự gom thêm sửa Home legacy, interest metadata, expense hoặc AI vào đây.

Kiểm release: analyzer/full Flutter tests; asset/parser/widget/FFI checks và
manual trên DNY-NX9 STAGING; source và CI gắn exact HEAD. Không cần live Gemini,
DB apply, native dependency hoặc production rollout để nghiệm thu phần này.

Lỗi fallback legacy Home đã phát hiện nằm ở service nuốt lỗi và Provider đánh
dấu thành công. Discovery mới tránh đường đó, nhưng Home cũ vẫn là finding có
phạm vi riêng; không tuyên bố sửa toàn app hoặc dữ liệu Home hiện tại là verified.

## 9. Handover và trạng thái review

Changed: tài liệu thiết kế này; chưa sửa product source/config/data.
Why: dùng lại dữ liệu/SQLite V1; ngăn chọn một nơi nhưng engine trả nơi khác,
đồng thời không mất draft khi đổi workspace/phiên.
Testing: read-only source/contract inspection; chưa chạy D01–D14, analyzer hoặc
Flutter tests cho tính năng chưa triển khai. Evidence Phase 2 giữ riêng.
Problems: thiếu editable sample/interest filters/fixed-destination engine và
account input persistence là giới hạn rõ của P3.1, không được báo full MVP.
Lesson Candidate: lựa chọn UI chỉ có hiệu lực khi contract/service hiểu nó;
nếu backend chưa hỗ trợ thì chặn minh bạch, không đổi dữ liệu để che mismatch.

Self-review R2: đã tách data inventory, hoạt động đón khách và lịch mẫu; giữ
ownership/generation/Phase 2 compatibility. Bước data review và marker publication
phải được freeze trong plan/data packet trước implementation. **Owner review:
PENDING. Implementation plan: NOT WRITTEN. Product implementation: NOT STARTED.**

## 10. Delta sau Owner review catalogue

Root cause: readiness đã kiểm tên/nguồn nhưng phần lớn cặp sample theo thứ tự
list, chưa có chứng cứ tuyến/điều kiện hoạt động. Disclaimer đơn lẻ không sửa được lịch
ghép sai. R2 bỏ nghĩa “ba ngày hai đêm dùng ngay”, thêm review trước publication,
và giữ riêng các claim chưa kiểm chứng. Chi tiết tại `P3_1_CATALOGUE_REVIEW.md`.

recommended_day thuộc SampleDay, không gắn cố định lên PlaceReference. Mô hình
về sau có thể bổ sung category, location, loại hoạt động, duration có đơn vị/basis,
route/zone và opening evidence có observedAt/source; không tự suy giá trị thiếu.
P3.1 không thêm schema DB chỉ vì đề xuất field. AI chỉ đề xuất; server phải kiểm
tra hoạt động được phép, thời gian và dữ liệu tuyến trước khi coi lịch khả thi.
