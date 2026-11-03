# Kế Hoạch Triển Khai: Tinh Gọn & Nâng Cấp UX Lập Chuyến Đi, Trợ Giúp AI, Ngân Sách và Xem Lại

## 1. Mục tiêu và Phạm vi (Scope)
Thực hiện yêu cầu của Product Owner / User dựa trên 6 ảnh chụp màn hình thực tế:
1. **Màn hình "Lập chuyến đi" (`SelectedDestinationControls` / `HomePlannerScreen`)**:
   - Loại bỏ các khối văn bản hướng dẫn rườm rà, lặp lại.
   - Các thông tin quan trọng/lưu ý ("Thông tin chưa lưu", "Hệ thống đồng hành...") đưa vào dạng Accordion (xổ xuống khi chạm) hoặc Info Chip tinh gọn.
   - Bố cục gọn gàng, làm nổi bật thông tin cốt lõi (Điểm đến, Thời gian, Số người, Ngân sách, Nơi xuất phát).
2. **Giao diện "Đề xuất lịch từ AI" (`AiGenerationPreview`)**:
   - *Trước khi tạo*: Tinh gọn thông tin tham số gửi AI thành Card tổng hợp (Chips cho sở thích); đưa điều khoản bảo mật vào thẻ *"Chính sách & Bảo mật AI"* có thể mở rộng (mặc định gọn gàng).
   - *Sau khi AI tạo*: Bỏ khối disclaimer dài lê thê trên đầu; phân nhóm hoạt động theo từng Ngày (Ngày 1, Ngày 2, Ngày 3...) với Card hoạt động trực quan (giờ giấc badge, chi phí nổi bật, icon điểm đến) thay vì văn bản phẳng.
3. **Màn hình "Chỉnh lịch trình - Ngân sách" (`ManualBudgetPanel`)**:
   - Chuyển đổi danh sách chi tiêu từ dạng thô sơ (Divider + Text dòng) sang Card chi tiêu trực quan: có Icon danh mục (ẩm thực 🍜, di chuyển 🚗, tham quan 🏛️, lưu trú 🏨...), số tiền nổi bật, tag trạng thái rõ ràng, nút *"Sửa dự kiến"* / *"Sửa khoản đã chi"* trang nhã.
4. **Màn hình "Xem lại trước khi lưu" (`ManualSavePreview`)**:
   - Thay đổi cách hiển thị các dòng thay đổi (`_ChangeRow`) và cảnh báo (`_IssueRow`) từ văn bản thuần túy sang các thẻ nhóm trực quan: Thẻ thông tin chung, Thẻ thay đổi hoạt động (có icon ➕ Thêm, ✏️ Sửa, 🗑️ Xóa), Thẻ thay đổi ngân sách và Thẻ lưu ý/cảnh báo nổi bật.

---

## 2. Chi Tiết Thay Đổi Theo Từng Thành Phần

### Task 1: Tinh gọn `SelectedDestinationControls` (`selected_destination_controls.dart`)
- **Hiện trạng**: Văn bản "Điểm đến đã chọn", "Hệ thống sẽ đồng hành...", "Đây là thông tin đầu vào...", "Thông tin này chưa được lưu..." xếp chồng dạng cột làm trôi form dữ liệu xuống dưới.
- **Giải pháp**:
  - Tích hợp nút *"Đổi điểm đến"* / *"Để app gợi ý điểm đến"* gọn gàng ngay dưới hoặc cạnh thẻ `TripLivePreview`.
  - Gom các lưu ý vào một thẻ thông tin nhỏ gọn:
    ```dart
    // Collapsible Notice Banner
    ExpansionTile / AnimatedContainer:
    - Tiêu đề ngắn: "Lưu ý phiên làm việc & điểm đến" kèm icon Info
    - Nội dung xổ xuống: Hiển thị các thông điệp hỗ trợ và lưu ý chưa lưu
    ```
  - Giữ nguyên các Text và Finder quan trọng cho test: `Tự lập lịch trình`, `Để app gợi ý điểm đến`, `Thông tin này chưa được lưu`.

### Task 2: Hiện đại hóa Dialog "Đề xuất lịch từ AI" (`ai_generation_preview.dart`)
- **Hiện trạng**: Dialog hiển thị toàn bộ disclaimers và danh sách lịch trình dạng Text thuần túy, dài dòng và khó đọc.
- **Giải pháp**:
  - *Phần thông số*: Card nhỏ gọn với biểu tượng AI và các tags (Điểm đến, N-ngày, Ngân sách, Sở thích).
  - *Phần điều khoản*: Thẻ collapsible *"Điều khoản dữ liệu & bảo mật"* (mặc định đóng, người dùng ấn xem thì mở xổ xuống).
  - *Sau khi tạo đề xuất*:
    - Hiển thị Card tóm tắt AI kèm Mascot GoAI nhỏ.
    - Nhóm các hoạt động thành từng Ngày:
      - Header Ngày: `Ngày 1`, `Ngày 2` với icon lịch.
      - Thẻ hoạt động: Khung bo tròn, Giờ giấc `[ 14:00 - 15:00 ]` dạng pill, Tên hoạt động in đậm, Ước tính chi phí `1.000.000 đ` / `Miễn phí` có màu sắc nổi bật.
    - Căn cứ dữ liệu: Nút *"Xem căn cứ (N nguồn)"* / Badge Catalogue đặt tinh tế.
  - Bảo đảm tương thích test: Giữ các ValueKey: `ai-consent`, `ai-generate`, `ai-view-evidence`, `ai-cancel`, `ai-apply`.

### Task 3: Nâng cấp Card Chi tiêu trong "Ngân sách" (`manual_budget_panel.dart`)
- **Hiện trạng**: `_ExpenseRow` chỉ có một dòng kẻ ngang và 3 dòng text thô nối nhau bằng dấu `\n`.
- **Giải pháp**:
  - Thiết kế `_ExpenseCard`:
    - Container có border radius 12, viền nhẹ, bóng mờ.
    - Hàng 1: Icon danh mục (theo `e.category`: Restaurant cho ẩm thực, Commute cho di chuyển, Hotel cho lưu trú...) + Tiêu đề khoản chi + Badge trạng thái (`Đang tính` xanh lá / `Ngừng tính` xám).
    - Hàng 2: Số tiền lớn, rõ ràng (e.g. `800.000 ₫`) + Số lượng đơn vị (`1 đơn vị`).
    - Hàng 3: Tên hoạt động liên kết (nếu có) + Nút action *"Sửa dự kiến"* / *"Sửa khoản đã chi"*.

### Task 4: Trực quan hóa Màn hình "Xem lại trước khi lưu" (`manual_save_preview.dart`)
- **Hiện trạng**: Toàn bộ thay đổi và cảnh báo đều render bằng widget `Text` đơn thuần.
- **Giải pháp**:
  - Cấu trúc lại danh sách thay đổi `_ChangeRow`:
    - Nhóm theo các phần: Thông tin chuyến đi, Hoạt động lịch trình, Khoản chi dự kiến, Khoản đã chi.
    - Mỗi thay đổi là một thẻ nhỏ với Icon tương ứng:
      - ➕ Xanh lá: Thêm mới (ngày, hoạt động, khoản chi)
      - ✏️ Cam/Vàng: Chỉnh sửa / chuyển đổi
      - 🗑️ Đỏ: Xóa / loại bỏ
  - Cấu trúc lại `_IssueRow`:
    - Hiển thị dạng Card cảnh báo (màu cam nhạt hoặc đỏ nhạt) với Icon cảnh báo rõ ràng.
    - Nút *"Đi sửa nội dung"* và *"Ghi lý do chấp nhận"* thiết kế dạng button trực quan.

---

## 3. Kế hoạch Kiểm Thử (Verification Plan)
1. **Chạy `flutter analyze`**:
   - Kiểm tra toàn diện toàn bộ mã nguồn, bảo đảm 0 lỗi, 0 cảnh báo.
2. **Chạy các bộ Unit & Widget Tests liên quan**:
   - `test/manual_budget_ui_test.dart`
   - `test/manual_planner_screen_test.dart`
   - `test/editable_saved_trip_ui_test.dart`
   - `test/ai_assistant_test.dart`
   - `test/destination_ai_entry_test.dart`
   - `test/planner_destination_ui_test.dart`
3. **Bảo toàn Hợp đồng Kiểm thử (Test Invariants)**:
   - Tất cả các finder chính (`Key`, `Text`, `Type`) phải được giữ nguyên hoặc nâng cấp tương thích 100%.
