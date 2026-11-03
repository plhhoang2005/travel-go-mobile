# Local Chatbot Ollama Qwen3 4B Implementation Plan

**Execution approval:** Owner trả lời "duyệt" ngày 03/11/2026, chọn triển khai trực tiếp. Các câu "chưa phê duyệt"/"chỉ lập plan trong lượt hiện tại" bên dưới ghi trạng thái lúc lập plan và được approval này thay thế. Tiến độ/kết quả thực thi ở `docs/phase-3/LOCAL_AI_QWEN3_HANDOVER_20261103.md`.

**Runtime ruling:** Alias `qwen3:4b` hiện trỏ bản thinking-only (digest `359d7dd4bcda`), không thực hiện được mục tiêu chat trực tiếp bằng `think=false`. Pin biến thể cùng dòng Qwen3 4B/Q4_K_M là `qwen3:4b-instruct-2507-q4_K_M`, được nhà phát hành xác định non-thinking; không có runtime fallback. Bộ mẫu alias cũ bị cắt ở 256 token và không được nghiệm thu PASS. Service phải từ chối `done_reason=length`. Căn cứ: [official Ollama tags](https://ollama.com/library/qwen3/tags), [Qwen3-4B-Instruct-2507](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507).

**Execution checkpoint:** Tasks1–4 đã triển khai, review độc lập và sửa3regressions bằng RED→GREEN. Full cuối PASS: analyzer0issues,1.383Flutter tests,108Node contracts. Task5 đã cài Ollama/model, đo6mẫu host, build/cài APK trên Redmi Note8Pro và kiểm mất kết nối/retry/hủy/cold/history PASS; native Admin với tài khoản thật và tải đồng thời đúng toàn bộ web/API/IDE **NOT RUN**. Kết quả đầy đủ và giới hạn ở báo cáo bàn giao liên kết trên; các checklist dưới giữ như hướng dẫn thực thi gốc, không thay bằng chứng kiểm tra.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for direct execution, or `superpowers:subagent-driven-development` if the owner selects delegation. Steps use checkbox (`- [ ]`) syntax for tracking. Do not implement before owner review of this plan.

**Goal:** Chatbot TravelGO gọi Qwen3 4B thật qua Ollama, dùng đúng cấu hình trên thiết bị, báo lỗi trung thực và được kiểm chứng trên điện thoại thật.

**Architecture:** Giữ Flutter/Provider/Dio và `LocalAiService`. Admin và chatbot dùng chung một settings store cục bộ; service trả nội dung thật hoặc lỗi có kiểu, Provider quản lý yêu cầu và UI hiển thị trạng thái. Điện thoại kết nối USB tới Ollama trên laptop qua ADB reverse.

**Tech Stack:** Flutter/Dart, Provider, Dio, SharedPreferences hiện có; Ollama với `qwen3:4b-instruct-2507-q4_K_M` Q4_K_M; Android thật qua USB.

**Spec:** Thiết kế giới hạn trong mục "Thiết kế và phạm vi" của tài liệu này, theo trao đổi owner ngày 03/11/2026. Owner đã chọn model và thiết bị; chưa phê duyệt triển khai. Owner yêu cầu lập plan trước và dùng Superpowers, nên lưu plan cho gói sửa luồng hiện có. `.agent/product-scope.md` tiếp tục điều chỉnh quyền dữ liệu và tính trung thực; thiết kế Gemini trong `.agent/ai-planner-design.md` là lịch sử đối với lựa chọn local của gói này, không sửa tài liệu đó trong gói.

## Baseline và bằng chứng hiện tại

- Checkout: `D:/Travel-Go-Android/travel-go`; branch `feat/team-integration-v1`; HEAD `1b2a883df432c1d0d9e8b8c9d40b55aba719c8cf`.
- Working tree có sáu file Dart sửa dở và nhiều file untracked. Hai file giao với gói này là `admin_ai_management_screen.dart` và `ai_chat_provider.dart`; giữ nội dung người khác, đối chiếu diff trước khi sửa. Không stage toàn bộ file giao nhau nếu còn hunk ngoài task.
- `ApiConstants` vẫn chọn `qwen2.5:1.5b` và `http://10.0.2.2:11434`.
- `LocalAiService.sendChatMessage` gọi Ollama `/api/chat`, nhưng hardcode system prompt, chờ phản hồi 4 giây và trả lỗi dưới dạng chuỗi giống nội dung trả lời.
- Admin lưu model/prompt/temperature trong preferences; các giá trị này chưa được truyền vào lời gọi Ollama. Nút test có nhánh thành công giả, kể cả khi kết nối lỗi.
- Provider có nhánh gọi Gemini chưa commit nhưng không dùng `geminiResult`; sau đó vẫn gọi Ollama. Khi Ollama lỗi, Provider có thể tạo câu trả lời viết sẵn và gắn nguồn tĩnh.
- Chatbot đang gắn nhãn Gemini; danh sách phiên dùng chung trên thiết bị, chưa tách tài khoản. Đây là giới hạn đã biết, không được báo toàn bộ chatbot hoàn thành sau gói này.
- Phần cứng đọc được: i5-11400H, RTX 3050 Laptop 4 GB VRAM, khoảng 15,7 GiB RAM sử dụng được. Snapshot lúc đọc: còn khoảng 2 GiB RAM, mức dùng 87%; đây không phải phép đo khi chạy model.
- Terminal chưa tìm thấy `ollama`; probe localhost bị giới hạn socket của môi trường công cụ, nên trạng thái cài đặt/dịch vụ/model chưa xác minh. Chưa tải model, chạy inference, build/cài app hoặc sửa thiết lập máy.

## Thiết kế và phạm vi

### Quyết định đã chốt và đề xuất kỹ thuật

- Owner chọn **Qwen3 4B**, chạy trên laptop; **demo bằng điện thoại Android thật**. Không nhúng trọng số model vào APK.
- Đề xuất kết nối demo: USB, `adb -s <PHONE_ID> reverse tcp:11434 tcp:11434`; app gọi `http://127.0.0.1:11434`. Emulator chỉ dùng khi cần hồi quy, với host `http://10.0.2.2:11434` được cấu hình rõ.
- Model mặc định `qwen3:4b-instruct-2507-q4_K_M`; ngữ cảnh ban đầu `num_ctx=2048`, `think=false`, `num_predict=256`, `stream=false`. Đây là cấu hình thử nghiệm, chưa phải hiệu năng được chứng nhận. Kiểm tra hỗ trợ thinking trên bản Ollama/model thực tế trước demo.
- Timeout đề xuất: connect 5 giây, send 15 giây, receive 120 giây. UI có loading và hủy; không tự retry. Không hứa độ trễ dựa vào các timeout này.
- Settings gồm base URL, tên model, system prompt và temperature mặc định 0,7 trong khoảng 0–1. Nhãn Admin phải nói rõ "Cấu hình AI trên thiết bị này"; không hứa cấu hình toàn server hoặc đồng bộ sang máy khác.
- Settings được chụp tại lúc bắt đầu request. Lưu cấu hình mới áp dụng cho request sau, không đổi request đang chạy. Đổi input khi kiểm tra kết nối làm kết quả kiểm tra cũ hết hiệu lực.
- Chỉ báo kết nối thành công sau khi đọc được model từ `/api/tags` và một lời gọi `/api/chat` trả nội dung assistant không rỗng. Đo độ trễ bằng Stopwatch, không ghi số cố định. Lưu cấu hình thành công và kết nối thành công là hai trạng thái khác nhau.
- Request lỗi giữ tin nhắn người dùng, không thêm câu trả lời mẫu hoặc nguồn giả. Nút thử lại gửi lại cùng tin nhắn đang lỗi, không nhân đôi user message; hủy không tự gửi lại.
- Mỗi request gắn với session ID và request generation. Chuyển/tạo/xóa session hoặc dispose thì hủy request hiện tại; kết quả đến muộn không được hiện hoặc lưu vào session khác.

### Trong gói này

Settings local dùng chung; service Ollama có lỗi có kiểu; bỏ Gemini và fallback viết sẵn khỏi chatbot local; bỏ nhãn/công tắc web chưa có truy xuất thật; lỗi/thử lại/hủy và chống phản hồi nhầm session; hướng dẫn và nghiệm thu USB thật.

### Gói sau, chưa được triển khai từ plan này

Hội thoại nhiều lượt đầy đủ, RAG catalogue, tư vấn theo chuyến đi, nguồn có evidence, tìm web thật, rating từ DB, áp dụng thay đổi lịch qua preview, tách lịch sử theo tài khoản và xử lý lịch sử legacy. Không gọi các phần này là đã xong khi gói kết nối PASS. Chat hiện tại chỉ dùng dữ liệu thử tổng hợp cho demo; không nghiệm thu quyền riêng tư nhiều tài khoản trước khi tách lịch sử.

## Global Constraints

- Chỉ lập plan trong lượt hiện tại. Code, cài model, cấu hình máy và vận hành điện thoại là các bước thực thi sau khi duyệt.
- Giữ Provider/Dio/SharedPreferences; không thêm dependency, sửa native manifest/build hoặc đổi kiến trúc gốc.
- Không đụng CRUD Admin/catalogue/publication, database, Supabase deployments, AI gateway Gemini của các luồng lịch trình cũ, quota hoặc billing.
- Không thay permanent rules. Không gọi Google/Gemini hoặc tự chuyển model/provider khi lỗi trong chatbot local.
- Không mở cổng ra LAN, chỉnh firewall hoặc đặt `OLLAMA_HOST=0.0.0.0` cho phương án USB. Không xóa cài đặt/model/lịch sử cũ hoặc thay SDK để làm test PASS.
- Không dump API keys, tokens, chat riêng tư hoặc preferences ra log. Không dùng quyền Admin trong prompt/model.
- Kiểm tra lại branch/HEAD/dirty diff khi thực thi; giữ nguyên baseline ngoài gói. Dùng nhánh/worktree phù hợp nếu cần, không tự chuyển checkout đang có sửa dở hoặc bỏ mất các hunk hiện tại.
- Mọi thay đổi vào main qua PR/human review; không tự push main. Tối đa ba vòng sửa lỗi liên tiếp; nếu hết guard thì checkpoint.
- Nếu giao Antigravity code: bắt buộc ghi rõ yêu cầu dùng Superpowers phù hợp trong handoff theo chỉ thị owner. Không tự dùng delegation trong lượt lập plan.

## Review Focus

1. Model chưa cài, service ngừng hoặc trả HTTP 404/500: báo đúng lỗi, không thành công giả (Task 2, 4).
2. RAM/VRAM thấp và cold load lâu: loading/hủy hoạt động; không tự gọi thêm request hoặc model khác (Task 3, 5).
3. Đổi/xóa session hoặc cấu hình khi request đang chờ: response cũ không ghi sang chat khác, kết quả test cấu hình cũ không còn hiệu lực (Task 3, 4).
4. HTTP 200 nhưng JSON sai/assistant rỗng: coi là lỗi phản hồi, không lưu thành công và không gắn nguồn (Task 2, 3).
5. Lưu settings/lịch sử thất bại hoặc widget dispose giữa chừng: giữ dữ liệu đang soạn, thoát loading, không gọi setState sau dispose hoặc tự gửi lại (Task 1, 3, 4).

## File map và interfaces dự kiến

| File | Vai trò |
| --- | --- |
| `lib/core/constants/api_constants.dart` | Default model Qwen3 4B và host USB của chatbot local. |
| `lib/features/trip_planner/models/local_ai_settings.dart` (mới) | `LocalAiSettings`: immutable settings, defaults và validation. |
| `lib/features/ai_chat/services/local_ai_settings_store.dart` (mới) | `Future<LocalAiSettings> load()`, `String? get loadWarning`, `Future<void> save(LocalAiSettings settings)` qua preferences hiện có. |
| `lib/features/trip_planner/models/local_ai_models.dart` | Thêm `LocalAiFailureCode`, `LocalAiFailure` và `LocalAiConnectionCheck`. |
| `lib/features/trip_planner/services/local_ai_service.dart` | Thêm `Future<String> requestReply(String prompt, {required LocalAiSettings settings, CancelToken? cancelToken})` và `Future<LocalAiConnectionCheck> checkConnection(LocalAiSettings settings, {CancelToken? cancelToken})`. |
| `lib/features/ai_chat/providers/ai_chat_provider.dart` | Nạp settings, gọi service, lỗi/thử lại/hủy và request generation. |
| `lib/features/admin/presentation/screens/admin_ai_management_screen.dart` | Form cấu hình local và test thật bằng cùng service. |
| `lib/features/ai_chat/presentation/screens/ai_chatbot_screen.dart` | Nhãn Ollama/model, loading/hủy/lỗi/thử lại; bỏ thông báo web không có evidence. |
| `docs/LOCAL_AI_SETUP.md` (mới) | Hướng dẫn Windows/Ollama, USB và bảng nghiệm thu runtime. |

API mới là additive: giữ `sendChatMessage(String, {List<LocalChatMessage>? history})` cho màn hình ba tab cũ, delegate transport khi phù hợp nhưng giữ history và thông báo lỗi tương thích. Không viết lại hai hàm search/recommend trong gói này. `requestReply` của chatbot chính không nhận lịch sử ở gói đầu; Task hội thoại sau sẽ bổ sung rõ ràng.

## Task 1: Settings local dùng chung, lưu thành công thật

**Files:** tạo settings model/store theo file map; sửa constants; tạo `test/local_ai_settings_test.dart`.

**Interfaces:** `LocalAiSettings` có `baseUrl`, `modelName`, `systemPrompt`, `temperature`; `LocalAiSettingsStore` nhận optional `SharedPreferences` để test không cần dependency mới. `loadWarning` là null khi load hợp lệ, là thông báo an toàn khi phải dùng defaults vì JSON/validation lỗi; reset mỗi lần load. `save` ném lỗi nếu ghi preferences trả false.

- [ ] Viết test defaults: host USB `http://127.0.0.1:11434`, model `qwen3:4b-instruct-2507-q4_K_M`, temperature 0,7; roundtrip giữ đúng settings.
- [ ] Viết test validation: model/prompt rỗng, temperature ngoài 0–1, URL sai scheme/thiếu host/có credentials/query/fragment/path khác `/` bị từ chối trước network. Chuẩn hóa dấu `/` cuối.
- [ ] Viết test settings hỏng trả default kèm trạng thái cảnh báo có thể hiển thị; save thất bại không báo thành công và không thay settings đang hoạt động.
- [ ] Chạy test và xác nhận RED trước patch. Lưu settings mới vào một JSON key `travelgo_local_ai_settings_v1`; không đọc hoặc log Gemini key. Giữ preferences legacy/lịch sử nguyên vẹn, không tự nhập model Gemini làm local model.
- [ ] Implement interfaces và chạy GREEN: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/local_ai_settings_test.dart`.
- [ ] Review diff thuộc task, commit chọn lọc khi không trộn hunk ngoài task: `feat(ai): add shared local Ollama settings`.

## Task 2: Ollama transport và kiểm tra kết nối có bằng chứng

**Files:** sửa local AI models/service; bổ sung `test/local_ai_service_test.dart`. Dùng fake `HttpClientAdapter` theo pattern tests hiện có, không cài mocking package.

**Interfaces:** `LocalAiFailureCode` gồm `connection`, `timeout`, `modelMissing`, `server`, `invalidResponse`, `cancelled`; `LocalAiFailure` giữ code và thông báo tiếng Việt an toàn; `LocalAiConnectionCheck` giữ `modelName` và `Duration elapsed`.

- [ ] Viết test request gửi đúng model, system prompt, temperature, `num_ctx=2048`, `num_predict=256`, `think=false`, `stream=false`, host và timeouts đã chốt; chỉ một POST chat cho mỗi lần gửi.
- [ ] Viết test lỗi mạng/timeout/cancel, HTTP 404 model thiếu so với 404 endpoint sai, HTTP 500, JSON sai và assistant content rỗng/whitespace. Lỗi 404 không đủ body để xác định thiếu model phải báo server/endpoint, không đoán.
- [ ] Viết test checkConnection: `/api/tags` có model chính xác rồi POST chat có nội dung mới PASS; tags rỗng/model thiếu thì không POST; latency đo thực; response `done=false` không được coi là hoàn tất.
- [ ] Chạy RED, implement hai method mới và compatibility wrapper, chạy GREEN: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/local_ai_service_test.dart,test/local_ai_assistant_screen_test.dart`.
- [ ] Giữ nguyên test search/recommend; không xóa assertions bảo vệ dữ liệu. Commit chọn lọc: `fix(ai): validate real Ollama replies and connection checks`.

## Task 3: Provider dùng phản hồi thật và giữ request đúng session

**Files:** sửa `ai_chat_provider.dart`; cập nhật `test/ai_chat_flow_test.dart` (fixtures/adapter synthetic, không gọi mạng thật trong tests).

**Interfaces:** giữ `sendMessage(String)`; thêm `LocalAiFailure? lastFailure`, `String? failedMessageId`, `Future<void> retryFailedMessage()`, `void cancelPendingReply()`; giữ `reloadAiSettings()` để Admin await. Constructor cho phép inject settings store, giữ injection service/storage cũ.

- [ ] Viết test trả đúng nội dung từ fake Ollama; lỗi không sinh câu trả lời theo từ khóa, không gắn citations tĩnh và không gửi Gemini. Thay các tests đang đòi fallback viết sẵn/nguồn giả bằng tests hành vi mới; giữ storage roundtrip và điều hướng.
- [ ] Viết test retry giữ nguyên user message ID, chỉ thêm một assistant khi thành công; click gửi lặp trong loading không tạo request thứ hai; hủy giữ câu hỏi và không tự retry.
- [ ] Viết test giữ request bằng Completer, lần lượt chuyển/tạo/xóa session rồi cho response cũ trả về: không hiện/lưu vào session mới hoặc làm sống lại session đã xóa. Dispose không notify sau đóng.
- [ ] Viết test lỗi lưu user message: còn nội dung trong bộ nhớ, không gọi AI nếu chưa lưu, thoát loading và retry không nhân đôi. Lỗi lưu assistant giữ câu trả lời đã nhận trong bộ nhớ, báo chưa lưu và không gọi lại model để thay thế.
- [ ] Chạy RED, bỏ lời gọi Gemini và `_generateSmartTravelFallback` khỏi đường gửi chatbot local, implement snapshot/generation/cancel/error; chạy GREEN: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/ai_chat_flow_test.dart`.
- [ ] Commit chọn lọc: `fix(ai): preserve local chat requests and report genuine failures`.

## Task 4: Admin cấu hình đúng service và chatbot hiển thị trung thực

**Files:** sửa hai screen trong file map; tạo `test/admin_ai_management_test.dart`, cập nhật UI assertions trong `test/ai_chat_flow_test.dart`.

**Interfaces:** Admin dùng cùng settings model/store/service; cho phép inject store/service qua constructor optional để widget tests không gọi mạng. Chỉ báo lưu xong sau `save` và `await reloadAiSettings` thành công. Nếu lưu được nhưng reload lỗi phải báo rõ khác biệt.

- [ ] Viết widget tests: nhập host/model/prompt/temperature, lưu rồi gửi chat dùng đúng các giá trị mới; lỗi save giữ form và không báo thành công. Nút test kiểm tra form hiện tại, không âm thầm lưu.
- [ ] Viết widget tests: model thiếu, timeout, HTTP 500 không hiển thị sẵn sàng/dự phòng; sửa form khi test đang chờ khiến kết quả cũ không cập nhật trạng thái; dispose không setState sau await.
- [ ] Viết widget tests: nhãn Ollama + model, không còn Gemini/API-key input/web-grounding switch hoặc nhãn web đã tìm. Với lịch sử cũ, không trình bày citations không có provenance như nguồn đã kiểm chứng; không xóa lịch sử.
- [ ] Viết widget tests lỗi/thử lại/hủy và giữ nội dung trên màn hình hẹp/text scale 2; giữ nút quay lại/lịch sử.
- [ ] Chạy RED, sửa UI bằng theme/layout sẵn có, chạy GREEN: `./tool/verify-travelgo.ps1 -Mode Targeted -TestPath test/admin_ai_management_test.dart,test/ai_chat_flow_test.dart,test/admin_navigation_test.dart`.
- [ ] Commit chọn lọc: `fix(ai): connect local settings and show truthful chatbot status`.

## Task 5: Setup, kiểm tra toàn bộ và nghiệm thu điện thoại thật

**Files:** tạo `docs/LOCAL_AI_SETUP.md`; ghi kết quả gói vào tài liệu này hoặc handover riêng, không sửa rules/phạm vi cũ một cách tự động.

- [ ] Sau duyệt, kiểm tra Ollama đã cài/dịch vụ/model trước khi cài hoặc tải gì. Nếu thiếu, dùng installer chính thức và `ollama pull qwen3:4b-instruct-2507-q4_K_M` theo quyền thực thi được owner cấp; không tự tải model lớn khác. Hướng dẫn tách rõ bước owner làm và bước agent đã làm.
- [ ] Chạy host probe `/api/tags`, `/api/show` cho model và một synthetic `/api/chat`; kiểm metadata cho `think=false`, ghi version/model digest và PASS/FAIL, không giả kết quả khi tool bị chặn.
- [ ] Kiểm ADB tại SDK được khai báo trong `android/local.properties`, chọn đúng `<PHONE_ID>` từ `adb devices`; bật USB debugging và xác nhận trên máy nếu cần. Reverse đúng cổng bằng `adb -s <PHONE_ID> reverse tcp:11434 tcp:11434`. Không đụng thiết bị khác.
- [ ] Chạy targeted tests cần thiết rồi `./tool/verify-travelgo.ps1 -Mode Full`; ghi actual HEAD/dirty diff, exit và log. Full chạy analyzer, Flutter suite và Node contracts theo script hiện hành. Không chạy Full song song build APK.
- [ ] Sau code Flutter, thực hiện hot reload qua Dart MCP nếu có active app. Nếu không có, ghi NOT AVAILABLE, không claim reload PASS; build/chạy lại đúng source trên phone để kiểm runtime. Không clear/uninstall khi có draft chưa lưu.
- [ ] Thử điện thoại: API thật thành công; chọn model không tồn tại báo lỗi; endpoint không kết nối báo lỗi; cancel giữ câu hỏi; retry không trùng; chuyển chat khi chờ không lẫn response; lưu settings và mở lại giữ cấu hình. Không dùng nút test làm bằng chứng duy nhất.
- [ ] Mở đúng web/API và Android Studio sẽ demo, dùng phone và không bật emulator/build nền. Chạy một cold request và ít nhất năm warm requests synthetic tuần tự; ghi thời gian, RAM còn trống, VRAM, `ollama ps` CPU/GPU split và lỗi. Không gọi model thứ hai đồng thời.
- [ ] Mục tiêu demo đề xuất: 5/5 warm requests có câu trả lời hợp lệ, mỗi request tối đa 30 giây với prompt ngắn và output tối đa 256 token; cold tối đa 120 giây; UI không đơ/crash. Đây là ngưỡng nghiệm thu đề xuất, chưa đo. Nếu không đạt, checkpoint và đề xuất chỉnh output/context hoặc dùng model cũ khi owner chọn; không âm thầm fallback.
- [ ] Viết hướng dẫn khởi động/prewarm trước demo, host USB/emulator, xử lý cổng đang dùng, thiếu model, timeout, ADB chưa trong PATH; cách gỡ reverse sau demo `adb -s <PHONE_ID> reverse --remove tcp:11434`.
- [ ] Commit tài liệu/kết quả được xác minh: `docs(ai): document Qwen3 phone demo setup and acceptance`. Bàn giao Changed/Why/Testing/Problems/Lesson Candidate bằng tiếng Việt; phân biệt gói kết nối xong với toàn bộ chatbot/RAG chưa xong.

## Tài liệu chính thức đã đối chiếu

- [Qwen3 4B trên Ollama](https://ollama.com/library/qwen3:4b-instruct-2507-q4_K_M): bản Q4_K_M khoảng 2,5 GB; không coi dung lượng file là tổng RAM/VRAM.
- [Ollama chat API](https://docs.ollama.com/api/chat), [model list](https://docs.ollama.com/api/tags), [thinking](https://docs.ollama.com/capabilities/thinking), [context length](https://docs.ollama.com/context-length).
- [Windows setup](https://docs.ollama.com/windows), [Android reverse forwarding](https://developer.android.com/develop/ui/views/layout/webapps/access-local-server), [emulator host alias](https://developer.android.com/studio/run/emulator-networking-address).

## Self-review và trạng thái bàn giao plan

- [x] Phạm vi đầu tiên tách khỏi RAG/hội thoại/account isolation; không gọi đây là toàn bộ AI hoàn tất.
- [x] Model/phone theo quyết định owner; các timeout/output/ngưỡng demo đánh dấu đề xuất, không giả benchmark.
- [x] Settings/service/provider/Admin có tên interface và trách nhiệm cụ thể; giữ wrapper cho consumer cũ.
- [x] Năm review risks được gắn tests hoặc nghiệm thu runtime; không coi mocked PASS là phone acceptance.
- [x] Baseline dirty được ghi, không có stage/commit/push hoặc product code changes trong lượt plan.
- [ ] Owner review plan và chọn cách thực thi: đề xuất trực tiếp trong session vì các task phụ thuộc cùng interfaces và số file vừa phải; delegation chỉ khi owner chọn.
- [ ] Implement, automated verification và runtime acceptance: NOT RUN.
