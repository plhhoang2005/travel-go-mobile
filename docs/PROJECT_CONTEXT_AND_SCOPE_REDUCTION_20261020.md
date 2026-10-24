# TravelGO — Hồ sơ hiện trạng và đề xuất thu gọn phạm vi để hoàn thành tuần sau

> Ngày tổng hợp: **20/10/2026**, giờ Việt Nam. Bằng chứng mới nhất đã đọc: báo cáo nghiệm thu cập nhật khoảng **15:38** cùng ngày.
> Người nhận: chủ dự án và ChatGPT web. Tài liệu này có thể đọc độc lập, không cần truy cập repository hoặc các cuộc chat trước.
> Mục đích: hiểu dự án đang có gì, còn thiếu gì, vì sao phạm vi lớn và quyết định một bản giao nhỏ nhưng hoàn chỉnh.
> Trạng thái: **báo cáo hiện trạng + phương án đề xuất**. Chưa sửa sản phẩm, chưa chính thức thay baseline MUST, chưa nghiệm thu toàn dự án.

## 1. Kết luận điều hành

TravelGO đã có lượng triển khai đáng kể: khám phá điểm đến, lập lịch trình thủ công, ngân sách dự kiến/thực tế, lưu bản nháp, lưu tài khoản, kiểm soát quyền riêng tư và các thao tác AI thật. Vì vậy, hướng khả thi để hoàn thành tuần sau là **đóng một luồng sử dụng xuyên suốt dựa trên những gì đã có**, thay vì làm lại ứng dụng hoặc mở thêm tính năng.

Khó khăn chính hiện nay là độ rộng của cam kết: vừa ứng dụng du lịch đầy đủ, vừa AI sinh/sửa/tư vấn/gợi ý, vừa dữ liệu có nguồn và ràng buộc thực tế, vừa bản đồ/radar/thời tiết, vừa cơ chế lưu an toàn và một ma trận nghiệm thu lớn. Nhiều phần có source và tests nhưng chưa đủ bằng chứng trên thiết bị để gọi là hoàn tất.

**Phương án khuyến nghị để ChatGPT web phản biện:** bản demo học thuật Android, giữ 5 nhóm chức năng ở mức hẹp: Account, Discovery, Planner, AI và Budget. Trọng tâm là chọn điểm đến → tạo lịch trình → sửa thủ công → kiểm tra chi phí → xác nhận/lưu → mở lại. Giữ 12 điểm đến đang có để khám phá; tập trung dữ liệu và demo sâu vào 1–2 điểm đến. Giữ AI sinh lịch trình có preview/xác nhận; giới hạn công sức bổ sung cho chat/gợi ý/sửa AI đã tồn tại. Hoãn các tích hợp vận hành sâu, cộng tác, radar, mở rộng bản đồ và polish toàn app.

Đây là **đề nghị thay đổi phạm vi cần owner chốt**, không phải tuyên bố mọi MUST cũ đã đạt. Đặc biệt, nếu hoãn AI dùng giờ mở cửa, route và thời tiết thật, phải ghi FR-AI-005 là phần giảm/hoãn, không đổi nhãn `unknown` thành bằng chứng đã hoàn thành.

Không thể cam kết ngày giao chỉ từ số tests. Còn thiếu rubric môn học, số giờ owner có thể làm mỗi ngày và danh sách artifact bắt buộc. Mốc làm việc đề nghị là **28/10/2026**, phù hợp deadline thiết kế đang ghi; cần owner xác nhận đó có phải hạn nộp thực tế.

## 2. Yêu cầu mới và cách hiểu thời hạn

Yêu cầu trực tiếp của owner:

> “Hiện tại tôi thấy scope chúng ta quá rộng. Tôi muốn bạn tổng hợp project qua 1 file md chi tiết để ChatGPT web đọc và phân tích, sau đó giảm scope lại cho đến tuần sau hoàn thành.”

Ngày hiện tại là thứ Ba, **20/10/2026**. “Tuần sau” được hiểu là **26/10–01/11/2026**.

| Mốc | Nguồn và ý nghĩa | Cách dùng trong phân tích |
| --- | --- | --- |
| 24/10/2026, trước 25/10 | Kế hoạch MUST delivery lập sau Phase 1 | Mốc giao nội bộ cũ, chưa đạt toàn bộ |
| 28/10/2026 | Bộ thiết kế Phase 1 và README | Deadline thiết kế đang được ghi nhận |
| Tuần 26/10–01/11 | Yêu cầu mới của owner | Cửa sổ mong muốn; chưa có ngày cụ thể mới |

**Giả định để lập phương án:** khóa demo ngày 27/10, giao ngày 28/10. Không tự coi 30/10 hoặc 01/11 là được gia hạn. Nếu hạn môn học khác, phải lập lịch lùi từ hạn thật.

## 3. Sản phẩm phục vụ ai và giải quyết việc gì?

TravelGO là ứng dụng Flutter hỗ trợ chuẩn bị chuyến du lịch tại Việt Nam. Persona ban đầu là Minh, 25 tuổi, làm CNTT tại TP.HCM, đi 2–4 ngày cùng bạn/gia đình, ngân sách khoảng 3–5 triệu đồng/người.

Các câu hỏi người dùng cần giải quyết:

1. Đi đâu cho phù hợp sở thích và ngân sách?
2. Trong mỗi ngày nên làm gì, vào thời gian nào?
3. Chi phí dự kiến bao nhiêu, thực tế đã chi bao nhiêu?
4. Có thể sửa, lưu và mở lại kế hoạch mà không mất dữ liệu không?

Giá trị nên giữ trong bản giao: **một lịch trình nhìn được, sửa được, có chi phí rõ ràng và lưu lại được**. AI hỗ trợ tạo đề xuất; quyền quyết định và lưu thuộc người dùng. Không biến ứng dụng thành một cửa sổ chatbot chung chung.

### Hai lớp tầm nhìn đang cùng tồn tại

| Lớp | Nội dung | Điều cần tránh khi giảm scope |
| --- | --- | --- |
| Định hướng gốc trong AGENTS/knowledge | Decision Intelligence, MCDA/Pareto/Greedy, biểu đồ và backend làm nguồn quyết định | Không quảng bá thuật toán/engine là đã chạy thật nếu chưa có backend evidence |
| Thiết kế học thuật Phase 1 và triển khai Phase 3 | Discovery, manual itinerary, Hybrid AI, Account, Budget | Không coi tất cả màn hình cũ đều là yêu cầu bắt buộc của bản nộp |

Hai lớp này tạo thêm nhánh automatic planner cũ và manual/AI planner mới. Đề nghị chọn manual/AI itinerary làm **luồng demo chính**, giữ nhánh engine cũ ở trạng thái hiện có nếu không gây cản trở. Việc đổi luật/kiến trúc gốc vẫn cần quyết định riêng; tài liệu này không sửa chúng.

## 4. Phạm vi baseline trước khi giảm

Bộ thiết kế Phase 1 ngày 08/10 xác định:

| Nhóm | Cam kết chính |
| --- | --- |
| Account & Profile — MUST | Guest, email/password, Google, duy trì phiên, sở thích/ngân sách/phong cách, draft local và chuyển draft vào tài khoản |
| Discovery — MUST | Danh sách/tìm kiếm/lọc, chi tiết và nguồn, chọn điểm đến, lịch trình mẫu |
| Trip Planner — MUST | Nhập thông tin, tạo thủ công, thêm/sửa/xóa/đổi thứ tự hoạt động, preview/xác nhận/lưu, danh sách/mở lại, snapshot offline chỉ đọc |
| AI — MUST | Cá nhân hóa, sinh itinerary, chat theo ngữ cảnh, đề xuất sửa có xác nhận, xét dữ liệu vận hành, manual khi AI lỗi, Guest quota |
| Budget — MUST | Dự kiến, thực tế theo loại, số còn lại/vượt, đổi lịch trình giữ actual |
| Security — MUST | Backend phân quyền dữ liệu riêng tư; credentials nhạy cảm ở server |
| Map, Weather — SHOULD | Bản đồ/route/khoảng cách; forecast/gợi ý/cảnh báo khi triển khai |
| Community, Group — SHOULD | Bài viết/đánh giá/bình luận; mời người và cộng tác theo vai trò |
| Booking, payment, push — DEFERRED | Không thuộc MVP |
| Sửa trip đã lưu offline/advanced sync — DEFERRED | Guest draft local vẫn được sửa; snapshot tài khoản offline chỉ đọc |

Baseline còn chốt 12 điểm đến, Gemini qua server, Provider, SQLite, Guest AI 3 lượt/ngày theo giờ Việt Nam và xử lý retry không tạo trùng. Phạm vi AI cũ **không chỉ có generation**; nếu chỉ demo generation thì phải công khai các phần còn lại được giảm hoặc chưa nghiệm thu.

## 5. Kiến trúc thực tế đã thấy trong source

### 5.1. Công nghệ

Thông tin dưới đây đọc từ source hiện tại, không phải đề nghị nâng cấp:

| Thành phần | Đang có |
| --- | --- |
| Client | Flutter/Dart; `pubspec.yaml` khai báo Dart SDK `^3.13.3` |
| State | Provider/ChangeNotifier |
| Network | Dio |
| Auth/database | Supabase Flutter, PostgreSQL/RLS và RPC |
| Local | SQLite/sqflite; lớp repository/store và lifecycle tài khoản |
| AI | Supabase Edge Function `itinerary-proposal`, Gemini phía server; source pin `gemini-3.5-flash-lite` |
| AI readiness cũ | Edge Function `ai-request`; không đồng nghĩa functional itinerary UI |
| Visual | `fl_chart`, `flutter_animate`, ảnh có mapping theo ID |
| Map/location | `flutter_map`, `latlong2`, `geolocator`; các màn bản đồ và radar cũ |
| Backend Java | Có `backend/pom.xml`, MapController/MapService và health controller |
| Verification | Flutter tests/analyzer, Node contracts, SQL/native probes và kiểm thử UI thiết bị |

Không có việc nâng package, đổi Provider, dựng backend mới hoặc chuyển framework trong đề xuất thu gọn.

### 5.2. Bốn luồng cần hiểu

**Khám phá:** người dùng tìm điểm đến → `DiscoveryProvider` → catalogue JSON bundled → UI chi tiết/nguồn → tạo workspace cho đúng điểm đến. Catalogue đọc được không chứng minh mọi thông tin hoạt động đã xác minh.

**Manual và ngân sách:** nhập trip → `ManualPlannerProvider` giữ bản nháp → các command thay đổi document → timeline và budget render lại → preview → người dùng xác nhận. Chi phí dự kiến và actual được lưu riêng; không để AI hoặc xóa hoạt động làm mất actual.

**Lưu:** Guest → SQLite draft; Account → repository kiểm owner/phiên → RPC server → nhận xác nhận/receipt → cập nhật snapshot/list. Nếu server đã ghi nhưng phản hồi bị mất, UI phải giữ trạng thái “chưa xác nhận” và retry đúng yêu cầu cũ. `baseVersion` chặn bản sửa cũ ghi đè bản mới.

**AI:** người dùng đồng ý gửi ngữ cảnh → client gửi context tối thiểu → gateway kiểm Auth/quota → Gemini → server/client kiểm cấu trúc → preview → người dùng Cancel hoặc Apply vào draft. Apply draft và Save cloud là hai hành động khác nhau.

### 5.3. Mô hình dữ liệu và phạm vi lưu

`EditableTripDocumentV2` có input, ngày, hoạt động, estimates, actualExpenses, exceptions và nguồn tham chiếu. Input có title, destination, dates, timezone, origin, travelerCount, budget, interests và priority. Hoạt động có ID/ngày/thứ tự/khung giờ/placeId/provenance.

| Loại dữ liệu | Nơi/trạng thái | Hệ quả |
| --- | --- | --- |
| Bản đang sửa | Có thể chỉ trong RAM trước explicit save | Cài lại/force-stop có thể mất nếu chưa có đường recovery |
| Guest draft đã lưu | SQLite trên thiết bị | Không tự thành trip tài khoản |
| Trip tài khoản | Server với owner/version; local cache/snapshot có kiểm quyền | Cần server acknowledgement; cache không thay server verification |
| Snapshot offline | Đọc lại dữ liệu đã cache trong phạm vi được phép | Không hứa truy cập trip chưa từng cache hoặc sửa cloud offline |
| AI proposal | Đề xuất chờ xác nhận | Không tự động mutate/save |
| Dữ liệu V1 cũ | Contract/snapshot và adapter riêng | Không tự rewrite/migrate toàn bộ sang V2 để kịp deadline |

### 5.4. Các màn/nhánh đã tồn tại

Navigation chính có 5 tab: Trang chủ, Khám phá, Chuyến đi, Yêu thích, Cá nhân. Ngoài ra có onboarding/auth, planner landing, manual editor, preview AI, detail trip đã lưu, snapshot cũ, day map, trip map và các sheet radar/route.

Có endpoint constants `/plan-trip`, `/simulate-sensitivity`; base URL local/emulator và fallback được khai báo. Trong backend Java đã rà inventory, thấy map/health controllers, **chưa thấy planning controller**. Vì vậy không khẳng định backend MCDA/Pareto/Greedy đang hoạt động. Đây là kết luận từ inventory, chưa phải runtime audit đầy đủ.

## 6. Trạng thái từng nhóm: đã có gì, còn thiếu gì?

Quy ước:

- **Source:** đã thấy triển khai hoặc cấu trúc trong checkout.
- **Historical evidence:** báo cáo/log từ lượt trước, được đọc lại trong lần tổng hợp này.
- **Partial:** đạt một số ca; không đại diện toàn module.
- **Open:** chưa có đủ evidence hoặc chưa đạt nghiệm thu.
- **Proposal:** ý kiến trong tài liệu này, chưa triển khai.

| Nhóm | Source và evidence đã có | Phần còn mở / giới hạn |
| --- | --- | --- |
| Guest/Auth | Có auth screens, provider, lifecycle, guard owner/epoch; Google subset theo ledger; interrupted-cold restore có retest emulator và DNY đạt trên C2 | Full Auth negative/timeout/expiry/revoke và latency matrix chưa đóng; không gọi toàn Auth accepted |
| Profile | G1 preferences source + SQL; ledger ghi save/reopen/Cancel/clear/owner isolation emulator đạt, staging migration áp theo quyền riêng | Không suy từ emulator ra toàn physical acceptance; không mở thêm profile features |
| Discovery | Catalogue 12 điểm đến/72 places; search/filter/detail/source; tests và native subsets | 12 mẫu chưa verified feasibility; operational data còn thiếu; độ phủ ảnh/tọa độ thấp |
| Manual planner | Input, timeline, hoạt động, sửa ngày/thứ tự, preview/save, V2; nhiều source regressions | Full form/date/boundary và device matrix chưa đóng |
| Save/list/reopen | Guest và Account subsets có evidence; DNY create/readback và update/list/readback; stale conflict thực đã thử | V1 read/copy, import/full variants và các ca matrix khác còn mở |
| Retry sau mất phản hồi | Main UI với hook QA trên emulator và DNY: uncertain → retry → version đúng, đạt theo report/log | QA build riêng; không biến hook thành behavior bình thường; không tự đóng toàn import/receipt matrix |
| Budget | Estimates/actual/category/chart; có source tests và native actual-preservation subset | Các form/offline/resize/delete liên quan actual chưa đủ mọi biến thể |
| AI generation | Gateway v12 thật; Account A native preview/Cancel/Apply trên emulator | Không suy thành AI thật trên DNY hoặc toàn privacy/error matrix; chỉ fixture được phép |
| AI advice/recommend/modify | Có service/UI/validator; A advice, B recommendations và modify Cancel/Apply đạt happy path emulator | Operational feed FR-AI-005 còn mở; Guest live AI chưa được evidence hiện hành xác nhận |
| Offline/privacy | Local partitions, RLS, snapshot/outbox/receipts; tests và các native subsets | DNY offline/USB, uncached, expiry/revoke và full matrix còn mở |
| Map | Map/day-map/radar source; subset lỗi tile/thiếu vị trí/Back có evidence | Catalogue hiện `routingReady=false` cho mọi điểm đến; không claim route optimizer hoàn chỉnh |
| Weather | Có Open-Meteo service source | Không chứng minh forecast đã nối vào AI itinerary constraints |
| Favorites/Home | Có UI/provider/services và visual refresh | Không phải ưu tiên tăng thêm nội dung, voucher hoặc dịch vụ đặt chỗ |
| Community/collaboration | Là SHOULD trong thiết kế; có group-location/radar code | Không thấy evidence đủ để gọi social publishing hoặc collaborative itinerary hoàn chỉnh |
| Release | Có APK debug x64/profile ARM64 staging và checksum trong reports | Chưa nghiệm thu tổng thể, chưa chốt artifact nộp, chưa production rollout |

## 7. Bằng chứng mới nhất và các trạng thái cũ đã bị thay thế

### 7.1. Checkout đang tổng hợp

- Repo: `D:\Travel-Go-Android\travel-go`.
- Branch: `codex/phase-3-discovery-design`.
- HEAD: `cdf91ef85c4a8e494fe6bf5c6f37f56b3b2bcdaa`.
- Working tree có nhiều tracked modifications và untracked files, thuộc nhiều đợt; **HEAD không đại diện đầy đủ source đang chạy**.
- Có các file Word/HTML/script của owner, generated macOS và nhiều tài liệu lịch sử ngoài task. Lần này chỉ tạo file tổng hợp này, không sửa/xóa/stage những file đó.

### 7.2. Automated checks gần nhất đã đọc log

Thư mục bằng chứng: `.dart_tool/travelgo-verification/20261020T052246884Z-16184/`.

| Kiểm tra | Nội dung cuối log đã đọc |
| --- | --- |
| `analyze.log` | `No issues found! (ran in 43.1s)` |
| `flutter-tests.log` | `01:30 +766: All tests passed!` |
| `node-contracts.log` | 89 tests, 89 pass, 0 fail, 0 skipped |

Đây là **log kiểm thử đã tồn tại, được đọc lại**, không phải chạy suite mới trong task tài liệu. Widget tests có cảnh báo ảnh HTTP400 nhưng suite vẫn pass; không dùng chúng để kết luận ảnh native đạt hoặc hỏng.

Checkpoint MUST ledger trước đó ghi full run dừng ở 479 PASS/4 FAIL. Completion plan sau đó ghi 4 ca targeted PASS và chưa kết luận root cause. Full log 766 PASS cùng báo cáo cập nhật sau là evidence mới hơn về kết quả suite. Không tiếp tục liệt kê 4 ca đó như lỗi hiện hành đã xác nhận; cũng không suy chúng chưa từng xảy ra hoặc đã có causal diagnosis đầy đủ.

### 7.3. Native evidence cập nhật sau checkpoint dừng

Nguồn chính: cuối `P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md`, cùng các log C2/D3 trong `.dart_tool`.

| Ca | Kết quả được ghi nhận | Giới hạn |
| --- | --- | --- |
| PHONE03 interrupted-cold, emulator | Cold → HOME trước restore xong → resume; đúng Account B, không Guest/A | Đúng build/sequence đó |
| PHONE03 interrupted-cold, DNY/profile | Cold → HOME khoảng 584ms → resume; đúng Account A, không Guest/B | Log profile không có stage trace; UI evidence cho đúng ca |
| D3 hai phiên, stale save | Emulator ghi version5; DNY từ version4 bị conflict, giữ draft; reload thấy winner/version5 | Không tự đóng mọi conflict variant |
| D3 main UI mất phản hồi sau commit | Emulator retry đúng, server version1→2 | Dùng QA adapter có scope |
| D3 main UI mất phản hồi trên DNY | Uncertain → Retry → server version2→3 | Profile không có debug marker; report nêu bằng chứng UI/version |
| Tổng P3.2 | **PARTIAL / NOT ACCEPTED** | D1/D2/D4/D5, V1, E/F và các mục khác còn mở |

C2 normal staging APK theo report đã được cài trả lại sau QA:

- Emulator x64 debug SHA256: `B659857F500094F8B0AECC3E011A7CECC3C479099B498271F1D1C5EDB31AAD3B`.
- DNY ARM64 profile SHA256: `0AC26ADFCE52C350BAFF73A88923F16021AE6B6EE9229A5B922E4B6CD3F2BDE6`.

Lần tổng hợp này không điều khiển thiết bị hoặc kiểm lại installed hash. Các giá trị trên là evidence lịch sử mới nhất đã đọc, không phải live state cam kết tại thời điểm ChatGPT web trả lời.

### 7.4. AI đã gọi thật đến mức nào?

MUST ledger ngày 20/10 ghi gateway v12, readback source khớp; emulator Account A/B thật qua server, context QA giả lập được cho phép:

- A sinh proposal: một lượt Cancel, một lượt Apply; draft có 4 hoạt động và nhãn chưa xác minh.
- A tư vấn theo ngày; không tự thay đổi trip.
- B gợi ý hoạt động; một lượt modify Cancel, một lượt modify Apply tạo hoạt động 09:00–10:00.
- Sau 3 kết quả dùng được của B, request tiếp bị chặn quota; manual planner vẫn dùng được.
- Server log trong cửa sổ thử có **6 HTTP200 + 1 HTTP429**.

Không gọi đây là AI production ready, không suy khả năng xử lý context riêng tư tùy ý hoặc Guest rollout. Giai đoạn này dùng staging, allowlist và giới hạn free tier. Không có yêu cầu tăng quota/billing hoặc deploy mới trong task tổng hợp.

## 8. Dữ liệu du lịch: phần nào là thật, phần nào còn thiếu?

Đã đọc asset `assets/catalogue/catalogue_readiness_v1.json`:

- 12 điểm đến, mỗi nơi 6 places: Hà Nội, Hạ Long, Sa Pa, Ninh Bình, Huế, Đà Nẵng, Hội An, Nha Trang, Đà Lạt, TP.HCM, Phú Quốc, Cần Thơ.
- Có 17 source entries; metadata kiểm tra ghi ngày 13/10/2026.
- Mọi destination có `routingReady=false`.
- Mọi sample có `status=not_feasibility_verified`.
- Quyền trong asset chỉ mô tả tên thực tế/source links; không sao chép descriptions/images, không có distribution licence chung được gán cho mọi nội dung.

Do đó:

1. Có tên điểm tham quan và nguồn không đồng nghĩa có giá vé/giờ mở cửa/tọa độ/thời gian di chuyển đáng tin cậy.
2. Có mẫu itinerary không đồng nghĩa mẫu đó khả thi và đủ điều kiện hiển thị như lịch đã xác minh.
3. Có weather service hoặc map widget không đồng nghĩa AI đã xét thời tiết và route thật.
4. `unknown` phải được giữ là chưa biết; không thay bằng0, miễn phí, mở cả ngày hoặc route chắc chắn.

Đề xuất giữ dữ liệu khám phá rộng hiện có, nhưng chỉ chọn **Huế và/hoặc Hà Nội** làm fixture demo sâu vì đã có native evidence liên quan. Chưa khẳng định hai nơi này đã đủ verified operational data. Nếu cần kiểm nguồn mới, đó là công việc riêng sau khi chốt rubric và scope; tài liệu này không browse lại các nguồn du lịch.

## 9. Vì sao scope hiện tại quá rộng?

Các nhận định dưới đây là phân tích từ cấu trúc/yêu cầu/báo cáo, không phải thống kê thời gian đã đo:

1. **Hai hướng planner cùng tồn tại:** nhánh engine/MCDA/Pareto cũ và manual/Hybrid AI mới làm tăng UI, contract và cách giải thích sản phẩm.
2. **AI là nhiều sản phẩm nhỏ:** sinh lịch, recommendation, advice và modification có output/validation/preview/quota/error khác nhau.
3. **Dữ liệu vận hành là một workload riêng:** xác minh 12 × 6 places, giờ mở cửa, giá, tọa độ, route và weather cần nhiều hơn một JSON tên địa điểm.
4. **State kết hợp tăng nhanh:** Guest/Account A/B × online/offline × draft/saved × V1/V2 × success/timeout/uncertain/conflict × emulator/phone.
5. **Nhiều phần SHOULD đã có code:** map/radar/favorites/Home có sức hút làm tiếp, nhưng chiếm thời gian chốt luồng MUST.
6. **Nghiệm thu chưa gom về một bản giao:** có nhiều packet/log/APK/source dirty; “đã làm” và “đã nghiệm thu” dễ bị lẫn.
7. **Tài liệu không cùng thời điểm:** README/knowledge còn trạng thái rất cũ; ledger STOP không chứa các ca C2/D3 mới hơn trong acceptance report.
8. **Chưa rõ tiêu chí chấm điểm:** chưa biết hạng mục nào bắt buộc để được tính là hoàn thành môn học; dễ tối ưu sai mục tiêu.

Phần có thể giảm là số luồng cam kết, độ sâu dữ liệu, loại thiết bị và độ rộng feature mới. Phần không nên cắt để giữ lịch là tính trung thực, bảo toàn dữ liệu, owner isolation và xác nhận rõ ràng trước AI thay đổi/lưu.

## 10. Ba phương án để chọn

| Phương án | Bản giao | Lợi ích | Chi phí/rủi ro |
| --- | --- | --- | --- |
| A — Manual core | Discovery → manual → budget → save/reopen; AI chỉ trình bày là phần mở rộng đang có | Ít phụ thuộc API/quota nhất, tập trung độ ổn định | Giảm mạnh FR-AI-*; có thể không đáp ứng môn học yêu cầu AI/API thật |
| **B — Android core + AI có giới hạn** | 5 module ở mức hẹp; generation thật và explicit preview/apply; reuse assistant hiện có, không mở rộng | Giữ điểm khác biệt và tận dụng triển khai đã có | Phải ghi rõ AI005, Guest AI và các ma trận chưa được giữ trong bản nộp |
| C — Giữ toàn MUST hiện tại | Toàn FR cũ, data constraints, mọi AI mode và matrix rộng | Ít thay đổi baseline | Chưa có cơ sở tin kịp 28/10 với nguồn lực chưa rõ; nguy cơ tiếp tục kéo dài |

**Khuyến nghị B**, có A làm phương án thay thế chỉ khi owner/rubric cho phép. Không dùng A hoặc video cũ để giả một yêu cầu live AI đã đạt nếu rubric đòi gọi thật.

Đừng mặc định bỏ chức năng đã chạy ổn chỉ để có danh sách scope ngắn. Thu gọn chủ yếu bằng **đóng băng chức năng, giảm công việc còn phải phát triển và giới hạn phạm vi tuyên bố/nghiệm thu**. Xóa feature vật lý có thể làm phát sinh regression mới.

## 11. Phạm vi bản giao B đề xuất

### 11.1. Một hành trình chính

> Guest khám phá → chọn Huế/Hà Nội → nhập chuyến đi ngắn → tạo thủ công hoặc yêu cầu AI sinh đề xuất → preview → xác nhận áp dụng → sửa một hoạt động → thêm chi phí dự kiến và thực tế → lưu → mở lại. Nhánh Account chứng minh lưu cloud và mở lại đúng chủ sở hữu.

Demo chỉ cần chứng minh vài ngày hợp lý, ví dụ2–3 ngày / 2 người, không cần biến toàn domain limit366 ngày/1000 hoạt động thành luồng demo. Validator hiện có vẫn giữ nguyên.

### 11.2. Giữ, đóng băng, hoãn

| Hạng mục | Đề xuất bản B | Giới hạn công việc mới |
| --- | --- | --- |
| Android | Nền tảng giao chính | 1 emulator + 1 DNY; không mở QA iOS/web/desktop |
| Email/password, Guest | Giữ | Chốt restore/logout/owner isolation; không redesign Auth |
| Google | Giữ hiện có nếu ổn; demo phụ | Không phát triển thêm provider/Auth UX; nếu bị chặn, ghi rõ và chọn email cho luồng chính, không gọi ACC003 hoàn tất |
| Profile | Giữ G1 hiện có | Không thêm form/traveler/voucher/settings mới |
| Discovery | Giữ12 destinations/search/detail/source | Không tăng số điểm; không buộc mọi nơi có lịch mẫu verified mới |
| Manual planner | Giữ một editor V2 | Thêm/sửa/xóa, ngày/thứ tự, preview; không dựng editor mới |
| AI generation | Giữ làm tính năng nổi bật | Một context demo ngắn, preview/Cancel/Apply; manual vẫn chạy khi lỗi/quota |
| AI advice/recommend/modify | Reuse hiện có, smoke tối thiểu nếu giữ trong scope | Không mở memory dài hạn, agent/tool calling hoặc thêm mode; nếu không đủ evidence thì đánh partial/hoãn tương ứng |
| AI005 data integration | Đề nghị hoãn phần feed vận hành đầy đủ | Giữ nhãn estimated/unknown; không hứa tối ưu thực tế theo live weather/hours/routes |
| Guest AI | Đề nghị hoãn mở rộng live Guest trong bản nộp, giữ Guest manual | Đây là thay đổi FR-AI-007 cần owner/rubric chấp thuận; không đổi quota lén |
| Budget | Giữ cả estimate và actual cơ bản | Không thêm split bill, FX, payment, forecasting |
| Save/list/reopen | Giữ | Chứng minh local và cloud; retry/conflict/ownership vẫn bắt buộc đúng |
| Guest→Account import | Giữ một luồng import V2 có xác nhận nếu nằm trong bản giao | Không mở batch/migration variants mới; pending/receipt hiện có không được phá |
| Offline | Giữ snapshot đã cache chỉ đọc | Không advanced sync/offline cloud editing; chưa cache thì báo unavailable |
| V1 | Bảo toàn khả năng đọc hiện có | Đề nghị hoãn nâng cấp/copy/migration V1 đầy đủ nếu rubric cho phép |
| Map | Giữ màn hiện có nếu không cản luồng; phụ trợ | Không routing mới, không phủ tọa độ72 places; lỗi tile vẫn hiển thị trung thực |
| Weather/radar/group/community | Hoãn phần phát triển và tích hợp mới | Không coi radar source là collaboration hoàn chỉnh |
| Home/Favorites/visual | Đóng băng giao diện đang có | Chỉ sửa lỗi chặn thao tác/đọc chữ/ảnh đúng; không thêm đợt refresh toàn app |
| Booking/payment/push | Tiếp tục deferred | Không mở lại |
| Production/store release | Ngoài mục tiêu bản demo, trừ rubric bắt buộc | Không mặc định deploy/migration/billing/Play Store là việc cần làm tuần này |

### 11.3. Bảng delta so với MUST cũ

| Requirement | Cam kết đề xuất | Cách ghi trung thực |
| --- | --- | --- |
| ACC003 Google | Đóng băng, kiểm nhanh nếu giữ | Thiếu acceptance thì partial/deferred, không thay bằng email rồi gọi đạt Google |
| DIS004 sample itinerary | Không mở campaign xác minh12 mẫu | Sample chưa verified tiếp tục unavailable/pending |
| AI001/003/004 | Có source/native subset; chỉ reuse và smoke nếu nằm trong bản nộp | Mỗi mode có trạng thái riêng; generation không đại diện cả3 |
| AI005 | Không hoàn thiện full operational integration trong bản B | Ghi reduced/deferred; unknown labels không đủ để PASS requirement cũ |
| AI007 Guest quota/live policy | Đề nghị Account-only AI demo; Guest manual giữ | Policy rollout và baseline Guest entitlement phải được owner quyết định |
| TRP006 offline | Chỉ cached snapshot read-only theo quyền hiện có | Không claim offline mọi trip/uncached |
| V1 compatibility | Giữ đọc, hoãn mở rộng/copy nếu được chấp thuận | Không rewrite/xóa dữ liệu cũ |
| Security/data integrity | Giữ | Không giảm RLS/owner guards/actual preservation/idempotency để demo nhanh |

Nếu owner không đồng ý các delta, phải chọn phạm vi khác hoặc thay ngày giao; không thể vừa giữ mọi tiêu chí cũ vừa gọi một demo hẹp là hoàn thành tất cả.

## 12. Definition of Done đề xuất cho bản giao hẹp

Đây là checklist mới để owner duyệt, **không thay thế ngầm E01–E12/PHONE01–04 hoặc55 AC cũ**. Các mục không được chọn phải có trạng thái deferred/partial và lý do trong báo cáo nộp.

| ID | Hành vi cần thấy | Evidence tối thiểu |
| --- | --- | --- |
| D01 | Guest vào khám phá, search và chọn đúng điểm đến | Native thao tác trên bản APK chốt |
| D02 | Tạo manual itinerary ngắn; sửa/xóa/đổi thứ tự không lỗi và không mất input | Native + tests liên quan |
| D03 | AI thật trả proposal; Cancel không đổi draft; Apply đúng một lần | Request thực trong quota, native; chỉ dùng fixture/context đã được phép |
| D04 | AI lỗi/hết lượt vẫn sửa manual, lỗi hiển thị rõ | Kiểm có chủ đích; không dùng fallback giả làm AI thật |
| D05 | Estimate/actual tách biệt, tổng/còn lại đúng, actual giữ khi sửa itinerary | Tests + một native fixture có actual |
| D06 | Guest save/restart/reopen đúng draft | Kiểm từ đĩa, không chỉ RAM |
| D07 | Account save/list/open và update/readback đúng version | Native server acknowledgement |
| D08 | Đổi A→B/Guest không lộ trip/profile cũ; cold/resume không tự Guest sai | Negative tests + native ca trọng yếu; reuse C2 trong đúng build nếu còn phù hợp |
| D09 | Retry sau mất phản hồi không ghi trùng; stale version không ghi đè | Có evidence C2/D3 để reuse; kiểm lại nếu source/build thay đổi liên quan |
| D10 | Snapshot đã cache đọc offline đúng quyền; uncached unavailable | Native trên môi trường có kênh điều khiển phù hợp |
| D11 | Source chốt analyzer sạch, full Flutter và Node contracts đạt | Log/exit/packet hash; không skip/weaken assertions |
| D12 | APK đúng main/ABI/STAGING, không bật QA loss hook; có hướng dẫn/demo/known limitations | Checksum, installed build, artifact checklist và owner xem lại |

Nếu giữ import/Google/assistant modes trong phạm vi nộp, thêm đúng smoke cho các mục đó. Không được bảo đảm chất lượng bằng cách chỉ chọn happy path trong khi đã biết có lỗi mất dữ liệu hoặc lộ dữ liệu.

**Điều kiện chặn giao:** crash luồng chính, lưu báo thành công nhưng không có dữ liệu, mất actual/draft, duplicate write, lộ dữ liệu giữa tài khoản, AI tự ghi không có xác nhận, hoặc giả dữ liệu thành live/verified. Lỗi căn lề nhỏ, ảnh phụ thiếu và feature đã hoãn có thể ghi limitations nếu không cản sử dụng.

## 13. Lịch đề xuất đến 28/10

Chưa có giờ làm thực tế của owner. Ước lượng dưới đây là khoảng **26–42 giờ tập trung**, chưa tính blocker tài khoản/thiết bị/rubric hoặc lỗi mới. Đây là dự toán để kiểm tính khả thi, không phải cam kết.

| Ngày | Kết quả cần chốt | Khoảng công sức giả định |
| --- | --- | --- |
| 20/10 | Đọc file này trên ChatGPT web, lấy rubric và quyết định phạm vi B/A | 2–3h |
| 21/10 | Khóa danh sách in/out, chọn fixtures/demo, đối chiếu source/evidence hiện tại | 4–6h |
| 22/10 | Đóng luồng manual→budget→save/list/open; chỉ fixes chặn luồng | 4–6h |
| 23/10 | Chốt AI generation và các mode đã chọn; không mở feature mới | 3–5h |
| 24/10 | Full checks trên packet ổn định, xử lý regression có bằng chứng | 4–6h |
| 25–26/10 | Native emulator + DNY, isolation/retry/offline và demo rehearsal | 4–6h |
| 27/10 | Khóa source/APK, chụp/quay demo, hướng dẫn và gap report | 3–4h |
| 28/10 | Kiểm artifact, chạy thử ngắn và giao | 2h |

Các ngưỡng điều chỉnh đề nghị:

- Cuối21/10 chưa chốt rubric/scope: không mở thêm implementation packet rộng.
- Cuối23/10 AI còn bị quota/config/provider chặn: owner chọn dùng evidence/video hợp lệ hoặc phương án A **chỉ khi rubric cho phép**; không bí mật tăng quota hoặc đổi model/billing.
- Cuối24/10 core save/privacy/actual còn lỗi: dừng polish/map/assistant expansion, ưu tiên lỗi chặn giao.
- Ngày27/10: không mở tính năng mới; chỉ sửa blocker và kiểm lại phần ảnh hưởng.
- Không kịp tiêu chí an toàn: bàn giao partial với gap rõ, xin điều chỉnh scope/deadline; không gắn nhãn complete cho toàn baseline.

## 14. Rủi ro, phụ thuộc và quyết định còn thiếu

| Mục | Ảnh hưởng | Cách thu gọn/giải quyết đề nghị |
| --- | --- | --- |
| Rubric môn học chưa có | Có thể cắt nhầm phần bắt buộc | Lấy danh sách điểm/chức năng/artifact trước khi chốt scope |
| Giờ làm/ngày chưa rõ | Không kiểm được lịch26–42h | Owner cung cấp lịch21–28/10; ưu tiên đầu ra thay vì số màn |
| API/quota free tier | Demo AI bị chặn nếu hết lượt | Lên lịch một batch demo ngắn; giữ manual; không đổi quota/billing tự động |
| Build/config staging | Key từng rotate; app cũ có thể lỗi dù source đúng | Dùng defines hiện có hợp lệ, không đưa secrets vào file; chốt exact APK |
| Offline trên DNY qua Wi-Fi | Tắt mạng có thể mất kênh điều khiển | Cần USB độc lập hoặc owner thử thủ công có evidence; không giả offline bằng server error |
| Dirty tree lớn | Nhầm packet/source đã được kiểm | Lập danh sách file thuộc bản giao, selective staging khi được giao; không reset/clean |
| Auth/local/receipt phức tạp | Thay đổi nhỏ có thể gây privacy/data-loss | Đóng băng contracts/guards; fix có ca tái hiện và target verification |
| Dữ liệu vận hành thiếu | AI không đủ cơ sở tuyên bố lịch tối ưu/khả thi | Giới hạn claim, hiển thị chưa xác minh, hoãn full AI005 theo quyết định |
| V1 và các biến thể import | Nghiệm thu tốn công | Bảo toàn đọc hiện có; chỉ chọn luồng V2 chính nếu rubric đồng ý |
| Chuỗi tài liệu dài | Owner/ChatGPT dễ đọc nhầm trạng thái cũ | Dùng file tổng hợp này làm entrypoint; giữ nguồn gốc và ngày evidence |

Các câu owner cần quyết định với ChatGPT web, tối đa 5 nhóm:

1. Ngày nộp thật, rubric và artifact bắt buộc là gì? Có bắt buộc live AI, Google, map hoặc thuật toán cụ thể không?
2. Từ 21–28/10 có bao nhiêu giờ tập trung/ngày; có người hỗ trợ không?
3. Chọn A, B hay C? Có đồng ý hoãn full AI005, Guest live AI, mẫu verified12 nơi và các phần SHOULD không?
4. Trong bản B, assistant advice/recommend/modify là bắt buộc demo hay chỉ trình bày evidence hiện có?
5. Đích giao là APK demo học thuật, source/báo cáo/video, hay bắt buộc production/Play Store? Không mặc định các đích này tương đương.

## 15. Giới hạn thực thi và cách phối hợp cần giữ

- Mặc định **không dùng superpowers**, chỉ dùng khi owner yêu cầu rõ cho task hiện tại; không subagents trong lần tổng hợp này.
- Tài liệu này không cấp quyền code/deploy/database/config/billing/quota/merge hoặc hủy mọi checkpoint STOP cũ. Những cập nhật C2/D3 về sau có phạm vi riêng, không tự mở quyền toàn dự án.
- Không sửa permanent rules/native/dependencies hoặc refactor architecture để “giảm scope”. Scope sản phẩm và thao tác kỹ thuật là hai quyết định khác nhau.
- Không đọc/in passwords, tokens, server secrets hoặc credentials trong các artifact gửi ChatGPT web.
- Giữ data owner/Guest và file ngoài task; không clear/uninstall/reset/clean để tạo baseline dễ test.
- Không tự đưa main hoặc rollout production. Mọi thay đổi baseline MUST phải được owner ghi nhận rõ; human review/merge gate giữ nguyên.
- Owner muốn hiểu luồng và evidence. Bàn giao cần phân biệt source đã sửa, tests, native quan sát, proposal và limitation; không cần giải thích từng dòng code.

## 16. Prompt sẵn dùng cho ChatGPT web

Upload **chính file Markdown này**, rồi gửi đoạn sau. Các đường dẫn trong file chỉ là chỉ mục nguồn; ChatGPT web không được giả vờ đã mở repo/log/ảnh local.

```text
Bạn là người hỗ trợ thu gọn phạm vi và lập kế hoạch giao một đồ án Android.
Hãy đọc toàn bộ file TravelGO tôi đính kèm. Ngày tham chiếu là 20/10/2026,
tuần sau là 26/10–01/11; deadline thiết kế đang ghi28/10 nhưng cần tôi xác nhận hạn thật.

Mục tiêu của tôi là hoàn thành một sản phẩm nhỏ, dùng được và trình bày được tuần sau.
Tôi không muốn tiếp tục mở rộng features, viết lại app hoặc lập kế hoạch quá lớn.

Hãy:
1. Tóm tắt trong 10 dòng: sản phẩm, giá trị cốt lõi, đã có gì, thiếu gì và điểm nghẽn chính.
2. Phân biệt evidence hiện hành với báo cáo cũ; lưu ý log 766 Flutter/89 Node PASS
   và C2/D3 mới hơn checkpoint STOP, nhưng toàn P3.2 vẫn NOT ACCEPTED.
3. Phản biện phương ánB; đề xuất phạm vi nhỏ nhất vẫn đáp ứng rubric.
   Chỉ hỏi tối đa 5 câu thiết yếu về rubric/ngày nộp/giờ làm/đích giao trước khi kết luận cứng.
   Khi thiếu câu trả lời, nêu giả định và trình bày phương án có điều kiện.
4. Xuất bảng KEEP/FREEZE/DEFER/DROP với lý do, chi phí còn lại và requirement bị ảnh hưởng.
   Phân biệt ngừng phát triển/giảm cam kết với việc xóa code đã chạy ổn.
5. Nêu rõ những MUST cũ phải đổi nếu chọn scope mới, nhất làAI005/GuestAI/Google/samples.
   Không gọi requirement đạt chỉ vì nó đã được giảm hoặc đổi tên.
6. Đưa ra duy nhất một hành trình demo chính, một nhánh lỗi, Definition of Done đo được
   và lịch từng ngày đến ngày giao thật, có thời gian kiểm thử/tài liệu/dự phòng.
7. Liệt kê5 việc nên dừng làm ngay và 5 việc còn phải hoàn tất theo ưu tiên.
8. Viết một Scope Baseline v2 ngắn để tôi phê duyệt và đưa lại cho coding agent.
   Kèm prompt thực thi giới hạn phạm vi, yêu cầu bảo toàn dữ liệu, tests và evidence.

Đừng suy thêm features từ tên TravelGO hoặc từ source cũ; không đề xuất thay framework,
viết backend mới, tăng billing, rewrite Auth/sync hoặc triển khai map/community/collaboration.
Không giảm tiêu chuẩn bảo mật, lưu dữ liệu, actual preservation, idempotency và consent.
Không coi đề xuất của bạn tự cấp quyền code/deploy/DB/merge hoặc sửa luật repository.
Không tuyên bố đã đọc file local hay kiểm tra runtime ngoài nội dung tôi cung cấp.
```

## 17. Chỉ mục nguồn để coding agent đối chiếu sau này

Phần nội dung cần cho ChatGPT web đã được diễn giải phía trên. Chỉ mục này giúp quay lại kiểm chứng, không yêu cầu upload toàn bộ lịch sử.

| Nguồn | Vai trò / cảnh báo thời điểm |
| --- | --- |
| `AGENTS.md`, `.agent/rules.md`, `.agent/workflow.md` | Luật owner, evidence/handover và ranh giới thực thi |
| `.agent/knowledge.md` | Tầm nhìn/ADRs/debt cũ; ISSUE003 “chưa Auth” đã lỗi thời so với source mới |
| `docs/phase-1/PROJECT_OVERVIEW.md` | Mục tiêu học thuật, 1 developer+AI, hạn 28/10 và scope nền |
| `docs/phase-1/FUNCTIONAL_REQUIREMENTS.md` | FR/MUST/SHOULD/DEFERRED và các mode AI bắt buộc theo baseline cũ |
| `docs/phase-2/execution/PHASE2_CLOSEOUT.md` | Readiness/schema/quota/integration evidence; không đại diện UI Phase3 |
| `docs/phase-3/P3_1_ACCEPTANCE_REPORT.md` | Discovery implementation và catalogue limitations |
| `docs/phase-3/MUST_DELIVERY_PLAN_20261024.md` | Ledger G1/G2/G3/G4; AI v12 và checkpoint STOP; phần cuối cũ hơn C2/D3 |
| `docs/phase-3/P3_2_COMPLETION_PLAN.md` | Phân tích4 failures, proposed matrix/budget; nhiều trạng thái đã có evidence mới hơn |
| `docs/phase-3/P3_2_UX_REFRESH_ACCEPTANCE_REPORT.md` | Cuối report ngày 20/10 chứa C2/D3 mới nhất; toàn phase vẫn partial |
| `lib/main.dart`, navigation shell | Wiring/providers, runtime resources và 5 tabs; có QA loss hook opt-in |
| `lib/features/trip_planner/` | Manual/legacy/AI UI, DTO/command/validator/calculator/services |
| `lib/features/trips/` | Store/repository, Auth lifecycle, saved snapshots/import/receipts |
| `supabase/functions/itinerary-proposal/` | Functional AI gateway/index; không phải quyền deploy mới |
| `assets/catalogue/catalogue_readiness_v1.json` | 12 destinations/72 places/17 sources; sample chưa verified, routingReady=false |
| `.dart_tool/travelgo-verification/20261020T052246884Z-16184/` | Đã đọc analyzer 43.1s clean, Flutter 766 PASS, Node 89 PASS |
| `.dart_tool/p32-c2-phone03-exact-{emulator,dny}.log` | Native interrupted-cold theo đúng build và sequence |
| `.dart_tool/p32-d3-two-session-conflict-dny.log` | Hai phiên và stale version |
| `.dart_tool/p32-d3-main-ui-reply-loss-{emulator,dny}.log` | QA mất phản hồi sau commit và retry main UI |
| `tool/verify-travelgo.ps1` | Helper Status/Targeted/Ai/Full; không phải chỉ thị chạy lại trong task tài liệu |

README đang giữ nhiều mô tả Phase1/NOT RUN cũ, không phải dashboard trạng thái hiện hành. Các log dưới `.dart_tool` là artifact local ignored, không chắc có sẵn nếu chỉ clone repository. HEAD giống nhau không chứng minh dirty tree giống nhau; future execution cần kiểm lại actual source.

## 18. Bàn giao lần tổng hợp này

- **Changed:** chỉ tạo `docs/PROJECT_CONTEXT_AND_SCOPE_REDUCTION_20261020.md`; chưa sửa sản phẩm hoặc áp dụng scope mới.
- **Why:** gom yêu cầu, source, evidence và phương án giảm phạm vi vào một file đọc độc lập; tránh nhầm readiness/source/test PASS với nghiệm thu toàn bộ.
- **Testing:** đã đọc Git branch/HEAD/status, source inventory, asset catalogue, SHA của 3 file Auth so với checkpoint và tail logs analyzer/Flutter/Node hiện có. Không chạy mới `flutter analyze`, `flutter test`, build, hot reload hay native QA vì đây là task tài liệu; kết quả766/89 là evidence đã tồn tại.
- **Problems:** rubric/giờ làm/ngày nộp thật chưa xác nhận; scope B chưa được owner chốt; P3.2 và whole MUST chưa accepted; không khẳng định live state server/thiết bị từ log lịch sử.
- **Lesson Candidate:** nhiều báo cáo cùng ngày có trạng thái khác nhau → checkpoint theo phase có thể cũ hơn acceptance theo ca → đọc nguồn cập nhật sau và chỉ thay trạng thái đúng subset. Nhiều code đã có nhưng chưa đóng luồng → giảm cam kết/độ rộng QA có chủ đích, giữ data integrity, rồi chốt một bản giao có evidence.
