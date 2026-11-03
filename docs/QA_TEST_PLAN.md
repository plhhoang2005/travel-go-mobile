# KẾ HOẠCH KIỂM THỬ TỪNG CHỨC NĂNG (QA TEST PLAN & CHECKLIST)
**Dự án:** TravelGO Mobile Client  
**Phiên bản kiểm thử:** `feat/team-integration-v1` (Pull Request #54)  
**Thời gian thực hiện:** Tháng 11/2026  
**Mục tiêu:** Cung cấp bộ tiêu chí kiểm thử nghiệm thu (UAT / Functional QA) rõ ràng cho 4 thành viên trong nhóm để rà soát thực tế trên thiết bị trước khi Tech Lead bấm merge vào nhánh `main`.

---

## 1. Hướng Dẫn Kéo Mã Nguồn & Chạy Ứng Dụng Dành Cho Thành Viên

Mỗi thành viên mở terminal trên máy tính của mình và thực hiện các bước sau:

```bash
# 1. Cập nhật các branch mới nhất từ GitHub
git fetch origin

# 2. Chuyển sang nhánh tích hợp cần kiểm thử
git checkout feat/team-integration-v1

# 3. Kéo mã nguồn mới nhất của nhánh
git pull origin feat/team-integration-v1

# 4. Cập nhật thư viện
flutter pub get

# 5. Chạy ứng dụng trên máy ảo hoặc điện thoại Android thật
flutter run
```

> [!NOTE]
> - Phiên bản này đã vượt qua 100% kiểm tra tự động (`flutter analyze` 0 lỗi và 1319/1319 `flutter test` passed).
> - Thành viên ghi nhận kết quả: Đạt ghi **PASS**, Lỗi ghi **FAIL** kèm mô tả vào bảng bên dưới.

---

## 2. Bảng Kiểm Thử Chi Tiết Từng Chức Năng (40 Test Cases)

### Module 1: Khám Phá & Điểm Đến (Home & Discovery)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-01** | Danh sách điểm đến nổi bật | Mở tab **Khám phá** (Tab 1) | Hiển thị danh sách các điểm đến Việt Nam (Hà Nội, Hạ Long, Đà Nẵng, Huế,...) với ảnh bìa rõ nét. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-02** | Tìm kiếm điểm đến | Nhập từ khóa (vd: "Đà Nẵng", "Huế") vào thanh tìm kiếm | Danh sách lọc tức thì theo từ khóa nhập vào, không đơ lag. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-03** | Lọc theo thẻ (Filter Chips) | Bấm chọn các chip lọc (Biển, Văn hóa, Ẩm thực,...) | Lọc chính xác danh sách các điểm đến thuộc chủ đề tương ứng. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-04** | Chi tiết điểm đến & Nguồn ảnh | Chạm vào một thẻ điểm đến bất kỳ | Chuyển sang màn hình chi tiết, ảnh lớn có nút icon tròn hiển thị thông tin bản quyền/nguồn ảnh minh bạch. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-05** | Nút CTA "Lập lịch trình" | Tại màn hình chi tiết điểm đến, bấm nút **"Lập lịch trình cho điểm đến này"** | Tự động chuyển sang màn hình Lập lịch với Điểm đến đã được điền sẵn. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |

---

### Module 2: Lập Lịch Trình & Ngân Sách (Manual Planner & Budget)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-06** | Nhập thông số chuyến đi | Vào tab **Lập lịch** (Tab 2), chọn Điểm xuất phát, Điểm đến, Số ngày (1-30), Số người, Ngân sách | Các trường nhập mượt mà, hỗ trợ cả chip chọn nhanh và nhập tùy biến. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-07** | Thêm hoạt động vào ngày | Bấm **"Thêm hoạt động"** ở Ngày 1, nhập Tên, Địa điểm, Thời gian, Chi phí ước tính | Hoạt động xuất hiện ngay trên danh sách của Ngày 1 kèm badge thời gian và chi phí. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-08** | Tính toán ngân sách tự động | Thêm 2-3 hoạt động có chi phí khác nhau | Thẻ tổng kết ngân sách ở đầu trang tự nhảy số tổng tiền dự kiến tương ứng. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-09** | Phân loại ngân sách thực tế | Chuyển sang tab/chế độ **"Chi thực tế"** trong ngày | Cho phép nhập tiền đã chi thực tế, phân biệt rõ: Ngân sách mục tiêu, Dự tính, Đã chi. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-10** | Chuyển đổi giữa các ngày | Chuyến đi có từ 2 ngày trở lên, chạm vào Ngày 1, Ngày 2, Ngày 3 trên thanh ngày | Danh sách hoạt động chuyển đổi mượt mà theo đúng ngày được chọn. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-11** | Lưu nháp chế độ Khách (Guest) | Tạo lịch ở chế độ Khách, thoát hẳn ứng dụng rồi mở lại | Lịch trình đang soạn vẫn còn nguyên, không bị mất dữ liệu. | `[ ] PASS`<br>`[ ] FAIL` | |

---

### Module 3: Xác Thực, Tài Khoản & Vòng Đời Ứng Dụng (Auth & Session)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-12** | Trải nghiệm chế độ Khách (Guest) | Mở app lần đầu hoặc bấm "Tiếp tục với tư cách Khách" | Dùng được đầy đủ tính năng khám phá, xem bản đồ, tạo lịch trình nháp không bị chặn. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-13** | Đăng nhập / Đăng ký tài khoản | Vào màn hình Đăng nhập từ Avatar góc phải AppBar, nhập email/mật khẩu | Đăng nhập thành công, hiển thị thông báo chào mừng và cập nhật Avatar. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-14** | Nhập lịch trình Guest vào Account | Soạn 1 lịch ở Guest -> Bấm Lưu chuyến đi -> App yêu cầu đăng nhập -> Đăng nhập | Hiển thị màn hình xác nhận nhập (Import preview) chuyến đi nháp vào tài khoản đã đăng nhập. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-15** | Đăng xuất tài khoản | Bấm Đăng xuất từ màn hình Cá nhân (Profile) | Đưa về trạng thái Khách sạch, danh sách chuyến đi của tài khoản cũ bị ẩn ngay lập tức. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-16** | Đưa app xuống nền & Mở lại (Lifecycle) | Đang mở app, bấm nút Home để app xuống background 10 giây rồi mở lại | Không bị văng app (crash), giữ nguyên màn hình và trạng thái đăng nhập. | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |
| **TC-17** | Avatar góc trên AppBar | Bấm vào biểu tượng Avatar ở góc trên cùng bên phải màn hình | Mở nhanh trang Thông tin cá nhân (nếu đã đăng nhập) hoặc trang Đăng nhập (nếu là Khách). | `[x] PASS`<br>`[ ] FAIL` | Chi Hậu (Owner) - Đạt |

---

### Module 4: Chuyến Đi Của Tôi (My Trips & Offline Mode)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-18** | Xem danh sách chuyến đi đã lưu | Vào tab **Chuyến đi** (Tab 5) khi đã đăng nhập và có chuyến đi đã lưu | Hiển thị danh sách các thẻ chuyến đi với tiêu đề, ngày tạo, tổng chi phí. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-19** | Kéo để làm mới (Pull-to-refresh) | Vuốt ngón tay từ trên xuống dưới tại danh sách chuyến đi | Hiển thị vòng xoay tải và cập nhật lại danh sách mới nhất từ bộ nhớ/server. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-20** | Xem chi tiết khi mất mạng (Offline) | Bật Chế độ máy bay (Airplane mode) rồi mở xem một chuyến đi đã lưu | Vẫn xem được toàn bộ lịch trình, hoạt động đã lưu từ cache ổ đĩa mà không bị lỗi mạng. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-21** | Xóa chuyến đi có xác nhận | Bấm nút Xóa (thùng rác) tại một chuyến đi | Hiện modal xác nhận "Bạn có chắc muốn xóa?". Nếu bấm Hủy thì giữ nguyên; bấm Đồng ý thì chuyến đi bị xóa. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-22** | Màn hình danh sách rỗng (Empty State) | Mở tab Chuyến đi khi tài khoản chưa lưu chuyến đi nào | Hiển thị giao diện rỗng đẹp mắt (hình minh họa + nút "Tạo chuyến đi đầu tiên"). | `[ ] PASS`<br>`[ ] FAIL` | |

---

### Module 5: Bản Đồ Tương Tác (Interactive Map)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-23** | Hiển thị bản đồ OpenStreetMap | Vào tab **Bản đồ** (Tab 3) | Bản đồ Việt Nam tải lên với đầy đủ các điểm ghim (markers) tương ứng các danh lam thắng cảnh. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-24** | Chạm vào Marker trên bản đồ | Chạm vào một marker bất kỳ trên bản đồ | Hiển thị popup card tóm tắt tên địa điểm, ảnh nhỏ và nút "Xem chi tiết". | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-25** | Thao tác thu phóng (Zoom & Pan) | Dùng 2 ngón tay phóng to, thu nhỏ và cuộn bản đồ liên tục | Thao tác mượt mà, khung hình ổn định, không bị đơ hoặc giật lag nhờ cơ chế throttled zoom. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-26** | Chế độ mất mạng trên bản đồ | Tắt mạng Wi-Fi/4G và mở bản đồ | Bản đồ tự động dùng cache offline hoặc chuyển sang nguồn tile dự phòng Arcgis, không crash app. | `[ ] PASS`<br>`[ ] FAIL` | |

---

### Module 6: Trợ Lý AI Nội Bộ (Local AI Assistant)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-27** | Mở màn hình Trợ lý AI | Vào tab **Trợ lý AI** (Tab 4) từ thanh điều hướng dưới | Màn hình trợ lý mở ra với giao diện 3 tab: Trò chuyện, Tìm kiếm kết hợp, Gợi ý lịch trình. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-28** | Tab 1 - Trò chuyện (Chat tư vấn) | Nhập câu hỏi: "Nên mang trang phục gì khi đi Sa Pa tháng 11?" | AI phản hồi gợi ý chi tiết, có định dạng đẹp mắt và danh sách lời khuyên thực tế. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-29** | Tab 2 - Tìm kiếm kết hợp (Hybrid Search) | Nhập từ khóa: "quán cà phê ngắm hoàng hôn Đà Lạt" | Trả về danh sách địa điểm đề xuất phù hợp trong danh mục kèm đánh giá và mô tả ngắn. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-30** | Tab 3 - Gợi ý lịch trình (Recommend) | Chọn điểm đến và số ngày rồi bấm "Gợi ý lịch trình" | Sinh đề xuất lịch trình các buổi Sáng/Chiều/Tối có phân bổ hoạt động hợp lý. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-31** | Công tắc tìm kiếm có dẫn chứng (Grounding) | Bật công tắc "Tìm kiếm có dẫn chứng web" và gửi câu hỏi | Kết quả có gắn nhãn nguồn tham khảo minh bạch (Law 3). | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-32** | Xem trước & Xác nhận áp dụng AI | Xem lịch trình AI đề xuất -> Bấm Xem trước (Preview) -> Thử bấm Hủy rồi bấm Áp dụng | Bấm Hủy: Giữ nguyên lịch hiện tại. Bấm Áp dụng: Cập nhật hoạt động vào lịch trình chính thức. | `[ ] PASS`<br>`[ ] FAIL` | |

---

### Module 7: Cộng Đồng, Đánh Giá & Chia Sẻ (Community & Reviews)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-33** | Bảng tin cộng đồng (Community Feed) | Mở màn hình Khám phá cộng đồng | Hiển thị danh sách các bài chia sẻ chuyến đi từ người dùng khác kèm số lượt thích và đánh giá. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-34** | Sao chép chuyến đi (Clone Trip) | Mở một chuyến đi chia sẻ trên cộng đồng -> Bấm **"Sao chép về chuyến đi của tôi"** | Tạo một bản sao độc lập lưu vào tài khoản của mình để có thể tự do sửa đổi. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-35** | Đánh giá sao (Rating Stars) | Tại trang chi tiết địa điểm, chạm chọn số sao (1 đến 5 sao) | Hệ thống ghi nhận số sao được chọn và cập nhật giao diện trực quan ngay lập tức. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-36** | Viết nhận xét & Xem danh sách đánh giá | Nhập nội dung nhận xét và bấm Gửi đánh giá | Đánh giá mới xuất hiện trong danh sách nhận xét của địa điểm. | `[ ] PASS`<br>`[ ] FAIL` | |

---

### Module 8: Quản Trị Hệ Thống (Admin Panel & Access Gate)

| Test ID | Chức năng kiểm thử | Các bước thao tác | Kết quả mong đợi | Đánh giá | Người test & Ghi chú |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **TC-37** | Chặn quyền tài khoản thường & Khách | Dùng tài khoản thường hoặc tài khoản Khách | Không hiển thị nút vào trang Quản trị Admin; nếu cố tình mở thì bị chặn với thông báo lỗi rõ ràng. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-38** | Chế độ Demo Sandbox Offline | Chuyển sang tài khoản quản trị khi đang offline hoặc server chưa kết nối | App kích hoạt chế độ Sandbox Offline minh bạch, cho phép duyệt số liệu mẫu không bị đơ hoặc văng lỗi mạng. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-39** | Xem Dashboard chỉ số Admin | Vào Dashboard Admin | Hiển thị thẻ thống kê: Tổng người dùng, Tổng chuyến đi, Lượt truy cập và biểu đồ chu kỳ 7/30 ngày. | `[ ] PASS`<br>`[ ] FAIL` | |
| **TC-40** | Quản lý trạng thái ấn phẩm (Publication) | Vào danh sách điểm đến trong Admin | Xem được trạng thái Đã phát hành (Published) / Bản nháp (Draft) của từng điểm đến. | `[ ] PASS`<br>`[ ] FAIL` | |

---

## 3. Mẫu Báo Cáo Lỗi Khi Phát Hiện Tính Năng FAIL

Khi một thành viên kiểm thử phát hiện tính năng không hoạt động như mong đợi, vui lòng gửi phản hồi theo định dạng mẫu sau:

```markdown
### [BÁO CÁO LỖI] - <Mã Test ID> - <Tên Chức Năng>
- **Thành viên phát hiện:** (Vd: Nguyễn Văn A)
- **Thiết bị thử nghiệm:** (Vd: Android Pixel 7 Emulator API 34 hoặc Xiaomi Redmi Note 12 - Android 13)
- **Mô tả hiện tượng lỗi:** (Vd: Bấm nút "Lập lịch trình" ở chi tiết điểm đến nhưng không chuyển trang)
- **Các bước tái hiện (Steps to reproduce):**
  1. Vào tab Khám phá
  2. Bấm vào điểm đến Hà Nội
  3. Bấm nút "Lập lịch trình"
  4. Quan sát thấy màn hình không phản hồi
- **Ảnh chụp màn hình / Video đính kèm:** (Nếu có)
- **Ghi chú thêm:** (Có đang bật mạng hay tắt mạng không)
```
