# P3.1 — Đối chiếu phản hồi catalogue của Owner

Ngày kiểm: 2026-10-15. Phạm vi: review dữ liệu và hiệu chỉnh thiết kế, chưa sửa
JSON, code hoặc database. Giữ 12 destination IDs. Đây không là review toàn bộ
72 địa điểm hoặc chứng nhận mọi địa điểm đang đón khách ở ngày kiểm.

## 1. Kết luận và nguyên nhân

Phân biệt ba câu hỏi độc lập: đúng danh tính/vùng, đúng thông tin hoạt động,
và hợp lý về lịch trình. Nguồn nhắc tên chỉ hỗ trợ câu đầu. Không biến ngày
đọc website hoặc phản hồi Owner thành ngày xác minh mở cửa/tuyến thực tế.

Các cặp trong phần lớn sample khớp thứ tự danh sách, nhưng không có dữ liệu
route/duration/giờ để chứng minh khả thi. Đây là thiếu bước review lịch, không
phải lỗi cần sửa MCDA/Pareto/Greedy. Tên gọi “lịch ba ngày” dễ gây hiểu là một
chuyến ba ngày hai đêm có thể sử dụng ngay; thêm disclaimer không sửa cặp sai.

## 2. Đối chiếu và hướng xử lý

| Điểm đến | Owner feedback | Codex evidence và hướng xử lý |
| --- | --- | --- |
| Hà Nội | Giữ, có thể tối ưu | Chưa kiểm tuyến độc lập trong task này; không tự đánh dấu lịch tối ưu. |
| Hạ Long | Gom theo tuyến tàu | Đã đọc nguồn Ban quản lý: Sửng Sốt/Mê Cung thuộc VHL2; danh sách VHL1 có Thiên Cung/Trống Mái. Không ghép Mê Cung–Thiên Cung như cùng tuyến mặc định; không suy một tàu ghé đủ mọi điểm của tuyến. |
| Sa Pa | Sửa Sa Pa-napro | Website operator dùng SAPANAPRO và nêu Tả Phìn/sản phẩm tắm Dao đỏ. Chấp nhận hướng chuẩn hóa tên; chưa xác minh dịch vụ tại chỗ đang nhận khách hoặc lịch đặt chỗ. Giữ ID cũ khi sửa display name. |
| Ninh Bình | Tối ưu tuyến | Chưa đo tuyến/giờ; giữ phản hồi là đề xuất review, không cấp chứng nhận lịch. |
| Huế | Gom các lăng | Đề xuất biên tập cần thời lượng/di chuyển trước khi khẳng định phù hợp; không ép ba lăng vào một ngày. |
| Đà Nẵng | Ghi cụ thể chùa Linh Ứng/Quan Thế Âm | Cổng du lịch Đà Nẵng xác nhận quan hệ Sơn Trà–chùa Linh Ứng–tượng. Phân biệt vùng và điểm con, không tính chúng như hai hoạt động độc lập mặc định. Không lấy giá/giờ từ bài cũ làm dữ liệu live. |
| Hội An | Gom phố cổ, Chùa Cầu, Tấn Ký, bảo tàng | Hướng nhóm theo khu vực của Owner được ghi nhận; chưa xác minh thời gian đủ trong một ngày hoặc trạng thái đón khách từng điểm. |
| Nha Trang | Hòn Mun hạn chế; Bảo Đại mở 4/2026 | Báo Khánh Hòa 2024 dẫn Ban quản lý về tạm dừng hoạt động trong phân khu Hòn Mun; chưa có xác minh cập nhật 2026 trong task này. Claim Bảo Đại mở tháng 4/2026, hai biệt thự/thứ Hai–Sáu vẫn OWNER-REPORTED/UNVERIFIED, chưa tìm được bài trực tiếp hỗ trợ. Không tự sinh hoạt động lặn hoặc lịch vào biệt thự. |
| Đà Lạt | Bidoup có trekking dài | Trang chính thức có nhiều tuyến, gồm tuyến Bidoup 17 km; có nội dung thời lượng không nhất quán giữa tiêu đề và thẻ. Không lấy số giờ tự động; cần chọn loại tour trước, không mặc định ghép với Linh Phước cùng ngày. Khoảng cách 50 km chưa đo độc lập ở task này. |
| TP.HCM | Đức Bà trùng tu, chỉ xem ngoài | Bài chính nhà thờ ngày 19/3/2026 nói dự án tiếp tục cả trong/ngoài. Chưa xác nhận chính sách khách du lịch ở ngày 15/10; không coi lịch lễ là giờ tham quan. Chỉ đề xuất xem ngoài có điều kiện tiếp cận, không khẳng định toàn nhà thờ đóng. |
| Phú Quốc | Tách vùng Bắc/Nam, thời lượng Hòn Thơm | Ghi nhận hướng review; chưa đo route hoặc xác minh vận hành/cáp treo ở task này. Không tự thêm quãng đường/phút hoặc nói hai điểm chắc chắn đủ một ngày. |
| Cần Thơ | Bằng Lăng xa Cồn Sơn | Bài Báo Cần Thơ ghi Bằng Lăng cách trung tâm hơn 50 km. Đủ căn cứ cảnh báo review di chuyển; không suy thời gian từ Cồn Sơn hoặc tuyến hiện tại. |

## 3. Nguồn đã đọc và giới hạn từng claim

- [Hành trình VHL2 — Ban quản lý](https://halongbay.com.vn/vi/tours/2-ha-long-bay-itinerary-2-international-cruise-port-soi-sim-beach-ti-top-island-sung-sot-cave-tung-sau-lagoon-me-cung-cave-bo-nau-cave-luon-cave-trong-cave-trinh-nu-cave-ho-dong-tien): hỗ trợ membership tuyến, không chứng minh chuyến tàu/ngày cụ thể.
- [Danh sách hành trình Hạ Long](https://halongbay.com.vn/tours): VHL1 có Thiên Cung và Trống Mái; không dùng để suy giờ chạy/giá hiện hành.
- [SAPANAPRO](https://sapanapro.com/tam-la-nguoi-dao-tri-thuc-ban-dia-khoa-hoc/): hỗ trợ brand, Tả Phìn và sản phẩm, không là xác nhận booking/spa đang hoạt động.
- [Chùa Linh Ứng — Cổng du lịch Đà Nẵng](https://danangfantasticity.com/en/kham-pha/chua-linh-ung-bai-but-da-nang): hỗ trợ quan hệ khu vực/công trình.
- [Khôi phục vịnh Nha Trang — Báo Khánh Hòa, 2024](https://baokhanhhoa.vn/chinh-tri/dua-nq09-vao-cuoc-song/202409/chung-tay-phuc-hoi-vinh-nha-trang-ky1tung-buoc-phuc-hoi-ran-san-ho-3a2121a/): hạn chế hoạt động được báo tại thời điểm bài, không là xác nhận trạng thái 2026.
- [Tour tuyến — VQG Bidoup](https://bidoupnuiba.gov.vn/dich-vu/tour-tuyen-du-lich-sinh-thai/): hỗ trợ có nhiều loại tuyến; duration card không đáng lấy máy móc do mâu thuẫn hiển thị.
- [Thông tin trùng tu — Nhà thờ Đức Bà, 19/3/2026](https://www.chinhtoasaigon.org/post/dat-2-thanh-gia-len-dinh-thap-kem-19-3-2026): chứng cứ trùng tu, không là quy định đón khách du lịch tháng 10.
- [Vườn cò Bằng Lăng — Báo Cần Thơ](https://baocantho.com.vn/ve-dep-thien-nhien-o-vuon-co-bang-lang-a158289.html): mô tả khoảng cách từ trung tâm; không có route/duration tới Cồn Sơn.

Không dùng favicon/domain trong bản dán làm bằng chứng bài gốc. Không chép giá,
giờ, khoảng cách hoặc trạng thái hoạt động từ snippet quảng cáo vào catalogue.
Chưa kiểm độc lập thay đổi địa giới theo văn bản; thiết kế chỉ tách travel
destination ID khỏi admin area. Không đổi ID Hội An/Đà Nẵng/Phú Quốc/Huế.

## 4. Quy tắc cập nhật dữ liệu đề xuất

1. Chuẩn hóa tên SAPANAPRO và Linh Ứng Sơn Trà, bảo toàn place IDs/source trace.
   Tên hoạt động tắm tại chỗ chỉ công bố khi có evidence dịch vụ phù hợp.
2. Review các sample theo tuyến/khu vực và điều kiện: Hạ Long theo tàu, Bidoup
   theo loại tour, Hòn Mun theo hoạt động/phân khu, Bảo Đại theo lịch đón khách,
   Phú Quốc theo vùng; không phải lịch nào cũng có hai điểm/ngày.
3. Chưa review xong: giữ địa điểm trong danh sách tham khảo; ẩn lịch ngày của
   sample cần sửa, hiện “Ví dụ đang được rà soát”. Không xóa địa điểm để che lỗi.
4. Tách source inventory cũ khỏi reviewed/publication state trong data packet
   kế tiếp. Chưa chọn marker/schema mới trong code; freeze contract và fixtures
   khi lập plan trước khi chỉnh data/tests. Không tự thêm dataset production.
5. Trường tương lai: destinationId/placeId/name/category, location nullable,
   activity type/route hoặc zone, visit duration có đơn vị/basis; opening evidence
   phải có activity/scope/source/observedAt. Không dùng một boolean open cho mọi
   hoạt động; không phát minh tọa độ/duration. recommended_day thuộc sample.
6. AI có thể đề xuất cách sắp xếp; dữ liệu tuyến/thời gian và server validation
   mới là cơ sở đánh giá khả thi. Không tự dùng LLM để tính route hoặc xác minh
   mở cửa, và không chuyển thuật toán Decision Engine sang Flutter.

## 5. Handover

Changed: spec P3.1 R2 và báo cáo review này; chưa sửa raw catalogue/data app.
Why: đúng địa danh không suy ra hoạt động hiện tại hoặc itinerary khả thi.
Testing: web/source inspection, tài liệu/diff check; runtime/analyze/Flutter
tests/data parser revision NOT RUN vì không sửa implementation.
Problems: lịch mới chưa được biên tập/duyệt; Bảo Đại 4/2026 và trạng thái mở cửa
hiện tại chưa xác nhận. Không chấp nhận tất cả claim Owner như verified.
Lesson Candidate: danh tính, điều kiện hoạt động và khả thi lịch phải có evidence
riêng; disclaimer không thay việc sửa nội dung sai.
