# TravelGO — Scope Baseline v2 (đề xuất phê duyệt) & Master Prompt cho AI Coding Agent

> **Ngày lập:** Thứ Ba, 20/10/2026 (Asia/Ho_Chi_Minh)  
> **Deadline bản demo:** **Chủ nhật, 25/10/2026**; báo cáo với thầy trong tuần 26/10–01/11/2026.  
> **Người quyết định:** Chủ dự án TravelGO.  
> **Nguồn đầu vào:** `PROJECT_CONTEXT_AND_SCOPE_REDUCTION_20261020.md` (báo cáo hiện trạng được cung cấp ngày 20/10/2026) và quyết định scope mới nhất của chủ dự án.  
> **Trạng thái:** `PROPOSED — AWAITING BASELINE-DELTA APPROVAL`. Các **lựa chọn định hướng** dưới đây đã được chủ dự án xác nhận; những thay đổi đối với **MUST/acceptance cũ** vẫn cần phê duyệt minh thị.  
> **Loại công việc của tài liệu này:** Phân tích và soạn kế hoạch. **Chưa sửa code, config, database, repository, CI, tài nguyên production hoặc scope gốc.**

---

## 1. Tóm tắt quyết định (decision record)

| Câu hỏi | Quyết định mới nhất của owner | Diễn giải thực thi |
|---|---|---|
| Chiến lược | Giảm scope có kiểm soát | Đóng một luồng sản phẩm hoàn chỉnh; ưu tiên sửa blocker, không viết lại ứng dụng |
| AI | **AI sinh lịch trình + AI đề xuất chỉnh sửa** | Cả hai phải là chức năng thật trong phạm vi demo; mọi thay đổi có preview / Cancel / Apply; không tự ghi vào draft/cloud |
| Account & Save | **Guest local + Email Account cloud** | Guest lưu SQLite, tài khoản email lưu qua Supabase; giữ owner isolation và cơ chế xác nhận ghi |
| Rubric môn học | **Chưa xác định** | Không mặc định thầy cho phép giảm yêu cầu AI, Google, bản đồ hay thuật toán; cần xác nhận trước khi tuyên bố đáp ứng môn học |
| Nguồn lực | **4–6 giờ tập trung/ngày** | 21–25/10 = **20–30 giờ**, bao gồm QA, tài liệu và đóng gói, không phải chỉ coding |
| Artifact | **APK demo, source code, báo cáo/tài liệu** | Không tự thêm Play Store, production release, slides/video vào điều kiện hoàn thành |
| Deadline | **25/10/2026** | Freeze tính năng trước ngày giao; dành ngày 25/10 cho chốt build, kiểm tra, ghi hạn chế và rehearsal |
| Chức năng ngoài các lựa chọn trên | Theo bảng gợi ý trước | Giữ/đóng băng/hoãn như §4; **không xóa code đã chạy ổn** chỉ để bảng scope ngắn hơn |

**Điều quan trọng:** Lựa chọn AI *sinh + đề xuất chỉnh sửa* **thay thế** lựa chọn cũ *chỉ sinh lịch trình*. AI advice/chat/recommend tự do **không thuộc** bản demo được cam kết, trừ khi owner đổi quyết định bằng văn bản.

### Sản phẩm phải chứng minh điều gì?

Một người dùng có thể **khám phá điểm đến → tạo chuyến đi → nhận đề xuất lịch trình từ AI → xem trước/xác nhận → yêu cầu AI đề xuất sửa một phần → xem trước/xác nhận → sửa tay và quản lý chi phí → lưu → mở lại đúng dữ liệu**. Guest vẫn có nhánh lập, lưu và mở lại kế hoạch thủ công tại thiết bị.

**Không tuyên bố:** tối ưu lịch trình theo thời gian di chuyển thật, giờ mở cửa thật hay dự báo thời tiết thật; đã nghiệm thu mọi tính năng cũ; đã triển khai production; hay đáp ứng rubric chưa được cung cấp.

---

## 2. Hiện trạng có bằng chứng — không đồng nhất với hoàn thành

Tài liệu nguồn ngày 20/10/2026 ghi nhận:

- Client Flutter/Dart, `Provider`, Dio; Supabase Auth/PostgreSQL/RLS/RPC; SQLite local; Edge Function `itinerary-proposal` và Gemini server-side.
- Catalogue hiện có **12 điểm đến / 72 places**; có tìm kiếm, bộ lọc, chi tiết và nguồn tham chiếu. Mọi destination trong asset đang `routingReady=false`; các itinerary sample chưa `feasibility_verified`.
- Manual planner, budget estimates/actual, Guest draft, Account save/list/reopen và AI proposal/modify đã có source và **một số** bằng chứng native/emulator.
- Log đã đọc trước đó: `flutter analyze` **No issues**, Flutter **766 PASS**, Node contracts **89 PASS**. Đây là **evidence lịch sử**, chưa chạy lại khi tạo file này.
- Các ca C2/D3 cập nhật về interrupted-cold, stale-version conflict và reply-loss retry có evidence theo build/case cụ thể; **không làm Phase 3.2 thành ACCEPTED**. Trạng thái toàn phase là **PARTIAL / NOT ACCEPTED**.
- Checkout được báo cáo đang ở branch `codex/phase-3-discovery-design`, working tree **dirty**; HEAD không chứa toàn bộ trạng thái đang chạy. Coding Agent phải kiểm tra lại, không tự reset/clean hoặc stage ngoài phạm vi.

**Quy tắc evidence:** phân biệt `SOURCE_PRESENT`, `TEST_PASS`, `NATIVE_PASS`, `PARTIAL`, `NOT_TESTED`, `DEFERRED`, `BLOCKED`. Không gán `DONE` chỉ vì có widget/source hoặc vì phạm vi đã cắt giảm.

---

## 3. Ranh giới MVP demo 25/10

### 3.1. Năm module bắt buộc trong demo

1. **Discovery** — duy trì danh sách 12 điểm đến đang có, tìm kiếm/chọn điểm đến, xem chi tiết/nguồn; chỉ tập trung dữ liệu demo sâu **01 điểm đến (ưu tiên Huế)**. Nếu fixture Huế hiện không ổn, chọn **Hà Nội** từ catalogue có sẵn và ghi thay đổi; không thêm dữ liệu đại trà.
2. **Planner** — nhập chuyến đi 2–3 ngày; tạo, thêm/sửa/xóa/đổi thứ tự hoạt động thủ công; preview và xác nhận; không mở editor hoặc engine planner thứ hai.
3. **AI** — (a) **Generate**: gọi Edge Function/Gemini thật để đưa ra *proposal*; (b) **Modify proposal**: AI đề xuất chỉnh một hoạt động/ngày của draft hiện hành. Cả hai đều phải **preview → Cancel hoặc Apply**, Apply không tự save cloud; khi lỗi/quota hết, manual vẫn sử dụng được.
4. **Budget** — giữ estimated và actual riêng biệt, hiển thị tổng/còn lại/vượt; thay đổi itinerary không xóa hoặc tự ghi đè `actualExpenses`.
5. **Account & Storage** — Guest draft SQLite và reopen sau restart; email/password Account cloud save/list/open/update; owner isolation giữa A/B/Guest, retry không ghi trùng, stale version không ghi đè bản mới.

**Security/data integrity là điều kiện xuyên suốt**, không phải tính năng được phép bỏ để kịp ngày: RLS/owner guard, auth lifecycle, consent, idempotency, baseVersion, dữ liệu local theo chủ sở hữu, bí mật chỉ giữ phía server.

### 3.2. Những giới hạn cụ thể

- **Platform giao:** Android APK dùng environment staging đã có; không hỗ trợ mới iOS/web/desktop; không production/Play Store.
- **Demo fixture:** 01 điểm đến, 2–3 ngày, 1–2 khách, hoạt động nằm trong catalogue và chi phí **ví dụ do người dùng nhập**; không biến giá mẫu thành giá vé thực tế.
- **AI demo:** ưu tiên **Account email** vì Guest live AI chưa có nghiệm thu đầy đủ; Guest vẫn tạo/lưu manual bình thường. Guest AI entitlement/quota gốc **chưa tự thay đổi** và cần quyết định ở bảng delta.
- **Dữ liệu vận hành:** thiếu giờ mở cửa, giá, thời gian di chuyển, tọa độ hoặc route phải ghi `unknown`/`estimated`/`not verified`, không mặc định 0, miễn phí, mở cả ngày, hay khả thi đã xác minh.
- **Map/weather:** giữ màn hình hiện hữu nếu không gây lỗi, nhưng không cam kết route tối ưu/forecast ràng buộc AI; không mở rộng 72 places.
- **Offline:** Guest draft vẫn lưu local theo hành vi hiện có; Account offline chỉ xem snapshot đã cache *nếu* quyền hợp lệ, không hứa offline edit/sync cloud.
- **V1:** không xóa hay migrate dữ liệu cũ hàng loạt; giữ đường đọc hiện hữu, không cam kết mở rộng import/copy/migration trong sprint.
- **Visual/UI:** không refresh toàn app; chỉ sửa crash, thao tác bị chặn hoặc thông tin đánh lừa người dùng.

---

## 4. Bảng KEEP / FREEZE / DEFER / DROP cho sprint

**Định nghĩa:** `KEEP` = hoàn thiện/kiểm thử trong cam kết 25/10. `FREEZE` = giữ hành vi đang có, không phát triển thêm; chỉ fix lỗi chặn luồng. `DEFER` = hoãn công việc/acceptance còn mở, **không đồng nghĩa xóa source**. `DROP NEW WORK` = không khởi tạo feature mới trong sprint. Thời lượng ước tính dưới đây là *mức ưu tiên*, không phải kết quả đo.

| Feature/khối | Trạng thái sprint | Phạm vi cụ thể và lý do | Tác động baseline |
|---|---|---|---|
| Discovery + search/detail/source | **KEEP (P0)** | Reuse 12 điểm đến, kiểm một fixture demo; không thêm địa điểm | Có thể giảm acceptance của sample DIS004 |
| Manual planner V2 | **KEEP (P0)** | Một editor, edit/delete/reorder, preview, không mất input | Giữ core MUST |
| AI **Generate** | **KEEP (P0)** | Gọi thật, parse/validate, preview/Cancel/Apply, fallback manual | Giữ một AI MUST |
| AI **Modify proposal** | **KEEP (P0)** | Đề xuất sửa trên draft, human confirmation, apply đúng một lần | Giữ chức năng AI sửa có xác nhận |
| Budget estimate/actual | **KEEP (P0)** | Tổng đúng; actual không mất sau AI/manual changes | Giữ core MUST |
| Guest local save/reopen | **KEEP (P0)** | Từ SQLite sau app restart, không chỉ RAM | Giữ core MUST |
| Email Account cloud save/list/reopen | **KEEP (P0)** | RPC acknowledgement, owner/version/isolation/retry | Giữ core MUST |
| Security/session/data ownership | **KEEP — NON-NEGOTIABLE** | Không lộ A/B/Guest, không duplicate/overwrite, không leak secrets | Không giảm |
| Profile và preferences hiện có | **FREEZE (P1)** | Giữ state/persistence; không thêm settings hay UI mới | Giảm độ sâu QA nếu baseline yêu cầu full matrix |
| Google Sign-In | **FREEZE + DEFER ACCEPTANCE** | Để code như hiện có; không thuộc live demo chính | **ACC003: cần owner duyệt** |
| Favorites/Home/UI polish | **FREEZE (P2)** | Không làm refresh/voucher/trang mới | SHOULD/UI không mở rộng |
| Day map / trip map / radar cũ | **FREEZE**, phần tích hợp mới **DEFER** | Không phát triển routing, tọa độ, tile/data coverage | SHOULD hoãn |
| AI Advice/Chat contextual | **DEFER** | Không cam kết hội thoại trong bản demo | **AI baseline: cần owner duyệt** |
| AI Recommendations tự do | **DEFER** | Không cam kết mode gợi ý hoạt động độc lập | **AI baseline: cần owner duyệt** |
| AI sử dụng live weather/hours/routes | **DEFER** | Không ngụy tạo năng lực tối ưu vận hành thật | **FR-AI-005: cần owner duyệt** |
| Guest live AI + quota acceptance rộng | **DEFER ACCEPTANCE** | Demo AI bằng email account, Guest manual | **FR-AI-007: cần owner duyệt** |
| 12 sample itinerary verified | **DEFER** | Mẫu chưa xác minh tiếp tục pending/unavailable | **DIS004: cần owner duyệt** |
| Guest→Account import mở rộng | **DEFER ACCEPTANCE** | Không phá đường có sẵn; không hứa import trong demo | **MUST cũ: cần owner duyệt** |
| V1 migrate/copy và acceptance đầy đủ | **DEFER** | Giữ khả năng đọc đang có; không rewrite dữ liệu | **Nếu là MUST/rubric: cần duyệt** |
| Community/collaboration/Weather integration | **DEFER** | Không tạo social/group/live weather mới | SHOULD hoãn |
| Automatic planner cũ / MCDA-Pareto-Greedy | **FREEZE**, phát triển mới **DEFER** | Không gọi engine là chạy thật khi không có backend evidence | Có thể ảnh hưởng đề tài/rubric; xác nhận thầy |
| Booking/payment/push/store rollout | **DROP NEW WORK** | Không nằm trong demo; vốn đã deferred | Không tạo yêu cầu mới |

> **Không xóa feature ổn định cho “gọn code”.** Cắt **cam kết/độ rộng nghiệm thu và phần việc mới**, không cắt an toàn dữ liệu. Nếu code của chức năng hoãn chặn demo, agent được phép đề xuất **ẩn entry point bằng cơ chế sẵn có** sau phê duyệt; không phá behavior/contract đang chạy.

---

## 5. Baseline MUST/acceptance cần phê duyệt thay đổi

**Đây là danh sách yêu cầu owner phải ký duyệt riêng trước khi agent coi v2 là baseline chính thức.** Các ID bên dưới chỉ dùng khi đã được nêu trong file nguồn; tên/ánh xạ ID của các yêu cầu AI khác cần agent đối chiếu `docs/phase-1/FUNCTIONAL_REQUIREMENTS.md` thay vì suy diễn.

| ID hoặc cam kết cũ | Baseline Phase 1 | Scope v2 đề xuất | Trạng thái quyết định |
|---|---|---|---|
| **ACC003 — Google Sign-In** | MUST | Không có trong demo chính; giữ source, ghi `PARTIAL/DEFERRED`, không tuyên bố PASS | **PENDING OWNER APPROVAL** |
| **Guest→Account draft import** | MUST | Hoãn nghiệm thu import/migration; không xóa hoặc phá luồng hiện có | **PENDING OWNER APPROVAL** |
| **DIS004 — lịch trình mẫu** | MUST | Không xác minh đủ 12 samples; chỉ dùng fixture hiện có kèm trạng thái chưa xác minh | **PENDING OWNER APPROVAL** |
| **AI Chat/Advice/Recommendations** | MUST theo bản AI đa mode | Không cam kết chạy/demo/QA hai mode này; giữ source hiện có | **PENDING OWNER APPROVAL** |
| **AI Generate + Modify** | Thuộc AI MUST | **Vẫn KEEP**; cả hai cần evidence live, preview và apply/cancel | **OWNER SELECTED**; nghiệm thu chưa xác nhận |
| **FR-AI-005** | AI xét dữ liệu vận hành (hours/route/weather) | Hoãn full integration; `unknown` không đồng nghĩa PASS | **PENDING OWNER APPROVAL** |
| **FR-AI-007 — Guest AI/quota** | Guest entitlement & quota theo baseline | Demo AI bằng Account; Guest manual. **Không tự đổi server policy/quota** | **PENDING OWNER APPROVAL** |
| **TRP006 — offline snapshot** | Chỉ đọc cache theo giới hạn quyền | **Giữ đúng contract đã mô tả**, không mở offline sync mới; test subset thay vì full matrix | Contract **UNCHANGED**; thay acceptance: **PENDING nếu áp dụng** |
| **V1 compatibility/copy/migration** | Tương thích theo contracts cũ | Giữ đọc có sẵn; hoãn variant nâng cấp/copy chưa nghiệm thu | **PENDING nếu đây là MUST** |
| **55 AC / E01–E12 / PHONE01–04 và ma trận cũ** | Full acceptance trước đây | Dùng DoD demo hẹp (§7) và gap ledger riêng; **không tự đánh dấu old AC PASS** | **PENDING OWNER APPROVAL** |
| **RLS, isolation, receipt, idempotency, actual preservation, consent** | Core MUST | **Không thay đổi, không miễn trừ** | **LOCKED** |

**Điều kiện phê duyệt:** Chủ dự án cần nêu rõ: “Tôi phê duyệt Scope Baseline v2 và các delta tại §5 cho bản demo 25/10/2026; các MUST cũ ngoài phạm vi phải ghi PARTIAL/DEFERRED, không coi là PASS.” Đây chỉ là mẫu câu duyệt, **không phải sự phê duyệt đã xảy ra**. Nếu rubric của thầy yêu cầu mục bị hoãn, owner phải chọn bổ sung phạm vi hoặc xin điều chỉnh kỳ vọng/hạn giao.

### Những điều vẫn chưa rõ (Open Questions)

1. **Rubric/thầy:** có bắt buộc live AI theo nhiều mode, Google Login, thuật toán MCDA, map hay xuất bản app không? **Chưa được xác nhận.**
2. **AI Modify runtime:** source/emulator đã có happy path nhưng cần agent xác minh endpoint, cấu trúc proposal, cách Apply và quota trên bản build cuối.
3. **Thiết bị cuối:** emulator và DNY có còn sẵn để native QA/đối chiếu đúng APK hay không? Không được bịa `PASS` nếu không thể chạy.
4. **Tình trạng staging/quota:** vẫn dùng cấu hình hợp lệ đang có; không tự nâng plan, tăng billing, đổi policy hoặc deploy.

---

## 6. Kịch bản demo chính và nhánh lỗi

### 6.1. Một hành trình demo chính — **Account email / 01 điểm đến**

**Dữ liệu giả lập hợp lệ để nhập UI:** tài khoản test staging được owner cho phép; Huế (fallback Hà Nội nếu source có blocker); 2 ngày, 2 người; ngân sách ví dụ do người dùng nhập; điểm tham quan chọn từ catalogue. Dữ liệu giá/giờ mở cửa không được gọi là đã xác minh nếu chưa có nguồn.

| Bước | Thao tác trên app | Điều cần quan sát |
|---|---|---|
| 1 | Đăng nhập Email Account và vào Discovery | Hiển thị đúng chủ sở hữu và danh sách có tìm kiếm |
| 2 | Chọn Huế (hoặc fixture đã chốt) | Detail/source đúng và có nút tạo chuyến đi |
| 3 | Tạo draft 2 ngày + ngân sách | Input giữ nguyên khi chuyển màn |
| 4 | Yêu cầu **AI Generate** | Có call server thật; proposal parse được; Cancel không đổi draft; thử lại và Apply đúng một lần |
| 5 | Yêu cầu **AI Modify** một hoạt động/ngày | Chỉ đưa ra patch/proposal, có preview thay đổi; Cancel không mutate; Apply một lần đúng mục tiêu |
| 6 | Sửa tay một hoạt động | Draft/timeline cập nhật, không mất ngày/budget |
| 7 | Nhập ít nhất 1 estimated và 1 actual expense | Tổng/còn lại/vượt đúng; actual không bị mất khi edit |
| 8 | Save cloud, thoát/mở lại từ danh sách chuyến đi | Phải có acknowledgement; server readback đúng owner/version, không phải chỉ từ RAM |

**Nhánh Guest phụ bắt buộc kiểm tối thiểu:** mở Guest → tạo/sửa draft thủ công → lưu SQLite → restart app → mở lại chính draft. **Không** demo Guest AI như đã hỗ trợ nếu entitlement live chưa được xác minh/phê duyệt.

### 6.2. Một nhánh lỗi có chủ đích

Mô phỏng điều kiện AI bị từ chối hợp lệ (ví dụ quota/timeout bằng cơ chế QA sẵn có **nếu được phép và không ảnh hưởng production**) → app thông báo rõ → draft và actual không đổi → người dùng tiếp tục sửa và lưu manual. **Không** dùng fixture/fallback giả làm phản hồi Gemini thật. Không tự bật QA fault hook trong APK bàn giao.

### 6.3. Những câu cần nói rõ lúc báo cáo

- “AI đề xuất và người dùng xác nhận; ứng dụng không tự chỉnh sửa hoặc tự lưu chuyến đi.”
- “Lịch trình và các chi phí chưa đủ dữ liệu vận hành có nhãn ước tính/chưa xác minh.”
- “Bản nộp tập trung Android, một luồng hoàn chỉnh; Google, AI chat/recommend, routing và community thuộc backlog/limitation.”
- “Các test và bằng chứng native có ngày/build xác định; toàn bộ Phase 3.2 cũ chưa được khẳng định nghiệm thu.”

---

## 7. Definition of Done (DoD) cho bản demo v2

Dùng trạng thái `[ ]` để theo dõi; **đừng tick chỉ vì code có sẵn**. Mỗi mục phải có test/log/native/screenshot/notes tương ứng trên build cuối hoặc ghi giới hạn chính xác.

| ID | Mức | Điều kiện chấp nhận | Evidence tối thiểu |
|---|---|---|---|
| V2-01 | P0 | App Android mở/điều hướng 5 module không crash ở luồng chọn | APK + native smoke |
| V2-02 | P0 | Search/chọn fixture Discovery đúng destination | Native smoke và source/asset đối chiếu |
| V2-03 | P0 | Manual draft 2 ngày, edit/delete/reorder/preview không mất input | Test trọng yếu + native |
| V2-04 | P0 | **AI Generate thật**; preview; Cancel = không đổi; Apply = đổi draft một lần | Live staging response + native, che context nhạy cảm |
| V2-05 | P0 | **AI Modify thật**; proposal đúng draft; Cancel không đổi; Apply đúng 1 lần | Live staging response + native + assertion state |
| V2-06 | P0 | AI error/quota không mất draft/actual, manual dùng bình thường | Targeted negative + native/QA an toàn |
| V2-07 | P0 | Estimates và actual tách biệt; total/balance đúng; sửa trip không làm mất actual | Test + native fixture |
| V2-08 | P0 | Guest save → restart → reopen đúng từ local persistence | Native từ ổ đĩa, không chỉ RAM |
| V2-09 | P0 | Email Account save/list/reopen/update có server ack/version đúng | Native server readback |
| V2-10 | **BLOCKER** | Không lộ dữ liệu A/B/Guest; cold/resume/logout đúng owner | Native subset + tests; không tự bỏ guards |
| V2-11 | **BLOCKER** | Retry reply-loss không tạo trùng; stale version conflict không ghi đè; AI không auto-save | Regression có tái hiện hoặc evidence phù hợp build |
| V2-12 | P1 | Snapshot đã cache đọc offline theo quyền; chưa cache báo unavailable | Chạy nếu thiết bị/kênh QA cho phép; thiếu phải ghi `NOT_TESTED`, không gọi PASS |
| V2-13 | P0 | Analyzer sạch, full Flutter tests và Node contracts đạt trên source chốt | Exit code, logs, không skip assertions; ghi test bị blocker |
| V2-14 | P0 | APK chạy từ đúng source + env staging + ABI tương thích; QA hooks không bật | Path, SHA256, build mode, package/app id, install/smoke evidence |
| V2-15 | P0 | Có source handover và báo cáo giới hạn; demo script chạy lại được | Files, README ngắn, known issues, test matrix |

**Blocker giao bản “hoàn thành”:** crash luồng chính; report lưu thành công mà server/local không có dữ liệu; mất draft/actual; cross-account data leak; duplicated write; stale overwrite; AI mutates/saves không xác nhận; giả dữ liệu nguồn chưa xác minh thành live; AI Generate/Modify đã chọn mà không có evidence thực tế. Nếu không sửa được trước 25/10, **giao partial với gap rõ**, không tự đổi định nghĩa DONE.

**Không phải blocker khi đã ghi đúng limitation:** hình ảnh phụ thiếu, căn lề nhỏ, module hoãn, thiếu độ phủ dữ liệu toàn 12 điểm đến hoặc live routing chưa triển khai.

---

## 8. Lịch tối giản 21–25/10 (4–6h/ngày, tổng 20–30h)

| Ngày | Đầu ra tối thiểu | Phân bổ gợi ý | Gate cuối ngày |
|---|---|---|---|
| **T4 21/10** | Phê duyệt delta; audit worktree + config; chốt fixture, backlog P0, xác nhận đường chạy của 2 AI mode | 1h quyết định, 2–3h audit/smoke, 1–2h buffer | Có baseline phê duyệt và ít nhất một đường demo chạy được; chưa tự code nếu chưa có lệnh triển khai |
| **T5 22/10** | Chốt Discovery → Manual → Budget → Guest/Account Save → Reopen; fix đúng blocker có tái hiện | 3–4h core, 1h targeted tests, 0–1h buffer | Không mất draft/actual; đúng ack và owner |
| **T6 23/10** | Chốt **AI Generate + AI Modify**, Cancel/Apply, error/quota/manual fallback | 3–4h AI, 1h negative smoke, 0–1h buffer | Cả hai mode có evidence thật hoặc báo ngay `BLOCKED`, không giả PASS |
| **T7 24/10** | Full analyzer/tests/contracts, native smoke emulator + DNY (nếu có), security/retry/conflict trọng yếu; fix regression cuối | 2h suite, 2–3h native/fixes, 0–1h buffer | Có packet source/log nhất quán; không có release blocker chưa xử lý |
| **CN 25/10** | **Freeze**, build APK cuối, SHA256, run-demo, source snapshot/handover + report ngắn | 2h build/QA, 1–2h docs/evidence, 1–2h buffer | Giao 3 artifact; nói rõ `DONE/PARTIAL/BLOCKED/DEFERRED` và known limitations |

**Nguyên tắc ứng phó:**

- Nếu **21/10** rubric chưa rõ, giữ scope là bản demo *có điều kiện*; không tự công bố đáp ứng toàn bộ đồ án.
- Nếu **23/10** AI thật chưa chạy do quota/config/provider, không tăng billing, sửa quota/server policy hoặc tạo mock giả. Owner quyết định đổi scope hoặc chấp nhận `PARTIAL`; **hai AI mode vẫn là mục tiêu đã chọn**.
- Nếu **24/10** save, owner isolation hoặc actual preservation còn lỗi, dừng polish/map/chat; xử lý blocker trước, kể cả phải ghi demo chưa hoàn thành.
- **25/10** không mở tính năng mới. Chỉ sửa blocker, chạy lại những test bị ảnh hưởng, đóng gói và bàn giao.

### Ưu tiên cố định nếu thời gian thiếu

`P0 integrity + save` > `P0 AI Generate + Modify` > `P0 manual/budget/discovery` > `native evidence + APK` > `documentation` > `P1 offline subset` > `P2 polish`.

Tài liệu/báo cáo là artifact bắt buộc nên không được bỏ hoàn toàn; chỉ giảm độ dài tài liệu chứ không giấu limitation.

---

## 9. Năm việc dừng ngay / năm việc phải hoàn tất

**DỪNG:** (1) thêm điểm đến/place/ảnh hàng loạt; (2) làm map routing/weather/radar/community mới; (3) mở thêm AI advice/chat/recommend/agent tools; (4) nâng dependency/đổi framework/refactor Auth/Sync hoặc dựng backend mới; (5) polish toàn app, Play Store/production/billing/feature flag mới không cần thiết.

**HOÀN TẤT THEO THỨ TỰ:** (1) xác nhận baseline delta và smoke core; (2) không mất dữ liệu trong Guest + Account save/reopen, owner isolation, conflict/retry; (3) AI Generate + Modify với preview/Cancel/Apply thật; (4) analyzer/tests/native evidence phù hợp source cuối; (5) APK + source handover + báo cáo trạng thái/giới hạn.

---

## 10. Ba artifact bắt buộc và nội dung bàn giao

| Artifact | Nội dung tối thiểu | Không tự làm |
|---|---|---|
| **APK demo** | Bản Android staging chạy được; đúng ABI/build; filename/path, SHA256; không bật QA hook; có hướng dẫn cài, test account do owner tự giữ | Play Store, production rollout, nâng billing |
| **Source code** | Checkout/revision hoặc danh sách changed files + hướng dẫn build/reproduce, diff phạm vi task; tách file owner/untracked không liên quan | `git clean/reset`, stage/commit/push/merge khi chưa được giao quyền |
| **Báo cáo/tài liệu** | Tóm tắt mục tiêu, kiến trúc 1 trang, 2 AI modes, luồng demo, bảng chức năng v2, test evidence, screenshots nếu có, blockers/limitations, gap với baseline cũ | Tuyên bố FULL ACCEPTED hoặc dữ liệu đã verified khi chưa có evidence |

**Artifact evidence nên gom:** `scope decision + source revision + build config (không secrets) + analyzer/test exits + native QA notes + APK SHA256 + limitation ledger`.

---

## 11. Master Prompt — đưa trực tiếp cho AI Coding Agent

> **Cách dùng:** Copy nguyên khối dưới đây. Chế độ mặc định **READ-ONLY AUDIT / PLAN**. Chỉ sau khi owner **phê duyệt §5** và gửi **lệnh triển khai rõ ràng** thì agent mới được sửa code. Tài liệu này tự nó **không cấp quyền** deploy/merge/db/config/billing hay sửa rules.

```text
BẠN LÀ AI CODING AGENT CHO DỰ ÁN TRAVELGO ANDROID.

BỐI CẢNH & NGUỒN CHÂN LÝ
- Đọc file TRAVELGO_SCOPE_BASELINE_V2_20261020.md này từ đầu đến cuối.
- Đối chiếu repo thực tế trước mọi khẳng định về runtime; đặc biệt AGENTS.md,
  .agent/rules.md, .agent/workflow.md, docs/phase-1/FUNCTIONAL_REQUIREMENTS.md,
  docs/phase-3/* và các log/evidence liên quan.
- Tài liệu nguồn PROJECT_CONTEXT_AND_SCOPE_REDUCTION_20261020.md là snapshot
  ngày 20/10/2026, KHÔNG chứng minh code hiện tại hoặc acceptance toàn phase.
- Scope mới là DEMO ANDROID đến 25/10/2026, nguồn lực owner 4–6h/ngày.
- Owner chọn AI GENERATE + MODIFY PROPOSAL; Guest local + Email Account cloud.
- Rubric môn học chưa có. Không giả định yêu cầu cũ đã được hủy.

QUYỀN HẠN & GATES
1) MODE MẶC ĐỊNH = READ_ONLY. Kiểm tra status/log/source, lập kế hoạch,
   bản đồ affected FR/AC, risk, test plan. KHÔNG sửa bất kỳ file nào.
2) CHỈ chuyển MODE = IMPLEMENT sau lệnh triển khai riêng của owner VÀ sau khi
   owner phê duyệt các baseline deltas tại §5 (hoặc giới hạn triển khai không
   phụ thuộc delta đó); yêu cầu được giao phải chỉ ra work packet cụ thể.
3) KHÔNG tự coi tài liệu này là permission thay đổi MUST, policy, quotas,
   secrets, server/deploy, schema, billing, permanent rules, branch, Git history.
4) KHÔNG reset/clean/stash đè dữ liệu/stage bulk, không xóa file ngoài task,
   không tự commit/push/merge/deploy. Worktree có thể đang dirty.
5) Nếu rule repo hoặc approval gate mâu thuẫn: STOP và báo rõ xung đột; không
   viện deadline để bypass. Không dùng subagents/superpowers nếu owner chưa yêu cầu.

SCOPE IMPLEMENT (KHI ĐƯỢC PHÉP)
P0: Discovery reuse 12 destinations nhưng deep-demo 01 fixture; manual V2;
AI Generate thật; AI Modify proposal thật; explicit preview/Cancel/Apply;
estimate + actual budget; Guest SQLite save/reopen; Email Account Supabase
save/list/reopen; auth lifecycle/RLS/owner isolation/idempotency/stale version.
AI Modify chỉ apply lên draft sau xác nhận, không auto-write cloud; tránh
apply lặp. Mọi thay đổi itinerary giữ actualExpenses nguyên vẹn.
Nếu AI lỗi hoặc quota hết, báo lỗi rõ và manual vẫn hoạt động; không fake live.
FREEZE: Google, Profile expansion, Home/Favorites visual, maps hiện hữu,
legacy planner engine, code các AI modes khác.
DEFER: AI advice/chat/recommend độc lập, FR-AI-005 full operational feed,
Guest live AI acceptance, sample verification 12 places, guest->account
import/migration expansion, V1 copy variants, weather/radar/group/community,
routing optimizer, booking/payment, multi-platform/store release.
Việc hoãn KHÔNG cho phép xóa code hoặc đánh dấu old MUST/AC là PASSED.

ENGINEERING INVARIANTS
- Reuse Flutter, Provider, Dio, Supabase, SQLite, Edge Function hiện tại;
  không rewrite Auth, sync, backend hoặc cập nhật package vì tiện tay.
- Gemini API/credentials chỉ ở server; không in secrets, tokens hay thông tin
  riêng tư vào prompts, logs, patches hoặc báo cáo.
- Respect RLS, owner/epoch/session, version/receipt, retry idempotency.
- Preview/Cancel/Apply phải có test: Cancel = no mutation,
  Apply = exactly-once intended draft mutation, Save = explicit separate action.
- Giữ nhãn unknown/estimated/unverified; không gán giờ mở cửa, khoảng cách,
  giá vé, route hay forecast không có evidence.
- Không đổi assertions/test để tạo PASS; không che thất bại.
- Sửa đúng bug có tái hiện; mỗi patch nhỏ, diff riêng, targeted regression.

WORKFLOW THEO GATE
GATE 0 (READ_ONLY):
A. Báo current branch, HEAD, git status tóm tắt, các file dirty/untracked
   thuộc owner cần bảo vệ, môi trường staging/thiết bị sẵn có (không đọc secret).
B. Trace 01 luồng: email login -> discovery -> draft -> AI generate preview/
   cancel/apply -> AI modify preview/cancel/apply -> manual/budget -> save/
   reopen. Trace riêng Guest local save/reopen.
C. Map requirement IDs thật với bảng §5; ghi ID không tra được là UNKNOWN,
   không tự invent. Đánh dấu KEEP/FREEZE/DEFER, điểm MUST cần phê duyệt.
D. Đối chiếu source, tests và NATIVE evidence đang có; nêu rõ cái nào chỉ là
   log 20/10, cái nào đã chạy mới. Đề xuất tối đa 3 work packets P0, ước lượng
   theo 20–30 giờ tổng, nêu dependency/risk và exact DoD của mỗi packet.
E. Trả kết quả AUDIT / PLAN cho owner. DỪNG ở đây, chờ quyền triển khai.

GATE 1 (IMPLEMENT — ONLY IF EXPLICITLY AUTHORIZED):
- Chỉ làm work packet được giao; đọc/tuân thủ AGENTS/rules/workflow.
- Trước mỗi patch nêu file ảnh hưởng, invariant, bước test.
- Không mở feature mới. Giữ nguyên file ngoài task và dirty changes của owner.
- Test targeted liên quan, rồi full analyzer/Flutter/Node contract theo helper
  tool/verify-travelgo.ps1 nếu phù hợp; kiểm exit code, không đoán PASS.
- Native smoke trên emulator và DNY nếu có; nếu thiếu, ghi NOT_TESTED.
- Không yêu cầu QA destructive reset/uninstall/clear data của owner.
- Chỉ dùng staging/config hợp lệ; không tự deploy hoặc thay quota/billing.

GATE 2 (HANDOVER — BEFORE DEMO):
- Đóng băng thay đổi; build Android APK đúng ABI/staging không QA fault hooks.
- Báo artifact path, SHA256, source revision + phạm vi diff; nếu chưa chạy được
  phải ghi rõ BLOCKED và lý do, không dựng evidence.
- Bàn giao: feature status, DoD V2-01..15, old-MUST delta status, tests/run
  times, native steps và kết quả, known issues, reproduction, limitations,
  demo steps, backup/fallback manual.
- KHÔNG tự push/merge/ship. Owner là người review và quyết định.

OUTPUT FORMAT MỖI LẦN TRẢ LỜI
1. Mode & authorization status (READ_ONLY / IMPLEMENT-APPROVED).
2. Source/evidence mới đã đọc hoặc chạy (phân biệt historical).
3. KEEP / DEFER mapping & MUST delta nào còn pending.
4. Changes (file path + lý do) hoặc, trong READ_ONLY, đề xuất changes.
5. Tests: command, exit, kết quả; native evidence cụ thể theo build.
6. Risks/blockers + decision cần owner.
7. Next smallest work packet (không tự thực hiện khi chưa được phép).

STOP CONDITIONS
- Mất actual/draft, lộ dữ liệu A/B/Guest, duplicate write, stale overwrite,
  AI tự mutate/save, làm giả dữ liệu khả thi/live, mismatch source/build,
  yêu cầu tăng quota/billing/secrets/deploy hoặc phạm vi mâu thuẫn rubric.
- STOP, mô tả tình huống/impact, phương án an toàn, chờ owner ra quyết định.
```

---

## 12. Owner approval checklist — CHƯA PHÊ DUYỆT

- [ ] Tôi xác nhận **25/10/2026** là deadline khóa demo, không phải bảo đảm đã đáp ứng rubric của thầy.
- [ ] Tôi phê duyệt đổi phạm vi demo của **ACC003 Google**, **DIS004 12 samples**, **AI Advice/Recommendations/Chat**, **FR-AI-005**, **FR-AI-007 Guest live**, **Guest→Account import**, và ma trận acceptance cũ như bảng §5; các mục hoãn vẫn ghi `DEFERRED/PARTIAL`, **không** ghi `PASS`.
- [ ] Tôi xác nhận **AI Generate + AI Modify** đều **KEEP P0**, cần AI thật + preview/Cancel/Apply, không hạ chuẩn bảo toàn dữ liệu.
- [ ] Tôi đồng ý các chức năng **FREEZE/DEFER** được giữ source, không tự xóa hoặc rewrite.
- [ ] Tôi hiểu nếu rubric thầy bắt buộc feature đã hoãn, cần đổi scope hoặc thống nhất lại hạn/tiêu chí.
- [ ] Tôi **chưa** cấp quyền sửa code/deploy/database/push/merge bằng file này; các work packet coding sẽ được giao riêng.

**Mẫu tin nhắn phê duyệt phù hợp (owner gửi sau khi xem):**

> Tôi phê duyệt Scope Baseline v2, bao gồm các delta ở mục 5, chỉ cho bản demo học thuật Android ngày 25/10/2026. Các MUST cũ hoãn phải ghi DEFERRED/PARTIAL, không coi là PASS. Tiếp tục Gate 0 audit read-only và trình tôi work packets; chưa sửa code.

Khi đã đọc Gate 0 và muốn coding thật, owner cần gửi **lệnh triển khai một work packet cụ thể**, phạm vi file/điều kiện test, và mọi quyền ngoại lệ nếu có. Không suy diễn từ việc gửi file.

---

## 13. Quy tắc cập nhật tài liệu v2 trong 5 ngày

- Chỉ cập nhật danh sách tasks theo evidence mới: `TODO / IN_PROGRESS / PASS / PARTIAL / BLOCKED / DEFERRED / NOT_TESTED` với ngày + build + link/path log.
- Nếu phát sinh rubric, ghi **decision change** rõ ràng; không chỉnh sửa ngầm cam kết cũ.
- Nếu test mới phủ định evidence trước, ưu tiên evidence mới đúng source/build và mô tả vì sao.
- Nếu 25/10 chưa đạt một P0/Blocker, tên bản giao là **TravelGO Demo — Partial**, kèm gap; không làm báo cáo đánh tráo “hoàn thành Phase 3.2”.

**Phạm vi file này:** tài liệu định hướng và hợp đồng giao việc có điều kiện cho AI Agent; **không phải báo cáo nghiệm thu, không phải lệnh triển khai**.
