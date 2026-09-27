---
name: anti-slop-ui
description: Internal Design Director and Anti-AI-Slop Skill for Flutter Mobile. Enforces tactile, deterministic UI design, strict design tokens (Theme.of(context).colorScheme), interactive dashboards (fl_chart, Slider, Timeline), spacing scales (4/8/16/24px), and eliminates generic AI aesthetic tells.
---

# Anti-AI-Slop & Flutter UI/UX Design System Skill

Kỹ năng nội bộ định hướng thiết kế và loại bỏ triệt để **AI-Slop** trong ứng dụng Flutter Mobile (TravelGO). Kế thừa triết lý **Design Director & Deterministic Rails** của `pbakaus/impeccable` và bộ **33 Tells** nhận diện của `yetone/kill-ai-slop`.

---

## 1. Triết Lý Thiết Kế: Craft Over Commodity

AI thường có xu hướng tạo ra các giao diện "trung bình cộng thống kê": nền gradient tím xanh, bo góc bóng bay 24-32px, card lồng card rỗng tuếch, và biến mọi bài toán phức tạp thành một khung chat hỏi-đáp lười biếng.

Kỹ năng này bắt buộc Agent phải tư duy như một **Mobile Product Designer**:
1. **Direct Manipulation**: Người dùng di động muốn chạm, kéo slider, chạm tooltip biểu đồ, và xem lịch trình trực quan — KHÔNG muốn gõ văn bản hỏi-đáp.
2. **Deterministic Tokens**: Màu sắc, độ bo góc, khoảng cách phải tuân theo hệ thống token chặt chẽ của Flutter (`Theme.of(context).colorScheme`), không hardcode mã màu lạ.
3. **High Information Density**: Mỗi pixel trên màn hình điện thoại đều quý giá. Ưu tiên metric cards, bảng so sánh và timeline thay vì các card rỗng chứa toàn padding.

---

## 2. Shared Design Commands (Các Thao Tác Thiết Kế)

Khi review hoặc xây dựng UI, Agent áp dụng 5 thao tác cốt lõi:

| Command / Mindset | Ý nghĩa công năng | Quy chuẩn thực thi trên Flutter |
| :--- | :--- | :--- |
| **`/audit`** | Kiểm toán slop trên widget | Quét code tìm: màu hardcode (`Color(0xFF...)`), `BorderRadius` > 16, card lồng card, emoji thừa, hoặc layout dạng chatbot. |
| **`/dashboardize`** | Biến form/chat thành Dashboard | Thay thế các câu hỏi văn bản bằng `Slider` trọng số, `ParetoChartWidget` (đánh đổi chi phí-thời gian), `BudgetDonutChart` và `ItineraryTimelineWidget`. |
| **`/distill`** | Chưng cất, loại bỏ rác thị giác | Xóa bỏ các `LinearGradient` trang trí, glow shadow neon, bỏ các lớp `Card` bọc ngoài không cần thiết; dùng hairline border (`slate200`) để ngăn cách. |
| **`/polish`** | Chuẩn hóa token và nhịp điệu | Ép toàn bộ `EdgeInsets` về hệ số 4 (`4/8/16/24px`), dùng `Theme.of(context).colorScheme` cho màu bề mặt và tương phản. |
| **`/typeset`** | Phân cấp độ sâu văn bản | Áp dụng đúng tỷ lệ kích thước: Title 18-20px bold, Subtitle 14-15px w500, Body 13-14px w400, Caption 11-12px slate500. Không dùng font serif lạ cho UI kỹ thuật. |

---

## 3. Flutter Anti-Slop Matrix (Bảng Đối Chiếu & Thay Thế)

### 3.1. Màu Sắc (Color)
- ❌ **AI Slop**: `LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)])` (tím-xanh AI mặc định) hoặc đổ bóng phát sáng neon rực rỡ.
- ✅ **Clean Flutter**: 
  ```dart
  // Dùng màu chủ đạo từ Theme hoặc AppTheme
  color: Theme.of(context).colorScheme.primary, // AppTheme.primaryColor (#0284C7 Sky)
  backgroundColor: Theme.of(context).colorScheme.surface,
  ```
- ❌ **AI Slop**: Status alert một màu ở 3 độ opacity (nền đỏ 10%, viền đỏ 50%, chữ đỏ đậm).
- ✅ **Clean Flutter**: Nền phẳng trung tính (`AppTheme.slate100`), viền hairline (`AppTheme.slate200`), trạng thái biểu đạt bằng chữ in đậm kèm icon ngữ nghĩa và một accent color tiết chế.

### 3.2. Bố Cục & Card (Layout & Components)
- ❌ **AI Slop**: Lồng `Card` bên trong `Card`, mỗi card lại có shadow to và bo góc `BorderRadius.circular(24)` hoặc `32`.
- ✅ **Clean Flutter**: 
  ```dart
  // Giữ BorderRadius tối đa 16px (trừ khi là pill capsule)
  Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppTheme.slate200, width: 1),
    ),
    child: ...
  )
  ```
- ❌ **AI Slop**: Spacing tùy tiện (`EdgeInsets.all(13)`, `SizedBox(height: 19)`).
- ✅ **Clean Flutter**: Hệ số 4 nghiêm ngặt:
  - `4px` (xs): Giữa nhãn và icon phụ.
  - `8px` (sm): Giữa các dòng trong cùng một block.
  - `16px` (md): Padding chuẩn trong thẻ Card, khoảng cách giữa các phần tử liên quan.
  - `24px` (lg): Khoảng cách giữa các section độc lập.

### 3.3. Tương Tác & Nghiệp Vụ (Direct Manipulation vs Chatbot Trap)
- ❌ **AI Slop (Chatbot Trap)**: 
  * "Chào bạn, bạn muốn đi đâu? Hãy chat với tôi để lên lịch trình."
  * Màn hình kết quả là một đoạn text dài vô tận do LLM sinh ra.
- ✅ **Clean Flutter (TravelGO Decision Dashboard)**:
  * **Cấu hình trực quan**: `Slider` chỉnh ngân sách (1–20 triệu VNĐ) và các thanh kéo tỷ trọng (Chi phí, Thời gian, Trải nghiệm).
  * **So sánh phương tiện**: `ParetoChartWidget` bằng `fl_chart` hiển thị trực tiếp trục $X$ (Thời gian) vs trục $Y$ (Chi phí) với điểm tối ưu nổi bật.
  * **Phân bổ ngân sách**: `BudgetDonutChart` bằng `fl_chart` hiển thị rõ tỷ lệ % và số tiền từng khoản (Di chuyển, Khách sạn, Ăn uống, Vé tham quan).
  * **Lịch trình**: `ItineraryTimelineWidget` hiển thị thẻ mốc giờ, địa điểm và chi phí theo từng ngày.
  * **Tầng LLM**: Thu gọn vào một `ExplanationCard` ngắn gọn tóm tắt lý do lựa chọn, không chiếm quyền điều khiển của người dùng.

### 3.4. Chuyển Động (Motion)
- ❌ **AI Slop**: Animation giật nảy (`Curves.bounceOut`), xoay lộn vòng, hoặc scale nhảy tưng tưng khi bấm.
- ✅ **Clean Flutter**: 
  - Chuyển động nhẹ nhàng phục vụ định hướng (orientation):
  - Thời lượng: 200–300ms.
  - Easing: `Curves.easeInOut` hoặc `Curves.fastOutSlowIn`.

### 3.5. Ngôn Từ & Copywriting
- ❌ **AI Slop**: *"Không chỉ là một công cụ — đó là tương lai của du lịch 🚀✨"*
- ✅ **Clean Flutter**: Con số thực, dữ liệu thực: *"Đề xuất tối ưu cho ngân sách 4.500.000 đ với thời gian di chuyển 5 giờ 30 phút."*

---

## 4. Quy Trình Self-Audit Trước Khi Đóng Task

Trước khi hoàn thành bất kỳ task UI nào, Agent bắt buộc tự đặt 4 câu hỏi:
1. `[ ]` **Token Check**: Có màu nào bị hardcode `Color(0xFF...)` lạ không? Đã dùng `Theme.of(context).colorScheme` chưa?
2. `[ ]` **Radius & Spacing Check**: Có bo góc nào vượt quá `16px` không? Spacing có tuân thủ chuẩn `4/8/16/24px` không?
3. `[ ]` **Anti-Chatbot Check**: Màn hình này có thể thao tác trực quan bằng slider/biểu đồ không, hay đang ép người dùng đọc một bức tường chữ?
4. `[ ]` **Verify**: Đã chạy `flutter analyze` (0 errors) và `flutter test` thành công chưa?
