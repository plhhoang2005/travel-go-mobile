# P3.2 — Lịch trình thủ công và ngân sách cho Guest/tài khoản

Ngày: 2026-10-15. Revision: R1.
**IN-CHAT DIRECTION APPROVED; WRITTEN SPEC PENDING OWNER REVIEW.**
Đây là đặc tả đề xuất để review; chưa có implementation plan P3.2, code,
migration hoặc quyền triển khai database từ tài liệu này.

## 1. Ý định đã thống nhất và trạng thái thực tế

Owner chọn A: đầy đủ Guest và tài khoản, gồm chỉnh ngày/hoạt động, estimated và
actual expenses, lưu/mở lại và phát hiện xung đột. Owner sau đó duyệt hướng tạo
hợp đồng chỉnh sửa mới, giữ V1 và tạo bản sao khi cần chỉnh chuyến V1; yêu cầu
“ok hãy tiến hành” cho bước viết spec. Không mở lại lựa chọn Guest-only.

Mục tiêu: người dùng chọn Huế trong Discovery, tự lập lịch, nhập ngân sách và
chi phí, lưu đúng nơi; khi sửa lịch không mất tiền đã ghi nhận hoặc ghi đè bản
mới hơn. Manual dùng được độc lập với Decision Engine và AI. Thành công được
đo bằng hành vi lưu/phục hồi/bảo toàn dữ liệu, không bằng số màn hình.

Baseline khảo sát: `codex/phase-3-discovery-design`,
`39ba694a5b8f22083dedfd08fa462061dc730b08`. P3.1 source là `abc98147...`,
APK staging và automated checks đã bàn giao; Owner Android acceptance còn
PENDING theo `P3_1_ACCEPTANCE_REPORT.md`. Không dùng PASS của Phase 2 thay cho
P3.1/P3.2. Main PR #38 đã merge theo bàn giao; tài liệu closeout Phase 2 còn
các đoạn lịch sử trước merge, không lấy chúng làm trạng thái mới nhất.

Actual source hiện có: `PlanTripResponse.Activity` không có item ID; canonical
V1 chỉ chứa metadata/request/plan; B3 import giữ receipt và nội dung bất biến,
remoteVersion=1. `LocalTripStore` schema version 1 chưa hỗ trợ upgrade; snapshot
và lifecycle tài khoản đang kiểm owner/session/generation và purge khi logout.
Những giới hạn này là lý do cần hợp đồng mới, không phải lỗi cần phá V1 để sửa.

Nguồn yêu cầu: Phase 1 FR-TRP-001–006, FR-ACC-005/006, FR-BUD-001–004,
UF-002/004/006/007/008; BR-007/008/009/016/019/021; P3.1 R2;
`docs/phase-2/execution/R06_IMPORT_CONTRACT.md`. Quy tắc chi tiết còn PROPOSED
ở Phase 1 được chốt cho P3.2 bằng spec này nếu Owner duyệt, không sửa lại lịch sử.

## 2. Phạm vi và lựa chọn kiến trúc

Bao gồm input trip, timeline manual, ledger dự kiến/thực chi, Guest local save,
selected Guest import mới, account create/read/edit/delete, conflict/retry,
snapshot offline và bản sao từ V1. Full account ở đây là vòng đời chuyến đi;
không tuyên bố toàn bộ module email/Google/profile đã nghiệm thu.

Không gồm gọi Gemini, tự xếp lịch, thay thuật toán MCDA/Pareto/Greedy, fixed-
destination engine, routing/weather live, phát hành mẫu pending, cộng tác nhóm,
blog, booking hoặc thanh toán. Vẫn giữ 12 điểm đến P3.1; mẫu 12/12 pending không
được copy như lịch đã dùng được. Có thể tạo hoạt động custom và tham chiếu địa
điểm catalogue; tham chiếu không chứng minh đang mở cửa hoặc thuận tuyến.

Chọn **editable document V2 + repository tương thích**, cùng domain model cho
Guest và account. Manual mutation, validation và cộng tiền là domain client;
server kiểm lại trước remote commit. Đây không phải chuyển Decision Engine
sang Flutter. Provider/Material/AppTheme và dependency hiện có được giữ.

Các hướng đã cân nhắc:

| Hướng | Lợi ích | Trade-off/kết luận |
| --- | --- | --- |
| Document V2 tách V1, dùng trips hiện tại làm anchor tài khoản | Giữ list/ownership cũ; một aggregate atomic; dễ kiểm ledger | Cần codec/store/RPC mới; chọn cho P3.2 |
| Mở V1/B3 cho sửa trực tiếp | Ít kiểu dữ liệu mới | Phá receipt/hash/version bất biến; không chọn |
| Chuẩn hóa ngay thành nhiều bảng day/item/expense | Thuận query từng mục và group về sau | Migration rộng, thêm đường lệch giữa JSON và rows; chưa cần cho MVP này |

Không tạo hệ lưu song song không nối với danh sách chuyến hiện tại. Mỗi chuyến
V2 tài khoản có một `public.trips` anchor và một private authoritative document;
không dual-write lịch V2 vào `trip_activities`, `ai_plan_data` hay V1 raw text.

## 3. Hợp đồng domain V2

Các tên dưới đây là contract thiết kế mới, chưa tồn tại trong source/API.
`schemaVersion=2` của editable envelope độc lập với SQLite database version,
local revision và remote content version. Không đưa V2 vào decoder/import V1.

| Thành phần | Dữ liệu và invariant |
| --- | --- |
| EditableTripDocumentV2 | schemaVersion; input; days; items; estimates; actualExpenses; exceptions; source |
| TripInput | title; destinationId/name; startDate/endDate; timezone; origin; travelerCount; totalBudgetVnd; interests; priority |
| TripDay | id UUID ổn định; ordinal 1..N; date nullable khi draft chưa chọn ngày; notes |
| TripItem | id UUID; dayId; position 0..n-1; title; placeId nullable; startMinute/endMinute nullable; notes; provenance |
| EstimatedExpense | id UUID; itemId nullable; category; unitAmountVnd nullable; basis; customQuantity nullable; active; description; provenance |
| ActualExpense | id UUID; itemId nullable; amountVnd bắt buộc; category; paidOn; description; sourceItemSnapshot nullable; provenance=user_provided |
| ValidationException | issueCode; affected item IDs; reason; fingerprint của dữ liệu tạo issue |
| SourceReference | kind=new/manual_v1_copy/catalogue_reference; source identity/digest khi có; không chứa token/owner authority |

Provenance có quality=user_provided/estimated/unknown, sourceRefs và observedAt
nullable; null money bắt buộc unknown. Thời điểm/source thiếu vẫn null, không
tự gán ngày hôm nay hoặc publisher. N là days.length; date range đủ phải khớp N.

UUID được sinh một lần khi tạo entity, giữ qua edit/reorder/day move/save/import.
ID trùng, item trỏ day khác document và expense trỏ item không tồn tại bị từ
chối. Actual đã unlink có itemId=null và snapshot title/ngày cũ. Đổi item không
đổi số tiền, category, paidOn hoặc mô tả khoản đã trả.

Destination chọn từ 12 ID đã duyệt; name là snapshot, không làm authority thay
ID. Catalogue thiếu trường không được lấp bằng giá/giờ/tọa độ tự nghĩ ra.
Input từ P3.1 được copy, không dùng metadata mới để đổi nghĩa response cũ.
Manual V2 không submit qua API engine hiện không nhận destinationId.

Draft có thể thiếu ngày, có ngày trống, chưa có hoạt động. Khi chưa có date range,
N lấy từ numDays đầu vào P3.1 và được người dùng sửa; không tự gán ngày hôm nay.
Chọn date range tạo đúng N=end-start+1, gắn ngày theo ordinal. Confirm account
save/import yêu cầu title/destination/origin, đủ hai ngày, travelerCount>=1,
ít nhất một day; day rỗng hợp lệ. Guest được lưu bản nháp chưa hoàn chỉnh với lỗi
được chỉ rõ. Không nhập nhằng nhãn bản nháp với chuyến đủ điều kiện lưu tài khoản.

Date là YYYY-MM-DD có thật, so sánh calendar date; timezone MVP cố định
Asia/Ho_Chi_Minh, currency VND. Giờ là số phút 0..1439 theo ngày địa phương;
nếu cả hai có thì end>start. Qua nửa đêm phải tách thành hoạt động ở hai ngày;
không suy ngày từ DateTime UTC. Giờ thiếu vẫn được lưu với nhãn chưa có giờ.

Giới hạn chung client/server: tối đa 366 ngày, 1000 items tổng cộng, 1000 entries
cho mỗi ledger, 1 MiB UTF-8/envelope và depth 32; title/origin tối đa 200 Unicode
characters, notes/description/reason tối đa 2000, interests tối đa 20 x 80.
Money nguyên 0..9007199254740991 VND; count/quantity nguyên 1..2147483647;
mọi tích/tổng cũng phải nằm trong giới hạn money. Reject fractional/exponent
integer tokens, duplicate JSON keys, invalid Unicode, nonfinite/unknown schema,
trường ngoài contract. Không clamp, truncate hoặc biến invalid thành 0.

## 4. Ngày, thứ tự và validation

Timeline hiển thị ordinal và giờ; position là thứ tự người dùng chủ động chọn.
Reorder không âm thầm sửa giờ. Giờ ngược thứ tự hoặc overlap có thông báo cụ thể;
chuyển item sang ngày khác giữ ID, giờ và expense links, tính lại issue ngày mới.

Tăng ngày giữ các day ID hiện có, thêm day trống. Đổi startDate nhưng giữ N dịch
date theo ordinal, preview ngày cũ/mới. Giảm N phải preview các day/items bị ảnh
hưởng; người dùng chọn ngày đích còn tồn tại cho từng item hoặc xóa có xác nhận.
Không cho apply resize khi item còn lơ lửng. Cancel/back không mutation.
Item bị xóa làm derived estimate inactive và actual unlink giữ snapshot, trong
cùng một mutation. Day còn lại giữ ID và được đánh ordinal lại.

Validation có severity/code/field/item/message và source nếu có:

- Lỗi schema/identity, date range, amount/count hoặc time range sai chặn confirm
  và remote save; Guest draft chỉ chấp nhận structural validity, không lưu JSON
  hỏng. Dữ liệu form sai giữ ở form cho sửa, không ghi giá trị invalid vào document.
- Overlap và known-closed chỉ được confirm sau sửa hoặc exception có lý do cho
  đúng issue fingerprint. Sửa giờ/ngày/item liên quan làm exception cũ hết hiệu
  lực; không dùng checkbox miễn trừ toàn chuyến. P3.2 catalogue hiện không có
  opening evidence, nên không tạo known-closed claim từ tên hay free text.
- Unknown giá/giờ/di chuyển/thời tiết và thiếu giờ chỉ cảnh báo; không hiển thị
  “lịch khả thi” vì không thấy overlap. Overbudget không chặn save/edit.

Server quyết định validation khi remote save, không tin client exceptions đã
duyệt hoặc cờ verified. Trong P3.2 không có publisher-evidence ingestion mới;
giá trị người nhập mang user_provided, tham khảo cũ mang estimated/unknown,
không tự nâng thành verified.

## 5. Ledger và phép tính tiền

Budget là VND toàn chuyến, >=0. Màn nhập luôn ghi đơn vị/basis; không dùng
double làm authority. Categories: transport, accommodation, food, attractions,
shopping, other; unknown category bị reject, không tự đẩy vào other.

Estimate basis và multiplier: trip_total=1; per_person=travelerCount;
per_day=N; per_person_day=travelerCount*N; custom_quantity=customQuantity nguyên
dương do người dùng nhập, có nhãn đơn vị. Custom quantity bắt buộc chỉ ở basis
này. Quantity thay đổi được preview khi sửa số người/ngày; actual không nhân lại.
Actual amount là tổng thực tế của entry, không có multiplier.

knownEstimate = tổng active(unitAmountVnd * multiplier) với amount khác null.
unknownEstimateCount = số estimate active có amount null.
actualTotal = tổng actual.amountVnd.
estimateRemaining = totalBudgetVnd - knownEstimate; nhãn “chưa gồm khoản chưa
biết giá” nếu unknown>0. actualRemaining = totalBudgetVnd - actualTotal.
Remaining có thể âm; tổng nonnegative và balance tính bằng integer có kiểm range.

Vector bắt buộc: budget=500000; estimate=100000 per_person, travelers=3;
thêm một unknown estimate; actual=250000. Kết quả: knownEstimate=300000,
estimateRemaining=200000 với unknownCount=1; actualRemaining=250000.
Không cộng estimate+actual thành đã chi; 0 người dùng nhập khác null chưa biết.

Mỗi item có tối đa một estimate derived active; sửa giá cập nhật entry đó, không
đồng thời nhân thêm bản sao. Chi phí trip-level được thêm rõ ở ledger. Không
tạo tiền đã chi từ AI, engine cost hoặc thao tác đánh dấu hoạt động hoàn tất.
Sửa/xóa actual là thao tác riêng có preview/xác nhận xóa; itinerary mutation
không được đưa thay đổi actual amount/category/paidOn vào commit.

## 6. Guest local, V1 và chuyển tài khoản

Editable store dùng SQLite hiện có với upgrade additive database version 1→2:
thêm guest_editable_drafts, editable_trip_snapshots, editable_import_journal,
editable_mutation_outbox. Không đổi byte/hash/schema/receipt hoặc rewrite rows
của guest_drafts/account_trip_snapshots/local_import_journal V1.
Upgrade chạy transaction; fail rollback, báo không mở được, không reset database.
Không hỗ trợ downgrade phá dữ liệu; app cũ không được dùng để ghi DB version mới.

Guest bấm “Lưu bản nháp”: lưu document + digest + local revision trong một
transaction; update kiểm expected local revision. Dirty chỉ hết sau commit đúng
snapshot; nếu đang ghi mà người dùng sửa tiếp, nội dung mới vẫn dirty. Storage
lỗi giữ RAM và bản disk hoàn chỉnh trước đó; chưa bấm lưu thì không hứa restart
phục hồi. Back khi dirty có Lưu/Không lưu/Ở lại, thất bại lưu không thoát.

V1 giữ viewer/save/import cũ. CTA “Tạo bản sao để chỉnh sửa” tạo document V2 mới,
ID trip/day/item mới, source digest trỏ bản V1 đã đọc. Mapping giữ title/order/
input và chỉ đọc giờ theo HH:mm hợp lệ; chuỗi khác giữ note gốc và để giờ unknown.
Cost V1 là estimate tham khảo, không actual; không tự chuyển budgetBreakdown
thành ledger vì có thể trùng activity cost. Preview cho người dùng rà giá/basis/
ngày, ghi rõ chưa đủ dữ liệu. Destination V1 không khớp 12 ID phải chọn rõ;
không map tên gần giống hoặc đổi winner ngầm. Cancel không thay bản gốc.

Guest V2 import là operation mới, không gọi import_guest_draft_v1. Login không
tự import; chỉ chọn bản nháp và preview revision cố định. Journal lưu source
scope/draftId/localRevision/digest/requestId/targetOwner; lỗi/mất ack giữ nguồn.
Server unique owner+deviceScope+draftId+sourceRevision và owner+requestId.
Retry cùng source/key/content trả cùng receipt; khác content bị reject. Revision
mới tạo trip mới chỉ khi người dùng chọn chuyển bản sửa; không tự update trip
đã nhận từ revision trước. Không coi cùng nội dung là cùng source identity.

Sau ack hợp lệ: ghi owner snapshot, receipt/journal và đánh dấu/xóa đúng source
revision trong một SQLite transaction; không mất revision mới sửa sau submit.
Không còn bản transferred editable trong vùng Guest; Guest revision mới chưa
được nhận vẫn riêng. A→B hoặc session đổi invalidate dialog/callback và chặn
ack sai owner; không chuyển retry đang pending sang B. Nếu local ack fail sau
remote commit, recovery tra receipt và chạy lại local ack, không tạo trip mới.

## 7. Account: lưu nguyên tử, version và recovery

Logical storage mới: private.editable_trip_documents chứa trip_id, content_version,
payload_text, content_digest, updated_at; FK tới trips anchor. Private
editable_trip_mutations giữ owner/request/source bindings, operation, digest,
base/result version, trip ID, committed_at và deleted tombstone, không chứa
token. Private editable_trip_write_permits giữ trip_id, backend PID, transaction
ID và allowed operation trong lúc trusted RPC đang ghi; không có app privileges,
được tạo/xóa trong cùng transaction, không tồn tại sau commit bình thường.
Không có expense document khác để ghi lệch với itinerary.

Public operation names mới, tách version với import V1:

| Operation | Input chính | Output/đảm bảo |
| --- | --- | --- |
| create_editable_trip_v2 | requestId, payloadText, contentDigest, source binding nếu import/copy | tripId, receipt version=1, head hoàn chỉnh |
| update_editable_trip_v2 | tripId, expectedVersion, requestId, typed commands, candidate payloadText/digest | version+1 và receipt nếu compare-and-commit thành công |
| get_editable_trip_v2 | tripId | owned complete document/version/digest hoặc unavailable |
| get_editable_mutation_v2 | requestId | own immutable receipt + current head riêng, hoặc deleted/not_found |
| list_owned_trips_v2 | cursor/limit | owned list tagged legacy_v1/editable_v2, authoritative version cho V2 |
| delete_editable_trip_v2 | tripId, expectedVersion, requestId | committed receipt/tombstone; retry không recreate |

Đây là RPC thiết kế, chưa deployed. Owner lấy từ auth.uid(), không từ payload.
Create/delete/update cùng transaction với anchor projections/document/receipt.
Create projection giữ dates legacy NULL như import V1 để tránh đổi calendar date
sang timestamp; UI V2 đọc ngày từ document. Title/destination/numDays/budget ở
anchor là projection được server tạo; ai_plan_data={} và canonical_payload_text
NULL cho V2. List DTO có discriminator từ join server, không suy kind từ blob rỗng.

Update nhận ordered typed commands cho phần itinerary hoặc actual. Server áp
dụng commands lên đúng base rồi so sánh candidate, không nhận arbitrary document
replacement như chứng cứ actual được sửa có chủ đích. Itinerary command giữ
actual fields, chỉ unlink đúng item đã xóa và tạo snapshot tương ứng; actual
add/edit/delete command xuất phát từ form actual riêng và không đổi lịch.
Một lần lưu có thể chứa cả hai loại command, preview liệt kê riêng các thay đổi
actual; tất cả commit cùng một version. Như vậy sửa lịch lẫn nhập tiền trước
khi bấm lưu được hỗ trợ mà không phải hai lần commit dở dang. Hai thiết bị sửa
lịch/tiền vẫn dùng cùng aggregate version nên conflict thay vì last-write-wins.

Mỗi mutation: xác thực chủ hiện tại → lookup request receipt/binding → khóa
aggregate → kiểm version và validation → ghi document/projections/version +
receipt → commit. Digest binding bao gồm exact candidate bytes và ordered commands
ở update; create gắn source binding, delete gắn trip/version. Cùng key/digest/
operation/base trả receipt cũ ngay cả current
version đã cao hơn; key binding khác reject. Version chỉ tăng đúng một lần khi
có commit; client không gửi version tương lai làm authority.

Receipt giữ kết quả của request gốc (requestId/tripId/resultVersion/digests/
committedAt/source khi có). Head trả kèm là document hiện tại với version/digest
riêng, có thể mới hơn receipt; không cần giữ mọi payload lịch sử trong receipt.
Không gắn head version mới với digest cũ. Nếu head mới hơn request đã ack,
client cập nhật cache đơn điệu nhưng giữ bản đang sửa và yêu cầu xem lại trước
edit tiếp; không tự đổi editor base. Deleted trả tombstone, head=null. Mọi
lookup/retry kiểm binding và quyền trước trả nội dung. V1-copy source là remote
thì server xác minh source trip thuộc subject và digest nguồn khớp; không đọc
nguồn của tài khoản khác dựa vào caller-supplied source ID.

Save confirmation đóng băng candidate digest + editorGeneration + baseVersion;
sửa tiếp hoặc đổi session làm confirmation hết hiệu lực. Pending payload ghi
outbox owner-scoped trước gửi; UI phân biệt “Đang lưu”, “Chưa xác nhận được kết
quả” và “Đã lưu”. Timeout: lookup cùng requestId, retry chính frozen bytes/key
khi not_found; không phát create mới. Ack cũ không xóa dirty của edit mới.

Conflict giữ RAM của người dùng và không overwrite snapshot/version server.
Có lựa chọn xem bản mới hoặc “Lưu thành chuyến mới” sau preview; chuyến mới có
IDs mới, không copy actual mặc định và không chuyển ledger khỏi bản gốc. Không auto-merge,
không tự đổi expectedVersion rồi gửi lại. Tải bản mới phải cảnh báo bỏ sửa chưa
lưu. Account editor chưa submit nằm RAM, rời app có thể mất nội dung chưa lưu;
outbox chỉ phục hồi thao tác save người dùng đã xác nhận, không là offline editor.

List/detail V1 vẫn viewer; V2 dùng service mới và tagged model, không đưa document
V2 qua SavedTrip legacy decoder. V1 copy tạo anchor V2 mới sau explicit confirm;
bản gốc và receipt V1 giữ nguyên, UI ghi “Bản sao” và liên kết nguồn nếu còn quyền.
List legacy được paginate/sort ổn định theo created_at,id; V2 mới cùng list này,
không tạo tab giấu chuyến cũ. Không suy version cho legacy chưa versioned.

## 8. Quyền, xóa và offline account

V2 private tables deny direct app access; bật RLS defense in depth. RPC trusted
SECURITY DEFINER dùng search_path rỗng, qualified names; revoke EXECUTE PUBLIC/
anon và grant đúng authenticated entrypoints, không grant private helper/table.
Kiểm non-null auth.uid và ownership mỗi operation; subject B không được lookup
receipt/document A. Không dùng user_metadata, ID do caller hay UI làm quyền.
Public RPC là ngoại lệ cần thiết để ghi private aggregate, không là cách né RLS.

Thêm guard riêng cho anchor V2: generic trips update/delete và trip_activities
write không được làm lệch document/receipt. Guard kiểm private write permit
khớp trip/backend PID/transaction ID/operation, không dùng app-settable GUC.
RPC tạo permit trước ghi anchor và xóa trước return; lỗi rollback cả permit.
Auth.users cascade chỉ được qua khi parent user đã không còn, tương tự B3;
trusted path và cascade có negative tests riêng. Không đổi B3 imported_trip_immutable
hoặc mở direct CRUD cho V1. Create V2 chỉ qua operation; tag hiển thị lấy từ
authoritative join, không tin user tự gắn marker trong legacy JSON.

Delete cần preview rõ sẽ xóa chuyến và cả ledger actual, đúng version/quyền và
explicit confirm. Xóa item/day chỉ giữ actual như mục 4; hai loại xóa không được
nhầm nhau. Tombstone ngăn replay create/update cũ khôi phục trip đã xóa. Không
thêm account deletion/TTL cleanup; receipt giữ để retry, policy retention rộng
hơn vẫn ngoài scope. Auth account cascade không bị guard V2 chặn.

Snapshot V2 lưu complete document/digest/version/fetchedAt trong namespace owner,
chỉ replace atomic khi version mới hơn; cùng version/digest khác là corruption.
Không để remote ack version thấp đè cache cao. Offline chỉ xem đã cache, có nhãn
phiên bản/thời điểm; không sửa saved trip hoặc ghi actual. Chưa cache thì unavailable.

Lifecycle hiện có được mở rộng để purge snapshot/outbox/import account data V2
vào cùng cleanup protocol khi logout/switch; lock namespace khi purge fail,
recover trước publish readiness. Guest chưa chuyển và remote data được giữ.
Session hết hạn/refresh/background thì seal và chặn operation, không chuyển
account RAM/outbox sang Guest. Chỉ current proof/handle mới đọc/ack/resume được;
response đến muộn sau purge không tái tạo cache. Không lưu raw JWT trong SQLite.
Sau logout outbox bị purge, login lại tải remote list; không tự dựng retry mới
cho request identity đã xóa. Không hứa thu hồi quyền tức thời khi hoàn toàn offline.

## 9. UI và ranh giới component

Entry từ workspace P3.1 mở manual editor với hai phần “Lịch trình”/“Ngân sách”,
giữ navigation shell. Input header nêu destination, ngày, số người và budget;
đầu vào chưa đủ có CTA hoàn thiện. Timeline theo ngày, empty day có “Thêm hoạt
động”; hoạt động mở form sửa, menu Chuyển ngày/Lên/Xuống/Xóa. Kéo chỉ là tiện
ích thêm, không là đường duy nhất. Form hủy không ghi document, có lỗi tại field.

Budget hiển thị Ngân sách/Dự kiến đã biết/Đã chi/hai balances và unknown count;
ledger tách “Dự kiến” và “Đã chi”, không biểu đồ trộn hai loại. Có preview trước
save/import và danh sách issue có thể nhảy về field/item. Không nhồi card trang
trí hoặc tạo chatbot. Dùng AppTheme thực tế teal/coral hiện có; hướng dẫn nội
bộ còn ví dụ màu cũ không phải quyền thay theme.

UI states: loading, empty, editable dirty/clean, validating, saving, uncertain,
conflict, storage/network/deployment error, cached read-only và unavailable.
Remote chưa có schema/RPC phải báo chức năng lưu tài khoản chưa sẵn sàng; không
âm thầm save bằng legacy insert rồi báo V2 saved. Action busy có phản hồi và
semantics; không khóa toàn UI vì network. Không dùng màu làm tín hiệu duy nhất.

Proposed responsibility map (chưa là file allowlist implementation):

- Editable domain/codec/validator/money trong feature trip_planner: immutable
  document, mutation commands và validation; không phụ thuộc widget/Supabase.
- ManualPlannerProvider giữ editorGeneration, candidate/base/version và dirty;
  register lifecycle consumer, tách khỏi legacy TripProvider engine state.
- Repository adapter trong feature trips route V1/V2, local draft, snapshot,
  outbox và RPC; không để screen viết SQL hoặc gọi generic legacy save cho V2.
- Editor/timeline/forms/budget/preview là widgets nhỏ; UI chỉ dispatch commands.
- SQL validator/mutations/guards là server authority, có contract vectors chung
  với Dart. Tên file/signature/packet dependency chốt trong implementation plan
  sau khi written spec được duyệt, không tự triển khai từ responsibility map.

UI/UX Pro Max đã tìm đúng hướng dragging movements: cung cấp thao tác thay thế;
Flutter search trả Semantics/TalkBack guidance. Đây là gợi ý thiết kế, chưa có
ảnh chạy thật. Quy chuẩn: Theme.colorScheme/textTheme; spacing bội 4; radius<=16
trừ pill; Android targets>=48dp; textScale 1.5 và cỡ lớn hệ thống, 360/390px,
portrait/landscape, safe area, keyboard không che nút, TalkBack và reduced motion.
Không thêm font/package/native permission/design system mới.

## 10. Nghiệm thu và điều kiện triển khai

| ID | Hành vi bắt buộc | Bằng chứng cần thu sau approval implementation |
| --- | --- | --- |
| M01 | Input ngày/count/budget 0; draft thiếu ngày khác confirm đủ ngày | Domain + form; AC-011 |
| M02 | IDs ổn định qua CRUD/reorder/day move; cancel giữ nguyên | Domain/widget; AC-012/013 |
| M03 | Resize preview, exception invalidation, unknown không verified | Domain/widget; manual portion AC-042 |
| M04 | Vector 500000/100000x3/250000/unknown đúng; overflow/basis bị reject | Dart/SQL golden vectors + UI; AC-024/043 |
| M05 | Sửa/xóa item chỉ thay estimate/link, actual amount/category/paidOn giữ | Domain + transaction; AC-025/027, manual portion AC-044 |
| M06 | Guest save/close/reopen đúng revision; storage fail giữ disk cũ/dirty mới | Disk SQLite FFI + Android; AC-005/045 |
| M07 | V1 bytes/receipts không đổi; copy preview tạo ID mới, cancel không mutation | Existing regression + adapter vectors |
| M08 | Upgrade 1→2 atomic; fault rollback; old V1 store/import/snapshot vẫn đọc | Existing populated SQLite fixture/restart |
| M09 | Import đúng selected revision; lost ack/retry và source conflict | Native PostgreSQL + SQLite recovery; AC-006/039 |
| M10 | Account create/read/edit có receipt; không half-save/false saved | DB fault + service/provider + Android; AC-014/015 |
| M11 | Hai sessions cùng base chỉ một commit; retry không duplicate/tăng version lại; head mới hơn receipt không đổi editor base ngầm | Native independent-session barrier tests + client |
| M12 | Itinerary command không sửa tiền actual; explicit actual commands độc lập; batch cùng version | SQL adversarial + server vectors |
| M13 | A/B, expired proof, delayed response, purge failure/restart an toàn | SQL roles + lifecycle fault + Android; AC-040/045 |
| M14 | Offline V2 complete read-only; no cache/unavailable rõ; không cache downgrade | Store/service/UI + airplane-mode; AC-016 |
| M15 | Direct table/anchor/activity bypass và giả owner/receipt bị từ chối | Real anon/auth roles + guard negative controls; AC-034 |
| M16 | Delete confirmation/version/tombstone; account cascade không lỗi | Native SQL concurrency/fault + UI |
| M17 | Chữ lớn, TalkBack, button reorder, keyboard/back/loading/error/unknown | Widget sizes + Android observed evidence |
| M18 | Selected destination manual đúng nơi, không engine/AI calls; auto mode cũ giữ | Integrated regression + Android |

527 Flutter tests/40 node catalogue checks là evidence P3.1 tại HEAD đã bàn giao,
không phải kết quả M01–M18. Bộ 527 Flutter tests được chạy lại ở task tài liệu
này, vẫn PASS; node suite không chạy lại. P3.2 toàn bộ implementation/tests
SQL/UI đang NOT RUN. Không claim full AI AC-018/020/041/044 hoặc group từ manual tests.

Verification source sau implementation: flutter analyze --no-pub; full flutter
test --no-pub; node --test test/catalogue_readiness_test.mjs; dart format và
git diff --check. SQLite FFI không thay native PostgreSQL concurrency/RLS/ACL;
widget pass không thay Android manual hoặc đánh giá UI thực tế.

Trước viết migration phải inspect metadata/ACL/trigger thật của staging, đối
chiếu B3/B9 và không đọc/export private trip data. Tạo source migration có
preflight/version dependency, SQL positive/negative tests và native runner;
không Docker. Không giả định staging baseline.sql hoặc Phase 1 logical tables
là schema thật hiện tại. API/RPC definitions chi tiết, guard authorization và
compatibility vectors phải nằm trong implementation plan review được.

Staging target duy nhất dự kiến: bkocylxbuyvdgxccpixx; primary
oavbymauorhmrjcustzw vẫn ngoài scope, B3 primary NOT APPLIED theo handoff.
Approval spec/plan/code không tự cấp quyền apply/deploy. Chỉ chạy database writes
khi đã có target-specific Owner authorization; không enable AI hoặc sửa backend
repo bên cạnh. Build APK staging sau source/SQL checks, bàn giao Owner test.
P3.2 không được báo hoàn tất account runtime trước khi schema staging được phép
apply và acceptance M09–M16 có evidence, dù phần Guest/UI đã chạy.

## 11. Tự review và bàn giao thiết kế

Self-review R1: đã đối chiếu mục tiêu Guest/account với cả local/remote paths;
tách V1 copy và V2 mutation; giữ imported immutability, ledger actual, date/basis,
receipt retry, pending import revision và snapshot/lifecycle boundaries. Không
có implementation placeholder hoặc auto rollout. Hai phần cần engineering
review kỹ trong plan là guard trusted mutation không giả được và upgrade/purge
V2 đi cùng lifecycle V1; đây là tiêu chí phải chứng minh, không bằng chứng đã đạt.

Changed: một spec mới; không sửa code/config/catalogue/migration/permanent rules.
Why: document V2 có identity và ledger rõ, bảo toàn cam kết V1 đã nghiệm thu.
Testing: source/contract inspection và spec self-review; theo verification rule
của repo đã chạy lại flutter analyze --no-pub: No issues found (5.7s), exit 0;
flutter test --no-pub --reporter expanded: 527 PASS (27s), exit 0. Không có tests
P3.2 mới vì chưa implementation; đây chỉ là regression baseline. Log ignored:
build/p32-design-flutter-regression.log. Scan có 18 acceptance rows, không có
TODO/TBD/FIXME hoặc trailing whitespace; chỉ một file tài liệu được stage.
Problems: P3.1 Owner test còn pending; schema live/SQL runtime V2 chưa kiểm;
chưa có implementation plan hoặc approval written spec. Account edit chưa
submit nằm RAM là giới hạn được nêu rõ, không có offline account edit/autosync.
Lesson Candidate: payload hiển thị không đủ để làm editor → thiếu identity và
version gây mất liên kết tiền → tách editable aggregate, dùng mutation/version
và giữ immutable receipt của hợp đồng cũ.

Tài liệu nằm trong docs/phase-3 vì docs/superpowers là vùng riêng Owner cấm đọc/
sửa. Superpowers brainstorming được Owner yêu cầu cho task thiết kế hiện tại;
Codex-only, không subagents. Written spec phải được Owner review trước
writing-plans; khi code dùng workflow bình thường, superpowers OFF. Ngưỡng
25 calls/5 files/3 repair rounds được giữ cho task tài liệu này. Không push/PR/
main reset/clean hoặc đụng sáu mục riêng và generated macOS của Owner.

Nguồn kỹ thuật bổ sung đã đọc ngày 2026-10-15:
[Supabase database functions](https://supabase.com/docs/guides/database/functions),
[Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
Changelog markdown không tải được trong lượt khảo sát trước (web content type;
shell DNS); cần kiểm breaking changes phù hợp trước implementation Supabase.
