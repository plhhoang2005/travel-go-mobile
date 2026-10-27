# Coverage ledger — Giá vé/giờ tham quan 72 địa điểm

Ngày kiểm tra: **20/10/2026**. Phạm vi lấy đúng 72 stable IDs từ asset đang có, không thêm hoặc thay địa điểm. Development seed `assets/catalogue/place_visit_details_v1.json` đã tích hợp màn hình; chưa publish live.

## Trạng thái thực tế

- Inventory: **72/72 IDs**, thuộc **12 destinations**.
- Đã đối chiếu và đưa vào seed **16/72 hồ sơ có giá/giờ reviewed theo phạm vi đã ghi**:2 Hà Nội,6 Hạ Long,4 Huế,2 Hội An và2 Đà Nẵng (Ngũ Hành Sơn/Sơn Trà). Không cộng snapshot lịch sử vào số reviewed.
- Bốn hồ sơ chỉ có giá: Phố cổ/Chùa Cầu Hội An, Linh Ứng Bãi Bụt, Đèo Hải Vân. Chợ Hàn chỉ có giờ tham khảo có nguồn. Không trộn giờ/giá của đường phố, di tích, cơ sở hoặc dịch vụ riêng.
- Reviewed trong seed: **giá20/72, giờ17/72**. Màn hình đã nối lớp dữ liệu cho toàn bộ72 IDs, tests kiểm binding đúng ID và6 hồ sơ/trang; **native/publish chưa nghiệm thu**.56 hồ sơ chưa đủ cả hai trường:4 chỉ có giá,1 chỉ có giờ,51 thiếu cả hai. Không gọi UI binding, source coverage và native coverage là một.
- Các hàng NOT_RESEARCHED phải tiếp tục tra cứu; không phải giá0, miễn phí hoặc mở24/7. Thiếu nguồn là blocker của mục tiêu FULL72.

Quy tắc: SOURCED_SNAPSHOT chỉ mô tả nội dung nguồn được đọc ngày 20/10, không khẳng định giá/giờ chắc chắn không đổi tại ngày đi. F2 ghi cập nhật31/03/2025; F3 ghi06/11/2024. Ngày truy cập khác ngày nguồn ban hành.

## Danh sách đầy đủ

| STT | Điểm đến | Stable place ID | Địa điểm | Giá vé | Giờ tham quan | Nguồn | Ghi chú / việc còn lại |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | Hà Nội | `ha-noi/hoan-kiem` | Hồ Hoàn Kiếm | REVIEWED_SEED | REVIEWED_SEED | [F5] | Chỉ đi dạo ven hồ miễn phí; nguồn mô tả mở cả ngày, theo điều tiết tại chỗ. Không gồm vé/lịch đền Ngọc Sơn hoặc lịch phố đi bộ. |
| 2 | Hà Nội | `ha-noi/van-mieu` | Văn Miếu – Quốc Tử Giám | REVIEWED_SEED | REVIEWED_SEED | [F1] | Ban ngày 70.000đ; ưu tiên 35.000đ/miễn theo đối tượng và giấy tờ; 08:00–17:00 hằng ngày. Không áp giá này cho tour đêm. Ưu tiên nguồn quản lý, F5 còn ghi giá cũ 30k. |
| 3 | Hà Nội | `ha-noi/old-quarter` | Phố cổ Hà Nội | SCOPE_REVIEW_REQUIRED | SCOPE_REVIEW_REQUIRED | [F5] | Tổng quan ghi miễn phí, 07:00–nửa đêm; chưa có quy định quản lý xác nhận đó là giờ đường phố hay cơ sở. Seed chưa duyệt. |
| 4 | Hà Nội | `ha-noi/opera` | Nhà hát Lớn Hà Nội | SCOPE_REVIEW_REQUIRED | SOURCE_FOUND | [F5] | Nguồn tổng quan ghi giá chung và dẫn lịch diễn; trang hanoioperahouse.org.vn chưa đọc được. Không dùng 300k cho mọi show/tour. |
| 5 | Hà Nội | `ha-noi/one-pillar` | Chùa Một Cột | SCOPE_REVIEW_REQUIRED | SCOPE_REVIEW_REQUIRED | [F5] | Có giá 25k/lịch trong tổng quan nhưng cần phí theo đối tượng và đối chiếu quản lý; không dựa tổng quan có nhiều dữ liệu cũ để duyệt. |
| 6 | Hà Nội | `ha-noi/st-joseph` | Nhà thờ Lớn Hà Nội | SCOPE_REVIEW_REQUIRED | CONFLICT | [F5] | Nguồn tổng quan ghi 08–12/14–18 hằng ngày; bài dẫn nội quy giáo xứ ghi 08–11/14–17 thứ Hai–Bảy. Trang giaoxuchinhtoahanoi.org chưa đọc được; không dùng giờ lễ làm giờ tham quan. |
| 7 | Hạ Long | `ha-long/bay` | Vịnh Hạ Long | REVIEWED_SEED | REVIEWED_SEED | [F2], [F3] | 8 tuyến ban ngày và 6 lựa chọn lưu trú có phí chung; giờ cảng 01/4–31/10 xuất từ05:00/về trước20:00, 01/11–31/3 xuất từ05:30/về trước19:00. Không coi giờ về là giờ chuyến cuối được nhận khách. |
| 8 | Hạ Long | `ha-long/sung-sot` | Hang Sửng Sốt | REVIEWED_SEED | REVIEWED_SEED | [F2], [F3] | VHL2:250k/người/lần cho tuyến, dùng cùng package với Mê Cung. 16/4–31/10 07:30–17:30;01/11–15/4 07:30–17:00. |
| 9 | Hạ Long | `ha-long/me-cung` | Hang Mê Cung | REVIEWED_SEED | REVIEWED_SEED | [F2], [F3] | Cùng phí VHL2;08:00–17:30 hè/08:00–17:00 đông. Không cộng250k lần nữa khi cùng tuyến với Sửng Sốt. |
| 10 | Hạ Long | `ha-long/thien-cung` | Động Thiên Cung | REVIEWED_SEED | REVIEWED_SEED | [F2], [F3] | VHL1:250k/người/lần cho tuyến;07:30–17:30 hè/07:30–17:00 đông theo mốc mùa đón khách16/4. |
| 11 | Hạ Long | `ha-long/ga-choi` | Hòn Gà Chọi | REVIEWED_SEED | REVIEWED_SEED | [F2], [F6] | Alias Trống Mái được nguồn quản lý xác nhận, tuyến1/5; ngắm từ tàu đi qua nên thời điểm theo chuyến, không gán một khung giờ mở cửa riêng. Conditions yêu cầu xác nhận hành trình với đơn vị tàu. |
| 12 | Hạ Long | `ha-long/tuan-chau` | Tuần Châu | REVIEWED_SEED | REVIEWED_SEED | [F7], [F8], [F9], [F10] | Phạm vi Tuần Châu Park, không phải toàn đảo/cảng/phà. Gói4 người lớn300k; gói3 kèm đồ uống người lớn150k, trẻ80–100cm50k. Không tự suy miễn phí cho các nhóm khác. Lịch từng phân khu và show10:00/15:00 riêng, áp từ04/05/2026. |
| 13 | Sa Pa | `sa-pa/fansipan` | Fansipan | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 14 | Sa Pa | `sa-pa/cat-cat` | Bản Cát Cát | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 15 | Sa Pa | `sa-pa/ta-phin` | Bản Tả Phìn | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 16 | Sa Pa | `sa-pa/bac-ha` | Chợ Bắc Hà | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 17 | Sa Pa | `sa-pa/muong-hum` | Chợ Mường Hum | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 18 | Sa Pa | `sa-pa/sapa-napro` | SAPANAPRO, Tả Phìn | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 19 | Ninh Bình | `ninh-binh/hang-mua` | Hang Múa | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 20 | Ninh Bình | `ninh-binh/tam-coc` | Tam Cốc | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 21 | Ninh Bình | `ninh-binh/trang-an` | Tràng An | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 22 | Ninh Bình | `ninh-binh/hoa-lu` | Cố đô Hoa Lư | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 23 | Ninh Bình | `ninh-binh/van-long` | Đầm Vân Long | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 24 | Ninh Bình | `ninh-binh/bai-dinh` | Chùa Bái Đính | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 25 | Huế | `hue/citadel` | Kinh thành Huế | REVIEWED_SEED | REVIEWED_SEED | [F11], [F12], [F13] | Phạm vi Đại Nội có vé, không phải toàn Kinh thành. Vé lẻ người lớn200k/trẻ7–12 tuổi40k; giữ các gói2/3/4/all theo đúng quyền lợi. Hè16/3–15/10 tham quan06:30–18:30, bán vé đến17:30; đông16/10–15/3 tham quan07:00–18:00, bán vé đến17:00. |
| 26 | Huế | `hue/tu-duc` | Lăng Tự Đức | REVIEWED_SEED | REVIEWED_SEED | [F11], [F12], [F13] | Người lớn150k/trẻ7–12 tuổi30k; thêm gói chung theo tuyến. Giờ theo cổng vé Trung tâm, tách hạn bán vé và đóng cửa sau60phút. |
| 27 | Huế | `hue/minh-mang` | Lăng Minh Mạng | REVIEWED_SEED | REVIEWED_SEED | [F11], [F12], [F13] | Người lớn150k/trẻ7–12 tuổi30k; có gói chung, không cộng lại cùng gói ở mỗi di tích. |
| 28 | Huế | `hue/khai-dinh` | Lăng Khải Định | REVIEWED_SEED | REVIEWED_SEED | [F11], [F12], [F13] | Người lớn150k/trẻ7–12 tuổi30k; không áp chính sách miễn trẻ em của Gia Long/Đồng Khánh cho điểm này. |
| 29 | Huế | `hue/dong-ba` | Chợ Đông Ba | SOURCE_GAP | SCOPE_REVIEW_REQUIRED | [F14] | Huetripo ghi06:30–19:00, chưa đối chiếu đủ lịch theo ngày/phân khu; không dùng giá hàng hóa trong listing làm vé vào chợ. Seed giữ unverified. |
| 30 | Huế | `hue/thien-mu` | Chùa Thiên Mụ | SOURCE_GAP | SOURCE_GAP | — | Nguồn quản lý/du lịch tìm được chủ yếu lịch sử, chưa đủ phí/giờ; không suy free24h hay áp giờ di tích có vé. |
| 31 | Đà Nẵng | `da-nang/my-khe` | Biển Mỹ Khê | SOURCE_GAP | SOURCE_GAP | — | Trang Ban quản lý có snippet phí miễn nhưng không đọc được trực tiếp: web fetch lỗi, browser báo chứng chỉ không khớp; không bypass và không lấy snippet làm reviewed. Chưa đủ lịch tắm/cứu hộ/tiếp cận, không24/7. |
| 32 | Đà Nẵng | `da-nang/marble` | Ngũ Hành Sơn | REVIEWED_SEED | REVIEWED_SEED | [F19], [F20] | Thủy Sơn40k/HSSV10k; Âm Phủ20k/7k; thang máy riêng15k/lượt hoặc30k/khứ hồi; dưới6 tuổi miễn từng hạng mục theo nguồn.07:00–17:00 hằng ngày; không coi là giờ nhận thang máy cuối. |
| 33 | Đà Nẵng | `da-nang/son-tra` | Bán đảo Sơn Trà | REVIEWED_SEED | REVIEWED_SEED | [F21], [F22] | Miễn phí cảnh quan theo bảng2023, loại trừ cơ sở/dịch vụ riêng; nguồn nêu đúng niên đại. Ba tuyến kiểm soát:tháng3–9 07:30–18:30,tháng10–2 07:30–17:30, có trạm/rào/loại xe/hướng một chiều. Không áp toàn bán đảo/cơ sở riêng. |
| 34 | Đà Nẵng | `da-nang/lady-buddha` | Tượng Quan Thế Âm — chùa Linh Ứng Bãi Bụt, Sơn Trà | REVIEWED_SEED | CONFLICT | [F21], [F25] | Phí vào chùa miễn theo bảng2023; không suy quyền vào mọi tầng tượng. Giờ08–17 ở bảng2023 khác06–21 trong hướng dẫn khác; trang chùa chỉ đọc được nội quy, bài giờ rỗng qua web và browser. Không duyệt một giờ tùy ý. |
| 35 | Đà Nẵng | `da-nang/hai-van` | Đèo Hải Vân | REVIEWED_SEED | SOURCE_GAP | [F23] | Chỉ ngắm cảnh đường đèo miễn theo nguồn2025; loại trừ Hải Vân Quan/hầm/xe/quán/dịch vụ. Giờ gợi ý bình minh/hoàng hôn không phải giờ vận hành đã xác minh; giữ giờ unverified. |
| 36 | Đà Nẵng | `da-nang/han-market` | Chợ Hàn | SOURCE_GAP | REVIEWED_SEED | [F24] |06:00–19:00 là khung tham khảo trong bài12/06/2026, khác giờ quán Trình7:30–19:30 và có thể khác từng quầy/ngày. Nguồn không xác nhận vé/miễn, không đổi im lặng thành0. |
| 37 | Hội An | `hoi-an/ancient-town` | Phố cổ Hội An | REVIEWED_SEED | SCOPE_REVIEW_REQUIRED | [F4] | Gói80k/120k khác quyền lợi, dùng tối đa3 ngày theo nguồn16/03/2026. Lịch phố đi bộ ghi trong notes, chưa có mốc mùa đủ để tạo rules hoặc coi giờ mở toàn khu. |
| 38 | Hội An | `hoi-an/japanese-bridge` | Chùa Cầu | REVIEWED_SEED | SOURCE_GAP | [F4] | Cùng package80k/120k với phố cổ, chọn Chùa Cầu hoặc Miếu Quan Công; không cộng giá gói nhiều lần. Chưa có giờ mở riêng đủ căn cứ. |
| 39 | Hội An | `hoi-an/tan-ky` | Nhà cổ Tấn Ký | REVIEWED_SEED | REVIEWED_SEED | [F4], [F16], [F17] | Chọn điểm theo ô vé chung; F17 đối chiếu tên. F16 cổng Hội An dẫn Traveloka:08:00–11:30/13:30–17:45 thứHai–Chủnhật. Ghi rõ nguồn tổng hợp không ngày hiệu lực và yêu cầu xác nhận lịch đặc biệt. |
| 40 | Hội An | `hoi-an/history-museum` | Bảo tàng Lịch sử – Văn hóa Hội An | REVIEWED_SEED | REVIEWED_SEED | [F4], [F15], [F17] | 10B Trần Hưng Đạo,07:00–17:00 hằng ngày theo hồ sơ tổng hợp cổng Hội An, không phải7NguyễnHuệ cũ. Chỉ đưa gói120k có quyền bảo tàng rõ; không tự thêm giá vé lẻ hoặc gói80k cho điểm này. |
| 41 | Hội An | `hoi-an/an-bang` | Biển An Bàng | SOURCE_GAP | SOURCE_GAP | — | Đã rà nguồn Hội An nhưng chưa đủ claim phí/giờ; không suy miễn phí24/7 từ mô tả bãi biển hoặc phí thuê ghế. |
| 42 | Hội An | `hoi-an/cua-dai` | Biển Cửa Đại | SOURCE_GAP | SOURCE_GAP | — | Đã rà nguồn Hội An nhưng chưa đủ claim phí/giờ; không suy miễn phí24/7 từ mô tả bãi biển hoặc phí thuê ghế. |
| 43 | Nha Trang | `nha-trang/city-beach` | Bãi biển Nha Trang | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 44 | Nha Trang | `nha-trang/hon-mun` | Hòn Mun | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 45 | Nha Trang | `nha-trang/monkey-island` | Đảo Khỉ | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 46 | Nha Trang | `nha-trang/long-son` | Chùa Long Sơn | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 47 | Nha Trang | `nha-trang/po-nagar` | Tháp Bà Po Nagar | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 48 | Nha Trang | `nha-trang/bao-dai` | Biệt thự Bảo Đại | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 49 | Đà Lạt | `da-lat/xuan-huong` | Hồ Xuân Hương | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 50 | Đà Lạt | `da-lat/central-market` | Chợ Đà Lạt | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 51 | Đà Lạt | `da-lat/railway-station` | Ga Đà Lạt | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 52 | Đà Lạt | `da-lat/lang-biang` | Lang Biang | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 53 | Đà Lạt | `da-lat/bidoup` | Vườn quốc gia Bidoup – Núi Bà | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 54 | Đà Lạt | `da-lat/linh-phuoc` | Chùa Linh Phước | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 55 | TP. Hồ Chí Minh | `ho-chi-minh/notre-dame` | Nhà thờ Đức Bà Sài Gòn | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 56 | TP. Hồ Chí Minh | `ho-chi-minh/post-office` | Bưu điện Trung tâm Sài Gòn | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 57 | TP. Hồ Chí Minh | `ho-chi-minh/opera` | Nhà hát Thành phố | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 58 | TP. Hồ Chí Minh | `ho-chi-minh/ben-thanh` | Chợ Bến Thành | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 59 | TP. Hồ Chí Minh | `ho-chi-minh/jade-emperor` | Chùa Ngọc Hoàng | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 60 | TP. Hồ Chí Minh | `ho-chi-minh/binh-tay` | Chợ Bình Tây | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 61 | Phú Quốc | `phu-quoc/sao` | Bãi Sao | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 62 | Phú Quốc | `phu-quoc/hon-thom` | Hòn Thơm | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 63 | Phú Quốc | `phu-quoc/national-park` | Vườn quốc gia Phú Quốc | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 64 | Phú Quốc | `phu-quoc/long-beach` | Bãi Trường | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 65 | Phú Quốc | `phu-quoc/ganh-dau` | Mũi Gành Dầu | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 66 | Phú Quốc | `phu-quoc/dinh-cau` | Dinh Cậu | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 67 | Cần Thơ | `can-tho/cai-rang` | Chợ nổi Cái Răng | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 68 | Cần Thơ | `can-tho/ninh-kieu` | Bến Ninh Kiều | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 69 | Cần Thơ | `can-tho/ong-pagoda` | Chùa Ông | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 70 | Cần Thơ | `can-tho/binh-thuy` | Nhà cổ Bình Thủy | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 71 | Cần Thơ | `can-tho/con-son` | Cồn Sơn | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |
| 72 | Cần Thơ | `can-tho/bang-lang` | Vườn cò Bằng Lăng | NOT_RESEARCHED | NOT_RESEARCHED | — | Chưa đọc đủ nguồn cho giá và giờ. |

## Nguồn đã mở trực tiếp

- [F1]: https://vanmieu.gov.vn/vi/visitor-information — Trung tâm Văn Miếu–Quốc Tử Giám; thông tin du khách. Kiểm20/10/2026; không suy giá tour đêm từ vé ban ngày.
- [F2]: https://halongbay.com.vn/p/58-muc-phi-tham-quan-vinh-ha-long — Ban quản lý, mức phí theo tuyến; trang ghi31/03/2025. Kiểm20/10/2026.
- [F3]: https://halongbay.com.vn/p/71-thoi-gian-don-tra-khach-ve-cang-ben — Ban quản lý, lịch đón khách từng điểm theo mùa; trang ghi06/11/2024. Kiểm20/10/2026.
- [F4]: https://hoianworldheritage.org.vn/vi/news/Du-lich-Hoi-An/cap-nhat-ve-tham-quan-khu-pho-co-hoi-an-hanh-trinh-cham-ve-nguyen-ban-giua-long-di-san-3033.hwh — cập nhật vé16/03/2026; kiểm 20/10/2026. Không nhầm giờ phố đi bộ thành giờ di tích.

[F1]: https://vanmieu.gov.vn/vi/visitor-information
[F2]: https://halongbay.com.vn/p/58-muc-phi-tham-quan-vinh-ha-long
[F3]: https://halongbay.com.vn/p/71-thoi-gian-don-tra-khach-ve-cang-ben
[F4]: https://hoianworldheritage.org.vn/vi/news/Du-lich-Hoi-An/cap-nhat-ve-tham-quan-khu-pho-co-hoi-an-hanh-trinh-cham-ve-nguyen-ban-giua-long-di-san-3033.hwh
[F5]: https://image.vietnam.travel/vi/things-to-do/11-must-see-attractions-ha-noi
[F6]: https://halongbay.com.vn/en/places/5-hon-trong-mai
[F7]: https://booking.tuanchauverse.com/vi/combo-tuan-chau-park
[F8]: https://booking.tuanchauverse.com/vi/tuan-chau-farm
[F9]: https://booking.tuanchauverse.com/vi/hours
[F10]: https://booking.tuanchauverse.com/vi/news/tuan-chau-park-cam-nang-kham-pha-cong-vien-giai-tri-da-dang-tai-dao-tuan-chau-tu-a-den-z
[F11]: https://hueworldheritage.org.vn/Thong-tin-tham-quan/Gia-ve
[F12]: https://eticket.hueworldheritage.org.vn/thoi-gian-tham-quan
[F13]: https://eticket.hueworldheritage.org.vn/noi-quy
[F14]: https://huetripo.hue.gov.vn/co-so-dich-vu/cho-/cho-dong-ba-hue-759007

Huế batch20/10: web extractor trả trang JavaScript rỗng và PDF timeout, đã chuyển đọc browser chính thức. Menu cổng vé dẫn thẳng F11. Bảng lẻ áp02/06/2026:200k/40k Đại Nội,150k/30k ba lăng; bảng tuyến áp04/01/2026 có240k/30k,200k/30k,3điểm420k/80k,4điểm530k/100k,all600k/120k; source và package IDs dùng chung. F12 xác nhận giờ đóng cửa sau60phút kết thúc bán vé, khác nhiều bài tổng quan. Không lấy giá từ snippet/PDF tải lỗi hoặc gán miễn trẻ7–12 từ di tích khác. RED `20261020T110002617Z-2392`, GREEN18 asset+model tests `20261020T110217269Z-14348`, exit0.60 ID chưa reviewed là4 Hà Nội còn lại,2 Huế còn lại, và54 thuộc9 điểm đến khác; xem từng hàng ledger. Chưa đủ điều kiện build/publish release complete.

Hạ Long batch review20/10: F2/F3 mở lại đầy đủ; F6 đối chiếu alias và hình thức tàu đi qua. F7/F8 là trang sản phẩm đang ghi giá, ưu tiên đúng gói thay cho giá100k của bài cũF10 (gói3 có quyền lợi khác); không chuyển combo ẩm thực ghi hết hạn31/08/2026 thành giá hiện hành. Chính sách miễn/giảm ngoài các nhóm đã nêu chưa được mở rộng bằng suy luận. F9 lịch áp04/05/2026, Farm/FarmHill nghỉ giữa ngày; nguồn chỉ nêu giờ bắt đầu show, không bịa giờ kết thúc. Data/model tests17PASS log `20261020T105336315Z-5084`; reviewed8, còn64. Các cảnh báo Hanoi được đổi thành lời hướng dẫn cho khách, chi tiết research giữ ở ledger.

Execution source review 20/10: F1 đã mở lại ở URL canonical `https://www.vanmieu.gov.vn/vi/introduction/visitor-information`; F5 là cổng Cục Du lịch Quốc gia, dùng riêng mục Hồ Hoàn Kiếm cho hai claim seed, không dùng giá Văn Miếu trong bài. F5 không ghi ngày hiệu lực; checkedAt là ngày đọc. Không sao chép toàn bài/ảnh. Bài dẫn nội quy giáo xứ dùng để phát hiện mâu thuẫn, chưa dùng làm evidence reviewed: https://thuha.rentbikehanoi.com/du-lich/nha-tho-lon-ha-noi/ .

## Cách cập nhật khi thực thi

Mỗi batch 6 nơi: đọc nguồn price/hours riêng → xác định đúng khu/vé/tuyến/ngày/mùa → ghi ngày và URL → review các claim → thêm dataset mới → tests binding → native subset. Chỉ nâng REVIEWED/IN_APP_VERIFIED khi có evidence tương ứng. Không tự thay địa điểm thiếu nguồn; ghi exact unresolved item cho owner.


[F15]: https://hoiancreativecity.com/vi/bao-tang-lich-su-van-hoa-hoi-an-minh-chung-song-dong-cua-thuong-cang-phon-thinh-mot-thoi
[F16]: https://hoiancreativecity.com/vi/nha-co-tan-ky-noi-luu-giu-ve-dep-xua-cu-cua-hoi-an
[F17]: https://www.hoianworldheritage.org.vn/vi/news/Dieu-can-biet/ve-tham-quan-hoi-an-1940.hwh
[F18]: https://hoiancreativecity.com/vi/bang-gia-ve-tham-quan-pho-co-hoi-an

Hội An batch20/10 (current): đọc lại F4 và thông tin vé2023, dùng giá/quyền lợi theo F4 tháng3/2026; F17 (2020) chỉ map tên Tấn Ký/bảo tàng, không lấy lịch phố đi bộ cũ hoặc quốc tịch/tuổi giảm từ trang này. F18 cùng portal còn giữ cách chia giá theo quốc tịch và địa điểm biểu diễn cũ; không trộn với quyền lợi mới của F4. F15 là mục tổng hợp, F16 ghi bài/ảnh Traveloka; cả hai không nêu ngày công bố/hiệu lực. Dataset nêu đúng mức độ nguồn này và cần kiểm lịch trước đi, không nhận đó là thông báo vận hành mới hôm nay. F16 web extractor timeout, browser đọc trực tiếp được hai buổi. Không lấy giờ phố đi bộ làm giờ Chùa Cầu, không tự đặt ngày chuyển mùa. Hai biển thiếu bằng chứng phí/giờ cụ thể. Giá16,giờ14,both14/72;58 chưa đủ cả hai. RED `20261020T135352447Z-26968` assertion thiếu reviewed; GREEN36 asset/domain/Discovery/detail/builder `20261020T135500596Z-22580`, exit0; scoped analyzer clean. Protected catalogue SHA không đổi. Đây là tiến độ dữ liệu, chưa phải FULL/native/live acceptance.

Nguồn sẵn cho packet Đà Nẵng tiếp theo, chưa nhập seed hoặc tính reviewed: https://danangfantasticity.com/en/len-lich-kham-pha-da-nang-2026-cap-nhat-gia-ve-tham-quan-cac-diem-khu-du-lich (22/01/2026). Có bảng Ngũ Hành Sơn07–17,ThủySơn40k/HSSV10k,ÂmPhủ20k/7k,thangmáy15k/lượt30kkhứhồi,nhómtrẻdưới6miễn; cần đối chiếu quản lý đúng subsite và điều kiện trước nhập. HảiVânQuan ở bảng này còn ghi tự do, khác bảng vé Huế2026, càng không áp vào Đèo Hải Vân của catalogue.
Full check sau Hội An: analyzer clean, Flutter841/Node89 PASS, exit0, log `20261020T135542693Z-7776`. Current staging/main/debug/x64 APK SHA `5332D97D8D911ABD296073F966B511852AEFECC6E9CE9F6323BBFC5729604B51`; source asset SHA `21F3F23EDA726C9F2258EC222DEFA241C1D4ADB4AA3EDC904BC4064E9DC9E0EC`. Native/install/live NOT RUN. Packet đã tới25 outer calls/5 authored files/0 repairs; checkpoint, chờ owner continuation theo workflow guard. Lịch sử14/12/8 counts ở các đoạn trước là snapshots, số current ở đầu ledger.

[F19]: https://nguhanhson.org/news/thong-tin-can-biet/gia-ve-tham-quan/
[F20]: https://danangfantasticity.com/ja/tin-tuc/len-lich-kham-pha-da-nang-2026-cap-nhat-gia-ve-tham-quan-cac-diem-khu-du-lich
[F21]: https://danangfantasticity.com/en/gia-ve-cac-diem-tham-quan-tai-da-nang-2023
[F22]: https://danangfantasticity.com/en/di-san-canh-quan/ban-dao-son-tra
[F23]: https://danangfantasticity.com/ja/di-san-canh-quan/deo-hai-van-thien-ha-de-nhat-hung-quan
[F24]: https://danangfantasticity.com/cn/am-thuc-dia-phuong/kham-pha-am-thuc-da-nang-tai-6-khu-cho-dia-phuong-noi-tieng
[F25]: https://chualinhung.vn/

Đà Nẵng batch20/10 (current): F19 web fetch lỗi nhưng browser đọc trực tiếp bảng giá/giờ, trang ghi18/06/2014; F20 bảng22/01/2026 đối chiếu cùng mức và07–17, không dùng07:30 của tổng quan2023. Không suy ngày bài2014 là ngày hiệu lực mọi mức giá. Thang máy là dịch vụ riêng và phí khứ hồi từ F20, không cộng cả một lượt và khứ hồi. Không áp miễn theo tuổi cho nhóm ngoài nguồn. Không chuyển ưu đãi ngày lễ năm2025 thành chính sách ngày thường2026.

F21 trang áp từ01/01/2023, không ghi ngày kết thúc hoặc cập nhật mới; seed ghi đúng tuổi nguồn, tham khảo và xác nhận tại điểm trước đi. Dùng riêng claim miễn cảnh quan Sơn Trà và vào Linh Ứng, không sử dụng các mức bảo tàng/cơ sở khác đã đổi. F22 kiểm soát3 tuyến chứ không phải mọi cơ sở trên bán đảo; rào đóng cuối giờ nhưng không suy cutoff/chuyến cuối. Mùa đông chứa29/2 được test cả năm nhuận. F23 ngắm cảnh miễn, giờ gợi ý không đủ để kết luậnno_fixed_hours/24h. F24 ghi rõ khung tham khảo, không cam kết mọi quầy mở suốt hoặc ngày lễ. Không dùng giờ quán Trình tại chợ làm giờ toàn chợ.

Gap còn lại của nhóm: `da-nang/my-khe` cả hai field (https://sontra.danang.vn/index.php/2019/04/21/bai-bien-my-khe/ fetch lỗi; browser certificate mismatch, không bypass); `da-nang/lady-buddha` giờ (F21 08–17 vs SunWorld06–21; trang chùa bài giờ rỗng, chỉ nội quy đọc được); `da-nang/hai-van` giờ (chỉ gợi ý thời điểm); `da-nang/han-market` phí (không có claim). Bài SunWorld chỉ dùng phát hiện mâu thuẫn, không làm evidence reviewed: https://sunworld.vn/vi/banahills/check-in/chua-linh-ung-bai-buthtml . Phạm vi đúng72IDs giữ nguyên, không thay nơi khó tra.

RED hai assertions thiếu reviewed `20261020T141034897Z-21300`; GREEN38 asset/domain/Discovery/detail/builder `20261020T141214318Z-29452`, exit0; scoped analyzer clean. Số current: giá20,giờ17,both16;56 thiếu ít nhất một field (4chỉgiá,1chỉgiờ,51thiếucảhai). Full collected: analyzer clean, Flutter843/Node89 PASS exit0, `20261020T141251289Z-16568`. Current APK main/staging/debug/x64 SHA `875D5DFE2CE48BEF169F4E0DDB820818816DD2F67CE806FE7F570CD9D43DF1D1`; source asset SHA `26BB382E435DEB1AE84B23C4642C2758E263B118D75F90420B1430EEFF7D189A`. Native/install/live NOT RUN. Packet20outer calls/5authored files/0repairs closes at5-file guard; next Ninh Bình6IDs after owner continuation. Protected catalogue/Auth/lifecycle hashes vẫn bằng preflight.