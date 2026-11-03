# Bàn giao chatbot local Qwen3 4B — 03/11/2026

## Tóm tắt cho owner

Đã triển khai đường chatbot gọi Ollama thật, dùng chung cấu hình với Admin và báo lỗi/thử lại/hủy trung thực. Không còn gọi Gemini hoặc thay lỗi bằng nội dung mẫu trong chatbot local. Model chạy trên laptop; điện thoại thật kết nối qua USB. RAG, lịch sử hội thoại nhiều lượt và tách lịch sử theo tài khoản vẫn là gói tiếp theo.

Tài liệu được cập nhật theo kết quả thực thi. Không coi bảng runtime API bên dưới là nghiệm thu APK hoặc toàn bộ tải demo đồng thời.

## Changed

- Base HEAD `1b2a883df432c1d0d9e8b8c9d40b55aba719c8cf`, branch `feat/team-integration-v1`. Có owner dirty work trước task; snapshot đối chiếu tại `.dart_tool/local-ollama-plan/baseline-hashes.json`.
- Checks và APK được tạo từ working tree có bốn dirty file CRUD owner giữ nguyên SHA, không từ clean checkout tách riêng; không stage/commit các file đó. Hai file AI chồng lấn baseline được thay theo phạm vi local đã duyệt.
- Settings model/store mới; default `http://127.0.0.1:11434`, model pin `qwen3:4b-instruct-2507-q4_K_M`, prompt và temperature lưu thành một JSON cấu hình trên thiết bị.
- `LocalAiService`: request thật, lỗi có kiểu, kiểm model + generation thật, timeout rõ, từ chối nội dung rỗng/sai schema/chưa hoàn tất hoặc chạm giới hạn token. Giữ API wrapper và phần search/recommend cũ.
- Provider: bỏ đường Gemini/fallback viết sẵn; giữ câu hỏi khi lỗi; retry không nhân đôi; hủy và generation guard; ghi storage tuần tự; cảnh báo/chưa lưu và retry metadata riêng theo chat, kể cả lỗi ghi tới sau khi đổi chat.
- Admin: form cấu hình local, test không tự lưu, kết quả test cũ hết hiệu lực khi form đổi; lưu và nạp settings vẫn hoàn tất khi đóng route; UI chỉ cập nhật khi mounted.
- Chatbot: nhãn Ollama/model, lỗi/hủy/thử lại; gỡ công tắc web chưa có retrieval; không trình bày citations legacy như evidence thật; giữ lịch sử trên storage.
- Tests mới cho settings, transport, Provider, Admin và review regressions; cập nhật test UI/navigation/sandbox với SharedPreferences mock và assertions theo local design.
- Hướng dẫn: `docs/LOCAL_AI_SETUP.md`; kế hoạch owner duyệt: `docs/superpowers/plans/2026-11-03-local-chatbot-ollama-qwen3-4b.md`.
- Cài Ollama chính thức `0.40.14` qua winget; tải Qwen3 4B. Không sửa dependencies/native configuration/DB hoặc deploy Supabase. Không đụng bốn dirty file CRUD Admin ngoài phạm vi (đã đối chiếu SHA).

## Why

UI có câu trả lời chưa chứng minh model đã chạy: trước đây lỗi Ollama bị thay bằng nội dung mẫu và nguồn tĩnh. Gói này tách phản hồi model với lỗi, dùng cùng settings cho test và chat, giữ dữ liệu khi lưu/kết nối thất bại.

Runtime phát hiện alias `qwen3:4b` trỏ thinking-only digest `359d7dd4bcda`. Metadata chỉ cho phép thinking=true, template mở `<think>`; `think=false`, soft switch và assistant prefill không tạo được câu trả lời cuối trong giới hạn đã chọn. Diagnostic thinking=true trả câu cuối nhưng không phù hợp mục tiêu chat trực tiếp. Vì vậy pin **cùng dòng Qwen3 4B/Q4_K_M, biến thể Instruct** thay vì tự fallback lúc chạy. Nguồn: [Ollama tags](https://ollama.com/library/qwen3/tags), [model card Qwen](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507).

Review độc lập tìm hai lỗi được sửa bằng RED→GREEN: A→B→A làm mất cảnh báo reply chưa lưu; Admin dispose khi save đang chờ làm root chatbot giữ settings cũ.

## Testing

### Automated

- Settings 12 tests: RED trước khi có interface, GREEN sau triển khai.
- Transport: RED trước method/typed errors; kiểm payload, model, timeouts, schema, lỗi/cancel, probe và wrapper history. Thêm RED→GREEN từ chối `done_reason=length`.
- Provider/UI: lỗi và retry, lưu lỗi trước/sau inference, hủy/đổi/xóa chat với response muộn, khởi tạo lại, màn hình 320dp/text scale2.
- Review regressions: 3 FAIL trước patch → PASS sau patch. Lượt combined local package cuối trước Full: **74/74 PASS**.
- Full v1: dừng ở 5 lint infos mới; sửa ngoặc/underscore, không suppress diagnostics.
- Full v2: **analyzer PASS**, Flutter **1380 PASS / 2 FAIL** do sandbox Admin tests chưa mock preferences; Node chưa chạy. Giữ assertions, thêm mock; targeted sandbox **5/5 PASS**.
- Full cuối: **PASS exit 0** — analyzer **No issues found**, Flutter **1.383/1.383 PASS**, Node contracts **108/108 PASS**. Command `./tool/verify-travelgo.ps1 -Mode Full`; logs `.dart_tool/local-ollama-plan/full-v3.log`, `.dart_tool/travelgo-verification/20261103T105511847Z-13808/`. Chuỗi `RPC_FAIL` trong contract fixture là ca lỗi được test, không phải pipeline failure.
- Hot reload ban đầu không có active app ở hai DTD IDE; sau khi cài APK và `flutter attach` tới phone, DTD project kết nối thành công và **hot reload PASS**. Dart MCP không ghi nhận runtime error trong lượt kiểm tra chat.

### Host API thật, Instruct đã pin

Ollama `0.40.14`; model prefix digest `0edcdef34593`; payload `think=false`, `stream=false`, `num_ctx=2048`, `num_predict=256`, temperature0,7. Input synthetic, không dùng credentials/chat cá nhân.

| Mẫu | Trạng thái | Thời gian |
| --- | --- | --- |
| Cold chào một câu | PASS, tiếng Việt, stop | 6.167 ms |
| Warm chuẩn bị đi Huế | PASS, stop | 4.778 ms |
| Warm du lịch gia đình | PASS, stop | 3.061 ms |
| Warm thiếu dữ liệu giá | PASS, nói chưa đủ dữ liệu | 1.618 ms |
| Warm ghi ngân sách | PASS, stop | 2.542 ms |
| Warm hỏi thông tin đi Đà Lạt | PASS, stop | 1.467 ms |

Warm median **2.542 ms**, max **4.778 ms**. Không có thinking text; nội dung không bị cắt. Đây là kiểm tính hoàn chỉnh/ngôn ngữ, không xác minh độc lập mọi kiến thức du lịch. Vẫn có câu diễn đạt/dữ kiện cần catalogue RAG, không gắn nhãn đã kiểm duyệt.

Phần cứng đọc: i5-11400H, RTX3050 Laptop4GB, RAM15,7GiB khả dụng. `ollama ps`:3,2GB model runtime, **28% CPU /72% GPU**, ctx2048; RAM còn khoảng2,17–2,39GB trong các mẫu. Không cam kết model nằm toàn GPU. Chưa xác minh đầy đủ web/API/Android Studio cùng tải sẽ dùng khi demo. Logs `runtime-results-instruct.jsonl`, `runtime-instruct-probe.log` trong scratch task.

Mẫu alias thinking cũ từng trả HTTP/schema hợp lệ nhưng đều `done_reason=length`, chưa ra câu cuối: **không nghiệm thu PASS**. Lưu riêng logs baseline để truy nguyên, không trộn với kết quả Instruct.

### Điện thoại

- Redmi Note8Pro đã kết nối ADB qua USB; reverse cổng11434 đã tạo, không mở Ollama ra LAN.
- Trước cập nhật không thấy editor/nhãn chưa lưu; không clear/uninstall dữ liệu. Guest có màn hình giới thiệu/Bỏ qua khi cold start.
- Build debug `lib/main.dart` **PASS**, Gradle28,5giây; APK SHA256 `2B70173E3471C28946965DBF9E106F4C13F745D53A1E95D53123F7ABB6687BA1`. `adb install -r` **Success** trên đúng phone; đây là bản debug/staging local, không deploy cloud.
- Phone **PASS**: gỡ reverse do task tạo → gửi câu hỏi tổng hợp → báo lỗi kết nối thật, giữ đúng1câu hỏi và có Thử lại; khôi phục reverse → retry nhận câu tiếng Việt thật, vẫn đúng1câu hỏi, không còn lỗi/loading. Ảnh `.dart_tool/local-ollama-plan/phone-real-reply.png`.
- Phone **PASS**: gửi khi model đang tải → Hủy yêu cầu → câu hỏi còn nguyên, sau khi chờ không có assistant đến muộn, loading dừng. JSON flags `.dart_tool/local-ollama-plan/phone-results.jsonl`, ảnh `phone-cancelled.png`.
- Phone **PASS** cold start: force-stop riêng app → mở lại → Bỏ qua giới thiệu/Guest → Hỏi AI; câu hỏi đã hủy vẫn giữ đúng1bản và không có assistant cũ. Mở lịch sử → chọn cuộc chat tổng hợp trước đó → câu hỏi và câu trả lời tiếng Việt còn nguyên, không có lỗi/loading. App được để ở hội thoại này, reverse USB được giữ để owner tiếp tục thử.
- Native Admin save/test bằng tài khoản thật và model-missing qua Admin: **NOT RUN**; hợp đồng đã kiểm bằng widget/service tests. Không đổi quyền hoặc đăng nhập Admin giả để kiểm tra. Exact simultaneous web/API/Android Studio load: **NOT RUN**, không lấy benchmark API làm bằng chứng thay thế.

## Problems

- Chưa nghiệm thu toàn bộ chatbot: RAG, hội thoại nhiều lượt, tách lịch sử theo chủ tài khoản, tìm web và apply vào lịch chưa nằm trong gói kết nối. Dùng dữ liệu thử tổng hợp; không chứng nhận quyền riêng tư đa tài khoản.
- RAM hạn chế khi mở nhiều ứng dụng; dùng phone, build trước demo, một request/model tại một thời điểm. Hai model tải về cùng tồn tại trên đĩa, nhưng chỉ Instruct được chọn mặc định và không tự fallback.
- Minor deferred từ reviewer: malformed JSON có thể được phân loại server thay vì invalidResponse (vẫn báo lỗi, không thành công giả); class comment cũ trong `LocalAiService` còn mô tả Qwen2.5/Hybrid RAG. Không dùng comment đó làm trạng thái implementation.
- Chưa push/merge/deploy cloud. Các kết quả NOT RUN nêu trên giữ nguyên; không chứng nhận toàn bộ hệ thống quản trị hoặc đồ án từ gói này.

## Lesson Candidate

1. Alias model trỏ phiên bản thinking khác dự kiến → chỉ dựa tên và `think=false` không đủ → pin tag/digest và kiểm metadata, câu trả lời cuối, `done_reason`, chất lượng/ngôn ngữ thực.
2. Đổi route/chat làm mất cảnh báo dữ liệu chưa lưu → state persistence bị gộp với lifecycle request/widget → giữ trạng thái chưa lưu theo session và hoàn tất reload cấu hình độc lập vòng đời màn hình.
