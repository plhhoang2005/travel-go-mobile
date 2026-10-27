# Plan cho Antigravity — Admin lưu → xuất bản → app khách thấy

Ngày 23/10/2026, Asia/Saigon. Owner giao Codex lập plan để Antigravity triển khai. **Codex plan/review; Antigravity code/test/sửa findings.** Superpowers OFF. Một gói thực hiện liên tục; các bước dưới đây là thứ tự kỹ thuật, không yêu cầu owner giao lại từng bước hoặc cấp thêm calls.

**Actual baseline:** `363215b0079fc703022e9f0a39d6706c6dfc4e6c`, branch `codex/phase-3-discovery-design`. Xác minh lại HEAD và dirty files trước sửa. Checkout có nhiều owner-dirty/untracked dependencies; không reset/stash/clean hoặc chỉ lấy bare HEAD rồi bỏ dependencies. Ghi baseline/hash cho file đã dirty, selective stage phần mình sửa.

**Căn cứ:** [review R3](ADMIN_DEMO_CODEX_REVIEW_R3_20261023.md). D1/D2 đã đóng; D3 là facts của địa điểm mới chưa đủ schema public; D4 là save chỉ ghi nháp và publication screen chưa được nối. Owner muốn số lượng địa điểm thay đổi theo CRUD, không hardcode 72; thêm/sửa/ẩn đã lưu thành công phải cập nhật danh mục app khách.

## 1. Hành vi cuối cùng

```text
Admin thêm / sửa / xác nhận ẩn
  → lưu command lên server, nhận draft revision R
  → tự tạo preview cho R
  → tự publish preview: upload → readback hash → activate manifest
  → nhận operation completed đúng sourceRevision R
  → UI báo đã lưu và xuất bản
  → app đang dùng làm mới public snapshot
  → Home / Explore / chi tiết cùng dùng danh mục mới
```

- Một thao tác Lưu, không cần owner bấm Xuất bản riêng. Draft vẫn là bước nội bộ của pipeline để dùng API hiện có; không phải bước thủ công bắt buộc trong UX này.
- Mỗi command nhận **một revision từ server**; chỉ publish revision vừa nhận. Không tự đoán `currentRevision + 1` hoặc lấy preview cũ của thao tác khác.
- Admin thấy cả records đã ẩn với trạng thái rõ ràng. Khách chỉ thấy records active và con thuộc parent active. “Xóa” trong gói này là archive/ẩn; giữ IDs và lịch sử chuyến đi.
- App khách cùng phiên chạy refresh sau publish; thiết bị khác cập nhật khi khởi động, foreground resume hoặc kéo tải lại. Không hứa mọi máy offline đổi ngay. Không thêm Realtime/polling mới cho gói demo.
- Không cố định số lượng. Tests dùng baseline N/M → thêm → N+1/M+1 → ẩn → giảm tương ứng. 12/72 chỉ là seed fixture hiện tại.
- Không đổi thuật toán lập lịch/AI, quota, dependencies, native config, permanent rules hoặc mở lại các findings DEFERRED. Điểm đến mới vẫn dùng lập lịch thủ công theo khả năng hiện tại.

## 2. Quyết định triển khai

### 2.1. Chuẩn hóa facts ở API xuất bản, không cần migration mới

Sửa `bundle.mjs` để chuyển facts **unverified** thiếu list mặc định sang public DTO hợp lệ trước encode. Dùng bản sao, không mutate frozen draft hoặc facts đã reviewed:

- Thiếu `price.evidence.conditions` → `[]` khi price.status và evidence.reviewState đều unverified.
- Thiếu `hours.evidence.conditions` → `[]` khi hours.status và evidence.reviewState đều unverified.
- Thiếu `hours.notes` → `[]` khi hours.status unverified.

Áp dụng cho cả records mới và drafts local đã tạo thiếu fields trước đó. Không đổi giá/giờ, IDs, checkedAt, review state, sourceIds hoặc các list hợp lệ đang có. Không biến giá trị sai kiểu thành hợp lệ hoặc nới parser cho reviewed facts. Đây là adapter public DTO phía server, không phải Flutter tự bịa fallback. Giữ sửa D1: nguồn của facts/packages phải đi cùng projection.

**Lý do chọn:** đóng được lỗi producer→consumer cho cả dữ liệu đang có mà không sửa lịch sử draft/migration đã dùng. Không cần Supabase CLI hay thao tác dữ liệu live chỉ để thêm list mặc định. SQL createPlace vẫn có internal draft shape hiện tại; public release phải có canonical shape app khách cần.

### 2.2. Điều phối trong AdminCatalogueProvider, tái dùng publication service

Không tạo endpoint mới. Inject `AdminPublicationService publicationService` vào AdminCatalogueProvider; giữ `AdminCatalogueService` cho command. Shell lấy service từ publication provider hiện có (`_getEffectivePublicationProvider().service`) để giữ cùng project/lifecycle, không tạo vòng phụ thuộc giữa hai providers.

Thêm callback optional `Future<void> Function(PublicationOperation operation)? onPublished` cho refresh cùng app. Callback chỉ chạy sau completed acknowledgement; production shell phải cung cấp. Tests không có callback vẫn phải gọi publisher thật được inject/mock, không có default publisher giả trả success.

Giữ `submitDestination/submitPlace/archiveDestination/archivePlace -> Future<bool>` để dùng form callbacks hiện có. `true` chỉ có nghĩa server đã xác nhận publish hoàn tất. Với restore history đang hoãn: không tự nối thêm luồng mới; giữ semantics cũ hoặc tách private command option explicit để tránh tự thay behavior ngoài scope.

State nhỏ trong cùng provider: `idle`, `savingDraft`, `publishing`, `published`, `savedNotPublished`; lưu saved revision/snapshot và phase để không gửi lại create khi draft đã được server acknowledge. `_isSaving` bao phủ save + publish, chặn double tap và command kế tiếp trong khi đang xử lý. Khi owner/role đổi hoặc dispose, generation fence phải chặn mọi snapshot/error/callback đến muộn.

### 2.3. Refresh dùng một public snapshot

- PublicCatalogueProvider thêm `initialize()` để load cache/seed trước rồi fetch manifest; `main.dart` dùng initialize thay vì chỉ load seed.
- Admin publish thành công gọi `PublicCatalogueProvider.refresh(force:true)`; làm mới dashboard đang dùng sau đó. Refresh local lỗi không được đổi publication completed thành draft-save failure; hiển thị cảnh báo đồng bộ local, không gửi lại command/publish.
- `onResume()` kiểm manifest mới, không để khoảng cache 5 phút chặn buổi demo sau khi admin vừa lưu. Giữ repository single-flight để gộp request đồng thời.
- DiscoveryProvider nhận optional `Future<PublicCatalogueSnapshot> Function(bool force)? publicSnapshotLoader`; main.dart luôn inject loader của PublicCatalogueProvider. Loader dùng refresh(force:force), trả public snapshot đã xác minh. Pull-to-refresh Home/Explore hiện gọi DiscoveryProvider.load(force:true), nên phải đi vào loader public, không quay lại asset seed. Asset repository chỉ còn cho isolated tests/khởi tạo khi không cấu hình public loader.
- DiscoveryProvider và PlaceVisitDetailsProvider bind theo identity **version + sha256**, không chỉ version. Seed v1 và remote v1 khác hash phải thay thế toàn bộ danh mục và facts cùng nhau; repository vẫn reject same-version conflict khi current đã là remote.
- Không xóa danh mục last-known-good khi refresh lỗi; không để async asset load cũ ghi đè snapshot public mới. Giữ query/filter hiện có; kiểm tab “Tất cả” khi tìm record mới, không tự gán interests chưa được admin khai báo.

## 3. Files thực thi — hợp 22 files

Đây là allowlist đề xuất của một packet; khi owner chuyển prompt cuối tài liệu cho Antigravity là giao thực hiện hợp này. Không tự thêm file ngoài danh sách hoặc sửa permanent rules để bỏ giới hạn toàn project. Các kiểm tra/log/fixtures sinh ra nằm trong ignored `.dart_tool`, không commit build artifacts.

| # | File | Action / trách nhiệm |
|---|---|---|
| 1 | `supabase/functions/admin-publication/bundle.mjs` | Modify: normalize unverified defaults trước encode, giữ reference closure/facts. |
| 2 | `lib/features/admin/providers/admin_catalogue_provider.dart` | Modify: inject publisher, pipeline/state/generation/acknowledgement. |
| 3 | `lib/features/admin/presentation/screens/admin_shell_screen.dart` | Modify: inject service + onPublished refresh public snapshot/dashboard. |
| 4 | `lib/features/admin/presentation/screens/admin_catalogue_screen.dart` | Modify: nút Lưu/ẩn dùng pipeline; progress/error/retry message theo phase. |
| 5 | `lib/features/admin/presentation/widgets/admin_destination_form.dart` | Modify: busy qua toàn pipeline, hiển thị lỗi lưu/đồng bộ đúng từ caller. |
| 6 | `lib/features/admin/presentation/widgets/admin_place_form.dart` | Modify: cùng contract UX; không double submit hoặc đóng giả thành công. |
| 7 | `lib/features/explore/providers/public_catalogue_provider.dart` | Modify: initialize/startup/resume refresh, giữ snapshot khi offline. |
| 8 | `lib/features/explore/providers/discovery_provider.dart` | Modify: public loader, force refresh, version+hash binding và async fence. |
| 9 | `lib/features/explore/providers/place_visit_details_provider.dart` | Modify: version+hash binding, facts đi cùng snapshot mới. |
| 10 | `lib/main.dart` | Modify: initialize public provider và inject loader; dùng ProxyProviders hiện có. |
| 11 | `test/discovery_public_bundle_test.mjs` | Modify: new-place defaults, không mutate source, seed/reference regression. |
| 12 | `test/admin_catalogue_provider_test.dart` | Modify: save→preview→publish thứ tự, phase/failure/double tap. |
| 13 | `test/admin_catalogue_ui_test.dart` | Modify: publisher fixture/injection, save/ẩn chờ acknowledgement. |
| 14 | `test/admin_draft_history_test.dart` | Modify: cập nhật constructor fixture; giữ assertions của history, không mở tính năng restore mới. |
| 15 | `test/admin_catalogue_forms_test.dart` | Modify: busy/message/error theo phase; không đóng form trước publish completed. |
| 16 | `test/public_catalogue_consumers_test.dart` | Modify: Home/Explore/facts bind lại ở seed v1→remote v1/different hash. |
| 17 | `test/public_catalogue_repository_test.dart` | Modify nếu cần: first release, refresh/version progression, offline giữ cache. |
| 18 | `test/public_catalogue_provider_test.dart` | Create: initialize, resume, force refresh và local refresh lỗi. File này chưa có ở baseline. |
| 19 | `test/admin_catalogue_publish_flow_test.dart` | Create: integration actual SQL payload → Node bundle → Dart/repository/consumers; tests pipeline fixture. |
| 20 | `supabase/tests/admin_catalogue_visibility.sql` | Create: synthetic actor/session, create/update/archive, xuất JSON cases; rollback không chạm live. |
| 21 | `tool/build_catalogue_visibility_fixtures.mjs` | Create: CLI nhận JSON cases SQL, dùng actual builder/encoder tạo bundle+manifest fixtures dưới `.dart_tool`. |
| 22 | `tool/verify-flutter-admin.ps1` | Modify: Publication mode chạy SQL visibility → fixture builder → Dart flow integration, fail nếu thiếu bước/fixture. |

Các files khác như AdminPublicationService/Provider, PublicCatalogueRepository, SQL command/publication APIs được **đọc và tái dùng**; không sửa chỉ vì tiện. Nếu source mới khác baseline hoặc phát hiện một contract bắt buộc ngoài allowlist, ghi rõ file/thay đổi và tác động, không tự refactor diện rộng.

## 4. API và contract cần giữ

| Bước | API hiện có | Điều kiện trước khi qua bước sau |
|---|---|---|
| Save | `public.admin_discovery_command(p_request_id,p_expected_revision,p_command,p_reason)` | Nhận snapshot server có revision R/entityId; giữ requestId đã dùng. |
| Preview | POST `admin-publication`, contract `travelgo.admin.publication.v1`, action `preview`, request `{requestId,draftRevision:R}` | `preview.sourceRevision==R`, không blocker, chưa expired; giữ previewId/digest/expectedActiveVersion. |
| Publish | Cùng endpoint, action `publish`, request `{requestId,previewId,previewDigest,expectedDraftRevision:R,expectedActiveVersion}` | Operation `state=completed`, `sourceRevision==R`, version hợp lệ; pending/needs_retry không thành success. |
| Customer | Public manifest `discovery_release_manifest` và object `discovery-catalogue/releases/v2/<version>.json` | Kiểm hash/length/schema, ghi cache atomic rồi bind consumer. Không GET draft private bằng quyền customer. |

Không gọi `get_discovery_publication_operation` làm dependency của happy path: RPC status đó chưa có implementation ở baseline (R10 đang hoãn). Không mở lại toàn bộ worker/recovery protocol. Không upload trực tiếp/service key từ Flutter; vẫn dùng Edge server.

### Acknowledgement và lỗi

- Save chưa ack: không publish; giữ requestId khi retry command, không tự đổi ID sau timeout.
- Save đã ack nhưng preview fail/blocker: giữ snapshot R trong RAM, báo **“Đã lưu, chưa xuất bản”** và thông tin lỗi; không gửi lại create. Retry known preview failure dùng R, không đòi user nhập lại record.
- Publish trả pending/needs_retry hoặc mất acknowledgement: giữ **savedNotPublished**, không auto-loop/replay mù vì R10 chưa hoàn thiện; không báo khách đã thấy. Báo cần kiểm trạng thái/tải lại trước thao tác mới. Đây là xử lý trung thực của failure state, không yêu cầu xây crash recovery/queue trong gói demo.
- Completed đã ack: form được đóng; thông báo **“Đã lưu và xuất bản”**. Nếu refresh cùng app lỗi, giữ trạng thái completed và cảnh báo tải lại danh mục; các máy khách vẫn có thể lấy release đã active khi online.
- Backend là authority cho quyền, revision và validation. Không bỏ auth/hash/constraints để làm demo chạy. Không hứa local refresh đã hoàn tất trên mọi thiết bị.

## 5. Thứ tự triển khai và tests bắt buộc

Thực hiện liên tục, không dừng xin giao từng bước. Có thể commit theo dependency sau khi nhóm thay đổi tương ứng compile/check được; không lấy commit/task labels làm approval gate.

### Bước 1 — D3: chuẩn hóa public DTO và tạo case SQL động

- [ ] RED bằng actual createPlace payload đang thiếu list: Node builder → Dart parser lỗi list như reviewer R3.
- [ ] Normalize đúng mục 2.1; seed cũ giữ nguyên facts/24 nguồn trong fixture hiện tại. Case đã có array hợp lệ không bị viết lại; sai kiểu/reviewed facts không được âm thầm chữa thành unverified.
- [ ] SQL visibility test dùng actual RPC: lấy baseline counts/IDs; thêm destination và place; đọc lại; sửa name/image; archive place rồi parent; thu payload ở mỗi mốc. Claims/session là fixtures, role checks vẫn chạy; SQL rollback cuối cùng.
- [ ] JSON cases gồm expected IDs/counts/revisions suy từ baseline, không dùng 72 làm giới hạn. Ví dụ fixture hiện tại có thể là 13/73 trước archive.

### Bước 2 — Save tự publish và UI acknowledgement

- [ ] Inject publicationService bắt buộc trong provider và mọi constructor sites (shell + ba test fixtures đã liệt kê). Không thêm default trả completed giả.
- [ ] Lưu snapshot R rồi preview/publish đúng R. Giữ command ID, preview ID, publish ID riêng; xác minh response trước success. Preview được tạo mới cho mỗi command, không dùng global preview từ màn cũ.
- [ ] UI Lưu và nút xác nhận ẩn gọi cùng pipeline. Trong thời gian chờ, disable double tap; message phân biệt lưu và đồng bộ. Giữ callback Future<bool>; có thể thêm optional error-message getter vào forms để lấy lỗi mới nhất từ caller thay vì luôn báo “không lưu được” khi thực ra draft đã lưu.
- [ ] Tests dùng Completer giữ publish pending: form chưa đóng, chưa success, chưa refresh; completed đúng R mới success. Known preview failure không gọi publish; save failure không gọi preview; publish pending không success; retry sau save-ack không tạo trùng record.
- [ ] Auth đổi/dispose giữa await không được ghi admin data hoặc chạy onPublished cho session mới. Chỉ cần fence trong pipeline này, không mở dự án race handling toàn app.

### Bước 3 — App khách fetch và bind danh mục public mới

- [ ] Root initialize load cache/seed rồi refresh; resume và pull-to-refresh kiểm manifest mới theo mục 2.3. Same-app onPublished force refresh và cập nhật dashboard đang dùng.
- [ ] Discovery/visits bind identity version+hash. Fake network có seed v1, remote v1 khác hash: Home/Explore/detail cùng thấy destination/place mới. Lần sau remote v2 sửa/ẩn: cả ba cùng cập nhật; consumer không tự đọc asset trả dữ liệu cũ.
- [ ] Cold start có manifest mới fetch được; offline giữ last-known-good đã cache, không đánh offline là publication failure. Không dùng flags/local JSON để giả customer visibility.

### Bước 4 — Kiểm chứng xuyên lớp, không chỉ dữ liệu seed

- [ ] Harness Publication mode chạy test SQL mới và xuất stdout JSON sạch bằng psql `-A -t`/capture phù hợp; nếu thêm `Invoke-Sql -OutputJsonPath`, chỉ ghi file khi child exit0 và JSON hợp lệ. Fixture/output path nằm trong ignored run root và được truyền rõ tới các bước sau.
- [ ] CLI Node dùng **actual bundle.mjs/encodePublicBundle**, tạo cases/manifest hashes theo bytes thực; không copy serializer/mock payload khác shape server.
- [ ] Harness truyền path fixture tới `admin_catalogue_publish_flow_test.dart` bằng `--dart-define=TRAVELGO_CATALOGUE_FLOW_FIXTURE=<absolute-path>` và flag `RUN_CATALOGUE_FLOW_SQL=true`. Khi flag true mà fixture thiếu/sai JSON thì test FAIL, không skip. Full thường có thể chỉ chạy các unit tests không cần PG; lượt Publication với integration flag và no-skip là required evidence riêng.
- [ ] Dart flow test dùng actual parser/repository, mock HTTP manifest/Storage bằng bytes Node vừa tạo: created → thấy new IDs; updated → thấy thông tin mới; archived → new IDs biến khỏi active catalogue. Đồng thời đọc admin payload để chứng minh admin vẫn thấy records ẩn. Không hardcode số lượng phải luôn là 72.
- [ ] Widget/provider test chứng minh nhấn Lưu đi qua auto-publish callback tới public refresh; không chỉ tự gọi publication screen độc lập.
- [ ] D1/D2 vẫn PASS, dashboard counts thuộc bản đã publish. Existing AI tests vẫn PASS; không yêu cầu AI hỗ trợ new ID.

## 6. Verification commands và nghiệm thu

Các lệnh sau là mục tiêu sau implementation, **chưa được chạy/khẳng định PASS trong lượt lập plan**:

```powershell
node --test test/discovery_public_bundle_test.mjs test/admin_publication_gateway_test.mjs
./tool/verify-flutter-admin.ps1 -Mode Publication -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Targeted -TestPath @('test/admin_catalogue_provider_test.dart','test/admin_catalogue_ui_test.dart','test/admin_catalogue_forms_test.dart','test/admin_draft_history_test.dart','test/public_catalogue_consumers_test.dart','test/public_catalogue_provider_test.dart','test/public_catalogue_repository_test.dart','test/admin_catalogue_publish_flow_test.dart') -FlutterRoot D:/flutter/flutter
./tool/verify-travelgo.ps1 -Mode Full -FlutterRoot D:/flutter/flutter
```

Run targeted trong lúc sửa; Full một lần ở source cuối, lặp khi có thay đổi/failure cần xác minh. Giữ ba vòng RCA cho cùng vấn đề; nếu không tiến triển thì nêu root cause/checkpoint, không lặp vô hạn. Không đổi counts/checks hoặc nới assertions để bàn giao PASS. Có Dart app active thì hot reload sau Dart changes; không có thì ghi NOT RUN, không tự mở/cài/đụng bản nháp thiết bị.

**Demo acceptance:**

1. Admin tạo destination mới → Lưu → một pipeline tự publish → admin và Home/Explore khách thấy new ID sau refresh.
2. Thêm place dưới destination đó → khách mở detail thấy place mới, thông tin unverified hiển thị trung thực, không parser error.
3. Sửa tên/ảnh → lưu và refresh thấy dữ liệu mới, ID giữ nguyên.
4. Ẩn place/parent → admin vẫn thấy badge ẩn; khách không thấy record active; trip đã lưu không mất lịch sử.
5. Dashboard sau publish vẫn đọc được; seed và những records cũ còn đầy đủ facts/sources.
6. Preview/publish lỗi → không success giả, không tạo trùng record khi draft đã được ack.

Không kết luận “đã demo trên server/điện thoại” chỉ từ local tests. Gói này cho source/local synthetic verification; không tự deploy Edge, thay bucket/storage policy, apply SQL live, đổi secrets/flags/AI quota hoặc merge. Nếu cần runtime thật, hoàn tất local packet rồi đưa ra artifact/commit và concrete rollout steps cho owner; giữ NOT RUN cho bước chưa có quyền.

## 7. Handover cho Codex

Một báo cáo cuối đợt: Changed / Why / Testing / Problems / Lesson Candidate; exact base/final commits, dirty delta, file hashes, commands/exits/logs, trạng thái D3/D4, integration no-skip result và phần NOT RUN. Giải thích thao tác Lưu → command revision → publication acknowledgement → client snapshot. Không yêu cầu đóng lại R1/R4/R5/R9/R10/R11/R12 đang DEFERRED.

## Prompt copy cho Antigravity

```text
Owner giao thực hiện luồng Admin lưu → tự xuất bản → app khách nhận danh mục. Giữ Codex plan/review, Antigravity code/tests/fix. Đọc AGENTS.md, rules/workflow và docs/phase-3/ADMIN_SAVE_PUBLISH_VISIBILITY_PLAN_20261023.md. Baseline review hiện tại 363215b; kiểm actual HEAD/dirty files trước sửa.

Tôi giao trọn packet 22 files trong plan, làm liên tục theo dependency, không xin giao lại từng bước hoặc thêm calls. Không cố định 72 địa điểm. D1/D2 đã đóng; tập trung D3 public DTO của new place và D4 nối Lưu/ẩn với publication, cùng startup/resume/pull refresh và version+hash binding để Home/Explore/detail thực sự thấy dữ liệu mới.

Tái dùng command/publication APIs. Chuẩn hóa missing lists của unverified facts ở server projection theo plan, không bịa giá/giờ hoặc nới parser. AdminCatalogueProvider tự save→preview→publish revision vừa nhận; chỉ completed ack mới trả success. Draft saved nhưng publication fail phải báo đúng và không gửi lại create. Force-refresh public snapshot cùng app; khách khác fetch khi startup/resume/pull. Không yêu cầu owner mở màn Xuất bản riêng.

Viết meaningful regression actual SQL→Node→Dart cho thêm/sửa/ẩn ngoài seed, không chỉ test 72 records ban đầu. Harness Publication phải thực sự chạy integration, missing fixtures là FAIL. Giữ owner work, selective staging, không weaken assertions, thêm dependencies/native/permanent rules, deploy/live/thiết bị/merge hoặc tự bật Superpowers. Không mở lại hardening/race/history/AI mới đã hoãn.

Chạy checks theo plan, Full một lần ở source cuối. Bàn giao một báo cáo có exact commit/diff, commands/exits/logs, trạng thái D3/D4 và phần local/mock/NOT RUN để Codex review toàn luồng. Không tự khẳng định live/demo thiết bị đã đạt.
```
