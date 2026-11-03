# TravelGO — thiết lập chatbot local với Qwen3 4B

Owner chọn Qwen3 4B và điện thoại Android thật ngày 03/11/2026. Model chạy trên laptop; APK không chứa model. Các bước dưới là hướng dẫn, không phải bằng chứng đã nghiệm thu.

Pin chính xác `qwen3:4b-instruct-2507-q4_K_M`: bản Instruct của Qwen3 4B trả lời trực tiếp. Không dùng alias `qwen3:4b` cho cấu hình này vì alias hiện trỏ bản thinking-only. [Biến thể chính thức](https://ollama.com/library/qwen3/tags), [Qwen model card](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507).

## 1. Cài model trên Windows

Cài [Ollama chính thức](https://ollama.com/download/windows), mở ứng dụng và mở terminal mới:

```powershell
ollama --version
ollama pull qwen3:4b-instruct-2507-q4_K_M
ollama list
```

Giữ Ollama chạy nền. Chỉ dùng `ollama serve` nếu chưa có dịch vụ; lỗi cổng đang dùng thường có nghĩa một instance đã chạy. Không cần API key Gemini. Model mặc định là bản [Q4_K_M khoảng 2,5 GB](https://ollama.com/library/qwen3:4b-instruct-2507-q4_K_M); bộ nhớ khi chạy còn bao gồm ngữ cảnh và bộ đệm.

## 2. Kiểm tra host trước khi mở app

```powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags'

$travelGoPayload = @{
    model = 'qwen3:4b-instruct-2507-q4_K_M'
    stream = $false
    think = $false
    messages = @(@{ role = 'user'; content = 'Chào tôi bằng một câu tiếng Việt.' })
    options = @{ num_ctx = 2048; num_predict = 256; temperature = 0.7 }
} | ConvertTo-Json -Depth 6

$travelGoReply = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/chat' `
    -Method Post -ContentType 'application/json; charset=utf-8' `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($travelGoPayload)) -TimeoutSec 120

$travelGoReply.message.content
ollama ps
```

Phải có nội dung assistant thật. Kiểm tra phiên bản/model qua `/api/show` nếu chế độ `think=false` không được hỗ trợ. Không coi API danh sách model đơn thuần là bằng chứng sinh câu trả lời thành công. [Chat API](https://docs.ollama.com/api/chat), [thinking](https://docs.ollama.com/capabilities/thinking).

## 3. Điện thoại qua USB

1. Bật Developer options và USB debugging trên điện thoại, cắm cáp hỗ trợ dữ liệu, chấp nhận thông báo cho phép máy tính.
2. Tìm Android SDK từ `android/local.properties`. Máy của owner hiện dùng:

```powershell
$travelGoAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $travelGoAdb devices -l
```

3. Thay `<PHONE_ID>` bằng serial đúng trong danh sách, không chọn nhầm thiết bị:

```powershell
& $travelGoAdb -s <PHONE_ID> reverse tcp:11434 tcp:11434
& $travelGoAdb -s <PHONE_ID> reverse --list
```

4. Chạy app từ thư mục project, hoặc cài APK đã kiểm tra. Không clear data/uninstall nếu còn bản nháp cần giữ.

```powershell
flutter run -d <PHONE_ID> -t lib/main.dart
```

5. Cấu hình mặc định cho phone: `http://127.0.0.1:11434`, model `qwen3:4b-instruct-2507-q4_K_M`. Nếu dùng emulator thì đổi địa chỉ local thành `http://10.0.2.2:11434`.

Kết nối này cần USB/ADB còn hoạt động; rút cáp hoặc khởi động lại thiết bị có thể cần tạo reverse lại. Không cần mở Ollama ra LAN hoặc chỉnh firewall cho phương án USB. [Android reverse forwarding](https://developer.android.com/develop/ui/views/layout/webapps/access-local-server).

## 4. Cấu hình trong TravelGO

Admin → Quản trị AI → Cấu hình AI trên thiết bị này:

- Nhập địa chỉ, model đã tải, chỉ dẫn trả lời và độ sáng tạo.
- **Kiểm tra kết nối** kiểm tra model rồi gọi sinh câu trả lời thật. Không tự lưu form; chỉnh form làm kết quả test trước đó hết hiệu lực.
- **Lưu cấu hình** lưu trên đúng thiết bị và nạp cho chatbot. Lưu được không đồng nghĩa kết nối được; request đang chạy giữ nguyên cấu hình ban đầu, request sau dùng cấu hình mới.
- Ở nút **Hỏi AI**, nhãn hiển thị Ollama/model. Lỗi giữ câu hỏi và cho thử lại; thử lại không nhân đôi câu hỏi. Hủy hoặc chuyển chat bỏ qua phản hồi của request cũ.
- Chưa có RAG hoặc tìm web trong gói kết nối này; câu trả lời chưa phải dữ kiện catalogue được kiểm duyệt. Lịch sử nguồn cũ được giữ trong storage nhưng không trình bày như evidence đã xác minh.

Settings lưu một JSON tại key `travelgo_local_ai_settings_v1`; không dùng API key Gemini hoặc model cloud trong luồng local. Lịch sử chat hiện vẫn ở cấp thiết bị, chưa tách chủ tài khoản: dùng dữ liệu thử tổng hợp, không coi đây là bản đã nghiệm thu quyền riêng tư nhiều tài khoản.

## 5. Demo trên laptop của owner

Phần cứng đã đọc: i5-11400H, RTX 3050 Laptop 4 GB VRAM, khoảng 16 GB RAM. Trước khi cài model, snapshot RAM còn khoảng 2 GB; chưa đo inference tại snapshot này.

- Dùng phone, không chạy emulator đồng thời; giảm ứng dụng nền trước demo.
- Build/cài app trước khi demo, không chạy Gradle/full tests song song inference.
- Dùng một model, từng request; giữ `num_ctx=2048`, `num_predict=256`, `think=false` làm cấu hình bắt đầu. Đây không phải bảo đảm tốc độ hoặc đủ VRAM.
- Gửi một câu ngắn để làm nóng model trước demo. Kiểm tra `ollama ps` để biết model đang chạy CPU/GPU thế nào.
- Đo một cold request và ít nhất năm warm requests với web/API và Android Studio thực sự sẽ dùng trong buổi demo. Ghi thời gian, RAM, VRAM và kết quả; không suy từ dung lượng file.
- Mục tiêu đề xuất: cold ≤120 giây; 5/5 warm requests hợp lệ, từng request ngắn ≤30 giây; UI không đơ/crash. Nếu không đạt, báo kết quả và điều chỉnh có chủ đích, không âm thầm đổi model hay trả nội dung mẫu.

## 6. Xử lý lỗi

| Hiện tượng | Kiểm tra |
| --- | --- |
| Không nhận diện `ollama` | Mở terminal mới sau cài; kiểm tra đường dẫn cài chính thức. |
| Host từ chối kết nối | Mở Ollama, thử lại `/api/tags` trên laptop trước. |
| Model chưa tìm thấy | Chạy `ollama list`; tải đúng `qwen3:4b-instruct-2507-q4_K_M`, không chỉ model khác cùng họ. |
| Host thành công, phone thất bại | Kiểm tra USB authorization, đúng serial, reverse còn hoạt động và base URL là `127.0.0.1`. |
| Phản hồi quá lâu | Kiểm tra RAM/VRAM/`ollama ps`; app cho hủy và thử lại, không tự gọi lặp. |
| HTTP 200 nhưng nội dung sai/rỗng | Báo phản hồi không hợp lệ; không coi thành công hoặc tạo câu trả lời thay thế. |
| Không lưu được cấu hình/hội thoại | Giữ dữ liệu trong bộ nhớ/form, kiểm tra dung lượng thiết bị; thử lại. Lỗi lưu assistant không gọi lại model. |

Kết thúc demo có thể gỡ riêng reverse đã tạo:

```powershell
& $travelGoAdb -s <PHONE_ID> reverse --remove tcp:11434
```

## Bằng chứng nghiệm thu

Kết quả thực tế ghi trong `docs/phase-3/LOCAL_AI_QWEN3_HANDOVER_20261103.md` sau khi thu log. Chỉ ghi PASS cho bước thực sự chạy: kiểm thử tự động, API host, APK/phone, tốc độ đồng thời là các loại bằng chứng riêng.
