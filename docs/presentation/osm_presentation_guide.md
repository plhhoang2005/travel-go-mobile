# 🗺️ HƯỚNG DẪN THUYẾT TRÌNH & KỊCH BẢN LIVE DEMO PHÂN HỆ OPENSTREETMAP (OSM)
**Dự án**: TravelGO Mobile (Smart Mobility Decision Intelligence System)  
**Tác giả**: Hoang Pham (@plhhoang2005)  
**Phiên bản**: Production-Ready Presentation Kit  

---

## PHẦN 1: SLIDE TALKING POINTS (LỜI THOẠI KỸ THUẬT THEO TỪNG SLIDE)

### Slide 1: Bối cảnh & Vấn đề Thực tế (The Map Problem)
* **Ý chính**: *"Tại sao ứng dụng du lịch thông minh không chọn Google Maps Platform?"*
* **Lời thoại gợi ý**:
  > *"Kính thưa thầy cô và hội đồng, khi phát triển một hệ thống điều hướng du lịch, phản xạ đầu tiên của nhiều lập trình viên là dùng Google Maps API. Tuy nhiên, bài toán chi phí của Google Maps là một 'cái bẫy' lớn đối với các startup và ứng dụng du lịch: Google tính phí từ $5 đến $10 cho mỗi 1.000 lượt gọi Directions và Distance Matrix. Với hàng chục ngàn người dùng tra cứu lịch trình mỗi ngày, chi phí có thể lên tới hàng ngàn USD mỗi tháng.*  
  > *Chính vì vậy, TravelGO lựa chọn chiến lược **Hệ sinh thái Bản đồ Mở OpenStreetMap (OSM)** kết hợp động cơ định tuyến mã nguồn mở **OSRM (Open Source Routing Machine)**. Giải pháp này giúp chúng tôi hoàn toàn tự chủ 100% về mặt dữ liệu, tiết kiệm chi phí hạ tầng, tuân thủ giấy phép ODbL và mở ra khả năng tự triển khai máy chủ định tuyến riêng trong tương lai."*

---

### Slide 2: Kiến trúc Hệ thống Bản đồ Đa tầng (Multi-tier Resilient Architecture)
* **Ý chính**: *"Kiến trúc 3 lớp bảo đảm tính khả dụng cao và phản hồi thời gian thực."*
* **Lời thoại gợi ý**:
  > *"Kiến trúc phân hệ Bản đồ của TravelGO gồm 3 tầng liên kết chặt chẽ:  
  > 1. **Tầng Client Flutter**: Sử dụng `flutter_map` render native canvas, tích hợp cơ chế Dual-Tile Layer với Global CDN và Humanitarian HOT.  
  > 2. **Tầng Backend Spring Boot**: Đóng vai trò Single Source of Truth cho Decision Engine, gọi OSRM API, xác thực tọa độ hợp lệ và giải mã Polyline đường đi.  
  > 3. **Tầng Realtime Supabase**: Đồng bộ vị trí các thành viên trong nhóm du lịch (Group Location Radar) theo thời gian thực."*

---

### Slide 3: Triết lý "Zero Silent Fallbacks" (Luật 3 AGENTS.md)
* **Ý chính**: *"Tính kiên cố của ứng dụng di động trong điều kiện mạng yếu hoặc mất kết nối."*
* **Lời thoại gợi ý**:
  > *"Một điểm khác biệt cốt lõi trong triết lý kỹ thuật của TravelGO là **Luật 3: Zero Silent Fallbacks**. Khi đi du lịch đến vùng sâu vùng xa, việc mất sóng 4G hoặc server CDN bị nghẽn là điều không thể tránh khỏi.  
  > Ứng dụng TravelGO không bao giờ để xảy ra tình trạng crash trắng màn hình hay đơ ứng dụng. Nếu tile server chính gặp sự cố, hệ thống tự động chuyển sang server dự phòng. Nếu mất mạng hoàn toàn, hệ thống lập tức chuyển sang chế độ ngoại tuyến, vẽ đường thẳng ước lượng và hiển thị nhãn `[FALLBACK]` minh bạch cho người dùng."*

---

### Slide 4: Trí tuệ Quyết định & Thuật toán Tối ưu Lộ trình AI TSP
* **Ý chính**: *"Tránh bẫy chatbot văn bản suông (Luật 1) bằng mô hình toán học tương tác trực quan."*
* **Lời thoại gợi ý**:
  > *"TravelGO không phải là một chatbot hỏi-đáp văn bản thông thường. Thay vào đó, chúng tôi cung cấp một Dashboard tương tác. Người dùng có thể kéo-thả thứ tự các điểm dừng, hoặc bấm nút **'Tối ưu AI'** để kích hoạt giải thuật toán học Greedy 2-Opt TSP.  
  > Thuật toán sẽ tính toán ma trận cự ly trắc địa Haversine thực tế, tìm ra thứ tự di chuyển ngắn nhất và hiển thị minh bạch số km và thời gian tiết kiệm được trước khi áp dụng vào bản đồ OSM."*

---

## PHẦN 2: KỊCH BẢN LIVE DEMO 3 PHÚT (STEP-BY-STEP LIVE SCRIPT)

| Thời gian | Hành động trên App | Lời thuyết minh đồng thời |
| :--- | :--- | :--- |
| **00:00 - 00:30** | Mở tab **Bản đồ**.<br>Chỉ vào vị trí GPS sinh viên tại ĐH Bách Khoa.<br>Bấm **"Khám phá hành trình"** (Demo Đà Lạt 3 ngày). | *"Đây là giao diện Bản đồ thông minh TravelGO. Ứng dụng tự động định vị người dùng và khởi tạo lộ trình mẫu Đà Lạt 3 ngày 2 đêm với các điểm mốc Milestone Marker trực quan trên nền bản đồ OpenStreetMap."* |
| **00:30 - 01:10** | Dùng thanh chuyển đổi nổi `FloatingViewSwitch` chuyển sang chế độ **"Hành trình"**.<br>Bấm chuyển tab **[Ngày 1]**, **[Ngày 2]** trên thanh Day Chips. | *"Ở chế độ Hành trình, người dùng có thể lọc danh sách các trạm dừng chân theo từng ngày. Lộ trình được phân bổ khoa học: Ngày 1 nghỉ ngơi check-in, Ngày 2 tham quan khám phá, giúp tránh tình trạng quá tải thể lực cho du khách."* |
| **01:10 - 02:00** | Mở **RouteBuilderSheet** (hoặc bấm *"tự tạo lộ trình mới"*).<br>Thêm 2 trạm dừng (ví dụ: Chợ Đêm, Thung lũng Tình Yêu).<br>Thao tác kéo-thả đổi thứ tự trạm.<br>Bấm nút **"Tối ưu AI"**.<br>Bấm **"Chấp nhận"**. | *"Khi người dùng tự lên lịch trình và thêm nhiều trạm dừng rải rác, việc đi lại có thể bị zig-zag lãng phí xăng xe. Tôi chỉ cần bấm **'Tối ưu AI'**, thuật toán TSP sẽ phân tích cự ly Haversine tức thì và chỉ ra: 'Có thể tiết kiệm 3.8 km và 12 phút di chuyển'. Khi bấm Chấp nhận, lộ trình trên bản đồ OSM lập tức được tái cấu trúc theo thứ tự tối ưu."* |
| **02:00 - 02:30** | Bật tính năng **Group Location Radar**.<br>Chạm vào marker của thành viên trong nhóm (An, Lan, Khoa). | *"Trong chuyến đi nhóm, TravelGO hỗ trợ radar định vị các thành viên thời gian thực trên bản đồ OSM, giúp đoàn không bị lạc nhau tại các điểm du lịch đông đúc."* |
| **02:30 - 03:00** | **Tuyệt chiêu thuyết phục**: Bật Chế độ máy bay (hoặc ngắt Wifi điện thoại).<br>Bấm vẽ lại lộ trình.<br>Chỉ vào nhãn **[FALLBACK]** và banner cảnh báo ngoại tuyến. | *"Và đây là minh chứng cho Luật 3: Ngay cả khi tôi tắt hoàn toàn kết nối mạng trên điện thoại, ứng dụng vẫn hoạt động kiên cố, kích hoạt cơ chế Fallback ngoại tuyến và thông báo minh bạch cho người dùng mà không hề bị crash."* |

---

## PHẦN 3: BỘ CÂU HỎI PHẢN BIỆN THƯỜNG GẶP CỦA HỘI ĐỒNG (DEFENSE Q&A)

### Câu hỏi 1: "Tại sao không dùng Mapbox SDK hoặc Google Maps SDK cho đẹp và nhiều tính năng hơn?"
* **Trả lời trọng tâm**:
  1. **Bài toán chi phí**: Mapbox và Google Maps đều có ngưỡng thu phí rất nhanh (sau free tier). OSM là nguồn dữ liệu mở hoàn toàn miễn phí.
  2. **Quyền riêng tư & Tự chủ**: Với OSM và OSRM, toàn bộ máy chủ lưu trữ tile và định tuyến có thể tự triển khai on-premise hoặc private cloud, không phụ thuộc vào chính sách thay đổi giá của bên thứ 3.
  3. **Khả năng tùy biến**: `flutter_map` cho phép can thiệp trực tiếp vào các lớp TileLayer, MarkerLayer, PolylineLayer với hiệu năng Canvas native của Flutter rất nhẹ và mượt mà.

### Câu hỏi 2: "Máy chủ tile công cộng của OpenStreetMap có bị giới hạn băng thông (Rate Limit) không? Nếu bị chặn thì ứng dụng xử lý thế nào?"
* **Trả lời trọng tâm**:
  1. OpenStreetMap có chính sách Tile Usage Policy (yêu cầu User-Agent rõ ràng và attribution). TravelGO tuân thủ đầy đủ bằng `SimpleAttributionWidget`.
  2. TravelGO đã thiết kế kiến trúc **Dual-Tile Layer**: Khi server chính `tile.openstreetmap.org` gặp sự cố tải tile, callback `errorTileCallback` được kích hoạt và lớp `tile.openstreetmap.fr/hot` (Humanitarian) sẽ đóng vai trò dự phòng.
  3. Lộ trình dài hạn: Dự án đã sẵn sàng phương án triển khai một Tile Cache Server riêng (dùng Nginx/TileServer GL) hoặc đóng gói Offline Vector Tiles (MBTiles) trực tiếp vào thiết bị.

### Câu hỏi 3: "Thuật toán tối ưu TSP chạy trực tiếp trên điện thoại có làm chậm app hoặc đơ giao diện không?"
* **Trả lời trọng tâm**:
  1. **Thiết kế phân tầng thông minh**:
     * Với số lượng trạm $\le 7$ (chiếm 95% trường hợp chuyến đi 1-3 ngày của du khách), thuật toán duyệt hoán vị tối ưu trong chưa đầy **1 mili-giây**.
     * Với số lượng trạm lớn hơn, thuật toán chuyển sang **Nearest-Neighbor kết hợp 2-Opt** với giới hạn 50 vòng lặp, thời gian xử lý $< 5$ mili-giây.
  2. **Tuân thủ Luật 4 (Non-Blocking UI)**: Mọi tác vụ tính toán và vẽ lại đường đi đều được chạy bất đồng bộ (`async`/`await`), không bao giờ gây giật lag (frame drop) trên Main UI Thread của Flutter.
