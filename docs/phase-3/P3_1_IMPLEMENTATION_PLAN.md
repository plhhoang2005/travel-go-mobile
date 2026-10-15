# P3.1 — Kế hoạch triển khai Discovery theo R2

Ngày: 2026-10-15. **IMPLEMENTED — AUTOMATED CHECKS PASS; OWNER TEST PENDING.**
Owner duyệt R2 bằng “ok duyệt r2”, sau đó yêu cầu “tiến hành làm p3.1”.
Yêu cầu sau cấp quyền triển khai các packet trong plan; không hỏi lại approval
R2/plan. Trạng thái approval này thay thông tin chờ duyệt plan còn ở spec R2.
Spec: `P3_1_DISCOVERY_DESIGN.md`; data review: `P3_1_CATALOGUE_REVIEW.md`.
Codex-only, không subagents/Docker. Superpowers OFF trong task lập plan này;
chỉ bật nếu Owner yêu cầu rõ cho task cụ thể, luôn tắt khi code.

## 1. Baseline và phạm vi

- Repo `plhhoang2005/travel-go-mobile`, checkout `D:/Travel-Go-Android/travel-go`.
- Branch hiện tại `codex/phase-3-discovery-design`, HEAD trước plan
  `a0cb8b4bdc8b0ba2c0d4e4271fa597a1a139d886`.
- Baseline sản phẩm `ebccb6d39d6db4cbfd568daf4edda97dd7643ea6` sau PR #38.
  Local main vẫn `77fd1a8`; remote-tracking origin/main là baseline trên.
  Remote trực tiếp chưa kiểm được ở session mới do lỗi mạng; không giả định
  remote không thay đổi. Không tự merge/rebase/reset hoặc fast-forward main.
- `macos/Flutter/GeneratedPluginRegistrant.swift` dirty sẵn của Owner; index rỗng
  trước lượt này. Giữ toàn bộ untracked docs/assets. Không add-all/clean/reset.
- Không đọc/sửa/stage/delete `Huong_dan_su_dung_Map.docx`, `create_doc.py`,
  `create_ppt.py`, `docs/superpowers/`, `embed.py`, `presentation.html`.
- Chỉ Discovery, catalogue, chọn điểm đến và input workspace. Không thay backend,
  canonical trip V1/hash, schema SQLite, import/receipt, Auth architecture, native
  config, dependencies, AI, manual itinerary hoặc ngân sách thực chi.
- Primary B3 NOT APPLIED theo checkpoint; không apply/deploy/bật gateway.

Luồng đích: catalogue đóng gói → tìm/lọc → chi tiết/nguồn → xác nhận nếu có nội
dung chưa lưu → tạo workspace mới đúng điểm đến → Guest lưu/reopen input.
Account giữ input trong RAM, hiện chưa lưu. Selected destination chặn engine
auto-winner; hành động rõ ràng đưa người dùng về chế độ app tự gợi ý.

## 2. Các điểm code đã đối chiếu

| Vị trí hiện tại | Trách nhiệm khi triển khai |
| --- | --- |
| `lib/features/explore/presentation/screens/explore_screen.dart` | Hiện lấy HomeCatalogProvider và weather mặc định; thay riêng màn này bằng catalogue tham khảo. Giữ constructor để các đường Home cùng đến Discovery mới. |
| `lib/features/navigation/presentation/screens/main_navigation_shell.dart` | Đã dùng ExploreScreen trong IndexedStack; không cần sửa shell/tab. |
| `lib/main.dart` | TripProvider đã nhận Auth context qua ProxyProvider; chỉ thêm DiscoveryProvider độc lập, lazy và không tự gọi dịch vụ mạng. |
| `lib/features/trip_planner/providers/trip_provider.dart` | Đã có generation, invalidation, Guest checkpoint, save/open V1 và request immutable; bổ sung thay workspace có điều kiện và guard submit. |
| `lib/features/trip_planner/presentation/screens/home_planner_screen.dart` | Hiện gọi health probe khi mở và luôn cho submit; thêm selected destination, cảnh báo account và đường quay lại auto mode. |
| `lib/features/trips/models/trip_payload_codec.dart` | Metadata V1 đã có destinationId/name; dùng nguyên contract. Không dùng copyWith để xóa nullable fields vì nó giữ giá trị cũ. |
| `test/guest_draft_planner_test.dart` | Có API spy, completer và SQLite FFI; dùng lại fixture/cách kiểm chứng, giữ nguyên assertions cũ. |
| `test/catalogue_readiness_test.mjs` | Hiện kiểm nguồn vietnam.travel và ngày nguồn bằng ngày inventory; cần kiểm ngày riêng cho nguồn bổ sung, không làm yếu negative controls. |

Map search hiện có chỉ xử lý dấu dựng sẵn. Discovery cần thêm loại dấu tổ hợp;
không sửa map service để tránh lan phạm vi. Chuẩn hóa tìm kiếm không được thay
tên hiển thị, metadata hoặc bytes canonical trip.

## 3. Hợp đồng dữ liệu và publication được đề xuất chốt cùng plan

Giữ catalogue schemaVersion=1, status `reference_data_not_deployed`, rights và
mọi place IDs. Đây là inventory/reference, không dùng status ấy để suy DB đã
deploy. Kiểm kê nguồn ban đầu 12 destinations/72 places/12 candidates; không
đổi số thành yêu cầu hai điểm/ngày. Không thêm trường recommended_day vào place.

Bổ sung duy nhất `sample.editorialReview` trong data packet P0:

```json
{
  "status": "pending",
  "reviewedAt": null,
  "sourceIds": [],
  "conditions": [],
  "reviewNotes": []
}
```

- `status` chỉ nhận `pending` hoặc `reviewed_with_conditions`. Thiếu cả object
  ở dữ liệu cũ được hiểu pending để giữ tương thích inventory; có object sai
  kiểu/trạng thái/ngày/tham chiếu thì từ chối catalogue, không âm thầm sửa.
- Pending: reviewedAt=null, sourceIds/conditions rỗng; reviewNotes có thể ghi
  lý do cần rà soát. UI chỉ hiện “Ví dụ đang được rà soát”, không render days.
- Reviewed_with_conditions: reviewedAt là ngày lịch YYYY-MM-DD hợp lệ,
  sourceIds không rỗng và trỏ đúng source records, conditions/reviewNotes là
  các danh sách string không rỗng. Review notes phải mô tả căn cứ ghép điểm,
  điều kiện tiếp cận và giới hạn; nguồn chỉ nhắc tên không đủ để nâng trạng thái.
- Cả hai giữ `sample.status=not_feasibility_verified`; không có giá trị verified.
  Reviewed là biên tập có điều kiện, không là xác nhận đang mở hoặc tuyến tối ưu.
  Warnings cũ luôn giữ. UI chỉ bật preview khi toàn bộ điều kiện marker hợp lệ.
- Lần đầu cả 12 candidates mặc định pending. Không cần bịa hoặc ép công bố một
  lịch để hoàn tất Discovery. Nếu P0 có đủ evidence mới cho sample cụ thể, ghi
  reviewNotes và sửa days theo căn cứ; không chỉ đổi marker để bật preview.
- Days là số nguyên dương liên tiếp, placeIds thuộc đúng destination; mỗi ngày
  có ít nhất một điểm, không lặp cùng placeId trong ngày. Không cố định ba ngày,
  hai điểm/ngày hoặc bắt dùng đủ sáu điểm trong parser runtime.
- Nguồn mới có source record riêng, title/publisher/HTTPS URL/checkedAt hợp lệ.
  Giữ checkedAt inventory 2026-10-13; không thay ngày nguồn cũ thành ngày mở cửa.
  Không bắt ngày của mọi nguồn bằng ngày inventory.
- Host allowlist runtime/test: `vietnam.travel`, `www.vietnam.travel`,
  `sapanapro.com`, `danangfantasticity.com`, `halongbay.com.vn`. Chỉ bổ sung
  source record từ URL đã đọc và ghi claim trong P0; không thêm domain khác,
  wildcard, userinfo, port khác 443 hoặc URL không HTTPS. Source IDs phải tồn tại.
- Chuẩn hóa tên SAPANAPRO và Linh Ứng Sơn Trà chỉ sau đọc lại nguồn trực tiếp
  tương ứng; giữ IDs và trace trong review doc. Không tự đổi tên thành hoạt động
  đang nhận khách. Bảo Đại/Hòn Mun/Bidoup/Đức Bà giữ giới hạn chưa xác minh.
- coordinates/openingHours/priceVnd/durationMinutes vẫn null,
  operationalStatus=unknown, routingReady=false. Không bổ sung operational schema
  tương lai vào P3.1 hoặc chuyển các giá trị này thành 0/mở cửa/miễn phí.

P0 phải xong và kiểm diff/data contract trước khi copy asset; nếu evidence thiếu
thì giữ pending. Automated tests chứng minh cấu trúc và chính sách hiển thị,
không chứng minh operator đang đón khách. Quyền phân phối vẫn not_assigned;
nghiệm thu STAGING không tự cấp quyền phát hành dataset công khai.

## 4. Hợp đồng workspace và UI

TripProvider bổ sung read-only `currentMetadata`, `hasSelectedDestination`,
`canReplaceWorkspace` và thông tin context cần cho nhãn chưa lưu. Tên API dự kiến:
`prepareDestinationWorkspace(...)` và `useSuggestedDestination(...)`, nhận
`expectedWorkspaceGeneration` và xác nhận thay dirty workspace từ caller.
Không phụ thuộc model Explore trong TripProvider; truyền ID/name đã parse.

1. Capture generation trước dialog. Generation hiện tăng khi Auth/context đổi,
   nên kiểm cùng token sau dialog và ngay trước mutation; không dùng chỉ mounted.
2. Nếu disposed, save/load đang chạy, token cũ, ID/name không hợp lệ hoặc dirty
   mà chưa xác nhận: trả false, không mutate request/metadata/response/IDs/digest.
   UI thông báo state/phiên đã đổi và không navigate. Busy disable CTA cả hai mode.
3. Thành công: invalidate operation cũ; giữ deep-frozen request nếu có input,
   nếu plan-only dùng preset Minh và hiển thị là input ban đầu có thể sửa.
   Tạo TripMetadataV1 mới: title “Chuyến đi <tên>”, destinationId/name đúng;
   startDate/endDate/timezone=null. Response/active ID/revision/savedDigest=null,
   restored=false, hasInput/activity=true. Chưa sinh UUID hoặc mở SQLite.
4. Hủy/back dialog giữ nguyên payload/digest/ID và không navigate. Bản revision
   đã lưu luôn còn. Save về sau mới cấp ID; save lại workspace ấy tăng revision.
5. Auto mode dùng cùng cơ chế, metadata mới rỗng destination và ngày/tiêu đề cũ,
   giữ input; không đổi/xóa draft cũ. Không gọi engine cho đến người dùng submit.
6. Guard đầu submitPlan trước _invalidate/API nếu destinationId đã có, kể cả
   restore. Không xóa saved response hoặc đổi winner để khớp metadata.
7. Account prepare không Guest write/cloud write, không ghi đè Guest checkpoint.
   Kiểm Guest → A → B → Guest và authEpoch đổi khi dialog mở. Không sửa Auth
   provider hoặc đổi cơ chế context để đạt test mới.

Shared UI helper chịu trách nhiệm dialog và token; provider chịu trách nhiệm
mutation/guard. Detail chỉ mở HomePlannerScreen khi provider trả true. Planner
hiện tên điểm đến, lời giải thích chưa hỗ trợ lập lịch theo nơi đã chọn và nút
“Để app gợi ý điểm đến”. Account hiện “Thông tin này chưa được lưu”. Không dùng
`!canPersistGuestDraft` một mình để kết luận account vì Guest cũng có thể thiếu
store trong fixture. Selected workspace không cần health probe lúc mở; auto mode
giữ health flow cũ. Kiểm spy riêng health và plan để tránh gộp sai bằng chứng.

DiscoveryProvider sở hữu loading/ready/error/search/filter và load token;
repository chỉ load asset + parser, loader inject được. Nạp khi màn dùng lần
đầu; retry/refresh chỉ đọc asset. Load cũ/dispose không notify/ghi đè. Text search
trim, lower-case, bỏ dấu tiếng Việt dựng sẵn/đ/Đ và combining marks U+0300–036F;
không thay display text hoặc thêm alias ngoài spec.

UI dùng Theme, spacing bội 4, radius <=16, list tile gọn; source URL wrap, chi
tiết cuộn. Không ảnh publisher/weather/giá giả. Giữ map entry hiện có như đường
độc lập, không đổi map data/service; mở Discovery/detail không tự mở map/site.
Không để thông tin lịch pending rò qua subtitle, semantics hoặc expandable day.

## 5. Các packet triển khai — allowlist chính xác

**Owner override sau P0:** “bạn làm hết p3.1 luôn sau đó để tôi test luôn không
cần phải chia nhỏ p3.1 ra đâu”. Các packet dưới giữ vai trò thứ tự kỹ thuật;
không còn là giới hạn file/tool-call khiến dừng giữa P3.1. Không thêm gate mới,
không dùng subagents/superpowers hoặc sửa permanent rules để thực hiện override.

Mỗi packet là một task riêng <=25 calls, <=5 files, <=3 vòng sửa. Thực hiện tuần
tự, không gom toàn bộ thành một task. Mỗi file mới ghi dưới đây nằm trong
allowlist; không thêm checkpoint file thứ sáu. Nếu scope cần đổi, báo cụ thể
trước khi vượt giới hạn; không tự chia task để che thay đổi ngoài plan.

### P0 — Data review và publication (4 files)

1. `docs/phase-2/catalogue/catalogue_readiness_v1.json` — thêm review marker,
   chỉnh tên/nguồn có căn cứ, giữ unknown và samples pending khi chưa đủ chứng cứ.
2. `docs/phase-2/catalogue/README.md` — mô tả publication policy và giới hạn.
3. `docs/phase-3/P3_1_CATALOGUE_REVIEW.md` — ghi delta/evidence thực đọc và việc
   chưa xác minh; không ghi nhận claim Owner là kiểm chứng độc lập.
4. `test/catalogue_readiness_test.mjs` — thêm marker/date/source controls,
   không xóa negative cases cũ để hợp thức hóa dữ liệu sai.

Exit: node tests PASS; kiểm 12/72/12, IDs giữ nguyên; inventory review đủ 12 sample
và pending list rõ. Nếu cần hơn 25 calls để xác minh lịch, dừng việc nâng marker;
giữ pending thay vì bỏ qua review hoặc đưa runtime dùng lịch chưa kiểm.

### P1 — Model và parser (3 files; sau P0)

1. `lib/features/explore/models/catalogue_reference.dart` — immutable models.
2. `lib/features/explore/services/catalogue_parser.dart` — validation/allowlist,
   review policy, vùng theo ID. Không adapter sang POI cost int.
3. `test/catalogue_parser_test.dart` — valid/negative fixtures inline.

Exit D01/D02: reject duplicate IDs, source thiếu/sai host/userinfo/date/schema,
sample chéo, field sai kiểu/false verification; giữ null/unknown; lists bất biến.
Kiểm ngày không tồn tại như 2026-02-30. Test ngày một/ba điểm và số ngày khác ba.
Test marker thiếu→pending, malformed→error, reviewed thiếu evidence→error.

### P2 — Bundle catalogue (3 files; sau P1)

1. `assets/catalogue/catalogue_readiness_v1.json` — copy bytes đúng P0.
2. `pubspec.yaml` — chỉ thêm asset declaration; không dependency/lockfile.
3. `test/catalogue_asset_test.dart` — so sánh bytes nguồn/runtime và load bằng
   rootBundle rồi parse, không chỉ đọc file qua File API.

Exit D01/D06: bản đã review thực sự vào Flutter bundle; nguồn đổi mà copy cũ
phải fail. Approval plan này cần bao gồm asset declaration cụ thể trên.

### P3 — Repository và Discovery state (5 files; sau P2)

1. `lib/features/explore/services/catalogue_repository.dart` — injected loader.
2. `lib/features/explore/providers/discovery_provider.dart` — state/search/filter.
3. `lib/main.dart` — thêm provider độc lập; không đổi ProxyProvider/Auth wiring.
4. `test/catalogue_repository_test.dart` — loader error/parse error/retry.
5. `test/discovery_provider_test.dart` — search, region, stale load, dispose.

Exit D03/D06: đủ 12 IDs; `DA NANG`, `Đà Nẵng`, Unicode tổ hợp đều tìm được;
clear query giữ filter, reset filter đúng; empty khác error. Load/retry không
HomeCatalog/weather/API. Kiểm production registration và không tự mở local DB.

### P4 — Workspace và engine guard (2 files; sau P3)

1. `lib/features/trip_planner/providers/trip_provider.dart` — APIs ở mục 4.
2. `test/discovery_workspace_test.dart` — API spies/completers/SQLite FFI.

Exit D07–D12: giữ mọi request field, reset đúng metadata/identity; clean/dirty,
reject/hủy, busy và token/Auth/dispose; response cũ không quay lại. Selected
submit API count=0 và không mất saved response; auto mode submit được. Guest
save/reopen input giữ destination/hash, save tăng revision, draft cũ nguyên vẹn.
Account prepare không store/API/cloud write; checkpoint Guest hồi phục đúng.
FFI phải reopen DB từ disk sau đóng store, không chỉ tái dùng object provider.

### P5 — Planner và shared confirmation (4 files; sau P4)

1. `lib/features/trip_planner/presentation/screens/home_planner_screen.dart`.
2. `lib/features/trip_planner/presentation/widgets/planner_workspace_actions.dart`
   — shared helper confirm/prepare/auto mode, token trước dialog và mounted sau.
3. `lib/features/trip_planner/presentation/widgets/selected_destination_controls.dart`
   — tên destination, thông báo giới hạn/lưu RAM, CTA auto mode.
4. `test/planner_destination_ui_test.dart` — cancel/back/confirm, busy/stale,
   account/Guest, selected restored, plan-only và text scale.

Exit: không submit selected qua UI/provider, vẫn xem result đã lưu; auto mode
hoạt động với Guest/account. Không bỏ luồng save/open cũ. Tại selected workspace
không tự health/plan call khi mở; auto giữ hành vi cũ. 360/390 và text scale 1.5.

### P6 — Discovery list và detail (5 files; sau P5)

1. `lib/features/explore/presentation/screens/explore_screen.dart` — giữ entry
   constructor, state mới/search/filter, loading/error/retry/empty.
2. `lib/features/explore/presentation/screens/destination_detail_screen.dart`
   — place/source/unknown, preview có điều kiện và CTA dùng shared helper P5.
3. `lib/features/explore/presentation/widgets/destination_reference_list_tile.dart`
   — item tên/vùng/tham khảo, không weather hoặc ảnh mạng.
4. `test/discovery_screen_test.dart` — list/search/filter/retry/navigation.
5. `test/destination_detail_test.dart` — nguồn/ngày/unknown/publication/CTA.

Exit D03–D09/D13: tab và các route Home tới cùng Discovery; detail đúng ID, không
render day của pending, reviewed fixture giữ conditions/warnings và không ép
số điểm/ngày. Fixture là synthetic có nhãn test, không là evidence du lịch thật.
Provider reject thì không navigate. Long URL/error/conditions không overflow.
Các widget phụ tĩnh nhỏ có thể private trong screen; không gom logic provider
hoặc parser vào screen để tránh phải thêm file ngoài allowlist.

### P7 — Regression và nghiệm thu (3 files; sau P6)

1. `test/discovery_planner_flow_test.dart` — flow xuyên màn theo production
   provider wiring, selected destination/auto, load lỗi và stale response.
2. `test/guest_draft_planner_test.dart` — chỉ thêm regression thực còn thiếu;
   giữ toàn bộ assertions cũ và imports/fixtures dùng lại được.
3. `docs/phase-3/P3_1_ACCEPTANCE_REPORT.md` — exact HEAD, commands/results,
   D01–D14, staging APK/CI và Owner acceptance riêng, blockers/NOT RUN.

Exit: toàn bộ matrix mục 6. Nếu chỉ thiếu manual acceptance, ghi PENDING và
đưa hướng dẫn nghiệm thu cụ thể, không tự đổi thành PASS hoặc chạy live DB.

## 6. Verification và điều kiện hoàn tất

Trong mỗi packet code/data: chạy test tái hiện/negative cần thiết trước sửa,
test mục tiêu sau sửa, `flutter analyze` và `flutter test` trước bàn giao/commit.
P0 thêm `node --test test/catalogue_readiness_test.mjs`; các packet sau giữ check
này khi thay catalogue. Format check chỉ các Dart files đã sửa bằng
`dart format --output=none --set-exit-if-changed <explicit-files>`.
P2 trở đi dùng `flutter pub get` nếu cần cập nhật asset manifest; lockfile ngoài
allowlist phải giữ nguyên, không tự upgrade dependencies.

Chạy shell theo dõi được, yield/poll <=60 giây; không kết luận timeout chỉ vì
lệnh còn chạy. Tối đa ba vòng sửa; nếu chưa đạt thì dừng với bằng chứng/checkpoint
trong file được phép hoặc chat, không reset thay đổi Owner.

| Acceptance | Packet / bằng chứng |
| --- | --- |
| D01–D02 inventory/parser/bytes | P0/P1/P2: node, parser negative, rootBundle và byte equality |
| D03 search/filter | P3/P6: có/không dấu, tổ hợp, đ/Đ, trim/empty/reset |
| D04 source/unknown | P1/P6: date thật, source bind, không 0/free/live giả |
| D05 publication | P0/P1/P6: pending không hiện ngày; reviewed giữ điều kiện |
| D06 offline/error/retry | P2/P3/P6: bundle hoạt động offline; asset hỏng không fallback giả |
| D07–D09 workspace/races | P4/P5/P6: token, cancel, save/load/Auth/dispose/response muộn |
| D10 Guest persistence | P4/P7: disk FFI reopen + Android đóng/mở app |
| D11 account/checkpoint | P4/P7: Guest → A → B → Guest; không Guest/cloud write |
| D12 selected/auto engine | P4/P5/P7: API spies; selected restore chặn, auto submit đúng |
| D13 responsive | P5/P6: widths 360/390, scale 1.5; Android đối chiếu |
| D14 Phase 2 regression | P7: full Flutter suite, codec/store/import/snapshot/Auth suites hiện có |

Nghiệm thu DNY-NX9 STAGING sau code và quyền build/install phù hợp: search/filter
12 nơi khi offline; mở source/unknown; pending không có lịch ngày; chọn Huế,
hủy thay dirty không mất dữ liệu; xác nhận tạo mới vẫn giữ draft cũ; Guest lưu,
đóng/mở và reopen đúng Huế/input; selected không tự lập nơi khác; auto mode rõ
ràng; account báo chưa lưu và đổi phiên không lẫn workspace; kiểm text scale.
Không clear app data. Record ai chạy/commit/APK/target/kết quả; FFI không thay
Owner manual, tests pass không thay source review hoặc xác nhận dữ liệu du lịch.

CI Flutter hiện chỉ chạy analyzer/tests; node check là local evidence riêng,
không tuyên bố CI đã chạy node. PR/CI exact HEAD là bước publication sau khi
Owner authorize; plan này không cấp quyền push/merge/deploy. Không push main.

## 7. Approval và bàn giao lượt lập plan

R2 APPROVED; implementation AUTHORIZED bởi yêu cầu “tiến hành làm p3.1”.
Đã bắt đầu P0 theo thứ tự trên. Không hỏi lại các quyết định đã chốt; chỉ báo
khi phát sinh blocker/scope mới thật.
Không dùng approval của PR #34–#38 làm quyền merge các PR tiếp theo.

### Bàn giao lịch sử của lượt lập plan (trước implementation authorization)

Changed: plan này và trạng thái approval trong spec R2; không sửa source/data.
Why: tận dụng workspace/SQLite V1 và chặn mismatch điểm đến ở provider lẫn UI;
review/publication đi trước asset để không phát lịch sai có gắn disclaimer.
Testing: read-only source/contract/Git inspection và kiểm diff tài liệu;
flutter analyze/flutter test/node tests NOT RUN trong lượt lập plan, không sửa
implementation. Bằng chứng Phase 2 giữ riêng, không dùng làm PASS P3.1.
Problems: chưa có mẫu mới đủ evidence, fixed-destination API hoặc account-input
persistence; thiết kế chấp nhận các giới hạn này và UI phải nói rõ. Remote mới
chưa xác minh do lỗi mạng. Không rollout primary.
Lesson Candidate: chọn nơi trên UI nhưng API chưa nhận nơi đó → contract mismatch
→ guard tại cả state và UI, có đường rõ về auto; nguồn nhắc tên không chứng minh
lịch dùng được → review độc lập và chỉ công bố lịch đủ điều kiện biên tập.

## 8. Checkpoint triển khai P0 — 2026-10-15

- Authorization: Owner “tiến hành làm p3.1”; superpowers OFF, Codex-only.
- Branch `codex/phase-3-discovery-design`; baseline HEAD vẫn `a0cb8b4`.
  Đây là thay đổi working tree, chưa commit/push/PR và chưa runtime integration.
- Changed trong task P0: bốn file allowlist P0 và chính plan này để ghi approval,
  checkpoint; tổng năm file. Spec R2 dirty và generated macOS là thay đổi từ
  trước task, không stage/reset. Giữ sáu mục riêng, mọi untracked khác và index.
- Data: 12/72/12, toàn bộ 96 destination/place/sample IDs giữ nguyên; historical
  days không đổi. 12/12 marker pending, không mẫu mới được công bố. Hai display
  names/source bindings chuẩn hóa có nguồn trực tiếp; sources tăng 15→17.
- Tests: node 40/40 PASS, exit 0. Test marker đã fail trước sửa data vì thiếu
  editorialReview, rồi PASS sau bổ sung. Tám negative controls cũ vẫn giữ.
  `git diff --check` trên bốn file P0 exit 0. `flutter analyze`: No issues found,
  61.8 giây, exit 0. `flutter test --reporter compact`: 471 tests PASS, exit 0.
  Checks chạy trên working tree P0 ở baseline a0cb8b4, không là CI hoặc evidence
  cho feature Discovery chưa code. Lần chạy sandbox kẹt SDK cache lock đã hủy;
  lần sau chạy với quyền SDK cache phù hợp, không đổi dependency/native config.
- Giới hạn: ngày/giá/giờ/tọa độ/vận hành vẫn chưa xác minh; chưa có Flutter
  asset/parser/UI mới, nên D05 runtime và nghiệm thu Android P3.1 NOT RUN.
- Budget checkpoint: đã dùng năm file/task; dừng thay đổi ở P0 theo quy tắc
  Owner, không tự nối P1 trong cùng task để vượt ngưỡng. Bước tiếp theo đã được
  authorize là P1 (ba file model/parser/test trong mục 5), không cần duyệt lại
  thiết kế hoặc plan. Không tự apply DB, bật AI gateway hay push main.

## 9. Thực hiện trọn P3.1 theo Owner override

Đã triển khai P1–P7 trong cùng lượt sau P0. Data contract và scope R2 giữ nguyên;
không thêm account-input persistence, manual editor, AI hoặc backend API mới.
Parser/repository/state, asset declaration, Discovery list/detail, shared confirm,
workspace/engine guards và regression đã có. Account selected input hiện RAM;
12/12 sample pending vẫn ẩn ngày. Không coi UI có đủ 12 điểm đến là full MVP.

Delta hợp lý so với file list dự kiến: thêm DiscoveryProvider vào fixture
`test/auth_navigation_test.dart` để khớp dependency mới, không sửa assertion cũ;
giữ tiêu đề Khám Phá Việt Nam. Regression Guest draft sẵn có không cần sửa vì
test mới đã nằm riêng. Test file phụ cho fixture chỉ dùng imports helper đã có.

Verification cuối và artifact test ghi tại `P3_1_ACCEPTANCE_REPORT.md`; P0 budget
checkpoint bên trên là lịch sử, không còn là lý do dừng triển khai. Owner manual
acceptance của P3.1 vẫn PENDING; không kế thừa 7/7 Phase 2 thành PASS mới.
